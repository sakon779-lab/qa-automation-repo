*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_API_Sends_Warning_And_Sets_Warned_At_For_An_Overstaying_Session_That_Has_Not_Been_Warned_Yet
    [Documentation]    Verify API sends warning and sets warned_at for an overstaying session that has not been warned yet

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Test Lot', 5.00, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '3 hours', NOW() - INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '3 hours', ${dynamic_id}, 'ACTIVE')

    # Create Sessions
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCK_SERVER_URL}

    # Mock POST /notify to return HTTP 200 with JSON {}
    Arm Mock Expectation    POST    /notify    200    {}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /sessions/${dynamic_id}/warn    json={}    headers=${headers}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    200    ${resp}
    Log To Console    Response Text: ${resp.text}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal    ${json}[warned]    ${True}
    Should Be Equal    ${json}[already_warned]    ${False}

    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM sessions WHERE id = ${dynamic_id} AND warned_at IS NOT NULL
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-002_Verify_API_Does_Not_Send_A_Second_Warning_For_An_Overstaying_Session_That_Has_Already_Been_Warned
    [Documentation]    Verify API does not send a second warning for an overstaying session that has already been warned

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Test Lot', 5.00, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '3 hours', NOW() - INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status, warned_at) VALUES (${dynamic_id}, NOW() - INTERVAL '3 hours', ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '5 minutes')

    # Create Sessions
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCK_SERVER_URL}

    # Mock POST /notify to return HTTP 200 with JSON {}
    Arm Mock Expectation    POST    /notify    200    {}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /sessions/${dynamic_id}/warn    json={}    headers=${headers}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    200    ${resp}
    Log To Console    Response Text: ${resp.text}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal    ${json}[warned]    ${False}
    Should Be Equal    ${json}[already_warned]    ${True}

    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT warned_at FROM sessions WHERE id = ${dynamic_id}
    Should Not Be Equal    ${db_count_result[0][0]}    ${None}

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-003_Verify_API_Returns_404_When_Session_Does_Not_Exist
    [Documentation]    Verify API returns 404 when the session does not exist

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random

    # Create Sessions
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCK_SERVER_URL}

    # Mock POST /notify to return HTTP 200 with JSON {}
    Arm Mock Expectation    POST    /notify    200    {}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${non_existent_id}=    Evaluate    random.randint(10000, 99999)    modules=random
    ${str_id}=       Convert To String    ${non_existent_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /sessions/${non_existent_id}/warn    json={}    headers=${headers}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    404    ${resp}
    Log To Console    Response Text: ${resp.text}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session not found

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Mock Server

TC-004_Verify_API_Returns_400_When_Session_Is_Not_Overstaying
    [Documentation]    Verify API returns 400 when the session is not overstaying

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Test Lot', 5.00, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '3 hours', NOW() + INTERVAL '30 minutes')
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '3 hours', ${dynamic_id}, 'ACTIVE')

    # Create Sessions
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCK_SERVER_URL}

    # Mock POST /notify to return HTTP 200 with JSON {}
    Arm Mock Expectation    POST    /notify    200    {}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /sessions/${dynamic_id}/warn    json={}    headers=${headers}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    400    ${resp}
    Log To Console    Response Text: ${resp.text}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session is not overstaying

    # Post-Assertion from CSV — no warning was recorded (warned_at stays NULL)
    ${db_count_result}=    Query    SELECT warned_at FROM sessions WHERE id = ${dynamic_id}
    Should Be Equal    ${db_count_result[0][0]}    ${None}

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

*** Keywords ***
Cleanup Test Case And Mock
    [Arguments]    ${id}
    # 1. Clear Database
    Execute Sql String    TRUNCATE reservations RESTART IDENTITY CASCADE
    Execute Sql String    TRUNCATE spots RESTART IDENTITY CASCADE
    Execute Sql String    TRUNCATE lots RESTART IDENTITY CASCADE
    Execute Sql String    TRUNCATE drivers RESTART IDENTITY CASCADE
    Execute Sql String    TRUNCATE owners RESTART IDENTITY CASCADE

    # 2. Clear Mock Safely (Step-by-step to preserve types)
    Reset Mock Server

    # 3. Disconnect
    Disconnect From Global Database

Cleanup Mock Server
    [Arguments]
    # Clear Mock Safely (Step-by-step to preserve types)
    Reset Mock Server