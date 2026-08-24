@echo off
REM Doble clic aqui para ver las animaciones de MOVIMIENTO de los enemigos (idle/andar/embestida).
REM Teclas: ESPACIO/-> animacion, <- anterior, A/D direccion, B/V enemigo, P pausa, +/- velocidad, ESC salir.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona dev_enemigos_animaciones.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0." res://dev_enemigos_animaciones.tscn
