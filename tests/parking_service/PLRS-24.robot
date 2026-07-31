*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_Utilization_66_7_Pct
    [Documentation]    Verify utilization is 66.7 pct when one session occupied 40 of the 60-minute window on a 1-spot lot (40/60, seed inside window with margins).
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner K', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver K', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'KPI Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'K1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '50 minutes', NOW() - INTERVAL '10 minutes', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status) VALUES (${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '50 minutes', NOW() - INTERVAL '10 minutes', 'COMPLETED')
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${to}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${from}=    Evaluate    (datetime.datetime.utcnow() - datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=${from}    to=${to}
    ${resp}=    GET On Session    api    /lots/${dynamic_id}/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[utilization_pct]    66.7
    Should Be Equal As Integers    ${json}[occupied_min]    40
    Should Be Equal As Integers    ${json}[available_min]    60
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-002_Verify_Utilization_25_0_Pct
    [Documentation]    Verify utilization is 25.0 pct when a 2-spot lot has one 30-minute session in the 60-minute window (30/120).
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner K', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver K', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'KPI Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'K1', true), (${dynamic_id} + 1, ${dynamic_id}, 'K2', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '40 minutes', NOW() - INTERVAL '10 minutes', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status) VALUES (${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '40 minutes', NOW() - INTERVAL '10 minutes', 'COMPLETED')
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${to}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${from}=    Evaluate    (datetime.datetime.utcnow() - datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=${from}    to=${to}
    ${resp}=    GET On Session    api    /lots/${dynamic_id}/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[utilization_pct]    25.0
    Should Be Equal As Integers    ${json}[occupied_min]    30
    Should Be Equal As Integers    ${json}[available_min]    120
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-003_Verify_Utilization_0_0_Pct_No_Sessions
    [Documentation]    Verify utilization is 0.0 pct when the lot has a spot but no sessions in the window.
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner K', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver K', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'KPI Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'K1', true)
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${to}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${from}=    Evaluate    (datetime.datetime.utcnow() - datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=${from}    to=${to}
    ${resp}=    GET On Session    api    /lots/${dynamic_id}/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[utilization_pct]    0.0
    Should Be Equal As Integers    ${json}[occupied_min]    0
    Should Be Equal As Integers    ${json}[available_min]    60
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-004_Verify_Utilization_0_0_Pct_No_Spots
    [Documentation]    Verify utilization is 0.0 pct (division-by-zero guard) when the lot has zero spots.
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner K', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver K', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'KPI Lot', 40, '1234')
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${to}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${from}=    Evaluate    (datetime.datetime.utcnow() - datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=${from}    to=${to}
    ${resp}=    GET On Session    api    /lots/${dynamic_id}/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[utilization_pct]    0.0
    Should Be Equal As Integers    ${json}[occupied_min]    0
    Should Be Equal As Integers    ${json}[available_min]    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-005_Verify_API_Returns_400_Missing_To_Param
    [Documentation]    Verify API returns 400 when the 'to' query param is missing.
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner K', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver K', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'KPI Lot', 40, '1234')
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${from}=    Evaluate    (datetime.datetime.utcnow() - datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=${from}
    ${resp}=    GET On Session    api    /lots/${dynamic_id}/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid date format. Please use ISO 8601 (YYYY-MM-DDTHH:MM:SSZ).
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-006_Verify_API_Returns_400_Invalid_From_Date
    [Documentation]    Verify API returns 400 when 'from' is not a valid ISO 8601 datetime.
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner K', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver K', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'KPI Lot', 40, '1234')
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${to}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=not-a-date    to=${to}
    ${resp}=    GET On Session    api    /lots/${dynamic_id}/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid date format. Please use ISO 8601 (YYYY-MM-DDTHH:MM:SSZ).
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-007_Verify_API_Returns_404_Lot_Not_Found
    [Documentation]    Verify API returns 404 when the lot does not exist.
    # --- 1. SETUP PHASE ---
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${to}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${from}=    Evaluate    (datetime.datetime.utcnow() - datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=${from}    to=${to}
    ${resp}=    GET On Session    api    /lots/999999/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot with the specified ID does not exist.

TC-008_Verify_Utilization_33_3_Pct_Wider_Window
    [Documentation]    Verify utilization halves to 33.3 pct for the same 40-minute session when the window is widened to 120 minutes (40/120).
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner K', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver K', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'KPI Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'K1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '50 minutes', NOW() - INTERVAL '10 minutes', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status) VALUES (${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '50 minutes', NOW() - INTERVAL '10 minutes', 'COMPLETED')
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${to}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${from}=    Evaluate    (datetime.datetime.utcnow() - datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=${from}    to=${to}
    ${resp}=    GET On Session    api    /lots/${dynamic_id}/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[utilization_pct]    33.3
    Should Be Equal As Integers    ${json}[occupied_min]    40
    Should Be Equal As Integers    ${json}[available_min]    120
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-009_Verify_Zero_Length_Window_Returns_0_0_Pct
    [Documentation]    Verify a zero-length window (from equals to) returns 0.0 pct with available_min 0 — the empty-range guard, not an error.
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner K', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver K', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'KPI Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'K1', true)
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${now}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=${now}    to=${now}
    ${resp}=    GET On Session    api    /lots/${dynamic_id}/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[utilization_pct]    0.0
    Should Be Equal As Integers    ${json}[occupied_min]    0
    Should Be Equal As Integers    ${json}[available_min]    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-010_Verify_Inverted_Range_Returns_0_0_Pct
    [Documentation]    Verify an inverted range (from after to) returns 0.0 pct with available_min 0 — treated as an empty period, never an error.
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner K', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver K', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'KPI Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'K1', true)
    Create Global API Session
    
    # --- 2. EXERCISE PHASE ---
    ${now}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${from}=    Evaluate    (datetime.datetime.utcnow() - datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    &{params}=    Create Dictionary    from=${now}    to=${from}
    ${resp}=    GET On Session    api    /lots/${dynamic_id}/utilization    params=&{params}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[utilization_pct]    0.0
    Should Be Equal As Integers    ${json}[occupied_min]    0
    Should Be Equal As Integers    ${json}[available_min]    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

*** Keywords ***
Cleanup Test Case And Mock
    [Arguments]    ${id}
    Execute Sql String    DELETE FROM sessions WHERE id = ${id}
    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
    Execute Sql String    DELETE FROM spots WHERE id IN (${id}, ${id} + 1)
    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Disconnect From Global Database