*** Settings ***
Documentation    Verify the MxLint extension loads correctly in Mendix Studio Pro
Resource         resources/studiopro.resource
Suite Setup      Start Studio Pro With Extension
Suite Teardown   Stop Studio Pro

*** Test Cases ***
Extension DLL Is Deployed
    [Documentation]    The extension DLL should be in the app extensions folder
    Extension DLL Should Be Deployed

Extension Creates Config On First Run
    [Documentation]    Studio Pro loading the extension should create the default config
    [Tags]    config
    Wait Until Keyword Succeeds    60s    5s
    ...    Extension Config Should Exist

Config Contains Expected Default Values
    [Documentation]    The generated config should have correct default settings
    [Tags]    config
    ${content}=    Extension Config Should Exist
    Should Contain    ${content}    .mendix-cache/rules
    Should Contain    ${content}    .mendix-cache/lint-results.json
    Should Contain    ${content}    modelsource
    Should Contain    ${content}    mxlint-rules

MxLint Menu Is Available
    [Documentation]    The MxLint menu extension should register menu entries
    [Tags]    ui
    # Look for the Extensions menu or MxLint menu entry
    Wait Until Keyword Succeeds    30s    5s
    ...    Element Should Exist    name:Extensions

Open MxLint Pane
    [Documentation]    Opening the MxLint pane should show the lint results panel
    [Tags]    ui    pane
    # Click the Extensions menu
    Click    name:Extensions
    Wait Until Keyword Succeeds    10s    2s
    ...    Element Should Exist    name:Open MxLint
    Click    name:Open MxLint
    # The pane should appear at the bottom
    Wait Until Keyword Succeeds    15s    3s
    ...    Element Should Exist    name:MxLint
