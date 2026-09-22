# ============================================================
#  guardias_plan.gd  (class_name GuardiasPlan)
#  LOS GUARDIAS DEL PUEBLO Y SU CAMBIO DE TURNO, como DATOS y CUENTAS. Aqui no se crea ningun nodo:
#  se dice donde esta cada guardia en cada momento, y el nodo (guardia_pueblo.gd) solo lo pinta.
#
#  Pedido del usuario el 22/09/2026: dos guardias a cada lado de los portones del este y del oeste,
#  mirando hacia dentro, con el arma fuera; ocho en total, cada uno con su casa. Turnos de 20 minutos
#  (dos por cada dia de 40: "hacer trabajar mas a unos que a otros es explotacion laboral"). El relevo:
#    - el que ENTRA sale de su casa, va andando por las calles al CUARTEL, pasa dentro un minuto y sale
#      armado; va hasta la casilla de delante de su puesto;
#    - el que estaba se aparta, el nuevo ocupa el sitio, y el relevado se pone delante de el un momento;
#    - el relevado se va al cuartel, pasa dentro un minuto, sale sin armadura y vuelve a su casa.
#
#  TODO SALE DE LA HORA (CicloDia.segundo), no se simula. Sin estado y sin red: entres cuando entres al
#  pueblo cada guardia esta donde le toca, y en multijugador todos ven lo mismo porque la hora ya se
#  comparte (Net._set_hora_pueblo). Dos relojes pueden ir unos segundos desfasados; es decorado.
#
#  Las cuentas van por TRAMOS: cada guardia tiene, para cada cambio de turno, una lista de tramos
#  (escondido / quieto / andando por una ruta) con su hora de empiece y de fin, contada desde el cambio.
# ============================================================
extends RefCounted
class_name GuardiasPlan

const TURNO := 1200.0          # 20 minutos: los cambios caen en el segundo 0 y en el 1200 del ciclo
const EN_CUARTEL := 60.0       # lo que tardan dentro del cuartel en ponerse (o quitarse) el equipo
const VELOCIDAD := 80.0        # px/s andando; algo por debajo de los 100 del jugador: van de paseo
const PAUSA := 0.6             # entre gesto y gesto del relevo
const SALUDO := 1.5            # lo que el relevado se queda delante del nuevo antes de irse
const INF := 1.0e9

enum Tipo { OCULTO, QUIETO, ANDA }

# LOS PUESTOS: los dos lados de cada porton, en la calle mayor pegados a la muralla, dejando libre la
# fila del medio. 'mira' es hacia dentro del pueblo. 'aparte' es donde se hace a un lado el relevado:
# la fila del medio, que es calle (las de fuera son hierba, y un poco mas alla estan los braseros).
const PUESTOS := [
	{"casilla": Vector2i(2, 37), "mira": Vector2i(1, 0), "aparte": Vector2i(2, 38)},
	{"casilla": Vector2i(2, 39), "mira": Vector2i(1, 0), "aparte": Vector2i(2, 38)},
	{"casilla": Vector2i(71, 37), "mira": Vector2i(-1, 0), "aparte": Vector2i(71, 38)},
	{"casilla": Vector2i(71, 39), "mira": Vector2i(-1, 0), "aparte": Vector2i(71, 38)},
]

# LOS OCHO GUARDIAS: su casa (la huella de una casa de PuebloPlano.CASAS), su puesto y su grupo. El
# grupo 0 hace el turno que empieza en el segundo 0 del ciclo y el 1 el que empieza en el 1200. Los del
# porton oeste viven en el barrio oeste y los del este en el este; el cuartel queda al norte, asi que
# todos cruzan medio pueblo dos veces por turno.
const GUARDIAS := [
	{"casa": Rect2i(3, 24, 3, 3), "puesto": 0, "grupo": 0},
	{"casa": Rect2i(8, 24, 3, 3), "puesto": 1, "grupo": 0},
	{"casa": Rect2i(63, 24, 3, 3), "puesto": 2, "grupo": 0},
	{"casa": Rect2i(68, 24, 3, 3), "puesto": 3, "grupo": 0},
	{"casa": Rect2i(3, 33, 3, 3), "puesto": 0, "grupo": 1},
	{"casa": Rect2i(8, 33, 3, 3), "puesto": 1, "grupo": 1},
	{"casa": Rect2i(63, 33, 3, 3), "puesto": 2, "grupo": 1},
	{"casa": Rect2i(68, 33, 3, 3), "puesto": 3, "grupo": 1},
]


# ============================================================
#  DONDE ESTA CADA UNO
# ============================================================
# El estado del guardia 'g' en el segundo 't' del ciclo:
#   {visible, pos (px, el origen del nodo), mira (Vector2), moviendose, armado, solido}
static func estado(g: int, t: float) -> Dictionary:
	var t_ciclo: float = fposmod(t, CicloDia.CICLO)
	var cambio: float = 0.0 if t_ciclo < TURNO else TURNO
	var tau: float = t_ciclo - cambio
	var entra: bool = int(GUARDIAS[g]["grupo"]) == (0 if cambio == 0.0 else 1)
	var tramos: Array = linea(g, entra)
	for tr in tramos:
		if tau < float(tr["t1"]):
			return _evaluar(tr, tau)
	return _evaluar(tramos[-1], float(tramos[-1]["t0"]))


# ¿Esta de guardia (en su puesto, solido) en este momento? Lo usan las comprobaciones.
static func en_puesto(g: int, t: float) -> bool:
	return bool(estado(g, t)["solido"])


static func _evaluar(tr: Dictionary, tau: float) -> Dictionary:
	var tipo: int = tr["tipo"]
	var out := {"visible": tipo != Tipo.OCULTO, "armado": bool(tr["armado"]), "solido": bool(tr.get("solido", false)),
		"moviendose": false, "mira": tr.get("mira", Vector2.DOWN), "pos": tr.get("pos", Vector2.ZERO)}
	if tipo != Tipo.ANDA:
		return out
	var ruta: PackedVector2Array = tr["ruta"]
	var dur: float = float(tr["t1"]) - float(tr["t0"])
	var u: float = clampf((tau - float(tr["t0"])) / maxf(dur, 0.001), 0.0, 1.0)
	var r: Array = _punto_en(ruta, u * _largo(ruta))
	out["pos"] = r[0]
	out["mira"] = r[1]
	out["moviendose"] = true
	return out


# ============================================================
#  LOS TRAMOS
# ============================================================
static var _lineas: Dictionary = {}

# Los tramos del guardia 'g' en un cambio de turno: si 'entra', los de entrar de guardia; si no, los
# de ser relevado. Contados desde el cambio. Se calculan una vez (las rutas no cambian).
static func linea(g: int, entra: bool) -> Array:
	var clave: String = "%d_%s" % [g, entra]
	if not _lineas.has(clave):
		_lineas[clave] = _linea_entra(g) if entra else _linea_sale(g)
	return _lineas[clave]


static func _linea_entra(g: int) -> Array:
	var d: Dictionary = GUARDIAS[g]
	var p: Dictionary = PUESTOS[int(d["puesto"])]
	var puesto: Vector2i = p["casilla"]
	var frente: Vector2i = puesto + (p["mira"] as Vector2i)
	var mira_dentro := Vector2(p["mira"] as Vector2i)
	var r_ida: PackedVector2Array = ruta(puerta_casa(g), puerta_cuartel())
	var r_puesto: PackedVector2Array = ruta(puerta_cuartel(), frente)
	var ev: Dictionary = _relevo(g)
	var out: Array = []
	var t: float = 0.0
	t = _anda(out, t, r_ida, false)
	out.append({"t0": t, "t1": t + EN_CUARTEL, "tipo": Tipo.OCULTO, "armado": false})
	t += EN_CUARTEL
	t = _anda(out, t, r_puesto, true)
	# Delante de su puesto, mirando al compañero, hasta que este se aparta.
	out.append({"t0": t, "t1": ev["entra_ocupa"], "tipo": Tipo.QUIETO, "armado": true,
		"pos": pos_de(frente), "mira": -mira_dentro})
	_anda(out, ev["entra_ocupa"], PackedVector2Array([pos_de(frente), pos_de(puesto)]), true)
	# Y de guardia hasta el siguiente cambio, mirando hacia dentro.
	out.append({"t0": ev["entra_listo"], "t1": INF, "tipo": Tipo.QUIETO, "armado": true, "solido": true,
		"pos": pos_de(puesto), "mira": mira_dentro})
	return out


static func _linea_sale(g: int) -> Array:
	var d: Dictionary = GUARDIAS[g]
	var p: Dictionary = PUESTOS[int(d["puesto"])]
	var puesto: Vector2i = p["casilla"]
	var frente: Vector2i = puesto + (p["mira"] as Vector2i)
	var aparte: Vector2i = p["aparte"]
	var mira_dentro := Vector2(p["mira"] as Vector2i)
	var ev: Dictionary = _relevo(companero(g))
	var out: Array = []
	# De guardia hasta que llega el relevo y le toca apartarse.
	out.append({"t0": 0.0, "t1": ev["sale_aparta"], "tipo": Tipo.QUIETO, "armado": true, "solido": true,
		"pos": pos_de(puesto), "mira": mira_dentro})
	var t: float = _anda(out, ev["sale_aparta"], PackedVector2Array([pos_de(puesto), pos_de(aparte)]), true)
	out.append({"t0": t, "t1": ev["sale_delante"], "tipo": Tipo.QUIETO, "armado": true,
		"pos": pos_de(aparte), "mira": mira_dentro})
	t = _anda(out, ev["sale_delante"], PackedVector2Array([pos_de(aparte), pos_de(frente)]), true)
	# Delante del nuevo, mirandole (hacia el porton), un momento.
	out.append({"t0": t, "t1": t + SALUDO, "tipo": Tipo.QUIETO, "armado": true,
		"pos": pos_de(frente), "mira": -mira_dentro})
	t += SALUDO
	t = _anda(out, t, ruta(frente, puerta_cuartel()), true)
	out.append({"t0": t, "t1": t + EN_CUARTEL, "tipo": Tipo.OCULTO, "armado": false})
	t += EN_CUARTEL
	t = _anda(out, t, ruta(puerta_cuartel(), puerta_casa(g)), false)
	out.append({"t0": t, "t1": INF, "tipo": Tipo.OCULTO, "armado": false})
	return out


# LAS HORAS DEL RELEVO en un puesto, a partir de cuando llega el que ENTRA ('g') a la casilla de
# delante. Son las mismas para los dos, por eso salen de un solo sitio.
static func _relevo(g: int) -> Dictionary:
	var d: Dictionary = GUARDIAS[g]
	var p: Dictionary = PUESTOS[int(d["puesto"])]
	var puesto: Vector2i = p["casilla"]
	var frente: Vector2i = puesto + (p["mira"] as Vector2i)
	var aparte: Vector2i = p["aparte"]
	var llega: float = _largo(ruta(puerta_casa(g), puerta_cuartel())) / VELOCIDAD + EN_CUARTEL \
		+ _largo(ruta(puerta_cuartel(), frente)) / VELOCIDAD
	var ev := {}
	ev["llega"] = llega
	ev["sale_aparta"] = llega + PAUSA
	var fin_aparta: float = ev["sale_aparta"] + pos_de(puesto).distance_to(pos_de(aparte)) / VELOCIDAD
	ev["entra_ocupa"] = fin_aparta + PAUSA * 0.5
	ev["entra_listo"] = ev["entra_ocupa"] + pos_de(frente).distance_to(pos_de(puesto)) / VELOCIDAD
	ev["sale_delante"] = ev["entra_listo"] + PAUSA * 0.5
	return ev


# Añade el tramo de andar 'ruta' desde 't' y devuelve la hora a la que se acaba.
static func _anda(out: Array, t: float, r: PackedVector2Array, armado: bool) -> float:
	var dur: float = _largo(r) / VELOCIDAD
	out.append({"t0": t, "t1": t + dur, "tipo": Tipo.ANDA, "armado": armado, "ruta": r})
	return t + dur


# El que comparte puesto con 'g' (el del otro turno).
static func companero(g: int) -> int:
	for i in GUARDIAS.size():
		if i != g and int(GUARDIAS[i]["puesto"]) == int(GUARDIAS[g]["puesto"]):
			return i
	return g


# ============================================================
#  SITIOS Y RUTAS
# ============================================================
static func puerta_casa(g: int) -> Vector2i:
	return PuebloPlano.puerta_de({"rect": GUARDIAS[g]["casa"]})


static func puerta_cuartel() -> Vector2i:
	for casa in PuebloPlano.CASAS:
		if String(casa["clave"]) == "cuartel":
			return PuebloPlano.puerta_de(casa)
	return Vector2i.ZERO


# El origen del nodo de un personaje plantado en la casilla 'c': sus pies en el centro de la casilla
# (el origen va por encima de los pies, ver PoseJugador.HUELLA_Y).
static func pos_de(c: Vector2i) -> Vector2:
	return PuebloPlano.centro_px(c) - Vector2(0.0, PoseJugador.HUELLA_Y)


static var _astar: AStarGrid2D = null

# La rejilla para buscar caminos: lo solido del plano no se pisa y la hierba cuesta mas que la calle,
# asi que van por las calles salvo que atajar compense de verdad.
static func _rejilla() -> AStarGrid2D:
	if _astar != null:
		return _astar
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, PuebloPlano.ANCHO, PuebloPlano.ALTO)
	a.cell_size = Vector2(PuebloPlano.CELDA, PuebloPlano.CELDA)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.update()
	for y in PuebloPlano.ALTO:
		for x in PuebloPlano.ANCHO:
			var c := Vector2i(x, y)
			if PuebloPlano.solida(c):
				a.set_point_solid(c)
			elif PuebloPlano.suelo(c) != PuebloPlano.Suelo.CALLE:
				a.set_point_weight_scale(c, 5.0)
	_astar = a
	return a


static var _rutas: Dictionary = {}

# El camino andando de una casilla a otra, como puntos de paso (px, origen del nodo). Sin los puntos
# intermedios que caen en linea recta.
static func ruta(desde: Vector2i, hasta: Vector2i) -> PackedVector2Array:
	var clave := "%s>%s" % [desde, hasta]
	if _rutas.has(clave):
		return _rutas[clave]
	var ids: Array[Vector2i] = _rejilla().get_id_path(desde, hasta)
	var out := PackedVector2Array()
	for i in ids.size():
		if i > 0 and i < ids.size() - 1:
			var a: Vector2i = ids[i] - ids[i - 1]
			var b: Vector2i = ids[i + 1] - ids[i]
			if a == b:
				continue
		out.append(pos_de(ids[i]))
	if out.is_empty():
		out.append(pos_de(desde))
	_rutas[clave] = out
	return out


static func _largo(r: PackedVector2Array) -> float:
	var l: float = 0.0
	for i in range(1, r.size()):
		l += r[i - 1].distance_to(r[i])
	return l


# El punto a 'dist' px del principio de la ruta, y hacia donde se va en ese tramo: [pos, mira].
static func _punto_en(r: PackedVector2Array, dist: float) -> Array:
	if r.size() < 2:
		return [r[0] if r.size() > 0 else Vector2.ZERO, Vector2.DOWN]
	var queda: float = dist
	for i in range(1, r.size()):
		var tramo: float = r[i - 1].distance_to(r[i])
		if queda <= tramo or i == r.size() - 1:
			var dir: Vector2 = (r[i] - r[i - 1]).normalized()
			return [r[i - 1] + dir * minf(queda, tramo), dir]
		queda -= tramo
	return [r[-1], Vector2.DOWN]
