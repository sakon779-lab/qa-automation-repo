*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_estimate_returns_200_with_price_80_for_overnight_2300_to_0100
    [Documentation]    Verify GET /web/bookings/estimate returns 200 with price ฿80 for overnight=true 23:00->01:00
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${dynamic_id}, 40)
    Create Global API Session

    ${params}=    Create Dictionary    lot_id=${lot_id}    start_time=23:00    end_time=01:00    overnight=true
    ${resp}=    GET On Session    api    /web/bookings/estimate    params=${params}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ราคาประเมิน ฿80

    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-002_Verify_GET_estimate_returns_200_with_price_40_for_overnight_2359_to_0001
    [Documentation]    Verify GET /web/bookings/estimate returns 200 with price ฿40 for overnight=true 23:59->00:01
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${dynamic_id}, 40)
    Create Global API Session

    ${params}=    Create Dictionary    lot_id=${lot_id}    start_time=23:59    end_time=00:01    overnight=true
    ${resp}=    GET On Session    api    /web/bookings/estimate    params=${params}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ราคาประเมิน ฿40

    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-003_Verify_GET_estimate_returns_200_with_price_960_for_overnight_1000_to_1000
    [Documentation]    Verify GET /web/bookings/estimate returns 200 with price ฿960 for overnight=true 10:00->10:00
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${dynamic_id}, 40)
    Create Global API Session

    ${params}=    Create Dictionary    lot_id=${lot_id}    start_time=10:00    end_time=10:00    overnight=true
    ${resp}=    GET On Session    api    /web/bookings/estimate    params=${params}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ราคาประเมิน ฿960

    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-004_Verify_GET_estimate_returns_inline_error_when_overnight_end_after_start
    [Documentation]    Verify GET /web/bookings/estimate returns 200 with inline error when overnight=true and end_time is after start_time
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${dynamic_id}, 40)
    Create Global API Session

    ${params}=    Create Dictionary    lot_id=${lot_id}    start_time=09:00    end_time=17:00    overnight=true
    ${resp}=    GET On Session    api    /web/bookings/estimate    params=${params}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Overnight booking requires an end time at or before the start time

    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-005_Verify_GET_estimate_returns_200_with_price_320_for_same_day_0900_to_1700
    [Documentation]    Verify GET /web/bookings/estimate returns 200 with price ฿320 for same-day booking 09:00->17:00
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${dynamic_id}, 40)
    Create Global API Session

    ${params}=    Create Dictionary    lot_id=${lot_id}    start_time=09:00    end_time=17:00
    ${resp}=    GET On Session    api    /web/bookings/estimate    params=${params}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ราคาประเมิน ฿320

    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-006_Verify_GET_estimate_returns_inline_error_when_start_after_end_same_day
    [Documentation]    Verify GET /web/bookings/estimate returns 200 with inline error when start_time >= end_time
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${dynamic_id}, 40)
    Create Global API Session

    ${params}=    Create Dictionary    lot_id=${lot_id}    start_time=17:00    end_time=09:00
    ${resp}=    GET On Session    api    /web/bookings/estimate    params=${params}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Start time must be before end time

    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-007_Verify_GET_estimate_converts_checkbox_on_to_true_returns_price_80
    [Documentation]    Verify GET /web/bookings/estimate converts HTML checkbox value overnight='on' to true
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${dynamic_id}, 40)
    Create Global API Session

    ${params}=    Create Dictionary    lot_id=${lot_id}    start_time=23:00    end_time=01:00    overnight=on
    ${resp}=    GET On Session    api    /web/bookings/estimate    params=${params}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ราคาประเมิน ฿80

    [Teardown]    Cleanup Parking Test Data    ${dynamic_id}

TC-008_Verify_POST_bookings_creates_soft_locked_reservation_for_overnight_on
    [Documentation]    Verify POST /web/bookings returns 200 with success fragment for overnight='on' 23:00->01:00
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${spot_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Seed Driver', 'driver_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${owner_id}, 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A1', true)
    Create Global API Session

    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${lot_id}    start_time=23:00    end_time=01:00    overnight=on
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ฿80
    Should Contain    ${body}    ยืนยันจ่าย
    Should Contain    ${body}    300

    ${result}=    Query    SELECT status FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Strings    ${result[0][0]}    SOFT_LOCKED

    [Teardown]    Cleanup Booking Test Data    ${dynamic_id}

TC-009_Verify_POST_bookings_returns_inline_error_when_overnight_end_after_start
    [Documentation]    Verify POST /web/bookings returns 200 with inline error when overnight='on' and end_time is after start_time
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${spot_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Seed Driver', 'driver_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${owner_id}, 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A1', true)
    Create Global API Session

    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${lot_id}    start_time=09:00    end_time=17:00    overnight=on
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Overnight booking requires an end time at or before the start time

    ${result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${result[0][0]}    0

    [Teardown]    Cleanup Booking Test Data    ${dynamic_id}

TC-010_Verify_POST_bookings_creates_soft_locked_reservation_for_same_day
    [Documentation]    Verify POST /web/bookings returns 200 with success fragment for same-day booking 09:00->17:00
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${spot_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Seed Driver', 'driver_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${owner_id}, 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A1', true)
    Create Global API Session

    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${lot_id}    start_time=09:00    end_time=17:00
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ฿320
    Should Contain    ${body}    ยืนยันจ่าย
    Should Contain    ${body}    300

    ${result}=    Query    SELECT status FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Strings    ${result[0][0]}    SOFT_LOCKED

    [Teardown]    Cleanup Booking Test Data    ${dynamic_id}

TC-011_Verify_POST_bookings_returns_inline_error_when_start_after_end_same_day
    [Documentation]    Verify POST /web/bookings returns 200 with inline error when start_time >= end_time
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${spot_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Seed Driver', 'driver_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${owner_id}, 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A1', true)
    Create Global API Session

    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${lot_id}    start_time=17:00    end_time=09:00
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Start time must be before end time

    ${result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${result[0][0]}    0

    [Teardown]    Cleanup Booking Test Data    ${dynamic_id}

TC-012_Verify_POST_bookings_returns_inline_error_when_driver_id_missing
    [Documentation]    Verify POST /web/bookings returns 200 with inline error when driver_id is missing
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${spot_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Seed Driver', 'driver_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${owner_id}, 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A1', true)
    Create Global API Session

    ${form}=    Create Dictionary    lot_id=${lot_id}    start_time=23:00    end_time=01:00    overnight=on
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Driver ID is required

    ${result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${result[0][0]}    0

    [Teardown]    Cleanup Booking Test Data    ${dynamic_id}

TC-013_Verify_POST_bookings_returns_inline_error_when_lot_id_missing
    [Documentation]    Verify POST /web/bookings returns 200 with inline error when lot_id is missing
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${spot_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Seed Driver', 'driver_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${owner_id}, 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A1', true)
    Create Global API Session

    ${form}=    Create Dictionary    driver_id=${dynamic_id}    start_time=23:00    end_time=01:00    overnight=on
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Lot ID is required

    ${result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${result[0][0]}    0

    [Teardown]    Cleanup Booking Test Data    ${dynamic_id}

TC-014_Verify_POST_bookings_returns_inline_error_when_start_time_missing
    [Documentation]    Verify POST /web/bookings returns 200 with inline error when start_time is missing
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${spot_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Seed Driver', 'driver_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${owner_id}, 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A1', true)
    Create Global API Session

    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${lot_id}    end_time=01:00    overnight=on
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Start time is required

    ${result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${result[0][0]}    0

    [Teardown]    Cleanup Booking Test Data    ${dynamic_id}

TC-015_Verify_POST_bookings_returns_inline_error_when_end_time_missing
    [Documentation]    Verify POST /web/bookings returns 200 with inline error when end_time is missing
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${spot_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Seed Driver', 'driver_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${owner_id}, 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A1', true)
    Create Global API Session

    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${lot_id}    start_time=23:00    overnight=on
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    End time is required

    ${result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${result[0][0]}    0

    [Teardown]    Cleanup Booking Test Data    ${dynamic_id}

TC-016_Verify_POST_bookings_returns_inline_error_when_no_free_spot
    [Documentation]    Verify POST /web/bookings returns 200 with inline error when no free spot is available
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Seed Driver', 'driver_${dynamic_id}@plrs.test')
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${owner_id}, 'Seed Owner', 'owner_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${lot_id}, 'Seed Lot', ${owner_id}, 40)
    Create Global API Session

    ${form}=    Create Dictionary    driver_id=${dynamic_id}    lot_id=${lot_id}    start_time=23:00    end_time=01:00    overnight=on
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    No free spot available for the requested window

    ${result}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${dynamic_id}
    Should Be Equal As Integers    ${result[0][0]}    0

    [Teardown]    Cleanup Booking Test Data    ${dynamic_id}

TC-017_Verify_GET_bookings_new_renders_form_with_checkbox_and_htmx_wiring
    [Documentation]    Verify GET /web/bookings/new renders the booking form with the overnight checkbox and correct htmx wiring
    Create Global API Session

    ${resp}=    GET On Session    api    /web/bookings/new    expected_status=any

    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองที่จอด
    Should Contain    ${body}    /ชม.
    Should Contain    ${body}    hx-get="/web/bookings/estimate?lot_id=
    Should Contain    ${body}    hx-target="#estimate"
    Should Contain    ${body}    id="estimate"
    Should Contain    ${body}    hx-post="/web/bookings"
    Should Contain    ${body}    hx-target="#result"
    Should Contain    ${body}    id="result"
    Should Contain    ${body}    hx-trigger="change"

*** Keywords ***
Cleanup Booking Test Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id} + 3
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 2
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id} + 1
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database