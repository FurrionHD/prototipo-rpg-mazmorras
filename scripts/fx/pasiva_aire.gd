# ============================================================
#  pasiva_aire.gd
#  LOS EFECTOS DE LAS PASIVAS DEL REPASO y del "INTERRUMPIDO" (30/09/2026, paso E del plan de la amenaza; ver la
#  memoria pasivas-de-enemigos). Propuestos y aprobados con el usuario:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa):
#    LLAMADA     el Rey de la camada: cuando EL pega, medias lunas rojas de su boca hacia los lados (llama a la
#                camada, que salta detras). Las ratas muerden con su mordisco de siempre, mas pequeño.
#    ARDE        el Cuerpo ardiente del slime de fuego: una lengua de fuego sale de DONDE le han pegado hacia quien
#                le pego y le revienta encima. Sale siempre que salte la pasiva; la quemadura, solo si prende (la
#                tirada de resistencia a efectos de siempre) y con su dibujo de estado.
#    LATIDO      la Emboscada de la araña: la telaraña bajo su presa late en blanco y se encoge (como si tirara de
#                ella) justo cuando llega el mordisco, que sale mas grande.
#    DESTELLO    el Filo de reflejo de la segadora: una estrella en la guadaña del lado del golpe al pararlo; el
#                contragolpe es su tajo de siempre (InsectoAire.TAJO) con su gesto.
#    ECO         la Ecolocalizacion del chillon: medias lunas palidas que salen de su cabeza hacia el que va en
#                sigilo y lo envuelven al llegar (CombatTactico lo pone entero un momento: "te ha pillado").
#    ARRASTRE    el EMPUJON PEQUEÑO (menos de Pantalla.DESPLAZA_CORTA: no corta, retrasa la barra): polvo en los pies y
#                una marca corta de arrastre en el suelo, en la direccion en la que le han movido (se lee que le han
#                desplazado, no que ha andado). Con el texto "RETRASADO" y la estela de su ficha en la barra de turnos.
#    ESQUIRLAS   a quien le cortan la carga: lo que cargaba se rompe en esquirlas que saltan del pecho, caen y se
#                apagan (el hechizo, ademas, rompe su circulo: CombatTactico.circulo_acaba).
#  NADA DE LINEAS (efectos-sin-lineas): medias lunas llenas, bolas, bocanadas y esquirlas rellenas. Y NADA CON ANGULO
#  FIJO (efectos-orientados-no-fijos): todo sale de quien lo hace hacia quien lo recibe, con variacion por golpe.
#  Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name PasivaAire

enum Modo { LLAMADA, ARDE, LATIDO, DESTELLO, ECO, ESQUIRLAS, ARRASTRE }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80

const T_LLAMADA := 0.55
const T_ENTRE_LLAMADA := 0.08
const LLAMADA_FILO := Color(1.0, 0.62, 0.55)
const LLAMADA_DENTRO := Color(0.62, 0.08, 0.08)
const T_ARDE_VA := 0.16           # lo que tarda la lengua de fuego en llegar
const T_ARDE := 0.75
const FUEGO_OSCURO := Color(0.42, 0.07, 0.03)
const FUEGO_ROJO := Color(0.85, 0.16, 0.04)
const FUEGO_NARANJA := Color(1.0, 0.5, 0.1)
const FUEGO_AMARILLO := Color(1.0, 0.82, 0.3)
const FUEGO_BLANCO := Color(1.0, 0.97, 0.78)
const HUMO := Color(0.13, 0.11, 0.11)
const T_LATIDO := 0.5
const TELA := Color(0.93, 0.93, 0.97)
const T_DESTELLO := 0.32
const ACERO_HUESO := Color(1.0, 0.97, 0.88)
const T_ECO := 0.3                # lo que tarda (como poco) cada media luna en llegar
const T_ENTRE_ECO := 0.09
const T_ECO_ENVUELVE := 0.35
const ECO_C := Color(0.86, 0.8, 1.0)
const T_ESQUIRLAS := 0.7
const CARGA_C := Color(1.0, 0.84, 0.42)
const CONJURO_C := Color(0.78, 0.62, 1.0)
const T_ARRASTRE := 0.22          # lo que dura el deslizamiento (CombatTactico mueve el cuerpo a la vez)
const T_ARRASTRE_QUEDA := 0.7     # y lo que tarda en irse la marca
const POLVO := Color(0.55, 0.5, 0.44)
const SURCO := Color(0.08, 0.07, 0.06)

var modo: int = Modo.LLAMADA
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _o: Vector2 = Vector2.ZERO        # de donde sale (la boca, el sitio del golpe)
var _hasta: Vector2 = Vector2.ZERO    # el pecho de quien lo recibe
var _pies: Vector2 = Vector2.ZERO
var _eje: Vector2 = Vector2.RIGHT
var _ancho: float = 14.0
var _largo: float = 26.0
var _viaje: float = 0.2
var _giro: float = 0.0
var _color: Color = CARGA_C
var _piezas: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = la caja de quien lo hace (el rey, el slime, el chillon; en el LATIDO y las ESQUIRLAS da igual), 'caja' =
# la de quien lo recibe (en el DESTELLO, la de la segadora, y 'desde' la de quien le pega), 'pies_v' = sus pies,
# 'espera' = lo que falta para el golpe (lo que viaja), 'extra' = en las ESQUIRLAS, 1 carga y 0 conjuro.
static func sobre_cuerpo(padre: Node, m: int, desde: Rect2, caja: Rect2, pies_v: Vector2, semilla: int,
		espera: float, ritmo: float, extra: float = 1.0) -> PasivaAire:
	if padre == null:
		return null
	var e := PasivaAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._ancho = maxf(caja.size.x, 8.0)
	e._largo = maxf(caja.size.y, 10.0)
	e._pies = pies_v
	e._hasta = caja.get_center() - Vector2(0.0, caja.size.y * 0.08)
	var c_desde: Vector2 = desde.get_center() if desde.has_area() else e._hasta - Vector2(40.0, 0.0)
	var eje: Vector2 = (e._hasta - c_desde).normalized() if e._hasta.distance_squared_to(c_desde) > 1.0 else Vector2.RIGHT
	e._eje = eje
	e._giro = e._rng.randf_range(-0.5, 0.5)
	match m:
		Modo.LLAMADA:
			# De su BOCA: el borde de su cuerpo por el lado de su victima (el hocico), un poco alto.
			e._o = _borde(desde, eje) - eje * 2.0 + Vector2(0.0, -desde.size.y * 0.08)
			e._eje = eje.rotated(e._rng.randf_range(-0.15, 0.15))
			e._t = -maxf(espera, 0.0)
		Modo.ARDE:
			# DONDE LE HAN PEGADO: su borde del lado de quien le pega, a media altura.
			e._o = _borde(desde, eje) - eje * 3.0 + Vector2(0.0, e._rng.randf_range(-0.12, 0.05) * desde.size.y)
			e._viaje = T_ARDE_VA
			e._t = -maxf(espera, 0.0)
			var lat: Vector2 = eje.orthogonal()
			# La lengua: bocanadas que salen una tras otra y serpean (cada golpe distinto).
			var ondas: float = e._rng.randf_range(-1.0, 1.0)
			for i in 9:
				e._piezas.append({"t0": 0.022 * float(i), "tam": lerpf(1.25, 0.75, float(i) / 8.0) * e._rng.randf_range(0.85, 1.15),
					"lado": lat * sin(float(i) * 0.9 + ondas * 3.0) * e._rng.randf_range(2.0, 5.0), "fase": float(i) * 1.7})
			# Y el reventon encima de quien le pego.
			for i in 5:
				var a: float = TAU * float(i) / 5.0 + e._rng.randf_range(-0.4, 0.4)
				e._piezas.append({"reventon": true, "d": Vector2(cos(a), sin(a) * 0.8), "tam": e._rng.randf_range(0.8, 1.2),
					"fase": 11.0 + float(i) * 2.3})
		Modo.LATIDO:
			e._t = -maxf(espera, 0.0) + 0.06   # empieza un pelin antes del mordisco: cuando llega, tira
			for i in 7:
				var a2: float = TAU * float(i) / 7.0 + e._rng.randf_range(-0.3, 0.3)
				e._piezas.append({"a": a2, "r": e._rng.randf_range(0.85, 1.25)})
		Modo.DESTELLO:
			# EN LA GUADAÑA DEL LADO DEL GOLPE: arriba en su cuerpo, hacia quien le pega (el eje va de quien pega a ella).
			e._o = _borde(caja, -eje) + eje * 4.0 + Vector2(0.0, -e._largo * e._rng.randf_range(0.15, 0.25))
			e._t = -maxf(espera, 0.0)
		Modo.ECO:
			# De su cabeza hacia el que va en sigilo; llegan cuando llega el golpe.
			e._o = _borde(desde, eje) - eje * 3.0 + Vector2(0.0, -desde.size.y * 0.1)
			e._viaje = maxf(espera, T_ECO)
			e._t = -e._viaje
		Modo.ESQUIRLAS:
			e._color = CARGA_C if extra >= 0.5 else CONJURO_C
			e._o = e._hasta
			e._t = -maxf(espera, 0.0)
			for i in 11:
				var a3: float = TAU * float(i) / 11.0 + e._rng.randf_range(-0.25, 0.25)
				var d := Vector2(cos(a3), sin(a3) * 0.75 - 0.35).normalized()
				e._piezas.append({"d": d, "v": e._rng.randf_range(26.0, 48.0), "tam": e._rng.randf_range(2.0, 3.6),
					"gira": e._rng.randf_range(-12.0, 12.0), "a0": e._rng.randf_range(0.0, TAU)})
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	padre.add_child(e)
	return e


# EL EMPUJON PEQUEÑO: de 'pies0' a 'pies1' (donde estaba y donde acaba), con el ancho de lo que pisa.
static func arrastre(padre: Node, pies0: Vector2, pies1: Vector2, ancho: float, semilla: int, ritmo: float) -> PasivaAire:
	if padre == null:
		return null
	var e := PasivaAire.new()
	e.modo = Modo.ARRASTRE
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._o = pies0
	e._pies = pies1
	e._ancho = maxf(ancho, 8.0)
	e._eje = (pies1 - pies0).normalized() if pies1.distance_squared_to(pies0) > 0.25 else Vector2.RIGHT
	for i in 7:
		e._piezas.append({"u": e._rng.randf_range(0.1, 1.0), "lado": e._rng.randf_range(-1.0, 1.0),
			"tam": e._rng.randf_range(0.8, 1.3), "sube": e._rng.randf_range(4.0, 9.0)})
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	padre.add_child(e)
	return e


func duracion() -> float:
	match modo:
		Modo.LLAMADA: return T_LLAMADA + T_ENTRE_LLAMADA * 2.0
		Modo.ARDE: return T_ARDE
		Modo.LATIDO: return T_LATIDO
		Modo.DESTELLO: return T_DESTELLO
		Modo.ECO: return T_ECO_ENVUELVE
		Modo.ESQUIRLAS: return T_ESQUIRLAS
		Modo.ARRASTRE: return T_ARRASTRE + T_ARRASTRE_QUEDA
	return 0.5


func _capa(z: int, aditiva: bool) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = z
	if aditiva:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = mat
	add_child(n)
	n.draw.connect(_dibujar_capa.bind(n))
	return n


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()
		return
	for n in [_suelo, _delante, _brillo]:
		if n != null:
			(n as Node2D).queue_redraw()


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.LLAMADA: _llamada(capa)
		Modo.ARDE: _arde(capa)
		Modo.LATIDO: _latido(capa)
		Modo.DESTELLO: _destello(capa)
		Modo.ECO: _eco(capa)
		Modo.ESQUIRLAS: _esquirlas(capa)
		Modo.ARRASTRE: _arrastre(capa)


# El punto del borde de 'r' en la direccion 'd' desde su centro (el hocico, el lado del golpe).
static func _borde(r: Rect2, d: Vector2) -> Vector2:
	var c: Vector2 = r.get_center()
	if not r.has_area() or d.length_squared() < 0.0001:
		return c
	var hx: float = r.size.x * 0.5 / maxf(absf(d.x), 0.0001)
	var hy: float = r.size.y * 0.5 / maxf(absf(d.y), 0.0001)
	return c + d * minf(hx, hy)


static func _alto(h: float) -> Vector2:
	return Vector2(0.0, -h * K)


static func _ruido(x: float, k: float) -> float:
	return fmod(absf(sin(x * 12.9898 + k * 78.233) * 43758.5453), 1.0)


# ------------------------------------------------------------
#  LA LLAMADA DEL REY
# ------------------------------------------------------------
# Un chillido que LLAMA A LOS SUYOS, no un golpe: tres medias lunas llenas y rojas que salen de su boca hacia LOS
# LADOS (hacia su camada), un poco abiertas hacia delante, filo claro y cuerpo que se difumina hacia dentro
# (BestiaAire._media_luna). Hacia delante se leian como zarpazos sobre su victima (visto en la hoja, 30/09).
func _llamada(capa: Node2D) -> void:
	if _t < 0.0:
		return
	for lado in [-1.0, 1.0]:
		var ang: float = _eje.angle() + lado * (PI * 0.5 - 0.35) + _giro * 0.3
		for k in 3:
			var tk: float = _t - float(k) * T_ENTRE_LLAMADA
			if tk < 0.0 or tk > T_LLAMADA:
				continue
			var u: float = tk / T_LLAMADA
			var r: float = lerpf(5.0, 26.0, sqrt(u))
			var abre: float = lerpf(0.5, 0.8, u)
			var alfa: float = (1.0 - u * u) * (1.0 - 0.15 * float(k)) * clampf(tk / 0.04, 0.0, 1.0)
			var grueso: float = lerpf(4.0, 9.0, u)
			if capa == _delante:
				BestiaAire._media_luna(capa, _o, ang - abre, ang + abre, r, grueso, LLAMADA_FILO, LLAMADA_DENTRO, alfa, true)
			elif capa == _brillo:
				BestiaAire._media_luna(capa, _o, ang - abre, ang + abre, r, grueso * 0.45, Color(1.0, 0.45, 0.35),
					Color(0.5, 0.0, 0.0), alfa * 0.45, true)
	# Un fogonazo rojo en su boca al soltarla.
	if capa == _brillo and _t < 0.14:
		BarridoAire.brillo(capa, _o, 9.0, Color(1.0, 0.3, 0.2, 0.6 * (1.0 - _t / 0.14)))


# ------------------------------------------------------------
#  EL CUERPO ARDIENTE
# ------------------------------------------------------------
# Una bocanada de fuego (la de la Ignicion del slime, SlimeAire._bocanada: tres capas, blanco dentro, naranja,
# rojo y humo al envejecer), con su contorno que se agita y lamiendo hacia arriba.
func _bocanada(ci: CanvasItem, c: Vector2, r: float, k: float, fase: float) -> void:
	if r <= 0.5:
		return
	var paso: float = floor(_t * 14.0) + fase
	var n: int = 14
	var contorno := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a))
		var rr: float = r * (0.8 + 0.3 * _ruido(float(i) + paso * 3.1, fase))
		if d.y < -0.2:
			rr *= 1.0 + 0.35 * (-d.y) + (0.45 * (-d.y) if (i + int(paso)) % 3 == 0 else 0.0)
		contorno.append(Vector2(d.x * rr, d.y * rr * (1.15 if d.y < 0.0 else 0.8)))
	var vida: float = 1.0 - smoothstep(0.7, 1.0, k)
	var viejo: float = smoothstep(0.35, 0.85, k)
	var capas: Array = [
		[1.0, FUEGO_NARANJA.lerp(FUEGO_OSCURO, viejo), FUEGO_ROJO.lerp(HUMO, viejo), 0.72],
		[0.62, FUEGO_AMARILLO.lerp(FUEGO_ROJO, viejo), FUEGO_NARANJA.lerp(FUEGO_OSCURO, viejo), 0.95],
		[0.32, FUEGO_BLANCO, FUEGO_AMARILLO, 1.0 - smoothstep(0.15, 0.45, k)]]
	for cp in capas:
		var alfa: float = float(cp[3]) * vida
		if alfa <= 0.01:
			continue
		var esc: float = float(cp[0])
		var pv := PackedVector2Array([c])
		var pc := PackedColorArray([Color(cp[1] as Color, alfa)])
		var pi := PackedInt32Array()
		for i in n:
			pv.append(c + contorno[i] * esc)
			pc.append(Color(cp[2] as Color, alfa))
		for i in n:
			pi.append_array([0, 1 + i, 1 + (i + 1) % n])
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


func _arde(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var tam0: float = clampf(_largo * 0.3, 5.0, 11.0)
	if capa == _brillo:
		# El fogonazo donde le han pegado, y el calor sobre quien le pego al llegar.
		if _t < 0.16:
			BarridoAire.brillo(capa, _o, tam0 * 2.2, Color(FUEGO_NARANJA, 0.7 * (1.0 - _t / 0.16)))
		var ll: float = _t - _viaje
		if ll >= 0.0 and ll < 0.3:
			BarridoAire.brillo(capa, _hasta, _ancho * 0.9, Color(FUEGO_NARANJA, 0.55 * (1.0 - ll / 0.3)))
		return
	if capa != _delante:
		return
	for p in _piezas:
		if bool(p.get("reventon", false)):
			# EL REVENTON sobre quien le pego: bocanadas que se abren desde su pecho y suben.
			var tr: float = _t - _viaje
			if tr < 0.0:
				continue
			var kr: float = clampf(tr / 0.45, 0.0, 1.0)
			if kr >= 1.0:
				continue
			var cr: Vector2 = _hasta + (p["d"] as Vector2) * _ancho * 0.45 * sqrt(kr) + _alto(10.0 * kr)
			_bocanada(capa, cr, tam0 * float(p["tam"]) * (0.6 + 0.6 * sin(kr * PI)), kr, float(p["fase"]))
			continue
		# LA LENGUA: cada bocanada viaja del golpe a su pecho, serpeando, y se va quemando por el camino.
		var tp: float = _t - float(p["t0"])
		if tp < 0.0:
			continue
		var u: float = clampf(tp / _viaje, 0.0, 1.0)
		var vida: float = clampf(tp / (_viaje + 0.22), 0.0, 1.0)
		if vida >= 1.0:
			continue
		var c: Vector2 = _o.lerp(_hasta, u) + (p["lado"] as Vector2) * sin(u * PI) + _alto(6.0 * sin(u * PI))
		_bocanada(capa, c, tam0 * float(p["tam"]) * (1.0 - 0.35 * vida), vida, float(p["fase"]))


# ------------------------------------------------------------
#  LA EMBOSCADA
# ------------------------------------------------------------
# En el SUELO, bajo la presa: un anillo blanco que late y se cierra sobre sus pies (la tela que tira), dos veces, y
# motas de hebra brillando que se recogen hacia ella. Circulos en el suelo, no elipses (huellas-suelo-circulos).
func _latido(capa: Node2D) -> void:
	if _t < 0.0 or capa != _suelo and capa != _brillo:
		return
	var r0: float = _ancho * 1.7
	for k in 2:
		var tk: float = _t - 0.13 * float(k)
		if tk < 0.0 or tk > 0.3:
			continue
		var u: float = tk / 0.3
		var r: float = lerpf(r0, r0 * 0.3, u * u)
		var alfa: float = sin(u * PI) * (0.85 - 0.3 * float(k))
		if capa == _suelo:
			MagiaAire._anillo(capa, _pies, r, lerpf(5.0, 2.5, u), Color(TELA, alfa))
		else:
			MagiaAire._anillo(capa, _pies, r, lerpf(3.0, 1.5, u), Color(1.0, 1.0, 1.0, alfa * 0.4))
	# Las motas de hebra que se recogen.
	if capa == _brillo:
		var km: float = clampf(_t / 0.35, 0.0, 1.0)
		for p in _piezas:
			var rr: float = r0 * float(p["r"]) * (1.0 - 0.75 * km)
			var q: Vector2 = _pies + Vector2(cos(float(p["a"])), sin(float(p["a"]))) * rr
			BarridoAire.brillo(capa, q, 3.5, Color(1.0, 1.0, 1.0, 0.8 * sin(km * PI)))


# ------------------------------------------------------------
#  EL FILO DE REFLEJO
# ------------------------------------------------------------
# Al pararle el golpe, la guadaña del lado de quien pega echa una estrella (el destello bueno, BarridoAire.destello)
# y un brillo de hueso; ladeada distinto cada vez.
func _destello(capa: Node2D) -> void:
	if _t < 0.0 or capa != _brillo:
		return
	var u: float = clampf(_t / T_DESTELLO, 0.0, 1.0)
	var crece: float = sin(clampf(_t / 0.07, 0.0, 1.0) * PI * 0.5)
	var alfa: float = 1.0 - u * u
	var tam: float = clampf(minf(_ancho, _largo) * 0.4, 9.0, 17.0)
	BarridoAire.destello(capa, _o, tam * crece * (1.0 + 0.2 * u), Color(ACERO_HUESO, alfa), _giro + u * 0.35)
	BarridoAire.brillo(capa, _o, tam * 0.7, Color(1.0, 0.95, 0.8, 0.35 * alfa))


# ------------------------------------------------------------
#  LA ECOLOCALIZACION
# ------------------------------------------------------------
# Tres medias lunas palidas (lila y blanco, las del Chillido del chillon) que salen de su cabeza hacia el que va en
# sigilo, abriendose, y al llegar lo ENVUELVEN: un par de lunas ")" "(" que se cierran sobre el y un fogonazo.
func _eco(capa: Node2D) -> void:
	if capa == _suelo:
		return
	var ang: float = _eje.angle()
	var dist: float = _o.distance_to(_hasta)
	for k in 3:
		var tk: float = _t + _viaje - float(k) * T_ENTRE_ECO
		if tk < 0.0:
			continue
		var u: float = tk / maxf(_viaje - float(k) * T_ENTRE_ECO, 0.12)
		if u >= 1.0:
			continue
		var c: Vector2 = _o + _eje * dist * u
		var r: float = lerpf(7.0, maxf(_ancho, 12.0) * 1.1, u)
		var abre: float = lerpf(0.6, 1.0, u)
		var alfa: float = (0.95 - 0.2 * float(k)) * clampf(tk / 0.05, 0.0, 1.0) * (1.0 - 0.3 * u)
		if capa == _delante:
			BestiaAire._media_luna(capa, c - _eje * r, ang - abre, ang + abre, r, lerpf(5.0, 10.0, u), Color.WHITE, ECO_C, alfa, true)
		else:
			BestiaAire._media_luna(capa, c - _eje * r, ang - abre, ang + abre, r, lerpf(3.0, 6.0, u), ECO_C, ECO_C.darkened(0.4),
				alfa * 0.4, true)
	if _t < 0.0:
		return
	# AL LLEGAR: dos lunas que se cierran sobre el (una por cada lado) y el fogonazo.
	var ue: float = clampf(_t / T_ECO_ENVUELVE, 0.0, 1.0)
	var alfa_e: float = 1.0 - ue
	var re: float = lerpf(_largo * 0.7, _largo * 0.42, sqrt(ue))
	if capa == _delante:
		for s in [-1.0, 1.0]:
			var base: float = (ang + PI * 0.5) if s > 0.0 else (ang - PI * 0.5)
			BestiaAire._media_luna(capa, _hasta, base - 0.9, base + 0.9, re, 9.0 * alfa_e + 2.0, Color.WHITE, ECO_C, alfa_e, true)
	else:
		BarridoAire.brillo(capa, _hasta, _largo * 0.7, Color(ECO_C, 0.6 * alfa_e))


# ------------------------------------------------------------
#  INTERRUMPIDO
# ------------------------------------------------------------
# Lo que cargaba se rompe: un fogonazo en el pecho y esquirlas rellenas (triangulos de filo claro) que saltan, caen
# con peso, giran y se apagan. Doradas si era una carga de arma, lila si era un conjuro (su circulo, a sus pies, se
# rompe aparte).
func _esquirlas(capa: Node2D) -> void:
	if _t < 0.0 or capa == _suelo:
		return
	var u: float = clampf(_t / T_ESQUIRLAS, 0.0, 1.0)
	if capa == _brillo:
		if _t < 0.14:
			BarridoAire.destello(capa, _o, _ancho * 0.9 * (1.0 - _t / 0.14 * 0.4), Color(_color, 1.0 - _t / 0.14), _giro)
		BarridoAire.brillo(capa, _o, _ancho * 0.8, Color(_color, 0.35 * (1.0 - u)))
		return
	for p in _piezas:
		var d: Vector2 = p["d"]
		var pos: Vector2 = _o + d * float(p["v"]) * _t + Vector2(0.0, 70.0 * _t * _t)
		var alfa: float = 1.0 - smoothstep(0.55, 1.0, u)
		var tam: float = float(p["tam"]) * (1.0 - 0.3 * u)
		var a: float = float(p["a0"]) + float(p["gira"]) * _t
		var v0 := Vector2(cos(a), sin(a)) * tam * 1.3
		var v1 := Vector2(cos(a + 2.3), sin(a + 2.3)) * tam * 0.7
		var v2 := Vector2(cos(a - 2.3), sin(a - 2.3)) * tam * 0.7
		Poligono.relleno(capa, PackedVector2Array([pos + v0, pos + v1, pos + v2]), Color(_color.darkened(0.25), alfa))
		Poligono.relleno(capa, PackedVector2Array([pos + v0 * 0.7, pos + v1 * 0.5, pos + (v2 * 0.3)]),
			Color(Color.WHITE.lerp(_color, 0.35), alfa))


# ------------------------------------------------------------
#  EL EMPUJON PEQUEÑO
# ------------------------------------------------------------
# En el SUELO, la marca del arrastre: dos surcos cortos y blandos (los dos pies), bolas oscuras que se estiran desde
# donde estaba hasta donde va y se borran. Delante, polvo que se levanta a los lados de los pies al deslizarse.
func _arrastre(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var u: float = clampf(_t / T_ARRASTRE, 0.0, 1.0)
	var fin: Vector2 = _o.lerp(_pies, u)
	var lat: Vector2 = _eje.orthogonal()
	var largo: float = _o.distance_to(fin)
	if capa == _suelo:
		var borra: float = 1.0 - clampf((_t - T_ARRASTRE) / T_ARRASTRE_QUEDA, 0.0, 1.0)
		for pie in [-1.0, 1.0]:
			var n: int = maxi(3, int(largo / 1.5))
			for i in n + 1:
				var k: float = float(i) / float(n)
				var q: Vector2 = _o.lerp(fin, k) + lat * pie * _ancho * 0.22
				# Mas marcado hacia el final (donde frena y aprieta).
				BestiaAire._bola(capa, q, _ancho * 0.16 * (0.6 + 0.6 * k), Color(SURCO, 0.6 * borra * (0.4 + 0.6 * k)))
		return
	if capa != _delante:
		return
	for p in _piezas:
		var tp: float = _t - float(p["u"]) * T_ARRASTRE
		if tp < 0.0 or tp > 0.5:
			continue
		var k2: float = tp / 0.5
		var c: Vector2 = _o.lerp(_pies, float(p["u"])) + lat * float(p["lado"]) * _ancho * (0.35 + 0.4 * k2) 			- _eje * 3.0 * k2 + Vector2(0.0, -float(p["sube"]) * k2 * K)
		BestiaAire._bola(capa, c, _ancho * 0.3 * float(p["tam"]) * (0.6 + 0.8 * sqrt(k2)), Color(POLVO, 0.7 * (1.0 - k2)))
