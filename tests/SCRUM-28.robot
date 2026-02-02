*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Variables ***
${BASE_URL}    http://127.0.0.1:8000

*** Test Cases ***
TC-001_Happy_Path_Reverse_a_string
    [Documentation]    Happy Path - Reverse a string
    Create Session    api    ${BASE_URL}
    ${resp}=    GET On Session    api    /reverse/Olympus    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    original
    Dictionary Should Contain Value    ${json}    Olympus    original
    Dictionary Should Contain Key    ${json}    reversed
    Dictionary Should Contain Value    ${json}    supmylO    reversed

TC-002_Happy_Path_Palindrome
    [Documentation]    Happy Path - Palindrome
    Create Session    api    ${BASE_URL}
    ${resp}=    GET On Session    api    /reverse/racecar    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    original
    Dictionary Should Contain Value    ${json}    racecar    original
    Dictionary Should Contain Key    ${json}    reversed
    Dictionary Should Contain Value    ${json}    racecar    reversed

TC-003_Sad_Path_Empty_string
    [Documentation]    Sad Path - Empty string
    Create Session    api    ${BASE_URL}
    ${resp}=    GET On Session    api    /reverse/    expected_status=any
    Status Should Be    404    ${resp}

TC-004_Sad_Path_Spaces_only
    [Documentation]    Sad Path - Spaces only
    Create Session    api    ${BASE_URL}
    ${resp}=    GET On Session    api    /reverse/    expected_status=any
    Status Should Be    404    ${resp}