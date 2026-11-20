@echo off
rem LA TANDA DE LA TARDE DEL 20/11/2026 (SOLO REGLAS NUEVAS). Doble clic y a esperar (unas 6-8 horas en total).
rem Lo viejo ya esta en la BD (grupos36_hoy, grupos36_nuevas, sets, armas_armaduras): aqui solo lo nuevo, para comparar
rem sin repetir. Cada tanda entra sola en tools\resultados_simulador\simulador.db y deja su resumen en <tanda>_resumen.txt.
rem Cuantos Godot a la vez lo decide solo segun la RAM libre (cierra Chrome, Discord y Steam antes).
rem Lo importante primero: si se para antes, lo de arriba ya esta.
cd /d "%~dp0.."

echo === 0/5 BANCO (la bateria entera sobre este commit, antes de las tandas) ===
python tools\banco.py

echo === 1/5 GRUPOS, PISOS 1-36 (con todo lo del 20/11: fondo plano, defensa doble, energia, velocidades) ===
python tools\simulador.py --pisos-hasta 36 --grupos solo_guerrero,solo_mago,duo,trio,cuatro --escenarios uno,piso,jefe,seguida --veces 2 --reglas nuevas --tanda grupos36_20_11 > tools\resultados_simulador\grupos36_20_11_resumen.txt 2>&1
python tools\simulador_bd.py comparar grupos36_nuevas grupos36_20_11 > tools\resultados_simulador\comparar_grupos36_20_11.txt 2>&1

echo === 2/5 MAGOS: los 14 hechizos de dano solos (muneco, corro, juntos y piso) ===
python tools\simulador.py --grupos solo_mago --escenarios muneco,munecos,munecos_juntos,piso --magias todas --veces 2 --equipo fijo --reglas nuevas --tanda magos_20_11 > tools\resultados_simulador\magos_20_11_resumen.txt 2>&1

echo === 3/5 ARMAS contra los munecos (uno, corro y juntos; la armadura no cuenta: no pegan) ===
python tools\simulador.py --grupos solo_guerrero --escenarios muneco,munecos,munecos_juntos --armas todas --veces 1 --equipo fijo --reglas nuevas --tanda armas_munecos_20_11 > tools\resultados_simulador\armas_munecos_20_11_resumen.txt 2>&1

echo === 4/5 ARMAS x ARMADURAS en el piso (las 33 manos x tela, cuero, hierro y placas) ===
python tools\simulador.py --grupos solo_guerrero --escenarios piso --armas todas --armaduras todas --veces 3 --equipo fijo --reglas nuevas --tanda armas_armaduras_20_11 > tools\resultados_simulador\armas_armaduras_20_11_resumen.txt 2>&1
python tools\simulador_bd.py comparar armas_armaduras armas_armaduras_20_11 > tools\resultados_simulador\comparar_armas_armaduras_20_11.txt 2>&1

echo === 5/5 SETS DE HABILIDADES (cada combinacion de 4, contra el muneco, pisos 3 6 9 12) ===
python tools\simulador.py --pisos 3,6,9,12 --grupos solo_guerrero --escenarios muneco --armas daga,daga+escudo_pequeno,estoque,espada_corta+escudo_normal,mandobles,arco --sets todos --veces 1 --equipo fijo --reglas nuevas --tanda sets_20_11 > tools\resultados_simulador\sets_20_11_resumen.txt 2>&1
python tools\simulador_bd.py comparar sets sets_20_11 > tools\resultados_simulador\comparar_sets_20_11.txt 2>&1

echo.
echo HECHO. Resumenes en tools\resultados_simulador\*_20_11_resumen.txt
python tools\simulador_bd.py
pause
