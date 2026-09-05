# ============================================================
#  wall_crack_fx.gd
#  LAS GRIETAS de la piedra que esta a punto de reventar: salen del punto de impacto, se ramifican
#  y se van afilando hasta perderse en hilos. Van APARECIENDO durante el aviso -primero las gordas,
#  luego las finas-, asi que la pared se raja delante de ti antes de romperse.
#
#  LO QUE HACE QUE UNA GRIETA PAREZCA UNA GRIETA (y no un arañazo), sacado de las referencias:
#    1. SE RAMIFICA, y las hijas otra vez. Una linea sola, por quebrada que sea, se lee como un
#       rasguño; lo que dice "esto se ha partido" es el arbol.
#    2. SE AFILA. Cada rama nace mas fina que su madre y ademas adelgaza a lo largo. Las puntas son
#       hilos de medio pixel. Con grosor constante parece un rio dibujado.
#    3. NO VA RECTA NI VA SUAVE. Se quiebra a tirones, con angulos secos: la piedra se parte por
#       donde cede, no por donde le conviene a una curva.
#    4. ES ASIMETRICA. Las ramas no salen a intervalos iguales ni con el mismo largo.
#
#  TODO POR CODIGO Y CON SEMILLA: la grieta de una celda es SIEMPRE la misma. No es capricho: en
#  multijugador cada maquina la pinta por su cuenta (nadie manda un dibujo por red) y tiene que
#  salir identica, y ademas un redibujado a media aparicion no puede cambiarle la forma.
#
#  ES SOLO DIBUJO. Ni choca, ni tapa la luz, ni la IA sabe que existe.
#
#  Aspecto placeholder por codigo; el pase visual va al final, como el resto.
# ============================================================

extends Node2D

# El negro no es negro puro: es el color de la roca maciza que hay DETRAS de las paredes
# (DungeonFloor.color_roca). Asi una grieta no se lee como una raya pintada encima sino como el
# hueco por el que se ve el fondo, que es lo que tiene que parecer.
const COL_GRIETA := Color(0.05, 0.05, 0.07)

# --- LA FORMA DEL ARBOL ---
const TRONCOS := 5           # grietas principales por foco
const HONDURA := 3           # cuantas veces se ramifica (0 = solo troncos)
const TRAMOS := 5            # en cuantos trozos se quiebra cada rama
const GIRO := 0.5            # cuanto se tuerce en cada trozo (rad)
const GROSOR := 2.0          # el de un tronco recien nacido
const GROSOR_HIJA := 0.5     # lo que mide una hija respecto a su madre
const GROSOR_MIN := 0.45     # las puntas son hilos, pero se tienen que ver
const LARGO := 0.85          # largo del tronco, en celdas
const LARGO_HIJA := 0.55     # lo que mide una hija respecto a su madre
const RAMAS_POR_NIVEL := 2   # en cuantas se abre cada rama

# Los segmentos ya resueltos: {a, b, w, t}. 'w' es el grosor y 't' EL MOMENTO en que aparece (0..1),
# que es lo que deja que la grieta CREZCA en vez de encenderse entera. Se calculan UNA vez y _draw
# solo pinta los que ya han salido: la forma no cambia a media aparicion y redibujar no cuesta nada.
var _segs: Array = []
var _avance: float = 0.0     # 0 = nada, 1 = la grieta entera
# Por donde puede correr la grieta (celdas de rejilla) y el tamaño de celda, para saberlo.
var _zona: Dictionary = {}
var _lado: float = 32.0


# ¿Cae ese punto en piedra que se puede rajar?
func _dentro(p: Vector2) -> bool:
	if _zona.is_empty():
		return true
	return _zona.has(Vector2i(int(floor(p.x / _lado)), int(floor(p.y / _lado))))


# 'focos' son los puntos (en mundo) de donde sale cada grieta -- normalmente el centro de cada celda
# que va a reventar. 'lado' es el tamaño de celda y 'sem' la semilla del piso, para que dos pisos no
# calquen la misma grieta.
func preparar(focos: Array, permitidas: Array, lado: float, sem: int) -> void:
	_segs.clear()
	_lado = lado
	# LAS CELDAS POR LAS QUE PUEDE CORRER LA GRIETA: la piedra que se raja y la de su alrededor. Sin
	# esto las ramas seguian de largo y se metian por el suelo y por el musgo, rajando cosas que no
	# estan rotas -- y una grieta pintada sobre el suelo se lee como una mancha, no como una rotura.
	_zona.clear()
	for c in permitidas:
		_zona[c as Vector2i] = true
	for f in focos:
		_arbol(f as Vector2, lado, sem)
	# Por MOMENTO DE APARICION: asi _draw puede cortar por el primero que aun no toca en vez de
	# recorrerlo todo comparando. Con varias celdas esto son unos cuantos cientos de segmentos.
	_segs.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	queue_redraw()


func _arbol(foco: Vector2, lado: float, sem: int) -> void:
	var rng := RandomNumberGenerator.new()
	# La semilla sale del PUNTO, no de un contador: el mismo sitio da la misma grieta en cualquier
	# maquina y en cualquier momento.
	rng.seed = hash(Vector3i(int(foco.x), int(foco.y), sem))
	var giro: float = rng.randf() * TAU
	for i in TRONCOS:
		# En abanico, con un bandazo por tronco: a intervalos iguales se ve una estrella de dibujo
		# animado, no una piedra partida.
		var ang: float = giro + TAU * float(i) / float(TRONCOS) + rng.randf_range(-0.45, 0.45)
		_rama(rng, foco, ang, GROSOR, LARGO * lado, HONDURA, 0.0)


# UNA RAMA, y de paso sus hijas. 'nace' es el momento en que empieza a salir; cada hija nace mas
# tarde que su madre, y por eso la grieta crece de dentro hacia fuera en vez de aparecer entera.
func _rama(rng: RandomNumberGenerator, desde: Vector2, ang: float, grosor: float, largo: float,
		hondura: int, nace: float) -> void:
	var p: Vector2 = desde
	var paso: float = largo / float(TRAMOS)
	# Lo que tarda ESTA rama en dibujarse entera. Las de fuera son mas cortas y salen mas deprisa,
	# que es lo que hace que el ultimo tramo del aviso se llene de hilos de golpe.
	var dura: float = 0.35 * pow(0.65, float(HONDURA - hondura))
	for t in TRAMOS:
		# Se tuerce a TIRONES, no con una curva: la piedra cede por donde puede.
		ang += rng.randf_range(-GIRO, GIRO)
		var siguiente: Vector2 = p + Vector2(cos(ang), sin(ang)) * paso * rng.randf_range(0.65, 1.35)
		# SE ACABA LA PIEDRA, se acaba la grieta. Se corta en seco y no se busca por donde seguir: una
		# rama que rodea el obstaculo se lee como un tallo, no como una rotura.
		if not _dentro(siguiente):
			return
		# Se AFILA a lo largo: el ultimo trozo de una rama es la mitad de gordo que el primero.
		var f: float = 1.0 - 0.5 * float(t) / float(TRAMOS)
		var t0: float = nace + dura * float(t) / float(TRAMOS)
		_segs.append({"a": p, "b": siguiente, "w": maxf(GROSOR_MIN, grosor * f),
			"t": clampf(t0, 0.0, 1.0)})
		p = siguiente
		# Y de aqui salen las hijas. No desde la punta: una grieta se abre POR EL CAMINO, y colgando
		# todas del final salia una escoba en vez de un arbol.
		if hondura > 0 and t >= 1 and rng.randf() < 0.55:
			var lado_rama: float = 1.0 if rng.randf() < 0.5 else -1.0
			# Angulo seco (35-75 grados): las hijas suaves se leen como una curva, no como una rotura.
			var ang_hija: float = ang + lado_rama * rng.randf_range(0.6, 1.3)
			_rama(rng, p, ang_hija, grosor * GROSOR_HIJA, largo * LARGO_HIJA, hondura - 1,
				nace + dura * float(t) / float(TRAMOS))


# CUANTA GRIETA SE VE, de 0 a 1. Lo mueve el aviso segun se acerca el parto: la pared se va rajando
# delante de ti. Es lo que sustituye al brillo rojo de antes.
func avance(v: float) -> void:
	var nuevo: float = clampf(v, 0.0, 1.0)
	if is_equal_approx(nuevo, _avance):
		return
	_avance = nuevo
	queue_redraw()


func _draw() -> void:
	if _avance <= 0.0:
		return
	for s in _segs:
		var t0: float = float(s["t"])
		if t0 > _avance:
			break   # vienen ordenados: a partir de aqui no ha salido ninguno
		# El segmento se DIBUJA CRECIENDO, no aparece de golpe: se interpola su punta segun lo que
		# lleve de su propio tramo. Sin esto la grieta avanza a saltos de segmento y se ve la costura.
		var f: float = clampf((_avance - t0) / 0.06, 0.0, 1.0)
		draw_line(s["a"], (s["a"] as Vector2).lerp(s["b"], f), COL_GRIETA, float(s["w"]))
