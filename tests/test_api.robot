*** Settings ***
Library    RequestsLibrary

*** Variables ***
${API_URL}    http://127.0.0.1:8000

*** Test Cases ***
Test String Reverse Endpoint
    Create Session    api_session    ${API_URL}
    ${response}=    GET On Session    api_session    /reverse/hello
    Should Be Equal As Strings    ${response.status_code}    200
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Strings    ${json['original']}    hello
    Should Be Equal As Strings    ${json['reversed']}    olleh