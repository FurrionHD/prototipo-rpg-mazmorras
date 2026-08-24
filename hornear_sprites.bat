@echo off
REM Doble clic aqui DESPUES de tocar un generador de sprites (scripts/fx/*_sprites.gd) o
REM SpriteLienzo.UNIDADES_POR_CELDA. Vuelve a dibujar todos los enemigos y los deja como PNG en
REM assets/sprites/enemigos/, que es de donde el juego los carga.
REM
REM Si se olvida NO se rompe nada: el juego detecta que falta el horneado y dibuja al vuelo, solo
REM que pagando el rato de generarlo (~3 s la primera vez que sale cada bicho).
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/hornear_sprites.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0." res://tools/hornear_sprites.tscn
echo.
echo Ahora se importan los PNG nuevos...
"%GODOT%" --headless --path "%~dp0." --import
echo.
echo Listo.
pause
