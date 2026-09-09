@echo off
REM Doble clic aqui para ver la TABLA DE RADIOS DEL FAROLILLO: que se ve con cada pieza en cada piso.
REM Es la CURVA entera lo que hay que mirar para calibrar la luz, no un radio suelto.
REM Es logica pura: no abre ventana y no deja capturas, solo escribe el resultado por consola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/ver_lampara.gd y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." --script res://tools/ver_lampara.gd
pause
