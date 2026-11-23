@echo off
rem LAS RECETAS DEL ARBOL DEL BASICO (23/11/2026, la idea del jefe). Doble clic. Cierra Chrome, Discord y Steam.
rem Cada arma en el hueco del guerrero (grupo de 3 y de 4), con el arbol del basico DE VERDAD (mejoras=1) repartido
rem por RECETA: la exclusiva A o B y luego todo a la comun 1 (s1), todo a la comun 2 (s2) o mezcladas (mix);
rem la exclusiva no se sube. En los pisos 13-24 solo hay un punto (la exclusiva): ahi solo A y B.
rem AGUANTE: el que se elija con la tanda del aguante; cambialo aqui abajo (AGV vida, AGD defensa, por nivel).
cd /d "%~dp0.."
set AGV=1.5
set AGD=1.1
set ARMAS=daga,daga+daga,estoque,espada_corta,espada_corta+espada_corta,espada_larga+escudo_normal,mandobles,hacha_grande,maza_peq+escudo_normal,maza_peq,martillo_grande,arco,ballesta

echo === 1/8 NIVEL 2 (pisos 13,18,24), RECETA a_s1 ===
python tools\simulador.py --pisos 13,18,24 --grupos trio,cuatro --escenarios piso --veces 3 --reglas nuevas --mejoras 1 --receta a_s1 --armas %ARMAS% --aguante-vida %AGV% --aguante-def %AGD% --tanda recetas_n2_a_s1 > tools\resultados_simulador\recetas_n2_a_s1_resumen.txt 2>&1

echo === 2/8 NIVEL 2 (pisos 13,18,24), RECETA b_s1 ===
python tools\simulador.py --pisos 13,18,24 --grupos trio,cuatro --escenarios piso --veces 3 --reglas nuevas --mejoras 1 --receta b_s1 --armas %ARMAS% --aguante-vida %AGV% --aguante-def %AGD% --tanda recetas_n2_b_s1 > tools\resultados_simulador\recetas_n2_b_s1_resumen.txt 2>&1

echo === 3/8 NIVELES 3-5 (pisos 25,30,36,37,42,48,49,54,60), RECETA a_s1 ===
python tools\simulador.py --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --reglas nuevas --mejoras 1 --receta a_s1 --armas %ARMAS% --aguante-vida %AGV% --aguante-def %AGD% --tanda recetas_a_s1 > tools\resultados_simulador\recetas_a_s1_resumen.txt 2>&1

echo === 4/8 NIVELES 3-5 (pisos 25,30,36,37,42,48,49,54,60), RECETA a_s2 ===
python tools\simulador.py --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --reglas nuevas --mejoras 1 --receta a_s2 --armas %ARMAS% --aguante-vida %AGV% --aguante-def %AGD% --tanda recetas_a_s2 > tools\resultados_simulador\recetas_a_s2_resumen.txt 2>&1

echo === 5/8 NIVELES 3-5 (pisos 25,30,36,37,42,48,49,54,60), RECETA a_mix ===
python tools\simulador.py --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --reglas nuevas --mejoras 1 --receta a_mix --armas %ARMAS% --aguante-vida %AGV% --aguante-def %AGD% --tanda recetas_a_mix > tools\resultados_simulador\recetas_a_mix_resumen.txt 2>&1

echo === 6/8 NIVELES 3-5 (pisos 25,30,36,37,42,48,49,54,60), RECETA b_s1 ===
python tools\simulador.py --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --reglas nuevas --mejoras 1 --receta b_s1 --armas %ARMAS% --aguante-vida %AGV% --aguante-def %AGD% --tanda recetas_b_s1 > tools\resultados_simulador\recetas_b_s1_resumen.txt 2>&1

echo === 7/8 NIVELES 3-5 (pisos 25,30,36,37,42,48,49,54,60), RECETA b_s2 ===
python tools\simulador.py --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --reglas nuevas --mejoras 1 --receta b_s2 --armas %ARMAS% --aguante-vida %AGV% --aguante-def %AGD% --tanda recetas_b_s2 > tools\resultados_simulador\recetas_b_s2_resumen.txt 2>&1

echo === 8/8 NIVELES 3-5 (pisos 25,30,36,37,42,48,49,54,60), RECETA b_mix ===
python tools\simulador.py --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --reglas nuevas --mejoras 1 --receta b_mix --armas %ARMAS% --aguante-vida %AGV% --aguante-def %AGD% --tanda recetas_b_mix > tools\resultados_simulador\recetas_b_mix_resumen.txt 2>&1

echo.
echo HECHO. Resumenes en tools\resultados_simulador\recetas_*_resumen.txt
python tools\simulador_bd.py
pause
