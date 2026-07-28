*** Settings ***
Documentation     PLRS-8 — GET /lots/{id}/availability. Generated from test_designs/PLRS-8.csv.
...               Semantics (contract): total_spots = ACTIVE spots; available = total minus spots
...               held by a SOFT_LOCKED/CONFIRMED reservation covering now. Each test seeds its own
...               parent chain with dynamic ids and cleans up child-first.
Library           RequestsLibrary
Library           Collections
Library           DatabaseLibrary
Resource          ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_All_Active_One_Held
    ${ids}=    Seed Availability Lot    active=3    inactive=0    held=1
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    /lots/${ids}[lot]/availability    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[lot_id]    ${ids}[lot]
    Should Be Equal As Integers    ${json}[total_spots]    3
    Should Be Equal As Integers    ${json}[available]    2
    [Teardown]    Cleanup Availability Data    ${ids}

TC-002_All_Active_None_Held
    ${ids}=    Seed Availability Lot    active=5    inactive=0    held=0
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    /lots/${ids}[lot]/availability    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[total_spots]    5
    Should Be Equal As Integers    ${json}[available]    5
    [Teardown]    Cleanup Availability Data    ${ids}

TC-003_Unknown_Lot_Returns_404
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    /lots/999999/availability    expected_status=any
    Status Should Be    404    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Lot not found

TC-004_No_Active_Spots
    ${ids}=    Seed Availability Lot    active=0    inactive=2    held=0
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    /lots/${ids}[lot]/availability    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[total_spots]    0
    Should Be Equal As Integers    ${json}[available]    0
    [Teardown]    Cleanup Availability Data    ${ids}

TC-005_All_Active_All_Held
    ${ids}=    Seed Availability Lot    active=3    inactive=0    held=3
    Create Session    api    ${BASE_API_URL}
    ${resp}=    GET On Session    api    /lots/${ids}[lot]/availability    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[total_spots]    3
    Should Be Equal As Integers    ${json}[available]    0
    [Teardown]    Cleanup Availability Data    ${ids}

*** Keywords ***
Seed Availability Lot
    [Documentation]    Seed owner→driver→lot→spots (active/inactive) and hold the first `held`
    ...                ACTIVE spots with a now-covering SOFT_LOCKED reservation. Dynamic ids.
    [Arguments]    ${active}    ${inactive}    ${held}
    Connect To Global Database
    ${base}=    Evaluate    random.randint(1000000, 9000000)    modules=random
    ${o_id}=    Evaluate    ${base} + 1
    ${d_id}=    Evaluate    ${base} + 2
    ${l_id}=    Evaluate    ${base} + 3
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${o_id}, 'Avail Owner', 'owner_${o_id}@test.plrs', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${d_id}, 'Avail Driver', 'driver_${d_id}@test.plrs')
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate) VALUES (${l_id}, 'Avail Lot', ${o_id}, 40)
    ${total}=    Evaluate    ${active} + ${inactive}
    FOR    ${i}    IN RANGE    ${active}
        ${s_id}=    Evaluate    ${base} + 10 + ${i}
        Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${s_id}, ${l_id}, 'S-${i}', true)
    END
    FOR    ${i}    IN RANGE    ${inactive}
        ${s_id}=    Evaluate    ${base} + 50 + ${i}
        Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${s_id}, ${l_id}, 'X-${i}', false)
    END
    FOR    ${i}    IN RANGE    ${held}
        ${s_id}=    Evaluate    ${base} + 10 + ${i}
        Execute Sql String    INSERT INTO reservations (driver_id, spot_id, lot_id, start_time, end_time, status, price) VALUES (${d_id}, ${s_id}, ${l_id}, now() - interval '1 hour', now() + interval '1 hour', 'SOFT_LOCKED', 80)
    END
    ${ids}=    Create Dictionary    owner=${o_id}    driver=${d_id}    lot=${l_id}
    RETURN    ${ids}

Cleanup Availability Data
    [Arguments]    ${ids}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE lot_id = ${ids}[lot]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE lot_id = ${ids}[lot]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${ids}[lot]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${ids}[driver]
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${ids}[owner]
    Disconnect From Global Database
