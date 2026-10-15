# Auditoría de rendimiento (13/10/2026)

Hecha leyendo el código, en cuatro frentes: datos y guardado, pantallas, lo que corre en partida y los 235 mensajes de
red. Las líneas son las del 13/10 (pueden haberse movido algo). El plan que sale de aquí está en la memoria
`plan-optimizacion-total`. Gravedad: **A** se nota (tirón, bajada de FPS, espera), **M** gasto constante, **B** poco.

## 0. Arranque del juego (medido el 15/10)
- **6,3 s antes de enseñar nada.** Sin autoloads el proyecto arranca en 0,1 s: todo el tiempo es de cargar los
  autoloads. `game.gd` sola, 4,4 s: al nombrar cientos de clases Godot compila casi todo el código de golpe.
- Dentro de eso, `combat.tscn` precargada en `game.gd` cuesta 1,3 s; `net.gd` 1,1 s; `mundos.gd` 0,8 s.
- Lo pagan el juego al abrirse y **cada prueba de integración** (~95 × 6 s solo de arrancar).

## 1. Fallos de verdad
| Qué | Dónde |
|---|---|
| Fuga en `item_meta`: `crear_item(registrar=false)` la escribe igual y acaba en el save. Pasa en cada repintado del roster, cada `aplicar_aspecto` remoto y cada maniquí del espejo | `game.gd:9561-9570`, `10064-10081`, `3015-3019`; `net_hogar.gd:859`; `remote_player.gd:139`; `combat_espejo.gd:148` |
| La misma fuga en las cachés del cofre | `hogar_almacen.gd:262,730`; `tienda_vender.gd:82`; `hogar_encargos.gd:849` |
| Un montón del suelo vuelve con cantidad 1 al cambiar de piso (no se guarda `cantidad`) | `dungeon_floor.gd:2617-2620`, `2679-2681` |
| `Control.new()` en cada dibujo que nunca se libera | `maestro_menu.gd:706` |
| Un enemigo que entra en la oscuridad sigue visible si tú estás quieto | `niebla.gd:205,326` |
| `_difundir_almacen` no lo llama nadie | `net_hogar.gd:1279` |

## 2. Datos y guardado
| Problema | Dónde | Grav. |
|---|---|---|
| Un `MaterialItem` por unidad en bolsa, baúl y carbonera (~19.000 en el baúl real). Solo la BD los cuenta | `game.gd:5215,5218,5232` | A |
| Cristales por unidad (≈40 combinaciones posibles) | `game.gd:5211` | M |
| Cobrar un encargo expande el botín contado en N objetos | `game.gd:5769-5778`, `encargos.gd:1269-1293` | A |
| Mover montones O(n²) (`erase` dentro del bucle + texto por unidad) | `game.gd:10204-10244`, `10356` | A |
| Soltar de uno en uno: un pickup por unidad | `game.gd:13343-13365` | M |
| Tres copias de `_agrupar` con un texto por unidad en cada repintado | `inventory_menu.gd:549`, `hogar_almacen.gd:293`, `tienda_vender.gd:368` | M |
| Peces con `cm` exacto: casi nunca se cuentan juntos | `material_item.gd:26` | M |
| Guardado cada 2 s: `exportar_partida()` copia todo con `duplicate(true)` | `profile.gd:29,355`; `game.gd:2880-3117` | A |
| La foto PNG de cada personaje se reescribe como texto en cada guardado | `bd_filas.gd:96`, `personaje_data.gd:33` | A |
| `PartidaBD._ultimas` guarda todas las filas en texto para comparar | `partida_bd.gd:174,225` | M |
| `duplicate(true)` al cargar lo que acaba de construirse | `game.gd:3752-3914` | M |
| En modo mundo la bolsa se guarda dos veces | `game.gd:2982` + `3116` | M |
| `set_meta("sin_fuelle")` por frame que acaba en el save | `player.gd:2389` | B |
| Libreta del mapa: listas de `Vector2i` por celda, por triplicado | `game.gd:2311`; `net_mapa.gd` | A |
| `volcar_a_memoria` del piso en cada guardado | `dungeon_floor.gd:2559` | M |
| Arena: tres pasadas de la foto por guardado | `game.gd:2644` | M |
| `meta_de()` crea meta para cualquier objeto (también materiales) | `game.gd:6631` | M |

## 3. Cachés que faltan (se recalcula cada frame)
| Qué | Dónde |
|---|---|
| Peso y capacidad: ~5 recorridos de la bolsa por frame (HUD + jugador) | `hud.gd:755-770`; `player.gd:456`; `game.gd:9510,13474` |
| Vida y maná máximos: `Abilities.new()` por miembro y frame | `player.gd:2387`; `game.gd:7121` |
| `armor_mods` rehecho cada frame | `game.gd:9392` |
| Luz del farol: recorre la carbonera cada frame | `game.gd:6492`; `hud.gd:723` |
| `add_theme_color_override` cada frame | `hud.gd:727` |

## 4. Pantallas
| Problema | Dónde | Grav. |
|---|---|---|
| Cada retrato es un `MunecoJugador` vivo (~35 sprites, un material por capa) y se rehacen todos en cada clic. Personaje, maestro, altar, talleres, taberna, hogar | `menu_scaffold.gd:2685-2787` | A |
| Lo mismo en la barra de turnos y en el detalle de combate | `retrato_combate.gd:83`; `combate_detalle.gd:316` | A |
| Un clic rehace la pantalla entera (y reagrupa el baúl de 19.000) | `inventory_menu.gd:537`; `shop_menu.gd:448`; `hogar_almacen.gd:565`; `taller_menu.gd:344,431`; `character_menu.gd:440,501`; `combate_detalle.gd:255` | A |
| Muñeco grande nuevo en cada rebuild | `character_menu.gd:787`; `hogar_equipo.gd:188`; `altar_menu.gd:340` | A |
| `quien_lleva` por objeto (plantilla × 7 huecos) | `inventory_menu.gd:1103` | A |
| Orden con claves rehechas en cada comparación | `inventory_menu.gd:1384,1471` | M |
| Rejillas sin virtualizar; una conexión al scroll por celda | `menu_scaffold.gd:2230`; `celda_objeto.gd:152` | M |
| ~30 menús creados en cada escena aunque no se abran; el debug panel entero en `_ready` | `player.gd:252-295`; `debug_panel.gd:90` | A |
| `Net.hogar_cambiado` rehace el hogar entero | `home_menu.gd:76` | A |
| Imágenes sin caché | `retrato_combate.gd:62`; `combate_detalle.gd:541`; `fishing_book_menu.gd:195`; `multi_menu.gd:285` | M |
| `ShaderMaterial` nuevo por celda | `retrato_pieza.gd:98` | M |
| Chips de la ficha de objetivo cada frame | `combat.gd:1488` | M |
| Maestro: grimorios, plantillas y libros cargados en cada dibujo o rebuild | `maestro_menu.gd:282,688,2259` | M |
| Mapa: un `draw_rect` por celda | `map_menu.gd:292` | B |

## 5. Lo que corre en partida
| Problema | Dónde | Grav. |
|---|---|---|
| Separación entre enemigos O(N²) por frame | `enemy.gd:2035` | A |
| Esquivar paredes: hasta ~48 rayos por enemigo y frame | `enemy.gd:1122-1291` | A |
| Lista de aliados y exclusiones rehechas por cada rayo | `enemy.gd:1035,1084` | M |
| Detectar cada frame | `enemy.gd:803` | M |
| Buscar corro: O(N²) | `enemy.gd:2110` | M |
| `dist_congelar` 1400 px: casi todo el piso sigue con IA | `dungeon_floor.gd:145` | M |
| Grietas de pared: `set_pixel` y textura nueva ~170 veces por reparación | `wall_crack_fx.gd:509` | A |
| Un `ShaderMaterial` por capa de muñeco: cientos de draw calls en el pueblo | `muneco_jugador.gd:223,653` | A |
| `MunecoJugador._process` reescribe todas las capas aunque no cambie el fotograma | `muneco_jugador.gd:891` | M |
| `_ordenar_munecos` cada frame con dos grupos y `sort_custom`; `node_added` global | `game.gd:6258,6189` | M |
| 4 SubViewport de vendedores con `UPDATE_ALWAYS` | `vendedor_mercadillo.gd:63` | A |
| ~75 `PiezaPueblo` con 2 `get_nodes_in_group` por frame | `pieza_pueblo.gd:139` | M |
| Luces del pueblo ordenadas cada frame; un material por halo | `luz_pueblo.gd:85,142` | M |
| Humo, antorchas y partículas simulando fuera de pantalla | `town.gd:280`; `antorcha.gd`; `resource_node.gd:307` | M |
| Visión: limpia y sube texturas del piso entero; un barrido completo por ojo | `vision.gd:146,174,505` | M |
| `combat.tscn` instanciada en cada pelea | `game.gd:15529,15686` | A |
| `ArenaCombate` redibuja cada celda cada frame | `arena_combate.gd:374` | M |
| `cuerpo_de()` con búsqueda lineal, ~20 ticks por frame | `combat_tactico.gd:635,1241` | M |
| FX `*_aire`: un material por capa e instancia | `magia_aire.gd:536` y familia | B |
| Hojas de sprites soltadas al cambiar de escena y recargadas desde JSON (~1-2 s al pueblo) | `game.gd:6175`; `sprite_lienzo.gd:497` | A |
| Muralla, vidrios y cartel dibujados píxel a píxel sin caché | `dungeon_floor.gd:560`; `town.gd:290-336` | M |
| El cuerpo del mutante se carga al mutar | `sprites_enemigo.gd:358` | M |
| Sonidos cargados la primera vez que suenan | `sonido.gd:415` | M |

## 6. Red (235 RPC)
**Cómo viaja todo:** amigo → túnel Steam (probablemente relés de Valve) → **sala a 20 fps** (`sala.gd:29`) →
trabajadores (30 fps peleando, 5 en reserva: `trabajadores.gd:58-59`). Godot mira la red una vez por frame: cada paso
por la sala cuesta 50-100 ms.

**Entrar en combate** (`net_peleas.gd:69-351`): el espadazo entero (0,67-0,8 s, `player.gd:994-1007`) y después
8 viajes en serie para el que ataca y ~14 para el compañero (la zona solo se anuncia cuando el atacante ya tiene su
pantalla: `net_peleas.gd:1355`). Estimado: 1,2-2,5 s el que ataca, 1,8-3,5 s el compañero.

| Clase | Qué | Dónde |
|---|---|---|
| Fotos | Roster de combate: la foto PNG va **dos veces** por aliado (`imagen` y `pj`) | `combat_espejo.gd:191-241` |
| Fotos | Fichas con foto en cada pelea y al unirse | `net_partida.gd:221`; `_abre_mi_pelea`, `_pedir_unirme` |
| Fotos | `_set_grupo`: cada vez que entra alguien todos reenvían su grupo a todos (N² fotos) | `net_jugadores.gd:303-338` |
| Fotos | `_set_aspecto`, `_saludar`, `_presentarse`, `_presentar_ajeno`, `_listo` (también a los trabajadores) | `net.gd`, `net_pisos.gd` |
| Entero | `_set_almacen`: el baúl por unidad, ~2,5 MB | `net_hogar.gd:1038,1284` |
| Entero | `_mi_estado` cada 60 s: fotos, bolsa por unidad, historial del gacha | `net_partida.gd:600-649` |
| Entero | `_instantanea` en cada `_update_hp`, con tooltips y 11 stats derivadas | `combat_espejo.gd:352-434`; `combat.gd:1303` |
| Entero | `_difundir_hogar`: roster, cofre, encargos y formación enteros | `net_hogar.gd:594-622` |
| Entero | Libreta del mapa entera al entrar y al subir | `net_mapa.gd:74,169` |
| Entero | `_entrar_ok` con los agotados de toda la sesión | `net_pisos.gd:430` |
| Entero | `_tick_enemigos`: todos (cadáveres incluidos) a 20 Hz, por encima del tamaño de paquete | `net_enemigos.gd:288-327` |
| Calculable | `facing` que nadie usa en cada posición; uid, nombre y color en cada barra; rutas `.tres` en texto | `net_jugadores.gd:88,599`; `net_pisos.gd:77` |
| A todos | `_spawn_drop`, `_spawn_enemigo`, `_marcar_cadaver`, `_aviso_comer`, `_agotar_celda`, `_set_extrayendo` van a todos, también a otros pisos | `net_suelo.gd`, `net_enemigos.gd`, `net_recoleccion.gd`, `net_extraccion.gd` |
| Canales | Todo por el canal 0: lo gordo bloquea los turnos que van detrás | 222 RPC fiables |

Ya bien hechos, para copiar: `_subir_fotos` / `_set_fotos_roster` (foto una vez por huella), `_atb`, `_impactos`
(empaquetados), los deltas del taller (`_delta_al_host`).

No hay tabla de ids numéricos: todo el contenido viaja por `resource_path`. Hay 614 `.tres`: caben en 16 bits.
