*** Settings ***
Documentation     PLRS-59 — X-Request-Id correlation id. Generated from test_designs/PLRS-59.csv.
...               Two things are under test and they are different: what the caller gets BACK
...               (the response header) and what the app SENDS ON (the downstream stub call).
...               The forwarding cases therefore assert against what MockServer RECORDED, not
...               against what it was armed to answer — arming proves nothing about the header.
...               Every case uses its own unique id value, so no case can match another's traffic
...               and nothing here needs a global MockServer reset.
Library           RequestsLibrary
Library           Collections
Library           DatabaseLibrary
Resource          ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Caller_Supplied_Id_Is_Echoed_Verbatim
    [Documentation]    A usable caller id is used as-is and comes back in the response header
    ${id}=      Unique Request Id    plrs59
    ${resp}=    Call Health    ${id}
    Status Should Be    200    ${resp}
    Should Be Equal As Strings    ${resp.headers}[X-Request-Id]    ${id}
    # R59.6 — the body is untouched by this card
    Should Be Equal As Strings    ${resp.json()}[status]     ok
    Should Be Equal As Strings    ${resp.json()}[service]    plrs

TC-002_Missing_Header_Gets_A_Generated_Uuid4
    [Documentation]    No caller header → the server generates one; downstream must never see empty
    ${resp}=    Call Health
    Status Should Be    200    ${resp}
    Should Be A Uuid4    ${resp.headers}[X-Request-Id]

TC-003_Two_Headerless_Requests_Get_Different_Ids
    [Documentation]    The id is per-request — a shared module global would return the same value
    ${first}=     Call Health
    ${second}=    Call Health
    Should Not Be Equal As Strings    ${first.headers}[X-Request-Id]    ${second.headers}[X-Request-Id]

TC-004_Caller_Id_Reaches_The_Downstream_Stub
    [Documentation]    MockServer recorded a POST /charge carrying the caller's own id
    ${ids}=    Seed Soft Locked Reservation
    ${id}=     Unique Request Id    plrs59-fwd
    Arm Mock Expectation    POST    /charge    200    {"status": "SUCCESS", "txn_id": "mock_txn_888"}
    ...        request_id=${id}
    # raw session on purpose: this suite tests the middleware, so it sets the header per call
    Create Session    api    ${BASE_API_URL}
    ${headers}=    Create Dictionary    X-Request-Id=${id}
    ${resp}=    POST On Session    api    /bookings/${ids}[res]/confirm    headers=${headers}
    ...         expected_status=any
    Status Should Be    200    ${resp}
    Should Be Equal As Strings    ${resp.headers}[X-Request-Id]    ${id}
    # Post-Assertion from CSV — what the APP actually sent, not what the stub was armed with
    ${recorded}=    Get Mock Requests With Header    POST    /charge    X-Request-Id    ${id}
    Length Should Be    ${recorded}    1
    [Teardown]    Cleanup Booking Data    ${ids}

TC-005_Generated_Id_Reaches_Downstream_And_Matches_The_Response
    [Documentation]    With no caller header the SAME generated id is forwarded and returned —
    ...                that equality is what makes a downstream call correlatable
    ${ids}=    Seed Soft Locked Reservation
    # request_id=ANY: this is the one case that CANNOT scope its expectation — the whole point is
    # that the app invents the id, so no test can know it in advance. It must therefore clear the
    # expectation by path in its own teardown (a scoped clear cannot reach an unscoped one), and
    # it cannot run in parallel with another test on /charge.
    Arm Mock Expectation    POST    /charge    200    {"status": "SUCCESS", "txn_id": "mock_txn_888"}
    ...        request_id=ANY
    Create Session    api    ${BASE_API_URL}
    ${resp}=    POST On Session    api    /bookings/${ids}[res]/confirm    expected_status=any
    Status Should Be    200    ${resp}
    ${generated}=    Set Variable    ${resp.headers}[X-Request-Id]
    Should Be A Uuid4    ${generated}
    ${recorded}=    Get Mock Requests With Header    POST    /charge    X-Request-Id    ${generated}
    Length Should Be    ${recorded}    1
    [Teardown]    Cleanup Booking Data And Unscoped Charge Stub    ${ids}

TC-006_Empty_Header_Is_Replaced_Not_Refused
    [Documentation]    An empty value is never a 4xx and never forwarded empty
    ${resp}=    Call Health    ${EMPTY}
    Status Should Be    200    ${resp}
    Should Be A Uuid4    ${resp.headers}[X-Request-Id]

TC-007_Surrounding_Whitespace_Is_Stripped
    [Documentation]    The trimmed token is what gets used
    ${id}=      Unique Request Id    trim
    ${resp}=    Call Health    ${id}${SPACE}${SPACE}${SPACE}
    Status Should Be    200    ${resp}
    Should Be Equal As Strings    ${resp.headers}[X-Request-Id]    ${id}

TC-008_Exactly_128_Characters_Is_Accepted
    [Documentation]    Boundary — the limit is inclusive
    ${id}=      Evaluate    'a' * 128
    ${resp}=    Call Health    ${id}
    Status Should Be    200    ${resp}
    Should Be Equal As Strings    ${resp.headers}[X-Request-Id]    ${id}

TC-009_One_Over_The_Limit_Is_Replaced
    [Documentation]    Boundary — 129 characters is unusable, so a uuid4 is generated instead
    ${id}=      Evaluate    'a' * 129
    ${resp}=    Call Health    ${id}
    Status Should Be    200    ${resp}
    Should Not Be Equal As Strings    ${resp.headers}[X-Request-Id]    ${id}
    Should Be A Uuid4    ${resp.headers}[X-Request-Id]

TC-010_Id_Containing_A_Space_Is_Replaced
    [Documentation]    Header-injection guard — a caller value is never forwarded unchecked
    ${resp}=    Call Health    has space
    Status Should Be    200    ${resp}
    Should Not Be Equal As Strings    ${resp.headers}[X-Request-Id]    has space
    Should Be A Uuid4    ${resp.headers}[X-Request-Id]

TC-011_Error_Response_Carries_The_Header_Too
    [Documentation]    A client that just saw a 404 can quote the id that produced it
    ${id}=    Unique Request Id    plrs59-err
    Create Session    api    ${BASE_API_URL}
    ${headers}=    Create Dictionary    X-Request-Id=${id}
    ${resp}=    POST On Session    api    /bookings/999999/confirm    headers=${headers}
    ...         expected_status=any
    Status Should Be    404    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Booking not found
    Should Be Equal As Strings    ${resp.headers}[X-Request-Id]    ${id}

TC-012_Web_Layer_Is_Covered_By_The_Same_Middleware
    [Documentation]    The middleware is registered before every router, not only the JSON API
    ${id}=    Unique Request Id    plrs59-web
    Create Session    api    ${BASE_API_URL}
    ${headers}=    Create Dictionary    X-Request-Id=${id}
    ${resp}=    GET On Session    api    /web    headers=${headers}    expected_status=any
    Status Should Be    200    ${resp}
    Should Be Equal As Strings    ${resp.headers}[X-Request-Id]    ${id}

*** Keywords ***
Unique Request Id
    [Documentation]    A per-case id so no case can match another case's MockServer traffic —
    ...                the same discipline as the dynamic row ids, applied to the wire.
    [Arguments]    ${prefix}
    ${n}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    RETURN    ${prefix}-${n}

Call Health
    [Documentation]    GET /health, optionally with an X-Request-Id. ${NONE} = send no header at
    ...                all, which is a different case from sending an empty one.
    [Arguments]    ${request_id}=${NONE}
    Create Session    api    ${BASE_API_URL}
    IF    $request_id is None
        ${resp}=    GET On Session    api    /health    expected_status=any
    ELSE
        ${headers}=    Create Dictionary    X-Request-Id=${request_id}
        ${resp}=    GET On Session    api    /health    headers=${headers}    expected_status=any
    END
    RETURN    ${resp}

Should Be A Uuid4
    [Documentation]    Fails on an empty value too — "downstream always has one" is the rule.
    [Arguments]    ${value}
    Should Not Be Empty    ${value}
    ${version}=    Evaluate    uuid.UUID($value).version    modules=uuid
    Should Be Equal As Integers    ${version}    4

Seed Soft Locked Reservation
    [Documentation]    Parent chain (driver → lot → spot) then a SOFT_LOCKED reservation that
    ...                confirm can charge. Dynamic ids keep it parallel-safe.
    Connect To Global Database
    ${d_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${l_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${s_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${r_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${d_id}, 'Corr Driver', 'corr_${d_id}@test.plrs')
    Execute Sql String    INSERT INTO lots (id, name, hourly_rate) VALUES (${l_id}, 'Corr Lot', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${s_id}, ${l_id}, 'CR-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${r_id}, ${d_id}, ${s_id}, ${l_id}, NOW(), NOW() + INTERVAL '2 hours', 'SOFT_LOCKED', 80.00, NOW() + INTERVAL '300 seconds')
    ${ids}=    Create Dictionary    driver=${d_id}    lot=${l_id}    spot=${s_id}    res=${r_id}
    RETURN    ${ids}

Cleanup Booking Data And Unscoped Charge Stub
    [Documentation]    Teardown for the one case that armed an UNSCOPED /charge expectation.
    ...                Clearing by header cannot reach it, so it is cleared by path — otherwise it
    ...                lingers and shadows every later test's scoped /charge stub.
    [Arguments]    ${ids}
    Run Keyword And Ignore Error    Clear Mock Expectations For Path    POST    /charge
    Cleanup Booking Data    ${ids}

Cleanup Booking Data
    [Documentation]    Child-first cleanup of everything Seed Soft Locked Reservation created.
    [Arguments]    ${ids}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM payments WHERE reservation_id = ${ids}[res]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${ids}[res]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${ids}[spot]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${ids}[lot]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${ids}[driver]
    Disconnect From Global Database
