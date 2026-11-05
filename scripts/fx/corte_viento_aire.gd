# ============================================================
#  corte_viento_aire.gd  (class_name CorteVientoAire)
#  EL CORTE DE VIENTO VOLANDO (05/11/2026): la media luna verde palida de la lamina de la Segadora
#  (tools/sprites_sdf/segadora_efectos_pixel.corte_viento), que vuela los ultimos palmos hasta quien lo encaja y llega
#  JUSTO cuando le revienta el impacto (InsectoAire.Modo.VIENTO, el mismo golpe de la cola). Lo usan el set Filo de aire
#  (el corte que alarga tu golpe) y los cortes de la Segadora mutante. Sale de cada golpe de viento de la cola, asi que
#  se ve igual en el espejo. Formas rellenas y estela de puntos: nada de rayas (memoria efectos-sin-lineas). Se pinta en
#  CapaPixel, como los demas efectos del personaje.
# ============================================================
extends Node2D
class_name CorteVientoAire

const VIENTO_OSCURO := Color(0.27, 0.47, 0.39)
const VIENTO := Color(0.51, 0.77, 0.64)
const VIENTO_CLARO := Color(0.77, 0.94, 0.84)
const VIENTO_FILO := Color(0.96, 1.0, 0.97)
const T_VUELA := 0.20      # lo que tarda en recorrer su tramo (a ritmo 1)
const T_APAGA := 0.10      # lo que tarda en desaparecer tras el impacto
const TRAMO_MAX := 46.0    # lo que se le ve volar como mucho (px)
const RADIO := 8.0

var _desde: Vector2 = Vector2.ZERO
var _hasta: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _espera: float = 0.0   # hasta que llega al impacto (segundos de verdad)
var _ritmo: float = 1.0
var _t: float = 0.0


# Lanza un corte que llega a 'caja' (el cuerpo de quien lo encaja) desde la direccion de 'desde' en 'vuelo' segundos.
static func lanzar(padre: Node, desde: Vector2, caja: Rect2, vuelo: float, ritmo: float = 1.0) -> CorteVientoAire:
	if padre == null:
		return null
	var c := CorteVientoAire.new()
	var hasta: Vector2 = caja.get_center()
	var d: Vector2 = hasta - desde
	if d.length_squared() < 1.0:
		d = Vector2.RIGHT
	c._dir = d.normalized()
	var tramo: float = minf(TRAMO_MAX, maxf(d.length() * 0.6, 20.0))
	c._hasta = hasta - c._dir * caja.size.x * 0.25
	c._desde = c._hasta - c._dir * tramo
	c._espera = maxf(vuelo, 0.0)
	c._ritmo = maxf(ritmo, 0.05)
	c.z_index = Game.Z_ENCIMA_PERSONAJES + 80
	c.z_as_relative = false
	padre.add_child(c)
	CapaPixel.meter(c)
	return c


func _process(delta: float) -> void:
	_t += delta
	if _t > _espera + T_APAGA / _ritmo + 0.05:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var vuela: float = T_VUELA / _ritmo
	var ini: float = _espera - vuela
	if _t < ini:
		return
	var k: float = clampf((_t - ini) / maxf(vuela, 0.001), 0.0, 1.0)
	var alfa: float = 1.0
	if _t > _espera:
		alfa = 1.0 - clampf((_t - _espera) / (T_APAGA / _ritmo), 0.0, 1.0)
	var p: Vector2 = _desde.lerp(_hasta, k)
	# LA ESTELA: puntos detras que se apagan (la trama de CapaPixel los deshace).
	var lado: Vector2 = _dir.orthogonal()
	for i in 6:
		var atras: float = 4.0 + float(i) * 3.5
		if atras > _desde.distance_to(p) + 4.0:
			break
		var off: float = sin(float(i) * 2.3) * RADIO * 0.6
		draw_circle(p - _dir * atras + lado * off, 1.4, Color(VIENTO, alfa * (0.85 - 0.12 * float(i))))
	_media_luna(p, RADIO * (0.85 + 0.15 * k), alfa)


# La media luna con la cara hacia donde vuela: el cuerpo (dos arcos rellenos) y el filo claro delante.
func _media_luna(p: Vector2, r: float, alfa: float) -> void:
	var a0: float = _dir.angle()
	var ext := PackedVector2Array()
	var n: int = 12
	for i in n + 1:
		var a: float = a0 - 1.25 + 2.5 * float(i) / float(n)
		ext.append(p + Vector2(cos(a), sin(a)) * r)
	var c_int: Vector2 = p - _dir * r * 0.55
	for i in range(n, -1, -1):
		var a2: float = a0 - 1.05 + 2.1 * float(i) / float(n)
		ext.append(c_int + Vector2(cos(a2), sin(a2)) * r * 0.85)
	draw_colored_polygon(ext, Color(VIENTO_CLARO, alfa))
	# El filo: la misma luna mas fina, pegada a la cara.
	var filo := PackedVector2Array()
	for i in n + 1:
		var a3: float = a0 - 1.0 + 2.0 * float(i) / float(n)
		filo.append(p + Vector2(cos(a3), sin(a3)) * r)
	var c_f: Vector2 = p - _dir * r * 0.18
	for i in range(n, -1, -1):
		var a4: float = a0 - 0.9 + 1.8 * float(i) / float(n)
		filo.append(c_f + Vector2(cos(a4), sin(a4)) * r * 0.9)
	draw_colored_polygon(filo, Color(VIENTO_FILO, alfa))
	# La sombra del cuerpo, detras: lo que le da volumen.
	draw_circle(c_int + _dir * r * 0.15, r * 0.22, Color(VIENTO, alfa * 0.8))
