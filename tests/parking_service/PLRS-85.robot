*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_signup_renders_the_signup_form_page_with_all_fields_and_helper_text
    [Documentation]    Verify GET /web/signup renders the signup form page with all fields and helper text
    Create Global API Session
    ${resp}=    GET On Session    api    /web/signup    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    สมัครสมาชิก
    Should Contain    ${body}    name
    Should Contain    ${body}    email
    Should Contain    ${body}    phone
    Should Contain    ${body}    password
    Should Contain    ${body}    อย่างน้อย 8 ตัวอักษร
    Should Contain    ${body}    hx-post="/web/signup"
    Should Contain    ${body}    hx-target="#auth-result"
    Should Contain    ${body}    id="auth-result"

TC-002_Verify_POST_web_signup_creates_a_user_auto_logs_in_and_redirects_to_web
    [Documentation]    Verify POST /web/signup creates a user, auto-logs in, and redirects to /web when no next is provided
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    somchai_${dynamic_id}@qa.plrs.test
    ${form}=    Create Dictionary    name=สมชาย ใจดี    email=${email}    phone=0812345678    password=12345678
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup User By Email    ${email}

TC-003_Verify_POST_web_signup_with_next_web_bookings_new_redirects_to_that_path
    [Documentation]    Verify POST /web/signup with next=/web/bookings/new redirects to that path (open-redirect guard allows /web paths)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    somchai_next_${dynamic_id}@qa.plrs.test
    ${form}=    Create Dictionary    name=สมชาย ใจดี    email=${email}    phone=0812345678    password=12345678    next=/web/bookings/new
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web/bookings/new
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup User By Email    ${email}

TC-004_Verify_POST_web_signup_with_next_https_evil_example_ignores_the_off_site_path
    [Documentation]    Verify POST /web/signup with next=https://evil.example ignores the off-site path and redirects to /web (open-redirect guard)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    somchai_evil_${dynamic_id}@qa.plrs.test
    ${form}=    Create Dictionary    name=สมชาย ใจดี    email=${email}    phone=0812345678    password=12345678    next=https://evil.example
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup User By Email    ${email}

TC-005_Verify_POST_web_signup_with_an_already_registered_email_returns_inline_error
    [Documentation]    Verify POST /web/signup with an already-registered email (case-insensitive) returns inline error 'This email is already registered' with a link to /web/login
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    existing_${dynamic_id}@qa.plrs.test
    ${form1}=    Create Dictionary    name=Existing User    email=${email}    phone=0811111111    password=12345678
    ${resp1}=    POST On Session    api    /web/signup    data=${form1}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp1.status_code}    303
    ${upper_email}=    Set Variable    EXISTING_${dynamic_id}@QA.PLRS.TEST
    ${form2}=    Create Dictionary    name=New User    email=${upper_email}    phone=0822222222    password=12345678
    ${resp2}=    POST On Session    api    /web/signup    data=${form2}    expected_status=any
    Status Should Be    200    ${resp2}
    ${body}=    Set Variable    ${resp2.text}
    Should Contain    ${body}    This email is already registered
    Should Contain    ${body}    href="/web/login"
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup User By Email    ${email}

TC-006_Verify_POST_web_signup_with_password_shorter_than_8_characters_returns_inline_error
    [Documentation]    Verify POST /web/signup with password shorter than 8 characters returns inline error 'Password must be at least 8 characters'
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    shortpwd_${dynamic_id}@qa.plrs.test
    ${form}=    Create Dictionary    name=Short Pwd    email=${email}    phone=0833333333    password=1234567
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Password must be at least 8 characters
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    0

TC-007_Verify_POST_web_signup_with_password_of_exactly_8_characters_succeeds
    [Documentation]    Verify POST /web/signup with password of exactly 8 characters succeeds (boundary value passes)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    boundary_${dynamic_id}@qa.plrs.test
    ${form}=    Create Dictionary    name=Boundary Pwd    email=${email}    phone=0844444444    password=12345678
    ${resp}=    POST On Session    api    /web/signup    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web
    ${count}=    Query    SELECT count(*) FROM users WHERE email = '${email}'
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup User By Email    ${email}

TC-008_Verify_GET_web_login_renders_the_login_form_page_with_email_and_password_fields
    [Documentation]    Verify GET /web/login renders the login form page with email and password fields
    Create Global API Session
    ${resp}=    GET On Session    api    /web/login    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    เข้าสู่ระบบ
    Should Contain    ${body}    email
    Should Contain    ${body}    password
    Should Contain    ${body}    hx-post="/web/login"
    Should Contain    ${body}    hx-target="#auth-result"
    Should Contain    ${body}    id="auth-result"

TC-009_Verify_GET_web_login_next_web_profile_renders_the_hidden_next_field
    [Documentation]    Verify GET /web/login?next=/web/profile renders the hidden next field with the /web path value
    Create Global API Session
    ${resp}=    GET On Session    api    /web/login    params=next=/web/profile    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    เข้าสู่ระบบ
    Should Contain    ${body}    email
    Should Contain    ${body}    password
    Should Contain    ${body}    value="/web/profile"

TC-010_Verify_POST_web_login_with_valid_credentials_sets_plrs_session_cookie_and_redirects_to_web
    [Documentation]    Verify POST /web/login with valid credentials sets plrs_session cookie and redirects to /web when no next is provided
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    login_${dynamic_id}@qa.plrs.test
    ${signup_form}=    Create Dictionary    name=Login User    email=${email}    phone=0855555555    password=12345678
    ${signup_resp}=    POST On Session    api    /web/signup    data=${signup_form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${signup_resp.status_code}    303
    ${login_form}=    Create Dictionary    email=${email}    password=12345678
    ${resp}=    POST On Session    api    /web/login    data=${login_form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web
    [Teardown]    Cleanup User By Email    ${email}

TC-011_Verify_POST_web_login_with_next_https_evil_example_ignores_the_off_site_path
    [Documentation]    Verify POST /web/login with next=https://evil.example ignores the off-site path and redirects to /web (open-redirect guard)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    loginevil_${dynamic_id}@qa.plrs.test
    ${signup_form}=    Create Dictionary    name=Login Evil    email=${email}    phone=0866666666    password=12345678
    ${signup_resp}=    POST On Session    api    /web/signup    data=${signup_form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${signup_resp.status_code}    303
    ${login_form}=    Create Dictionary    email=${email}    password=12345678    next=https://evil.example
    ${resp}=    POST On Session    api    /web/login    data=${login_form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web
    [Teardown]    Cleanup User By Email    ${email}

TC-012_Verify_POST_web_login_with_wrong_password_returns_inline_error
    [Documentation]    Verify POST /web/login with wrong password returns inline error 'Invalid email or password' (does not reveal which was wrong)
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    wrongpwd_${dynamic_id}@qa.plrs.test
    ${signup_form}=    Create Dictionary    name=Wrong Pwd    email=${email}    phone=0877777777    password=12345678
    ${signup_resp}=    POST On Session    api    /web/signup    data=${signup_form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${signup_resp.status_code}    303
    ${login_form}=    Create Dictionary    email=${email}    password=wrongpass
    ${resp}=    POST On Session    api    /web/login    data=${login_form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Invalid email or password
    [Teardown]    Cleanup User By Email    ${email}

TC-013_Verify_POST_web_login_with_unknown_email_returns_the_same_inline_error
    [Documentation]    Verify POST /web/login with unknown email returns the same inline error 'Invalid email or password' (no user enumeration)
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    nobody_${dynamic_id}@qa.plrs.test
    ${login_form}=    Create Dictionary    email=${email}    password=12345678
    ${resp}=    POST On Session    api    /web/login    data=${login_form}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Invalid email or password

TC-014_Verify_POST_web_logout_clears_the_plrs_session_cookie_and_redirects_to_web
    [Documentation]    Verify POST /web/logout clears the plrs_session cookie and redirects to /web when logged in
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    logout_${dynamic_id}@qa.plrs.test
    ${signup_form}=    Create Dictionary    name=Logout User    email=${email}    phone=0888888888    password=12345678
    ${signup_resp}=    POST On Session    api    /web/signup    data=${signup_form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${signup_resp.status_code}    303
    ${jar}=    Create Dictionary    plrs_session=${signup_resp.cookies}[plrs_session]
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/logout    data=${empty}    cookies=${jar}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web
    [Teardown]    Cleanup User By Email    ${email}

TC-015_Verify_POST_web_logout_with_no_session_cookie_still_answers_303_redirect_to_web
    [Documentation]    Verify POST /web/logout with no session cookie still answers 303 redirect to /web (edge case)
    Create Global API Session
    ${empty}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/logout    data=${empty}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web

TC-016_Verify_navbar_right_shows_login_link_when_not_logged_in
    [Documentation]    Verify navbar_right shows 'เข้าสู่ระบบ' link when not logged in
    Create Global API Session
    ${resp}=    GET On Session    api    /web/login    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    เข้าสู่ระบบ
    Should Contain    ${body}    href="/web/login"

TC-017_Verify_navbar_right_shows_the_logged_in_users_name_and_logout_button_after_signup_auto_login
    [Documentation]    Verify navbar_right shows the logged-in user's name and 'ออกจากระบบ' button after signup auto-login
    Connect To Global Database
    Create Global API Session
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    navbar_${dynamic_id}@qa.plrs.test
    ${signup_form}=    Create Dictionary    name=Navbar User    email=${email}    phone=0899999999    password=12345678
    ${signup_resp}=    POST On Session    api    /web/signup    data=${signup_form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${signup_resp.status_code}    303
    ${jar}=    Create Dictionary    plrs_session=${signup_resp.cookies}[plrs_session]
    ${resp}=    GET On Session    api    /web    cookies=${jar}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Navbar User
    Should Contain    ${body}    ออกจากระบบ
    Should Contain    ${body}    action="/web/logout"
    [Teardown]    Cleanup User By Email    ${email}

*** Keywords ***
Cleanup User By Email
    [Arguments]    ${email}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE email = '${email}'
    Run Keyword And Ignore Error    Disconnect From Global Database