@echo off
REM Doble clic aqui para ver los ataques de los ENEMIGOS en movimiento.
REM Teclas: ESPACIO siguiente, B/V cambiar de enemigo, T debil/fuerte, P pausa, R repetir, +/- velocidad, ESC salir.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona dev_enemigos_ataques.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0." res://dev_enemigos_ataques.tscn
