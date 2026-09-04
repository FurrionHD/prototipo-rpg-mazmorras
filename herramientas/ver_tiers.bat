@echo off
REM Doble clic aqui para ver el ESCALERA DEL TIER: celdas de verdad del T1 al T24, para ver que el sistema
REM aguanta lo que se le pide cuando el juego pase del T3 (hoy solo hay tres).
REM puestos. Saca una captura de cada seccion en tools\salida\tiers.png y se cierra.
REM Es lo que hay que mirar para juzgar la PANTALLA antes de dar nada por hecho.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_tiers.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_tiers.tscn
