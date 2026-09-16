@echo off
REM Doble clic aqui para recorrer la HERRERIA y la CARPINTERIA de verdad (rehechas con la cara del
REM inventario), con el baul lleno de metal, madera, cuero y nucleos.
REM Comprueba las once pestanas, que fundir, forjar y hacer herramientas
REM cobran lo que dicen y que la excelia va a quien eliges, y saca capturas en
REM tools\salida\herreria_*.png. Se cierra sola al terminar.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_herreria.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_herreria.tscn
