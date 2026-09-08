@echo off
REM Doble clic aqui para comprobar los TOCHOS y la BIBLIOTECA: que los 30 cargan, que un grimorio
REM no se confunde con un tocho, que leer gasta y apunta, que el relleno repetido no da nada y el
REM de sabiduria si, y que la biblioteca sobrevive a guardar y cargar.
REM Es logica pura: no abre ventana y no deja capturas, solo escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_tochos.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." res://tools/visores/dev_tochos.tscn
pause
