@echo off
rem LA TANDA DEL AGUANTE DE LOS ENEMIGOS (23/11/2026). Doble clic y a esperar (~2 h a ojo). Cierra Chrome, Discord y Steam.
rem Grupos de 3 y de 4, pisos 1-60 (5 niveles), 6 pisos por nivel: 1, 4, 6, 7, 10 y 12 de cada uno (el 6 y el 7 para
rem ver si el salto va con el TIER del equipo, cada 6 pisos, o con el NIVEL, cada 12).
rem Cada aguante de vida por nivel (x1 = hoy, x1,5, x1,7, x1,9; defensa x1,1 salvo en el x1) SIN y CON las mejoras de
rem los arboles de mentira (habilidades y magias x1,4 por nivel; el basico sus pasos 115/120/140 %).
rem Cada tanda entra sola en tools\resultados_simulador\simulador.db y deja su resumen en <tanda>_resumen.txt.
cd /d "%~dp0.."

echo === 1/8 VIDA x1 POR NIVEL, DEFENSA x1, SIN MEJORAS ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 0 --aguante-vida 1 --aguante-def 1 --tanda aguante_x1_sin > tools\resultados_simulador\aguante_x1_sin_resumen.txt 2>&1

echo === 2/8 VIDA x1 POR NIVEL, DEFENSA x1, CON MEJORAS ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 1 --aguante-vida 1 --aguante-def 1 --tanda aguante_x1_con > tools\resultados_simulador\aguante_x1_con_resumen.txt 2>&1

echo === 3/8 VIDA x1.5 POR NIVEL, DEFENSA x1.1, SIN MEJORAS ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 0 --aguante-vida 1.5 --aguante-def 1.1 --tanda aguante_x15_sin > tools\resultados_simulador\aguante_x15_sin_resumen.txt 2>&1

echo === 4/8 VIDA x1.5 POR NIVEL, DEFENSA x1.1, CON MEJORAS ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 1 --aguante-vida 1.5 --aguante-def 1.1 --tanda aguante_x15_con > tools\resultados_simulador\aguante_x15_con_resumen.txt 2>&1

echo === 5/8 VIDA x1.7 POR NIVEL, DEFENSA x1.1, SIN MEJORAS ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 0 --aguante-vida 1.7 --aguante-def 1.1 --tanda aguante_x17_sin > tools\resultados_simulador\aguante_x17_sin_resumen.txt 2>&1

echo === 6/8 VIDA x1.7 POR NIVEL, DEFENSA x1.1, CON MEJORAS ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 1 --aguante-vida 1.7 --aguante-def 1.1 --tanda aguante_x17_con > tools\resultados_simulador\aguante_x17_con_resumen.txt 2>&1

echo === 7/8 VIDA x1.9 POR NIVEL, DEFENSA x1.1, SIN MEJORAS ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 0 --aguante-vida 1.9 --aguante-def 1.1 --tanda aguante_x19_sin > tools\resultados_simulador\aguante_x19_sin_resumen.txt 2>&1

echo === 8/8 VIDA x1.9 POR NIVEL, DEFENSA x1.1, CON MEJORAS ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 1 --aguante-vida 1.9 --aguante-def 1.1 --tanda aguante_x19_con > tools\resultados_simulador\aguante_x19_con_resumen.txt 2>&1

echo.
echo HECHO. Resumenes en tools\resultados_simulador\aguante_*_resumen.txt
python tools\simulador_bd.py
pause
