@echo off
REM Doble clic aqui para ver los VENDEDORES del mercadillo dentro de sus puestos.
REM Comprueba el hueco del vendedor y saca capturas en tools\salida\mercadillo_*.png. Se cierra sola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_mercadillo.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_mercadillo.tscn
