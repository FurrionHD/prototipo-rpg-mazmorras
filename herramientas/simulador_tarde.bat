@echo off
rem LAS TANDAS GRANDES DEL SIMULADOR DE PELEAS (19/11/2026). Doble clic y a esperar (~4 horas con 10-12 Godot a la vez).
rem Cada tanda entra sola en tools\resultados_simulador\simulador.db y deja su resumen en <tanda>_resumen.txt.
rem Cuantos Godot a la vez lo decide solo segun la RAM libre (cierra Chrome, Discord y Steam antes).
rem Para comparar despues:  python tools\simulador_bd.py comparar <tanda1> <tanda2>
cd /d "%~dp0.."

echo === 1/3 ARMAS x ARMADURAS (las 33 combinaciones de manos x tela, cuero, hierro y placas; pisos 1-12) ===
python tools\simulador.py --grupos solo_guerrero --escenarios muneco,piso --armas todas --armaduras todas --veces 3 --tanda armas_armaduras > tools\resultados_simulador\armas_armaduras_resumen.txt 2>&1

echo === 2/3 SETS DE HABILIDADES (cada combinacion de 4, contra el muneco, pisos 3 6 9 12) ===
python tools\simulador.py --pisos 3,6,9,12 --grupos solo_guerrero --escenarios muneco --armas daga,daga+escudo_pequeno,estoque,espada_corta+escudo_normal,mandobles,arco --sets todos --veces 1 --tanda sets > tools\resultados_simulador\sets_resumen.txt 2>&1

echo === 3/3 GRUPOS (solo, duo, trio y cuatro contra todo: uno, corros del piso, manadas, jefes y mazmorra seguida) ===
python tools\simulador.py --grupos solo_guerrero,solo_mago,duo,trio,cuatro --escenarios uno,piso,manada,jefe,seguida --veces 5 --tanda grupos > tools\resultados_simulador\grupos_resumen.txt 2>&1

echo.
echo HECHO. Resumenes en tools\resultados_simulador\*_resumen.txt
python tools\simulador_bd.py
pause
