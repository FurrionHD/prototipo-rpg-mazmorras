@echo off
REM Abre la pantalla de CREACION DE PERSONAJE sola y saca una captura de cada fase,
REM en tools/salida/. Necesita ventana: con --headless las capturas salen negras.
REM
REM   ver_creador.bat          el creador de PERSONAJE (cuatro fases + vista previa)
REM   ver_creador.bat mundo    el modo simple, el de bautizar un mundo compartido
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0." res://tools/ver_creador.tscn -- %1
