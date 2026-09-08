@echo off
REM Doble clic aqui para comprobar las CASILLAS DE HECHIZOS del panel de debug: que marcar una te
REM concede el hechizo y te lo pone, que desmarcarla te lo quita sin olvidarlo, y que al pasarte del
REM tope las que sobran se desmarcan solas en vez de quedarse mintiendo.
REM Abre ventana y deja la foto en tools\salida\panel_hechizos.png.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_panel_hechizos.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_panel_hechizos.tscn
pause
