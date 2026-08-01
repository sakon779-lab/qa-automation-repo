*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_checkin_renders_form
    [Documentation]    Verify GET /web/checkin renders the check-in form page with reservation_id and wall_code fields and htmx wiring
    Create Global API Session
    ${resp}=    GET On Session    api    /web/checkin    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    เช็คอิน
    Should Contain    ${body}    wall_code
    Should Contain    ${body}    reservation_id
    Should Contain    ${body}    hx-post="/web/checkin"
    Should Contain    ${body}    hx-target="#checkin-result"
    Should Contain    ${body}    id="checkin-result"

TC-002_Verify_POST_web_checkin_valid_creates_ACTIVE_session
    [Documentation]    Verify POST /web/checkin with valid CONFIRMED reservation and correct wall code returns ACTIVE session fragment
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Checkin Fixture    CONFIRMED    -5 minutes    55 minutes
    ${form}=    Create Dictionary    reservation_id=${id}    wall_code=1234
    ${resp}=    POST On Session    api    /web/checkin    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ACTIVE
    Should Contain    ${body}    เช็คอินสำเร็จ
    ${count}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${id} AND status = 'ACTIVE'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Checkin Data    ${id}

TC-003_Verify_POST_web_checkin_wrong_wall_code
    [Documentation]    Verify POST /web/checkin with wrong wall code returns inline error 'Invalid wall code'
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Checkin Fixture    CONFIRMED    -5 minutes    55 minutes
    ${form}=    Create Dictionary    reservation_id=${id}    wall_code=9999
    ${resp}=    POST On Session    api    /web/checkin    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Invalid wall code
    ${count}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Checkin Data    ${id}

TC-004_Verify_POST_web_checkin_non_confirmed_reservation
    [Documentation]    Verify POST /web/checkin with non-CONFIRMED reservation returns inline error 'Reservation is not confirmed'
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Checkin Fixture    PENDING    -5 minutes    55 minutes
    ${form}=    Create Dictionary    reservation_id=${id}    wall_code=1234
    ${resp}=    POST On Session    api    /web/checkin    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Reservation is not confirmed
    ${count}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Checkin Data    ${id}

TC-005_Verify_POST_web_checkin_too_early
    [Documentation]    Verify POST /web/checkin when too early (start_time in 20 min, beyond 15-min early window) returns inline error 'Too early to check in'
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Checkin Fixture    CONFIRMED    20 minutes    80 minutes
    ${form}=    Create Dictionary    reservation_id=${id}    wall_code=1234
    ${resp}=    POST On Session    api    /web/checkin    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Too early to check in
    ${count}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Checkin Data    ${id}

TC-006_Verify_POST_web_checkin_after_grace_window
    [Documentation]    Verify POST /web/checkin after grace window (start_time 20 min ago, beyond 15-min late window) returns inline error 'Check-in period has expired'
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Checkin Fixture    CONFIRMED    -20 minutes    40 minutes
    ${form}=    Create Dictionary    reservation_id=${id}    wall_code=1234
    ${resp}=    POST On Session    api    /web/checkin    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Check-in period has expired
    ${count}=    Query    SELECT count(*) FROM sessions WHERE reservation_id = ${id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Checkin Data    ${id}

TC-007_Verify_POST_web_checkin_missing_reservation_id
    [Documentation]    Verify POST /web/checkin with missing reservation_id returns inline error 'Reservation ID is required'
    Create Global API Session
    ${form}=    Create Dictionary    wall_code=1234
    ${resp}=    POST On Session    api    /web/checkin    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Reservation ID is required

TC-008_Verify_POST_web_checkin_missing_wall_code
    [Documentation]    Verify POST /web/checkin with missing wall_code returns inline error 'Wall code is required'
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 9999999)    modules=random
    ${form}=    Create Dictionary    reservation_id=${non_existent_id}
    ${resp}=    POST On Session    api    /web/checkin    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Wall code is required

TC-009_Verify_POST_web_checkin_non_existent_reservation
    [Documentation]    Verify POST /web/checkin with non-existent reservation returns inline error 'Reservation not found'
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 9999999)    modules=random
    ${form}=    Create Dictionary    reservation_id=${non_existent_id}    wall_code=1234
    ${resp}=    POST On Session    api    /web/checkin    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Reservation not found

TC-010_Verify_GET_web_sessions_shows_ACTIVE_and_overstay_placeholder
    [Documentation]    Verify GET /web/sessions/{id} shows ACTIVE status and the htmx overstay placeholder
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Session Fixture    ACTIVE    -5 minutes    55 minutes    -5 minutes    NULL
    ${resp}=    GET On Session    api    /web/sessions/${id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ACTIVE
    Should Contain    ${body}    id="overstay-fragment"
    Should Contain    ${body}    hx-get="/web/sessions/${id}/overstay-fragment"
    Should Contain    ${body}    hx-trigger="load, every 30s"
    [Teardown]    Cleanup Session Data    ${id}

TC-011_Verify_GET_web_sessions_non_existent_404
    [Documentation]    Verify GET /web/sessions/{id} with a non-existent session id returns 404 and the contract error 'Session not found'
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 9999999)    modules=random
    ${resp}=    GET On Session    api    /web/sessions/${non_existent_id}    expected_status=any
    Status Should Be    404    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Session not found

TC-012_Verify_GET_overstay_fragment_completed_overstaying
    [Documentation]    Verify GET /web/sessions/{id}/overstay-fragment shows 'เกินมา 10 นาที' for a COMPLETED overstaying session.
    ...                end_time is -20:00 (the CSV's value), NOT -20 minutes 30 seconds. Postgres reads
    ...                that as -19:30 (only the first field takes the sign), which puts billable_min
    ...                exactly on 9.0 — and ceil() then depends on NOW() advancing between the two
    ...                INSERTs. It does today only because each statement commits separately; inside one
    ...                transaction NOW() is constant, billable_min is 9, and the case fails. -20:00 keeps
    ...                a 30-second margin either way.
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Session Fixture    COMPLETED    -65 minutes    -20 minutes    -45 minutes    -30 seconds
    ${resp}=    GET On Session    api    /web/sessions/${id}/overstay-fragment    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    เกินมา 10 นาที
    Should Contain    ${body}    hx-swap="outerHTML"
    [Teardown]    Cleanup Session Data    ${id}

TC-013_Verify_GET_web_sessions_completed_shows_checkout
    [Documentation]    Verify GET /web/sessions/{id} shows COMPLETED status and the check-out timestamp row for a completed session
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Session Fixture    COMPLETED    -35 minutes    25 minutes    -30 minutes    NOW
    ${resp}=    GET On Session    api    /web/sessions/${id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    COMPLETED
    Should Contain    ${body}    เช็คเอาต์:
    [Teardown]    Cleanup Session Data    ${id}

TC-014_Verify_POST_checkout_returns_COMPLETED_fragment
    [Documentation]    Verify POST /web/sessions/{id}/checkout on an ACTIVE session returns the COMPLETED fragment with duration_min 30
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Session Fixture    ACTIVE    -35 minutes    25 minutes    -30 minutes 30 seconds    NULL
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/sessions/${id}/checkout    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    COMPLETED
    Should Contain    ${body}    duration_min: 30
    ${status}=    Query    SELECT status FROM sessions WHERE id = ${id}
    Should Be Equal As Strings    ${status[0][0]}    COMPLETED
    [Teardown]    Cleanup Session Data    ${id}

TC-015_Verify_POST_checkout_already_completed
    [Documentation]    Verify POST /web/sessions/{id}/checkout on already COMPLETED session returns inline error 'Session is already completed'
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Session Fixture    COMPLETED    -35 minutes    25 minutes    -30 minutes    NOW
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/sessions/${id}/checkout    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Session is already completed
    ${status}=    Query    SELECT status FROM sessions WHERE id = ${id}
    Should Be Equal As Strings    ${status[0][0]}    COMPLETED
    [Teardown]    Cleanup Session Data    ${id}

TC-016_Verify_POST_checkout_non_existent_session
    [Documentation]    Verify POST /web/sessions/{id}/checkout with non-existent session returns inline error 'Session not found'
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 9999999)    modules=random
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/sessions/${non_existent_id}/checkout    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Session not found

TC-017_Verify_GET_overstay_fragment_non_existent_session
    [Documentation]    Verify GET /web/sessions/{id}/overstay-fragment with non-existent session returns inline error 'Session not found'
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 9999999)    modules=random
    ${resp}=    GET On Session    api    /web/sessions/${non_existent_id}/overstay-fragment    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Session not found

TC-018_Verify_GET_overstay_fragment_not_overstaying
    [Documentation]    Verify GET /web/sessions/{id}/overstay-fragment shows 'ยังไม่เกินเวลา' for non-overstaying ACTIVE session
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Session Fixture    ACTIVE    -5 minutes    55 minutes    -5 minutes    NULL
    ${resp}=    GET On Session    api    /web/sessions/${id}/overstay-fragment    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ยังไม่เกินเวลา
    Should Contain    ${body}    hx-swap="outerHTML"
    [Teardown]    Cleanup Session Data    ${id}

TC-019_Verify_GET_overstay_fragment_overstaying_active
    [Documentation]    Verify GET /web/sessions/{id}/overstay-fragment shows 'เกินมา 50 นาที' for an overstaying ACTIVE session
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Session Fixture    ACTIVE    -65 minutes    -60 minutes 30 seconds    -60 minutes    NULL
    ${resp}=    GET On Session    api    /web/sessions/${id}/overstay-fragment    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    เกินมา 50 นาที
    Should Contain    ${body}    hx-swap="outerHTML"
    [Teardown]    Cleanup Session Data    ${id}

*** Keywords ***
Seed Checkin Fixture
    [Arguments]    ${status}    ${start_offset}    ${end_offset}
    Connect To Global Database
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${driver}=    Evaluate    ${id} + 1
    ${lot}=       Evaluate    ${id} + 2
    ${spot}=      Evaluate    ${id} + 3
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner A', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver}, 'Driver A', 'driver_${driver}@test.com', 'KK${driver}')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${lot}, ${id}, 'Lot ${lot}', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot}, ${lot}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, lock_expires_at) VALUES (${id}, ${driver}, ${lot}, ${spot}, NOW() + INTERVAL '${start_offset}', NOW() + INTERVAL '${end_offset}', '${status}', NOW() + INTERVAL '300 seconds')
    RETURN    ${driver}    ${lot}    ${spot}    ${id}

Seed Session Fixture
    [Arguments]    ${status}    ${start_offset}    ${end_offset}    ${checkin_offset}    ${checkout_offset}
    Connect To Global Database
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${driver}=    Evaluate    ${id} + 1
    ${lot}=       Evaluate    ${id} + 2
    ${spot}=      Evaluate    ${id} + 3
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner A', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver}, 'Driver A', 'driver_${driver}@test.com', 'KK${driver}')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${lot}, ${id}, 'Lot ${lot}', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot}, ${lot}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, lock_expires_at) VALUES (${id}, ${driver}, ${lot}, ${spot}, NOW() + INTERVAL '${start_offset}', NOW() + INTERVAL '${end_offset}', 'CONFIRMED', NOW() + INTERVAL '300 seconds')
    IF    '${checkout_offset}' == 'NULL'
        Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status) VALUES (${id}, ${id}, NOW() + INTERVAL '${checkin_offset}', NULL, '${status}')
    ELSE IF    '${checkout_offset}' == 'NOW'
        Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status) VALUES (${id}, ${id}, NOW() + INTERVAL '${checkin_offset}', NOW(), '${status}')
    ELSE
        Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, checkout_at, status) VALUES (${id}, ${id}, NOW() + INTERVAL '${checkin_offset}', NOW() + INTERVAL '${checkout_offset}', '${status}')
    END
    RETURN    ${driver}    ${lot}    ${spot}    ${id}

Cleanup Checkin Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE reservation_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id} + 3
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 2
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Session Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id} + 3
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 2
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database