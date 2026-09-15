@echo off
REM Doble clic aqui para recorrer la TIENDA de verdad (la rehecha con la cara del inventario):
REM vender (botin, equipo, consumibles, hogar), la cesta, filtros, buscador y los dos mostradores.
REM Comprueba que se vende todo lo que tienes y se cobra lo anunciado, y saca capturas en
REM tools\salida\tienda_*.png. Se cierra sola al terminar.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_tienda.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_tienda.tscn
