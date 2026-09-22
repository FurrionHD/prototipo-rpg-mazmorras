@echo off
REM Doble clic aqui para ver los GUARDIAS del pueblo y su cambio de turno (GuardiasPlan).
REM Comprueba las rutas, los tramos y que siempre haya un guardia por puesto, y saca capturas
REM del relevo en tools\salida\guardias_*.png. Se cierra sola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_guardias.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_guardias.tscn
