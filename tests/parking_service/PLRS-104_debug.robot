*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Keywords ***
Seed Base Fixture
    [Documentation]    Creates owner, lot, spot with dynamic ids. Returns owner_id, lot_id, spot_id.
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${id} + 1
    ${spot_id}=    Evaluate    ${id} + 2
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${id}, 'Owner ${id}', 'owner_${id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate) VALUES (${lot_id}, ${id}, 'Lot ${id}', 40)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${spot_id}, ${lot_id}, 'A-1', true)
    RETURN    ${id}    ${lot_id}    ${spot_id}

Cleanup NoMember Booking Data
    [Arguments]    ${id}    ${lot_id}    ${spot_id}    ${driver_id}=${None}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM reservations WHERE driver_id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE id = ${driver_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

*** Test Cases ***
TC-004_Debug_GET_web_bookings_new
    Connect To Global Database
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${owner_id}    ${lot_id}    ${spot_id}=    Seed Base Fixture
    ${params}=    Create Dictionary    lot_id=${lot_id}
    ${resp}=    GET On Session    api    /web/bookings/new    params=${params}    expected_status=any
    Status Should Be    200    ${resp}
    Log    ${resp.text}
    [Teardown]    Cleanup NoMember Booking Data    ${id}    ${lot_id}    ${spot_id}