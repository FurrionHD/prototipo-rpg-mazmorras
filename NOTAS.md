# NOTAS del proyecto — Prototipo RPG de Mazmorras

Bitácora del proyecto para no perder contexto entre sesiones.
RPG 2D **top-down** (cenital) de exploración de mazmorras con economía simple.
Motor: **Godot 4.7** (GDScript), renderizador **GL Compatibility**.

**Modelo de juego:** exploración libre (tiempo real) + **combate por turnos**.
- Mundo de exploración: caminas libre por la mazmorra, abres cofres, topas enemigos.
- Mundo de combate: al chocar con un enemigo se entra en una pantalla de combate
  por turnos (estilo JRPG/Pokémon); al ganar vuelves a la mazmorra con el loot.

---

## Estado actual

- Proyecto Godot base creado, renderizador GL Compatibility.
- Git en rama `main`, conectado a GitHub (repo: prototipo-rpg-mazmorras).
  - `.gitignore` correcto: `.godot/` (caché) NO se sube. Solo `project.godot` trackeado.
  - Identidad LOCAL de git (FurrionHD). NO tocar la config global.
- Existe `scripts/player.gd` (movimiento, pendiente de reubicar y de montar su escena).
- **Aún NO empezada la Fase 1** formalmente (sin escenas, sin input map).

## Seguimiento en Jira

- Proyecto Jira (Kanban): `KAN` en https://dasuixd77.atlassian.net (board 2).
- Estructura: cada **Epic = fase** del roadmap; **Tareas** anidadas dentro;
  los bugs se crean como tipo "Error".
- Claude puede gestionar el tablero por la API REST de Jira si se le da un
  API token (se guarda FUERA del repo, nunca en git).
- `NOTAS.md` sigue siendo la fuente principal; Jira es la vista de tablero.

## Flujo de trabajo

- Claude (en VS Code) edita los scripts `.gd` y archivos de proyecto.
- El usuario monta las escenas y prueba la jugabilidad en Godot (Play).
- Si hay error, el usuario pega el error de la consola de Godot.
- Se trabaja en fases pequeñas; cada paso se commitea. TODO es modificable.

---

## Convenciones

- Archivos y carpetas: `snake_case` (p. ej. `player.gd`, `coin_pickup.gd`).
- Nodos raíz de escena: `PascalCase` (p. ej. `Player`).
- Variables y funciones GDScript: `snake_case`.
- Cada escena tiene su script en la **misma ruta relativa** bajo `scripts/`.
  - Escena: `scenes/actors/player/player.tscn`
  - Script: `scripts/actors/player/player.gd`

## Estructura de carpetas (objetivo)

```
assets/        arte y sonido en crudo (sprites/, tilesets/, audio/)
scenes/        escenas .tscn (actors/, levels/, ui/)
scripts/       lógica .gd, espejando scenes/
resources/     datos como .tres (items, enemigos, dificultad)
```

---

## Roadmap por fases

1. **Fase 1 (actual): movimiento** — `Player` (CharacterBody2D) top-down, WASD/flechas, 8 direcciones, exploración libre. Sin colisiones todavía.
2. **Fase 2: sala con paredes** — colisiones (TileMap o StaticBody2D).
3. **Fase 3: enemigo en la mazmorra** — un enemigo que, al tocarlo, dispara el combate.
4. **Fase 4: combate por turnos (esqueleto)** — escena de combate aparte: tú atacas, el enemigo ataca, vida, ganar/perder. Al ganar, vuelves a la mazmorra.
5. **Fase 5: drop de cristal + minijuego de recogida** — al ganar el combate dropea un cristal con valor aleatorio según dificultad; recogerlo lanza el minijuego de timing (intacto/dañado).
6. **Fase 6: inventario + HUD** — guardar cristales y mostrarlos.
7. **Fase 7: tienda / venta** — precio aleatorio según el valor del cristal.

---

## Visión de economía / loot (largo plazo)

- Los monstruos sueltan **cristalitos**, no monedas.
- Cada cristal tiene un `valor_base` aleatorio dentro de una franja (min–max) que
  depende de la **dificultad** de la mazmorra.
- Al **recoger**: minijuego de **timing** (pulsar en el momento correcto). Según
  el resultado el cristal queda **intacto** o **dañado** (menos valor), o se pierde.
- Al **vender** (tienda): precio = otro aleatorio calculado a partir del `valor_base`.
  Un cristal dañado vende menos.
- Diseño: modelar cristales, enemigos y dificultad como **Resources** (`.tres`)
  para ajustar valores sin tocar código.

---

## Progreso

### Fase 1 — Movimiento ✅ COMPLETADA
- [x] Estructura de carpetas.
- [x] `player.gd` (movimiento WASD/flechas, 8 dir) en `scripts/actors/player/`.
- [x] Input map `move_left/right/up/down` en `project.godot`.
- [x] Escena `scenes/actors/player/player.tscn` (CharacterBody2D + ColorRect + CollisionShape2D).
- [x] Probado: el jugador se mueve. (Jira KAN-7..12)

### Fase 2 — Sala con paredes ✅ COMPLETADA
- [x] Escena de nivel `scenes/levels/main.tscn` con el jugador.
- [x] Pared reutilizable `scenes/levels/wall.tscn` (StaticBody2D).
- [x] Sala rectangular (contenedor `Walls` con 4 instancias escaladas); el jugador colisiona.
- [x] `Camera2D` dentro de `player.tscn` que sigue al jugador.
- [x] Probado: colisiones y cámara OK. (Jira KAN-13..17)

### Fase 3 — Enemigo en la mazmorra ✅ COMPLETADA
- [x] `scripts/core/abilities.gd`: sistema de habilidades DanMachi (5 stats 0-999, rango I-S) — groundwork para Fase 4.
- [x] `enemy_data.gd` (EnemyData, stats por franja) + `slime.tres`.
- [x] `enemy.gd`: patrulla, persecución (Area2D circular de visión), regreso a su sitio, disparo de combate (placeholder) calculando iniciativa.
- [x] `enemy.tscn` y enemigo colocado en `main.tscn`; jugador en grupo "player".
- [x] Probado: patrulla → persecución → regreso → trigger de combate. (Jira KAN-18..22)

### Fase 4 — Combate por turnos ✅ COMPLETADA
- [x] Sistema de stats: `abilities.gd`, `stats_math.gd` (fórmulas DanMachi
  con coeficientes ajustables), `combatant.gd`.
- [x] Motor de turnos por velocidad (`battle.gd`, ATB, iniciativa, doble acción).
- [x] Pantalla de combate interactiva `scenes/ui/combat.tscn` + `combat.gd`
  (vida en números, botón Atacar/Continuar).
- [x] Gestor `Game` (autoload): stats del jugador (persisten), abre el combate
  como overlay en CanvasLayer y pausa la mazmorra; al ganar el enemigo desaparece.
- [x] `EnemyData` migrado a stats de combate. `main.tscn` = escena principal.
- [x] Probado: chocar con slime → combate → ganar → vuelta a la mazmorra. (Jira KAN-23..29)
- Pendiente futuro: game over en condiciones, magia/huir/objetos, curación.

### Epic KAN-43 — Sigilo, aguante e iniciativa ✅ COMPLETADO
- [x] Movimiento jugador: sigilo (Ctrl) / andar / correr (Shift) + aguante. (KAN-44/45/46)
- [x] Enemigo: deambular aleatorio, visión en CONO (con cono+línea dibujados),
  oído según tu ruido, y ataque desde distancia óptima con aviso de 0.15s
  (instantáneo si estás agotado). (KAN-47/48/50)
- [x] Atacar con ESPACIO para iniciar combate sin tocar al enemigo:
  tú = tu iniciativa; el enemigo al alcanzarte = su iniciativa. (KAN-49)
- Quitado el DetectionArea (detección ahora por distancia+ángulo).

### Fase 5 — Loot: extracción de cristal + drop ✅ (núcleo completado)
- [x] Al ganar, el cuerpo queda como CADAVER (gris, grupo "corpse").
- [x] `F` sobre el cuerpo → minijuego de extracción (`scripts/ui/extraction.gd`):
  barra con zona verde aleatoria, N pulsaciones (slime 3), acelera por acierto;
  calidad por proporción de fallos (intacto/normal/dañado/roto).
- [x] Tamaño de zona escala con Destreza vs "esperada" del enemigo (topes).
- [x] Tras extraer, el cuerpo se desvanece; ~0.7s después puede dejar un DROP
  en el suelo (`MonsterDrop`, `drop_pickup.gd`), calidad Defectuoso/Normal/
  Excelente; se recoge con F. Cristales/drops en `Game.crystals` / `Game.drops`.
- [ ] KAN-68: herramientas de recolección (cuchillos) — placeholders listos
  (`Game.tool_hit_reduction` / `tool_destreza_bonus`); falta sistema de equipo.
- OJO: `Game.dev_force_drop = true` (drop al 100% para pruebas). Poner en false
  para usar el `drop_chance` real (2%).

### Fase 6 — Inventario + HUD + Excelia ✅ COMPLETADA
- [x] Inventario visual: panel con [I], muestra habilidades (visible/interno), cristales, drops, peso, valor estimado.
- [x] Excelia (subida de habilidades por uso): interno (float) vs visible (int).
- [x] Resistencia: recibir daño×peligrosidad. Destreza: minijuego de extracción.
  Agilidad: **huir** de un enemigo que te persigue (ver abajo). Fuerza-por-peso: descartada.
- [x] Peso y capacidad: zurron 25px + bonus Fuerza (+50% a 999), sobrecarga gradual >80%.
- [x] Actualizar estado (tecla U → hogar después): aplica interno a visible.
- [x] Enemigos: variación de poder se estrecha a mayor nivel; suma capada a 999/habilidad.

### Fase 7 — Pueblo (altar, tienda, puertas) ✅ COMPLETADA
- [x] Dinero (`Game.money`) y venta de cristales en tienda.
- [x] Precio: `valor_estimado() × (1 ± 20% azar)`.
- [x] **Altar**: F → actualizar_estado() + curar 100% (sustituye tecla U, el hogar real).
- [x] **Tienda**: F → vender SOLO cristales (drops serán para crafteo futuro), muestra ganancia.
- [x] **Puertas viaje**: F para ir pueblo↔mazmorra (auto-detecta destino).
- [x] NPCs interactuables: jugador busca grupo "interactable" al presionar F (antes cadáveres/drops).
- [x] HUD actualizado: muestra dinero (arriba + inventario).
- [x] town.tscn: nueva escena pueblo con paredes, altar, tienda, puerta a mazmorra.
- [x] main.tscn: puerta de vuelta al pueblo.

### Ajustes de balance Excelia + fixes (post Fase 7) ✅
Curva de subida de habilidades afinada en TODOS los tramos (novato↔experto × enemigo débil↔fuerte):
- [x] **Destreza (extracción):** curva `dificultad²/PIVOTE` con pendiente y tope propios
  (`EXTRACTION_DESTREZA_PIVOTE=1.5`, `_SLOPE=0.65`, `_RETO_MAX=8`). Un experto sacando
  de bichos flojos casi no sube; un novato vs bicho superior sube mucho. Suelo del
  minijuego `EXTRACTION_DESTREZA_FLOOR=20` (novato sufre en el minijuego).
- [x] **Físicas (Fuerza/Resistencia/Agilidad):** tope de reto propio `RETO_MAX_FISICO=5`
  (Destreza usa 8). `ganar()` acepta `max_reto` opcional. Suelo de poder del jugador
  `PODER_JUGADOR_SUELO=10→40` para graduar el arranque (solo físicas; se autodesactiva
  al superar 40 de stats totales). El minijuego usa su piso aparte (20), no se toca.
- [x] `RETO_MAX` global 3→8 (enemigo muy superior = más ganancia de todo).
- [x] Extracción: **mínimo 3 pulsaciones** siempre.
- [x] **Fixes:** rebote de puertas al mantener F (jugador ignora teclas ya pulsadas al
  aparecer); inventario congelado tras recargar con [I] abierto (HUD resetea el flag);
  tienda con desglose por cristal y constante `PRECIO_AZAR`.
- **Fuerza-por-peso: DESCARTADA** (KAN-84 se puede cerrar). Llevaba desactivada con
  `GAIN_FUERZA_PESO=0` y se ha borrado el código muerto en vez de rediseñarla.

### Excelia de Agilidad: HUIR de verdad
Antes se pagaba por *correr cerca* de un enemigo, y eso se farmeaba dándole vueltas alrededor.
Ahora se paga por **abrir hueco con uno que te persigue a TI** (`enemy.persigue_a`), con una
**marca de agua**: solo cobra lo que supera la mayor distancia que le has sacado en esa misma
persecución (`player._tick_huida`).
- Correr en círculos → la distancia nunca bate el récord → no paga.
- Yo-yo (dejarse alcanzar y volver a huir) → el tramo ya cobrado no se repite.
- Hay que ir **corriendo**; y el récord se olvida en teletransportes y al cambiar de líder
  (`_reset_huida`), que si no regalarían el hueco de golpe.
- Techo natural: al pasar del `lose_range` del bicho te pierde y la persecución acaba.
- `GAIN_AGILIDAD_HUIDA = 0.25` por cada `_HUIDA_TICK = 55` px de hueco nuevo. PROVISIONAL.

**Lo que se cobra tiene DOS ejes que se multiplican:**
1. **Contra qué huyes** — `Game.reto(poder, nivel)` del perseguidor, hasta ×5. Un bicho de nivel
   inferior al tuyo te mide contra tu poder *de por vida*: da casi cero (anti-farmeo del piso 1).
2. **Cuánto te costó** — `Game.huida_dificultad_mult(vel_bicho, tu_vel_real)` = ratio de
   velocidades ×2, acotado a **×0.5 … ×2.0**. La velocidad tuya lleva **peso y armadura dentro a
   propósito**: ir cargado te hace más lento y la fuga vale más. No hace falta blindarlo contra
   el que se cargue aposta: si te pasas, el bicho es más rápido, el hueco no se abre y cobras 0.

### Combate avanzado — parte 1: críticos/evasión/defender (KAN-52/53/54) ✅
- [x] **Crítico** (KAN-52) y **evasión** (KAN-53) por CONTEST relativo (`stats_math._contest`):
  crit = tu Destreza vs Agilidad enemiga; esquiva = tu Agilidad vs Destreza enemiga.
  Se auto-equilibra al subir de nivel (es un ratio). Crít fijo ×1.5 (`CRIT_MULT`).
- [x] **Defender** (KAN-54): botón creado por código, mitiga el golpe y anula crítico hasta
  tu próximo turno. Aún SIN coste de energía (llega en la Fase B de equipo).
- [x] `resolve_attack()` en `stats_math.gd` centraliza esquiva→crít→mitigación→aturdir.

### Combate avanzado — parte 2: Sistema de acciones (KAN-55) 🔧 A PROBAR
Los dos botones ad-hoc (Atacar/Defender) pasan a una **barra de acciones de datos** en
`combat.gd`: **Atacar · Magia · Defender · Huir** (enum `Action` + `_action_buttons`).
Añadir una acción futura (habilidades, objetos) = una entrada más en la lista.
- [x] El botón de la escena (`AttackButton`) se **reutiliza como "Continuar"** al terminar;
  las 4 acciones se crean por código en un `HBoxContainer` (convención: UI por código).
- [x] **Huir** (nuevo): `StatsMath.flee_chance()` = CONTEST de tu Agilidad vs la del enemigo
  (50% en paridad, topes 10–95%). Entrar **agotado** la reduce (`FLEE_EXHAUSTED_MULT=0.6`).
  Éxito → sales del combate SIN loot y el enemigo **sigue vivo** (`_end(false, true)`, mensaje
  propio, no cuenta como derrota); fallo → pierdes el turno. Nota: al huir vuelves junto al
  enemigo en la mazmorra (posible re-trigger inmediato; pendiente pulir).
- [x] **Magia** (gancho KAN-56): botón presente pero **deshabilitado** (`_hay_hechizos()` = false)
  con tooltip. Listo para enchufar hechizos cuando exista el sistema.
- [x] `_slow_actions_left` se consume en `_fin_de_eleccion()` (común a atacar/defender/huir).

### Combate avanzado — parte 3: Magia por encantamientos (KAN-56) 🔧 A PROBAR
Los hechizos se lanzan **recitando frases**: cada turno un **test tipo examen (a/b/c/d)** con la
frase correcta mezclada con distractores de un **repositorio** (`SpellBook.REPOSITORIO`).
Aciertas → avanzas; fallas → **backfire**. Ritmo: **N frases = N turnos de recitado + 1 de disparo**
(corto 1 frase, medio 2, largo 3). En el turno en que eliges el hechizo ya recitas la 1ª frase.
- [x] **`SpellData`** (`scripts/items/spell_data.gd`) + 3 `.tres` en `resources/spells/`: `chispa`
  (corto), `bola_fuego` (medio), `tormenta` (largo). Campo `tipo` = {ATAQUE, BUFF, DEBUFF} pero
  **solo ATAQUE** implementado ahora (buff/debuff → futuro, con KAN-58).
- [x] **`SpellBook`** (`scripts/core/spell_book.gd`): repositorio de ~22 frases + `opciones_test()`
  (1 correcta + distractores barajados, excluyendo la correcta).
- [x] **Maná** (nuevo recurso): `max_mp = BASE_MP(20) + Magia×MP_FROM_MAGIA(0.033)` (`stats_math`)
  → a Magia 999 = 53 máx. Persiste entre combates (`Game.player_current_mp`, −1 = lleno, como la
  vida). **El maná se recupera JUGANDO, no esperando** (rediseño): ya NO hay regen pasiva por el
  mapa (`tick_mana_regen`, borrada: el jugador se plantaba quieto mirando la barra) ni goteo base
  por turno. Las fuentes son:
  - **Al PEGAR**: cada golpe de arma que ACIERTA (básico, golpe de habilidad o contraataque de la
    postura) devuelve `StatsMath.MP_POR_GOLPE_PCT(4%)` del maná máximo. Porcentual → escala solo
    con la Magia, nunca hay que retunearlo.
  - **Al GANAR** el combate: `MP_VICTORIA_PCT(25%)` del máximo (huir NO lo da: hay que rematar).
  - **Por turno**: solo lo que aporte el **arma mágica** (`mp_regen_bonus`, mejora Regeneración
    KAN-95), que así pasa de marginal a ser la firma del bastón/varita.
  - Fuera de combate: **pociones** de maná (con arrastre) y el **altar** (rellena al 100%; teclas
    dev H / debug stats también).
  Se **descuenta al empezar** el casteo (si fallas, se pierde). El mago que se queda a cero lejos
  del pueblo no espera: pega (Bastonazo) y recarga, o bebe.
- [x] **Daño**: `StatsMath.resolve_spell()` = `dano_base × magia_factor(Magia) × magic_amp`, mitigado
  por la Magia del enemigo. Sin esquiva/crítico (el riesgo es recitar bien). **`magic_amp`** del
  Combatant queda **neutro (1.0)**: gancho para las armas de mago (**KAN-95**, bastón/varita).
- [x] **Backfire**: `StatsMath.backfire_damage()` escala con `dano_base` y con lo avanzado que ibas
  (fallar la última frase de un hechizo largo duele mucho); interrumpe el conjuro y el maná ya está
  perdido.
- [x] **Casteo en `combat.gd`**: submenú de hechizos (`_accion_magia`), test por frase
  (`_mostrar_test`/`_responder_frase`), disparo (`_mostrar_disparo`/`_disparar_hechizo`), backfire.
  Estado persistente `_cast_spell`/`_cast_index`. Mientras casteas NO hay otras acciones (el enemigo
  te pega en cada hueco). **Excelia (fórmula dedicada)**: la Magia sube SOLO al **lanzar** (no por
  frase), escalada por `mana_factor = coste_mana/MAGIA_COSTE_REF(4)` × `reto(enemigo)` (tope 5), con
  rendimientos decrecientes por la Magia interna. Contra slime: Chispa ~1.5, Bola ~3, Tormenta ~5/cast.
- [x] **Equipables desde el DEBUG**: sección HECHIZOS (checkboxes) en `debug_panel.gd`; el jugador
  empieza **SIN hechizos** (`Game.equipped_spells = []`). La obtención aleatoria se verá más adelante.
- [x] HUD muestra maná y nº de hechizos equipados; la pantalla de combate muestra MP del jugador.
- Constantes PROVISIONALES → afinar con Excel. Interrupción por golpes fuertes del enemigo → futuro.

### Equipamiento — Armas de mago (KAN-95) 🔧 A PROBAR
Dos arquetipos de mago, enganchados al `magic_amp` que KAN-56 dejó neutro:
- **Mago puro — Bastón** (`baston.tres`, WeaponData `es_magica`, 2 manos, contundente): pega poco
  (`motion_value 0.4`), `magic_amp 1.8`, `mp_regen_bonus 0.4`, bloquea decente. Castea a su propia
  velocidad.
- **Mago híbrido — arma ligera + Varita** (`WandData`, `wand_data.gd`, off-hand): la varita NO
  ataca; da `magic_amp 1.4`, `mp_regen_bonus 0.15` y define la **velocidad de CASTEO**. Compatible
  con daga / espada corta / maza peq **y espada larga** (soporte; la larga si no solo admite escudo).
- **Cast-speed switch**: en `combat._process`, mientras `_cast_spell != null` la barra ATB usa
  `_player.cast_spd()` (velocidad de la varita / del bastón); atacando usa `spd()` (arma principal).
- **Combatant** nuevos: `cast_velocidad_mult`, `mp_regen_bonus`, `mana_reduccion`, `cast_spd()`
  (`magic_amp` ya existía). `Game.loadout_mods()` los calcula y combina (amp = producto main×off,
  regen sumado, cast_base = varita si hay, si no arma; `crear_player_combatant` los vuelca + armadura
  frena el casteo).
- **Mejoras mágicas** (`upgrades.gd`, gated por `weapon_categories`/`wand_categories`):
  **Potencia** (+magic_amp directo, `POTENCIA_STEP 0.05`, cap 0.25), **Eficiencia** (−% coste maná,
  `dim_sum` asintota a `EFICIENCIA_CAP 0.25`), **Celeridad** (+vel casteo, cap 0.10),
  **Regeneración** (+% regen del arma, cap 0.40), **Durabilidad** (reservada). `MAGIC_AMP_FLAT 0.02`
  = primario universal (cada mejora sube algo el amp) + el extra de Potencia. `magic_mods()` las
  agrega. **Tier mágico** (`magic_tier_ratio = tmult^0.14`): el tier sube el `magic_amp` de forma
  MUCHO más suave que el melee (t1 ×1, t2 ×1.12, t3 ×1.25) — subir de tier en magia rinde menos que
  en físico. El **bastón** (arma mágica que SÍ ataca) admite ADEMÁS **Agudeza** (raw
  melee) y **Peso** (aturdir, es contundente) — `weapon_mods` los honra para `es_magica`; la varita
  no (no ataca). Coste efectivo con Eficiencia en `combat._coste_efectivo()`.
- Equipables desde DEBUG (bastón en armas, varita en secundarias; mejoras por slot). PROVISIONALES.

### 🔧 KAN-58 (Estados alterados) — Fases 0 y 1 HECHAS, Fase 2 siguiente
Objetivo global: **cerrar el combate** (mecánicas) antes de un playtest grande "todo junto".
Orden acordado: **1) KAN-58 Estados alterados (esto), 2) KAN-57 Habilidades con energía**
(energía = stamina de entrada; solo habilidades/Defender gastan, básicos regeneran — ver memoria
`energia-combate-habilidades`). Los estados van primero porque magias/habilidades de buff/debuff los usan.

**ESTADO ACTUAL (implementado y probado):**
- **Fase 0 ✅** — `scenes/levels/sandbox.tscn` (arena vacía) + `scripts/ui/spawner.gd` (coloca
  enemigos con clic, solo en la arena). Tecla dev **T** salta a la arena. `enemy.recolocar()` fija
  el hogar en el punto del clic.
- **Fase 1 ✅** — Motor de estados data-driven:
  - `scripts/core/status_effects.gd`: catálogo (`Id`, `_defs`) + clase `Instance`. Campos:
    `stack_mode` (`none`/`merge`/`independent`), `dot`/`dot_default`/`dot_stack_mult`, `atk/def/spd_mult`,
    `is_stun`, `stun_prob_mult`, `max_stacks`.
  - `Combatant`: `statuses[]`, `apply_status(id, turns, magnitude, stacks_add, refresh_all, stack_cap)`,
    `tick_statuses()` (DoT + aturdido + expira, al inicio del turno), agregadores que multiplican
    `atk()`/`def_value()`/`spd()`/`cast_spd()`, `stun_taken_mult()` (gancho del rayo).
  - `combat.gd`: tick al inicio del turno de cada uno, muerte por DoT, salta turno si aturdido,
    estados pintados en las etiquetas, **log en pantalla = HISTORIAL** (6 líneas), **pausa de ~1s**
    tras la acción del enemigo, prints `[estado]` a consola (para montar Excel), y **panel dev**
    "ESTADOS (dev/test)" arriba-dcha para aplicar a mano.
  - **Diseño FINAL veneno vs sangrado** (acordado con el usuario):
    - **Veneno** ☠: `merge` (misma duración todos los stacks); cada stack **DUPLICA** el daño
      (base 3 × 2^(stacks−1) → 3·6·12·24·48). Un solo veneno; habilidades/enemigos capan hasta qué
      stack pueden subirlo vía `stack_cap` (los flojos a nivel bajo). SIN tiers con nombre.
    - **Sangrado** 🩸: `independent` (cada stack su propia duración, expiran solos); daño/stack =
      **fracción del ATAQUE del aplicador** (0.30×atk; subido de 0.15 para que importe), suma **lineal**. `refresh_all` reservado
      para una habilidad que reinicie todos los stacks. Lo aplicarán habilidades con armas cortantes.
    - Ambos los usan los dos bandos; la diferencia es la MECÁNICA, no quién los usa.
  - Estados ya en el catálogo (magnitudes PROVISIONALES → Excel): Veneno, Sangrado, Quemadura (DoT),
    Lento/pegajoso (merge, −5%/stack, máx 4), Débil (atk×0.8), Vulnerable (def×0.8), Fortaleza
    (atk×1.25), Aturdido (is_stun), Rayo (stun_prob_mult ×1.5).
- **Fase 2 ✅** — aturdido como ESTADO + debuff de rayo:
  - `stats_math.resolve_attack`: `aturde_p` se multiplica por `defender.stun_taken_mult()` (Rayo ×1.5,
    antes del cap `ATURDIR_MAX`).
  - `combat._aplicar_aturdir` (2 niveles, decisión del usuario): golpe **normal** que aturde =
    retraso parcial de barra ATB (stagger); golpe **CRÍTICO** que aturde = aplica el **estado Aturdido**
    (pierde su próximo turno vía el motor). El stun completo queda atado al crítico (depende de Destreza).
  - Marcas de consola `[combate] ===== INICIO/FIN =====` para delimitar combates al montar Excel.
  - Verificado: Rayo 18→27 y 40→60 (cap), crítico→Aturdido→pierde turno.
- **Fase 3 ✅** — CONTENIDO (estados cableados a fuentes) + resistencia:
  - Sistema genérico `StatusApplication` ([status_application.gd](scripts/items/status_application.gd)): lista de
    efectos por fuente. `EnemyData.al_golpear` (al golpear) y `SpellData.efectos` (al lanzar). Una fuente
    aplica VARIOS. Prob de hechizo = base × longitud (más largo = más fiable); buffs a uno mismo = siempre.
  - **Slimes**: normal → Pegajoso 50%; **venenoso** (verde, nuevo) → Pegajoso 50% + Veneno 35% (tier 1, cap 1);
    **de fuego** (naranja, nuevo) → Pegajoso 50% + Quemadura 35%. Los 3 en el spawner.
  - **Hechizos**: Chispa/Bola → Quemadura (50%/70%); Tormenta → Rayo 90% + Aturdido 30%; **Fortaleza** (buff
    atk×1.25 a uno mismo) y **Debilidad** (debuff atk al enemigo 80%) NUEVOS. Frases nuevas en SpellBook.
  - **Lento vs Pegajoso SEPARADOS**: Lento 🐌 = ralentización FIJA −25% (no apila, hechizo/habilidad);
    Pegajoso 🕸 = apilable independiente −5%/stack hasta 4 (slimes).
  - **Resistencia de armadura** (mejora `RESISTENCIA`, antes reservada, ahora activa): baja la PROBABILIDAD
    de que te apliquen un estado (`prob × (1−status_resist)`). `RESISTENCIA_STEP 0.03`, cap 0.50 sumando piezas.
    Disponible en toda armadura. Cadena: mejora → `armor_piece_mods` → `armor_mods` → `Combatant.status_resist`.
  - Pruebas exhaustivas de balance: aplazadas a cuando esté todo el combate avanzado (KAN-57 después).

**Duración de buffs/debuffs de stat (fix):** los estados de stat (Vulnerable/Débil/Lento/
Fortaleza/Rayo/Pegajoso) se saltan el PRIMER decremento del tick (flag `Instance.fresh`), así
un buff/debuff de N turnos sigue activo durante la acción de los N turnos (antes se "gastaba"
uno antes de poder usarlo: un buff de 3 solo servía 2). Los **DoT** (veneno/sangrado/quemadura)
NO usan `fresh`: aplican daño al inicio del turno y expiran normal. El stun (1 turno) tampoco.
`fresh` se resetea al reaplicar (refrescar = como nuevo).

**Motor de estados (propuesta base):** cada `Combatant` lleva estados activos
`{tipo, turnos_restantes, magnitud/stacks}`. Tick al INICIO del turno del afectado: aplica DoT,
descuenta duración, expira. Los de stat modifican `atk()`/`def_value()`/`spd()`; aturdido = pierde
turno. Re-aplicar refresca duración (los apilables suman stack). Mostrarlos en la línea del
combatiente (p.ej. `☠2 🔥1 ▼vel×3`).

**Estados a incluir (v1, pedidos por el usuario):**
- **Veneno** en varias CATEGORÍAS (tiers de daño/duración; definir cuántas y qué las distingue).
- **Sangrado**.
- **Aturdimiento**: se MANTIENE la mecánica actual por **PROBABILIDAD** (armas contundentes ya
  tienen `aturdir_base` ~12%). "Bien desarrollado" = que el aturdido sea un estado en condiciones
  (pierde el turno). **NO** es un sistema de buildup/umbral/decay.
- **Quemadura** (DoT) — la aplican las magias de FUEGO (Chispa y Bola de Fuego).
- **Pegajoso** (debuff de slimes): apilable **hasta 4**, **−5% velocidad por stack**, cada stack
  dura **3 turnos**. Probabilidad de aplicar: a definir (propuesta: base del efecto × factor
  relativo del atacante vs **Resistencia** del defensor, capado — reusar `_ratio_factor`/`_contest`
  de `stats_math.gd`).
- **Buffs de potenciación** típicos + debuffs.

**Cómo aplicarlos / probar (pedido por el usuario):**
- **Slime VERDE** raro (poca prob. de aparición) que aplica **veneno** con algunos ataques.
- **Buffs/debuffs con hechizos**; si faltan frases, **ampliar el repertorio** de `SpellBook`.
- **Quemadura** ← Chispa y Bola de Fuego. **Tormenta** / hechizos de rayo ← aplican un **debuff de
  RAYO** que **MULTIPLICA la probabilidad de aturdir del objetivo** (p.ej. ×1.5 sobre el ~12% del
  arma) mientras dura — como el rayo de Monster Hunter que facilita el KO. NO cambia la mecánica de
  stun, solo escala su probabilidad.
- Entrega de paso los **buff/debuff de hechizos** que quedaron aplazados en KAN-56.
- **Herramienta de test**: empezar con el **escenario VACÍO** y un **botón a la derecha (como el de
  DEBUG)** que permita **spawnear enemigos donde queramos** (clic para colocar). OJO: hoy `main.tscn`
  trae un slime pre-colocado.

**Fases sugeridas de implementación:**
0. ✅ Escenario vacío + **botón spawner de enemigos** (base para probar todo lo demás).
1. ✅ **Motor de estados** en `Combatant` (DoT, stat-mods, stacks, tick, display) + integración en
   `combat.gd`.
2. ✅ **Aturdido como estado** (crítico contundente) + **debuff de rayo** ×1.5 sobre la prob. de aturdir.
3. ✅ **Contenido**: quemadura en Chispa/Bola, rayo+aturdido en Tormenta, pegajoso en slimes, slimes de
   veneno (tier 1) y fuego, buff (Fortaleza) / debuff (Debilidad) con hechizos, resistencia de armadura.
   Efectos con PROBABILIDAD que sube con la longitud. **KAN-58 COMPLETA.**

**Preguntas de diseño abiertas** (resolver al retomar): nº de categorías de veneno y qué las
distingue; stat que resiste cada estado y fórmula de probabilidad de aplicación; multiplicador
exacto del debuff de rayo (~×1.5) y su duración; magnitudes/duraciones concretas (PROVISIONALES → Excel).

### Equipamiento — Fase A: armas + loadout de 2 manos (modelo MH Motion Values) 🔧 A PROBAR
Plan completo en `~/.claude/plans/daga-espada-corta-espada-cozy-kahan.md`.
- [x] **Modelo estilo Monster Hunter**: el "raw" (daño base) es común (viene de tu Fuerza);
  el arma aporta su **`motion_value`** (% de raw por golpe) y su **velocidad** (turnos ATB,
  MULTIPLICATIVA). Equilibrio = motion_value × velocidad. Afinidad de MH = nuestro crítico.
- [x] `WeaponData` (`scripts/items/weapon_data.gd`) + `ShieldData` (3 tamaños: peq/normal/grande).
  9 armas en `resources/weapons/`, 3 escudos en `resources/shields/` (valores PROVISIONALES;
  se afinan con el Excel del usuario).
- [x] **Loadout de 2 manos** en `Game`: `equipped_main` + `equipped_off` (arma dual | escudo | nada).
  `loadout_mods()` combina: dual = +velocidad; escudo = +bloqueo/−velocidad/−esquiva; arma a
  2 manos = sin secundaria pero bloquea decente. Cierra **KAN-82** (arma_factor = motion_value).
- [x] **Contundentes** (maza/martillo): menos daño (no cortan) + **aturdir/retrasar** (resta barra
  ATB del enemigo). Prob = `aturdir_base × factor_relativo(media Fuerza+Destreza vs Fuerza enemiga)`.
  Primer "estado" (adelanto de KAN-58).
- [x] Teclas DEV: **K** cicla arma principal, **L** cicla mano secundaria (imprime el loadout).
- OJO: con **Puños** (arma por defecto, MV 0.5) pegas la mitad que antes; equipa un arma real.
- Pendiente Fase B: **energía de combate** compartida con el aguante (ataque básico recupera,
  Defender/habilidades gastan); Fase MANT: desgaste + mantenimiento en el pueblo (sumidero $).

### Equipamiento — Fase B(1): Armaduras (5 slots) por CATEGORÍA + velocidad 🔧 A PROBAR
Verificado en headless (números exactos: DEF, reducción media y velocidad).
**OJO (rediseño):** se QUITÓ la mecánica de PESO/equip-load de armas y armaduras. Ahora la
armadura, **como las armas, modula la VELOCIDAD** (combate ATB + movimiento en mapa).
- [x] **`ArmorData`** (`scripts/items/armor_data.gd`) + 20 `.tres` en `resources/armor/`
  (4 categorías × 5 slots). Campo `velocidad_mult` (no `peso`).
- [x] **Escalón de categorías** (más DEF = más lento). `defensa_base` común (0.5) × `motion_def`;
  la velocidad se combina por cobertura de slot; slot VACÍO = bonus de "ir ligero"
  (`SIN_ARMADURA_VEL_MULT = 1.08`):

  | Categoría | DEF/pieza | reducción | velocidad |
  |---|---|---|---|
  | (sin nada) | 0 | 0% | ×1.08 |
  | **Cuero** | 0.25 | 5% | ×1.04 |
  | **Hierro** (media) | 0.50 | 7.5% | ×1.00 |
  | **Hierro completo** | 0.80 | 9% | ×0.93 |
  | **Placas** (máx) | 1.10 | 11% | ×0.88 |

- [x] **5 slots** en `Game` → `armor_mods()`:
  - **DEF plana ADITIVA** (`defensa_base × motion_def × tier_mult`), **SIN techo**.
  - **% reducción = MEDIA PONDERADA por cobertura** (pecho 0.35, casco/pantalón 0.20,
    manos/botas 0.125), NO suma. Techo `StatsMath.ARMOR_REDUCTION_MAX = 0.20`.
  - **velocidad_mult combinada** por cobertura (set completo = su valor; mezclar interpola;
    vacío = bonus ligero). Va a `Combatant.velocidad_mult` (combate) y `Game.armor_speed_mult()`
    (mapa, en `player.gd`).
- [x] Tecla DEV **J**: cicla ninguna/cuero/hierro/hierro completo/placas (DEF, reducción, velocidad).
- Valores PROVISIONALES → **afinar con Excel** en playtest.
- Enemigos: `extra_defense`/`armor_reduction` = 0 (sin cambios); puerta abierta a darles armadura.

### Herramientas — Panel de DEBUG clicable (en cualquier sala) ✅
`scripts/ui/debug_panel.gd` (CanvasLayer, la crea el jugador junto al HUD → aparece en
pueblo y mazmorra). Botón **DEBUG** abajo-izquierda abre/cierra un panel con:
- **STATS**: 5 campos (F/R/D/A/M) + Aplicar → `Game.debug_set_abilities()` (escribe el
  interno, `actualizar_estado()` y cura al 100%).
- **Habilidades del ENEMIGO**: 5 campos (F/R/D/A/M) que se escriben como los tuyos, más presets
  rápidos Base / 200 / 500 / Cheto → `Game.debug_enemy_override` (Dictionary por stat). Una casilla
  **vacía deja esa stat en su valor natural** (el reparto por pesos del piso), así se puede aislar UNA
  sola (p.ej. subir solo la Magia para ver cuánto frena la defensa mágica) sin deformar el resto del
  bicho. Se aplica en `EnemyData.crear_abilities()`.
- **ARMADURA por pieza**: dropdown Nada/Cuero/Hierro/Hierro compl./Placas + dropdown de TIER
  (T1/T2/T3) al lado, por slot.
- **ARMAS**: dropdowns de principal y secundaria + su TIER (reusa `Game._dev_weapons`/`_dev_offs`,
  `equipar_arma`/`equipar_secundaria`; revierte combinaciones inválidas).
- **PISO**: campo para fijar `Game.current_floor` (escala al enemigo).
- **PRUEBA (muñeco)**: Off / **Saco DPS** / **Pegador** + campo de **HP** (def. 500).
  `Game.debug_dummy_mode` (0/1/2) + `debug_dummy_hp`, aplicado en `start_combat`:
  - **Saco**: HP alto, **0 defensa/esquiva** (DPS limpio), **no pega** (`dummy_dmg_out_mult=0`),
    velocidad estándar (`dummy_speed_override = spd del jugador` → cadencia ~1:1). Para medir tu DPS.
  - **Pegador**: aguanta y te pega normal (súbele el daño con los presets de stats). Para probar
    la mitigación de la armadura.
  - En ambos, el jugador es **invulnerable** (`Combatant.invulnerable`, tests largos sin morir; el
    daño recibido se sigue midiendo). El combate loguea **`[dps]`** por acción (fuente + acumulado +
    turnos + DPS/turno tuyo y del enemigo) y un **resumen final** (desglose por fuente + daño
    recibido medio). Hooks: básico, habilidad, hechizo y DoT en `combat.gd` (`_dps_add`/`_dps_resumen`).
- **RAREZA** (dropdown por arma y pieza) + sección **MEJORAS** (elegir slot y repartir
  mejoras por categoría con −/+, según el máximo de la rareza).
- Mientras está abierto, `Game.debug_panel_open` congela al jugador (teclear sin moverse).
- **Ayuda de teclas en pantalla** (`scripts/ui/keys_help.gd`, la crea el jugador): panel arriba-izq
  con TODAS las teclas de debug (U/H/R/T/K/L/J + botón DEBUG + spawner) y los controles básicos.
  Se oculta/muestra con **F1**. Para builds de PRUEBA que se reparten a testers.

### Progresión — Rarezas + Mejoras (upgrades) de equipo 🔧 A PROBAR
`scripts/core/upgrades.gd` (class_name Upgrades, como StatsMath) centraliza enums+tablas+math.
Estado por ítem en `Game.equip_meta[slot] = {tier, rareza, mejoras{cat:n}}` (no en el `.tres`).
- **Rareza** (7: común→obra maestra): (1) `RAREZA_MULT` % pasivo sobre la base
  (**común 1.00** = regresión exacta … obra maestra 1.15); (2) `RAREZA_SLOTS` nº de
  mejoras (3→12).
- **Cada mejora** sube el número base +**0.3 fijo ×tier** (raw de arma / DEF de armadura),
  elijas la categoría que elijas (→ en un arma, cada mejora sube el raw). **Encima**, la
  categoría da un extra **decreciente** (`dim_sum`, decay 0.8).
- **Categorías arma**: Agudeza (+raw), Precisión (+crit +**acierto**), Peso (+stun, solo
  contundentes), Rapidez (+vel, **tope +0.08**), Durabilidad (reservada).
- **Categorías armadura** (GATING estricto por clase): Dureza (+DEF, todas); **Evasión**
  (+esquiva) solo ligeras/medias (cuero/hierro); **Resist. críticos** (−crit rival) solo
  pesadas (hierro completo/placas); Resistencia (estados) y Durabilidad reservadas.
- **Mecánicas nuevas** en `resolve_attack()`: `attacker.precision` (acierto) baja la
  evasión del defensor; `defender.crit_resist` baja el crit del atacante. Ambas acotadas
  (`Upgrades.EVASION_CAP`, `RESIST_CRIT_CAP`).
- Enganches: `_hand_from`/`loadout_mods`/`armor_mods` (game.gd) llaman a
  `Upgrades.weapon_mods` / `armor_piece_mods`. Verificado con test de curva.
- Que un ítem obra maestra supere la base del tier siguiente es INTENCIONADO.

### Progresión — Habilidades de enemigos por FRANJA de piso + reescalado base 🔧 A PROBAR
- **Reescalado stats base**: `FLOOR_STAT_GROWTH 1.18 → 1.10` (game.gd). Piso 13 ≈ dureza
  base del piso 8 de antes (1.10^12≈3.14 ≈ 1.18^7≈3.19). Nivel 1 = pisos 1-13.
- **Habilidades por FRANJA de suma** (reemplaza el multiplicador plano; se quitó
  `enemy_floor_ability_factor`): `Game.enemy_ability_sum_band(piso)` = `[175·(p-1),
  200+250·(p-1)]` → piso1 [80,200] (suelo `SUM_MIN_FLOOR=80` para que no salgan casi
  vacíos), piso2 [175,450] … piso13 [2100,3200] (PROVISIONAL).
- **Distribución por arquetipo** (enemy_data.gd): los campos `fuerza/…/magia` son ahora
  **PESOS** (proporción), no absolutos. Cada arquetipo ocupa un sub-tramo con
  `franja_low/high` (slime `[0.0,0.6]` = parte baja; goblins futuros la alta).
- **Roll por enemigo** (enemy.gd): `current_t = randf()` (0..1, posición en su
  sub-franja). `crear_abilities(t)` reparte la suma objetivo por pesos (cap 999/stat).
  `suma_habilidades(t)`/`crear_combatant(t)`. `current_power` renombrado a `current_t`
  (game.gd/player.gd actualizados). Debug override (200/500/999) sigue por encima.
- Con solo slimes en la parte baja, los pisos salen más flojos (esperando goblins).
- **HUD**: la barra de arriba muestra piso, peso de loot y **velocidad de armadura** (×); el
  inventario detalla la velocidad de armadura (+ por ir ligero / − por armadura pesada).

### Progresión — Escalado por PISO + TIERS de equipo 🔧 A PROBAR
Plan en `~/.claude/plans/ya-que-hemos-terminado-imperative-hejlsberg.md`. Cierra el bucle
"bajas de piso → enemigos más duros → mejoras tu equipo". Verificado con test de curva.
- **Enemigo escala con `current_floor`** (`game.gd` + `enemy_data.gd`), geométrico:
  - `FLOOR_STAT_GROWTH = 1.18` → vida/ataque BASE **sin techo** (piso5 ~×2, piso10 ~×4.4).
  - `FLOOR_ABILITY_GROWTH = 1.12` → habilidades (vía power), **capadas a 999**.
  - Defensa base escala más suave (`sqrt`); la velocidad NO (ATB justo). Piso 1 = como hoy.
- **Tiers de equipo como MULTIPLICADOR en runtime** (sin duplicar `.tres`): `Game.tier_mult(t)
  = pow(TIER_GROWTH=2.2, t-1)`. Escala **solo números sin techo**: `ataque_base` del arma
  (`_hand_from`) y `defensa_base` de la armadura (`armor_mods`). La **reducción %** NO (acotada).
  Tiers equipados: `equipped_main_tier`/`equipped_off_tier` y `equipped_<slot>_tier`.
  Deja el enganche listo para la tienda/crafteo (subir tier del ítem equipado).
- **Panel de debug**: dropdown de **tier (T1/T2/T3) al lado** de cada pieza de armadura y de
  cada arma; **selector de PISO** en la sección Enemigo. HUD muestra el piso actual.
- Curva verificada: piso 10 con equipo t1 = inviable (mueres antes de matar); con t3 se
  normaliza. Constantes PROVISIONALES → afinar con Excel (hoja piso↔tier pendiente).

### KAN-57 — Habilidades de armas (energía + framework) 🔧 EN CURSO
Energía de combate = **stamina de exploración**: entras al combate con la que traigas y vuelve
al salir (`Game.start_combat`/`_on_combat_finished`). El **básico regenera**, **Defender y las
habilidades gastan** (ver memoria `energia-combate-habilidades`). **Castear también regenera**
(recitar frase, lanzar, e incluso backfire): son turnos básicos que no gastan energía.
- **`AbilityData`** (`scripts/items/ability_data.gd`, `.tres`): las arma/escudo traen sus
  `habilidades`; el loadout las junta en `Combatant.abilities_combate`. Campos: `golpes_min/max`
  (+ `_dual`), `dano_mult` (× básico por golpe), `efectos` (Array[StatusApplication]) con
  `efectos_por_golpe` (tirada por impacto vs una al final; cada `StatusApplication` admite
  `solo_crit` = solo prende si ese golpe fue crítico), `coste_energia` (+ `_dual`),
  `bloqueo_turnos` (deja en guardia), `dano_tipo_override` (-1 arma / 0 corte / 1 contundente),
  `requiere_escudo` (técnica arma+escudo; `Game` la filtra si `equipped_off` no es un escudo),
  `cooldown` (turnos a esperar para reusarla; 0 = sin cooldown). Cada `StatusApplication` admite
  además `mult` = **NIVEL** de un estado de stat (Vulnerable/Débil/Lento): multiplicador propio
  que sustituye al del catálogo (0 = catálogo). Ej: Hendedura del hacha usa `mult=0.70` = −30% def
  (vs −20% base). Vive en `Instance.mult_override`; al reaplicar se queda con el nivel más fuerte;
  la etiqueta del enemigo muestra el % real (`🔻-30%·3t`).
- **Cooldowns** (KAN-57): estado POR COMBATE en `Combatant.ability_cooldowns` (dict AbilityData→turnos).
  `start_cooldown` al usar, `tick_cooldowns` al inicio de cada turno (en `_begin_player_turn`),
  `ability_ready`/`ability_cd_left` para el botón (deshabilitado + "⏳N" mientras cuece). Un
  Combatant nuevo por combate → arranca sin cooldowns. Junto a los **costes subidos (~+40%)**,
  las habilidades son jugadas de COMPROMISO (gastas un pico de energía Y esperas turnos), no spam.
  Cooldowns por rol: filler barato (Doble tajo) cd 1; golpes estándar (Ráfaga/Puñalada/Golpe de
  escudo) cd 2; setups/nukes/power (Tajo quebrantador/pesado/desarmante, Guardia rota) cd 3.
- **Dual por arma** (fix): una habilidad usa su versión **dual** SOLO si AMBAS armas la aportan
  (daga+daga), no daga+estoque — cada arma tiene sus habilidades. `Game` construye
  `Combatant.ability_hands` (habilidad → índices de mano que la traen); `_usar_habilidad` usa
  `ability_manos(ab)`/`ability_hand_indices(ab)` para los golpes/coste y golpea con el arma
  correcta (`set_active_hand`), sin alternar si no es dual real. Las de escudo/varita → mano 0.
- **Orden del submenú** (combat.gd): habilidades y hechizos se listan por **coste DESCENDENTE**
  (energía / maná efectivo; las más caras arriba). `sort_custom` sobre una copia de la lista.
- **Combate** (`combat.gd`): acción **Habilidad** (`_accion_habilidad`/`_usar_habilidad`); cada
  golpe con su esquiva/crítico propios, log per-hit en consola, estados vía `_tirar_efectos_habilidad`
  (prob × resistencia del rival).
- **Hechas** (números PROVISIONALES → Excel):
  - **Daga · Ráfaga** (`resources/abilities/rafaga.tres`): 2 tajos 0.7× (3-4 dual), Sangrado
    40%/hit. *Spray-and-pray*, riesgo repartido. 25 EN (38 dual).
  - **Daga · Puñalada certera** (`resources/abilities/punalada.tres`): 1 tajo 1.6× (2 dual) con
    Sangrado **garantizado** por golpe, **+ 50% de un 2º Sangrado si el golpe es CRÍTICO**
    (`StatusApplication.solo_crit`; premia el crítico alto de la daga). *Todo o nada* (si te
    esquivan, pierdes el golpe entero). 22 EN (34 dual). Contraste directo con Ráfaga.
  - **Escudo · Golpe de escudo** ×3 tamaños (`golpe_escudo_*.tres`): 1 golpe contundente 1.0×,
    stun 30% + guardia 1 turno (v1: coge el daño del arma principal).
  - **Espada corta** (versátil/táctica, contraste al azar de la daga):
    - **Tajo quebrantador** (`tajo_quebrantador.tres`): 1 tajo 1.4× (2 dual) + **Vulnerable** 75%
      (enemigo recibe más daño 3 turnos). Abridor táctico. 24 EN (36 dual).
    - **Doble tajo** (`doble_tajo.tres`): combo fiable de 2 tajos 0.9× (3 dual), sin estado, barato
      (18 EN / 28 dual). DPS consistente, el "pan de cada día".
  - **Espada larga** (mandoble de 1 mano, sin dual, hecho para *sword & board*): 2 normales + 1
    combinada con escudo (a petición del usuario, es el arma que más se combina con escudo):
    - **Tajo pesado** (`tajo_pesado.tres`): 1 golpe 1.9×, daño puro. El mazazo. 24 EN.
    - **Tajo desarmante** (`tajo_desarmante.tres`): 1 golpe 1.3× + **Débil** 70% (enemigo pega más
      flojo 3t). Setup defensivo (la corta da Vulnerable ofensivo; la larga, Débil defensivo). 22 EN.
    - **Guardia rota** (`guardia_rota.tres`, `requiere_escudo`): combo escudo+espada, 2 golpes 1.2×,
      **Aturdido** 45% + guardia 1 turno. Remate del sword&board. 28 EN.
  - **Maza pequeña** (contundente = control; 2 normales + 1 con escudo): dos sabores de control:
    - **Golpe demoledor** (`golpe_demoledor.tres`): 1 mazazo 1.4× (2 dual) + **Aturdido** 45% por
      golpe. Control por azar (stun = pierde turno). 28 EN (42 dual), cd 2.
    - **Rompepiernas** (`rompepiernas.tres`): 1 golpe 1.25× (2 dual) + **Lento** 80% (−25% vel 3t).
      Control sostenido/fiable (le robas turnos de ATB aunque no salte el stun). 26 EN (40 dual), cd 2.
    - **Aplastamiento** (`aplastamiento.tres`, `requiere_escudo`): combo escudo+maza, 2 golpes 1.15×,
      **Aturdido 55% + Vulnerable 60%** + guardia 1 turno. Lockdown del mace&board. 36 EN, cd 3.
  - **Espadón / Mandobles** (2 manos: sin dual ni escudo → 2 normales; daño bruto + compromiso):
    - **Tajo devastador** (`tajo_devastador.tres`): 1 golpe 2.3×, daño puro. El nuke más grande.
      Todo o nada (lento + cd 3). 36 EN, cd 3.
    - **Molinete** (`molinete.tres`): giro de 2 tajos 1.2× con **Sangrado** 50%/golpe. Reparte el
      riesgo en 2 esquivas y deja heridas. 32 EN, cd 2.
  - **Hacha grande** (2 manos: 2 normales; desgarra-armaduras + hachazo brutal, con combo interno):
    - **Hendedura** (`hendedura.tres`): 1 golpe 1.6× + **Vulnerable REFORZADO** 80% (**−30% def**,
      vs −20% normal; `StatusApplication.mult=0.70`). Abridor que raja de verdad. 32 EN, cd 2.
    - **Hachazo brutal** (`hachazo_brutal.tres`): 1 golpe 2.1×, daño puro. Remate tras abrir con
      Hendedura. 36 EN, cd 3.
  - **Martillo grande** (contundente 2 manos, el más lento y aturdidor: daño demoledor + CC pesado):
    - **Golpe sísmico** (`golpe_sismico.tres`): 1 golpe 2.0× + **Aturdido** 55%. Firma: pega como
      espadón y atonta. 38 EN, cd 3.
    - **Onda expansiva** (`onda_expansiva.tres`): 1 golpe 1.3× + **Aturdido 50% + Lento 70%**.
      Concusión (quita turno y luego ralentiza); control más frecuente. 32 EN, cd 2.
  - **Bastón** (mago, 2 manos: pega poquísimo → kit de gestión de recursos, no de daño):
    - **Canalizar** (`canalizar.tres`): UTILIDAD pura (no golpea, `dano_mult 0`): **gasta TODA la
      energía** y da **1 maná por cada 12.5 EN** (`energia_a_mana=12.5`; 103 EN → 8.24 maná). Ratio
      bajo a propósito: el mago apenas gasta energía y ya hay regen base → colchón, no maná infinito.
      cd 2. Solo disponible con EN ≥ 12.5 (al menos 1 de maná). El sobrante sobre `max_mp` se pierde.
    - **Bastonazo** (`bastonazo.tres`): golpe físico flojo (1.6× sobre MV 0.4) + **Lento 60%**.
      La opción física cuando andas corto de maná; el Lento da tiempo al mago frágil. 16 EN, cd 1.
  - **Varita** (`varita.tres`, off-hand del mago híbrido): también trae **Canalizar**
    (`canalizar_varita.tres`) pero a **peor ratio (18:1** vs 12.5 del bastón), porque es de soporte
    y se lleva con otras armas. `WandData` ahora tiene `habilidades` y entra en el bucle que las
    junta (`game.gd`, junto a WeaponData/ShieldData). cd 2.
  - **Nuevo en AbilityData**: `mana_gain` (maná fijo), `energia_a_mana` (gasta toda la EN → maná a
    ese ratio) y habilidades de UTILIDAD pura (`dano_mult 0` → no golpean). `_usar_habilidad` salta
    el bucle de golpes y `_accion_habilidad` muestra "toda EN → X MP".
  - **Estoque** (`estoque.tres`, sustituye al hacha de mano: enum `HACHA_MANO → ESTOQUE`, idx 5).
    Duelista fino/perforante (MV 0.75, vel 1.2, crit 0.12, corte); en `_dev_weapons`/`_dev_offs`.
    Distinto de la daga (sangrado/ráfaga) → identidad anti-armadura:
    - **Estocada penetrante** (`estocada_penetrante.tres`): 1.6× (2 dual) + **Vulnerable −25%** 70%
      (`mult=0.75`, perfora la guardia). 26/40 EN, cd 2.
    - **Fintas** (`fintas.tres`): 2 estocadas 0.9× (3 dual), sin estado; DPS fiable apoyado en el
      crítico alto. 20/30 EN, cd 1.
- **ROSTER COMPLETO**: las 9 armas (+ estoque = 10) y el escudo tienen kit. Cierra el grueso de KAN-57.
- Visión futura (no ahora): repertorio amplio desbloqueable, equipar/ordenar hasta 4 habilidades.
  "Imbuir veneno" → objeto futuro (viales), no habilidad.

### Rebalance de economía: núcleos, recolección, madera y fundido 🔧 A PROBAR
Plan en `~/.claude/plans/vale-jefazo-hay-que-quizzical-crane.md`. Salió todo del playtest.
Herramienta: `scripts/core/econ_test.gd` (headless, imprime las curvas para el Excel):
`godot --headless --script scripts/core/econ_test.gd`.

- **Coste de núcleos: reinicio por escalón.** Era acumulativo GLOBAL (`mejoras+1`), y como el
  núcleo marca el techo, al llegar al +3 te forzaba a cambiar de núcleo Y te cobraba 4 del nuevo.
  Llegar al +7 pedía **13 núcleos de slime de fuego** (bicho 1/50, drop 5%). Ahora cada núcleo
  cubre una BANDA (`MaterialData.mejora_min`..`mejora_max`) y dentro de ella la cuenta empieza en
  1: slime 1/2/3 (+1..+3), venenoso 1/2 (+4,+5), fuego 1/2 (+6,+7). **13 → 3.**
- **Drops:** núcleos 5% → **10%**, babas 25% → **30%**, cuero de rata 30% → **40%**. El rey rata
  estaba a 0.35/0.05 siendo un BOSS (el rey slime a 1.0/1.0): olvido, ahora 1.0/1.0.
- **Mochila** 3/4/6 → **3/3/6**.
- **Minijuegos, dos problemas.** (1) La dificultad capaba la VELOCIDAD por abajo a 0.6-0.7, así
  que cuanto mejor eras más LENTO iba el marcador. Suelo común `RECOLECCION_VEL_RETO_MIN = 1.0`:
  la velocidad base es el mínimo. (2) Las exigencias eran de 25-70 **cuando al piso 5 rondas los
  300 de stat** → reto ~0.2, el minijuego no existía. Se anclan a la curva (**~0.8 × stat esperada
  en su piso**, stat ≈ 60×piso): hierba 40, raíz 140, sanguinaria 230; cobre 30, hierro 350,
  acero 650; maderas 30/350/650. `RECOLECCION_PISO_FACTOR` 1.08 → 1.10.
  Si mañana cambia la curva de stats, las exigencias se **recalculan desde ella**, no se parchean.
- **Plantas por piso** (usaban la misma en todos lados y las dos pociones mejoradas pedían hierba):
  base → hierba (p1), **+1 → raíz amarga (p2)**, **+2 → sanguinaria (p4, NUEVA)**. La hierba sigue
  saliendo en todos los pisos: es la de la poción base y no quiero obligarte a subir. Densidad 10 → **5**.
- **MADERA** (`MaterialData.Tipo.MADERA`, al final del enum: se guarda como número). Enredaderas en
  la pared de los PASILLOS, 5 por piso. Tres tiers en espejo con los minerales: común p1, dura p6,
  negra p11. Es el **MANGO** del arma (antes llevaba empuñadura de cuero, que no tenía sentido).
- **Minijuego de TALADO** (`scripts/ui/talado.gd`) con **HACHA** y **AGILIDAD** — NO Fuerza: entre
  picar y talar la Fuerza se dispararía, y la Agilidad no tenía ninguna fuente fuera del combate.
  Va de **COMPÁS**: el tronco es un punto FIJO y lo que se mueve es la VENTANA, que da vueltas.
  Cada vuelta pide un hachazo; dentro = limpio y el ritmo ACELERA, fuera (o dejarla pasar) = pierdes
  el compás, +1 astilla y la ventana **ENCOGE**. 3 astillas = tronco rajado. Bola de nieve.
- **ADAMANTE → ACERO** (cobre → hierro → acero). El adamante suena a fin del juego, no a piso 11:
  se reserva para un tier ~10. Y los tiers se van al FONDO: hierro p3 → **p6**, acero → **p11**
  (tenías T2 a los diez minutos y estaba roto).
- **La fibra tiene que estar a la altura del metal** (`Forge.cuero_vale_para` / `madera_vale_para`):
  - ARMA = lingote + madera de su tier → **SÍ** sube de tier (la madera tiene 3, y la dura sale en
    el p6, justo donde el hierro).
  - ARMADURA = chapa + cuero de su tier → el único cuero que existe es el de rata (T1), así que la
    **armadura T2/T3 queda SIN FORJAR**. Es a propósito: son las piezas que estaban rotas. La regla
    ya estaba escrita y apagada en `forge.gd`; se desbloqueará sola el día que un bicho hondo suelte
    una piel mejor. (Cierra la memoria `pieles-por-tier-pendiente`.)
- **Mejorar cuesta núcleos Y material**: el núcleo es el permiso, pero la pieza hay que rehacerla
  (metal + su fibra, del tier de la pieza, subiendo con el nivel). Sin selector de calidades: la
  rareza ya está echada, así que meter material bueno no daría nada. Gasta la morralla.
- **La forja ya no spoilea**: listaba los tres metales desde el minuto uno. Ahora un metal aparece
  cuando te traes algo de él (`Game.materiales_vistos`, persistido; las partidas viejas lo
  reconstruyen de lo que tengan en el baúl).
- **DESHACER equipo** (pestaña nueva del herrero): recuperas la **mitad** de lo que costó hacerlo,
  núcleos incluidos. Se DERIVA de la receta, no de lo que metiste: así funciona igual con equipo
  comprado y con partidas viejas, sin tocar el save. Vuelve como material NORMAL (chatarra
  reaprovechable, no material de primera). Comprobado que **no** es una imprenta de dinero: una daga
  cuesta 350 y fundirla devuelve un lingote normal (~63).
- **Bugs cazados de paso:** `_uds_calidad()` daba **0 unidades al material PURO** (el premio de la
  Metalurgia alta) mientras `unidades_crafteo()` le daba 4 → el mejor material del juego no valía
  nada al forjar. `HERB_VEL_MAX` estaba declarado como techo y **nunca se aplicaba**.
- Números PROVISIONALES → Excel. Falta playtest de verdad.

### Rareza que se nota, crafteo base gratis, respawn por tiempo y mapa 🔧 A PROBAR
Plan en `~/.claude/plans/vale-jefazo-hay-que-quizzical-crane.md`. Cuatro cosas del playtest.

- **La RAREZA por fin se nota** (`upgrades.gd`). Antes iba de común 1.00 a obra maestra 1.15 y
  solo tocaba el raw del arma y la DEF: una daga obra maestra daba el MISMO crítico que una común,
  y una mejora rendía igual en las dos. Ahora:
  - Curva **1.00 → 1.55**.
  - Multiplica TODAS las stats de combate: cada una = `(base_arma + aporte_mejoras) × rareza`.
    `weapon_mods` las devuelve resueltas (claves nuevas `crit`/`evasion`/`aturdir`/`bloqueo`);
    `_hand_from`/`loadout_mods` dejan de leer los campos crudos del `.tres`.
  - Las MEJORAS rinden más en rarezas altas: sus TOPES (rapidez, evasión, resist.crit, potencia,
    eficiencia, celeridad, regen, resist.estados) escalan con la rareza (`Upgrades.cap_rareza`).
    El clamp agregado de armadura usa la mayor rareza equipada.
  - Armadura: evasión / resist.crit / resist.estados escalan con rareza; reducción y velocidad NO
    (son de tipo). **NO toca el `motion_value`** del arma ni la velocidad base por tamaño.
  - Cuidado cazado: el crítico de las contundentes es NEGATIVO a propósito. `mejor_con_rareza()`
    sube lo positivo y **suaviza lo negativo hacia cero** (una maza obra maestra no critica PEOR
    que una común). Verificado en `econ_test.gd` (sección "LA RAREZA SE NOTA").
  - **Fix de display**: la evasión de la daga/estoque no se veía en ningún sitio (sí funcionaba).
    Ahora la ficha del arma muestra "Evasión" y las stats del personaje "Prob. esquiva".
- **Crafteo T1 de serie** (`metales_forja_conocidos`): el cobre (T1) se enseña siempre; solo
  hierro/acero (T2/T3) se descubren al traerlos. Aprender la forja base no debe pedir picar antes.
- **Respawn de recursos por TIEMPO** (adiós al farmeo hacker de saltar de piso para resetear):
  - `Game.tiempo_mazmorra` (reloj de expedición, solo corre jugando; el árbol se pausa en combate).
    Persiste en el save. No se trampea cerrando el juego ni tocando la hora del PC.
  - **`Game.mazmorra_persistente[piso] = {agotados, zonas_vistas}`**, SEPARADO de `memoria_pisos`
    a propósito: la bandera `recordado` es `memoria_pisos.has(piso)` y si dejara ahí el piso,
    dejaría de poblarse de bichos. `olvidar_mazmorra()` NO lo toca (dura entre expediciones).
  - `agotados` pasa de `{celda: true}` a `{celda: tiempo}`. Un nodo reaparece `RESPAWN_SEGUNDOS`
    (~600s de juego) después de picarlo, cada uno por su cuenta. Densidad **5 → 8** por tipo.
  - Tecla dev **N**: +10 min al reloj (probar respawn sin esperar).
- **MAPA con la tecla M** (`scripts/ui/map_menu.gd`): niebla por sala/pasillo (`zonas_vistas`, se
  marca en el `_process` del piso al pisar cada zona; persiste). Dibuja lo explorado con sus nodos:
  vivos con el color del material, agotados apagados con los minutos que faltan, y el jugador. Solo
  en la mazmorra. M añadida al panel F1.
- Números PROVISIONALES → Excel (curva de rareza, RESPAWN_SEGUNDOS, densidad 8).

### Consistencia de menús: ficha de arma y feedback de crafteo unificados 🔧 A PROBAR
- **Ficha de arma en UN solo sitio**: `MenuScaffold.filas_arma(w, tier, rareza, mejoras)` devuelve
  `[[etiqueta, valor]...]` desde `Upgrades.weapon_mods` (la math del combate). La usan tienda,
  pack inicial e inventario; añadir una stat se hace ahí y punto. El menú de personaje mantiene su
  ficha "rica" (desglose base+mejora). Antes había 3 copias y al meter la evasión solo se actualizó
  una: la tienda salía con `<null>`, el inventario sin evasión e ignorando las mejoras.
- **Los tres menús de crafteo dan feedback igual**: forja/peletero/botánica usan la línea de aviso
  del scaffold (`m["aviso"]` + `MenuScaffold.decir`). La botánica no la capturaba; ahora dice
  "Fabricas N × …". `Game.craftear_con` devuelve el total fabricado (era bool).
- Regla para el futuro: los menús que hacen lo mismo comparten helper; nada de copiar la ficha o el
  aviso en cada uno.

### Forja: mango de madera + agarre de cuero (y el bastón, casi todo madera) 🔧 A PROBAR
- El coste de forja pasó de "metal + 1 fibra" a una **lista de ingredientes** (`Game.ingredientes_forja`),
  fuente única de la que tiran `forja_valida`/`score_forja`/`forjar`/la UI/`fundir` (2 o 3 materiales,
  mismo bucle, sin casos especiales). Mezclas en `Forge` (`MIX_ARMA`/`MIX_ARMA_MAGICA`/`MIX_ESCUDO`):
  - Arma normal = lingote (hoja) + madera (mango) + poco cuero (agarre).
  - Arma mágica (bastón/varita) = **casi toda madera** + algo de metal (contera) + cuero. Bastón T1: madera 6, metal 2.
  - Escudo = metal + cuero (correas). Armadura = chapa + cuero (igual).
- Madera del mango = del **tier del metal**; cuero del agarre = **cuero base, sin tier** (forrar un mango
  lo hace cualquier piel → las armas suben de tier sin problema). La armadura mantiene su cuero
  estructural por tier (T2/T3 sigue bloqueada). Fundir devuelve los mismos materiales, a la mitad.
- El botón **Auto** de la forja coge lo **mejor** primero (en la forja la calidad sube la rareza).
  Las **mejoras** siguen gastando lo **peor** (`_consumir_unidades`): ahí la calidad no afecta.
- **Recorte determinista**: lo que sobra de gastar de más vuelve al Hogar como material **dañado**
  (1 ud sobrante = 1 dañado), sin tirada. Murió el mecanismo probabilístico y su clase entera
  (`crafting.gd`/`Crafting`, `Forge.prob_devolver`, `MEZCLA_ACTIVA`). `Game._tirar_devolucion` lo hace.
- Números PROVISIONALES → Excel.

### Rebalance de habilidades: caras, CD alto y que viaja entre combates 🔧 A PROBAR
Eran spammeables (sobre todo las pesadas de 2 manos: cabían ~3 seguidas y el CD se reiniciaba cada combate).
- **Coste** muy arriba, sobre todo 2 manos: nukes **65-70** EN (con la barra ~100-130 tiras uno y a
  reconstruir), medias/setups 40-52. El **dual casi como una pesada** (Ráfaga 64, Puñalada 62…): mete
  más golpes, paga por ello.
- **Básicos regeneran 12 → 28**: pegar básico es la recarga real (ritmo habilidad → básicos → habilidad).
- **CD +2 a todo el daño**: fillers 1→3 (Fintas/Doble tajo/Bastonazo dejan de spammearse), estándar 2→4,
  nukes 3→5. Foco arcano y En guardia (utilidad) sin CD.
- **El CD viaja entre combates** (`Game.ability_cooldowns_persist`): baja 1 por combate que empiezas +
  por turno dentro. Runtime, se pone a cero en partida nueva (no va al save; los CD son efímeros).
- Números PROVISIONALES → Excel.

### Planificado a futuro (Epics creados, sin empezar)
- **KAN-51** Combate avanzado: críticos (Destreza), evasión (Agilidad),
  defender/bloqueo, sistema de acciones, magia+maná (.tres), habilidades, estados.
- **KAN-59** Multi-enemigos y compañeros (en combate y siguiéndote por la mazmorra).
- **KAN-65** Descanso y repoblado: respawn de enemigos + acampar para recuperarse.
- (Y la mazmorra de muchos pisos: ver memoria "dungeon-pisos".)

**Pendientes futuros (Epics en Jira, sin empezar):**
- **KAN-51** Combate avanzado: críticos (Destreza), evasión (Agilidad),
  defender/bloqueo, sistema de acciones, magia+maná (.tres), habilidades, estados.
- **KAN-59** Multi-enemigos y compañeros (en combate y siguiéndote por la mazmorra).
- **KAN-65** Descanso y repoblado: respawn de enemigos + acampar para recuperarse.
- **KAN-73** Mochila (extra_capacity) que sumas al zurron.
- **KAN-83** Inventario tipo Minecraft (grid, drag&drop).
- **KAN-84** Rediseñar Fuerza-por-peso (desactivada; Gain_FUERZA_PESO=0).
- Subir de NIVEL: resetea habilidades a 0 pero anterior queda fijado como bonus (diseño guardado, NO tocar).
- Mazmorra de muchos pisos (dificultad escala por fórmula con profundidad).

Nota: placeholders cuadrados (ColorRect) por ahora; lo visual/animaciones, al final.
Recordatorio: Town es ahora la escena por defecto; si arrancar en mazmorra, cambiar a `main.tscn` en Ajustes.
