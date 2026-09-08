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
	# Contra el MANIFIESTO, no contra un numero escrito aqui. La primera version decia "16" a pelo y
	# al añadir el Shock termico fallo por el motivo equivocado: el reparto estaba perfecto y lo que
	# estaba mal era la expectativa. Un visor que hay que retocar cada vez que añades contenido
	# acaba desactivado.
	var Libros = load("res://scripts/core/libros.gd")
	_ok("el pool son los %d grimorios del manifiesto" % Libros.GRIMORIOS.size(),
		_pool.size() == Libros.GRIMORIOS.size())
	var nombres: Array = []
	for s in _pool:
		nombres.append(String(s.resource_path).get_file().get_basename())
	_ok("pulso menor NO está (viene con el arma)", not nombres.has("pulso_menor"))
	_ok("tormenta SÍ está (ya tiene libro)", nombres.has("tormenta"))
	var cuenta: Dictionary = _por_banda()
	print("     por banda: %s" % cuenta)
	# Que TODA banda con peso tenga a alguien dentro. Antes decia "las cinco bandas" a pelo y al
	# entrar la mitica fallo por el motivo equivocado: habia seis y el reparto estaba perfecto.
	var vacias: Array = []
	for banda in Game.PESO_RAREZA_GRIMORIO:
		if int(cuenta.get(banda, 0)) == 0:
			vacias.append(_nombre_banda(int(banda)))
	_ok("las %d bandas con peso tienen a alguien" % Game.PESO_RAREZA_GRIMORIO.size()
		if vacias.is_empty() else "BANDAS CON PESO Y SIN HECHIZOS: %s" % ", ".join(vacias),
		vacias.is_empty())

	# EL PANEL DE DEBUG TIENE QUE VERLOS TODOS. Se comprueba contra un escaneo REAL de la carpeta y
	# no contra el manifiesto, que es lo unico que caza las dos averias posibles: que el manifiesto
	# se haya quedado corto, y que alguien vuelva a clavar una lista a mano en otro sitio.
	#
	# Esto existe porque paso: _dev_spells era una lista escrita a mano y el Shock termico no se
	# podia ni equipar para probarlo. Una herramienta de pruebas que no ve el contenido nuevo es
	# justo la que falla el dia que la necesitas.
	var en_disco: Array = []
	var dd := DirAccess.open(SPELLS_DIR)
	if dd != null:
		for f in dd.get_files():
			if f.ends_with(".tres"):
				en_disco.append(SPELLS_DIR + f)
	en_disco.sort()
	var del_panel: Array = Array(Game._dev_spells)
	del_panel.sort()
	var faltan: Array = []
	for r in en_disco:
		if not del_panel.has(r):
			faltan.append(String(r).get_file().get_basename())
	_ok("el panel de debug ve los %d hechizos de la carpeta" % en_disco.size() if faltan.is_empty()
		else "EL PANEL DE DEBUG NO VE: %s" % ", ".join(faltan), faltan.is_empty())

	# QUE CADA .tres ESTE COMPLETO. Los hechizos se escriben a mano y un campo mal tecleado no da
	# error: se queda en su valor por defecto. Un hechizo sin frases no se puede recitar —o sea, no
	# se puede lanzar— y el panel de debug lo pintaria como "0 frases" sin quejarse de nada.
	var mudos: Array = []
	var sin_nombre: Array = []
	for r in en_disco:
		var s: SpellData = load(r) as SpellData
		if s == null:
			continue
		if s.frases.is_empty():
			mudos.append(String(r).get_file().get_basename())
		if s.nombre.strip_edges() == "" or s.nombre == "Hechizo":
			sin_nombre.append(String(r).get_file().get_basename())
	_ok("todos tienen frases de recitado" if mudos.is_empty()
		else "SIN FRASES (no se pueden lanzar): %s" % ", ".join(mudos), mudos.is_empty())
	_ok("todos tienen nombre propio" if sin_nombre.is_empty()
		else "SIN NOMBRE: %s" % ", ".join(sin_nombre), sin_nombre.is_empty())

	# CADA MAGIA CON SUS PROPIAS FRASES. Dos hechizos que empiezan igual son dos hechizos que en
	# combate no se distinguen hasta la segunda frase -- y el recitado es justo lo que les da
	# personalidad. Paso al copiar una frase del repositorio en dos curaciones distintas.
	var de_quien := {}
	var repes: Array = []
	for r3 in en_disco:
		var s3: SpellData = load(r3) as SpellData
		if s3 == null:
			continue
		for fr in s3.frases:
			var clave: String = String(fr).strip_edges().to_lower()
			if de_quien.has(clave):
				repes.append("«%s» (%s y %s)" % [fr, de_quien[clave], s3.nombre])
			else:
				de_quien[clave] = s3.nombre
	_ok("ninguna frase se repite entre hechizos" if repes.is_empty()
		else "FRASES REPETIDAS: %s" % " | ".join(repes), repes.is_empty())

	# EL QUE PIDE DIBUJO PROPIO TIENE QUE PODER DARSE DE ALTA.
	#
	# CombatFX.T_VUELO dice cuanto tarda cada efecto en llegar, y un estilo que no este en esa tabla
	# se queda en 0.0 -- que NO significa "sale al instante", significa "no se dibuja nada": el
	# `vuelo > 0` es lo que decide si el efecto llega siquiera a la capa.
	#
	# Esto no es teoria: el Shock termico se lanzo sin apuntar ahi y salia SIN NINGUN efecto en el
	# juego, mientras en el visor de la capa se veia perfecto (alli se da de alta a mano y la tabla
	# no interviene). Y es la segunda vez que muerde la misma piedra -- la primera se llevo por
	# delante las tres habilidades de la rata.
	var mudos_fx: Array = []
	for r2 in en_disco:
		var s2: SpellData = load(r2) as SpellData
		if s2 == null or s2.fx_estilo < 0:
			continue
		if float(CombatFX.T_VUELO.get(s2.fx_estilo, 0.0)) <= 0.0:
			mudos_fx.append("%s (estilo %d)" % [s2.nombre, s2.fx_estilo])
	_ok("los que piden dibujo propio están en CombatFX.T_VUELO" if mudos_fx.is_empty()
		else "SIN VUELO, o sea SIN EFECTO en el juego: %s" % ", ".join(mudos_fx),
		mudos_fx.is_empty())
	_probar_marcar_desde_debug()
	_probar_shock_termico()


# EL SHOCK TERMICO: que la secuencia sea SECUENCIA y que el x1.5 exista.
#
# El hechizo promete "prende y luego moja, y el agua sobre lo que arde pega mas". Eso son tres
# cosas que se pueden romper por separado y en silencio:
#   1. que los golpes salgan en ORDEN (con el sorteo, la mitad de las veces el agua iba primera)
#   2. que exista la regla Quemadura -> Agua x1.5 (antes solo estaba Mojado -> Rayo)
#   3. que el fuego aplique la quema ANTES de que resuelva el agua
func _probar_shock_termico() -> void:
	print("\n-- Shock térmico: la secuencia --")
	var s: SpellData = load("res://resources/spells/shock_termico.tres") as SpellData
	if s == null:
		_ok("el hechizo carga", false)
		return
	_ok("va en orden, no al azar", s.mix_en_orden)
	# El orden REAL de los golpes. Se pide varias veces: si siguiera sorteando, alguna saldria al
	# reves y la prueba lo cazaria.
	var siempre_bien: bool = true
	for _intento in 40:
		if s.elemento_de_golpe(0, s.hits) != Elementos.Elemento.FUEGO:
			siempre_bien = false
		if s.elemento_de_golpe(s.hits - 1, s.hits) != Elementos.Elemento.AGUA:
			siempre_bien = false
	_ok("el fuego SIEMPRE va primero y el agua después", siempre_bien)

	# LA REGLA, que es lo que hace que el segundo golpe valga la pena.
	var amp: Dictionary = Elementos.AMPLIFICA_POR_ESTADO.get(StatusEffects.Id.QUEMADURA, {})
	_ok("el agua pega más sobre algo que arde (x%.2f)" % float(amp.get(Elementos.Elemento.AGUA, 1.0)),
		float(amp.get(Elementos.Elemento.AGUA, 1.0)) > 1.0)
	# Y la que ya existia, que no se puede haber roto al añadir la nueva.
	var amp2: Dictionary = Elementos.AMPLIFICA_POR_ESTADO.get(StatusEffects.Id.MOJADO, {})
	_ok("y el rayo sigue pegando más sobre lo mojado",
		float(amp2.get(Elementos.Elemento.RAYO, 1.0)) > 1.0)

	# LA QUEMA VA ATADA AL FUEGO. Esto es ESTRUCTURA, no balance: si el elemento_req no fuera FUEGO,
	# la quema podria caer en el golpe de agua y el orden dejaria de significar nada.
	#
	# Lo que NO se comprueba aqui es su probabilidad. Se penso ponerla a 1.0 para que el combo no
	# fallara nunca, y es justo lo que no se debe hacer: los estados pasan por la Eficacia del que
	# lanza y la resistencia a efectos del que recibe, como todos los demas. Un hechizo que se salta
	# ese sistema esta roto, y ademas clavar el numero aqui convertiria una decision de balance en
	# una prueba que hay que retocar cada vez que se ajusta.
	var quema_de_fuego: bool = false
	var mojado_de_agua: bool = false
	for ap in s.efectos:
		if ap == null:
			continue
		if int(ap.estado) == StatusEffects.Id.QUEMADURA:
			quema_de_fuego = int(ap.elemento_req) == Elementos.Elemento.FUEGO and float(ap.prob) > 0.0
		if int(ap.estado) == StatusEffects.Id.MOJADO:
			mojado_de_agua = int(ap.elemento_req) == Elementos.Elemento.AGUA and float(ap.prob) > 0.0
	_ok("la quema solo la puede dejar el golpe de FUEGO", quema_de_fuego)
	_ok("y el mojado solo el de AGUA", mojado_de_agua)


# LO QUE HACE LA CASILLA DEL PANEL DE DEBUG, calcado.
#
# El fallo que arregla: equipar_hechizo corta si el hechizo no esta entre los DISPONIBLES, asi que
# marcar la casilla de uno SIN APRENDER no hacia nada de nada. Solo se dejaban poner y quitar los
# que ya te sabias, que es exactamente el sintoma que se vio jugando.
#
# Se prueba con un personaje PELADO a proposito: con uno que ya se lo sepa todo, el caso roto no
# existe y la prueba pasaria sin comprobar nada.
func _probar_marcar_desde_debug() -> void:
	print("\n-- Marcar un hechizo desde el panel de debug --")
	var pj := PersonajeData.new()
	var s: SpellData = _pool[0]
	_ok("de partida no se lo sabe", not Game.hechizos_sabidos(pj).has(s))

	# Se llama a LA MISMA funcion que el panel, no a una copia de sus pasos.
	_ok("al marcar la casilla, entra", Game.conceder_y_equipar_hechizo(s, pj))
	_ok("y se lo ha aprendido", Game.hechizos_sabidos(pj).has(s))
	_ok("y se lo pone", Game.hechizos_con_huecos(pj).has(s))

	# Y el ida y vuelta, que es lo unico que si funcionaba antes.
	Game.quitar_hechizo(s, pj)
	_ok("al desmarcar, se lo quita", not Game.hechizos_con_huecos(pj).has(s))
	_ok("pero sigue sabiendoselo", Game.hechizos_sabidos(pj).has(s))
	_ok("y al volver a marcar, vuelve", Game.conceder_y_equipar_hechizo(s, pj))

	# EL TOPE sigue mandando: con las manos llenas, el siguiente NO entra (y la casilla se desmarca).
	var puestos: int = 1
	for otro in _pool:
		if puestos >= Game.MAX_HECHIZOS:
			break
		if Game.hechizos_con_huecos(pj).has(otro):
			continue
		Game.conceder_y_equipar_hechizo(otro, pj)
		puestos += 1
	var sobrante: SpellData = null
	for otro2 in _pool:
		if not Game.hechizos_con_huecos(pj).has(otro2):
			sobrante = otro2
			break
	if sobrante == null:
		_ok("(no hay hechizos de sobra para probar el tope)", true)
		return
	_ok("con los %d huecos llenos, el siguiente NO entra" % Game.MAX_HECHIZOS,
		not Game.conceder_y_equipar_hechizo(sobrante, pj))
	_ok("aunque sí se lo haya aprendido", Game.hechizos_sabidos(pj).has(sobrante))


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
	# LAS DOS VISTAS, siempre juntas. La tabla enseñaba solo la de "por hechizo" y eso llevo a bajar
	# el peso mitico creyendo que estaba empatado con el legendario, cuando POR BANDA seguia siendo
	# tres veces mas raro. Son dos preguntas distintas y las dos importan:
	#   BANDA   - cada cuanto sale uno DE ESA RAREZA (lo que se siente al tirar)
	#   HECHIZO - cuanto cuesta UNO CONCRETO (lo que decide si un chase item es alcanzable)
	var cnt: Dictionary = _por_banda()
	var linea: Array = []
	var linea2: Array = []
	for b in bandas:
		var n_b: int = int(cnt.get(b, 1))
		linea.append("%s %.2f%%" % [_nombre_banda(int(b)), float(por_banda[b]) * float(n_b) * 100.0])
		linea2.append("%s %.2f%%" % [_nombre_banda(int(b)), float(por_banda[b]) * 100.0])
	print("     sale la BANDA:    %s" % "  ·  ".join(linea))
	print("     sale UN hechizo:  %s" % "  ·  ".join(linea2))
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
	# EL OBJETIVO QUE SE PUSO A MANO: la BANDA legendaria vale un 2%. Se comprueba la banda ENTERA y
	# no "Tormenta sale el 2%", porque en cuanto entro el segundo legendario cada uno paso a salir el
	# 1% -- que es lo correcto y lo buscado. Lo que tiene que mantenerse es el peso de la banda.
	var cuenta: Dictionary = _por_banda()
	var n_leg: int = int(cuenta.get(Upgrades.Rareza.LEGENDARIO, 0))
	var por_uno: float = float(por_banda.get(Upgrades.Rareza.LEGENDARIO, 0.0))
	var banda_leg: float = por_uno * float(n_leg)
	_ok("la banda legendaria vale ~2%% en total (%.2f%%, repartido entre %d)" % [
		banda_leg * 100.0, n_leg], absf(banda_leg - 0.02) < 0.005)


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

	# Con N legendarios ya dentro, meter uno mas los deja a N/(N+1) de lo que salian. Se escribe la
	# razon y no "la mitad": la mitad solo valia cuando Tormenta estaba sola, y en cuanto entro el
	# Shock termico esa expectativa dejo de ser cierta aunque el reparto estuviera bien.
	var n_leg: int = int(_por_banda().get(Upgrades.Rareza.LEGENDARIO, 1))
	var razon: float = float(n_leg) / float(n_leg + 1)
	_ok("cada legendario baja a %d/%d de lo que salía (%.2f%% -> %.2f%%)" % [
		n_leg, n_leg + 1, p_antes * 100.0, float(despues[tormenta]) * 100.0],
		absf(float(despues[tormenta]) - p_antes * razon) < 0.0005)
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
	_ok("han salido los %d alguna vez" % _pool.size(), salidas.size() == _pool.size())

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
