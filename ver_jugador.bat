@echo off
REM Saca HOJAS DE CONTACTO del personaje en tools/salida/, para JUZGAR el dibujo.
REM Para ver el MOVIMIENTO esta ver_jugador_animaciones.bat, que abre una ventana.
REM
REM   ver_jugador.bat [animacion]     las 8 direcciones (filas) x los fotogramas
REM   ver_jugador.bat todas           todas las animaciones, una por fila, de perfil
REM
REM Animaciones: idle, sigilo, walk, correr, golpe, encaje, muerte, cadaver.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0." res://tools/ver_jugador.tscn -- %1 %2
