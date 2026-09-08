@echo off
REM Doble clic aqui para VER LAS MAGIAS en movimiento, una a una y en bucle. Es el equivalente del
REM visor de gestos pero para los hechizos: sale el dibujo que tendria en combate, contra una marca
REM del tamaño de un enemigo para poder juzgar la escala.
REM
REM   FLECHAS  cambiar de hechizo (van ordenados de comun a mitico)
REM   P        parar / seguir          S  pasar UN fotograma con el bucle parado
REM   R        repetir ahora           + / -  mas rapido / mas lento (hasta x0.05)
REM   F12      guarda la foto en tools\salida\
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_magias.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_magias.tscn
