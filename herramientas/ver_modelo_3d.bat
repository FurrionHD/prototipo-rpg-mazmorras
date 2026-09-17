@echo off
REM Renderiza el modelo 3D de referencia (tools/modelos/) con la camara del juego en las 8 direcciones,
REM al lado de nuestro muñeco, y mide donde caen ojos y boca. Salida en tools/salida/modelo3d/.
REM
REM ABRE UNA VENTANA a proposito: en --headless no se dibuja nada. Se cierra sola al terminar.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_modelo_3d.tscn
