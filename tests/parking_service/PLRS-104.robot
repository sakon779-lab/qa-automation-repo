*** Settings ***
Documentation    PLRS-104 - Vehicle selection in web booking flow
Library          RequestsLibrary
Library          Collections
Library          DatabaseLibrary
Resource         ../../resources/projects/parking_service/config.robot

*** Variables ***
${VEHICLE_1_ID}    11111111-1111-1111-1111-111111111111
${VEHICLE_2_ID}    22222222-2222-2222-2222-222222222222
${VEHICLE_3_ID}    33333333-3333-3333-3333-333333333333
${VEHICLE_4_ID}    44444444-4444-4444-4444-444444444444
${VEHICLE_5_ID}    99999999-9999-9999-9999-999999999999

*** Keywords ***
Seed Base Fixture
    [Documentation]    Seeds owner, lot, spot, user, and optionally vehicles. Returns the ids.
    [Arguments]    ${vehicle_count}=0
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    ${user_id}=    Evaluate    ${id} + 3
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner ${id}', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate) VALUES (${lot_id}, ${id}, 'Lot ${id}', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-1', true)
    Execute Sql String    INSERT INTO users (id, name, email, password_hash, phone, created_at) VALUES (${user_id}, 'Member ${id}', 'member_${id}@test.com', 'x', '0812345678', NOW())
    IF    ${vehicle_count} >= 1
        Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${VEHICLE_1_ID}', ${user_id}, 'กข1234', NOW())
    END
    IF    ${vehicle_count} >= 2
        Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${VEHICLE_2_ID}', ${user_id}, 'คง5678', NOW())
    END
    IF    ${vehicle_count} >= 3
        Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${VEHICLE_3_ID}', ${user_id}, 'งง9012', NOW())
    END
    RETURN    ${id}    ${lot_id}    ${spot_id}    ${user_id}

Signup And Get Session Cookie
    [Documentation]    POST /web/signup with form data, don't follow redirect, return the session cookie.
    [Arguments]    ${user_id}
    ${data}=    Create Dictionary    name=Member ${user_id}    email=member_${user_id}@test.com    password=Passw0rd!
    ${resp}=    POST On Session    api    /web/signup    data=${data}    expected_status=any    allow_redirects=${False}
    Status Should Be    303    ${resp}
    ${cookie}=    Create Dictionary    plrs_session=${resp.cookies}[plrs_session]
    RETURN    ${cookie}

Create Booking
    [Documentation]    POST /web/bookings with form data and optional session cookie.
    [Arguments]    ${lot_id}    ${start_at}    ${end_at}    ${cookie}=${EMPTY}    ${vehicle_id}=${EMPTY}    ${driver_id}=1
    ${form}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    IF    '${vehicle_id}' != '${EMPTY}'
        Set To Dictionary    ${form}    vehicle_id=${vehicle_id}
    END
    IF    '${cookie}' != '${EMPTY}'
        ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    ELSE
        ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any
    END
    RETURN    ${resp}

Cleanup Test Data
    [Documentation]    Deletes all rows seeded by this test, children first.
    [Arguments]    ${id}    ${user_id}=${EMPTY}    ${extra_spot_id}=${EMPTY}
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    IF    '${user_id}' == '${EMPTY}'
        ${user_id}=    Evaluate    ${id} + 3
    END
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id = ${user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = ${user_id}
    IF    '${extra_spot_id}' != '${EMPTY}'
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${extra_spot_id}
    END
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Data No User
    [Documentation]    Deletes rows for tests that don't seed a user (TC-004, TC-008).
    [Arguments]    ${id}    ${driver_id}=${EMPTY}
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    IF    '${driver_id}' != '${EMPTY}'
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = ${driver_id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${driver_id}
    END
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Data With Other User
    [Documentation]    Deletes rows for TC-009 which has an extra other user/owner.
    [Arguments]    ${id}
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    ${user_id}=    Evaluate    ${id} + 3
    ${other_owner_id}=    Evaluate    ${id} + 10
    ${other_user_id}=    Evaluate    ${id} + 11
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id = ${other_user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = ${other_user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${other_owner_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id = ${user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = ${user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Data Two Spots
    [Documentation]    Deletes rows for TC-012 which has two spots.
    [Arguments]    ${id}
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    ${spot2_id}=    Evaluate    ${id} + 4
    ${user_id}=    Evaluate    ${id} + 3
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id = ${user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = ${user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${spot_id}, ${spot2_id})
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

*** Test Cases ***
TC-001_Verify_GET_web_bookings_new_with_session_renders_select_with_member_vehicle_plate
    [Documentation]    Verify GET /web/bookings/new with a session renders a select with the member's vehicle plate
    Connect To Global Database
    Create Global API Session
    ${id}    ${lot_id}    ${spot_id}    ${user_id}=    Seed Base Fixture    1
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${resp}=    GET On Session    api    /web/bookings/new?lot_id=${lot_id}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="vehicle_id"
    Should Contain    ${body}    กข1234
    [Teardown]    Cleanup Test Data    ${id}

TC-002_Verify_GET_web_bookings_new_with_session_renders_one_option_per_vehicle
    [Documentation]    Verify GET /web/bookings/new with a session renders one option per vehicle (3 vehicles)
    Connect To Global Database
    Create Global API Session
    ${id}    ${lot_id}    ${spot_id}    ${user_id}=    Seed Base Fixture    3
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${resp}=    GET On Session    api    /web/bookings/new?lot_id=${lot_id}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="vehicle_id"
    Should Contain    ${body}    กข1234
    Should Contain    ${body}    คง5678
    Should Contain    ${body}    งง9012
    [Teardown]    Cleanup Test Data    ${id}

TC-003_Verify_GET_web_bookings_new_with_session_and_zero_vehicles_renders_empty_select_with_hint
    [Documentation]    Verify GET /web/bookings/new with a session and zero vehicles renders empty select with hint text and profile link
    Connect To Global Database
    Create Global API Session
    ${id}    ${lot_id}    ${spot_id}    ${user_id}=    Seed Base Fixture    0
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${resp}=    GET On Session    api    /web/bookings/new?lot_id=${lot_id}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="vehicle_id"
    Should Contain    ${body}    ยังไม่มีรถในโปรไฟล์ — เพิ่มรถได้ที่หน้าโปรไฟล์
    Should Contain    ${body}    href="/web/profile"
    [Teardown]    Cleanup Test Data    ${id}

TC-004_Verify_GET_web_bookings_new_with_NO_session_renders_page_without_vehicle_select
    [Documentation]    Verify GET /web/bookings/new with NO session renders the page without the vehicle select
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner ${id}', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate) VALUES (${lot_id}, ${id}, 'Lot ${id}', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-1', true)
    ${resp}=    GET On Session    api    /web/bookings/new?lot_id=${lot_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="driver_id"
    Should Contain    ${body}    Lot ${id}
    [Teardown]    Cleanup Test Data No User    ${id}

TC-005_Verify_POST_web_bookings_with_session_and_owned_vehicle_writes_plate_to_bridged_driver
    [Documentation]    Verify POST /web/bookings with a session and an owned vehicle writes the plate to the bridged driver and creates the booking
    Connect To Global Database
    Create Global API Session
    ${id}    ${lot_id}    ${spot_id}    ${user_id}=    Seed Base Fixture    1
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${resp}=    Create Booking    ${lot_id}    ${start_at}    ${end_at}    ${cookie}    ${VEHICLE_1_ID}
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal As Strings    ${result[0][0]}    กข1234
    [Teardown]    Cleanup Test Data    ${id}

TC-006_Verify_POST_web_bookings_with_session_and_3_vehicles_picking_2nd_writes_that_plate
    [Documentation]    Verify POST /web/bookings with a session and 3 vehicles, picking the 2nd, writes that vehicle's plate
    Connect To Global Database
    Create Global API Session
    ${id}    ${lot_id}    ${spot_id}    ${user_id}=    Seed Base Fixture    3
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${resp}=    Create Booking    ${lot_id}    ${start_at}    ${end_at}    ${cookie}    ${VEHICLE_2_ID}
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal As Strings    ${result[0][0]}    คง5678
    [Teardown]    Cleanup Test Data    ${id}
TC-007_Verify_POST_web_bookings_with_session_and_NO_vehicle_id_creates_booking_and_leaves_plate_NULL
    [Documentation]    Verify POST /web/bookings with a session and NO vehicle_id creates the booking and leaves drivers.plate NULL
    Connect To Global Database
    Create Global API Session
    ${id}    ${lot_id}    ${spot_id}    ${user_id}=    Seed Base Fixture    0
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${resp}=    Create Booking    ${lot_id}    ${start_at}    ${end_at}    ${cookie}
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Test Data    ${id}

TC-008_Verify_POST_web_bookings_with_NO_session_honours_submitted_driver_id_and_does_not_touch_plate
    [Documentation]    Verify POST /web/bookings with NO session honours the submitted driver_id and does not touch drivers.plate
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    ${driver_id}=    Evaluate    ${id} + 3
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner ${id}', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate) VALUES (${lot_id}, ${id}, 'Lot ${id}', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-1', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${driver_id}, 'Driver ${id}', 'driver_${id}@test.com')
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${resp}=    Create Booking    ${lot_id}    ${start_at}    ${end_at}    driver_id=${driver_id}
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Test Data No User    ${id}    ${driver_id}

TC-009_Verify_POST_web_bookings_with_session_and_vehicle_id_belonging_to_another_member_returns_Vehicle_not_found
    [Documentation]    Verify POST /web/bookings with a session and a vehicle_id belonging to another member returns 'Vehicle not found' and does NOT create the booking
    Connect To Global Database
    Create Global API Session
    ${id}    ${lot_id}    ${spot_id}    ${user_id}=    Seed Base Fixture    1
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${other_owner_id}=    Evaluate    ${id} + 10
    ${other_user_id}=    Evaluate    ${id} + 11
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${other_owner_id}, 'Other Owner', 'other_owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO users (id, name, email, password_hash, phone, created_at) VALUES (${other_user_id}, 'Other User', 'other_user_${id}@test.com', 'x', '0812345678', NOW())
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${VEHICLE_4_ID}', ${other_user_id}, 'จง9012', NOW())
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${resp}=    Create Booking    ${lot_id}    ${start_at}    ${end_at}    ${cookie}    ${VEHICLE_4_ID}
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Vehicle not found
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal As Integers    ${count[0][0]}    0
    ${result}=    Query    SELECT plate FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Test Data With Other User    ${id}

TC-010_Verify_POST_web_bookings_with_session_and_vehicle_id_not_a_uuid_returns_Vehicle_not_found
    [Documentation]    Verify POST /web/bookings with a session and vehicle_id='not-a-uuid' returns 'Vehicle not found' (not a 500) and does NOT create the booking
    Connect To Global Database
    Create Global API Session
    ${id}    ${lot_id}    ${spot_id}    ${user_id}=    Seed Base Fixture    1
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${resp}=    Create Booking    ${lot_id}    ${start_at}    ${end_at}    ${cookie}    not-a-uuid
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Vehicle not found
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal As Integers    ${count[0][0]}    0
    ${result}=    Query    SELECT plate FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Test Data    ${id}

TC-011_Verify_POST_web_bookings_with_session_and_well_formed_uuid_that_exists_in_no_row_returns_Vehicle_not_found
    [Documentation]    Verify POST /web/bookings with a session and a well-formed UUID that exists in no row returns 'Vehicle not found' and does NOT create the booking
    Connect To Global Database
    Create Global API Session
    ${id}    ${lot_id}    ${spot_id}    ${user_id}=    Seed Base Fixture    1
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${resp}=    Create Booking    ${lot_id}    ${start_at}    ${end_at}    ${cookie}    ${VEHICLE_5_ID}
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Vehicle not found
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal As Integers    ${count[0][0]}    0
    ${result}=    Query    SELECT plate FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Test Data    ${id}

TC-012_Verify_POST_web_bookings_twice_with_different_vehicles_leaves_second_vehicles_plate_on_bridged_driver
    [Documentation]    Verify POST /web/bookings twice with different vehicles leaves the second vehicle's plate on the bridged driver
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    ${spot2_id}=    Evaluate    ${id} + 4
    ${user_id}=    Evaluate    ${id} + 3
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner ${id}', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate) VALUES (${lot_id}, ${id}, 'Lot ${id}', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-1', true)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot2_id}, ${lot_id}, 'A-2', true)
    Execute Sql String    INSERT INTO users (id, name, email, password_hash, phone, created_at) VALUES (${user_id}, 'Member ${id}', 'member_${id}@test.com', 'x', '0812345678', NOW())
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${VEHICLE_1_ID}', ${user_id}, 'กข1234', NOW())
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${VEHICLE_2_ID}', ${user_id}, 'คง5678', NOW())
    ${cookie}=    Signup And Get Session Cookie    ${user_id}
    ${start_at_1}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at_1}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${resp1}=    Create Booking    ${lot_id}    ${start_at_1}    ${end_at_1}    ${cookie}    ${VEHICLE_1_ID}
    Status Should Be    200    ${resp1}
    ${body1}=    Set Variable    ${resp1.text}
    Should Contain    ${body1}    จองสำเร็จ
    Should Contain    ${body1}    ที่จอดถูกล็อกไว้
    ${start_at_2}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at_2}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=240)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${resp2}=    Create Booking    ${lot_id}    ${start_at_2}    ${end_at_2}    ${cookie}    ${VEHICLE_2_ID}
    Status Should Be    200    ${resp2}
    ${body2}=    Set Variable    ${resp2.text}
    Should Contain    ${body2}    จองสำเร็จ
    Should Contain    ${body2}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE id = (SELECT driver_id FROM users WHERE id = ${user_id})
    Should Be Equal As Strings    ${result[0][0]}    คง5678
    [Teardown]    Cleanup Test Data Two Spots    ${id}