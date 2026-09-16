@echo off
REM Doble clic aqui para recorrer la TABERNA de verdad (rehecha con la cara del
REM inventario), con una partida recien empezada.
REM Comprueba que el primer companero es gratis y trae su arma puesta,
REM y que los siguientes se pagan, y saca capturas en
REM tools\salida\taberna_*.png. Se cierra sola al terminar.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_taberna.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_taberna.tscn
