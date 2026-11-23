@echo off
rem LA TANDA DEL AGUANTE DE LOS ENEMIGOS (23/11/2026). Doble clic y a esperar. Cierra Chrome, Discord y Steam antes.
rem Grupos de 3 y de 4 (como se juega), pisos 1-60 (5 niveles), 6 pisos por nivel: 1, 4, 6, 7, 10 y 12 de cada uno
rem (el 6 y el 7 para ver si el salto va con el TIER del equipo, cada 6 pisos, o con el NIVEL, cada 12).
rem Aguante de vida por nivel x1 (hoy), x1,5, x1,7 y x1,9; defensa x1,1 (x1 en la de hoy).
rem Cada tanda entra sola en tools\resultados_simulador\simulador.db y deja su resumen en <tanda>_resumen.txt.
cd /d "%~dp0.."

echo === 1/4 VIDA x1 POR NIVEL, DEFENSA x1 ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --aguante-vida 1 --aguante-def 1 --tanda aguante_x1 > tools\resultados_simulador\aguante_x1_resumen.txt 2>&1

echo === 2/4 VIDA x1.5 POR NIVEL, DEFENSA x1.1 ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --aguante-vida 1.5 --aguante-def 1.1 --tanda aguante_x15 > tools\resultados_simulador\aguante_x15_resumen.txt 2>&1

echo === 3/4 VIDA x1.7 POR NIVEL, DEFENSA x1.1 ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --aguante-vida 1.7 --aguante-def 1.1 --tanda aguante_x17 > tools\resultados_simulador\aguante_x17_resumen.txt 2>&1

echo === 4/4 VIDA x1.9 POR NIVEL, DEFENSA x1.1 ===
python tools\simulador.py --pisos 1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60 --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --aguante-vida 1.9 --aguante-def 1.1 --tanda aguante_x19 > tools\resultados_simulador\aguante_x19_resumen.txt 2>&1

echo.
echo HECHO. Resumenes en tools\resultados_simulador\aguante_*_resumen.txt
python tools\simulador_bd.py
pause
