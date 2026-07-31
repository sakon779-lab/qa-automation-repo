*** Settings ***
Documentation    PLRS-4 — Lot & Spot inventory: create lot (default/custom rate), wall_code validation,
...              add spots, get lot with spot_count, 404. Finalized by Claude after Artemis's attempts
...              (fixes: build the spots `codes` list with Create List, and capture the real lot id from
...              the create response instead of reusing the owner's <dynamic_id> as the lot id).
Library          RequestsLibrary
Library          Collections
Library          DatabaseLibrary
Resource         ../../resources/projects/parking_service/config.robot


*** Test Cases ***
TC-001_Create_Lot_Default_Rate
    [Documentation]    Creates a lot with default hourly_rate (40) and a valid wall_code -> 201
    ${owner_id}=    Seed Owner
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=Lot A    owner_id=${owner_id}    wall_code=1234
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[hourly_rate]    40
    Should Be Equal As Strings    ${json}[wall_code]    1234
    [Teardown]    Cleanup Owner    ${owner_id}

TC-002_Create_Lot_Custom_Rate
    [Documentation]    Creates a lot with a custom hourly_rate (50) and a valid wall_code -> 201
    ${owner_id}=    Seed Owner
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=Lot B    owner_id=${owner_id}    hourly_rate=${50}    wall_code=1234
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[hourly_rate]    50
    Should Be Equal As Strings    ${json}[wall_code]    1234
    [Teardown]    Cleanup Owner    ${owner_id}

TC-003_Reject_Wall_Code_Too_Short
    [Documentation]    wall_code shorter than 4 digits -> 422 flat detail
    ${owner_id}=    Seed Owner
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=Lot C    owner_id=${owner_id}    wall_code=12
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    422    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Wall code must be a 4-digit numeric value
    [Teardown]    Cleanup Owner    ${owner_id}

TC-004_Reject_Wall_Code_Too_Long
    [Documentation]    wall_code longer than 4 digits -> 422 flat detail
    ${owner_id}=    Seed Owner
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=Lot D    owner_id=${owner_id}    wall_code=12345
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    422    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Wall code must be a 4-digit numeric value
    [Teardown]    Cleanup Owner    ${owner_id}

TC-005_Reject_Wall_Code_Non_Numeric
    [Documentation]    wall_code with non-numeric characters -> 422 flat detail
    ${owner_id}=    Seed Owner
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=Lot E    owner_id=${owner_id}    wall_code=12a4
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    422    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Wall code must be a 4-digit numeric value
    [Teardown]    Cleanup Owner    ${owner_id}

TC-006_Create_Spots
    [Documentation]    Adds two spots to a lot -> 201 list; spot rows land in the DB
    ${owner_id}=    Seed Owner
    Create Session    api    ${BASE_API_URL}
    ${lot_payload}=    Create Dictionary    name=Lot F    owner_id=${owner_id}    wall_code=1234
    ${lot_resp}=    POST On Session    api    /lots    json=${lot_payload}    expected_status=any
    Status Should Be    201    ${lot_resp}
    ${lot_id}=    Set Variable    ${lot_resp.json()}[id]
    # build a REAL list for the array payload (a literal ['A-1','B-2'] would be sent as a string)
    ${codes}=    Create List    A-1    B-2
    ${spot_payload}=    Create Dictionary    codes=${codes}
    ${spot_resp}=    POST On Session    api    /lots/${lot_id}/spots    json=${spot_payload}    expected_status=any
    Status Should Be    201    ${spot_resp}
    ${spots}=    Set Variable    ${spot_resp.json()}
    Length Should Be    ${spots}    2
    ${count}=    Query    SELECT count(*) FROM spots WHERE lot_id = ${lot_id}
    Should Be Equal As Integers    ${count}[0][0]    2
    [Teardown]    Cleanup Owner    ${owner_id}

TC-007_Get_Lot_With_Spot_Count
    [Documentation]    GET a lot returns its details including the computed spot_count
    ${owner_id}=    Seed Owner
    Create Session    api    ${BASE_API_URL}
    ${lot_payload}=    Create Dictionary    name=Lot G    owner_id=${owner_id}    wall_code=1234
    ${lot_resp}=    POST On Session    api    /lots    json=${lot_payload}    expected_status=any
    Status Should Be    201    ${lot_resp}
    ${lot_id}=    Set Variable    ${lot_resp.json()}[id]
    ${codes}=    Create List    A-1    B-2
    ${spot_payload}=    Create Dictionary    codes=${codes}
    POST On Session    api    /lots/${lot_id}/spots    json=${spot_payload}    expected_status=any
    ${get_resp}=    GET On Session    api    /lots/${lot_id}    expected_status=any
    Status Should Be    200    ${get_resp}
    ${json}=    Set Variable    ${get_resp.json()}
    Should Be Equal As Integers    ${json}[spot_count]    2
    Should Be Equal As Strings    ${json}[wall_code]    1234
    [Teardown]    Cleanup Owner    ${owner_id}

TC-008_Get_Nonexistent_Lot
    [Documentation]    GET a lot id that does not exist -> 404 flat detail
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    /lots/99999999    expected_status=any
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot not found


*** Keywords ***
Seed Owner
    [Documentation]    Insert one owner with a unique id + email (owners.email is NOT NULL); keep the
    ...                DB connection open for the test; return the owner id.
    Connect To Global Database
    ${owner_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${owner_id}, 'Owner A', 'owner_${owner_id}@test.com')
    RETURN    ${owner_id}

Cleanup Owner
    [Documentation]    Remove everything the test created, CHILD-FIRST (spots -> lots -> owner), then
    ...                disconnect. Best-effort so teardown never fails a passing test.
    [Arguments]    ${owner_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE lot_id IN (SELECT id FROM lots WHERE owner_id = ${owner_id})
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE owner_id = ${owner_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${owner_id}
    Disconnect From Global Database
