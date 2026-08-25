@echo off
REM Saca una hoja del personaje TAL CUAL SE VE JUGANDO: montado por capas y TEÑIDO.
REM La otra (ver_jugador.bat) enseña el horneado en gris; esta es la que caza los fallos de COLOR
REM -- el contorno comiendose los brazos, un tono que cruza el cuerpo, el tinte oscureciendo.
REM
REM   ver_jugador_juego.bat [animacion] [direcciones]
REM   ver_jugador_juego.bat walk          las ocho direcciones, un fotograma de cada una
REM   ver_jugador_juego.bat walk 1,2,3    esas tres, con sus ocho fotogramas
REM
REM ABRE UNA VENTANA a proposito: en --headless no se dibuja nada y la hoja saldria en negro.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0." res://tools/ver_jugador_juego.tscn -- %1 %2
