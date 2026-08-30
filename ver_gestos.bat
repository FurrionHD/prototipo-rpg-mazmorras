@echo off
REM Doble clic aqui para ver los gestos de ataque en movimiento.
REM Teclas: ESPACIO siguiente, 1-5 imbuicion, P pausa, R repetir, +/- velocidad, ESC salir.
REM Suena el sonido de cada gesto y en pantalla pone QUE FICHERO es (audio/sfx/...): asi se puede
REM decidir cual hay que retocar sin adivinar. Las teclas 1-5 cambian la imbuicion y con ella la
REM capa de elemento que suena encima.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona dev_gestos.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0." res://dev_gestos.tscn
