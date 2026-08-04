*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Keywords ***
Seed Owner
    [Arguments]    ${id}
    ${email}=    Set Variable    owner_${id}@test.com
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner ${id}', '${email}', true)
    RETURN    ${email}

Cleanup Lot And Owner
    [Arguments]    ${id}
    ${lot_id}=    Evaluate    ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE owner_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Disconnect From Global Database

Cleanup Owner Only
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE owner_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Disconnect From Global Database

*** Test Cases ***
TC-001_Verify_POST_lots_accepts_valid_lat_lng_and_creates_lot_with_coordinates
    [Documentation]    Verify POST /lots accepts valid lat/lng and creates lot with coordinates (201 Created)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Siam Square Lot    owner_id=${dynamic_id}    hourly_rate=50    wall_code=1234    lat=13.7456    lng=100.5342
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[name]    Siam Square Lot
    Should Be Equal As Strings    ${json}[owner_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[hourly_rate]    50
    Should Be Equal As Strings    ${json}[wall_code]    1234
    Should Be Equal As Strings    ${json}[spot_count]    0
    Should Be Equal As Strings    ${json}[lat]    13.7456
    Should Be Equal As Strings    ${json}[lng]    100.5342
    ${count}=    Query    SELECT count(*) FROM lots WHERE name = 'Siam Square Lot' AND owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-002_Verify_POST_lots_without_lat_lng_creates_lot_with_null_coordinates
    [Documentation]    Verify POST /lots without lat/lng creates lot with null coordinates (additive regression — PLRS-4 behaviour unchanged)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Old Lot No Coords    owner_id=${dynamic_id}    hourly_rate=40    wall_code=5678
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[name]    Old Lot No Coords
    Should Be Equal As Strings    ${json}[owner_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[hourly_rate]    40
    Should Be Equal As Strings    ${json}[wall_code]    5678
    Should Be Equal As Strings    ${json}[spot_count]    0
    Should Be Equal    ${json}[lat]    ${None}
    Should Be Equal    ${json}[lng]    ${None}
    ${result}=    Query    SELECT lat FROM lots WHERE name = 'Old Lot No Coords' AND owner_id = ${dynamic_id}
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-003_Verify_POST_lots_accepts_boundary_values_lat_90_lng_180
    [Documentation]    Verify POST /lots accepts boundary values lat=90, lng=180 (inclusive upper bounds) with 201 Created
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Boundary Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=9999    lat=90    lng=180
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[name]    Boundary Lot
    Should Be Equal As Strings    ${json}[owner_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[hourly_rate]    40
    Should Be Equal As Strings    ${json}[wall_code]    9999
    Should Be Equal As Strings    ${json}[spot_count]    0
    Should Be Equal As Numbers    ${json}[lat]    90
    Should Be Equal As Numbers    ${json}[lng]    180
    ${result}=    Query    SELECT lat, lng FROM lots WHERE name = 'Boundary Lot' AND owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${result[0][0]}    90
    Should Be Equal As Integers    ${result[0][1]}    180
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-004_Verify_POST_lots_accepts_boundary_value_lng_minus_180
    [Documentation]    Verify POST /lots accepts boundary value lng=-180 (inclusive lower bound) with 201 Created
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Lower Bound Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=8888    lat=0    lng=-180
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[name]    Lower Bound Lot
    Should Be Equal As Strings    ${json}[owner_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[hourly_rate]    40
    Should Be Equal As Strings    ${json}[wall_code]    8888
    Should Be Equal As Strings    ${json}[spot_count]    0
    Should Be Equal As Numbers    ${json}[lat]    0
    Should Be Equal As Numbers    ${json}[lng]    -180
    ${result}=    Query    SELECT lat, lng FROM lots WHERE name = 'Lower Bound Lot' AND owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${result[0][0]}    0
    Should Be Equal As Integers    ${result[0][1]}    -180
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-005_Verify_POST_lots_returns_400_when_lat_91_exceeds_upper_bound
    [Documentation]    Verify POST /lots returns 400 Invalid coordinates when lat=91 exceeds upper bound
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Bad Lat Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=1111    lat=91    lng=100
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-006_Verify_POST_lots_returns_400_when_lat_90_000001_just_above_upper_bound
    [Documentation]    Verify POST /lots returns 400 Invalid coordinates when lat=90.000001 is just above upper bound
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Over Bound Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=2222    lat=90.000001    lng=100
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-007_Verify_POST_lots_returns_400_when_lng_minus_181_below_lower_bound
    [Documentation]    Verify POST /lots returns 400 Invalid coordinates when lng=-181 is below lower bound
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Bad Lng Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=3333    lat=0    lng=-181
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-008_Verify_POST_lots_returns_400_when_lat_present_but_lng_missing
    [Documentation]    Verify POST /lots returns 400 Invalid coordinates when lat is present but lng is missing
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Missing Lng Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=4444    lat=13.7
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}
TC-009_Verify_POST_lots_returns_400_when_lng_present_but_lat_missing
    [Documentation]    Verify POST /lots returns 400 Invalid coordinates when lng is present but lat is missing
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Missing Lat Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=5555    lng=100.5
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-010_Verify_POST_lots_returns_400_when_lat_not_parseable_as_float
    [Documentation]    Verify POST /lots returns 400 Invalid coordinates when lat is not parseable as a float ('abc')
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Parse Fail Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=6666    lat=abc    lng=100
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-011_Verify_POST_lots_treats_empty_string_lat_lng_as_absent
    [Documentation]    Verify POST /lots treats empty-string lat/lng as absent (null) and creates lot with 201 Created
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Empty Coords Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=7777    lat=${EMPTY}    lng=${EMPTY}
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[name]    Empty Coords Lot
    Should Be Equal As Strings    ${json}[owner_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[hourly_rate]    40
    Should Be Equal As Strings    ${json}[wall_code]    7777
    Should Be Equal As Strings    ${json}[spot_count]    0
    Should Be Equal    ${json}[lat]    ${None}
    Should Be Equal    ${json}[lng]    ${None}
    ${result}=    Query    SELECT lat FROM lots WHERE name = 'Empty Coords Lot' AND owner_id = ${dynamic_id}
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-012_Verify_POST_lots_returns_400_when_name_missing
    [Documentation]    Verify POST /lots returns 400 Name is required when name is missing (PLRS-4 regression)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    owner_id=${dynamic_id}    hourly_rate=40    wall_code=1234
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Name is required
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-013_Verify_POST_lots_returns_400_when_owner_id_missing
    [Documentation]    Verify POST /lots returns 400 Owner ID is required when owner_id is missing (PLRS-4 regression)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=No Owner Lot    hourly_rate=40    wall_code=1234
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Owner ID is required
    ${count}=    Query    SELECT count(*) FROM lots WHERE name = 'No Owner Lot'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-014_Verify_POST_lots_returns_422_when_wall_code_invalid
    [Documentation]    Verify POST /lots returns 422 Wall code must be a 4-digit numeric value when wall_code is invalid (PLRS-4 regression)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${payload}=    Create Dictionary    name=Bad Wall Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=12ab
    ${resp}=    POST On Session    api    /lots    json=${payload}    expected_status=any
    Status Should Be    422    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Wall code must be a 4-digit numeric value
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-015_Verify_POST_lots_id_coordinates_sets_coordinates_on_lot_with_none
    [Documentation]    Verify POST /lots/{id}/coordinates sets coordinates on a lot that has none (200 OK)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'No Coords Lot', ${dynamic_id}, 40, '1234', NULL, NULL)
    ${payload}=    Create Dictionary    lat=13.7    lng=100.5
    ${resp}=    POST On Session    api    /lots/${lot_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[id]    ${lot_id}
    Should Be Equal As Strings    ${json}[name]    No Coords Lot
    Should Be Equal As Strings    ${json}[owner_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[hourly_rate]    40
    Should Be Equal As Strings    ${json}[wall_code]    1234
    Should Be Equal As Strings    ${json}[spot_count]    0
    Should Be Equal As Strings    ${json}[lat]    13.7
    Should Be Equal As Strings    ${json}[lng]    100.5
    ${result}=    Query    SELECT lat, lng FROM lots WHERE id = ${lot_id}
    Should Be Equal As Strings    ${result[0][0]}    13.7
    Should Be Equal As Strings    ${result[0][1]}    100.5
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-016_Verify_POST_lots_id_coordinates_overwrites_existing_coordinates
    [Documentation]    Verify POST /lots/{id}/coordinates overwrites existing coordinates on a lot (200 OK)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'Has Coords Lot', ${dynamic_id}, 40, '1234', 10.0, 20.0)
    ${payload}=    Create Dictionary    lat=13.7    lng=100.5
    ${resp}=    POST On Session    api    /lots/${lot_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[id]    ${lot_id}
    Should Be Equal As Strings    ${json}[name]    Has Coords Lot
    Should Be Equal As Strings    ${json}[owner_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[hourly_rate]    40
    Should Be Equal As Strings    ${json}[wall_code]    1234
    Should Be Equal As Strings    ${json}[spot_count]    0
    Should Be Equal As Strings    ${json}[lat]    13.7
    Should Be Equal As Strings    ${json}[lng]    100.5
    ${result}=    Query    SELECT lat, lng FROM lots WHERE id = ${lot_id}
    Should Be Equal As Strings    ${result[0][0]}    13.7
    Should Be Equal As Strings    ${result[0][1]}    100.5
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}
TC-017_Verify_POST_lots_id_coordinates_returns_400_when_lng_missing
    [Documentation]    Verify POST /lots/{id}/coordinates returns 400 Invalid coordinates when lng is missing
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'No Coords Lot', ${dynamic_id}, 40, '1234', NULL, NULL)
    ${payload}=    Create Dictionary    lat=13.7
    ${resp}=    POST On Session    api    /lots/${lot_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    ${result}=    Query    SELECT lat FROM lots WHERE id = ${lot_id}
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-018_Verify_POST_lots_id_coordinates_returns_400_when_lat_empty_string
    [Documentation]    Verify POST /lots/{id}/coordinates returns 400 Invalid coordinates when lat is empty string
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'No Coords Lot', ${dynamic_id}, 40, '1234', NULL, NULL)
    ${payload}=    Create Dictionary    lat=${EMPTY}    lng=100.5
    ${resp}=    POST On Session    api    /lots/${lot_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid coordinates
    ${result}=    Query    SELECT lat FROM lots WHERE id = ${lot_id}
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-019_Verify_POST_lots_id_coordinates_returns_404_for_non_existent_lot
    [Documentation]    Verify POST /lots/{id}/coordinates returns 404 Lot not found for non-existent lot id
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${payload}=    Create Dictionary    lat=13.7    lng=100.5
    ${resp}=    POST On Session    api    /lots/${non_existent_id}/coordinates    json=${payload}    expected_status=any
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot not found

TC-020_Verify_GET_web_owner_renders_create_lot_form_with_lat_lng_inputs
    [Documentation]    Verify GET /web/owner page renders create-lot form with lat/lng inputs, Google Maps link, and edit-coordinates section with htmx wiring
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'Listed Lot', ${dynamic_id}, 40, '1234', NULL, NULL)
    ${resp}=    GET On Session    api    /web/owner    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    แก้พิกัดลานเดิม
    Should Contain    ${body}    hx-post="/web/owner/lots"
    Should Contain    ${body}    hx-target="#lot-result"
    Should Contain    ${body}    id="lot-result"
    Should Contain    ${body}    hx-target="#coords-result"
    Should Contain    ${body}    id="coords-result"
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-021_Verify_POST_web_owner_lots_id_coordinates_with_valid_coords_returns_success
    [Documentation]    Verify POST /web/owner/lots/{id}/coordinates with valid coords returns success HTML fragment and updates lot
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'Edit Lot', ${dynamic_id}, 40, '1234', NULL, NULL)
    ${form}=    Create Dictionary    lat=13.7    lng=100.5
    ${resp}=    POST On Session    api    /web/owner/lots/${lot_id}/coordinates    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    [SUCCESS] พิกัดลาน Edit Lot อัปเดตแล้ว: 13.7, 100.5
    ${result}=    Query    SELECT lat, lng FROM lots WHERE id = ${lot_id}
    Should Be Equal As Strings    ${result[0][0]}    13.7
    Should Be Equal As Strings    ${result[0][1]}    100.5
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-022_Verify_POST_web_owner_lots_id_coordinates_with_invalid_coords_returns_error
    [Documentation]    Verify POST /web/owner/lots/{id}/coordinates with invalid coords returns inline error fragment (HTTP 200) and does not update lot
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'Edit Lot', ${dynamic_id}, 40, '1234', NULL, NULL)
    ${form}=    Create Dictionary    lat=91    lng=100
    ${resp}=    POST On Session    api    /web/owner/lots/${lot_id}/coordinates    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Invalid coordinates
    ${result}=    Query    SELECT lat FROM lots WHERE id = ${lot_id}
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-023_Verify_GET_web_lots_shows_navigate_button_with_google_maps_url
    [Documentation]    Verify GET /web/lots shows navigate button with exact Google Maps URL for a lot with coordinates
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'Nav Lot', ${dynamic_id}, 40, '1234', 13.7456, 100.5342)
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    https://www.google.com/maps/dir/?api=1&destination=13.7456,100.5342
    Should Contain    ${body}    target="_blank"
    Should Contain    ${body}    rel="noopener"
    Should Contain    ${body}    นำทาง
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}

TC-024_Verify_GET_web_lots_list_tab_shows_all_lots_including_without_coordinates
    [Documentation]    Verify GET /web/lots list tab shows all lots including a lot without coordinates (PLRS-82 regression guard)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Seed Owner    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng) VALUES (${lot_id}, 'List Only Lot', ${dynamic_id}, 40, '1234', NULL, NULL)
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    List Only Lot
    Should Contain    ${body}    รายการ
    [Teardown]    Cleanup Lot And Owner    ${dynamic_id}
