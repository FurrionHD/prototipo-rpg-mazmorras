@echo off
REM Saca una TIRA PNG con los fotogramas de una animacion, ampliados y en fila, en tools/salida/.
REM Para JUZGAR el dibujo frame a frame; para ver el movimiento esta ver_enemigos_animaciones.bat.
REM
REM   ver_animacion.bat [enemigo] [anim] [direccion]
REM   ver_animacion.bat slime encaje
REM   ver_animacion.bat rey_slime walk 2
REM
REM 'enemigo' es el nombre del .tres en scenes/actors/enemy (sin extension).
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0." res://tools/ver_animacion.tscn -- %1 %2 %3
