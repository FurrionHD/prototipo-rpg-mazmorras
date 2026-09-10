@echo off
REM Doble clic aqui para comprobar los FILOS y los MANTOS, y sobre todo el MANTO PRISMATICO: que su
REM elemento sale al azar entre los cinco, que el +10%% de velocidad dura lo que duran sus 25 ataques
REM (y NO lo que duren unos turnos), que al agotarse devuelve velocidad, afinidad y bonus, y que la
REM imbuicion viaja entera en la ficha de un combate al siguiente.
REM Comprueba tambien la mecanica moonlight: el manto de luz recorta la luz a x0.70 pero recibe x1.30
REM de oscuridad, que es la mitad que se olvida.
REM Es logica pura: no abre ventana y no deja capturas, solo escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_imbuiciones.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." res://tools/visores/dev_imbuiciones.tscn
pause
