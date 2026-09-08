@echo off
REM Doble clic aqui para REESCRIBIR los .tres de los tochos a partir de la tabla que hay dentro de
REM tools\generar_tochos.gd. Ahi es donde se editan los titulos y los textos: no toques los .tres a
REM mano, que esto los pisa. Tambien borra los que ya no esten en la tabla y les pone su clave de
REM biblioteca a los grimorios.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/generar_tochos.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." res://tools/generar_tochos.tscn
pause
