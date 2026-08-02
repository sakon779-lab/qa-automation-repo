*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_sandbox_renders_tutorial_page
    [Documentation]    Verify GET /web/sandbox renders the tutorial page with the header, the reset control and the scenario cards read from the delivered static/sandbox_scenarios.json
    Create Global API Session
    ${resp}=    GET On Session    api    /web/sandbox    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    คู่มือสอน
    Should Contain    ${body}    เริ่มใหม่ทั้งหมด
    Should Contain    ${body}    /sandbox/reset
    Should Contain    ${body}    สถานการณ์
    Should Contain    ${body}    ลองดู

TC-002_Verify_page_renders_delivered_scenario_file
    [Documentation]    Verify the page renders the DELIVERED scenario file rather than hardcoded copy - the narrative, method and path of a real step must appear on the page
    Create Global API Session
    ${resp}=    GET On Session    api    /web/sandbox    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    จองที่จอด
    Should Contain    ${body}    /bookings
    Should Contain    ${body}    POST
    Should Contain    ${body}    ลองดู

TC-003_Verify_each_step_shows_expect_status
    [Documentation]    Verify each step shows what SHOULD come back (expect_status) beside its ลองดู button, which is what makes the page teach rather than just fire requests
    Create Global API Session
    ${resp}=    GET On Session    api    /web/sandbox    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    expect_status
    Should Contain    ${body}    step-expect-contains

TC-004_Verify_destructive_reset_asks_before_firing
    [Documentation]    Verify the destructive reset asks before it fires - POST /sandbox/reset truncates every table, so the served JS must call confirm() and only then fetch()
    Create Global API Session
    ${resp}=    GET On Session    api    /static/sandbox.js    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    function resetAll
    Should Contain    ${body}    confirm(
    Should Contain    ${body}    /sandbox/reset