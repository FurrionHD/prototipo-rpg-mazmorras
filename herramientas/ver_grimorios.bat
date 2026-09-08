@echo off
REM Doble clic aqui para ver el REPARTO DE GRIMORIOS del gacha: que sale cada hechizo, que la
REM escala es monotona (mas raro = sale menos), que el repetido baja pero nunca a cero, que el
REM sesgo va por personaje, y que meter un hechizo nuevo recoloca el reparto SIN tocar codigo.
REM Tira 200.000 veces y compara la frecuencia real con la tabla.
REM Es logica pura: no abre ventana, solo escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_grimorios.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." res://tools/visores/dev_grimorios.tscn
pause
