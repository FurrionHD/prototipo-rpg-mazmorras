# PRUEBA: los menus que el jugador crea en CADA escena se montan PEREZOSOS (optimizacion 1D, 16/10/2026): al entrar
# en escena no construyen su interfaz, y al abrirlos por primera vez se construye entera, UNA sola vez.
# Talleres (ver taller_menu.asegurar_ui): boticaria, cocina, herreria, carpinteria, peleteria, runas, pescador, taberna.
# Tienda, hogar, maestro, personaje, pausa, ayuda de teclas (F1) e inventario: su _construir.
extends Node

var fallos := 0

func _ok(c: bool, t: String) -> void:
	print(("[PASA] " if c else "[FALLA] ") + t)
	if not c:
		fallos += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _frames(1)
	var talleres: Array = [
		["boticaria", "res://scripts/ui/craft_menu.gd", ""],
		["cocina", "res://scripts/ui/craft_menu.gd", "cocina"],
		["herreria", "res://scripts/ui/forge_menu.gd", ""],
		["carpinteria", "res://scripts/ui/forge_menu.gd", "carpintero"],
		["peleteria", "res://scripts/ui/tannery_menu.gd", ""],
		["runas", "res://scripts/ui/runas_menu.gd", ""],
		["pescador", "res://scripts/ui/fishing_book_menu.gd", ""],
		["taberna", "res://scripts/ui/tavern_menu.gd", ""],
		["tienda", "res://scripts/ui/shop_menu.gd", ""],
		["hogar", "res://scripts/ui/home_menu.gd", ""],
		["maestro", "res://scripts/ui/maestro_menu.gd", ""],
		["selector de piso", "res://scripts/ui/floor_select_menu.gd", ""],
		["altar", "res://scripts/ui/altar_menu.gd", ""],
		["subir de nivel", "res://scripts/ui/desarrollo_menu.gd", ""],
	]
	for t in talleres:
		var men = load(t[1]).new()
		if t[2] == "cocina":
			men.modo = men.Modo.COCINA
		elif t[2] == "carpintero":
			men.modo = "carpintero"
		add_child(men)
		await _frames(1)
		_ok(men._root == null, "%s: al montarse no construye la interfaz" % t[0])
		Game.cerrar_menus_abiertos()
		Game._active_layer = null
		men.abrir()
		await _frames(1)
		_ok(men._root != null and men._root.visible, "%s: al abrirlo se construye y se ve" % t[0])
		var raiz: Control = men._root
		men._cerrar()
		await _frames(1)
		_ok(not raiz.visible, "%s: al cerrarlo se esconde" % t[0])
		men.abrir()
		await _frames(1)
		_ok(men._root == raiz and raiz.visible, "%s: al reabrirlo NO se construye otra vez" % t[0])
		if t[0] == "runas":
			_ok(men._barra_pie != null and men._barra_pie.get_child_count() > 0, "runas: con su barra de filtros y orden")
		men._cerrar()
		men.queue_free()
		await _frames(1)
	# LA PAUSA y LA AYUDA DE TECLAS (F1): _construir al abrirlas.
	for m in [["pausa", "res://scripts/ui/pause_menu.gd"], ["ayuda F1", "res://scripts/ui/keys_help.gd"],
			["inventario", "res://scripts/ui/inventory_menu.gd"], ["personaje", "res://scripts/ui/character_menu.gd"]]:
		var men = load(m[1]).new()
		add_child(men)
		await _frames(1)
		_ok(men._root == null, "%s: al montarse no construye la interfaz" % m[0])
		men._set_open(true)
		await _frames(1)
		_ok(men._root != null and men._root.visible, "%s: al abrirla se construye y se ve" % m[0])
		var raiz: Control = men._root
		men._set_open(false)
		men._set_open(true)
		_ok(men._root == raiz and raiz.visible, "%s: al reabrirla NO se construye otra vez" % m[0])
		if m[0] == "pausa":
			men._abrir_ajustes()
			_ok(men._ajustes != null and men._ajustes.visible, "pausa: los ajustes se abren")
			men._ajustes.cerrar()
			await _frames(1)
			_ok(not men._ajustes.visible and men._root.visible, "pausa: al cerrarlos se vuelve a la pausa")
		men._set_open(false)
		men.queue_free()
		await _frames(1)
	# Los que se abren con datos que aqui no hay (el mercadillo necesita un puesto abierto a esta hora; el estanque, un charco): solo que al
	# montarse no construyan nada. Lo de abrirlos lo cubren sus visores (dev_mercadillo).
	for m in [["mercadillo", "res://scripts/ui/mercadillo_menu.gd"], ["estanque", "res://scripts/ui/fishing_menu.gd"]]:
		var men = load(m[1]).new()
		add_child(men)
		await _frames(1)
		_ok(men._root == null, "%s: al montarse no construye la interfaz" % m[0])
		if m[0] == "estanque":
			# Con un charco de mentira: abrirlo construye la interfaz y pinta la lista de cebos.
			var charco := Node2D.new()
			add_child(charco)
			Game.cerrar_menus_abiertos()
			Game._active_layer = null
			men.abrir(charco)
			await _frames(1)
			_ok(men._root != null and men._root.visible and men._content.get_child_count() > 0,
				"estanque: al abrirlo se construye y se pinta")
			men._cerrar()
			charco.queue_free()
		men.queue_free()
	print("[perezosos] RESULTADO: ", "FIN: TODO BIEN" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
