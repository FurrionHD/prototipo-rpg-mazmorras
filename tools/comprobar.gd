# HERRAMIENTA: carga los scripts tocados para que salten los errores de parseo sin tener que
# arrancar una partida entera. No forma parte del juego.
extends SceneTree

const SCRIPTS := [
	# El personaje dibujado por capas, de abajo arriba de la pila de clases: el esqueleto, la
	# fabrica, una capa, el registro y el compositor. Y los tres cuerpos que lo usan.
	"res://scripts/fx/pose_jugador.gd",
	"res://scripts/fx/capa_jugador.gd",
	"res://scripts/fx/cuerpo_sprites.gd",
	"res://scripts/fx/jugador_sprites.gd",
	"res://scripts/fx/muneco_jugador.gd",
	"res://scripts/actors/player/player.gd",
	"res://scripts/actors/player/companion.gd",
	"res://scripts/actors/player/remote_player.gd",
	# Los bichos dibujados por codigo: el motor, el registro que reparte y los generadores.
	"res://scripts/fx/sprite_lienzo.gd",
	"res://scripts/fx/sprites_enemigo.gd",
	"res://scripts/fx/arana_sprites.gd",
	"res://scripts/fx/escarabajo_sprites.gd",
	"res://scripts/fx/ciempies_sprites.gd",
	"res://scripts/fx/terreno_sprites.gd",
	"res://scripts/fx/recolectable_sprites.gd",
	"res://scripts/world/decorado.gd",
	"res://scripts/core/lampara.gd",
	"res://scripts/items/tool_data.gd",
	"res://scripts/items/material_data.gd",
	"res://scripts/core/game.gd",
	"res://scripts/core/save_data.gd",
	"res://scripts/core/jugador_data.gd",
	"res://scripts/world/vision.gd",
	"res://scripts/world/niebla.gd",
	"res://scripts/fx/prop_sprites.gd",
	"res://scripts/town/door.gd",
	"res://scripts/world/dungeon_exit.gd",
	"res://scripts/world/stairs.gd",
	"res://scripts/ui/menu_scaffold.gd",
	# El dibujo de un objeto y la celda que lo enseña. IconoItem lo comparten el SUELO y la
	# cuadricula, asi que un error aqui rompe las dos cosas a la vez.
	"res://scripts/ui/icono_item.gd",
	"res://scripts/ui/celda_objeto.gd",
	"res://scripts/items/drop_pickup.gd",
	"res://scripts/ui/inventory_menu.gd",
	"res://scripts/ui/shop_menu.gd",
	"res://scripts/world/dungeon_floor.gd",
	"res://scripts/world/resource_node.gd",
	# Los cuatro modulos GORDOS, que eran justo los que no estaban aqui: un error de parseo en
	# cualquiera de ellos no lo ve nadie hasta que arrancas una partida y llegas a esa pantalla
	# --y el de red, hasta que ademas hay DOS maquinas delante--. Son los que mas se tocan.
	"res://scripts/net/net.gd",
	"res://scripts/ui/combat.gd",
	"res://scripts/core/encargos.gd",
	"res://scripts/ui/home_menu.gd",
	"res://scripts/actors/enemy/enemy.gd",
	"res://scripts/world/spawn_zone.gd",
	"res://scripts/ui/casteo_mapa.gd",
	"res://scripts/world/fishing_spot.gd",
	"res://scripts/ui/map_menu.gd",
	"res://scripts/ui/debug_panel.gd",
	"res://scripts/ui/touch_pad.gd",
	# La MATH del equipo y los recursos que la alimentan. No estaban, y son los que tocas cada vez
	# que se ajusta el balance: un campo nuevo mal escrito en shield_data o en ability_data no da
	# la cara al cargar el juego, sino al abrir la ficha del objeto que lo usa.
	"res://scripts/core/combatant.gd",
	"res://scripts/core/stats_math.gd",
	"res://scripts/core/upgrades.gd",
	"res://scripts/items/shield_data.gd",
	"res://scripts/items/weapon_data.gd",
	"res://scripts/items/ability_data.gd",
	"res://scripts/items/status_application.gd",
	"res://scripts/core/status_effects.gd",
]

# Los .tres que se cargan a mano para que un campo mal escrito salte AQUI y no en la tienda. Un
# @export que no existe no impide cargar el recurso: Godot se lo traga y lo deja al default, asi
# que un `aggro_mult` mal tecleado se ve como "el escudo grande no atrae mas golpes" tres dias
# despues. Por eso no basta con cargarlos: hay que comprobar el VALOR (ver _comprobar_escudos).
const ESCUDOS := [
	"res://resources/shields/escudo_pequeno.tres",
	"res://resources/shields/escudo_normal.tres",
	"res://resources/shields/escudo_grande.tres",
]

func _initialize() -> void:
	var mal: int = 0
	for r in SCRIPTS:
		var s = load(r)
		if s == null:
			push_error("NO CARGA: %s" % r)
			mal += 1
		else:
			print("  ok  %s" % r)
	mal += _comprobar_slots()
	mal += _comprobar_escudos()
	# Y de paso que el TileSet se monte de verdad (create_tile con celdas repetidas revienta).
	var ts: TileSet = TerrenoSprites.tileset_de("roca")
	var src := ts.get_source(0) as TileSetAtlasSource
	print("TileSet: %d baldosas, atlas %s" % [src.get_tiles_count(), str(src.texture.get_size())])
	print("FIN, %d errores" % mal)
	quit(mal)


# TODA ranura que pueda salir en las subpestañas del herrero tiene que tener nombre. Si falta una,
# forge_menu revienta al pedirla y desaparece la fila ENTERA de subpestañas: el menu se queda
# clavado en la primera y parece que "solo se pueden mejorar las armas". Paso de verdad al meter
# el farolillo, y desde el codigo no se ve -- solo jugando, y ni eso: no da error a la vista.
func _comprobar_slots() -> int:
	var fm = load("res://scripts/ui/forge_menu.gd")
	var g = load("res://scripts/core/game.gd")
	if fm == null or g == null:
		return 0
	var nombres: Dictionary = fm.get_script_constant_map().get("SLOT_NOMBRES", {})
	var equipo: Array = g.get_script_constant_map().get("EQUIP_SLOTS", [])
	var faltan: Array = []
	for s2 in equipo:
		if not nombres.has(s2):
			faltan.append(s2)
	# Las tres que añade _slots_sub por su cuenta y no salen de EQUIP_SLOTS.
	for s2 in ["farolillo", "mochila", "herramienta"]:
		if not nombres.has(s2):
			faltan.append(s2)
	if faltan.is_empty():
		print("  ok  SLOT_NOMBRES cubre las %d ranuras" % (equipo.size() + 3))
		return 0
	push_error("SLOT_NOMBRES no tiene: %s" % str(faltan))
	print("  FALLO  a SLOT_NOMBRES le faltan: %s" % str(faltan))
	return 1


# LOS TRES ESCUDOS TIENEN QUE SER TRES ESCUDOS DISTINTOS. Eran el mismo con otros numeros; ahora
# cada tamaño tiene su papel (rodela duelista / heater guardian / torre defensor) y eso vive
# repartido entre campos del .tres y su lista de habilidades. Dos formas de romperlo en silencio:
#   - un @export mal tecleado: Godot carga el recurso igual y deja el campo al DEFAULT, asi que
#     el escudo grande simplemente "no atrae mas golpes" y nadie se entera;
#   - copiar un .tres sobre otro y dejar la misma lista de habilidades en dos tamaños, que es
#     literalmente el bug que este trabajo viene a arreglar.
# Por eso no basta con que carguen: se comprueba que los VALORES son distintos entre si.
func _comprobar_escudos() -> int:
	var vistos: Dictionary = {}     # aggro_mult -> nombre, para cazar dos tamaños iguales
	var habs: Dictionary = {}       # firma de la lista de habilidades -> nombre
	var faltan: Array = []
	for r in ESCUDOS:
		var sh = load(r)
		if sh == null:
			push_error("NO CARGA: %s" % r)
			faltan.append(r)
			continue
		# Si el campo no existe, get() devuelve null: eso es el @export mal escrito.
		for campo in ["aggro_mult", "contra_prob", "contra_mult"]:
			if sh.get(campo) == null:
				faltan.append("%s: sin campo '%s'" % [r, campo])
		var a: float = float(sh.get("aggro_mult"))
		if vistos.has(a):
			faltan.append("%s y %s tienen el MISMO aggro_mult (%.2f)" % [sh.nombre, vistos[a], a])
		vistos[a] = sh.nombre
		var firma := ""
		for ab in sh.habilidades:
			firma += (ab.resource_path if ab != null else "null") + "|"
		if habs.has(firma):
			faltan.append("%s y %s traen LAS MISMAS habilidades" % [sh.nombre, habs[firma]])
		habs[firma] = sh.nombre
	if faltan.is_empty():
		print("  ok  los %d escudos tienen personalidad propia" % ESCUDOS.size())
		return 0
	for f in faltan:
		push_error("ESCUDOS: %s" % str(f))
		print("  FALLO  %s" % str(f))
	return faltan.size()
