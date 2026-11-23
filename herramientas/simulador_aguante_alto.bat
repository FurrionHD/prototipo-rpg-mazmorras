@echo off
rem EL AGUANTE MAS ALTO (23/11/2026, el jefe: "tiene que crecer incluso con habilidades mejoradas"). Solo CON mejoras
rem (habilidades y magias x1,4 por nivel y el arbol del basico de verdad). Vida x2,2 / x2,5 / x2,8 / x3,2 por nivel con
rem defensa x1,1, y vida x2,5 con defensa x1,25. Mismos pisos y grupos que la tanda del aguante.
cd /d "%~dp0.."
set PISOS=1,4,6,7,10,12,13,16,18,19,22,24,25,28,30,31,34,36,37,40,42,43,46,48,49,52,54,55,58,60

echo === 1/5 VIDA x2.2, DEFENSA x1.1, CON MEJORAS ===
python tools\simulador.py --pisos %PISOS% --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 1 --aguante-vida 2.2 --aguante-def 1.1 --tanda aguante_x22_con > tools\resultados_simulador\aguante_x22_con_resumen.txt 2>&1

echo === 2/5 VIDA x2.5, DEFENSA x1.1, CON MEJORAS ===
python tools\simulador.py --pisos %PISOS% --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 1 --aguante-vida 2.5 --aguante-def 1.1 --tanda aguante_x25_con > tools\resultados_simulador\aguante_x25_con_resumen.txt 2>&1

echo === 3/5 VIDA x2.8, DEFENSA x1.1, CON MEJORAS ===
python tools\simulador.py --pisos %PISOS% --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 1 --aguante-vida 2.8 --aguante-def 1.1 --tanda aguante_x28_con > tools\resultados_simulador\aguante_x28_con_resumen.txt 2>&1

echo === 4/5 VIDA x3.2, DEFENSA x1.1, CON MEJORAS ===
python tools\simulador.py --pisos %PISOS% --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 1 --aguante-vida 3.2 --aguante-def 1.1 --tanda aguante_x32_con > tools\resultados_simulador\aguante_x32_con_resumen.txt 2>&1

echo === 5/5 VIDA x2.5, DEFENSA x1.25, CON MEJORAS ===
python tools\simulador.py --pisos %PISOS% --grupos trio,cuatro --escenarios piso --veces 4 --reglas nuevas --mejoras 1 --aguante-vida 2.5 --aguante-def 1.25 --tanda aguante_x25d_con > tools\resultados_simulador\aguante_x25d_con_resumen.txt 2>&1

echo.
echo HECHO.
