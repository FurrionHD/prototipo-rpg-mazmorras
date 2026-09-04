# ============================================================
#  dev_inventario.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el INVENTARIO de verdad (scripts/ui/inventory_menu.gd) con la bolsa y el baul llenos de
#  cosas inventadas, y saca una captura de CADA pestaña. Es la unica forma de juzgar la pantalla:
#  el visor de celdas enseña la pieza suelta, pero lo que hay que mirar aqui es el conjunto --
#  cuanto respira la rejilla, si la ficha de la derecha cabe, si las pestañas de arriba se leen.
#
#  Se llena a mano y no se carga una partida guardada a proposito: hace falta que salgan LOS OCHO
#  peldaños de rareza y las cinco clases de consumible a la vez, y una partida real casi nunca los
#  tiene todos. Ademas asi la captura es siempre la misma y dos versiones se pueden comparar.
#
#  Va CON VENTANA (nada de --headless): un Control no se coloca ni se dibuja sin superficie de
#  render, y en headless la captura sale en negro.
#
#  Y con process_mode = ALWAYS: el inventario PAUSA el arbol al abrirse (Game.abrir_menu), asi que
#  sin esto el propio visor se congela en el primer await y no llega a capturar nada.
#
#  Doble clic en herramientas/ver_inventario.bat, o:
#    godot --path . res://tools/visores/dev_inventario.tscn
#  Guarda tools/salida/inventario_<n>_<pestaña>.png y se cierra solo.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const MATS := ["cobre", "cobre_veteado", "cobre_profundo", "acero", "madera_comun", "madera_negra",
	"cuero_simple", "cuero_curtido", "baba_slime", "baba_venenosa", "nucleo_slime",
	"nucleo_minotauro", "carbon_veta", "carbon_negro", "ajo", "cebolla"]
const CONS := ["pocion_menor", "pocion_media", "pocion_mana_menor", "pocion_mana_media",
	"grimorio_bola_fuego", "grimorio_rayo", "plato_kebab_bestia", "plato_sopa_setas",
	"cebo_gusano", "piedra_retorno"]
const ARMAS := ["daga", "espada_corta", "espada_larga", "mandobles", "hacha_grande", "baston",
	"estoque", "maza_peq"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_llenar()

	var inv: CanvasLayer = preload("res://scripts/ui/inventory_menu.gd").new()
	add_child(inv)
	inv._set_open(true)

	DirAccess.make_dir_recursive_absolute(SALIDA)
	for i in inv.TABS.size():
		inv._on_tab(i)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var ruta: String = "%sinventario_%d_%s.png" % [SALIDA, i,
			String(inv.TABS[i]).to_lower()]
		get_viewport().get_texture().get_image().save_png(ruta)
		print("[inventario] ", ProjectSettings.globalize_path(ruta))
	get_tree().quit()


# ============================================================
#  LLENAR LA PARTIDA
# ============================================================

func _llenar() -> void:
	Game.money = 48210
	Game.crystals = []
	Game.materiales = []
	Game.almacen_materiales = []

	# La BOLSA: cristales de varias calidades y un puñado de materiales de cada escala.
	for cat in [1, 2, 3, 5]:
		for cal in [Cristal.Calidad.INTACTO, Cristal.Calidad.NORMAL, Cristal.Calidad.DANADO]:
			for _n in 3:
				var cr := Cristal.new()
				cr.categoria = cat
				cr.calidad = cal
				Game.crystals.append(cr)
	var i: int = 0
	for id in MATS:
		var d: MaterialData = load("res://resources/materials/%s.tres" % id) as MaterialData
		if d == null:
			continue
		i += 1
		# Cantidades MUY distintas entre montones (de 1 a 400): es lo que enseña si la banda del pie
		# aguanta un "x412" sin que el numero se salga ni se encoja.
		for _n in (i * 7) % 40 + 1:
			var it := MaterialItem.new()
			it.data = d
			it.calidad = MaterialItem.Calidad.NORMAL
			Game.materiales.append(it)
		# El HOGAR (pestaña Materiales) con lo mismo pero en cantidades mayores.
		for _n in (i * 23) % 300 + 5:
			var it2 := MaterialItem.new()
			it2.data = d
			it2.calidad = MaterialItem.Calidad.INTACTO
			Game.almacen_materiales.append(it2)

	Game.consumables = {}
	var j: int = 0
	for id in CONS:
		var c: ConsumableData = load("res://resources/consumables/%s.tres" % id) as ConsumableData
		if c == null:
			continue
		j += 1
		Game.consumables[c] = (j * 5) % 47 + 1

	_armas()
	_armaduras()


# Las armas con LAS OCHO RAREZAS repartidas, que es lo que no sale en una partida normal y es justo
# lo que hay que mirar: si los ocho fondos se distinguen puestos uno al lado del otro.
func _armas() -> void:
	Game.owned_weapons = []
	var r: int = 0
	for id in ARMAS:
		var w: WeaponData = load("res://resources/weapons/%s.tres" % id) as WeaponData
		if w == null:
			continue
		var copia: WeaponData = w.duplicate() as WeaponData
		Game.item_meta[copia] = {"tier": (r % 3) + 1, "rareza": r, "mejoras": {},
			"durabilidad": 1.0 - float(r) * 0.09, "banda": 0}
		Game.owned_weapons.append(copia)
		r += 1


func _armaduras() -> void:
	Game.owned_armor = []
	var d := DirAccess.open("res://resources/armor/")
	if d == null:
		return
	var r: int = 0
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var a: ArmorData = load("res://resources/armor/" + f) as ArmorData
		if a == null:
			continue
		var copia: ArmorData = a.duplicate() as ArmorData
		Game.item_meta[copia] = {"tier": (r % 3) + 1, "rareza": r % 8, "mejoras": {},
			"durabilidad": 1.0, "banda": 0}
		Game.owned_armor.append(copia)
		r += 1
		if r >= 20:
			return
