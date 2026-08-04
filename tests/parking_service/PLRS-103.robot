*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Library    Browser
Resource    ../../resources/projects/parking_service/config.robot

*** Keywords ***
Seed Owner
    [Arguments]    ${owner_id}
    Connect To Global Database
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${owner_id}, 'Owner A', 'owner_${owner_id}@test.com')

Seed Owner With Lot
    [Arguments]    ${owner_id}    ${lot_id}    ${lot_name}    ${lat}    ${lng}
    Seed Owner    ${owner_id}
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, lat, lng) VALUES (${lot_id}, ${owner_id}, '${lot_name}', 40, ${lat}, ${lng})

Cleanup Owner And Lot
    [Arguments]    ${owner_id}    ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE owner_id = ${owner_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${owner_id}
    Disconnect From Global Database

Cleanup Owner Only
    [Arguments]    ${owner_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE owner_id = ${owner_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${owner_id}
    Disconnect From Global Database

*** Test Cases ***
TC-001_Verify_GET_web_owner_renders_single_column_workflow_layout
    [Documentation]    Verify GET /web/owner renders the single-column workflow layout with Leaflet 1.9.4 and htmx forms
    Create Global API Session
    ${resp}=    GET On Session    api    /web/owner    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จัดการลาน + ช่องจอด
    Should Contain    ${body}    สมัครเจ้าของลาน
    Should Contain    ${body}    สร้างลานจอด
    Should Contain    ${body}    เพิ่มช่องจอด
    Should Contain    ${body}    แก้พิกัดลานเดิม
    Should Contain    ${body}    leaflet@1.9.4
    Should Contain    ${body}    hx-post="/web/owner/lots"
    Should Contain    ${body}    hx-target="#lot-result"
    Should Contain    ${body}    id="lot-result"
    Should Contain    ${body}    hx-post="/web/owner/coordinates"
    Should Contain    ${body}    hx-target="#coords-result"
    Should Contain    ${body}    id="coords-result"

TC-002_Verify_create_lot_map_initial_marker_at_Bangkok_center
    [Documentation]    Verify the create-lot map's initial marker is at Bangkok center with lat/lng inputs pre-filled
    Create Global API Session
    ${resp}=    GET On Session    api    /web/owner    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    value="13.756300"
    Should Contain    ${body}    value="100.501800"

TC-003_Verify_tapping_create_lot_map_updates_lat_lng_inputs
    [Documentation]    Verify tapping the create-lot map at (13.756331, 100.501762) updates the lat/lng inputs to 6 decimals
    New Browser    chromium    headless=${True}
    New Context    viewport={'width': 1280, 'height': 900}
    New Page       ${BASE_API_URL}/web/owner
    Wait For Elements State    id=create-lot-map    visible    timeout=10s
    Evaluate JavaScript    ${None}    () => { window.__plrsMaps.createMap.fire('click', {latlng: L.latLng(13.756331, 100.501762)}); return null; }
    ${lat}=    Get Property    id=create-lat    value
    ${lng}=    Get Property    id=create-lng    value
    Should Be Equal    ${lat}    13.756331
    Should Be Equal    ${lng}    100.501762
    [Teardown]    Close Browser

TC-004_Verify_dragging_create_lot_marker_updates_lat_lng_inputs
    [Documentation]    Verify dragging the create-lot marker to (13.750000, 100.500000) updates the lat/lng inputs to 6 decimals
    New Browser    chromium    headless=${True}
    New Context    viewport={'width': 1280, 'height': 900}
    New Page       ${BASE_API_URL}/web/owner
    Wait For Elements State    id=create-lot-map    visible    timeout=10s
    Evaluate JavaScript    ${None}    () => { const m = window.__plrsMaps.createMarker; m.setLatLng(L.latLng(13.750000, 100.500000)); m.fire('dragend'); return null; }
    ${lat}=    Get Property    id=create-lat    value
    ${lng}=    Get Property    id=create-lng    value
    Should Be Equal    ${lat}    13.750000
    Should Be Equal    ${lng}    100.500000
    [Teardown]    Close Browser

TC-005_Verify_typing_13_75_preserves_typed_value_and_moves_marker
    [Documentation]    Verify typing '13.75' into the create-lot lat input preserves the typed value
    New Browser    chromium    headless=${True}
    New Context    viewport={'width': 1280, 'height': 900}
    New Page       ${BASE_API_URL}/web/owner
    Wait For Elements State    id=create-lot-map    visible    timeout=10s
    Fill Text    id=create-lat    13.75
    Keyboard Key    press    Tab
    ${lat}=    Get Property    id=create-lat    value
    Should Be Equal    ${lat}    13.75
    [Teardown]    Close Browser

TC-006_Verify_typing_abc_does_not_move_marker_no_js_error
    [Documentation]    Verify typing 'abc' into the create-lot lat input does NOT move the marker and causes no JS error
    New Browser    chromium    headless=${True}
    New Context    viewport={'width': 1280, 'height': 900}
    New Page       ${BASE_API_URL}/web/owner
    Wait For Elements State    id=create-lot-map    visible    timeout=10s
    Fill Text    id=create-lat    abc
    Keyboard Key    press    Tab
    ${lat}=    Get Property    id=create-lat    value
    Should Be Equal    ${lat}    abc
    [Teardown]    Close Browser

TC-007_Verify_selecting_lot_with_coordinates_jumps_marker_and_inputs
    [Documentation]    Verify selecting a lot WITH coordinates in the edit-coordinates dropdown jumps the marker and inputs
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Seed Owner With Lot    ${dynamic_id}    ${lot_id}    Lot A    13.7563    100.5018
    New Browser    chromium    headless=${True}
    New Context    viewport={'width': 1280, 'height': 900}
    New Page       ${BASE_API_URL}/web/owner
    Wait For Elements State    id=edit-coords-map    visible    timeout=10s
    ${lot_id_str}=    Convert To String    ${lot_id}
    Select Options By    id=edit-lot-select    value    ${lot_id_str}
    ${lat}=    Get Property    id=edit-lat    value
    ${lng}=    Get Property    id=edit-lng    value
    Should Be Equal    ${lat}    13.756300
    Should Be Equal    ${lng}    100.501800
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-008_Verify_selecting_lot_without_coordinates_starts_at_Bangkok_center
    [Documentation]    Verify selecting a lot with NO coordinates in the edit-coordinates dropdown starts the marker at Bangkok center
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Seed Owner    ${dynamic_id}
    Connect To Global Database
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, lat, lng) VALUES (${lot_id}, ${dynamic_id}, 'Lot B', 40, NULL, NULL)
    New Browser    chromium    headless=${True}
    New Context    viewport={'width': 1280, 'height': 900}
    New Page       ${BASE_API_URL}/web/owner
    Wait For Elements State    id=edit-coords-map    visible    timeout=10s
    ${lot_id_str}=    Convert To String    ${lot_id}
    Select Options By    id=edit-lot-select    value    ${lot_id_str}
    ${lat}=    Get Property    id=edit-lat    value
    ${lng}=    Get Property    id=edit-lng    value
    Should Be Equal    ${lat}    13.756300
    Should Be Equal    ${lng}    100.501800
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-009_Verify_create_lot_form_submits_with_map_picked_coordinates
    [Documentation]    Verify the create-lot form submits with map-picked coordinates and creates the lot via POST /web/owner/lots
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner    ${dynamic_id}
    Create Global API Session
    ${form}=    Create Dictionary    name=Lot C    owner_id=${dynamic_id}    hourly_rate=40    wall_code=1234    lat=13.756331    lng=100.501762
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ถูกสร้างแล้ว
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id} AND name = 'Lot C' AND lat = 13.756331 AND lng = 100.501762
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-010_Verify_edit_coordinates_form_submits_and_updates_lot
    [Documentation]    Verify the edit-coordinates form submits with map-picked coordinates and updates the lot via POST /web/owner/coordinates
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Seed Owner With Lot    ${dynamic_id}    ${lot_id}    Lot D    13.7563    100.5018
    Create Global API Session
    ${form}=    Create Dictionary    lot_id=${lot_id}    lat=13.750000    lng=100.500000
    ${resp}=    POST On Session    api    /web/owner/coordinates    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    [SUCCESS] พิกัดลาน Lot D อัปเดตแล้ว: 13.75, 100.5
    ${count}=    Query    SELECT count(*) FROM lots WHERE id = ${lot_id} AND lat = 13.750000 AND lng = 100.500000
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}

TC-011_Verify_POST_lots_missing_name_returns_inline_error
    [Documentation]    Verify POST /web/owner/lots with missing name returns HTTP 200 with inline error 'Name is required'
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner    ${dynamic_id}
    Create Global API Session
    ${form}=    Create Dictionary    owner_id=${dynamic_id}    hourly_rate=40    wall_code=1234    lat=13.756331    lng=100.501762
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Name is required
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-012_Verify_POST_lots_missing_owner_id_returns_inline_error
    [Documentation]    Verify POST /web/owner/lots with missing owner_id returns HTTP 200 with inline error 'Owner ID is required'
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner    ${dynamic_id}
    Create Global API Session
    ${form}=    Create Dictionary    name=Lot E    hourly_rate=40    wall_code=1234    lat=13.756331    lng=100.501762
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Owner ID is required
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-013_Verify_POST_lots_invalid_wall_code_returns_inline_error
    [Documentation]    Verify POST /web/owner/lots with invalid wall_code returns HTTP 200 with inline error
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner    ${dynamic_id}
    Create Global API Session
    ${form}=    Create Dictionary    name=Lot F    owner_id=${dynamic_id}    hourly_rate=40    wall_code=12ab    lat=13.756331    lng=100.501762
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Wall code must be a 4-digit numeric value
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-014_Verify_POST_lots_out_of_range_lat_returns_inline_error
    [Documentation]    Verify POST /web/owner/lots with out-of-range lat returns HTTP 200 with inline error 'Invalid coordinates'
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner    ${dynamic_id}
    Create Global API Session
    ${form}=    Create Dictionary    name=Lot G    owner_id=${dynamic_id}    hourly_rate=40    wall_code=1234    lat=91.0    lng=100.501762
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Invalid coordinates
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Owner Only    ${dynamic_id}

TC-015_Verify_POST_coordinates_non_existent_lot_returns_inline_error
    [Documentation]    Verify POST /web/owner/coordinates with a non-existent lot_id returns HTTP 200 with inline error 'Lot not found'
    ${non_existent_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Create Global API Session
    ${form}=    Create Dictionary    lot_id=${non_existent_id}    lat=13.750000    lng=100.500000
    ${resp}=    POST On Session    api    /web/owner/coordinates    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Lot not found

TC-016_Verify_POST_coordinates_missing_lat_returns_inline_error
    [Documentation]    Verify POST /web/owner/coordinates with missing lat returns HTTP 200 with inline error 'Invalid coordinates'
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Seed Owner With Lot    ${dynamic_id}    ${lot_id}    Lot H    13.7563    100.5018
    Create Global API Session
    ${form}=    Create Dictionary    lot_id=${lot_id}    lng=100.500000
    ${resp}=    POST On Session    api    /web/owner/coordinates    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Invalid coordinates
    ${lat}=    Query    SELECT lat FROM lots WHERE id = ${lot_id}
    Should Be Equal As Numbers    ${lat[0][0]}    13.7563
    [Teardown]    Cleanup Owner And Lot    ${dynamic_id}    ${lot_id}