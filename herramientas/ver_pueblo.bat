@echo off
REM Doble clic aqui para ver el PUEBLO (scenes/levels/town.tscn, montado desde PuebloPlano).
REM Comprueba que cada oficio tiene su puerta, que se llega andando y que la F abre su menu,
REM y saca capturas en tools\salida\pueblo_*.png (el pueblo entero y cada puerta). Se cierra sola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_pueblo.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_pueblo.tscn
