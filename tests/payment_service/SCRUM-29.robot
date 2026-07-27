*** Settings ***
Library    RequestsLibrary
Library    Collections
Resource   ../../resources/projects/payment_service/config.robot

Suite Setup    Create Session For API

*** Test Cases ***
TC-001_Negative_Empty_Password
    [Documentation]    Verify API returns 400 when password is an empty string
    ${payload}=    Create Dictionary    password=
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password cannot be empty

TC-002_Negative_Whitespace_Password
    [Documentation]    Verify API returns 400 when password is whitespace-only
    ${payload}=    Create Dictionary    password=${SPACE}${SPACE}${SPACE}
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Password cannot be empty

TC-003_Positive_Weak_Password_ABC
    [Documentation]    Verify API returns Weak password with all rules failing for input 'abc'
    ${payload}=    Create Dictionary    password=abc
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    0
    Should Be Equal As Strings    ${json}[strength]    Weak
    Should Be Equal As Strings    ${json}[feedback][0]    Password is too short
    Should Be Equal As Strings    ${json}[feedback][1]    Add a number
    Should Be Equal As Strings    ${json}[feedback][2]    Add an uppercase letter
    Should Be Equal As Strings    ${json}[feedback][3]    Add a special character

TC-004_Positive_Weak_Password_123
    [Documentation]    Verify API returns Weak password with length and uppercase rules failing for input '123'
    ${payload}=    Create Dictionary    password=123
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    1
    Should Be Equal As Strings    ${json}[strength]    Weak
    Should Be Equal As Strings    ${json}[feedback][0]    Password is too short
    Should Be Equal As Strings    ${json}[feedback][1]    Add an uppercase letter
    Should Be Equal As Strings    ${json}[feedback][2]    Add a special character

TC-005_Positive_Weak_Password_Abc
    [Documentation]    Verify API returns Weak password with length and number rules failing for input 'Abc'
    ${payload}=    Create Dictionary    password=Abc
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    1
    Should Be Equal As Strings    ${json}[strength]    Weak
    Should Be Equal As Strings    ${json}[feedback][0]    Password is too short
    Should Be Equal As Strings    ${json}[feedback][1]    Add a number
    Should Be Equal As Strings    ${json}[feedback][2]    Add a special character

TC-006_Positive_Medium_Password_Ab1
    [Documentation]    Verify API returns Medium password with length rule failing for input 'Ab1'
    ${payload}=    Create Dictionary    password=Ab1
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    2
    Should Be Equal As Strings    ${json}[strength]    Medium
    Should Be Equal As Strings    ${json}[feedback][0]    Password is too short
    Should Be Equal As Strings    ${json}[feedback][1]    Add a special character

TC-007_Positive_Medium_Password_Short1!
    [Documentation]    Verify API returns Medium password with length rule failing for input 'Short1!'
    ${payload}=    Create Dictionary    password=Short1!
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    3
    Should Be Equal As Strings    ${json}[strength]    Medium
    Should Be Equal As Strings    ${json}[feedback][0]    Password is too short

TC-008_Positive_Medium_Password_LongPasswordWithoutSpecial
    [Documentation]    Verify API returns Medium password with number and special char rules failing for input 'LongPasswordWithoutSpecial'
    ${payload}=    Create Dictionary    password=LongPasswordWithoutSpecial
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    2
    Should Be Equal As Strings    ${json}[strength]    Medium
    Should Be Equal As Strings    ${json}[feedback][0]    Add a number
    Should Be Equal As Strings    ${json}[feedback][1]    Add a special character

TC-009_Positive_Strong_Password_P@ssw0rd1
    [Documentation]    Verify API returns Strong password for input 'P@ssw0rd1'
    ${payload}=    Create Dictionary    password=P@ssw0rd1
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    4
    Should Be Equal As Strings    ${json}[strength]    Strong
    Should Be Empty    ${json}[feedback]

TC-010_Positive_Medium_Password_1234567890
    [Documentation]    Verify API returns Medium password with uppercase and special char rules failing for input '1234567890'
    ${payload}=    Create Dictionary    password=1234567890
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    2
    Should Be Equal As Strings    ${json}[strength]    Medium
    Should Be Equal As Strings    ${json}[feedback][0]    Add an uppercase letter
    Should Be Equal As Strings    ${json}[feedback][1]    Add a special character

TC-011_Positive_Medium_Password_AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz
    [Documentation]    Verify API returns Medium password with number and special char rules failing for input 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz'
    ${payload}=    Create Dictionary    password=AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    2
    Should Be Equal As Strings    ${json}[strength]    Medium
    Should Be Equal As Strings    ${json}[feedback][0]    Add a number
    Should Be Equal As Strings    ${json}[feedback][1]    Add a special character

TC-012_Positive_Medium_Password_SpecialCharsOnly
    [Documentation]    Verify API returns Medium password with length, number, and uppercase rules failing for input '!@#$%^&*()_+{}|:""<>?`~'
    ${payload}=    Create Dictionary    password=!@#$%^&*()_+{}|:\""<>?`~
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    2
    Should Be Equal As Strings    ${json}[strength]    Medium
    Should Be Equal As Strings    ${json}[feedback][0]    Add a number
    Should Be Equal As Strings    ${json}[feedback][1]    Add an uppercase letter

TC-013_Positive_Strong_Password_P@ssw0rd
    [Documentation]    Verify API returns Strong password for input 'P@ssw0rd'
    ${payload}=    Create Dictionary    password=P@ssw0rd
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    4
    Should Be Equal As Strings    ${json}[strength]    Strong
    Should Be Empty    ${json}[feedback]

TC-014_Positive_Medium_Password_p@ssw0rd
    [Documentation]    Verify API returns Medium password with uppercase rule failing for input 'p@ssw0rd'
    ${payload}=    Create Dictionary    password=p@ssw0rd
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    3
    Should Be Equal As Strings    ${json}[strength]    Medium
    Should Be Equal As Strings    ${json}[feedback][0]    Add an uppercase letter

TC-015_Positive_Medium_Password_P@ssword
    [Documentation]    Verify API returns Medium password with number rule failing for input 'P@ssword'
    ${payload}=    Create Dictionary    password=P@ssword
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[score]    3
    Should Be Equal As Strings    ${json}[strength]    Medium
    Should Be Equal As Strings    ${json}[feedback][0]    Add a number

*** Keywords ***
Create Session For API
    Create Session    api    ${BASE_API_URL}