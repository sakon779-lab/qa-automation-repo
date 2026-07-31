*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_API_Marks_Confirmed_Reservation_As_No_Show_Outside_Grace_Window
    [Documentation]    Verify API marks a CONFIRMED reservation as NO_SHOW when it is past the grace window and not checked in.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 80)

    Create Global API Session


    # Steps
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/sweep-noshows    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[marked]    1
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE id = ${dynamic_id} AND status = 'NO_SHOW' AND forfeited = true
    Should Be Equal As Integers    ${db_count_result[0][0]}    1


    # Teardown
    [Teardown]    Cleanup Test Case    ${dynamic_id}

TC-002_Verify_API_Does_Not_Mark_Confirmed_Reservation_As_No_Show_Within_Grace_Window
    [Documentation]    Verify API does not mark a CONFIRMED reservation as NO_SHOW when it is within the grace window.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 80)

    Create Global API Session

    # Steps
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/sweep-noshows    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[marked]    0
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE id = ${dynamic_id} AND status = 'NO_SHOW'
    Should Be Equal As Integers    ${db_count_result[0][0]}    0

    # Teardown
    [Teardown]    Cleanup Test Case    ${dynamic_id}

TC-003_Verify_API_Does_Not_Mark_Confirmed_Reservation_As_No_Show_When_Checked_In
    [Documentation]    Verify API does not mark a CONFIRMED reservation as NO_SHOW when it is checked in.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at) VALUES (${dynamic_id}, ${dynamic_id}, NOW())

    Create Global API Session

    # Steps
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/sweep-noshows    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[marked]    0
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE id = ${dynamic_id} AND status = 'NO_SHOW'
    Should Be Equal As Integers    ${db_count_result[0][0]}    0

    # Teardown
    [Teardown]    Cleanup Test Case With Sessions    ${dynamic_id}

TC-004_Verify_API_Does_Not_Mark_No_Show_Reservation_Again
    [Documentation]    Verify API does not mark a NO_SHOW reservation again.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, forfeited) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'NO_SHOW', 80, true)

    Create Global API Session

    # Steps
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/sweep-noshows    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[marked]    0
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE id = ${dynamic_id} AND status = 'NO_SHOW'
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    # Teardown
    [Teardown]    Cleanup Test Case    ${dynamic_id}

TC-005_Verify_API_Does_Not_Mark_Confirmed_Reservation_Within_Grace_Window_Boundary
    [Documentation]    Verify API does not mark a CONFIRMED reservation still inside the grace window (start 14.5 min ago - 30s margin from the boundary).
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '14 minutes 30 seconds', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 80)

    Create Global API Session

    # Steps
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/sweep-noshows    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[marked]    0
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE id = ${dynamic_id} AND status = 'NO_SHOW'
    Should Be Equal As Integers    ${db_count_result[0][0]}    0

    # Teardown
    [Teardown]    Cleanup Test Case    ${dynamic_id}

TC-006_Verify_API_Does_Not_Mark_Soft_Locked_Reservation_As_No_Show
    [Documentation]    Verify API does not mark a SOFT_LOCKED reservation as NO_SHOW.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'SOFT_LOCKED', 80)

    Create Global API Session

    # Steps
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/sweep-noshows    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[marked]    0
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE id = ${dynamic_id} AND status = 'NO_SHOW'
    Should Be Equal As Integers    ${db_count_result[0][0]}    0

    # Teardown
    [Teardown]    Cleanup Test Case    ${dynamic_id}

TC-007_Verify_API_Marks_Multiple_Eligible_Reservations_As_No_Show_In_One_Sweep
    [Documentation]    Verify API marks multiple eligible reservations as NO_SHOW in one sweep.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner 1', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver 1', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot A', 2.50, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '40 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 1, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '20 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 2, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '40 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at) VALUES (${dynamic_id}, ${dynamic_id} + 2, NOW())

    Create Global API Session

    # Steps
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/sweep-noshows    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[marked]    2
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE id IN (${dynamic_id}, ${dynamic_id} + 1) AND status = 'NO_SHOW' AND forfeited = true
    Should Be Equal As Integers    ${db_count_result[0][0]}    2

    # Teardown
    [Teardown]    Cleanup Test Case With Sessions    ${dynamic_id}

*** Keywords ***
Cleanup Test Case
    [Arguments]    ${id}
    Execute Sql String    DELETE FROM sessions WHERE reservation_id IN (${id}, ${id} + 1, ${id} + 2)
    Execute Sql String    DELETE FROM reservations WHERE id IN (${id}, ${id} + 1, ${id} + 2)
    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Disconnect From Global Database

Cleanup Test Case With Sessions
    [Arguments]    ${id}
    Cleanup Test Case    ${id}

Get Column Names From Table
    [Arguments]    ${table_name}
    ${query}=    Set Variable    SELECT column_name FROM information_schema.columns WHERE table_name = '${table_name}'
    ${result}=    Query    ${query}
    @{column_names}=    Create List
    FOR    ${row}    IN    @{result}
        Append To List    ${column_names}    ${row}[0]
    END
    RETURN    ${column_names}