extends "res://tools/unitarias/caso.gd"
# LAS LUCES QUE HACEN SOMBRA (16/11, LucesSombra, memoria sombras-fuera-del-sprite): el sol con la hora y los focos del
# pueblo, cada uno con su direccion, su largo y su nivel de tono FIJO.

const ALTO := 30.0


# Un LuzPueblo de mentira: solo lo que lee LucesSombra (focos()).
class LuzFalsa extends Node:
	var lista: Array = []
	func focos() -> Array:
		return lista


func _foco(pos: Vector2, radio: float, fuerza: float = 1.0, siempre: bool = false) -> Dictionary:
	return {"pos": pos, "radio": radio, "fuerza": fuerza, "retraso": 0.0, "siempre": siempre}


func _sol_a(s: float) -> Array:
	CicloDia.hora_forzada = s
	var out: Array = []
	LucesSombra._sol(out, ALTO)
	CicloDia.hora_forzada = -1.0
	return out


func test_sol_con_la_hora() -> void:
	var man: Array = _sol_a(CicloDia.T_DIA + 60.0)
	var med: Array = _sol_a(CicloDia.T_NOCHE * 0.5)
	var tar: Array = _sol_a(CicloDia.T_ATARDECER - 60.0)
	if not (cierto(man.size() == 1 and med.size() == 1 and tar.size() == 1, "de dia hay sol")):
		return
	cierto((man[0]["dir"] as Vector2).x < -0.5, "por la mañana el sol esta al este: la sombra cae al oeste (%s)" % man[0]["dir"])
	cierto((tar[0]["dir"] as Vector2).x > 0.5, "por la tarde, al este (%s)" % tar[0]["dir"])
	cierto((med[0]["dir"] as Vector2).y < -0.9, "a mediodia, hacia el norte (arriba) (%s)" % med[0]["dir"])
	cierto(float(man[0]["largo"]) > float(med[0]["largo"]) * 1.5, "por la mañana mas larga que a mediodia (%.1f / %.1f)"
		% [man[0]["largo"], med[0]["largo"]])
	igual(float(med[0]["nivel"]), 1.0, "a pleno dia, los tres tonos")
	cierto(_sol_a(CicloDia.T_NOCHE + 100.0).is_empty(), "de noche no hay sol")


func test_focos_del_pueblo() -> void:
	var luz := LuzFalsa.new()
	CicloDia.hora_forzada = CicloDia.T_NOCHE + 300.0   # de noche: las antorchas encendidas
	var pos := Vector2(100, 100)
	luz.lista = [_foco(Vector2(60, 100), 120.0)]
	var out: Array = []
	LucesSombra._focos_pueblo(out, luz, pos, ALTO)
	if cierto(out.size() == 1, "una antorcha cerca: una sombra"):
		cierto((out[0]["dir"] as Vector2).is_equal_approx(Vector2(1, 0)), "lejos de la antorcha (%s)" % out[0]["dir"])
		igual(float(out[0]["nivel"]), 1.0, "cerca, los tres tonos")
	# Dos luces de fuerza parecida a los dos lados: DOS sombras, una a cada lado.
	luz.lista = [_foco(Vector2(60, 100), 120.0), _foco(Vector2(140, 100), 120.0)]
	out = []
	LucesSombra._focos_pueblo(out, luz, pos, ALTO)
	if cierto(out.size() == 2, "dos antorchas a los lados: dos sombras"):
		cierto((out[0]["dir"] as Vector2).x * (out[1]["dir"] as Vector2).x < 0.0, "una a cada lado")
	# Lejos: floja; mas alla de su radio: nada.
	luz.lista = [_foco(Vector2(0, 100), 120.0)]
	out = []
	LucesSombra._focos_pueblo(out, luz, pos, ALTO)
	cierto(out.size() == 1 and is_equal_approx(float(out[0]["nivel"]), LucesSombra.NIVEL_FLOJA), "lejos: tonos flojos (%s)" % str(out))
	luz.lista = [_foco(Vector2(-100, 100), 120.0)]
	out = []
	LucesSombra._focos_pueblo(out, luz, pos, ALTO)
	cierto(out.is_empty(), "fuera de su alcance: ninguna")
	# De dia las antorchas no tiran sombra (menos el altar, que va 'siempre' con la noche: de dia tampoco).
	CicloDia.hora_forzada = CicloDia.T_NOCHE * 0.5
	luz.lista = [_foco(Vector2(60, 100), 120.0), _foco(Vector2(140, 100), 120.0, 1.0, true)]
	out = []
	LucesSombra._focos_pueblo(out, luz, pos, ALTO)
	cierto(out.is_empty(), "de dia las antorchas no tiran sombra")
	CicloDia.hora_forzada = -1.0
	luz.free()


func test_largo_por_distancia() -> void:
	var luz := LuzFalsa.new()
	CicloDia.hora_forzada = CicloDia.T_NOCHE + 300.0
	var pos := Vector2(100, 100)
	var cerca: Array = []
	luz.lista = [_foco(Vector2(80, 100), 200.0)]
	LucesSombra._focos_pueblo(cerca, luz, pos, ALTO)
	var lejos: Array = []
	luz.lista = [_foco(Vector2(10, 100), 200.0)]
	LucesSombra._focos_pueblo(lejos, luz, pos, ALTO)
	CicloDia.hora_forzada = -1.0
	luz.free()
	if cierto(cerca.size() == 1 and lejos.size() == 1, "las dos alumbran"):
		cierto(float(lejos[0]["largo"]) > float(cerca[0]["largo"]), "la luz lejana (mas baja vista desde ti) la estira mas (%.1f / %.1f)"
			% [cerca[0]["largo"], lejos[0]["largo"]])


func test_niveles_fijos() -> void:
	igual(LucesSombra.nivel_de(0.9), 1.0, "fuerte")
	igual(LucesSombra.nivel_de(0.3), LucesSombra.NIVEL_FLOJA, "floja")
	igual(LucesSombra.nivel_de(0.05), 0.0, "sin sombra")


# Una Niebla de mentira: solo lo que lee LucesSombra (focos_luz()).
class NieblaFalsa extends Node:
	var lista: Array = []
	func focos_luz() -> Array:
		return lista


func test_farolillos_mazmorra() -> void:
	var n := NieblaFalsa.new()
	var celda: float = float(DungeonGenerator.CELDA)
	var yo := Vector2(100, 100)
	# Mi farolillo: lo llevo encima, no me hace sombra (solo la de contacto).
	n.lista = [{"pos": yo, "radio": 5.0}]
	var out: Array = []
	LucesSombra._farolillos(out, n, yo, ALTO)
	cierto(out.is_empty(), "el farolillo que llevas no te hace sombra")
	# El de un compañero a una celda: sombra fuerte lejos de el.
	n.lista = [{"pos": yo, "radio": 5.0}, {"pos": yo + Vector2(celda, 0), "radio": 5.0}]
	out = []
	LucesSombra._farolillos(out, n, yo, ALTO)
	if cierto(out.size() == 1, "el farolillo del compañero si"):
		cierto((out[0]["dir"] as Vector2).x < -0.9, "lejos de el (%s)" % out[0]["dir"])
		igual(float(out[0]["nivel"]), 1.0, "cerca: los tres tonos")
	# Uno que no llega.
	n.lista = [{"pos": yo + Vector2(celda * 6.0, 0), "radio": 5.0}]
	out = []
	LucesSombra._farolillos(out, n, yo, ALTO)
	cierto(out.is_empty(), "un farolillo que no te llega no te hace sombra")
	n.free()
