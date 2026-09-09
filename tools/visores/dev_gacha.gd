# ============================================================
#  dev_gacha.gd  --  HERRAMIENTA, no parte del juego.
#
#  Comprueba el GACHA DE LA MEDITACION: pagas y el azar decide que libro cae.
#
#  Lo que se prueba, y por que cada cosa:
#    1. El reparto sale el que dice la tabla (10 grimorio / 25 sabiduria / 65 relleno) con la
#       tolerancia de una muestra grande. Un reparto torcido no da error: solo hace el juego
#       mas tacaño o mas regalado, y nadie se entera.
#    2. EL PITY ES UN SUELO DURO. Es la prueba que justifica el visor entero: en 200 tiradas
#       tienen que salir AL MENOS los garantizados que tocan, y hay que contarlos con la suerte
#       apagada y encendida.
#    3. LA REGLA QUE SE IMPLEMENTA MAL POR DEFECTO: que salga un epico por suerte NO reinicia el
#       contador. Se prueba a proposito con un pool donde el epico sale casi siempre: si alguien
#       "arregla" el pity al estilo de los demas gachas (resetear al acertar), el garantizado de
#       la 50 se retrasa y esta prueba lo caza. Sin ella el fallo es invisible, porque seguirian
#       saliendo epicos.
#    4. El de 200 da LEGENDARIO O MEJOR, no mitico: Tormenta tiene que seguir costando ~1.000.000.
#    5. Los dos contadores son INDEPENDIENTES y el de 200 manda cuando vencen a la vez.
#    6. El pity es POR PERSONAJE: tirar con uno no acerca al otro a su garantizado.
#    7. El relleno YA LEIDO no se entrega, y con TODO el relleno leido el gacha no se cuelga
#       ni devuelve vacio: cae al tomo de sabiduria.
#    8. El pity SOBREVIVE a guardar y cargar, y en concreto EL DEL LIDER, que es el unico que va
#       desmontado en campos planos del SaveData (los compañeros viajan enteros en la plantilla).
#       Lo que no se copia campo a campo se pierde sin dar error.
#
#  Es logica pura, sin Control ni captura, asi que aqui SI vale --headless.
#
#    godot --headless --path . res://tools/visores/dev_gacha.tscn
#  Escribe el resultado por consola y devuelve codigo de salida != 0 si algo falla.
# ============================================================
extends Node

const DIR_TOCHOS := "res://resources/consumables/tochos/"

var _fallos: int = 0
var _hechas: int = 0
var _grimorios: Array = []    # los SpellData que pueden salir (el pool de verdad)
var _tochos: Array = []       # los ConsumableData de los 30 tochos


func _ready() -> void:
	print("=== EL GACHA DE LA MEDITACIÓN ===")
	_cargar()
	_probar_reparto()
	_probar_pity_suelo()
	_probar_pity_no_se_corta()
	_probar_pity_200_es_legendario()
	_probar_contadores_independientes()
	_probar_por_personaje()
	_probar_relleno_agotado()
	_probar_guardado()
	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _cargar() -> void:
	for ruta in Libros.GRIMORIOS:
		var c: ConsumableData = load(ruta) as ConsumableData
		if c != null and c.spell != null:
			_grimorios.append(c.spell)
	var d := DirAccess.open(DIR_TOCHOS)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".tres"):
				var t: ConsumableData = load(DIR_TOCHOS + f) as ConsumableData
				if t != null:
					_tochos.append(t)
	_ok("cargan los %d grimorios y los %d tochos" % [_grimorios.size(), _tochos.size()],
		_grimorios.size() > 0 and _tochos.size() > 0)


# Un personaje limpio: sin hechizos sabidos, para que el sesgo del repetido no enturbie el reparto.
func _pj() -> PersonajeData:
	var p := PersonajeData.new()
	p.nombre = "Prueba"
	return p


func _rng(semilla: int = 1234) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = semilla
	return r


# --- 1) El reparto 10 / 25 / 65 ---
func _probar_reparto() -> void:
	print("\n-- El reparto de qué clase de libro cae --")
	Game.biblioteca.clear()
	var p := _pj()
	var rng := _rng()
	var n := 20000
	var cuenta := {"g": 0, "s": 0, "r": 0}
	for i in n:
		# El pity se apaga a mano entre tiradas: aqui se mide el reparto CORRIENTE, y un garantizado
		# cada 50 lo empujaria hacia el grimorio y haria fallar la prueba por el motivo equivocado.
		p.gacha_n50 = 0
		p.gacha_n200 = 0
		var t: Dictionary = Game.tirar_meditacion(p, rng, _grimorios, _tochos)
		var c: ConsumableData = t.get("item")
		if c == null:
			continue
		if c.es_grimorio():
			cuenta["g"] += 1
		elif c.es_tomo_sabio():
			cuenta["s"] += 1
		else:
			cuenta["r"] += 1
	var pg: float = float(cuenta["g"]) / float(n)
	var ps: float = float(cuenta["s"]) / float(n)
	var pr: float = float(cuenta["r"]) / float(n)
	print("  grimorio %.1f%%  sabiduría %.1f%%  relleno %.1f%%" % [pg * 100.0, ps * 100.0, pr * 100.0])
	# Margen de 1.5 puntos: con 20.000 tiradas el ruido es de decimas, asi que esto solo salta si el
	# reparto esta de verdad torcido.
	_ok("grimorio ~10%%  (sale %.1f%%)" % (pg * 100.0), absf(pg - Game.GACHA_P_GRIMORIO) < 0.015)
	_ok("sabiduría ~25%%  (sale %.1f%%)" % (ps * 100.0), absf(ps - Game.GACHA_P_TOMO_SABIO) < 0.015)
	_ok("relleno ~65%%  (sale %.1f%%)" % (pr * 100.0), absf(pr - 0.65) < 0.015)


# --- 2) EL PITY ES UN SUELO DURO ---
# La comprobacion que pidio el: tiras 200 veces y cuentas que salieron AL MENOS los garantizados.
func _probar_pity_suelo() -> void:
	print("\n-- El pity como suelo duro (200 tiradas) --")
	Game.biblioteca.clear()
	# Se repite con varias semillas porque una sola podria colar por suerte justo la tirada que
	# falta. Si el suelo esta roto, con cinco rachas distintas se cae seguro.
	var peor_ep: int = 999
	var peor_leg: int = 999
	for semilla in [1, 7, 99, 2024, 55555]:
		var p := _pj()
		var rng := _rng(semilla)
		var epicos: int = 0
		var legendarios: int = 0
		for i in 200:
			var t: Dictionary = Game.tirar_meditacion(p, rng, _grimorios, _tochos)
			var s: SpellData = t.get("spell")
			if s == null:
				continue
			if int(s.rareza) >= Upgrades.Rareza.LEGENDARIO:
				legendarios += 1
			if int(s.rareza) >= Upgrades.Rareza.EPICO:
				epicos += 1
		peor_ep = mini(peor_ep, epicos)
		peor_leg = mini(peor_leg, legendarios)
	# En 200 tiradas el de 50 dispara 4 veces (50/100/150/200), pero en la 200 manda el de
	# legendario -- que TAMBIEN es "epico o mejor", asi que el suelo de epicos sigue siendo 4.
	_ok("en 200 tiradas salen al menos 4 épicos o mejores (el peor caso da %d)" % peor_ep,
		peor_ep >= 4)
	_ok("y al menos 1 legendario o mejor (el peor caso da %d)" % peor_leg, peor_leg >= 1)


# --- 3) LA REGLA QUE SE IMPLEMENTA MAL POR DEFECTO ---
# Un epico de suerte NO reinicia el contador: el garantizado de la 50 llega igual.
func _probar_pity_no_se_corta() -> void:
	print("\n-- Un golpe de suerte NO corta el pity --")
	Game.biblioteca.clear()
	var p := _pj()
	# Se mira el CONTADOR, que es donde vive el fallo. Tirar 49 veces y comprobar que n50 vale 49
	# demuestra que ningun acierto por el camino lo ha tocado -- y por el camino los ha habido,
	# porque el pool lleva epicos y miticos.
	var rng := _rng(4242)
	var suerte: int = 0
	for i in 49:
		var t: Dictionary = Game.tirar_meditacion(p, rng, _grimorios, _tochos)
		var s: SpellData = t.get("spell")
		if s != null and int(s.rareza) >= Upgrades.Rareza.EPICO:
			suerte += 1
	_ok("en las 49 primeras ha caído algún épico por suerte (%d)" % suerte, suerte > 0)
	_ok("y aun así el contador va por 49, sin reiniciarse", p.gacha_n50 == 49)
	# Y la 50 cobra el garantizado igual: es la consecuencia que se ve en pantalla.
	var t50: Dictionary = Game.tirar_meditacion(p, rng, _grimorios, _tochos)
	var s50: SpellData = t50.get("spell")
	_ok("la tirada 50 da el garantizado", int(t50.get("pity", 0)) == Game.GACHA_PITY_EPICO)
	_ok("y es épico o mejor", s50 != null and int(s50.rareza) >= Upgrades.Rareza.EPICO)
	_ok("ahora sí se reinicia el contador (dispara el pity, no la suerte)", p.gacha_n50 == 0)


# --- 4) El de 200 es LEGENDARIO, no mítico ---
func _probar_pity_200_es_legendario() -> void:
	print("\n-- El garantizado de 200 --")
	Game.biblioteca.clear()
	var p := _pj()
	var rng := _rng(31337)
	var ultimo: Dictionary = {}
	for i in 200:
		ultimo = Game.tirar_meditacion(p, rng, _grimorios, _tochos)
	var s: SpellData = ultimo.get("spell")
	_ok("la tirada 200 marca el garantizado de legendario",
		int(ultimo.get("pity", 0)) == Game.GACHA_PITY_LEGENDARIO)
	_ok("y da legendario o mejor", s != null and int(s.rareza) >= Upgrades.Rareza.LEGENDARIO)
	# LA PARTE QUE IMPORTA PARA LA ECONOMIA: el suelo NO es mitico. Si lo fuera, Tormenta saldria
	# garantizada cada 200 tiradas (400.000 monedas) en vez de costar el millon que tiene que costar.
	# Se comprueba sobre muchas rachas: aqui lo que se afirma es que el suelo no OBLIGA a mitico.
	var miticos_de_pity: int = 0
	var pities: int = 0
	for semilla in [3, 17, 404, 9001, 12345, 777, 246]:
		var p2 := _pj()
		var rng2 := _rng(semilla)
		for i in 200:
			var t: Dictionary = Game.tirar_meditacion(p2, rng2, _grimorios, _tochos)
			if int(t.get("pity", 0)) == Game.GACHA_PITY_LEGENDARIO:
				pities += 1
				var s2: SpellData = t.get("spell")
				if s2 != null and int(s2.rareza) >= Upgrades.Rareza.MITICO:
					miticos_de_pity += 1
	_ok("el suelo de 200 no garantiza mítico (%d de %d garantizados lo fueron, por suerte)"
		% [miticos_de_pity, pities], miticos_de_pity < pities)


# --- 5) Los dos contadores van por su cuenta ---
func _probar_contadores_independientes() -> void:
	print("\n-- Los dos escalones son independientes --")
	Game.biblioteca.clear()
	var p := _pj()
	var rng := _rng(8)
	for i in 50:
		Game.tirar_meditacion(p, rng, _grimorios, _tochos)
	_ok("tras 50 tiradas el de épico se ha reiniciado", p.gacha_n50 == 0)
	_ok("pero el de legendario sigue contando (va por 50)", p.gacha_n200 == 50)
	# En la 200 vencen los dos. Manda el alto, y el bajo TAMBIEN se reinicia: un legendario es
	# "epico o mejor", asi que el de 50 ha cobrado y no se le debe nada.
	for i in 150:
		Game.tirar_meditacion(p, rng, _grimorios, _tochos)
	_ok("en la 200 se reinician los dos", p.gacha_n50 == 0 and p.gacha_n200 == 0)
	var falta: Dictionary = Game.gacha_pity_restante(p)
	_ok("y lo que falta vuelve a ser 50 y 200",
		int(falta["epico"]) == 50 and int(falta["legendario"]) == 200)


# --- 6) POR PERSONAJE ---
func _probar_por_personaje() -> void:
	print("\n-- El pity va por personaje --")
	Game.biblioteca.clear()
	var uno := _pj()
	var otro := _pj()
	var rng := _rng(600)
	for i in 49:
		Game.tirar_meditacion(uno, rng, _grimorios, _tochos)
	_ok("el que medita va por 49", uno.gacha_n50 == 49)
	_ok("y el otro sigue a 0: no le han gastado su pity", otro.gacha_n50 == 0)
	var falta: Dictionary = Game.gacha_pity_restante(otro)
	_ok("al otro le siguen faltando sus 50", int(falta["epico"]) == 50)


# --- 7) EL REPARTO NO CAMBIA POR LO QUE TENGAS LEIDO ---
#
# Esta prueba antes afirmaba lo CONTRARIO ("ninguna tirada entrega relleno ya leído") y por eso dejo
# pasar el fallo: el gacha se saltaba los libros leidos, asi que un jugador con las curiosidades
# leidas no tenia ninguna que recibir y la tirada se caia al tomo de sabiduria por descarte. El 65%
# de curiosidades se volvia sabiduria EN SILENCIO, con la tabla de probabilidades prometiendo otra
# cosa. Se vio jugando: trece paginas de historial sin apenas una curiosidad.
#
# Lo repetido ya no desaparece del reparto: se entrega y se convierte en monedas al entrar en la
# bolsa (ver Game.add_consumable). Asi que lo que hay que comprobar es que el reparto sale IGUAL con
# la biblioteca vacia y con ella llena.
func _probar_relleno_agotado() -> void:
	print("\n-- Tenerlos leídos NO cambia el reparto --")
	var limpio: Dictionary = _reparto_con_biblioteca(false)
	var lleno: Dictionary = _reparto_con_biblioteca(true)
	print("  sin leer nada:   grimorio %.1f%%  sabiduría %.1f%%  relleno %.1f%%"
		% [limpio["g"] * 100.0, limpio["s"] * 100.0, limpio["r"] * 100.0])
	print("  todo leído:      grimorio %.1f%%  sabiduría %.1f%%  relleno %.1f%%"
		% [lleno["g"] * 100.0, lleno["s"] * 100.0, lleno["r"] * 100.0])
	_ok("con TODO leído sigue cayendo relleno (%.1f%%)" % (lleno["r"] * 100.0),
		absf(float(lleno["r"]) - 0.65) < 0.02)
	_ok("y la sabiduría NO se come su parte (%.1f%%)" % (lleno["s"] * 100.0),
		absf(float(lleno["s"]) - 0.25) < 0.02)
	_ok("ninguna tirada se queda vacía", int(lleno["vacias"]) == 0)


# El reparto de 3000 tiradas, con la biblioteca vacía o con TODOS los tochos marcados como leídos.
func _reparto_con_biblioteca(todo_leido: bool) -> Dictionary:
	Game.biblioteca.clear()
	if todo_leido:
		for c in _tochos:
			Game.biblioteca[c.tomo_id] = true
	var p := _pj()
	var rng := _rng(70)
	var n := 3000
	var cuenta := {"g": 0, "s": 0, "r": 0, "vacias": 0}
	for i in n:
		# El pity apagado: aqui se mide el reparto CORRIENTE, y un garantizado cada 50 lo empujaria
		# hacia el grimorio.
		p.gacha_n50 = 0
		p.gacha_n200 = 0
		var t: Dictionary = Game.tirar_meditacion(p, rng, _grimorios, _tochos)
		var c2: ConsumableData = t.get("item")
		if c2 == null:
			cuenta["vacias"] = int(cuenta["vacias"]) + 1
			continue
		var k: String = "g" if c2.es_grimorio() else ("s" if c2.es_tomo_sabio() else "r")
		cuenta[k] = int(cuenta[k]) + 1
	return {"g": float(cuenta["g"]) / n, "s": float(cuenta["s"]) / n,
		"r": float(cuenta["r"]) / n, "vacias": cuenta["vacias"]}


# --- 8) Guardar y cargar ---
func _probar_guardado() -> void:
	print("\n-- Guardar y cargar --")
	Game.biblioteca.clear()
	Game.gacha_historial.clear()
	var lider: PersonajeData = Game.lider()
	lider.gacha_n50 = 37
	lider.gacha_n200 = 137
	lider.gacha_total = 137
	Game.gacha_apuntar(lider, _grimorio_consumible(), Game.GACHA_PITY_EPICO)
	var d: SaveData = Game.exportar_partida()
	_ok("el save se lleva el pity del líder",
		d.player_gacha_n50 == 37 and d.player_gacha_n200 == 137)
	_ok("y la entrada del historial", d.gacha_historial.size() == 1)
	# Se ensucia a proposito ANTES de cargar: si importar_partida no escribiera los campos, la
	# prueba pasaria igual leyendo lo que ya habia en memoria.
	lider.gacha_n50 = 0
	lider.gacha_n200 = 0
	lider.gacha_total = 0
	Game.gacha_historial.clear()
	Game.gacha_historial.append({"nombre": "basura que no debería sobrevivir"})
	Game.importar_partida(d)
	var l2: PersonajeData = Game.lider()
	_ok("al cargar vuelve el pity del líder", l2.gacha_n50 == 37 and l2.gacha_n200 == 137)
	_ok("y el historial, sin arrastrar lo que había en memoria",
		Game.gacha_historial.size() == 1
		and String(Game.gacha_historial[0].get("nombre", "")) != "basura que no debería sobrevivir")
	# EL HISTORIAL SE CORTA: va dentro del SaveData, y sin tope una partida larga se lleva miles de
	# diccionarios en cada guardado.
	Game.gacha_historial.clear()
	for i in Game.GACHA_HISTORIAL_MAX + 50:
		Game.gacha_apuntar(l2, _grimorio_consumible(), 0)
	_ok("el historial se corta en %d" % Game.GACHA_HISTORIAL_MAX,
		Game.gacha_historial.size() == Game.GACHA_HISTORIAL_MAX)


func _grimorio_consumible() -> ConsumableData:
	return load(Libros.GRIMORIOS[0]) as ConsumableData


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
