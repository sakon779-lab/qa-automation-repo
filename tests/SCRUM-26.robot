*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Test Cases ***
TC_001_Happy_Path_Valid_Name
    [Documentation]    Happy Path - Valid Name
    Create Session    api    http://127.0.0.1:8000
    ${resp}=    GET On Session    api    /hello/Athena    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    message

TC_002_Sad_Path_Invalid_Characters
    [Documentation]    Sad Path - Invalid Characters
    Create Session    api    http://127.0.0.1:8000
    ${resp}=    GET On Session    api    /hello/@#%    expected_status=any
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    detail

TC_003_Sad_Path_Empty_Name
    [Documentation]    Sad Path - Empty Name
    Create Session    api    http://127.0.0.1:8000
    ${resp}=    GET On Session    api    /hello/    expected_status=any
    Status Should Be    404    ${resp}