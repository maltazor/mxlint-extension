*** Settings ***
Library    FlaUILibrary    uia=UIA3    screenshot_on_failure=False
Library    Process
Library    OperatingSystem

*** Variables ***
${STUDIOPRO_EXE}      %{STUDIOPRO_EXE}
${APP_DIR}            %{APP_DIR}
${STARTUP_TIMEOUT}    180
${MAIN_WINDOW}        /Window[contains(@Name,'Mendix Studio Pro')]

*** Keywords ***
Start Studio Pro With Extension
    [Documentation]    Launch Studio Pro with --enable-extension-development flag
    ${mpr_file}=    Join Path    ${APP_DIR}    App.mpr
    File Should Exist    ${mpr_file}
    ${pid}=    Launch Application With Args
    ...    ${STUDIOPRO_EXE}
    ...    --enable-extension-development "${mpr_file}"
    Set Suite Variable    ${STUDIOPRO_PID}    ${pid}
    Should Not Be Equal As Integers    ${pid}    0
    Log    Studio Pro launched with PID ${pid}
    Wait Until Element Exist    ${MAIN_WINDOW}    ${STARTUP_TIMEOUT}

Stop Studio Pro
    [Documentation]    Gracefully stop Studio Pro
    Run Keyword And Ignore Error    Close Application    ${STUDIOPRO_PID}
    Run Keyword And Ignore Error
    ...    Wait Until Element Does Not Exist    ${MAIN_WINDOW}    30

Extension DLL Should Be Deployed
    [Documentation]    Verify the extension DLL exists in the app's extensions folder
    ${dll_path}=    Join Path    ${APP_DIR}    extensions    MxLintExtension    MxLintExtension.dll
    File Should Exist    ${dll_path}

Extension Config Should Exist
    [Documentation]    Verify the extension config file was created
    ${config_path}=    Join Path    ${APP_DIR}    .mendix-cache    mxlint-extension.yaml
    File Should Exist    ${config_path}
    ${content}=    Get File    ${config_path}
    Should Contain    ${content}    rules
    Should Contain    ${content}    lint
    Should Contain    ${content}    modelsource
    RETURN    ${content}
