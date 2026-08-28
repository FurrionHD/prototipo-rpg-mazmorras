@echo off
REM Doble clic aqui para el visor VIVO del muñeco del jugador: animaciones adelante/atras, las 8
REM direcciones, arma equipada, dual, pausa y fotograma a fotograma.
REM
REM Teclas: ESPACIO/-> animacion, <- anterior, A/D direccion, B/V arma, N dual, P pausa,
REM         ,/. fotograma, +/- velocidad, F12 captura, ESC salir.
REM
REM ABRE UNA VENTANA a proposito: en --headless no se dibuja nada y no se reparte input a la GUI.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona dev_jugador_animaciones.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0." res://dev_jugador_animaciones.tscn
