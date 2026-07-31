*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_Rollup_For_Day_With_2_Bookings_And_1_Penalty
    [Documentation]    Verify the rollup for a day with 2 bookings and 1 penalty: fees 160 + penalty 30 - 2x10 platform = revenue 170 (R9).
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Sum Owner', 'sum_owner_${dynamic_id}@plrs.test', true);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 1, 'Sum Driver', 'sum_driver_${dynamic_id}@plrs.test');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 2, 'Sum Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 3, ${dynamic_id} + 2, 'SM-1', true);
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id} + 4, ${dynamic_id} + 1, ${dynamic_id} + 2, ${dynamic_id} + 3, NOW(), NOW() + INTERVAL '2 hours', 'CONFIRMED', 80, NOW() - INTERVAL '5 minutes');
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id} + 5, ${dynamic_id} + 1, ${dynamic_id} + 2, ${dynamic_id} + 3, NOW(), NOW() + INTERVAL '2 hours', 'CONFIRMED', 80, NOW() - INTERVAL '5 minutes');
    Execute Sql String    INSERT INTO penalties (id, reservation_id, amount, reason) VALUES (${dynamic_id} + 6, ${dynamic_id} + 4, 30, 'OVERSTAY');

    # Mock POST /email to return HTTP 200 with JSON {'status': 'SENT'}
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}

    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${today}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m-%d')    modules=datetime
    ${payload}=    Create Dictionary    date=${today}
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${resp}=    POST On Session    api    /lots/${lot_id}/daily-summary    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${lot_id}
    Should Be Equal As Strings    ${json}[date]    ${today}
    Should Be Equal As Integers    ${json}[bookings]    2
    Should Be Equal As Integers    ${json}[revenue]    170
    Should Be True    ${json}[emailed]

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-002_Verify_Day_With_No_Activity_Produces_Zero_Summary_And_Emails_Stub
    [Documentation]    Verify a day with no activity produces the zero summary and still sends the stub email.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Sum Owner', 'sum_owner_${dynamic_id}@plrs.test', true);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 1, 'Sum Driver', 'sum_driver_${dynamic_id}@plrs.test');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 2, 'Sum Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 3, ${dynamic_id} + 2, 'SM-1', true);

    # Mock POST /email to return HTTP 200 with JSON {'status': 'SENT'}
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}

    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${today}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m-%d')    modules=datetime
    ${payload}=    Create Dictionary    date=${today}
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${resp}=    POST On Session    api    /lots/${lot_id}/daily-summary    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${lot_id}
    Should Be Equal As Strings    ${json}[date]    ${today}
    Should Be Equal As Integers    ${json}[bookings]    0
    Should Be Equal As Integers    ${json}[utilization_pct]    0
    Should Be Equal As Integers    ${json}[revenue]    0
    Should Be True    ${json}[emailed]

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-003_Verify_Day_With_Reservation_But_No_Sessions
    [Documentation]    Verify a day with a reservation but no sessions: bookings and revenue counted, utilization 0.0 (S6.1 counts sessions).
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Sum Owner', 'sum_owner_${dynamic_id}@plrs.test', true);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 1, 'Sum Driver', 'sum_driver_${dynamic_id}@plrs.test');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 2, 'Sum Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 3, ${dynamic_id} + 2, 'SM-1', true);
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id} + 4, ${dynamic_id} + 1, ${dynamic_id} + 2, ${dynamic_id} + 3, NOW(), NOW() + INTERVAL '2 hours', 'CONFIRMED', 80, NOW() - INTERVAL '5 minutes');

    # Mock POST /email to return HTTP 200 with JSON {'status': 'SENT'}
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}

    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${today}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m-%d')    modules=datetime
    ${payload}=    Create Dictionary    date=${today}
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${resp}=    POST On Session    api    /lots/${lot_id}/daily-summary    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${lot_id}
    Should Be Equal As Strings    ${json}[date]    ${today}
    Should Be Equal As Integers    ${json}[bookings]    1
    Should Be Equal As Integers    ${json}[utilization_pct]    0
    Should Be Equal As Integers    ${json}[revenue]    70
    Should Be True    ${json}[emailed]

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-004_Verify_Penalty_Is_Included_In_Revenue
    [Documentation]    Verify a penalty is included in revenue: 1 booking 80 + penalty 50 - 10 platform = 120.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Sum Owner', 'sum_owner_${dynamic_id}@plrs.test', true);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 1, 'Sum Driver', 'sum_driver_${dynamic_id}@plrs.test');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 2, 'Sum Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 3, ${dynamic_id} + 2, 'SM-1', true);
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id} + 4, ${dynamic_id} + 1, ${dynamic_id} + 2, ${dynamic_id} + 3, NOW(), NOW() + INTERVAL '2 hours', 'CONFIRMED', 80, NOW() - INTERVAL '5 minutes');
    Execute Sql String    INSERT INTO penalties (id, reservation_id, amount, reason) VALUES (${dynamic_id} + 6, ${dynamic_id} + 4, 50, 'OVERSTAY');

    # Mock POST /email to return HTTP 200 with JSON {'status': 'SENT'}
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}

    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${today}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m-%d')    modules=datetime
    ${payload}=    Create Dictionary    date=${today}
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${resp}=    POST On Session    api    /lots/${lot_id}/daily-summary    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[lot_id]    ${lot_id}
    Should Be Equal As Strings    ${json}[date]    ${today}
    Should Be Equal As Integers    ${json}[bookings]    1
    Should Be Equal As Integers    ${json}[revenue]    120
    Should Be True    ${json}[emailed]

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-005_Verify_API_Returns_404_When_Lot_Does_Not_Exist
    [Documentation]    Verify API returns 404 when the lot does not exist.
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}
    Create Session    api    ${BASE_API_URL}
    ${tz}=    Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${today}=    Evaluate    datetime.datetime.now($tz).strftime('%Y-%m-%d')    modules=datetime
    ${payload}=    Create Dictionary    date=${today}
    ${resp}=    POST On Session    api    /lots/999999/daily-summary    json=${payload}    expected_status=any

    # Verification
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Lot not found

TC-006_Verify_API_Returns_400_When_Date_Field_Is_Missing
    [Documentation]    Verify API returns 400 when the date field is missing.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Sum Owner', 'sum_owner_${dynamic_id}@plrs.test', true);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 1, 'Sum Driver', 'sum_driver_${dynamic_id}@plrs.test');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 2, 'Sum Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 3, ${dynamic_id} + 2, 'SM-1', true);

    # Mock POST /email to return HTTP 200 with JSON {'status': 'SENT'}
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}

    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${resp}=    POST On Session    api    /lots/${lot_id}/daily-summary    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Date is required

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-007_Verify_API_Returns_400_When_Date_Is_An_Empty_String
    [Documentation]    Verify API returns 400 when the date is an empty string.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Sum Owner', 'sum_owner_${dynamic_id}@plrs.test', true);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 1, 'Sum Driver', 'sum_driver_${dynamic_id}@plrs.test');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 2, 'Sum Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 3, ${dynamic_id} + 2, 'SM-1', true);

    # Mock POST /email to return HTTP 200 with JSON {'status': 'SENT'}
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}

    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    date=${SPACE * 3}  # Using ${SPACE} to represent an empty string
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${resp}=    POST On Session    api    /lots/${lot_id}/daily-summary    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Date is required

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-008_Verify_API_Returns_400_When_Date_Is_Not_YYYY_MM_DD
    [Documentation]    Verify API returns 400 when the date is not YYYY-MM-DD.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Sum Owner', 'sum_owner_${dynamic_id}@plrs.test', true);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 1, 'Sum Driver', 'sum_driver_${dynamic_id}@plrs.test');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 2, 'Sum Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 3, ${dynamic_id} + 2, 'SM-1', true);

    # Mock POST /email to return HTTP 200 with JSON {'status': 'SENT'}
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}

    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    date=not-a-date
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${resp}=    POST On Session    api    /lots/${lot_id}/daily-summary    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid date format. Expected YYYY-MM-DD

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-009_Verify_SQL_Injection_String_Rejected_By_Format_Validation
    [Documentation]    Verify a SQL-injection string in date is rejected by format validation, never interpolated.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(100000, 999999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Sum Owner', 'sum_owner_${dynamic_id}@plrs.test', true);
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id} + 1, 'Sum Driver', 'sum_driver_${dynamic_id}@plrs.test');
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${dynamic_id} + 2, 'Sum Lot', ${dynamic_id}, 40, '1234');
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 3, ${dynamic_id} + 2, 'SM-1', true);

    # Mock POST /email to return HTTP 200 with JSON {'status': 'SENT'}
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}

    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    date='; DROP TABLE reservations;--
    ${lot_id}=    Evaluate    ${dynamic_id} + 2
    ${resp}=    POST On Session    api    /lots/${lot_id}/daily-summary    json=${payload}    expected_status=any

    # Verification
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid date format. Expected YYYY-MM-DD

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

*** Keywords ***
Cleanup Test Case And Mock
    [Arguments]    ${id}
    Execute Sql String    DELETE FROM sessions WHERE id = ${id} + 7;
    Execute Sql String    DELETE FROM penalties WHERE id = ${id} + 6;
    Execute Sql String    DELETE FROM reservations WHERE id IN (${id} + 4, ${id} + 5);
    Execute Sql String    DELETE FROM spots WHERE id = ${id} + 3;
    Execute Sql String    DELETE FROM lots WHERE id = ${id} + 2;
    Execute Sql String    DELETE FROM drivers WHERE id = ${id} + 1;
    Execute Sql String    DELETE FROM owners WHERE id = ${id};
    Disconnect From Global Database