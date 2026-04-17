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

Studio Pro Launched Successfully
    [Documentation]    Studio Pro should have started and shown a window during suite setup
    [Tags]    ui
    Log    Studio Pro launched and sign-in handled during suite setup

MxLint Panel Can Be Opened
    [Documentation]    MxLint pane can be opened through Studio Pro menu
    [Tags]    ui
    Open MxLint Pane Via Menu
