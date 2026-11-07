extends Node
# Vuelca a la consola las fichas de equipo tal como las pintan los menus (pase de textos 06/11): armas, escudos,
# armaduras y herramientas, a T1 comun sin mejoras y sin dueño (como en la tienda o el baul), y su descripcion.
# Sin ventana:
#   godot --headless --path . res://tools/volcar_textos_equipo.tscn


func _ready() -> void:
	await get_tree().process_frame   # los autoloads tienen que estar listos
	for carpeta in ["weapons", "shields", "armor", "tools", "wands"]:
		var dir := DirAccess.open("res://resources/" + carpeta)
		if dir == null:
			continue
		var nombres: Array = []
		for f in dir.get_files():
			if f.ends_with(".tres"):
				nombres.append(f)
		nombres.sort()
		for f in nombres:
			var it = load("res://resources/%s/%s" % [carpeta, f])
			var filas: Array = []
			if it is WeaponData:
				filas = MenuScaffold.filas_arma(it, 1, Upgrades.Rareza.COMUN, {})
			elif it is ShieldData:
				filas = MenuScaffold.filas_escudo(it, 1, Upgrades.Rareza.COMUN, {})
			elif it is ArmorData:
				filas = MenuScaffold.filas_armadura(it, 1, Upgrades.Rareza.COMUN, {})
			elif it is ToolData:
				filas = MenuScaffold.filas_herramienta(it)
			elif it is WandData:
				filas = [["(varita: ficha propia en inventory_menu / shop_menu)", ""]]
			else:
				continue
			print("=== %s  [%s/%s]" % [str(it.get("nombre")), carpeta, f])
			for fl in filas:
				print("  %s: %s" % [String(fl[0]), String(fl[1])])
			var desc: String = str(it.get("descripcion")) if it.get("descripcion") != null else ""
			if desc != "":
				print("  Sabor: " + desc.replace("\n", " "))
	get_tree().quit()
