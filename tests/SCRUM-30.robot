*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../resources/env.robot

*** Variables ***
${BASE_API_URL}    http://127.0.0.1:8000
${DB_PATH}    /tmp/test.db

*** Test Cases ***
TC_001_Successful_Checkout_Happy_Path
    [Documentation]    Positive: Successful Checkout (Happy Path)
    
    # --- 1. SETUP PHASE ---
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Database    sqlite3    ${DB_PATH}
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    
    # Mock external payment
    ${mock_payload}=    Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    ${mock_resp}=    POST On Session    api    /external/payment/charge    json=${mock_payload}
    Status Should Be    200    ${mock_resp}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=PROD-01    amount=1500.00
    ${resp}=    POST On Session    api    /api/v1/checkout    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    201    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[order_status]    COMPLETED
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Run Keywords
    ...    Execute Sql String    DELETE FROM orders WHERE user_id=${dynamic_id}
    ...    AND    Execute Sql String    DELETE FROM users WHERE id=${dynamic_id}
    ...    AND    Disconnect From All Databases

TC_002_Payment_Declined
    [Documentation]    Negative: Payment Declined
    
    # --- 1. SETUP PHASE ---
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Database    sqlite3    ${DB_PATH}
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    
    # Mock external payment
    ${mock_payload}=    Create Dictionary    status=DECLINED    reason="Insufficient Funds"
    ${mock_resp}=    POST On Session    api    /external/payment/charge    json=${mock_payload}
    Status Should Be    200    ${mock_resp}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=PROD-01    amount=1500.00
    ${resp}=    POST On Session    api    /api/v1/checkout    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    402    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[error]    Payment Declined
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Run Keywords
    ...    Execute Sql String    DELETE FROM users WHERE id=${dynamic_id}
    ...    AND    Disconnect From All Databases

TC_003_User_Not_Found
    [Documentation]    Negative: User Not Found
    
    # --- 1. SETUP PHASE ---
    Create Session    api    ${BASE_API_URL}
    
    # Mock external payment
    ${mock_payload}=    Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    ${mock_resp}=    POST On Session    api    /external/payment/charge    json=${mock_payload}
    Status Should Be    200    ${mock_resp}
    
    # --- 2. EXERCISE PHASE ---
    ${non_existent_dynamic_id}=    Evaluate    random.randint(9000, 9999)    modules=random
    ${payload}=    Create Dictionary    user_id=${non_existent_dynamic_id}    product_id=PROD-01    amount=1500.00
    ${resp}=    POST On Session    api    /api/v1/checkout    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    User not found
    
    # --- 4. TEARDOWN PHASE ---
    # No cleanup needed

TC_004_Missing_user_id
    [Documentation]    Negative: Missing user_id
    
    # --- 1. SETUP PHASE ---
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Database    sqlite3    ${DB_PATH}
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    
    # Mock external payment
    ${mock_payload}=    Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    ${mock_resp}=    POST On Session    api    /external/payment/charge    json=${mock_payload}
    Status Should Be    200    ${mock_resp}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary    product_id=PROD-01    amount=1500.00
    ${resp}=    POST On Session    api    /api/v1/checkout    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    user_id is required
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Run Keywords
    ...    Execute Sql String    DELETE FROM users WHERE id=${dynamic_id}
    ...    AND    Disconnect From All Databases

TC_005_user_id_not_positive_integer
    [Documentation]    Negative: user_id not positive integer
    
    # --- 1. SETUP PHASE ---
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Database    sqlite3    ${DB_PATH}
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    
    # Mock external payment
    ${mock_payload}=    Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    ${mock_resp}=    POST On Session    api    /external/payment/charge    json=${mock_payload}
    Status Should Be    200    ${mock_resp}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary    user_id=-999    product_id=PROD-01    amount=1500.00
    ${resp}=    POST On Session    api    /api/v1/checkout    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    user_id must be a positive integer
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Run Keywords
    ...    Execute Sql String    DELETE FROM users WHERE id=${dynamic_id}
    ...    AND    Disconnect From All Databases

TC_006_Missing_product_id
    [Documentation]    Negative: Missing product_id
    
    # --- 1. SETUP PHASE ---
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Database    sqlite3    ${DB_PATH}
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    
    # Mock external payment
    ${mock_payload}=    Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    ${mock_resp}=    POST On Session    api    /external/payment/charge    json=${mock_payload}
    Status Should Be    200    ${mock_resp}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    amount=1500.00
    ${resp}=    POST On Session    api    /api/v1/checkout    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    product_id is required
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Run Keywords
    ...    Execute Sql String    DELETE FROM users WHERE id=${dynamic_id}
    ...    AND    Disconnect From All Databases

TC_007_Empty_product_id
    [Documentation]    Negative: Empty product_id
    
    # --- 1. SETUP PHASE ---
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Database    sqlite3    ${DB_PATH}
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    
    # Mock external payment
    ${mock_payload}=    Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    ${mock_resp}=    POST On Session    api    /external/payment/charge    json=${mock_payload}
    Status Should Be    200    ${mock_resp}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=    amount=1500.00
    ${resp}=    POST On Session    api    /api/v1/checkout    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    product_id cannot be empty
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Run Keywords
    ...    Execute Sql String    DELETE FROM users WHERE id=${dynamic_id}
    ...    AND    Disconnect From All Databases

TC_008_Missing_amount
    [Documentation]    Negative: Missing amount
    
    # --- 1. SETUP PHASE ---
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Database    sqlite3    ${DB_PATH}
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    
    # Mock external payment
    ${mock_payload}=    Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    ${mock_resp}=    POST On Session    api    /external/payment/charge    json=${mock_payload}
    Status Should Be    200    ${mock_resp}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=PROD-01
    ${resp}=    POST On Session    api    /api/v1/checkout    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    amount is required
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Run Keywords
    ...    Execute Sql String    DELETE FROM users WHERE id=${dynamic_id}
    ...    AND    Disconnect From All Databases

TC_009_Amount_not_strictly_greater_than_0
    [Documentation]    Negative: Amount not strictly greater than 0
    
    # --- 1. SETUP PHASE ---
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random
    Connect To Database    sqlite3    ${DB_PATH}
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Session    api    ${BASE_API_URL}
    
    # Mock external payment
    ${mock_payload}=    Create Dictionary    status=SUCCESS    txn_id=mock_txn_888
    ${mock_resp}=    POST On Session    api    /external/payment/charge    json=${mock_payload}
    Status Should Be    200    ${mock_resp}
    
    # --- 2. EXERCISE PHASE ---
    ${payload}=    Create Dictionary    user_id=${dynamic_id}    product_id=PROD-01    amount=-1500.00
    ${resp}=    POST On Session    api    /api/v1/checkout    json=${payload}    expected_status=any
    
    # --- 3. VERIFICATION PHASE ---
    Status Should Be    400    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    amount must be strictly greater than 0
    
    # --- 4. TEARDOWN PHASE ---
    [Teardown]    Run Keywords
    ...    Execute Sql String    DELETE FROM users WHERE id=${dynamic_id}
    ...    AND    Disconnect From All Databases