*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Keywords ***
Seed Owner And Lot
    [Arguments]    ${owner_id}    ${lot_id}    ${wall_code}
    [Documentation]    Seed an owner and a lot with the given wall_code (NULL, '1234', or '').
    ...                Returns nothing; the caller owns the ids.
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Owner ${owner_id}', 'owner_${owner_id}@test.com', true)
    IF    "${wall_code}" == "NULL"
        Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'Lot Null Wall ${owner_id}', ${owner_id}, 40, NULL, NULL, NULL)
    ELSE
        Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'Lot Wall Code ${owner_id}', ${owner_id}, 40, '${wall_code}', NULL, NULL)
    END

Cleanup Owner And Lot
    [Arguments]    ${owner_id}    ${lot_id}
    [Documentation]    Delete the lot and owner seeded by this test (children first).
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${owner_id}
    Disconnect From Global Database

*** Test Cases ***
TC-001_Verify_POST_coordinates_returns_200_with_wall_code_null_for_NULL_wall_code
    [Documentation]    The bug fix: a lot whose wall_code is NULL must return wall_code: null (not crash).
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Seed Owner And Lot    ${dynamic_id}    ${lot_id}    NULL
    Create Global API Session
    ${payload}=    Create Dictionary    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /lots/${lot_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal    ${json}[wall_code]    ${None}
    Should Be Equal As Numbers    ${json}[lat]    13.7563
    Should Be Equal As Numbers    ${json}[lng]    100.5018
    ${db_result}=    Query    SELECT lat, lng FROM lots WHERE id = ${lot_id}
    Should Be Equal As Numbers    ${db_result[0][0]}    13.7563
    Should Be Equal As Numbers    ${db_result[0][1]}    100.5018
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-002_Verify_POST_coordinates_returns_200_with_wall_code_1234_for_lot_with_wall_code
    [Documentation]    Regression: a lot with a wall_code must still return it unchanged.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    Seed Owner And Lot    ${dynamic_id}    ${lot_id}    1234
    Create Global API Session
    ${payload}=    Create Dictionary    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /lots/${lot_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[wall_code]    1234
    Should Be Equal As Numbers    ${json}[lat]    13.7563
    Should Be Equal As Numbers    ${json}[lng]    100.5018
    ${db_result}=    Query    SELECT lat, lng FROM lots WHERE id = ${lot_id}
    Should Be Equal As Numbers    ${db_result[0][0]}    13.7563
    Should Be Equal As Numbers    ${db_result[0][1]}    100.5018
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-003_Verify_POST_web_owner_coordinates_returns_200_with_success_fragment_for_NULL_wall_code
    [Documentation]    The web route must also handle NULL wall_code and render the success fragment.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Seed Owner And Lot    ${dynamic_id}    ${lot_id}    NULL
    Create Global API Session
    ${form}=    Create Dictionary    lot_id=${lot_id}    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /web/owner/coordinates    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    [SUCCESS] พิกัดลาน Lot Null Wall ${dynamic_id} อัปเดตแล้ว: 13.7563, 100.5018
    ${db_result}=    Query    SELECT lat, lng FROM lots WHERE id = ${lot_id}
    Should Be Equal As Numbers    ${db_result[0][0]}    13.7563
    Should Be Equal As Numbers    ${db_result[0][1]}    100.5018
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-004_Verify_GET_lots_returns_200_with_wall_code_null_for_NULL_wall_code
    [Documentation]    The LotResponse fix applies to GET too — wall_code must be null, not missing/crash.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Seed Owner And Lot    ${dynamic_id}    ${lot_id}    NULL
    Create Global API Session
    ${resp}=    GET On Session    api    /lots/${lot_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal    ${json}[wall_code]    ${None}
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-005_Verify_POST_coordinates_returns_200_with_wall_code_empty_for_empty_string_wall_code
    [Documentation]    Empty-string wall_code was already valid — only NULL was broken. Must still work.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 3
    Seed Owner And Lot    ${dynamic_id}    ${lot_id}    ${EMPTY}
    Create Global API Session
    ${payload}=    Create Dictionary    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /lots/${lot_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[wall_code]    ${EMPTY}
    Should Be Equal As Numbers    ${json}[lat]    13.7563
    Should Be Equal As Numbers    ${json}[lng]    100.5018
    ${db_result}=    Query    SELECT lat, lng FROM lots WHERE id = ${lot_id}
    Should Be Equal As Numbers    ${db_result[0][0]}    13.7563
    Should Be Equal As Numbers    ${db_result[0][1]}    100.5018
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-006_Verify_POST_coordinates_returns_404_when_lot_does_not_exist
    [Documentation]    A non-existent lot id must yield 404 with the flat error detail.
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${payload}=    Create Dictionary    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /lots/${non_existent_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot not found

TC-007_Verify_POST_coordinates_returns_400_when_lat_is_missing
    [Documentation]    Missing lat must yield 400 with the flat error detail.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Seed Owner And Lot    ${dynamic_id}    ${lot_id}    NULL
    Create Global API Session
    ${payload}=    Create Dictionary    lng=100.5018
    ${resp}=    POST On Session    api    /lots/${lot_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-008_Verify_POST_coordinates_returns_400_when_lat_out_of_range
    [Documentation]    lat=91.0 is outside [-90, 90] — must yield 400 with the flat error detail.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Seed Owner And Lot    ${dynamic_id}    ${lot_id}    NULL
    Create Global API Session
    ${payload}=    Create Dictionary    lat=91.0    lng=100.5018
    ${resp}=    POST On Session    api    /lots/${lot_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-009_Verify_POST_web_owner_coordinates_returns_200_with_inline_Lot_not_found
    [Documentation]    The web route renders errors inline as HTTP 200 — never a 404.
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${form}=    Create Dictionary    lot_id=${non_existent_id}    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /web/owner/coordinates    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Lot not found