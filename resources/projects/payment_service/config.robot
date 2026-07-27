*** Settings ***
Documentation    PAYMENT service — environment config. Reuses the shared connection keywords in
...              resources/common/keywords.robot. Every value is env-overridable so the SAME suite runs
...              against dev / QA / Jenkins by exporting QA_* vars. Defaults = the Hermes payment QA env.
Resource         ../../common/keywords.robot

*** Variables ***
# --- Target API / Mock (defaults = payment QA :8001 / :1081) ---
${BASE_API_URL}      %{QA_API_URL=http://127.0.0.1:8001}
${MOCK_SERVER_URL}   %{QA_MOCK_URL=http://127.0.0.1:1081}
${MOCKSERVER_URL}    ${MOCK_SERVER_URL}

# --- Database (payment: shop_db). ALL fields env-overridable so another project never inherits
#     payment's DB by accident — this is the multi-project safety the QA repo depends on. ---
${DB_HOST}           %{QA_DB_HOST=127.0.0.1}
${DB_PORT}           %{QA_DB_PORT=5436}
${DB_NAME}           %{QA_DB_NAME=shop_db}
${DB_USER}           %{QA_DB_USER=postgres}
${DB_PASS}           %{QA_DB_PASS=secretpassword}
