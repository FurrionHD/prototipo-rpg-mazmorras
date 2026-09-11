@echo off
REM Doble clic aqui para ver los DIBUJOS DE LOS OBJETOS (minerales, lingotes, pieles, libros,
REM cristales...) en sus celdas de verdad, con los estados de calidad y la escala de cristales, y
REM debajo los mismos al tamano del SUELO. Guarda tools\salida\iconos.png y se cierra sola.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_iconos.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_iconos.tscn
