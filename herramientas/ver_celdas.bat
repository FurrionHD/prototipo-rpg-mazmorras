@echo off
REM Doble clic aqui para ver la CELDA del inventario con un objeto de cada clase y de cada peldaño
REM de cada escala, todos juntos: los 5 rangos de material, los 3 tipos de consumible, los cristales
REM y las 8 rarezas de equipo. Debajo, los mismos objetos al tamaño del SUELO (16 px, ampliados x4),
REM porque el dibujo lo comparten los dos sitios y un retoque para la celda llega tambien al suelo.
REM Guarda la captura en tools\salida\celdas.png y se cierra sola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_celdas.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_celdas.tscn
