*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_lots_renders_map_list_toggle
    [Documentation]    Verify GET /web/lots renders the map/list tab toggle with Leaflet map and OSM attribution
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'Map Lot', ${dynamic_id}, 40, '1234', 13.7563, 100.5018, 100)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    แผนที่
    Should Contain    ${body}    รายการ
    Should Contain    ${body}    id="lots-map"
    Should Contain    ${body}    © OpenStreetMap contributors
    [Teardown]    Cleanup TC-001 Data    ${dynamic_id}

TC-002_Verify_GET_web_lots_map_tab_shows_marker_popup
    [Documentation]    Verify GET /web/lots map tab shows a marker popup with lot name, price, availability and booking link
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'Map Lot', ${dynamic_id}, 40, '1234', 13.7563, 100.5018, 100)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-1', true)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Map Lot
    Should Contain    ${body}    ฿40/ชม.
    Should Contain    ${body}    1/1
    Should Contain    ${body}    /web/bookings/new?lot_id=${dynamic_id + 1}
    [Teardown]    Cleanup TC-002 Data    ${dynamic_id}

TC-003_Verify_GET_web_lots_excludes_lot_without_coords_from_map
    [Documentation]    Verify GET /web/lots excludes a lot without lat/lng from the map but still renders it in the list tab
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'No Coord Lot', ${dynamic_id}, 40, '1234', NULL, NULL, 100)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    No Coord Lot
    Should Contain    ${body}    id="lots-map"
    Should Contain    ${body}    © OpenStreetMap contributors
    [Teardown]    Cleanup TC-003 Data    ${dynamic_id}

TC-004_Verify_GET_web_lots_map_renders_empty_when_no_coords
    [Documentation]    Verify GET /web/lots map still renders (empty) when no lot has lat/lng, and the list shows all lots
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'No Coord Lot', ${dynamic_id}, 40, '1234', NULL, NULL, 100)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    id="lots-map"
    Should Contain    ${body}    © OpenStreetMap contributors
    Should Contain    ${body}    No Coord Lot
    [Teardown]    Cleanup TC-003 Data    ${dynamic_id}

TC-005_Verify_GET_web_checkin_gps_renders_map
    [Documentation]    Verify GET /web/checkin/gps renders the small Leaflet map with geofence circle, user position and OSM attribution
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'GPS Lot', ${dynamic_id}, 40, '1234', 13.7563, 100.5018, 100)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 3, 'Driver A', 'driver_${dynamic_id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 4, ${dynamic_id} + 3, ${dynamic_id} + 2, ${dynamic_id} + 1, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '55 minutes', 'CONFIRMED', 40)
    Create Global API Session
    ${params}=    Create Dictionary    reservation_id=${dynamic_id + 4}
    ${resp}=    GET On Session    api    /web/checkin/gps    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    id="gps-map"
    Should Contain    ${body}    © OpenStreetMap contributors
    Should Contain    ${body}    hx-get="/web/checkin/gps/distance"
    Should Contain    ${body}    hx-target="#gps-status"
    Should Contain    ${body}    id="gps-status"
    [Teardown]    Cleanup TC-005 Data    ${dynamic_id}

TC-006_Verify_distance_returns_inside_true_at_exact_coords
    [Documentation]    Verify GET /web/checkin/gps/distance returns inside=true with distance 0 when user is at the lot's exact coordinates
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'GPS Lot', ${dynamic_id}, 40, '1234', 13.7563, 100.5018, 100)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 3, 'Driver A', 'driver_${dynamic_id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 4, ${dynamic_id} + 3, ${dynamic_id} + 2, ${dynamic_id} + 1, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '55 minutes', 'CONFIRMED', 40)
    Create Global API Session
    ${params}=    Create Dictionary    reservation_id=${dynamic_id + 4}    lat=13.7563    lng=100.5018
    ${resp}=    GET On Session    api    /web/checkin/gps/distance    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[distance_m]    0
    Should Be Equal As Strings    ${json}[inside]    True
    Should Be Equal As Integers    ${json}[geofence_radius_m]    100
    Should Be Equal As Strings    ${json}[lot_name]    GPS Lot
    Should Be Equal As Strings    ${json}[lot_lat]    13.7563
    Should Be Equal As Strings    ${json}[lot_lng]    100.5018
    [Teardown]    Cleanup TC-005 Data    ${dynamic_id}

TC-007_Verify_distance_returns_inside_true_within_geofence
    [Documentation]    Verify GET /web/checkin/gps/distance returns inside=true with distance 97 when user is 100m east of the lot
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'GPS Lot', ${dynamic_id}, 40, '1234', 13.7563, 100.5018, 100)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 3, 'Driver A', 'driver_${dynamic_id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 4, ${dynamic_id} + 3, ${dynamic_id} + 2, ${dynamic_id} + 1, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '55 minutes', 'CONFIRMED', 40)
    Create Global API Session
    ${params}=    Create Dictionary    reservation_id=${dynamic_id + 4}    lat=13.7563    lng=100.5027
    ${resp}=    GET On Session    api    /web/checkin/gps/distance    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[distance_m]    97
    Should Be Equal As Strings    ${json}[inside]    True
    Should Be Equal As Integers    ${json}[geofence_radius_m]    100
    Should Be Equal As Strings    ${json}[lot_name]    GPS Lot
    Should Be Equal As Strings    ${json}[lot_lat]    13.7563
    Should Be Equal As Strings    ${json}[lot_lng]    100.5018
    [Teardown]    Cleanup TC-005 Data    ${dynamic_id}

TC-008_Verify_distance_returns_inside_false_outside_geofence
    [Documentation]    Verify GET /web/checkin/gps/distance returns inside=false with distance 108 when user is 111m east of the lot
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'GPS Lot', ${dynamic_id}, 40, '1234', 13.7563, 100.5018, 100)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 3, 'Driver A', 'driver_${dynamic_id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 4, ${dynamic_id} + 3, ${dynamic_id} + 2, ${dynamic_id} + 1, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '55 minutes', 'CONFIRMED', 40)
    Create Global API Session
    ${params}=    Create Dictionary    reservation_id=${dynamic_id + 4}    lat=13.7563    lng=100.5028
    ${resp}=    GET On Session    api    /web/checkin/gps/distance    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[distance_m]    108
    Should Be Equal As Strings    ${json}[inside]    False
    Should Be Equal As Integers    ${json}[geofence_radius_m]    100
    Should Be Equal As Strings    ${json}[lot_name]    GPS Lot
    Should Be Equal As Strings    ${json}[lot_lat]    13.7563
    Should Be Equal As Strings    ${json}[lot_lng]    100.5018
    [Teardown]    Cleanup TC-005 Data    ${dynamic_id}

TC-009_Verify_distance_returns_inside_true_at_boundary
    [Documentation]    Verify GET /web/checkin/gps/distance returns inside=true when user is at the geofence boundary
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'GPS Lot', ${dynamic_id}, 40, '1234', 13.7563, 100.5018, 100)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 3, 'Driver A', 'driver_${dynamic_id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 4, ${dynamic_id} + 3, ${dynamic_id} + 2, ${dynamic_id} + 1, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '55 minutes', 'CONFIRMED', 40)
    Create Global API Session
    ${params}=    Create Dictionary    reservation_id=${dynamic_id + 4}    lat=13.7563    lng=100.5027
    ${resp}=    GET On Session    api    /web/checkin/gps/distance    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[distance_m]    97
    Should Be Equal As Strings    ${json}[inside]    True
    Should Be Equal As Integers    ${json}[geofence_radius_m]    100
    Should Be Equal As Strings    ${json}[lot_name]    GPS Lot
    Should Be Equal As Strings    ${json}[lot_lat]    13.7563
    Should Be Equal As Strings    ${json}[lot_lng]    100.5018
    [Teardown]    Cleanup TC-005 Data    ${dynamic_id}

TC-010_Verify_distance_returns_error_when_reservation_id_missing
    [Documentation]    Verify GET /web/checkin/gps/distance returns HTTP 200 with detail 'Reservation ID is required' when reservation_id is missing
    Create Global API Session
    ${params}=    Create Dictionary    lat=13.7563    lng=100.5018
    ${resp}=    GET On Session    api    /web/checkin/gps/distance    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Reservation ID is required

TC-011_Verify_distance_returns_error_when_lat_missing
    [Documentation]    Verify GET /web/checkin/gps/distance returns HTTP 200 with detail 'Latitude is required' when lat is missing
    Create Global API Session
    ${params}=    Create Dictionary    reservation_id=1    lng=100.5018
    ${resp}=    GET On Session    api    /web/checkin/gps/distance    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Latitude is required

TC-012_Verify_distance_returns_error_when_lng_missing
    [Documentation]    Verify GET /web/checkin/gps/distance returns HTTP 200 with detail 'Longitude is required' when lng is missing
    Create Global API Session
    ${params}=    Create Dictionary    reservation_id=1    lat=13.7563
    ${resp}=    GET On Session    api    /web/checkin/gps/distance    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Longitude is required

TC-013_Verify_distance_returns_error_when_reservation_not_found
    [Documentation]    Verify GET /web/checkin/gps/distance returns HTTP 200 with detail 'Reservation not found' when the reservation does not exist
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${params}=    Create Dictionary    reservation_id=${non_existent_id}    lat=13.7563    lng=100.5018
    ${resp}=    GET On Session    api    /web/checkin/gps/distance    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Reservation not found

TC-014_Verify_distance_returns_error_when_lot_has_no_coords
    [Documentation]    Verify GET /web/checkin/gps/distance returns HTTP 200 with detail 'This lot has no map location yet' when the reservation's lot has no lat/lng
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${dynamic_id}, 'Owner A', 'owner_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code, lat, lng, geofence_radius_m) VALUES (${dynamic_id} + 1, 'No Coord Lot', ${dynamic_id}, 40, '1234', NULL, NULL, 100)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 3, 'Driver A', 'driver_${dynamic_id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 4, ${dynamic_id} + 3, ${dynamic_id} + 2, ${dynamic_id} + 1, NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '55 minutes', 'CONFIRMED', 40)
    Create Global API Session
    ${params}=    Create Dictionary    reservation_id=${dynamic_id + 4}    lat=13.7563    lng=100.5018
    ${resp}=    GET On Session    api    /web/checkin/gps/distance    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    This lot has no map location yet
    [Teardown]    Cleanup TC-005 Data    ${dynamic_id}

*** Keywords ***
Cleanup TC-001 Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup TC-002 Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id} + 2
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup TC-003 Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup TC-005 Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id} + 4
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id} + 3
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id} + 2
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database