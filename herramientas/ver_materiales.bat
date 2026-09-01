@echo off
REM Doble clic aqui para ver como se ve en el mapa cada material que se recolecta: veta, carbon,
REM sal, arboles, plantas y huerto, con su familia, su sub-tier metido en la FORMA del dibujo y su
REM tinte real. Sirve para juzgar si el bruto, el veteado y el profundo se distinguen sin el color.
REM Teclas: ->/ESPACIO siguiente material, <- anterior, arriba/abajo cambiar de familia, ESC salir.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_materiales.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_materiales.tscn
