*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Keywords ***
Get Mock Requests For Path
    [Arguments]    ${method}    ${path}
    Create Session    _mock    ${MOCKSERVER_URL}
    ${matcher}=   Create Dictionary    method=${method}    path=${path}
    ${params}=    Create Dictionary    type=REQUESTS    format=JSON
    ${resp}=      PUT On Session    _mock    /mockserver/retrieve
    ...           params=${params}    json=${matcher}    expected_status=200
    RETURN    ${resp.json()}

*** Test Cases ***
TC-001_Verify_first_warn_with_registered_push_subscription_sends_real_web_push
    [Documentation]    First warn with a registered push subscription sends a real web push
    ...                and returns {warned: true, already_warned: false}
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    
    # Seed owner, driver, lot, spot, reservation, session, push_subscription
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Driver A', 'driver_${dynamic_id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, lat, lng, geofence_radius_m, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 40, 13.7563, 100.5018, 100, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NULL)
    Execute Sql String    INSERT INTO push_subscriptions (id, session_id, endpoint, keys) VALUES (${dynamic_id}, ${dynamic_id}, 'http://mockserver:1080/push/${dynamic_id}', '{"p256dh": "key1", "auth": "auth1"}')
    
    # Arm mock expectation for push endpoint
    Arm Mock Expectation    POST    /push/${dynamic_id}    200    {"status": "ok"}
    
    # Create API session
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/warn    json=${empty}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[warned]    True
    Should Be Equal As Strings    ${json}[already_warned]    False
    
    # Post-Assertions: warned_at NOT NULL
    ${db_result}=    Query    SELECT warned_at FROM sessions WHERE id = ${dynamic_id}
    Should Not Be Equal As Strings    ${db_result[0][0]}    None
    
    # Verify MockServer recorded POST to push endpoint — WITH the warning text, per the
    # CSV's Post-Assertion. "A request arrived" alone would pass a push carrying the
    # wrong (or no) message.
    ${requests}=    Get Mock Requests For Path    POST    /push/${dynamic_id}
    Should Not Be Empty    ${requests}
    Should Contain    ${requests.__str__()}    Overstay Warning

    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-002_Verify_first_warn_with_NO_push_subscription_still_sets_warned_at
    [Documentation]    First warn with NO push subscription still sets warned_at and returns
    ...                {warned: true, already_warned: false} without error
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    
    # Seed owner, driver, lot, spot, reservation, session (NO push_subscription)
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner B', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Driver B', 'driver_${dynamic_id}@test.com', 'KK5678')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, lat, lng, geofence_radius_m, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot B', 40, 13.7563, 100.5018, 100, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'B1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NULL)
    
    # Create API session
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/warn    json=${empty}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[warned]    True
    Should Be Equal As Strings    ${json}[already_warned]    False
    
    # Post-Assertions: warned_at NOT NULL
    ${db_result}=    Query    SELECT warned_at FROM sessions WHERE id = ${dynamic_id}
    Should Not Be Equal As Strings    ${db_result[0][0]}    None
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-003_Verify_second_warn_returns_already_warned_true_without_sending_push
    [Documentation]    Second warn (already warned) returns {warned: false, already_warned: true}
    ...                without sending any push and without changing warned_at
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    
    # Seed owner, driver, lot, spot, reservation, session (already warned), push_subscription
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner C', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Driver C', 'driver_${dynamic_id}@test.com', 'KK9012')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, lat, lng, geofence_radius_m, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot C', 40, 13.7563, 100.5018, 100, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'C1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '1 hour')
    Execute Sql String    INSERT INTO push_subscriptions (id, session_id, endpoint, keys) VALUES (${dynamic_id}, ${dynamic_id}, 'http://mockserver:1080/push/${dynamic_id}', '{"p256dh": "key1", "auth": "auth1"}')
    
    # Arm mock expectation for push endpoint (should NOT be called)
    Arm Mock Expectation    POST    /push/${dynamic_id}    200    {"status": "ok"}
    
    # Create API session
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/warn    json=${empty}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[warned]    False
    Should Be Equal As Strings    ${json}[already_warned]    True
    
    # Post-Assertions: warned_at NOT NULL (unchanged)
    ${db_result}=    Query    SELECT warned_at FROM sessions WHERE id = ${dynamic_id}
    Should Not Be Equal As Strings    ${db_result[0][0]}    None
    
    # Verify MockServer recorded NO POST to push endpoint
    ${requests}=    Get Mock Requests For Path    POST    /push/${dynamic_id}
    Should Be Empty    ${requests}
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-004_Verify_API_returns_404_when_session_does_not_exist
    [Documentation]    Verify API returns 404 when session does not exist
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    
    # Create API session
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/warn    json=${empty}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session not found
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Disconnect From Global Database

TC-005_Verify_API_returns_400_when_session_is_not_overstaying
    [Documentation]    Verify API returns 400 when session is not overstaying
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    
    # Seed owner, driver, lot, spot, reservation (NOT overstaying), session
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner D', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Driver D', 'driver_${dynamic_id}@test.com', 'KK3456')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, lat, lng, geofence_radius_m, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot D', 40, 13.7563, 100.5018, 100, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'D1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '30 minutes', NULL)
    
    # Create API session
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/warn    json=${empty}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session is not overstaying
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-006_Verify_warn_succeeds_even_when_push_service_is_unreachable
    [Documentation]    Verify warn succeeds even when push service is unreachable (best-effort push send)
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    
    # Seed owner, driver, lot, spot, reservation, session, push_subscription (unreachable endpoint)
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner E', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Driver E', 'driver_${dynamic_id}@test.com', 'KK7890')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, lat, lng, geofence_radius_m, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot E', 40, 13.7563, 100.5018, 100, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'E1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NULL)
    Execute Sql String    INSERT INTO push_subscriptions (id, session_id, endpoint, keys) VALUES (${dynamic_id}, ${dynamic_id}, 'http://unreachable.invalid/push/${dynamic_id}', '{"p256dh": "key1", "auth": "auth1"}')
    
    # Create API session
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/warn    json=${empty}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[warned]    True
    Should Be Equal As Strings    ${json}[already_warned]    False
    
    # Post-Assertions: warned_at NOT NULL
    ${db_result}=    Query    SELECT warned_at FROM sessions WHERE id = ${dynamic_id}
    Should Not Be Equal As Strings    ${db_result[0][0]}    None
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-007_Verify_multiple_subscriptions_each_receive_push_notification
    [Documentation]    Verify multiple subscriptions for one session each receive a push notification
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${id2}=    Evaluate    ${dynamic_id} + 1
    
    # Seed owner, driver, lot, spot, reservation, session, two push_subscriptions
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner F', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Driver F', 'driver_${dynamic_id}@test.com', 'KK1122')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, lat, lng, geofence_radius_m, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot F', 40, 13.7563, 100.5018, 100, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'F1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NULL)
    Execute Sql String    INSERT INTO push_subscriptions (id, session_id, endpoint, keys) VALUES (${dynamic_id}, ${dynamic_id}, 'http://mockserver:1080/push/${dynamic_id}_1', '{"p256dh": "key1", "auth": "auth1"}')
    Execute Sql String    INSERT INTO push_subscriptions (id, session_id, endpoint, keys) VALUES (${id2}, ${dynamic_id}, 'http://mockserver:1080/push/${dynamic_id}_2', '{"p256dh": "key2", "auth": "auth2"}')
    
    # Arm mock expectations for both push endpoints
    Arm Mock Expectation    POST    /push/${dynamic_id}_1    200    {"status": "ok"}
    Arm Mock Expectation    POST    /push/${dynamic_id}_2    200    {"status": "ok"}
    
    # Create API session
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/warn    json=${empty}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[warned]    True
    Should Be Equal As Strings    ${json}[already_warned]    False
    
    # Post-Assertions: count push_subscriptions = 2
    ${db_result}=    Query    SELECT count(*) FROM push_subscriptions WHERE session_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_result[0][0]}    2
    
    # Verify MockServer recorded POST to both push endpoints — each with the warning text
    ${requests1}=    Get Mock Requests For Path    POST    /push/${dynamic_id}_1
    Should Not Be Empty    ${requests1}
    Should Contain    ${requests1.__str__()}    Overstay Warning
    ${requests2}=    Get Mock Requests For Path    POST    /push/${dynamic_id}_2
    Should Not Be Empty    ${requests2}
    Should Contain    ${requests2.__str__()}    Overstay Warning
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-008_Verify_invalid_subscription_endpoint_is_skipped_and_request_succeeds
    [Documentation]    Verify invalid/expired subscription endpoint is skipped and request still succeeds
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    
    # Seed owner, driver, lot, spot, reservation, session, push_subscription (invalid endpoint)
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner G', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Driver G', 'driver_${dynamic_id}@test.com', 'KK3344')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, lat, lng, geofence_radius_m, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot G', 40, 13.7563, 100.5018, 100, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'G1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '2 hours', NULL)
    Execute Sql String    INSERT INTO push_subscriptions (id, session_id, endpoint, keys) VALUES (${dynamic_id}, ${dynamic_id}, 'http://invalid-endpoint.invalid/push/${dynamic_id}', '{"p256dh": "key1", "auth": "auth1"}')
    
    # Create API session
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/warn    json=${empty}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[warned]    True
    Should Be Equal As Strings    ${json}[already_warned]    False
    
    # Post-Assertions: warned_at NOT NULL
    ${db_result}=    Query    SELECT warned_at FROM sessions WHERE id = ${dynamic_id}
    Should Not Be Equal As Strings    ${db_result[0][0]}    None
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}