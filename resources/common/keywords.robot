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
    Connect To Database    psycopg2    ${DB_NAME}    ${DB_USER}    ${DB_PASS}    ${DB_HOST}    ${DB_PORT}

Disconnect From Global Database
    [Documentation]    Safely disconnect (ignored if no connection is open).
    Run Keyword And Ignore Error    Disconnect From Database

Create Global API Session
    [Documentation]    Create a RequestsLibrary session 'api' pointing at the project's Base API.
    Create Session    api    ${BASE_API_URL}
