@echo off
REM Doble clic aqui para ver el menu del MAESTRO DE HABILIDADES de verdad, con la partida de prueba
REM (grupo de cuatro, baul lleno y cada uno con su arma). Saca una captura de cada caso en
REM tools\salida\maestro_*.png y se cierra. Es lo que hay que mirar para juzgar esa pantalla.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_maestro.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_maestro.tscn
