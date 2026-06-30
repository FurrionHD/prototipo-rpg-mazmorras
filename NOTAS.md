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

### Pendiente PRÓXIMO: Fases 6 y 7
- **Fase 6 (KAN-35):** inventario + HUD (mostrar cristales y drops).
- **Fase 7 (KAN-39):** tienda / venta (precio según categoría + calidad).

### Planificado a futuro (Epics creados, sin empezar)
- **KAN-51** Combate avanzado: críticos (Destreza), evasión (Agilidad),
  defender/bloqueo, sistema de acciones, magia+maná (.tres), habilidades, estados.
- **KAN-59** Multi-enemigos y compañeros (en combate y siguiéndote por la mazmorra).
- **KAN-65** Descanso y repoblado: respawn de enemigos + acampar para recuperarse.
- (Y la mazmorra de muchos pisos: ver memoria "dungeon-pisos".)

Nota: placeholders cuadrados (ColorRect) por ahora; lo visual/animaciones, al final.
Pendiente menor: borrar `escena_2d_prueba.tscn` (raíz, sin uso).
Recordatorio: `player.tscn` sigue siendo la escena principal del proyecto;
si se quiere arrancar en el nivel, cambiar a `main.tscn` en Ajustes del proyecto.
