# Los sonidos del juego

Tres carpetas y tres sistemas, todos alimentados por **un solo guión**:

```
python tools/audio/preparar_sonidos.py            # todo
python tools/audio/preparar_sonidos.py --solo-sfx # sin recodificar la música (minutos vs segundos)
```

| Carpeta | Qué es | Quién la lee |
|---|---|---|
| `audio/sfx/` | los golpes (154 wav mono) | `Sonido` (`scripts/core/sonido.gd`) |
| `audio/ambiente/` | bucles del sitio + ruidos sueltos | `Ambiente` (`scripts/core/ambiente.gd`) |
| `audio/musica/<contexto>/` | 24 pistas en 9 contextos | `Musica` (`scripts/core/musica.gd`) |

**Los originales sin tocar están en `Descargas/`** (`sonidos para los ataques de los enemigos`,
`sonidos para los ataques de los personajes`, `Sonidos ambiente`, `Musicas`). Se editan ahí y se
vuelve a lanzar el guión: lo de aquí se rehace entero y es idempotente.

## Cómo los busca el juego

Primero el de la **habilidad** y, si no existe, el de su **estilo**. Así el bramido del minotauro
suena distinto del chillido de la rata aunque compartan dibujo, y basta con tener el genérico de la
familia para que nada suene mudo.

**El nombre del fichero ES la clave**:

- **Sonido propio de una habilidad**: `sfx_<nombre del .tres>.wav`.
  `resources/abilities/minotauro_bramido.tres` → `sfx_minotauro_bramido.wav`.
  Además hay que **apuntar la clave en `Sonido.CLAVES`**, que es la lista que decide cuáles tienen
  sonido propio y la que da el índice que viaja por red. Se añade **al final**: reordenarla
  desincroniza el multijugador.
- **Genérico de familia o de arma**: `sfx_<estilo en minúsculas>.wav`, con el nombre del
  `CombatFX.Estilo`. `sfx_mordisco.wav`, `sfx_espada_tajo.wav`, `sfx_grito_guerra.wav`. Estos no
  van en ninguna lista: se encuentran solos. **Todas las habilidades del jugador van por aquí**,
  porque cada una tiene su estilo propio.
- **Capa de elemento**: `sfx_elem_<fuego|agua|rayo>.wav`. No sustituye al golpe: suena **encima**,
  6 dB por debajo, cuando el arma va imbuida (ver `Sonido.ELEMENTOS`).

## Varias versiones de lo mismo

Una clave puede tener **varias versiones**: `sfx_X_v1.wav`, `_v2`, `_v3`... y se sortea una en cada
disparo. Con una sola, se llama `sfx_X.wav` a secas. Es lo que hace que el Grito de guerra no suene
calcado las tres veces que lo lanzas en una pelea. Hoy hay 18 claves con varias.

**El sorteo NO es local.** La versión y la pizca de tono salen de una **semilla** que tira el
anfitrión al resolver el golpe y que viaja en el paquete de impactos (quinto entero, ver
`combat._apuntar_impacto_red`). Sin eso, el mismo mandoble sonaría distinto en cada pantalla.

## El volumen: tres pasos, en este orden

1. **Realce de graves** (`REALCE`, solo para los pisotones y mazazos). Medidos, esos golpes tienen
   el **97-100 % de su energía por debajo de 500 Hz**: son retumbe puro, y un altavoz de portátil
   no baja de ~150 Hz. Por eso el Pisotón atronador "no se escuchaba nada" — no le faltaba nivel,
   le faltaba una frecuencia que el altavoz no sabe dar. Se les fabrica el armónico que falta
   (paso-bajo → saturación → paso-alto de **seis polos**) y el oído reconstruye el grave a partir
   de él. Sube del 1,7 % al 12 % de energía audible. Con un solo polo no servía de nada: el
   fundamental seguía mandando.
2. **Igualar** (`igualar`). Se mide la sonoridad **ponderada K** (norma EBU R128 / ITU-R BS.1770),
   no el RMS pelado. Esto no es un detalle fino: en RMS, el martillo grande medía *exactamente*
   igual que un espadazo y se oía a la mitad, porque el oído es mucho menos sensible a los graves
   a igual energía.
3. **La mezcla a mano** (`GANANCIAS`). Igualar deja todo al mismo nivel, y eso no es lo que se
   quiere para todo: un pisotón de jefe tiene que pesar más que un mordisco de rata. Aquí van esos
   dB de decisión artística, aplicados con **limitador** para que subir 7 dB no sature.

La música y los bucles largos se igualan con `loudnorm` de ffmpeg (EBU R128), a -16 LUFS la música
y -22 el ambiente.

**No editar un .wav de aquí a mano**: lo pisa el siguiente `preparar_sonidos.py`. Se edita el
original de `Descargas` y se vuelve a lanzar. **Los 61 de enemigos también se regeneran** desde
`Descargas/sonidos para los ataques de los enemigos/recortados/` (con su tabla de renombres): sin
eso, el realce de graves se aplicaba encima del resultado de la pasada anterior y se iba
acumulando.

## Sonido fuera del combate

También suenan en el mapa:

- **Tu espadazo**, aunque no le des a nada (`player._tick_ataque`). El gesto sale del arma de la
  mano que pega, por la misma tabla `CombatFX.FX_ARMA` que usa el combate.
- **La embestida del enemigo**, antes de que se abra la pelea (`enemy._iniciar_impacto`), con su
  `EnemyData.fx_basico`.
- **El ambiente**: bucle de la mazmorra o del pueblo, ruidos sueltos cada 12-30 s, y bucles
  posicionales pegados al charco y al farolillo que llevas.

## Lo que falta

- **`sfx_mirada.wav` es el único estilo mudo** de los 102, y hoy no se nota: los dos que usan
  MIRADA (gárgola y aberración) tienen su propio fichero de habilidad. Un enemigo nuevo con ese
  estilo y sin clave propia sí saldría mudo.
- **`sfx_elem_veneno.wav` está sin usar**: el veneno no es un elemento, es un estado
  (ver `elements.gd`), así que no entra en `Sonido.ELEMENTOS`.
- **Dos mapeos por confirmar de oído** (el prompt del fichero venía cortado y son intercambiables):
  `cambio_ritmo` ↔ `senalar_hueco`, y `martillo_en_alto` ↔ `martillo_guerra`. Si suenan al revés,
  se cambian en el manifiesto del guión y se vuelve a lanzar.
- **El golpe en el mapa no viaja por red**: en multijugador oyes tu espadazo y el del bicho que
  simulas, pero no el del compañero que pega a tu lado (los `remote_player` no replican el gesto).
- **`sfx_aura.wav` es una copia de `sfx_arrastre_v1.wav`**, a falta de uno propio.
