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

Extension Dependencies Are Deployed
    [Documentation]    Key runtime dependencies must be present alongside the DLL
    ${ext_dir}=    Join Path    ${APP_DIR}    extensions    MxLintExtension
    File Should Exist    ${ext_dir}${/}YamlDotNet.dll

Studio Pro Main Window Is Visible
    [Documentation]    The Studio Pro main window should be present after sign-in skip
    [Tags]    ui
    Element Should Exist    ${MAIN_WINDOW}
