@echo off
title IQ-Market Runner 🚀
chcp 65001 > nul
cls

:: Sleek and premium CLI header
echo ===================================================
echo   IQ-MARKET DEVELOPER UTILITY
echo ===================================================
echo   System: Windows
echo   Workspace: d:\iqmarket
echo ===================================================
echo.
echo   [1] 📱 Run on Android Device (23106RN0DA)
echo   [2] 💻 Run on Windows (Desktop)
echo   [3] 🌐 Run on Google Chrome (Web)
echo   [4] 🧹 Clean and Restore Packages (clean & pub get)
echo   [5] 🔍 Run Flutter Static Analysis
echo   [6] ❌ Exit
echo.
echo ===================================================
set /p choice="👉 Choose an option (1-6): "

if "%choice%"=="1" goto android
if "%choice%"=="2" goto windows
if "%choice%"=="3" goto chrome
if "%choice%"=="4" goto clean
if "%choice%"=="5" goto analyze
if "%choice%"=="6" goto exit
goto invalid

:android
echo.
echo 🚀 Launching IQ-Market on Android Device (23106RN0DA)...
flutter run -d 23106RN0DA
pause
goto exit

:windows
echo.
echo 🚀 Launching IQ-Market on Windows Desktop...
flutter run -d windows
pause
goto exit

:chrome
echo.
echo 🚀 Launching IQ-Market on Google Chrome...
flutter run -d chrome --web-renderer canvaskit
pause
goto exit

:clean
echo.
echo 🧹 Cleaning build cache and fetching dependencies...
call flutter clean
call flutter pub get
echo.
echo ✅ Project ready!
pause
goto exit

:analyze
echo.
echo 🔍 Running flutter analyze...
call flutter analyze
pause
goto exit

:invalid
echo.
echo ⚠️ Invalid choice. Please try again.
pause
goto exit

:exit
exit
