@echo off
chcp 65001 >nul
rem RELEASE-сборка: запускается только из Junkie (ключ) и только при живой сессии
rem нашего Control (Build ID опубликован в панели, обслуживание выключено).
rem Результат: dist\release\Violite.release.lua, Violite.loader.ui.lua, RELEASE.txt
cd /d "%~dp0"
node build\bundle.js --release
if errorlevel 1 goto failed
node build\key-loader.js
if errorlevel 1 goto failed
echo.
echo Done: dist\release\  (дальнейшие шаги — dist\release\RELEASE.txt)
goto end
:failed
echo.
echo Build FAILED
:end
pause
