@echo off
REM Doble clic aqui para ver LA ANIMACION PREVIA DE LA MEDITACION a velocidad real y en bucle.
REM Es lo que hay que mirar para juzgar el RITMO: las capturas de ver_maestro.bat enseñan las cinco
REM fases sueltas, pero si el paseo se hace largo o el brillo entra de golpe solo se ve corriendo.
REM
REM TECLAS
REM   ESPACIO   repetir desde el principio
REM   FLECHAS   cambiar la rareza del brillo (es lo unico que la animacion comunica)
REM   P         pausa      , y .   un pasito atras / adelante
REM   + / -     mas lento / mas rapido
REM   ESC       salir
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_ritual.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_ritual.tscn
