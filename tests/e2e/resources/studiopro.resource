*** Settings ***
Library    FlaUILibrary    uia=UIA3    screenshot_on_failure=False
Library    Process
Library    OperatingSystem

*** Variables ***
${STUDIOPRO_EXE}      %{STUDIOPRO_EXE}
${APP_DIR}            %{APP_DIR}
${STARTUP_TIMEOUT}    180
${MAIN_WINDOW_PRIMARY}    /Window[contains(@Name,'Studio Pro')]
${MAIN_WINDOW_APP_MPR}    /Window[contains(@Name,'App.mpr')]
${MAIN_WINDOW_APP}        /Window[@Name='App']
${MAIN_WINDOW}            ${MAIN_WINDOW_PRIMARY}
${SIGN_IN_WINDOW}     /Window[contains(@Name,'Sign In')]
${WEBVIEW_PANE}       ${MAIN_WINDOW}/Pane/Pane
${MENU_BAR}           ${MAIN_WINDOW}//MenuBar
${EXTENSIONS_MENU_ITEM_LOCATOR}    ${MAIN_WINDOW}//MenuItem[contains(@Name,'Extension')]
${EXTENSIONS_BUTTON_LOCATOR}       ${MAIN_WINDOW}//Button[contains(@Name,'Extension')]
${EXTENSIONS_TAB_LOCATOR}          ${MAIN_WINDOW}//TabItem[contains(@Name,'Extension')]
${EXTENSIONS_MENU}    ${EXTENSIONS_MENU_ITEM_LOCATOR}
${MXLINT_MENU_ITEM_LOCATOR}    ${MAIN_WINDOW}//MenuItem[contains(@Name,'MxLint')]
${MXLINT_BUTTON_LOCATOR}       ${MAIN_WINDOW}//Button[contains(@Name,'MxLint')]
${MXLINT_MENU_ITEM}   ${MXLINT_MENU_ITEM_LOCATOR}
${MXLINT_PANE}        ${MAIN_WINDOW}//*[@Name='MxLint']

*** Keywords ***
Start Studio Pro With Extension
    [Documentation]    Launch Studio Pro with --enable-extension-development and skip sign-in
    Validate E2E Environment
    Log E2E Environment Snapshot
    ${mpr_file}=    Join Path    ${APP_DIR}    App.mpr
    File Should Exist    ${mpr_file}
    ${pid}=    Launch Application With Args
    ...    ${STUDIOPRO_EXE}
    ...    --enable-extension-development "${mpr_file}"
    Set Suite Variable    ${STUDIOPRO_PID}    ${pid}
    Set Suite Variable    ${MXLINT_PANE_OPENED}    ${False}
    Should Not Be Equal As Integers    ${pid}    0
    Log    Studio Pro launched with PID ${pid}
    Wait Until Keyword Succeeds    ${STARTUP_TIMEOUT}s    5s
    ...    Resolve Main Window Locator
    Set Main Window Dependent Locators
    ${signin_status}    ${signin_msg}=    Run Keyword And Ignore Error    Skip Sign In If Present
    Log    Sign-in skip result: ${signin_status} - ${signin_msg}    level=WARN
    ${load_status}    ${load_msg}=    Run Keyword And Ignore Error    Wait For Project To Load
    Log    Project load result: ${load_status} - ${load_msg}    level=WARN
    Try Open MxLint Pane During Setup

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
        Run Keyword And Ignore Error    Resolve Main Window Locator
        ${main_exists}=    Element Should Exist    ${MAIN_WINDOW}    ${False}
        Log    Escape attempt ${attempt}: active main locator=${MAIN_WINDOW}, exists=${main_exists}    level=WARN
        IF    not ${main_exists}
            Log Pane Diagnostics
            Log Studio Pro Window Snapshot
            Log Studio Pro Process Snapshot
        END
        ${main_focus_status}    ${main_focus_msg}=    Run Keyword And Ignore Error    Focus    ${MAIN_WINDOW}
        Log    Escape attempt ${attempt}: main focus=${main_focus_status} - ${main_focus_msg}    level=WARN
        ${webview_focus_status}    ${webview_focus_msg}=    Run Keyword And Ignore Error    Focus    ${WEBVIEW_PANE}
        Log    Escape attempt ${attempt}: webview focus=${webview_focus_status} - ${webview_focus_msg}    level=WARN
        Sleep    1s
        ${escape_status}    ${escape_msg}=    Run Keyword And Ignore Error    Press Key    s'ESCAPE'    ${MAIN_WINDOW}
        Log    Escape attempt ${attempt}: press escape=${escape_status} - ${escape_msg}    level=WARN
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
    Wait Until Keyword Succeeds    30s    5s
    ...    Resolve Main Window Locator
    Wait Until Keyword Succeeds    90s    5s
    ...    Extensions Menu Should Be Available
    Log    Project loaded successfully

Extensions Menu Should Be Available
    [Documentation]    Wait until the Extensions menu appears in the resolved Studio Pro main window.
    Resolve Main Window Locator
    ${main_exists}=    Element Should Exist    ${MAIN_WINDOW}    ${False}
    Should Be True    ${main_exists}    Main Studio Pro window is not available yet.
    Focus    ${MAIN_WINDOW}
    ${menu_bar_exists}=    Element Should Exist    ${MENU_BAR}    ${False}
    ${extensions_exists}=    Resolve Extensions Trigger Locator
    IF    not ${extensions_exists}
        Run Keyword And Ignore Error    Press Key    s'ALT'    ${MAIN_WINDOW}
        Sleep    1s
        ${extensions_exists}=    Resolve Extensions Trigger Locator
    END
    IF    not ${extensions_exists}
        Run Keyword And Ignore Error    Press Key    s'F10'    ${MAIN_WINDOW}
        Sleep    1s
        ${extensions_exists}=    Resolve Extensions Trigger Locator
    END
    IF    not ${extensions_exists}
        Run Keyword And Ignore Error    Press Key    s'ALT+E'    ${MAIN_WINDOW}
        Sleep    1s
        ${extensions_exists}=    Resolve Extensions Trigger Locator
    END
    Log    Extensions menu visible=${extensions_exists}, menu_bar=${menu_bar_exists}, menu_locator=${EXTENSIONS_MENU}    level=WARN
    Should Be True    ${extensions_exists}    Extensions menu is not visible yet.

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
    Element Should Appear Within    ${MAIN_WINDOW}    15
    Focus    ${MAIN_WINDOW}
    ${extensions_exists}=    Resolve Extensions Trigger Locator
    IF    not ${extensions_exists}
        Run Keyword And Ignore Error    Press Key    s'ALT'    ${MAIN_WINDOW}
        Sleep    1s
        ${extensions_exists}=    Resolve Extensions Trigger Locator
    END
    IF    not ${extensions_exists}
        Run Keyword And Ignore Error    Press Key    s'F10'    ${MAIN_WINDOW}
        Sleep    1s
        ${extensions_exists}=    Resolve Extensions Trigger Locator
    END
    IF    ${extensions_exists}
        Click    ${EXTENSIONS_MENU}
    END
    Sleep    1s
    Run Keyword And Ignore Error    Press Key    s'M'    ${MAIN_WINDOW}
    Run Keyword And Ignore Error    Press Key    s'DOWN'    ${MAIN_WINDOW}
    Run Keyword And Ignore Error    Press Key    s'ENTER'    ${MAIN_WINDOW}
    Element Should Appear Within    ${MXLINT_PANE}    30

Element Should Appear Within
    [Documentation]    Poll element existence with explicit timeout to avoid long UIA hangs.
    [Arguments]    ${locator}    ${timeout_seconds}=30
    FOR    ${index}    IN RANGE    ${timeout_seconds}
        ${exists}=    Element Should Exist    ${locator}    ${False}
        IF    ${exists}
            RETURN
        END
        Sleep    1s
    END
    Fail    Element '${locator}' did not appear within ${timeout_seconds}s.

Try Open MxLint Pane During Setup
    [Documentation]    Attempt to open pane during setup and store result
    ${opened}=    Run Keyword And Return Status    Open MxLint Pane Via Menu
    Set Suite Variable    ${MXLINT_PANE_OPENED}    ${opened}
    Log    MxLint pane opened during setup: ${opened}
    IF    not ${opened}
        Log Pane Diagnostics
        Log Studio Pro Process Snapshot
        Log Extension Directory Snapshot
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
        Log Studio Pro Process Snapshot
        Log Extension Directory Snapshot
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
    ${primary_exists}=    Element Should Exist    ${MAIN_WINDOW_PRIMARY}    ${False}
    ${app_mpr_exists}=    Element Should Exist    ${MAIN_WINDOW_APP_MPR}    ${False}
    ${app_exists}=    Element Should Exist    ${MAIN_WINDOW_APP}    ${False}
    ${main_exists}=    Element Should Exist    ${MAIN_WINDOW}    ${False}
    ${menu_bar_exists}=    Element Should Exist    ${MENU_BAR}    ${False}
    ${extensions_exists}=    Element Should Exist    ${EXTENSIONS_MENU}    ${False}
    ${menu_item_exists}=    Element Should Exist    ${MXLINT_MENU_ITEM}    ${False}
    ${pane_exists}=    Element Should Exist    ${MXLINT_PANE}    ${False}
    Log    Pane diagnostics: primary_window=${primary_exists}, app_mpr_window=${app_mpr_exists}, app_window=${app_exists}, active_main_locator=${MAIN_WINDOW}, active_main_exists=${main_exists}, menu_bar=${menu_bar_exists}, extensions_menu=${extensions_exists}, mxlint_menu_item=${menu_item_exists}, mxlint_pane=${pane_exists}    level=WARN

Validate E2E Environment
    [Documentation]    Assert key environment variables and files are present.
    Should Not Be Empty    ${STUDIOPRO_EXE}
    Should Not Be Empty    ${APP_DIR}
    Directory Should Exist    ${APP_DIR}
    File Should Exist    ${STUDIOPRO_EXE}
    ${mpr_path}=    Join Path    ${APP_DIR}    App.mpr
    File Should Exist    ${mpr_path}
    ${ext_dir}=    Join Path    ${APP_DIR}    extensions    MxLintExtension
    Directory Should Exist    ${ext_dir}
    ${dll_path}=    Join Path    ${ext_dir}    MxLintExtension.dll
    File Should Exist    ${dll_path}

Log E2E Environment Snapshot
    [Documentation]    Log critical environment paths for troubleshooting.
    Log    STUDIOPRO_EXE=${STUDIOPRO_EXE}    level=WARN
    Log    APP_DIR=${APP_DIR}    level=WARN
    ${mpr_path}=    Join Path    ${APP_DIR}    App.mpr
    Log    App.mpr path: ${mpr_path}    level=WARN
    ${ext_dir}=    Join Path    ${APP_DIR}    extensions    MxLintExtension
    Log    Extension dir: ${ext_dir}    level=WARN

Log Studio Pro Process Snapshot
    [Documentation]    Log tasklist output for Studio Pro process.
    ${result}=    Run Process    tasklist    /FI    IMAGENAME eq studiopro.exe
    Log    tasklist rc=${result.rc}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}    level=WARN

Log Studio Pro Window Snapshot
    [Documentation]    Log Studio Pro main window titles and handles from process API.
    ${tasklist_verbose}=    Run Process    tasklist    /v    /FI    IMAGENAME eq studiopro.exe
    Log    tasklist /v rc=${tasklist_verbose.rc}\nstdout:\n${tasklist_verbose.stdout}\nstderr:\n${tasklist_verbose.stderr}    level=WARN
    ${ps}=    Run Process
    ...    powershell
    ...    -NoProfile
    ...    -Command
    ...    Get-Process -Name studiopro -ErrorAction SilentlyContinue | Select-Object Id,MainWindowTitle,MainWindowHandle,Responding | Format-List | Out-String -Width 4096
    Log    powershell window snapshot rc=${ps.rc}\nstdout:\n${ps.stdout}\nstderr:\n${ps.stderr}    level=WARN

Log Extension Directory Snapshot
    [Documentation]    Log deployed extension directory contents.
    ${ext_dir}=    Join Path    ${APP_DIR}    extensions    MxLintExtension
    ${exists}=    Run Keyword And Return Status    Directory Should Exist    ${ext_dir}
    IF    ${exists}
        ${files}=    List Files In Directory    ${ext_dir}
        Log    Extension files: ${files}    level=WARN
    ELSE
        Log    Extension directory missing at ${ext_dir}    level=WARN
    END

Set Main Window Dependent Locators
    [Documentation]    Rebuild locators that depend on the active main window.
    ${menu_bar}=    Set Variable    ${MAIN_WINDOW}//MenuBar
    ${extensions_menu_item_locator}=    Set Variable    ${MAIN_WINDOW}//MenuItem[contains(@Name,'Extension')]
    ${extensions_button_locator}=    Set Variable    ${MAIN_WINDOW}//Button[contains(@Name,'Extension')]
    ${extensions_tab_locator}=    Set Variable    ${MAIN_WINDOW}//TabItem[contains(@Name,'Extension')]
    ${extensions_menu}=    Set Variable    ${extensions_menu_item_locator}
    ${mxlint_menu_item_locator}=    Set Variable    ${MAIN_WINDOW}//MenuItem[contains(@Name,'MxLint')]
    ${mxlint_button_locator}=    Set Variable    ${MAIN_WINDOW}//Button[contains(@Name,'MxLint')]
    ${mxlint_menu_item}=    Set Variable    ${mxlint_menu_item_locator}
    ${mxlint_pane}=    Set Variable    ${MAIN_WINDOW}//*[@Name='MxLint']
    ${webview_pane}=    Set Variable    ${MAIN_WINDOW}/Pane/Pane
    Set Suite Variable    ${MENU_BAR}    ${menu_bar}
    Set Suite Variable    ${EXTENSIONS_MENU_ITEM_LOCATOR}    ${extensions_menu_item_locator}
    Set Suite Variable    ${EXTENSIONS_BUTTON_LOCATOR}    ${extensions_button_locator}
    Set Suite Variable    ${EXTENSIONS_TAB_LOCATOR}    ${extensions_tab_locator}
    Set Suite Variable    ${EXTENSIONS_MENU}    ${extensions_menu}
    Set Suite Variable    ${MXLINT_MENU_ITEM_LOCATOR}    ${mxlint_menu_item_locator}
    Set Suite Variable    ${MXLINT_BUTTON_LOCATOR}    ${mxlint_button_locator}
    Set Suite Variable    ${MXLINT_MENU_ITEM}    ${mxlint_menu_item}
    Set Suite Variable    ${MXLINT_PANE}    ${mxlint_pane}
    Set Suite Variable    ${WEBVIEW_PANE}    ${webview_pane}
    Log    Updated window-dependent locators for ${MAIN_WINDOW}    level=WARN

Resolve Extensions Trigger Locator
    [Documentation]    Select the best available Extensions trigger locator for current UI shape.
    ${menu_item_exists}=    Element Should Exist    ${EXTENSIONS_MENU_ITEM_LOCATOR}    ${False}
    IF    ${menu_item_exists}
        Set Suite Variable    ${EXTENSIONS_MENU}    ${EXTENSIONS_MENU_ITEM_LOCATOR}
        RETURN    ${True}
    END
    ${button_exists}=    Element Should Exist    ${EXTENSIONS_BUTTON_LOCATOR}    ${False}
    IF    ${button_exists}
        Set Suite Variable    ${EXTENSIONS_MENU}    ${EXTENSIONS_BUTTON_LOCATOR}
        RETURN    ${True}
    END
    ${tab_exists}=    Element Should Exist    ${EXTENSIONS_TAB_LOCATOR}    ${False}
    IF    ${tab_exists}
        Set Suite Variable    ${EXTENSIONS_MENU}    ${EXTENSIONS_TAB_LOCATOR}
        RETURN    ${True}
    END
    RETURN    ${False}

Resolve Main Window Locator
    [Documentation]    Resolve active Studio Pro main window locator based on current window title.
    ${primary_exists}=    Element Should Exist    ${MAIN_WINDOW_PRIMARY}    ${False}
    ${app_mpr_exists}=    Element Should Exist    ${MAIN_WINDOW_APP_MPR}    ${False}
    ${app_exists}=    Element Should Exist    ${MAIN_WINDOW_APP}    ${False}
    IF    ${primary_exists}
        Set Suite Variable    ${MAIN_WINDOW}    ${MAIN_WINDOW_PRIMARY}
        Set Main Window Dependent Locators
        Log    Using main window locator: ${MAIN_WINDOW_PRIMARY}    level=WARN
        RETURN
    END
    IF    ${app_mpr_exists}
        Set Suite Variable    ${MAIN_WINDOW}    ${MAIN_WINDOW_APP_MPR}
        Set Main Window Dependent Locators
        Log    Using fallback main window locator: ${MAIN_WINDOW_APP_MPR}    level=WARN
        RETURN
    END
    IF    ${app_exists}
        Set Suite Variable    ${MAIN_WINDOW}    ${MAIN_WINDOW_APP}
        Set Main Window Dependent Locators
        Log    Using fallback main window locator: ${MAIN_WINDOW_APP}    level=WARN
        RETURN
    END
    Log Studio Pro Window Snapshot
    Log Pane Diagnostics
    Fail    Could not resolve Studio Pro main window locator.
