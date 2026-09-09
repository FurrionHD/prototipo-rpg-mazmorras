@echo off
REM Doble clic aqui para ver EL DIBUJO DE UN HECHIZO sin tener que montar un combate: da de alta el
REM efecto en una CapaHechizos de verdad y saca capturas del vuelo y del impacto en tools\salida\.
REM
REM NECESITA VENTANA: con --headless no se dibuja nada y las capturas salen en negro.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_fx_hechizo.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_fx_hechizo.tscn
