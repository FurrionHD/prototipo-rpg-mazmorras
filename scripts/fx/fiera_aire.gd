# ============================================================
#  fiera_aire.gd
#  LOS EFECTOS DE LAS BESTIAS DE LAS SIMAS en el mapa (30/09/2026): bestia acorazada, acechador y aberracion, uno a
#  uno y con su visto bueno (ver la memoria bestias-tactico). Aparte de BestiaAire (que ya es muy largo); usa sus
#  piezas estaticas (_media_luna, _bola, _tira). Empieza por la ACORAZADA:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.FIERA_*):
#    TESTARAZO   el basico: la testuz blindada contra el cuerpo. El frente del choque (media luna maciza combada hacia
#                quien embiste, del color de sus placas), un destello y esquirlas de piedra que salen hacia atras.
#    ZARPA       cada golpe del Zarpazo doble: TRES arañazos paralelos (una garra), medias lunas afiladas de hueso que
#                cruzan el cuerpo, cada golpe de un lado; el segundo cruza al primero.
#    PLACA       el CAPARAZON al parar un golpe de frente (Pantalla._mult_pasivas): un destello en estrella sobre las
#                placas y chispas que saltan hacia quien ha pegado: "esto no entra".
#  POR EL SUELO (SueloRoto.Tipo.FIERA_*, en el orden de Suelo):
#    ARROLLA     la Carga acorazada: una banda ANCHA de tierra raspada por su tripa blindada, las pisadas gordas de sus
#                cuatro patas a los lados, lajas que saltan y polvo. Al llegar al final, EL PISOTON: las losas del Golpe
#                sismico (SueloRoto.FRAGMENTOS) y el anillo de polvo del jabali (BestiaAire POLVO) en su circulo
#                (AbilityData.pisoton_final). Van DENTRO de este nodo y a su reloj, para que las hojas los vean igual.
#  NADA DE LINEAS (efectos-sin-lineas): medias lunas rellenas, bolas blandas, cometas. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name FieraAire

enum Modo { TESTARAZO, ZARPA, PLACA, ARROLLA }
# Los del suelo, en el orden de SueloRoto.Tipo.FIERA_*: no reordenar.
enum Suelo { ARROLLA }
const _MODO_DE_SUELO := [Modo.ARROLLA]

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const T_TESTARAZO := 0.5
const T_ZARPA := 0.34
const T_PLACA := 0.4
# LA CARGA va al paso de la bola del escarabajo: CombatTactico.mover_enemigo le da InsectoAire.T_RODADA a toda la que
# atraviesa. El pisoton cae al llegar.
const T_ARROLLA := InsectoAire.T_RODADA
const T_PISOTON_DURA := 1.2
const PLACA_C := Color(0.72, 0.56, 0.46)
const PLACA_CLARA := Color(0.95, 0.86, 0.74)
const PIEDRA := Color(0.46, 0.4, 0.34)

var modo: int = Modo.TESTARAZO
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _hasta: Vector2 = Vector2.ZERO
var _eje: Vector2 = Vector2.RIGHT
var _ancho: float = 14.0
var _largo: float = 26.0
var _tam: float = 8.0
var _viaje: float = 0.1
var _lado: float = 1.0
var _incl: float = 0.0   # ZARPA: la inclinacion propia de cada golpe
var _o: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _banda: float = 30.0
var _placa: Color = PLACA_C
var _placa_clara: Color = PLACA_CLARA
var _piezas: Array = []
var _radios: Array = []
var _lajas: Array = []
var _pisadas: Array = []
var forma: CombatFormas.Forma = null
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null
# EL PISOTON (solo ARROLLA): sus piezas van dentro y siguen el reloj de este nodo, con T_ARROLLA de retraso.
var _hijos_pisoton: Array = []

# El reloj. Con setter para que el pisoton vaya a la par tambien cuando alguien lo pone a mano (las hojas).
var _t: float = 0.0:
	set(v):
		_t = v
		_sincronizar_pisoton()


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = el centro de quien pega, 'caja' = el que lo recibe, 'espera' = lo que falta para el golpe, 'boca' = el
# ancho del dibujo de quien pega (el golpe va a SU escala, como los mordiscos de BestiaAire), 'color' = el de su ficha
# (color_visual): las placas del testarazo y del caparazon van de su color. 'lado' = de que lado entra el zarpazo.
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, semilla: int, espera: float, ritmo: float,
		boca: float = -1.0, color: Color = PLACA_C, lado: float = 0.0) -> FieraAire:
	if padre == null:
		return null
	var e := FieraAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._ancho = maxf(caja.size.x, 10.0)
	e._largo = maxf(caja.size.y, 10.0)
	e._tam = maxf((boca if boca > 0.0 else e._ancho) * 0.3, 4.0)
	e._placa = color.lerp(PLACA_C, 0.35)
	e._placa_clara = color.lightened(0.45).lerp(PLACA_CLARA, 0.4)
	e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.12, 0.12) * caja.size.x,
		e._rng.randf_range(-0.15, 0.05) * caja.size.y)
	var eje: Vector2 = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	e._eje = eje
	match m:
		Modo.TESTARAZO:
			e._viaje = 0.0
			e._t = -maxf(espera, 0.0)
			e._incl = e._rng.randf_range(-0.2, 0.2)
			# Las esquirlas salen hacia atras (hacia donde le empuja), abiertas en abanico.
			for i in 9:
				e._piezas.append({"d": eje.rotated(e._rng.randf_range(-0.9, 0.9)), "v": e._rng.randf_range(14.0, 28.0),
					"sube": e._rng.randf_range(8.0, 16.0), "tam": e._rng.randf_range(2.0, 3.4), "t0": e._rng.randf_range(0.0, 0.04)})
		Modo.ZARPA:
			e._viaje = clampf(espera, 0.06, 0.14)
			e._t = -e._viaje
			# DE QUE LADO ENTRA: el primer golpe por un lado y el segundo por el otro (el 'lado' que le pasan); sin el, al
			# azar. Y cada golpe con su inclinacion (efectos-orientados-no-fijos).
			e._lado = lado if lado != 0.0 else (1.0 if e._rng.randf() < 0.5 else -1.0)
			e._incl = e._rng.randf_range(-0.25, 0.25)
			e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.08, 0.08) * caja.size.x, -0.08 * caja.size.y)
		Modo.PLACA:
			e._viaje = 0.0
			e._t = -maxf(espera, 0.0)
			# EN SU FRENTE: el lado de las placas que mira a quien le pega (eje va de quien pega a el: el frente es -eje).
			e._hasta = caja.get_center() - eje * caja.size.x * 0.3 - Vector2(0.0, caja.size.y * 0.1)
			for i in 7:
				e._piezas.append({"d": (-eje).rotated(e._rng.randf_range(-1.1, 1.1)), "v": e._rng.randf_range(10.0, 20.0),
					"t0": e._rng.randf_range(0.0, 0.05)})
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
# 'pisoton' = el radio del circulo del final (AbilityData.pisoton_final); 0 = no hay. Por red viaja en el nucleo de la
# huella (SueloRoto.lanzar -> n_nucleo), que la linea no usa.
static func area(padre: Node, f: CombatFormas.Forma, s: int, semilla: int, espera: float, pisoton: float = 0.0) -> Node2D:
	if padre == null or f == null or s < 0 or s >= _MODO_DE_SUELO.size():
		return null
	var e := FieraAire.new()
	e.modo = int(_MODO_DE_SUELO[s])
	e.forma = f
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	e._o = SueloRoto.origen_de(f)
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	e._largo = maxf(f.largo, 4.0)
	e._banda = maxf(f.ancho, 8.0)
	# El borde de la banda, irregular (un surco perfecto parece de regla).
	var n: int = int(clampf(e._largo / 4.0, 8.0, 40.0))
	for i in n + 1:
		e._radios.append({"u": float(i) / float(n), "i": e._rng.randf_range(-0.1, 0.1), "d": e._rng.randf_range(-0.1, 0.1)})
	# LAS PISADAS de sus cuatro patas, a los dos lados de la banda: pares desordenados, cada una un poco torcida.
	# DESORDENADAS (sitio, tamaño y alguna que falta): en fila y a compas se leian como una LINEA DE PUNTOS. Mas
	# espaciadas, cada una movida a lo largo y hacia dentro/fuera.
	var paso: float = 13.0
	for i in int(e._largo / paso):
		for sg in [-1.0, 1.0]:
			if e._rng.randf() < 0.3:
				continue
			e._pisadas.append({"u": (float(i) + (0.5 if sg > 0.0 else 0.0) + e._rng.randf_range(-0.35, 0.35)) * paso / e._largo,
				"lado": sg * e._rng.randf_range(0.28, 0.5), "tam": e._rng.randf_range(2.6, 4.2)})
	# Polvo a los lados, a su paso.
	for i in int(clampf(e._largo / 6.0, 8.0, 22.0)):
		e._piezas.append({"u": e._rng.randf_range(0.04, 0.98), "lado": -1.0 if i % 2 == 0 else 1.0,
			"sube": e._rng.randf_range(4.0, 9.0), "tam": e._rng.randf_range(0.2, 0.34), "sale": e._rng.randf_range(0.2, 0.6)})
	# LAJAS: trozos planos de suelo que salta la tripa al raspar; mas grandes que los terrones del jabali.
	for i in int(clampf(e._largo / 10.0, 6.0, 12.0)):
		var pts := PackedVector2Array()
		var lados: int = e._rng.randi_range(4, 5)
		var r0: float = e._rng.randf_range(1.6, 2.8)
		for k in lados:
			var a: float = TAU * float(k) / float(lados) + e._rng.randf_range(-0.3, 0.3)
			pts.append(Vector2(cos(a), sin(a) * 0.7) * r0 * e._rng.randf_range(0.75, 1.15))
		e._lajas.append({"u": e._rng.randf_range(0.05, 0.95), "lado": -1.0 if i % 2 == 0 else 1.0, "pts": pts,
			"v": e._rng.randf_range(14.0, 28.0), "sube": e._rng.randf_range(9.0, 17.0), "gira": e._rng.randf_range(-8.0, 8.0)})
	padre.add_child(e)
	e._suelo = e._capa(SueloRoto.Z_SUELO, false)
	e._delante = e._capa(Z_ENCIMA, false)
	# EL PISOTON: losas y polvo en el circulo del final, a su reloj (parados: los mueve _sincronizar_pisoton).
	if pisoton > 0.0:
		var circ = circulo_pisoton(f, pisoton)
		for hijo in [SueloRoto.lanzar(e, circ, SueloRoto.Tipo.FRAGMENTOS, semilla, 0.0, 0.0),
				BestiaAire.area(e, circ, 0, semilla + 1, 0.0)]:
			if hijo != null:
				hijo.set_process(false)
				e._hijos_pisoton.append(hijo)
	e._t = -espera * e._ritmo
	return e


# EL CIRCULO DEL PISOTON de una linea 'f' con radio 'r': DELANTE de donde acaba (la bestia se para con los pies al final
# de la linea: centrado ahi, su cuerpo tapaba las losas). Lo usan la mecanica y la huella (CombatTactico.pisoton_de), este
# dibujo y las hojas: un solo sitio.
static func circulo_pisoton(f, r: float) -> RefCounted:
	return CombatFormas.circulo(f.origen + f.dir.normalized() * (f.largo + r * 0.9), r)


# CUANDO LE LLEGA a 'p' (en mundo): la carga, cuando le pasa por encima (como la bola del escarabajo); el pisoton,
# al final.
static func retraso(s: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	return clampf((p - f.origen).dot(f.dir.normalized()) / maxf(f.largo, 1.0), 0.0, 1.0) * T_ARROLLA


static func t_salir(_s: int) -> float:
	return T_ARROLLA


func duracion() -> float:
	match modo:
		Modo.TESTARAZO: return T_TESTARAZO
		Modo.ZARPA: return T_ZARPA
		Modo.PLACA: return T_PLACA
		Modo.ARROLLA: return T_ARROLLA + (T_PISOTON_DURA if not _hijos_pisoton.is_empty() else 1.4)
	return 1.0


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


# El pisoton va T_ARROLLA por detras de la carga. Sus piezas estan paradas: se les pone la hora y se repintan.
func _sincronizar_pisoton() -> void:
	for h in _hijos_pisoton:
		if not is_instance_valid(h):
			continue
		h.set("_t", _t - T_ARROLLA)
		h.queue_redraw()
		for capa in ["_suelo", "_delante", "_brillo"]:
			var c = h.get(capa)
			if c is CanvasItem:
				(c as CanvasItem).queue_redraw()


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.TESTARAZO: _testarazo(capa)
		Modo.ZARPA: _zarpa(capa)
		Modo.PLACA: _placa_fx(capa)
		Modo.ARROLLA: _arrolla(capa)


# ------------------------------------------------------------
#  LA BESTIA ACORAZADA
# ------------------------------------------------------------
# EL TESTARAZO: el frente del choque del jabali (BestiaAire._choque), pero MACIZO y del color de sus placas: una media
# luna gorda combada hacia quien embiste que se aplasta contra el cuerpo, con su contorno oscuro; un destello, y las
# esquirlas (cuadraditos de piedra, pixel) que saltan hacia atras, a donde le empuja.
func _testarazo(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var sale: Vector2 = _eje
	if capa == _brillo:
		if _t < 0.12:
			BarridoAire.destello(capa, _hasta - sale * _ancho * 0.25, _tam * 1.1,
				Color(1.0, 0.94, 0.82, 0.85 * (1.0 - _t / 0.12)), sale.angle())
		return
	if capa != _delante:
		return
	# GRANDE Y MACIZO (a la escala del pegador salia una medialunita palida sobre la figura): como poco, el cuerpo
	# entero de quien lo recibe, y se aguanta un rato antes de irse.
	# UN GOLPE SECO, NO UNA CUPULA (una media luna enorme y translucida se leia como una burbuja): el frente del choque
	# mediano y corto, del color de sus placas con su contorno, y un ESTALLIDO de cuñas gordas (cometas) que salen del
	# punto de impacto hacia donde le empuja, en abanico.
	var kf: float = clampf(_t / 0.1, 0.0, 1.0)
	var r: float = maxf(_ancho * 0.95, _tam * 1.2) * (0.85 + 0.2 * kf)
	var th: float = (-sale).angle()
	var c: Vector2 = _hasta + sale * r * 0.55
	var alfa: float = 1.0 - smoothstep(0.08, 0.22, _t)
	BestiaAire._media_luna(capa, c, th - 0.95, th + 0.95, r * 1.08, r * 0.55, BestiaAire.BOCA, BestiaAire.BOCA, alfa * 0.75, true)
	BestiaAire._media_luna(capa, c, th - 0.85, th + 0.85, r, r * 0.45, Color(1.0, 0.95, 0.86), _placa, alfa, true)
	# Gordas hasta el final y se apagan pronto: si adelgazan se quedan en RAYAS finas (efectos-sin-lineas).
	var ke: float = clampf(_t / 0.12, 0.0, 1.0)
	if ke < 1.0:
		for i in 7:
			var d: Vector2 = Vector2(sale.x, sale.y * K).normalized().rotated((float(i) - 3.0) * 0.36 + _incl)
			var ini: Vector2 = _hasta + d * r * (0.25 + 0.5 * ke)
			var fin: Vector2 = _hasta + d * r * (0.7 + 0.9 * sqrt(ke)) * (0.8 + 0.1 * float(i % 3))
			BarridoAire.cometa(capa, ini, fin, maxf(2.8, _ancho * 0.22), Color(1.0, 0.93, 0.8, pow(1.0 - ke, 1.5)))
	# Las esquirlas: suben y caen (parabola achatada), girando no hace falta: son pixeles.
	var pies: Vector2 = _hasta + Vector2(0.0, _largo * 0.35)
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > 0.42:
			continue
		var kt: float = tg / 0.42
		var d: Vector2 = g["d"]
		var p: Vector2 = _hasta + Vector2(d.x, d.y * K) * float(g["v"]) * kt \
			- Vector2(0.0, float(g["sube"]) * 4.0 * kt * (1.0 - kt) * K)
		var tam: float = float(g["tam"])
		capa.draw_rect(Rect2((p - Vector2(tam, tam) * 0.5).round(), Vector2(tam, tam)), Color(PIEDRA, 1.0 - kt * kt * kt))
		capa.draw_rect(Rect2((p - Vector2(tam, tam) * 0.5).round(), Vector2(tam * 0.5, tam * 0.5)),
			Color(_placa_clara, 0.8 * (1.0 - kt * kt)))
	# Un golpe de polvo a sus pies, hacia atras.
	var kp: float = clampf(_t / 0.45, 0.0, 1.0)
	for i in 4:
		var q: Vector2 = pies + Vector2(sale.x, sale.y * K).rotated((float(i) - 1.5) * 0.4) * (4.0 + 14.0 * sqrt(kp)) \
			- Vector2(0.0, 3.0 * kp)
		var rr: float = _ancho * 0.2 * (0.6 + 0.8 * kp)
		BestiaAire._bola(capa, q, rr * 1.2, Color(BestiaAire.POLVO, 0.28 * (1.0 - kp)))
		BestiaAire._bola(capa, q + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.7, Color(BestiaAire.POLVO_CLARO, 0.34 * (1.0 - kp)))


# EL ZARPAZO: una garra, TRES medias lunas paralelas de hueso (la pincelada del colmillo del jabali, filo claro que se
# difumina y cola que se afila) que cruzan el cuerpo de un lado a otro con un poco de caida. Cada arañazo sale un pelin
# despues que el anterior y con su largo; detras de cada uno, su contorno oscuro para que se lea sobre cualquier cuerpo.
# Orientada con el golpe: entra por el lado de 'lado' (visto desde quien pega) y cae hacia sus pies.
func _zarpa(capa: Node2D) -> void:
	var lat: Vector2 = Vector2(-_eje.y, _eje.x * K).normalized() * _lado
	if lat.length_squared() < 0.01:
		lat = Vector2.RIGHT * _lado
	# El tajo va de ARRIBA-lateral a ABAJO-el otro lateral: el centro del arco queda del lado del que entra, abajo.
	var th: float = (lat + Vector2(0.0, -0.5)).angle() + _incl
	# CORTAS Y GORDAS, afiladas por las dos puntas (medias lunas simetricas): con la pincelada larga del colmillo salian
	# pelos finos que colgaban por debajo de la figura. Tres concentricas, una garra.
	var r: float = maxf(_tam * 1.4, _ancho * 1.05)
	var sale: float = 0.05
	var u: float = clampf((_t + _viaje) / maxf(_viaje + sale, 0.01), 0.0, 1.0)
	u = 1.0 - (1.0 - u) * (1.0 - u)
	var k_ido: float = clampf((_t - sale) / 0.22, 0.0, 1.0)
	var alfa: float = clampf((_t + _viaje) / 0.03, 0.0, 1.0) * (1.0 - k_ido * k_ido)
	var grueso: float = maxf(_tam * 0.3, _ancho * 0.26)
	var sep: float = grueso * 1.25
	var s: float = -_lado
	var c: Vector2 = _hasta - Vector2(cos(th), sin(th)) * r * 0.7
	for i in 3:
		var ui: float = clampf(u * 1.25 - float(i) * 0.12, 0.0, 1.0)
		var ri: float = r + sep * (float(i) - 1.0)
		var a_ini: float = th - 0.6 * s
		var a_fin: float = th + (0.55 + 0.08 * float(i % 2)) * s
		var cabeza: float = lerpf(a_ini, a_fin, ui)
		var cola: float = lerpf(a_ini, cabeza, k_ido * 0.8)
		var punta: Vector2 = c + Vector2(cos(cabeza), sin(cabeza)) * ri
		if capa == _brillo:
			if i == 1 and _t >= 0.0 and _t < 0.12:
				BarridoAire.destello(capa, punta, _tam * 0.5, Color(1.0, 0.96, 0.9, 0.8 * (1.0 - _t / 0.12)), th)
			continue
		if capa != _delante or alfa <= 0.0 or ui <= 0.02:
			continue
		BestiaAire._media_luna(capa, c, cola, cabeza, ri + grueso * 0.2, grueso * 1.5, BestiaAire.ENCIA, BestiaAire.ENCIA, alfa * 0.8, true)
		BestiaAire._media_luna(capa, c, cola, cabeza, ri, grueso, BestiaAire.HUESO, BestiaAire.HUESO_SOMBRA, alfa, true)


# EL CAPARAZON PARA EL GOLPE: un destello en estrella sobre las placas del frente (grande y blanco, que crece en el
# instante y se apaga) y chispas cortas (cometas) que saltan hacia quien ha pegado. Sin circulo con borde.
func _placa_fx(capa: Node2D) -> void:
	if _t < 0.0:
		return
	if capa == _brillo:
		if _t < 0.16:
			var k: float = _t / 0.16
			BarridoAire.destello(capa, _hasta, _ancho * (0.45 + 0.25 * sin(PI * minf(k * 2.0, 1.0))),
				Color(1.0, 0.97, 0.88, 0.95 * (1.0 - k)), _eje.angle() + PI * 0.25)
		return
	if capa != _delante:
		return
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > 0.28:
			continue
		var kt: float = tg / 0.28
		var d: Vector2 = g["d"]
		var cabeza: Vector2 = _hasta + d * float(g["v"]) * sqrt(kt) + Vector2(0.0, 6.0 * kt * kt)
		var cola: Vector2 = cabeza - d * (3.0 + 3.0 * (1.0 - kt))
		BarridoAire.cometa(capa, cola, cabeza, 1.3, Color(1.0, 0.86, 0.55, 1.0 - kt))
	# Y la placa que se ilumina un momento (una bola blanda del color claro de sus placas).
	if _t < 0.2:
		BestiaAire._bola(capa, _hasta, _ancho * 0.35, Color(_placa_clara, 0.5 * (1.0 - _t / 0.2)))


# LA CARGA ACORAZADA POR EL SUELO: la rodada del escarabajo (InsectoAire._rodada: banda por capas sin bordes duros, mas
# oscura por el centro) pero ANCHA, de su tripa blindada raspando; a los lados las PISADAS gordas de sus patas; polvo que
# se levanta a su paso y LAJAS de suelo que saltan girando. Todo aparece segun pasa (T_ARROLLA de punta a punta).
func _arrolla(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var lat: Vector2 = _dir.orthogonal()
	var va: float = clampf(_t / T_ARROLLA, 0.0, 1.0)
	var seca: float = 1.0 - smoothstep(T_ARROLLA + 0.6, T_ARROLLA + T_PISOTON_DURA, _t)
	var semi: float = _banda * 0.32
	if capa == _suelo:
		var fuera_i := PackedVector2Array()
		var fuera_d := PackedVector2Array()
		var borde_i := PackedVector2Array()
		var borde_d := PackedVector2Array()
		var medio_i := PackedVector2Array()
		var medio_d := PackedVector2Array()
		for rd in _radios:
			var u: float = minf(float(rd["u"]), va)
			var p: Vector2 = _o + _dir * _largo * u
			var si: float = semi * (1.0 + float(rd["i"]))
			var sd: float = semi * (1.0 + float(rd["d"]))
			fuera_i.append(p - lat * (si + 3.0))
			fuera_d.append(p + lat * (sd + 3.0))
			borde_i.append(p - lat * si)
			borde_d.append(p + lat * sd)
			medio_i.append(p - lat * si * 0.45)
			medio_d.append(p + lat * sd * 0.45)
			if float(rd["u"]) >= va:
				break
		if borde_i.size() >= 2:
			BestiaAire._tira(capa, fuera_i, fuera_d, Color(BestiaAire.TIERRA, 0.12 * seca))
			BestiaAire._tira(capa, borde_i, borde_d, Color(BestiaAire.TIERRA, 0.17 * seca))
			BestiaAire._tira(capa, medio_i, medio_d, Color(0.16, 0.12, 0.09, 0.2 * seca))
		# Las pisadas: huellas ovaladas hondas (oscuras) con un labio claro detras, que aparecen al pasar.
		for pd in _pisadas:
			if float(pd["u"]) > va:
				continue
			var p2: Vector2 = _o + _dir * _largo * float(pd["u"]) + lat * _banda * float(pd["lado"])
			var tam: float = float(pd["tam"])
			BestiaAire._bola(capa, p2 - _dir * tam * 0.5, tam * 1.2, Color(0.66, 0.58, 0.47, 0.45 * seca))
			BestiaAire._bola(capa, p2, tam, Color(0.08, 0.06, 0.05, 0.85 * seca))
			BestiaAire._bola(capa, p2, tam * 0.55, Color(0.05, 0.04, 0.03, 0.9 * seca))
		return
	if capa != _delante:
		return
	for g in _piezas:
		var tp: float = _t - float(g["u"]) * T_ARROLLA
		if tp < 0.0 or tp > 0.7:
			continue
		var kv: float = tp / 0.7
		var lado: float = float(g["lado"])
		var base: Vector2 = _o + _dir * _largo * float(g["u"]) + lat * semi * lado
		var p3: Vector2 = base + lat * lado * float(g["sale"]) * semi * kv - Vector2(0.0, float(g["sube"]) * kv)
		var rr: float = _banda * float(g["tam"]) * (0.5 + 0.9 * kv)
		BestiaAire._bola(capa, p3, rr * 1.2, Color(BestiaAire.POLVO, 0.3 * (1.0 - kv)))
		BestiaAire._bola(capa, p3 + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.75, Color(BestiaAire.POLVO_CLARO, 0.36 * (1.0 - kv)))
	for lj in _lajas:
		var tl: float = _t - float(lj["u"]) * T_ARROLLA
		if tl < 0.0 or tl > 0.5:
			continue
		var kl: float = tl / 0.5
		var b: Vector2 = _o + _dir * _largo * float(lj["u"]) + lat * semi * float(lj["lado"])
		var c: Vector2 = b + lat * float(lj["lado"]) * float(lj["v"]) * kl - Vector2(0.0, float(lj["sube"]) * 4.0 * kl * (1.0 - kl) * K)
		var giro: float = float(lj["gira"]) * tl
		var pts := PackedVector2Array()
		for q in (lj["pts"] as PackedVector2Array):
			pts.append(c + q.rotated(giro))
		var a: float = 1.0 - kl * kl * kl
		BestiaAire._poligono(capa, pts, Color(PIEDRA, a))
		var arriba := PackedVector2Array()
		for q in pts:
			arriba.append(c + (q - c) * 0.55 + Vector2(-0.4, -0.5))
		BestiaAire._poligono(capa, arriba, Color(0.64, 0.57, 0.48, a))
