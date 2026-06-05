@echo off
REM =============================================
REM  Arrastra un PDF sobre este archivo .bat
REM  y genera el .md limpio al lado del PDF.
REM =============================================

if "%~1"=="" (
    echo Arrastra un archivo PDF sobre este .bat para convertirlo.
    pause
    exit /b
)

echo.
echo  PDF to Markdown
echo  ================
echo.

python "%~dp0pdf2md.py" "%~1"

echo.
pause
