# ============================================================
#  LAS LUCES QUE HACEN SOMBRA (16/11/2026, memoria sombras-fuera-del-sprite)
#  Que luces le llegan a un punto del suelo y hacia donde le tiran la sombra. Lo pregunta cada SombraSuelo (unas
#  10 veces por segundo, no a cada fotograma).
#
#  Cada luz que devuelve es {dir, largo, nivel}:
#    dir   = hacia donde cae la sombra (unitario, en el plano de la PANTALLA: lejos de la luz),
#    largo = cuanto se estira, en px de mundo (lo alto que es el cuerpo por lo baja que llega la luz),
#    nivel = 1 (los tres tonos de siempre) o NIVEL_FLOJA (una luz floja: los tonos un escalon mas claros). Tonos FIJOS:
#            no hay medias tintas, la luz o pega fuerte, o pega floja, o no hace sombra.
#  Las ordena de la mas fuerte a la mas floja (si hay mas de las que admite el shader, se quedan las fuertes).
#
#  PASO 2 (este): EL PUEBLO. El SOL de dia, que se mueve con la hora (sale por el este y se pone por el oeste: la sombra
#  larga por la mañana y la tarde, corta al mediodia) y los FOCOS de LuzPueblo de noche (antorchas, braseros, ventanas,
#  el altar), cada uno hasta donde alumbra. Su eleccion 16/11: TODAS las que le den, sin tope.
#  PASO 3: LA MAZMORRA. Los FAROLILLOS (el tuyo, el de tus compañeros y el de los otros jugadores: Niebla.focos_luz) y
#  las FLORES del musgo y los BROTES de la sala del jefe (Vision.flores_en: solo las que te alumbran de verdad, con las
#  paredes en medio). El que lleva el farolillo no se hace sombra con el suyo (lo lleva encima): solo la de contacto.
# ============================================================
class_name LucesSombra
extends RefCounted

const NIVEL_FLOJA := 0.6
# Por encima de esto pega fuerte; entre FLOJA_DESDE y esto, floja; por debajo no hace sombra.
const FUERTE_DESDE := 0.45
const FLOJA_DESDE := 0.15
# A que altura estan las luces del pueblo (px de mundo): una antorcha cerca te tira la sombra larga, una lejos corta.
const ALTURA_FOCO := 48.0
# Los topes del largo, en altos del cuerpo.
const LARGO_MIN := 0.3
const LARGO_MAX := 2.0
const LARGO_MAX_SOL := 2.5
# El sol, visto a 45 grados: lo que se mueve de arriba abajo en la pantalla se ve aplastado.
const APLASTADO_SUELO := 0.7


static func nivel_de(fuerza: float) -> float:
	if fuerza >= FUERTE_DESDE:
		return 1.0
	if fuerza >= FLOJA_DESDE:
		return NIVEL_FLOJA
	return 0.0


# Las luces que le llegan al punto 'pos' (px de mundo) desde el arbol de 'quien'. 'alto' = lo alto que es el cuerpo
# (px de mundo), para el largo.
static func en(quien: Node, pos: Vector2, alto: float) -> Array:
	var out: Array = []
	var luz: Node = quien.get_tree().get_first_node_in_group(&"luz_pueblo") if quien.is_inside_tree() else null
	if luz != null and luz.get_viewport() == quien.get_viewport():
		_sol(out, alto)
		_focos_pueblo(out, luz, pos, alto)
	var niebla: Node = quien.get_tree().get_first_node_in_group(&"niebla") if quien.is_inside_tree() else null
	if niebla != null and niebla.get_viewport() == quien.get_viewport():
		_farolillos(out, niebla, pos, alto)
		_flores(out, niebla, pos, alto)
	out.sort_custom(func(a, b): return float(a["fuerza"]) > float(b["fuerza"]))
	return out


# EL SOL: de 0 (sale) a T_NOCHE (se pone). Por el este (derecha) por la mañana, al sur a mediodia y por el oeste
# (izquierda) por la tarde: la sombra cae al lado contrario, y al norte (arriba) a mediodia.
static func _sol(out: Array, alto: float) -> void:
	var s: float = CicloDia.segundo()
	if s >= CicloDia.T_NOCHE:
		return
	var fuerza: float = 1.0 - CicloDia.noche(s)
	var nivel: float = nivel_de(fuerza)
	if nivel <= 0.0:
		return
	var u: float = s / CicloDia.T_NOCHE
	var dir := Vector2(-cos(PI * u), -sin(PI * u) * APLASTADO_SUELO).normalized()
	# Lo alto que esta: nada al salir y al ponerse, lo mas alto a mediodia.
	var alto_sol: float = maxf(sin(PI * u), 0.05)
	var largo: float = alto * clampf(0.5 / alto_sol, LARGO_MIN, LARGO_MAX_SOL)
	out.append({"dir": dir, "largo": largo, "nivel": nivel, "fuerza": fuerza})


# LOS FAROLILLOS de la mazmorra (Niebla.focos_luz): radio en celdas; mas floja cuanto mas lejos.
static func _farolillos(out: Array, niebla: Node, pos: Vector2, alto: float) -> void:
	for f in niebla.focos_luz():
		var radio: float = float(f["radio"]) * float(DungeonGenerator.CELDA)
		var d: Vector2 = pos - (f["pos"] as Vector2)
		var dist: float = d.length()
		if dist >= radio or dist < 6.0:
			continue
		var fuerza: float = 1.0 - dist / radio
		var nivel: float = nivel_de(fuerza)
		if nivel <= 0.0:
			continue
		out.append({"dir": d / dist, "largo": alto * clampf(dist / ALTURA_FOCO, LARGO_MIN, LARGO_MAX), "nivel": nivel, "fuerza": fuerza})


# LAS FLORES Y LOS BROTES (Vision.flores_en): luz fija, pegada al suelo, y solo si te llega de verdad.
const ALCANCE_FLOR := 160.0

static func _flores(out: Array, niebla: Node, pos: Vector2, alto: float) -> void:
	for f in niebla.vision.flores_en(pos, ALCANCE_FLOR):
		var d: Vector2 = pos - (f["pos"] as Vector2)
		var dist: float = d.length()
		if dist < 2.0:
			continue
		var fuerza: float = float(f["fuerza"])
		var nivel: float = nivel_de(fuerza)
		if nivel <= 0.0:
			continue
		out.append({"dir": d / dist, "largo": alto * clampf(dist / ALTURA_FOCO, LARGO_MIN, LARGO_MAX), "nivel": nivel, "fuerza": fuerza})


# LOS FOCOS DEL PUEBLO (LuzPueblo): los que le alumbran, cada uno con su fuerza a esa hora y menos cuanto mas lejos.
static func _focos_pueblo(out: Array, luz: Node, pos: Vector2, alto: float) -> void:
	for f in luz.focos():
		var radio: float = float(f["radio"])
		var d: Vector2 = pos - (f["pos"] as Vector2)
		var dist: float = d.length()
		if dist >= radio or dist < 2.0:
			continue
		var fuerza_hora: float = CicloDia.noche() if bool(f["siempre"]) else CicloDia.luces(float(f["retraso"]))
		var fuerza: float = fuerza_hora * float(f["fuerza"]) * (1.0 - dist / radio)
		var nivel: float = nivel_de(fuerza)
		if nivel <= 0.0:
			continue
		var largo: float = alto * clampf(dist / ALTURA_FOCO, LARGO_MIN, LARGO_MAX)
		out.append({"dir": d / dist, "largo": largo, "nivel": nivel, "fuerza": fuerza})
