*** Settings ***
Documentation    PARKING (PLRS) service — environment config. Reuses the shared connection keywords in
...              resources/common/keywords.robot. Every value is env-overridable (export QA_* to retarget).
...              Defaults = the Hermes-deployed plrs_qa stack (API :8003 / mock :1083 / db :5438, parking).
Resource         ../../common/keywords.robot

*** Variables ***
# --- Target API / Mock (defaults = plrs_qa :8003 / :1083) ---
${BASE_API_URL}      %{QA_API_URL=http://127.0.0.1:8003}
${MOCK_SERVER_URL}   %{QA_MOCK_URL=http://127.0.0.1:1083}
${MOCKSERVER_URL}    ${MOCK_SERVER_URL}

# --- Database (parking: user/db/pass all "parking"). Env-overridable. ---
${DB_HOST}           %{QA_DB_HOST=127.0.0.1}
${DB_PORT}           %{QA_DB_PORT=5438}
${DB_NAME}           %{QA_DB_NAME=parking}
${DB_USER}           %{QA_DB_USER=parking}
${DB_PASS}           %{QA_DB_PASS=parking}

*** Keywords ***
Cleanup Parking Test Data
    [Documentation]    PARALLEL-SAFE standard [Teardown] for a test that seeded rows with an
    ...                explicit <dynamic_id>: deletes ONLY that test's rows, children first.
    ...                (The old TRUNCATE version wiped concurrently-running tests' data.)
    [Arguments]    ${id}=${EMPTY}
    IF    '${id}' != ''
        ${id2}=    Evaluate    ${id} + 1
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM penalties WHERE reservation_id = ${id}
        # push_subscriptions references sessions, so it goes before them (PLRS-50).
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM push_subscriptions WHERE session_id IN (${id}, ${id2})
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE reservation_id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE id IN (${id}, ${id2})
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    END
    Run Keyword And Ignore Error    Disconnect From Global Database
