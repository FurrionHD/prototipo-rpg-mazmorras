# Los gestos de ataque del jugador

Dos formas de verlos.

## 1. El VISOR, que es lo que quieres casi siempre

**Doble clic en `ver_gestos.bat`**, en la raíz del proyecto. Y ya.

Desde el editor de Godot es igual de rápido: abre `dev_gestos.tscn` y pulsa **F6** (*ejecutar la
escena actual*). Con F5 arrancaría el juego entero, que no es lo que quieres aquí.

Los lanza **en movimiento**, en bucle, cada repetición sobre un muñeco distinto, y tres veces
seguidas cada uno para que dé tiempo a mirarlos.

| tecla | |
|---|---|
| `ESPACIO` / `→` | el siguiente gesto |
| `←` | el anterior |
| `1`..`5` | imbuición: acero, veneno, fuego, agua, rayo |
| `P` | parar / seguir el bucle |
| `R` | repetir el de ahora |
| `+` / `-` | más lento / más rápido |
| `F12` | guardar una captura |
| `ESC` | salir |

Los que alcanzan a varios (Molinete, Grito de guerra, Segar) salen contra la fila entera, y los que
van sobre uno mismo (Filo emponzoñado, En guardia, Voto de guardia, Voz de mando) sobre el muñeco
de abajo, que es el que ataca.

## 2. Las hojas de contactos

Cuatro instantes de cada gesto, una hoja por arma:

- `gestos_1_daga.png`
- `gestos_2_estoque.png`
- `gestos_3_espada_corta.png`
- `gestos_4_espada_larga.png`
- `gestos_5_mandobles.png`
- `gestos_6_imbuiciones.png` — los mismos gestos con acero, veneno, fuego, agua y rayo

Se regeneran con el visor (`F12`) o volviendo a escribir el generador; son capturas, no hay que
mantenerlas al día salvo que cambie un gesto.
