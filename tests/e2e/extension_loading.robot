*** Settings ***
Documentation    Verify the MxLint extension loads correctly in Mendix Studio Pro
Library          FlaUILibrary    uia=UIA3    screenshot_on_failure=False
Library          OperatingSystem
Resource         resources/studiopro.resource
Suite Setup      Start Studio Pro With Extension
Suite Teardown   Stop Studio Pro

*** Test Cases ***
Extension DLL Is Deployed
    [Documentation]    The compiled extension DLL must exist in the app extensions folder
    Extension DLL Should Be Deployed

Manifest Is Deployed
    [Documentation]    The extension manifest.json must be present alongside the DLL
    ${manifest}=    Join Path    ${APP_DIR}    extensions    MxLintExtension    manifest.json
    File Should Exist    ${manifest}
    ${content}=    Get File    ${manifest}
    Should Contain    ${content}    MxLintExtension.dll

Studio Pro Main Window Is Visible
    [Documentation]    The Studio Pro main window should be present after sign-in skip
    [Tags]    ui
    Element Should Exist    ${MAIN_WINDOW}

Extension Creates Config On First Run
    [Documentation]    The extension should create the default config file
    [Tags]    config
    Wait Until Keyword Succeeds    180s    5s
    ...    Extension Config Should Exist

Config Contains Expected Default Values
    [Documentation]    The generated config should have correct default settings
    [Tags]    config
    ${content}=    Extension Config Should Exist
    Should Contain    ${content}    .mendix-cache/rules
    Should Contain    ${content}    .mendix-cache/lint-results.json
    Should Contain    ${content}    modelsource
    Should Contain    ${content}    mxlint-rules
