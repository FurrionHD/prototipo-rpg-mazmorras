# Arquitectura para un futuro multijugador

> Estado: **preparación (Fase 0)**. El multijugador **NO está implementado**. Este documento
> congela decisiones de diseño y deja registrado lo que falta por decidir, para poder abordarlo
> más adelante sin arrepentirnos de la arquitectura. En **un jugador el juego funciona igual que
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
| `COMBATE` | **No congela el mundo** | Mi pelea no puede parar al compañero ni a los spawns; se resuelve por-instancia. |
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

---

## Roadmap por fases (futuro, no ahora)

1. **(HECHO)** Costura de pausa + este documento.
2. Partir `Game` en estado por-jugador vs compartido vs mundo.
3. Desacoplar combate / extracción / recolección de la pausa global (por-instancia).
4. Cola de combate + reglas de unión / emboscada / ATB.
5. Throttling de spawns sin pausa.
6. Guardado autoritativo / sincronizado.
7. Lobby + transporte de red.
