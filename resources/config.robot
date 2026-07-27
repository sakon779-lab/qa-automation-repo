*** Settings ***
Documentation    Backward-compat shim. Historically the single payment config; kept so any legacy
...              `Resource ../resources/config.robot` still resolves. NEW suites import
...              resources/projects/<project>/config.robot directly (payment_service / parking_service).
Resource         projects/payment_service/config.robot
