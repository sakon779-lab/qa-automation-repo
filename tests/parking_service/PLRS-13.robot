*** Settings ***
Documentation     PLRS-13 — POST /bookings/{id}/confirm. Generated from test_designs/PLRS-13.csv;
...               error messages are the design contract verbatim. Each test seeds its OWN parent
...               chain (drivers → lots → spots → reservations) with dynamic ids, arms the
...               MockServer /charge reply via the shared keyword, and cleans up after itself.
Library           RequestsLibrary
Library           Collections
Library           DatabaseLibrary
Resource          ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Confirm_Valid_Soft_Locked_Booking
    [Documentation]    Valid SOFT_LOCKED booking → 200 CONFIRMED + PAID payment recorded
    ${ids}=    Seed Reservation    status=SOFT_LOCKED    lock_offset_sec=300
    Arm Mock Expectation    POST    /charge    200    {"status": "SUCCESS", "txn_id": "mock_txn_888"}
    Create Session    api    ${BASE_API_URL}
    ${resp}=    POST On Session    api    /bookings/${ids}[res]/confirm    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    CONFIRMED
    Should Be Equal As Numbers    ${json}[amount]    80
    Should Be True    ${json}[payment_id] > 0
    # Post-Assertion from CSV: a PAID BOOKING payment row exists for this reservation
    ${db_count}=    Query    SELECT count(*) FROM payments WHERE reservation_id = ${ids}[res] AND kind = 'BOOKING' AND status = 'PAID'
    Should Be Equal As Integers    ${db_count[0][0]}    1
    [Teardown]    Cleanup Booking Data    ${ids}

TC-002_Confirm_Expired_Soft_Lock_Returns_409
    [Documentation]    SOFT_LOCKED with lock_expires_at in the past → 409 contract-verbatim
    ${ids}=    Seed Reservation    status=SOFT_LOCKED    lock_offset_sec=-300
    Arm Mock Expectation    POST    /charge    200    {"status": "SUCCESS", "txn_id": "mock_txn_888"}
    Create Session    api    ${BASE_API_URL}
    ${resp}=    POST On Session    api    /bookings/${ids}[res]/confirm    expected_status=any
    Status Should Be    409    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Booking has expired. Please re-book.
    [Teardown]    Cleanup Booking Data    ${ids}

TC-003_Confirm_Already_Confirmed_Returns_409
    [Documentation]    Already CONFIRMED booking → 409 contract-verbatim
    ${ids}=    Seed Reservation    status=CONFIRMED    lock_offset_sec=300
    Arm Mock Expectation    POST    /charge    200    {"status": "SUCCESS", "txn_id": "mock_txn_888"}
    Create Session    api    ${BASE_API_URL}
    ${resp}=    POST On Session    api    /bookings/${ids}[res]/confirm    expected_status=any
    Status Should Be    409    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Booking is already confirmed.
    [Teardown]    Cleanup Booking Data    ${ids}

TC-004_Confirm_Nonexistent_Booking_Returns_404
    [Documentation]    Unknown booking id → 404 contract-verbatim (no seeds → no teardown)
    Create Session    api    ${BASE_API_URL}
    ${resp}=    POST On Session    api    /bookings/999999/confirm    expected_status=any
    Status Should Be    404    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Booking not found

*** Keywords ***
Seed Reservation
    [Documentation]    Seed the FULL parent chain with dynamic ids (drivers → lots → spots), then the
    ...                reservation itself. Returns a dict of the ids for the test + teardown.
    [Arguments]    ${status}    ${lock_offset_sec}
    Connect To Global Database
    ${d_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${l_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${s_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${r_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${d_id}, 'Robot Driver', 'robot_${d_id}@test.plrs')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${l_id}, 'Robot Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${s_id}, ${l_id}, 'R-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${r_id}, ${d_id}, ${s_id}, ${l_id}, NOW(), NOW() + INTERVAL '2 hours', '${status}', 80.00, NOW() + INTERVAL '${lock_offset_sec} seconds')
    ${ids}=    Create Dictionary    driver=${d_id}    lot=${l_id}    spot=${s_id}    res=${r_id}
    RETURN    ${ids}

Cleanup Booking Data
    [Documentation]    Child-first cleanup of everything Seed Reservation created + reset MockServer.
    [Arguments]    ${ids}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM payments WHERE reservation_id = ${ids}[res]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${ids}[res]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${ids}[spot]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${ids}[lot]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${ids}[driver]
    Disconnect From Global Database
