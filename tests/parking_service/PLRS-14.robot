*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Positive_Checkin_With_Correct_Wall_Code_And_Reservation
    [Documentation]    Verify API creates session successfully with correct wall-code and reservation inside the grace window
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_<dynamic_id>@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id, wall_code) VALUES (${dynamic_id}, 2.50, 'Test Lot', ${dynamic_id}, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, status, start_time, end_time, spot_id) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW(), NOW() + INTERVAL '2 hours', ${dynamic_id})

    # Steps
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=${dynamic_id}    wall_code=1234
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    ACTIVE
    Should Be True    ${json}[session_id] > 0
    Should Not Be Empty    ${json}[checkin_at]
    
    # Post-Assertions
    ${db_count_result}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-002_Negative_Checkin_With_Incorrect_Wall_Code
    [Documentation]    Verify API returns 401 when wall-code is incorrect
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_<dynamic_id>@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id, wall_code) VALUES (${dynamic_id}, 2.50, 'Test Lot', ${dynamic_id}, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, status, start_time, end_time, spot_id) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW(), NOW() + INTERVAL '2 hours', ${dynamic_id})

    # Steps
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=${dynamic_id}    wall_code=1235
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    401    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid wall code

    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-003_Negative_Checkin_More_Than_15_Minutes_Early
    [Documentation]    Verify API returns 425 when check-in is more than 15 minutes early (reservation starts 30 minutes from now)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_<dynamic_id>@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id, wall_code) VALUES (${dynamic_id}, 2.50, 'Test Lot', ${dynamic_id}, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, status, start_time, end_time, spot_id) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '150 minutes', ${dynamic_id})

    # Steps
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=${dynamic_id}    wall_code=1234
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    425    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Too early to check in

    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-004_Negative_Checkin_After_Grace_Window
    [Documentation]    Verify API returns 409 when check-in is after the grace window (reservation started 30 minutes ago)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_<dynamic_id>@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id, wall_code) VALUES (${dynamic_id}, 2.50, 'Test Lot', ${dynamic_id}, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, status, start_time, end_time, spot_id) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', ${dynamic_id})

    # Steps
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=${dynamic_id}    wall_code=1234
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    409    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Check-in period has expired

    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-005_Negative_Checkin_Missing_Reservation_Id
    [Documentation]    Verify API returns 400 when reservation_id is missing or null
    Create Global API Session
    ${payload}=    Create Dictionary    wall_code=1234
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Reservation ID is required

TC-006_Negative_Checkin_Missing_Wall_Code
    [Documentation]    Verify API returns 400 when wall_code is missing or null
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=1
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Wall code is required

TC-007_Negative_Checkin_Reservation_Not_Found
    [Documentation]    Verify API returns 404 when reservation is not found
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=999999    wall_code=1234
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Reservation not found

TC-008_Negative_Checkin_Reservation_Not_Confirmed
    [Documentation]    Verify API returns 409 when reservation status is not CONFIRMED
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_<dynamic_id>@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id, wall_code) VALUES (${dynamic_id}, 2.50, 'Test Lot', ${dynamic_id}, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, status, start_time, end_time, spot_id) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'PENDING', NOW(), NOW() + INTERVAL '2 hours', ${dynamic_id})

    # Steps
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=${dynamic_id}    wall_code=1234
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    409    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Reservation is not confirmed

    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-009_Positive_Checkin_Near_Early_Edge_Of_Grace_Window
    [Documentation]    Verify check-in succeeds near the early edge of the grace window (reservation starts 14 minutes from now)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_<dynamic_id>@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id, wall_code) VALUES (${dynamic_id}, 2.50, 'Test Lot', ${dynamic_id}, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, status, start_time, end_time, spot_id) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() + INTERVAL '14 minutes', NOW() + INTERVAL '134 minutes', ${dynamic_id})

    # Steps
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=${dynamic_id}    wall_code=1234
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    ACTIVE
    Should Be True    ${json}[session_id] > 0
    
    # Post-Assertions
    ${db_count_result}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-010_Positive_Checkin_Near_Late_Edge_Of_Grace_Window
    [Documentation]    Verify check-in succeeds near the late edge of the grace window (reservation started 14 minutes ago)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_<dynamic_id>@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id, wall_code) VALUES (${dynamic_id}, 2.50, 'Test Lot', ${dynamic_id}, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, status, start_time, end_time, spot_id) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '14 minutes', NOW() + INTERVAL '106 minutes', ${dynamic_id})

    # Steps
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=${dynamic_id}    wall_code=1234
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    ACTIVE
    Should Be True    ${json}[session_id] > 0
    
    # Post-Assertions
    ${db_count_result}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-011_Negative_Checkin_Reservation_Id_Zero
    [Documentation]    Verify API returns 400 when reservation_id is 0 (contract: int > 0)
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=0    wall_code=1234
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Reservation ID is required

TC-012_Negative_Checkin_Wall_Code_Length_Less_Than_Four
    [Documentation]    Verify API returns 400 when wall_code length is less than 4 (contract: string length 4)
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=1    wall_code=123
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Wall code is required

TC-013_Negative_Checkin_Wall_Code_Length_Greater_Than_Four
    [Documentation]    Verify API returns 400 when wall_code length is greater than 4 (contract: string length 4)
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=1    wall_code=12345
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Wall code is required

TC-014_Negative_Checkin_Wall_Code_Leading_Trailing_Whitespace
    [Documentation]    Verify API returns 400 when wall_code has leading/trailing whitespace (length becomes 6)
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=1    wall_code=${SPACE}1234${SPACE}
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Wall code is required

TC-015_Negative_Checkin_Wall_Code_Invalid_Characters
    [Documentation]    Verify API returns 401 when wall_code is 4 non-numeric characters that do not match the lot's code
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_<dynamic_id>@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id, wall_code) VALUES (${dynamic_id}, 2.50, 'Test Lot', ${dynamic_id}, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, status, start_time, end_time, spot_id) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW(), NOW() + INTERVAL '2 hours', ${dynamic_id})

    # Steps
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=${dynamic_id}    wall_code=abcd
    ${resp}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any

    # Verification
    Status Should Be    401    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid wall code

    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-016_Positive_Checkin_Idempotent
    [Documentation]    Verify check-in is idempotent — a second check-in for the same reservation returns the same ACTIVE session and no duplicate row
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Test Owner', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Test Driver', 'driver_<dynamic_id>@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id, wall_code) VALUES (${dynamic_id}, 2.50, 'Test Lot', ${dynamic_id}, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, status, start_time, end_time, spot_id) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW(), NOW() + INTERVAL '2 hours', ${dynamic_id})

    # Steps
    Create Global API Session
    ${payload}=    Create Dictionary    reservation_id=${dynamic_id}    wall_code=1234
    ${resp1}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any
    ${session_id1}=    Set Variable    ${resp1.json()}[session_id]
    
    # Second check-in with the same payload
    ${resp2}=    POST On Session    api    /sessions/checkin    json=${payload}    expected_status=any
    ${session_id2}=    Set Variable    ${resp2.json()}[session_id]

    # Verification
    Status Should Be    200    ${resp1}
    Status Should Be    200    ${resp2}
    ${json1}=    Set Variable    ${resp1.json()}
    Should Be Equal As Strings    ${json1}[status]    ACTIVE
    Should Be True    ${session_id1} > 0
    
    ${json2}=    Set Variable    ${resp2.json()}
    Should Be Equal As Strings    ${json2}[status]    ACTIVE
    Should Be Equal As Integers    ${session_id1}    ${session_id2}
    
    # Post-Assertions
    ${db_count_result}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

*** Keywords ***
Cleanup Test Case And Mock
    [Arguments]    ${id}=${EMPTY}
    IF    '${id}' != ''
        ${id2}=    Evaluate    ${id} + 1
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM penalties WHERE reservation_id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE reservation_id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE id IN (${id}, ${id2})
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    END
    Run Keyword And Ignore Error    Disconnect From Global Database
