# PRUEBA: la huella de los retratos con las capas RECORDADAS (optimizacion 1D, 16/10/2026; ver
# RetratoHorneado.texto_capas). La recordada tiene que ser SIEMPRE la calculada: para cada personaje de la partida
# grande, y despues de cada cambio que mueve las capas (aspecto, armadura, arma, mejoras cambiadas EN SU SITIO,
# foto, barba). Si capas_de empieza a leer algo nuevo del personaje y no se añade a la firma, esto falla.
extends Node

var fallos := 0

func _ok(c: bool, t: String) -> void:
	print(("[PASA] " if c else "[FALLA] ") + t)
	if not c:
		fallos += 1


func _igual(pj: PersonajeData, que: String) -> void:
	var rec: String = RetratoHorneado.texto_capas(pj)
	_ok(rec == RetratoHorneado.texto_capas_calculado(pj), "%s: %s" % [pj.nombre, que])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	var gente: Array = Game.party + Game.en_el_banquillo()
	_ok(gente.size() >= 4, "personajes: %d" % gente.size())
	for pj in gente:
		_igual(pj, "recordada = calculada")
		_igual(pj, "y otra vez (de la memoria)")

	var pj: PersonajeData = gente[0]
	var antes: String = RetratoHorneado.texto_capas(pj)
	# El ASPECTO: otra pieza de ropa / pelo.
	var p: Dictionary = pj.pieza("pelo")
	pj.poner_pieza("pelo", String(p["modelo"]), Color(0.1, 0.9, 0.2), 0.0)
	_igual(pj, "tras cambiar el color del pelo")
	# La ARMADURA: otra pieza en el pecho y luego ninguna.
	var pecho_viejo: Resource = pj.equipped_pecho
	pj.equipped_pecho = load("res://resources/armor/placas_pecho.tres")
	_igual(pj, "tras ponerse un peto de placas")
	pj.equipped_pecho = null
	_igual(pj, "tras quitarse el peto")
	pj.equipped_pecho = pecho_viejo
	# El ARMA.
	var main_viejo: Resource = pj.equipped_main
	pj.equipped_main = load("res://resources/weapons/espada_larga.tres")
	_igual(pj, "tras cambiar de arma")
	# Las MEJORAS cambiadas en su sitio (el diccionario es el mismo).
	var meta: Dictionary = pj.equip_meta.get("main", {})
	if meta.is_empty():
		pj.equip_meta["main"] = {"tier": 1, "mejoras": {}}
		meta = pj.equip_meta["main"]
	if not (meta.get("mejoras") is Dictionary):
		meta["mejoras"] = {}
	(meta["mejoras"] as Dictionary)["filo"] = int((meta["mejoras"] as Dictionary).get("filo", 0)) + 9
	_igual(pj, "tras subir las mejoras del arma (en su sitio)")
	meta["tier"] = int(meta.get("tier", 1)) + 1
	_igual(pj, "tras subir el tier del arma (en su sitio)")
	pj.equipped_main = main_viejo
	# La FOTO y la BARBA.
	var img_vieja: PackedByteArray = pj.imagen
	pj.imagen = PackedByteArray([1, 2, 3]) if pj.imagen.is_empty() else PackedByteArray()
	_igual(pj, "tras cambiar la foto")
	pj.imagen = img_vieja
	pj.set_meta(JugadorSprites.BARBA_NPC, true)
	_igual(pj, "con la marca de barba")
	pj.remove_meta(JugadorSprites.BARBA_NPC)
	_igual(pj, "sin ella")
	print("[huella] RESULTADO: ", "FIN: TODO BIEN" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
