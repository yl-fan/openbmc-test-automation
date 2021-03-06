*** Settings ***
Documentation          This example demonstrates executing commands on a remote machine
...                    and getting their output and the return code.
...
...                    Notice how connections are handled as part of the suite setup and
...                    teardown. This saves some time when executing several test cases.

Resource               ../lib/rest_client.robot
Resource               ../lib/ipmi_client.robot
Resource               ../lib/openbmc_ffdc.robot
Resource               ../lib/state_manager.robot
Library                ../data/model.py
Resource               ../lib/boot_utils.robot
Resource               ../lib/utils.robot

Suite Setup            Setup The Suite
Test Setup             Open Connection And Log In
Test Teardown          Post Test Case Execution

*** Variables ***

${stack_mode}     skip
${model}=         ${OPENBMC_MODEL}

*** Test Cases ***
Verify connection
    Execute new Command    echo "hello"
    Response Should Be Equal    "hello"

Execute ipmi BT capabilities command
    [Tags]  Execute_ipmi_BT_capabilities_command
    Run IPMI command            0x06 0x36
    response Should Be Equal    " 01 40 40 0a 01"

Execute Set Sensor Boot Count
    [Tags]  Execute_Set_Sensor_Boot_Count

    ${uri}=    Get System component    BootCount
    ${x}=      Get Sensor Number   ${uri}

    Run IPMI command   0x04 0x30 ${x} 0x01 0x00 0x35 0x00 0x00 0x00 0x00 0x00 0x00
    Read the Attribute      ${uri}   value
    ${val}=     convert to integer    53
    Response Should Be Equal   ${val}

Verify OCC Power Supply Redundancy
    [Documentation]  Check if OCC's power supply is set to not redundant.
    [Tags]  Verify_OCC_Power_Supply_Redundancy
    ${uri}=  Get System Component  PowerSupplyRedundancy

    Read The Attribute  ${uri}  value
    Response Should Be Equal  Disabled

Verify OCC Power Supply Derating Value
    [Documentation]  Check if OCC's power supply derating value
    ...  is set correctly to a constant value 10.
    [Tags]  Verify_OCC_Power_Supply_Derating_Value

    ${uri}=  Get System Component  PowerSupplyDerating

    Read The Attribute  ${uri}  value
    Response Should Be Equal  ${10}


Verify Enabling OCC Turbo Setting Via IPMI
    [Documentation]  Set and verify OCC's turbo allowed on enable.
    # The allowed value for turbo allowed:
    # True  - To enable turbo allowed.
    # False - To disable turbo allowed.
    [Setup]  Turbo Setting Test Case Setup
    [Tags]  Verify_Enabling_OCC_Turbo_Setting_Via_IPMI
    [Teardown]  Restore System Configuration

    ${uri}=  Get System Component  TurboAllowed
    ${sensor_num}=  Get Sensor Number  ${uri}

    ${ipmi_cmd}=  Catenate  SEPARATOR=  0x04 0x30 ${sensor_num} 0x00${SPACE}
    ...  0x00 0x01 0x00 0x00 0x00 0x00 0x20 0x00
    Run IPMI Command  ${ipmi_cmd}

    Read The Attribute  ${uri}  value
    Response Should Be Equal  True


Verify Disabling OCC Turbo Setting Via IPMI
    [Documentation]  Set and verify OCC's turbo allowed on disable.
    # The allowed value for turbo allowed:
    # True  - To enable turbo allowed.
    # False - To disable turbo allowed.
    [Setup]  Turbo Setting Test Case Setup
    [Tags]  Verify_Disabling_OCC_Turbo_Setting_Via_IPMI
    [Teardown]  Restore System Configuration

    ${uri}=  Get System Component  TurboAllowed
    ${sensor_num}=  Get Sensor Number  ${uri}

    ${ipmi_cmd}=  Catenate  SEPARATOR=  0x04 0x30 ${sensor_num} 0x00${SPACE}
    ...  0x00 0x00 0x00 0x01 0x00 0x00 0x20 0x00
    Run IPMI Command  ${ipmi_cmd}

    Read The Attribute  ${uri}  value
    Response Should Be Equal  False


Verify Setting OCC Turbo Via REST
    [Documentation]  Verify enabling and disabling OCC's turbo allowed
    ...  via REST.
    # The allowed value for turbo allowed:
    # True  - To enable turbo allowed.
    # False - To disable turbo allowed.

    [Setup]  Turbo Setting Test Case Setup
    [Tags]  Verify_Setting_OCC_Turbo_Via_REST
    [Teardown]  Restore System Configuration

    Set Turbo Setting Via REST  False
    ${setting}=  Read Turbo Setting Via REST
    Should Be Equal  ${setting}  False

    Set Turbo Setting Via REST  True
    ${setting}=  Read Turbo Setting Via REST
    Should Be Equal  ${setting}  True

io_board Present
    [Tags]  io_board_Present
    ${uri}=    Get System component    io_board
    Read The Attribute   ${uri}    present
    Response Should Be Equal    True

io_board Fault
    [Tags]  io_board_Fault
    ${uri}=    Get System component    io_board
    Read The Attribute   ${uri}    fault
    Response Should Be Equal    False

*** Keywords ***

Setup The Suite
    [Documentation]  Initial suite setup.

    # Boot Host.
    REST Power On

    Open Connection And Log In
    ${resp}=   Read Properties   ${OPENBMC_BASE_URI}enumerate   timeout=30
    Set Suite Variable      ${SYSTEM_INFO}          ${resp}
    log Dictionary          ${resp}

Turbo Setting Test Case Setup
    [Documentation]  Open Connection and turbo settings

    Open Connection And Log In
    ${setting}=  Read Turbo Setting Via REST
    Set Global Variable  ${TURBO_SETTING}  ${setting}

Get System component
    [Arguments]    ${type}
    ${list}=    Get Dictionary Keys    ${SYSTEM_INFO}
    ${resp}=    Get Matches    ${list}    regexp=^.*[0-9a-z_].${type}[0-9]*$
    ${url}=    Get From List    ${resp}    0
    [Return]    ${url}

Execute new Command
    [Arguments]    ${args}
    ${output}=  Execute Command    ${args}
    set test variable    ${OUTPUT}     "${output}"

response Should Be Equal
    [Arguments]    ${args}
    Should Be Equal    ${OUTPUT}    ${args}

Response Should Be Empty
    Should Be Empty    ${OUTPUT}

Read the Attribute
    [Arguments]    ${uri}    ${parm}
    ${output}=     Read Attribute      ${uri}    ${parm}
    set test variable    ${OUTPUT}     ${output}

Get Sensor Number
    [Arguments]  ${name}
    ${x}=       get sensor   ${OPENBMC_MODEL}   ${name}
    [Return]     ${x}

Get Inventory Sensor Number
    [Arguments]  ${name}
    ${x}=       get inventory sensor   ${OPENBMC_MODEL}   ${name}
    [Return]     ${x}

Post Test Case Execution
    [Documentation]  Do the post test teardown.
    ...  1. Capture FFDC on test failure.
    ...  2. Close all open SSH connections.

    FFDC On Test Case Fail
    Close All Connections

Restore System Configuration
    [Documentation]  Restore System Configuration.

    Open Connection And Log In
    Set Turbo Setting Via REST  ${TURBO_SETTING}
    Close All Connections
