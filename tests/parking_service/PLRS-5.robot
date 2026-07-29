*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Booking_Free_Spot_Returns_201
    [Documentation]    Booking a free spot for a 2-hour window returns 201 SOFT_LOCKED with price = ceil(2h)*40 = 80

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_driver_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_lot_id}=       Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_spot_id}=      Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_driver_id}, 'Driver', 'driver_${dynamic_driver_id}@x.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_lot_id}, 'Lot A', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_spot_id}, ${dynamic_lot_id}, 'A-1', true)
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            driver_id=${dynamic_driver_id}
    ...            lot_id=${dynamic_lot_id}
    ...            start_time=10:00
    ...            end_time=12:00
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    201    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Integers   ${json}[lock_ttl_sec]    300
    Should Be Equal As Integers   ${json}[price]    80

    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_driver_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_driver_id}    ${dynamic_lot_id}    ${dynamic_spot_id}

TC-002_Booking_30_Minute_Window_Returns_40
    [Documentation]    A 30-minute window is billed as a whole hour: price = ceil(0.5h)*40 = 40

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_driver_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_lot_id}=       Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_spot_id}=      Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_driver_id}, 'Driver', 'driver_${dynamic_driver_id}@x.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_lot_id}, 'Lot A', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_spot_id}, ${dynamic_lot_id}, 'A-1', true)
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            driver_id=${dynamic_driver_id}
    ...            lot_id=${dynamic_lot_id}
    ...            start_time=10:00
    ...            end_time=10:30
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    201    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Integers   ${json}[lock_ttl_sec]    300
    Should Be Equal As Integers   ${json}[price]    40

    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_driver_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_driver_id}    ${dynamic_lot_id}    ${dynamic_spot_id}

TC-003_No_Free_Spot_Available_Returns_409
    [Documentation]    409 when every spot in the lot is already soft-locked for an overlapping window

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_driver_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_lot_id}=       Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_spot_id}=      Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_driver_id}, 'Driver', 'driver_${dynamic_driver_id}@x.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_lot_id}, 'Lot A', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_spot_id}, ${dynamic_lot_id}, 'A-1', true)
    Execute Sql String    INSERT INTO reservations (driver_id, spot_id, lot_id, start_time, end_time, status, lock_expires_at) VALUES (${dynamic_driver_id}, ${dynamic_spot_id}, ${dynamic_lot_id}, '1900-01-01 10:00:00', '1900-01-01 12:00:00', 'SOFT_LOCKED', NOW() + INTERVAL '300 seconds')
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            driver_id=${dynamic_driver_id}
    ...            lot_id=${dynamic_lot_id}
    ...            start_time=10:00
    ...            end_time=12:00
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    409    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    No free spot available for the requested window

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_driver_id}    ${dynamic_lot_id}    ${dynamic_spot_id}

TC-004_Start_Time_After_End_Time_Returns_400
    [Documentation]    400 when start_time is after end_time

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_driver_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_lot_id}=       Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_spot_id}=      Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_driver_id}, 'Driver', 'driver_${dynamic_driver_id}@x.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_lot_id}, 'Lot A', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_spot_id}, ${dynamic_lot_id}, 'A-1', true)
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            driver_id=${dynamic_driver_id}
    ...            lot_id=${dynamic_lot_id}
    ...            start_time=12:00
    ...            end_time=10:00
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    400    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time must be before end time

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_driver_id}    ${dynamic_lot_id}    ${dynamic_spot_id}

TC-005_Start_Time_Equals_End_Time_Returns_400
    [Documentation]    400 when start_time equals end_time (zero-length window)

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_driver_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_lot_id}=       Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_spot_id}=      Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_driver_id}, 'Driver', 'driver_${dynamic_driver_id}@x.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_lot_id}, 'Lot A', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_spot_id}, ${dynamic_lot_id}, 'A-1', true)
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            driver_id=${dynamic_driver_id}
    ...            lot_id=${dynamic_lot_id}
    ...            start_time=10:00
    ...            end_time=10:00
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    400    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time must be before end time

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_driver_id}    ${dynamic_lot_id}    ${dynamic_spot_id}

TC-006_Driver_ID_Missing_Returns_400
    [Documentation]    400 when driver_id is missing

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_lot_id}=       Evaluate    random.randint(100000, 999999)    modules=random
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            lot_id=${dynamic_lot_id}
    ...            start_time=10:00
    ...            end_time=12:00
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    400    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Driver ID is required

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    None    ${dynamic_lot_id}    None

TC-007_Lot_ID_Missing_Returns_400
    [Documentation]    400 when lot_id is missing

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_driver_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            driver_id=${dynamic_driver_id}
    ...            start_time=10:00
    ...            end_time=12:00
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    400    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot ID is required

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_driver_id}    None    None

TC-008_Start_Time_Missing_Returns_400
    [Documentation]    400 when start_time is missing

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_driver_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_lot_id}=       Evaluate    random.randint(100000, 999999)    modules=random
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            driver_id=${dynamic_driver_id}
    ...            lot_id=${dynamic_lot_id}
    ...            end_time=12:00
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    400    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time is required

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_driver_id}    ${dynamic_lot_id}    None

TC-009_End_Time_Missing_Returns_400
    [Documentation]    400 when end_time is missing

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_driver_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_lot_id}=       Evaluate    random.randint(100000, 999999)    modules=random
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            driver_id=${dynamic_driver_id}
    ...            lot_id=${dynamic_lot_id}
    ...            start_time=10:00
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    400    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    End time is required

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_driver_id}    ${dynamic_lot_id}    None

TC-010_SQL_Injection_Rejected_Safely
    [Documentation]    SQL injection in start_time is rejected safely as 400 (no 500) and does NOT drop the drivers table

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_driver_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_lot_id}=       Evaluate    random.randint(100000, 999999)    modules=random
    ${dynamic_spot_id}=      Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_driver_id}, 'Driver', 'driver_${dynamic_driver_id}@x.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_lot_id}, 'Lot A', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_spot_id}, ${dynamic_lot_id}, 'A-1', true)
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${payload}=    Create Dictionary
    ...            driver_id=${dynamic_driver_id}
    ...            lot_id=${dynamic_lot_id}
    ...            start_time=''; DROP TABLE drivers;--
    ...            end_time=12:00
    ${resp}=       POST On Session    api    /bookings    json=${payload}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    400    ${resp}
    ${json}=            Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time must be before end time

    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM drivers WHERE id = ${dynamic_driver_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_driver_id}    ${dynamic_lot_id}    ${dynamic_spot_id}

*** Keywords ***
Cleanup Test Case And Mock
    [Arguments]    ${driver_id}    ${lot_id}    ${spot_id}
    # 1. Clear Database
    Run Keyword If    '${driver_id}' != 'None'    Execute Sql String    DELETE FROM reservations WHERE driver_id=${driver_id}
    Run Keyword If    '${driver_id}' != 'None'    Execute Sql String    DELETE FROM drivers WHERE id=${driver_id}
    Run Keyword If    '${lot_id}' != 'None'       Execute Sql String    DELETE FROM spots WHERE lot_id=${lot_id}
    Run Keyword If    '${lot_id}' != 'None'       Execute Sql String    DELETE FROM lots WHERE id=${lot_id}

    # 2. Disconnect
    Disconnect From Global Database

Status Should Be
    [Arguments]    ${expected_status}    ${response}
    Should Be Equal As Integers   ${response.status_code}    ${expected_status}