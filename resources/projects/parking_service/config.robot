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
    [Documentation]    Standard [Teardown] for any test that SEEDED rows: truncate every parking
    ...                table (children die via CASCADE — sessions go with reservations), clear mock
    ...                expectations, close the DB connection. Call ONLY from tests that ran
    ...                Connect To Global Database and seeded data (no-seed tests get NO teardown).
    Run Keyword And Ignore Error    Execute Sql String    TRUNCATE reservations RESTART IDENTITY CASCADE
    Run Keyword And Ignore Error    Execute Sql String    TRUNCATE spots RESTART IDENTITY CASCADE
    Run Keyword And Ignore Error    Execute Sql String    TRUNCATE lots RESTART IDENTITY CASCADE
    Run Keyword And Ignore Error    Execute Sql String    TRUNCATE drivers RESTART IDENTITY CASCADE
    Run Keyword And Ignore Error    Execute Sql String    TRUNCATE owners RESTART IDENTITY CASCADE
    Reset Mock Server
    Run Keyword And Ignore Error    Disconnect From Global Database
