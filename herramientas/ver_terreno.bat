@echo off
REM Doble clic aqui para dibujar un trozo de mazmorra con TODAS las capas del terreno puestas
REM (suelo, muro, musgo, riachuelo, lago, columnas) y los recolectables encima, un juego por tramo,
REM mas la frontera entre dos tramos.
REM
REM Y lo que hay que mirar del LAGO:
REM   lago_zoom.png    la union del riachuelo con el lago, a zoom 6. Si ahi se ve una costura o una
REM                    orilla con espuma en medio del agua, esta mal.
REM   lago_formas.png  dieciseis lagos de dieciseis semillas. Un lago bonito no demuestra nada;
REM                    dieciseis dicen si la forma es organica o siempre sale la misma elipse.
REM Ademas imprime en la consola el barrido de 500 semillas (conexo, area, orilla). Si sale algun
REM FALLO, el PNG puede estar bien y el generador no.
REM
REM Guarda los PNG en tools\salida\ y se cierra solo.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot y ejecuta tools/ver_terreno.gd con Archivo ^> Ejecutar (Ctrl+Mayus+X^).
    pause
    exit /b 1
)
REM --script y no una escena: ver_terreno.gd es un SceneTree, no tiene .tscn.
"%GODOT%" --headless --path "%~dp0.." --script res://tools/ver_terreno.gd
pause
