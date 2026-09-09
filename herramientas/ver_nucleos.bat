@echo off
REM Doble clic aqui para ver la TABLA DE PAREJAS DE NUCLEOS, que es de lo que vive la mejora del
REM farolillo: cada banda pide uno de cada rama. Si a una banda le falta su pareja, ese tramo de
REM mejoras es IMPOSIBLE -- y jugando no hay forma de darse cuenta: solo se ve el boton en gris.
REM Es logica pura: no abre ventana y no deja capturas, solo escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/ver_nucleos.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." res://tools/ver_nucleos.tscn
pause
