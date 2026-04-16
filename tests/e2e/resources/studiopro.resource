*** Settings ***
Library    FlaUILibrary    uia=UIA3    screenshot_on_failure=False
Library    Process
Library    OperatingSystem

*** Variables ***
${STUDIOPRO_EXE}      %{STUDIOPRO_EXE}
${APP_DIR}            %{APP_DIR}
${STARTUP_TIMEOUT}    180
${MAIN_WINDOW}        /Window[contains(@Name,'Mendix Studio Pro')]
${SIGN_IN_WINDOW}     /Window[contains(@Name,'Sign In')]

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
    Skip Sign In If Present

Skip Sign In If Present
    [Documentation]    If the sign-in dialog appears, find and click the skip button
    ${exists}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    IF    not ${exists}
        Log    No sign-in window detected, skipping
        RETURN
    END
    Log    Sign-in window detected, exploring children...
    Dump Element Children    ${SIGN_IN_WINDOW}
    Try Click Skip Button

Dump Element Children
    [Documentation]    Log all children of an element for XPath discovery
    [Arguments]    ${xpath}
    ${children}=    Find All Elements    ${xpath}
    FOR    ${child}    IN    @{children}
        Log    XPath: ${child.Xpath} | Name: ${child.Name} | AutomationId: ${child.AutomationId} | ClassName: ${child.ClassName}
    END

Try Click Skip Button
    [Documentation]    Try common skip/close button patterns on the sign-in window
    # Try various possible button names
    ${patterns}=    Create List
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Skip']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='skip']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Skip Sign In']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Cancel']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Close']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Not now']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Later']
    ...    ${SIGN_IN_WINDOW}/Hyperlink[@Name='Skip']
    ...    ${SIGN_IN_WINDOW}/Text[@Name='Skip']
    ...    ${MAIN_WINDOW}/Button[@Name='Skip']
    ...    ${MAIN_WINDOW}/Button[@Name='Cancel']
    ...    ${MAIN_WINDOW}/Button[@Name='Close']
    FOR    ${pattern}    IN    @{patterns}
        ${found}=    Element Should Exist    ${pattern}    ${False}
        IF    ${found}
            Log    Found skip element at: ${pattern}
            Click    ${pattern}
            Log    Clicked skip button successfully
            RETURN
        END
    END
    Log    WARN: Could not find skip button - check Dump Element Children output
    Fail    Could not find skip button on sign-in window. Check log for UI tree.

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
