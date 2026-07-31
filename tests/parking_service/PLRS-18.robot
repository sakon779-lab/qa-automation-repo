*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_No_Overstay_Ends_Right_Now
    [Documentation]    Verify no overstay when the reservation ends right now (inside the 10-minute grace)
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver A', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Lot A', 5.00)
    Execute Sql String    INSERT INTO spots (id, code, lot_id, is_active) VALUES (${dynamic_id}, 'OV-1', ${dynamic_id}, true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '2 hours', NOW())
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '2 hours', ${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE ---
    ${resp}=    GET On Session    api    /sessions/${dynamic_id}/overstay    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[overstaying]    ${False}
    Should Be Equal As Integers    ${json}[billable_min]    0

    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-002_Verify_No_Overstay_Ended_8_Minutes_Ago
    [Documentation]    Verify no overstay when the reservation ended 8 minutes ago (still inside the 10-minute grace)
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver A', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Lot A', 5.00)
    Execute Sql String    INSERT INTO spots (id, code, lot_id, is_active) VALUES (${dynamic_id}, 'OV-1', ${dynamic_id}, true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '8 minutes')
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '2 hours', ${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE ---
    ${resp}=    GET On Session    api    /sessions/${dynamic_id}/overstay    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[overstaying]    ${False}
    Should Be Equal As Integers    ${json}[billable_min]    0

    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-003_Verify_Overstay_Begins_Just_Past_Grace
    [Documentation]    Verify overstay begins just past the grace (reservation ended 10.5 minutes ago -> 30s margin keeps ceil at 1)
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver A', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Lot A', 5.00)
    Execute Sql String    INSERT INTO spots (id, code, lot_id, is_active) VALUES (${dynamic_id}, 'OV-1', ${dynamic_id}, true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '10 minutes 30 seconds')
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '2 hours', ${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE ---
    ${resp}=    GET On Session    api    /sessions/${dynamic_id}/overstay    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[overstaying]    ${True}
    Should Be Equal As Integers    ${json}[billable_min]    1

    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-004_Verify_Significant_Overstay
    [Documentation]    Verify significant overstay (reservation ended 39.5 minutes ago -> 29.5 min past grace -> ceil 30)
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver A', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Lot A', 5.00)
    Execute Sql String    INSERT INTO spots (id, code, lot_id, is_active) VALUES (${dynamic_id}, 'OV-1', ${dynamic_id}, true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '39 minutes 30 seconds')
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '2 hours', ${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE ---
    ${resp}=    GET On Session    api    /sessions/${dynamic_id}/overstay    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[overstaying]    ${True}
    Should Be Equal As Integers    ${json}[billable_min]    30

    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-005_Verify_API_Returns_404_For_Non_Existent_Session
    [Documentation]    Verify API returns 404 when session does not exist
    # --- 1. SETUP PHASE ---
    Create Session    api    ${BASE_API_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${resp}=    GET On Session    api    /sessions/999999/overstay    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session not found

TC-006_Verify_Completed_Session_Bills_From_Stored_Checkout_At
    [Documentation]    Verify completed session bills from stored checkout_at (checked out 40 min after end -> 30 billable) — fully deterministic: no live clock involved
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver A', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Lot A', 5.00)
    Execute Sql String    INSERT INTO spots (id, code, lot_id, is_active) VALUES (${dynamic_id}, 'OV-1', ${dynamic_id}, true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '3 hours', NOW() - INTERVAL '1 hour')
    Execute Sql String    INSERT INTO sessions (id, checkin_at, checkout_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '20 minutes 59 seconds', ${dynamic_id}, 'COMPLETED')
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE ---
    Log To Console    Checking session with dynamic_id: ${dynamic_id}
    ${resp}=    GET On Session    api    /sessions/${dynamic_id}/overstay    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Log To Console    Response JSON: ${json}
    Should Be Equal As Strings    ${json}[overstaying]    ${True}
    Should Be Equal As Integers    ${json}[billable_min]    30

    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-007_Verify_Completed_Session_Checked_Out_Within_Grace
    [Documentation]    Verify completed session that checked out within grace is not billable (checked out 8 min after end)
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver A', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Lot A', 5.00)
    Execute Sql String    INSERT INTO spots (id, code, lot_id, is_active) VALUES (${dynamic_id}, 'OV-1', ${dynamic_id}, true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '3 hours', NOW() - INTERVAL '1 hour')
    Execute Sql String    INSERT INTO sessions (id, checkin_at, checkout_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '52 minutes', ${dynamic_id}, 'COMPLETED')
    Create Session    api    ${BASE_API_URL}

    # --- 2. EXERCISE PHASE ---
    ${resp}=    GET On Session    api    /sessions/${dynamic_id}/overstay    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[overstaying]    ${False}
    Should Be Equal As Integers    ${json}[billable_min]    0

    # --- 4. TEARDOWN PHASE ---
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
