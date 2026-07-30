*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_Expired_Unpaid_SOFT_LOCKED_Reservations_Are_Cancelled_By_Sweep
    [Documentation]    Verify an expired unpaid SOFT_LOCKED reservation is cancelled by the sweep and counted once.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner R', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver R', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Release Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'R-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'SOFT_LOCKED', 80, NOW() - INTERVAL '2 minutes')

    # Steps
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    released

    ${status_result}=    Query    SELECT status FROM reservations WHERE id = ${dynamic_id}
    ${status}=    Set Variable    ${status_result[0][0]}
    Should Be Equal As Strings    ${status}    CANCELLED

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-002_Verify_SOFT_LOCKED_Reservations_Still_Inside_TTL_Are_Left_Untouched
    [Documentation]    Verify a SOFT_LOCKED reservation still inside its TTL is left untouched.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner R', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver R', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Release Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'R-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'SOFT_LOCKED', 80, NOW() + INTERVAL '3 minutes')

    # Steps
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    released

    ${status_result}=    Query    SELECT status FROM reservations WHERE id = ${dynamic_id}
    ${status}=    Set Variable    ${status_result[0][0]}
    Should Be Equal As Strings    ${status}    SOFT_LOCKED

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-003_Verify_CONFIRMED_Reservations_Are_Never_Released_Even_When_Lock_Expires_At_Has_Passed
    [Documentation]    Verify a CONFIRMED reservation is never released even when its lock_expires_at has passed.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner R', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver R', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Release Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'R-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 80, NOW() - INTERVAL '10 minutes')

    # Steps
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    released

    ${status_result}=    Query    SELECT status FROM reservations WHERE id = ${dynamic_id}
    ${status}=    Set Variable    ${status_result[0][0]}
    Should Be Equal As Strings    ${status}    CONFIRMED

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-004_Verify_Already_CANCELLED_Reservations_Are_Not_Counted_Again
    [Documentation]    Verify an already CANCELLED reservation is not counted again — the sweep is idempotent through the status transition.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner R', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver R', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Release Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'R-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'CANCELLED', 80, NOW() - INTERVAL '15 minutes')

    # Steps
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary
    ${resp}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    released

    ${status_result}=    Query    SELECT status FROM reservations WHERE id = ${dynamic_id}
    ${status}=    Set Variable    ${status_result[0][0]}
    Should Be Equal As Strings    ${status}    CANCELLED

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-005_Verify_Mixed_Batch_Releases_Only_The_Expired_Unpaid_Soft_Locks
    [Documentation]    Verify a mixed batch releases only the expired unpaid soft-locks: 2 expired + 1 still locked + 1 confirmed seeded, exactly 2 released.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner R', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver R', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Release Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'R-1', true)
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id} + 1, ${dynamic_id}, 'R-2', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'SOFT_LOCKED', 80, NOW() - INTERVAL '30 seconds')
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id} + 1, ${dynamic_id}, ${dynamic_id}, ${dynamic_id} + 1, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'SOFT_LOCKED', 80, NOW() - INTERVAL '5 minutes')
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id} + 2, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'CONFIRMED', 80, NOW() - INTERVAL '5 minutes')

    # Steps
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary
    ${resp_flush}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any
    ${resp}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp_flush}
    Status Should Be    200    ${resp}
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    released

    ${count_result}=    Query    SELECT count(*) FROM reservations WHERE status = 'CANCELLED' AND id IN (${dynamic_id}, ${dynamic_id} + 1)
    Should Be Equal As Integers    ${count_result[0][0]}    2

    ${status_result}=    Query    SELECT status FROM reservations WHERE id = ${dynamic_id} + 2
    ${status}=    Set Variable    ${status_result[0][0]}
    Should Be Equal As Strings    ${status}    CONFIRMED

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-006_Verify_Second_Sweep_Over_Same_Data_Releases_Nothing_More
    [Documentation]    Verify a second sweep over the same data releases nothing more (idempotency of the whole endpoint).
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner R', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver R', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Release Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'R-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'SOFT_LOCKED', 80, NOW() - INTERVAL '4 minutes')

    # Steps
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary
    ${resp_flush}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any
    ${resp_first_sweep}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any
    ${resp_second_sweep}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp_flush}
    Status Should Be    200    ${resp_first_sweep}
    Status Should Be    200    ${resp_second_sweep}

    ${json_first}=    Set Variable    ${resp_first_sweep.json()}
    Dictionary Should Contain Key    ${json_first}    released

    ${json_second}=    Set Variable    ${resp_second_sweep.json()}
    Should Be Equal As Strings    ${json_second}[released]    0

    ${status_result}=    Query    SELECT status FROM reservations WHERE id = ${dynamic_id}
    ${status}=    Set Variable    ${status_result[0][0]}
    Should Be Equal As Strings    ${status}    CANCELLED

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

TC-007_Verify_Released_Spot_Becomes_Bookable_Again
    [Documentation]    Verify the released spot becomes bookable again: after the sweep the freed spot is still active and its hold is gone.
    Connect To Global Database
    ${dynamic_id}=    Evaluate    random.randint(1000, 9999)    modules=random

    # PreRequisites
    Execute Sql String    INSERT INTO owners (id, name, email, subscription_active) VALUES (${dynamic_id}, 'Owner R', 'owner_${dynamic_id}@example.com', true)
    Execute Sql String    INSERT INTO drivers (id, name, email) VALUES (${dynamic_id}, 'Driver R', 'driver_${dynamic_id}@example.com')
    Execute Sql String    INSERT INTO lots (id, owner_id, name, hourly_rate, wall_code) VALUES (${dynamic_id}, ${dynamic_id}, 'Release Lot', 40, '1234')
    Execute Sql String    INSERT INTO spots (id, lot_id, code, is_active) VALUES (${dynamic_id}, ${dynamic_id}, 'R-1', true)
    Execute Sql String    INSERT INTO reservations (id, driver_id, lot_id, spot_id, start_time, end_time, status, price, lock_expires_at) VALUES (${dynamic_id}, ${dynamic_id}, ${dynamic_id}, ${dynamic_id}, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '90 minutes', 'SOFT_LOCKED', 80, NOW() - INTERVAL '90 seconds')

    # Steps
    Create Session    api    ${BASE_API_URL}
    ${payload}=    Create Dictionary
    ${resp_flush}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any
    ${resp}=    POST On Session    api    /bookings/release-expired    json=${payload}    expected_status=any

    # Verification
    Status Should Be    200    ${resp_flush}
    Status Should Be    200    ${resp}

    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    released

    ${count_result}=    Query    SELECT count(*) FROM reservations WHERE spot_id = ${dynamic_id} AND status IN ('SOFT_LOCKED', 'CONFIRMED')
    Should Be Equal As Integers    ${count_result[0][0]}    0

    ${is_active_result}=    Query    SELECT is_active FROM spots WHERE id = ${dynamic_id}
    ${is_active}=    Set Variable    ${is_active_result[0][0]}
    Should Be Equal    ${is_active}    ${True}

    # Teardown
    [Teardown]    Cleanup Test Case And Mock    ${dynamic_id}

*** Keywords ***
Cleanup Test Case And Mock
    [Arguments]    ${id}
    Execute Sql String    DELETE FROM reservations WHERE id IN (${id}, ${id} + 1, ${id} + 2)
    Execute Sql String    DELETE FROM spots WHERE id IN (${id}, ${id} + 1)
    Execute Sql String    DELETE FROM lots WHERE id = ${id}
    Execute Sql String    DELETE FROM drivers WHERE id = ${id}
    Execute Sql String    DELETE FROM owners WHERE id = ${id}
    Disconnect From Global Database