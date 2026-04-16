*** Settings ***
Library    FlaUILibrary    uia=UIA3    screenshot_on_failure=False
Library    Collections
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
    [Documentation]    If the sign-in dialog appears, explore and skip it
    ${exists}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    IF    not ${exists}
        Log    No sign-in window detected
        RETURN
    END
    Log    Sign-in window detected, exploring UI tree...
    Dump UI Tree
    Try Click Skip Button

Dump UI Tree
    [Documentation]    Explore the sign-in window at multiple depth levels
    @{search_paths}=    Create List
    ...    ${MAIN_WINDOW}
    ...    ${MAIN_WINDOW}/Window
    ...    ${MAIN_WINDOW}/Button
    ...    ${MAIN_WINDOW}/Pane
    ...    ${MAIN_WINDOW}/Text
    ...    ${MAIN_WINDOW}/Hyperlink
    ...    ${MAIN_WINDOW}/Custom
    ...    ${MAIN_WINDOW}/Document
    ...    ${MAIN_WINDOW}/Group
    ...    ${SIGN_IN_WINDOW}/Button
    ...    ${SIGN_IN_WINDOW}/Pane
    ...    ${SIGN_IN_WINDOW}/Text
    ...    ${SIGN_IN_WINDOW}/Hyperlink
    ...    ${SIGN_IN_WINDOW}/Custom
    ...    ${SIGN_IN_WINDOW}/Document
    ...    ${SIGN_IN_WINDOW}/Group
    FOR    ${path}    IN    @{search_paths}
        ${elements}=    Find All Elements    ${path}
        ${count}=    Get Length    ${elements}
        IF    ${count} > 0
            Log    === Found ${count} elements at ${path} ===
            FOR    ${el}    IN    @{elements}
                Log    XPath: ${el.Xpath} | Name: ${el.Name} | AutomationId: ${el.AutomationId} | ClassName: ${el.ClassName}
            END
        END
    END
    # Also try one more level deep inside any Pane children
    ${panes}=    Find All Elements    ${MAIN_WINDOW}/Pane
    FOR    ${pane}    IN    @{panes}
        Log    === Exploring pane children: ${pane.Xpath} ===
        @{pane_search}=    Create List
        ...    ${pane.Xpath}/Button
        ...    ${pane.Xpath}/Text
        ...    ${pane.Xpath}/Hyperlink
        ...    ${pane.Xpath}/Pane
        ...    ${pane.Xpath}/Custom
        ...    ${pane.Xpath}/Document
        FOR    ${sub_path}    IN    @{pane_search}
            ${sub_els}=    Find All Elements    ${sub_path}
            ${sub_count}=    Get Length    ${sub_els}
            IF    ${sub_count} > 0
                Log    === Found ${sub_count} at ${sub_path} ===
                FOR    ${sub_el}    IN    @{sub_els}
                    Log    XPath: ${sub_el.Xpath} | Name: ${sub_el.Name} | AutomationId: ${sub_el.AutomationId} | ClassName: ${sub_el.ClassName}
                END
            END
        END
    END

Try Click Skip Button
    [Documentation]    Try to find and click skip/close button on sign-in
    @{patterns}=    Create List
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Skip']
    ...    ${MAIN_WINDOW}/Button[@Name='Skip']
    ...    ${MAIN_WINDOW}/Pane/Button[@Name='Skip']
    ...    ${MAIN_WINDOW}/Pane/Pane/Button[@Name='Skip']
    ...    ${SIGN_IN_WINDOW}/Hyperlink[@Name='Skip']
    ...    ${MAIN_WINDOW}/Hyperlink[@Name='Skip']
    ...    ${MAIN_WINDOW}/Pane/Hyperlink[@Name='Skip']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Cancel']
    ...    ${MAIN_WINDOW}/Button[@Name='Cancel']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Close']
    ...    ${MAIN_WINDOW}/Button[@Name='Close']
    ...    ${MAIN_WINDOW}/Pane/Button[@Name='Close']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Not now']
    ...    ${MAIN_WINDOW}/Button[@Name='Not now']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Later']
    ...    ${MAIN_WINDOW}/Button[@Name='Later']
    ...    ${SIGN_IN_WINDOW}/Button[@Name='Continue offline']
    ...    ${MAIN_WINDOW}/Button[@Name='Continue offline']
    ...    ${MAIN_WINDOW}/Pane/Button[@Name='Continue offline']
    FOR    ${pattern}    IN    @{patterns}
        ${found}=    Element Should Exist    ${pattern}    ${False}
        IF    ${found}
            Log    Found skip element at: ${pattern}
            Click    ${pattern}
            Log    Clicked skip button successfully
            RETURN
        END
    END
    Fail    Could not find skip button. Check Dump UI Tree log output for available elements.

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
