# Sonidos de ataque enemigo

Generados con IA a partir de los prompts de `sonidos_ataques.html`, ya **recortados y en mono**:
sin silencio de relleno, cortados a la duración del efecto en pantalla y con fundido de salida.

Los originales sin tocar están en `Descargas/sonidos para los ataques de los enemigos/`
(las subcarpetas por familia); estos salen de su carpeta `recortados/`.

## Cómo los busca el juego

Primero el de la **habilidad** y, si no existe, el de su **estilo**. Así el bramido del minotauro
suena distinto del chillido de la rata aunque compartan dibujo, y basta con tener el genérico de la
familia para que nada suene mudo.

**El nombre del fichero ES la clave**, y por eso importa:

- **Sonido propio de una habilidad**: `sfx_<nombre del .tres>.wav`.
  `resources/abilities/minotauro_bramido.tres` → `sfx_minotauro_bramido.wav`.
  Además hay que **apuntar la clave en `Sonido.CLAVES`** (`scripts/core/sonido.gd`), que es la
  lista que decide cuáles tienen sonido propio y la que da el índice que viaja por red. Se añade
  **al final**: reordenarla desincroniza el multijugador.
- **Genérico de familia**: `sfx_<estilo en minúsculas>.wav`, con el nombre del `CombatFX.Estilo`.
  `sfx_mordisco.wav`, `sfx_chillido.wav`, `sfx_caparazon.wav`. Estos no van en ninguna lista: se
  encuentran solos.

Quien lo reproduce es `Sonido` (autoload, `scripts/core/sonido.gd`), y quien lo dispara es
`CombatFX._process`, en el mismo frame en que da de alta el dibujo. Suenan por el bus **SFX**.

## Lo que falta

- **39 de los ficheros llevan sufijo `_vN`**: hay varias versiones y no se ha elegido cuál se queda.
  Al decidir, borrar las demás y **quitarle el `_vN`** al elegido.
  Mientras tanto hay un **puente temporal** en `sonido.gd`: si no encuentra `sfx_X.wav` prueba
  `sfx_X_v1.wav`, así que ya suena todo. **Ese puente se borra cuando estén elegidas** (está
  señalado con un comentario en `_stream`).
- **Los que más contenido perdieron al cortar** y conviene escuchar antes de darlos por buenos:
  `minotauro_pisoton`, `golem_machaca`, `escupitajo`, `yugular`, `aberracion_alarido`, `telarana`,
  `vortice_v3`, `bestia_carga`.
- **Estilos todavía mudos**: todo lo del jugador (MELEE, PROYECTIL, ARCANO, RAYO, CAIDA_RAYO,
  CAIDA_GOTA, ARCO, EXPLOSION), más SPLAT y MIRADA como genéricos. Los 61 de aquí son todos de
  ataque enemigo. Si arranca el juego en depuración, la consola avisa **una vez** por cada clave
  que no encuentra.
- `sfx_aura.wav` es una copia de `sfx_arrastre_v1.wav`, a falta de uno propio.
