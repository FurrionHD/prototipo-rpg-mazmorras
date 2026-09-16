@echo off
REM Doble clic aqui para recorrer el PESCADOR de verdad (rehecho con la cara del
REM inventario): el libro de peces y el mostrador de cebos.
REM Comprueba que las especies sin pescar salen en negro
REM y que comprar cebos cobra lo que dice, y saca capturas en
REM tools\salida\pescador_*.png. Se cierra sola al terminar.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_pescador.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_pescador.tscn
