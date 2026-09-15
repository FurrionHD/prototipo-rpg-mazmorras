@echo off
REM Doble clic aqui para PROBAR A MANO el menu del HOGAR con una partida de prueba: materiales en la
REM bolsa y en casa, piezas y consumibles en el cofre y dinero en la hucha. La ventana NO se cierra
REM sola; abajo a la izquierda hay un boton para reabrir el hogar. Tu partida guardada NO se toca.
REM
REM   ver_hogar.bat capturas   -> pasada automatica, guarda tools\salida\hogar_*.png y se cierra
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_hogar.tscn y pulsa F6.
    pause
    exit /b 1
)
if "%1"=="" (
    "%GODOT%" --path "%~dp0.." res://tools/visores/dev_hogar.tscn
) else (
    "%GODOT%" --path "%~dp0.." res://tools/visores/dev_hogar.tscn -- %*
)
