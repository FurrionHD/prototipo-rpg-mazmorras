# Arquitectura para un futuro multijugador

> Estado: **LAN jugable, en el hito 5 (combate)**. Hechos los hitos 1–4 (esqueleto andante,
> recogida replicada, menús/mazmorra compartida, hogar compartido), la **fase 5.1** (enemigos
> replicados) y la **5.2** (pisos independientes con autoridad por piso: cada uno anda por donde
> quiera y ve los mismos bichos) y la **5.3** (se PELEA: cualquiera, simule el piso o no, con
> peleas simultáneas, extracción y botín compartidos). Falta compartir UNA misma pelea entre dos
> humanos (5.4) y el guardado sincronizado (hito 6). En **un jugador el juego funciona igual que
> siempre**: el tiempo se pausa en los menús y en combate como hasta ahora.

## Por qué existe este documento

Hoy el juego se apoya en dos suposiciones que un multijugador rompe:

1. **Una única pausa global gobierna TODO el mundo** (`get_tree().paused`). La usan por igual los
   menús, el combate, la extracción de cristales y los minijuegos de recolección. En multi, un
   jugador abriendo un menú o entrando en combate congelaría a los demás — justo lo contrario de
   lo que queremos (que un compañero pueda meterse en mi pelea, o que un enemigo se una si hay
   hueco, mientras el otro sigue jugando).
2. **Todo el estado vive en un único singleton `Game`** (~6000 líneas) volcado a un único
   `SaveData` `.tres`. No hay separación entre "lo mío", "lo de mi compañero" y "lo compartido".

La regla que seguimos: **no refactorizar de verdad hacia la red antes de que exista netcode**
(evitar el YAGNI que adivina mal la arquitectura y rompe el modo un jugador). La Fase 0 hace solo
lo de bajo riesgo y alto valor: una **costura de pausa** ya implementada, y este documento.

---

## Fase 0 — YA HECHO: la costura de pausa

En `scripts/core/game.gd` se ha centralizado la pausa detrás de una **pila modal** que es la
única dueña de `get_tree().paused`:

- `enum Modal { MENU, PERSONAJE, COMBATE, EXTRACCION, RECOLECCION, SISTEMA }`
- `entrar_modal(tipo, fuente)` / `salir_modal(fuente)` / `fijar_modal(tipo, fuente, activo)`
  (idempotente, para menús `_set_open(bool)`) / `limpiar_modales()` (al cambiar de escena).
- `_refrescar_pausa()` es el **único** sitio que escribe `get_tree().paused`: pausa mientras la
  pila no esté vacía. En un jugador, comportamiento idéntico al anterior.

Todos los pausadores dispersos se enrutan por ahí: `abrir_menu`/`cerrar_menu` (token `MENU`),
`start_combat`/`_on_combat_finished` (`COMBATE`), extracción (`EXTRACCION`), minijuegos de
minar/talar/cosechar (`RECOLECCION`), y los menús que pausaban a mano — `character_menu`
(`PERSONAJE`), `keys_help` y `pause_menu` (`SISTEMA`).

**La etiqueta de tipo no cambia nada hoy** (todos pausan igual). Es metadato dormido: el día que
exista la red, `_refrescar_pausa()` es el único punto donde decidir qué pausas son **locales de
cada jugador** (`MENU`, `PERSONAJE`, `SISTEMA`) y cuáles **no deben congelar el mundo compartido**
(`COMBATE`, `EXTRACCION`, `RECOLECCION`).

---

## Mapa de estado: por-jugador vs compartido vs mundo

Derivado del código actual. Hoy TODO esto vive en el singleton `Game`; la tabla dice a qué
"dueño" pertenecería cada cosa en multi.

### POR JUGADOR (cada humano tiene lo suyo)
- Su `PersonajeData` líder + sus acompañantes (cada persona ya es un `Resource` autónomo y
  serializable — `scripts/core/personaje_data.gd`).
- **Bolsa** de expedición: `crystals`, `materiales` (lo que pesa).
- **Dinero personal**: `money` (ver decisión sobre el bote del hogar más abajo).
- Menú de personaje, y la extracción/recolección que esté haciendo (su modal local).
- Su posición en la mazmorra.

### COMPARTIDO (pueblo / hogar)
- **Baúl del hogar** `almacen_materiales` — ya está separado de la bolsa y es la **fuente única
  de todo el crafteo** (herrero, carpintero, boticaria, peletero). Candidato natural a almacén
  compartido. (`game.gd`, `guardar_materiales_en_hogar`.)
- **Plantilla** de personajes guardados (`plantilla`), oficios y contadores de crafteo.
- **NUEVO a crear**: un **cofre de armas/armaduras** compartido para traspasar equipo al
  compañero.
- **NUEVO a crear**: un **bote de dinero en el hogar** (ver decisión abajo).

### MUNDO / EXPEDICIÓN (autoritativo del host)
- Semilla del mundo, mazmorra persistente, spawns, mapa (`mapa_snapshot`, `mapa_trabajo`).

### ⚠️ Punto de fricción a vigilar
El equipo equipado de cada persona (`equipped_*` en `PersonajeData`) **comparte la MISMA
instancia por referencia** con el baúl de equipo poseído (`owned_*`) del grupo. Cómodo hoy (un
compañero se pone tu espada vieja sin duplicarla), pero **exige cuidado** si el inventario deja de
ser compartido entre jugadores: habría que decidir propiedad y evitar que dos humanos "compartan"
la misma instancia de arma.

---

## Clasificación de cada pausa en multi

| Modal | En multi | Motivo |
|---|---|---|
| `MENU`, `PERSONAJE`, `SISTEMA` | **Local** al jugador — **IMPLEMENTADO** | Con sesión activa `_refrescar_pausa()` no pausa el árbol; el `Player` corta su propio input consultando `Game.hay_modal()` (sigue emitiendo posición: el otro te ve quieto de pie). En solitario todo pausa como siempre. Nota asumida: en multi las pociones tiquean con el menú abierto. |
| `COMBATE` | **No congela el mundo** (pendiente 5.2) | Mi pelea no puede parar al compañero ni a los spawns; se resuelve por-instancia. En multi el árbol ya no se pausa, pero **falta throttlear los relojes de spawn**, que hoy se congelaban gratis con la pausa global. |
| `EXTRACCION` | **No congela, y es por-cuerpo** | Si yo extraigo un cadáver, el otro recibe "ocupado" en ESE cuerpo, pero el mundo sigue. |
| `RECOLECCION` | **No congela** | Igual que la extracción: minar/talar/cosechar es local a quien lo hace. |

---

## Decisiones de diseño (especificación acordada)

- **Dinero**: personal por jugador, PERO **depositable en el hogar** en un bote común del que el
  otro puede sacar y guardar (nuevo almacén compartido, análogo a `almacen_materiales`).
- **Inventario / bolsa**: separado por jugador.
- **Almacén del hogar**: materiales de crafteo **compartidos** (ya existe). Se añade un **cofre de
  armas/armaduras** compartido para pasarle equipo al compañero.
- **Equipo y menús de mejorar/reparar: POR JUGADOR** — cada uno ve y toca solo sus objetos y los
  de SUS acompañantes. Punto de contacto: reparar/mejorar consumen materiales del baúl COMPARTIDO
  del hogar (gastáis del mismo bote).
- **Bolsa y PESO de carga: POR JUGADOR (verificado)** — cada uno tiene su mochila equipada y su
  bolsa (`Game.materiales`, nunca sincronizada por `Net`); el tope de carga sale de la Fuerza de
  TU equipo, no de la del compañero. Inherente a que cada proceso corre su propio `Game`.
- **Hogar compartido IMPLEMENTADO (hito 4)**: baúl de materiales compartido con **candado de
  taller** (uno craftea a la vez; el otro ve "el taller está ocupado" — como las vetas); bote de
  dinero común; cofre de armas/armaduras (submenús Armas/Armaduras) que serializa la meta por
  instancia (tier/rareza/mejoras/durabilidad/capacidad); tienda con el surtido del host. Todo
  host-autoritativo con espejo en los clientes y refresco por `Net.hogar_cambiado`.
- **Surtido de la tienda: manda el mundo del HOST** (decidido). Si el host tiene la tienda T2
  abierta (Rey Slime muerto), ambos la ven y compran de ella, cada uno con su dinero; el progreso
  del invitado no cambia el surtido. Coherente con "el host es la autoridad del mundo". Se
  implementa en el hito 4.
- **Minerales del suelo**: los recoge **quien llega primero** (exclusión, ya modelada por
  `drop_pickup`). Si yo lo cojo, el otro no puede — pero puedo **soltarlo desde el inventario**
  para pasárselo (`soltar_item` ya existe).
- **Cadáver ocupado**: si uno está en el minijuego de extracción de un cuerpo, el otro recibe
  "ocupado" y no puede iniciar ESE cuerpo (el modal `EXTRACCION` pasa a ser por-cuerpo, no global).
- **Cupo de personajes en sesión (IMPLEMENTADO)**: máximo **4 personajes EN TOTAL** entre todos
  los humanos. 2 humanos → principal + 1 acompañante cada uno; 3 → host con 1 acompañante, el
  resto solos; 4 → todos solos. Los acompañantes que sobran se van **solos al hogar** al entrar
  gente y **vuelven solos** al irse gente o cerrar la sesión (`Net.cupo_party()` / `_aplicar_cupo`).
- **Personaje ORIGINAL intocable (IMPLEMENTADO)**: el que creaste al empezar la partida
  (`PersonajeData.es_original`) **nunca se saca del equipo** (ni en solitario) y en multi el cupo
  **siempre lo mantiene contigo**: si por posición quedara fuera, se **desliza** al último hueco
  permitido (pos 3 → 2 → 1). Los demás se apartan por orden desde abajo de la formación.
- **Formación en combate multi (DECIDIDO)**: el combate tiene 4 huecos y se llena por **ORDEN DE
  FORMACIÓN**, no por quién lidera en el mapa. Entra la **posición 1 de cada humano** presente;
  los huecos sobrantes se rellenan con las **posiciones 2 por orden de entrada al combate** (el
  que entró primero tiene prioridad): 2 humanos → pos 1+2 de cada uno; 3 → tres pos 1 + la pos 2
  del que entró PRIMERO; 4 → solo las cuatro pos 1. Da igual con qué personaje anduvieras por el
  mapa (1/2/3): al combate van los de ARRIBA de tu formación. Requisito acompañante: **reordenar
  tus personajes desde el menú de personaje** (qué número ocupa cada uno).
- **Altar**: cada jugador solo consolida/sube **su propio estado y el de SUS acompañantes**.
- **Subir de nivel: el crédito del guardián es DEL PERSONAJE que lo mató peleando** (regla del
  usuario). Que el host mate a un boss NO da crédito a los personajes del invitado: para subir de
  nivel, tu personaje tiene que haber participado en ESA pelea (los `guardianes_vencidos` viven en
  cada `PersonajeData` y así se quedan). Distinción clave: el **surtido de tienda** se abre con el
  progreso del MUNDO del host (la tienda es del pueblo), pero la **subida de nivel es del
  personaje** (la Excelia es tuya).
- **Combate — unirse y cola**: un compañero o un enemigo puede **unirse a una pelea EN CURSO si
  hay hueco** (tope actual `MAX_COMBATIENTES = 5`). Si no hay hueco, **queda en cola**. Hoy NO
  existe cola: el control es por exclusión (`_combat_triggered`) + pausa global; habrá que crear
  una cola real.
- **Combate con menú abierto (regla del usuario)**: como en multi el mundo no se para, un enemigo
  puede embestirte mientras miras el inventario. Al entrar en combate se te **cierra el menú a la
  fuerza PRIMERO** y luego arranca el combate — nunca pelear con un menú tapando la pantalla.
  Exigirá una convención "ciérrate" por menú (los que usan `abrir_menu` no registran su nodo en la
  pila, solo el token); se implementa junto al combate en multi, donde se puede probar.
- **Ventaja de ATB / emboscada**: quien **INICIA** el combate arranca con su adelanto de
  iniciativa (emboscada). Quien se **une a una pelea ya empezada NO cuenta como emboscada y entra
  con 0 % de adelanto** — la pelea ya estaba en marcha. (Anclar contra el ATB actual en
  `scripts/ui/combat.gd`.)
- **Spawns durante combate**: como en multi el tiempo **no se para**, hay que **reducir/pausar los
  relojes de spawn por zona mientras haya combate activo** para no saturar. Hoy esos relojes se
  congelan "gratis" gracias a la pausa global (`spawn_zone.gd`, aforo en `dungeon_floor.gd`); al
  quitar la pausa global hay que gestionarlo explícitamente.
- **Guardado sincronizado**: el **host guarda por los dos**; un único `SaveData` autoritativo. Hoy
  es `ResourceSaver` de un fichero local por ranura (`scripts/core/profile.gd`); habrá que hacerlo
  autoritativo/sincronizado.
- **Guardar en mazmorra CONGELA la expedición (decidido)**: guardar con gente dentro no la cierra,
  la congela ENTERA en el save del host, incluidas las **posiciones de cada invitado por su
  identidad**. Al retomar: el host aparece donde estaba (como en solitario) y el MISMO invitado,
  al cruzar la puerta de la mazmorra, **se materializa donde lo dejó** (p. ej. al lado del boss),
  no en la entrada. Un invitado distinto sin posición guardada entra por el piso 1. "El último en
  salir cierra" aplica a sesiones vivas: salir andando = cerrar; guardar y apagar = congelar.
- **La expedición congelada es de la MAZMORRA del host (decidido)**: si el host juega en solitario
  sin entrar a la mazmorra, la congelada sobrevive. Si el host **entra en solitario**, eso abre
  expedición NUEVA y la congelada se **descarta** (incluida la posición del invitado, que la
  próxima vez entra por el piso 1). El invitado nunca pierde lo SUYO (personaje/bolsa/Excelia,
  atado a su identidad): solo el sitio. Al implementar: **avisar antes de descartar** ("Hay una
  expedición congelada con la posición de X. Entrar la descarta. ¿Seguro?").
- **Mensajes de HUD locales**: los avisos que salen al recoger un objeto (y en general los
  toasts del HUD: recogida, subida de rango, etc.) deben mostrarse **solo al jugador que hizo la
  acción**, no a los dos. Hoy los dispara `hud.mostrar_recogida(...)` sobre el único HUD; en multi
  cada cliente tiene su HUD y el aviso NO debe replicarse por RPC a todos.
- **Mecánicas "vivas" del mapa son INDIVIDUALES por jugador**: la huida que entrena Agilidad
  (`_tick_huida()` en `scripts/actors/player/player.gd`, con su estado `_huida_perseguidor`,
  `_huida_record`, `_huida_acum`…), el sigilo/aguante ([[sigilo-aguante]]) y similares se calculan
  por separado para cada humano. Encaja de forma natural si **cada jugador controla su propio nodo
  `Player`** (ese estado ya vive en el nodo, no en el singleton) — punto a respetar al diseñar la
  replicación.
- **Huir del combate es INDIVIDUAL**: si yo huyo de una pelea, mi compañero (el otro jugador) que
  esté en ese mismo combate **sigue luchando contra el enemigo** — no huimos los dos por que uno
  huya. La huida saca del combate solo a quien la ejecuta; el combate continúa para el resto de
  participantes (y para los enemigos que siguen en él).

---

## Decisiones de red (acordadas para empezar)

- **Modelo de red**: **host-autoritativo** (uno hace de host+jugador, el otro de cliente), red de
  alto nivel de Godot sobre **ENet**. Para 2 jugadores no hace falta servidor dedicado.
- **Transporte / conexión**: **LAN primero** (misma red o LAN virtual tipo Hamachi / Tailscale /
  ZeroTier — todas fingen una LAN y saltan el NAT sin publicar nada ni port forwarding). El
  cliente conecta a la **IP del host** con un **código/contraseña de sala**. Internet directo
  (port forwarding) queda para más adelante.
- **Los jugadores pueden estar SEPARADOS**: cada uno con su propia cámara, en salas o pisos
  distintos (uno extrae mientras el otro pelea). Es la visión potente, pero **implica replicar
  todo el estado del mundo por red** (posiciones, enemigos, cadáveres, objetos del suelo): es el
  bloque de trabajo más grande.
- **Personaje del invitado**: entra con un **personaje NUEVO** la primera vez. Si vuelve a entrar
  **el mismo jugador**, carga el personaje que ya tenía guardado; si es un jugador **distinto**,
  se crea uno nuevo. → hace falta **persistir el personaje del invitado por identidad de jugador**
  (guardado por-invitado dentro de la partida del host, indexado por algún id estable del cliente).

## Preguntas ABIERTAS (aún por decidir)

- **Identidad del invitado**: ¿cómo se identifica "el mismo jugador" para recuperar su personaje?
  (id de máquina, nombre elegido en el lobby, etc.). Necesario para la persistencia de arriba.
- **Reparto de loot** y de XP/Excelia en un grupo mixto de dos humanos.

## Hitos de implementación (LAN, incremental)

Orden pensado para **depurar barato** (el combate va al FINAL, es lo más delicado):

1. **Esqueleto andante**: host abre partida, cliente conecta por IP+código, los dos aparecen en el
   mismo pueblo/piso y **se ven moverse**. Sin inventario ni combate. (Rompe el bloqueo gordo: el
   mundo pasa a soportar 2 presencias.)
2. **Recogida de objetos** replicada, con **mensaje de HUD solo para quien recoge** y exclusión
   (quien llega primero se lo lleva) + soltar para pasar.
3. **Extracción / recolección** por-instancia (modal local) + "ocupado" en un cuerpo/veta que ya
   trabaja el otro.
4. **Estado compartido de pueblo**: baúl de materiales, cofre de armas/armaduras, bote de dinero.
5. **Combate**: despausar el mundo, cola de refuerzos, unirse a media pelea, regla de emboscada/
   ATB, barras por-personaje, y que cada jugador **solo pueda accionar SUS personajes en su turno**.
6. **Guardado sincronizado** (host guarda por los dos) + persistencia del personaje del invitado.

### Hito 5 troceado (el combate es demasiado grande para un solo paso)

Visión del usuario para este hito: **cada jugador anda por el piso/sala que quiera y puede haber
varios combates A LA VEZ, hasta uno por jugador** (yo peleo con un bicho mientras mi compañero
pelea con otro en otra sala u otro piso), y **todos vemos los mismos enemigos en las mismas
posiciones**.

- **5.1 — Enemigos replicados (HECHO)**: quien simula un piso corre la IA/spawns de siempre y
  replica sus bichos; los demás los VEN moverse con cuerpos ligeros
  (`scripts/actors/enemy/remote_enemy.gd`). Sin combate todavía.
- **5.2 — Pisos independientes y autoridad por piso (HECHO)**: cada uno anda por el piso que
  quiera, las escaleras dejan de arrastrar a todos, y la simulación se reparte por piso.
- **5.3 — Todos pelean, con el mundo vivo (HECHO)**: se quita el tope temporal; pelea cualquiera,
  simule el piso o no, y la extracción y el botín son compartidos.
- **5.4 — Unirse a peleas en curso.** En tres pasos:
  - **A (HECHO)**: los **enemigos se unen** a una pelea en marcha, y si está llena **esperan
    pegados** y entran en cuanto muere uno.
  - **B (HECHO)**: los enemigos **van a por todos**, no solo a por quien simula el piso.
  - **C (HECHO)**: **dos humanos en UNA misma pelea** (5.3 da peleas simultáneas pero separadas),
    con el espejo al día, el grupo entero del que se une, magia enrutada, huida individual y
    traspaso de la pelea.

#### El espejo deja de ser "solo números" (cierre de 5.4-C)

El primer 5.4-C montaba el espejo UNA vez (`setup_espejo` con el roster del anfitrión) y a partir
de ahí solo le mandaba **números** (`instantanea()`: hp/mp/energía + turno + log). Todo lo que
cambiara la **composición** o el **estado** de la pelea después del montaje era invisible, y de ahí
salían tres bugs con la misma raíz. Lo que se hizo:

- **Los estados VIAJAN**. `_chips_de(c)` decide los chips (carga telegrafiada, provocación,
  imbuición, `statuses`) y los devuelve como pares `[texto, tooltip]`; van dentro de `_valores()`
  y el espejo los cachea en `_chips_espejo`. En el espejo los combatientes son maniquíes **sin
  motor de estados**: la única forma de que vea los debuffs de los demás es recibirlos resueltos.
  Un solo sitio decide y las dos pantallas pintan lo mismo.
- **Las ALTAS no caben en la instantánea**: es solo números y además va `unreliable`. Un
  combatiente nuevo (refuerzo, invocación del Rey Slime, compañero que se une) sube
  `combat._rev` y difunde el **roster entero** por canal FIABLE (`Net.difundir_roster` →
  `combat.aplicar_roster`). `aplicar_roster` **reconcilia por índice** en vez de reconstruir:
  conserva selección, log y marcadores, y reestrena el hueco de un cadáver comparando el nombre.
- **Autocuración**: la instantánea lleva `rev`; si al espejo no le cuadra, pide el roster una vez
  (`Net.pedir_roster_pelea`). Así un alta perdida no deja la pantalla desincronizada para siempre.
- **Muertos y KO** se apagan en el espejo (`_apagar_caidos`): allí no hay motor que lo haga.
- **El que se une entra con SU GRUPO**: `solicitar_unirse` manda la formación entera y el
  anfitrión mete dobles hasta llenar (`MAX_ALIADOS`). `_dobles[peer]` es un **Array**, y el
  desgaste vuelve **por índice** (`_mis_en_pelea` / `_mis_huecos`): cruzarlo mal le daría al
  acompañante la vida del líder.
- **Nombres duplicados**: dos personajes con el mismo nombre eran indistinguibles; se numeran
  (`Dasui`, `Dasui (2)`) sobre el **Combatant**, que es una copia de esa pelea — nunca sobre el
  `PersonajeData`.
- **Un enemigo entra por CUALQUIERA de los que están dentro**: si el alcanzado está espejando, sus
  ids se reenvían al anfitrión (`_refuerzos_para_mi_pelea`), que resuelve sus propios nodos
  (`_nodo_de_id`: reales si simula el piso, espejos si no), mete los que quepan y **devuelve** el
  resto. Y **reasigna la reserva** a su nombre: si no, una desconexión del alcanzado
  descongelaría (`_soltar_reservas_de`) bichos que se están peleando.
- **MAGIA enrutada**. Recitar son varios turnos con su examen de frases, así que no basta una
  acción suelta. La costura son `_mostrar_test` / `_mostrar_disparo`, por donde pasan tanto la
  primera frase como las siguientes: si el que recita es de otro, el anfitrión **sortea las
  opciones** y le pide la respuesta (`Net.pedir_frase` / `pedir_disparo`); el espejo pinta el mismo
  examen y devuelve el TEXTO elegido. **Quien valida es el anfitrión**: la frase correcta no sale
  de su máquina.
- **Los objetos los paga QUIEN los usa**: las bolsas son por jugador y no se sincronizan, así que
  el espejo gasta el consumible en local y el anfitrión resuelve el efecto sin cobrar.

#### La barra de acción y la huida individual

- **La barra de acción del espejo se movía sola... o más bien no se movía**. `_update_timeline()`
  pinta desde `_gauge`, y el ATB corre SOLO en el anfitrión: en el espejo los marcadores se
  quedaban clavados donde nacieron. No puede ir en la instantánea (esa sale solo cuando algo
  cambia, y la barra iría a saltos), así que va como las **posiciones de los enemigos**: tick
  propio a ~20 Hz (`ATB_TICK`, `_difundir_atb` → `Net.difundir_atb` → `aplicar_atb`),
  `unreliable_ordered` — si se pierde uno, el siguiente llega en 50 ms.
- **HUIR ES INDIVIDUAL** (regla del usuario, ahora implementada). Antes, huir llamaba a `_end` y
  cerraba la pelea **para todos**. Ahora, si el que escapa es el personaje de otro humano, se
  **retira** a él y a los suyos (`_huir_solo` / `_retirar_aliado`) y la pelea sigue.
  - ⚠️ **No se sacan de `_aliados`**: ese array se cruza por índice con `Game._active_player_pjs` y
    `combat_finished` devuelve por posición — moverlo le daría a uno la vida de otro. Se apartan en
    `_huidos`, y el filtro va en **`_aliados_vivos()`**, que es el embudo de a quién pegan los
    enemigos, quién recibe área, cuándo se pierde y quién cobra el maná de la victoria.
  - `Net.sacar_de_la_pelea(peer)` le devuelve lo suyo y le cierra **su** espejo, y lo saca de
    `_pelea_participantes`. Si con eso no queda nadie en pie, la pelea acaba como siempre.
  - ⚠️ A mitad de pelea la vida y el maná viven en el **Combatant**, no en la ficha (solo bajan al
    cerrar). Por eso el que huye pasa antes por `Game.volcar_desgaste_en_ficha()`, o se iría con la
    vida con la que entró.

#### ⚠️ UNA PANTALLA POR MÁQUINA (el cuelgue del playtest)

`Game.combate_activo()` es `not _active_enemies.is_empty()`, y **en un ESPEJO eso es `false`**: los
bichos los lleva la máquina que ejecuta la pelea. Como los guardias de "¿le abro una pelea?"
preguntaban por ahí, a alguien que estaba espejando **se le montaba OTRA pelea local encima**: se
le robaba la pantalla, y el anfitrión se quedaba **esperando para siempre** un turno suyo que ya
nunca iba a llegar (en la captura: una ventana peleando sola contra un Slime, y la otra parada en
"Turno de X. Esperando su acción...").

- `Game.hay_pelea_en_pantalla()` (`_active_layer != null`) es el predicado correcto para eso, y lo
  usan `enemy.gd` (espera de hueco) y `spawn_zone` (los partos también se alejan del que espeja:
  tampoco ve venir al que le nace al lado).
- `Game.start_combat` **rechaza** si ya hay una capa montada. Invariante duro, sin excepciones.
- Y al que le alcanza un bicho mientras espeja, ese bicho **se une a la pelea que está peleando**
  (`Net.refuerzo_a_mi_pelea`, que reserva el grupo y lo reenvía a su anfitrión) en vez de abrirle
  una nueva.
- Red de seguridad por si algo se cuela: antes de pedirle el turno a alguien se comprueba que
  **siga en la pelea** (`Net.esta_en_mi_pelea`); si no, sus personajes salen (`sacar_a`) y la pelea
  continúa en vez de colgarse.

Y un ruido que tapaba el log: `deserializar_equipo` hacía `load("")` por **cada ranura vacía de
cada ficha** que viaja por la red — decenas de `Resource file not found: res://` en rojo. Una
ranura vacía es normal, no un error: ahora se corta antes.

#### El TRASPASO de la pelea

La pelea la **ejecuta una máquina**. Si esa se va, la pelea ya no se cierra para todos: **se
traspasa** al primero que quede dentro y sigue donde estaba. Decisión del usuario, y es la misma
pieza que hacía falta para la caída de conexión, así que se construye una vez.

La clave para que esto no fuera un monstruo: **casi todo el `Combatant` es DERIVADO** (sale de la
ficha y el equipo, o del `EnemyData`). Así que el que la recoge la **reconstruye por el camino de
siempre** — `Game.start_combat` con los bichos + `unir_aliado_al_combate` con los de otros humanos —
y por la red solo viaja lo **volátil**, que es lo único que no se puede deducir:

- Por combatiente (`_volatil` / `_aplicar_volatil`): vida, maná, aguante, `provocar_turnos`,
  **estados**, cooldowns, carga telegrafiada e imbuición. Un `StatusEffects.Instance` es su **id de
  catálogo** + `turns/stacks/magnitude/mult_override/fresh`, así que serializarlo es barato y el
  traspaso sale **fiel**: no se pierden debuffs.
- De la pelea: barras de ATB, acciones lentas, guardias y **conjuros a medias** (`_casteos`), que se
  reanudan por la frase por la que iban.
- De los enemigos: su **`net_id`**, para que el que la recoge resuelva **sus** nodos con
  `_nodo_de_id` (reales si simula el piso, espejos si no). Los que murieron NO viajan: sus
  cadáveres los deja el que se va.

⚠️ **Los bichos traspasados NO se reanudan al cerrar la pantalla vieja**
(`Game.enemigos_traspasados`). Reanudarlos los devolvería al mundo en mitad de la pelea nueva, con
dos máquinas mandando sobre el mismo bicho. Y el que la recoge **reasigna las reservas** a su
nombre (`asumir_pelea` → `reasignar_reservas`).

**Caída BRUSCA de quien ejecuta**: ahí no hay traspaso posible — lo manda el que se va, y a este le
han cortado sin darle tiempo. Lo que sí se hace es no dejar la pantalla colgada esperando turnos que
no llegarán: `_anfitrion_perdido()` cierra el espejo y te devuelve al mapa (lo que vivieron tus
personajes en esa pelea se pierde, porque sus dobles se fueron con él). Al revés —**se cae uno que
estaba en MI pelea**— sus personajes salen de ella (`combat.sacar_a`), o la pelea esperaría para
siempre un turno suyo.

⚠️ **`Net.cerrar_pelea()` va DESPUÉS de volcar el resultado a las fichas** (en
`Game._on_combat_finished`). Es la que devuelve a cada humano lo que vivió su doble, y lo lee de la
ficha del doble: llamándola antes —como estaba— se les mandaba la vida y el maná **con los que
entraron**, y el que se unía salía de la pelea intacto.
- **5.5 — Huir individual + pulido.**

#### Unirse a una pelea en curso (5.4-A y 5.4-B)

**Enemigos que se unen.** `_invocar_slime` ya sabía meter un enemigo en una pelea en marcha (lo usa
el Rey Slime); se extrae su motor a `combat.anadir_enemigo()`. Diferencia clave: un refuerzo que
llega andando **NO** lleva la marca de `_slots_invocados`, porque es un enemigo de verdad — cuenta
como kill, da maná al morir y su cadáver es extraíble.

**Cola**: si la pelea está al tope (`MAX_ENEMIGOS`), el bicho se queda **esperando pegado** y lo
reintenta cada 0,4 s; al morir uno entra en su hueco. Matar no te alivia del todo: sabes que hay
más esperando fuera. Si la pelea acaba sin que entrara, vuelve a su vida normal.

⚠️ **La trampa del cruce por índice**: `combat._enemies` y `Game._active_enemies` se cruzan **por
posición** (así vuelven los muertos al cerrar). Reutilizar el hueco de un cadáver **desplaza** a su
nodo de la lista, y ese bicho no recibiría `morir()` ni `reanudar_tras_combate()` → congelado para
siempre, el bug de las estatuas otra vez. `Game.unir_enemigo_al_combate()` mantiene las dos listas
cuadradas y **mata en el momento** al nodo relevado.

**Los enemigos van a por todos.** `remote_player` deja de ser un fantasma visual y pasa a ser un
`CharacterBody2D` calcado de `companion.gd` (capa 4, máscara 1, cuerpo 32×32) dentro del grupo
`"aliado"`. **Con `velocity`**, que no es cosmética: el **oído** del enemigo sale de
`velocity.length()`, así que sin ella un jugador remoto sería completamente silencioso.

Si el alcanzado es el cuerpo de otro jugador, **la pelea es suya**: el dueño del piso reserva el
grupo (`_reservar_grupo`, compartido con la vía de "el jugador ataca") y se la **empuja con
emboscada** — le han saltado encima. Si ese jugador ya estaba peleando, los bichos **se unen a su
pelea**; el que no quepa se devuelve al dueño (`salir_de_pelea`) para que lo suelte.

⚠️ **El culling medía solo contra el jugador local**, así que los bichos alrededor de tu compañero
estaban dormidos y no lo perseguían nunca. Ahora se mide contra el **aliado más cercano**: quien
simula el piso lo simula para todos. (La niebla del mapa sigue siendo solo tuya: es tu libreta.)
Y ojo, `player._perseguidor` recorre `"aliado"` para la excelia de huida → **los remotos se
excluyen** por la meta `peer_id`, o entrenarías Agilidad porque persiguen a otro.

#### Cómo funciona el combate multi (5.3)

**Cada máquina juega SU pelea** (`_active_enemies` y compañía son singulares: una a la vez por
máquina, que es justo "una por jugador"). Lo que se reparte es la autoridad:

- **El espejo se volvió un enemigo de verdad**: el alta de red lleva la **ruta del `.tres`** del
  `EnemyData` y su `t` (`load()` cachea → misma instancia que en la máquina que lo simula), así que
  `remote_enemy` expone `data`/`current_t`/`hp_restante`/`es_boss` y entra en los grupos
  `enemy`/`corpse`. Con eso **se le pasa tal cual a `Game.start_combat`**, que lee esos campos con
  `in` y al cerrar llama `morir()`/`reanudar_tras_combate()`: **cero refactor de las 2700 líneas
  del combate**.
- **Reserva de pelea** (calcada del candado de vetas): al atacar un espejo se le pide la pelea a su
  dueño, que arma el grupo con `vecinos()` (el de siempre, con su tope `MAX_COMBATIENTES`), lo
  congela, lo apunta en `_enem_ocupados` y devuelve los ids. Al acabar se le devuelve el resultado
  (muerto / HP restante) y él lo aplica sobre los nodos reales. Nadie puede robarte un bicho:
  reservar pone `_combat_triggered` en el nodo real (así rebota hasta el propio dueño) y
  `_enem_ocupados` corta entre clientes.
- **Extracción**: mismo candado pero por cuerpo. Al terminar, el dueño consume el cadáver real y su
  baja despawnea los espejos de todos, así que nadie puede extraerlo dos veces.
- **Botín**: `Game._tirar_drop` era el único drop del juego que se plantaba en local saltándose
  `Net`; ahora sale por `Net.solicitar_soltar` y el suelo es el mismo para todos.
- Si alguien **se desconecta a media pelea**, el host difunde la baja y cada dueño suelta sus
  reservas (`reanudar_tras_combate`): si no, esos bichos quedarían congelados para siempre.

#### El mundo sigue vivo: lo que la pausa global tapaba

Quitar la pausa destapó dependencias que en un jugador no se veían. La peor **corrompía estado**:
`enemy._start_combat` marcaba `_combat_triggered` a todo el grupo **antes** de llamar a
`Game.start_combat`, que puede rechazar si ya hay una pelea — y nadie revertía el flag. Quedaban
**bichos estatua**: sin IA para siempre, ocupando aforo del piso y de la sala, sin dar loot ni
cristal. Ahora se pregunta `Game.combate_activo()` **antes** de congelar a nadie.

Además: el culling ya no re-enciende la física de los que están en combate; el aguante **no**
regenera dentro del combate (invalidaba "correr antes de pelear se paga"); se llama a
`reset_huida()` al salir (el mundo se movió mientras peleabas y el primer tick podía cobrar ese
salto como hueco abierto → excelia de Agilidad regalada); y `enemy_links` no recalcula O(n²) bajo
una pantalla que ni dibuja el mundo.

**Spawns durante el combate (decisión del usuario)**: NO se congelan los relojes — la mazmorra
sigue viva, que es la gracia del multi. Lo que se hace es **alejar los partos de quien está
peleando** (`DIST_MIN_PELEANDO` = 260 px frente a los 64 de siempre), porque plantarle un bicho en
las narices a alguien metido en una pantalla donde no puede verlo venir es injusto. De paso los
partos ya respetan a **todos** los jugadores del piso, no solo al local
(`Net.jugadores_remotos_aqui()` + `Net.avisar_combate()`).

#### Dueño de piso: cómo se reparte la simulación (5.2)

**El problema:** una máquina solo puede simular UN piso. `Game.current_floor` es un escalar global,
el grupo `dungeon_floor` es un singleton y los grupos `enemy`/`corpse`/`pickup` son **globales del
árbol** (`_vivos_en_el_piso()` contaría los bichos de dos pisos, `_guardar_estado()` volcaría los
del piso A dentro de `memoria_pisos[piso_B]`). Por eso se descartó "el host simula todos los pisos":
habría exigido romper todo eso.

**La solución:** cada piso tiene UN DUEÑO, que es quien lo simula y replica.
- `_dueno_piso` (`piso -> peer_id`, solo host) y `_soy_dueno` (en cada máquina). Los gates de
  `dungeon_floor` (`hay_sitio()`, `_colocar_boss()`, población/restauración) preguntan
  **`Net.simulo_mi_piso()`**, que en solitario es siempre `true`.
- **Estar solo en un piso = ser su dueño.** Si coincidís, manda uno y el otro espeja.
- El reparto se decide **antes** de reconstruir el piso: el viaje pasa por el host
  (`solicitar_piso` → `_conceder_piso` → `_viaje_ok`), que es justo quien necesita saberlo.
- **Escaleras individuales**: te mueven solo a ti (antes, hito 3b, `_cambiar_piso_todos` arrastraba
  a todos). Por la puerta del pueblo se entra **siempre al piso 1**; ya no hay "piso activo de la
  sesión" (`piso_actual` desapareció): el piso de cada cual vive en `_peers[id]["lugar"]`.

#### Memoria de piso de SESIÓN: volver a un piso lo encuentra igual

Como en un jugador: los mismos bichos y **cadáveres** (llevan tu cristal dentro).
- Se reutiliza la maquinaria que ya existía: `_guardar_estado()` / `_restaurar_estado()` y
  `crear_enemigo(data, pos, radio, t)`.
- Al abandonar un piso, el dueño manda su **foto** al host. Si queda alguien allí, ese la hereda
  (`_asumir_piso` → `dungeon_floor.adoptar_foto()`, traspaso fiel); si no queda nadie, el piso se
  **congela** en `Net._fotos_piso` hasta que alguien vuelva.
- La foto viaja con la **ruta del `.tres`** del `EnemyData` en vez del recurso (mismo truco que los
  materiales del suelo, `_item_a_dict`); `load()` cachea, así que la comparación de identidad del
  boss sigue valiendo. El `suelo` NO va en la foto: en sesión los drops los lleva Net.
- Vive en la **sesión (host)**, no en el save de nadie → las dos máquinas no divergen y el save del
  cliente sigue sin tocarse.

#### El canal de enemigos, y por qué el host retransmite

En `scripts/net/net.gd`, mismo patrón que los drops (`_suelo`/`_drops`):
- `_enemigos` (el dueño): `id -> {nodo, lugar, color, lado}`. Se registra en
  **`dungeon_floor.crear_enemigo()`**, la fábrica ÚNICA por la que pasan población inicial, goteo
  de partos, brotes, boss y restauración. La baja va en `enemy._exit_tree()` (cubre reciclado por
  aforo y desmontaje del piso).
- `_enem_nodos` (el que espeja): `id -> remote_enemy`.
- Alta/baja fiables, posiciones a **~20 Hz** en lotes `unreliable_ordered`, y `_pedir_enemigos`
  para el que llega o cambia de piso.
- **RETRANSMISIÓN**: en la topología estrella de Godot un cliente **no tiene socket con otro
  cliente**, así que si el dueño es un cliente sus bichos van cliente → HOST → los demás
  (`_rel_spawn` / `_rel_despawn` / `_rel_tick`, y `_pedir_roster` para pedirle la lista al dueño
  cliente). Si el dueño es el host, difunde directo. En LAN el salto extra son ~1-2 ms, nada al
  lado del tick de 20 Hz.
- Los **ids llevan dentro quién los creó** (`unique_id * 1e6 + n`): con varios dueños simulando a
  la vez, un contador suelto en cada máquina chocaría.
- Al cambiar de dueño, los que sigan en ese piso **tiran sus espejos** (`_limpiar_espejo`): el
  dueño nuevo recrea los bichos con ids nuevos y, sin esto, se verían por duplicado (se nota con
  3-4 jugadores).
- **Nada nuevo que persistir**: quien simula guarda como siempre; nadie guarda enemigos de otro.

**Pendiente conocido para el combate:** `hp_restante` (bicho herido al huir) no está en el formato
de `memoria_pisos`, y un cadáver espejado no es extraíble por quien no es el dueño (`remote_enemy`
no entra en el grupo `corpse`). En una **desconexión brusca** no da tiempo a sacar la foto: quien
herede ese piso lo recibe vacío y las paredes lo van repoblando.

---

## Roadmap por fases (futuro, no ahora)

1. **(HECHO)** Costura de pausa + este documento.
2. Partir `Game` en estado por-jugador vs compartido vs mundo.
3. Desacoplar combate / extracción / recolección de la pausa global (por-instancia).
4. Cola de combate + reglas de unión / emboscada / ATB.
5. Throttling de spawns sin pausa.
6. Guardado autoritativo / sincronizado.
7. Lobby + transporte de red.
