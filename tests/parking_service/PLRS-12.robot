*** Settings ***
Documentation     PLRS-12 — S2.3 Concurrency guard (no double-hold) on POST /bookings.
...
...               The guard under test is Postgres `SELECT ... FOR UPDATE` inside one transaction:
...               two requests racing for the last free spot must yield exactly one 201 and one
...               409, never two holds. pytest cannot prove this (SQLite has no row locks), so the
...               race cases here — TC-010/TC-011 — are the card's actual proof, running against
...               the deployed QA stack on real Postgres.
...
...               Race cases fire both requests from a ThreadPoolExecutor via one Evaluate, using
...               raw requests.post per thread (a RequestsLibrary session is NOT thread-safe). The
...               winner is whichever transaction takes the lock first, so assertions are on the
...               SET of outcomes, never on which request won; the decisive proof is the DB count
...               in Post-Assertions, which is order-independent by construction.
Library           RequestsLibrary
Library           Collections
Library           DatabaseLibrary
Resource          ../../resources/projects/parking_service/config.robot

*** Keywords ***
Seed Booking Fixture
    [Documentation]    driver(+optional second) -> lot -> active spot; returns the ids.
    ...                Seeds is_active=true explicitly: the column is nullable with no default and
    ...                the handler filters `is_active IS TRUE`, so an unseeded flag makes every
    ...                spot invisible and every booking 409 (this exact slip broke the PLRS-12
    ...                deploy smoke before the contract was corrected).
    [Arguments]    ${two_drivers}=${FALSE}
    ${base}=      Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${driver}=    Set Variable    ${base}
    ${driver2}=   Evaluate    ${base} + 100
    ${lot}=       Evaluate    ${base} + 1
    ${spot}=      Evaluate    ${base} + 2
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${driver}, 'Driver ${base}', 'driver_${base}@test.com')
    IF    ${two_drivers}
        Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${driver2}, 'Driver ${base} B', 'driver_${base}_2@test.com')
    END
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${lot}, 'Lot ${base}', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot}, ${lot}, 'A1', true)
    RETURN    ${base}    ${driver}    ${driver2}    ${lot}    ${spot}

Cleanup Booking Test Data
    [Documentation]    Surgical, parallel-safe teardown — deletes only this test's rows.
    [Arguments]    ${base}
    Execute Sql String    DELETE FROM reservations WHERE driver_id IN (${base}, ${base} + 100)
    Execute Sql String    DELETE FROM spots WHERE id IN (${base} + 2, ${base} + 102)
    Execute Sql String    DELETE FROM lots WHERE id IN (${base} + 1, ${base} + 101)
    Execute Sql String    DELETE FROM drivers WHERE id IN (${base}, ${base} + 100)

Fire Two Bookings Concurrently
    [Documentation]    Submit BOTH requests to a 2-worker pool before waiting on either, so the
    ...                two are in flight together. Returns [[status, body], [status, body]].
    [Arguments]    ${p1}    ${p2}
    ${results}=    Evaluate
    ...    [[r.status_code, r.json()] for r in concurrent.futures.ThreadPoolExecutor(max_workers=2).map(lambda kw: requests.post('${BASE_API_URL}/bookings', json=kw, timeout=15), [$p1, $p2])]
    ...    modules=concurrent.futures,requests
    RETURN    ${results}

Assert Exactly One Winner
    [Documentation]    Order-independent race outcome: one 201 with the delivered success shape,
    ...                one 409 with the delivered detail string — in EITHER order.
    [Arguments]    ${results}    ${price}
    ${codes}=    Evaluate    sorted(r[0] for r in $results)
    Should Be Equal    ${codes}    ${{[201, 409]}}
    ${winner}=    Evaluate    next(r[1] for r in $results if r[0] == 201)
    ${loser}=     Evaluate    next(r[1] for r in $results if r[0] == 409)
    Should Be Equal As Strings    ${winner}[status]    SOFT_LOCKED
    Should Be Equal As Strings    ${winner}[lock_ttl_sec]    300
    Should Be Equal As Strings    ${winner}[price]    ${price}
    Should Be Equal As Strings    ${loser}[detail]    No free spot available for the requested window

Assert Both Succeed
    [Arguments]    ${results}
    ${codes}=    Evaluate    sorted(r[0] for r in $results)
    Should Be Equal    ${codes}    ${{[201, 201]}}
    FOR    ${r}    IN    @{results}
        Should Be Equal As Strings    ${r[1]}[status]    SOFT_LOCKED
    END


*** Variables ***
${BOOK_DAY}        2026-09-01
${BOOK_DAY_NEXT}   2026-09-02

*** Test Cases ***
TC-001_Same_Day_Booking_Returns_201_Soft_Locked
    [Documentation]    Baseline: POST /bookings 10:00->11:00 -> 201 SOFT_LOCKED price 40.
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Strings    ${json}[lock_ttl_sec]    300
    Should Be Equal As Strings    ${json}[price]    40
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND spot_id = ${spot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-002_Overnight_Booking_Returns_201_Price_80
    [Documentation]    23:00 -> 01:00 the next day = 201, 2 hours, price 80. Crossing
    ...                midnight needs no flag now — it is an ordinary window that names both of its days.
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_at=${BOOK_DAY}T23:00:00    end_at=${BOOK_DAY_NEXT}T01:00:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[status]    SOFT_LOCKED
    Should Be Equal As Strings    ${json}[price]    80
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver} AND spot_id = ${spot}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-003_Same_Day_Start_Not_Before_End_Returns_400
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T10:00:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Start time must be before end time
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-005_Missing_Driver_Id_Returns_400
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Driver ID is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE spot_id = ${spot}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-006_Missing_Lot_Id_Returns_400
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    driver_id=${driver}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Lot ID is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-007_Missing_Start_Time_Returns_400
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    end_at=${BOOK_DAY}T11:00:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Start time is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-008_Missing_End_Time_Returns_400
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    End time is required
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-009_Sql_Injection_In_Start_Time_Returns_400_No_Write
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00'; DROP TABLE reservations;--    end_at=${BOOK_DAY}T11:00:00
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    start_at must be an ISO 8601 datetime
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id = ${driver}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-010_Race_For_Last_Spot_Exactly_One_Wins
    [Documentation]    THE card's deliverable: two concurrent requests, same lot, one free spot,
    ...                identical window -> exactly one 201 and one 409, in either order, and
    ...                exactly ONE SOFT_LOCKED row in the database.
    Connect To Global Database
    ${base}    ${driver}    ${driver2}    ${lot}    ${spot}=    Seed Booking Fixture    two_drivers=${TRUE}
    ${p1}=    Create Dictionary    driver_id=${driver}     lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${p2}=    Create Dictionary    driver_id=${driver2}    lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${results}=    Fire Two Bookings Concurrently    ${p1}    ${p2}
    Assert Exactly One Winner    ${results}    40
    ${count}=    Query    SELECT count(*) FROM reservations WHERE spot_id = ${spot} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-011_Race_Overnight_Vs_Next_Morning_Exactly_One_Wins
    [Documentation]    The case that separates a correct guard from a plausible one: a window
    ...                running 23:00 into 01:00 the NEXT day races 00:30->01:00 on that next
    ...                morning for the same spot. PLRS-81 compares windows on the real timeline,
    ...                where the two genuinely share 00:30-01:00, so exactly one may win. Under
    ...                the retired clock-face model the second window was read as the SAME day
    ...                and the pair never met; naming the days is what makes the overlap real.
    Connect To Global Database
    ${base}    ${driver}    ${driver2}    ${lot}    ${spot}=    Seed Booking Fixture    two_drivers=${TRUE}
    ${p1}=    Create Dictionary    driver_id=${driver}     lot_id=${lot}    start_at=${BOOK_DAY}T23:00:00    end_at=${BOOK_DAY_NEXT}T01:00:00
    ${p2}=    Create Dictionary    driver_id=${driver2}    lot_id=${lot}    start_at=${BOOK_DAY_NEXT}T00:30:00    end_at=${BOOK_DAY_NEXT}T01:00:00
    ${results}=    Fire Two Bookings Concurrently    ${p1}    ${p2}
    ${codes}=    Evaluate    sorted(r[0] for r in $results)
    Should Be Equal    ${codes}    ${{[201, 409]}}
    ${loser}=    Evaluate    next(r[1] for r in $results if r[0] == 409)
    Should Be Equal As Strings    ${loser}[detail]    No free spot available for the requested window
    ${count}=    Query    SELECT count(*) FROM reservations WHERE spot_id = ${spot} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-012_Concurrent_Different_Spots_Same_Lot_Both_Succeed
    [Documentation]    Two free spots in the lot: concurrent identical windows must BOTH get 201 —
    ...                the guard must not over-serialize a lot that still has capacity.
    Connect To Global Database
    ${base}    ${driver}    ${driver2}    ${lot}    ${spot}=    Seed Booking Fixture    two_drivers=${TRUE}
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${base} + 102, ${lot}, 'A2', true)
    ${p1}=    Create Dictionary    driver_id=${driver}     lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${p2}=    Create Dictionary    driver_id=${driver2}    lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${results}=    Fire Two Bookings Concurrently    ${p1}    ${p2}
    Assert Both Succeed    ${results}
    ${count}=    Query    SELECT count(*) FROM reservations WHERE lot_id = ${lot} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    2
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-013_Concurrent_Touching_Windows_Same_Spot_Both_Succeed
    [Documentation]    10:00->11:00 and 11:00->12:00 share only a touching edge (half-open
    ...                windows) — both must get 201 on the SAME spot even when fired together.
    Connect To Global Database
    ${base}    ${driver}    ${driver2}    ${lot}    ${spot}=    Seed Booking Fixture    two_drivers=${TRUE}
    ${p1}=    Create Dictionary    driver_id=${driver}     lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${p2}=    Create Dictionary    driver_id=${driver2}    lot_id=${lot}    start_at=${BOOK_DAY}T11:00:00    end_at=${BOOK_DAY}T12:00:00
    ${results}=    Fire Two Bookings Concurrently    ${p1}    ${p2}
    Assert Both Succeed    ${results}
    ${count}=    Query    SELECT count(*) FROM reservations WHERE spot_id = ${spot} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    2
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-014_Expired_Soft_Lock_Frees_The_Spot
    [Documentation]    First booking soft-locks; its lock is forced past expiry; a second booking
    ...                for the same window succeeds -> 2 SOFT_LOCKED rows (one stale, one live).
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${first}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${first}
    Execute Sql String    UPDATE reservations SET lock_expires_at = NOW() - INTERVAL '1 minute' WHERE spot_id = ${spot}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    Should Be Equal As Strings    ${resp.json()}[status]    SOFT_LOCKED
    ${count}=    Query    SELECT count(*) FROM reservations WHERE spot_id = ${spot} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    2
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-015_Concurrent_Different_Lots_Both_Succeed
    [Documentation]    The lock is per-spot-row: two lots must never contend with each other.
    Connect To Global Database
    ${base}    ${driver}    ${driver2}    ${lot}    ${spot}=    Seed Booking Fixture    two_drivers=${TRUE}
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${base} + 101, 'Lot ${base} B', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${base} + 102, ${base} + 101, 'B1', true)
    ${lot_b}=    Evaluate    ${base} + 101
    ${p1}=    Create Dictionary    driver_id=${driver}     lot_id=${lot}      start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${p2}=    Create Dictionary    driver_id=${driver2}    lot_id=${lot_b}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${results}=    Fire Two Bookings Concurrently    ${p1}    ${p2}
    Assert Both Succeed    ${results}
    ${count}=    Query    SELECT count(*) FROM reservations WHERE driver_id IN (${driver}, ${driver2}) AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    2
    [Teardown]    Cleanup Booking Test Data    ${base}

TC-016_Sequential_Second_Booking_Same_Window_Returns_409
    [Documentation]    Non-race baseline: with the only spot already held, the same window 409s.
    Connect To Global Database
    ${base}    ${driver}    ${d2}    ${lot}    ${spot}=    Seed Booking Fixture
    Create Global API Session
    ${payload}=    Create Dictionary    driver_id=${driver}    lot_id=${lot}    start_at=${BOOK_DAY}T10:00:00    end_at=${BOOK_DAY}T11:00:00
    ${first}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    201    ${first}
    ${resp}=    POST On Session    api    /bookings    json=${payload}    expected_status=any
    Status Should Be    409    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    No free spot available for the requested window
    ${count}=    Query    SELECT count(*) FROM reservations WHERE spot_id = ${spot} AND status = 'SOFT_LOCKED'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Booking Test Data    ${base}
