*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_checkin_gps_renders_raw_number_input
    [Documentation]    Verify GET /web/checkin/gps renders the raw number input (regression guard) when SANDBOX_MODE=false, even with a CONFIRMED reservation in the DB
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate) VALUES (${dynamic_id}, ${dynamic_id}, 'ลานจอดสีลม', 50.00)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'สมชาย', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO spots (id, lot_id, code) VALUES (${dynamic_id}, ${dynamic_id}, 'SPOT_${dynamic_id}')
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '1 hour', NOW() + INTERVAL '2 hours', 'CONFIRMED')
    Create Global API Session

    # --- 2. EXERCISE PHASE ---
    ${resp}=    GET On Session    api    /web/checkin/gps    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    <input type="number" name="reservation_id"
    Should Contain    ${body}    Reservation ID

    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-002_Verify_GET_web_checkin_gps_keeps_GPS_flow_untouched
    [Documentation]    Verify GET /web/checkin/gps keeps the GPS flow untouched — GPS button, hidden lat/lng inputs, and gps-status paragraph are present
    # --- 1. SETUP PHASE ---
    Create Global API Session

    # --- 2. EXERCISE PHASE ---
    ${resp}=    GET On Session    api    /web/checkin/gps    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    id="checkin-submit"
    Should Contain    ${body}    onclick="getLocation()"
    Should Contain    ${body}    id="lat"
    Should Contain    ${body}    id="lng"
    Should Contain    ${body}    id="gps-status"

TC-003_Verify_GET_web_checkin_gps_form_submits_field_names
    [Documentation]    Verify GET /web/checkin/gps form still submits reservation_id, lat, lng field names to the same endpoint (backend contract unchanged)
    # --- 1. SETUP PHASE ---
    Create Global API Session

    # --- 2. EXERCISE PHASE ---
    ${resp}=    GET On Session    api    /web/checkin/gps    expected_status=any

    # --- 3. VERIFICATION PHASE ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="reservation_id"
    Should Contain    ${body}    name="lat"
    Should Contain    ${body}    name="lng"

*** Keywords ***
Cleanup Test Case Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database