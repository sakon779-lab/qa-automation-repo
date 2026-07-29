*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_Penalty_For_Session_Checked_Out_40_Min_Past_End
    [Documentation]    Verify penalty for session checked out 40 min past end (billable 30 -> 20 + 5*2 = 30)
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '1 hour', 'CONFIRMED')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '20 minutes', 'COMPLETED', NOW() - INTERVAL '30 minutes')
    
    Arm Mock Expectation    POST    /charge    200    {"status": "CHARGED"}
    
    Create Session    api    ${BASE_API_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/penalty    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[penalty]    35
    Should Be True    ${json}[penalty_id] > 0
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM penalties WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-002_Verify_Minimum_Penalty_Band
    [Documentation]    Verify minimum penalty band (billable 1 -> 20 + 5*1 = 25)
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '1 hour', 'CONFIRMED')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '49 minutes 30 seconds', 'COMPLETED', NOW() - INTERVAL '30 minutes')
    
    Arm Mock Expectation    POST    /charge    200    {"status": "CHARGED"}
    
    Create Session    api    ${BASE_API_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/penalty    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[penalty]    25
    Should Be True    ${json}[penalty_id] > 0
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM penalties WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-003_Verify_No_Penalty_When_Checkout_Is_Inside_The_10_Min_Grace
    [Documentation]    Verify no penalty when checkout is inside the 10-min grace (billable 0: no charge, no row)
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '1 hour', 'CONFIRMED')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '52 minutes', 'COMPLETED', NOW() - INTERVAL '30 minutes')
    
    Arm Mock Expectation    POST    /charge    200    {"status": "CHARGED"}
    
    Create Session    api    ${BASE_API_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/penalty    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[penalty]    0
    Should Be Equal As Strings    ${json}[penalty_id]    None
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM penalties WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-004_Verify_API_Returns_404_When_Session_Id_Not_Found
    [Documentation]    Verify API returns 404 when session id not found
    
    # --- 1. SETUP PHASE ---
    Arm Mock Expectation    POST    /charge    200    {"status": "CHARGED"}
    
    Create Session    api    ${BASE_API_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${non_existent_id}=    Evaluate    random.randint(1000, 9999) + 10000    modules=random
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${non_existent_id}/penalty    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session not found
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Reset Mock Server

TC-005_Verify_409_When_Overstaying_But_Warning_Was_Never_Sent
    [Documentation]    Verify 409 when overstaying but warning was never sent (warned_at NULL)
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '1 hour', 'CONFIRMED')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '20 minutes', 'COMPLETED', NULL)
    
    Arm Mock Expectation    POST    /charge    200    {"status": "CHARGED"}
    
    Create Session    api    ${BASE_API_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/penalty    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    409    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Warning must be sent before applying penalty
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-006_Verify_Exact_15_Min_Block_Boundary
    [Documentation]    Verify exact 15-min block boundary (billable 15 -> 20 + 5*1 = 25)
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '1 hour', 'CONFIRMED')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '35 minutes', 'COMPLETED', NOW() - INTERVAL '30 minutes')
    
    Arm Mock Expectation    POST    /charge    200    {"status": "CHARGED"}
    
    Create Session    api    ${BASE_API_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/penalty    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[penalty]    30
    Should Be True    ${json}[penalty_id] > 0
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM penalties WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-007_Verify_API_Is_Idempotent_Per_Session
    [Documentation]    Verify API is idempotent per session: a second apply returns the existing Penalty, no second charge
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '1 hour', 'CONFIRMED')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status, warned_at) VALUES (${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '20 minutes', 'COMPLETED', NOW() - INTERVAL '30 minutes')
    
    Arm Mock Expectation    POST    /charge    200    {"status": "CHARGED"}
    
    Create Session    api    ${BASE_API_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary
    ${resp1}=    POST On Session    api    /sessions/${dynamic_id}/penalty    json=${payload}    expected_status=any
    ${resp2}=    POST On Session    api    /sessions/${dynamic_id}/penalty    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp1}
    ${json1}=    Set Variable    ${resp1.json()}
    Should Be Equal As Strings    ${json1}[penalty]    35
    Should Be True    ${json1}[penalty_id] > 0
    
    Status Should Be    200    ${resp2}
    ${json2}=    Set Variable    ${resp2.json()}
    Should Be Equal As Strings    ${json2}[penalty]    35
    Should Be Equal As Integers    ${json1}[penalty_id]    ${json2}[penalty_id]
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM penalties WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

*** Keywords ***
Cleanup Test Case And Mock
    [Arguments]    ${id}
    Execute Sql String    DELETE FROM penalties WHERE reservation_id = ${id}
    Execute Sql String    DELETE FROM sessions WHERE id = ${id}
    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    
    Reset Mock Server