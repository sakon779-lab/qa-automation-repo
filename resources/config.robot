*** Settings ***
Documentation    Global Environment Variables and Connection Keywords
Library          DatabaseLibrary
Library          RequestsLibrary

*** Variables ***
# ==========================================
# 🌍 ENVIRONMENT CONFIGURATIONS
# ==========================================
# --- Target API ---
${BASE_API_URL}      http://127.0.0.1:8000

# --- Mock Server ---
${MOCK_SERVER_URL}   http://127.0.0.1:1080

# --- Database (PostgreSQL) ---
${DB_HOST}           127.0.0.1
${DB_PORT}           5433
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