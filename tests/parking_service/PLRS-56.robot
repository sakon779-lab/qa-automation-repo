*** Settings ***
Documentation    PLRS-56 — daily-summary and payout read date/month as an Asia/Bangkok calendar
...              period. Translated 1:1 from the approved test_designs/PLRS-56.csv.
...              Seeds are anchored to the THAI day/month boundary, so 03:00 Thai is 20:00Z the
...              PREVIOUS day by construction at any run time — that crossing is the whole card.
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Keywords ***
Business Today
    [Documentation]    The BUSINESS calendar day (Asia/Bangkok, fixed +07:00). utcnow() would name
    ...                yesterday between 00:00 and 07:00 Thai — exactly when the nightly runs.
    [Arguments]    ${days_offset}=0
    ${tz}=       Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${when}=     Evaluate    datetime.datetime.now($tz) + datetime.timedelta(days=${days_offset})    modules=datetime
    ${text}=     Evaluate    $when.strftime('%Y-%m-%d')
    RETURN    ${text}

Business This Month
    ${tz}=       Evaluate    datetime.timezone(datetime.timedelta(hours=7))    modules=datetime
    ${text}=     Evaluate    datetime.datetime.now($tz).strftime('%Y-%m')    modules=datetime
    RETURN    ${text}

Seed Owner Chain
    [Documentation]    owner -> driver -> lot -> spot, all keyed by the same id (different tables).
    [Arguments]    ${id}
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active, subscription_fee) VALUES (${id}, 'TZ Owner', 'tz_own_${id}@plrs.test', true, 300)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${id}, 'TZ Driver', 'tz_drv_${id}@plrs.test')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${id}, 'TZ Lot', ${id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${id}, ${id}, 'TZ-1', true)

Seed Reservation At Thai Hour
    [Documentation]    A reservation pinned to `hours` after Thai midnight of the current Thai
    ...                day (base=day) or of the 1st of the current Thai month (base=month).
    [Arguments]    ${id}    ${res_id}    ${hours}    ${price}=40    ${base}=day
    Execute Sql String    INSERT INTO reservations (id, driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${res_id}, ${id}, ${id}, ${id}, date_trunc('${base}', NOW() AT TIME ZONE 'Asia/Bangkok') AT TIME ZONE 'Asia/Bangkok' + INTERVAL '${hours} hours', date_trunc('${base}', NOW() AT TIME ZONE 'Asia/Bangkok') AT TIME ZONE 'Asia/Bangkok' + INTERVAL '${hours} hours' + INTERVAL '1 hour', 'COMPLETED', ${price})

Cleanup TZ Test Data
    [Arguments]    ${id}    ${payout_amount}=${EMPTY}
    IF    '${payout_amount}' != ''
        Run Keyword And Ignore Error    Execute Sql String    DELETE FROM payments WHERE kind = 'PAYOUT' AND reservation_id IS NULL AND amount = ${payout_amount}
    END
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE lot_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Status Should Be
    [Arguments]    ${expected_status}    ${response}
    Should Be Equal As Integers    ${response.status_code}    ${expected_status}

*** Test Cases ***
TC-001_Booking_At_0300_Thai_Counts_On_That_Thai_Day
    [Documentation]    03:00 Thai is 20:00Z the previous day — the attribution this card changes.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Chain    ${dynamic_id}
    Seed Reservation At Thai Hour    ${dynamic_id}    ${dynamic_id}    3
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}
    Create Global API Session
    ${today}=      Business Today
    ${payload}=    Create Dictionary    date=${today}
    ${resp}=       POST On Session    api    /lots/${dynamic_id}/daily-summary    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[lot_id]    ${dynamic_id}
    Should Be Equal As Strings     ${json}[date]      ${today}
    Should Be Equal As Integers    ${json}[bookings]  1
    Should Be Equal As Numbers     ${json}[utilization_pct]    0.0
    Should Be Equal As Integers    ${json}[revenue]   30
    Should Be True                 ${json}[emailed]
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}

TC-002_Booking_At_1000_Thai_Still_Counts_Same_Day
    [Documentation]    Both zones agree on this one — the no-regression control.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Chain    ${dynamic_id}
    Seed Reservation At Thai Hour    ${dynamic_id}    ${dynamic_id}    10
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}
    Create Global API Session
    ${today}=      Business Today
    ${payload}=    Create Dictionary    date=${today}
    ${resp}=       POST On Session    api    /lots/${dynamic_id}/daily-summary    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[bookings]    1
    Should Be Equal As Integers    ${json}[revenue]     30
    Should Be True                 ${json}[emailed]
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}

TC-003_Same_Booking_Absent_From_Previous_Thai_Day
    [Documentation]    Proves the 03:00 Thai row moved OUT of the old UTC-day window.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Chain    ${dynamic_id}
    Seed Reservation At Thai Hour    ${dynamic_id}    ${dynamic_id}    3
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}
    Create Global API Session
    ${yesterday}=    Business Today    -1
    ${payload}=      Create Dictionary    date=${yesterday}
    ${resp}=         POST On Session    api    /lots/${dynamic_id}/daily-summary    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings     ${json}[date]        ${yesterday}
    Should Be Equal As Integers    ${json}[bookings]    0
    Should Be Equal As Integers    ${json}[revenue]     0
    Should Be True                 ${json}[emailed]
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}

TC-004_Thai_Day_Spans_0300_To_2300_Across_Two_UTC_Dates
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${res2}=          Evaluate    ${dynamic_id} + 1
    Seed Owner Chain    ${dynamic_id}
    Seed Reservation At Thai Hour    ${dynamic_id}    ${dynamic_id}    3
    Seed Reservation At Thai Hour    ${dynamic_id}    ${res2}    23
    Arm Mock Expectation    POST    /email    200    {"status": "SENT"}
    Create Global API Session
    ${today}=      Business Today
    ${payload}=    Create Dictionary    date=${today}
    ${resp}=       POST On Session    api    /lots/${dynamic_id}/daily-summary    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[bookings]    2
    Should Be Equal As Integers    ${json}[revenue]     60
    Should Be True                 ${json}[emailed]
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}

TC-005_First_Of_Month_At_0300_Thai_Counts_In_That_Thai_Month
    [Documentation]    03:00 Thai on the 1st is 20:00Z on the LAST day of the previous month.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Chain    ${dynamic_id}
    Seed Reservation At Thai Hour    ${dynamic_id}    ${dynamic_id}    3    40    month
    Create Global API Session
    ${month}=      Business This Month
    ${payload}=    Create Dictionary    month=${month}
    ${resp}=       POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[owner_id]        ${dynamic_id}
    Should Be Equal As Strings     ${json}[month]           ${month}
    Should Be Equal As Integers    ${json}[gross]           40
    Should Be Equal As Integers    ${json}[platform_fees]   10
    Should Be Equal As Integers    ${json}[subscription]    300
    Should Be Equal As Integers    ${json}[payout]          0
    Should Not Be True             ${json}[transferred]
    Should Be True                 ${json}[owes_platform]
    # Post-Assertion from CSV — a zero payout must not record a payment
    ${db_count_result}=    Query    SELECT count(*) FROM payments WHERE kind = 'PAYOUT' AND reservation_id IS NULL AND amount = 0
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}

TC-006_Full_Thai_Month_Pays_Out_Normally
    [Documentation]    R10 arithmetic is unchanged by the window shift.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Chain    ${dynamic_id}
    FOR    ${i}    IN RANGE    10
        ${res_id}=    Evaluate    ${dynamic_id} + ${i}
        ${hours}=     Evaluate    24 * (${i} + 1) + 12
        Seed Reservation At Thai Hour    ${dynamic_id}    ${res_id}    ${hours}    100    month
    END
    Arm Mock Expectation    POST    /transfer    200    {"status": "SUCCESS"}
    Create Global API Session
    ${month}=      Business This Month
    ${payload}=    Create Dictionary    month=${month}
    ${resp}=       POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[gross]           1000
    Should Be Equal As Integers    ${json}[platform_fees]   100
    Should Be Equal As Integers    ${json}[subscription]    300
    Should Be Equal As Integers    ${json}[payout]          600
    Should Be True                 ${json}[transferred]
    Should Not Be True             ${json}[owes_platform]
    # presence, not exact count: a PAYOUT payment has no test-scoping column
    ${db_count_result}=    Query    SELECT count(*) FROM payments WHERE kind = 'PAYOUT' AND reservation_id IS NULL AND amount = 600
    Should Be True    ${db_count_result[0][0]} >= 1
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}    600

TC-007_Daily_Summary_Still_Rejects_Malformed_Date
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Chain    ${dynamic_id}
    Create Global API Session
    ${payload}=    Create Dictionary    date=31-07-2026
    ${resp}=       POST On Session    api    /lots/${dynamic_id}/daily-summary    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid date format. Expected YYYY-MM-DD
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}

TC-008_Daily_Summary_Still_Rejects_Missing_Date
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Chain    ${dynamic_id}
    Create Global API Session
    ${empty_payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /lots/${dynamic_id}/daily-summary    json=${empty_payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Date is required
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}

TC-009_Payout_Still_Rejects_Malformed_Month
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Chain    ${dynamic_id}
    Create Global API Session
    ${payload}=    Create Dictionary    month=2026/08
    ${resp}=       POST On Session    api    /owners/${dynamic_id}/payout    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Invalid month format. Expected YYYY-MM
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}

TC-010_Payout_Still_Rejects_Missing_Month
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Seed Owner Chain    ${dynamic_id}
    Create Global API Session
    ${empty_payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /owners/${dynamic_id}/payout    json=${empty_payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Month is required
    [Teardown]    Cleanup TZ Test Data    ${dynamic_id}
