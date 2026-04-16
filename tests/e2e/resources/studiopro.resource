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
    [Documentation]    If the sign-in dialog appears, skip it using keyboard navigation.
    ...    The sign-in content is rendered in a WebView2 which FlaUI cannot
    ...    inspect directly, so we use Tab and Enter to reach the skip button.
    ${exists}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    IF    not ${exists}
        Log    No sign-in window detected
        RETURN
    END
    Log    Sign-in window detected, attempting keyboard skip...
    Focus    ${MAIN_WINDOW}
    Sleep    2s
    # Try Escape first — may dismiss the sign-in dialog
    Press Keys    ${MAIN_WINDOW}    ESCAPE
    Sleep    3s
    ${still_sign_in}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    IF    not ${still_sign_in}
        Log    Sign-in dismissed with Escape
        RETURN
    END
    # Escape didn't work. Tab through the WebView2 content to find Skip.
    # Try increasing Tab counts to locate the skip button/link.
    Focus    ${MAIN_WINDOW}
    FOR    ${tab_count}    IN RANGE    1    15
        Press Keys    ${MAIN_WINDOW}    TAB
        Sleep    0.3s
    END
    Press Keys    ${MAIN_WINDOW}    RETURN
    Sleep    3s
    ${still_sign_in2}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    IF    not ${still_sign_in2}
        Log    Sign-in skipped with Tab+Enter (14 tabs)
        RETURN
    END
    # Try fewer tabs — the skip link might be earlier
    Focus    ${MAIN_WINDOW}
    FOR    ${tab_count}    IN RANGE    1    6
        Press Keys    ${MAIN_WINDOW}    TAB
        Sleep    0.3s
    END
    Press Keys    ${MAIN_WINDOW}    RETURN
    Sleep    3s
    ${still_sign_in3}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    IF    not ${still_sign_in3}
        Log    Sign-in skipped with Tab+Enter (5 tabs)
        RETURN
    END
    # Try Shift+Tab in case Skip is before the focused element
    Focus    ${MAIN_WINDOW}
    FOR    ${tab_count}    IN RANGE    1    6
        Press Keys    ${MAIN_WINDOW}    SHIFT TAB
        Sleep    0.3s
    END
    Press Keys    ${MAIN_WINDOW}    RETURN
    Sleep    3s
    ${still_sign_in4}=    Element Should Exist    ${SIGN_IN_WINDOW}    ${False}
    IF    not ${still_sign_in4}
        Log    Sign-in skipped with Shift+Tab+Enter
        RETURN
    END
    Log    WARN: All keyboard skip attempts failed. Proceeding anyway.

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
