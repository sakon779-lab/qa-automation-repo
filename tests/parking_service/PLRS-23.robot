*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_staff_search_renders_plate_search_form
    [Documentation]    Verify GET /web/staff/search renders the plate-search form page with heading and htmx wiring when no plate param is provided
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ค้นหาทะเบียนรถ
    Should Contain    ${body}    hx-get="/web/staff/search"
    Should Contain    ${body}    hx-target="#search-result"
    Should Contain    ${body}    id="search-result"

TC-002_Verify_GET_web_staff_search_with_plate_renders_active_session
    [Documentation]    Verify GET /web/staff/search?plate=KK<dynamic_id> renders active-session result card with plate, lot, spot, driver name and active status
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Somchai', 'somchai_${dynamic_id}@plrs.test', 'KK${dynamic_id}')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Main Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '30 minutes')
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=KK${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    KK${dynamic_id}
    Should Contain    ${body}    Somchai
    Should Contain    ${body}    lot_id: ${dynamic_id}
    Should Contain    ${body}    spot_id: ${dynamic_id}
    Should Contain    ${body}    ใช้งานอยู่
    ${db_count}=    Query    SELECT count(*) FROM sessions WHERE id = ${dynamic_id} AND status = 'ACTIVE'
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-003_Verify_GET_web_staff_search_unknown_plate_renders_no_active_booking
    [Documentation]    Verify GET /web/staff/search?plate=ZZ9999 renders 'no active booking' message when the delegated PLRS-22 API returns active=false with null session
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=ZZ9999    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ไม่พบการจองที่ใช้งานอยู่สำหรับทะเบียนนี้

TC-004_Verify_GET_web_staff_search_blank_plate_renders_inline_error
    [Documentation]    Verify GET /web/staff/search with blank plate query parameter renders inline 'Plate is required' message (HTTP 200, not an error status)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Plate is required

TC-005_Verify_GET_web_staff_search_whitespace_plate_renders_inline_error
    [Documentation]    Verify GET /web/staff/search with whitespace-only plate query parameter renders inline 'Plate is required' message (HTTP 200, not an error status)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=%20%20    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Plate is required

TC-006_Verify_GET_web_staff_search_normalized_plate_renders_result
    [Documentation]    Verify GET /web/staff/search?plate=kk%201234 renders result card with normalized plate KK1234
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Somchai', 'somchai_${dynamic_id}@plrs.test', 'KK1234')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Main Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '30 minutes')
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=kk%201234    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    KK1234
    Should Contain    ${body}    Somchai
    Should Contain    ${body}    lot_id: ${dynamic_id}
    Should Contain    ${body}    spot_id: ${dynamic_id}
    Should Contain    ${body}    ใช้งานอยู่
    ${db_count}=    Query    SELECT count(*) FROM sessions WHERE id = ${dynamic_id} AND status = 'ACTIVE'
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-007_Verify_GET_web_staff_search_lowercase_plate_renders_result
    [Documentation]    Verify GET /web/staff/search?plate=kk1234 renders result card for lowercase plate input, matched case-insensitively
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Somchai', 'somchai_${dynamic_id}@plrs.test', 'KK1234')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Main Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'CONFIRMED', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '30 minutes')
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=kk1234    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    KK1234
    Should Contain    ${body}    Somchai
    Should Contain    ${body}    lot_id: ${dynamic_id}
    Should Contain    ${body}    spot_id: ${dynamic_id}
    Should Contain    ${body}    ใช้งานอยู่
    ${db_count}=    Query    SELECT count(*) FROM sessions WHERE id = ${dynamic_id} AND status = 'ACTIVE'
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-008_Verify_GET_web_staff_search_unknown_plate_renders_no_active_booking
    [Documentation]    Verify GET /web/staff/search?plate=UNKNOWN99 renders 'no active booking' message for an unknown plate
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=UNKNOWN99    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ไม่พบการจองที่ใช้งานอยู่สำหรับทะเบียนนี้

TC-009_Verify_GET_web_staff_search_completed_session_renders_no_active_booking
    [Documentation]    Verify GET /web/staff/search?plate=COMPLETED1 renders 'no active booking' message when the plate has only COMPLETED sessions
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id}, 'Somchai', 'somchai_${dynamic_id}@plrs.test', 'COMPLETED1')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${dynamic_id}, 'Main Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, status, start_time, end_time) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, 'COMPLETED', NOW() - INTERVAL '3 hours', NOW() - INTERVAL '2 hours')
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at) VALUES (${dynamic_id}, ${dynamic_id}, 'COMPLETED', NOW() - INTERVAL '3 hours')
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=COMPLETED1    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ไม่พบการจองที่ใช้งานอยู่สำหรับทะเบียนนี้
    ${db_count}=    Query    SELECT count(*) FROM sessions WHERE id = ${dynamic_id} AND status = 'COMPLETED'
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-010_Verify_GET_web_staff_search_sql_injection_renders_no_active_booking
    [Documentation]    Verify GET /web/staff/search with SQL injection payload in plate query parameter does not reflect the payload or execute it
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=%27%3B%20DROP%20TABLE%20drivers%3B--    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ไม่พบการจองที่ใช้งานอยู่สำหรับทะเบียนนี้

TC-011_Verify_GET_web_staff_search_xss_payload_renders_no_active_booking
    [Documentation]    Verify GET /web/staff/search with XSS payload in plate query parameter does not reflect the payload unescaped or execute it
    Create Global API Session
    ${resp}=    GET On Session    api    /web/staff/search    params=plate=%3Cscript%3Ealert(1)%3C%2Fscript%3E    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ไม่พบการจองที่ใช้งานอยู่สำหรับทะเบียนนี้