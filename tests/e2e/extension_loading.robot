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

Manifest Is Deployed
    [Documentation]    The extension manifest.json must be present alongside the DLL
    ${manifest}=    Join Path    ${APP_DIR}    extensions    MxLintExtension    manifest.json
    File Should Exist    ${manifest}
    ${content}=    Get File    ${manifest}
    Should Contain    ${content}    MxLintExtension.dll

Studio Pro Loaded Past Sign In
    [Documentation]    After setup, Studio Pro should no longer be on the sign-in screen
    [Tags]    ui
    Element Should Exist    ${MAIN_WINDOW}
    ${sign_in}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    IF    ${sign_in}
        Fail    Studio Pro is still on the sign-in screen
    END

Extension Creates Config On First Run
    [Documentation]    After sign-in is skipped the extension should create the config
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
