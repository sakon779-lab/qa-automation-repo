*** Settings ***
Documentation    Global Environment Variables and Connection Keywords
Library          DatabaseLibrary
Library          RequestsLibrary

*** Variables ***
# ==========================================
# 🌍 ENVIRONMENT CONFIGURATIONS — default to the Hermes QA env (:8001/:1081/:5436)
# override per-var with env QA_API_URL / QA_MOCK_URL / QA_DB_PORT (e.g. Jenkins, or dev :8000)
# ==========================================
# --- Target API ---
${BASE_API_URL}      %{QA_API_URL=http://127.0.0.1:8001}

# --- Mock Server ---
${MOCK_SERVER_URL}   %{QA_MOCK_URL=http://127.0.0.1:1081}
# alias — test เก่าบางไฟล์ (SCRUM-30) อ้างชื่อไม่มี underscore
${MOCKSERVER_URL}    ${MOCK_SERVER_URL}

# --- Database (PostgreSQL) ---
# DB_PORT 5435 = docker payment db (เดิม 5434 ชนกับ native PostgreSQL บนเครื่อง)
${DB_HOST}           127.0.0.1
${DB_PORT}           %{QA_DB_PORT=5436}
${DB_NAME}           shop_db
${DB_USER}           postgres
${DB_PASS}           secretpassword


*** Keywords ***
# ==========================================
# 🛠️ GLOBAL HELPER KEYWORDS
# ==========================================
Connect To Global Database
    [Documentation]    Connects to the target PostgreSQL database using global variables.
    Connect To Database    psycopg2    ${DB_NAME}    ${DB_USER}    ${DB_PASS}    ${DB_HOST}    ${DB_PORT}

Disconnect From Global Database
    [Documentation]    Safely disconnects from the database.
    Disconnect From Database

Create Global API Session
    [Documentation]    Creates a RequestsLibrary session pointing to the Base API.
    Create Session    api    ${BASE_API_URL}