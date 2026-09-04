@echo off
REM Doble clic aqui para ver el INVENTARIO de verdad, con la bolsa y el baul llenos de cosas
REM inventadas: las ocho rarezas de arma, las cinco clases de consumible y montones de cantidades
REM muy distintas. Saca una captura de cada pestaña en tools\salida\inventario_*.png y se cierra.
REM Es lo que hay que mirar para juzgar la PANTALLA; ver_celdas.bat es para juzgar la CELDA suelta.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_inventario.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_inventario.tscn
