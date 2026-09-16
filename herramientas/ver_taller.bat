@echo off
REM Doble clic aqui para recorrer la BOTICARIA y la COCINA de verdad (rehechas con la cara del
REM inventario), con el baul lleno de ingredientes de varias calidades y tiers.
REM Comprueba que la rejilla son las recetas, que el filtro Vida/Mana/Antidotos filtra, que fabricar
REM cobra lo que dice y que la excelia del oficio va a quien eliges, y saca capturas en
REM tools\salida\taller_*.png. Se cierra sola al terminar.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_taller.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_taller.tscn
