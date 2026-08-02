*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_checkin_gps_renders_page
    [Documentation]    Verify GET /web/checkin/gps renders the GPS check-in page with form, geolocation script, and htmx wiring
    Create Global API Session
    ${resp}=    GET On Session    api    /web/checkin/gps    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    เช็คอินด้วยตำแหน่ง
    Should Contain    ${body}    reservation_id
    Should Contain    ${body}    getLocation
    Should Contain    ${body}    hx-post="/web/checkin/gps"
    Should Contain    ${body}    hx-target="#checkin-result"
    Should Contain    ${body}    id="checkin-result"

TC-002_Verify_GPS_checkin_success_at_lot_center
    [Documentation]    Verify GPS check-in succeeds when driver is at the lot's exact center (distance 0)
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}=    Seed Checkin Fixture    13.7563    100.5018    100
    ${form}=    Create Dictionary    reservation_id=${reservation_id}    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ACTIVE
    Should Contain    ${body}    เช็คอินสำเร็จ
    ${result}=    Query    SELECT status FROM sessions WHERE reservation_id = ${reservation_id}
    Should Be Equal As Strings    ${result[0][0]}    ACTIVE
    [Teardown]    Cleanup Checkin Data    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}

TC-003_Verify_GPS_checkin_success_just_inside_geofence
    [Documentation]    Verify GPS check-in succeeds JUST INSIDE the geofence — 98.96 m against a 100 m radius
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}=    Seed Checkin Fixture    13.7563    100.5018    100
    ${form}=    Create Dictionary    reservation_id=${reservation_id}    lat=13.75719    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ACTIVE
    Should Contain    ${body}    เช็คอินสำเร็จ
    ${result}=    Query    SELECT status FROM sessions WHERE reservation_id = ${reservation_id}
    Should Be Equal As Strings    ${result[0][0]}    ACTIVE
    [Teardown]    Cleanup Checkin Data    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}

TC-004_Verify_GPS_checkin_refused_outside_geofence
    [Documentation]    Verify GPS check-in is refused when driver is just outside the geofence (distance > radius)
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}=    Seed Checkin Fixture    13.7563    100.5018    100
    ${form}=    Create Dictionary    reservation_id=${reservation_id}    lat=13.7663    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Not at the lot
    ${result}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${reservation_id}
    Should Be Equal As Integers    ${result[0][0]}    0
    [Teardown]    Cleanup Checkin Data    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}

TC-005_Verify_GPS_checkin_error_missing_reservation_id
    [Documentation]    Verify GPS check-in returns error when reservation_id is missing
    Create Global API Session
    ${form}=    Create Dictionary    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Reservation ID is required

TC-006_Verify_GPS_checkin_error_missing_lat
    [Documentation]    Verify GPS check-in returns error when lat is missing
    Create Global API Session
    ${form}=    Create Dictionary    reservation_id=1    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Latitude is required

TC-007_Verify_GPS_checkin_error_missing_lng
    [Documentation]    Verify GPS check-in returns error when lng is missing
    Create Global API Session
    ${form}=    Create Dictionary    reservation_id=1    lat=13.7563
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Longitude is required

TC-008_Verify_GPS_checkin_error_reservation_not_found
    [Documentation]    Verify GPS check-in returns error when reservation does not exist
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(99999999, 999999999)    modules=random
    ${form}=    Create Dictionary    reservation_id=${non_existent_id}    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Reservation not found

TC-009_Verify_GPS_checkin_refused_not_confirmed
    [Documentation]    Verify GPS check-in is refused when reservation status is not CONFIRMED
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}=    Seed Checkin Fixture With Status    SOFT_LOCKED
    ${form}=    Create Dictionary    reservation_id=${reservation_id}    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Reservation is not confirmed
    ${result}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${reservation_id}
    Should Be Equal As Integers    ${result[0][0]}    0
    [Teardown]    Cleanup Checkin Data    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}

TC-010_Verify_GPS_checkin_refused_too_early
    [Documentation]    Verify GPS check-in is refused when driver checks in more than 15 minutes early
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}=    Seed Checkin Fixture With Start Offset    20
    ${form}=    Create Dictionary    reservation_id=${reservation_id}    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Too early to check in
    ${result}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${reservation_id}
    Should Be Equal As Integers    ${result[0][0]}    0
    [Teardown]    Cleanup Checkin Data    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}

TC-011_Verify_GPS_checkin_refused_period_expired
    [Documentation]    Verify GPS check-in is refused when driver checks in more than 15 minutes after start_time
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}=    Seed Checkin Fixture With Start Offset    -20
    ${form}=    Create Dictionary    reservation_id=${reservation_id}    lat=13.7563    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Check-in period has expired
    ${result}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${reservation_id}
    Should Be Equal As Integers    ${result[0][0]}    0
    [Teardown]    Cleanup Checkin Data    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}

TC-012_Verify_GPS_checkin_success_negative_coordinates
    [Documentation]    Verify GPS check-in succeeds with negative lat/lng values (southern/western hemisphere) when inside geofence
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}=    Seed Checkin Fixture    -33.8688    -151.2093    100
    ${form}=    Create Dictionary    reservation_id=${reservation_id}    lat=-33.8688    lng=-151.2093
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ACTIVE
    Should Contain    ${body}    เช็คอินสำเร็จ
    ${result}=    Query    SELECT status FROM sessions WHERE reservation_id = ${reservation_id}
    Should Be Equal As Strings    ${result[0][0]}    ACTIVE
    [Teardown]    Cleanup Checkin Data    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}

TC-013_Verify_GPS_checkin_success_extreme_coordinates
    [Documentation]    Verify GPS check-in succeeds with extreme lat/lng values (lat=90, lng=180) when inside geofence
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}=    Seed Checkin Fixture    90    180    100
    ${form}=    Create Dictionary    reservation_id=${reservation_id}    lat=90    lng=180
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ACTIVE
    Should Contain    ${body}    เช็คอินสำเร็จ
    ${result}=    Query    SELECT status FROM sessions WHERE reservation_id = ${reservation_id}
    Should Be Equal As Strings    ${result[0][0]}    ACTIVE
    [Teardown]    Cleanup Checkin Data    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}

TC-014_Verify_GPS_checkin_refused_just_outside_geofence
    [Documentation]    Verify GPS check-in is refused JUST OUTSIDE the geofence — 105.64 m against a 100 m radius
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}=    Seed Checkin Fixture    13.7563    100.5018    100
    ${form}=    Create Dictionary    reservation_id=${reservation_id}    lat=13.75725    lng=100.5018
    ${resp}=    POST On Session    api    /web/checkin/gps    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Not at the lot
    ${result}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${reservation_id}
    Should Be Equal As Integers    ${result[0][0]}    0
    [Teardown]    Cleanup Checkin Data    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}

*** Keywords ***
Seed Checkin Fixture
    [Arguments]    ${lat}    ${lng}    ${radius}
    [Documentation]    Seed owner -> lot -> spot -> driver -> reservation with CONFIRMED status
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=      Evaluate    ${dynamic_id} + 2
    ${spot_id}=     Evaluate    ${dynamic_id} + 3
    ${driver_id}=   Evaluate    ${dynamic_id} + 4
    ${reservation_id}=    Evaluate    ${dynamic_id} + 5
    ${email}=    Set Variable    owner_${dynamic_id}@test.com
    ${driver_email}=    Set Variable    driver_${dynamic_id}@test.com
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${owner_id}, 'Owner A', '${email}')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${lot_id}, 'Lot A', ${owner_id}, 40, '1234', ${lat}, ${lng}, ${radius})
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver_id}, 'Driver A', '${driver_email}', 'KK1234')
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${reservation_id}, ${driver_id}, ${lot_id}, ${spot_id}, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '55 minutes', 'CONFIRMED')
    RETURN    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}

Seed Checkin Fixture With Status
    [Arguments]    ${status}
    [Documentation]    Seed fixture with a custom reservation status
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=      Evaluate    ${dynamic_id} + 2
    ${spot_id}=     Evaluate    ${dynamic_id} + 3
    ${driver_id}=   Evaluate    ${dynamic_id} + 4
    ${reservation_id}=    Evaluate    ${dynamic_id} + 5
    ${email}=    Set Variable    owner_${dynamic_id}@test.com
    ${driver_email}=    Set Variable    driver_${dynamic_id}@test.com
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${owner_id}, 'Owner A', '${email}')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${lot_id}, 'Lot A', ${owner_id}, 40, '1234', 13.7563, 100.5018, 100)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver_id}, 'Driver A', '${driver_email}', 'KK1234')
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${reservation_id}, ${driver_id}, ${lot_id}, ${spot_id}, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '55 minutes', '${status}')
    RETURN    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}

Seed Checkin Fixture With Start Offset
    [Arguments]    ${start_offset_minutes}
    [Documentation]    Seed fixture with a custom start_time offset from NOW
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=      Evaluate    ${dynamic_id} + 2
    ${spot_id}=     Evaluate    ${dynamic_id} + 3
    ${driver_id}=   Evaluate    ${dynamic_id} + 4
    ${reservation_id}=    Evaluate    ${dynamic_id} + 5
    ${end_offset_minutes}=    Evaluate    ${start_offset_minutes} + 60
    ${email}=    Set Variable    owner_${dynamic_id}@test.com
    ${driver_email}=    Set Variable    driver_${dynamic_id}@test.com
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${owner_id}, 'Owner A', '${email}')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${lot_id}, 'Lot A', ${owner_id}, 40, '1234', 13.7563, 100.5018, 100)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver_id}, 'Driver A', '${driver_email}', 'KK1234')
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${reservation_id}, ${driver_id}, ${lot_id}, ${spot_id}, NOW() + INTERVAL '${start_offset_minutes} minutes', NOW() + INTERVAL '${end_offset_minutes} minutes', 'CONFIRMED')
    RETURN    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}    ${reservation_id}

Cleanup Checkin Data
    [Arguments]    ${reservation_id}    ${spot_id}    ${lot_id}    ${driver_id}    ${owner_id}
    [Documentation]    Delete seeded rows children-first, then disconnect
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE reservation_id = ${reservation_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${reservation_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${owner_id}
    Run Keyword And Ignore Error    Disconnect From Global Database