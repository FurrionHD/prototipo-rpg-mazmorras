@echo off
REM Doble clic aqui para ver el DIA Y LA NOCHE del pueblo (CicloDia + LuzPueblo).
REM Fija la hora a mediodia, atardecer, noche y amanecer y saca capturas en tools\salida\noche_*.png.
REM Se cierra sola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_noche.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_noche.tscn
