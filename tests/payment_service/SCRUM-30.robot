*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/payment_service/config.robot

*** Test Cases ***
TC-001_Successful_Checkout_Happy_Path
    [Documentation]    Positive test case for successful checkout
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCKSERVER_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${mock_path}=       Set Variable    /external/payment/charge
    ${mock_status}=     Set Variable    ${200}
    ${mock_json}=       Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    
    ${test_id_list}=    Evaluate    ["${dynamic_id}"]
    ${headers_dict}=    Create Dictionary    X-Test-Id=${test_id_list}
    
    ${http_req}=        Create Dictionary    method=POST    path=${mock_path}    headers=${headers_dict}
    ${body_dict}=       Create Dictionary    type=JSON    json=${mock_json}
    ${http_resp}=       Create Dictionary    statusCode=${mock_status}    body=${body_dict}
    ${mock_exp}=        Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session        mock_api    /mockserver/expectation    json=${mock_exp}
    
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=PROD-01    amount=1500.00
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /api/v1/checkout    json=${payload}    headers=${headers}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[order_status]    COMPLETED
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM orders WHERE user_id = ${dynamic_id} AND status = 'COMPLETED'
    Should Be Equal As Integers    ${db_count_result[0][0]}    1
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-002_Payment_Declined
    [Documentation]    Negative test case for payment declined
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCKSERVER_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${mock_path}=       Set Variable    /external/payment/charge
    ${mock_status}=     Set Variable    ${400}
    ${mock_json}=       Create Dictionary    status=DECLINED    reason="Insufficient Funds"
    
    ${test_id_list}=    Evaluate    ["${dynamic_id}"]
    ${headers_dict}=    Create Dictionary    X-Test-Id=${test_id_list}
    
    ${http_req}=        Create Dictionary    method=POST    path=${mock_path}    headers=${headers_dict}
    ${body_dict}=       Create Dictionary    type=JSON    json=${mock_json}
    ${http_resp}=       Create Dictionary    statusCode=${mock_status}    body=${body_dict}
    ${mock_exp}=        Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session        mock_api    /mockserver/expectation    json=${mock_exp}
    
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=PROD-01    amount=1500.00
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /api/v1/checkout    json=${payload}    headers=${headers}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    402    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Payment Declined
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM orders WHERE user_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-003_User_Not_Found
    [Documentation]    Negative test case for user not found
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCKSERVER_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${mock_path}=       Set Variable    /external/payment/charge
    ${mock_status}=     Set Variable    ${200}
    ${mock_json}=       Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    
    ${test_id_list}=    Evaluate    ["99999"]
    ${headers_dict}=    Create Dictionary    X-Test-Id=${test_id_list}
    
    ${http_req}=        Create Dictionary    method=POST    path=${mock_path}    headers=${headers_dict}
    ${body_dict}=       Create Dictionary    type=JSON    json=${mock_json}
    ${http_resp}=       Create Dictionary    statusCode=${mock_status}    body=${body_dict}
    ${mock_exp}=        Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session        mock_api    /mockserver/expectation    json=${mock_exp}
    
    ${payload}=    Create Dictionary    user_id=99999    product_id=PROD-01    amount=1500.00
    ${str_id}=       Convert To String    99999
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /api/v1/checkout    json=${payload}    headers=${headers}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    User not found
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM orders WHERE user_id = 99999
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Run Keywords
    ...    Log    No cleanup needed for TC-003
    ...    AND    Log    TC-003 test completed

TC-004_Missing_user_id
    [Documentation]    Negative test case for missing user_id
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCKSERVER_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${mock_path}=       Set Variable    /external/payment/charge
    ${mock_status}=     Set Variable    ${200}
    ${mock_json}=       Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    
    ${test_id_list}=    Evaluate    ["${dynamic_id}"]
    ${headers_dict}=    Create Dictionary    X-Test-Id=${test_id_list}
    
    ${http_req}=        Create Dictionary    method=POST    path=${mock_path}    headers=${headers_dict}
    ${body_dict}=       Create Dictionary    type=JSON    json=${mock_json}
    ${http_resp}=       Create Dictionary    statusCode=${mock_status}    body=${body_dict}
    ${mock_exp}=        Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session        mock_api    /mockserver/expectation    json=${mock_exp}
    
    ${payload}=    Create Dictionary    product_id=PROD-01    amount=1500.00
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /api/v1/checkout    json=${payload}    headers=${headers}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    user_id is required
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM orders WHERE user_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-005_user_id_not_positive_integer
    [Documentation]    Negative test case for user_id not positive integer
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCKSERVER_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${mock_path}=       Set Variable    /external/payment/charge
    ${mock_status}=     Set Variable    ${200}
    ${mock_json}=       Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    
    ${test_id_list}=    Evaluate    ["${dynamic_id}"]
    ${headers_dict}=    Create Dictionary    X-Test-Id=${test_id_list}
    
    ${http_req}=        Create Dictionary    method=POST    path=${mock_path}    headers=${headers_dict}
    ${body_dict}=       Create Dictionary    type=JSON    json=${mock_json}
    ${http_resp}=       Create Dictionary    statusCode=${mock_status}    body=${body_dict}
    ${mock_exp}=        Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session        mock_api    /mockserver/expectation    json=${mock_exp}
    
    ${payload}=    Create Dictionary    user_id=-999    product_id=PROD-01    amount=1500.00
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /api/v1/checkout    json=${payload}    headers=${headers}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    user_id must be a positive integer
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM orders WHERE user_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-006_Missing_product_id
    [Documentation]    Negative test case for missing product_id
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCKSERVER_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${mock_path}=       Set Variable    /external/payment/charge
    ${mock_status}=     Set Variable    ${200}
    ${mock_json}=       Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    
    ${test_id_list}=    Evaluate    ["${dynamic_id}"]
    ${headers_dict}=    Create Dictionary    X-Test-Id=${test_id_list}
    
    ${http_req}=        Create Dictionary    method=POST    path=${mock_path}    headers=${headers_dict}
    ${body_dict}=       Create Dictionary    type=JSON    json=${mock_json}
    ${http_resp}=       Create Dictionary    statusCode=${mock_status}    body=${body_dict}
    ${mock_exp}=        Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session        mock_api    /mockserver/expectation    json=${mock_exp}
    
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    amount=1500.00
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /api/v1/checkout    json=${payload}    headers=${headers}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    product_id is required
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM orders WHERE user_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-007_Empty_product_id
    [Documentation]    Negative test case for empty product_id
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCKSERVER_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${mock_path}=       Set Variable    /external/payment/charge
    ${mock_status}=     Set Variable    ${200}
    ${mock_json}=       Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    
    ${test_id_list}=    Evaluate    ["${dynamic_id}"]
    ${headers_dict}=    Create Dictionary    X-Test-Id=${test_id_list}
    
    ${http_req}=        Create Dictionary    method=POST    path=${mock_path}    headers=${headers_dict}
    ${body_dict}=       Create Dictionary    type=JSON    json=${mock_json}
    ${http_resp}=       Create Dictionary    statusCode=${mock_status}    body=${body_dict}
    ${mock_exp}=        Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session        mock_api    /mockserver/expectation    json=${mock_exp}
    
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=    amount=1500.00
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /api/v1/checkout    json=${payload}    headers=${headers}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    product_id cannot be empty
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM orders WHERE user_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-008_Missing_amount
    [Documentation]    Negative test case for missing amount
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCKSERVER_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${mock_path}=       Set Variable    /external/payment/charge
    ${mock_status}=     Set Variable    ${200}
    ${mock_json}=       Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    
    ${test_id_list}=    Evaluate    ["${dynamic_id}"]
    ${headers_dict}=    Create Dictionary    X-Test-Id=${test_id_list}
    
    ${http_req}=        Create Dictionary    method=POST    path=${mock_path}    headers=${headers_dict}
    ${body_dict}=       Create Dictionary    type=JSON    json=${mock_json}
    ${http_resp}=       Create Dictionary    statusCode=${mock_status}    body=${body_dict}
    ${mock_exp}=        Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session        mock_api    /mockserver/expectation    json=${mock_exp}
    
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=PROD-01
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /api/v1/checkout    json=${payload}    headers=${headers}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    amount is required
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM orders WHERE user_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-009_Amount_not_strictly_greater_than_0
    [Documentation]    Negative test case for amount not strictly greater than 0
    
    # --- 1. SETUP PHASE ---
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    Create Session    mock_api    ${MOCKSERVER_URL}
    
    # --- 2. EXERCISE PHASE ---
    ${mock_path}=       Set Variable    /external/payment/charge
    ${mock_status}=     Set Variable    ${200}
    ${mock_json}=       Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    
    ${test_id_list}=    Evaluate    ["${dynamic_id}"]
    ${headers_dict}=    Create Dictionary    X-Test-Id=${test_id_list}
    
    ${http_req}=        Create Dictionary    method=POST    path=${mock_path}    headers=${headers_dict}
    ${body_dict}=       Create Dictionary    type=JSON    json=${mock_json}
    ${http_resp}=       Create Dictionary    statusCode=${mock_status}    body=${body_dict}
    ${mock_exp}=        Create Dictionary    httpRequest=${http_req}    httpResponse=${http_resp}
    PUT On Session        mock_api    /mockserver/expectation    json=${mock_exp}
    
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=PROD-01    amount=-1500.00
    ${str_id}=       Convert To String    ${dynamic_id}
    ${headers}=      Create Dictionary    X-Test-Id=${str_id}
    ${resp}=         POST On Session    api    /api/v1/checkout    json=${payload}    headers=${headers}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    amount must be strictly greater than 0
    
    # Post-Assertion from CSV
    ${db_count_result}=    Query    SELECT count(*) FROM orders WHERE user_id = ${dynamic_id}
    Should Be Equal As Integers    ${db_count_result[0][0]}    0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

*** Keywords ***
Cleanup Test Case And Mock
    [Arguments]    ${id}
    # 1. Clear Database
    Execute Sql String    DELETE FROM orders WHERE user_id=${id}
    Execute Sql String    DELETE FROM users WHERE id=${id}
    
    # 2. Clear Mock Safely (Step-by-step to preserve types)
    ${test_id_list}=      Evaluate    ["${id}"]
    ${headers_dict}=      Create Dictionary    X-Test-Id=${test_id_list}
    ${req_dict}=          Create Dictionary    headers=${headers_dict}
    ${clear_req}=         Create Dictionary    httpRequest=${req_dict}
    PUT On Session        mock_api    /mockserver/clear    json=${clear_req}
    
    # 3. Disconnect
    Disconnect From Global Database