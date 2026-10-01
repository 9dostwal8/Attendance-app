@echo off
title ZKTeco Local Attendance Bridge (Port 5055)
color 0A
echo ===================================================================
echo               ZKTeco Local Attendance Bridge Server
echo ===================================================================
echo  This service bridges communication between your Web Browser
echo  (Chrome/Edge) and your local ZKTeco attendance machine.
echo.
echo  Listening on: http://127.0.0.1:5055
echo ===================================================================
echo.

dart run bin/zk_bridge.dart

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Bridge exited with error code %ERRORLEVEL%.
    pause
)
