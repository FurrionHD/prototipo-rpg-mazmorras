# ============================================================
#  arena_combate.gd
#  LA ARENA DE UNA PELEA EN EL MAPA: el rectangulo donde se pelea, dibujado en el suelo, y las tres
#  reglas de su borde. El rectangulo lo calcula ArenaCalculo; esto lo pinta y lo vigila.
#
#  EL BORDE NO ES UNA PARED. Es la decision del usuario y cambia la implementacion entera: si fuera
#  un StaticBody2D, nadie podria cruzarlo, y aqui los tres casos son justo cruzarlo:
#
#    DE DENTRO  un combatiente que se acerca al borde -> SE LE PROPONE HUIR. Esa es la nueva forma
#               de huir: no se le frena, se le pregunta. Quien confirme pasa por _accion_huir() de
#               siempre, con su tirada de Agilidad y su excelia.
#    DE FUERA, ENEMIGO  se mete en la pelea y aparece JUSTO POR DENTRO, en el punto donde choco --
#               no por una puerta comun. Varios que lleguen por el mismo lado quedan escalonados.
#               Se queda ahi quieto hasta que le toque su turno.
#    DE FUERA, JUGADOR  se le pregunta Si/No. Con Si entra como el enemigo. Con No ATRAVIESA la zona
#               como si no existiera, y no se le vuelve a preguntar hasta que salga y vuelva.
#
#  Por eso no hay colision de ninguna clase: es vigilancia por posicion y tres señales. Quien decide
#  que hacer con ellas es la pelea, no esto. Asi esta pieza se puede probar sola, sin combate.
#
#  DIBUJO: z absoluto BAJO (el patron de AreaCuracion.Z_SUELO). Esto esta en el SUELO y los cuerpos
#  tienen que verse por encima. Y se dibuja SIN ACHATAR, alineado a las celdas: los cuerpos se
#  proyectan a 45 grados (sprite_lienzo) pero el suelo es una rejilla cuadrada de 32x32, y un
#  rectangulo achatado no cuadraria con las celdas que pisa.
# ============================================================
extends Node2D
class_name ArenaCombate

# Un combatiente de DENTRO ha llegado al borde: hay que proponerle huir.
signal borde_desde_dentro(cuerpo: Node2D)
# Un enemigo de FUERA ha tocado el borde: entra a la pelea en 'punto'.
signal enemigo_entra(cuerpo: Node2D, punto: Vector2)
# Un jugador de FUERA ha tocado el borde: hay que preguntarle si entra.
signal jugador_pregunta(cuerpo: Node2D)

const Z_SUELO := 2

# A que distancia del borde cuenta como "tocarlo", en px. Generoso a proposito: con un margen
# apretado, alguien que se acerca en diagonal a buena velocidad se salta el borde entre dos frames y
# no se le pregunta nada.
const MARGEN := 12.0

# Cuanto se mete hacia dentro el que entra, desde el borde. Poco: la idea es que se quede pegado al
# muro, no que aparezca en medio de la pelea.
const ENTRADA_DENTRO := 14.0

# Dos que entran por el mismo sitio no se pisan: al segundo se le corre esto a lo largo del muro.
const SEPARACION_ENTRADA := 26.0

# El latigazo de las señales: una vez avisado de un cuerpo, no se vuelve a avisar hasta que se
# despega del borde. Sin esto, la pregunta saldria cada frame.
const SOLTAR := MARGEN * 2.5

# Lo que se oscurece fuera de la arena. Es una pista de "aqui se pelea, ahi no".
const FUERA_ALFA := 0.28
const FUERA_MARGEN := 3000.0   # cuanto se pinta de oscuro alrededor (de sobra para cualquier zoom)

const TRAZO_LARGO := 14.0
const TRAZO_HUECO := 10.0


var rect_celdas: Rect2i = Rect2i()
var rect: Rect2 = Rect2()          # el mismo, en pixeles y en coordenadas de mundo
# LA FORMA (03/10, en la mazmorra): fila a fila, 1 en las celdas que son arena (ver
# ArenaCalculo.forma_de_arena). VACIA = el rectangulo entero, como en la arena de pruebas.
var mascara: PackedByteArray = PackedByteArray()
# EL BORDE DE VERDAD: solo los tramos donde la arena toca SUELO de fuera. Contra la roca no hay borde --
# ahi ya para la pared --, asi que pegado a un muro ni se propone huir ni entra nadie. Cada tramo es
# {a, b, n, t}: sus dos puntas en px de mundo, la normal hacia DENTRO y la direccion. Juntados en tiras rectas.
var tramos: Array[Dictionary] = []
# ¿Es el rectangulo de siempre con borde abierto por los cuatro lados? Entonces se recorta como antes.
var _rect_abierto: bool = false

# Los cuerpos que SON de esta pelea. Lo pone quien monta la arena y lo actualiza cuando entra o sale
# alguien. Es lo que distingue "me acerco al borde desde dentro" de "vengo de fuera".
var en_pelea: Array[Node2D] = []

var _t: float = 0.0

# EL CIRCULO DE MOVIMIENTO del que tiene el turno: hasta donde puede andar. Radio 0 = no se pinta.
# Va aqui y no en un nodo propio porque tiene que salir en la MISMA capa y el mismo z que la arena:
# es suelo, y los cuerpos se ven por encima.
var circulo_centro: Vector2 = Vector2.ZERO
var circulo_radio: float = 0.0
# Un bicho acercandose se pinta de otro color que tu: se lee de un vistazo de quien es el turno.
var circulo_enemigo: bool = false

# Cuerpos ya avisados, para no repetir la señal cada frame. Se sueltan al despegarse del borde.
var _avisados: Dictionary = {}
# Los que dijeron que NO: atraviesan libremente y no se les vuelve a preguntar. Se suelta cuando se
# alejan del todo (asi, si vuelven, se les pregunta otra vez -- lo pidio el usuario).
var _dijeron_que_no: Dictionary = {}
# Puntos de entrada ya usados, para escalonar a los que llegan por el mismo sitio.
var _entradas: Array[Vector2] = []


# Cuelga una arena del piso. 'padre' suele ser el DungeonFloor.
static func montar(padre: Node, rect_celdas_: Rect2i,
		mascara_: PackedByteArray = PackedByteArray()) -> ArenaCombate:
	if padre == null or not is_instance_valid(padre):
		return null
	var a := ArenaCombate.new()
	a.poner_forma(rect_celdas_, mascara_, padre.get("gen") as DungeonGenerator)
	a.z_as_relative = false
	a.z_index = Z_SUELO
	# TOP LEVEL: esto dibuja en coordenadas de MUNDO (el rectangulo viene en px del piso), asi que no
	# puede heredar la transformada de quien lo cuelgue. Sin esto, el dia que el nodo del piso no
	# este en el origen, la arena saldria pintada desplazada respecto al suelo que delimita.
	a.top_level = true
	padre.add_child(a)
	return a


# ------------------------------------------------------------
#  GEOMETRIA (lo que le preguntan la pelea y el turno)
# ------------------------------------------------------------

# La forma de la arena y su borde. 'gen' es el trazado del piso (para saber que lado da a roca y cual a
# suelo); null = todo lado de fuera es borde (las pruebas sueltas, sin piso).
func poner_forma(rc: Rect2i, m: PackedByteArray, gen: DungeonGenerator) -> void:
	rect_celdas = rc
	rect = ArenaCalculo.rect_px(rc)
	mascara = m
	tramos = tramos_de(rc, m, gen)
	var largo: float = 0.0
	for tr in tramos:
		largo += (tr["a"] as Vector2).distance_to(tr["b"])
	_rect_abierto = m.is_empty() and is_equal_approx(largo, (rect.size.x + rect.size.y) * 2.0)


# LOS TRAMOS DEL BORDE: cada lado de celda de arena que da a una celda que NO es arena pero SI suelo.
# Los lados se juntan en tiras rectas: asi los trazos del dibujo corren seguidos y no vuelven a empezar
# cada 32 px.
static func tramos_de(rc: Rect2i, m: PackedByteArray, gen: DungeonGenerator) -> Array[Dictionary]:
	var cel: float = float(DungeonGenerator.CELDA)
	# Lados sueltos, agrupados por la linea en la que caen: clave [eje, linea, normal] -> posiciones.
	var grupos: Dictionary = {}
	for y in range(rc.position.y, rc.end.y):
		for x in range(rc.position.x, rc.end.x):
			var c := Vector2i(x, y)
			if not ArenaCalculo.en_forma(rc, m, c):
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var v: Vector2i = c + d
				if ArenaCalculo.en_forma(rc, m, v):
					continue
				if gen != null and not gen.es_suelo(v):
					continue
				# Lado vertical (izq/dcha): linea = x del lado, posicion = y. Horizontal al reves.
				var clave: Array
				if d.x != 0:
					clave = [0, x + (1 if d == Vector2i.RIGHT else 0), -d.x]
				else:
					clave = [1, y + (1 if d == Vector2i.DOWN else 0), -d.y]
				if not grupos.has(clave):
					grupos[clave] = []
				(grupos[clave] as Array).append(y if d.x != 0 else x)
	var out: Array[Dictionary] = []
	for clave in grupos:
		var pos: Array = grupos[clave]
		pos.sort()
		var ini: int = int(pos[0])
		var fin: int = ini
		for i in range(1, pos.size() + 1):
			if i < pos.size() and int(pos[i]) == fin + 1:
				fin = int(pos[i])
				continue
			var linea: float = float(clave[1]) * cel
			if int(clave[0]) == 0:
				out.append({"a": Vector2(linea, float(ini) * cel), "b": Vector2(linea, float(fin + 1) * cel),
					"n": Vector2(float(clave[2]), 0.0), "t": Vector2.DOWN})
			else:
				out.append({"a": Vector2(float(ini) * cel, linea), "b": Vector2(float(fin + 1) * cel, linea),
					"n": Vector2(0.0, float(clave[2])), "t": Vector2.RIGHT})
			if i < pos.size():
				ini = int(pos[i])
				fin = ini
	return out


func contiene(p: Vector2) -> bool:
	if not rect.has_point(p):
		return false
	return mascara.is_empty() or ArenaCalculo.en_forma(rect_celdas, mascara, ArenaCalculo.celda_de_px(p))


# ¿Se puede estar en 'p' sin salirse? Dentro, y a 'margen' o mas de un tramo de borde (los muros no
# cuentan: ahi para la roca).
func dentro_px(p: Vector2, margen: float = 0.0) -> bool:
	return contiene(p) and distancia_al_borde(p) >= margen


# El punto mas cercano del borde a 'p': {q, n, t} del tramo. Vacio si no hay tramos.
func _tramo_cercano(p: Vector2) -> Dictionary:
	var mejor: Dictionary = {}
	var mejor_d: float = INF
	for tr in tramos:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, tr["a"], tr["b"])
		var d: float = p.distance_squared_to(q)
		if d < mejor_d:
			mejor_d = d
			mejor = {"q": q, "n": tr["n"], "t": tr["t"]}
	return mejor


# Mete un punto dentro de la arena, pegado al borde si estaba fuera. Lo usa el movimiento del turno
# como pared BLANDA: no te frena en seco, te devuelve.
func recortar_dentro(p: Vector2, margen: float = ENTRADA_DENTRO) -> Vector2:
	if _rect_abierto:
		# El rectangulo de siempre con borde por los cuatro lados (la arena de pruebas): igual que antes.
		return Vector2(
			clampf(p.x, rect.position.x + margen, rect.position.x + rect.size.x - margen),
			clampf(p.y, rect.position.y + margen, rect.position.y + rect.size.y - margen))
	if dentro_px(p, margen):
		return p
	var t: Dictionary = _tramo_cercano(p)
	if not t.is_empty():
		var q: Vector2 = (t["q"] as Vector2) + (t["n"] as Vector2) * maxf(margen, 1.0)
		if contiene(q):
			return q
	# Sin tramo a mano (o en una esquina rara): el centro de la celda de arena mas cercana.
	return _centro_mas_cercano(p)


func _centro_mas_cercano(p: Vector2) -> Vector2:
	var cel: float = float(DungeonGenerator.CELDA)
	var mejor: Vector2 = rect.get_center()
	var mejor_d: float = INF
	for y in range(rect_celdas.position.y, rect_celdas.end.y):
		for x in range(rect_celdas.position.x, rect_celdas.end.x):
			if not ArenaCalculo.en_forma(rect_celdas, mascara, Vector2i(x, y)):
				continue
			var c := (Vector2(x, y) + Vector2(0.5, 0.5)) * cel
			var d: float = p.distance_squared_to(c)
			if d < mejor_d:
				mejor_d = d
				mejor = c
	return mejor


# La distancia de un punto al BORDE (los tramos abiertos) mas cercano. Negativa si esta fuera. Sin
# ningun tramo (una sala cerrada entera), INF dentro y -INF fuera: nunca se esta "en el borde".
func distancia_al_borde(p: Vector2) -> float:
	var t: Dictionary = _tramo_cercano(p)
	var d: float = INF if t.is_empty() else p.distance_to(t["q"])
	return d if contiene(p) else -d


# EL PUNTO POR DONDE ENTRA alguien que ha chocado desde fuera: el mismo sitio donde choco, metido
# hacia dentro, y corrido a lo largo del muro si ya hay otro ahi. Se apunta para el siguiente.
func punto_de_entrada(desde: Vector2) -> Vector2:
	var p: Vector2 = recortar_dentro(desde)
	var intentos: int = 0
	while _ocupado(p) and intentos < 12:
		# Se corre a lo largo del muro por el que ha entrado: si toco por un lado vertical, se baja;
		# si fue por uno horizontal, se va hacia un lado.
		# Se corre a lo largo del tramo de borde por el que ha entrado.
		var tr: Dictionary = _tramo_cercano(desde)
		var a_lo_largo: Vector2 = tr["t"] if not tr.is_empty() else Vector2.RIGHT
		var paso: float = SEPARACION_ENTRADA * float((intentos / 2) + 1)
		if intentos % 2 == 1:
			paso = -paso
		p = recortar_dentro(p + a_lo_largo * paso)
		intentos += 1
	_entradas.append(p)
	return p


func _ocupado(p: Vector2) -> bool:
	for q in _entradas:
		if p.distance_to(q) < SEPARACION_ENTRADA:
			return true
	return false


# Al acabar la pelea se sueltan los sitios de entrada: la arena siguiente empieza limpia.
func olvidar_entradas() -> void:
	_entradas.clear()


# ¿Este cuerpo esta atravesando la arena tras decir que NO? Lo pregunta el dibujo de los demas para
# no pintarlo: el que cruza no se le ve a los que estan peleando, para no molestarles.
func esta_de_paso(cuerpo: Node2D) -> bool:
	return _dijeron_que_no.has(cuerpo)


func dijo_que_no(cuerpo: Node2D) -> void:
	if cuerpo != null:
		_dijeron_que_no[cuerpo] = true


# ------------------------------------------------------------
#  LA VIGILANCIA DEL BORDE
# ------------------------------------------------------------

# Quien mira: los de la pelea (para proponerles huir) y los cuerpos sueltos del piso que se acerquen
# desde fuera. Se le pasan desde fuera para no atarse a ningun grupo concreto y poder probarlo solo.
func vigilar(cuerpos_fuera: Array) -> void:
	for c in en_pelea:
		if not is_instance_valid(c):
			continue
		_mirar_desde_dentro(c)
	for c in cuerpos_fuera:
		if not is_instance_valid(c) or en_pelea.has(c):
			continue
		_mirar_desde_fuera(c as Node2D)
	_limpiar()


func _mirar_desde_dentro(c: Node2D) -> void:
	var d: float = distancia_al_borde(c.global_position)
	if d > SOLTAR:
		_avisados.erase(c)
		return
	if d <= MARGEN and not _avisados.has(c):
		_avisados[c] = true
		borde_desde_dentro.emit(c)


func _mirar_desde_fuera(c: Node2D) -> void:
	var p: Vector2 = c.global_position
	var dentro: bool = contiene(p)
	var d: float = distancia_al_borde(p)

	# El que dijo que no atraviesa tranquilo. Se le suelta el pestillo cuando se ha ido del todo, y
	# entonces volveria a preguntarsele si choca otra vez.
	if _dijeron_que_no.has(c):
		if not dentro and d < -SOLTAR:
			_dijeron_que_no.erase(c)
			_avisados.erase(c)
		return

	if not dentro and d < -SOLTAR:
		_avisados.erase(c)
		return
	# 'd' es negativa fuera: tocar el borde es estar a menos de MARGEN por fuera (o ya haberlo
	# cruzado, que pasa si venia rapido).
	if d < -MARGEN:
		return
	if _avisados.has(c):
		return
	_avisados[c] = true
	if _es_jugador(c):
		jugador_pregunta.emit(c)
	else:
		enemigo_entra.emit(c, punto_de_entrada(p))


func _es_jugador(c: Node2D) -> bool:
	return c.is_in_group("aliado") or c.is_in_group("player") or c.is_in_group("jugador_remoto")


# Se sueltan las fichas de cuerpos que ya no existen: una pelea larga con bichos muriendose deja el
# diccionario lleno de punteros colgados.
func _limpiar() -> void:
	for d in [_avisados, _dijeron_que_no]:
		for c in d.keys():
			if not is_instance_valid(c):
				d.erase(c)


# ------------------------------------------------------------
#  DIBUJO
# ------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# 1) LO DE FUERA, oscurecido. Cuatro rectangulos alrededor: se ve de un vistazo donde se pelea.
	var m: float = FUERA_MARGEN
	var col_fuera := Color(0.0, 0.0, 0.02, FUERA_ALFA)
	var x0: float = rect.position.x
	var y0: float = rect.position.y
	var x1: float = x0 + rect.size.x
	var y1: float = y0 + rect.size.y
	draw_rect(Rect2(x0 - m, y0 - m, rect.size.x + m * 2.0, m), col_fuera)          # arriba
	draw_rect(Rect2(x0 - m, y1, rect.size.x + m * 2.0, m), col_fuera)              # abajo
	draw_rect(Rect2(x0 - m, y0, m, rect.size.y), col_fuera)                        # izquierda
	draw_rect(Rect2(x1, y0, m, rect.size.y), col_fuera)                            # derecha
	# Con FORMA, tambien las celdas del rectangulo que no son arena.
	if not mascara.is_empty():
		var cel: float = float(DungeonGenerator.CELDA)
		for y in range(rect_celdas.position.y, rect_celdas.end.y):
			for x in range(rect_celdas.position.x, rect_celdas.end.x):
				if not ArenaCalculo.en_forma(rect_celdas, mascara, Vector2i(x, y)):
					draw_rect(Rect2(Vector2(x, y) * cel, Vector2(cel, cel)), col_fuera)

	# 2) EL BORDE, a trazos y latiendo despacio: se lee como algo vivo, no como una linea pintada. Solo
	# donde se puede salir: contra la roca ya esta la pared.
	var late: float = 0.5 + 0.5 * sin(_t * 2.2)
	var col := Color(1.0, 0.85, 0.45, 0.55 + 0.25 * late)
	for tr in tramos:
		_trazos(tr["a"], tr["b"], col)

	# 3) EL CIRCULO DE MOVIMIENTO, sin achatar (es suelo, como el rectangulo).
	if circulo_radio > 0.0:
		var base: Color = Color(1.0, 0.45, 0.35) if circulo_enemigo else Color(0.45, 0.85, 1.0)
		draw_circle(circulo_centro, circulo_radio, Color(base, 0.10))
		draw_arc(circulo_centro, circulo_radio, 0.0, TAU, 72, Color(base, 0.55 + 0.2 * late), 2.0)
		draw_circle(circulo_centro, 3.0, Color(base, 0.8))   # de donde salio: su sitio al empezar

	# 4) LAS HUELLAS: lo que tapa una habilidad mientras se apunta (y, las cargadas, mientras cargan).
	# Tambien sin achatar. El NUCLEO (la zona de impacto, con el daño entero) va mas marcado.
	for clave in huellas:
		var h: Dictionary = huellas[clave]
		var f = h["forma"]
		var c: Color = h["color"]
		CombatFormas.dibujar(f, self, Color(c, 0.6 + 0.3 * late))
		var n: float = float(h["nucleo"])
		if n > 0.0:
			draw_circle(f.centro, n, Color(c, 0.30))
			draw_arc(f.centro, n, 0.0, TAU, 48, Color(c, 0.9), 2.0)


# LAS HUELLAS PINTADAS, por clave (quien la lanza): {forma, nucleo, color}.
var huellas: Dictionary = {}

func poner_huella(clave: Variant, forma: RefCounted, nucleo: float = 0.0,
		color: Color = Color(0.45, 0.85, 1.0)) -> void:
	huellas[clave] = {"forma": forma, "nucleo": nucleo, "color": color}


func quitar_huella(clave: Variant) -> void:
	huellas.erase(clave)


func poner_circulo(centro: Vector2, radio: float, de_enemigo: bool = false) -> void:
	circulo_centro = centro
	circulo_radio = radio
	circulo_enemigo = de_enemigo


func quitar_circulo() -> void:
	circulo_radio = 0.0


func _trazos(a: Vector2, b: Vector2, col: Color) -> void:
	var largo: float = a.distance_to(b)
	if largo <= 0.0:
		return
	var dir: Vector2 = (b - a) / largo
	# Los trazos se desplazan con el tiempo: el borde "corre" despacio y se distingue del terreno.
	var paso: float = TRAZO_LARGO + TRAZO_HUECO
	var d: float = fmod(_t * 18.0, paso) - paso
	while d < largo:
		var ini: float = maxf(d, 0.0)
		var fin: float = minf(d + TRAZO_LARGO, largo)
		if fin > ini:
			draw_line(a + dir * ini, a + dir * fin, col, 3.0)
		d += paso
