*** Settings ***
Library          RequestsLibrary
Library          Collections
Resource         ../../resources/projects/parking_service/config.robot

*** Test Cases ***
Check Signup Response
    Create Global API Session
    ${id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${data}=    Create Dictionary    name=Member ${id}    email=member_${id}@test.com    password=Passw0rd!
    ${resp}=    POST On Session    api    /web/signup    data=${data}    expected_status=any    allow_redirects=${False}
    Log To Console    STATUS: ${resp.status_code}
    Log To Console    BODY: ${resp.text}
    Log To Console    HEADERS: ${resp.headers}