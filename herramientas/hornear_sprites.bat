@echo off
REM Doble clic aqui DESPUES de tocar un generador de sprites (scripts/fx/*_sprites.gd, las hojas 3D de
REM tools/sprites_sdf) o SpriteLienzo.UNIDADES_POR_CELDA. Vuelve a dibujar lo que elijas y lo deja como PNG en
REM assets/sprites/..., que es de donde el juego lo carga.
REM
REM PREGUNTA QUE HORNEAR (05/10): antes lo horneaba todo siempre y casi todo el rato se lo comia el personaje.
REM Tambien se puede pasar la eleccion como argumento sin menu: hornear_sprites.bat enemigos
REM (o varias: hornear_sprites.bat terreno,props). Lo que sobre de cada parte horneada se borra solo.
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

set HORNO_SOLO=%~1
if not "%HORNO_SOLO%"=="" goto hornear

echo Que quieres hornear?
echo   1. Enemigos              (lo normal tras tocar un enemigo; un par de minutos)
echo   2. Personaje             (cuerpo, pelo, ropa, armas: lo que mas tarda)
echo   3. Mundo                 (terreno, recolectables, props y peces)
echo   4. Iconos de objetos
echo   5. TODO                  (tras tocar algo general, como el tamano del pixel)
choice /c 12345 /n /m "Elige 1-5: "
if errorlevel 5 set HORNO_SOLO=& goto hornear
if errorlevel 4 set HORNO_SOLO=iconos& goto hornear
if errorlevel 3 set HORNO_SOLO=terreno,recolectables,props,peces& goto hornear
if errorlevel 2 set HORNO_SOLO=jugador& goto hornear
set HORNO_SOLO=enemigos

:hornear
if "%HORNO_SOLO%"=="" (echo Horneando TODO...) else (echo Horneando: %HORNO_SOLO%)
"%GODOT%" --headless --path "%~dp0.." res://tools/hornear_sprites.tscn
echo.
echo Ahora se importan los PNG nuevos...
"%GODOT%" --headless --path "%~dp0.." --import
echo.
echo Listo.
pause
