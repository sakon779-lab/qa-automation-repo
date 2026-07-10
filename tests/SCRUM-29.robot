*** Settings ***
Library    RequestsLibrary
Library    Collections
Resource   ../resources/config.robot

*** Test Cases ***
TC-001_Password_Strength_Checker_Positive_Score_4_Strong
    [Documentation]    Verify API returns score 4 Strong with feedback [] for Password1!
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=Password1!
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    4
    Should Be Equal As Strings    ${json}[strength]    Strong
    Lists Should Match    ${json}[feedback]    []

TC-002_Password_Strength_Checker_Positive_Score_1_Weak
    [Documentation]    Verify API returns score 1 Weak with feedback [Password is too short, Add an uppercase letter, Add a special character] for 123456
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=123456
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    1
    Should Be Equal As Strings    ${json}[strength]    Weak
    Lists Should Match    ${json}[feedback]    ['Password is too short', 'Add an uppercase letter', 'Add a special character']

TC-003_Password_Strength_Checker_Positive_Score_3_Medium_Add_Special_Character
    [Documentation]    Verify API returns score 3 Medium with feedback [Add a special character] for Password1
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=Password1
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    3
    Should Be Equal As Strings    ${json}[strength]    Medium
    Lists Should Match    ${json}[feedback]    ['Add a special character']

TC-004_Password_Strength_Checker_Positive_Score_3_Medium_Add_Number
    [Documentation]    Verify API returns score 3 Medium with feedback [Add a number] for Password!
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=Password!
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    3
    Should Be Equal As Strings    ${json}[strength]    Medium
    Lists Should Match    ${json}[feedback]    ['Add a number']

TC-005_Password_Strength_Checker_Positive_Score_1_Weak_Add_Number_Uppercase_Special_Character
    [Documentation]    Verify API returns score 1 Weak with feedback [Add a number, Add an uppercase letter, Add a special character] for abcdefgh
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=abcdefgh
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    1
    Should Be Equal As Strings    ${json}[strength]    Weak
    Lists Should Match    ${json}[feedback]    ['Add a number', 'Add an uppercase letter', 'Add a special character']

TC-006_Password_Strength_Checker_Positive_Score_2_Medium_Password_Is_Too_Short_Add_Special_Character
    [Documentation]    Verify API returns score 2 Medium with feedback [Password is too short, Add a special character] for Ab1
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=Ab1
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    2
    Should Be Equal As Strings    ${json}[strength]    Medium
    Lists Should Match    ${json}[feedback]    ['Password is too short', 'Add a special character']

TC-007_Password_Strength_Checker_Positive_Score_4_Strong_SQL_Injection
    [Documentation]    Verify API returns score 4 Strong with feedback [] for SQL injection Password1! apostrophe; DROP TABLE users;--
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=Password1!\'; DROP TABLE users;--
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    4
    Should Be Equal As Strings    ${json}[strength]    Strong
    Lists Should Match    ${json}[feedback]    []

TC-008_Password_Strength_Checker_Positive_Score_4_Strong_XSS
    [Documentation]    Verify API returns score 4 Strong with feedback [] for XSS Password1!<script>alert(1)</script>
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=Password1!<script>alert(1)</script>
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    4
    Should Be Equal As Strings    ${json}[strength]    Strong
    Lists Should Match    ${json}[feedback]    []

TC-009_Password_Strength_Checker_Negative_Null_Password
    [Documentation]    Verify API returns 400 Bad Request with detail Password is required for null password
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=${None}
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password is required

TC-010_Password_Strength_Checker_Negative_Missing_Password_Field
    [Documentation]    Verify API returns 400 Bad Request with detail Password is required for missing password field
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password is required

TC-011_Password_Strength_Checker_Negative_Empty_String_Password
    [Documentation]    Verify API returns 400 Bad Request with detail Password cannot be empty for empty string password
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=${EMPTY}
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password cannot be empty

TC-012_Password_Strength_Checker_Negative_Whitespace_Only_Password
    [Documentation]    Verify API returns 400 Bad Request with detail Password cannot be empty for whitespace-only password
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    password=${SPACE}${SPACE}${SPACE}
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Log To Console    ${resp.text}
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password cannot be empty

*** Keywords ***
Status Should Be
    [Arguments]    ${expected_status}    ${response}
    Should Be Equal As Integers    ${response.status_code}    ${expected_status}

Lists Should Match
    [Arguments]    ${actual_list}    ${expected_list}
    Lists Should Be Equal    ${actual_list}    ${expected_list}