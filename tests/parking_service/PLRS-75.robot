*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_POST_sandbox_reset_returns_403_and_touches_nothing
    [Documentation]    Verify POST /sandbox/reset on the QA stack answers 403 'Sandbox mode is not enabled'
    ...    and touches NOTHING - QA deliberately leaves SANDBOX_MODE unset, and this endpoint deletes
    ...    the entire database when the gate is open, so the 403 here is the permanent regression proof
    ...    that the gate defaults CLOSED

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Survivor Owner', 'survivor_${dynamic_id}@test.com', true)
    Create Global API Session

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /sandbox/reset    json=${empty}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    403    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Sandbox mode is not enabled
    # Post-Assertion: the seeded row SURVIVED - the reset did not run
    ${db_count_result}=    Query    SELECT count(*) FROM owners WHERE id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-002_Verify_second_call_is_refused_identically
    [Documentation]    Verify a second call is refused identically - the gate is stateless, there is no
    ...    'first request arms it' path, and data seeded between calls also survives

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Survivor Driver', 'survivor_${dynamic_id}@test.com')
    Create Global API Session

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${empty}=    Create Dictionary
    ${resp1}=    POST On Session    api    /sandbox/reset    json=${empty}    expected_status=any
    ${resp2}=    POST On Session    api    /sandbox/reset    json=${empty}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult & Post-Assertions) ---
    Status Should Be    403    ${resp1}
    ${json1}=    Set Variable    ${resp1.json()}
    Should Be Equal As Strings    ${json1}[detail]    Sandbox mode is not enabled
    Status Should Be    403    ${resp2}
    ${json2}=    Set Variable    ${resp2.json()}
    Should Be Equal As Strings    ${json2}[detail]    Sandbox mode is not enabled
    # Post-Assertion: the seeded row SURVIVED both calls
    ${db_count_result}=    Query    SELECT count(*) FROM drivers WHERE id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    1

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

*** Keywords ***
Cleanup Test Case Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database