*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource    ../../resources/projects/payment_service/config.robot

*** Keywords ***
Seed User With Orders
    [Arguments]    ${user_id}    ${order_amounts_statuses}
    [Documentation]    Seeds a user and their orders. order_amounts_statuses is a list of
    ...                [amount, status] pairs. Returns nothing.
    Execute Sql String    INSERT INTO users (id, status) VALUES (${user_id}, 'ACTIVE')
    FOR    ${order}    IN    @{order_amounts_statuses}
        ${amount}=    Set Variable    ${order}[0]
        ${status}=    Set Variable    ${order}[1]
        ${product_id}=    Set Variable    PROD-${user_id}-${amount}
        Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${user_id}, '${product_id}', ${amount}, '${status}')
    END

Cleanup User Data
    [Arguments]    ${user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM orders WHERE user_id = ${user_id}
    Run Keyword And Ignore Error    Execute Sql String    DELETE FROM users WHERE id = ${user_id}
    Run Keyword And Ignore Error    Disconnect From Global Database

*** Test Cases ***
TC-001_Verify_API_returns_Bronze_tier_with_total_spend_0_for_a_user_with_no_COMPLETED_orders
    [Documentation]    Verify API returns Bronze tier with total_spend 0 for a user with no COMPLETED orders
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/${dynamic_id}/loyalty    expected_status=any

    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[user_id]    ${dynamic_id}
    Should Be Equal As Numbers    ${json}[total_spend]    0.0
    Should Be Equal As Strings    ${json}[tier]    Bronze
    Should Be Equal As Integers    ${json}[cashback_percent]    0
    Should Be Equal As Strings    ${json}[next_tier]    Silver
    Should Be Equal As Numbers    ${json}[spend_to_next_tier]    5000.0

    [Teardown]    Cleanup User Data    ${dynamic_id}

TC-002_Verify_API_returns_Bronze_tier_for_total_spend_4999_boundary_just_below_Silver
    [Documentation]    Verify API returns Bronze tier for total_spend 4999 (boundary just below Silver)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${dynamic_id}, 'PROD-01', 4999.00, 'COMPLETED')
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/${dynamic_id}/loyalty    expected_status=any

    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[user_id]    ${dynamic_id}
    Should Be Equal As Numbers    ${json}[total_spend]    4999.0
    Should Be Equal As Strings    ${json}[tier]    Bronze
    Should Be Equal As Integers    ${json}[cashback_percent]    0
    Should Be Equal As Strings    ${json}[next_tier]    Silver
    Should Be Equal As Numbers    ${json}[spend_to_next_tier]    1.0

    [Teardown]    Cleanup User Data    ${dynamic_id}

TC-003_Verify_API_returns_Silver_tier_for_total_spend_5000_lower_bound_inclusive
    [Documentation]    Verify API returns Silver tier for total_spend 5000 (lower bound inclusive)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${dynamic_id}, 'PROD-01', 5000.00, 'COMPLETED')
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/${dynamic_id}/loyalty    expected_status=any

    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[user_id]    ${dynamic_id}
    Should Be Equal As Numbers    ${json}[total_spend]    5000.0
    Should Be Equal As Strings    ${json}[tier]    Silver
    Should Be Equal As Integers    ${json}[cashback_percent]    1
    Should Be Equal As Strings    ${json}[next_tier]    Gold
    Should Be Equal As Numbers    ${json}[spend_to_next_tier]    15000.0

    [Teardown]    Cleanup User Data    ${dynamic_id}

TC-004_Verify_API_returns_Silver_tier_for_total_spend_12500_worked_example
    [Documentation]    Verify API returns Silver tier for total_spend 12500 (worked example)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${dynamic_id}, 'PROD-01', 12500.00, 'COMPLETED')
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/${dynamic_id}/loyalty    expected_status=any

    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[user_id]    ${dynamic_id}
    Should Be Equal As Numbers    ${json}[total_spend]    12500.0
    Should Be Equal As Strings    ${json}[tier]    Silver
    Should Be Equal As Integers    ${json}[cashback_percent]    1
    Should Be Equal As Strings    ${json}[next_tier]    Gold
    Should Be Equal As Numbers    ${json}[spend_to_next_tier]    7500.0

    [Teardown]    Cleanup User Data    ${dynamic_id}

TC-005_Verify_API_returns_Gold_tier_for_total_spend_20000_lower_bound_inclusive
    [Documentation]    Verify API returns Gold tier for total_spend 20000 (lower bound inclusive)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${dynamic_id}, 'PROD-01', 20000.00, 'COMPLETED')
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/${dynamic_id}/loyalty    expected_status=any

    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[user_id]    ${dynamic_id}
    Should Be Equal As Numbers    ${json}[total_spend]    20000.0
    Should Be Equal As Strings    ${json}[tier]    Gold
    Should Be Equal As Integers    ${json}[cashback_percent]    2
    Should Be Equal As Strings    ${json}[next_tier]    Platinum
    Should Be Equal As Numbers    ${json}[spend_to_next_tier]    30000.0

    [Teardown]    Cleanup User Data    ${dynamic_id}

TC-006_Verify_API_returns_Gold_tier_for_total_spend_49999_boundary_just_below_Platinum
    [Documentation]    Verify API returns Gold tier for total_spend 49999 (boundary just below Platinum)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${dynamic_id}, 'PROD-01', 49999.00, 'COMPLETED')
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/${dynamic_id}/loyalty    expected_status=any

    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[user_id]    ${dynamic_id}
    Should Be Equal As Numbers    ${json}[total_spend]    49999.0
    Should Be Equal As Strings    ${json}[tier]    Gold
    Should Be Equal As Integers    ${json}[cashback_percent]    2
    Should Be Equal As Strings    ${json}[next_tier]    Platinum
    Should Be Equal As Numbers    ${json}[spend_to_next_tier]    1.0

    [Teardown]    Cleanup User Data    ${dynamic_id}
TC-007_Verify_API_returns_Platinum_tier_for_total_spend_50000_lower_bound_inclusive_top_tier
    [Documentation]    Verify API returns Platinum tier for total_spend 50000 (lower bound inclusive, top tier)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${dynamic_id}, 'PROD-01', 50000.00, 'COMPLETED')
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/${dynamic_id}/loyalty    expected_status=any

    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[user_id]    ${dynamic_id}
    Should Be Equal As Numbers    ${json}[total_spend]    50000.0
    Should Be Equal As Strings    ${json}[tier]    Platinum
    Should Be Equal As Integers    ${json}[cashback_percent]    5
    Should Be Equal    ${json}[next_tier]    ${None}
    Should Be Equal As Numbers    ${json}[spend_to_next_tier]    0.0

    [Teardown]    Cleanup User Data    ${dynamic_id}

TC-008_Verify_API_excludes_CANCELLED_orders_from_total_spend_COMPLETED_30000_plus_CANCELLED_25000_returns_Gold
    [Documentation]    Verify API excludes CANCELLED orders from total_spend (COMPLETED 30000 + CANCELLED 25000 -> Gold)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${dynamic_id}, 'PROD-01', 30000.00, 'COMPLETED')
    Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${dynamic_id}, 'PROD-02', 25000.00, 'CANCELLED')
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/${dynamic_id}/loyalty    expected_status=any

    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[user_id]    ${dynamic_id}
    Should Be Equal As Numbers    ${json}[total_spend]    30000.0
    Should Be Equal As Strings    ${json}[tier]    Gold
    Should Be Equal As Integers    ${json}[cashback_percent]    2
    Should Be Equal As Strings    ${json}[next_tier]    Platinum
    Should Be Equal As Numbers    ${json}[spend_to_next_tier]    20000.0

    [Teardown]    Cleanup User Data    ${dynamic_id}

TC-009_Verify_API_rounds_fractional_total_spend_to_2_decimals_COMPLETED_12500_50_returns_Silver
    [Documentation]    Verify API rounds fractional total_spend to 2 decimals (COMPLETED 12500.50 -> Silver)
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random
    Execute Sql String    INSERT INTO users (id, status) VALUES (${dynamic_id}, 'ACTIVE')
    Execute Sql String    INSERT INTO orders (user_id, product_id, amount, status) VALUES (${dynamic_id}, 'PROD-01', 12500.50, 'COMPLETED')
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/${dynamic_id}/loyalty    expected_status=any

    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json}[user_id]    ${dynamic_id}
    Should Be Equal As Numbers    ${json}[total_spend]    12500.5
    Should Be Equal As Strings    ${json}[tier]    Silver
    Should Be Equal As Integers    ${json}[cashback_percent]    1
    Should Be Equal As Strings    ${json}[next_tier]    Gold
    Should Be Equal As Numbers    ${json}[spend_to_next_tier]    7499.5

    [Teardown]    Cleanup User Data    ${dynamic_id}

TC-010_Verify_API_returns_404_when_user_id_does_not_exist_in_the_users_table
    [Documentation]    Verify API returns 404 when user_id does not exist in the users table
    Create Global API Session
    ${non_existent_id}=    Evaluate    random.randint(1000000, 2000000000)    modules=random

    ${resp}=    GET On Session    api    /api/v1/users/${non_existent_id}/loyalty    expected_status=any

    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    User not found

TC-011_Verify_API_returns_404_when_user_id_is_0_not_in_users_table
    [Documentation]    Verify API returns 404 when user_id is 0 (not in users table)
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/0/loyalty    expected_status=any

    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    User not found

TC-012_Verify_API_returns_404_when_user_id_is_negative_not_in_users_table
    [Documentation]    Verify API returns 404 when user_id is negative (not in users table)
    Create Global API Session

    ${resp}=    GET On Session    api    /api/v1/users/-1/loyalty    expected_status=any

    Status Should Be    404    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Strings    ${json}[detail]    User not found