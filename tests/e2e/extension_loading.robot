*** Settings ***
Documentation    Verify the MxLint extension loads correctly in Mendix Studio Pro
Library          FlaUILibrary    uia=UIA3    screenshot_on_failure=False
Library          OperatingSystem
Resource         resources/studiopro.resource
Suite Setup      Start Studio Pro With Extension
Suite Teardown   Stop Studio Pro

*** Test Cases ***
Extension DLL Is Deployed
    [Documentation]    The extension DLL should be in the app extensions folder
    Extension DLL Should Be Deployed

Studio Pro Main Window Is Visible
    [Documentation]    The Studio Pro main window should be present
    [Tags]    ui
    Element Should Exist    ${MAIN_WINDOW}

Inspect Studio Pro UI Tree
    [Documentation]    Dump the UI tree for debugging menu XPaths
    [Tags]    debug
    Dump Window Children

Open MxLint Pane
    [Documentation]    Open the MxLint pane to trigger extension initialization
    [Tags]    ui
    Open MxLint Pane Via Menu

Extension Creates Config After Pane Opens
    [Documentation]    After the pane is opened the extension creates the default config
    [Tags]    config
    Wait Until Keyword Succeeds    120s    5s
    ...    Extension Config Should Exist

Config Contains Expected Default Values
    [Documentation]    The generated config should have correct default settings
    [Tags]    config
    ${content}=    Extension Config Should Exist
    Should Contain    ${content}    .mendix-cache/rules
    Should Contain    ${content}    .mendix-cache/lint-results.json
    Should Contain    ${content}    modelsource
    Should Contain    ${content}    mxlint-rules
