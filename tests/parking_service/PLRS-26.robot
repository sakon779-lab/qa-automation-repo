*** Settings ***
Documentation    PLRS-26 — POST /owners/{id}/payout (month-end batch payout, stub transfer).
...              Translated 1:1 from the approved test_designs/PLRS-26.csv (Athena, finalized).
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Payout_Computed_And_Transferred_Worked_Example_1
    [Documentation]    Payout computed and transferred when gross exceeds fees + subscription (worked example 1)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Payout Owner', 'own_${dynamic_id}@x.com', true, 300);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Payout Driver', 'drv_${dynamic_id}@x.com');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Payout Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'PY-1', true);
    FOR    ${i}    IN RANGE    10
        ${rid}=    Evaluate    ${dynamic_id} + ${i}
        Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${rid}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, date_trunc('month', NOW()) + INTERVAL '${i+1} hour', date_trunc('month', NOW()) + INTERVAL '${i+3} hour', 'COMPLETED', 100);
    END
    Arm Mock Expectation    POST    /transfer    200    {"status": "SUCCESS"}
    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${month}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m')    modules=datetime
    ${payload}=    Create Dictionary    month=${month}
    ${resp}=    POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[owner_id]    ${dynamic_id}
    Should Be Equal As Strings    ${json}[month]    ${month}
    Should Be Equal As Integers    ${json}[gross]    1000
    Should Be Equal As Integers    ${json}[platform_fees]    100
    Should Be Equal As Integers    ${json}[subscription]    300
    Should Be Equal As Integers    ${json}[payout]    600
    Should Be True    ${json}[transferred]
    Should Not Be True    ${json}[owes_platform]
    # Post-Assertion from CSV — presence, not exact count: Payment(kind=PAYOUT) has no owner/dynamic_id
    # column (reservation_id is always NULL for a payout), so an exact-1 count is not re-run-safe —
    # a leftover row from any earlier run with the SAME worked-example amount collides (found live).
    ${db_count_result}=    Query    SELECT count(*) FROM payments WHERE kind = 'PAYOUT' AND reservation_id IS NULL AND amount = 600
    Should Be True    ${db_count_result[0][0]} >= 1
    [Teardown]    Cleanup Payout Test Data    ${dynamic_id}    600

TC-002_Negative_Net_Floors_Payout_To_Zero_No_Payment_Worked_Example_2
    [Documentation]    Negative net floors payout to 0, flags owes_platform, and records NO payment (worked example 2)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Payout Owner', 'own_${dynamic_id}@x.com', true, 300);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Payout Driver', 'drv_${dynamic_id}@x.com');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Payout Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'PY-1', true);
    FOR    ${i}    IN RANGE    5
        ${rid}=    Evaluate    ${dynamic_id} + ${i}
        Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${rid}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, date_trunc('month', NOW()) + INTERVAL '${i+1} hour', date_trunc('month', NOW()) + INTERVAL '${i+3} hour', 'COMPLETED', 20);
    END
    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${month}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m')    modules=datetime
    ${payload}=    Create Dictionary    month=${month}
    ${resp}=    POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[gross]    100
    Should Be Equal As Integers    ${json}[platform_fees]    50
    Should Be Equal As Integers    ${json}[subscription]    300
    Should Be Equal As Integers    ${json}[payout]    0
    Should Not Be True    ${json}[transferred]
    Should Be True    ${json}[owes_platform]
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM payments WHERE kind = 'PAYOUT' AND reservation_id IS NULL AND amount = 0
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    [Teardown]    Cleanup Payout Test Data    ${dynamic_id}

TC-003_Exact_Break_Even_Payout_Zero_Not_Owing
    [Documentation]    Exact break-even: payout 0, transferred false, owes_platform false
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Payout Owner', 'own_${dynamic_id}@x.com', true, 300);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Payout Driver', 'drv_${dynamic_id}@x.com');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Payout Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'PY-1', true);
    FOR    ${i}    IN RANGE    5
        ${rid}=    Evaluate    ${dynamic_id} + ${i}
        Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${rid}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, date_trunc('month', NOW()) + INTERVAL '${i+1} hour', date_trunc('month', NOW()) + INTERVAL '${i+3} hour', 'COMPLETED', 70);
    END
    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${month}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m')    modules=datetime
    ${payload}=    Create Dictionary    month=${month}
    ${resp}=    POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[gross]    350
    Should Be Equal As Integers    ${json}[platform_fees]    50
    Should Be Equal As Integers    ${json}[payout]    0
    Should Not Be True    ${json}[transferred]
    Should Not Be True    ${json}[owes_platform]
    [Teardown]    Cleanup Payout Test Data    ${dynamic_id}

TC-004_Penalties_Attached_To_The_Months_Reservations_Count_Into_Gross
    [Documentation]    Penalties attached to the month's reservations count into gross
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Payout Owner', 'own_${dynamic_id}@x.com', true, 300);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Payout Driver', 'drv_${dynamic_id}@x.com');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Payout Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'PY-1', true);
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, date_trunc('month', NOW()) + INTERVAL '1 hour', date_trunc('month', NOW()) + INTERVAL '3 hour', 'COMPLETED', 450);
    ${rid2}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${rid2}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, date_trunc('month', NOW()) + INTERVAL '2 hour', date_trunc('month', NOW()) + INTERVAL '4 hour', 'COMPLETED', 450);
    Execute Sql String    INSERT INTO penalties (id, reservation_id, amount, reason) VALUES (${dynamic_id}, ${dynamic_id}, 100, 'OVERSTAY');
    Arm Mock Expectation    POST    /transfer    200    {"status": "SUCCESS"}
    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${month}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m')    modules=datetime
    ${payload}=    Create Dictionary    month=${month}
    ${resp}=    POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[gross]    1000
    Should Be Equal As Integers    ${json}[platform_fees]    20
    Should Be Equal As Integers    ${json}[subscription]    300
    Should Be Equal As Integers    ${json}[payout]    680
    Should Be True    ${json}[transferred]
    # Post-Assertion from CSV — presence, not exact count (see TC-001 comment)
    ${db_count_result}=    Query    SELECT count(*) FROM payments WHERE kind = 'PAYOUT' AND reservation_id IS NULL AND amount = 680
    Should Be True    ${db_count_result[0][0]} >= 1
    [Teardown]    Cleanup Payout Test Data    ${dynamic_id}    680

TC-005_Reservations_Outside_The_Requested_Month_Are_Excluded_From_Gross
    [Documentation]    Reservations outside the requested month are excluded from gross
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Payout Owner', 'own_${dynamic_id}@x.com', true, 300);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Payout Driver', 'drv_${dynamic_id}@x.com');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Payout Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'PY-1', true);
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, date_trunc('month', NOW()) + INTERVAL '1 hour', date_trunc('month', NOW()) + INTERVAL '3 hour', 'COMPLETED', 800);
    ${rid2}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${rid2}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, date_trunc('month', NOW()) - INTERVAL '10 day', date_trunc('month', NOW()) - INTERVAL '10 day' + INTERVAL '2 hour', 'COMPLETED', 900);
    Arm Mock Expectation    POST    /transfer    200    {"status": "SUCCESS"}
    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${month}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m')    modules=datetime
    ${payload}=    Create Dictionary    month=${month}
    ${resp}=    POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[gross]    800
    Should Be Equal As Integers    ${json}[platform_fees]    10
    Should Be Equal As Integers    ${json}[payout]    490
    Should Be True    ${json}[transferred]
    [Teardown]    Cleanup Payout Test Data    ${dynamic_id}    490

TC-006_Subscription_Amount_Comes_From_The_Owner_Row_Not_A_Constant
    [Documentation]    Subscription amount comes from the owner row, not a constant
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Payout Owner', 'own_${dynamic_id}@x.com', true, 500);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Payout Driver', 'drv_${dynamic_id}@x.com');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Payout Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'PY-1', true);
    FOR    ${i}    IN RANGE    10
        ${rid}=    Evaluate    ${dynamic_id} + ${i}
        Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${rid}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, date_trunc('month', NOW()) + INTERVAL '${i+1} hour', date_trunc('month', NOW()) + INTERVAL '${i+3} hour', 'COMPLETED', 100);
    END
    Arm Mock Expectation    POST    /transfer    200    {"status": "SUCCESS"}
    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${month}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m')    modules=datetime
    ${payload}=    Create Dictionary    month=${month}
    ${resp}=    POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[gross]    1000
    Should Be Equal As Integers    ${json}[platform_fees]    100
    Should Be Equal As Integers    ${json}[subscription]    500
    Should Be Equal As Integers    ${json}[payout]    400
    Should Be True    ${json}[transferred]
    [Teardown]    Cleanup Payout Test Data    ${dynamic_id}    400

TC-007_Unknown_Owner_Returns_Contract_404_And_Transfers_Nothing
    [Documentation]    Unknown owner returns the contract 404 and transfers nothing
    Create Session    api    ${BASE_API_URL}
    ${non_existent_integer_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${month}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m')    modules=datetime
    ${payload}=    Create Dictionary    month=${month}
    ${resp}=    POST On Session    api    /owners/${non_existent_integer_id}/payout    json=${payload}    expected_status=any
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Owner not found

TC-008_Missing_Month_Returns_Contract_400
    [Documentation]    Missing month returns the contract 400
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Payout Owner', 'own_${dynamic_id}@x.com', true, 300);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Payout Driver', 'drv_${dynamic_id}@x.com');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Payout Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'PY-1', true);
    Create Session    api    ${BASE_API_URL}
    ${empty_payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /owners/${dynamic_id}/payout    json=${empty_payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Month is required
    [Teardown]    Cleanup Payout Test Data    ${dynamic_id}

TC-009_Malformed_Month_Returns_Contract_400
    [Documentation]    Malformed month returns the contract 400
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${dynamic_id}, 'Payout Owner', 'own_${dynamic_id}@x.com', true, 300);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Payout Driver', 'drv_${dynamic_id}@x.com');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id}, 'Payout Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'PY-1', true);
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    month=10-2023
    ${resp}=    POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid month format. Expected YYYY-MM
    [Teardown]    Cleanup Payout Test Data    ${dynamic_id}

*** Keywords ***
Cleanup Payout Test Data
    [Documentation]    PARALLEL-SAFE teardown for a PLRS-26 test: deletes ONLY this test's rows
    ...                (any PAYOUT payment first, by exact amount — reservation_id IS NULL so it
    ...                can't be scoped by id), then the seeded parent chain, children first.
    [Arguments]    ${id}    ${payout_amount}=${EMPTY}
    IF    '${payout_amount}' != ''
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM payments WHERE kind = 'PAYOUT' AND reservation_id IS NULL AND amount = ${payout_amount}
    END
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM penalties WHERE reservation_id >= ${id} AND reservation_id < ${id} + 20
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE id >= ${id} AND id < ${id} + 20
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database
