*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Test Cases ***
TC-001 Verify Strong Password
    [Documentation]    Verify Strong Password
    Create Session    api    http://127.0.0.1:8000
    ${payload}=    Create Dictionary    password=StrongP@ss1
    ${resp}=    POST On Session    api    /check-password    json=${payload}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    4
    Should Be Equal As Strings    ${json}[strength]    Strong
    Should Be Empty    ${json}[feedback]

TC-002 Verify Medium Password
    [Documentation]    Verify Medium Password
    Create Session    api    http://127.0.0.1:8000
    ${payload}=    Create Dictionary    password=Ab1
    ${resp}=    POST On Session    api    /check-password    json=${payload}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Log To Console    ${json}  # Debugging line to log the response
    Should Be Equal As Integers    ${json}[score]    2
    Should Be Equal As Strings    ${json}[strength]    Medium
    ${expected_feedback}=    Create List    Password is too short    Add a special character
    Lists Should Be Equal    ${json}[feedback]    ${expected_feedback}

TC-003 Verify Weak Password
    [Documentation]    Verify Weak Password
    Create Session    api    http://127.0.0.1:8000
    ${payload}=    Create Dictionary    password=abc
    ${resp}=    POST On Session    api    /check-password    json=${payload}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[score]    0
    Should Be Equal As Strings    ${json}[strength]    Weak
    ${expected_feedback}=    Create List    Password is too short    Add a number    Add an uppercase letter    Add a special character
    Lists Should Be Equal    ${json}[feedback]    ${expected_feedback}

TC-004 Verify Empty Password
    [Documentation]    Verify Empty Password
    Create Session    api    http://127.0.0.1:8000
    ${payload}=    Create Dictionary    password=
    # ⚠️ CRITICAL: Use expected_status=any to prevent auto-fail on 4xx/5xx
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    422    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    detail

TC-005 Verify Null Password
    [Documentation]    Verify Null Password
    Create Session    api    http://127.0.0.1:8000
    ${payload}=    Create Dictionary    password=${None}
    # ⚠️ CRITICAL: Use expected_status=any to prevent auto-fail on 4xx/5xx
    ${resp}=    POST On Session    api    /check-password    json=${payload}    expected_status=any
    Status Should Be    422    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    detail