*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Test Cases ***
TC-001 Verify Hello World API with valid name
    Create Session    api    http://127.0.0.1:8000
    ${resp}=    GET On Session    api    /hello/Athena
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    message
    Dictionary Value Should Be    ${json}    message    Hello, Athena!

TC-002 Verify Hello World API with empty name
    Create Session    api    http://127.0.0.1:8000
    ${resp}=    GET On Session    api    /hello/
    Status Should Be    404    ${resp}

TC-003 Verify Hello World API with special characters in name
    Create Session    api    http://127.0.0.1:8000
    ${resp}=    GET On Session    api    /hello/@#%
    Status Should Be    404    ${resp}