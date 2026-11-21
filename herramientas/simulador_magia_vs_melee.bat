@echo off
rem MAGIAS FRENTE A CUERPO A CUERPO CON MANA DE VERDAD (21/11/2026). Doble clic y a esperar; mejor cuando no uses el PC.
rem El mago gasta su mana (ya no se rellena contra los munecos) y lleva pociones de mana SIN FIN, pero no bebe otra hasta
rem que la anterior acaba de soltar su mana. Pisos 6, 12, 18, 24, 30 y 36; contra uno y en area (munecos juntos).
rem Cada tanda entra sola en tools\resultados_simulador\simulador.db y deja su resumen en <tanda>_resumen.txt.
rem Cuantos Godot a la vez lo decide solo segun la RAM libre (cierra Chrome, Discord y Steam antes).
cd /d "%~dp0.."

echo === 1/2 MAGOS: los 14 hechizos de dano, con mana real ===
python tools\simulador.py --pisos 6,12,18,24,30,36 --grupos solo_mago --escenarios muneco,munecos_juntos --magias todas --veces 2 --equipo fijo --reglas nuevas --mana real --tanda magia_real_21_11 > tools\resultados_simulador\magia_real_21_11_resumen.txt 2>&1

echo === 2/2 ARMAS: todas las manos, mismos pisos y munecos ===
python tools\simulador.py --pisos 6,12,18,24,30,36 --grupos solo_guerrero --escenarios muneco,munecos_juntos --armas todas --veces 1 --equipo fijo --reglas nuevas --tanda melee_real_21_11 > tools\resultados_simulador\melee_real_21_11_resumen.txt 2>&1

echo.
echo HECHO. Resumenes en tools\resultados_simulador\magia_real_21_11_resumen.txt y melee_real_21_11_resumen.txt
python tools\simulador_bd.py
pause
