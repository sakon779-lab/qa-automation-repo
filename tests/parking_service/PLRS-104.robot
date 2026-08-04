*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Keywords ***
Seed Owner Lot Spot
    [Arguments]    ${dynamic_id}
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate) VALUES (${dynamic_id} + 1, ${dynamic_id}, 'Lot ${dynamic_id}', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-1', true)

Signup And Get Session Cookie
    [Arguments]    ${dynamic_id}
    ${form}=    Create Dictionary    name=Member ${dynamic_id}    email=member_${dynamic_id}@test.com    password=Passw0rd!    phone=0812345678
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    ${cookie}=    Create Dictionary    plrs_session=${resp.cookies}[plrs_session]
    RETURN    ${cookie}

Seed Vehicles For User
    [Arguments]    ${dynamic_id}    ${vehicle_count}
    Run Keyword If    ${vehicle_count} >= 1    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('11111111-1111-1111-1111-111111111111', (SELECT id FROM users WHERE email = 'member_${dynamic_id}@test.com'), 'กข1234', NOW())
    Run Keyword If    ${vehicle_count} >= 2    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('22222222-2222-2222-2222-222222222222', (SELECT id FROM users WHERE email = 'member_${dynamic_id}@test.com'), 'คง5678', NOW())
    Run Keyword If    ${vehicle_count} >= 3    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('33333333-3333-3333-3333-333333333333', (SELECT id FROM users WHERE email = 'member_${dynamic_id}@test.com'), 'งง9012', NOW())

Cleanup Member Booking Data
    [Arguments]    ${dynamic_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id IN (SELECT driver_id FROM users WHERE email = 'member_${dynamic_id}@test.com')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id IN (SELECT id FROM users WHERE email = 'member_${dynamic_id}@test.com')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE email = 'member_${dynamic_id}@test.com'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE email = 'member_${dynamic_id}@test.com'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${dynamic_id} + 2
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${dynamic_id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${dynamic_id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Owner Lot Spot Data
    [Arguments]    ${dynamic_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${dynamic_id} + 2
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${dynamic_id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${dynamic_id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup NoMember Booking Data
    [Arguments]    ${dynamic_id}    ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${dynamic_id} + 2
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${dynamic_id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${dynamic_id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Member Booking Data With Other
    [Arguments]    ${dynamic_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id IN (SELECT driver_id FROM users WHERE email = 'member_${dynamic_id}@test.com')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id IN (SELECT id FROM users WHERE email = 'member_${dynamic_id}@test.com')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE email = 'member_${dynamic_id}@test.com'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE email = 'member_${dynamic_id}@test.com'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id IN (SELECT id FROM users WHERE email = 'other_user_${dynamic_id}@test.com')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE email = 'other_user_${dynamic_id}@test.com'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE email = 'other_driver_${dynamic_id}@test.com'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${dynamic_id} + 10
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${dynamic_id} + 2
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${dynamic_id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${dynamic_id}
    Run Keyword And Ignore Error    Disconnect From Global Database

*** Test Cases ***
TC-001_Verify_GET_web_bookings_new_with_session_renders_select_with_member_vehicle_plate
    [Documentation]    Verify GET /web/bookings/new with a session renders a select with the member's vehicle plate
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    Seed Vehicles For User    ${dynamic_id}    1
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${params}=    Create Dictionary    lot_id=${lot_id}
    ${resp}=    GET On Session    api    /web/bookings/new    params=${params}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="vehicle_id"
    Should Contain    ${body}    กข1234
    [Teardown]    Cleanup Member Booking Data    ${dynamic_id}

TC-002_Verify_GET_web_bookings_new_with_session_renders_one_option_per_vehicle
    [Documentation]    Verify GET /web/bookings/new with a session renders one option per vehicle (3 vehicles)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    Seed Vehicles For User    ${dynamic_id}    3
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${params}=    Create Dictionary    lot_id=${lot_id}
    ${resp}=    GET On Session    api    /web/bookings/new    params=${params}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="vehicle_id"
    Should Contain    ${body}    กข1234
    Should Contain    ${body}    คง5678
    Should Contain    ${body}    งง9012
    [Teardown]    Cleanup Member Booking Data    ${dynamic_id}

TC-003_Verify_GET_web_bookings_new_with_session_and_zero_vehicles_renders_empty_select_with_hint
    [Documentation]    Verify GET /web/bookings/new with a session and zero vehicles renders empty select with hint text and profile link
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${params}=    Create Dictionary    lot_id=${lot_id}
    ${resp}=    GET On Session    api    /web/bookings/new    params=${params}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="vehicle_id"
    Should Contain    ${body}    ยังไม่มีรถในโปรไฟล์ — เพิ่มรถได้ที่หน้าโปรไฟล์
    Should Contain    ${body}    href="/web/profile"
    [Teardown]    Cleanup Member Booking Data    ${dynamic_id}

TC-004_Verify_GET_web_bookings_new_with_NO_session_renders_page_without_vehicle_select
    [Documentation]    Verify GET /web/bookings/new with NO session renders the page without the vehicle select
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${params}=    Create Dictionary    lot_id=${lot_id}
    ${resp}=    GET On Session    api    /web/bookings/new    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="driver_id"
    Should Contain    ${body}    Lot ${dynamic_id}
    [Teardown]    Cleanup Owner Lot Spot Data    ${dynamic_id}
TC-005_Verify_POST_web_bookings_with_session_and_owned_vehicle_writes_plate_to_bridged_driver
    [Documentation]    Verify POST /web/bookings with a session and an owned vehicle writes the plate to the bridged driver and creates the booking
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    Seed Vehicles For User    ${dynamic_id}    1
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${start_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=11111111-1111-1111-1111-111111111111
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE email = 'member_${dynamic_id}@test.com'
    Should Be Equal As Strings    ${result[0][0]}    กข1234
    [Teardown]    Cleanup Member Booking Data    ${dynamic_id}

TC-006_Verify_POST_web_bookings_with_session_and_3_vehicles_picking_2nd_writes_that_plate
    [Documentation]    Verify POST /web/bookings with a session and 3 vehicles, picking the 2nd, writes that vehicle's plate
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    Seed Vehicles For User    ${dynamic_id}    3
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${start_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=22222222-2222-2222-2222-222222222222
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE email = 'member_${dynamic_id}@test.com'
    Should Be Equal As Strings    ${result[0][0]}    คง5678
    [Teardown]    Cleanup Member Booking Data    ${dynamic_id}

TC-007_Verify_POST_web_bookings_with_session_and_NO_vehicle_id_creates_booking_leaves_plate_NULL
    [Documentation]    Verify POST /web/bookings with a session and NO vehicle_id creates the booking and leaves drivers.plate NULL
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${start_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE email = 'member_${dynamic_id}@test.com'
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Member Booking Data    ${dynamic_id}

TC-008_Verify_POST_web_bookings_with_NO_session_honours_submitted_driver_id_and_does_not_touch_plate
    [Documentation]    Verify POST /web/bookings with NO session honours the submitted driver_id and does not touch drivers.plate
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${driver_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${driver_id}, 'Driver ${dynamic_id}', 'driver_${dynamic_id}@test.com')
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${start_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup NoMember Booking Data    ${dynamic_id}    ${driver_id}
TC-009_Verify_POST_web_bookings_with_session_and_vehicle_id_belonging_to_another_member_returns_Vehicle_not_found
    [Documentation]    Verify POST /web/bookings with a session and a vehicle_id belonging to another member returns 'Vehicle not found' and does NOT create the booking
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    Seed Vehicles For User    ${dynamic_id}    1
    ${other_user_uuid}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${other_driver_id}=    Evaluate    ${dynamic_id} + 12
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id} + 10, 'Other Owner', 'other_owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${other_driver_id}, 'Other Driver', 'other_driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO users (id, name, email, password_hash, phone, driver_id, created_at) VALUES ('${other_user_uuid}', 'Other User', 'other_user_${dynamic_id}@test.com', 'x', '0812345678', ${other_driver_id}, NOW())
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('44444444-4444-4444-4444-444444444444', '${other_user_uuid}', 'จง9012', NOW())
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${start_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=44444444-4444-4444-4444-444444444444
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Vehicle not found
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id IN (SELECT driver_id FROM users WHERE email = 'member_${dynamic_id}@test.com')
    Should Be Equal As Integers    ${count[0][0]}    0
    ${plate}=    Query    SELECT plate FROM drivers WHERE email = 'member_${dynamic_id}@test.com'
    Should Be Equal    ${plate[0][0]}    ${None}
    [Teardown]    Cleanup Member Booking Data With Other    ${dynamic_id}

TC-010_Verify_POST_web_bookings_with_session_and_vehicle_id_not_a_uuid_returns_Vehicle_not_found
    [Documentation]    Verify POST /web/bookings with a session and vehicle_id='not-a-uuid' returns 'Vehicle not found' (not a 500) and does NOT create the booking
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    Seed Vehicles For User    ${dynamic_id}    1
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${start_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=not-a-uuid
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Vehicle not found
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id IN (SELECT driver_id FROM users WHERE email = 'member_${dynamic_id}@test.com')
    Should Be Equal As Integers    ${count[0][0]}    0
    ${plate}=    Query    SELECT plate FROM drivers WHERE email = 'member_${dynamic_id}@test.com'
    Should Be Equal    ${plate[0][0]}    ${None}
    [Teardown]    Cleanup Member Booking Data    ${dynamic_id}

TC-011_Verify_POST_web_bookings_with_session_and_well_formed_uuid_that_exists_in_no_row_returns_Vehicle_not_found
    [Documentation]    Verify POST /web/bookings with a session and a well-formed UUID that exists in no row returns 'Vehicle not found' and does NOT create the booking
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    Seed Vehicles For User    ${dynamic_id}    1
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${start_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=99999999-9999-9999-9999-999999999999
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Vehicle not found
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id IN (SELECT driver_id FROM users WHERE email = 'member_${dynamic_id}@test.com')
    Should Be Equal As Integers    ${count[0][0]}    0
    ${plate}=    Query    SELECT plate FROM drivers WHERE email = 'member_${dynamic_id}@test.com'
    Should Be Equal    ${plate[0][0]}    ${None}
    [Teardown]    Cleanup Member Booking Data    ${dynamic_id}

TC-012_Verify_POST_web_bookings_twice_with_different_vehicles_leaves_second_vehicles_plate_on_bridged_driver
    [Documentation]    Verify POST /web/bookings twice with different vehicles leaves the second vehicle's plate on the bridged driver
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 4, ${dynamic_id} + 1, 'A-2', true)
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}
    Seed Vehicles For User    ${dynamic_id}    2
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${start_at_1}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at_1}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form_1}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at_1}    end_at=${end_at_1}    vehicle_id=11111111-1111-1111-1111-111111111111
    ${resp_1}=    POST On Session    api    /web/bookings    data=${form_1}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp_1}
    ${body_1}=    Set Variable    ${resp_1.text}
    Should Contain    ${body_1}    จองสำเร็จ
    Should Contain    ${body_1}    ที่จอดถูกล็อกไว้
    ${start_at_2}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at_2}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=240)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form_2}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at_2}    end_at=${end_at_2}    vehicle_id=22222222-2222-2222-2222-222222222222
    ${resp_2}=    POST On Session    api    /web/bookings    data=${form_2}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp_2}
    ${body_2}=    Set Variable    ${resp_2.text}
    Should Contain    ${body_2}    จองสำเร็จ
    Should Contain    ${body_2}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE email = 'member_${dynamic_id}@test.com'
    Should Be Equal As Strings    ${result[0][0]}    คง5678
    [Teardown]    Cleanup Member Booking Data    ${dynamic_id}