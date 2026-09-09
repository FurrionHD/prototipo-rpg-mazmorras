@echo off
REM Saca una TIRA PNG con la vida de un fx_estilo, instante a instante, en tools/salida/.
REM Para JUZGAR el dibujo de un golpe; para ver el movimiento esta ver_enemigos_ataques.bat.
REM
REM   ver_fx.bat [estilo] [ancho] [dur]
REM   ver_fx.bat NUBE_ESPORAS
REM   ver_fx.bat MICELIO 120
REM
REM 'estilo' es el NOMBRE del valor de CombatFX.Estilo (da igual mayusculas) o su numero.
REM
REM SIN --headless a proposito: esto tiene que RENDERIZAR de verdad (los golpes se dibujan en un
REM _draw), y sin driver de video la captura sale negra. La ventana se cierra sola al terminar.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" (
    echo No encuentro Godot en:
    echo   %GODOT%
    pause
    exit /b 1
)
REM --quit-after ES UNA RED DE SEGURIDAD, no un limite: el script se cierra solo en cuanto guarda el
REM PNG (medio segundo), asi que esto no llega a usarse nunca cuando todo va bien. Esta para cuando
REM algo NO compila: entonces la escena no llega a su get_tree().quit(), la ventana se queda EN GRIS
REM para siempre y hay que matarla a mano. Con esto se cierra sola a los ~10 segundos.
"%GODOT%" --quit-after 600 --path "%~dp0.." res://tools/ver_fx.tscn -- %1 %2 %3
