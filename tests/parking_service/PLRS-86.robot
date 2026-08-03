*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_profile_with_valid_session_returns_200
    [Documentation]    Verify GET /web/profile with valid session returns 200 and shows logged-in user's info
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${vehicle_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    # Create user via signup (properly hashes password) and get session cookie
    ${cookie}=    Signup And Get Session Cookie    ${email}
    # Get the actual user_id from DB
    ${user_id}=    Get User Id By Email    ${email}
    # Seed vehicle directly in DB
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${vehicle_id}', '${user_id}', 'กข5678', NOW())
    # Exercise: GET /web/profile with cookie
    ${resp}=    GET On Session    api    /web/profile    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Seed User
    Should Contain    ${body}    ${email}
    Should Contain    ${body}    0812345678
    Should Contain    ${body}    รถของฉัน
    Should Contain    ${body}    กข5678
    Should Contain    ${body}    เพิ่มรถ
    Should Contain    ${body}    hx-post="/web/profile/vehicles"
    Should Contain    ${body}    vehicle-result
    Should Contain    ${body}    vehicle-list
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE user_id = '${user_id}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

TC-002_Verify_GET_profile_without_cookie_redirects_to_login
    [Documentation]    Verify GET /web/profile without session cookie returns 303 redirect
    Create Global API Session
    ${resp}=    GET On Session    api    /web/profile    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web/login?next=/web/profile

TC-003_Verify_GET_profile_with_invalid_cookie_redirects_to_login
    [Documentation]    Verify GET /web/profile with invalid session cookie returns 303 redirect
    Create Global API Session
    ${cookie}=    Create Dictionary    plrs_session=invalid-session-token
    ${resp}=    GET On Session    api    /web/profile    cookies=${cookie}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web/login?next=/web/profile

TC-004_Verify_POST_vehicles_with_valid_plate_adds_vehicle
    [Documentation]    Verify POST /web/profile/vehicles with valid plate adds vehicle
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Exercise: POST new vehicle
    ${form}=    Create Dictionary    plate=กข1234
    ${resp}=    POST On Session    api    /web/profile/vehicles    data=${form}    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    กข1234
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE user_id = '${user_id}' AND plate = 'กข1234'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

TC-005_Verify_POST_vehicles_with_empty_plate_returns_error
    [Documentation]    Verify POST /web/profile/vehicles with empty plate returns 'Plate is required'
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Exercise: POST with empty plate
    ${form}=    Create Dictionary    plate=${EMPTY}
    ${resp}=    POST On Session    api    /web/profile/vehicles    data=${form}    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    Plate is required
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE user_id = '${user_id}'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

TC-006_Verify_POST_vehicles_with_whitespace_plate_returns_error
    [Documentation]    Verify POST /web/profile/vehicles with whitespace-only plate returns 'Plate is required'
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Exercise: POST with whitespace-only plate
    ${form}=    Create Dictionary    plate=${SPACE * 3}
    ${resp}=    POST On Session    api    /web/profile/vehicles    data=${form}    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    Plate is required
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE user_id = '${user_id}'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

TC-007_Verify_POST_vehicles_with_duplicate_plate_returns_error
    [Documentation]    Verify POST /web/profile/vehicles with duplicate plate returns error
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${vehicle_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Seed vehicle directly in DB
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${vehicle_id}', '${user_id}', 'กข5678', NOW())
    # Exercise: POST duplicate plate
    ${form}=    Create Dictionary    plate=กข5678
    ${resp}=    POST On Session    api    /web/profile/vehicles    data=${form}    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    This plate is already in your profile
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE user_id = '${user_id}' AND plate = 'กข5678'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

TC-008_Verify_POST_vehicles_with_plate_from_another_user_is_allowed
    [Documentation]    Verify POST /web/profile/vehicles with plate from another user is allowed
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${other_user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${other_vehicle_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${other_email}=    Set Variable    other_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Create other user via signup
    ${other_cookie}=    Signup And Get Session Cookie    ${other_email}
    ${other_user_id}=    Get User Id By Email    ${other_email}
    # Seed vehicle for other user
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${other_vehicle_id}', '${other_user_id}', 'กข5678', NOW())
    # Exercise: POST plate that belongs to another user
    ${form}=    Create Dictionary    plate=กข5678
    ${resp}=    POST On Session    api    /web/profile/vehicles    data=${form}    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    กข5678
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE user_id = '${user_id}' AND plate = 'กข5678'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Multi User Vehicle Test Data    ${user_id}    ${other_user_id}    ${other_vehicle_id}

TC-009_Verify_POST_vehicles_with_trimmed_plate_is_stored
    [Documentation]    Verify POST /web/profile/vehicles with leading/trailing spaces is trimmed
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Exercise: POST with spaces around plate
    ${form}=    Create Dictionary    plate=${SPACE * 2}กข1234${SPACE * 2}
    ${resp}=    POST On Session    api    /web/profile/vehicles    data=${form}    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    กข1234
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE user_id = '${user_id}' AND plate = 'กข1234'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

TC-010_Verify_POST_delete_own_vehicle_returns_updated_list
    [Documentation]    Verify POST /web/profile/vehicles/{id}/delete with own vehicle
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${vehicle_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Seed vehicle directly in DB
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${vehicle_id}', '${user_id}', 'กข5678', NOW())
    # Exercise: DELETE own vehicle
    ${resp}=    POST On Session    api    /web/profile/vehicles/${vehicle_id}/delete    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    ยังไม่มีรถในโปรไฟล์
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE id = '${vehicle_id}'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

TC-011_Verify_POST_delete_another_users_vehicle_returns_not_found
    [Documentation]    Verify POST /web/profile/vehicles/{id}/delete with another user's vehicle
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${other_user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${other_vehicle_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${other_email}=    Set Variable    other_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    ${other_cookie}=    Signup And Get Session Cookie    ${other_email}
    ${other_user_id}=    Get User Id By Email    ${other_email}
    # Seed vehicle for other user
    Execute Sql String    INSERT INTO vehicles (id, user_id, plate, created_at) VALUES ('${other_vehicle_id}', '${other_user_id}', 'กข5678', NOW())
    # Exercise: DELETE another user's vehicle
    ${resp}=    POST On Session    api    /web/profile/vehicles/${other_vehicle_id}/delete    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    Vehicle not found
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE id = '${other_vehicle_id}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Multi User Vehicle Test Data    ${user_id}    ${other_user_id}    ${other_vehicle_id}

TC-012_Verify_POST_delete_nonexistent_vehicle_returns_not_found
    [Documentation]    Verify POST /web/profile/vehicles/{id}/delete with non-existent vehicle
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Exercise: DELETE non-existent vehicle
    ${non_existent_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${resp}=    POST On Session    api    /web/profile/vehicles/${non_existent_id}/delete    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    Vehicle not found
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM users WHERE id = '${user_id}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

TC-013_Verify_POST_delete_with_non_uuid_id_returns_not_found
    [Documentation]    Verify POST /web/profile/vehicles/{id}/delete with non-UUID id
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Exercise: DELETE with non-UUID id
    ${resp}=    POST On Session    api    /web/profile/vehicles/not-a-uuid/delete    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    Should Contain    ${resp.text}    Vehicle not found
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM users WHERE id = '${user_id}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

TC-014_Verify_POST_vehicles_without_cookie_redirects_to_login
    [Documentation]    Verify POST /web/profile/vehicles without cookie returns 303 redirect
    Create Global API Session
    ${form}=    Create Dictionary    plate=กข1234
    ${resp}=    POST On Session    api    /web/profile/vehicles    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web/login?next=/web/profile

TC-015_Verify_POST_delete_without_cookie_redirects_to_login
    [Documentation]    Verify POST /web/profile/vehicles/{id}/delete without cookie returns 303 redirect
    Create Global API Session
    ${vehicle_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${resp}=    POST On Session    api    /web/profile/vehicles/${vehicle_id}/delete    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web/login?next=/web/profile

TC-016_Verify_GET_profile_with_zero_vehicles_shows_empty_list
    [Documentation]    Verify GET /web/profile for user with zero vehicles
    Connect To Global Database
    ${user_id}=    Evaluate    str(uuid.uuid4())    modules=uuid
    ${email}=    Set Variable    seed_${user_id}@plrs.test
    ${cookie}=    Signup And Get Session Cookie    ${email}
    ${user_id}=    Get User Id By Email    ${email}
    # Exercise: GET /web/profile with cookie
    ${resp}=    GET On Session    api    /web/profile    cookies=${cookie}    expected_status=any
    # Verify
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Seed User
    Should Contain    ${body}    ${email}
    Should Contain    ${body}    0812345678
    Should Contain    ${body}    รถของฉัน
    Should Contain    ${body}    เพิ่มรถ
    # Post-assertion
    ${count}=    Query    SELECT count(*) FROM vehicles WHERE user_id = '${user_id}'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Vehicle Test Data    ${user_id}

*** Keywords ***
Signup And Get Session Cookie
    [Arguments]    ${email}
    Create Global API Session
    ${form}=    Create Dictionary    name=Seed User    email=${email}    phone=0812345678    password=password123
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    ${cookie}=    Create Dictionary    plrs_session=${resp.cookies}[plrs_session]
    RETURN    ${cookie}

Get User Id By Email
    [Arguments]    ${email}
    ${result}=    Query    SELECT id FROM users WHERE email = '${email}'
    RETURN    ${result[0][0]}

Cleanup Vehicle Test Data
    [Arguments]    ${user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id = '${user_id}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = '${user_id}'
    Run Keyword And Ignore Error    Disconnect From Global Database

Cleanup Multi User Vehicle Test Data
    [Arguments]    ${user_id}    ${other_user_id}    ${other_vehicle_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE user_id = '${user_id}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM vehicles WHERE id = '${other_vehicle_id}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = '${user_id}'
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = '${other_user_id}'
    Run Keyword And Ignore Error    Disconnect From Global Database