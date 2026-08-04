*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Keywords ***
Seed Driver
    [Arguments]    ${email}    ${plate}    ${id}
    Execute Sql String    INSERT INTO drivers (id, name, email, plate) VALUES (${id}, 'Legacy', '${email}', '${plate}')

Seed User
    [Arguments]    ${email}
    ${uuid}=    Evaluate    str(uuid.uuid4())    modules=uuid
    Execute Sql String    INSERT INTO users (id, name, email, phone, password_hash, created_at) VALUES ('${uuid}', 'Existing', '${email}', '0812345678', 'x', NOW())

Cleanup Signup Data
    [Arguments]    ${email}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE lower(email) = lower('${email}')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM drivers WHERE lower(email) = lower('${email}')
    Disconnect From Global Database

*** Test Cases ***
TC-001_Verify_signup_with_existing_driver_email_returns_303_and_creates_second_driver
    [Documentation]    Verify signup with email that already exists in drivers returns 303 and creates a second drivers row
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    clash_${dynamic_id}@test.plrs
    Seed Driver    ${email}    ZZ9999    ${dynamic_id}
    Create Global API Session
    ${form}=    Create Dictionary    name=Clash    email=${email}    phone=0812345678    password=password123
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    ${count}=    Query    SELECT count(*) FROM drivers WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    2
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Signup Data    ${email}

TC-002_Verify_signup_with_fresh_email_returns_303_and_creates_one_driver
    [Documentation]    Verify signup with a fresh email returns 303 and creates one drivers row
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    fresh_${dynamic_id}@test.plrs
    Create Global API Session
    ${form}=    Create Dictionary    name=NewUser    email=${email}    phone=0812345678    password=password123
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    ${count}=    Query    SELECT count(*) FROM drivers WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Signup Data    ${email}

TC-003_Verify_signup_with_existing_user_email_returns_200_with_error
    [Documentation]    Verify signup with email already in users returns 200 with 'This email is already registered'
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    dup_${dynamic_id}@test.plrs
    Seed User    ${email}
    Create Global API Session
    ${form}=    Create Dictionary    name=Second    email=${email}    phone=0812345678    password=password123
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any
    Should Be Equal As Integers    ${resp.status_code}    200
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    This email is already registered
    Should Contain    ${body}    href="/web/login"
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Signup Data    ${email}

TC-004_Verify_signup_with_short_password_returns_200_with_error
    [Documentation]    Verify signup with password shorter than 8 characters returns 200 with error
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    short_${dynamic_id}@test.plrs
    Create Global API Session
    ${form}=    Create Dictionary    name=Short    email=${email}    phone=0812345678    password=short
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any
    Should Be Equal As Integers    ${resp.status_code}    200
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Password must be at least 8 characters
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Signup Data    ${email}
TC-005_Verify_signup_with_email_in_multiple_drivers_returns_303_and_creates_third
    [Documentation]    Verify signup with email that exists in MULTIPLE drivers rows returns 303 and creates yet another drivers row (3 total)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    multi_${dynamic_id}@test.plrs
    Seed Driver    ${email}    ZZ9998    ${dynamic_id}
    Seed Driver    ${email}    ZZ9997    ${dynamic_id + 1}
    Create Global API Session
    ${form}=    Create Dictionary    name=Multi    email=${email}    phone=0812345678    password=password123
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    ${count}=    Query    SELECT count(*) FROM drivers WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    3
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Signup Data    ${email}

TC-006_Verify_signup_with_email_in_both_drivers_and_users_returns_200_with_error
    [Documentation]    Verify signup with email in BOTH drivers and users returns 200 with 'This email is already registered'
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    both_${dynamic_id}@test.plrs
    Seed Driver    ${email}    ZZ9999    ${dynamic_id}
    Seed User    ${email}
    Create Global API Session
    ${form}=    Create Dictionary    name=Second    email=${email}    phone=0812345678    password=password123
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any
    Should Be Equal As Integers    ${resp.status_code}    200
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    This email is already registered
    Should Contain    ${body}    href="/web/login"
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Signup Data    ${email}

TC-007_Verify_signup_with_case_variant_email_in_drivers_returns_303
    [Documentation]    Verify signup with case-variant email that exists in drivers returns 303 and creates a second drivers row
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    case_${dynamic_id}@test.plrs
    ${email_upper}=    Set Variable    CASE_${dynamic_id}@TEST.PLRS
    Seed Driver    ${email}    ZZ9999    ${dynamic_id}
    Create Global API Session
    ${form}=    Create Dictionary    name=Case    email=${email_upper}    phone=0812345678    password=password123
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    ${count}=    Query    SELECT count(*) FROM drivers WHERE lower(email) = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    2
    ${count}=    Query    SELECT count(*) FROM users WHERE lower(email) = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Signup Data    ${email}

TC-008_Verify_signup_with_case_variant_email_in_users_returns_200_with_error
    [Documentation]    Verify signup with case-variant email already in users returns 200 with 'This email is already registered'
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    caseuser_${dynamic_id}@test.plrs
    ${email_upper}=    Set Variable    CASEUSER_${dynamic_id}@TEST.PLRS
    Seed User    ${email}
    Create Global API Session
    ${form}=    Create Dictionary    name=Second    email=${email_upper}    phone=0812345678    password=password123
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any
    Should Be Equal As Integers    ${resp.status_code}    200
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    This email is already registered
    Should Contain    ${body}    href="/web/login"
    ${count}=    Query    SELECT count(*) FROM users WHERE lower(email) = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Signup Data    ${email}