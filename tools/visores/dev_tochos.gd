# ============================================================
#  dev_tochos.gd  --  HERRAMIENTA, no parte del juego.
#
#  Comprueba los TOCHOS y la BIBLIOTECA: los libros que NO enseñan magia (el 65% de relleno y el
#  25% de sabiduria de la Meditacion), que se leen una vez, se gastan y quedan apuntados.
#
#  Lo que se prueba, y por que cada cosa:
#    1. Los 30 cargan, con id unico y texto. Un id repetido se come la entrada del otro EN SILENCIO.
#    2. Un GRIMORIO esta en la biblioteca pero NO es un tocho. Los dos llevan tomo_id, y sin el
#       `spell == null` de es_tocho() la ficha del grimorio pasaba a decir "se lee una vez" en vez
#       de que hechizo enseña. Es el fallo que este visor existe para que no vuelva.
#    3. Leer gasta el libro y lo apunta. Releer un repetido gasta y NO rompe nada.
#    4. El de SABIDURIA sube la magia de QUIEN lo lee, y solo la suya. El de relleno no sube nada.
#    5. Estudiar un grimorio tambien lo mete en la biblioteca (va por otra rama distinta).
#    6. Las tres secciones reparten los 46 libros sin dejarse ninguno ni contar dos veces.
#    7. La biblioteca SOBREVIVE a guardar y cargar. Es un campo nuevo de SaveData con cinco puntos
#       de copia, y lo que no se copia campo a campo se pierde sin dar error.
#    8. NINGUN texto lleva cifras. Es la regla de la casa: un consejo con numeros se queda mintiendo
#       en cuanto se toca el balance, y nadie vuelve a corregirlo.
#
#  Es logica pura, sin Control ni captura, asi que aqui SI vale --headless.
#
#    godot --headless --path . res://tools/visores/dev_tochos.tscn
#  Escribe el resultado por consola y devuelve codigo de salida != 0 si algo falla.
# ============================================================
extends Node

const DIR_TOCHOS := "res://resources/consumables/tochos/"
const DIR_CONSUM := "res://resources/consumables/"

var _fallos: int = 0
var _hechas: int = 0
var _tochos: Array = []       # los 30, cargados
var _grimorios: Array = []    # los 16


func _ready() -> void:
	print("=== TOCHOS Y BIBLIOTECA ===")
	_cargar()
	_probar_catalogo()
	_probar_grimorio_no_es_tocho()
	_probar_leer()
	_probar_sabiduria()
	_probar_secciones()
	_probar_guardado()
	_probar_sin_cifras()
	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _cargar() -> void:
	var d := DirAccess.open(DIR_TOCHOS)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".tres"):
				var c: ConsumableData = load(DIR_TOCHOS + f) as ConsumableData
				if c != null:
					_tochos.append(c)
	var d2 := DirAccess.open(DIR_CONSUM)
	if d2 != null:
		for f in d2.get_files():
			if f.begins_with("grimorio_") and f.ends_with(".tres"):
				var c2: ConsumableData = load(DIR_CONSUM + f) as ConsumableData
				if c2 != null:
					_grimorios.append(c2)


# --- 1) El catalogo ---
func _probar_catalogo() -> void:
	print("\n-- El catálogo --")
	_ok("hay 30 tochos", _tochos.size() == 30)
	var ids := {}
	var repes: Array = []
	var sin_texto: Array = []
	for c in _tochos:
		var id: String = String(c.tomo_id)
		if ids.has(id):
			repes.append(id)
		ids[id] = true
		if c.descripcion.strip_edges() == "":
			sin_texto.append(c.nombre)
	_ok("ningún id repetido" if repes.is_empty() else "IDS REPETIDOS: %s" % ", ".join(repes),
		repes.is_empty())
	_ok("todos traen texto" if sin_texto.is_empty() else "SIN TEXTO: %s" % ", ".join(sin_texto),
		sin_texto.is_empty())
	var sabios: int = 0
	for c in _tochos:
		if c.es_tomo_sabio():
			sabios += 1
	_ok("6 son de sabiduría y 24 de relleno", sabios == 6 and _tochos.size() - sabios == 24)


# --- 2) El grimorio NO es un tocho ---
func _probar_grimorio_no_es_tocho() -> void:
	print("\n-- Grimorio vs tocho --")
	# Contra el MANIFIESTO, no contra un numero a pelo: si no, cada hechizo nuevo rompe el visor por
	# el motivo equivocado y acaba desactivado a fuerza de dar guerra.
	var Libros = load("res://scripts/core/libros.gd")
	_ok("hay %d grimorios (los del manifiesto)" % Libros.GRIMORIOS.size(),
		_grimorios.size() == Libros.GRIMORIOS.size())
	var malos: Array = []
	var fuera: Array = []
	for c in _grimorios:
		if c.es_tocho():
			malos.append(c.nombre)
		if not c.en_biblioteca():
			fuera.append(c.nombre)
	_ok("ninguno cuenta como tocho" if malos.is_empty() else "CUENTAN COMO TOCHO: %s" % ", ".join(malos),
		malos.is_empty())
	_ok("todos entran en la biblioteca" if fuera.is_empty() else "FUERA DE LA BIBLIOTECA: %s" % ", ".join(fuera),
		fuera.is_empty())
	# LA REGRESION CONCRETA: la ficha de un grimorio tiene que seguir hablando de su hechizo.
	var g: ConsumableData = _grimorios[0]
	_ok("la ficha del grimorio no dice 'se lee una vez'",
		not g.resumen(100.0, 50.0).contains("se lee una vez"))
	var t: ConsumableData = _tochos[0]
	_ok("y la del tocho sí", t.resumen(100.0, 50.0).contains("se lee"))


# --- 3) Leer gasta y apunta ---
func _probar_leer() -> void:
	print("\n-- Leer un tocho --")
	Game.biblioteca.clear()
	var c: ConsumableData = _relleno()
	var p := PersonajeData.new()
	Game.consumables[c] = 2

	_ok("de partida la biblioteca está vacía", Game.tomos_leidos() == 0)
	_ok("se lee", Game.leer_tocho(c, p))
	_ok("y se ha gastado (quedaba 1)", int(Game.consumables.get(c, 0)) == 1)
	_ok("queda apuntado en la biblioteca", Game.tomo_leido(c.tomo_id))
	_ok("la biblioteca tiene 1 entrada", Game.tomos_leidos() == 1)

	# EL REPETIDO DE RELLENO: no pasa nada, y sobre todo NO SE GASTA. Que siga en la bolsa es lo
	# importante: es lo unico que te deja venderlo o guardarlo en el baul.
	_ok("un relleno repetido NO se lee", not Game.leer_tocho(c, p))
	_ok("y NO se gasta (sigue quedando 1)", int(Game.consumables.get(c, 0)) == 1)
	_ok("la biblioteca sigue con 1", Game.tomos_leidos() == 1)

	# SIN EJEMPLARES no se puede leer: lo tiene que parar gastar_consumible, no una comprobacion
	# propia (si no, un dia dejarian de decir lo mismo).
	Game.consumables[c] = 0
	Game.biblioteca.clear()
	_ok("sin ejemplares no se lee", not Game.leer_tocho(c, p))


# --- 4) El tomo de sabiduria enseña; el de relleno no ---
func _probar_sabiduria() -> void:
	print("\n-- Sabiduría vs relleno --")
	var sabio: ConsumableData = _sabio()
	var basura: ConsumableData = _relleno()
	var lector := PersonajeData.new()
	var otro := PersonajeData.new()

	Game.consumables[basura] = 1
	var antes_b: float = float(lector.ability_internal["magia"])
	Game.leer_tocho(basura, lector)
	_ok("el de relleno no enseña nada",
		is_equal_approx(float(lector.ability_internal["magia"]), antes_b))

	Game.consumables[sabio] = 1
	var antes_s: float = float(lector.ability_internal["magia"])
	var antes_otro: float = float(otro.ability_internal["magia"])
	Game.leer_tocho(sabio, lector)
	_ok("el de sabiduría sube la magia del que lo lee",
		float(lector.ability_internal["magia"]) > antes_s)
	_ok("y NO la de otro del grupo",
		is_equal_approx(float(otro.ability_internal["magia"]), antes_otro))
	# NO SE CONSOLIDA SOLO: la excelia entra en el interno y se lee en el altar, como todo lo demas.
	_ok("no toca lo consolidado (eso es del altar)",
		is_equal_approx(float(lector.ability_consolidado["magia"]), 0.0))

	# EL SABIO REPETIDO SI se relee: lo que da es la excelia, no el texto, y esa se cobra cada vez.
	# Es la diferencia exacta con el de relleno, y por eso se prueban las dos juntas.
	Game.consumables[sabio] = 1
	var antes_re: float = float(lector.ability_internal["magia"])
	_ok("un sabio repetido SÍ se relee", Game.leer_tocho(sabio, lector))
	_ok("y vuelve a enseñar", float(lector.ability_internal["magia"]) > antes_re)
	_ok("pero gasta el ejemplar", int(Game.consumables.get(sabio, 0)) == 0)


# --- 5) y 6) El grimorio entra por su rama, y las secciones ---
func _probar_secciones() -> void:
	print("\n-- Estudiar un grimorio y las secciones --")
	Game.biblioteca.clear()
	var g: ConsumableData = _grimorios[0]
	var p := PersonajeData.new()
	Game.consumables[g] = 1
	_ok("se estudia el grimorio", Game.aprender_de_grimorio(g, p))
	_ok("aprende su hechizo", Game.hechizos_sabidos(p).has(g.spell))
	_ok("y ADEMAS queda en la biblioteca", Game.tomo_leido(g.tomo_id))

	# EL GRIMORIO REPETIDO EN EL MISMO PERSONAJE: no se deja usar y NO SE GASTA. Es lo que permite
	# guardarlo en el baul para que se lo estudie otro del grupo; si se quemara, un duplicado seria
	# dinero a la basura. Va con OTRO personaje al lado para dejar claro que el bloqueo es POR
	# PERSONA y no global.
	Game.consumables[g] = 1
	_ok("el mismo personaje NO puede volver a estudiarlo", not Game.aprender_de_grimorio(g, p))
	_ok("y el libro NO se gasta (queda para el baúl)", int(Game.consumables.get(g, 0)) == 1)
	var otro := PersonajeData.new()
	_ok("pero OTRO del grupo sí puede", Game.aprender_de_grimorio(g, otro))

	# LO QUE EL GACHA VA A PREGUNTAR (2c). Solo el relleno leido se descarta; el grimorio y el
	# sabio entran en la bolsa siempre, porque los dos siguen sirviendo para algo.
	print("\n-- Qué reparte el gacha --")
	var relleno: ConsumableData = _relleno()
	var sabio: ConsumableData = _sabio()
	Game.biblioteca.clear()
	_ok("un relleno SIN leer se entrega", Game.tocho_aporta_algo(relleno))
	Game.biblioteca[relleno.tomo_id] = true
	_ok("un relleno YA LEÍDO no se entrega", not Game.tocho_aporta_algo(relleno))
	Game.biblioteca[sabio.tomo_id] = true
	_ok("un sabio ya leído SÍ se entrega (da excelia igual)", Game.tocho_aporta_algo(sabio))
	Game.biblioteca[g.tomo_id] = true
	_ok("un grimorio ya leído SÍ se entrega (se lo puede estudiar otro)",
		Game.tocho_aporta_algo(g))

	# Y LO QUE PASA CUANDO AUN ASI TE LLEGA UNO: no entra en la bolsa, se convierte en monedas. Las
	# curiosidades son el 65% de lo que cae y no valen para nada una vez leidas, asi que sin esto
	# media pestaña de consumibles acababa siendo tomos muertos.
	print("\n-- Un libro ya leído no ocupa sitio --")
	Game.biblioteca.clear()
	Game.consumables.clear()
	Game.money = 0
	Game.biblioteca[relleno.tomo_id] = true
	var pago: int = Game.add_consumable(relleno, 1)
	_ok("un relleno YA LEÍDO no entra en la bolsa", int(Game.consumables.get(relleno, 0)) == 0)
	_ok("y paga monedas (%d)" % pago, pago > 0 and Game.money == pago)
	# Los otros dos SI entran, y cada uno por su motivo.
	Game.add_consumable(sabio, 1)
	_ok("un tomo de sabiduría SÍ entra (da excelia cada vez)",
		int(Game.consumables.get(sabio, 0)) == 1)
	Game.add_consumable(g, 1)
	_ok("un grimorio ya leído SÍ entra (se lo estudia otro del grupo)",
		int(Game.consumables.get(g, 0)) == 1)
	# Y uno SIN leer entra como siempre: la regla es "ya leído", no "es un tocho".
	Game.biblioteca.clear()
	Game.add_consumable(relleno, 1)
	_ok("un relleno SIN leer entra normal", int(Game.consumables.get(relleno, 0)) == 1)

	var cuenta := {"Grimorios": 0, "Sabiduría": 0, "Curiosidades": 0}
	var raras: Array = []
	for c in _tochos + _grimorios:
		var s: String = c.seccion_biblioteca()
		if cuenta.has(s):
			cuenta[s] += 1
		else:
			raras.append(s)
	_ok("no hay secciones inventadas", raras.is_empty())
	# La comprobacion buena NO es "salen 16/6/24" —eso caduca con cada libro nuevo— sino que cada
	# seccion recoge EXACTAMENTE lo suyo: los grimorios los que llevan hechizo, sabiduria los que dan
	# excelia, y curiosidades el resto. Asi el visor sigue valiendo con 17 libros o con 300.
	var n_sabios: int = 0
	for c in _tochos:
		if c.es_tomo_sabio():
			n_sabios += 1
	_ok("Grimorios = los %d que llevan hechizo (salen %d)" % [_grimorios.size(), cuenta["Grimorios"]],
		cuenta["Grimorios"] == _grimorios.size())
	_ok("Sabiduría = los %d que dan excelia (salen %d)" % [n_sabios, cuenta["Sabiduría"]],
		cuenta["Sabiduría"] == n_sabios)
	_ok("Curiosidades = el resto (%d)" % cuenta["Curiosidades"],
		cuenta["Curiosidades"] == _tochos.size() - n_sabios)
	_ok("los %d libros están repartidos, sin perder ni duplicar ninguno" % (_tochos.size() + _grimorios.size()),
		cuenta["Grimorios"] + cuenta["Sabiduría"] + cuenta["Curiosidades"] == _tochos.size() + _grimorios.size())


# --- 7) Guardar y cargar ---
func _probar_guardado() -> void:
	print("\n-- Guardar y cargar --")
	Game.biblioteca.clear()
	Game.biblioteca[&"humedad"] = true
	Game.biblioteca[&"rata_comun"] = true
	Game.biblioteca[&"grimorio_rayo"] = true
	var d: SaveData = Game.exportar_partida()
	_ok("el save se lleva las 3 entradas", d.biblioteca.size() == 3)
	# Se ensucia a proposito ANTES de cargar: si importar_partida no escribiera el campo, la prueba
	# pasaria igual leyendo lo que ya habia en memoria.
	Game.biblioteca.clear()
	Game.biblioteca[&"basura_que_no_deberia_sobrevivir"] = true
	Game.importar_partida(d)
	_ok("al cargar vuelven las 3", Game.tomos_leidos() == 3)
	_ok("y son las mismas", Game.tomo_leido(&"humedad") and Game.tomo_leido(&"rata_comun")
		and Game.tomo_leido(&"grimorio_rayo"))
	_ok("sin arrastrar lo que había en memoria",
		not Game.tomo_leido(&"basura_que_no_deberia_sobrevivir"))


# --- 8) La regla de los numeros ---
func _probar_sin_cifras() -> void:
	print("\n-- Los textos no llevan cifras --")
	var con_cifra: Array = []
	for c in _tochos:
		for ch in c.descripcion:
			if ch >= "0" and ch <= "9":
				con_cifra.append(c.nombre)
				break
	if con_cifra.is_empty():
		_ok("ninguno de los 30 lleva un número escrito en cifra", true)
	else:
		_ok("LLEVAN CIFRAS (van en letra, o se quedan mintiendo al mover el balance): %s"
			% ", ".join(con_cifra), false)


func _relleno() -> ConsumableData:
	for c in _tochos:
		if not c.es_tomo_sabio():
			return c
	return _tochos[0]


func _sabio() -> ConsumableData:
	for c in _tochos:
		if c.es_tomo_sabio():
			return c
	return _tochos[0]


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
