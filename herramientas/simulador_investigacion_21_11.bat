@echo off
rem LA INVESTIGACION DEL 21/11/2026 (memoria magias-valoracion-21-11): lo que se guarda al subir de nivel.
rem   A) magia_suma: el mago guarda como el guerrero (suma con el baston). Magos y armas contra los munecos, pisos 6-36.
rem   B) El jugador que NO va al estandar: sube de nivel con 600, 750 o 900 de stats, con lo guardado tal cual y
rem      con lo guardado suavizado por encima de 600 (bakeo_suave). Contra los corros del piso y el jefe.
rem Cada tanda entra sola en tools\resultados_simulador\simulador.db y deja su resumen en <tanda>_resumen.txt.
cd /d "%~dp0.."
set R=tools\resultados_simulador
set COMUN=--reglas nuevas --magia-suma 1

echo === A1 MAGOS con magia_suma, mana real ===
python tools\simulador.py --pisos 6,12,18,24,30,36 --grupos solo_mago --escenarios muneco,munecos_juntos --magias todas --veces 2 --equipo fijo --mana real %COMUN% --tanda inv_magos_suma > %R%\inv_magos_suma_resumen.txt 2>&1

echo === B LOS SEIS JUGADORES (600/750/900, sin y con suavizado) en el piso y el jefe ===
for %%S in (600 750 900) do (
  python tools\simulador.py --pisos 6,12,13,18,24,25,30,36 --grupos solo_guerrero,solo_mago,cuatro --escenarios piso,jefe --veces 10 --stats-nivel %%S %COMUN% --tanda inv_s%%S > %R%\inv_s%%S_resumen.txt 2>&1
  python tools\simulador.py --pisos 6,12,13,18,24,25,30,36 --grupos solo_guerrero,solo_mago,cuatro --escenarios piso,jefe --veces 10 --stats-nivel %%S --bakeo-suave 600 %COMUN% --tanda inv_s%%S_suave > %R%\inv_s%%S_suave_resumen.txt 2>&1
)

echo.
echo HECHO.
python tools\simulador_bd.py
pause
