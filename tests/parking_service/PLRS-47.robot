*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_the_booking_page_renders_the_lot_name_and_its_hourly_rate
    [Documentation]    Verify the booking page renders the lot name and its hourly rate
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', true)
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    url=/web/bookings/new?lot_id=${dynamic_id}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองที่จอด
    Should Contain    ${body}    Web Lot
    Should Contain    ${body}    ฿40/ชม.
    # htmx wiring — a typo here renders every word above and still 200s, while the fragment is
    # swapped into nothing. Assert the trigger AND that its target element actually exists.
    Should Contain    ${body}    hx-post="/web/bookings"
    Should Contain    ${body}    hx-target="#result"
    Should Contain    ${body}    id="result"
    Should Contain    ${body}    hx-target="#estimate"
    Should Contain    ${body}    id="estimate"
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-002_Verify_the_booking_page_shows_the_not_found_notice_for_an_unknown_lot
    [Documentation]    Verify the booking page shows the not-found notice for an unknown lot
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    url=/web/bookings/new?lot_id=999999    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ไม่พบลานจอด

TC-003_Verify_the_price_estimate_ceils_a_half_hour_to_one_hour_R3_10_00_10_30_at_rate_40_equals_40
    [Documentation]    Verify the price estimate ceils a half hour to one hour (R3): 10:00-10:30 at rate 40 = 40
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', true)
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    url=/web/bookings/estimate?lot_id=${dynamic_id}&start_time=10:00&end_time=10:30    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ราคาประเมิน ฿40
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-004_Verify_the_price_estimate_charges_3_hours_for_a_2_5_hour_window_R3_13_00_15_30_at_rate_40_equals_120
    [Documentation]    Verify the price estimate charges 3 hours for a 2.5 hour window (R3): 13:00-15:30 at rate 40 = 120
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', true)
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    url=/web/bookings/estimate?lot_id=${dynamic_id}&start_time=13:00&end_time=15:30    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ราคาประเมิน ฿120
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-005_Verify_the_price_estimate_shows_the_contract_error_when_end_time_precedes_start_time
    [Documentation]    Verify the price estimate shows the contract error when end time precedes start time
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', true)
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    url=/web/bookings/estimate?lot_id=${dynamic_id}&start_time=10:30&end_time=10:00    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Start time must be before end time
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-006_Verify_a_successful_booking_renders_the_price_the_300s_lock_countdown_and_the_confirm_button
    [Documentation]    Verify a successful booking renders the price, the 300s lock countdown and the confirm button
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', true)
    Create Session    api    ${BASE_API_URL}
    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${dynamic_id}    start_time=10:00    end_time=10:30
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ฿40
    Should Contain    ${body}    ยืนยันจ่าย
    Should Contain    ${body}    300
    # the confirm button must be wired back to the same swap target (see TC-001)
    Should Contain    ${body}    /confirm
    Should Contain    ${body}    hx-target="#result"
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${db_count_result[0][0]}    1
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-007_Verify_the_booking_fragment_shows_the_contract_error_when_the_lot_has_no_free_spot
    [Documentation]    Verify the booking fragment shows the contract error when the lot has no free spot
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', false)
    Create Session    api    ${BASE_API_URL}
    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${dynamic_id}    start_time=10:00    end_time=10:30
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    No free spot available
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-008_Verify_the_booking_fragment_shows_the_contract_error_when_driver_id_is_missing
    [Documentation]    Verify the booking fragment shows the contract error when driver id is missing
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', true)
    Create Session    api    ${BASE_API_URL}
    ${form}=    Create Dictionary    lot_id=${dynamic_id}    start_time=10:00    end_time=10:30
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Driver ID is required
    ${db_count_result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-009_Verify_confirming_a_live_soft_lock_charges_the_driver_and_renders_the_payment_receipt
    [Documentation]    Verify confirming a live soft lock charges the driver and renders the payment receipt
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '0 minutes', NOW() + INTERVAL '30 minutes', 'SOFT_LOCKED', 40, NOW() + INTERVAL '5 minutes')
    Arm Mock Expectation    POST    /charge    200    {"status": "SUCCESS", "txn_id": "mock_txn_888"}
    Create Session    api    ${BASE_API_URL}
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/bookings/${dynamic_id}/confirm    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    CONFIRMED
    Should Contain    ${body}    payment
    ${db_count_result1}=    Query    SELECT count(*) FROM reservations WHERE id = ${dynamic_id} AND status = 'CONFIRMED'
    Should Be Equal As Integers    ${db_count_result1[0][0]}    1
    ${db_count_result2}=    Query    SELECT count(*) FROM payments WHERE reservation_id = ${dynamic_id} AND kind = 'BOOKING' AND status = 'PAID'
    Should Be Equal As Integers    ${db_count_result2[0][0]}    1
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-010_Verify_confirming_after_the_soft_lock_expired_shows_the_contract_expiry_message
    [Documentation]    Verify confirming after the soft lock expired shows the contract expiry message
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '6 minutes', NOW() + INTERVAL '-5 minutes', 'SOFT_LOCKED', 40, NOW() - INTERVAL '1 minute')
    Create Session    api    ${BASE_API_URL}
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/bookings/${dynamic_id}/confirm    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Booking has expired. Please re-book.
    ${db_count_result}=    Query    SELECT count(*) FROM payments WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-011_Verify_confirming_an_already_confirmed_booking_shows_the_contract_duplicate_message
    [Documentation]    Verify confirming an already-confirmed booking shows the contract duplicate message
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Web Driver', 'webdrv_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Web Owner', 'webown_${dynamic_id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Web Lot', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'W-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '0 minutes', NOW() + INTERVAL '30 minutes', 'CONFIRMED', 40, NOW() + INTERVAL '5 minutes')
    Create Session    api    ${BASE_API_URL}
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/bookings/${dynamic_id}/confirm    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Booking is already confirmed.
    ${db_count_result}=    Query    SELECT count(*) FROM payments WHERE reservation_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

*** Keywords ***
Cleanup Test Case Data
    [Arguments]    ${id}
    Execute Sql String    DELETE FROM payments WHERE reservation_id = ${id}
    Execute Sql String    DELETE FROM reservations WHERE driver_id = ${id}
    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Disconnect From Global Database