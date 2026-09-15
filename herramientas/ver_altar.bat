@echo off
REM Doble clic aqui para PROBAR A MANO el menu del ALTAR y el de SUBIR DE NIVEL, con un escenario
REM donde sale todo: las nueve pasivas pendientes, los once desarrollos subiendo de rango (Sedaki),
REM los once disponibles al subir de nivel (el lider) y uno en el Hogar (Oriol).
REM La ventana NO se cierra sola: abajo a la izquierda hay botones para reabrir el altar, rehacer el
REM escenario y subir de nivel. Tu partida guardada NO se toca.
REM
REM   ver_altar.bat capturas   -> pasada automatica, guarda tools\salida\altar_*.png y se cierra
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_altar.tscn y pulsa F6.
    pause
    exit /b 1
)
if "%1"=="" (
    "%GODOT%" --path "%~dp0.." res://tools/visores/dev_altar.tscn
) else (
    "%GODOT%" --path "%~dp0.." res://tools/visores/dev_altar.tscn -- %*
)
