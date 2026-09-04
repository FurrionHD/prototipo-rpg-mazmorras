@echo off
REM Doble clic aqui para ver el menu de PERSONAJE de verdad, con un grupo de cuatro (guerrero, maga
REM con baston, tanque con escudo y uno pelado), el baul lleno y hechizos, desarrollos y pasivas
REM puestos. Saca una captura de cada seccion en tools\salida\personaje_*.png y se cierra.
REM Es lo que hay que mirar para juzgar la PANTALLA antes de dar nada por hecho.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_personaje.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_personaje.tscn
