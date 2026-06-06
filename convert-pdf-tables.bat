@echo off
REM =============================================
REM  Arrastra un PDF sobre este .bat
REM  Convierte con docling (mejor para tablas)
REM  Usa virtualenv en C:\venv-pdf
REM =============================================

if "%~1"=="" (
    echo Arrastra un archivo PDF sobre este .bat para convertirlo.
    pause
    exit /b
)

echo.
echo  PDF to Markdown (docling)
echo  ==========================
echo.

C:\venv-pdf\Scripts\python.exe "%~dp0pdf2md.py" "%~1" --engine docling

echo.
pause
