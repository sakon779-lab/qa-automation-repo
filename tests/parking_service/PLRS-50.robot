*** Settings ***
Documentation    PLRS-50 — POST /push-subscriptions stores a Web Push subscription for a session.
...
...              Every assertion here is the one written in test_designs/PLRS-50.csv. Where the
...              app disagreed with the CSV the app was fixed (PR #53); the expected results were
...              not moved to meet it. A test named "returns 400" that asserts 201 reports nothing.
...
...              `endpoint` is UNIQUE across the whole table, so no two cases may use the same URL
...              literal — under pabot they would hand each other a 409 nobody designed. Each case
...              derives its endpoint from its own dynamic id.
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Variables ***
${P256DH}     BElk3x9QmZ8yT1vW5rN7cL2pS4uA6dF8gH0jK1lM3nO5qR7sT9uV0wX2yZ4
${AUTH_KEY}   a1b2c3d4e5f6g7h8

*** Test Cases ***
TC-001_Verify_POST_push-subscriptions_stores_a_subscription_successfully
    [Documentation]    Verify POST /push-subscriptions stores a subscription successfully for an existing session
    ${id}=    New Dynamic Id
    ${endpoint}=    Set Variable    https://fcm.googleapis.com/fcm/send/${id}
    Connect To Global Database
    Seed Subscription Fixture    ${id}
    Create Global API Session
    ${payload}=    Subscription Payload    ${id}    ${endpoint}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[session_id]    ${id}
    Should Be Equal As Strings    ${json}[endpoint]    ${endpoint}
    Should Be Equal    ${json}[subscribed]    ${True}
    ${db_count}=    Query    SELECT count(*) FROM push_subscriptions WHERE session_id = ${id} AND endpoint = '${endpoint}'
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Push Test Data    ${id}

TC-002_Verify_same_endpoint_under_a_different_session_is_refused
    [Documentation]    Verify the SAME endpoint URL registered under a DIFFERENT session is refused —
    ...                the UNIQUE constraint is on endpoint alone, not on (session_id, endpoint)
    ${id}=    New Dynamic Id
    ${id2}=    Evaluate    ${id} + 1
    ${endpoint}=    Set Variable    https://fcm.googleapis.com/fcm/send/${id}
    Connect To Global Database
    Seed Subscription Fixture    ${id}
    Seed Subscription Fixture    ${id2}
    Create Global API Session
    ${payload_1}=    Subscription Payload    ${id}    ${endpoint}
    ${payload_2}=    Subscription Payload    ${id2}    ${endpoint}
    ${first}=    POST On Session    api    /push-subscriptions    json=${payload_1}    expected_status=any
    ${second}=    POST On Session    api    /push-subscriptions    json=${payload_2}    expected_status=any
    Status Should Be    201    ${first}
    Should Be Equal As Integers    ${first.json()}[session_id]    ${id}
    Should Be Equal As Strings    ${first.json()}[endpoint]    ${endpoint}
    Should Be Equal    ${first.json()}[subscribed]    ${True}
    Status Should Be    409    ${second}
    Should Be Equal As Strings    ${second.json()}[detail]    Endpoint already registered
    ${db_count}=    Query    SELECT count(*) FROM push_subscriptions WHERE endpoint = '${endpoint}'
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Push Test Data    ${id}    ${id2}

TC-003_Verify_POST_push-subscriptions_returns_400_when_session_id_is_missing
    [Documentation]    Verify POST /push-subscriptions returns 400 when session_id is missing
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    endpoint=https://fcm.googleapis.com/fcm/send/tc003    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Session ID is required

TC-004_Verify_POST_push-subscriptions_returns_400_when_endpoint_is_missing
    [Documentation]    Verify POST /push-subscriptions returns 400 when endpoint is missing
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    session_id=${1}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Endpoint is required

TC-005_Verify_POST_push-subscriptions_returns_400_when_endpoint_is_whitespace_only
    [Documentation]    Verify POST /push-subscriptions returns 400 when endpoint is whitespace-only.
    ...                A blank endpoint is a missing endpoint. The declared status is 400 with a flat
    ...                detail string — a 422 in pydantic's nested shape is a defect, not a pass.
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${whitespace}=    Evaluate    ' ' * 3
    ${payload}=    Create Dictionary    session_id=${1}    endpoint=${whitespace}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Endpoint is required

TC-006_Verify_POST_push-subscriptions_returns_400_when_keys_is_missing
    [Documentation]    Verify POST /push-subscriptions returns 400 when keys is missing
    Create Global API Session
    ${payload}=    Create Dictionary    session_id=${1}    endpoint=https://fcm.googleapis.com/fcm/send/tc006
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Keys are required

TC-007_Verify_POST_push-subscriptions_returns_400_when_keys_is_missing_p256dh_field
    [Documentation]    Verify POST /push-subscriptions returns 400 when the keys object is missing
    ...                p256dh — it cannot encrypt a push message, so it is as unusable as no keys
    ${id}=    New Dynamic Id
    ${endpoint}=    Set Variable    https://fcm.googleapis.com/fcm/send/${id}
    Connect To Global Database
    Seed Subscription Fixture    ${id}
    Create Global API Session
    ${keys}=    Create Dictionary    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    session_id=${id}    endpoint=${endpoint}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Keys are required
    ${db_count}=    Query    SELECT count(*) FROM push_subscriptions WHERE endpoint = '${endpoint}'
    Should Be Equal As Integers    ${db_count[0][0]}    0
    [Teardown]    Cleanup Push Test Data    ${id}

TC-008_Verify_POST_push-subscriptions_returns_400_when_keys_is_missing_auth_field
    [Documentation]    Verify POST /push-subscriptions returns 400 when the keys object is missing auth
    ${id}=    New Dynamic Id
    ${endpoint}=    Set Variable    https://fcm.googleapis.com/fcm/send/${id}
    Connect To Global Database
    Seed Subscription Fixture    ${id}
    Create Global API Session
    ${keys}=    Create Dictionary    p256dh=${P256DH}
    ${payload}=    Create Dictionary    session_id=${id}    endpoint=${endpoint}    keys=${keys}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Keys are required
    ${db_count}=    Query    SELECT count(*) FROM push_subscriptions WHERE endpoint = '${endpoint}'
    Should Be Equal As Integers    ${db_count[0][0]}    0
    [Teardown]    Cleanup Push Test Data    ${id}

TC-009_Verify_POST_push-subscriptions_returns_404_when_session_does_not_exist
    [Documentation]    Verify POST /push-subscriptions returns 404 when the session does not exist
    ${missing_id}=    New Dynamic Id
    Create Global API Session
    ${payload}=    Subscription Payload    ${missing_id}    https://fcm.googleapis.com/fcm/send/${missing_id}
    ${resp}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    404    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Session not found

TC-010_Verify_second_subscription_with_same_endpoint_and_session_is_refused
    [Documentation]    Verify a second subscription with the SAME endpoint URL under the SAME session
    ...                is refused — a repeat registration is a conflict, never a silent overwrite and
    ...                never an idempotent success
    ${id}=    New Dynamic Id
    ${endpoint}=    Set Variable    https://fcm.googleapis.com/fcm/send/${id}
    Connect To Global Database
    Seed Subscription Fixture    ${id}
    Create Global API Session
    ${payload}=    Subscription Payload    ${id}    ${endpoint}
    ${first}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    ${second}=    POST On Session    api    /push-subscriptions    json=${payload}    expected_status=any
    Status Should Be    201    ${first}
    Should Be Equal As Integers    ${first.json()}[session_id]    ${id}
    Should Be Equal As Strings    ${first.json()}[endpoint]    ${endpoint}
    Should Be Equal    ${first.json()}[subscribed]    ${True}
    Status Should Be    409    ${second}
    Should Be Equal As Strings    ${second.json()}[detail]    Endpoint already registered
    ${db_count}=    Query    SELECT count(*) FROM push_subscriptions WHERE session_id = ${id}
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Push Test Data    ${id}

*** Keywords ***
New Dynamic Id
    [Documentation]    A per-test id used for every seeded row AND for the endpoint URL, so two
    ...                cases can never collide on the UNIQUE endpoint column. The +1 in TC-002 is
    ...                why the range stops short of the seed floor used elsewhere.
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    RETURN    ${id}

Subscription Payload
    [Arguments]    ${session_id}    ${endpoint}
    ${keys}=    Create Dictionary    p256dh=${P256DH}    auth=${AUTH_KEY}
    ${payload}=    Create Dictionary    session_id=${session_id}    endpoint=${endpoint}    keys=${keys}
    RETURN    ${payload}

Seed Subscription Fixture
    [Arguments]    ${id}
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner A', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${id}, 'Driver A', 'driver_${id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${id}, ${id}, 'Lot A', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${id}, ${id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${id}, ${id}, ${id}, ${id}, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '30 minutes', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at) VALUES (${id}, ${id}, 'ACTIVE', NOW() - INTERVAL '2 hours')

Cleanup Push Test Data
    [Documentation]    Deletes only this test's rows, children first. Never TRUNCATE — a concurrent
    ...                test's data is not this test's to remove.
    [Arguments]    @{ids}
    FOR    ${id}    IN    @{ids}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM push_subscriptions WHERE session_id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    END
    Run Keyword And Ignore Error    Disconnect From Global Database
