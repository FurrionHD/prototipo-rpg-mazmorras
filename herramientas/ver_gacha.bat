@echo off
REM Doble clic aqui para comprobar el GACHA DE LA MEDITACION: que el reparto sale 10/25/65, que el
REM PITY es un suelo duro (tiras 200 veces y cuentas los garantizados), que un epico de suerte NO
REM corta el contador, que el de 200 da legendario pero NO mitico, que va por personaje, y que el
REM pity del lider sobrevive a guardar y cargar.
REM Es logica pura: no abre ventana y no deja capturas, solo escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_gacha.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." res://tools/visores/dev_gacha.tscn
pause
