@echo off
REM Doble clic aqui para recorrer la PELETERIA de verdad (la rehecha con la cara del inventario):
REM curtir, correas y mochilas, con el baul lleno de pieles de varias calidades y tiers.
REM Comprueba que la rejilla es un monton por calidad, que curtir cobra lo que dice y que una
REM tanda de mochilas sale entera, y saca capturas en tools\salida\peleteria_*.png.
REM Se cierra sola al terminar.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_peleteria.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_peleteria.tscn
