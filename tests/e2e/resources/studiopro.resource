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

Dump Window Children
    [Documentation]    Log all direct children of the Studio Pro window for XPath discovery
    ${children}=    Find All Elements    ${MAIN_WINDOW}
    FOR    ${child}    IN    @{children}
        Log    XPath: ${child.Xpath} | Name: ${child.Name} | AutomationId: ${child.AutomationId} | ClassName: ${child.ClassName}
    END

Open MxLint Pane Via Menu
    [Documentation]    Open the MxLint pane through Extensions > Open MxLint menu
    Dump Window Children
    ${extensions_menu}=    Set Variable    ${MAIN_WINDOW}/Menu/MenuItem[@Name='Extensions']
    ${exists}=    Element Should Exist    ${extensions_menu}    ${False}
    IF    ${exists}
        Click    ${extensions_menu}
    ELSE
        ${extensions_menu}=    Set Variable    ${MAIN_WINDOW}/MenuItem[@Name='Extensions']
        ${exists}=    Element Should Exist    ${extensions_menu}    ${False}
        IF    ${exists}
            Click    ${extensions_menu}
        ELSE
            Fail    Could not find Extensions menu - check Dump Window Children log output
        END
    END
    ${open_mxlint}=    Set Variable    /MenuItem[@Name='Open MxLint']
    Wait Until Element Exist    ${open_mxlint}    10
    Click    ${open_mxlint}
    Log    MxLint pane opened

Extension Config Should Exist
    [Documentation]    Verify the extension config file was created
    ${config_path}=    Join Path    ${APP_DIR}    .mendix-cache    mxlint-extension.yaml
    File Should Exist    ${config_path}
    ${content}=    Get File    ${config_path}
    Should Contain    ${content}    rules
    Should Contain    ${content}    lint
    Should Contain    ${content}    modelsource
    RETURN    ${content}
