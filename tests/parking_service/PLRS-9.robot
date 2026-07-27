*** Settings ***
Documentation    PLRS-9 — Owner registration: create owner, required-field 400s (flat detail),
...              duplicate 409, and security payloads spec-first (accepted 201, stored as data).
...              Finalized by Claude — each test uses a UNIQUE email/name so re-runs are idempotent
...              (the CSV's fixed emails collided across runs → 409 on create).
Library          RequestsLibrary
Library          Collections
Library          DatabaseLibrary
Resource         ../../resources/projects/parking_service/config.robot


*** Test Cases ***
TC-001_Create_Owner_Success
    [Documentation]    Valid name + email -> 201 with the owner (subscription_active defaults true)
    ${email}=    Unique Email
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=Acme Parking    email=${email}
    ${resp}=    POST On Session    api    /owners    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[name]    Acme Parking
    Should Be Equal As Strings    ${json}[email]    ${email}
    Should Be True    ${json}[subscription_active]
    [Teardown]    Delete Owner By Email    ${email}

TC-002_Missing_Name_400
    [Documentation]    name absent -> 400 flat {detail}
    Create Session    api    ${BASE_API_URL}
    ${email}=    Unique Email
    ${payload}=    Create Dictionary    email=${email}
    ${resp}=    POST On Session    api    /owners    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Name is required

TC-003_Missing_Email_400
    [Documentation]    email absent -> 400 flat {detail}
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=Acme Parking
    ${resp}=    POST On Session    api    /owners    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Email is required

TC-004_Duplicate_Email_409
    [Documentation]    Same email twice -> second is 409 flat {detail}
    ${email}=    Unique Email
    Create Session    api    ${BASE_API_URL}
    ${first}=    Create Dictionary    name=First Owner    email=${email}
    POST On Session    api    /owners    json=${first}    expected_status=any
    ${second}=    Create Dictionary    name=Second Owner    email=${email}
    ${resp}=    POST On Session    api    /owners    json=${second}    expected_status=any
    Status Should Be    409    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Email already exists
    [Teardown]    Delete Owner By Email    ${email}

TC-005_Empty_Name_400
    [Documentation]    name empty string -> 400
    Create Session    api    ${BASE_API_URL}
    ${email}=    Unique Email
    ${payload}=    Create Dictionary    name=${EMPTY}    email=${email}
    ${resp}=    POST On Session    api    /owners    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Name is required

TC-006_Empty_Email_400
    [Documentation]    email empty string -> 400
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=Acme Parking    email=${EMPTY}
    ${resp}=    POST On Session    api    /owners    json=${payload}    expected_status=any
    Status Should Be    400    ${resp}
    Should Be Equal As Strings    ${resp.json()}[detail]    Email is required

TC-007_Name_SQL_Injection_Accepted
    [Documentation]    SQL-injection string in name is a valid string input -> 201 (ORM stores it as data)
    ${email}=    Unique Email
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=; DROP TABLE owners;--    email=${email}
    ${resp}=    POST On Session    api    /owners    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    Should Be Equal As Strings    ${resp.json()}[email]    ${email}
    [Teardown]    Delete Owner By Email    ${email}

TC-008_Email_SQL_Injection_Accepted
    [Documentation]    SQL-injection string in email is a valid string input -> 201
    ${name}=    Unique Name
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=${name}    email=; DROP TABLE owners;--
    ${resp}=    POST On Session    api    /owners    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    Should Be Equal As Strings    ${resp.json()}[name]    ${name}
    [Teardown]    Delete Owner By Name    ${name}

TC-009_Name_XSS_Accepted
    [Documentation]    XSS string in name is a valid string input -> 201 (not executed server-side)
    ${email}=    Unique Email
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=<script>alert(1)</script>    email=${email}
    ${resp}=    POST On Session    api    /owners    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    Should Be Equal As Strings    ${resp.json()}[email]    ${email}
    [Teardown]    Delete Owner By Email    ${email}

TC-010_Email_XSS_Accepted
    [Documentation]    XSS string in email is a valid string input -> 201
    ${name}=    Unique Name
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    name=${name}    email=<script>alert(1)</script>
    ${resp}=    POST On Session    api    /owners    json=${payload}    expected_status=any
    Status Should Be    201    ${resp}
    Should Be Equal As Strings    ${resp.json()}[name]    ${name}
    [Teardown]    Delete Owner By Name    ${name}


*** Keywords ***
Unique Email
    ${n}=    Evaluate    random.randint(1000000, 9999999)    modules=random
    RETURN    owner_${n}@test.com

Unique Name
    ${n}=    Evaluate    random.randint(1000000, 9999999)    modules=random
    RETURN    Owner_${n}

Delete Owner By Email
    [Arguments]    ${email}
    Connect To Global Database
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE email = '${email}'
    Disconnect From Global Database

Delete Owner By Name
    [Arguments]    ${name}
    Connect To Global Database
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM owners WHERE name = '${name}'
    Disconnect From Global Database
