*** Settings ***
Documentation    Shared, project-AGNOSTIC helper keywords reused by every project's suite.
...              The concrete values (${BASE_API_URL}, ${DB_HOST}, ${DB_PORT}, ${DB_NAME},
...              ${DB_USER}, ${DB_PASS}) are supplied by the importing project's config.robot
...              (resources/projects/<project>/config.robot) — NEVER hard-code a project's values here.
Library          DatabaseLibrary
Library          RequestsLibrary

*** Keywords ***
Connect To Global Database
    [Documentation]    Connect to the target project's PostgreSQL using the DB_* variables the
    ...                project's config.robot defined.
    ...
    ...                Closes any connection still open first. DatabaseLibrary keeps ONE current
    ...                connection, so opening a second over it logs "Overwriting not closed
    ...                connection" as a run-level WARNING — the report then shows an Execution
    ...                Errors block on a fully green run, which trains everyone to ignore that
    ...                block. Any suite whose teardown was skipped (a failure before [Teardown],
    ...                or a case that simply never disconnects) leaks one into the next test, so
    ...                making the connect itself idempotent fixes it for every suite at once
    ...                rather than auditing fifteen of them. Safe because tests run sequentially:
    ...                a connection still open here belongs to a test that has already finished.
    Run Keyword And Ignore Error    Disconnect From Database
    Connect To Database    psycopg2    ${DB_NAME}    ${DB_USER}    ${DB_PASS}    ${DB_HOST}    ${DB_PORT}

Disconnect From Global Database
    [Documentation]    Safely disconnect (ignored if no connection is open).
    Run Keyword And Ignore Error    Disconnect From Database

Current Request Scope
    [Documentation]    This test's correlation id — minted on first use, then reused.
    ...
    ...                Everything about mock isolation hangs off this one value: the API session
    ...                sends it as X-Request-Id, the app forwards it to MockServer (PLRS-59), and
    ...                the expectation is armed to match ONLY that value. Get-or-mint (rather than
    ...                mint-on-session-create) makes the order irrelevant — several suites arm the
    ...                expectation BEFORE they create the session, and a test that minted twice
    ...                would arm one id and send another, matching nothing.
    ${existing}=    Get Variable Value    ${REQUEST_SCOPE_ID}    ${EMPTY}
    IF    '${existing}' != ''
        RETURN    ${existing}
    END
    ${suffix}=    Evaluate    uuid.uuid4().hex    modules=uuid
    Set Test Variable    ${REQUEST_SCOPE_ID}    rf-${suffix}
    RETURN    rf-${suffix}

Create Global API Session
    [Documentation]    Create a RequestsLibrary session 'api' pointing at the project's Base API,
    ...                carrying this test's X-Request-Id on every request it makes.
    ...
    ...                Session-level (not per-call) on purpose: a test cannot forget it, and
    ...                forgetting is exactly the failure that would silently put a test back on a
    ...                shared global expectation. A single call may still override the header when
    ...                it needs to (a suite testing the middleware itself does).
    ${scope}=     Current Request Scope
    ${headers}=   Create Dictionary    X-Request-Id=${scope}
    Create Session    api    ${BASE_API_URL}    headers=${headers}

Arm Mock Expectation
    [Documentation]    Arm a canned MockServer reply BEFORE the API call that triggers it — for
    ...                stub-backed endpoints (the APP calls MockServer itself; the test only arms
    ...                the reply). Uses the importing project's ${MOCKSERVER_URL}.
    ...                Usage:  Arm Mock Expectation    POST    /charge    200    {"status": "SUCCESS", "txn_id": "mock_txn_888"}
    ...
    ...                The expectation is SCOPED to this test's correlation id, so two tests
    ...                arming the same path never see each other's stub and a test that forgot to
    ...                arm gets a loud 404 instead of quietly matching someone else's expectation.
    ...
    ...                ${request_id}=ANY arms an UNSCOPED expectation (matches any caller). Use it
    ...                only for a case that cannot know the id in advance — one that deliberately
    ...                sends no header and lets the app generate one. Such a case must clear its
    ...                own expectation with `Clear Mock Expectations For Path` and cannot run in
    ...                parallel with another test on the same path.
    [Arguments]    ${method}    ${path}    ${status}    ${body}    ${request_id}=${EMPTY}
    Create Session    _mock    ${MOCKSERVER_URL}
    ${status_int}=    Convert To Integer    ${status}
    IF    '${request_id}' == 'ANY'
        ${http_req}=    Create Dictionary    method=${method}    path=${path}
    ELSE
        IF    '${request_id}' == '${EMPTY}'
            ${scope}=    Current Request Scope
        ELSE
            ${scope}=    Set Variable    ${request_id}
        END
        ${values}=      Create List    ${scope}
        ${hdr}=         Create Dictionary    X-Request-Id=${values}
        ${http_req}=    Create Dictionary    method=${method}    path=${path}    headers=${hdr}
    END
    ${http_resp}=     Create Dictionary    statusCode=${status_int}    body=${body}
    ${exp}=           Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session    _mock    /mockserver/expectation    json=${exp}    expected_status=201

Get Mock Requests With Header
    [Documentation]    Return the requests MockServer actually RECEIVED on ${path} carrying
    ...                ${header}: ${value} — as a list of recorded httpRequest objects.
    ...
    ...                Arming an expectation proves what the stub WOULD answer; this proves what the
    ...                APP actually SENT. That is the only way to assert a header the app is
    ...                supposed to propagate (PLRS-59's correlation id), and it is the same
    ...                match MockServer will use to scope an expectation per test once every
    ...                request carries its own id.
    [Arguments]    ${method}    ${path}    ${header}    ${value}
    Create Session    _mock    ${MOCKSERVER_URL}
    # MockServer matches headers as name -> LIST of values (KeysToMultiValues); a bare string
    # silently matches nothing, which would make every assertion here vacuously "0 requests".
    ${values}=    Create List          ${value}
    ${hdr}=       Create Dictionary    ${header}=${values}
    ${matcher}=   Create Dictionary    method=${method}    path=${path}    headers=${hdr}
    ${params}=    Create Dictionary    type=REQUESTS    format=JSON
    ${resp}=      PUT On Session    _mock    /mockserver/retrieve
    ...           params=${params}    json=${matcher}    expected_status=200
    RETURN    ${resp.json()}

Clear Mock Expectations For This Test
    [Documentation]    Remove only the expectations THIS test armed, matched by its correlation id.
    ...
    ...                Replaces the old `Reset Mock Server`, which called /mockserver/reset — a
    ...                GLOBAL wipe. Under pabot that is a live hazard, not a theoretical one: one
    ...                worker finishing its test would delete the expectations another worker had
    ...                already armed and was mid-way through using, and the victim fails somewhere
    ...                unrelated with no trace of who did it. The old keyword is deliberately gone
    ...                rather than kept as an alias, so any suite still calling it fails the dryrun
    ...                loudly instead of silently reintroducing the hazard.
    ...
    ...                A no-op when this test never minted a scope (nothing of its own to clear).
    ...                Safe when MockServer is unreachable (ignored).
    ${scope}=    Get Variable Value    ${REQUEST_SCOPE_ID}    ${EMPTY}
    IF    '${scope}' == '${EMPTY}'    RETURN
    Run Keyword And Ignore Error    Create Session    _mock    ${MOCKSERVER_URL}
    ${values}=    Create List          ${scope}
    ${hdr}=       Create Dictionary    X-Request-Id=${values}
    ${matcher}=   Create Dictionary    headers=${hdr}
    Run Keyword And Ignore Error    PUT On Session    _mock    /mockserver/clear
    ...    json=${matcher}    expected_status=any

Clear Mock Expectations For Path
    [Documentation]    Remove every expectation on ${method} ${path}, regardless of caller.
    ...
    ...                The cleanup partner of `Arm Mock Expectation ... request_id=ANY`: an
    ...                unscoped expectation carries no correlation id, so the scoped clear above
    ...                cannot reach it and it would linger and shadow later tests on that path.
    [Arguments]    ${method}    ${path}
    Run Keyword And Ignore Error    Create Session    _mock    ${MOCKSERVER_URL}
    ${matcher}=   Create Dictionary    method=${method}    path=${path}
    Run Keyword And Ignore Error    PUT On Session    _mock    /mockserver/clear
    ...    json=${matcher}    expected_status=any
