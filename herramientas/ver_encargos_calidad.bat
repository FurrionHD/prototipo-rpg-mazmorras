@echo off
REM Doble clic aqui para ver LA TABLA DE CALIDADES DE UN ENCARGO por piso y tipo de material, para
REM poder mover los MARGEN_* mirando numeros en vez de a ojo.
REM Es logica pura: no abre ventana y no deja capturas, solo escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/dev_encargos_calidad.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." res://tools/dev_encargos_calidad.tscn
pause
