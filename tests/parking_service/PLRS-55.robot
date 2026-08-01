*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_API_accepts_overnight_booking
    [Documentation]    Verify API accepts overnight booking 23:00 -> 01:00 with price 80 (2 hours at rate 40)
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=23:00    end_time=01:00    overnight=${TRUE}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Strings    ${json}[lock_ttl_sec]    300
    Should Be Equal As Strings    ${json}[price]    80
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-002_Verify_API_accepts_overnight_booking_2359_to_0001
    [Documentation]    Verify API accepts overnight booking 23:59 -> 00:01 with price 40 (2 minutes ceil to 1 hour at rate 40)
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=23:59    end_time=00:01    overnight=${TRUE}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Strings    ${json}[lock_ttl_sec]    300
    Should Be Equal As Strings    ${json}[price]    40
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-003_Verify_API_accepts_overnight_booking_full_24_hour
    [Documentation]    Verify API accepts overnight booking 10:00 -> 10:00 as full 24-hour window with price 960 (24 hours at rate 40)
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=10:00    end_time=10:00    overnight=${TRUE}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Strings    ${json}[lock_ttl_sec]    300
    Should Be Equal As Strings    ${json}[price]    960
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-004_Verify_API_returns_400_when_overnight_contradictory
    [Documentation]    Verify API returns 400 when overnight=true but end_time is later than start_time (contradictory flag)
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=08:00    end_time=10:00    overnight=${TRUE}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Overnight booking requires an end time at or before the start time
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-005_Verify_API_accepts_same_day_booking_backward_compat
    [Documentation]    Verify API accepts same-day booking 08:00 -> 10:00 without overnight flag (backward compat) with price 80
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=08:00    end_time=10:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Strings    ${json}[lock_ttl_sec]    300
    Should Be Equal As Strings    ${json}[price]    80
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-006_Verify_API_returns_400_when_same_day_start_after_end
    [Documentation]    Verify API returns 400 when same-day start_time >= end_time without overnight flag (backward compat: 12:00 -> 10:00)
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=12:00    end_time=10:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time must be before end time
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-007_Verify_API_returns_400_when_same_day_start_equals_end
    [Documentation]    Verify API returns 400 when same-day start_time equals end_time without overnight flag (backward compat: 10:00 -> 10:00)
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=10:00    end_time=10:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time must be before end time
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-008_Verify_API_returns_409_when_overnight_conflicts_with_overnight
    [Documentation]    Verify API returns 409 when overnight booking 23:00 -> 01:00 conflicts with existing overnight reservation 22:00 -> 00:30
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${res_id}=    Evaluate    ${id} + 4
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${res_id}, ${driver}, ${lot}, ${spot}, '2024-01-15 22:00:00', '2024-01-16 00:30:00', 'SOFT_LOCKED')
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=23:00    end_time=01:00    overnight=${TRUE}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    409    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    No free spot available for the requested window
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-009_Verify_API_returns_409_when_overnight_conflicts_with_next_morning
    [Documentation]    Verify API returns 409 when overnight booking 23:00 -> 01:00 conflicts with existing next-morning same-day reservation 00:00 -> 00:30
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${res_id}=    Evaluate    ${id} + 4
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${res_id}, ${driver}, ${lot}, ${spot}, '2024-01-16 00:00:00', '2024-01-16 00:30:00', 'SOFT_LOCKED')
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=23:00    end_time=01:00    overnight=${TRUE}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    409    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    No free spot available for the requested window
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-010_Verify_API_returns_409_when_same_day_conflicts_with_overnight
    [Documentation]    Verify API returns 409 when same-day booking 00:30 -> 01:00 conflicts with existing overnight reservation 23:00 -> 01:00
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${res_id}=    Evaluate    ${id} + 4
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${res_id}, ${driver}, ${lot}, ${spot}, '2024-01-15 23:00:00', '2024-01-16 01:00:00', 'SOFT_LOCKED')
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=00:30    end_time=01:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    409    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    No free spot available for the requested window
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-011_Verify_API_accepts_overnight_booking_touching_edges
    [Documentation]    Verify API accepts overnight booking 23:00 -> 01:00 when existing reservation ends exactly at 01:00 (touching edges do not conflict)
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${res_id}=    Evaluate    ${id} + 4
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status) VALUES (${res_id}, ${driver}, ${lot}, ${spot}, '2024-01-16 01:00:00', '2024-01-16 02:00:00', 'SOFT_LOCKED')
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=23:00    end_time=01:00    overnight=${TRUE}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Strings    ${json}[lock_ttl_sec]    300
    Should Be Equal As Strings    ${json}[price]    80
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    2
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-012_Verify_API_returns_400_when_driver_id_missing
    [Documentation]    Verify API returns 400 when driver_id is missing
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    lot_id=${lot}    start_time=08:00    end_time=10:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Driver ID is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-013_Verify_API_returns_400_when_lot_id_missing
    [Documentation]    Verify API returns 400 when lot_id is missing
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    start_time=08:00    end_time=10:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot ID is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-014_Verify_API_returns_400_when_start_time_missing
    [Documentation]    Verify API returns 400 when start_time is missing
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    end_time=10:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-015_Verify_API_returns_400_when_end_time_missing
    [Documentation]    Verify API returns 400 when end_time is missing
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=08:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    End time is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-016_Verify_API_returns_400_when_start_time_sql_injection
    [Documentation]    Verify API returns 400 when start_time contains SQL injection string and no DB write occurs
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=''; DROP TABLE drivers;--    end_time=10:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time must be before end time
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

TC-017_Verify_API_accepts_overnight_truthy_string
    [Documentation]    Verify API accepts overnight booking when overnight is sent as non-boolean truthy string 'yes' (coerced to true, no 500)
    ${driver}    ${lot}    ${spot}    ${id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_time=23:00    end_time=01:00    overnight=yes
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Strings    ${json}[lock_ttl_sec]    300
    Should Be Equal As Strings    ${json}[price]    80
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND lot_id = ${lot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver}    ${lot}    ${spot}    ${id}

*** Keywords ***
Seed Booking Fixture
    [Documentation]    Seed owner -> driver -> lot -> spot; returns the ids the tests need.
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${driver}=    Evaluate    ${id} + 1
    ${lot}=       Evaluate    ${id} + 2
    ${spot}=      Evaluate    ${id} + 3
    Connect To Global Database
    Create Global API Session
    Execute Sql String    INSERT INTO owners (id, name, email) VALUES (${id}, 'Seed Owner', 'owner_${id}@test.com')
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver}, 'Seed Driver', 'driver_${driver}@test.com', 'KK1234')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${lot}, ${id}, 'Seed Lot', 40, 'W1')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot}, ${lot}, 'A1', true)
    RETURN    ${driver}    ${lot}    ${spot}    ${id}

Cleanup Booking Test Data
    [Arguments]    ${driver}    ${lot}    ${spot}    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = ${driver}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${driver}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database
