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
${EXTENSIONS_MENU}    ${MAIN_WINDOW}//MenuItem[@Name='Extensions']
${MXLINT_MENU_ITEM}   ${MAIN_WINDOW}//MenuItem[contains(@Name,'MxLint')]
${MXLINT_PANE}        /Window[contains(@Name,'Mendix Studio Pro')]//*[@Name='MxLint']

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
    Should Contain    ${content}    cli
    Should Contain    ${content}    version:
    Should Contain    ${content}    modelsource
    RETURN    ${content}

Open MxLint Pane Via Menu
    [Documentation]    Open MxLint pane from Studio Pro menu and assert it is visible
    Wait Until Keyword Succeeds    20s    2s
    ...    Open MxLint Pane Once
    Set Suite Variable    ${MXLINT_PANE_OPENED}    ${True}

Open MxLint Pane Once
    ${already_open}=    Element Should Exist    ${MXLINT_PANE}    ${False}
    IF    ${already_open}
        RETURN
    END
    Log Pane Diagnostics
    Wait Until Element Exist    ${MAIN_WINDOW}    15
    Focus    ${MAIN_WINDOW}
    Wait Until Element Exist    ${EXTENSIONS_MENU}    15
    Click    ${EXTENSIONS_MENU}
    Sleep    1s
    Log Pane Diagnostics
    Wait Until Element Exist    ${MXLINT_MENU_ITEM}    15
    Click    ${MXLINT_MENU_ITEM}
    Wait Until Element Exist    ${MXLINT_PANE}    30

Try Open MxLint Pane During Setup
    [Documentation]    Attempt to open pane during setup and store result
    ${opened}=    Run Keyword And Return Status    Open MxLint Pane Via Menu
    Set Suite Variable    ${MXLINT_PANE_OPENED}    ${opened}
    Log    MxLint pane opened during setup: ${opened}
    IF    not ${opened}
        Log Pane Diagnostics
    END

Lint Results File Should Exist
    [Documentation]    Verify lint-results.json is generated in Mendix cache.
    ${results_path}=    Join Path    ${APP_DIR}    .mendix-cache    lint-results.json
    Sleep    15s
    ${status}    ${message}=    Run Keyword And Ignore Error
    ...    Wait Until Keyword Succeeds    180s    5s
    ...    File Should Exist    ${results_path}
    IF    '${status}' == 'FAIL'
        Log Cache Directory Snapshot
        Log MxLint Cache Logs
        Log Pane Diagnostics
        Fail    ${message}
    END
    ${content}=    Get File    ${results_path}
    Should Contain    ${content}    testsuites

Log MxLint Cache Logs
    [Documentation]    Log mxlint.logs from Mendix cache to aid troubleshooting.
    ${log_path}=    Join Path    ${APP_DIR}    .mendix-cache    mxlint.logs
    ${exists}=    Run Keyword And Return Status    File Should Exist    ${log_path}
    IF    ${exists}
        ${logs}=    Get File    ${log_path}
        Log    ===== BEGIN mxlint.logs =====\n${logs}\n===== END mxlint.logs =====    level=WARN
    ELSE
        Log    mxlint.logs not found at ${log_path}    level=WARN
    END

Log Cache Directory Snapshot
    [Documentation]    Log files present in .mendix-cache to aid troubleshooting.
    ${cache_dir}=    Join Path    ${APP_DIR}    .mendix-cache
    ${exists}=    Run Keyword And Return Status    Directory Should Exist    ${cache_dir}
    IF    ${exists}
        ${files}=    List Files In Directory    ${cache_dir}
        Log    .mendix-cache files: ${files}    level=WARN
    ELSE
        Log    .mendix-cache directory does not exist at ${cache_dir}    level=WARN
    END

Log Pane Diagnostics
    [Documentation]    Log key UI element presence for pane troubleshooting.
    ${main_exists}=    Element Should Exist    ${MAIN_WINDOW}    ${False}
    ${extensions_exists}=    Element Should Exist    ${EXTENSIONS_MENU}    ${False}
    ${menu_item_exists}=    Element Should Exist    ${MXLINT_MENU_ITEM}    ${False}
    ${pane_exists}=    Element Should Exist    ${MXLINT_PANE}    ${False}
    Log    Pane diagnostics: main_window=${main_exists}, extensions_menu=${extensions_exists}, mxlint_menu_item=${menu_item_exists}, mxlint_pane=${pane_exists}    level=WARN
