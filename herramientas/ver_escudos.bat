@echo off
REM Doble clic aqui para ver LA PERSONALIDAD DE LOS TRES ESCUDOS en numeros: los tres eran el mismo
REM escudo con otras cifras, y esto mide lo que ahora los separa.
REM Es logica pura: no abre ventana y no deja capturas, solo escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/dev_escudos.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." res://tools/dev_escudos.tscn
pause
