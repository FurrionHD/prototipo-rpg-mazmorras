@echo off
rem TANDAS DE LA NOCHE 23-24/11/2026 (cerrar el balance): jefes, pares, energia y recetas, con las tablas por escalon.
cd /d "%~dp0.."

echo === 1/14 JEFES con las tablas (pisos 1-60, solo el jefe) ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos-hasta 60 --grupos trio,cuatro --escenarios jefe --veces 4 --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_jefes > tools\resultados_simulador\noche_jefes_resumen.txt 2>&1

echo === 2/14 MUTANTES (y cada enemigo y jefe) solos, con las tablas ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos-hasta 60 --grupos trio --escenarios uno --veces 1 --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_uno > tools\resultados_simulador\noche_uno_resumen.txt 2>&1

echo === 3/14 ESCALONES PARES con menos daño ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos-hasta 60 --grupos trio,cuatro --escenarios piso --veces 4 --dano-tabla "1;0.85;1;0.62;0.8;0.42;0.7;0.38;0.6;0.28" --tanda noche_pares > tools\resultados_simulador\noche_pares_resumen.txt 2>&1

echo === 4/14 ENERGIA de las mejoras x1,2 por nivel ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos-hasta 60 --grupos trio,cuatro --escenarios piso --veces 4 --mejora-energia 1.2 --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_en12 > tools\resultados_simulador\noche_en12_resumen.txt 2>&1

echo === 5/14 ENERGIA de las mejoras al ritmo de la regeneracion del basico (+15 %% por nivel) ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos-hasta 60 --grupos trio,cuatro --escenarios piso --veces 4 --mejora-energia basico --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_enbas > tools\resultados_simulador\noche_enbas_resumen.txt 2>&1

echo === 6/14 ENERGIA: coste x1,4 y el basico repone al mismo ritmo ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos-hasta 60 --grupos trio,cuatro --escenarios piso --veces 4 --basico-energia mejoras --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_basrep > tools\resultados_simulador\noche_basrep_resumen.txt 2>&1

echo === 7/14 RECETAS nivel 2 a_s1 ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos 13,18,24 --grupos trio,cuatro --escenarios piso --veces 3 --receta a_s1 --armas daga,daga+daga,estoque,espada_corta,espada_corta+espada_corta,espada_larga+escudo_normal,mandobles,hacha_grande,maza_peq+escudo_normal,maza_peq,martillo_grande,arco,ballesta --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_rec_n2_a_s1 > tools\resultados_simulador\noche_rec_n2_a_s1_resumen.txt 2>&1

echo === 8/14 RECETAS nivel 2 b_s1 ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos 13,18,24 --grupos trio,cuatro --escenarios piso --veces 3 --receta b_s1 --armas daga,daga+daga,estoque,espada_corta,espada_corta+espada_corta,espada_larga+escudo_normal,mandobles,hacha_grande,maza_peq+escudo_normal,maza_peq,martillo_grande,arco,ballesta --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_rec_n2_b_s1 > tools\resultados_simulador\noche_rec_n2_b_s1_resumen.txt 2>&1

echo === 9/14 RECETAS niveles 3-5 a_s1 ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --receta a_s1 --armas daga,daga+daga,estoque,espada_corta,espada_corta+espada_corta,espada_larga+escudo_normal,mandobles,hacha_grande,maza_peq+escudo_normal,maza_peq,martillo_grande,arco,ballesta --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_rec_a_s1 > tools\resultados_simulador\noche_rec_a_s1_resumen.txt 2>&1

echo === 10/14 RECETAS niveles 3-5 a_s2 ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --receta a_s2 --armas daga,daga+daga,estoque,espada_corta,espada_corta+espada_corta,espada_larga+escudo_normal,mandobles,hacha_grande,maza_peq+escudo_normal,maza_peq,martillo_grande,arco,ballesta --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_rec_a_s2 > tools\resultados_simulador\noche_rec_a_s2_resumen.txt 2>&1

echo === 11/14 RECETAS niveles 3-5 a_mix ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --receta a_mix --armas daga,daga+daga,estoque,espada_corta,espada_corta+espada_corta,espada_larga+escudo_normal,mandobles,hacha_grande,maza_peq+escudo_normal,maza_peq,martillo_grande,arco,ballesta --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_rec_a_mix > tools\resultados_simulador\noche_rec_a_mix_resumen.txt 2>&1

echo === 12/14 RECETAS niveles 3-5 b_s1 ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --receta b_s1 --armas daga,daga+daga,estoque,espada_corta,espada_corta+espada_corta,espada_larga+escudo_normal,mandobles,hacha_grande,maza_peq+escudo_normal,maza_peq,martillo_grande,arco,ballesta --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_rec_b_s1 > tools\resultados_simulador\noche_rec_b_s1_resumen.txt 2>&1

echo === 13/14 RECETAS niveles 3-5 b_s2 ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --receta b_s2 --armas daga,daga+daga,estoque,espada_corta,espada_corta+espada_corta,espada_larga+escudo_normal,mandobles,hacha_grande,maza_peq+escudo_normal,maza_peq,martillo_grande,arco,ballesta --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_rec_b_s2 > tools\resultados_simulador\noche_rec_b_s2_resumen.txt 2>&1

echo === 14/14 RECETAS niveles 3-5 b_mix ===
python tools\simulador.py --reglas nuevas --mejoras 1 --aguante-tabla "1;1;6.32;3.2;13;8.52;34.4;18;79;43.9" --pisos 25,30,36,37,42,48,49,54,60 --grupos trio,cuatro --escenarios piso --veces 3 --receta b_mix --armas daga,daga+daga,estoque,espada_corta,espada_corta+espada_corta,espada_larga+escudo_normal,mandobles,hacha_grande,maza_peq+escudo_normal,maza_peq,martillo_grande,arco,ballesta --dano-tabla "1;1;1;0.75;0.8;0.5;0.7;0.45;0.6;0.33" --tanda noche_rec_b_mix > tools\resultados_simulador\noche_rec_b_mix_resumen.txt 2>&1

echo.
echo HECHO.
