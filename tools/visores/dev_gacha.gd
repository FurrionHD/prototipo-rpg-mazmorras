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
#    4. Los TRES escalones son INDEPENDIENTES y no se pisan.
#    5. CUANDO VENCEN VARIOS A LA VEZ SE COBRAN TODOS. Es el fallo que se vio jugando: se llego a
#       la 200, vencian los tres, y el codigo (un if/elif) entregaba solo el mitico y tiraba los
#       otros dos. Desde fuera parecia mala suerte. Se prueba llegando a la 200 y contando que en
#       esa tirada Y LAS SIGUIENTES caen los tres garantizados.
#    6. El pity es POR PERSONAJE y POR BANNER: tirar con uno, o en otro circulo, no acerca al otro.
#    7. El relleno YA LEIDO no se entrega, y con TODO el relleno leido el gacha no se cuelga
#       ni devuelve vacio: cae al tomo de sabiduria.
#    8. El pity SOBREVIVE a guardar y cargar, y en concreto EL DEL LIDER, que es el unico que va
#       desmontado en campos planos del SaveData (los compañeros viajan enteros en la plantilla).
#       Lo que no se copia campo a campo se pierde sin dar error.
#    9. EL REPARTO DEL CATALOGO por banner: que cada uno tenga su mitico, sus legendarios y sus
#       epicos. Si alguien añade un hechizo y descuadra un banner, aqui se ve.
#   10. LA MONOTONIA, banner por banner: un hechizo de banda alta tiene que salir MENOS que uno de
#       banda baja. Es la regla que el peso POR BANDA rompe sola en cuanto cambian los miembros.
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
var _grimorios: Array = []    # TODOS los SpellData que tienen grimorio (el catalogo entero)
var _tochos: Array = []       # los ConsumableData de los 30 tochos


func _ready() -> void:
	print("=== EL GACHA DE LA MEDITACIÓN ===")
	_cargar()
	_probar_reparto_banners()
	_probar_monotonia()
	_probar_reparto()
	_probar_pity_suelo()
	_probar_pity_no_se_corta()
	_probar_pity_200()
	_probar_cola_no_pierde_nada()
	_probar_cola_sobrevive_a_x1()
	_probar_contadores_independientes()
	_probar_por_personaje()
	_probar_por_banner()
	_probar_relleno_agotado()
	_probar_guardado()
	_probar_migracion()
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


# El pool de un banner. Casi todas las pruebas van sobre el de ATAQUE, que es el que era el gacha
# entero antes de los banners.
func _pool(i: int = Game.BANNER_ATAQUE) -> Array:
	return Game.pool_banner(_grimorios, i)


# Apaga el pity de un personaje para medir el reparto CORRIENTE. Con los garantizados encendidos,
# uno cada 50 tiradas empuja la muestra hacia el grimorio y la prueba falla por el motivo equivocado.
func _sin_pity(p: PersonajeData) -> void:
	p.gacha_pity.clear()


# Cuantas tiradas lleva un personaje hacia un escalon concreto de un banner.
func _cuenta(p: PersonajeData, r: int, i: int = Game.BANNER_ATAQUE) -> int:
	return int((Game.gacha_estado(p, i)["n"] as Dictionary).get(r, 0))


func _rng(semilla: int = 1234) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = semilla
	return r


# --- EL REPARTO DEL CATALOGO ENTRE LOS BANNERS ---
#
# Lo que se pidio: cada banner grande con SU mitico, dos legendarios o mas y cuatro epicos o mas. No
# esta escrito a mano en ningun sitio -- sale de preguntarle a cada hechizo si es una imbuicion -- y
# justo por eso hay que comprobarlo: el dia que alguien añada un manto legendario o una magia epica,
# el reparto se mueve solo y esta prueba dice si se ha descuadrado.
func _probar_reparto_banners() -> void:
	print("\n-- El reparto del catálogo entre los círculos --")
	for i in Game.BANNERS.size():
		var b: Dictionary = Game.banner(i)
		var pool: Array = _pool(i)
		var por_banda := {}
		for s in pool:
			por_banda[int(s.rareza)] = int(por_banda.get(int(s.rareza), 0)) + 1
		print("  %-24s %2d hechizos   míticos %d · legendarios %d · épicos %d" % [
			String(b["nombre"]), pool.size(),
			int(por_banda.get(Upgrades.Rareza.MITICO, 0)),
			int(por_banda.get(Upgrades.Rareza.LEGENDARIO, 0)),
			int(por_banda.get(Upgrades.Rareza.EPICO, 0))])
		if int(b.get("cupo", 0)) > 0:
			# El de novato no lleva techo por arriba, lleva TOPE: lo que hay que comprobar es que no
			# se le cuela nada por encima de su rareza maxima.
			var tope: int = int(b["tope"])
			var cuela: int = 0
			for s in pool:
				if int(s.rareza) > tope:
					cuela += 1
			_ok("el de novato no deja salir nada por encima de %s (%d colados)"
				% [Upgrades.rareza_nombre(tope).to_lower(), cuela], cuela == 0)
			_ok("y aun asi tiene de sobra donde elegir (%d hechizos)" % pool.size(), pool.size() >= 15)
			continue
		_ok("%s tiene su mítico" % String(b["nombre"]),
			int(por_banda.get(Upgrades.Rareza.MITICO, 0)) >= 1)
		_ok("y al menos 2 legendarios (%d)" % int(por_banda.get(Upgrades.Rareza.LEGENDARIO, 0)),
			int(por_banda.get(Upgrades.Rareza.LEGENDARIO, 0)) >= 2)
		_ok("y al menos 4 épicos (%d)" % int(por_banda.get(Upgrades.Rareza.EPICO, 0)),
			int(por_banda.get(Upgrades.Rareza.EPICO, 0)) >= 4)
	# EL FONDO COMUN: raro y por debajo tiene que estar en LOS DOS grandes, que es lo que se pidio
	# ("los raros para abajo van como comunes entre los dos").
	var comunes_at: int = 0
	var comunes_im: int = 0
	for s in _pool(Game.BANNER_ATAQUE):
		if int(s.rareza) < Game.BANNER_CORTE_TEMA:
			comunes_at += 1
	for s in _pool(Game.BANNER_IMBUICIONES):
		if int(s.rareza) < Game.BANNER_CORTE_TEMA:
			comunes_im += 1
	_ok("el fondo de raro para abajo es el MISMO en los dos (%d y %d)" % [comunes_at, comunes_im],
		comunes_at == comunes_im and comunes_at > 0)


# --- LA MONOTONIA, BANNER POR BANNER ---
#
# LA REGLA QUE NO SE PUEDE ROMPER: un hechizo de banda mas alta tiene que salir MENOS que uno de
# banda mas baja. Se rompe sola, sin que nadie toque un peso, porque el peso es DE LA BANDA y se
# reparte entre sus miembros: basta con que una banda alta se quede con pocos y la de debajo con
# muchos. Por eso se comprueba por banner y no una vez.
func _probar_monotonia() -> void:
	print("\n-- Un hechizo de banda alta sale MENOS que uno de banda baja --")
	Game.biblioteca.clear()
	for i in Game.BANNERS.size():
		var probs: Dictionary = Game.probs_grimorio(_pool(i), _pj())
		# El peso de UN hechizo de cada banda (todos los de una banda pesan igual sin sesgo).
		var por_banda := {}
		for s in probs:
			por_banda[int(s.rareza)] = float(probs[s])
		var bandas: Array = por_banda.keys()
		bandas.sort()
		var linea: PackedStringArray = []
		var bien: bool = true
		for k in bandas.size():
			linea.append("%s %.2f%%" % [Upgrades.rareza_nombre(int(bandas[k])).to_lower(),
				float(por_banda[bandas[k]]) * 100.0])
			if k > 0 and float(por_banda[bandas[k]]) >= float(por_banda[bandas[k - 1]]):
				bien = false
		print("  %-24s %s" % [String(Game.banner(i)["nombre"]), "  ·  ".join(linea)])
		_ok("%s: cada banda sale menos que la de debajo" % String(Game.banner(i)["nombre"]), bien)


# --- 1) El reparto 10 / 25 / 65 ---
func _probar_reparto() -> void:
	print("\n-- El reparto de qué clase de libro cae --")
	Game.biblioteca.clear()
	var p := _pj()
	var rng := _rng()
	var n := 20000
	var cuenta := {"g": 0, "s": 0, "r": 0}
	for i in n:
		_sin_pity(p)
		var t: Dictionary = Game.tirar_meditacion(p, rng, _pool(), _tochos)
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
			var t: Dictionary = Game.tirar_meditacion(p, rng, _pool(), _tochos)
			var s: SpellData = t.get("spell")
			if s == null:
				continue
			if int(s.rareza) >= Upgrades.Rareza.LEGENDARIO:
				legendarios += 1
			if int(s.rareza) >= Upgrades.Rareza.EPICO:
				epicos += 1
		peor_ep = mini(peor_ep, epicos)
		peor_leg = mini(peor_leg, legendarios)
	# LA CUENTA, con cuidado, porque no es la que parece. En 200 tiradas VENCEN siete garantizados: el
	# de epico 4 veces (50/100/150/200), el de legendario 2 (100/200) y el de mitico 1 (200). Pero los
	# que coinciden se cobran en las tiradas SIGUIENTES, y las de la 200 caen ya fuera de la ventana.
	# Dentro de las 200 se cobran cinco:
	#     t50  epico          t100 legendario (el epico que tambien vencia pasa a la cola)
	#     t101 ese epico      t150 epico
	#     t200 mitico         (legendario y epico quedan pendientes para la 201 y la 202)
	# Asi que el suelo DENTRO de la ventana es 5 epicos-o-mejores y 2 legendarios-o-mejores, y lo que
	# pase de ahi es suerte. Con el if/elif viejo eran 4 y 1: los coincidentes no se cobraban NUNCA,
	# ni dentro ni fuera. Que la cola los pague mas tarde es justo lo que arregla el fallo.
	_ok("en 200 tiradas salen al menos 5 épicos o mejores (el peor caso da %d)" % peor_ep,
		peor_ep >= 5)
	_ok("y al menos 2 legendarios o mejores (el peor caso da %d)" % peor_leg, peor_leg >= 2)


# --- 3) LA REGLA QUE SE IMPLEMENTA MAL POR DEFECTO ---
# Un epico de suerte NO reinicia el contador: el garantizado de la 50 llega igual.
func _probar_pity_no_se_corta() -> void:
	print("\n-- Un golpe de suerte NO corta el pity --")
	Game.biblioteca.clear()
	var p := _pj()
	# Se mira el CONTADOR, que es donde vive el fallo. Tirar 49 veces y comprobar que n50 vale 49
	# demuestra que ningun acierto por el camino lo ha tocado -- y por el camino los ha habido,
	# porque el pool lleva epicos y miticos.
	# LA SEMILLA SE BUSCA, no se escribe. Con una fija, la prueba se apaga sola en cuanto cambia el
	# catalogo: llevaba una que daba dos epicos por suerte, entraron banners (el pool paso de 22 a 21
	# hechizos y de 5 epicos a 4) y con esa misma semilla dejaron de caer -- la prueba seguia en verde
	# sin comprobar ya nada, que es la peor forma de fallar.
	var rng: RandomNumberGenerator = null
	var suerte: int = 0
	for semilla in [4242, 7, 13, 99, 555, 2718, 31415, 1618, 8080, 11]:
		p = _pj()
		rng = _rng(semilla)
		suerte = 0
		for i in 49:
			var t: Dictionary = Game.tirar_meditacion(p, rng, _pool(), _tochos)
			var s: SpellData = t.get("spell")
			if s != null and int(s.rareza) >= Upgrades.Rareza.EPICO:
				suerte += 1
		if suerte > 0:
			break
	_ok("en las 49 primeras ha caído algún épico por suerte (%d)" % suerte, suerte > 0)
	_ok("y aun así el contador va por 49, sin reiniciarse",
		_cuenta(p, Upgrades.Rareza.EPICO) == 49)
	# Y la 50 cobra el garantizado igual: es la consecuencia que se ve en pantalla.
	var t50: Dictionary = Game.tirar_meditacion(p, rng, _pool(), _tochos)
	var s50: SpellData = t50.get("spell")
	_ok("la tirada 50 da el garantizado", int(t50.get("pity", -1)) == Upgrades.Rareza.EPICO)
	_ok("y es épico o mejor", s50 != null and int(s50.rareza) >= Upgrades.Rareza.EPICO)
	_ok("ahora sí se reinicia el contador (dispara el pity, no la suerte)",
		_cuenta(p, Upgrades.Rareza.EPICO) == 0)


# --- 4) La tirada 200: el mítico ---
func _probar_pity_200() -> void:
	print("\n-- El garantizado de 200 --")
	Game.biblioteca.clear()
	var p := _pj()
	var rng := _rng(31337)
	var ultimo: Dictionary = {}
	for i in 200:
		ultimo = Game.tirar_meditacion(p, rng, _pool(), _tochos)
	var s: SpellData = ultimo.get("spell")
	# EN LA 200 MANDA EL MITICO: es el mejor de los tres que vencen, y los otros dos van a la cola.
	_ok("la tirada 200 marca el garantizado de mítico",
		int(ultimo.get("pity", -1)) == Upgrades.Rareza.MITICO)
	_ok("y da mítico", s != null and int(s.rareza) >= Upgrades.Rareza.MITICO)


# --- 5) LA PRUEBA DEL FALLO QUE SE VIO JUGANDO ---
#
# Se llego a la 200 con una x10 y cayo SOLO la legendaria: vencian tambien el de epico y el de
# legendario, y el if/elif de entonces se quedaba con el mejor y tiraba los demas. Aqui se llega a la
# 200 y se comprueba que los TRES se cobran -- el mejor en la propia 200 y los otros dos en las dos
# tiradas siguientes, que es lo que pasa dentro de la misma x10.
func _probar_cola_no_pierde_nada() -> void:
	print("\n-- Los garantizados que coinciden NO se pierden --")
	Game.biblioteca.clear()
	var p := _pj()
	var rng := _rng(2024)
	for i in 199:
		Game.tirar_meditacion(p, rng, _pool(), _tochos)
	# La 200 y las dos siguientes: dentro de una x10 estas tres son cartas distintas de la misma tanda.
	var tres: Array = []
	for i in 3:
		tres.append(int(Game.tirar_meditacion(p, rng, _pool(), _tochos).get("pity", -1)))
	print("  las tres cartas de la 200 en adelante: %s" % str(tres))
	_ok("la 200 da el mítico", tres[0] == Upgrades.Rareza.MITICO)
	_ok("la siguiente cobra el legendario que también vencía", tres[1] == Upgrades.Rareza.LEGENDARIO)
	_ok("y la siguiente el épico", tres[2] == Upgrades.Rareza.EPICO)
	_ok("la cola queda vacía: no se debe nada",
		(Game.gacha_estado(p, Game.BANNER_ATAQUE)["cola"] as Array).is_empty())


# --- 6) LA COLA SOBREVIVE A UNA TIRADA SUELTA ---
#
# El caso que decidio que la cola se guardara en la partida: si tiras de x1 justo en la 200, los dos
# garantizados que sobran no tienen "siguientes tiradas de la tanda" donde caer. Tienen que esperar,
# aunque las proximas sean de mañana.
func _probar_cola_sobrevive_a_x1() -> void:
	print("\n-- Lo que sobra espera a la próxima tirada --")
	Game.biblioteca.clear()
	var p := _pj()
	var rng := _rng(4004)
	for i in 200:
		Game.tirar_meditacion(p, rng, _pool(), _tochos)
	var cola: Array = Game.gacha_estado(p, Game.BANNER_ATAQUE)["cola"]
	_ok("tras la 200 quedan dos garantizados apuntados (%d)" % cola.size(), cola.size() == 2)
	# Que la cola sobreviva a guardar y cargar (el "aunque sea otro dia") se prueba en _probar_guardado,
	# que es el que trabaja con el LIDER: es el unico personaje cuyo pity viaja desmontado en campos
	# planos del SaveData, y por tanto el unico donde se puede perder.
	var t: Dictionary = Game.tirar_meditacion(p, rng, _pool(), _tochos)
	_ok("la siguiente tirada cobra uno", int(t.get("pity", -1)) >= Upgrades.Rareza.EPICO)
	_ok("y queda uno pendiente",
		(Game.gacha_estado(p, Game.BANNER_ATAQUE)["cola"] as Array).size() == 1)


# --- 7) Los tres escalones van por su cuenta ---
func _probar_contadores_independientes() -> void:
	print("\n-- Los tres escalones son independientes --")
	Game.biblioteca.clear()
	var p := _pj()
	var rng := _rng(8)
	for i in 50:
		Game.tirar_meditacion(p, rng, _pool(), _tochos)
	_ok("tras 50 tiradas el de épico se ha reiniciado", _cuenta(p, Upgrades.Rareza.EPICO) == 0)
	_ok("pero el de legendario sigue contando (va por 50)",
		_cuenta(p, Upgrades.Rareza.LEGENDARIO) == 50)
	_ok("y el de mítico también", _cuenta(p, Upgrades.Rareza.MITICO) == 50)
	for i in 150:
		Game.tirar_meditacion(p, rng, _pool(), _tochos)
	_ok("en la 200 se reinician los tres",
		_cuenta(p, Upgrades.Rareza.EPICO) == 0 and _cuenta(p, Upgrades.Rareza.LEGENDARIO) == 0
		and _cuenta(p, Upgrades.Rareza.MITICO) == 0)


# --- 8) POR PERSONAJE ---
func _probar_por_personaje() -> void:
	print("\n-- El pity va por personaje --")
	Game.biblioteca.clear()
	var uno := _pj()
	var otro := _pj()
	var rng := _rng(600)
	for i in 49:
		Game.tirar_meditacion(uno, rng, _pool(), _tochos)
	_ok("el que medita va por 49", _cuenta(uno, Upgrades.Rareza.EPICO) == 49)
	_ok("y el otro sigue a 0: no le han gastado su pity",
		_cuenta(otro, Upgrades.Rareza.EPICO) == 0)
	var falta: Dictionary = Game.gacha_pity_restante(otro)
	_ok("al otro le siguen faltando sus 50", int(falta[Upgrades.Rareza.EPICO]) == 50)


# --- 9) Y POR BANNER ---
# Lo que hace que separar en banners signifique algo: tirar en uno no acerca el garantizado del otro.
func _probar_por_banner() -> void:
	print("\n-- Y el pity va por banner --")
	Game.biblioteca.clear()
	var p := _pj()
	var rng := _rng(1500)
	for i in 40:
		Game.tirar_meditacion(p, rng, _pool(Game.BANNER_ATAQUE), _tochos, Game.BANNER_ATAQUE)
	_ok("40 tiradas en el de ataque cuentan ahí",
		_cuenta(p, Upgrades.Rareza.EPICO, Game.BANNER_ATAQUE) == 40)
	_ok("y el de imbuiciones sigue a 0",
		_cuenta(p, Upgrades.Rareza.EPICO, Game.BANNER_IMBUICIONES) == 0)
	var falta: Dictionary = Game.gacha_pity_restante(p, Game.BANNER_IMBUICIONES)
	_ok("al de imbuiciones le faltan sus 50 enteras",
		int(falta[Upgrades.Rareza.EPICO]) == 50)


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
		_sin_pity(p)
		var t: Dictionary = Game.tirar_meditacion(p, rng, _pool(), _tochos)
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
	lider.gacha_pity.clear()
	var est: Dictionary = Game.gacha_estado(lider, Game.BANNER_ATAQUE)
	est["n"][Upgrades.Rareza.EPICO] = 37
	est["n"][Upgrades.Rareza.LEGENDARIO] = 87
	est["cola"] = [Upgrades.Rareza.LEGENDARIO]
	lider.gacha_total = 137
	# Y el CUPO del novato, que es del mundo y va por su cuenta.
	Game.tiradas_novato = 12
	Game.gacha_apuntar(lider, _grimorio_consumible(), Upgrades.Rareza.EPICO)
	var d: SaveData = Game.exportar_partida()
	_ok("el save se lleva el pity del líder, por banner",
		int(((d.player_gacha_pity.get(&"ataque", {}) as Dictionary).get("n", {}) as Dictionary)
			.get(Upgrades.Rareza.EPICO, 0)) == 37)
	_ok("y la cola de garantizados pendientes",
		((d.player_gacha_pity.get(&"ataque", {}) as Dictionary).get("cola", []) as Array).size() == 1)
	_ok("y el cupo del banner de novato", d.tiradas_novato == 12)
	_ok("y la entrada del historial", d.gacha_historial.size() == 1)
	# Se ensucia a proposito ANTES de cargar: si importar_partida no escribiera los campos, la
	# prueba pasaria igual leyendo lo que ya habia en memoria.
	lider.gacha_pity.clear()
	lider.gacha_total = 0
	Game.tiradas_novato = 0
	Game.gacha_historial.clear()
	Game.gacha_historial.append({"nombre": "basura que no debería sobrevivir"})
	Game.importar_partida(d)
	var l2: PersonajeData = Game.lider()
	_ok("al cargar vuelve el pity del líder",
		_cuenta(l2, Upgrades.Rareza.EPICO) == 37 and _cuenta(l2, Upgrades.Rareza.LEGENDARIO) == 87)
	_ok("y la cola pendiente",
		(Game.gacha_estado(l2, Game.BANNER_ATAQUE)["cola"] as Array).size() == 1)
	_ok("y el cupo del novato", Game.tiradas_novato == 12)
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


# --- 10) LA MIGRACION de las partidas de antes de los banners ---
#
# El que ya llevaba 180 tiradas acumuladas no puede perderlas por una actualizacion: sus dos
# contadores planos se vuelcan al banner de ataque, que es el que era el gacha entero.
func _probar_migracion() -> void:
	print("\n-- Las partidas de antes de los banners no pierden su pity --")
	var p := _pj()
	p.gacha_pity.clear()
	p.gacha_n50 = 31
	p.gacha_n200 = 180
	Game.gacha_migrar_pity(p)
	_ok("el de épico llega al banner de ataque", _cuenta(p, Upgrades.Rareza.EPICO) == 31)
	_ok("y el de legendario también", _cuenta(p, Upgrades.Rareza.LEGENDARIO) == 180)
	_ok("los contadores viejos quedan a cero: no se cobra dos veces",
		p.gacha_n50 == 0 and p.gacha_n200 == 0)
	# El de legendario estaba en 200 y ahora esta en 100: el que venia con 180 encima ya lo tiene
	# vencido, y se lo cobra en la siguiente tirada. Le debiamos una.
	var falta: Dictionary = Game.gacha_pity_restante(p)
	_ok("con 180 acumuladas, el legendario le toca YA (faltan %d)"
		% int(falta[Upgrades.Rareza.LEGENDARIO]), int(falta[Upgrades.Rareza.LEGENDARIO]) == 0)
	# Y NO SE VUELVE A MIGRAR: si volviera a entrar, machacaria lo que lleve acumulado desde entonces.
	p.gacha_n50 = 999
	Game.gacha_migrar_pity(p)
	_ok("y no vuelve a migrar (no machaca lo de después)",
		_cuenta(p, Upgrades.Rareza.EPICO) == 31)


func _grimorio_consumible() -> ConsumableData:
	return load(Libros.GRIMORIOS[0]) as ConsumableData


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
