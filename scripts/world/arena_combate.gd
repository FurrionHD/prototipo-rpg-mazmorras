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

# Los cuerpos que SON de esta pelea. Lo pone quien monta la arena y lo actualiza cuando entra o sale
# alguien. Es lo que distingue "me acerco al borde desde dentro" de "vengo de fuera".
var en_pelea: Array[Node2D] = []

var _t: float = 0.0
# Cuerpos ya avisados, para no repetir la señal cada frame. Se sueltan al despegarse del borde.
var _avisados: Dictionary = {}
# Los que dijeron que NO: atraviesan libremente y no se les vuelve a preguntar. Se suelta cuando se
# alejan del todo (asi, si vuelven, se les pregunta otra vez -- lo pidio el usuario).
var _dijeron_que_no: Dictionary = {}
# Puntos de entrada ya usados, para escalonar a los que llegan por el mismo sitio.
var _entradas: Array[Vector2] = []


# Cuelga una arena del piso. 'padre' suele ser el DungeonFloor.
static func montar(padre: Node, rect_celdas_: Rect2i) -> ArenaCombate:
	if padre == null or not is_instance_valid(padre):
		return null
	var a := ArenaCombate.new()
	a.rect_celdas = rect_celdas_
	a.rect = ArenaCalculo.rect_px(rect_celdas_)
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

func contiene(p: Vector2) -> bool:
	return rect.has_point(p)


# Mete un punto dentro de la arena, pegado al borde si estaba fuera. Lo usa el movimiento del turno
# como pared BLANDA: no te frena en seco, te devuelve.
func recortar_dentro(p: Vector2, margen: float = ENTRADA_DENTRO) -> Vector2:
	return Vector2(
		clampf(p.x, rect.position.x + margen, rect.position.x + rect.size.x - margen),
		clampf(p.y, rect.position.y + margen, rect.position.y + rect.size.y - margen))


# La distancia de un punto al borde mas cercano. Negativa si esta fuera.
func distancia_al_borde(p: Vector2) -> float:
	var dx: float = minf(p.x - rect.position.x, rect.position.x + rect.size.x - p.x)
	var dy: float = minf(p.y - rect.position.y, rect.position.y + rect.size.y - p.y)
	return minf(dx, dy)


# EL PUNTO POR DONDE ENTRA alguien que ha chocado desde fuera: el mismo sitio donde choco, metido
# hacia dentro, y corrido a lo largo del muro si ya hay otro ahi. Se apunta para el siguiente.
func punto_de_entrada(desde: Vector2) -> Vector2:
	var p: Vector2 = recortar_dentro(desde)
	var intentos: int = 0
	while _ocupado(p) and intentos < 12:
		# Se corre a lo largo del muro por el que ha entrado: si toco por un lado vertical, se baja;
		# si fue por uno horizontal, se va hacia un lado.
		var por_vertical: bool = absf(desde.x - rect.position.x) < MARGEN \
			or absf(desde.x - (rect.position.x + rect.size.x)) < MARGEN
		var paso: float = SEPARACION_ENTRADA * float((intentos / 2) + 1)
		if intentos % 2 == 1:
			paso = -paso
		p = recortar_dentro(p + (Vector2(0.0, paso) if por_vertical else Vector2(paso, 0.0)))
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

	# 2) EL BORDE, a trazos y latiendo despacio: se lee como algo vivo, no como una linea pintada.
	var late: float = 0.5 + 0.5 * sin(_t * 2.2)
	var col := Color(1.0, 0.85, 0.45, 0.55 + 0.25 * late)
	_trazos(Vector2(x0, y0), Vector2(x1, y0), col)
	_trazos(Vector2(x1, y0), Vector2(x1, y1), col)
	_trazos(Vector2(x1, y1), Vector2(x0, y1), col)
	_trazos(Vector2(x0, y1), Vector2(x0, y0), col)


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
