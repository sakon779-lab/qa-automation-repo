*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_session_page_offers_notification_button_wired_to_session_and_VAPID_key
    [Documentation]    Verify the session page offers the notification button wired to THIS session
    ...                and to the configured VAPID key - without that wiring the button cannot
    ...                register the device and the whole PLRS-50 -> 71 -> 72 chain delivers nothing

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner P72', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver P72', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot P72', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '1 hour')
    Create Global API Session

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${resp}=    GET On Session    api    /web/sessions/${dynamic_id}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult) ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    เปิดการแจ้งเตือน
    Should Contain    ${body}    push-status
    Should Contain    ${body}    data-vapid-key=
    Should Contain    ${body}    /static/push.js

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-002_Verify_page_still_shows_PLRS-48_deliverables
    [Documentation]    Verify the page still shows everything PLRS-48 delivered - this card only ADDS controls

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner P72', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver P72', 'driver_${dynamic_id}@test.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Lot P72', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'A1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour', 'CONFIRMED', 80)
    Execute Sql String    INSERT INTO sessions (id, reservation_id, status, checkin_at) VALUES (${dynamic_id}, ${dynamic_id}, 'ACTIVE', NOW() - INTERVAL '1 hour')
    Create Global API Session

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${resp}=    GET On Session    api    /web/sessions/${dynamic_id}    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult) ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ACTIVE
    Should Contain    ${body}    overstay-fragment
    Should Contain    ${body}    hx-get

    # --- 4. TEARDOWN PHASE (From Teardown) ---
    [Teardown]    Cleanup Test Case Data    ${dynamic_id}

TC-003_Verify_install_banner_exists_but_starts_hidden
    [Documentation]    Verify the install banner exists but starts HIDDEN - 'ติดตั้งแอป' must never
    ...                advertise an install that would do nothing when tapped, so it is revealed only
    ...                when the browser fires beforeinstallprompt (that event is a browser state, not
    ...                inducible from a robot)

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Create Global API Session

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${resp}=    GET On Session    api    /web    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult) ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    ติดตั้งแอป
    Should Contain    ${body}    install-banner
    Should Contain    ${body}    hidden
    Should Contain    ${body}    beforeinstallprompt
    Should Contain    ${body}    หน้าจอ

TC-004_Verify_served_handler_treats_registered_device_as_success
    [Documentation]    Verify the served handler treats an already-registered device as SUCCESS and
    ...                uses the declared wording for a refused permission - asserted on the shipped
    ...                script because both are behaviour, not markup

    # --- 1. SETUP PHASE (From PreRequisites) ---
    Create Global API Session

    # --- 2. EXERCISE PHASE (From Steps) ---
    ${resp}=    GET On Session    api    /static/push.js    expected_status=any

    # --- 3. VERIFICATION PHASE (From ExpectedResult) ---
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    เปิดการแจ้งเตือนไว้แล้ว
    Should Contain    ${body}    ไม่ได้รับอนุญาตให้แจ้งเตือน
    Should Contain    ${body}    dataset.vapidKey
    Should Contain    ${body}    /push-subscriptions

*** Keywords ***
Cleanup Test Case Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM push_subscriptions WHERE session_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM sessions WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database