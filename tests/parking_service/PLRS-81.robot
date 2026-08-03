*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_API_accepts_same_day_2_hour_window
    [Documentation]    Verify POST /bookings accepts a same-day 2-hour window and returns 201 with price 80
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Integers    ${json}[lock_ttl_sec]    300
    Should Be Equal As Integers    ${json}[price]    80
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-002_Verify_API_accepts_overnight_2_hour_window
    [Documentation]    Verify POST /bookings accepts an overnight 2-hour window crossing midnight
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Integers    ${json}[lock_ttl_sec]    300
    Should Be Equal As Integers    ${json}[price]    80
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-003_Verify_API_accepts_multi_day_43_5_hour_window
    [Documentation]    Verify POST /bookings accepts a multi-day 43.5-hour window with price 1760
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=2670)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Integers    ${json}[lock_ttl_sec]    300
    Should Be Equal As Integers    ${json}[price]    1760
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-004_Verify_API_accepts_multi_week_168_hour_window
    [Documentation]    Verify POST /bookings accepts a multi-week 168-hour window with price 6720
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=10140)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Integers    ${json}[lock_ttl_sec]    300
    Should Be Equal As Integers    ${json}[price]    6720
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-005_Verify_API_returns_400_when_start_at_equals_end_at
    [Documentation]    Verify POST /bookings returns 400 when start_at equals end_at
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${start_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time must be before end time
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-006_Verify_API_returns_400_when_start_at_after_end_at
    [Documentation]    Verify POST /bookings returns 400 when start_at is after end_at
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time must be before end time
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-007_Verify_API_returns_400_when_driver_id_missing
    [Documentation]    Verify POST /bookings returns 400 when driver_id is missing
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Driver ID is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE lot_id = ${lot_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-008_Verify_API_returns_400_when_lot_id_missing
    [Documentation]    Verify POST /bookings returns 400 when lot_id is missing
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot ID is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-009_Verify_API_returns_400_when_start_at_missing
    [Documentation]    Verify POST /bookings returns 400 when start_at is missing
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Start time is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-010_Verify_API_returns_400_when_end_at_missing
    [Documentation]    Verify POST /bookings returns 400 when end_at is missing
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    End time is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-011_Verify_API_returns_400_for_legacy_start_time_end_time
    [Documentation]    Verify POST /bookings returns 400 with migration message for legacy start_time/end_time
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_time=14:00    end_time=16:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    start_time/end_time are no longer supported — use start_at/end_at with full ISO 8601 datetimes
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-012_Verify_API_returns_400_for_legacy_overnight_flag
    [Documentation]    Verify POST /bookings returns 400 with migration message for legacy overnight flag
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}    overnight=${True}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    overnight is no longer supported — use start_at/end_at with full ISO 8601 datetimes
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-013_Verify_API_returns_400_for_injection_in_start_at
    [Documentation]    Verify an unparseable start_at is answered by naming the field and expected format
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at='; DROP TABLE drivers;--    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    start_at must be an ISO 8601 datetime
    ${count}=    Query    SELECT count(*) FROM drivers WHERE id = ${driver_id}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-014_Verify_API_returns_409_on_overlapping_window
    [Documentation]    Verify POST /bookings returns 409 when the requested window overlaps an existing reservation
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    Execute Sql String    INSERT INTO reservations (driver_id, lot_id, spot_id, start_time, end_time, status, lock_expires_at) VALUES (${driver_id}, ${lot_id}, ${spot_id}, NOW() + INTERVAL '1 hour', NOW() + INTERVAL '3 hours', 'SOFT_LOCKED', NOW() + INTERVAL '5 minutes')
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=120)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=240)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    409    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    No free spot available for the requested window
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-015_Verify_API_returns_409_when_lot_has_no_active_spots
    [Documentation]    Verify POST /bookings returns 409 when the lot has no active spots
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    Execute Sql String    UPDATE spots SET is_active = false WHERE id = ${spot_id}
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    409    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    No free spot available for the requested window
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-016_Verify_API_succeeds_when_soft_lock_expired
    [Documentation]    Verify POST /bookings succeeds for a multi-day window when an existing soft-lock has expired
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    Execute Sql String    INSERT INTO reservations (driver_id, lot_id, spot_id, start_time, end_time, status, lock_expires_at) VALUES (${driver_id}, ${lot_id}, ${spot_id}, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '1 hour', 'SOFT_LOCKED', NOW() - INTERVAL '5 minutes')
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${payload}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Integers    ${json}[lock_ttl_sec]    300
    Should Be Equal As Integers    ${json}[price]    80
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    2
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-017_Verify_web_booking_form_renders
    [Documentation]    Verify GET /web/bookings/new renders the booking form with datetime-local inputs and htmx wiring
    Create Global API Session
    ${resp}=    GET On Session    api    /web/bookings/new    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    type="datetime-local"
    Should Contain    ${body}    name="start_at"
    Should Contain    ${body}    name="end_at"
    Should Contain    ${body}    hx-post="/web/bookings"
    Should Contain    ${body}    hx-target="#result"
    Should Contain    ${body}    id="result"
    Should Contain    ${body}    hx-get="/web/bookings/estimate?lot_id=
    Should Contain    ${body}    hx-target="#estimate"
    Should Contain    ${body}    id="estimate"

TC-018_Verify_web_estimate_returns_price_fragment
    [Documentation]    Verify GET /web/bookings/estimate returns the estimated price fragment for a 2-hour window
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${params}=    Create Dictionary    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    GET On Session    api    /web/bookings/estimate    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ราคาประเมิน ฿80
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

TC-019_Verify_web_booking_form_creates_reservation
    [Documentation]    Verify the web booking form creates a reservation and the fragment shows price and lock countdown
    ${driver_id}    ${lot_id}    ${spot_id}    ${owner_id}=    Seed Booking Fixture
    ${start_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=60)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${end_at}=    Evaluate    (datetime.datetime.utcnow() + datetime.timedelta(minutes=180)).strftime('%Y-%m-%dT%H:%M:%SZ')    modules=datetime
    ${form}=    Create Dictionary    driver_id=${driver_id}    lot_id=${lot_id}    start_at=${start_at}    end_at=${end_at}
    ${resp}=    POST On Session    api    /web/bookings    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองสำเร็จ
    Should Contain    ${body}    ที่จอดถูกล็อกไว้
    Should Contain    ${body}    ฿80
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver_id} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}

*** Keywords ***
Seed Booking Fixture
    [Documentation]    Seed owner -> driver -> lot -> spot with a shared dynamic id; returns the ids.
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${driver_id}=    Evaluate    ${dynamic_id} + 1
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${spot_id}=    Evaluate    ${dynamic_id} + 3
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${driver_id}, 'Driver ${driver_id}', 'driver_${driver_id}@test.com', 'KK${driver_id}')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${lot_id}, 'Lot ${lot_id}', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-${spot_id}', true)
    RETURN    ${driver_id}    ${lot_id}    ${spot_id}    ${dynamic_id}

Cleanup Booking Test Data
    [Arguments]    ${driver_id}    ${spot_id}    ${lot_id}    ${owner_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${owner_id}
    Run Keyword And Ignore Error    Disconnect From Global Database