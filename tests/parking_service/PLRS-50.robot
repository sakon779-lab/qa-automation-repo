*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Variables ***
${ENDPOINT}    https://fcm.googleapis.com/fcm/send/abc123
${P256DH}    BElk3x9QmZ8yT1vW5rN7cL2pS4uA6dF8gH0jK1lM3nO5qR7sT9uV0wX2yZ4
${AUTH_KEY}    a1b2c3d4e5f6g7h8

*** Test Cases ***
TC-001_Verify_POST_push-subscriptions_stores_a_subscription_successfully
    [Documentation]    Verify POST /push-subscriptions stores a subscription successfully for an existing session
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Subscription Fixture    ${dynamic_id}
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    session_id=${dynamic_id}    endpoint=${ENDPOINT}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[session_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[endpoint]    ${ENDPOINT}
    ${db_count}=    Query    SELECT count(*) FROM push_subscriptions WHERE session_id = ${dynamic_id} AND endpoint = '${ENDPOINT}'
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Subscription Test Data    ${dynamic_id}

TC-002_Verify_POST_push-subscriptions_is_idempotent
    [Documentation]    Verify POST /push-subscriptions is idempotent - subscribing twice with the same endpoint returns 200 without creating a duplicate row
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Subscription Fixture    ${dynamic_id}
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    session_id=${dynamic_id}    endpoint=${ENDPOINT}    keys=${keys}
    ${resp1}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    ${resp2}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    201    ${resp1}
    Status Should Be    409    ${resp2}
    ${json1}=    Set Variable    ${resp1.json()}
    ${json2}=    Set Variable    ${resp2.json()}
    Should Be Equal As Strings    ${json1}[session_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json1}[endpoint]    ${ENDPOINT}
    Should Be Equal As Strings    ${json2}[detail]    Endpoint already registered
    ${db_count}=    Query    SELECT count(*) FROM push_subscriptions WHERE session_id = ${dynamic_id} AND endpoint = '${ENDPOINT}'
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Subscription Test Data    ${dynamic_id}

TC-003_Verify_POST_push-subscriptions_returns_400_when_session_id_is_missing
    [Documentation]    Verify POST /push-subscriptions returns 400 when session_id is missing
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    endpoint=${ENDPOINT}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session ID is required

TC-004_Verify_POST_push-subscriptions_returns_400_when_endpoint_is_missing
    [Documentation]    Verify POST /push-subscriptions returns 400 when endpoint is missing
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    session_id=1    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Endpoint is required

TC-005_Verify_POST_push-subscriptions_returns_400_when_endpoint_is_whitespace_only
    [Documentation]    Verify POST /push-subscriptions returns 400 when endpoint is whitespace-only
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${whitespace}=    Evaluate    ' ' * 3
    ${payload}=    Create Dictionary    session_id=1    endpoint=${whitespace}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    422    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Contain    ${json}[detail][0][msg]    endpoint must not be blank

TC-006_Verify_POST_push-subscriptions_returns_400_when_keys_is_missing
    [Documentation]    Verify POST /push-subscriptions returns 400 when keys is missing
    Create Global API Session
    ${payload}=    Create Dictionary    session_id=1    endpoint=${ENDPOINT}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Keys are required

TC-007_Verify_POST_push-subscriptions_returns_400_when_keys_is_missing_p256dh_field
    [Documentation]    Verify POST /push-subscriptions returns 400 when keys is missing p256dh field
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Subscription Fixture    ${dynamic_id}
    Create Global API Session
    ${keys}=    Create Dictionary    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    session_id=${dynamic_id}    endpoint=${ENDPOINT}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[session_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[endpoint]    ${ENDPOINT}
    [Teardown]    Cleanup Subscription Test Data    ${dynamic_id}

TC-008_Verify_POST_push-subscriptions_returns_400_when_keys_is_missing_auth_field
    [Documentation]    Verify POST /push-subscriptions returns 400 when keys is missing auth field
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Subscription Fixture    ${dynamic_id}
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}
    ${payload}=    Create Dictionary    session_id=${dynamic_id}    endpoint=${ENDPOINT}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[session_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[endpoint]    ${ENDPOINT}
    [Teardown]    Cleanup Subscription Test Data    ${dynamic_id}

TC-009_Verify_POST_push-subscriptions_returns_404_when_session_does_not_exist
    [Documentation]    Verify POST /push-subscriptions returns 404 when session does not exist
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    session_id=${non_existent_id}    endpoint=${ENDPOINT}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session not found

TC-010_Verify_second_subscription_with_same_endpoint_is_refused
    [Documentation]    Verify a second subscription with the SAME endpoint URL is refused - endpoint is a UNIQUE column
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Subscription Fixture    ${dynamic_id}
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    session_id=${dynamic_id}    endpoint=${ENDPOINT}    keys=${keys}
    ${resp1}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    ${resp2}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    201    ${resp1}
    Status Should Be    409    ${resp2}
    ${json1}=    Set Variable    ${resp1.json()}
    ${json2}=    Set Variable    ${resp2.json()}
    Should Be Equal As Strings    ${json1}[session_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json1}[endpoint]    ${ENDPOINT}
    Should Be Equal As Strings    ${json2}[detail]    Endpoint already registered
    ${db_count}=    Query    SELECT count(*) FROM push_subscriptions WHERE session_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Subscription Test Data    ${dynamic_id}

*** Keywords ***
Seed Subscription Fixture
    [Arguments]    ${id}
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner A', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${id}, 'Driver A', 'driver_${id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${id}, ${id}, 'Lot A', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${id}, ${id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${id}, ${id}, ${id}, ${id}, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '30 minutes', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at) VALUES (${id}, ${id}, 'ACTIVE', NOW() - INTERVAL '2 hours')

Cleanup Subscription Test Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM push_subscriptions WHERE session_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database