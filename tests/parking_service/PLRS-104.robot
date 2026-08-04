*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Variables ***
${VEHICLE_1}    11111111-1111-1111-1111-111111111111
${VEHICLE_2}    22222222-2222-2222-2222-222222222222
${VEHICLE_3}    33333333-3333-3333-3333-333333333333
${VEHICLE_4}    44444444-4444-4444-4444-444444444444
${VEHICLE_NONE}    99999999-9999-9999-9999-999999999999

*** Keywords ***
Seed Base Fixture
    [Documentation]    Creates owner, lot, spot with dynamic ids. Returns owner_id, lot_id, spot_id.
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner ${id}', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate) VALUES (${lot_id}, ${id}, 'Lot ${id}', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-1', true)
    RETURN    ${id}    ${lot_id}    ${spot_id}

Signup And Get Session Cookie
    [Arguments]    ${id}    ${email}
    [Documentation]    POST /web/signup, don't follow redirect, return the session cookie dict.
    ${form}=    Create Dictionary    name=Member ${id}    email=${email}    phone=0812345678    password=Passw0rd!
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    ${cookie}=    Create Dictionary    plrs_session=${resp.cookies}[plrs_session]
    RETURN    ${cookie}

Get User Id By Email
    [Arguments]    ${email}
    ${result}=    Query    SELECT id FROM users WHERE email = '${email}'
    RETURN    ${result[0][0]}

Seed Vehicle
    [Arguments]    ${vehicle_id}    ${user_id}    ${plate}
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${vehicle_id}', '${user_id}', '${plate}', NOW())

Get Bridged Driver Id
    [Arguments]    ${user_id}
    ${result}=    Query    SELECT driver_id FROM users WHERE id = '${user_id}'
    RETURN    ${result[0][0]}

Cleanup Member Booking Data
    [Arguments]    ${id}    ${user_id}    ${lot_id}    ${spot_id}    ${extra_spot_id}=${None}
    ${driver_id}=    Get Bridged Driver Id    ${user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id = '${user_id}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = '${user_id}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${extra_spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup NoMember Booking Data
    [Arguments]    ${id}    ${lot_id}    ${spot_id}    ${driver_id}=${None}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup OtherUser Data
    [Arguments]    ${other_owner_id}    ${other_user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id = '${other_user_id}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = '${other_user_id}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${other_owner_id}

*** Test Cases ***
TC-001_Verify_GET_web_bookings_new_with_session_renders_select_with_members_vehicle_plate
    [Documentation]    Verify GET /web/bookings/new with a session renders a select with the member's vehicle plate
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    Seed Vehicle    ${VEHICLE_1}    ${user_id}    กข1234
    ${params}=    Create Dictionary    lot_id=${lot_id}
    ${resp}=    GET On Session    api    /web/bookings/new    params=${params}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    <select name="vehicle_id">
    Should Contain    ${body}    <option value="${VEHICLE_1}">กข1234</option>
    [Teardown]    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}

TC-002_Verify_GET_web_bookings_new_renders_one_option_per_vehicle
    [Documentation]    Verify GET /web/bookings/new with a session renders one option per vehicle (3 vehicles)
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    Seed Vehicle    ${VEHICLE_1}    ${user_id}    กข1234
    Seed Vehicle    ${VEHICLE_2}    ${user_id}    คง5678
    Seed Vehicle    ${VEHICLE_3}    ${user_id}    งง9012
    ${params}=    Create Dictionary    lot_id=${lot_id}
    ${resp}=    GET On Session    api    /web/bookings/new    params=${params}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    <select name="vehicle_id">
    Should Contain    ${body}    <option value="${VEHICLE_1}">กข1234</option>
    Should Contain    ${body}    <option value="${VEHICLE_2}">คง5678</option>
    Should Contain    ${body}    <option value="${VEHICLE_3}">งง9012</option>
    [Teardown]    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}

TC-003_Verify_GET_web_bookings_new_with_zero_vehicles_renders_empty_select_with_hint
    [Documentation]    Verify GET /web/bookings/new with a session and zero vehicles renders empty select with hint text and profile link
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    ${params}=    Create Dictionary    lot_id=${lot_id}
    ${resp}=    GET On Session    api    /web/bookings/new    params=${params}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    <select name="vehicle_id">
    Should Contain    ${body}    ยังไม่มีรถในโปรไฟล์ — เพิ่มรถได้ที่หน้าโปรไฟล์
    Should Contain    ${body}    href="/web/profile"
    [Teardown]    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}

TC-004_Verify_GET_web_bookings_new_with_NO_session_renders_page_without_vehicle_select
    [Documentation]    Verify GET /web/bookings/new with NO session renders the page without the vehicle select
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${params}=    Create Dictionary    lot_id=${lot_id}
    ${resp}=    GET On Session    api    /web/bookings/new    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองในชื่อ
    Should Contain    ${body}    Lot ${id}
    [Teardown]    Cleanup NoMember Booking Data    ${id}    ${lot_id}    ${spot_id}

TC-005_Verify_POST_web_bookings_with_session_and_owned_vehicle_writes_plate_to_bridged_driver
    [Documentation]    Verify POST /web/bookings with a session and an owned vehicle writes the plate to the bridged driver and creates the booking
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    Seed Vehicle    ${VEHICLE_1}    ${user_id}    กข1234
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=${VEHICLE_1}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${driver_id}=    Get Bridged Driver Id    ${user_id}
    ${result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal As Strings    ${result[0][0]}    กข1234
    [Teardown]    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}

TC-006_Verify_POST_web_bookings_with_3_vehicles_picking_2nd_writes_that_vehicles_plate
    [Documentation]    Verify POST /web/bookings with a session and 3 vehicles, picking the 2nd, writes that vehicle's plate
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    Seed Vehicle    ${VEHICLE_1}    ${user_id}    กข1234
    Seed Vehicle    ${VEHICLE_2}    ${user_id}    คง5678
    Seed Vehicle    ${VEHICLE_3}    ${user_id}    งง9012
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=${VEHICLE_2}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${driver_id}=    Get Bridged Driver Id    ${user_id}
    ${result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal As Strings    ${result[0][0]}    คง5678
    [Teardown]    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}
TC-007_Verify_POST_web_bookings_with_session_and_NO_vehicle_id_creates_booking_and_leaves_plate_NULL
    [Documentation]    Verify POST /web/bookings with a session and NO vehicle_id creates the booking and leaves drivers.plate NULL
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${driver_id}=    Get Bridged Driver Id    ${user_id}
    ${result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}

TC-008_Verify_POST_web_bookings_with_NO_session_honours_submitted_driver_id_and_does_not_touch_plate
    [Documentation]    Verify POST /web/bookings with NO session honours the submitted driver_id and does not touch drivers.plate
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${driver_id}=    Evaluate    ${id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${driver_id}, 'Driver ${id}', 'driver_${id}@test.com')
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    ${result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal    ${result[0][0]}    ${None}
    [Teardown]    Cleanup NoMember Booking Data    ${id}    ${lot_id}    ${spot_id}    ${driver_id}

TC-009_Verify_POST_web_bookings_with_session_and_vehicle_belonging_to_another_member_returns_Vehicle_not_found
    [Documentation]    Verify POST /web/bookings with a session and a vehicle_id belonging to another member returns 'Vehicle not found' and does NOT create the booking
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    Seed Vehicle    ${VEHICLE_1}    ${user_id}    กข1234
    ${other_owner_id}=    Evaluate    ${id} + 10
    ${other_user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${other_owner_id}, 'Other Owner', 'other_owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO users (id, name, email, password_hash, phone, created_at) VALUES ('${other_user_id}', 'Other User', 'other_user_${id}@test.com', 'x', '0812345678', NOW())
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${VEHICLE_4}', '${other_user_id}', 'จง9012', NOW())
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=${VEHICLE_4}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Vehicle not found
    ${driver_id}=    Get Bridged Driver Id    ${user_id}
    ${count_result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count_result[0][0]}    0
    ${plate_result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal    ${plate_result[0][0]}    ${None}
    [Teardown]    Run Keywords    Cleanup OtherUser Data    ${other_owner_id}    ${other_user_id}
    ...    AND    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}

TC-010_Verify_POST_web_bookings_with_session_and_invalid_uuid_returns_Vehicle_not_found
    [Documentation]    Verify POST /web/bookings with a session and vehicle_id='not-a-uuid' returns 'Vehicle not found' (not a 500) and does NOT create the booking
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    Seed Vehicle    ${VEHICLE_1}    ${user_id}    กข1234
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=not-a-uuid
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Vehicle not found
    ${driver_id}=    Get Bridged Driver Id    ${user_id}
    ${count_result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count_result[0][0]}    0
    ${plate_result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal    ${plate_result[0][0]}    ${None}
    [Teardown]    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}

TC-011_Verify_POST_web_bookings_with_session_and_nonexistent_uuid_returns_Vehicle_not_found
    [Documentation]    Verify POST /web/bookings with a session and a well-formed UUID that exists in no row returns 'Vehicle not found' and does NOT create the booking
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    Seed Vehicle    ${VEHICLE_1}    ${user_id}    กข1234
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=${VEHICLE_NONE}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Vehicle not found
    ${driver_id}=    Get Bridged Driver Id    ${user_id}
    ${count_result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count_result[0][0]}    0
    ${plate_result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal    ${plate_result[0][0]}    ${None}
    [Teardown]    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}

TC-012_Verify_POST_web_bookings_twice_with_different_vehicles_leaves_second_vehicles_plate
    [Documentation]    Verify POST /web/bookings twice with different vehicles leaves the second vehicle's plate on the bridged driver
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    member_${id}@test.com
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${spot2_id}=    Evaluate    ${id} + 4
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot2_id}, ${lot_id}, 'A-2', true)
    ${cookie}=    Signup And Get Session Cookie    ${id}    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    Seed Vehicle    ${VEHICLE_1}    ${user_id}    กข1234
    Seed Vehicle    ${VEHICLE_2}    ${user_id}    คง5678
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form1}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    vehicle_id=${VEHICLE_1}
    ${resp1}=    POST On Session    api    /web/bookings    data=${form1}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp1}
    ${body1}=    Set Variable    ${resp1.text}
    Should Contain    ${body1}    จองสำเร็จ
    Should Contain    ${body1}    ที่จอดถูกล็อกไว้
    ${start_at2}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at2}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=240)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form2}=    Create Dictionary    driver_id=1    lot_id=${lot_id}    start_at=${start_at2}    end_at=${end_at2}    vehicle_id=${VEHICLE_2}
    ${resp2}=    POST On Session    api    /web/bookings    data=${form2}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp2}
    ${body2}=    Set Variable    ${resp2.text}
    Should Contain    ${body2}    จองสำเร็จ
    Should Contain    ${body2}    ที่จอดถูกล็อกไว้
    ${driver_id}=    Get Bridged Driver Id    ${user_id}
    ${result}=    Query    SELECT plate FROM drivers WHERE id = ${driver_id}
    Should Be Equal As Strings    ${result[0][0]}    คง5678
    [Teardown]    Cleanup Member Booking Data    ${id}    ${user_id}    ${lot_id}    ${spot_id}    ${spot2_id}