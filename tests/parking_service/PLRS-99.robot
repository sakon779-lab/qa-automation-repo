*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Keywords ***
Seed Lot Only
    [Arguments]    ${id}
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${id}, 'Seed Lot', 40)

Seed Spot With Active Session
    [Arguments]    ${id}    ${start_offset}    ${end_offset}
    ${driver_id}=    Evaluate    ${id} + 100
    ${spot_id}=      Evaluate    ${id} + 1
    ${res_id}=       Evaluate    ${id} + 20
    ${sess_id}=      Evaluate    ${id} + 10
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver_id}, 'Driver A', 'driver_${id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${id}, 'Seed Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, spot_id, driver_id, lot_id, start_time, end_time, status) VALUES (${res_id}, ${spot_id}, ${driver_id}, ${id}, NOW() ${start_offset}, NOW() ${end_offset}, 'CONFIRMED')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, status) VALUES (${sess_id}, ${res_id}, NOW() ${start_offset}, 'ACTIVE')
    Set Test Variable    ${driver_id}
    Set Test Variable    ${spot_id}
    Set Test Variable    ${res_id}
    Set Test Variable    ${sess_id}

Seed Spot With Future Booking
    [Arguments]    ${id}
    ${driver_id}=    Evaluate    ${id} + 100
    ${spot_id}=      Evaluate    ${id} + 1
    ${res_id}=       Evaluate    ${id} + 20
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver_id}, 'Driver A', 'driver_${id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${id}, 'Seed Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, spot_id, driver_id, lot_id, start_time, end_time, status) VALUES (${res_id}, ${spot_id}, ${driver_id}, ${id}, NOW() + INTERVAL '1 hour', NOW() + INTERVAL '2 hours', 'CONFIRMED')
    Set Test Variable    ${driver_id}
    Set Test Variable    ${spot_id}
    Set Test Variable    ${res_id}

Seed Spot With Past Booking
    [Arguments]    ${id}    ${start_offset}    ${end_offset}
    ${driver_id}=    Evaluate    ${id} + 100
    ${spot_id}=      Evaluate    ${id} + 1
    ${res_id}=       Evaluate    ${id} + 20
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver_id}, 'Driver A', 'driver_${id}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${id}, 'Seed Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, spot_id, driver_id, lot_id, start_time, end_time, status) VALUES (${res_id}, ${spot_id}, ${driver_id}, ${id}, NOW() ${start_offset}, NOW() ${end_offset}, 'CONFIRMED')
    Set Test Variable    ${driver_id}
    Set Test Variable    ${spot_id}
    Set Test Variable    ${res_id}

Seed Spot With XSS Plate
    [Arguments]    ${id}
    ${driver_id}=    Evaluate    ${id} + 100
    ${spot_id}=      Evaluate    ${id} + 1
    ${res_id}=       Evaluate    ${id} + 20
    ${sess_id}=      Evaluate    ${id} + 10
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver_id}, 'Driver A', 'driver_${id}@test.com', '<script>alert(1)</script>')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${id}, 'Seed Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, spot_id, driver_id, lot_id, start_time, end_time, status) VALUES (${res_id}, ${spot_id}, ${driver_id}, ${id}, NOW(), NOW() + INTERVAL '1 hour', 'CONFIRMED')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, status) VALUES (${sess_id}, ${res_id}, NOW(), 'ACTIVE')
    Set Test Variable    ${driver_id}
    Set Test Variable    ${spot_id}
    Set Test Variable    ${res_id}
    Set Test Variable    ${sess_id}

Seed Mixed Lot
    [Arguments]    ${id}
    ${driver1}=    Evaluate    ${id} + 100
    ${driver2}=    Evaluate    ${id} + 101
    ${spot1}=      Evaluate    ${id} + 1
    ${spot2}=      Evaluate    ${id} + 2
    ${spot3}=      Evaluate    ${id} + 3
    ${res1}=       Evaluate    ${id} + 20
    ${res2}=       Evaluate    ${id} + 21
    ${sess1}=      Evaluate    ${id} + 10
    ${sess2}=      Evaluate    ${id} + 11
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver1}, 'Driver A', 'driver_${id}@test.com', 'KK1234'), (${driver2}, 'Driver B', 'driver2_${id}@test.com', 'AB5678')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${id}, 'Seed Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot1}, ${id}, 'A1', true), (${spot2}, ${id}, 'A2', true), (${spot3}, ${id}, 'A3', true)
    Execute Sql String    INSERT INTO reservations (id, spot_id, driver_id, lot_id, start_time, end_time, status) VALUES (${res1}, ${spot1}, ${driver1}, ${id}, NOW(), NOW() + INTERVAL '1 hour', 'CONFIRMED'), (${res2}, ${spot2}, ${driver2}, ${id}, NOW() - INTERVAL '2 hours', NOW() + INTERVAL '1 hour', 'CONFIRMED')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, status) VALUES (${sess1}, ${res1}, NOW(), 'ACTIVE'), (${sess2}, ${res2}, NOW() - INTERVAL '2 hours', 'ACTIVE')
    Set Test Variable    ${driver1}
    Set Test Variable    ${driver2}
    Set Test Variable    ${spot1}
    Set Test Variable    ${spot2}
    Set Test Variable    ${spot3}
    Set Test Variable    ${res1}
    Set Test Variable    ${res2}
    Set Test Variable    ${sess1}
    Set Test Variable    ${sess2}

Cleanup Lot Only
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Disconnect From Global Database

Cleanup Spot With Session
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE id = ${id} + 10
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id} + 20
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id} + 100
    Disconnect From Global Database

Cleanup Spot With Booking
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id} + 20
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id} + 100
    Disconnect From Global Database

Cleanup Mixed Lot
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE id IN (${id} + 10, ${id} + 11)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id IN (${id} + 20, ${id} + 21)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${id} + 1, ${id} + 2, ${id} + 3)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id IN (${id} + 100, ${id} + 101)
    Disconnect From Global Database

*** Test Cases ***
TC-001_Verify_GET_web_staff_renders_page_shell
    [Documentation]    Verify GET /web/staff renders the page shell with lot dropdown, htmx wiring, and search link
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Lot Only    ${dynamic_id}
    ${resp}=    GET On Session    api    /web/staff    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Seed Lot
    Should Contain    ${body}    hx-get="/web/staff/board"
    Should Contain    ${body}    hx-target="#staff-board"
    Should Contain    ${body}    id="staff-board"
    Should Contain    ${body}    hx-trigger="every 30s"
    Should Contain    ${body}    href="/web/staff/search"
    [Teardown]    Cleanup Lot Only    ${dynamic_id}

TC-002_Verify_GET_web_staff_board_returns_400_when_lot_id_missing
    [Documentation]    Verify GET /web/staff/board returns 400 when lot_id is missing
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/board    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot ID is required

TC-003_Verify_GET_web_staff_board_returns_400_when_lot_id_non_integer
    [Documentation]    Verify GET /web/staff/board returns 400 when lot_id is non-integer
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=abc    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot ID is required

TC-004_Verify_GET_web_staff_board_returns_404_when_lot_not_found
    [Documentation]    Verify GET /web/staff/board returns 404 when lot_id references a non-existent lot
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${non_existent_id}    expected_status=any
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot not found

TC-005_Verify_GET_web_staff_board_renders_fragment_for_lot_with_no_spots
    [Documentation]    Verify GET /web/staff/board renders the fragment for a lot with no spots, showing zero-count summary chips
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Lot Only    ${dynamic_id}
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จอดอยู่
    Should Contain    ${body}    เกินเวลา
    Should Contain    ${body}    ว่าง
    [Teardown]    Cleanup Lot Only    ${dynamic_id}

TC-006_Verify_spot_with_active_session_not_overstaying_shows_parked
    [Documentation]    Verify a spot with an active session not overstaying shows badge 'จอดอยู่'
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Spot With Active Session    ${dynamic_id}    - INTERVAL '0 minutes'    + INTERVAL '1 hour'
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A1
    Should Contain    ${body}    KK1234
    Should Contain    ${body}    จอดอยู่
    [Teardown]    Cleanup Spot With Session    ${dynamic_id}
TC-007_Verify_spot_with_overstaying_session_shows_over_15_minutes
    [Documentation]    Verify a spot with an active session overstaying shows badge 'เกิน 15 นาที'
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Spot With Active Session    ${dynamic_id}    - INTERVAL '3 hours'    - INTERVAL '25 minutes - 30 seconds'
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A1
    Should Contain    ${body}    KK1234
    Should Contain    ${body}    เกิน 15 นาที
    [Teardown]    Cleanup Spot With Session    ${dynamic_id}

TC-008_Verify_spot_at_overstay_threshold_not_overstaying
    [Documentation]    Verify a spot with an active session exactly at the overstay threshold is NOT overstaying
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Spot With Active Session    ${dynamic_id}    - INTERVAL '1 minute'    + INTERVAL '1 hour'
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A1
    Should Contain    ${body}    KK1234
    Should Contain    ${body}    จอดอยู่
    [Teardown]    Cleanup Spot With Session    ${dynamic_id}

TC-009_Verify_empty_spot_shows_vacant
    [Documentation]    Verify an empty spot with no booking today shows badge 'ว่าง'
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${spot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Seed Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${dynamic_id}, 'A1', true)
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A1
    Should Contain    ${body}    ว่าง
    [Teardown]    Cleanup Spot With Booking    ${dynamic_id}

TC-010_Verify_empty_spot_with_future_booking_shows_vacant_until
    [Documentation]    Verify an empty spot with a future booking today shows badge 'ว่างถึง HH:MM'
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Spot With Future Booking    ${dynamic_id}
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A1
    Should Contain    ${body}    ว่างถึง 
    [Teardown]    Cleanup Spot With Booking    ${dynamic_id}
TC-011_Verify_mixed_lot_renders_all_badges_and_summary_chips
    [Documentation]    Verify a lot with mixed spot statuses renders all three badges and correct summary chips
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Mixed Lot    ${dynamic_id}
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A1
    Should Contain    ${body}    KK1234
    Should Contain    ${body}    จอดอยู่
    Should Contain    ${body}    A2
    Should Contain    ${body}    AB5678
    Should Contain    ${body}    เกิน 
    Should Contain    ${body}    A3
    Should Contain    ${body}    ว่าง
    [Teardown]    Cleanup Mixed Lot    ${dynamic_id}

TC-012_Verify_XSS_plate_is_html_escaped
    [Documentation]    Verify a plate containing XSS script is HTML-escaped in the rendered fragment and not executed
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Spot With XSS Plate    ${dynamic_id}
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    &lt;script&gt;
    Should Not Contain    ${body}    <script>alert(1)</script>
    [Teardown]    Cleanup Spot With Session    ${dynamic_id}

TC-013_Verify_spot_with_in_progress_reservation_shows_vacant
    [Documentation]    Verify an empty spot with a reservation currently in progress shows plain 'ว่าง'
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Spot With Past Booking    ${dynamic_id}    - INTERVAL '30 minutes'    + INTERVAL '30 minutes'
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A1
    Should Contain    ${body}    ว่าง
    Should Not Contain    ${body}    ว่างถึง
    [Teardown]    Cleanup Spot With Booking    ${dynamic_id}

TC-014_Verify_spot_with_ended_booking_shows_vacant
    [Documentation]    Verify an empty spot with a booking that already ended today shows plain 'ว่าง'
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Spot With Past Booking    ${dynamic_id}    - INTERVAL '2 hours'    - INTERVAL '1 hour'
    ${resp}=    GET On Session    api    /web/staff/board    params=lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A1
    Should Contain    ${body}    ว่าง
    Should Not Contain    ${body}    ว่างถึง
    [Teardown]    Cleanup Spot With Booking    ${dynamic_id}