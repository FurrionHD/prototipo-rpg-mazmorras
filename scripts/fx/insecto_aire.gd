# ============================================================
#  insecto_aire.gd
#  LOS EFECTOS DE LOS INSECTOIDES en el mapa (29/09/2026): araña, escarabajo, ciempies y segadora, uno a uno y con
#  su visto bueno (ver la memoria insectoides-tactico). Aparte de BestiaAire para no engordarlo mas; usa sus piezas
#  estaticas (_tira, _poligono, _bola). Empieza por la ARAÑA:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.INSECTO_*):
#    QUELICEROS  el basico: el EFECTO de un mordisco (no se dibujan colmillos: los enseña la araña en su sprite), dos
#                medias lunas que entran desde los lados y se cierran sobre el cuerpo. A escala de la araña.
#    PONZONA     el Mordisco ponzoñoso: lo mismo en verde y goteando.
#    VENENO      (lo pone CombatTactico._on_impacto, SOLO SI ENTRA) gotitas verdes que saltan de donde muerde y una
#                mancha verde que se apaga.
#    HEBRAS      a los que pilla la Telaraña al caer: unas hebras pegadas del suelo a sus piernas, un momento.
#  POR EL SUELO (SueloRoto.Tipo.INSECTO_*, ver Suelo):
#    TELARANA    el ovillo de seda que sale de la araña, vuela en parabola abriendose y revienta en hebras al caer
#                (la red que se queda la pinta RED, aparte).
#  SE QUEDA:
#    RED         la telaraña tendida en el suelo los turnos de la araña: radios y espiral, rocio; cada turno mas rota
#                y deshilachada, y encoge (como el charco de savia, CombatTactico._charco_visible).
#  EL ESCARABAJO (29/09): el gesto lo hace SU CUERPO (EscarabajoSprites: se hace bola y rueda de verdad, se cierra
#  en el Caparazon) y aqui solo va lo que cae sobre los demas:
#    PALA        el basico: un golpe CHATO y ancho (la pala empuja, no corta): una media luna gruesa y aplastada
#                cruzada a la linea del golpe que se hunde en el cuerpo, destello de metal y chispas.
#    ARROLLA     la Embestida rodante en CADA uno que atraviesa, cuando la bola le pasa por encima (el suelo lo
#                retrasa: ver RODADA): el frente redondo de la bola que le cruza, destello y chispas a los lados.
#    CAPARAZON   sobre el mismo, al cerrarse del todo: un reflejo que barre el lomo de punta a punta y un anillo de
#                polvo a ras del suelo.
#    RODADA      (suelo) la banda de tierra aplastada que deja la bola detras, con su labio a los lados, y el polvo
#                que se levanta a su paso.
#  EL CIEMPIES (29/09), igual: el gesto es de su cuerpo (CiempiesSprites) y aqui lo que cae sobre la victima:
#    FORCIPULAS  el basico: dos ganchos finos que entran desde los lados y SE CRUZAN como una tijera.
#    PATITAS     cada picotazo de la Oleada de patas: 6-8 patitas que se clavan escalonadas de arriba abajo.
#    APRETON     el Enrosque (al enroscarse y en cada turno suyo): dos medias lunas que aprietan a la presa por los
#                lados a la altura de la cintura y un destello rojo apagado. Enroscado lo pinta su SPRITE (dos
#                mitades a los pies de la presa: CombatTactico._tick_vis_enrosque) y la presa tiembla.
#  LAS HEBRAS NO SON LINEAS (lo aprobo el usuario, 29/09): cada una es un hilo relleno que se afila, mas grueso junto a
#  los nudos, con un halo suave detras. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name InsectoAire

enum Modo { TELARANA, QUELICEROS, PONZONA, VENENO, HEBRAS, RED, PALA, ARROLLA, CAPARAZON, RODADA,
	FORCIPULAS, PATITAS, APRETON }
# Los del suelo, en el orden de SueloRoto.Tipo.INSECTO_*: no reordenar (el Modo si se puede).
enum Suelo { TELARANA, RODADA }
const _MODO_DE_SUELO := [Modo.TELARANA, Modo.RODADA]

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const T_CLAVADO := 0.2            # lo que se quedan los colmillos clavados antes de salir
const T_IRSE := 0.16
const T_TELA_CAE := 0.4           # lo que vuela el ovillo hasta el suelo
const T_SECA := 0.5               # lo que tarda en irse la red al secarse
const T_VENENO := 0.8
const T_HEBRAS := 1.4
const ABD_ATRAS := 7.0            # la punta del abdomen levantado de la araña, desde sus pies (px)
const ABD_ALTO := 20.0
# LO QUE TARDA LA BOLA EN CRUZAR SU LINEA: los marcos que rueda a su ritmo (EscarabajoSprites.RODAR_MARCOS /
# RODAR_FPS). Con ello va el cuerpo por la linea (CombatTactico.mover_enemigo) y le llega el golpe a cada uno.
const T_RODADA := 8.0 / 18.0
const T_PALA := 0.2               # lo que dura el aplaston del basico tras el golpe
const T_ARROLLA := 0.4
const T_CAPARAZON := 0.7
const HIERRO := Color(0.3, 0.42, 0.34)
const HIERRO_FILO := Color(0.9, 0.97, 0.95)
const CHISPA := Color(1.0, 0.86, 0.5)
const TIERRA := Color(0.2, 0.16, 0.12)
const QUITINA := Color(0.12, 0.08, 0.17)
const QUITINA_CLARA := Color(0.6, 0.5, 0.78)
const SEDA := Color(0.95, 0.95, 0.99)
const SEDA_SOMBRA := Color(0.22, 0.2, 0.28)
const VENENO := Color(0.46, 0.84, 0.22)
const VENENO_OSCURO := Color(0.12, 0.34, 0.08)
const VENENO_CLARO := Color(0.82, 1.0, 0.56)

var modo: int = Modo.QUELICEROS
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _hasta: Vector2 = Vector2.ZERO
var _eje: Vector2 = Vector2.RIGHT     # hacia donde muerde (de quien muerde a quien recibe), ya variado
var _lado: Vector2 = Vector2.DOWN     # a lo ancho de la boca: los dos colmillos, uno a cada lado
var _tam: float = 8.0
var _viaje: float = 0.14
var _ancho: float = 14.0
var _largo: float = 26.0
var _o: Vector2 = Vector2.ZERO
var _r: float = 25.0
var _dir: Vector2 = Vector2.RIGHT
var _lejos: float = 60.0              # TELARANA: lo lejos que esta la araña (f.ancho, ver CombatTactico.desde_quien_lanza)
var queda: float = 1.0                # RED: lo que le queda (1 = recien tendida); se rompe y encoge con ello
var _secando: float = -1.0            # RED: desde cuando se esta yendo (-1 = sigue)
var _piezas: Array = []               # gotas (VENENO), hebras (HEBRAS), pelusas (TELARANA)
var _radios: Array = []               # RED: {a, lob, vida}
var _anillos: Array = []              # RED: {f, vidas: [..]} (un tramo por hueco entre radios)
var _rocio: Array = []                # RED: {i, j, fase}
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null
var _peso: float = 1.0                # ARROLLA: el primero que atraviesa, entero; los de detras, menos


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, s: int, semilla: int, espera: float) -> Node2D:
	if padre == null or f == null or s < 0 or s >= _MODO_DE_SUELO.size():
		return null
	var e := InsectoAire.new()
	e.modo = int(_MODO_DE_SUELO[s])
	e.forma = f
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._o = f.centro
	e._r = maxf(f.radio, 8.0)
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	e._lejos = f.ancho if f.ancho > 8.0 else 60.0
	if e.modo == Modo.RODADA:
		e._o = SueloRoto.origen_de(f)
		e._largo = maxf(f.largo, 4.0)
		e._ancho = maxf(f.ancho, 8.0)
		# El borde de la banda, un poco irregular: un surco perfecto parece pintado con regla.
		var n: int = int(clampf(e._largo / 4.0, 8.0, 40.0))
		for i in n + 1:
			e._radios.append({"u": float(i) / float(n), "i": e._rng.randf_range(-0.08, 0.08),
				"d": e._rng.randf_range(-0.08, 0.08)})
		# Las bocanadas de polvo por la linea, que se levantan al paso de la bola, a los dos lados.
		for i in int(clampf(e._largo / 6.0, 6.0, 18.0)):
			e._piezas.append({"u": e._rng.randf_range(0.04, 0.98), "lado": -1.0 if i % 2 == 0 else 1.0,
				"sube": e._rng.randf_range(3.0, 7.0), "tam": e._rng.randf_range(0.3, 0.5), "sale": e._rng.randf_range(0.2, 0.6)})
		# Y unos terrones que salen despedidos a los lados.
		for i in int(clampf(e._largo / 12.0, 4.0, 9.0)):
			e._anillos.append({"u": e._rng.randf_range(0.05, 0.95), "lado": -1.0 if i % 2 == 0 else 1.0,
				"v": e._rng.randf_range(12.0, 24.0), "sube": e._rng.randf_range(8.0, 15.0), "tam": e._rng.randf_range(1.2, 2.0)})
		e._suelo = e._capa(SueloRoto.Z_SUELO, false)
		e._delante = e._capa(Z_ENCIMA, false)
		return e
	# Las pelusas de seda que saltan al reventar el ovillo.
	for i in 10:
		e._piezas.append({"a": TAU * (float(i) + e._rng.randf_range(0.0, 0.8)) / 10.0,
			"v": e._rng.randf_range(0.35, 0.8) * e._r, "sube": e._rng.randf_range(4.0, 10.0),
			"tam": e._rng.randf_range(1.0, 1.8)})
	e._delante = e._capa(Z_ENCIMA, false)
	return e


static func retraso(s: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	# LA BOLA le llega a cada uno cuando pasa por donde esta.
	if s == Suelo.RODADA:
		return clampf((p - f.origen).dot(f.dir.normalized()) / maxf(f.largo, 1.0), 0.0, 1.0) * T_RODADA
	return T_TELA_CAE


static func t_salir(s: int) -> float:
	return T_RODADA if s == Suelo.RODADA else T_TELA_CAE


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = de donde viene (quien muerde), 'caja' = el cuerpo que lo recibe, 'espera' = lo que falta para el golpe
# (los colmillos se clavan justo en el), 'boca' = el ancho del dibujo de quien muerde (van a SU escala).
# 'peso' (ARROLLA): la fraccion del golpe que se lleva (CombatFX: 1 el primero, menos los de detras).
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, semilla: int, espera: float,
		ritmo: float, boca: float = -1.0, peso: float = 1.0) -> InsectoAire:
	if padre == null:
		return null
	var e := InsectoAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._ancho = maxf(caja.size.x, 8.0)
	e._largo = maxf(caja.size.y, 10.0)
	e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.18, 0.18) * caja.size.x,
		e._rng.randf_range(-0.2, 0.1) * caja.size.y)
	var eje: Vector2 = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	match m:
		Modo.QUELICEROS, Modo.PONZONA:
			e._viaje = clampf(espera, 0.08, 0.2)
			e._t = -e._viaje
			# Cada mordisco con su variacion: la boca un poco girada sobre la linea del golpe.
			e._eje = eje.rotated(e._rng.randf_range(-0.28, 0.28))
			e._lado = e._eje.orthogonal()
			var de_quien: float = boca if boca > 0.0 else e._ancho
			e._tam = maxf(de_quien * 0.2, 4.0) * (1.12 if m == Modo.PONZONA else 1.0)
		Modo.VENENO:
			e._t = -maxf(espera, 0.0)
			e._eje = eje
			e._tam = maxf(e._ancho * 0.35, 4.0)
			# Las gotas salen hacia el lado contrario de quien muerde, abiertas en abanico.
			for i in 8:
				e._piezas.append({"d": eje.rotated(e._rng.randf_range(-1.3, 1.3)), "v": e._rng.randf_range(10.0, 20.0),
					"sube": e._rng.randf_range(5.0, 11.0), "tam": e._rng.randf_range(0.9, 1.6)})
		Modo.PALA:
			# La pala llega desde el escarabajo y se aplasta EN el golpe. A su escala (la pala es suya).
			e._viaje = clampf(espera, 0.06, 0.14)
			e._t = -e._viaje
			e._eje = eje.rotated(e._rng.randf_range(-0.22, 0.22))
			e._lado = e._eje.orthogonal()
			e._tam = maxf((boca if boca > 0.0 else e._ancho) * 0.36, 6.0) * e._rng.randf_range(0.92, 1.08)
			# Las chispas saltan hacia donde empuja, abiertas: el hierro que rasca.
			for i in 3:
				e._piezas.append({"d": e._eje.rotated(e._rng.randf_range(-1.1, 1.1)), "v": e._rng.randf_range(10.0, 18.0),
					"t0": e._rng.randf_range(0.0, 0.04)})
		Modo.ARROLLA:
			# Sale EN el golpe: es la bola que ya le esta pasando por encima.
			e._t = -maxf(espera, 0.0)
			e._peso = clampf(peso, 0.4, 1.0)
			e._eje = eje
			e._lado = eje.orthogonal()
			e._tam = maxf((boca if boca > 0.0 else e._ancho) * 0.34, 5.0) * lerpf(0.7, 1.0, e._peso)
			# Chispas A LOS LADOS: la bola pasa por encima y sigue, no rebota. Un poco hacia donde va.
			for i in int(round(lerpf(4.0, 7.0, e._peso))):
				var s: float = -1.0 if i % 2 == 0 else 1.0
				e._piezas.append({"d": (e._lado * s).rotated(-s * e._rng.randf_range(0.15, 0.7)),
					"v": e._rng.randf_range(14.0, 26.0) * lerpf(0.7, 1.0, e._peso), "t0": e._rng.randf_range(0.0, 0.05)})
		Modo.FORCIPULAS:
			e._viaje = clampf(espera, 0.08, 0.2)
			e._t = -e._viaje
			e._eje = eje.rotated(e._rng.randf_range(-0.3, 0.3))
			e._lado = e._eje.orthogonal()
			# A la escala de un ciempies GRANDE: con 0,2 salian dos rayitas.
			e._tam = maxf((boca if boca > 0.0 else e._ancho) * 0.32, 7.0)
		Modo.PATITAS:
			# Escalonadas de arriba abajo en 0,1 s; del lado de quien pica sobre todo, alguna del otro.
			e._t = -maxf(espera, 0.0)
			e._eje = eje
			e._tam = maxf(e._ancho * 0.5, 7.0)
			var n: int = e._rng.randi_range(6, 8)
			for i in n:
				var h: float = float(i) / float(n - 1)
				var lado_p: float = -1.0 if e._rng.randf() < 0.75 else 1.0
				var sitio: Vector2 = caja.get_center() + Vector2(e._rng.randf_range(-0.3, 0.3) * caja.size.x,
					lerpf(-0.38, 0.4, h) * caja.size.y)
				var d: Vector2 = (eje * 0.8 + Vector2(-lado_p * eje.y, lado_p * eje.x) * 0.35 * e._rng.randf_range(0.3, 1.0)
					+ Vector2(0.0, 0.25)).normalized()
				e._piezas.append({"p": sitio, "d": d, "t0": h * 0.1 + e._rng.randf_range(-0.01, 0.01),
					"gota": e._rng.randf() < 0.4})
		Modo.APRETON:
			e._t = -maxf(espera, 0.0)
			e._hasta = caja.get_center() + Vector2(0.0, caja.size.y * 0.12)
		Modo.CAPARAZON:
			# Sobre SU cuerpo: la caja es la suya. Sale al cerrarse del todo (el golpe).
			e._t = -maxf(espera, 0.0)
			e._hasta = caja.get_center()
			e._tam = e._rng.randf_range(-0.12, 0.12)   # lo que se ladea el reflejo
			for i in 12:
				e._piezas.append({"a": TAU * (float(i) + e._rng.randf_range(0.0, 0.7)) / 12.0,
					"u": e._rng.randf_range(0.85, 1.1), "sube": e._rng.randf_range(1.5, 4.0), "tam": e._rng.randf_range(0.16, 0.26)})
		Modo.HEBRAS:
			e._t = -maxf(espera, 0.0)
			e._hasta = Vector2(caja.get_center().x, caja.end.y)   # los pies
			for i in 4:
				var lado: float = -1.0 if i % 2 == 0 else 1.0
				e._piezas.append({"x": lado * e._rng.randf_range(0.55, 1.1), "y": e._rng.randf_range(-0.6, 0.8),
					"h": e._rng.randf_range(0.14, 0.32), "px": lado * e._rng.randf_range(0.05, 0.3),
					"t0": float(i) * 0.03})
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# LA RED QUE SE QUEDA (la Telaraña): no se va sola; se va cuando CombatTactico la seca (secar()). 'espera' = lo que
# falta para que caiga el ovillo que la tiende.
static func red(padre: Node, f: CombatFormas.Forma, semilla: int, espera: float) -> InsectoAire:
	if padre == null or f == null:
		return null
	var e := InsectoAire.new()
	e.modo = Modo.RED
	e.forma = f
	e._rng.seed = hash(semilla)
	e._t = -maxf(espera, 0.0)
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._o = f.centro
	e._r = maxf(f.radio, 6.0)
	# Los RADIOS, cada uno con su largo; y LOS ANILLOS de la espiral, un tramo por hueco. Cada pieza con su 'vida': al
	# secarse se van rompiendo las de vida mas alta primero.
	var n: int = 10
	var a0: float = e._rng.randf_range(0.0, TAU)
	for i in n:
		e._radios.append({"a": a0 + TAU * (float(i) + e._rng.randf_range(-0.2, 0.2)) / float(n),
			"lob": e._rng.randf_range(0.88, 1.04), "vida": e._rng.randf_range(0.0, 0.9)})
	# Se rompe POR SECTORES (una red rasgada, no tramos sueltos al azar): la vida de cada tramo tira de la de su radio.
	for fr in [0.22, 0.38, 0.53, 0.67, 0.8, 0.92]:
		var vidas: Array = []
		for i in n:
			vidas.append(0.55 * float(e._radios[i]["vida"]) + 0.35 * e._rng.randf() + 0.1 * fr)
		e._anillos.append({"f": fr, "vidas": vidas})
	for k in 6:
		e._rocio.append({"i": e._rng.randi_range(0, n - 1), "j": e._rng.randi_range(1, e._anillos.size() - 1),
			"fase": e._rng.randf_range(0.0, TAU)})
	e._suelo = e._capa(SueloRoto.Z_SUELO, false)
	return e


# La red se seca: se va en T_SECA y fuera.
func secar() -> void:
	if _secando < 0.0:
		_secando = maxf(_t, 0.0)


func duracion() -> float:
	match modo:
		Modo.TELARANA: return T_TELA_CAE + 0.45
		Modo.VENENO: return T_VENENO
		Modo.HEBRAS: return T_HEBRAS
		Modo.RED: return INF if _secando < 0.0 else _secando + T_SECA
		Modo.PALA: return T_PALA + 0.25
		Modo.ARROLLA: return T_ARROLLA
		Modo.CAPARAZON: return T_CAPARAZON
		Modo.PATITAS: return 0.34
		Modo.APRETON: return 0.4
		Modo.RODADA: return T_RODADA + 1.4
	return T_CLAVADO + T_IRSE


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
		Modo.TELARANA: _telarana(capa)
		Modo.QUELICEROS, Modo.PONZONA: _queliceros(capa)
		Modo.FORCIPULAS: _forcipulas(capa)
		Modo.PATITAS: _patitas(capa)
		Modo.APRETON: _apreton(capa)
		Modo.VENENO: _veneno(capa)
		Modo.HEBRAS: _hebras(capa)
		Modo.RED: _red(capa)
		Modo.PALA: _pala(capa)
		Modo.ARROLLA: _arrolla(capa)
		Modo.CAPARAZON: _caparazon(capa)
		Modo.RODADA: _rodada(capa)


# ------------------------------------------------------------
#  EL MORDISCO DE LA ARAÑA
# ------------------------------------------------------------
# NO SE DIBUJAN COLMILLOS (29/09, lo pidio el usuario: "quedan feos de pelitas; mejor que sea el efecto visual de un
# mordisco, y si envenena que sea el efecto pero verde y goteando"). Los colmillos los enseña la araña en su sprite;
# aqui va EL MORDISCO: dos medias lunas llenas (filo duro, difuminadas por dentro, como los tajos de las armas) que
# ABRAZAN EL CUERPO POR FUERA desde los lados -los queliceros de una araña estan a los lados- y se cierran como una
# pinza "(  )" con las puntas al otro lado, justo en el golpe, con un destello y las dos marcas. El ponzoñoso, en verde y goteando.
func _queliceros(capa: Node2D) -> void:
	var cierre: float    # 0 = empezando a entrar, 1 = cerradas
	var alfa: float
	if _t < 0.0:
		var u: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		cierre = 1.0 - (1.0 - u) * (1.0 - u)
		alfa = clampf(u * 3.0, 0.0, 1.0)
	else:
		cierre = 1.0
		alfa = 1.0 - smoothstep(T_CLAVADO * 0.5, T_CLAVADO + T_IRSE, _t)
	var verde: bool = modo == Modo.PONZONA
	var c: Vector2 = _hasta
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.12:
			BarridoAire.destello(capa, c, _tam * 1.1, Color(0.7, 1.0, 0.5, 0.8 * (1.0 - _t / 0.12)) if verde \
				else Color(0.92, 0.86, 1.0, 0.8 * (1.0 - _t / 0.12)), _eje.angle())
		return
	if capa != _delante or alfa <= 0.01:
		return
	var filo: Color = VENENO_CLARO if verde else Color(0.96, 0.93, 1.0)
	var dentro: Color = VENENO if verde else QUITINA_CLARA
	# LA PINZA "(  )" QUE SE CIERRA SOBRE LA VICTIMA (dibujo del usuario, 29/09): cada media luna nace a un lado, del
	# lado de la araña, se comba HACIA FUERA y su punta se clava en el cuerpo; las dos puntas se juntan ahi, en el
	# golpe. Cada una es un arco de circulo que pasa por su base y por la punta, con el centro hacia dentro (asi se
	# comba hacia fuera y el filo duro queda por fuera).
	var punta: Vector2 = c + _eje * _tam * 0.45
	for s in [-1.0, 1.0]:
		var base: Vector2 = c - _eje * _tam * 1.5 + _lado * s * _tam * 1.25
		var m: Vector2 = (base + punta) * 0.5
		var d: Vector2 = punta - base
		var n: Vector2 = d.orthogonal().normalized()
		if n.dot(_lado * s) > 0.0:
			n = -n   # el centro hacia el eje del mordisco: el arco se comba hacia fuera
		var o: Vector2 = m + n * d.length() * 0.45
		var r: float = o.distance_to(punta)
		var a_ini: float = (base - o).angle()
		var a_fin: float = a_ini + wrapf((punta - o).angle() - a_ini, -PI, PI)
		var cabeza: float = lerpf(a_ini, a_fin, cierre)
		# Toda la estela a la vista mientras cierra; al soltar, la cola alcanza a la cabeza y se apaga.
		var cola: float = a_ini if _t < 0.0 else lerpf(a_ini, a_fin, clampf(_t / (T_CLAVADO + T_IRSE), 0.0, 0.85))
		BestiaAire._media_luna(capa, o, cola, cabeza, r, _tam * 0.8, filo, dentro, alfa, false)
	# LAS DOS MARCAS al cerrar; en el ponzoñoso, goteando.
	if _t >= 0.0:
		var escurre: float = clampf(_t / 0.4, 0.0, 1.0)
		for s2 in [-1.0, 1.0]:
			var p: Vector2 = c + _lado * s2 * _tam * 0.22
			BestiaAire._bola(capa, p, maxf(1.3, _tam * 0.16), Color(VENENO_OSCURO if verde else QUITINA, 0.9 * alfa))
			if verde:
				BarridoAire.cometa(capa, p, p + Vector2(0.0, 1.5 + _tam * 0.9 * escurre), maxf(1.0, _tam * 0.14),
					Color(VENENO, 0.9 * alfa))


# ------------------------------------------------------------
#  EL VENENO QUE ENTRA
# ------------------------------------------------------------
# Donde se han clavado: una mancha verde que se abre y se apaga, gotitas que saltan hacia fuera y caen, y un hilo que
# escurre hacia abajo.
func _veneno(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var apaga: float = 1.0 - smoothstep(T_VENENO * 0.5, T_VENENO, _t)
	var crece: float = clampf(_t / 0.1, 0.0, 1.0)
	BestiaAire._bola(capa, _hasta, _tam * lerpf(0.6, 1.4, crece), Color(VENENO, 0.8 * apaga))
	BestiaAire._bola(capa, _hasta, _tam * 0.6 * crece, Color(VENENO_OSCURO, 0.7 * apaga))
	BestiaAire._bola(capa, _hasta + Vector2(-_tam * 0.2, -_tam * 0.25), _tam * 0.3 * crece, Color(VENENO_CLARO, 0.6 * apaga))
	var escurre: float = clampf((_t - 0.08) / 0.5, 0.0, 1.0)
	if escurre > 0.0:
		BarridoAire.cometa(capa, _hasta, _hasta + Vector2(0.0, 2.0 + _tam * 0.9 * escurre), maxf(1.0, _tam * 0.18),
			Color(VENENO, 0.85 * apaga))
	var kv: float = clampf(_t / 0.5, 0.0, 1.0)
	if kv >= 1.0:
		return
	for g in _piezas:
		var d: Vector2 = g["d"]
		var p: Vector2 = _hasta + d * float(g["v"]) * kv - Vector2(0.0, float(g["sube"]) * 4.0 * kv * (1.0 - kv) * K) \
			+ Vector2(0.0, 6.0 * kv * kv)
		var tam: float = float(g["tam"])
		capa.draw_circle(p, tam + 0.5, Color(VENENO_OSCURO, 1.0 - kv * kv))
		capa.draw_circle(p, tam, Color(VENENO, 1.0 - kv * kv))


# ------------------------------------------------------------
#  LAS HEBRAS en las piernas de los que pilla la red al caer
# ------------------------------------------------------------
func _hebras(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var apaga: float = 1.0 - smoothstep(T_HEBRAS * 0.6, T_HEBRAS, _t)
	for h in _piezas:
		var sube: float = clampf((_t - float(h["t0"])) / 0.1, 0.0, 1.0)
		if sube <= 0.0:
			continue
		var suelo: Vector2 = _hasta + Vector2(float(h["x"]) * _ancho, 2.0 + float(h["y"]) * 3.0)
		var pierna: Vector2 = _hasta + Vector2(float(h["px"]) * _ancho, -float(h["h"]) * _largo * sube)
		# Cuelga un poco: el control, por debajo de la recta.
		var ctrl: Vector2 = suelo.lerp(pierna, 0.5) + Vector2(0.0, 2.5)
		hilo(capa, suelo, ctrl, pierna, 0.7, apaga, false)
		BestiaAire._bola(capa, suelo, 1.8, Color(SEDA, 0.6 * apaga))


# UN HILO DE SEDA de 'a' a 'b' por la curva de 'ctrl': relleno, mas grueso junto a los nudos (las puntas) y fino en
# medio, con un halo suave detras. Con 'sombra', su sombra en el suelo (la red tendida). Publica: la usa la hoja.
static func hilo(ci: CanvasItem, a: Vector2, ctrl: Vector2, b: Vector2, g: float, alfa: float, sombra: bool) -> void:
	if alfa <= 0.01 or a.distance_squared_to(b) < 0.25:
		return
	var n: int = maxi(3, int(a.distance_to(b) / 5.0))
	var c_i := PackedVector2Array()
	var c_d := PackedVector2Array()
	var h_i := PackedVector2Array()
	var h_d := PackedVector2Array()
	var s_i := PackedVector2Array()
	var s_d := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n)
		var p: Vector2 = a.lerp(ctrl, s).lerp(ctrl.lerp(b, s), s)
		var tg: Vector2 = (ctrl - a) * (1.0 - s) + (b - ctrl) * s
		var nn: Vector2 = tg.normalized().orthogonal() if tg.length_squared() > 0.0001 else Vector2.UP
		var w: float = g * (0.55 + 0.45 * absf(2.0 * s - 1.0))
		c_i.append(p - nn * w * 0.5)
		c_d.append(p + nn * w * 0.5)
		h_i.append(p - nn * w * 1.4)
		h_d.append(p + nn * w * 1.4)
		s_i.append(p + Vector2(0.6, 1.3) - nn * w * 0.6)
		s_d.append(p + Vector2(0.6, 1.3) + nn * w * 0.6)
	if sombra:
		BestiaAire._tira(ci, s_i, s_d, Color(SEDA_SOMBRA, 0.35 * alfa))
	BestiaAire._tira(ci, h_i, h_d, Color(SEDA, 0.2 * alfa))
	BestiaAire._tira(ci, c_i, c_d, Color(SEDA, 0.95 * alfa))


# ------------------------------------------------------------
#  LA TELARAÑA POR EL AIRE
# ------------------------------------------------------------
# El ovillo sale de la araña (de su abdomen, un palmo por encima del suelo), vuela en parabola dejando un hilo detras y
# se va abriendo en hebras segun cae; al caer revienta en pelusas de seda. La red tendida es RED, otro nodo.
func _telarana(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	# De la PUNTA DEL ABDOMEN levantado (AranaSprites, la 'telarana'): un poco detras de sus pies y bien arriba.
	var desde: Vector2 = _o - _dir * (_lejos + ABD_ATRAS) + Vector2(0.0, -ABD_ALTO)
	if _t < T_TELA_CAE:
		var k: float = _t / T_TELA_CAE
		var p: Vector2 = _vuelo(desde, k)
		var antes: Vector2 = _vuelo(desde, maxf(k - 0.35, 0.0))
		BarridoAire.cometa(capa, antes, p, 1.4, Color(SEDA, 0.55))
		var r: float = lerpf(3.6, 5.5, k)
		BestiaAire._bola(capa, p, r * 2.4, Color(SEDA, 0.25))
		capa.draw_circle(p, r + 0.6, Color(SEDA_SOMBRA, 0.6))
		capa.draw_circle(p, r, SEDA)
		# SE VA ABRIENDO: hebras que salen del ovillo en la segunda mitad del vuelo.
		var abre: float = clampf((k - 0.5) / 0.5, 0.0, 1.0)
		if abre > 0.0:
			for i in 6:
				var a: float = TAU * float(i) / 6.0 + _t * 4.0
				var fin: Vector2 = p + Vector2(cos(a), sin(a) * K) * (r + _r * 0.5 * abre)
				hilo(capa, p, p.lerp(fin, 0.5) + Vector2(0.0, 1.5), fin, 0.7, abre, false)
		return
	# AL CAER: pelusas de seda que saltan y un soplo blanco en el centro.
	var kc: float = clampf((_t - T_TELA_CAE) / 0.35, 0.0, 1.0)
	BestiaAire._bola(capa, _o, _r * 0.5 * (0.6 + kc), Color(SEDA, 0.35 * (1.0 - kc)))
	for g in _piezas:
		var d := Vector2(cos(float(g["a"])), sin(float(g["a"])))
		var p2: Vector2 = _o + d * float(g["v"]) * kc - Vector2(0.0, float(g["sube"]) * 4.0 * kc * (1.0 - kc) * K)
		BestiaAire._bola(capa, p2, float(g["tam"]) * 1.6, Color(SEDA, 0.8 * (1.0 - kc * kc)))


func _vuelo(desde: Vector2, k: float) -> Vector2:
	return desde.lerp(_o, k) - Vector2(0.0, 30.0 * sin(PI * k))


# ------------------------------------------------------------
#  LA RED TENDIDA
# ------------------------------------------------------------
# Radios desde el centro y la espiral en anillos, cada tramo un poco combado hacia dentro. Se tiende de golpe al caer
# (crece con un pelin de mas), tiene rocio que brilla, y segun le queda se rompe (faltan tramos, los radios rotos
# cuelgan cortos) y encoge; al secarse se apaga.
func _red(capa: Node2D) -> void:
	if _t < 0.0 or capa != _suelo or forma == null:
		return
	var entra: float = clampf(_t / 0.14, 0.0, 1.0)
	var sale: float = 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)
	var alfa: float = entra * sale * lerpf(0.75, 1.0, queda)
	if alfa <= 0.01:
		return
	var sobra: float = 1.0 + 0.12 * sin(PI * entra)
	var r: float = BestiaAire.radio_charco(forma, queda) * lerpf(0.35, 1.0, entra) * sobra * lerpf(0.85, 1.0, sale)
	# Lo que sigue entero: al principio todo; a dos tercios se rasga un sector; con un tercio, mas de la mitad sigue; al
	# secarse, cada vez menos.
	var entero: float = (0.45 + 0.55 * queda) * lerpf(0.4, 1.0, sale)
	var n: int = _radios.size()
	var puntas: Array = []
	for i in n:
		var rd: Dictionary = _radios[i]
		puntas.append(Vector2(cos(float(rd["a"])), sin(float(rd["a"]))) * r * float(rd["lob"]))
	# LOS RADIOS (rotos: solo el primer trozo, colgando).
	for i in n:
		var fin: Vector2 = puntas[i]
		if float(_radios[i]["vida"]) > entero:
			fin *= 0.35
		hilo(capa, _o, _o + fin * 0.5, _o + fin, 0.75, alfa, true)
	# LA ESPIRAL: un tramo entre cada par de radios, en cada anillo.
	for an in _anillos:
		var fr: float = float(an["f"])
		for i in n:
			if float(an["vidas"][i]) > entero:
				continue
			var j: int = (i + 1) % n
			if (float(_radios[i]["vida"]) > entero or float(_radios[j]["vida"]) > entero) and fr > 0.35:
				continue   # un radio roto ya no sujeta la espiral de mas afuera
			var a: Vector2 = _o + (puntas[i] as Vector2) * fr
			var b: Vector2 = _o + (puntas[j] as Vector2) * fr
			var ctrl: Vector2 = a.lerp(b, 0.5).lerp(_o, 0.06)
			hilo(capa, a, ctrl, b, 0.6, alfa * 0.9, true)
	# EL CENTRO, mas tupido.
	BestiaAire._bola(capa, _o, maxf(2.5, r * 0.14), Color(SEDA, 0.75 * alfa))
	# EL ROCIO: gotitas en algunos nudos que brillan cada una a su ritmo.
	for d in _rocio:
		var i2: int = int(d["i"])
		var an2: Dictionary = _anillos[int(d["j"])]
		if float(an2["vidas"][i2]) > entero or float(_radios[i2]["vida"]) > entero:
			continue   # sin la hebra donde estaba, no hay gota
		var p: Vector2 = _o + (puntas[i2] as Vector2) * float(an2["f"])
		var brilla: float = 0.55 + 0.45 * sin(_t * 2.6 + float(d["fase"]))
		capa.draw_circle(p, 1.1, Color(0.75, 0.85, 0.95, alfa))
		BestiaAire._bola(capa, p, 2.6, Color(1.0, 1.0, 1.0, 0.45 * alfa * brilla))


# ------------------------------------------------------------
#  EL ESCARABAJO
# ------------------------------------------------------------
# EL PALAZO DEL BASICO: la pala empuja, no corta. Una media luna MUY abierta (mucho radio, poco angulo) combada hacia
# la victima y cruzada a la linea del golpe; llega desde el escarabajo, se aplasta contra el cuerpo (se ensancha y
# engorda) y se apaga. Con el destello de metal en el golpe y tres chispas hacia donde empuja.
func _pala(capa: Node2D) -> void:
	var c: Vector2 = _hasta
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.12:
			BarridoAire.destello(capa, c + _eje * _tam * 0.1, _tam * 1.0, Color(HIERRO_FILO, 0.85 * (1.0 - _t / 0.12)),
				_eje.angle() + PI * 0.25)
		return
	if capa != _delante:
		return
	var llega: float
	var alfa: float
	var aplasta: float = 0.0
	if _t < 0.0:
		var u: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		llega = u * u
		alfa = clampf(u * 2.5, 0.0, 1.0)
	else:
		llega = 1.0
		aplasta = clampf(_t / T_PALA, 0.0, 1.0)
		alfa = 1.0 - smoothstep(0.3, 1.0, aplasta)
	var r: float = _tam * 1.7
	var frente: Vector2 = c - _eje * _tam * lerpf(1.3, 0.0, llega) + _eje * _tam * 0.25 * aplasta
	var abre: float = 0.6 + 0.14 * aplasta
	# GORDA: con medio _tam de grueso salia una raya (el relleno se difumina hacia dentro). Es una PLACA que aplasta.
	BestiaAire._media_luna(capa, frente - _eje * r, _eje.angle() - abre, _eje.angle() + abre, r,
		_tam * lerpf(1.1, 1.5, aplasta), HIERRO_FILO, HIERRO.lightened(0.35), alfa, true)
	if _t >= 0.0:
		_chispas(capa, c, 0.22, 0.3)


# LAS CHISPAS: cometas cortas con la cabeza llena que salen de 'c' por su 'd' y caen un poco. 'dura' = lo que vuela
# cada una; 'desde' = de a que fraccion de _tam arrancan (del borde del golpe, no del centro).
func _chispas(capa: Node2D, c: Vector2, dura: float, desde: float) -> void:
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > dura:
			continue
		var k: float = tg / dura
		var d: Vector2 = g["d"]
		var a0: Vector2 = c + d * _tam * desde
		var cabeza: Vector2 = a0 + d * float(g["v"]) * sqrt(k) + Vector2(0.0, 6.0 * k * k)
		var cola: Vector2 = a0 + d * float(g["v"]) * sqrt(maxf(k - 0.35, 0.0))
		BarridoAire.cometa(capa, cola, cabeza, maxf(1.4, _tam * 0.16), Color(CHISPA, 1.0 - k * k))


# LA BOLA QUE LE PASA POR ENCIMA (Embestida rodante), en cada uno que atraviesa: el FRENTE REDONDO de la bola (una
# media luna del radio de la bola, combada hacia donde va) que le cruza de lado a lado, un destello, chispas A LOS
# LADOS (la bola sigue, no rebota) y polvo que sale de sus pies. El primero, entero; los de detras, mas pequeño.
func _arrolla(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var c: Vector2 = _hasta
	if capa == _brillo:
		if _t < 0.14:
			BarridoAire.destello(capa, c, _tam * 1.4, Color(1.0, 0.97, 0.9, 0.9 * (1.0 - _t / 0.14)), _eje.angle())
		return
	if capa != _delante:
		return
	var k: float = clampf(_t / 0.16, 0.0, 1.0)
	var r: float = _tam * 1.05
	var o: Vector2 = c + _eje * _tam * lerpf(-0.9, 0.9, k) - _eje * r * 0.35
	BestiaAire._media_luna(capa, o, _eje.angle() - 1.25, _eje.angle() + 1.25, r, r * 0.5, HIERRO_FILO, HIERRO,
		0.95 * (1.0 - k * k), true)
	# El polvo que le sale de los pies, a los dos lados.
	var kp: float = clampf(_t / T_ARROLLA, 0.0, 1.0)
	var pies: Vector2 = c + Vector2(0.0, _largo * 0.45)
	for s in [-1.0, 1.0]:
		var p: Vector2 = pies + _lado * s * _ancho * (0.3 + 0.7 * kp) - Vector2(0.0, 3.0 * kp)
		BestiaAire._bola(capa, p, _ancho * 0.28 * (0.6 + 0.8 * kp), Color(BestiaAire.POLVO, 0.35 * (1.0 - kp)))
		BestiaAire._bola(capa, p + Vector2(-1.0, -1.5), _ancho * 0.16 * (0.6 + 0.8 * kp),
			Color(BestiaAire.POLVO_CLARO, 0.4 * (1.0 - kp)))
	_chispas(capa, c, 0.3, 0.4)


# EL CAPARAZON, sobre el mismo al cerrarse del todo: un REFLEJO estrecho y ladeado que barre el lomo de punta a punta
# (el "clanc" del hierro; hecho de brillos blandos, no de una raya) con una estrellita arriba al pasar por el centro,
# y un anillo de polvo bajo a ras del suelo, del golpe de aplastarse. Solo la mitad de delante: la de detras la
# taparia el.
func _caparazon(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var w: float = _ancho * 0.5
	var h: float = _largo * 0.5
	if capa == _delante:
		var kp: float = clampf(_t / 0.5, 0.0, 1.0)
		if kp >= 1.0:
			return
		var pies: Vector2 = _hasta + Vector2(0.0, h * 0.8)
		for g in _piezas:
			var a: float = float(g["a"])
			if sin(a) < -0.1:
				continue
			var rad: float = w * float(g["u"]) * (0.75 + 0.55 * (1.0 - pow(1.0 - kp, 2.0)))
			var p: Vector2 = pies + Vector2(cos(a), sin(a) * 0.45) * rad - Vector2(0.0, float(g["sube"]) * kp)
			var rr: float = w * float(g["tam"]) * (0.6 + 0.8 * kp)
			BestiaAire._bola(capa, p, rr * 1.2, Color(BestiaAire.POLVO, 0.3 * (1.0 - kp)))
			BestiaAire._bola(capa, p + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.75, Color(BestiaAire.POLVO_CLARO, 0.36 * (1.0 - kp)))
		return
	if capa != _brillo:
		return
	# EL LOMO: la mitad de arriba de su caja (esta aplastado: lo de abajo es el faldon).
	var dc: Vector2 = _hasta + Vector2(0.0, -h * 0.15)
	var rx: float = w * 0.8
	var ry: float = h * 0.55
	var ks: float = clampf(_t / 0.26, 0.0, 1.0)
	if ks < 1.0:
		var x: float = lerpf(-1.15, 1.15, ks * ks * (3.0 - 2.0 * ks))
		for j in 11:
			var yy: float = lerpf(-1.0, 1.0, float(j) / 10.0)
			var px: float = x + yy * (0.35 + _tam)
			var dentro: float = 1.0 - (px * px + yy * yy)
			if dentro <= 0.0:
				continue
			BestiaAire._bola(capa, dc + Vector2(px * rx, yy * ry), rx * 0.2, Color(HIERRO_FILO, 0.6 * minf(dentro * 2.0, 1.0)))
	var te: float = _t - 0.1
	if te >= 0.0 and te < 0.16:
		BarridoAire.destello(capa, dc + Vector2(0.0, -ry * 0.4), w * 0.55, Color(HIERRO_FILO, 0.9 * (1.0 - te / 0.16)), 0.3)


# LO QUE DEJA LA BOLA EN EL SUELO: una BANDA de tierra aplastada del ancho de la bola, de donde sale a por donde va,
# con el borde un poco irregular; dentro, mas oscura por el centro (hundida); fuera, un LABIO claro de la tierra que
# aparta (como el borde del pisoton: sin el se leeria como una sombra). Polvo que se levanta a los lados a su paso y
# terrones despedidos. Se va apagando al acabar.
func _rodada(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var lat: Vector2 = _dir.orthogonal()
	var va: float = clampf(_t / T_RODADA, 0.0, 1.0)
	var seca: float = 1.0 - smoothstep(T_RODADA + 0.5, T_RODADA + 1.4, _t)
	var semi: float = _ancho * 0.36
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
			fuera_i.append(p - lat * (si + 2.4))
			fuera_d.append(p + lat * (sd + 2.4))
			borde_i.append(p - lat * si)
			borde_d.append(p + lat * sd)
			medio_i.append(p - lat * si * 0.5)
			medio_d.append(p + lat * sd * 0.5)
			if float(rd["u"]) >= va:
				break
		if borde_i.size() < 2:
			return
		# SIN BORDES DUROS (efectos sin lineas): la banda por capas, cada una mas estrecha y mas oscura, y lo de fuera
		# apenas se nota. El labio de tierra apartada son TERRONES blandos a los lados, no una tira.
		BestiaAire._tira(capa, fuera_i, fuera_d, Color(TIERRA, 0.12 * seca))
		BestiaAire._tira(capa, borde_i, borde_d, Color(TIERRA, 0.16 * seca))
		BestiaAire._tira(capa, medio_i, medio_d, Color(TIERRA, 0.18 * seca))
		# Desordenados (sitio, tamaño, y alguno que falta): en fila y a compas se leian como una LINEA DE PUNTOS.
		for k in borde_i.size():
			var rd2: Dictionary = _radios[k]
			var j_i: float = float(rd2["i"]) * 12.0
			var j_d: float = float(rd2["d"]) * 12.0
			if j_i > -0.4:
				BestiaAire._bola(capa, fuera_i[k].lerp(borde_i[k], 0.3 + 0.3 * j_i) + _dir * j_d * 1.5, 2.4 + j_d * 1.2,
					Color(0.62, 0.54, 0.44, 0.3 * seca))
			if j_d > -0.4:
				BestiaAire._bola(capa, fuera_d[k].lerp(borde_d[k], 0.3 + 0.3 * j_d) - _dir * j_i * 1.5, 2.4 + j_i * 1.2,
					Color(0.62, 0.54, 0.44, 0.3 * seca))
		return
	if capa != _delante:
		return
	for g in _piezas:
		var tp: float = _t - float(g["u"]) * T_RODADA
		if tp < 0.0 or tp > 0.7:
			continue
		var kv: float = tp / 0.7
		var lado: float = float(g["lado"])
		var base: Vector2 = _o + _dir * _largo * float(g["u"]) + lat * semi * lado
		var p2: Vector2 = base + lat * lado * float(g["sale"]) * semi * kv - Vector2(0.0, float(g["sube"]) * kv)
		var rr: float = _ancho * float(g["tam"]) * (0.5 + 0.9 * kv)
		BestiaAire._bola(capa, p2, rr * 1.2, Color(BestiaAire.POLVO, 0.3 * (1.0 - kv)))
		BestiaAire._bola(capa, p2 + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.75, Color(BestiaAire.POLVO_CLARO, 0.36 * (1.0 - kv)))
	for pd in _anillos:
		var tt: float = _t - float(pd["u"]) * T_RODADA
		if tt < 0.0 or tt > 0.45:
			continue
		var kt: float = tt / 0.45
		var b2: Vector2 = _o + _dir * _largo * float(pd["u"]) + lat * semi * float(pd["lado"])
		var p3: Vector2 = b2 + lat * float(pd["lado"]) * float(pd["v"]) * kt - Vector2(0.0, float(pd["sube"]) * 4.0 * kt * (1.0 - kt) * K)
		var tam: float = float(pd["tam"])
		capa.draw_rect(Rect2(p3 - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), Color(BestiaAire.TIERRA, 1.0 - kt * kt * kt))


# ------------------------------------------------------------
#  EL CIEMPIES
# ------------------------------------------------------------
# LAS FORCIPULAS DEL BASICO: dos medias lunas finas y GANCHUDAS que entran desde los lados y SE CRUZAN como una tijera
# sobre el cuerpo (las de la araña se cierran en paralelo y se juntan; estas se pasan: cada punta acaba al otro lado).
# Rojo oscuro con el filo ambar, un destello en el cruce y dos marcas. El veneno que entra lo pone CombatTactico.
func _forcipulas(capa: Node2D) -> void:
	var cierre: float
	var alfa: float
	if _t < 0.0:
		var u: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		cierre = 1.0 - (1.0 - u) * (1.0 - u)
		alfa = clampf(u * 3.0, 0.0, 1.0)
	else:
		cierre = 1.0
		alfa = 1.0 - smoothstep(T_CLAVADO * 0.5, T_CLAVADO + T_IRSE, _t)
	var c: Vector2 = _hasta
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.12:
			BarridoAire.destello(capa, c, _tam * 1.1, Color(1.0, 0.8, 0.45, 0.85 * (1.0 - _t / 0.12)), _eje.angle() + 0.4)
		return
	if capa != _delante or alfa <= 0.01:
		return
	for s in [-1.0, 1.0]:
		# De un lado (del lado del ciempies) al OTRO lado de la victima: la punta se pasa del eje, y por eso se cruzan.
		var base: Vector2 = c - _eje * _tam * 1.3 + _lado * s * _tam * 1.2
		var punta: Vector2 = c + _eje * _tam * 0.35 - _lado * s * _tam * 0.55
		var m: Vector2 = (base + punta) * 0.5
		var d: Vector2 = punta - base
		var n: Vector2 = d.orthogonal().normalized()
		if n.dot(_eje) > 0.0:
			n = -n   # combada hacia delante: el gancho
		var o: Vector2 = m + n * d.length() * 0.35
		var r: float = o.distance_to(punta)
		var a_ini: float = (base - o).angle()
		var a_fin: float = a_ini + wrapf((punta - o).angle() - a_ini, -PI, PI)
		var cabeza: float = lerpf(a_ini, a_fin, cierre)
		var cola: float = a_ini if _t < 0.0 else lerpf(a_ini, a_fin, clampf(_t / (T_CLAVADO + T_IRSE), 0.0, 0.85))
		BestiaAire._media_luna(capa, o, cola, cabeza, r, _tam * 0.85, Color(1.0, 0.76, 0.32), Color(0.5, 0.09, 0.07),
			alfa, false)
	if _t >= 0.0:
		for s2 in [-1.0, 1.0]:
			BestiaAire._bola(capa, c + _lado * s2 * _tam * 0.2, maxf(1.3, _tam * 0.15), Color(0.3, 0.04, 0.04, 0.9 * alfa))


# LA RAFAGA DE PATITAS (Oleada de patas), en cada picotazo: 6-8 pinchos cortos y rellenos (cometas con la punta
# ambar) que se clavan ESCALONADOS de arriba abajo, desde fuera del cuerpo y sobre todo del lado de quien pica. Como
# una ola que le recorre.
func _patitas(capa: Node2D) -> void:
	if capa == _brillo:
		return
	if capa != _delante:
		return
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < -0.06 or tg > 0.2:
			continue
		var p: Vector2 = g["p"]
		var d: Vector2 = g["d"]
		if tg < 0.0:
			# Entrando: la cometa viene de fuera hacia su sitio.
			var k: float = 1.0 + tg / 0.06
			var cab: Vector2 = p - d * _tam * 1.4 * (1.0 - k)
			BarridoAire.cometa(capa, cab - d * _tam * 1.5, cab, maxf(2.6, _tam * 0.4), Color(1.0, 0.78, 0.34, k))
			continue
		# Clavada: se queda un momento y se apaga, con un puntito oscuro donde pincho.
		var a: float = 1.0 - tg / 0.2
		# GORDAS: una figura mide 14 px y a 0,26 de grueso se quedaban en alfileres de dos pixeles.
		BarridoAire.cometa(capa, p - d * _tam * 1.5, p, maxf(2.6, _tam * 0.4), Color(1.0, 0.78, 0.34, a))
		BestiaAire._bola(capa, p, maxf(1.2, _tam * 0.16), Color(0.35, 0.05, 0.04, 0.8 * a))
		# EL VENENO, en la punta de alguna: una gotita verde que escurre (la mancha grande de la araña, en cada uno de
		# los cinco picotazos, lo tapaba todo de verde).
		if bool(g["gota"]):
			var q: Vector2 = p + Vector2(0.0, 1.0 + _tam * 0.5 * (tg / 0.2))
			BestiaAire._bola(capa, q, maxf(1.4, _tam * 0.14) * 1.6, Color(VENENO, 0.3 * a))
			capa.draw_circle(q, maxf(1.0, _tam * 0.12), Color(VENENO, a))


# EL APRETON: el abrazo se cierra. Dos medias lunas a los lados de la cintura que entran hacia el cuerpo (el anillo que
# aprieta), un destello rojo apagado en medio, y se sueltan.
func _apreton(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var c: Vector2 = _hasta
	if capa == _brillo:
		# Rojo, no blanco: el destello aditivo sobre el cuerpo claro se iba al blanco.
		if _t < 0.16:
			BarridoAire.destello(capa, c, _ancho * 0.6, Color(0.85, 0.12, 0.08, 0.7 * (1.0 - _t / 0.16)), 0.2)
		return
	if capa != _delante:
		return
	var k: float = clampf(_t / 0.12, 0.0, 1.0)
	var alfa: float = 1.0 - smoothstep(0.14, 0.4, _t)
	# GORDAS Y PEGADAS: con un tercio de ancho de grueso y lejos del cuerpo salian dos rayas sueltas en el aire.
	for s in [-1.0, 1.0]:
		var x: float = _ancho * lerpf(0.8, 0.3, k * k)
		var r: float = _ancho * 0.5
		var o: Vector2 = c + Vector2(s * (x + r), 0.0)
		var hacia: float = PI if s > 0.0 else 0.0
		BestiaAire._media_luna(capa, o, hacia - 0.95, hacia + 0.95, r, _ancho * 0.6, Color(0.98, 0.5, 0.38),
			Color(0.5, 0.1, 0.07), alfa, true)
