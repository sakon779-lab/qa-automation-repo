*** Settings ***
Library    RequestsLibrary
Resource   ../../resources/projects/payment_service/config.robot

*** Variables ***
${API_URL}    ${BASE_API_URL}

*** Test Cases ***
Test String Reverse Endpoint
    Create Session    api_session    ${API_URL}
    ${response}=    GET On Session    api_session    /reverse/hello
    Should Be Equal As Strings    ${response.status_code}    200
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Strings    ${json['original']}    hello
    Should Be Equal As Strings    ${json['reversed']}    olleh