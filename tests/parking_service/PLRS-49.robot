*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_owner_renders_page_with_forms_and_htmx
    [Documentation]    Verify GET /web/owner renders the page with all three forms and htmx wiring
    Create Global API Session
    ${resp}=    GET On Session    api    /web/owner    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    สมัคร Owner
    Should Contain    ${body}    สร้างลาน
    Should Contain    ${body}    เพิ่มช่องจอด
    Should Contain    ${body}    hx-post="/web/owner/register"
    Should Contain    ${body}    hx-post="/web/owner/lots"
    Should Contain    ${body}    hx-post="/web/owner/spots"
    Should Contain    ${body}    hx-target="#owner-result"
    Should Contain    ${body}    hx-target="#lot-result"
    Should Contain    ${body}    hx-target="#spots-result"
    Should Contain    ${body}    id="owner-result"
    Should Contain    ${body}    id="lot-result"
    Should Contain    ${body}    id="spots-result"

TC-002_Verify_POST_web_owner_register_creates_owner
    [Documentation]    Verify POST /web/owner/register creates an owner and returns HTML fragment
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Create Global API Session
    ${form}=    Create Dictionary    name=New Owner ${dynamic_id}    email=new_owner_${dynamic_id}@test.com
    ${resp}=    POST On Session    api    /web/owner/register    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    New Owner ${dynamic_id}
    Should Contain    ${body}    new_owner_${dynamic_id}@test.com
    ${count}=    Query    SELECT count(*) FROM owners WHERE email = 'new_owner_${dynamic_id}@test.com'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup TC002 Data    ${dynamic_id}

TC-003_Verify_POST_web_owner_register_duplicate_email_error
    [Documentation]    Verify POST /web/owner/register with duplicate email shows inline error
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Existing Owner', 'existing_${dynamic_id}@test.com', true)
    Create Global API Session
    ${form}=    Create Dictionary    name=Duplicate Owner    email=existing_${dynamic_id}@test.com
    ${resp}=    POST On Session    api    /web/owner/register    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Email already exists
    ${count}=    Query    SELECT count(*) FROM owners WHERE email = 'existing_${dynamic_id}@test.com'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup TC003 Data    ${dynamic_id}

TC-004_Verify_POST_web_owner_register_blank_name_error
    [Documentation]    Verify POST /web/owner/register with blank name shows inline error
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Create Global API Session
    ${form}=    Create Dictionary    name=${EMPTY}    email=blank_name_${dynamic_id}@test.com
    ${resp}=    POST On Session    api    /web/owner/register    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Name is required
    ${count}=    Query    SELECT count(*) FROM owners WHERE email = 'blank_name_${dynamic_id}@test.com'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup TC004 Data    ${dynamic_id}

TC-005_Verify_POST_web_owner_register_blank_email_error
    [Documentation]    Verify POST /web/owner/register with blank email shows inline error
    Create Global API Session
    ${form}=    Create Dictionary    name=No Email Owner    email=${EMPTY}
    ${resp}=    POST On Session    api    /web/owner/register    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Email is required

TC-006_Verify_POST_web_owner_lots_creates_lot
    [Documentation]    Verify POST /web/owner/lots creates a lot and returns HTML fragment
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Create Global API Session
    ${form}=    Create Dictionary    name=Test Lot ${dynamic_id}    owner_id=${dynamic_id}    hourly_rate=40    wall_code=1234
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Test Lot ${dynamic_id}
    Should Contain    ${body}    ฿40/ชม.
    ${count}=    Query    SELECT count(*) FROM lots WHERE name = 'Test Lot ${dynamic_id}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup TC006 Data    ${dynamic_id}

TC-007_Verify_POST_web_owner_lots_invalid_wall_code
    [Documentation]    Verify POST /web/owner/lots with non-numeric wall_code shows inline error
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Create Global API Session
    ${form}=    Create Dictionary    name=Invalid Wall Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=12a4
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Wall code must be a 4-digit numeric value
    ${count}=    Query    SELECT count(*) FROM lots WHERE name = 'Invalid Wall Lot'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup TC007 Data    ${dynamic_id}

TC-008_Verify_POST_web_owner_lots_short_wall_code
    [Documentation]    Verify POST /web/owner/lots with 3-digit wall_code shows inline error
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Create Global API Session
    ${form}=    Create Dictionary    name=Short Wall Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=123
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Wall code must be a 4-digit numeric value
    ${count}=    Query    SELECT count(*) FROM lots WHERE name = 'Short Wall Lot'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup TC007 Data    ${dynamic_id}

TC-009_Verify_POST_web_owner_lots_long_wall_code
    [Documentation]    Verify POST /web/owner/lots with 5-digit wall_code shows inline error
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Create Global API Session
    ${form}=    Create Dictionary    name=Long Wall Lot    owner_id=${dynamic_id}    hourly_rate=40    wall_code=12345
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Wall code must be a 4-digit numeric value
    ${count}=    Query    SELECT count(*) FROM lots WHERE name = 'Long Wall Lot'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup TC007 Data    ${dynamic_id}

TC-010_Verify_POST_web_owner_lots_blank_name_error
    [Documentation]    Verify POST /web/owner/lots with blank name shows inline error
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Create Global API Session
    ${form}=    Create Dictionary    name=${EMPTY}    owner_id=${dynamic_id}    hourly_rate=40    wall_code=1234
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Name is required
    ${count}=    Query    SELECT count(*) FROM lots WHERE owner_id = ${dynamic_id}
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup TC007 Data    ${dynamic_id}

TC-011_Verify_POST_web_owner_lots_blank_owner_id_error
    [Documentation]    Verify POST /web/owner/lots with blank owner_id shows inline error
    Create Global API Session
    ${form}=    Create Dictionary    name=No Owner Lot    owner_id=${EMPTY}    hourly_rate=40    wall_code=1234
    ${resp}=    POST On Session    api    /web/owner/lots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Owner ID is required

TC-012_Verify_POST_web_owner_lots_id_spots_creates_spots
    [Documentation]    Verify POST /web/owner/lots/{id}/spots creates spots from comma-separated codes
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${lot_id}, 'Lot ${dynamic_id}', ${dynamic_id}, 40, '1234')
    Create Global API Session
    ${form}=    Create Dictionary    codes=A-12,B-13
    ${resp}=    POST On Session    api    /web/owner/lots/${lot_id}/spots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A-12
    Should Contain    ${body}    B-13
    Should Contain    ${body}    spot_count: 2
    ${count}=    Query    SELECT count(*) FROM spots WHERE lot_id = ${lot_id}
    Should Be Equal As Integers    ${count[0][0]}    2
    [Teardown]    Cleanup TC012 Data    ${dynamic_id}    ${lot_id}

TC-013_Verify_POST_web_owner_lots_id_spots_trims_whitespace
    [Documentation]    Verify POST /web/owner/lots/{id}/spots trims whitespace around comma-separated codes
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${lot_id}, 'Lot ${dynamic_id}', ${dynamic_id}, 40, '1234')
    Create Global API Session
    ${form}=    Create Dictionary    codes=${SPACE}A-12${SPACE},${SPACE}B-13${SPACE}
    ${resp}=    POST On Session    api    /web/owner/lots/${lot_id}/spots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    A-12
    Should Contain    ${body}    B-13
    Should Contain    ${body}    spot_count: 2
    ${count}=    Query    SELECT count(*) FROM spots WHERE lot_id = ${lot_id}
    Should Be Equal As Integers    ${count[0][0]}    2
    [Teardown]    Cleanup TC012 Data    ${dynamic_id}    ${lot_id}

TC-014_Verify_POST_web_owner_lots_unknown_id_spots_error
    [Documentation]    Verify POST /web/owner/lots/{id}/spots with unknown lot_id shows inline error
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(900000000, 999999999)    modules=random
    ${form}=    Create Dictionary    codes=A-12
    ${resp}=    POST On Session    api    /web/owner/lots/${non_existent_id}/spots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Lot not found

TC-015_Verify_POST_web_owner_lots_id_spots_empty_codes
    [Documentation]    Verify POST /web/owner/lots/{id}/spots with empty codes re-renders current spot list
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    ${spot_id}=    Evaluate    ${dynamic_id} + 2
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${lot_id}, 'Lot ${dynamic_id}', ${dynamic_id}, 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code) VALUES (${spot_id}, ${lot_id}, 'EXISTING-01')
    Create Global API Session
    ${form}=    Create Dictionary    codes=${EMPTY}
    ${resp}=    POST On Session    api    /web/owner/lots/${lot_id}/spots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    EXISTING-01
    Should Contain    ${body}    spot_count: 1
    ${count}=    Query    SELECT count(*) FROM spots WHERE lot_id = ${lot_id}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup TC015 Data    ${dynamic_id}    ${lot_id}    ${spot_id}

TC-016_Verify_POST_web_owner_spots_creates_spots
    [Documentation]    Verify POST /web/owner/spots takes lot_id from form body and creates spots
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${lot_id}=    Evaluate    ${dynamic_id} + 1
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner ${dynamic_id}', 'owner_${dynamic_id}@test.com', true)
    Execute Sql String    INSERT INTO lots (id, name, owner_id, hourly_rate, wall_code) VALUES (${lot_id}, 'Lot ${dynamic_id}', ${dynamic_id}, 40, '1234')
    Create Global API Session
    ${form}=    Create Dictionary    lot_id=${lot_id}    codes=C-21,C-22
    ${resp}=    POST On Session    api    /web/owner/spots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    C-21
    Should Contain    ${body}    C-22
    Should Contain    ${body}    spot_count: 2
    ${count}=    Query    SELECT count(*) FROM spots WHERE lot_id = ${lot_id}
    Should Be Equal As Integers    ${count[0][0]}    2
    [Teardown]    Cleanup TC012 Data    ${dynamic_id}    ${lot_id}

TC-017_Verify_POST_web_owner_spots_blank_lot_id_error
    [Documentation]    Verify POST /web/owner/spots with blank lot_id shows 'Lot not found'
    Create Global API Session
    ${form}=    Create Dictionary    lot_id=${EMPTY}    codes=A-12
    ${resp}=    POST On Session    api    /web/owner/spots    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Lot not found

*** Keywords ***
Cleanup TC002 Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE email = 'new_owner_${id}@test.com'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup TC003 Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup TC004 Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE email = 'blank_name_${id}@test.com'
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup TC006 Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE name = 'Test Lot ${id}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup TC007 Data
    [Arguments]    ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE owner_id = ${id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup TC012 Data
    [Arguments]    ${id}    ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE lot_id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup TC015 Data
    [Arguments]    ${id}    ${lot_id}    ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE id = ${spot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM spots WHERE lot_id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM lots WHERE id = ${lot_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Run Keyword And Ignore Error    Disconnect From Global Database