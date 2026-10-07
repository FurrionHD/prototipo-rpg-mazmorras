# Pruebas sin ventana (`tools/prueba_*.tscn`): cómo escribirlas para que no den falsas alarmas

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
