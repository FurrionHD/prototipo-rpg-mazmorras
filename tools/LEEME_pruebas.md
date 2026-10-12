# Pruebas sin ventana (`tools/prueba_*.tscn`): cómo escribirlas para que no den falsas alarmas

## LA REGLA (12/10/2026): antes de cada commit, las pruebas

**Antes de cada commit o subida se pasan las pruebas y tienen que salir todas bien.** Y cada mecánica nueva entra
con su prueba (los mutantes nuevos, lo que venga): a partir de ahora, siempre.

```
python tools/pasar_pruebas.py --rapidas   # antes de CADA commit (sin las de red, ~6 min con 4 a la vez)
python tools/pasar_pruebas.py             # TODAS, también las de red de una en una: antes de juntar a main o hacer .exe
python tools/pasar_pruebas.py arena magia # solo las que lleven esas palabras en el nombre
python tools/pasar_pruebas.py --lista     # qué pasaría, con qué tope, sin lanzar nada
```

El lanzador busca solo todas las `prueba_*.tscn` (una prueba nueva no hay que apuntarla en ningún sitio), deja la
salida de cada una en `tools/resultados_pruebas/<nombre>.log` y dice BIEN / MAL / COLGADA / SIN MARCA.

- **Toda prueba nueva termina diciendo `FIN: TODO BIEN`** (o líneas `MAL: ...`) y sale con `quit(0)` / `quit(1)`.
  Sin marca sale como "SIN MARCA" y cuenta como no hecha.
- Si una prueba se lanza con algo especial (`-- nube_local`, dos fases con una variable de entorno, `--fixed-fps`),
  se apunta en `COMO_SE_LANZA` dentro de `pasar_pruebas.py`. Las que lanzan procesos (sala, trabajadores, otro
  jugador) van en `es_de_red`: se pasan de una en una.
- La **huella del combate** (`prueba_huella_combate`) compara con `tools/huellas/*.txt`. Si se cambia el combate a
  propósito, se vuelve a grabar (`-- grabar`) en el mismo commit; se regrabó el 12/10 (llevaba sin tocarse desde el
  15/09 y comparaba contra un combate de hace un mes).
- Inestable conocida (falla a veces sin que el juego cambie): `prueba_bd_un_jugador` (el fichero de la ranura a veces sigue cogido al borrarlo).
- Inestable conocida: `prueba_comer_cristales` (1 de cada 3-5 pasadas: "se lo come" o "animacion de transformacion"; visto el 12/10 tambien sin cambios).
  Si fallan, se repiten antes de dar nada por roto.

Se lanzan así (sin ventana, cada una dice `FIN: TODO BIEN` o lista sus `MAL:`):

```
godot --headless --path . res://tools/prueba_mut_profundo.tscn
```

El 07/10/2026 fallaban 7 pruebas y **ninguna era un fallo del juego**: o se habían quedado viejas tras un cambio,
o no tenían en cuenta una mecánica. Estas son las trampas que salieron, para no volver a caer.

## Cuando una prueba falla

1. Pásala con el código de antes (`git stash`, probar, `git stash pop`): ¿fallaba ya?
2. Repasa esta lista antes de tocar el juego.
3. Si cambias una mecánica (la barra, los charcos, las formas...), **actualiza sus pruebas en el mismo commit**.

## Las trampas

**El azar.** Ningún estado entra seguro: `StatusEffects.PROB_TECHO` es el 95 % aunque la ficha diga 1.0, y la
resistencia y la repetición del mismo estado restan más. Para mirar que una habilidad *mete* su estado:
`seed(4242)` justo antes de usarla (misma tirada en cada pasada). Si además quieres el estado seguro en la ficha,
duplícala (`ab.duplicate(true)`) y pon `prob = 1.0` en sus efectos.

**Esquivar.** Lo que se esquiva no hace nada (ni daño, ni estados, ni empujones; también las habilidades sin daño,
como el Eclipse). Para mirar lo que hace al entrar: puntería del enemigo a 5.0, o `evasion_bonus = -5.0` en los
tuyos. **Y devuélvelo al acabar** (guarda el valor antes).

**La pelea sigue corriendo.** Si no la paras, la barra avanza y al enemigo le llega SU turno en mitad de la prueba:
se mueve, empieza una carga o una habilidad que espera media barra, y lo que pruebas sale con su huella. Para
mirar una habilidad: `combat.set_process(false)`, mover el mapa a mano (`t.tick(get_process_delta_time())`) y
limpiar lo suyo (`t._cargas.erase(e)`, `t._presas_carga.erase(e)`, `e.charging = null`, `e.retrasando = false`).
Vuelve a `set_process(true)` al acabar si lo de detrás lo necesita.

**Fotogramas ≠ tiempo.** Sin ventana Godot hace los fotogramas muy deprisa: "120 fotogramas" puede ser 0,1 s y el
salto aún no ha llegado. Mide por reloj (`Time.get_ticks_msec()`) o con `create_timer`.

**Dónde colocar a la gente.**
- Los conos y líneas de un enemigo nacen en su **frente** (`forma_de` → `frente_dibujo`), no en sus pies: coloca
  respecto a `forma_de(...).origen`.
- Los saltos se paran donde se acaba el suelo de la pelea: pon a la presa **hacia dentro** de la zona (`t._en_arena`).
- Lejos significa lejos: los que no deben entrar, a 300-400 px.

**Cosas que han cambiado de forma.**
- **Charcos** (06/10): van por clave, varios por enemigo (`clave_charco`). No busques `t._charcos[e]`: busca
  `t._charcos.values()` con `ch["dueno"] == e`.
- **La barra** (06/10): las habilidades (menos el básico) esperan media barra con su huella pintada (clase CARGA). Un
  paquete de huellas puede llevar más de una.
- **Formas en bolas** (07/10): una LÍNEA con `ancho_fin = CombatFormas.BOLAS` es una fila de círculos.

**Lo que no es de la prueba.** Los avisos de Godot al cerrar (`ObjectDB instances leaked`, `resources still in use`,
`RID allocations leaked`) salen siempre y no significan nada.
