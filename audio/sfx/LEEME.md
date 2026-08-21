# Sonidos de ataque enemigo

Generados con IA a partir de los prompts de `sonidos_ataques.html`, ya **recortados y en mono**:
sin silencio de relleno, cortados a la duración del efecto en pantalla y con fundido de salida.

Los originales sin tocar están en `Descargas/sonidos para los ataques de los enemigos/`
(las subcarpetas por familia); estos salen de su carpeta `recortados/`.

## Lo que falta

- **39 de los 61 llevan sufijo `_vN`**: hay varias versiones y no se ha elegido cuál se queda.
  Al decidir, borrar las demás y **quitarle el `_vN`** al elegido — el nombre sin sufijo es el
  que busca el juego.
- **Falta `sfx_aura.wav`** (el slime de fuego prendiéndose). Se va a usar una copia de
  `sfx_arrastre_v1.wav`, que es el que más cuerpo tiene.
- **Los que más contenido perdieron al cortar** y conviene escuchar antes de darlos por buenos:
  `pisoton_atronador`, `machaca`, `escupitajo`, `yugular`, `alarido`, `telarana`, `vortice_v3`,
  `carga_acorazada`.

## Cómo los va a buscar el juego

Primero el de la habilidad y, si no existe, el de su estilo. Así `sfx_bramido.wav` puede sonar
distinto de `sfx_chillido.wav` aunque compartan dibujo, y basta con tener el genérico de la
familia para que nada suene mudo.

**El sistema de audio NO está montado todavía**: no hay bus, ni reproductor, ni llamada desde
`CombatFX`. Estos ficheros están aquí esperando.
