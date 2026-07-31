*** Settings ***
Documentation     PLRS-22 — GET /staff/sessions?plate= (staff verification by licence plate).
...               Translated from test_designs/PLRS-22.csv. Finalized by Claude after Artemis's
...               round ended at the write-guard cap: it read the CSV's Steps prose
...               ("Call GET /staff/sessions?plate=KK1234") as a KEYWORD NAME and kept fixing the
...               arguments of a keyword that should never have existed.
...
...               The pair that matters here is TC-004 (right plate, wrong session state) and
...               TC-010 (right state, wrong plate). Either alone can be satisfied by a lookup that
...               just checks whether a key exists; together they force a real match on both.
Library           RequestsLibrary
Library           Collections
Library           DatabaseLibrary
Resource          ../../resources/projects/parking_service/config.robot


*** Test Cases ***
TC-001_Exact_Plate_Finds_The_Active_Session
    [Documentation]    Stored 'KK 1234', searched 'KK 1234' -> the active session with its details
    ${ids}=    Seed Plate Scenario    session_status=ACTIVE
    ${resp}=   Lookup Plate    KK 1234
    Status Should Be    200    ${resp}
    ${json}=   Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[plate]    KK1234
    Should Be True    ${json}[active]
    Should Be Equal As Integers    ${json}[session][id]         ${ids}[session]
    Should Be Equal As Integers    ${json}[session][lot_id]     ${ids}[lot]
    Should Be Equal As Integers    ${json}[session][spot_id]    ${ids}[spot]
    Should Be Equal As Integers    ${json}[session][driver][id]    ${ids}[driver]
    Should Be Equal As Strings     ${json}[session][driver][name]  Driver A
    # R22.8 — start/end/checkin_at are DB values: assert PRESENCE, never a fixed timestamp
    Should Not Be Empty    ${json}[session][start]
    Should Not Be Empty    ${json}[session][end]
    Should Not Be Empty    ${json}[session][checkin_at]
    [Teardown]    Cleanup Plate Scenario    ${ids}

TC-002_Lower_Case_With_Space_Still_Finds_It
    [Documentation]    Case-insensitive match — 'kk 1234' finds the same driver
    ${ids}=    Seed Plate Scenario    session_status=ACTIVE
    ${resp}=   Lookup Plate    kk 1234
    Status Should Be    200    ${resp}
    Should Be Equal As Strings    ${resp.json()}[plate]    KK1234
    Should Be True    ${resp.json()}[active]
    [Teardown]    Cleanup Plate Scenario    ${ids}

TC-003_No_Space_Finds_A_Plate_Stored_With_One
    [Documentation]    Normalisation applies to BOTH sides: stored 'KK 1234' is found by 'KK1234'
    ${ids}=    Seed Plate Scenario    session_status=ACTIVE
    ${resp}=   Lookup Plate    KK1234
    Status Should Be    200    ${resp}
    Should Be Equal As Strings    ${resp.json()}[plate]    KK1234
    Should Be True    ${resp.json()}[active]
    [Teardown]    Cleanup Plate Scenario    ${ids}

TC-004_Only_A_Completed_Session_Is_Not_Active
    [Documentation]    Right plate, wrong state — history is not a current verification, and it is
    ...                a 200 rather than a 404 so staff can tell it from a broken request
    ${ids}=    Seed Plate Scenario    session_status=COMPLETED
    ${resp}=   Lookup Plate    KK 1234
    Status Should Be    200    ${resp}
    ${json}=   Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[plate]    KK1234
    Should Not Be True    ${json}[active]
    Should Be Equal    ${json}[session]    ${None}
    [Teardown]    Cleanup Plate Scenario    ${ids}

TC-005_Only_A_No_Show_Session_Is_Not_Active
    [Documentation]    Same as TC-004 for the NO_SHOW outcome
    ${ids}=    Seed Plate Scenario    session_status=NO_SHOW    checkin=${False}
    ${resp}=   Lookup Plate    KK 1234
    Status Should Be    200    ${resp}
    Should Not Be True    ${resp.json()}[active]
    Should Be Equal    ${resp.json()}[session]    ${None}
    [Teardown]    Cleanup Plate Scenario    ${ids}

TC-006_Registered_Driver_With_No_Session_At_All
    [Documentation]    The plate exists but the car has never parked -> 200, not active
    Connect To Global Database
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${id}, 'Driver A', 'driver_${id}@test.com', 'KK 1234')
    ${resp}=   Lookup Plate    KK 1234
    Status Should Be    200    ${resp}
    Should Not Be True    ${resp.json()}[active]
    Should Be Equal    ${resp.json()}[session]    ${None}
    [Teardown]    Cleanup Lone Driver    ${id}

TC-007_Unknown_Plate_Answers_Exactly_Like_An_Idle_One
    [Documentation]    R22.3 — the endpoint never reveals whether a plate is registered
    ${resp}=   Lookup Plate    XX 1234
    Status Should Be    200    ${resp}
    ${json}=   Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[plate]    XX1234
    Should Not Be True    ${json}[active]
    Should Be Equal    ${json}[session]    ${None}

TC-008_Car_Parked_Past_Its_Booked_Window_Is_Still_Active
    [Documentation]    The reservation window has ended and the session was never closed. R22.2
    ...                makes session STATUS the only criterion, so the car is still parked — which
    ...                is exactly what staff need confirmed. Verified against the deployed endpoint
    ...                before writing this: the CSV originally expected active=false.
    ${ids}=    Seed Plate Scenario    session_status=ACTIVE    window=past
    ${resp}=   Lookup Plate    KK 1234
    Status Should Be    200    ${resp}
    ${json}=   Set Variable    ${resp.json()}
    Should Be True    ${json}[active]
    Should Be Equal As Integers    ${json}[session][lot_id]     ${ids}[lot]
    Should Be Equal As Integers    ${json}[session][spot_id]    ${ids}[spot]
    [Teardown]    Cleanup Plate Scenario    ${ids}

TC-009_Missing_Plate_Parameter_Returns_400
    [Documentation]    The only error path: no plate to search for
    Create Global API Session
    ${resp}=    GET On Session    api    /staff/sessions    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Plate is required

TC-010_Another_Plate_Holding_The_Only_Active_Session_Does_Not_Leak
    [Documentation]    Right state, wrong plate. With TC-004 this is the pair that proves a real
    ...                match rather than "is this key in the table"
    ${ids}=    Seed Two Drivers One Parked
    ${resp}=   Lookup Plate    BB2222
    Status Should Be    200    ${resp}
    ${json}=   Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[plate]    BB2222
    Should Not Be True    ${json}[active]
    Should Be Equal    ${json}[session]    ${None}
    # the OTHER plate really is parked — proving the negative above is about the match, not an
    # empty database
    ${other}=    Lookup Plate    AA1111
    Should Be True    ${other.json()}[active]
    [Teardown]    Cleanup Plate Scenario    ${ids}


*** Keywords ***
Lookup Plate
    [Documentation]    GET /staff/sessions with the plate as a query PARAMETER, so RequestsLibrary
    ...                does the URL-encoding (a hand-built '?plate=KK%201234' double-encodes).
    [Arguments]    ${plate}
    Create Global API Session
    ${params}=    Create Dictionary    plate=${plate}
    ${resp}=      GET On Session    api    /staff/sessions    params=${params}    expected_status=any
    RETURN    ${resp}

Seed Plate Scenario
    [Documentation]    driver 'KK 1234' -> lot -> spot -> reservation -> session, with the session
    ...                status and the booking window under the caller's control. Returns the ids.
    ...                The plate is stored WITH a space on purpose: normalisation has to work on
    ...                the stored side too, not just the query.
    [Arguments]    ${session_status}    ${checkin}=${True}    ${window}=current
    Connect To Global Database
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${d}=     Set Variable    ${id}
    ${r}=     Evaluate    ${id} + 1
    ${l}=     Evaluate    ${id} + 2
    ${s}=     Evaluate    ${id} + 3
    ${sess}=  Evaluate    ${id} + 4
    IF    '${window}' == 'past'
        ${start}=    Set Variable    NOW() - INTERVAL '3 hours'
        ${end}=      Set Variable    NOW() - INTERVAL '1 hour'
    ELSE
        ${start}=    Set Variable    NOW() - INTERVAL '1 hour'
        ${end}=      Set Variable    NOW() + INTERVAL '1 hour'
    END
    IF    ${checkin}
        ${checkin_at}=    Set Variable    NOW() - INTERVAL '50 minutes'
    ELSE
        ${checkin_at}=    Set Variable    null
    END
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${d}, 'Driver A', 'driver_${d}@test.com', 'KK 1234')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${l}, 'Lot A', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${s}, ${l}, 'SPOT-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${r}, ${d}, ${l}, ${s}, ${start}, ${end}, 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, status) VALUES (${sess}, ${r}, ${checkin_at}, '${session_status}')
    ${ids}=    Create Dictionary    driver=${d}    reservation=${r}    lot=${l}    spot=${s}    session=${sess}
    RETURN    ${ids}

Seed Two Drivers One Parked
    [Documentation]    AA1111 is parked (ACTIVE session), BB2222 is registered but idle.
    Connect To Global Database
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${d}=     Set Variable    ${id}
    ${idle}=  Evaluate    ${id} + 6
    ${r}=     Evaluate    ${id} + 1
    ${l}=     Evaluate    ${id} + 2
    ${s}=     Evaluate    ${id} + 3
    ${sess}=  Evaluate    ${id} + 4
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${d}, 'Parked Driver', 'parked_${d}@test.com', 'AA1111')
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${idle}, 'Idle Driver', 'idle_${idle}@test.com', 'BB2222')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${l}, 'Lot A', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${s}, ${l}, 'SPOT-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${r}, ${d}, ${l}, ${s}, NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, checkin_at, status) VALUES (${sess}, ${r}, NOW() - INTERVAL '50 minutes', 'ACTIVE')
    ${ids}=    Create Dictionary    driver=${d}    idle=${idle}    reservation=${r}    lot=${l}    spot=${s}    session=${sess}
    RETURN    ${ids}

Cleanup Plate Scenario
    [Documentation]    Child-first removal of only this test's rows (parallel-safe), then disconnect.
    [Arguments]    ${ids}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE id = ${ids}[session]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${ids}[reservation]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${ids}[spot]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${ids}[lot]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${ids}[driver]
    ${idle}=    Get From Dictionary    ${ids}    idle    default=${EMPTY}
    IF    '${idle}' != ''
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${idle}
    END
    Disconnect From Global Database

Cleanup Lone Driver
    [Documentation]    Teardown for the case that seeded only a driver row.
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Disconnect From Global Database
