*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_lots_returns_200_with_lot_card_showing_name_hourly_rate_in_฿_ชม_format_and_available_total_spots
    [Documentation]    Verify GET /web/lots returns 200 with lot card showing name, hourly_rate in ฿/ชม. format, and available/total_spots
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 1, 'ลานจอดสีฟ้า', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-01', true), (${dynamic_id} + 3, ${dynamic_id} + 1, 'A-02', true), (${dynamic_id} + 4, ${dynamic_id} + 1, 'A-03', true)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ลานจอดสีฟ้า
    Should Contain    ${body}    ฿40/ชม.
    Should Contain    ${body}    3/3
    [Teardown]    Cleanup Test Case Data TC-001    ${dynamic_id}

TC-002_Verify_GET_web_lots_shows_เต็ม_badge_when_a_lot_has_available_0
    [Documentation]    Verify GET /web/lots shows 'เต็ม' badge when a lot has available == 0
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 100, 'Driver A', 'driver_${dynamic_id}_100@test.com'), (${dynamic_id} + 101, 'Driver B', 'driver_${dynamic_id}_101@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 1, 'ลานเต็ม', ${dynamic_id}, 50, '5678')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'B-01', true), (${dynamic_id} + 3, ${dynamic_id} + 1, 'B-02', true)
    Execute Sql String    INSERT INTO reservations (id, spot_id, lot_id, driver_id, status, start_time, end_time) VALUES (${dynamic_id} + 4, ${dynamic_id} + 2, ${dynamic_id} + 1, ${dynamic_id} + 100, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes'), (${dynamic_id} + 5, ${dynamic_id} + 3, ${dynamic_id} + 1, ${dynamic_id} + 101, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes')
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ลานเต็ม
    Should Contain    ${body}    ฿50/ชม.
    Should Contain    ${body}    0/2
    Should Contain    ${body}    เต็ม
    [Teardown]    Cleanup Test Case Data TC-002    ${dynamic_id}

TC-003_Verify_GET_web_lots_renders_multiple_lot_cards_each_with_its_own_name_rate_and_availability
    [Documentation]    Verify GET /web/lots renders multiple lot cards each with its own name, rate, and availability
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 100, 'Driver A', 'driver_${dynamic_id}_100@test.com'), (${dynamic_id} + 101, 'Driver B', 'driver_${dynamic_id}_101@test.com'), (${dynamic_id} + 102, 'Driver C', 'driver_${dynamic_id}_102@test.com'), (${dynamic_id} + 103, 'Driver D', 'driver_${dynamic_id}_103@test.com'), (${dynamic_id} + 104, 'Driver E', 'driver_${dynamic_id}_104@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 1, 'ลาน A', ${dynamic_id}, 40, '1234'), (${dynamic_id} + 2, 'ลาน B', ${dynamic_id}, 60, '5678')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 3, ${dynamic_id} + 1, 'A-01', true), (${dynamic_id} + 4, ${dynamic_id} + 1, 'A-02', true), (${dynamic_id} + 5, ${dynamic_id} + 1, 'A-03', true), (${dynamic_id} + 6, ${dynamic_id} + 1, 'A-04', true), (${dynamic_id} + 7, ${dynamic_id} + 1, 'A-05', true), (${dynamic_id} + 8, ${dynamic_id} + 2, 'B-01', true), (${dynamic_id} + 9, ${dynamic_id} + 2, 'B-02', true), (${dynamic_id} + 10, ${dynamic_id} + 2, 'B-03', true)
    Execute Sql String    INSERT INTO reservations (id, spot_id, lot_id, driver_id, status, start_time, end_time) VALUES (${dynamic_id} + 11, ${dynamic_id} + 3, ${dynamic_id} + 1, ${dynamic_id} + 100, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes'), (${dynamic_id} + 12, ${dynamic_id} + 4, ${dynamic_id} + 1, ${dynamic_id} + 101, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes'), (${dynamic_id} + 13, ${dynamic_id} + 8, ${dynamic_id} + 2, ${dynamic_id} + 102, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes'), (${dynamic_id} + 14, ${dynamic_id} + 9, ${dynamic_id} + 2, ${dynamic_id} + 103, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes'), (${dynamic_id} + 15, ${dynamic_id} + 10, ${dynamic_id} + 2, ${dynamic_id} + 104, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes')
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ลาน A
    Should Contain    ${body}    ฿40/ชม.
    Should Contain    ${body}    3/5
    Should Contain    ${body}    ลาน B
    Should Contain    ${body}    ฿60/ชม.
    Should Contain    ${body}    0/3
    Should Contain    ${body}    เต็ม
    [Teardown]    Cleanup Test Case Data TC-003    ${dynamic_id}

TC-004_Verify_GET_web_lots_returns_200_and_renders_the_lot_list_page_heading
    [Documentation]    Verify GET /web/lots returns 200 and renders the lot-list page heading
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ลานจอดทั้งหมด

TC-005_Verify_GET_web_lots_id_availability_fragment_returns_available_total_spots_matching_the_JSON_API
    [Documentation]    Verify GET /web/lots/{id}/availability-fragment returns available/total_spots matching the JSON API GET /lots/{id}/availability exactly
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 100, 'Driver A', 'driver_${dynamic_id}_100@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 1, 'ลานจอดสีฟ้า', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-01', true), (${dynamic_id} + 3, ${dynamic_id} + 1, 'A-02', true), (${dynamic_id} + 4, ${dynamic_id} + 1, 'A-03', true)
    Execute Sql String    INSERT INTO reservations (id, spot_id, lot_id, driver_id, status, start_time, end_time) VALUES (${dynamic_id} + 5, ${dynamic_id} + 2, ${dynamic_id} + 1, ${dynamic_id} + 100, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes')
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots/${dynamic_id + 1}/availability-fragment    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    2/3
    ${resp_json}=    GET On Session    api    /lots/${dynamic_id + 1}/availability    expected_status=any
    Status Should Be    200    ${resp_json}
    ${json}=    Set Variable    ${resp_json.json()}
    Should Be Equal As Integers    ${json}[available]    2
    Should Be Equal As Integers    ${json}[total_spots]    3
    [Teardown]    Cleanup Test Case Data TC-005    ${dynamic_id}

TC-006_Verify_GET_web_lots_id_availability_fragment_shows_เต็ม_badge_when_available_0
    [Documentation]    Verify GET /web/lots/{id}/availability-fragment shows 'เต็ม' badge when available == 0
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 100, 'Driver A', 'driver_${dynamic_id}_100@test.com'), (${dynamic_id} + 101, 'Driver B', 'driver_${dynamic_id}_101@test.com')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 1, 'ลานเต็ม', ${dynamic_id}, 50, '5678')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'B-01', true), (${dynamic_id} + 3, ${dynamic_id} + 1, 'B-02', true)
    Execute Sql String    INSERT INTO reservations (id, spot_id, lot_id, driver_id, status, start_time, end_time) VALUES (${dynamic_id} + 4, ${dynamic_id} + 2, ${dynamic_id} + 1, ${dynamic_id} + 100, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes'), (${dynamic_id} + 5, ${dynamic_id} + 3, ${dynamic_id} + 1, ${dynamic_id} + 101, 'CONFIRMED', NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes')
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots/${dynamic_id + 1}/availability-fragment    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    0/2
    Should Contain    ${body}    เต็ม
    [Teardown]    Cleanup Test Case Data TC-006    ${dynamic_id}

TC-007_Verify_GET_web_lots_id_availability_fragment_with_unknown_lot_id_returns_200_with_inline_Lot_not_found_text
    [Documentation]    Verify GET /web/lots/{id}/availability-fragment with unknown lot_id returns 200 with inline 'Lot not found' text
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(900000000, 999999999)    modules=random
    ${resp}=    GET On Session    api    /web/lots/${non_existent_id}/availability-fragment    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Lot not found

TC-008_Verify_the_availability_fragment_is_wired_with_hx_get_hx_trigger_every_30s_and_hx_swap_outerHTML
    [Documentation]    Verify the availability fragment is wired with hx-get, hx-trigger every 30s, and hx-swap=outerHTML
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 1, 'ลานจอดสีฟ้า', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-01', true), (${dynamic_id} + 3, ${dynamic_id} + 1, 'A-02', true), (${dynamic_id} + 4, ${dynamic_id} + 1, 'A-03', true)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    hx-get="/web/lots/
    Should Contain    ${body}    hx-trigger="every 30s"
    Should Contain    ${body}    hx-swap="outerHTML"
    [Teardown]    Cleanup Test Case Data TC-008    ${dynamic_id}

TC-009_Verify_GET_web_lots_escapes_HTML_in_lot_names
    [Documentation]    Verify GET /web/lots escapes HTML in lot names — a name containing <script> is rendered as text, not executed
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 1, '<script>alert(1)</script>', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-01', true), (${dynamic_id} + 3, ${dynamic_id} + 1, 'A-02', true), (${dynamic_id} + 4, ${dynamic_id} + 1, 'A-03', true)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    &lt;script&gt;alert(1)&lt;/script&gt;
    [Teardown]    Cleanup Test Case Data TC-009    ${dynamic_id}

TC-010_Verify_GET_web_lots_renders_hourly_rate_in_the_exact_delivered_format_฿40_ชม
    [Documentation]    Verify GET /web/lots renders hourly_rate in the exact delivered format '฿40/ชม.' (symbol first, no space)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 1, 'ลานจอดสีฟ้า', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 2, ${dynamic_id} + 1, 'A-01', true), (${dynamic_id} + 3, ${dynamic_id} + 1, 'A-02', true), (${dynamic_id} + 4, ${dynamic_id} + 1, 'A-03', true)
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ฿40/ชม.
    [Teardown]    Cleanup Test Case Data TC-010    ${dynamic_id}

TC-011_Verify_GET_web_lots_shows_เต็ม_badge_for_a_lot_with_zero_spots
    [Documentation]    Verify GET /web/lots shows 'เต็ม' badge for a lot with zero spots (total_spots == 0)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 1, 'ลานว่างเปล่า', ${dynamic_id}, 30, '9012')
    Create Global API Session
    ${resp}=    GET On Session    api    /web/lots    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ลานว่างเปล่า
    Should Contain    ${body}    ฿30/ชม.
    Should Contain    ${body}    0/0
    Should Contain    ${body}    เต็ม
    [Teardown]    Cleanup Test Case Data TC-011    ${dynamic_id}

*** Keywords ***
Cleanup Test Case Data TC-001
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${id} + 2, ${id} + 3, ${id} + 4)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Case Data TC-002
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id IN (${id} + 4, ${id} + 5)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${id} + 2, ${id} + 3)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id IN (${id} + 100, ${id} + 101)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Case Data TC-003
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id IN (${id} + 11, ${id} + 12, ${id} + 13, ${id} + 14, ${id} + 15)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${id} + 3, ${id} + 4, ${id} + 5, ${id} + 6, ${id} + 7, ${id} + 8, ${id} + 9, ${id} + 10)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id IN (${id} + 1, ${id} + 2)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id IN (${id} + 100, ${id} + 101, ${id} + 102, ${id} + 103, ${id} + 104)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Case Data TC-005
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id} + 5
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${id} + 2, ${id} + 3, ${id} + 4)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id} + 100
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Case Data TC-006
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id IN (${id} + 4, ${id} + 5)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${id} + 2, ${id} + 3)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id IN (${id} + 100, ${id} + 101)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Case Data TC-008
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${id} + 2, ${id} + 3, ${id} + 4)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Case Data TC-009
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${id} + 2, ${id} + 3, ${id} + 4)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Case Data TC-010
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id IN (${id} + 2, ${id} + 3, ${id} + 4)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Test Case Data TC-011
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database