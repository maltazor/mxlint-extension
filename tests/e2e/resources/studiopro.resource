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
${WEBVIEW_PANE}       /Window[contains(@Name,'Mendix Studio Pro')]/Pane/Pane
${EXTENSIONS_MENU}    /Window[contains(@Name,'Mendix Studio Pro')]/MenuBar/MenuItem[@Name='Extensions']
${MXLINT_MENU_ITEM}   /Window[contains(@Name,'Mendix Studio Pro')]/Menu/MenuItem[contains(@Name,'MxLint')]
${MXLINT_PANE}        /Window[contains(@Name,'Mendix Studio Pro')]//*[@Name='MxLint']
${MXLINT_EMPTY_STATE}    ${MXLINT_PANE}//*[contains(@Name,'No test cases found')]
${MXLINT_RESULTS_RULE}   ${MXLINT_PANE}//*[contains(@Name,'DemoUsersDisabled') or contains(@Name,'SecurityChecks') or contains(@Name,'StrongPasswordPolicy')]

*** Keywords ***
Start Studio Pro With Extension
    [Documentation]    Launch Studio Pro with --enable-extension-development and skip sign-in
    ${mpr_file}=    Join Path    ${APP_DIR}    App.mpr
    File Should Exist    ${mpr_file}
    ${pid}=    Launch Application With Args
    ...    ${STUDIOPRO_EXE}
    ...    --enable-extension-development "${mpr_file}"
    Set Suite Variable    ${STUDIOPRO_PID}    ${pid}
    Set Suite Variable    ${MXLINT_PANE_OPENED}    ${False}
    Should Not Be Equal As Integers    ${pid}    0
    Log    Studio Pro launched with PID ${pid}
    Wait Until Element Exist    ${MAIN_WINDOW}    ${STARTUP_TIMEOUT}
    Try Open MxLint Pane During Setup
    ${signin_status}    ${signin_msg}=    Run Keyword And Ignore Error    Skip Sign In If Present
    Log    Sign-in skip result: ${signin_status} - ${signin_msg}    level=WARN
    ${load_status}    ${load_msg}=    Run Keyword And Ignore Error    Wait For Project To Load
    Log    Project load result: ${load_status} - ${load_msg}    level=WARN
    IF    not ${MXLINT_PANE_OPENED}
        Try Open MxLint Pane During Setup
    END

Skip Sign In If Present
    [Documentation]    Dismiss the sign-in dialog by pressing Escape.
    ...    The sign-in content is rendered in a WebView2 so we cannot click
    ...    UI elements directly. Pressing Escape skips the sign-in.
    ${exists}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    IF    not ${exists}
        Log    No sign-in window detected
        RETURN
    END
    Log    Sign-in window detected, waiting for WebView2 to load...
    Sleep    10s
    FOR    ${attempt}    IN RANGE    1    6
        Log    Escape attempt ${attempt}/5
        Focus    ${MAIN_WINDOW}
        Run Keyword And Ignore Error    Focus    ${WEBVIEW_PANE}
        Sleep    1s
        Press Key    s'ESCAPE'    ${MAIN_WINDOW}
        Sleep    5s
        ${still_sign_in}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
        IF    not ${still_sign_in}
            Log    Sign-in dismissed with Escape (attempt ${attempt})
            RETURN
        END
        Log    Sign-in still present after attempt ${attempt}
    END
    Fail    Could not dismiss sign-in dialog after 5 Escape attempts

Wait For Project To Load
    [Documentation]    After sign-in is dismissed a loading modal appears.
    ...    Wait until the window title no longer contains "Sign In".
    Log    Waiting for project to finish loading...
    Wait Until Keyword Succeeds    120s    5s
    ...    Sign In Window Should Be Gone
    Log    Project loaded successfully

Sign In Window Should Be Gone
    [Documentation]    Assert that no sign-in window exists
    ${exists}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    Should Not Be True    ${exists}    Studio Pro is still showing the sign-in window

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
    ${config_path}=    Join Path    ${APP_DIR}    mxlint.yaml
    File Should Exist    ${config_path}
    ${content}=    Get File    ${config_path}
    Should Contain    ${content}    rules
    Should Contain    ${content}    lint
    Should Contain    ${content}    modelsource
    RETURN    ${content}

Open MxLint Pane Via Menu
    [Documentation]    Open MxLint pane from Studio Pro menu and assert it is visible
    Wait Until Keyword Succeeds    20s    2s
    ...    Open MxLint Pane Once

Open MxLint Pane Once
    Focus    ${MAIN_WINDOW}
    Click Hold    ${EXTENSIONS_MENU}    750
    Click    ${MXLINT_MENU_ITEM}
    Wait Until Element Exist    ${MXLINT_PANE}    20

Try Open MxLint Pane During Setup
    [Documentation]    Attempt to open pane during setup and store result
    ${opened}=    Run Keyword And Return Status    Open MxLint Pane Via Menu
    Set Suite Variable    ${MXLINT_PANE_OPENED}    ${opened}
    Log    MxLint pane opened during setup: ${opened}

MxLint Pane Should Show Lint Results
    [Documentation]    Verify lint results are visible in the pane table.
    Open MxLint Pane Via Menu
    ${is_empty}=    Element Should Exist    ${MXLINT_EMPTY_STATE}    ${False}
    Should Not Be True    ${is_empty}    MxLint pane shows empty state instead of lint results
    Wait Until Keyword Succeeds    120s    5s
    ...    Wait Until Element Exist    ${MXLINT_RESULTS_RULE}    10
