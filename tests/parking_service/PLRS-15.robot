*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_API_Completes_Active_Session_With_Correct_Duration_Min
    [Documentation]    Verify API completes an ACTIVE session with correct duration_min (checked in 59.5 minutes ago -> ceil rounds to 60)
    [Setup]    Setup_Test_Environment
    
    # --- EXERCISE PHASE ---
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/checkout    json={}    expected_status=any
    
    # --- VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[session_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[status]    COMPLETED
    Should Be Equal As Integers    ${json}[duration_min]    60
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM sessions WHERE id = ${dynamic_id} AND status = 'COMPLETED'
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

TC-002_Verify_Duration_Min_Rounds_Up_To_Next_Minute
    [Documentation]    Verify duration_min rounds UP to the next minute (checked in 3661 seconds ago -> 62)
    [Setup]    Setup_Test_Environment
    
    # --- EXERCISE PHASE ---
    ${resp}=    POST On Session    api    /sessions/${dynamic_id_plus_one}/checkout    json={}    expected_status=any
    
    # --- VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[session_id]    ${dynamic_id_plus_one}
    Should Be Equal As Strings    ${json}[status]    COMPLETED
    Should Be Equal As Integers    ${json}[duration_min]    62
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM sessions WHERE id = ${dynamic_id_plus_one} AND status = 'COMPLETED'
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

TC-003_Verify_API_Returns_409_For_Already_Completed_Session
    [Documentation]    Verify API returns 409 when checking out an already COMPLETED session
    [Setup]    Setup_Test_Environment_For_TC_003
    
    # --- EXERCISE PHASE ---
    ${resp}=    POST On Session    api    /sessions/${dynamic_id}/checkout    json={}    expected_status=any
    
    # --- VERIFICATION PHASE ---
    Status Should Be    409    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session is already completed

TC-004_Verify_API_Returns_404_For_Unknown_Session
    [Documentation]    Verify API returns 404 when checking out an unknown session
    # --- EXERCISE PHASE ---
    ${non_existent_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${resp}=    POST On Session    api    /sessions/${non_existent_id}/checkout    json={}    expected_status=any
    
    # --- VERIFICATION PHASE ---
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Session not found

*** Keywords ***
Setup_Test_Environment
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${dynamic_id_plus_one}=    Evaluate    ${dynamic_id} + 1    modules=builtins
    
    # --- SETUP PHASE ---
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'OwnerA', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'DriverA', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id) VALUES (${dynamic_id}, 2.50, 'LotA', ${dynamic_id})
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '2 hours', NOW() + INTERVAL '1 hour')
    
    # --- ACTIVE SESSION ---
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '3570 seconds', ${dynamic_id}, 'ACTIVE')  # Adjusted to 3570 seconds for TC-001
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status) VALUES (${dynamic_id_plus_one}, NOW() - INTERVAL '3661 seconds', ${dynamic_id}, 'ACTIVE')  # Adjusted to 3661 seconds for TC-002
    
    Create Global API Session
    Set Suite Variable    ${dynamic_id}    ${dynamic_id}
    Set Suite Variable    ${dynamic_id_plus_one}    ${dynamic_id_plus_one}

Setup_Test_Environment_For_TC_003
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    
    # --- SETUP PHASE ---
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'OwnerA', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'DriverA', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, hourly_rate, name, owner_id) VALUES (${dynamic_id}, 2.50, 'LotA', ${dynamic_id})
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '2 hours', NOW() + INTERVAL '1 hour')
    
    # --- COMPLETED SESSION ---
    Execute Sql String    INSERT INTO sessions (id, checkin_at, reservation_id, status) VALUES (${dynamic_id}, NOW() - INTERVAL '3570 seconds', ${dynamic_id}, 'COMPLETED')  # Set session to COMPLETED
    
    Create Global API Session
    Set Suite Variable    ${dynamic_id}    ${dynamic_id}

Cleanup_Test_Environment
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
[Teardown]    Cleanup_Test_Environment    ${dynamic_id}