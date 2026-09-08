@echo off
REM Doble clic aqui para recorrer la TIENDA de verdad, subpestaña a subpestaña, en los dos
REM mostradores (T1 y el T2 del Rey Slime). Comprueba que cada una pinta lo suyo -- que es donde
REM pega el fallo de renumerar el match por indice -- y que ya no se vende magia en ninguna.
REM Saca una captura de cada una en tools\salida\tienda_*.png y se cierra.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_tienda.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_tienda.tscn
