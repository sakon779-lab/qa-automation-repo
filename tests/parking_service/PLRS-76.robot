*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    DatabaseLibrary
Resource   ../../resources/projects/parking_service/config.robot

*** Test Cases ***
TC-001_Verify_GET_web_sandbox_renders_tutorial_page
    [Documentation]    Verify GET /web/sandbox renders the tutorial page with its header, the
    ...                reset control, and the persona tour read from the delivered
    ...                static/sandbox_tour.json.
    Create Global API Session
    ${resp}=    GET On Session    api    /web/sandbox    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    คู่มือสอน
    Should Contain    ${body}    เริ่มใหม่ทั้งหมด
    Should Contain    ${body}    /sandbox/reset
    Should Contain    ${body}    สิ่งที่ควรเห็นบนหน้าจอ
    Should Contain    ${body}    เปิดหน้านี้

TC-002_Verify_page_renders_delivered_tour_file
    [Documentation]    Verify the page renders the DELIVERED tour file rather than hardcoded
    ...                copy — a persona, a real step title and the link to the real screen that
    ...                step opens must all appear.
    Create Global API Session
    ${resp}=    GET On Session    api    /web/sandbox    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    คนขับ
    Should Contain    ${body}    จองที่จอด
    Should Contain    ${body}    /web/lots

TC-003_Verify_the_API_view_is_reachable_from_the_page
    [Documentation]    The page used to embed a console of our own, and this case asserted the
    ...                expect_status shown beside each of its buttons. That console was retired:
    ...                Swagger already executes every endpoint and validates its schema, so the
    ...                curation moved INTO it as named request-body examples. What the page must
    ...                still do is TAKE the visitor there — a tour that teaches the screens and
    ...                then hides the API view is a dead end for the audience that wants it.
    Create Global API Session
    ${resp}=    GET On Session    api    /web/sandbox    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    /docs
    Should Contain    ${body}    เปิดหน้า API docs
    # ...and the destination has to be real, with the curated examples actually in it.
    ${docs}=    GET On Session    api    /openapi.json    expected_status=any
    Status Should Be    200    ${docs}
    Should Contain    ${docs.text}    examples

TC-004_Verify_destructive_reset_asks_before_firing
    [Documentation]    Verify the destructive reset asks before it fires - POST /sandbox/reset truncates every table, so the served JS must call confirm() and only then fetch()
    Create Global API Session
    ${resp}=    GET On Session    api    /static/sandbox.js    expected_status=any
    Status Should Be    200    ${resp}
    ${body}=    Set Variable    ${resp.text}
    Should Contain    ${body}    function resetAll
    Should Contain    ${body}    confirm(
    Should Contain    ${body}    /sandbox/reset