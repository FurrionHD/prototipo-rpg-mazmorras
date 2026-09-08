# ============================================================
#  dev_grimorios.gd  --  HERRAMIENTA, no parte del juego.
#
#  El REPARTO DE GRIMORIOS del gacha: peso por rareza, y dentro de cada rareza a partes iguales.
#
#  Lo que se comprueba, y por que cada cosa:
#    1. Cada hechizo tiene su rareza y el pool es el que se espera (16: todos menos pulso menor,
#       que viene con el arma, y CON Tormenta, que antes no tenia libro).
#    2. LA MONOTONIA: un hechizo de banda alta NO puede salir mas que uno de banda baja. Es el
#       fallo que se cuela solo, porque el peso es DE LA BANDA y hay que partirlo entre sus
#       miembros: con el primer reparto que se escribio, un RARO salia la mitad que un EPICO.
#    3. Que la cuenta sale como dice la tabla, hechizo a hechizo.
#    4. EL SESGO DEL REPETIDO: baja, pero NUNCA a cero. En un gacha se pierde.
#    5. Que el sesgo va POR PERSONAJE. Es lo que permite conseguir magias para uno nuevo: si
#       contara lo que sabe el grupo, el recien llegado no sacaria nada.
#    6. QUE AÑADIR UN HECHIZO NO TOCA CODIGO: se mete un segundo legendario de mentira y cada uno
#       tiene que pasar a salir la mitad, sin cambiar una sola constante. Es el objetivo del diseño
#       entero, asi que se prueba de verdad.
#    7. Que el sorteo real converge a esas probabilidades (muchas tiradas con semilla fija).
#
#  Es logica pura, sin Control ni captura, asi que aqui SI vale --headless.
#
#    godot --headless --path . res://tools/visores/dev_grimorios.tscn
# ============================================================
extends Node

const SPELLS_DIR := "res://resources/spells/"
const GRIMORIOS_DIR := "res://resources/consumables/"
const TIRADAS := 200000

var _fallos: int = 0
var _hechas: int = 0
var _pool: Array = []      # los hechizos que tienen grimorio


func _ready() -> void:
	print("=== REPARTO DE GRIMORIOS ===")
	_cargar_pool()
	_probar_pool()
	_probar_monotonia()
	_probar_cuentas()
	_probar_sesgo()
	_probar_por_personaje()
	_probar_banda_nueva()
	_probar_sorteo()
	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


# El pool del gacha es "los hechizos que tienen libro". Se deriva de los ficheros y no de una lista
# escrita aqui: una lista propia acabaria discrepando de la carpeta el dia que se añada uno.
func _cargar_pool() -> void:
	var d := DirAccess.open(SPELLS_DIR)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var id: String = f.get_basename()
		if not ResourceLoader.exists("%sgrimorio_%s.tres" % [GRIMORIOS_DIR, id]):
			continue
		var s: SpellData = load(SPELLS_DIR + f) as SpellData
		if s != null:
			_pool.append(s)


func _probar_pool() -> void:
	print("\n-- El pool --")
	_ok("hay 16 hechizos con grimorio", _pool.size() == 16)
	var nombres: Array = []
	for s in _pool:
		nombres.append(String(s.resource_path).get_file().get_basename())
	_ok("pulso menor NO está (viene con el arma)", not nombres.has("pulso_menor"))
	_ok("tormenta SÍ está (ya tiene libro)", nombres.has("tormenta"))
	var cuenta: Dictionary = _por_banda()
	print("     por banda: %s" % cuenta)
	_ok("las cinco bandas tienen a alguien", cuenta.size() == 5)


# --- 2) LA MONOTONIA, que es la comprobacion que justifica este visor ---
func _probar_monotonia() -> void:
	print("\n-- Monotonía: más raro = sale menos --")
	var probs: Dictionary = Game.probs_grimorio(_pool, PersonajeData.new())
	# Una probabilidad POR BANDA (todos los de una banda salen lo mismo, asi que basta con uno).
	var por_banda := {}
	for s in probs:
		por_banda[int(s.rareza)] = float(probs[s])
	var bandas: Array = por_banda.keys()
	bandas.sort()
	var linea: Array = []
	for b in bandas:
		linea.append("%s %.2f%%" % [_nombre_banda(int(b)), float(por_banda[b]) * 100.0])
	print("     cada hechizo sale: %s" % "  ·  ".join(linea))
	var rotas: Array = []
	for i in range(bandas.size() - 1):
		var baja: float = float(por_banda[bandas[i]])
		var alta: float = float(por_banda[bandas[i + 1]])
		if alta >= baja:
			rotas.append("%s (%.2f%%) no sale menos que %s (%.2f%%)" % [
				_nombre_banda(int(bandas[i + 1])), alta * 100.0,
				_nombre_banda(int(bandas[i])), baja * 100.0])
	if rotas.is_empty():
		_ok("cada banda sale menos que la anterior", true)
	else:
		_ok("ORDEN ROTO: %s" % " | ".join(rotas), false)
	# Y el objetivo que se puso a mano: Tormenta en el 2%.
	var t: float = float(por_banda.get(Upgrades.Rareza.LEGENDARIO, 0.0))
	_ok("Tormenta sale ~2%% (sale %.2f%%)" % (t * 100.0), absf(t - 0.02) < 0.005)


# --- 3) La cuenta, hechizo a hechizo ---
func _probar_cuentas() -> void:
	print("\n-- La cuenta --")
	var probs: Dictionary = Game.probs_grimorio(_pool, PersonajeData.new())
	var cuenta: Dictionary = _por_banda()
	var total_pesos: float = 0.0
	for b in cuenta:
		total_pesos += float(Game.PESO_RAREZA_GRIMORIO.get(b, 0.0))
	var malos: Array = []
	for s in probs:
		var b: int = int(s.rareza)
		# lo que TIENE que salir: el peso de su banda, entre sus miembros, entre el total.
		var esperado: float = float(Game.PESO_RAREZA_GRIMORIO.get(b, 0.0)) \
			/ float(cuenta[b]) / total_pesos
		if absf(float(probs[s]) - esperado) > 0.0001:
			malos.append(s.nombre)
	_ok("los 16 salen lo que dice la tabla" if malos.is_empty()
		else "NO CUADRAN: %s" % ", ".join(malos), malos.is_empty())
	var suma: float = 0.0
	for s in probs:
		suma += float(probs[s])
	_ok("las probabilidades suman 1", absf(suma - 1.0) < 0.0001)


# --- 4) El sesgo del repetido ---
func _probar_sesgo() -> void:
	print("\n-- El repetido: baja, pero nunca a cero --")
	var p := PersonajeData.new()
	var s: SpellData = _pool[0]
	var antes: float = float(Game.pesos_grimorio(_pool, p)[s])
	Game.aprender_hechizo(s, p)
	var despues: float = float(Game.pesos_grimorio(_pool, p)[s])
	_ok("sabérselo le baja el peso", despues < antes)
	_ok("pero NO lo deja a cero (sigue pudiendo tocar)", despues > 0.0)
	_ok("baja lo que dice la constante",
		absf(despues - antes * Game.GRIMORIO_SABIDO_MULT) < 0.0001)
	# Y los demas no se enteran: sesgar uno no puede mover el peso CRUDO de otro.
	var otro: SpellData = _pool[1]
	var p2 := PersonajeData.new()
	_ok("saberse uno no cambia el peso de otro",
		is_equal_approx(float(Game.pesos_grimorio(_pool, p)[otro]),
			float(Game.pesos_grimorio(_pool, p2)[otro])))


# --- 5) POR PERSONAJE: lo que hace posible equipar a uno nuevo ---
func _probar_por_personaje() -> void:
	print("\n-- El sesgo va por personaje --")
	var veterano := PersonajeData.new()
	for s in _pool:
		Game.aprender_hechizo(s, veterano)
	var novato := PersonajeData.new()

	var pv: Dictionary = Game.probs_grimorio(_pool, veterano)
	var pn: Dictionary = Game.probs_grimorio(_pool, novato)
	# El veterano se lo sabe TODO: todo su reparto esta sesgado por igual, asi que al normalizar
	# vuelve a la forma de siempre. Es lo que se busco: en un gacha se sigue perdiendo.
	_ok("el que se lo sabe todo sigue sacando grimorios",
		absf(float(pv[_pool[0]]) - float(pn[_pool[0]])) < 0.0001)
	# Y lo que de verdad importa: al novato no le afecta NADA lo que sepa el otro.
	var comun: SpellData = _de_banda(Upgrades.Rareza.COMUN)
	_ok("el novato tiene la tabla limpia", float(pn[comun]) > 0.10)


# --- 6) EL OBJETIVO DEL DISEÑO: un hechizo nuevo no toca codigo ---
func _probar_banda_nueva() -> void:
	print("\n-- Meter otro legendario no toca código --")
	var p := PersonajeData.new()
	var antes: Dictionary = Game.probs_grimorio(_pool, p)
	var tormenta: SpellData = _de_banda(Upgrades.Rareza.LEGENDARIO)
	var p_antes: float = float(antes[tormenta])

	# Un legendario de mentira, como sera el "Shock térmico fulminante". No se guarda en disco: solo
	# se mete en el pool, que es justo lo que hara el hechizo nuevo el dia que exista.
	var nuevo := SpellData.new()
	nuevo.nombre = "Hechizo legendario de prueba"
	nuevo.rareza = Upgrades.Rareza.LEGENDARIO
	var pool2: Array = _pool.duplicate()
	pool2.append(nuevo)
	var despues: Dictionary = Game.probs_grimorio(pool2, p)

	_ok("ahora Tormenta sale la MITAD (%.2f%% -> %.2f%%)" % [
		p_antes * 100.0, float(despues[tormenta]) * 100.0],
		absf(float(despues[tormenta]) - p_antes * 0.5) < 0.0005)
	_ok("y el nuevo sale lo mismo que ella",
		absf(float(despues[nuevo]) - float(despues[tormenta])) < 0.0001)
	# Las otras bandas NO se enteran: el legendario nuevo se come el trozo de su propia banda.
	var comun: SpellData = _de_banda(Upgrades.Rareza.COMUN)
	_ok("las demás bandas no se mueven",
		absf(float(despues[comun]) - float(antes[comun])) < 0.0001)


# --- 7) El sorteo de verdad ---
func _probar_sorteo() -> void:
	print("\n-- El sorteo real (%d tiradas) --" % TIRADAS)
	var p := PersonajeData.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260908
	var salidas := {}
	var nulos: int = 0
	for i in TIRADAS:
		var s: SpellData = Game.sortear_grimorio(_pool, rng, p)
		if s == null:
			nulos += 1
			continue
		salidas[s] = int(salidas.get(s, 0)) + 1
	_ok("el sorteo nunca devuelve nada vacío", nulos == 0)
	_ok("han salido los 16 alguna vez", salidas.size() == 16)

	var probs: Dictionary = Game.probs_grimorio(_pool, p)
	var peor: float = 0.0
	var quien: String = ""
	for s in probs:
		var esperada: float = float(probs[s])
		var real: float = float(salidas.get(s, 0)) / float(TIRADAS)
		var desvio: float = absf(real - esperada)
		if desvio > peor:
			peor = desvio
			quien = s.nombre
	print("     el que más se desvía: %s (%.3f puntos)" % [quien, peor * 100.0])
	# Margen amplio a proposito: esto vigila que el sorteo siga la tabla, no el ruido del azar.
	_ok("la frecuencia real cuadra con la tabla", peor < 0.005)


# --- utilidades ---
func _por_banda() -> Dictionary:
	var cuenta := {}
	for s in _pool:
		cuenta[int(s.rareza)] = int(cuenta.get(int(s.rareza), 0)) + 1
	return cuenta


func _de_banda(b: int) -> SpellData:
	for s in _pool:
		if int(s.rareza) == b:
			return s
	return null


func _nombre_banda(b: int) -> String:
	var n := ["común", "poco común", "raro", "épico", "legendario", "mítico", "obra maestra", "prístino"]
	return n[b] if b >= 0 and b < n.size() else "?"


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
