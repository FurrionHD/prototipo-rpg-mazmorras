extends Node
# Vuelca a la consola lo que lee el jugador de cada habilidad (pase de textos 06/11): la ficha (resumen) a una mano y, si
# cambia, a dos; y la descripcion de sabor. Sin ventana:
#   godot --headless --path . res://tools/volcar_textos_habilidades.tscn
# Las de enemigos (sin precio) salen al final, marcadas: el jugador tambien las lee en la ficha del enemigo.


func _ready() -> void:
	await get_tree().process_frame   # los autoloads (el catalogo de estados) tienen que estar listos
	var dir := DirAccess.open("res://resources/abilities")
	var nombres: Array = []
	for f in dir.get_files():
		if f.ends_with(".tres"):
			nombres.append(f)
	nombres.sort()
	var de_enemigo: Array = []
	for f in nombres:
		var a = load("res://resources/abilities/" + f)
		if a == null or not (a is AbilityData):
			continue
		# De ENEMIGO = ni se compra ni cuesta energia (17/11: el Golpe sismico del martillo tiene precio 0).
		if int(a.precio) <= 0 and a.coste_energia <= 0.0 and a.coste_energia_dual <= 0.0:
			de_enemigo.append([f, a])
			continue
		_volcar(f, a, "")
	for par in de_enemigo:
		_volcar(par[0], par[1], " (ENEMIGO)")
	get_tree().quit()


func _volcar(f: String, ab: AbilityData, marca: String) -> void:
	print("=== %s%s  [%s]" % [ab.nombre, marca, f])
	var enem: bool = marca != ""
	var uno: String = ab.resumen(1, enem)
	print("  " + uno.replace("\n", "\n  "))
	var dos: String = ab.resumen(2, enem)
	if dos != uno:
		print("  [a dos manos]\n  " + dos.replace("\n", "\n  "))
	if ab.descripcion != "":
		print("  Sabor: " + ab.descripcion.replace("\n", " "))
