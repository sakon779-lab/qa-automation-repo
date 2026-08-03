*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_bookings_new_renders_driver_id_number_input
    [Documentation]    Verify GET /web/bookings/new renders the driver_id number input (NOT the persona select) when SANDBOX_MODE=false
    ...    Regression guard: QA mode must render byte-for-byte identical to today.
    ...    The sandbox=true dropdown cases are not inducible from a robot (env var fixed at container start); covered by app unit tests.

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'seed_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 1, 'สมชาย ใจดี', 'somchai_${dynamic_id}@plrs.test', 'KK1234')
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 2, 'สมหญิง รักดี', 'somying_${dynamic_id}@plrs.test', 'KK5678')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 3, 'ลานจอดกลางเมือง', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 4, ${dynamic_id} + 3, 'A-01', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 5, ${dynamic_id} + 1, ${dynamic_id} + 4, ${dynamic_id} + 3, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 40)
    Create Global API Session

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${resp}=    GET On Session    api    /web/bookings/new    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult) ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="driver_id"
    Should Contain    ${body}    type="number"
    Should Contain    ${body}    required

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-002_Verify_GET_web_checkin_renders_reservation_id_and_wall_code_inputs
    [Documentation]    Verify GET /web/checkin renders the reservation_id number input and the wall_code manual input when SANDBOX_MODE=false
    ...    Regression guard: QA mode must render byte-for-byte identical to today.
    ...    The sandbox=true reservation dropdown case is not inducible from a robot (env var fixed at container start); covered by app unit tests.

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'seed_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 1, 'สมชาย ใจดี', 'somchai_${dynamic_id}@plrs.test', 'KK1234')
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 2, 'สมหญิง รักดี', 'somying_${dynamic_id}@plrs.test', 'KK5678')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 3, 'ลานจอดกลางเมือง', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 4, ${dynamic_id} + 3, 'A-01', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 5, ${dynamic_id} + 1, ${dynamic_id} + 4, ${dynamic_id} + 3, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 40)
    Create Global API Session

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${resp}=    GET On Session    api    /web/checkin    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult) ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    name="reservation_id"
    Should Contain    ${body}    type="number"
    Should Contain    ${body}    name="wall_code"
    Should Not Contain    ${body}    <select name="reservation_id">

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-003_Verify_GET_web_navbar_renders_without_sandbox_badge
    [Documentation]    Verify GET /web navbar renders WITHOUT the sandbox badge 'โหมดทดลอง (sandbox)' when SANDBOX_MODE=false
    ...    Regression guard: QA mode must render byte-for-byte identical to today.
    ...    The sandbox=true badge case is not inducible from a robot (env var fixed at container start); covered by app unit tests.

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Seed Owner', 'seed_${dynamic_id}@plrs.test', true)
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 1, 'สมชาย ใจดี', 'somchai_${dynamic_id}@plrs.test', 'KK1234')
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${dynamic_id} + 2, 'สมหญิง รักดี', 'somying_${dynamic_id}@plrs.test', 'KK5678')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 3, 'ลานจอดกลางเมือง', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 4, ${dynamic_id} + 3, 'A-01', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id} + 5, ${dynamic_id} + 1, ${dynamic_id} + 4, ${dynamic_id} + 3, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 40)
    Create Global API Session

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${resp}=    GET On Session    api    /web    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult) ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    navbar-plrs
    Should Not Contain    ${body}    โหมดทดลอง (sandbox)

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

*** Keywords ***
Cleanup Test Case Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id} + 5
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id} + 4
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 3
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id IN (${id} + 1, ${id} + 2)
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database