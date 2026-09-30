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
#  Y EL ACECHADOR (30/09):
#    FAUCES      el basico: dos mandibulas LARGAS y oscuras (un hocico, no los paletos de la rata) con colmillos curvos
#                que se cruzan al cerrar; un destello y un tiron hacia quien muerde.
#    YUGULAR     el Salto a la yugular: durante el salto, una ESTELA DE SOMBRA (pinceladas de tinta negra con su
#                pincel claro roto, el lenguaje de la Voragine) que sigue su arco; al caer, las fauces ALTAS, al
#                cuello, y el destello rojo en estrella. La sangre la pone CombatTactico._on_impacto (solo si entra).
#    DENTELLADA  cada mordisco de la Dentellada desgarradora: las fauces y, al cerrar, TIRAN: un jiron de cometas
#                rojas hacia el acechador y la victima arrastrada un palmo hacia el.
#    VAHO        (se queda) la pasiva Olor a sangre: sobre quien sangra, mientras haya un acechador en la pelea, un
#                hilo de vaho rojo que sube ondulando. CombatTactico._tick_olor lo pone y lo quita.
#  Y LA ABERRACION (30/09):
#    TENTACULO   el basico y cada golpe del Latigazo: un tentaculo DEL SPRITE (su morado, borde, lomo claro y
#                ventosas) que brota de su masa, llega en curva, RESTALLA y se recoge; verdugon rojo y baba.
#    MIRADA      sobre quien le pilla la Mirada del vacio: se le abre un OJO negro con la pupila del eclipse encima de
#                la cabeza, y tiembla encogido (el miedo).
#    PUSTULAS    (sobre ella) la Carne que se cierra: bultos que se hinchan y se hunden al curarse.
#    GRIETAS     (se queda) mientras la luz le corta la cura: rajas doradas que chisporrotean. CombatTactico._tick_carne.
#  POR EL SUELO: CONO (la Mirada: el ojo se enciende y tres medias lunas negras recorren el cono) y ALARIDO (frentes
#  de sonido rotos y deformes en circulo completo, violeta enfermizo).
#  NADA DE LINEAS (efectos-sin-lineas): medias lunas rellenas, bolas blandas, cometas. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name FieraAire

enum Modo { TESTARAZO, ZARPA, PLACA, ARROLLA, FAUCES, YUGULAR, DENTELLADA, VAHO,
	TENTACULO, MIRADA, PUSTULAS, GRIETAS, CONO, ALARIDO }
# Los del suelo, en el orden de SueloRoto.Tipo.FIERA_*: no reordenar.
enum Suelo { ARROLLA, CONO, ALARIDO }
const _MODO_DE_SUELO := [Modo.ARROLLA, Modo.CONO, Modo.ALARIDO]

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
# EL ACECHADOR: sus fauces cerradas se quedan lo de la rata; la Dentellada pesa mas y tira.
const T_CERRADO := 0.22
const T_IRSE := 0.18
const T_ESTELA_VIVE := 0.3        # lo que dura cada trozo de la estela de sombra desde que pasa el cuerpo
const T_TIRON := 0.26             # lo que tarda el tiron de la Dentellada (va y vuelve)
const T_SECA := 0.5               # lo que tarda en irse el vaho cuando deja de sangrar
const MANDIBULA := Color(0.1, 0.07, 0.07)
const ENCIA_ROJA := Color(0.42, 0.07, 0.09)
const VAHO := Color(0.78, 0.1, 0.12)
# LA ABERRACION: lo que tarda la Mirada en recorrer su cono y el Alarido en llegar a su borde.
const T_CONO := 0.35
const T_ALARIDO := 0.45
const ALARIDO := Color(0.66, 0.42, 0.9)
const ALARIDO_CLARO := Color(0.93, 0.84, 1.0)

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
var _desde: Vector2 = Vector2.ZERO   # YUGULAR: de donde salta (el centro de su cuerpo al despegar)
var _arco: float = 0.0              # YUGULAR: lo alto que salta (CombatTactico.ALTO_SALTO_BICHO, a su tamaño)
var _lento: float = 1.0
var _dibujo: CanvasItem = null      # DENTELLADA: el de la victima, que se arrastra hacia el
var _base_dibujo: Vector2 = Vector2.ZERO
var _secando: float = -1.0          # VAHO: desde cuando se esta yendo (-1 = sigue)
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
		boca: float = -1.0, color: Color = PLACA_C, lado: float = 0.0, dibujo: CanvasItem = null,
		arco: float = 0.0) -> FieraAire:
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
		Modo.FAUCES, Modo.YUGULAR, Modo.DENTELLADA:
			# LAS FAUCES VAN A LO LARGO DE LA LINEA DEL MORDISCO, como las de la rata (la boca no muerde de lado), cada
			# mordisco con su variacion; y a la escala de quien muerde ('boca').
			e._viaje = clampf(espera, 0.12, 0.24) if m == Modo.DENTELLADA else clampf(espera, 0.08, 0.2)
			e._lento = 1.3 if m == Modo.DENTELLADA else (1.15 if m == Modo.YUGULAR else 1.0)
			# ...pero ACOTADA por el cuerpo que recibe: el acechador mide 17 px de frente y 66 de perfil, y con su ancho a
			# pelo las fauces salian diminutas hacia el norte y el sur y enormes de lado.
			e._tam = clampf((boca if boca > 0.0 else e._ancho) * 0.34, e._largo * 0.3, e._largo * 0.42) 				* (1.15 if m == Modo.YUGULAR else 1.0)
			e._incl = e._rng.randf_range(-0.3, 0.3) * (1.4 if m == Modo.DENTELLADA else 1.0)
			if m == Modo.YUGULAR:
				# AL CUELLO: alto en el cuerpo. Y el salto entero es su viaje: la estela va mientras vuela.
				e._hasta = Vector2(caja.get_center().x + e._rng.randf_range(-0.08, 0.08) * caja.size.x,
					caja.position.y + caja.size.y * 0.28)
				e._eje = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
				e._viaje = clampf(espera, 0.12, 0.5)
				e._desde = desde
				e._arco = arco
				# Las gotas de tinta que suelta la estela: en que punto del arco y cuanto caen.
				for i in 7:
					e._piezas.append({"u": e._rng.randf_range(0.15, 0.85), "cae": e._rng.randf_range(6.0, 12.0),
						"r": e._rng.randf_range(0.9, 1.6), "lado": e._rng.randf_range(-1.0, 1.0)})
			if m == Modo.DENTELLADA:
				e._tomar_dibujo(dibujo)
				# El jiron: cuatro cometas de sangre que salen de la herida hacia el que tira, abiertas un poco.
				for i in 4:
					e._piezas.append({"a": e._rng.randf_range(-0.45, 0.45), "v": e._rng.randf_range(0.8, 1.3),
						"t0": e._rng.randf_range(0.0, 0.05), "g": e._rng.randf_range(0.7, 1.1)})
			e._t = -e._viaje
		Modo.TENTACULO:
			# Brota del BORDE de su masa hacia quien recibe, cada golpe de un sitio ('lado': -1, 0, 1, y un poco al azar).
			e._viaje = clampf(espera, 0.1, 0.22)
			e._t = -e._viaje
			var de_quien: float = boca if boca > 0.0 else 20.0
			e._lado = (lado if lado != 0.0 else e._rng.randf_range(-1.0, 1.0)) + e._rng.randf_range(-0.25, 0.25)
			if absf(e._lado) < 0.3:
				e._lado = 0.3 * (1.0 if e._rng.randf() < 0.5 else -1.0)
			# NACE DENTRO DE LA MASA (a 0,3 de su ancho y con la bajada salia despegado, un tentaculo suelto al lado) y del
			# grosor de los del sprite.
			e._o = desde + eje * de_quien * 0.12 + eje.orthogonal() * e._lado * de_quien * 0.16 + Vector2(0.0, de_quien * 0.05)
			e._tam = clampf(de_quien * 0.1, 2.2, 4.5)
			e._placa = color
			e._placa_clara = color.lightened(0.35)
			for i in 5:
				e._piezas.append({"d": Vector2(e._rng.randf_range(-1.0, 1.0), e._rng.randf_range(-1.2, -0.3)).normalized(),
					"v": e._rng.randf_range(6.0, 14.0), "r": e._rng.randf_range(0.8, 1.5), "t0": e._rng.randf_range(0.0, 0.05)})
		Modo.MIRADA:
			e._t = -maxf(espera, 0.0)
			e._hasta = Vector2(caja.get_center().x, caja.position.y - caja.size.y * 0.15)
			e._tomar_dibujo(dibujo)
		Modo.PUSTULAS:
			e._t = -maxf(espera, 0.0)
			e._o = caja.get_center()
			e._placa = color
			for i in 7:
				e._piezas.append({"x": e._rng.randf_range(-0.2, 0.2), "y": e._rng.randf_range(-0.3, 0.08),
					"r": e._rng.randf_range(1.8, 2.8) * maxf(caja.size.x / 30.0, 0.6), "t0": float(i) * 0.05})
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	# LA ESTELA DE SOMBRA va DETRAS de los cuerpos (la deja el, por el aire): encima de todo tapaba su propio salto.
	if m == Modo.YUGULAR:
		e._suelo = e._capa(Game.Z_PERSONAJES - 1, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# EL VAHO DEL OLOR A SANGRE sobre 'caja' (quien sangra): se queda hasta que le llaman a secar(); lo mueve seguir().
# LAS GRIETAS DE LUZ sobre la aberracion ('caja'): como el vaho, se quedan hasta secar() y las mueve seguir().
static func grietas(padre: Node, caja: Rect2, semilla: int) -> FieraAire:
	if padre == null:
		return null
	var e := FieraAire.new()
	e.modo = Modo.GRIETAS
	e._rng.seed = hash(semilla)
	e._t = 0.0
	e._incl = e._rng.randf_range(0.0, TAU)
	# Cuatro rajas quebradas en coordenadas de su caja (-0,5..0,5), repartidas por la carne.
	for i in 4:
		var pts := PackedVector2Array()
		# EN LA MASA DEL MEDIO, cortas: su caja incluye los tentaculos, y repartidas por toda ella salian fuera del cuerpo.
		var p := Vector2(e._rng.randf_range(-0.16, 0.16), e._rng.randf_range(-0.28, 0.05))
		var a: float = e._rng.randf_range(0.0, TAU)
		for k in 5:
			pts.append(p)
			a += e._rng.randf_range(-0.9, 0.9)
			p += Vector2(cos(a) * 0.045, sin(a) * 0.05)
		e._lajas.append({"pts": pts})
	e.seguir(caja)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


static func vaho(padre: Node, caja: Rect2, semilla: int) -> FieraAire:
	if padre == null:
		return null
	var e := FieraAire.new()
	e.modo = Modo.VAHO
	e._rng.seed = hash(semilla)
	e._ritmo = 1.0
	e._t = 0.0
	e._incl = e._rng.randf_range(0.0, TAU)   # la fase propia de cada uno: que no ondulen todos a la vez
	e.seguir(caja)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	return e


func seguir(caja: Rect2) -> void:
	_hasta = Vector2(caja.get_center().x, caja.position.y + caja.size.y * 0.1)
	_ancho = maxf(caja.size.x, 10.0)
	_largo = maxf(caja.size.y, 10.0)
	_o = caja.get_center()


func secar() -> void:
	if _secando < 0.0:
		_secando = _t


func _tomar_dibujo(dibujo: CanvasItem) -> void:
	if not is_instance_valid(dibujo):
		return
	if not dibujo.has_meta(&"esq_base"):
		dibujo.set_meta(&"esq_base", dibujo.get("position"))
	dibujo.set_meta(&"esq_n", int(dibujo.get_meta(&"esq_n", 0)) + 1)
	_base_dibujo = dibujo.get_meta(&"esq_base")
	_dibujo = dibujo


# El arrastre de la Dentellada: la victima va hacia quien tira y vuelve. Publica para las hojas (sin _process).
func aplicar_temblor() -> void:
	if not is_instance_valid(_dibujo):
		return
	var fuera := Vector2.ZERO
	if modo == Modo.DENTELLADA and _t >= 0.0 and _t < T_TIRON:
		fuera = (-_eje * _tam * 0.45 * sin(PI * _t / T_TIRON)).round()
	# EL MIEDO de la Mirada: se encoge (baja un pelin) y tiembla mientras le mira el ojo.
	elif modo == Modo.MIRADA and _t >= 0.0 and _t < 0.5:
		var k: float = 1.0 - _t / 0.5
		fuera = Vector2(sin(_t * 85.0) * 1.3 * k, 1.0 + 0.5 * sin(_t * 60.0) * k).round()
	_dibujo.set("position", _base_dibujo + fuera)


func _devolver_dibujo() -> void:
	if not is_instance_valid(_dibujo):
		return
	_dibujo.set("position", _base_dibujo)
	var n: int = int(_dibujo.get_meta(&"esq_n", 1)) - 1
	if n <= 0:
		_dibujo.remove_meta(&"esq_base")
		_dibujo.remove_meta(&"esq_n")
	else:
		_dibujo.set_meta(&"esq_n", n)
	_dibujo = null


func _exit_tree() -> void:
	_devolver_dibujo()


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
	# LA MIRADA y EL ALARIDO (la aberracion): solo su forma; se pintan encima de los cuerpos.
	if e.modo in [Modo.CONO, Modo.ALARIDO]:
		e._largo = maxf(f.radio, 8.0)
		e._banda = deg_to_rad(f.apertura if f.apertura > 0.0 else 30.0)
		e._o = f.origen if e.modo == Modo.CONO else f.centro
		e._incl = e._rng.randf_range(0.0, TAU)
		padre.add_child(e)
		e._delante = e._capa(Z_ENCIMA, false)
		e._brillo = e._capa(Z_ENCIMA + 1, true)
		e._t = -espera * e._ritmo
		return e
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
	match int(_MODO_DE_SUELO[s]) if s >= 0 and s < _MODO_DE_SUELO.size() else -1:
		Modo.CONO: return clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0) * T_CONO
		Modo.ALARIDO: return clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0) * T_ALARIDO
	return clampf((p - f.origen).dot(f.dir.normalized()) / maxf(f.largo, 1.0), 0.0, 1.0) * T_ARROLLA


static func t_salir(s: int) -> float:
	match int(_MODO_DE_SUELO[s]) if s >= 0 and s < _MODO_DE_SUELO.size() else -1:
		Modo.CONO: return T_CONO
		Modo.ALARIDO: return T_ALARIDO
	return T_ARROLLA


func duracion() -> float:
	match modo:
		Modo.TESTARAZO: return T_TESTARAZO
		Modo.ZARPA: return T_ZARPA
		Modo.PLACA: return T_PLACA
		Modo.ARROLLA: return T_ARROLLA + (T_PISOTON_DURA if not _hijos_pisoton.is_empty() else 1.4)
		Modo.DENTELLADA: return maxf((T_CERRADO + T_IRSE) * _lento, T_TIRON + 0.2)
		Modo.YUGULAR: return maxf((T_CERRADO + T_IRSE) * _lento, T_ESTELA_VIVE)
		Modo.FAUCES: return (T_CERRADO + T_IRSE) * _lento
		Modo.VAHO, Modo.GRIETAS: return INF if _secando < 0.0 else _secando + T_SECA
		Modo.TENTACULO: return 0.5
		Modo.MIRADA: return 0.55
		Modo.PUSTULAS: return 0.9
		Modo.CONO: return T_CONO + 0.25
		Modo.ALARIDO: return T_ALARIDO + 3.0 * 0.09 + 0.25
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
		_devolver_dibujo()
		queue_free()
		return
	aplicar_temblor()
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
		Modo.FAUCES, Modo.DENTELLADA: _fauces(capa)
		Modo.YUGULAR:
			_estela_sombra(capa)
			_fauces(capa)
		Modo.VAHO: _vaho(capa)
		Modo.TENTACULO: _tentaculo(capa)
		Modo.MIRADA: _ojo_mirada(capa)
		Modo.PUSTULAS: _pustulas(capa)
		Modo.GRIETAS: _grietas_luz(capa)
		Modo.CONO: _cono_mirada(capa)
		Modo.ALARIDO: _alarido(capa)


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


# ------------------------------------------------------------
#  EL ACECHADOR
# ------------------------------------------------------------
# LAS FAUCES: dos mandibulas largas y oscuras, una a cada lado de la linea del mordisco (la de quien muerde de su
# lado), que se cierran de golpe; los colmillos curvos se CRUZAN al cerrar. Como el mordisco de la rata (se van
# juntando mientras llega el golpe, rebotan un pelin y tiran hacia quien muerde), pero un hocico y no unos paletos.
# La Yugular solo las abre en el ultimo tramo del salto (antes vuela la estela); la Dentellada tira mas fuerte.
func _fauces(capa: Node2D) -> void:
	var perp: Vector2 = _eje.rotated(_incl)
	var fila: Vector2 = Vector2(-perp.y, perp.x)
	var cierre: float
	var alfa: float = 1.0
	var tiron := Vector2.ZERO
	if _t < 0.0:
		var abre: float = minf(_viaje, 0.16 * _lento)
		var u: float = clampf(1.0 + _t / abre, 0.0, 1.0)
		cierre = u * u
		alfa = clampf(u * 3.0, 0.0, 1.0)
	else:
		cierre = 1.0
		var kt: float = clampf(_t / (T_CERRADO * _lento), 0.0, 1.0)
		var tira: float = 0.8 if modo == Modo.DENTELLADA else 0.35
		tiron = -_eje * _tam * tira * sin(PI * minf(kt * 1.6, 1.0))
		alfa = 1.0 - smoothstep(T_CERRADO * _lento, (T_CERRADO + T_IRSE) * _lento, _t)
	if alfa <= 0.0:
		return
	var c: Vector2 = _hasta + tiron
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.14:
			BarridoAire.destello(capa, c, _tam * 0.9, Color(1.0, 0.95, 0.85, 0.85 * (1.0 - _t / 0.14)), perp.angle())
		return
	if capa != _delante:
		return
	# EL REBOTE: al llegar a tope la boca afloja un pelin en vez de quedarse clavada.
	if _t > 0.03 and _t < 0.1:
		cierre = 1.0 - 0.12 * sin((_t - 0.03) / 0.07 * PI)
	# LA YUGULAR: el destello rojo en estrella al cerrar, detras de los dientes y sin mezcla aditiva (sumado, naranja).
	if modo == Modo.YUGULAR and _t >= 0.0 and _t < 0.26:
		var kd: float = _t / 0.26
		BarridoAire.destello(capa, c, _tam * lerpf(1.5, 2.1, kd), Color(0.90, 0.10, 0.12, 0.9 * (1.0 - kd)),
			perp.angle() + PI * 0.125)
	# LA DENTELLADA: el jiron, detras de las fauces (sale de la herida hacia el que tira).
	if modo == Modo.DENTELLADA:
		_jiron(capa, c)
	# LARGAS Y FINAS (un hocico): con media boca de 1,3 y el grueso de la rata, cerradas eran un ovalo, un ojo.
	var media: float = _tam * 1.6
	var colmillo: float = _tam * 0.85
	var sep: float = lerpf(colmillo * 2.0, -colmillo * 0.2, cierre)
	_mandibula_larga(capa, c, fila, perp, media, colmillo, sep, alfa, 0.0)
	_mandibula_larga(capa, c, fila, -perp, media, colmillo, sep, alfa, 0.09)
	# LO QUE DEJA: los dos agujeros de los colmillos, con su gota escurriendo.
	if _t >= 0.0 and cierre > 0.85:
		for s in [-1.0, 1.0]:
			var p: Vector2 = c + fila * (0.62 * media * s)
			BestiaAire._bola(capa, p, maxf(1.5, colmillo * 0.17), Color(BestiaAire.SANGRE, 0.95 * alfa))
			BarridoAire.cometa(capa, p, p + Vector2(0.0, colmillo * 0.6), maxf(1.1, colmillo * 0.14),
				Color(BestiaAire.SANGRE, 0.6 * alfa))


# LOS DIENTES de una mandibula: [donde a lo largo (-1..1), largo (fraccion del colmillo), ancho]. Los CANINOS largos
# y curvos, y dientes cortos entre ellos. La de abajo va corrida un pelin ('corre'): encajan, no chocan punta con punta.
const _DIENTES_FAUCES := [[-0.62, 1.0, 0.16], [0.62, 1.0, 0.16], [-0.86, 0.42, 0.09], [0.86, 0.42, 0.09],
	[-0.38, 0.34, 0.08], [0.38, 0.34, 0.08], [-0.14, 0.28, 0.07], [0.14, 0.28, 0.07]]

# UNA MANDIBULA LARGA: la media luna oscura (el filo de dentro curvado: abre por el medio y en las puntas casi se
# juntan) con un borde algo mas claro para que se lea en un piso oscuro, la encia roja por dentro, y sus dientes de
# hueso que crecen hacia la otra ('crece') y se curvan hacia el medio.
func _mandibula_larga(ci: CanvasItem, c: Vector2, fila: Vector2, crece: Vector2, media: float, colmillo: float,
		sep: float, alfa: float, corre: float) -> void:
	var n: int = 14
	var dentro := PackedVector2Array()
	var fuera := PackedVector2Array()
	var borde_d := PackedVector2Array()
	var borde_f := PackedVector2Array()
	var encia := PackedVector2Array()
	var grueso: float = _tam * 0.32
	for i in n + 1:
		var k: float = float(i) / float(n) * 2.0 - 1.0
		var q: Vector2 = c + fila * media * k - crece * (sep * 0.5 + colmillo * (0.15 + 0.35 * (1.0 - k * k)))
		var g: float = grueso * pow(maxf(1.0 - k * k, 0.0), 0.55)
		dentro.append(q)
		fuera.append(q - crece * g)
		borde_d.append(q + crece * 0.6)
		borde_f.append(q - crece * (g + 1.0) - fila * k * 0.8)
		encia.append(q - crece * g * 0.32)
	var pts_b := PackedVector2Array(borde_d)
	var inv_b := borde_f.duplicate()
	inv_b.reverse()
	pts_b.append_array(inv_b)
	BestiaAire._poligono(ci, pts_b, Color(0.34, 0.27, 0.25, 0.85 * alfa))
	var pts := PackedVector2Array(dentro)
	var inv := fuera.duplicate()
	inv.reverse()
	pts.append_array(inv)
	BestiaAire._poligono(ci, pts, Color(MANDIBULA, alfa))
	BestiaAire._tira(ci, dentro, encia, Color(ENCIA_ROJA, 0.9 * alfa))
	# LOS DIENTES, desde el filo de dentro.
	for d in _DIENTES_FAUCES:
		var k: float = clampf(float(d[0]) + corre, -0.95, 0.95)
		var base: Vector2 = c + fila * media * k - crece * (sep * 0.5 + colmillo * (0.15 + 0.35 * (1.0 - k * k)))
		var largo: float = colmillo * float(d[1])
		var w: float = media * float(d[2]) * 0.5
		# CURVO: la punta se va hacia el medio de la boca (un gancho), el lomo por fuera.
		var gancho: Vector2 = -fila * signf(k) * largo * 0.3
		var punta: Vector2 = base + crece * largo + gancho
		var medio: Vector2 = base + crece * largo * 0.55 + gancho * 0.3
		var diente := PackedVector2Array([base - fila * w, medio - fila * w * 0.7, punta, medio + fila * w * 0.7,
			base + fila * w])
		var sombra := PackedVector2Array([base - fila * (w + 0.6), medio - fila * (w * 0.7 + 0.6),
			punta + (punta - medio).normalized() * 0.6, medio + fila * (w * 0.7 + 0.6), base + fila * (w + 0.6)])
		BestiaAire._poligono(ci, sombra, Color(BestiaAire.ENCIA, 0.8 * alfa))
		BestiaAire._poligono(ci, diente, Color(BestiaAire.HUESO, alfa))
		# El lomo en sombra (la mitad de fuera de la curva): da el volumen del colmillo.
		if float(d[1]) > 0.9:
			BestiaAire._poligono(ci, PackedVector2Array([base + fila * signf(k) * w, medio + fila * signf(k) * w * 0.7,
				punta, medio + fila * signf(k) * w * 0.05]), Color(BestiaAire.HUESO_SOMBRA, alfa))


# EL JIRON DE LA DENTELLADA: al cerrar, cuatro cometas de sangre gordas que salen de la herida hacia el que tira
# (con su contorno oscuro detras) y unas gotas.
func _jiron(ci: CanvasItem, c: Vector2) -> void:
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > 0.24:
			continue
		var k: float = tg / 0.24
		var d: Vector2 = (-_eje).rotated(float(g["a"]))
		var cabeza: Vector2 = c + d * _tam * 1.9 * float(g["v"]) * sqrt(k) + Vector2(0.0, 5.0 * k * k)
		var cola: Vector2 = c + d * _tam * 0.5 * k
		var ancho: float = maxf(1.6, _tam * 0.24 * float(g["g"])) * (1.0 - 0.4 * k)
		var a: float = 1.0 - k * k
		BarridoAire.cometa(ci, cola, cabeza, ancho * 1.5, Color(BestiaAire.ENCIA, 0.6 * a))
		BarridoAire.cometa(ci, cola, cabeza, ancho, Color(BestiaAire.SANGRE, a))
		BestiaAire._bola(ci, cabeza, ancho * 0.55, Color(BestiaAire.SANGRE, a))


# DONDE VA SU CUERPO en el salto (0 = despega, 1 = cae): en recto del despegue al cuello, y el arco por encima.
func _en_salto(u: float) -> Vector2:
	var fin: Vector2 = _hasta - _eje * _tam * 1.2
	return _desde.lerp(fin, u) - Vector2(0.0, _arco * 4.0 * u * (1.0 - u))


# LA ESTELA DE SOMBRA DEL SALTO: tres pinceladas de tinta negra que siguen su arco (la gorda por el medio y dos mas
# finas que salen un poco despues, a los lados), gordas por detras de el y que se afilan hasta nada; cada trozo vive
# T_ESTELA_VIVE desde que pasa. Con la pincelada clara ROTA por el filo de arriba (el lenguaje de la Voragine:
# oscuridad-nuestro-lenguaje) y gotas de tinta que caen. Detras de los cuerpos: la deja el.
func _estela_sombra(capa: Node2D) -> void:
	if capa != _suelo:
		return
	var u_h: float = clampf((_t + _viaje) / maxf(_viaje, 0.01), 0.0, 1.0)
	if u_h <= 0.0:
		return
	var desde_cae: float = maxf(_t, 0.0)
	var grueso: float = _tam * 0.6
	var lat: Vector2 = _eje.orthogonal()
	for hebra in 3:
		var off: float = [0.0, -0.8, 0.8][hebra]
		var g: float = grueso * [1.0, 0.45, 0.4][hebra]
		var retrasa: float = [0.0, 0.1, 0.16][hebra]
		var pts := PackedVector2Array()
		var anchos := PackedFloat32Array()
		var alfas := PackedFloat32Array()
		var n: int = 22
		for i in n + 1:
			var u: float = u_h * float(i) / float(n)
			var edad: float = (u_h - u) * _viaje + desde_cae - retrasa * _viaje
			var a: float = clampf(1.0 - edad / T_ESTELA_VIVE, 0.0, 1.0)
			# Se afila hacia el cuerpo (la punta la tapa el) y hacia la cola (que ya se va).
			var cabeza: float = clampf((u_h - u) / 0.14, 0.0, 1.0)
			var cola: float = clampf(u / 0.1, 0.0, 1.0)
			var ruido: float = 0.85 + 0.3 * sin(float(i) * 2.3 + float(hebra) * 4.1)
			pts.append(_en_salto(u) + lat * off * grueso * sin(PI * u))
			anchos.append(g * sqrt(a) * cabeza * cola * ruido)
			alfas.append(a * (0.95 if hebra == 0 else 0.75))
		_cinta(capa, pts, anchos, alfas, MagiaMayor.NEGRO)
		# LA PINCELADA CLARA ROTA, por el filo de arriba de la gorda.
		if hebra == 0:
			for i in n:
				if sin(float(i) * 3.7 + 1.1) < 0.2 or anchos[i] < 0.8:
					continue
				var p0: Vector2 = pts[i]
				var p1: Vector2 = pts[i + 1]
				var nn: Vector2 = (p1 - p0).orthogonal().normalized()
				if nn.y > 0.0:
					nn = -nn
				var q0: Vector2 = p0 + nn * anchos[i] * 0.85
				var q1: Vector2 = p1 + nn * anchos[i + 1] * 0.85
				var t: Vector2 = nn * maxf(0.4, anchos[i] * 0.22)
				capa.draw_primitive(PackedVector2Array([q0 - t, q1, q0 + t]),
					PackedColorArray([Color(MagiaMayor.PINCEL, alfas[i]), Color(MagiaMayor.PINCEL, 0.0),
						Color(MagiaMayor.PINCEL, alfas[i])]), PackedVector2Array())
	# LAS GOTAS DE TINTA: se sueltan al pasar el cuerpo y caen apagandose.
	for g2 in _piezas:
		var u2: float = float(g2["u"])
		if u2 > u_h:
			continue
		var edad2: float = (u_h - u2) * _viaje + desde_cae
		var k: float = clampf(edad2 / (T_ESTELA_VIVE * 1.2), 0.0, 1.0)
		if k >= 1.0:
			continue
		var p2: Vector2 = _en_salto(u2) + lat * float(g2["lado"]) * grueso * 0.8 + Vector2(0.0, float(g2["cae"]) * k * k)
		MagiaMayor._disco(capa, p2, float(g2["r"]) * (1.0 - 0.4 * k), Color(MagiaMayor.NEGRO, 1.0 - k),
			Color(MagiaMayor.NEGRO, 0.0))


# UNA CINTA rellena por unos puntos, cada uno con su ancho y su alfa (sin rayas: una banda con degradado de alfa).
static func _cinta(ci: CanvasItem, pts: PackedVector2Array, anchos: PackedFloat32Array, alfas: PackedFloat32Array,
		col: Color) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	var d_prev: Vector2 = Vector2.RIGHT
	for i in n:
		var d: Vector2 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if d.length_squared() > 0.0001:
			d_prev = d.normalized()
		var nn: Vector2 = d_prev.orthogonal()
		pv.append(pts[i] + nn * anchos[i])
		pv.append(pts[i] - nn * anchos[i] * 0.7)
		pc.append(Color(col, alfas[i]))
		pc.append(Color(col, alfas[i] * 0.8))
	for i in n - 1:
		var b: int = i * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# EL VAHO DEL OLOR A SANGRE: un hilo de vaho rojo que sube ondulando desde la cabeza de quien sangra. No es una raya:
# bocanadas blandas encadenadas que suben sin parar (nacen abajo, se abren y se apagan arriba), con un nucleo mas vivo.
func _vaho(capa: Node2D) -> void:
	if capa != _delante:
		return
	var vivo: float = clampf(_t / 0.4, 0.0, 1.0)
	if _secando >= 0.0:
		vivo *= 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)
	if vivo <= 0.0:
		return
	var alto: float = _largo * 0.95
	var n: int = 16
	for hilo in 2:
		var fase: float = _incl + float(hilo) * 2.4
		var lado: float = (float(hilo) - 0.5) * _ancho * 0.18
		for i in n:
			var s: float = fposmod(float(i) / float(n) + _t * (0.32 + 0.06 * float(hilo)), 1.0)
			var x: float = sin(s * 5.0 - _t * 2.4 + fase) * _ancho * 0.22 * (0.35 + s)
			var p: Vector2 = _hasta + Vector2(lado * (1.0 - s) + x, -alto * s)
			# GORDAS Y QUE SE ABREN al subir: con bolitas finas el hilo se leia como una raya roja (efectos-sin-lineas).
			var r: float = _ancho * 0.17 * (0.7 + 0.6 * s) * (1.0 if hilo == 0 else 0.7)
			var a: float = vivo * sin(PI * s) * (0.42 if hilo == 0 else 0.3)
			BestiaAire._bola(capa, p, r * 1.8, Color(VAHO, a * 0.35))
			BestiaAire._bola(capa, p, r, Color(VAHO, a))
			BestiaAire._bola(capa, p, r * 0.45, Color(1.0, 0.45, 0.42, a * 0.7))


# ------------------------------------------------------------
#  LA ABERRACION
# ------------------------------------------------------------
# EL TENTACULO (basico y cada golpe del Latigazo): es PARTE DEL SPRITE (lo-que-sale-del-cuerpo-parece-sprite): de su
# morado, con su borde oscuro, el lomo mas claro y ventosas palidas por debajo. Brota del borde de su masa (cada golpe
# de un sitio: 'lado'), va en curva hasta quien recibe, RESTALLA (la curva se da la vuelta de golpe) y se recoge.
func _tentaculo(capa: Node2D) -> void:
	var dist: float = _o.distance_to(_hasta)
	if dist < 2.0:
		return
	var eje: Vector2 = (_hasta - _o) / dist
	var lat: Vector2 = eje.orthogonal()
	# Cuanto ha salido (0..1): brota mientras llega el golpe, se queda un momento y se recoge.
	var u: float
	if _t < 0.0:
		var k: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		u = 1.0 - (1.0 - k) * (1.0 - k)
	else:
		u = 1.0 - smoothstep(0.1, 0.3, _t)
	# EL RESTALLIDO: la panza de la curva pasa de un lado al otro justo en el golpe.
	var panza: float = lerpf(1.0, -0.7, smoothstep(-0.05, 0.05, _t)) * _lado
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.12:
			BarridoAire.destello(capa, _hasta, _tam * 1.6, Color(0.98, 0.9, 1.0, 0.8 * (1.0 - _t / 0.12)), eje.angle())
		return
	if capa != _delante:
		return
	# LA MARCA DEL AZOTE, detras del tentaculo: un verdugon rojo de lado a lado del cuerpo, que se va.
	if _t >= 0.0 and _t < 0.45:
		var km: float = _t / 0.45
		var a_m: Vector2 = _hasta - lat * _ancho * 0.45 + Vector2(0.0, -2.0)
		var b_m: Vector2 = _hasta + lat * _ancho * 0.45 + Vector2(0.0, 2.0)
		BarridoAire.cometa(capa, a_m, b_m, maxf(1.6, _ancho * 0.12), Color(0.85, 0.12, 0.16, 0.85 * (1.0 - km)))
	if u > 0.02:
		var ctrl: Vector2 = (_o + _hasta) * 0.5 + lat * dist * 0.32 * panza - Vector2(0.0, dist * 0.12)
		var n: int = 16
		var pts: Array = []
		for i in n + 1:
			var v: float = u * float(i) / float(n)
			var a: Vector2 = _o.lerp(ctrl, v)
			var b: Vector2 = ctrl.lerp(_hasta, v)
			pts.append(a.lerp(b, v))
		# Tres pasadas, como un sprite: el borde, la carne y el lomo con luz; y las ventosas por debajo.
		for pasada in 3:
			for i in pts.size():
				var f: float = float(i) / float(n)
				var r: float = lerpf(_tam, _tam * 0.35, f)
				var p: Vector2 = pts[i]
				match pasada:
					# El borde, solo fuera del cuerpo: en el arranque (dentro de su masa) seria un tubo pegado encima.
					0:
						if f > 0.18:
							BestiaAire._bola(capa, p, r + 0.9, _placa.darkened(0.7))
					1: BestiaAire._bola(capa, p, r, _placa)
					2: BestiaAire._bola(capa, p + Vector2(-0.2, -r * 0.35), r * 0.5, _placa_clara)
		for i in range(2, pts.size() - 1, 2):
			var f2: float = float(i) / float(n)
			BestiaAire._bola(capa, (pts[i] as Vector2) + Vector2(0.0, lerpf(_tam, _tam * 0.35, f2) * 0.45),
				maxf(0.6, _tam * 0.22 * (1.0 - f2 * 0.5)), Color(0.93, 0.8, 0.9))
	# EL RESTALLIDO en la punta: una media luna corta y palida atravesada al tentaculo, y la baba que salta y cae.
	if _t >= 0.0 and _t < 0.16:
		var kr: float = _t / 0.16
		var th: float = eje.angle() + PI * 0.5 * _lado
		BestiaAire._media_luna(capa, _hasta, th - 0.7, th + 0.7, _tam * (2.2 + 1.2 * kr), _tam * 0.8,
			Color(1.0, 0.95, 1.0), _placa_clara, 1.0 - kr, true)
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > 0.45:
			continue
		var kg: float = tg / 0.45
		var d: Vector2 = g["d"]
		var p2: Vector2 = _hasta + d * float(g["v"]) * kg + Vector2(0.0, 14.0 * kg * kg)
		BestiaAire._bola(capa, p2, float(g["r"]) * (1.0 - 0.3 * kg), Color(_placa.lightened(0.25), 1.0 - kg * kg))


# LA MIRADA DEL VACIO sobre quien la recibe: se le ABRE UN OJO encima de la cabeza (negro, la almendra de la
# oscuridad, con la pupila clara del eclipse: oscuridad-nuestro-lenguaje), le mira y se cierra; y el se encoge
# temblando (el miedo). El temblor lo pone aplicar_temblor.
func _ojo_mirada(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var abre: float = smoothstep(0.0, 0.12, _t) * (1.0 - smoothstep(0.38, 0.52, _t))
	if abre <= 0.01:
		return
	var w: float = maxf(_ancho * 1.1, 10.0)
	var h: float = w * 0.45 * abre
	var c: Vector2 = _hasta
	var arriba := PackedVector2Array()
	var abajo := PackedVector2Array()
	var halo_a := PackedVector2Array()
	var halo_b := PackedVector2Array()
	var n: int = 14
	for i in n + 1:
		var s: float = float(i) / float(n) * 2.0 - 1.0
		var alto: float = h * (1.0 - s * s)
		arriba.append(c + Vector2(s * w, -alto))
		abajo.append(c + Vector2(s * w, alto * 0.8))
		halo_a.append(c + Vector2(s * w * 1.25, -alto * 1.5 - 1.0))
		halo_b.append(c + Vector2(s * w * 1.25, alto * 1.3 + 1.0))
	BestiaAire._tira(capa, halo_a, halo_b, Color(MagiaMayor.ECLIPSE, 0.3 * abre))
	BestiaAire._tira(capa, arriba, abajo, Color(MagiaMayor.NEGRO, 0.95))
	# La pupila clara, que te mira. Se mueve un pelin (no es un dibujo quieto: esta mirando).
	var pup: Vector2 = c + Vector2(sin(_t * 9.0) * w * 0.12, 0.0)
	MagiaMayor._disco(capa, pup, h * 0.62, Color(MagiaMayor.ECLIPSE_CLARO, abre), Color(MagiaMayor.ECLIPSE, 0.0))
	MagiaMayor._disco(capa, pup, h * 0.28, Color(MagiaMayor.NEGRO, abre), Color(MagiaMayor.NEGRO, abre * 0.6))


# LA CARNE QUE SE CIERRA (al empezar su turno, si se cura): bultos de su carne que se hinchan y se hunden sobre ella,
# como pustulas que cierran las heridas; cada uno con su brillo humedo arriba.
func _pustulas(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > 0.5:
			continue
		var k: float = tg / 0.5
		var r: float = float(g["r"]) * sin(PI * minf(k * 1.3, 1.0))
		if r <= 0.4:
			continue
		var p: Vector2 = _o + Vector2(float(g["x"]) * _ancho, float(g["y"]) * _largo)
		# Con contraste: del mismo tono que la carne no se veian (burbujas palidas).
		MagiaMayor._disco(capa, p, r + 1.0, _placa.darkened(0.6), Color(_placa.darkened(0.6), 0.9))
		MagiaMayor._disco(capa, p, r, _placa.lightened(0.3), _placa.lightened(0.05))
		BestiaAire._bola(capa, p + Vector2(-r * 0.3, -r * 0.35), r * 0.35, Color(1.0, 0.9, 1.0, 0.8))


# LAS GRIETAS DE LUZ (mientras la luz le corta la cura): rajas doradas en su carne que chisporrotean. Se quedan hasta
# que vuelve a curarse (secar()).
func _grietas_luz(capa: Node2D) -> void:
	var vivo: float = clampf(_t / 0.3, 0.0, 1.0)
	if _secando >= 0.0:
		vivo *= 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)
	if vivo <= 0.0:
		return
	var late: float = 0.75 + 0.25 * sin(_t * 7.0 + _incl)
	for g in _lajas:
		var pts := PackedVector2Array()
		for q in (g["pts"] as PackedVector2Array):
			pts.append(_o + Vector2(q.x * _ancho, q.y * _largo))
		if capa == _brillo:
			for q2 in pts:
				BarridoAire.brillo(capa, q2, _ancho * 0.07, Color(1.0, 0.8, 0.35, 0.25 * vivo * late))
			continue
		if capa != _delante:
			continue
		# FINAS: gordas eran hojas doradas pegadas, no rajas.
		_raja(capa, pts, maxf(0.6, _ancho * 0.018), vivo * late)
	# Las chispas: suben de las rajas y se apagan.
	if capa != _delante:
		return
	for i in 5:
		var fase: float = fposmod(_t * 1.4 + float(i) * 0.21 + _incl, 1.0)
		var base_g: Dictionary = _lajas[i % _lajas.size()]
		var q3: Vector2 = (base_g["pts"] as PackedVector2Array)[int(fase * 7.0) % (base_g["pts"] as PackedVector2Array).size()]
		var p3: Vector2 = _o + Vector2(q3.x * _ancho, q3.y * _largo) - Vector2(0.0, fase * _largo * 0.35)
		BarridoAire.cometa(capa, p3 + Vector2(0.0, 2.5), p3, 1.1, Color(1.0, 0.88, 0.5, vivo * (1.0 - fase)))


# ------------------------------------------------------------
#  LA ABERRACION POR EL SUELO
# ------------------------------------------------------------
# LA MIRADA DEL VACIO por su cono: el ojo se ENCIENDE (el punto de luz del eclipse, alto, donde tiene el ojo) y por el
# cono avanzan tres medias lunas NEGRAS de lado a lado, con el pincel claro roto por delante, que se abren y se
# apagan al llegar (la Voragine, no un rayo).
func _cono_mirada(capa: Node2D) -> void:
	if _t < 0.0:
		return
	# SU OJO: el cono sale del frente de su cuerpo a ras de suelo; el ojo esta un poco mas atras y en alto.
	var ojo: Vector2 = _o - _dir * 9.0 - Vector2(0.0, 8.0)
	if capa == _brillo:
		if _t < 0.3:
			var ke: float = _t / 0.3
			BarridoAire.destello(capa, ojo, 7.0 + 5.0 * sin(PI * ke), Color(MagiaMayor.ECLIPSE_CLARO, 0.9 * (1.0 - ke)), 0.0)
		return
	if capa != _delante:
		return
	if _t < 0.3:
		MagiaMayor._disco(capa, ojo, 2.6 * (1.0 - _t / 0.3), Color(MagiaMayor.ECLIPSE_CLARO, 1.0), Color(MagiaMayor.ECLIPSE, 0.0))
	var mitad: float = _banda * 0.5
	for ola in 3:
		var to: float = _t - float(ola) * 0.08
		if to < 0.0:
			continue
		var k: float = clampf(to / T_CONO, 0.0, 1.0)
		var r: float = lerpf(8.0, _largo, 1.0 - (1.0 - k) * (1.0 - k))
		var alfa: float = (1.0 - smoothstep(0.7, 1.0, k)) * (1.0 - 0.2 * float(ola))
		if alfa <= 0.0:
			continue
		# GORDAS (a 2,5-7 eran rayitas negras que casi no se veian).
		var grueso: float = lerpf(6.0, 13.0, k) * (1.0 - 0.2 * float(ola))
		var n: int = 12
		var fuera := PackedVector2Array()
		var dentro := PackedVector2Array()
		var filo: Array = []
		for i in n + 1:
			var s: float = float(i) / float(n) * 2.0 - 1.0
			var a: float = _dir.angle() + s * mitad
			var w: float = grueso * (1.0 - s * s) * (0.85 + 0.3 * sin(float(i) * 2.1 + float(ola)))
			var d := Vector2(cos(a), sin(a))
			fuera.append(_o + d * (r + w * 0.5))
			dentro.append(_o + d * maxf(r - w, 0.0))
			filo.append([_o + d * (r + w * 0.5 + 1.0), w])
		BestiaAire._tira(capa, fuera, dentro, Color(MagiaMayor.NEGRO, alfa))
		for i in n:
			if sin(float(i) * 3.3 + float(ola) * 1.7) < 0.1:
				continue
			var p0: Vector2 = filo[i][0]
			var p1: Vector2 = filo[i + 1][0]
			var t2: Vector2 = (p1 - p0).normalized().orthogonal() * (0.4 + 0.9 * float(filo[i][1]) / maxf(grueso, 0.1))
			capa.draw_primitive(PackedVector2Array([p0 - t2, p1, p0 + t2]),
				PackedColorArray([Color(MagiaMayor.PINCEL, alfa), Color(MagiaMayor.PINCEL, 0.0), Color(MagiaMayor.PINCEL, alfa)]),
				PackedVector2Array())


# EL ALARIDO DEMENTE: frentes de sonido en CIRCULO COMPLETO alrededor de ella, pero ROTOS y DEFORMES (lo que "no
# deberias estar oyendo"): cada frente ondula fuerte, tiene huecos y tiembla, en un violeta enfermizo. El Chillido del
# rey rata, retorcido. Del filo claro y duro a nada hacia dentro, y un halo tenue por fuera.
func _alarido(capa: Node2D) -> void:
	if capa != _delante or _t < 0.0:
		return
	var alto := Vector2(0.0, -5.0)
	for k in 4:
		var tk: float = _t - float(k) * 0.09
		if tk < 0.0:
			continue
		var prog: float = clampf(tk / T_ALARIDO, 0.0, 1.0)
		var rf: float = _largo * (1.0 - (1.0 - prog) * (1.0 - prog))
		var apaga: float = clampf((tk - T_ALARIDO) / 0.2, 0.0, 1.0)
		var alfa: float = (0.85 - 0.14 * float(k)) * (1.0 - 0.35 * prog) * (1.0 - apaga)
		if alfa <= 0.0 or rf < 4.0:
			continue
		var grueso: float = lerpf(3.0, 6.5, prog)
		var ondula: float = 2.5 + 3.5 * prog
		var n: int = 48
		for i in n:
			var s0: float = float(i) / float(n)
			var s1: float = float(i + 1) / float(n)
			# LOS HUECOS: trozos del frente que no estan (cambian de sitio en cada frente).
			var roto0: float = sin(s0 * TAU * 3.0 + float(k) * 2.3 + _incl)
			if roto0 < -0.55:
				continue
			var a0: float = s0 * TAU
			var a1: float = s1 * TAU
			var w0: float = rf + sin(a0 * 5.0 + _t * 30.0 + float(k)) * ondula + sin(a0 * 13.0 - _t * 55.0) * ondula * 0.35
			var w1: float = rf + sin(a1 * 5.0 + _t * 30.0 + float(k)) * ondula + sin(a1 * 13.0 - _t * 55.0) * ondula * 0.35
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			var borde: float = clampf((roto0 + 0.55) / 0.4, 0.0, 1.0)
			var f0: Vector2 = _o + d0 * w0 + alto
			var f1: Vector2 = _o + d1 * w1 + alto
			var i0: Vector2 = _o + d0 * maxf(w0 - grueso, 0.0) + alto
			var i1: Vector2 = _o + d1 * maxf(w1 - grueso, 0.0) + alto
			var h0: Vector2 = _o + d0 * (w0 + grueso * 0.6) + alto
			var h1: Vector2 = _o + d1 * (w1 + grueso * 0.6) + alto
			var c0 := Color(ALARIDO_CLARO, alfa * borde)
			var nada := Color(ALARIDO, 0.0)
			capa.draw_primitive(PackedVector2Array([f0, f1, i1]), PackedColorArray([c0, c0, nada]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([f0, i1, i0]), PackedColorArray([c0, nada, nada]), PackedVector2Array())
			var hc := Color(ALARIDO, alfa * borde * 0.35)
			capa.draw_primitive(PackedVector2Array([f0, f1, h1]), PackedColorArray([hc, hc, nada]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([f0, h1, h0]), PackedColorArray([hc, nada, nada]), PackedVector2Array())


# UNA RAJA DE LUZ rellena (no una raya): cada tramo es una cuña dorada, gorda en medio de la raja y afilada en las
# puntas, con el nucleo casi blanco.
static func _raja(ci: CanvasItem, pts: PackedVector2Array, w: float, alfa: float) -> void:
	var n: int = pts.size()
	if n < 2 or alfa <= 0.0:
		return
	for capa_r in 2:
		var ancho: float = w * (1.0 if capa_r == 0 else 0.45)
		var col: Color = Color(1.0, 0.76, 0.28, alfa) if capa_r == 0 else Color(1.0, 0.97, 0.82, alfa)
		for i in n - 1:
			var s0: float = float(i) / float(n - 1)
			var s1: float = float(i + 1) / float(n - 1)
			var g0: float = ancho * sin(PI * s0) + 0.2
			var g1: float = ancho * sin(PI * s1) + 0.2
			var d: Vector2 = (pts[i + 1] - pts[i]).normalized().orthogonal()
			ci.draw_primitive(PackedVector2Array([pts[i] - d * g0, pts[i + 1] - d * g1, pts[i + 1] + d * g1, pts[i] + d * g0]),
				PackedColorArray([col, col, col, col]), PackedVector2Array())
