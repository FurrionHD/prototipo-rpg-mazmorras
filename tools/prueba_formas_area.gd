# ============================================================
#  PRUEBA: LAS FORMAS DE AREA EN EL MAPA
#  Comprueba sin ventana la geometria de CombatFormas y la derivacion desde las fichas de VERDAD
#  (las 120 habilidades y los 30 hechizos del juego):
#    1) la geometria hace lo que dice (dentro/fuera de circulo, cono, linea y rectangulo);
#    2) toda habilidad y todo hechizo derivan una forma valida, sin reventar;
#    3) area_max sigue siendo TOPE DURO: la forma propone, area_max trunca;
#    4) el principal sale SIEMPRE el primero, aunque este lejos del centro de la huella;
#    5) el desempate es por orden (el indice de _enemies), que es lo que comparten anfitrion y
#       espejo -- sin eso, en red cada maquina repartiria distinto;
#    6) lo que diga la FICHA gana a la derivacion;
#    7) quien tienes pegado al cuerpo entra en tu cono (el caso de angulo degenerado).
#  Y de paso imprime el reparto de formas derivadas, que es la lista de por donde empezar a
#  decidirlas una a una.
#
#    godot --headless --path . res://tools/prueba_formas_area.tscn
# ============================================================
extends Node

const DIR_HAB := "res://resources/abilities"
const DIR_SPELL := "res://resources/spells"
const RADIO_ARENA := 220.0

var _fallos: int = 0

const NOMBRES := ["PUNTO", "CIRCULO", "CONO", "LINEA", "RECTANGULO"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_probar_geometria()
	_probar_alcanzados()
	_probar_ficha_manda()
	_probar_catalogo()
	print("[formas] RESULTADO: %s (%d fallos)"
		% ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)


# 1) y 7) LA GEOMETRIA.
func _probar_geometria() -> void:
	var c := CombatFormas.circulo(Vector2(100, 100), 50.0)
	_afirmar(c.contiene(Vector2(100, 100)), "circulo: no se contiene a si mismo")
	_afirmar(c.contiene(Vector2(140, 100)), "circulo: deberia pillar a 40 px")
	_afirmar(not c.contiene(Vector2(160, 100)), "circulo: NO deberia pillar a 60 px")

	# Cono de 90 grados mirando a la derecha: pilla lo de delante, no lo de detras ni lo de al lado.
	var k := CombatFormas.cono(Vector2.ZERO, Vector2.RIGHT, 100.0, 90.0)
	_afirmar(k.contiene(Vector2(50, 0)), "cono: deberia pillar lo de justo delante")
	_afirmar(k.contiene(Vector2(50, 40)), "cono: deberia pillar dentro del abanico")
	_afirmar(not k.contiene(Vector2(50, 90)), "cono: NO deberia pillar fuera del abanico")
	_afirmar(not k.contiene(Vector2(-50, 0)), "cono: NO deberia pillar lo de DETRAS")
	_afirmar(not k.contiene(Vector2(150, 0)), "cono: NO deberia pillar mas alla del radio")
	# 7) El que tienes ENCIMA entra: un vector casi nulo no tiene angulo fiable.
	_afirmar(k.contiene(Vector2.ZERO), "cono: el que tienes pegado al cuerpo tiene que entrar")

	var l := CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 200.0, 40.0)
	_afirmar(l.contiene(Vector2(100, 0)), "linea: deberia pillar lo de en medio")
	_afirmar(l.contiene(Vector2(100, 19)), "linea: deberia pillar dentro del ancho")
	_afirmar(not l.contiene(Vector2(100, 30)), "linea: NO deberia pillar fuera del ancho")
	_afirmar(not l.contiene(Vector2(250, 0)), "linea: NO deberia pillar mas alla del largo")
	_afirmar(not l.contiene(Vector2(-20, 0)), "linea: NO deberia pillar lo de DETRAS")

	var r := CombatFormas.rectangulo(Vector2(0, 0), Vector2(100, 60))
	_afirmar(r.contiene(Vector2(40, 20)), "rectangulo: deberia pillar lo de dentro")
	_afirmar(not r.contiene(Vector2(60, 0)), "rectangulo: NO deberia pillar lo de fuera")
	# Girado 90 grados, lo que antes entraba por ancho ahora entra por alto.
	var r2 := CombatFormas.rectangulo(Vector2(0, 0), Vector2(100, 60), Vector2.DOWN)
	_afirmar(r2.contiene(Vector2(0, 40)), "rectangulo girado: no giro")
	_afirmar(not r2.contiene(Vector2(40, 0)), "rectangulo girado: giro de menos")

	# El radio crece con los objetivos que se piden.
	_afirmar(CombatFormas.radio_para(4) > CombatFormas.radio_para(2),
		"radio_para: pedir mas objetivos tiene que dar mas radio")


# 3), 4) y 5) A QUIEN PILLA.
func _probar_alcanzados() -> void:
	# Cinco cuerpos en fila, separados 50 px. La forma es un circulo gordo que los tapa a todos.
	var pos := {}
	var orden := {}
	var todos: Array = []
	for i in 5:
		var c := RefCounted.new()
		pos[c] = Vector2(float(i) * 50.0, 0.0)
		orden[c] = i
		todos.append(c)
	var pos_de := func(c): return pos[c]
	var orden_de := func(c): return orden[c]

	var f := CombatFormas.circulo(Vector2(100, 0), 500.0)

	# 3) TOPE DURO: pide 3 y no pueden salir 5, por mucho que la forma los tape.
	var tres: Array = CombatFormas.alcanzados(f, todos, todos[2], 3, pos_de, orden_de)
	_afirmar(tres.size() == 3, "alcanzados: el tope de 3 devolvio %d" % tres.size())

	# 4) EL PRINCIPAL, EL PRIMERO, aunque sea el mas lejano al centro de la huella.
	var lejos: Array = CombatFormas.alcanzados(f, todos, todos[4], 3, pos_de, orden_de)
	_afirmar(not lejos.is_empty() and lejos[0] == todos[4],
		"alcanzados: el principal no salio el primero")

	# ...y los que le siguen van por cercania al centro (el centro esta en el cuerpo 2).
	_afirmar(tres.size() == 3 and tres[0] == todos[2]
		and (tres.has(todos[1]) and tres.has(todos[3])),
		"alcanzados: los secundarios no salieron por cercania al centro")

	# 5) DESEMPATE POR ORDEN. Dos a la MISMA distancia del centro: tiene que ganar el de indice
	#    menor, siempre, o el espejo repartiria distinto que el anfitrion.
	var a := RefCounted.new()
	var b := RefCounted.new()
	var p := RefCounted.new()
	var pos2 := {a: Vector2(-60, 0), b: Vector2(60, 0), p: Vector2(0, 0)}
	var ord2 := {a: 7, b: 3, p: 0}
	var f2 := CombatFormas.circulo(Vector2.ZERO, 500.0)
	var res: Array = CombatFormas.alcanzados(f2, [a, b, p], p, 3,
		func(c): return pos2[c], func(c): return ord2[c])
	_afirmar(res.size() == 3 and res[0] == p and res[1] == b,
		"alcanzados: el empate no se rompio por orden (tenia que ganar el indice 3)")


# 6) LO QUE DIGA LA FICHA GANA.
func _probar_ficha_manda() -> void:
	var ab := AbilityData.new()
	ab.area_modo = AbilityData.AreaModo.SPLASH
	ab.area_max = 3
	# Sin forma en la ficha: se deduce un circulo.
	var derivada: CombatFormas.Forma = CombatFormas.de_habilidad(
		ab, Vector2.ZERO, Vector2(100, 0), RADIO_ARENA)
	_afirmar(derivada.tipo == CombatFormas.Tipo.CIRCULO,
		"derivacion: un SPLASH de 3 tenia que salir CIRCULO, salio %s" % derivada)

	# Con forma en la ficha: manda ella.
	ab.forma = CombatFormas.Tipo.CONO
	ab.forma_radio = 150.0
	ab.forma_apertura = 60.0
	var suya: CombatFormas.Forma = CombatFormas.de_habilidad(
		ab, Vector2.ZERO, Vector2(100, 0), RADIO_ARENA)
	_afirmar(suya.tipo == CombatFormas.Tipo.CONO, "la ficha no gano a la derivacion")
	_afirmar(is_equal_approx(suya.radio, 150.0), "la ficha no impuso su radio")
	_afirmar(is_equal_approx(suya.apertura, 60.0), "la ficha no impuso su apertura")

	# El molinete: circulo alrededor de QUIEN ATACA, no de donde apunta.
	ab.forma = CombatFormas.Tipo.CIRCULO
	ab.forma_desde_quien_ataca = true
	var mol: CombatFormas.Forma = CombatFormas.de_habilidad(
		ab, Vector2.ZERO, Vector2(100, 0), RADIO_ARENA)
	_afirmar(mol.centro.is_equal_approx(Vector2.ZERO),
		"desde_quien_ataca: el circulo tenia que caer sobre el atacante, cayo en %s" % mol.centro)
	ab.forma_desde_quien_ataca = false
	var sis: CombatFormas.Forma = CombatFormas.de_habilidad(
		ab, Vector2.ZERO, Vector2(100, 0), RADIO_ARENA)
	_afirmar(sis.centro.is_equal_approx(Vector2(100, 0)),
		"sin desde_quien_ataca: el circulo tenia que caer donde apuntas, cayo en %s" % sis.centro)


# 2) TODO EL CATALOGO DE VERDAD.
func _probar_catalogo() -> void:
	var cuenta_h := {}
	var n_h: int = 0
	for ruta in _tres_de(DIR_HAB):
		var ab = ResourceLoader.load(ruta)
		if ab == null or not (ab is AbilityData):
			continue
		n_h += 1
		var f: CombatFormas.Forma = CombatFormas.de_habilidad(
			ab, Vector2.ZERO, Vector2(80, 0), RADIO_ARENA)
		if not _forma_valida(f, ruta):
			continue
		cuenta_h[f.tipo] = int(cuenta_h.get(f.tipo, 0)) + 1
		# El tope se respeta: una habilidad de area con area_max chico no puede tapar la arena.
		if ab.es_area() and ab.area_max > 1 and ab.area_max < 99 \
				and f.tipo == CombatFormas.Tipo.CIRCULO:
			_afirmar(f.radio < RADIO_ARENA,
				"%s: area_max=%d pero su circulo tapa la arena entera" % [ruta, ab.area_max])

	var cuenta_s := {}
	var n_s: int = 0
	for ruta in _tres_de(DIR_SPELL):
		var sp = ResourceLoader.load(ruta)
		if sp == null or not (sp is SpellData):
			continue
		n_s += 1
		var f2: CombatFormas.Forma = CombatFormas.de_hechizo(
			sp, Vector2.ZERO, Vector2(80, 0), RADIO_ARENA)
		if not _forma_valida(f2, ruta):
			continue
		cuenta_s[f2.tipo] = int(cuenta_s.get(f2.tipo, 0)) + 1

	_afirmar(n_h > 50, "solo se leyeron %d habilidades: ¿se movio la carpeta?" % n_h)
	_afirmar(n_s > 10, "solo se leyeron %d hechizos: ¿se movio la carpeta?" % n_s)
	print("[formas] %d habilidades -> %s" % [n_h, _resumen(cuenta_h)])
	print("[formas] %d hechizos    -> %s" % [n_s, _resumen(cuenta_s)])


func _forma_valida(f: CombatFormas.Forma, ruta: String) -> bool:
	if f == null:
		_fallo("%s: no derivo ninguna forma" % ruta)
		return false
	var medida: float = maxf(maxf(f.radio, f.largo), maxf(f.tam.x, f.tam.y))
	if medida <= 0.0:
		_fallo("%s: derivo una forma de tamaño 0 (%s)" % [ruta, f])
		return false
	if not f.contiene(f.centro_util()):
		_fallo("%s: la forma %s no se contiene ni a si misma" % [ruta, f])
		return false
	return true


func _resumen(cuenta: Dictionary) -> String:
	var partes: Array = []
	for t in [0, 1, 2, 3, 4]:
		if cuenta.has(t):
			partes.append("%s %d" % [NOMBRES[t], int(cuenta[t])])
	return ", ".join(partes)


func _tres_de(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		_fallo("no se pudo abrir %s" % dir)
		return out
	for f in d.get_files():
		# En el .exe los .tres se exportan como .remap; en el proyecto, tal cual.
		var n: String = f.trim_suffix(".remap")
		if n.ends_with(".tres"):
			out.append("%s/%s" % [dir, n])
	return out


func _afirmar(ok: bool, mensaje: String) -> void:
	if not ok:
		_fallo(mensaje)


func _fallo(mensaje: String) -> void:
	_fallos += 1
	if _fallos <= 25:
		print("[formas] FALLO  %s" % mensaje)
