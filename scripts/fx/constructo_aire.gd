# ============================================================
#  constructo_aire.gd
#  LOS EFECTOS DE LOS CONSTRUCTOS en el mapa (30/09/2026, paso 2, uno a uno y con su visto bueno; ver la memoria
#  constructos-tactico). Empieza por el GOLEM DE ARCILLA:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.CONSTRUCTO_*):
#    APLASTON    el puñetazo (el gesto lo hace su sprite, 'embestida'), copiado del porrazo de la maza (MazaAire, "god"):
#                el puño CAE DE ARRIBA ABAJO sobre quien lo recibe (la estela de arcilla que baja), el fogonazo romo
#                del impacto, una onda que APLASTA contra el suelo y PIEDRECILLAS angulosas que saltan alto y caen
#                ("pega duro y es grande"). En la Machaca, mas gordo ('peso'). La 1a version (media luna de lado y
#                terrones redondos) se leia como un corte horizontal y "circulos guarros" (30/09).
#    PEGOTES     si el golpe le deja LENTO: manchas de barro en los pies un momento (CombatTactico._on_impacto).
#  SOBRE EL GOLEM (CombatTactico._tick_barro, mirando su estado; tambien en el espejo):
#    COCERSE     el fuego lo cuece (o se Endurece): un resplandor de brasa que le sube de los pies a la cabeza y vaho.
#    VAPOR       el agua le cae estando cocido: una nube de vapor al apagarse.
#    DURO        mientras esta cocido/endurecido: algun hilo de vaho de vez en cuando (el tono terracota lo pone el
#                shader tinte_constructo sobre su sprite: el modulate lo reescribe el aviso del golpe cada fotograma).
#    BLANDO      mientras esta mojado: gotas de barro que le caen y un charquito bajo los pies (y el tono de barro
#                mojado en el shader).
#  Y LA GARGOLA (30/09, paso 2, en su basalto: GargolaSprites._basalto):
#    SURCOS      el zarpazo (el gesto lo hace su sprite): TRES SURCOS de garra que bajan de arriba abajo sobre quien lo
#                recibe, gordos y cortos, inclinados del lado del golpe, y ESQUIRLAS angulosas que saltan.
#    POLVO       si el zarpazo le deja LENTO: polvo de piedra en los pies un momento.
#    PICADO      cae encima como una losa: el golpe de ARRIBA del aplaston con sus piedrecillas, en basalto (el suelo lo
#                revienta el ESTALLIDO de la huella, como la Machaca).
#    PETREA      la Mirada petrea sobre quien la recibe: se le cubre de piedra gris de los pies a media pierna.
#    CONO        (por el suelo, SueloRoto.Tipo.CONSTRUCTO_PETREA) la onda de piedra gris que avanza por el cono desde
#                sus ojos claros.
#    ESTATUA     le pegan estando POSADA (recibe la mitad): destello seco de piedra, chispas y lascas.
#    DESPEREZA   deja de estar posada (se mueve o se eleva): le caen trocitos de piedra, como desperezandose (el gris de
#                estatua lo pone el shader tinte_constructo, CombatTactico._tick_posadas).
#  Y EL COLOSO (30/09, paso 2, en su granito):
#    MAZO        su manotazo (el brazo que cae lo hace su sprite, 'basico'): el golpe de ARRIBA del aplaston, mas gordo y
#                con LASCAS CUADRADAS de sillar.
#    SISMO       a quien le pilla el Pisoton: polvo de granito en los pies (y le tiembla la figura: CombatTactico).
#    SISMO_SUELO (por el suelo, SueloRoto.Tipo.CONSTRUCTO_SISMO) tres anillos de losas que saltan desde el pie, el de
#                dentro el mas gordo, y las grietas hasta el borde.
#    MURALLA     se planta (Fortaleza): el pulso azul de sus runas de los pies a la cabeza y SILLARES que brotan alrededor
#                de sus pies y se hunden (y mientras dure, las runas le brillan: shader tinte_constructo 'runas').
#    CLAVADO     Imparable: intentan moverlo y no se mueve: grietas bajo sus pies y polvo a ras de suelo.
#  NADA DE LINEAS (efectos-sin-lineas): medias lunas llenas, bolas con borde, cometas gordas. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name ConstructoAire

enum Modo { APLASTON, PEGOTES, COCERSE, VAPOR, DURO, BLANDO, SURCOS, POLVO, PICADO, PETREA, CONO, ESTATUA, DESPEREZA,
	MAZO, SISMO, SISMO_SUELO, MURALLA, CLAVADO }
# Los de la gargola: en basalto y no en arcilla.
const _DE_PIEDRA := [Modo.SURCOS, Modo.POLVO, Modo.PICADO, Modo.PETREA, Modo.CONO, Modo.ESTATUA, Modo.DESPEREZA,
	Modo.MAZO, Modo.SISMO, Modo.SISMO_SUELO, Modo.MURALLA, Modo.CLAVADO]

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ARCILLA := Color(0.6, 0.45, 0.3)
const T_APLASTON := 0.55
const T_PEGOTES := 0.9
const T_COCERSE := 0.8
const T_VAPOR := 0.9
const T_SECA := 0.5
const BRASA := Color(1.0, 0.55, 0.18)
const VAHO := Color(0.86, 0.84, 0.82)
const POLVO := Color(0.66, 0.57, 0.46)
const BASALTO := Color(0.4, 0.42, 0.45)
const POLVO_PIEDRA := Color(0.6, 0.62, 0.65)
const OJO_CLARO := Color(0.86, 0.92, 0.96)
const T_SURCOS := 0.5
const T_POLVO := 0.8
const T_PETREA := 1.2
const T_CONO := 0.4
const T_ESTATUA := 0.4
const T_DESPEREZA := 0.8
const GRANITO := Color(0.45, 0.45, 0.5)
const RUNA := Color(0.55, 0.9, 1.0)
const T_MURALLA := 1.3
const T_CLAVADO := 0.6
const T_SISMO := 0.3

var modo: int = Modo.APLASTON
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _hasta: Vector2 = Vector2.ZERO
var _pies: Vector2 = Vector2.ZERO
var _eje: Vector2 = Vector2.RIGHT
var _ancho: float = 14.0
var _largo: float = 26.0
var _peso: float = 1.0
var _incl: float = 0.0
var _imp: Vector2 = Vector2.ZERO     # APLASTON: donde entra el puño
var _swing: Array = []               # APLASTON: por donde baja (bezier de tres puntos)
const GRAVEDAD := 320.0
var _piezas: Array = []
var _secando: float = -1.0
var _borde: Color = Color(0.2, 0.14, 0.09)
var _barro: Color = ARCILLA
var _claro: Color = Color(0.8, 0.66, 0.48)
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = el centro de quien pega, 'caja' = el que lo recibe, 'color' = el de su ficha (su arcilla), 'peso' = 1 el
# puñetazo, mas en la Machaca.
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, pies: Vector2, color: Color, semilla: int,
		espera: float, ritmo: float, peso: float = 1.0) -> ConstructoAire:
	if padre == null:
		return null
	var e := ConstructoAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._ancho = maxf(caja.size.x, 8.0)
	e._largo = maxf(caja.size.y, 10.0)
	e._pies = pies
	e._peso = peso
	e._tonos(color, m in _DE_PIEDRA)
	e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.12, 0.12) * caja.size.x,
		e._rng.randf_range(-0.15, 0.05) * caja.size.y)
	e._eje = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	e._incl = e._rng.randf_range(-0.25, 0.25)
	e._t = -maxf(espera, 0.0)
	match m:
		Modo.APLASTON, Modo.PICADO, Modo.MAZO:
			# EL IMPACTO: arriba en su cuerpo (cabeza y hombros), del lado de quien pega. El puño viene de ARRIBA, un poco
			# de su lado (cada golpe con su inclinacion).
			e._imp = caja.get_center() - e._eje * caja.size.x * 0.15 + Vector2(e._rng.randf_range(-0.1, 0.1) * caja.size.x,
				-caja.size.y * e._rng.randf_range(0.18, 0.3))
			var lado: float = 1.0 if e._rng.randf() < 0.5 else -1.0
			var alto: float = caja.size.y * (1.1 + 0.3 * peso)
			e._swing = [e._imp + Vector2(-e._eje.x * 8.0 + lado * 7.0, -alto), e._imp + Vector2(-e._eje.x * 4.0 + lado * 3.0, -alto * 0.45),
				e._imp]
			# LAS PIEDRECILLAS: poligonos de 4-5 lados (no bolas), que salen hacia arriba y hacia donde empuja el golpe, alto,
			# girando, y caen con peso.
			for i in int(round(11.0 * peso)):
				var sal: Vector2 = (Vector2(e._eje.x, e._eje.y * K) * 0.6 + Vector2(e._rng.randf_range(-1.0, 1.0), 0.0)).normalized()
				var n_l: int = 4 + e._rng.randi() % 2
				var forma := PackedVector2Array()
				for k in n_l:
					var a: float = TAU * float(k) / float(n_l) + e._rng.randf_range(-0.35, 0.35)
					forma.append(Vector2(cos(a), sin(a)) * e._rng.randf_range(0.65, 1.1))
				e._piezas.append({"v": sal * e._rng.randf_range(30.0, 70.0) * sqrt(peso)
					+ Vector2(0.0, -e._rng.randf_range(70.0, 130.0) * sqrt(peso)),
					"tam": e._rng.randf_range(1.6, 3.0) * sqrt(peso), "gira": e._rng.randf_range(-14.0, 14.0),
					"forma": forma, "t0": e._rng.randf_range(0.0, 0.04)})
		Modo.MURALLA:
			# Seis sillares alrededor de sus pies (circulo en el suelo), cada uno con su tamaño y su momento.
			for i in 6:
				var a_m: float = TAU * (float(i) + 0.5) / 6.0 + e._rng.randf_range(-0.2, 0.2)
				# Pegados a sus pies y GORDOS (a 0,85 del ancho y 7-10 px salian lejos y diminutos).
				var r_m: float = e._rng.randf_range(0.42, 0.52)
				e._piezas.append({"x": cos(a_m) * r_m, "y": sin(a_m) * r_m * 0.6, "w": e._rng.randf_range(13.0, 17.0),
					"h": e._rng.randf_range(20.0, 30.0), "t0": e._rng.randf_range(0.0, 0.12)})
		Modo.CLAVADO:
			for i in 6:
				e._piezas.append({"a": TAU * (float(i) + e._rng.randf_range(-0.3, 0.3)) / 6.0, "l": e._rng.randf_range(0.5, 0.85)})
		Modo.SURCOS:
			# De que lado viene el golpe: los surcos se inclinan hacia alli (arriba del lado de quien pega).
			var lado_s: float = -signf(e._eje.x) if absf(e._eje.x) > 0.15 else (1.0 if e._rng.randf() < 0.5 else -1.0)
			e._incl = lado_s * e._rng.randf_range(0.25, 0.45)
			e._imp = caja.get_center() + Vector2(e._rng.randf_range(-0.08, 0.08) * caja.size.x, -caja.size.y * 0.08)
			for i in 7:
				e._piezas.append(_esquirla(e._rng, Vector2(-lado_s * 0.8 + e._eje.x * 0.4, 0.0), 0.8))
		Modo.ESTATUA:
			e._imp = caja.get_center() - e._eje * caja.size.x * 0.25 + Vector2(0.0, -caja.size.y * 0.1)
			for i in 6:
				e._piezas.append(_esquirla(e._rng, Vector2(-e._eje.x, -e._eje.y * K), 0.6))
		Modo.DESPEREZA:
			# Trocitos que se le sueltan del lomo, los hombros y las alas y caen a sus pies.
			for i in 9:
				var q: Dictionary = _esquirla(e._rng, Vector2.ZERO, 0.5)
				q["x"] = e._rng.randf_range(-0.42, 0.42)
				q["y"] = e._rng.randf_range(-0.45, 0.05)
				q["v"] = Vector2(e._rng.randf_range(-12.0, 12.0), e._rng.randf_range(-20.0, 0.0))
				q["t0"] = e._rng.randf_range(0.0, 0.25)
				e._piezas.append(q)
		Modo.POLVO, Modo.PETREA, Modo.SISMO:
			for i in 6:
				e._piezas.append({"x": e._rng.randf_range(-0.4, 0.4), "t0": e._rng.randf_range(0.0, 0.15),
					"tam": e._rng.randf_range(0.8, 1.2), "sube": e._rng.randf_range(4.0, 9.0), "h": e._rng.randf_range(0.7, 1.0)})
		Modo.PEGOTES:
			for i in 4:
				var mancha := PackedVector2Array()
				for k in 9:
					var a2: float = TAU * float(k) / 9.0
					mancha.append(Vector2(cos(a2), sin(a2) * 0.6) * e._rng.randf_range(0.6, 1.15))
				e._piezas.append({"x": e._rng.randf_range(-0.4, 0.4), "y": e._rng.randf_range(-0.1, 0.02),
					"tam": e._rng.randf_range(2.2, 3.4), "forma": mancha})
		Modo.COCERSE, Modo.VAPOR:
			for i in (7 if m == Modo.COCERSE else 11):
				e._piezas.append({"x": e._rng.randf_range(-0.4, 0.4), "t0": e._rng.randf_range(0.0, 0.35),
					"sube": e._rng.randf_range(18.0, 34.0), "tam": e._rng.randf_range(0.8, 1.3)})
	# EL MAZO DEL COLOSO: las lascas son SILLARES (cuadradas, sin girar casi) y mas gordas.
	if m == Modo.MAZO:
		for g in e._piezas:
			var lado_q: float = e._rng.randf_range(0.85, 1.1)
			g["forma"] = PackedVector2Array([Vector2(-lado_q, -lado_q), Vector2(lado_q, -lado_q), Vector2(lado_q, lado_q),
				Vector2(-lado_q, lado_q)])
			g["tam"] = float(g["tam"]) * 1.35
			g["gira"] = float(g["gira"]) * 0.3
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	padre.add_child(e)
	return e


# LO QUE SE QUEDA mientras dure su estado (DURO o BLANDO): sigue a su cuerpo (seguir) y se va (secar).
static func estado(padre: Node, m: int, caja: Rect2, pies: Vector2, color: Color, semilla: int) -> ConstructoAire:
	var e: ConstructoAire = sobre_cuerpo(padre, m, caja.get_center(), caja, pies, color, semilla, 0.0, 1.0)
	if e != null:
		e._hasta = caja.get_center()
	return e


func seguir(caja: Rect2, pies: Vector2) -> void:
	_ancho = maxf(caja.size.x, 8.0)
	_largo = maxf(caja.size.y, 10.0)
	_hasta = caja.get_center()
	_pies = pies


func secar() -> void:
	if _secando < 0.0:
		_secando = _t


func _tonos(color: Color, piedra: bool = false) -> void:
	if piedra:
		# EL BASALTO DE SU SPRITE (GargolaSprites._colores): el borde, la piedra y la luz fria del lomo.
		_barro = GargolaSprites._basalto(color)
		_borde = _barro.darkened(0.72)
		_claro = _barro.lerp(Color(0.74, 0.78, 0.84), 0.34)
		return
	_barro = color.lerp(ARCILLA, 0.4)
	_borde = _barro.darkened(0.65)
	_claro = _barro.lightened(0.35)


# UNA ESQUIRLA ANGULOSA (poligono de 4-5 lados) que sale hacia 'hacia' y hacia arriba, y cae con peso.
static func _esquirla(rng: RandomNumberGenerator, hacia: Vector2, fuerza: float) -> Dictionary:
	var n_l: int = 4 + rng.randi() % 2
	var forma_e := PackedVector2Array()
	for k in n_l:
		var a: float = TAU * float(k) / float(n_l) + rng.randf_range(-0.35, 0.35)
		forma_e.append(Vector2(cos(a), sin(a)) * rng.randf_range(0.6, 1.1))
	var sal: Vector2 = (hacia * 0.7 + Vector2(rng.randf_range(-1.0, 1.0), 0.0)).normalized()
	return {"v": sal * rng.randf_range(30.0, 60.0) * fuerza + Vector2(0.0, -rng.randf_range(60.0, 110.0) * fuerza),
		"tam": rng.randf_range(1.5, 2.6), "gira": rng.randf_range(-14.0, 14.0), "forma": forma_e,
		"t0": rng.randf_range(0.0, 0.05)}


func duracion() -> float:
	match modo:
		Modo.APLASTON: return T_APLASTON
		Modo.PEGOTES: return T_PEGOTES
		Modo.COCERSE: return T_COCERSE
		Modo.VAPOR: return T_VAPOR
		Modo.PICADO: return T_APLASTON
		Modo.SURCOS: return T_SURCOS
		Modo.POLVO: return T_POLVO
		Modo.PETREA: return T_PETREA
		Modo.CONO: return T_CONO + 0.35
		Modo.ESTATUA: return T_ESTATUA
		Modo.DESPEREZA: return T_DESPEREZA
		Modo.MAZO: return T_APLASTON
		Modo.SISMO: return T_POLVO
		Modo.SISMO_SUELO: return T_SISMO + 0.8
		Modo.MURALLA: return T_MURALLA
		Modo.CLAVADO: return T_CLAVADO
	return INF   # los que se quedan: hasta que se secan


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
	if _t >= duracion() or (_secando >= 0.0 and _t - _secando >= T_SECA):
		queue_free()
		return
	for n in [_suelo, _delante, _brillo]:
		if n != null:
			(n as Node2D).queue_redraw()


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.APLASTON, Modo.PICADO, Modo.MAZO: _aplaston(capa)
		Modo.SISMO: _polvo(capa)
		Modo.SISMO_SUELO: _sismo_suelo(capa)
		Modo.MURALLA: _muralla(capa)
		Modo.CLAVADO: _clavado(capa)
		Modo.PEGOTES: _pegotes(capa)
		Modo.SURCOS: _surcos(capa)
		Modo.POLVO: _polvo(capa)
		Modo.PETREA: _petrea(capa)
		Modo.CONO: _cono(capa)
		Modo.ESTATUA: _estatua(capa)
		Modo.DESPEREZA: _despereza(capa)
		Modo.COCERSE: _cocerse(capa)
		Modo.VAPOR: _vapor(capa)
		Modo.DURO: _duro(capa)
		Modo.BLANDO: _blando(capa)


# Lo que queda al irse (los que se quedan se secan poco a poco).
func _queda() -> float:
	return 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)


# UN TERRON: bola de arcilla con su borde oscuro, su relleno y un brillo arriba a la izquierda (como su sprite).
func _terron(ci: CanvasItem, p: Vector2, r: float, alfa: float) -> void:
	if r <= 0.4 or alfa <= 0.01:
		return
	ci.draw_circle(p, r + 0.8, Color(_borde, alfa))
	ci.draw_circle(p, r, Color(_barro, alfa))
	ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(_claro, alfa))


# ------------------------------------------------------------
#  EL APLASTON (el puñetazo y la Machaca)
# ------------------------------------------------------------
const T_BAJA := 0.12

func _en_swing(u: float) -> Vector2:
	var p0: Vector2 = _swing[0]
	var p1: Vector2 = _swing[1]
	var p2: Vector2 = _swing[2]
	return p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)


# LA ESTELA DEL PUÑO que baja (la de la maza, MazaAire._estela, en arcilla): banda rellena GORDA en la cabeza y afilada
# y transparente hacia la cola.
func _estela_puno(ci: CanvasItem, s_cola: float, s_cabeza: float, grueso: float, alfa: float) -> void:
	if alfa <= 0.0 or s_cabeza - s_cola < 0.01:
		return
	var n: int = 10
	var tr := Color(_barro, 0.0)
	for i in n:
		var u0: float = float(i) / float(n)
		var u1: float = float(i + 1) / float(n)
		var p0: Vector2 = _en_swing(lerpf(s_cola, s_cabeza, u0))
		var p1: Vector2 = _en_swing(lerpf(s_cola, s_cabeza, u1))
		var d: Vector2 = (p1 - p0).normalized().orthogonal() if p1.distance_squared_to(p0) > 0.0001 else Vector2.RIGHT
		var w0: float = grueso * pow(u0, 1.3)
		var w1: float = grueso * pow(u1, 1.3)
		var c0 := Color(_claro, alfa * u0)
		var c1 := Color(_claro, alfa * u1)
		var h0 := Color(_barro, alfa * 0.6 * u0)
		var h1 := Color(_barro, alfa * 0.6 * u1)
		for lado in [1.0, -1.0]:
			ci.draw_primitive(PackedVector2Array([p0, p1, p1 + d * w1 * 0.45 * lado]), PackedColorArray([c0, c1, h1]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0, p1 + d * w1 * 0.45 * lado, p0 + d * w0 * 0.45 * lado]),
				PackedColorArray([c0, h1, h0]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.45 * lado, p1 + d * w1 * 0.45 * lado, p1 + d * w1 * lado]),
				PackedColorArray([h0, h1, tr]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.45 * lado, p1 + d * w1 * lado, p0 + d * w0 * lado]),
				PackedColorArray([h0, tr, tr]), PackedVector2Array())


# UNA PIEDRECILLA: poligono con su borde oscuro, su cara y una arista clara (como la piedra de su sprite).
func _piedra(ci: CanvasItem, p: Vector2, forma: PackedVector2Array, tam: float, giro: float, alfa: float) -> void:
	if alfa <= 0.01 or tam <= 0.3:
		return
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	for q in forma:
		var r: Vector2 = q.rotated(giro)
		fuera.append(p + r * (tam + 0.8))
		dentro.append(p + r * tam)
	Poligono.relleno(ci, fuera, Color(_borde, alfa))
	Poligono.relleno(ci, dentro, Color(_barro, alfa))
	Poligono.relleno(ci, PackedVector2Array([dentro[0], dentro[1], p]), Color(_claro, alfa))


func _aplaston(capa: Node2D) -> void:
	var escala: float = 0.85 + 0.35 * _peso
	var grueso: float = maxf(_ancho * 0.9, 12.0) * escala
	if capa == _delante:
		# 1) EL PUÑO QUE BAJA: la estela de arriba abajo que acaba en el golpe y se apaga enseguida.
		var sw: float = clampf((_t + T_BAJA) / T_BAJA, 0.0, 1.0)
		if sw > 0.0 and _t < 0.1:
			_estela_puno(capa, maxf(0.0, sw - 0.75), sw * sw * (3.0 - 2.0 * sw), grueso, 0.95 * (1.0 - clampf(_t / 0.1, 0.0, 1.0)))
		if _t < 0.0:
			return
		# 3) LA ONDA que aplasta: media luna rellena hacia ABAJO (contra el suelo) que se abre y se apaga.
		var ko: float = clampf(_t / 0.2, 0.0, 1.0)
		if ko < 1.0:
			var ang: float = PI * 0.5 + _incl * 0.5
			BestiaAire._media_luna(capa, _imp, ang - 1.35, ang + 1.35, (5.0 + 16.0 * ko) * escala, lerpf(11.0, 6.0, ko) * escala,
				_claro, _barro, 0.85 * (1.0 - ko), true)
		# 4) LAS PIEDRECILLAS: saltan alto, giran y caen; al llegar a los pies se paran y se apagan.
		for g in _piezas:
			var tg: float = _t - float(g["t0"])
			if tg < 0.0 or tg > 0.7:
				continue
			var v: Vector2 = g["v"]
			var p: Vector2 = _imp + v * tg + Vector2(0.0, 0.5 * GRAVEDAD * tg * tg)
			var suelo_y: float = _pies.y + 2.0 + float(g["tam"])
			var alfa: float = 1.0
			if p.y > suelo_y and v.y + GRAVEDAD * tg > 0.0:
				p.y = suelo_y
				alfa = 1.0 - clampf((tg - 0.45) / 0.25, 0.0, 1.0)
			_piedra(capa, p, g["forma"], float(g["tam"]), float(g["gira"]) * minf(tg, 0.45), alfa)
		return
	if capa == _brillo:
		if _t < 0.0:
			return
		# 2) EL FOGONAZO ROMO del impacto: destello corto y un brillo calido.
		var pulso: float = exp(-_t / 0.06)
		BarridoAire.destello(capa, _imp, (9.0 + 10.0 * pulso) * escala, Color(1.0, 0.95, 0.85, pulso), _incl + 0.4)
		BarridoAire.brillo(capa, _imp, grueso * 0.8, Color(1.0, 0.85, 0.65, 0.5 * (1.0 - clampf(_t / 0.2, 0.0, 1.0))))
		return
	if capa == _suelo and _t >= 0.0:
		# 5) EL POLVO que levanta a sus pies (el golpe le hunde contra el suelo), hacia los lados.
		var kp: float = clampf(_t / 0.45, 0.0, 1.0)
		for i in 4:
			var lado: float = -1.0 if i % 2 == 0 else 1.0
			var q: Vector2 = _pies + Vector2(lado * _ancho * (0.35 + 0.6 * kp) * (1.0 + 0.3 * float(i / 2)), -4.0 * kp)
			BestiaAire._bola(capa, q, _ancho * (0.28 + 0.3 * kp) * escala, Color(POLVO, 0.4 * (1.0 - kp)))


# ------------------------------------------------------------
#  LOS PEGOTES (le ha dejado lento)
# ------------------------------------------------------------
func _pegotes(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var sale: float = clampf(_t / 0.1, 0.0, 1.0)
	var alfa: float = 1.0 - smoothstep(0.6, 1.0, _t / T_PEGOTES)
	for g in _piezas:
		var p: Vector2 = _pies + Vector2(float(g["x"]) * _ancho, float(g["y"]) * _largo + 1.5 * _t)
		# MANCHAS de barro pegadas (con su borde), no bolas; resbalan un poco mientras se van.
		var tam: float = float(g["tam"]) * sale
		var fuera := PackedVector2Array()
		var dentro := PackedVector2Array()
		for q in (g["forma"] as PackedVector2Array):
			fuera.append(p + q * (tam + 0.8))
			dentro.append(p + q * tam)
		Poligono.relleno(capa, fuera, Color(_borde, alfa))
		Poligono.relleno(capa, dentro, Color(_barro.darkened(0.2), alfa))


# ------------------------------------------------------------
#  COCERSE (el fuego, o el Endurecerse)
# ------------------------------------------------------------
# Un resplandor de brasa que le sube de los pies a la cabeza (una banda llena y blanda) y el vaho caliente que sube.
func _cocerse(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var u: float = clampf(_t / (T_COCERSE * 0.6), 0.0, 1.0)
	if capa == _brillo:
		var alto: float = lerpf(_largo * 0.45, -_largo * 0.5, u)
		var c: Vector2 = _hasta + Vector2(0.0, alto)
		var a: float = sin(u * PI) * (1.0 - _t / T_COCERSE)
		BestiaAire._bola(capa, c, _ancho * 0.75, Color(BRASA, 0.7 * a))
		BarridoAire.brillo(capa, _hasta, _ancho * 0.9, Color(BRASA, 0.3 * a))
		return
	if capa == _delante:
		_vaho(capa, 0.55)


func _vaho(capa: Node2D, fuerza: float) -> void:
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > 0.55:
			continue
		var k: float = tg / 0.55
		var p: Vector2 = Vector2(_hasta.x + float(g["x"]) * _ancho, _hasta.y - _largo * 0.35) \
			- Vector2(0.0, float(g["sube"]) * k)
		BestiaAire._bola(capa, p, _ancho * 0.22 * float(g["tam"]) * (0.6 + 0.9 * k), Color(VAHO, fuerza * (1.0 - k)))


# EL VAPOR (agua sobre la arcilla cocida): una nube blanca gorda que sube y se abre.
func _vapor(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	for g in _piezas:
		var tg: float = _t - float(g["t0"]) * 0.6
		if tg < 0.0 or tg > 0.7:
			continue
		var k: float = tg / 0.7
		var p: Vector2 = Vector2(_hasta.x + float(g["x"]) * _ancho * (1.0 + k), _hasta.y - _largo * 0.1) \
			- Vector2(0.0, float(g["sube"]) * 1.3 * k)
		BestiaAire._bola(capa, p, _ancho * 0.35 * float(g["tam"]) * (0.6 + 1.0 * k), Color(Color.WHITE, 0.6 * (1.0 - k * k)))


# ------------------------------------------------------------
#  LOS QUE SE QUEDAN
# ------------------------------------------------------------
# DURO: cada poco, un hilo de vaho que le sale de los hombros (la arcilla aun caliente).
func _duro(capa: Node2D) -> void:
	if capa != _delante:
		return
	var ciclo: float = 1.3
	var q: float = _queda()
	for i in 2:
		var tc: float = fmod(_t + float(i) * ciclo * 0.5, ciclo)
		if tc > 0.8:
			continue
		var k: float = tc / 0.8
		var lado: float = -1.0 if i == 0 else 1.0
		var p: Vector2 = Vector2(_hasta.x + lado * _ancho * 0.28, _hasta.y - _largo * 0.3) - Vector2(-lado * 2.0, 14.0 * k)
		BestiaAire._bola(capa, p, _ancho * 0.12 * (0.7 + 0.8 * k), Color(VAHO, 0.4 * (1.0 - k) * q))


# BLANDO: gotas de barro que le caen de los costados al suelo, y el charquito bajo los pies (un circulo en el suelo,
# no una elipse: huellas-suelo-circulos) que crece un poco al llegar cada gota.
func _blando(capa: Node2D) -> void:
	var q: float = _queda()
	var aparece: float = clampf(_t / 0.3, 0.0, 1.0)
	if capa == _suelo:
		var r: float = _ancho * (0.42 + 0.03 * sin(_t * 3.0)) * aparece
		# Oscuro (sobre el suelo de la mazmorra, un barro claro se leia como un resplandor) y con un brillo de agua.
		BestiaAire._bola(capa, _pies, r * 1.2, Color(_borde, 0.85 * q))
		BestiaAire._bola(capa, _pies, r * 0.9, Color(_barro.darkened(0.55), 0.9 * q))
		BestiaAire._bola(capa, _pies + Vector2(-r * 0.3, -r * 0.15), r * 0.25, Color(_claro, 0.35 * q))
		return
	if capa != _delante:
		return
	var ciclo: float = 0.9
	for i in 3:
		var tc: float = fmod(_t + float(i) * 0.31, ciclo)
		var k: float = tc / 0.45
		if k > 1.0:
			continue
		var lado: float = [-0.24, 0.26, -0.06][i]   # de SU cuerpo (mas afuera colgaban en el aire)
		var x: float = _hasta.x + lado * _ancho
		var y0: float = _hasta.y - _largo * [0.05, 0.15, 0.3][i]
		var p: Vector2 = Vector2(x, lerpf(y0, _pies.y - 1.0, k * k))
		_terron(capa, p, 2.6, q * (1.0 - smoothstep(0.85, 1.0, k)))


# ------------------------------------------------------------
#  LA GARGOLA
# ------------------------------------------------------------
# LAS ESQUIRLAS que saltan de 'desde' (las del aplaston: alto, girando, y al llegar a los pies se paran y se apagan).
func _esquirlas(capa: CanvasItem, desde: Vector2, t: float, vida: float) -> void:
	for g in _piezas:
		var tg: float = t - float(g["t0"])
		if tg < 0.0 or tg > vida:
			continue
		var v: Vector2 = g["v"]
		var p: Vector2 = desde + v * tg + Vector2(0.0, 0.5 * GRAVEDAD * tg * tg)
		var suelo_y: float = _pies.y + 2.0 + float(g["tam"])
		var alfa: float = 1.0
		if p.y > suelo_y and v.y + GRAVEDAD * tg > 0.0:
			p.y = suelo_y
			alfa = 1.0 - clampf((tg - vida * 0.65) / (vida * 0.35), 0.0, 1.0)
		_piedra(capa, p, g["forma"], float(g["tam"]), float(g["gira"]) * minf(tg, 0.45), alfa)


# UN SURCO de garra: huso relleno de 'a' (arriba) a 'b' (abajo), GORDO en medio y afilado en las puntas, con su borde
# oscuro, la piedra y un filo claro del lado de la luz. 'u' = hasta donde ha bajado ya (0..1).
func _surco(capa: CanvasItem, a: Vector2, b: Vector2, grueso: float, u: float, alfa: float) -> void:
	if u <= 0.01 or alfa <= 0.01:
		return
	var n: int = 8
	var d: Vector2 = (b - a)
	var perp: Vector2 = d.normalized().orthogonal()
	var fuera_i := PackedVector2Array()
	var fuera_d := PackedVector2Array()
	var dentro_i := PackedVector2Array()
	var dentro_d := PackedVector2Array()
	for i in n + 1:
		var k: float = float(i) / float(n)
		var p: Vector2 = a + d * k * u
		# Mas gordo arriba de la mitad (donde entra la garra) y afilado al irse.
		var w: float = grueso * sin(PI * k) * (1.0 - 0.35 * k)
		fuera_i.append(p - perp * (w * 0.5 + 0.9))
		fuera_d.append(p + perp * (w * 0.5 + 0.9))
		dentro_i.append(p - perp * w * 0.5)
		dentro_d.append(p + perp * w * 0.5)
	BestiaAire._tira(capa, fuera_i, fuera_d, Color(_borde, alfa))
	BestiaAire._tira(capa, dentro_i, dentro_d, Color(_barro, alfa))
	# El filo claro: el tercio de un lado (el de la luz).
	var claro_i := PackedVector2Array()
	for i in n + 1:
		claro_i.append(dentro_i[i].lerp(dentro_d[i], 0.35))
	BestiaAire._tira(capa, dentro_i, claro_i, Color(_claro, alfa * 0.9))


func _surcos(capa: Node2D) -> void:
	var abajo := Vector2(0.0, 1.0).rotated(_incl)
	if capa == _delante:
		if _t < 0.0:
			return
		# Bajan de arriba abajo en 0,1 s (uno detras de otro, poco) y se quedan un momento antes de apagarse.
		# GORDOS Y CORTOS, pero que se lean: casi del alto de la figura y de un tercio de su ancho cada uno (a 0,42 del
		# alto y 3,5 px eran rasguños que no se veian).
		var largo: float = _largo * 0.8
		var grueso: float = clampf(_ancho * 0.42, 5.5, 9.0)
		var alfa: float = 1.0 - smoothstep(0.55, 1.0, _t / T_SURCOS)
		for i in 3:
			var off: float = (float(i) - 1.0) * _ancho * 0.36
			var tk: float = _t - float(i) * 0.025
			var u: float = clampf(tk / 0.1, 0.0, 1.0)
			var a: Vector2 = _imp + Vector2(off, 0.0) - abajo * largo * (0.55 - 0.08 * absf(float(i) - 1.0))
			_surco(capa, a, a + abajo * largo, grueso * (1.0 - 0.15 * absf(float(i) - 1.0)), u * (2.0 - u), alfa)
		_esquirlas(capa, _imp + abajo * largo * 0.35, _t - 0.06, 0.45)
		return
	if capa == _brillo and _t >= 0.0 and _t < 0.14:
		# Un fogonazo seco y frio donde entra la garra.
		var pulso: float = 1.0 - _t / 0.14
		BarridoAire.destello(capa, _imp - abajo * _largo * 0.2, 7.0 + 6.0 * pulso, Color(0.9, 0.95, 1.0, pulso), _incl)


# POLVO DE PIEDRA en los pies (le ha dejado lento): nubecillas grises que se levantan poco y se posan.
func _polvo(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0:
			continue
		var k: float = clampf(tg / (T_POLVO - 0.15), 0.0, 1.0)
		var p: Vector2 = _pies + Vector2(float(g["x"]) * _ancho * (1.0 + 0.5 * k), -float(g["sube"]) * sin(k * PI * 0.5))
		BestiaAire._bola(capa, p, _ancho * 0.2 * float(g["tam"]) * (0.7 + 0.6 * k), Color(POLVO_PIEDRA, 0.55 * (1.0 - k)))


# LA PIEL SE HACE PIEDRA (la Mirada petrea): de los pies a media pierna, una capa de basalto claro con su borde y el
# filo de arriba mellado, que SUBE en 0,25 s, se queda y se deshace en polvo al irse.
func _petrea(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var sube: float = clampf(_t / 0.25, 0.0, 1.0)
	sube = sube * (2.0 - sube)
	var alfa: float = 1.0 - smoothstep(0.7, 1.0, _t / T_PETREA)
	# Media pierna DE VERDAD: casi la mitad de la figura y un poco mas ancho que ella (a 0,32 x 0,3 eran motas en los pies).
	var alto: float = _largo * 0.46 * sube
	var mitad: float = _ancho * 0.62
	if capa == _delante:
		if alto < 1.0:
			return
		# El contorno: de un pie al otro por abajo y el filo de arriba mellado.
		var n: int = 7
		var fuera := PackedVector2Array()
		var dentro := PackedVector2Array()
		for i in n + 1:
			var k: float = float(i) / float(n)
			var x: float = lerpf(-mitad, mitad, k)
			var mella: float = (0.12 + 0.12 * sin(float(i) * 2.7 + 1.3)) * alto
			fuera.append(_pies + Vector2(x, -alto + mella))
			dentro.append(_pies + Vector2(x, 1.5))
		var borde_f := PackedVector2Array()
		var borde_d := PackedVector2Array()
		for i in n + 1:
			var k2: float = float(i) / float(n) * 2.0 - 1.0
			borde_f.append(fuera[i] + Vector2(k2 * 1.2, -1.1))
			borde_d.append(dentro[i] + Vector2(k2 * 1.2, 0.8))
		BestiaAire._tira(capa, borde_f, borde_d, Color(_borde, 0.95 * alfa))
		BestiaAire._tira(capa, fuera, dentro, Color(_claro.lerp(_barro, 0.35), 0.95 * alfa))
		# Las caras de la piedra: facetas mas oscuras (sin rayas).
		for i in 3:
			var cx: float = lerpf(-mitad * 0.6, mitad * 0.6, float(i) / 2.0)
			var c: Vector2 = _pies + Vector2(cx, -alto * 0.35)
			var h: float = alto * 0.3
			var w: float = mitad * 0.28
			Poligono.relleno(capa, PackedVector2Array([c + Vector2(-w, 0.0), c + Vector2(0.0, -h),
				c + Vector2(w * 1.1, 0.2), c + Vector2(0.3, h * 0.6)]), Color(_barro, 0.8 * alfa))
		return
	if capa == _suelo and _t > T_PETREA * 0.7:
		_polvo_de(capa, (_t - T_PETREA * 0.7) / (T_PETREA * 0.3))


func _polvo_de(capa: CanvasItem, k: float) -> void:
	for g in _piezas:
		var p: Vector2 = _pies + Vector2(float(g["x"]) * _ancho * (1.0 + 0.4 * k), -float(g["sube"]) * 0.5 * k)
		BestiaAire._bola(capa, p, _ancho * 0.18 * float(g["tam"]) * (0.8 + 0.5 * k), Color(POLVO_PIEDRA, 0.45 * (1.0 - k)))


# LE PEGAN POSADA (es piedra, recibe la mitad): destello SECO (corto, frio), chispas que saltan hacia quien pega y
# lascas de piedra.
func _estatua(capa: Node2D) -> void:
	if _t < 0.0:
		return
	if capa == _brillo:
		if _t < 0.09:
			var pulso: float = 1.0 - _t / 0.09
			BarridoAire.destello(capa, _imp, 8.0 + 4.0 * pulso, Color(1.0, 1.0, 1.0, pulso), 0.35)
		# Las chispas: cometas cortas y gordas, amarillo blanco, rapidas.
		var k: float = clampf(_t / 0.22, 0.0, 1.0)
		if k >= 1.0:
			return
		for i in 5:
			var ang: float = (-_eje).angle() + (float(i) - 2.0) * 0.45 + sin(float(i) * 4.1) * 0.15
			var d := Vector2(cos(ang), sin(ang) * K - 0.35).normalized()
			var cab: Vector2 = _imp + d * (4.0 + 22.0 * k) + Vector2(0.0, 30.0 * k * k)
			BarridoAire.cometa(capa, cab - d * 10.0 * (1.0 - k * 0.5), cab, 3.0, Color(1.0, 0.9, 0.6, 1.0 - k))
		return
	if capa == _delante:
		_esquirlas(capa, _imp, _t, 0.35)


# DEJA DE SER ESTATUA: se le sueltan trocitos del cuerpo que caen a sus pies, y un poco de polvo al llegar.
func _despereza(capa: Node2D) -> void:
	if _t < 0.0:
		return
	if capa == _delante:
		for g in _piezas:
			var tg: float = _t - float(g["t0"])
			if tg < 0.0:
				continue
			var p0: Vector2 = Vector2(_hasta.x + float(g["x"]) * _ancho, _hasta.y + float(g["y"]) * _largo)
			var v: Vector2 = g["v"]
			var p: Vector2 = p0 + v * tg + Vector2(0.0, 0.5 * GRAVEDAD * tg * tg)
			var alfa: float = 1.0
			if p.y > _pies.y + 1.0:
				p.y = _pies.y + 1.0
				alfa = 1.0 - clampf((_t - 0.5) / 0.3, 0.0, 1.0)
			_piedra(capa, p, g["forma"], float(g["tam"]) * 0.8, float(g["gira"]) * minf(tg, 0.4), alfa)
		return
	if capa == _suelo and _t > 0.2:
		var k: float = clampf((_t - 0.2) / 0.6, 0.0, 1.0)
		for i in 4:
			var lado: float = -1.0 if i % 2 == 0 else 1.0
			BestiaAire._bola(capa, _pies + Vector2(lado * _ancho * (0.25 + 0.3 * float(i / 2) + 0.3 * k), -2.0 * k),
				_ancho * (0.18 + 0.15 * k), Color(POLVO_PIEDRA, 0.4 * (1.0 - k)))


# ------------------------------------------------------------
#  POR EL SUELO: LA ONDA DE LA MIRADA PETREA (SueloRoto.Tipo.CONSTRUCTO_PETREA)
# ------------------------------------------------------------
var _o: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _banda: float = 0.7

static func area(padre: Node, f: CombatFormas.Forma, semilla: int, espera: float) -> ConstructoAire:
	if padre == null or f == null:
		return null
	var e := ConstructoAire.new()
	e.modo = Modo.CONO
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	e._tonos(BASALTO, true)
	e._o = f.origen
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	e._largo = maxf(f.radio, 8.0)
	e._banda = deg_to_rad(f.apertura if f.apertura > 0.0 else 40.0)
	# Las lascas que va levantando el frente: en que tramo del cono (u), a que lado (s) y cuanto saltan.
	for i in 14:
		var q: Dictionary = _esquirla(e._rng, Vector2.ZERO, 0.35)
		q["u"] = e._rng.randf_range(0.15, 0.95)
		q["s"] = e._rng.randf_range(-0.85, 0.85)
		e._piezas.append(q)
	padre.add_child(e)
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	e._t = -maxf(espera, 0.0) * e._ritmo
	return e


# CUANDO LE LLEGA el frente a 'p' (lo mismo que se dibuja).
static func retraso(f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	var u: float = clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0)
	return (1.0 - sqrt(1.0 - u)) * T_CONO


func _en_cono(u: float, s: float) -> Vector2:
	var a: float = _dir.angle() + s * _banda * 0.5
	return _o + Vector2(cos(a), sin(a)) * (_largo * u)


# LA ONDA: sus ojos claros se encienden (alto, sobre donde nace el cono) y por el cono avanza un FRENTE de piedra gris,
# relleno y gordo, con el filo claro delante y el borde oscuro detras; el suelo por donde pasa se queda gris un momento
# y salta alguna lasca.
func _cono(capa: Node2D) -> void:
	if _t < 0.0:
		return
	# SUS OJOS: en su cabeza, arriba y detras de donde nace el cono (a -14 salia en el pecho).
	# De lado (E/O) el frente del cono esta a la altura de los pies y la cabeza queda mas arriba que hacia N/S.
	var ojo: Vector2 = _o - _dir * 10.0 - Vector2(0.0, 27.0 + 14.0 * (1.0 - absf(_dir.y)))
	var k: float = clampf(_t / T_CONO, 0.0, 1.0)
	var r: float = _largo * (1.0 - (1.0 - k) * (1.0 - k))
	var apaga: float = clampf((_t - T_CONO) / 0.35, 0.0, 1.0)
	var mitad: float = _banda * 0.5
	var n: int = 14
	if capa == _brillo:
		if _t < 0.3:
			var ke: float = _t / 0.3
			BarridoAire.destello(capa, ojo, 6.0 + 5.0 * sin(PI * ke), Color(OJO_CLARO, 0.9 * (1.0 - ke)), 0.0)
		return
	if capa == _suelo:
		# El suelo PETRIFICADO por detras del frente: gris, que se apaga al final.
		var fuera := PackedVector2Array()
		var dentro := PackedVector2Array()
		for i in n + 1:
			var s: float = float(i) / float(n) * 2.0 - 1.0
			var a: float = _dir.angle() + s * mitad
			fuera.append(_o + Vector2(cos(a), sin(a)) * r)
			dentro.append(_o + Vector2(cos(a), sin(a)) * 4.0)
		BestiaAire._tira(capa, fuera, dentro, Color(_barro, 0.35 * (1.0 - apaga)))
		return
	if capa != _delante or apaga >= 1.0:
		return
	var alfa: float = 1.0 - apaga
	# EL FRENTE: una banda de piedra gorda a lo ancho del cono, con el borde oscuro detras y el filo claro delante.
	# GORDO (a 5-10 px se leia como una raya en arco): un frente de piedra con cuerpo.
	var grueso: float = lerpf(11.0, 18.0, k)
	var borde_f := PackedVector2Array()
	var borde_d := PackedVector2Array()
	var cara_f := PackedVector2Array()
	var cara_d := PackedVector2Array()
	var filo := PackedVector2Array()
	for i in n + 1:
		var s2: float = float(i) / float(n) * 2.0 - 1.0
		var a2: float = _dir.angle() + s2 * mitad
		var d := Vector2(cos(a2), sin(a2))
		var w: float = grueso * (1.0 - 0.55 * s2 * s2) * (0.85 + 0.3 * sin(float(i) * 2.3 + 0.7))
		borde_f.append(_o + d * (r + 1.0))
		borde_d.append(_o + d * maxf(r - w - 1.2, 0.0))
		cara_f.append(_o + d * r)
		cara_d.append(_o + d * maxf(r - w, 0.0))
		filo.append(_o + d * maxf(r - w * 0.3, 0.0))
	BestiaAire._tira(capa, borde_f, borde_d, Color(_borde, 0.9 * alfa))
	BestiaAire._tira(capa, cara_f, cara_d, Color(_barro, 0.95 * alfa))
	BestiaAire._tira(capa, cara_f, filo, Color(_claro, 0.95 * alfa))
	# LAS LASCAS: al pasarles el frente saltan un poco y caen.
	for g in _piezas:
		var t_llega: float = (1.0 - sqrt(1.0 - float(g["u"]))) * T_CONO
		var tg: float = _t - t_llega
		if tg < 0.0 or tg > 0.4:
			continue
		var base: Vector2 = _en_cono(float(g["u"]), float(g["s"]))
		var v: Vector2 = g["v"]
		var p: Vector2 = base + Vector2(v.x * 0.4, v.y) * tg + Vector2(0.0, 0.5 * GRAVEDAD * tg * tg)
		if p.y > base.y:
			p.y = base.y
		_piedra(capa, p, g["forma"], float(g["tam"]) * 0.8, float(g["gira"]) * tg,
			1.0 - clampf((tg - 0.25) / 0.15, 0.0, 1.0))


# ------------------------------------------------------------
#  EL COLOSO (30/09, paso 2, en su granito)
# ------------------------------------------------------------
# LOS SILLARES de la Muralla: bloques de granito con su borde, la cara y la tapa clara, que BROTAN del suelo (crecen
# hacia arriba), se quedan y se hunden. Medio anillo delante de el (en _delante) y el otro medio detras (en _suelo,
# bajo los cuerpos).
func _sillar(capa: CanvasItem, base: Vector2, ancho: float, alto: float, alfa: float) -> void:
	if alto < 0.8 or alfa <= 0.01:
		return
	var w: float = ancho * 0.5
	capa.draw_rect(Rect2(base + Vector2(-w - 1.0, -alto - 1.0), Vector2(ancho + 2.0, alto + 2.0)), Color(_borde, alfa))
	capa.draw_rect(Rect2(base + Vector2(-w, -alto), Vector2(ancho, alto)), Color(_barro, alfa))
	capa.draw_rect(Rect2(base + Vector2(-w, -alto), Vector2(ancho, minf(alto, ancho * 0.35))), Color(_claro, alfa))
	# La junta azul de la runa, a media altura (lo que lo mantiene de una pieza).
	if alto > 5.0:
		capa.draw_rect(Rect2(base + Vector2(-w * 0.5, -alto * 0.55), Vector2(w, 1.4)), Color(RUNA, alfa * 0.9))


func _muralla(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var sube: float = clampf(_t / 0.18, 0.0, 1.0)
	sube = sube * (2.0 - sube)
	var baja: float = clampf((_t - (T_MURALLA - 0.35)) / 0.35, 0.0, 1.0)
	var alto_k: float = sube * (1.0 - baja)
	if capa == _brillo:
		# EL PULSO DE LAS RUNAS: una luz azul fria que le sube de los pies a la cabeza.
		var u: float = clampf(_t / 0.45, 0.0, 1.0)
		if u < 1.0:
			var c: Vector2 = Vector2(_hasta.x, lerpf(_pies.y - 4.0, _hasta.y - _largo * 0.45, u))
			# Una banda que SUBE (a lo ancho de medio cuerpo), no un fogonazo que lo blanquea entero.
			BestiaAire._bola(capa, c, _ancho * 0.22, Color(RUNA, 0.45 * sin(u * PI)))
			BarridoAire.brillo(capa, c, _ancho * 0.35, Color(RUNA, 0.12 * sin(u * PI)))
		return
	for g in _piezas:
		var delante: bool = float(g["y"]) > 0.0
		if (capa == _delante) != delante or (capa != _delante and capa != _suelo):
			continue
		var tg: float = clampf((_t - float(g["t0"])) / 0.18, 0.0, 1.0)
		var base: Vector2 = _pies + Vector2(float(g["x"]), float(g["y"])) * _ancho
		_sillar(capa, base, float(g["w"]), float(g["h"]) * alto_k * tg * (2.0 - tg), 1.0)
	# El polvo al brotar.
	if capa == _suelo and _t < 0.5:
		var kp: float = _t / 0.5
		for g in _piezas:
			var base2: Vector2 = _pies + Vector2(float(g["x"]), float(g["y"])) * _ancho
			BestiaAire._bola(capa, base2, float(g["w"]) * (0.5 + 0.6 * kp), Color(POLVO_PIEDRA, 0.4 * (1.0 - kp)))


# CLAVADO (Imparable): intentan moverlo y no se mueve: grietas cortas bajo sus pies y polvo que sale a ras de suelo.
func _clavado(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var k: float = clampf(_t / 0.2, 0.0, 1.0)
	var alfa: float = 1.0 - smoothstep(0.55, 1.0, _t / T_CLAVADO)
	if capa == _suelo:
		for g in _piezas:
			var a: float = float(g["a"])
			var d := Vector2(cos(a), sin(a))
			_grieta(capa, _pies, d, _ancho * float(g["l"]) * 0.6 * k, 3.0, alfa)
		return
	if capa == _delante:
		var kp: float = clampf(_t / T_CLAVADO, 0.0, 1.0)
		for i in 4:
			var lado: float = -1.0 if i % 2 == 0 else 1.0
			BestiaAire._bola(capa, _pies + Vector2(lado * _ancho * (0.3 + 0.25 * float(i / 2) + 0.35 * kp), 1.0 - 3.0 * kp),
				_ancho * (0.08 + 0.08 * kp), Color(POLVO_PIEDRA, 0.5 * (1.0 - kp)))


# UNA GRIETA: cuña oscura rellena que se afila al irse (sin rayas), con el borde algo mas claro.
func _grieta(capa: CanvasItem, o: Vector2, d: Vector2, largo: float, grueso: float, alfa: float) -> void:
	if largo < 1.0 or alfa <= 0.01:
		return
	var n: Vector2 = d.orthogonal()
	var codo: Vector2 = o + d * largo * 0.5 + n * largo * 0.12
	var fin: Vector2 = o + d * largo
	Poligono.relleno(capa, PackedVector2Array([o + n * grueso, codo + n * grueso * 0.6, fin, codo - n * grueso * 0.6,
		o - n * grueso]), Color(_borde.darkened(0.3), alfa))


# ------------------------------------------------------------
#  POR EL SUELO: EL PISOTON SISMICO (SueloRoto.Tipo.CONSTRUCTO_SISMO)
# ------------------------------------------------------------
# TRES ANILLOS DE LOSAS que se levantan uno detras de otro desde el pie (el de dentro el mas gordo: cerca pega mas, sus
# tramos), grietas que corren desde el pie hasta el borde y polvo en el borde al final.
static func area_sismo(padre: Node, f: CombatFormas.Forma, semilla: int, espera: float) -> ConstructoAire:
	if padre == null or f == null:
		return null
	var e := ConstructoAire.new()
	e.modo = Modo.SISMO_SUELO
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	e._tonos(GRANITO, true)
	e._o = f.centro
	e._largo = maxf(f.radio, 8.0)
	# Las losas: por anillo, a su radio, cada una con su forma (4-5 lados), su tamaño (menguando hacia fuera) y lo que
	# se levanta.
	for anillo in 3:
		var r: float = e._largo * (float(anillo) + 0.55) / 3.0
		var n_l: int = 8 + anillo * 5
		# GORDAS (a 7-3,6 px eran motas): la de dentro casi como un pie suyo.
		var tam: float = lerpf(15.0, 8.0, float(anillo) / 2.0)
		for i in n_l:
			var a: float = TAU * (float(i) + e._rng.randf_range(-0.3, 0.3)) / float(n_l)
			var q: Dictionary = _esquirla(e._rng, Vector2.ZERO, 0.0)
			# En CIRCULO, como su huella (huellas-suelo-circulos: nada de elipses).
			q["p"] = Vector2(cos(a), sin(a)) * r * e._rng.randf_range(0.92, 1.06)
			q["tam"] = tam * e._rng.randf_range(0.8, 1.15)
			q["anillo"] = anillo
			q["alza"] = tam * e._rng.randf_range(0.6, 1.0)
			e._piezas.append(q)
	# Las grietas: 7 radios desde el pie hasta el borde.
	for i in 7:
		e._radios_sismo.append({"a": TAU * (float(i) + e._rng.randf_range(-0.3, 0.3)) / 7.0, "l": e._rng.randf_range(0.75, 1.0)})
	padre.add_child(e)
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._t = -maxf(espera, 0.0) * e._ritmo
	return e


var _radios_sismo: Array = []

# CUANDO LE LLEGA a 'p' (cada anillo, a su tiempo).
static func retraso_sismo(f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	var u: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
	return u * T_SISMO


func _sismo_suelo(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var apaga: float = clampf((_t - (T_SISMO + 0.45)) / 0.3, 0.0, 1.0)
	var alfa: float = 1.0 - apaga
	if capa == _suelo:
		# LAS GRIETAS corren del pie al borde en lo que tarda el frente.
		var k: float = clampf(_t / T_SISMO, 0.0, 1.0)
		for g in _radios_sismo:
			var a: float = float(g["a"])
			_grieta(capa, _o, Vector2(cos(a), sin(a)), _largo * float(g["l"]) * k, 4.0, alfa)
		# El polvo del borde, al llegar el frente.
		if _t > T_SISMO * 0.8:
			var kp: float = clampf((_t - T_SISMO * 0.8) / 0.5, 0.0, 1.0)
			for i in 10:
				var a2: float = TAU * float(i) / 10.0
				BestiaAire._bola(capa, _o + Vector2(cos(a2), sin(a2)) * _largo * (0.95 + 0.1 * kp),
					8.0 * (0.6 + 0.7 * kp), Color(POLVO_PIEDRA, 0.4 * (1.0 - kp)))
	if capa != _suelo:
		return
	# LAS LOSAS, en la capa del suelo (bajo los cuerpos: encima tapaban sus piernas): cada anillo salta cuando le llega el
	# frente (los de dentro antes), sube, cae y se queda un momento.
	for g in _piezas:
		var t_llega: float = (float(g["anillo"]) + 0.55) / 3.0 * T_SISMO
		var tg: float = _t - t_llega
		if tg < 0.0:
			continue
		var salto: float = clampf(tg / 0.22, 0.0, 1.0)
		var h: float = float(g["alza"]) * sin(salto * PI) + float(g["alza"]) * 0.25 * (1.0 - salto)
		var p: Vector2 = _o + Vector2(g["p"]) - Vector2(0.0, h * (1.0 - apaga))
		_losa(capa, p, g["forma"], float(g["tam"]), float(g["gira"]) * 0.03 * salto, alfa)


# UNA LOSA de suelo: como la piedrecilla, pero con la cara de arriba CLARA (es una placa levantada, no una piedra suelta).
func _losa(ci: CanvasItem, p: Vector2, forma_l: PackedVector2Array, tam: float, giro: float, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var fuera := PackedVector2Array()
	var cara := PackedVector2Array()
	var tapa := PackedVector2Array()
	for q in forma_l:
		var r: Vector2 = q.rotated(giro)
		fuera.append(p + Vector2(r.x, r.y * 0.7) * (tam + 1.0) + Vector2(0.0, 1.5))
		cara.append(p + Vector2(r.x, r.y * 0.7) * tam + Vector2(0.0, 1.5))
		tapa.append(p + Vector2(r.x, r.y * 0.7) * tam * 0.85)
	Poligono.relleno(ci, fuera, Color(_borde, alfa))
	Poligono.relleno(ci, cara, Color(_barro.darkened(0.25), alfa))
	# La tapa CLARA: sobre el suelo oscuro de la mazmorra, una losa gris medio no se distinguia.
	Poligono.relleno(ci, tapa, Color(_claro, alfa))
