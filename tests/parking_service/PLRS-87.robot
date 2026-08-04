*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_adding_first_payment_method_Visa_4242_returns_200_with_card_listed_and_is_default_true
    [Documentation]    Verify adding the first payment method (Visa 4242) returns 200 with the card listed and is_default=true automatically
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    ${form}=    Create Dictionary    number=4242424242424242    exp_month=12    exp_year=2030    cvc=123
    ${resp}=    POST On Session    api    /web/profile/payment-methods    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Visa •••• 4242
    ${count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}' AND brand = 'Visa' AND last4 = '4242' AND is_default = true
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-002_Verify_adding_second_payment_method_Mastercard_4444_returns_200_with_card_listed_and_is_default_false
    [Documentation]    Verify adding a second payment method (Mastercard 4444) returns 200 with the card listed and is_default=false
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    # First add Visa (becomes default), then add Mastercard (should NOT be default)
    ${visa_form}=    Create Dictionary    number=4242424242424242    exp_month=12    exp_year=2030    cvc=123
    ${resp1}=    POST On Session    api    /web/profile/payment-methods    data=${visa_form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp1}
    ${form}=    Create Dictionary    number=5555555555554444    exp_month=01    exp_year=2031    cvc=456
    ${resp}=    POST On Session    api    /web/profile/payment-methods    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Log    ${body}
    Should Contain    ${body}    Mastercard •••• 4444
    ${count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}' AND brand = 'Mastercard' AND last4 = '4444' AND is_default = false
    Log    Mastercard non-default count: ${count[0][0]}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-003_Verify_adding_card_failing_Luhn_check_returns_200_with_inline_error_Invalid_card_number
    [Documentation]    Verify adding a card with a number failing Luhn check (4242424242424241) returns 200 with inline error 'Invalid card number'
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    ${form}=    Create Dictionary    number=4242424242424241    exp_month=12    exp_year=2030    cvc=123
    ${resp}=    POST On Session    api    /web/profile/payment-methods    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Invalid card number
    ${count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-004_Verify_adding_card_with_expired_date_returns_200_with_inline_error_Card_is_expired
    [Documentation]    Verify adding a card with an expired date (01/2020) returns 200 with inline error 'Card is expired'
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    ${form}=    Create Dictionary    number=4242424242424242    exp_month=01    exp_year=2020    cvc=123
    ${resp}=    POST On Session    api    /web/profile/payment-methods    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Card is expired
    ${count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-005_Verify_setting_non_default_payment_method_as_default_returns_200_with_updated_list
    [Documentation]    Verify setting a non-default payment method as default returns 200 with the updated list showing the card as default
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    Add Two Payment Methods    ${user_id}    ${cookie}
    ${pm_id}=    Query    SELECT id FROM payment_methods WHERE user_id = '${user_id}' AND brand = 'Mastercard' LIMIT 1
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/profile/payment-methods/${pm_id[0][0]}/set-default    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Mastercard •••• 4444
    ${mc_count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}' AND is_default = true AND brand = 'Mastercard'
    Should Be Equal As Integers    ${mc_count[0][0]}    1
    ${visa_count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}' AND is_default = true AND brand = 'Visa'
    Should Be Equal As Integers    ${visa_count[0][0]}    0
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-006_Verify_setting_default_on_another_users_payment_method_returns_200_with_inline_error
    [Documentation]    Verify setting default on another user's payment method returns 200 with inline error 'Payment method not found'
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${other_id}=    Evaluate    ${dynamic_id} + 1
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${other_email}=    Set Variable    pay_${other_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    ${other_cookie}=    Signup And Get Session Cookie    ${other_id}    ${other_email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    ${other_user_id}=    Get User Id By Email    ${other_email}
    Add Two Payment Methods    ${user_id}    ${cookie}
    Add Two Payment Methods    ${other_user_id}    ${other_cookie}
    ${pm_id}=    Query    SELECT id FROM payment_methods WHERE user_id = '${other_user_id}' LIMIT 1
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/profile/payment-methods/${pm_id[0][0]}/set-default    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Log    ${body}
    Should Contain    ${body}    Payment method not found
    ${count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${other_user_id}' AND is_default = true
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-007_Verify_deleting_non_default_payment_method_returns_200_with_updated_list
    [Documentation]    Verify deleting a non-default payment method returns 200 with the updated list without the deleted card
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    Add Two Payment Methods    ${user_id}    ${cookie}
    ${pm_id}=    Query    SELECT id FROM payment_methods WHERE user_id = '${user_id}' AND brand = 'Mastercard' LIMIT 1
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/profile/payment-methods/${pm_id[0][0]}/delete    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Visa •••• 4242
    ${mc_count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}' AND brand = 'Mastercard'
    Should Be Equal As Integers    ${mc_count[0][0]}    0
    ${visa_count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}' AND brand = 'Visa' AND is_default = true
    Should Be Equal As Integers    ${visa_count[0][0]}    1
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-008_Verify_deleting_default_payment_method_promotes_next_remaining_method_to_default
    [Documentation]    Verify deleting the default payment method promotes the next remaining method to default
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    Add Two Payment Methods    ${user_id}    ${cookie}
    ${pm_id}=    Query    SELECT id FROM payment_methods WHERE user_id = '${user_id}' AND brand = 'Visa' LIMIT 1
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/profile/payment-methods/${pm_id[0][0]}/delete    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Mastercard •••• 4444
    ${visa_count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}' AND brand = 'Visa'
    Should Be Equal As Integers    ${visa_count[0][0]}    0
    ${mc_count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}' AND brand = 'Mastercard' AND is_default = true
    Should Be Equal As Integers    ${mc_count[0][0]}    1
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-009_Verify_deleting_another_users_payment_method_returns_200_with_inline_error
    [Documentation]    Verify deleting another user's payment method returns 200 with inline error 'Payment method not found'
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${other_id}=    Evaluate    ${dynamic_id} + 1
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${other_email}=    Set Variable    pay_${other_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    ${other_cookie}=    Signup And Get Session Cookie    ${other_id}    ${other_email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    ${other_user_id}=    Get User Id By Email    ${other_email}
    Add Two Payment Methods    ${user_id}    ${cookie}
    # Only add ONE payment method for the other user (Visa becomes default)
    ${visa_form}=    Create Dictionary    number=4242424242424242    exp_month=12    exp_year=2030    cvc=123
    ${resp1}=    POST On Session    api    /web/profile/payment-methods    data=${visa_form}    cookies=${other_cookie}    expected_status=any
    Status Should Be    200    ${resp1}
    ${pm_id}=    Query    SELECT id FROM payment_methods WHERE user_id = '${other_user_id}' LIMIT 1
    ${form}=    Create Dictionary
    ${resp}=    POST On Session    api    /web/profile/payment-methods/${pm_id[0][0]}/delete    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Log    ${body}
    Should Contain    ${body}    Payment method not found
    ${count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${other_user_id}'
    Log    Other user payment methods count: ${count[0][0]}
    Should Be Equal As Integers    ${count[0][0]}    1
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-010_Verify_adding_card_with_SQL_injection_in_number_field_returns_200_with_inline_error
    [Documentation]    Verify adding a card with SQL injection in the number field returns 200 with inline error 'Invalid card number' and does not execute the injection
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    ${email}=    Set Variable    pay_${dynamic_id}@test.plrs
    ${cookie}=    Signup And Get Session Cookie    ${dynamic_id}    ${email}
    Connect To Global Database
    ${user_id}=    Get User Id By Email    ${email}
    ${form}=    Create Dictionary    number=4242424242424242'; DROP TABLE payment_methods;--    exp_month=12    exp_year=2030    cvc=123
    ${resp}=    POST On Session    api    /web/profile/payment-methods    data=${form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    Invalid card number
    ${count}=    Query    SELECT count(*) FROM payment_methods WHERE user_id = '${user_id}'
    Should Be Equal As Integers    ${count[0][0]}    0
    [Teardown]    Cleanup Payment Test Data    ${email}

TC-011_Verify_POST_payment_methods_without_session_cookie_redirects_to_login
    [Documentation]    Verify POST /web/profile/payment-methods without a valid plrs_session cookie redirects to /web/login?next=/web/profile with 303
    Create Session    api    ${BASE_API_URL}
    ${form}=    Create Dictionary    number=4242424242424242    exp_month=12    exp_year=2030    cvc=123
    ${resp}=    POST On Session    api    /web/profile/payment-methods    data=${form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${resp.status_code}    303
    Should Be Equal    ${resp.headers}[Location]    /web/login?next=/web/profile

TC-012_Verify_POST_internal_charges_is_closed_on_QA_returns_403
    [Documentation]    Verify POST /internal/charges is CLOSED on QA — SANDBOX_MODE is deliberately unset there, so the money-pipeline endpoint answers 403 for any payload
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary    user_id=11111111-1111-1111-1111-111111111111    amount=50    idempotency_key=qa-gate-probe    reason=OVERSTAY
    ${resp}=    POST On Session    api    /internal/charges    json=${payload}    expected_status=any
    Status Should Be    403    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    Sandbox mode is not enabled

*** Keywords ***
Signup And Get Session Cookie
    [Arguments]    ${dynamic_id}    ${email}
    Create Session    api    ${BASE_API_URL}
    ${signup_form}=    Create Dictionary    name=Pay User    email=${email}    phone=0812345678    password=password123
    ${signup_resp}=    POST On Session    api    /web/signup    data=${signup_form}    expected_status=any    allow_redirects=${False}
    Should Be Equal As Integers    ${signup_resp.status_code}    303
    ${cookie}=    Create Dictionary    plrs_session=${signup_resp.cookies}[plrs_session]
    RETURN    ${cookie}

Get User Id By Email
    [Arguments]    ${email}
    ${result}=    Query    SELECT id FROM users WHERE email = '${email}'
    RETURN    ${result[0][0]}

Add Two Payment Methods
    [Arguments]    ${user_id}    ${cookie}
    ${visa_form}=    Create Dictionary    number=4242424242424242    exp_month=12    exp_year=2030    cvc=123
    ${resp1}=    POST On Session    api    /web/profile/payment-methods    data=${visa_form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp1}
    ${mc_form}=    Create Dictionary    number=5555555555554444    exp_month=01    exp_year=2031    cvc=456
    ${resp2}=    POST On Session    api    /web/profile/payment-methods    data=${mc_form}    cookies=${cookie}    expected_status=any
    Status Should Be    200    ${resp2}

Cleanup Payment Test Data
    [Arguments]    ${email}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM charges WHERE user_id IN (SELECT id FROM users WHERE email = '${email}')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM payment_methods WHERE user_id IN (SELECT id FROM users WHERE email = '${email}')
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE email = '${email}'
    Run Keyword And Ignore Error    Disconnect From Global Database