*** Settings ***
Library          DatabaseLibrary
Resource         ../../resources/projects/parking_service/config.robot

*** Test Cases ***
Check Users Table Schema
    Connect To Global Database
    ${cols}=    Query    SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'users' ORDER BY ordinal_position
    Log To Console    USERS COLUMNS: ${cols}
    ${cols2}=    Query    SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'vehicles' ORDER BY ordinal_position
    Log To Console    VEHICLES COLUMNS: ${cols2}
    ${cols3}=    Query    SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'drivers' ORDER BY ordinal_position
    Log To Console    DRIVERS COLUMNS: ${cols3}
    Disconnect From Global Database