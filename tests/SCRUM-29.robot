*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../resources/config.robot

*** Test Cases ***
TC-001_Verify_API_Returns_200_OK_For_Weak_Password
    [Documentation]    Verify API returns 200 OK with correct score, strength, and feedback for weak password
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=abc
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    0
    Should Be Equal As Strings    ${json}[strength]    Weak
    Lists Should Be Equal    ${json}[feedback]    ['Password is too short', 'Add a number', 'Add an uppercase letter', 'Add a special character']
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-002_Verify_API_Returns_200_OK_For_Password_With_Only_Number
    [Documentation]    Verify API returns 200 OK with correct score, strength, and feedback for password with only number
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=123
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    1
    Should Be Equal As Strings    ${json}[strength]    Weak
    Lists Should Be Equal    ${json}[feedback]    ['Password is too short', 'Add an uppercase letter', 'Add a special character']
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-003_Verify_API_Returns_200_OK_For_Password_With_Only_Uppercase
    [Documentation]    Verify API returns 200 OK with correct score, strength, and feedback for password with only uppercase
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=ABC
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    1
    Should Be Equal As Strings    ${json}[strength]    Weak
    Lists Should Be Equal    ${json}[feedback]    ['Password is too short', 'Add a number', 'Add a special character']
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-004_Verify_API_Returns_200_OK_For_Password_With_Number_And_Uppercase
    [Documentation]    Verify API returns 200 OK with correct score, strength, and feedback for password with number and uppercase
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=Ab1
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    2
    Should Be Equal As Strings    ${json}[strength]    Medium
    Lists Should Be Equal    ${json}[feedback]    ['Password is too short', 'Add a special character']
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-005_Verify_API_Returns_200_OK_For_Strong_Password
    [Documentation]    Verify API returns 200 OK with correct score, strength, and feedback for strong password
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=StrongP@ss1
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    4
    Should Be Equal As Strings    ${json}[strength]    Strong
    Lists Should Be Equal    ${json}[feedback]    []
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-006_Verify_API_Returns_400_Bad_Request_For_Empty_Password
    [Documentation]    Verify API returns 400 Bad Request when password is empty string
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password cannot be empty
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-007_Verify_API_Returns_400_Bad_Request_For_Password_As_Whitespace
    [Documentation]    Verify API returns 400 Bad Request when password is whitespace only
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password= 
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password cannot be empty
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-008_Verify_API_Returns_400_Bad_Request_For_Password_Field_Missing
    [Documentation]    Verify API returns 400 Bad Request when password field is missing
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password is required
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-009_Verify_API_Returns_400_Bad_Request_For_Password_As_Null
    [Documentation]    Verify API returns 400 Bad Request when password is null
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=${None}
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password is required
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-010_Verify_API_Returns_200_OK_For_Password_With_Special_Character
    [Documentation]    Verify API returns 200 OK with correct score, strength, and feedback for password with special character
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=Passw0rd!
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    4
    Should Be Equal As Strings    ${json}[strength]    Strong
    Lists Should Be Equal    ${json}[feedback]    []
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-011_Verify_API_Returns_200_OK_For_Password_With_All_Rules_Satisfied
    [Documentation]    Verify API returns 200 OK with correct score, strength, and feedback for password with all rules satisfied
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=MyP@ssw0rd123
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    4
    Should Be Equal As Strings    ${json}[strength]    Strong
    Lists Should Be Equal    ${json}[feedback]    []
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-012_Verify_API_Returns_200_OK_For_Password_Length_Greater_Than_8_But_No_Other_Rules
    [Documentation]    Verify API returns 200 OK with correct score, strength, and feedback for password with length >= 8 but no other rules
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Global Database
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=abcdefgh
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /check-password    json=${payload}    headers=${headers}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    1
    Should Be Equal As Strings    ${json}[strength]    Weak
    Lists Should Be Equal    ${json}[feedback]    ['Add a number', 'Add an uppercase letter', 'Add a special character']
    Execute Sql String    SELECT count(*) FROM users WHERE id = ${dynamic_id}
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

*** Keywords ***
Cleanup Test Case And Mock
    [Arguments]    ${id}
    Execute Sql String    DELETE FROM orders WHERE user_id=${id}
    Execute Sql String    DELETE FROM users WHERE id=${id}
    Disconnect From Global Database