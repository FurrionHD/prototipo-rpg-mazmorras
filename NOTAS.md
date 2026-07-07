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
- [x] Fuerza: cargar peso en sobrecarga. Resistencia: recibir daño×peligrosidad.
  Agilidad: correr cerca de enemigos. Destreza: minijuego de extracción.
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
- Pendiente: KAN-84 rediseñar Fuerza-por-peso (sigue desactivada, `GAIN_FUERZA_PESO=0`).

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
  vida). **Regen por turno escala con la Magia**: `StatsMath.mp_regen() = MP_REGEN_BASE(0.1) +
  Magia×MP_REGEN_PER_MAGIA(0.0002)` (magia 999 → ~0.3/turno). El **altar** (y teclas dev H / debug stats) lo rellenan al
  100%. Se **descuenta al empezar** el casteo (si fallas, se pierde). Pociones en combate → futuro.
  OJO anti-spam: el regen escalado permitiría spamear a Magia alta; se equilibra con los NIVELES de
  hechizo (KAN-96): misma magia en versión cara (Chispa nv2 = 10-12 MP) al subir Magia/nivel.
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
      **fracción baja del ATAQUE del aplicador** (0.15×atk), suma **lineal**. `refresh_all` reservado
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
- **Fuerza del ENEMIGO**: presets Base / 200 / 500 / Cheto → `Game.debug_enemy_stat_override`
  (-1 = stats del `.tres`; >=0 = las 5 habilidades planas). Se aplica en `EnemyData.crear_abilities()`.
- **ARMADURA por pieza**: dropdown Nada/Cuero/Hierro/Hierro compl./Placas + dropdown de TIER
  (T1/T2/T3) al lado, por slot.
- **ARMAS**: dropdowns de principal y secundaria + su TIER (reusa `Game._dev_weapons`/`_dev_offs`,
  `equipar_arma`/`equipar_secundaria`; revierte combinaciones inválidas).
- **PISO**: campo para fijar `Game.current_floor` (escala al enemigo).
- **RAREZA** (dropdown por arma y pieza) + sección **MEJORAS** (elegir slot y repartir
  mejoras por categoría con −/+, según el máximo de la rareza).
- Mientras está abierto, `Game.debug_panel_open` congela al jugador (teclear sin moverse).

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
habilidades gastan** (ver memoria `energia-combate-habilidades`).
- **`AbilityData`** (`scripts/items/ability_data.gd`, `.tres`): las arma/escudo traen sus
  `habilidades`; el loadout las junta en `Combatant.abilities_combate`. Campos: `golpes_min/max`
  (+ `_dual`), `dano_mult` (× básico por golpe), `efectos` (Array[StatusApplication]) con
  `efectos_por_golpe` (tirada por impacto vs una al final; cada `StatusApplication` admite
  `solo_crit` = solo prende si ese golpe fue crítico), `coste_energia` (+ `_dual`),
  `bloqueo_turnos` (deja en guardia), `dano_tipo_override` (-1 arma / 0 corte / 1 contundente),
  `requiere_escudo` (técnica arma+escudo; `Game` la filtra si `equipped_off` no es un escudo).
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
- **Siguiente**: kit de 2 habilidades para el resto (mandoble/hacha grande,
  maza/martillo, hacha de mano, bastón). Enfoque acordado: **arma por arma sobre la marcha**.
- Visión futura (no ahora): repertorio amplio desbloqueable, equipar/ordenar hasta 4 habilidades.
  "Imbuir veneno" → objeto futuro (viales), no habilidad.

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
