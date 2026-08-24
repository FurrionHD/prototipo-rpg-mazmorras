# HERRAMIENTA: carga los scripts tocados para que salten los errores de parseo sin tener que
# arrancar una partida entera. No forma parte del juego.
extends SceneTree

const SCRIPTS := [
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
	"res://scripts/ui/inventory_menu.gd",
	"res://scripts/ui/shop_menu.gd",
	"res://scripts/world/dungeon_floor.gd",
	"res://scripts/world/resource_node.gd",
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
	# Y de paso que el TileSet se monte de verdad (create_tile con celdas repetidas revienta).
	var ts: TileSet = TerrenoSprites.tileset_de("roca")
	var src := ts.get_source(0) as TileSetAtlasSource
	print("TileSet: %d baldosas, atlas %s" % [src.get_tiles_count(), str(src.texture.get_size())])
	print("FIN, %d errores" % mal)
	quit(mal)
