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

### Unitarias (15/10/2026): la lógica pura, en milisegundos
```
python tools/pasar_pruebas.py --unitarias                                   # todas, por el lanzador
godot --headless --path . res://tools/prueba_unitarias.tscn                 # lo mismo, a mano
godot --headless --path . res://tools/prueba_unitarias.tscn -- stats bd     # solo los archivos con esas palabras
```
- Viven en `tools/unitarias/test_<tema>.gd`: `extends "res://tools/unitarias/caso.gd"` y funciones `test_<algo>()`
  con `cierto`, `igual`, `cerca` y `entre`. Las pasa todas `tools/unitarias/correr.gd` en UN solo Godot (el
  arranque son ~6 s; los tests, décimas). Un error de script dentro de un test se apunta como fallo de ese test y
  se sigue con el resto. Como `prueba_unitarias.tscn` es una prueba más, `--rapidas` y la batería entera ya la pasan.
- **Qué va en unitaria:** cuentas, tablas, conversiones (StatsMath, BDFilas, CombatFormas, ArenaCalculo,
  StatusEffects, Encargos...). Probar PROPIEDADES (paridad, topes, que crezca con la stat, ida y vuelta, casos
  límite), no números copiados del código: así un retoque de balance no rompe el test y un fallo de la fórmula sí.
- **Qué NO:** lo que cruza piezas (física, red, guardado real, una pelea entera). Eso sigue en `prueba_*.tscn`.
- **Índice archivo → prueba:** `python tools/indice_pruebas.py` rehace `tools/INDICE_PRUEBAS.md` (qué pruebas
  nombran cada script y cuáles no tiene ninguna). Mirarlo para saber qué pasar tras tocar un archivo.

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
- (13/10) REVISADAS TODAS LAS INESTABLES, una a una (repetidas solas y 4-6 a la vez, con `repetir`):
  - `prueba_bd_un_jugador`: era la PRUEBA. Fallo cuando las de BD iban 4 a la vez y se pisaban la ranura 97 (ya van
    de una en una, `va_sola`). 20/20 bien, tambien con el PC cargado.
  - `prueba_bd_ranura`: sobre todo la prueba (medir tiempo con otros procesos a la vez); ahora mide 3 veces y vale la
    mejor. Y un detalle DEL JUEGO: los trozos de 1000 materiales hacian que un paso del guardado continuo doblara su
    presupuesto (TROZO_CONTAR 1000 -> 300).
  - `prueba_zona_ajena`: fallo DEL JUEGO. El jugador estaba en el modo de movimiento de plataformas: un enemigo pegado
    por debajo contaba como suelo y al teletransportarse lo lanzaba contra la pared (~3 %). Ahora va FLOTANDO; lo
    vigila `prueba_jugador_no_monta` (con el modo viejo sale lanzado 214 px).
  - `prueba_insectos_tactico`: era la PRUEBA (medía el sitio libre con una raya apuntada a los pies; la del juego
    apunta al bulto con mejor_apunte y pasaba pegada a otro bicho de la prueba). 0/48 con 4 a la vez.
  - `prueba_retraso_barra` (paso 8, 15/10): fallo DEL JUEGO. La IA buscaba sitio fuera de tu area en 3 anillos al
    35/65/100 % de lo que anda, y segun la Agilidad de la tirada se saltaba la franja buena (un slime mas agil lo hacia
    PEOR). Ahora anillos cada 12 px (PASO_ANILLO). La prueba fija la agilidad a 36, que con lo viejo fallaba siempre.
  - `prueba_dot_del_golpe` (15/10): era la PRUEBA. Un critico con 60 % de armadura pegaba mas que un golpe normal sin
    ella; ahora fuerza sin criticos (y devuelve el critico y la esquiva al acabar). 16/16 con 4 a la vez.
  - `prueba_sala_steam` (15/10): 5 fallos SEGUIDOS (~95 s cada uno, el tunel de Steam se abre pero Ana no llega a entrar
    en el mundo) y despues 20 bien seguidas: apunta a un mal rato de la red de Steam (Valve), no al codigo. Si vuelve a
    fallar, guardar ANTES de repetir `%APPDATA%/DungeonOratoria/logs/prueba_sala_steam_S.log` (cada pasada lo pisa).
  - `prueba_town_trabajadores`: SIN REVISAR a proposito (los trabajadores se van a rehacer enteros).
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
