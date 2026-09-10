@echo off
REM Doble clic aqui para ver LOS SEIS AMAGOS DEL GACHA seguidos.
REM
REM El amago es el "fakeout" y pasa AL VOLTEAR LA CARTA: sale con la cara del comun, se queda asi el
REM rato justo para que te la creas, y entonces revienta en blanco y sale la de verdad. En el juego
REM cae en el 22% de las tandas de epico o mejor, asi que verlo a base de tirar seria cosa de veinte
REM tiradas por cada combinacion.
REM
REM Son SEIS porque solo hay amago de epico para arriba y se finge el suelo que el jugador YA SABE:
REM el comun de normal, o el garantizado si esa tanda traia pity.
REM
REM Va a 0,6x a proposito -- a velocidad real el fogonazo dura tres fotogramas y lo unico que puedes
REM decir de el es "algo ha pasado". Con + lo subes a la de verdad para juzgar el RITMO, que es otra
REM pregunta. Los tiempos salen de maestro_menu, asi que esto no se queda desfasado si cambian alli.
REM
REM Y ver_ritual.bat sigue siendo el de la animacion previa (el maestro y la estanteria).
REM
REM TECLAS
REM   ESPACIO   repetir el de ahora
REM   FLECHAS   cual de los seis
REM   S         fijar este y que no pase al siguiente
REM   P         pausa
REM   + / -     mas rapido / mas lento
REM   ESC       salir
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    echo Abre el proyecto en Godot, selecciona tools/visores/dev_amagos.tscn y pulsa F6.
    pause
    exit /b 1
)
"%GODOT%" --path "%~dp0.." res://tools/visores/dev_amagos.tscn
