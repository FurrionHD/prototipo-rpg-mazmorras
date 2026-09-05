@echo off
REM Doble clic aqui para dibujar los peces del charco y poder MIRARLOS. Cada PNG contesta una
REM pregunta distinta, y por eso son cinco:
REM
REM   peces_tabla.png       las cinco especies en todas sus tallas, sobre gris neutro.
REM                         ¿Se distingue un bagre de una lubina SIN leer el nombre?
REM   peces_en_el_agua.png  EL DECISIVO. El lago de verdad y encima cada especie con el mismo tinte
REM                         que le pone el juego. ¿Se lee la silueta A TRAVES del agua? Juzgarlos
REM                         sobre fondo blanco seria mirar el dato de al lado.
REM   peces_hoja_*.png      la hoja horneada cruda, a zoom 6: pixel a pixel.
REM   peces_giro.png        los frames por ocho rumbos, rotados como los rota el juego.
REM   peces_libro.png       la foto del libro de pesca, conocida y por descubrir.
REM
REM Y avisa por consola de las dos cosas que el ojo no ve: colas que se salen del lienzo y peces que
REM salen en trozos sueltos (un barbillon despegado del morro, una cola despegada del cuerpo).
REM
REM Guarda los PNG en tools\salida\ y se cierra solo.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/ver_peces.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." tools/ver_peces.tscn
pause
