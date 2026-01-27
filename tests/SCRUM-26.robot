*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Test Cases ***
TC-001_Verify_Hello_World_API_with_valid_name
    [Documentation]    Verify Hello World API with valid name
    Create Session    api    http://127.0.0.1:8000
    ${resp}=    GET On Session    api    /hello/Athena    expected_status=any
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    message

TC-002_Verify_Hello_World_API_with_empty_name
    [Documentation]    Verify Hello World API with empty name
    Create Session    api    http://127.0.0.1:8000
    ${resp}=    GET On Session    api    /hello/    expected_status=any
    Status Should Be    404    ${resp}

TC-003_Verify_Hello_World_API_with_special_characters_in_name
    [Documentation]    Verify Hello World API with special characters in name
    Create Session    api    http://127.0.0.1:8000
    ${resp}=    GET On Session    api    /hello/@#%    expected_status=any
    Status Should Be    400    ${resp}