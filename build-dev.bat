@echo off
chcp 65001 >nul
rem DEV-сборка: работает где угодно, без ключа и без сервера (сессия owner локально).
rem Результат: dist\dev\Violite.dev.lua + копия в workspace Potassium (VioCFG\Violite).
rem В executor: loadstring(readfile("VioCFG/Violite/Violite.dev.lua"))()
cd /d "%~dp0"
node build\bundle.js --install
if errorlevel 1 goto failed
node build\key-loader.js --preview
if errorlevel 1 goto failed
echo.
echo Done: dist\dev\
goto end
:failed
echo.
echo Build FAILED
:end
pause
