@echo off
REM Doble clic aqui para ver LOS SEIS AMAGOS DEL GACHA seguidos.
REM
REM El amago es el "fakeout": la luz vira a un color PEOR y a mitad del brillo se rompe y sale el de
REM verdad. En el juego pasa el 22% de las tandas buenas, asi que verlo a base de tirar seria cosa
REM de veinte tiradas por cada uno: esto los pone los seis en fila.
REM
REM Va a 0,6x a proposito -- a velocidad real el fogonazo dura tres fotogramas y lo unico que puedes
REM decir de el es "algo ha pasado". Con + lo subes a la de verdad para juzgar el RITMO, que es otra
REM pregunta. Y ver_ritual.bat sigue siendo el de una animacion suelta (ahi el amago va con F).
REM
REM TECLAS
REM   ESPACIO   repetir el de ahora
REM   FLECHAS   cual de los seis
REM   S         fijar este y que no pase al siguiente
REM   P         pausa      , y .   un pasito atras / adelante
REM   + / -     mas rapido / mas lento
REM   ESC       salir
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_amagos.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_amagos.tscn
