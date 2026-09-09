@echo off
REM Doble clic aqui para comprobar LA REGLA DE LA VISIBILIDAD contra el caso que la definio: dos
REM aliados con farolillo, uno detras de un muro (no se le ve, aunque lleve su luz) y otro con linea
REM despejada (si se le ve, aunque tu luz no le llegue). Lo cita scripts/world/vision.gd.
REM Es logica pura: no abre ventana y no deja capturas, solo escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/probar_vision.gd y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." --script res://tools/probar_vision.gd
pause
