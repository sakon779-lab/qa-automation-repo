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

Create Global API Session
    [Documentation]    Create a RequestsLibrary session 'api' pointing at the project's Base API.
    Create Session    api    ${BASE_API_URL}

Arm Mock Expectation
    [Documentation]    Arm a canned MockServer reply BEFORE the API call that triggers it — for
    ...                stub-backed endpoints (the APP calls MockServer itself; the test only arms
    ...                the reply). Uses the importing project's ${MOCKSERVER_URL}.
    ...                Usage:  Arm Mock Expectation    POST    /charge    200    {"status": "SUCCESS", "txn_id": "mock_txn_888"}
    [Arguments]    ${method}    ${path}    ${status}    ${body}
    Create Session    _mock    ${MOCKSERVER_URL}
    ${status_int}=    Convert To Integer    ${status}
    ${http_req}=      Create Dictionary    method=${method}    path=${path}
    ${http_resp}=     Create Dictionary    statusCode=${status_int}    body=${body}
    ${exp}=           Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session    _mock    /mockserver/expectation    json=${exp}    expected_status=201

Reset Mock Server
    [Documentation]    Clear every expectation so the next test/suite starts clean. Safe to call
    ...                even when MockServer is unreachable (ignored).
    Run Keyword And Ignore Error    Create Session    _mock    ${MOCKSERVER_URL}
    Run Keyword And Ignore Error    PUT On Session    _mock    /mockserver/reset    expected_status=any
