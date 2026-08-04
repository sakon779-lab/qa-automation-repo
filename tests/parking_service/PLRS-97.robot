*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_logged_in_member_sees_account_name_on_booking_form
    [Documentation]    Verify a logged-in member sees 'จองในชื่อ {name} (บัญชีที่ล็อกอินอยู่)' on the booking form
    ...                instead of the driver_id field
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    acct_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    Acct User    ${email}    0812345678    password123

    # Exercise: GET /web/bookings/new with the session cookie
    ${resp}=    GET On Session    api    /web/bookings/new    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองในชื่อ Acct User (บัญชีที่ล็อกอินอยู่)

    # Post-Assertion: user has a bridged driver
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}' AND driver_id IS NOT NULL
    Should Be Equal As Integers    ${count[0][0]}    1

    [Teardown]    Cleanup Member Test Data    ${dynamic_id}    ${email}

TC-002_Verify_session_booking_uses_bridged_driver
    [Documentation]    Verify POST /web/bookings with a session books for the session's bridged driver
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    acct_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    Acct User    ${email}    0812345678    password123
    Seed Owner Lot Spot    ${dynamic_id}

    # Materialize time placeholders (Thai business day)
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${now_plus_60m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime
    ${now_plus_180m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime

    # Exercise: POST /web/bookings with session cookie, forged driver_id is ignored
    ${form}=    Create Dictionary    driver_id=999999    lot_id=${dynamic_id}    start_at=${now_plus_60m}    end_at=${now_plus_180m}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้

    # Post-Assertion: reservation created for the bridged driver, not the forged one
    ${count}=    Query    SELECT count(*) FROM reservations WHERE lot_id = ${dynamic_id} AND driver_id = (SELECT driver_id FROM users WHERE email = '${email}')
    Should Be Equal As Integers    ${count[0][0]}    1

    [Teardown]    Cleanup Member And Lot Test Data    ${dynamic_id}    ${email}

TC-003_Verify_forged_driver_id_is_ignored_with_session
    [Documentation]    Verify a driver_id forged in the form body is IGNORED when a session is present
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    acct_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    Acct User    ${email}    0812345678    password123
    Seed Owner Lot Spot    ${dynamic_id}

    # Materialize time placeholders
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${now_plus_60m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime
    ${now_plus_180m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime

    # Exercise: POST /web/bookings with session cookie and forged driver_id
    ${form}=    Create Dictionary    driver_id=999999    lot_id=${dynamic_id}    start_at=${now_plus_60m}    end_at=${now_plus_180m}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ

    # Post-Assertion: NO reservation for the forged driver_id
    ${count}=    Query    SELECT count(*) FROM reservations WHERE lot_id = ${dynamic_id} AND driver_id = 999999
    Should Be Equal As Integers    ${count[0][0]}    0

    [Teardown]    Cleanup Member And Lot Test Data    ${dynamic_id}    ${email}

TC-004_Verify_profile_lists_booking_with_checkin_button
    [Documentation]    Verify GET /web/profile lists the member's booking under 'การจองของฉัน'
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    acct_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    Acct User    ${email}    0812345678    password123
    Seed Owner Lot Spot    ${dynamic_id}

    # Materialize time placeholders
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${now_plus_60m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime
    ${now_plus_180m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime

    # Create a booking first
    ${form}=    Create Dictionary    driver_id=999999    lot_id=${dynamic_id}    start_at=${now_plus_60m}    end_at=${now_plus_180m}
    ${booking_resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${booking_resp}

    # Exercise: GET /web/profile
    ${resp}=    GET On Session    api    /web/profile    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    การจองของฉัน
    Should Contain    ${body}    Lot ${dynamic_id}
    Should Contain    ${body}    SOFT_LOCKED
    Should Contain    ${body}    เช็คอิน

    # Post-Assertion: exactly 1 reservation for the bridged driver
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = (SELECT driver_id FROM users WHERE email = '${email}')
    Should Be Equal As Integers    ${count[0][0]}    1

    [Teardown]    Cleanup Member And Lot Test Data    ${dynamic_id}    ${email}

TC-005_Verify_empty_state_when_no_bookings
    [Documentation]    Verify a member with no bookings sees the 'ยังไม่มีการจอง' empty state
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    acct_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    Acct User    ${email}    0812345678    password123

    # Exercise: GET /web/profile
    ${resp}=    GET On Session    api    /web/profile    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    การจองของฉัน
    Should Contain    ${body}    ยังไม่มีการจอง

    # Post-Assertion: no reservations for this member
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = (SELECT driver_id FROM users WHERE email = '${email}')
    Should Be Equal As Integers    ${count[0][0]}    0

    [Teardown]    Cleanup Member Test Data    ${dynamic_id}    ${email}

TC-006_Verify_login_does_not_create_second_bridged_driver
    [Documentation]    Verify logging in again does NOT create a second bridged driver
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    acct_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    Acct User    ${email}    0812345678    password123

    # Exercise: Login again
    ${login_form}=    Create Dictionary    email=${email}    password=password123
    ${login_resp}=    POST On Session    api    /web/login    data=${login_form}    allow_redirects=${False}    expected_status=any
    Should Be Equal As Integers    ${login_resp.status_code}    303
    ${new_cookie}=    Create Dictionary    plrs_session=${login_resp.cookies}[plrs_session]

    # GET /web/profile with the new session cookie
    ${resp}=    GET On Session    api    /web/profile    cookies=${new_cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    การจองของฉัน
    Should Contain    ${body}    Acct User

    # Post-Assertion: only ONE bridged driver exists
    ${count}=    Query    SELECT count(*) FROM drivers WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1

    [Teardown]    Cleanup Member Test Data    ${dynamic_id}    ${email}

TC-007_Verify_null_driver_id_is_refused
    [Documentation]    Verify a session whose user row has driver_id NULL is refused with the data-integrity message
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    acct_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    Acct User    ${email}    0812345678    password123
    Seed Owner Lot Spot    ${dynamic_id}

    # Break the bridge: set driver_id to NULL
    Execute Sql String    UPDATE users SET driver_id = NULL WHERE email = '${email}'

    # Materialize time placeholders
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${now_plus_60m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime
    ${now_plus_180m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime

    # Exercise: POST /web/bookings
    ${form}=    Create Dictionary    driver_id=999999    lot_id=${dynamic_id}    start_at=${now_plus_60m}    end_at=${now_plus_180m}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    No driver linked to this account — please log out and log in again

    # Post-Assertion: no reservation created
    ${count}=    Query    SELECT count(*) FROM reservations WHERE lot_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0

    [Teardown]    Cleanup Member And Lot Test Data    ${dynamic_id}    ${email}

TC-008_Verify_missing_driver_row_is_refused
    [Documentation]    Verify a bridge pointing at a non-existent driver row is refused with the same message
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    acct_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    Acct User    ${email}    0812345678    password123
    Seed Owner Lot Spot    ${dynamic_id}

    # Break the bridge: point at a non-existent driver
    Execute Sql String    UPDATE users SET driver_id = 999999 WHERE email = '${email}'

    # Materialize time placeholders
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${now_plus_60m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime
    ${now_plus_180m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime

    # Exercise: POST /web/bookings
    ${form}=    Create Dictionary    driver_id=999999    lot_id=${dynamic_id}    start_at=${now_plus_60m}    end_at=${now_plus_180m}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    No driver linked to this account — please log out and log in again

    # Post-Assertion: no reservation created
    ${count}=    Query    SELECT count(*) FROM reservations WHERE lot_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0

    [Teardown]    Cleanup Member And Lot Test Data    ${dynamic_id}    ${email}

TC-009_Regression_booking_form_without_session_shows_driver_id
    [Documentation]    Regression: with NO session the booking form still renders the raw driver_id input
    Create Global API Session

    # Exercise: GET /web/bookings/new with no cookies
    ${resp}=    GET On Session    api    /web/bookings/new    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="driver_id"

TC-010_Regression_booking_without_session_uses_submitted_driver_id
    [Documentation]    Regression: with NO session POST /web/bookings still books for the submitted driver_id
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Lot Spot    ${dynamic_id}
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Guest ${dynamic_id}', 'guest_${dynamic_id}@test.plrs', 'KK${dynamic_id}')

    # Materialize time placeholders
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${now_plus_60m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime
    ${now_plus_180m}=    Evaluate    (datetime.datetime.now($tz) + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%S')    modules=datetime

    # Exercise: POST /web/bookings with NO cookies
    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${dynamic_id}    start_at=${now_plus_60m}    end_at=${now_plus_180m}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ

    # Post-Assertion: reservation created for the submitted driver_id
    ${count}=    Query    SELECT count(*) FROM reservations WHERE lot_id = ${dynamic_id} AND driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    1

    [Teardown]    Cleanup Guest Booking Test Data    ${dynamic_id}

*** Keywords ***
Signup And Get Session Cookie
    [Arguments]    ${name}    ${email}    ${phone}    ${password}
    ${form}=    Create Dictionary    name=${name}    email=${email}    phone=${phone}    password=${password}
    ${resp}=    POST On Session    api    /web/signup    data=${form}    allow_redirects=${False}    expected_status=any
    Should Be Equal As Integers    ${resp.status_code}    303
    ${cookie}=    Create Dictionary    plrs_session=${resp.cookies}[plrs_session]
    RETURN    ${cookie}

Seed Owner Lot Spot
    [Arguments]    ${id}
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner ${id}', 'owner_${id}@test.plrs', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${id}, 'Lot ${id}', ${id}, 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${id}, ${id}, 'A-${id}', true)

Cleanup Member Test Data
    [Arguments]    ${id}    ${email}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id IN (SELECT driver_id FROM users WHERE email = '${email}')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id IN (SELECT id FROM users WHERE email = '${email}')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE email = '${email}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE email = '${email}'
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Member And Lot Test Data
    [Arguments]    ${id}    ${email}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id IN (SELECT driver_id FROM users WHERE email = '${email}')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id IN (SELECT id FROM users WHERE email = '${email}')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE email = '${email}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE email = '${email}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE lot_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Guest Booking Test Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE lot_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database