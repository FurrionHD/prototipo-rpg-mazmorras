# ============================================================
#  magia_aire.gd
#  LOS EFECTOS DE LAS MAGIAS en el mapa (26/09/2026, las comunes de 1 frase; los eligio el usuario):
#  POR EL SUELO (SueloRoto: la ficha del hechizo dice cual en SpellData.suelo_mapa; MAGIA_* en el orden de Modo):
#    ALIENTO   Brasa: un aliento de dragon. BOCANADAS de fuego que salen de la mano y se abren por el cono, crecen,
#              suben en puntas y se hacen humo (blancas por dentro, rojas por fuera), humo oscuro detras y el suelo
#              ennegrecido con ascuas que se apagan.
#    LLUVIA    Rocio: una nube baja sobre la franja y una lluvia fuerte que la recorre desde ti; cada gota salpica
#              al caer y deja charcos que luego se secan.
#    ORBE      Pulso menor: una bolita violeta con estela que va recta; en el primero revienta en un anillo
#              relleno y un destello. ORBE_FALLA: no habia nadie, se apaga al final del recorrido.
#    BOLA      Descarga: una bola electrica chisporroteando hasta el primero; revienta en un fogonazo y de ella
#              salen los ARCOS de la cadena. BOLA_FALLA: se deshace en chispas.
#    ANDANADA  Andanada ignea: cuatro bolas de fuego caen del cielo, una tras otra, en sus puntos del circulo
#              (puntos_andanada); su sombra crece en el suelo antes y cada una revienta en una bocanada.
#    OLA       Torrente: una ola de verdad se levanta delante de ti y recorre la franja, con cresta de espuma y
#              rociada por delante; detras deja el suelo mojado. Arrastra (el empuje lo pone la ficha).
#    RAYO_CIELO Rayo: un relampago cae del cielo sobre el primero (fogonazo, onda y chamusquina); de ahi salen los
#              ARCOS de la cadena.
#    HELICE    Pulso arcano (su dibujo): DOS orbes que avanzan girando uno alrededor del otro y se cruzan (doble
#              helice); se juntan al llegar y revientan dos veces. HELICE_FALLA: se apagan al final.
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa):
#    ARCO      el salto de una cadena: un rayo quebrado RELLENO de pecho a pecho que chisporrotea.
#    CURA      Vendaje de luz: una columna de luz calida cae sobre el aliado, una venda de luz le rodea el pecho
#              y suben destellos.
#    MALDICION Debilidad: una niebla violeta cae sobre el enemigo y lo aplasta (galones hacia abajo, anillo que
#              se cierra a sus pies, gotas oscuras).
#    FORTALECER Fortaleza: un aura roja sube por el cuerpo (galones hacia arriba, anillo que se abre, destello).
#    FILO      los Filos: el elemento viaja en arco de tu mano a su arma y revienta en ella.
#  Y POR EL SUELO, tambien:
#    LAVA      Mar de brasas: el suelo se raja desde ti, las grietas se llenan de lava, salen llamas y luego se
#              enfria (rojo -> negro).
#    JABALINA  Venablo de tormenta: dos lanzas de rayo, una tras otra, rectas al primero; revientan en chispazos.
#    MIASMA    Debilidad (26/09: "no hay un efecto previo que dispare la debilidad"): una bola de maldicion baja sobre
#              el centro del circulo, revienta y una ola de miasma se abre por el suelo; a cada uno le entra la
#              MALDICION (sobre el cuerpo) cuando le alcanza.
#    ONDA_FUERZA Fortaleza (lo mismo, 26/09): concentras el poder (motas rojas que se juntan en tu pecho), un
#              fogonazo y una onda de fuerza sale de ti por el suelo; a cada uno de los tuyos le entra el aura
#              (FORTALECER) cuando le llega.
#  NADA DE LINEAS peladas (bandas rellenas con halo, cometas y destellos de BarridoAire). Coordenadas de MUNDO;
#  el suelo SIN achatar; lo que va en el aire, a su altura por K. Todo sale de una semilla.
# ============================================================
extends Node2D
class_name MagiaAire

# Los del suelo van en el orden de SueloRoto.Tipo.MAGIA_*: no reordenar.
enum Modo { ALIENTO, LLUVIA, ORBE, BOLA, ORBE_FALLA, BOLA_FALLA, ANDANADA, OLA, RAYO_CIELO, HELICE, HELICE_FALLA,
	LAVA, JABALINA, JABALINA_FALLA, MIASMA, ONDA_FUERZA,
	ARCO, CURA, MALDICION, FORTALECER, FILO }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ALTO_MANO := 12.0          # a que altura sale lo que lanzas (la mano)
const ALTO_PECHO := 13.0

# EL ALIENTO
const T_ALIENTO := 0.34          # lo que tarda el frente de llama en llegar al fondo del cono
const T_SOSTIENE := 0.22         # lo que se queda entero
const T_RECOGE := 0.3            # y lo que tarda la cola en alcanzar al frente (se va hacia delante)
const BOCANADAS := 30
const T_EMITE := 0.5             # lo que dura el soplo (salen bocanadas todo ese rato)
const T_VIAJE_BOCANADA := 0.34   # lo que tarda una bocanada en llegar a su sitio (la primera, al fondo: T_ALIENTO)
const FUEGO_OSCURO := Color(0.42, 0.07, 0.03)
const FUEGO_BLANCO := Color(1.0, 0.97, 0.78)
const FUEGO_AMARILLO := Color(1.0, 0.82, 0.3)
const FUEGO_NARANJA := Color(1.0, 0.5, 0.1)
const FUEGO_ROJO := Color(0.85, 0.16, 0.04)
const HUMO := Color(0.13, 0.11, 0.11)
const CHAMUSCADO := Color(0.05, 0.03, 0.02)

# LA LLUVIA
const T_FRENTE := 0.32           # lo que tarda la lluvia en recorrer la franja desde ti
const T_LLUEVE := 1.0            # lo que llueve en total
const T_CAIDA := 0.16            # lo que tarda una gota en caer
const ALTO_NUBE := 46.0
const GOTAS := 170
const AGUA := Color(0.55, 0.78, 1.0)
const AGUA_CLARA := Color(0.88, 0.95, 1.0)
const CHARCO := Color(0.22, 0.42, 0.78)
const NUBE := Color(0.2, 0.24, 0.34)
const NUBE_LUZ := Color(0.46, 0.53, 0.66)

# EL ORBE Y LA BOLA
const V_ORBE := 380.0
const V_BOLA := 300.0
const T_REVIENTA := 0.3
const ARCANO := Color(0.66, 0.46, 1.0)
const ARCANO_CLARO := Color(0.92, 0.86, 1.0)
const RAYO := Color(1.0, 0.9, 0.25)
const RAYO_CLARO := Color(1.0, 1.0, 0.86)

# LA ANDANADA
const T_ENTRE_BOLAS := 0.1       # entre una bola y la siguiente
const T_CAE_BOLA := 0.24         # lo que tarda una bola en caer
const ALTO_CAIDA := 95.0

# LA OLA
const T_OLA := 0.55              # lo que tarda en recorrer la franja
const ALTO_OLA := 30.0
const AGUA_HONDA := Color(0.12, 0.3, 0.7)
const ESPUMA := Color(0.93, 0.97, 1.0)

# EL RAYO DEL CIELO
const T_RAYO_CAE := 0.08
const ALTO_RAYO := 120.0

# LA HELICE
const V_HELICE := 260.0
const AMPLITUD_HELICE := 11.0
const PASO_HELICE := 46.0        # px que avanza en una vuelta entera

# LA LAVA
const T_LAVA := 0.8              # lo que tarda el frente de lava en llegar al fondo (se ve avanzar, como el martillo)
# Cada trozo vive a SU ritmo desde que se abre (se abre desde ti hacia delante y se va igual): arde, se enfria y
# se deshace en polvo.
const T_VIVE_LAVA := 0.9
const T_ENFRIA_LAVA := 0.5
const T_DESHACE_LAVA := 0.45
const LAVA := Color(1.0, 0.45, 0.08)
const LAVA_CLARA := Color(1.0, 0.85, 0.35)
const COSTRA := Color(0.16, 0.06, 0.04)

# LA JABALINA
const V_JABALINA := 520.0
const T_ENTRE_LANZAS := 0.1

# LA MIASMA (la Debilidad por el suelo)
const T_CAE_MALDICION := 0.3
const T_EXPANDE := 0.32
const ALTO_MALDICION := 70.0

# LA ONDA DE FUERZA (la Fortaleza por el suelo)
const T_CARGA := 0.24
const T_ONDA_FUERZA := 0.3

# LA MALDICION Y LA FORTALEZA
const T_SOBRE := 0.8
const MALDITO := Color(0.55, 0.3, 0.75)
const MALDITO_OSCURO := Color(0.16, 0.06, 0.22)
const FUERZA := Color(1.0, 0.42, 0.22)
const FUERZA_CLARA := Color(1.0, 0.85, 0.6)

# LA CURA
const T_CURA := 0.95
const LUZ_CALIDA := Color(1.0, 0.9, 0.55)
const LUZ_BLANCA := Color(1.0, 0.99, 0.92)

# EL ARCO
const T_ARCO := 0.28
const T_REJITTER := 0.045

var modo: int = Modo.ORBE
var forma: CombatFormas.Forma = null
var color: Color = RAYO
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _semilla: int = 1
var _o: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _lat: Vector2 = Vector2.DOWN
var _r: float = 30.0
var _largo: float = 60.0
var _ancho: float = 30.0
var _humos: Array = []
var _bocanadas: Array = []
var _manchas: Array = []
var _ascuas: Array = []
var _chispas: Array = []
var _gotas: Array = []
var _charcos: Array = []
var _nubes: Array = []
var _motas: Array = []
var _puntos: Array = []
# El arco.
var _desde: Vector2 = Vector2.ZERO
var _hasta: Vector2 = Vector2.ZERO
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# LA ANDANADA: donde cae cada bola dentro del circulo apuntado. Sale SOLO de la forma (su centro, en la rejilla
# de 1/16 en la que viaja por red), asi que quien resuelve, el dibujo y el espejo sacan los mismos puntos.
const R_BOLA := 16.0
const BOLAS := 4

static func puntos_andanada(f: CombatFormas.Forma) -> Array:
	var out: Array = []
	if f == null:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(f.centro.x * 16.0), roundi(f.centro.y * 16.0)))
	var r: float = maxf(f.radio - R_BOLA * 0.5, 4.0)
	var intentos: int = 0
	while out.size() < BOLAS and intentos < 60:
		intentos += 1
		var a: float = rng.randf_range(0.0, TAU)
		var d: float = r * sqrt(rng.randf())
		var p: Vector2 = f.centro + Vector2(cos(a), sin(a)) * d
		var lejos: bool = true
		for q in out:
			if (q as Vector2).distance_to(p) < R_BOLA * 1.3:
				lejos = false
				break
		if lejos or intentos > 45:
			out.append(p)
	return out


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> MagiaAire:
	if padre == null or f == null:
		return null
	var e := MagiaAire.new()
	e.modo = m
	e.forma = f
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._preparar_area()
	return e


# CUANDO LE LLEGA a 'p', en segundos desde que se lanza.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	var o: Vector2 = SueloRoto.origen_de(f)
	match m:
		Modo.ALIENTO:
			return clampf(p.distance_to(o) / maxf(f.radio, 1.0), 0.0, 1.0) * T_ALIENTO
		Modo.LLUVIA:
			var a: float = clampf((p - o).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0)
			return a * T_FRENTE + T_CAIDA
		Modo.ORBE, Modo.ORBE_FALLA:
			return maxf(0.0, (p - o).dot(f.dir)) / V_ORBE
		Modo.BOLA, Modo.BOLA_FALLA:
			return maxf(0.0, (p - o).dot(f.dir)) / V_BOLA
		Modo.ANDANADA:
			# La bola MAS CERCANA a 'p' (la que le cae encima).
			var pts: Array = puntos_andanada(f)
			var mejor: int = 0
			for i in pts.size():
				if (pts[i] as Vector2).distance_squared_to(p) < (pts[mejor] as Vector2).distance_squared_to(p):
					mejor = i
			return T_ENTRE_BOLAS * float(mejor) + T_CAE_BOLA
		Modo.OLA:
			return clampf((p - o).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0) * T_OLA
		Modo.RAYO_CIELO:
			return T_RAYO_CAE
		Modo.HELICE, Modo.HELICE_FALLA:
			return maxf(0.0, (p - o).dot(f.dir)) / V_HELICE
		Modo.LAVA:
			return clampf((p - o).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0) * T_LAVA + 0.08
		Modo.JABALINA, Modo.JABALINA_FALLA:
			return maxf(0.0, (p - o).dot(f.dir)) / V_JABALINA
		Modo.MIASMA:
			return T_CAE_MALDICION + clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0) * T_EXPANDE
		Modo.ONDA_FUERZA:
			return T_CARGA + clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0) * T_ONDA_FUERZA
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.ALIENTO: return T_ALIENTO
		Modo.LLUVIA: return T_FRENTE + T_CAIDA
		Modo.ANDANADA: return T_ENTRE_BOLAS * float(BOLAS - 1) + T_CAE_BOLA
		Modo.OLA: return T_OLA
		Modo.RAYO_CIELO: return T_RAYO_CAE
		Modo.LAVA: return T_LAVA
		Modo.MIASMA: return T_CAE_MALDICION + T_EXPANDE
		Modo.ONDA_FUERZA: return T_CARGA + T_ONDA_FUERZA
	return 0.3


func duracion() -> float:
	match modo:
		Modo.ALIENTO: return T_ALIENTO + T_SOSTIENE + T_RECOGE + 1.3
		Modo.LLUVIA: return T_LLUEVE + 1.8
		Modo.ORBE, Modo.ORBE_FALLA: return _largo / V_ORBE + T_REVIENTA + 0.5
		Modo.BOLA, Modo.BOLA_FALLA: return _largo / V_BOLA + T_REVIENTA + 0.7
		Modo.ANDANADA: return T_ENTRE_BOLAS * float(BOLAS - 1) + T_CAE_BOLA + 1.3
		Modo.OLA: return T_OLA + 1.6
		Modo.RAYO_CIELO: return T_RAYO_CAE + 0.9
		Modo.HELICE, Modo.HELICE_FALLA: return _largo / V_HELICE + T_REVIENTA + 0.5
		Modo.LAVA: return T_LAVA + T_VIVE_LAVA + T_ENFRIA_LAVA + T_DESHACE_LAVA + 0.4
		Modo.JABALINA, Modo.JABALINA_FALLA: return _largo / V_JABALINA + T_ENTRE_LANZAS + T_REVIENTA + 0.5
		Modo.MIASMA: return T_CAE_MALDICION + T_EXPANDE + 1.1
		Modo.ONDA_FUERZA: return T_CARGA + T_ONDA_FUERZA + 0.8
		Modo.ARCO: return T_ARCO + 0.05
		Modo.CURA: return T_CURA
		Modo.MALDICION, Modo.FORTALECER: return T_SOBRE
		Modo.FILO: return 0.75
	return 1.0


func _preparar_area() -> void:
	_o = SueloRoto.origen_de(forma)
	_dir = forma.dir.normalized() if forma.dir.length_squared() > 0.0001 else Vector2.RIGHT
	_lat = _dir.orthogonal()
	_r = maxf(forma.radio, 8.0)
	_largo = maxf(forma.largo if forma.tipo == CombatFormas.Tipo.LINEA else forma.radio, 4.0)
	_ancho = maxf(forma.ancho, 8.0)
	match modo:
		Modo.ALIENTO:
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			for i in BOCANADAS:
				var lado: float = -1.0 if _rng.randf() < 0.5 else 1.0
				_bocanadas.append({"t0": T_EMITE * float(i) / float(BOCANADAS) + _rng.randf_range(0.0, 0.03),
					"a": lado * pow(_rng.randf(), 1.3) * mitad * 0.8, "u": _rng.randf_range(0.82, 1.02),
					"vida": _rng.randf_range(0.45, 0.6), "tam": _rng.randf_range(0.8, 1.2), "fase": _rng.randf_range(0.0, 50.0)})
			# La primera sale derecha y llega al fondo: marca el frente (lo que dice retraso).
			_bocanadas[0]["t0"] = 0.0
			_bocanadas[0]["a"] = 0.0
			_bocanadas[0]["u"] = 1.0
			for i in 16:
				var u: float = _rng.randf_range(0.15, 1.0)
				_humos.append({"u": u, "a": _rng.randf_range(-mitad, mitad) * 0.8, "t0": u * T_ALIENTO + _rng.randf_range(0.05, 0.3),
					"r": _rng.randf_range(4.0, 8.0), "sube": _rng.randf_range(12.0, 24.0), "vida": _rng.randf_range(0.7, 1.1)})
			for i in 12:
				var u2: float = _rng.randf_range(0.2, 0.95)
				_manchas.append({"u": u2, "a": _rng.randf_range(-mitad, mitad) * 0.85, "r": _rng.randf_range(5.0, 10.0)})
			for i in 26:
				var u3: float = _rng.randf_range(0.15, 1.0)
				_ascuas.append({"u": u3, "a": _rng.randf_range(-mitad, mitad) * 0.9, "tam": _rng.randf_range(0.8, 1.6),
					"fase": _rng.randf_range(0.0, TAU), "vida": _rng.randf_range(0.9, 1.5)})
			for i in 12:
				var u4: float = _rng.randf_range(0.3, 1.0)
				_chispas.append({"u": u4, "a": _rng.randf_range(-mitad, mitad) * 0.8, "t0": u4 * T_ALIENTO + _rng.randf_range(0.0, 0.3),
					"v": Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-55.0, -30.0))})
		Modo.LLUVIA:
			for i in GOTAS:
				var u: float = _rng.randf()
				var llega: float = u * T_FRENTE
				_gotas.append({"u": u, "v": _rng.randf_range(-0.5, 0.5), "t0": llega + _rng.randf_range(0.0, maxf(0.05, T_LLUEVE - llega - T_CAIDA)),
					"largo": _rng.randf_range(11.0, 17.0)})
			var n_ch: int = int(clampf(_largo / 18.0, 5.0, 12.0))
			for i in n_ch:
				var u2: float = (float(i) + _rng.randf_range(0.1, 0.9)) / float(n_ch)
				_charcos.append({"u": u2, "v": _rng.randf_range(-0.32, 0.32), "r": _rng.randf_range(5.0, 10.0),
					"ex": _rng.randf_range(0.7, 1.3), "giro": _rng.randf_range(0.0, PI)})
			var n_nu: int = int(clampf(_largo / 14.0, 6.0, 14.0))
			for i in n_nu:
				_nubes.append({"u": (float(i) + 0.5) / float(n_nu), "v": _rng.randf_range(-0.25, 0.25),
					"r": _rng.randf_range(0.34, 0.5) * _ancho, "fase": _rng.randf_range(0.0, TAU)})
		Modo.ANDANADA:
			_puntos = puntos_andanada(forma)
			for i in 20:
				_ascuas.append({"b": i % maxi(_puntos.size(), 1), "a": _rng.randf_range(0.0, TAU),
					"d": _rng.randf_range(2.0, R_BOLA * 0.9), "tam": _rng.randf_range(0.8, 1.5),
					"fase": _rng.randf_range(0.0, TAU), "vida": _rng.randf_range(0.7, 1.2)})
		Modo.OLA:
			for i in 26:
				_gotas.append({"v": _rng.randf_range(-0.5, 0.5), "t0": _rng.randf_range(0.0, T_OLA * 0.95),
					"vel": Vector2(_rng.randf_range(40.0, 80.0), _rng.randf_range(-50.0, -20.0)), "largo": _rng.randf_range(4.0, 7.0)})
			for i in int(clampf(_largo / 14.0, 8.0, 16.0)):
				_charcos.append({"u": (float(i) + _rng.randf_range(0.1, 0.9)) / clampf(_largo / 14.0, 8.0, 16.0),
					"v": _rng.randf_range(-0.38, 0.38), "r": _rng.randf_range(5.0, 11.0)})
		Modo.ONDA_FUERZA:
			for i in 12:
				var a2: float = _rng.randf_range(0.0, TAU)
				_motas.append({"a": a2, "d": _rng.randf_range(16.0, 28.0), "t0": _rng.randf_range(0.0, 0.1),
					"tam": _rng.randf_range(1.2, 2.0)})
			for i in 10:
				_humos.append({"a": _rng.randf_range(0.0, TAU), "r": _rng.randf_range(4.0, 7.0), "vida": _rng.randf_range(0.4, 0.6)})
		Modo.MIASMA:
			for i in 14:
				var a: float = _rng.randf_range(0.0, TAU)
				_humos.append({"a": a, "d": _rng.randf_range(0.35, 1.0), "r": _rng.randf_range(5.0, 9.0),
					"fase": _rng.randf_range(0.0, TAU), "vida": _rng.randf_range(0.6, 0.95)})
		Modo.LAVA:
			# EL SUELO QUE SE RAJA EN LOSAS (26/09, sus referencias: piedra oscura rota y la lava brillando por las
			# grietas). Celdas de Voronoi dentro de la franja, encogidas: el hueco entre losas es la grieta, y por
			# el se ve la malla de lava que va debajo.
			_charcos = _losas_de_la_franja()
			for i in 26:
				_motas.append({"u": _rng.randf_range(0.05, 0.97), "v": _rng.randf_range(-0.38, 0.38),
					"t0": _rng.randf_range(0.0, 1.3), "r": _rng.randf_range(2.0, 4.0)})
			for i in 16:
				_bocanadas.append({"u": _rng.randf_range(0.03, 0.98), "v": _rng.randf_range(-0.4, 0.4),
					"t0": _rng.randf_range(0.0, 0.3), "vida": _rng.randf_range(0.45, 0.7), "tam": _rng.randf_range(0.9, 1.5),
					"fase": _rng.randf_range(0.0, 50.0)})
			for i in 30:
				_ascuas.append({"u": _rng.randf_range(0.0, 1.0), "v": _rng.randf_range(-0.45, 0.45), "tam": _rng.randf_range(0.8, 1.5),
					"fase": _rng.randf_range(0.0, TAU), "vida": _rng.randf_range(1.2, 1.9)})
			# LOS GEISERES de lava.
			for i in 6:
				_gotas.append({"u": (float(i) + _rng.randf_range(0.2, 0.8)) / 6.0, "v": _rng.randf_range(-0.3, 0.3),
					"t0": _rng.randf_range(0.02, 0.12), "fuerza": _rng.randf_range(90.0, 130.0), "giro": _rng.randf_range(-0.3, 0.3)})
			# LAS PIEDRAS que salta el frente al abrirse (como el suelo que rompe el martillo).
			for i in 22:
				_chispas.append({"u": _rng.randf_range(0.02, 1.0), "v": _rng.randf_range(-0.4, 0.4),
					"vel": Vector2(_rng.randf_range(10.0, 30.0), _rng.randf_range(-70.0, -40.0)), "tam": _rng.randf_range(1.4, 2.6),
					"piedra": _rng.randf() < 0.6})
		Modo.RAYO_CIELO:
			for i in 7:
				var a: float = _rng.randf_range(0.0, TAU)
				_motas.append({"d": Vector2(cos(a), sin(a) * K), "v": _rng.randf_range(25.0, 55.0), "tam": _rng.randf_range(1.0, 1.8)})
		Modo.ORBE, Modo.ORBE_FALLA, Modo.BOLA, Modo.BOLA_FALLA, Modo.HELICE, Modo.HELICE_FALLA, Modo.JABALINA, Modo.JABALINA_FALLA:
			for i in 7:
				var a: float = _rng.randf_range(0.0, TAU)
				_motas.append({"d": Vector2(cos(a), sin(a) * K), "v": _rng.randf_range(20.0, 45.0), "tam": _rng.randf_range(1.0, 1.8)})
	_suelo = _capa(SueloRoto.Z_SUELO, false)
	_delante = _capa(Z_ENCIMA, false)
	_brillo = _capa(Z_ENCIMA + 1, true)


# ------------------------------------------------------------
#  SOBRE UN CUERPO: el arco de una cadena, de pecho a pecho
# ------------------------------------------------------------
static func arco(padre: Node, desde: Vector2, hasta: Vector2, col: Color, semilla: int, espera: float,
		ritmo: float) -> MagiaAire:
	if padre == null:
		return null
	var e := MagiaAire.new()
	e.modo = Modo.ARCO
	e.color = col
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._desde = desde
	e._hasta = hasta
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# LA MALDICION y la FORTALEZA sobre un cuerpo ('caja').
static func sobre_cuerpo(padre: Node, m: int, caja: Rect2, col: Color, semilla: int, espera: float, ritmo: float) -> MagiaAire:
	if padre == null:
		return null
	var e := MagiaAire.new()
	e.modo = m
	e.color = col
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._desde = Vector2(caja.get_center().x, caja.end.y)
	e._hasta = caja.get_center()
	e._ancho = maxf(caja.size.x, 10.0)
	e._largo = maxf(caja.size.y, 16.0)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	for i in 8:
		e._motas.append({"x": e._rng.randf_range(-0.55, 0.55), "t0": e._rng.randf_range(0.0, 0.45),
			"tam": e._rng.randf_range(2.5, 4.0)})
	e._suelo = e._capa(SueloRoto.Z_SUELO, m == Modo.FORTALECER)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# EL FILO: de 'desde' (el pecho de quien lo lanza) al arma de quien lo recibe ('caja', su cuerpo).
static func filo(padre: Node, desde: Vector2, caja: Rect2, col: Color, semilla: int, espera: float, ritmo: float) -> MagiaAire:
	if padre == null:
		return null
	var e := MagiaAire.new()
	e.modo = Modo.FILO
	e.color = col
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	# El viaje ocupa el vuelo: sale 'espera' segundos antes de llegar.
	e._t = -maxf(espera, 0.0)
	e._largo = maxf(espera, 0.05)
	e._desde = desde
	e._hasta = caja.get_center() + Vector2(caja.size.x * 0.35, 0.0)   # por la mano del arma
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# EL VENDAJE DE LUZ sobre un aliado: 'caja' = su cuerpo.
static func cura(padre: Node, caja: Rect2, semilla: int, espera: float, ritmo: float) -> MagiaAire:
	if padre == null:
		return null
	var e := MagiaAire.new()
	e.modo = Modo.CURA
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._desde = Vector2(caja.get_center().x, caja.end.y)   # sus pies
	e._hasta = caja.get_center()                          # su pecho
	e._ancho = maxf(caja.size.x, 10.0)
	e._largo = maxf(caja.size.y, 16.0)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	for i in 9:
		e._motas.append({"x": e._rng.randf_range(-0.6, 0.6), "t0": e._rng.randf_range(0.1, 0.55),
			"sube": e._rng.randf_range(18.0, 30.0), "tam": e._rng.randf_range(3.0, 5.5)})
	e._suelo = e._capa(SueloRoto.Z_SUELO, true)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


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


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
static func _alto(h: float) -> Vector2:
	return Vector2(0.0, -h * K)


static func _ruido(x: float, k: float) -> float:
	return fmod(absf(sin(x * 12.9898 + k * 78.233) * 43758.5453), 1.0)


# UNA LENGUA: banda rellena a lo largo de 'pts', con su ancho y sus dos colores en cada punto (borde y nucleo). A lo
# ancho: transparente, borde, nucleo, borde, transparente. Va en un solo triangle_array.
static func _lengua(ci: CanvasItem, pts: PackedVector2Array, anchos: PackedFloat32Array, bordes: PackedColorArray,
		nucleos: PackedColorArray) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for i in n:
		var d: Vector2 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		var nor: Vector2 = d.normalized().orthogonal() if d.length_squared() > 0.0001 else Vector2.UP
		var w: float = anchos[i]
		var cb: Color = bordes[i]
		var offs: Array = [-w, -w * 0.45, 0.0, w * 0.45, w]
		var cols: Array = [Color(cb, 0.0), cb, nucleos[i], cb, Color(cb, 0.0)]
		for j in 5:
			pv.append(pts[i] + nor * offs[j])
			pc.append(cols[j])
	for i in n - 1:
		var b: int = i * 5
		for j in 4:
			pi.append_array([b + j, b + j + 1, b + 5 + j, b + j + 1, b + 6 + j, b + 5 + j])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# UNA BOCANADA DE FUEGO en 'c' de radio 'r' y edad 'k' (0 nace, 1 se apaga). Silueta irregular que cambia a saltos
# (como el fuego de pixel-art: pocas formas, no un borron) y se estira hacia ARRIBA en puntas; tres capas de dentro
# a fuera: blanca, amarilla/naranja y roja. Al envejecer se oscurece hasta hacerse humo.
func _bocanada(ci: CanvasItem, c: Vector2, r: float, k: float, fase: float) -> void:
	var paso: float = floor(_t * 14.0) + fase
	var n: int = 14
	var contorno := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a))
		var rr: float = r * (0.8 + 0.3 * _ruido(float(i) + paso * 3.1, fase))
		if d.y < -0.2:
			# Arriba: la llama sube, y una de cada tres es una punta.
			rr *= 1.0 + 0.35 * (-d.y) + (0.45 * (-d.y) if (i + int(paso)) % 3 == 0 else 0.0)
		contorno.append(Vector2(d.x * rr, d.y * rr * (1.15 if d.y < 0.0 else 0.8)))
	var vida: float = 1.0 - smoothstep(0.7, 1.0, k)
	var viejo: float = smoothstep(0.35, 0.85, k)
	var capas: Array = [
		[1.0, FUEGO_NARANJA.lerp(FUEGO_OSCURO, viejo), FUEGO_ROJO.lerp(HUMO, viejo), 0.72],
		[0.62, FUEGO_AMARILLO.lerp(FUEGO_ROJO, viejo), FUEGO_NARANJA.lerp(FUEGO_OSCURO, viejo), 0.95],
		[0.32, FUEGO_BLANCO, FUEGO_AMARILLO, 1.0 - smoothstep(0.15, 0.45, k)]]
	for cp in capas:
		var esc: float = float(cp[0])
		var alfa: float = float(cp[3]) * vida
		if alfa <= 0.01:
			continue
		var pv := PackedVector2Array([c + Vector2(0.0, r * 0.12 * (1.0 - esc))])
		var pc := PackedColorArray([Color(cp[1] as Color, alfa)])
		var pi := PackedInt32Array()
		for i in n:
			pv.append(c + contorno[i] * esc + Vector2(0.0, r * 0.12 * (1.0 - esc)))
			pc.append(Color(cp[2] as Color, alfa))
		for i in n:
			pi.append_array([0, 1 + i, 1 + (i + 1) % n])
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# Un anillo RELLENO que se difumina hacia dentro y hacia fuera (la onda de un impacto). En el suelo: sin achatar.
static func _anillo(ci: CanvasItem, c: Vector2, r: float, grueso: float, col: Color, achata: float = 1.0) -> void:
	if r <= 0.3 or col.a <= 0.0:
		return
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	var n: int = 28
	var radios: Array = [maxf(0.0, r - grueso), r, r + grueso * 0.6]
	var cols: Array = [Color(col, 0.0), col, Color(col, 0.0)]
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a) * achata)
		for j in 3:
			pv.append(c + d * radios[j])
			pc.append(cols[j])
	for i in n:
		var b0: int = i * 3
		var b1: int = ((i + 1) % n) * 3
		for j in 2:
			pi.append_array([b0 + j, b0 + j + 1, b1 + j, b0 + j + 1, b1 + j + 1, b1 + j])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# Un rayo QUEBRADO relleno de 'a' a 'b' (halo ancho del color y nucleo blanco fino). 'sem' cambia el quiebro.
static func _quebrado(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, claro: Color, sem: float, tramos: int,
		desvio: float, grueso: float, alfa: float) -> void:
	var pts := PackedVector2Array()
	var d: Vector2 = b - a
	var nor: Vector2 = d.normalized().orthogonal() if d.length_squared() > 0.01 else Vector2.UP
	for i in tramos + 1:
		var u: float = float(i) / float(tramos)
		var j: float = 0.0 if i == 0 or i == tramos else (_ruido(sem + float(i), 3.1) - 0.5) * 2.0 * desvio
		pts.append(a + d * u + nor * j)
	var anchos := PackedFloat32Array()
	var bordes := PackedColorArray()
	var nucleos := PackedColorArray()
	for i in pts.size():
		var u2: float = float(i) / float(tramos)
		var afila: float = 0.55 + 0.45 * sin(u2 * PI)
		anchos.append(grueso * afila)
		bordes.append(Color(col, 0.55 * alfa))
		nucleos.append(Color(claro, alfa))
	_lengua(ci, pts, anchos, bordes, nucleos)


# ------------------------------------------------------------
#  EL DIBUJO
# ------------------------------------------------------------
func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.ALIENTO: _aliento(capa)
		Modo.LLUVIA: _lluvia(capa)
		Modo.ORBE, Modo.ORBE_FALLA: _orbe(capa)
		Modo.BOLA, Modo.BOLA_FALLA: _bola(capa)
		Modo.ANDANADA: _andanada(capa)
		Modo.OLA: _ola(capa)
		Modo.RAYO_CIELO: _rayo_cielo(capa)
		Modo.HELICE, Modo.HELICE_FALLA: _helice(capa)
		Modo.LAVA: _lava(capa)
		Modo.MIASMA: _miasma(capa)
		Modo.ONDA_FUERZA: _onda_fuerza(capa)
		Modo.JABALINA, Modo.JABALINA_FALLA: _jabalina(capa)
		Modo.ARCO: _arco(capa)
		Modo.CURA: _cura(capa)
		Modo.MALDICION, Modo.FORTALECER: _sobre(capa)
		Modo.FILO: _filo(capa)


# Un punto del cono en el suelo: a la fraccion 'u' del radio y 'a' radianes del eje.
func _en_cono(u: float, a: float) -> Vector2:
	return _o + _dir.rotated(a) * _r * u


func _aliento(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	var frente: float = 1.0 - pow(1.0 - clampf(_t / T_ALIENTO, 0.0, 1.0), 2.0)
	var t_fin: float = T_ALIENTO + T_SOSTIENE
	var cola: float = clampf((_t - t_fin) / T_RECOGE, 0.0, 1.0)
	cola = cola * cola
	var vivo: bool = cola < 1.0
	if capa == _suelo:
		# EL SUELO ENNEGRECIDO: manchas por donde ya ha pasado el frente, que se apagan despacio.
		var apaga: float = 1.0 - clampf((_t - t_fin - 0.4) / 1.2, 0.0, 1.0)
		for m in _manchas:
			var u: float = float(m["u"])
			if u > frente:
				continue
			var p: Vector2 = _en_cono(u, float(m["a"]))
			BarridoAire.brillo(capa, p, float(m["r"]), Color(CHAMUSCADO, 0.42 * apaga))
		# Y las ASCUAS: puntitos que laten y se apagan.
		for a2 in _ascuas:
			var u2: float = float(a2["u"])
			var t_a: float = _t - u2 * T_ALIENTO
			if t_a < 0.0:
				continue
			var vida: float = 1.0 - clampf((t_a - 0.3) / float(a2["vida"]), 0.0, 1.0)
			if vida <= 0.0:
				continue
			var late: float = 0.6 + 0.4 * sin(_t * 11.0 + float(a2["fase"]))
			var p2: Vector2 = _en_cono(u2, float(a2["a"]))
			BarridoAire.brillo(capa, p2, float(a2["tam"]) * 2.4, Color(FUEGO_NARANJA, 0.55 * vida * late))
			BarridoAire.brillo(capa, p2, float(a2["tam"]), Color(FUEGO_AMARILLO, vida * late))
		return
	if capa == _delante:
		# EL HUMO, detras del fuego: bocanadas oscuras que suben y se abren.
		for h in _humos:
			var th: float = _t - float(h["t0"])
			if th < 0.0:
				continue
			var k: float = th / float(h["vida"])
			if k >= 1.0:
				continue
			var p: Vector2 = _en_cono(float(h["u"]), float(h["a"])) + _alto(ALTO_MANO + float(h["sube"]) * k)
			BarridoAire.brillo(capa, p, float(h["r"]) * (1.3 + 1.5 * k), Color(HUMO, 0.62 * sin(k * PI)))
		if not vivo:
			return
		# LAS BOCANADAS DE FUEGO (26/09: las lenguas "parecen lineas hacia delante"): bolas de llama irregulares
		# que salen de la mano, crecen y se frenan al avanzar, con puntas que suben; al envejecer se oscurecen y
		# se hacen humo. Primero las viejas (las de lejos): las nuevas, junto a la mano, van encima.
		for b in _bocanadas:
			var tb: float = _t - float(b["t0"])
			if tb < 0.0:
				continue
			var k: float = tb / float(b["vida"])
			if k >= 1.0:
				continue
			var viaje: float = 1.0 - pow(1.0 - clampf(tb / T_VIAJE_BOCANADA, 0.0, 1.0), 2.0)
			var u: float = float(b["u"]) * viaje
			var c: Vector2 = _en_cono(u, float(b["a"])) + _alto(ALTO_MANO * (1.0 - 0.35 * u) + 10.0 * k * k)
			var r: float = (2.0 + u * _r * tan(mitad) * 0.36) * float(b["tam"]) * (0.7 + 0.5 * minf(1.0, tb / 0.12))
			_bocanada(capa, c, r, k, float(b["fase"]))
		return
	if capa == _brillo:
		if vivo:
			# El resplandor del fuego, suave, a lo largo del eje.
			for j in 5:
				var u: float = (float(j) + 0.5) / 5.0 * frente
				if u < cola * frente:
					continue
				BarridoAire.brillo(capa, _en_cono(u, 0.0) + _alto(ALTO_MANO * 0.8), _r * 0.28, Color(FUEGO_NARANJA, 0.22))
			BarridoAire.brillo(capa, _o + _alto(ALTO_MANO), 7.0, Color(FUEGO_AMARILLO, 0.5 * (1.0 - cola)))
		# CHISPAS que saltan hacia arriba.
		for c in _chispas:
			var tc: float = _t - float(c["t0"])
			if tc < 0.0 or tc > 0.55:
				continue
			var p0: Vector2 = _en_cono(float(c["u"]), float(c["a"])) + _alto(ALTO_MANO)
			var v: Vector2 = c["v"]
			var p1: Vector2 = p0 + v * tc + Vector2(0.0, 60.0 * tc * tc)
			var p_ant: Vector2 = p0 + v * maxf(0.0, tc - 0.06)
			BarridoAire.cometa(capa, p_ant, p1, 1.3, Color(FUEGO_AMARILLO, 1.0 - tc / 0.55))


func _lluvia(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var sale: float = clampf(_t / 0.2, 0.0, 1.0)
	var fin: float = 1.0 - clampf((_t - T_LLUEVE) / 0.5, 0.0, 1.0)
	if capa == _suelo:
		# EL SUELO MOJADO: una sombra fria por donde ha pasado la lluvia, y los charcos que crecen y se secan.
		var frente: float = clampf(_t / T_FRENTE, 0.0, 1.0)
		var seca: float = 1.0 - clampf((_t - T_LLUEVE) / 1.6, 0.0, 1.0)
		for ch in _charcos:
			var u: float = float(ch["u"])
			if u > frente:
				continue
			var crece: float = clampf((_t - u * T_FRENTE) / 0.6, 0.0, 1.0)
			var c: Vector2 = _o + _dir * _largo * u + _lat * _ancho * float(ch["v"])
			var r: float = float(ch["r"]) * (0.4 + 0.6 * crece)
			BarridoAire.brillo(capa, c, r * 1.35, Color(CHARCO, 0.5 * seca))
			_anillo(capa, c, r * 0.9, 1.4, Color(AGUA, 0.35 * seca))
			BarridoAire.brillo(capa, c + Vector2(-r * 0.3, -r * 0.25), r * 0.4, Color(AGUA_CLARA, 0.4 * seca))
		# Las SALPICADURAS de cada gota al llegar al suelo: un anillito que se abre.
		for g in _gotas:
			var tg: float = _t - float(g["t0"]) - T_CAIDA
			if tg < 0.0 or tg > 0.22:
				continue
			var p: Vector2 = _o + _dir * _largo * float(g["u"]) + _lat * _ancho * float(g["v"])
			_anillo(capa, p, 1.5 + 5.0 * (tg / 0.22), 1.5, Color(AGUA_CLARA, 0.85 * (1.0 - tg / 0.22)))
			# y dos gotitas que saltan
			for sj in 2:
				var ds: float = -1.0 if sj == 0 else 1.0
				var ps: Vector2 = p + _lat * ds * 4.0 * (tg / 0.22) + _alto(10.0 * sin(tg / 0.22 * PI))
				BarridoAire.brillo(capa, ps, 1.1, Color(AGUA_CLARA, 0.8 * (1.0 - tg / 0.22)))
		return
	if capa == _delante:
		# LA NUBE, baja, sobre la franja: bultos oscuros y blandos que se forman desde ti y se deshacen al final.
		for nu in _nubes:
			var u: float = float(nu["u"])
			var llega: float = clampf((_t - u * T_FRENTE * 0.8) / 0.25, 0.0, 1.0)
			if llega <= 0.0:
				continue
			var c: Vector2 = _o + _dir * _largo * u + _lat * _ancho * float(nu["v"]) + _alto(ALTO_NUBE) \
				+ Vector2(sin(_t * 1.3 + float(nu["fase"])) * 1.5, 0.0)
			var r: float = float(nu["r"]) * (0.7 + 0.3 * llega)
			BarridoAire.brillo(capa, c, r * 1.1, Color(NUBE, 0.8 * llega * fin))
			BarridoAire.brillo(capa, c + Vector2(r * 0.15, -r * 0.35), r * 0.62, Color(NUBE_LUZ, 0.55 * llega * fin))
		# LAS GOTAS cayendo: cometas finas de la nube al suelo.
		for g in _gotas:
			var tg: float = _t - float(g["t0"])
			if tg < 0.0 or tg > T_CAIDA:
				continue
			var p: Vector2 = _o + _dir * _largo * float(g["u"]) + _lat * _ancho * float(g["v"])
			var h: float = ALTO_NUBE * (1.0 - tg / T_CAIDA)
			var cabeza: Vector2 = p + _alto(h)
			BarridoAire.cometa(capa, cabeza + Vector2(0.0, -float(g["largo"])), cabeza, 1.7, Color(AGUA_CLARA, 0.95 * sale))
		return
	if capa == _brillo:
		# Un velo de agua fresca sobre la franja mientras llueve.
		var n: int = int(clampf(_largo / 22.0, 3.0, 9.0))
		for j in n:
			var u: float = (float(j) + 0.5) / float(n)
			if u > clampf(_t / T_FRENTE, 0.0, 1.0):
				continue
			BarridoAire.brillo(capa, _o + _dir * _largo * u + _alto(ALTO_NUBE * 0.4), _ancho * 0.55, Color(AGUA, 0.07 * fin))


# Donde va el proyectil a los 't' segundos (en el aire, a la altura de la mano).
func _pos_proyectil(t: float, v: float) -> Vector2:
	var d: float = clampf(t * v, 0.0, _largo)
	return _o + _dir * (6.0 + d) + _alto(ALTO_MANO)


func _orbe(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var t_llega: float = _largo / V_ORBE
	var falla: bool = modo == Modo.ORBE_FALLA
	if _t < t_llega:
		if capa == _brillo:
			var p: Vector2 = _pos_proyectil(_t, V_ORBE)
			# La ESTELA: tres cometas que se difuminan, un pelo separadas, y motas que se quedan atras.
			for j in 3:
				var off: Vector2 = _lat * (float(j) - 1.0) * 1.6
				BarridoAire.cometa(capa, p - _dir * (38.0 - 9.0 * absf(float(j) - 1.0)) + off * 1.6, p + off, 5.0 - 1.5 * absf(float(j) - 1.0),
					Color(ARCANO, 0.6))
			BarridoAire.brillo(capa, p, 14.0, Color(ARCANO, 0.5))
			BarridoAire.brillo(capa, p, 5.5, Color(ARCANO_CLARO, 1.0))
			BarridoAire.destello(capa, p, 10.0, Color(ARCANO_CLARO, 0.65), _t * 8.0)
			for k in 4:
				var tk: float = _t - float(k) * 0.05
				if tk < 0.0:
					continue
				var pk: Vector2 = _pos_proyectil(tk, V_ORBE) + _lat * sin(float(k) * 2.3 + _t * 20.0) * 3.0
				BarridoAire.brillo(capa, pk, 1.6, Color(ARCANO_CLARO, 0.5 - 0.1 * float(k)))
		return
	var tr: float = _t - t_llega
	var fin: Vector2 = _pos_proyectil(t_llega, V_ORBE)
	var k2: float = clampf(tr / T_REVIENTA, 0.0, 1.0)
	if falla:
		# NO HABIA NADIE: el orbe se encoge y se apaga en una bocanada.
		if capa == _brillo and k2 < 1.0:
			BarridoAire.brillo(capa, fin, 8.0 * (1.0 - k2), Color(ARCANO, 0.4 * (1.0 - k2)))
			BarridoAire.brillo(capa, fin, 3.5 * (1.0 - k2), Color(ARCANO_CLARO, 1.0 - k2))
		return
	if capa == _brillo:
		# EL CHOQUE: anillo relleno que se abre, destello en estrella y motas que salen y caen.
		if tr < 0.1:
			BarridoAire.brillo(capa, fin, 22.0 * (1.0 - tr / 0.1), Color(ARCANO_CLARO, 0.5 * (1.0 - tr / 0.1)))
		_anillo(capa, fin, 4.0 + 22.0 * (1.0 - pow(1.0 - k2, 2.0)), 4.5, Color(ARCANO, 0.85 * (1.0 - k2)), K)
		BarridoAire.destello(capa, fin, 22.0 * (1.0 - k2 * 0.6), Color(ARCANO_CLARO, 1.0 - k2), 0.4)
		for m in _motas:
			var tm: float = tr
			if tm > 0.45:
				continue
			var pm: Vector2 = fin + (m["d"] as Vector2) * float(m["v"]) * tm + Vector2(0.0, 40.0 * tm * tm)
			BarridoAire.brillo(capa, pm, float(m["tam"]), Color(ARCANO_CLARO, 1.0 - tm / 0.45))
	elif capa == _suelo:
		var suelo_p: Vector2 = fin - _alto(ALTO_MANO)
		BarridoAire.brillo(capa, suelo_p, 10.0, Color(ARCANO, 0.25 * (1.0 - clampf(tr / 0.6, 0.0, 1.0))))


func _bola(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var t_llega: float = _largo / V_BOLA
	var falla: bool = modo == Modo.BOLA_FALLA
	var chispa: float = floor(_t / T_REJITTER)
	if _t < t_llega:
		if capa == _brillo:
			var p: Vector2 = _pos_proyectil(_t, V_BOLA)
			BarridoAire.cometa(capa, p - _dir * 26.0, p, 5.0, Color(RAYO, 0.4))
			BarridoAire.brillo(capa, p, 16.0, Color(RAYO, 0.45 + 0.2 * _ruido(chispa, 1.0)))
			BarridoAire.brillo(capa, p, 6.0, Color(RAYO_CLARO, 1.0))
			# El chisporroteo: rayitos quebrados que salen de la bola y cambian cada poco.
			for j in 6:
				var a: float = TAU * _ruido(chispa + float(j) * 7.0, 2.0)
				var q: Vector2 = p + Vector2(cos(a), sin(a) * K) * (10.0 + 8.0 * _ruido(chispa, float(j)))
				_quebrado(capa, p, q, RAYO, RAYO_CLARO, chispa * 13.0 + float(j), 3, 2.8, 2.2, 0.95)
		return
	var tr: float = _t - t_llega
	var fin: Vector2 = _pos_proyectil(t_llega, V_BOLA)
	var k2: float = clampf(tr / T_REVIENTA, 0.0, 1.0)
	if falla:
		if capa == _brillo and k2 < 1.0:
			BarridoAire.brillo(capa, fin, 9.0 * (1.0 - k2), Color(RAYO, 0.35 * (1.0 - k2)))
			for j in 3:
				var a2: float = TAU * _ruido(chispa + float(j) * 5.0, 4.0)
				_quebrado(capa, fin, fin + Vector2(cos(a2), sin(a2) * K) * 8.0 * (1.0 - k2), RAYO, RAYO_CLARO,
					chispa * 11.0 + float(j), 3, 2.0, 1.4, 1.0 - k2)
		return
	if capa == _brillo:
		# EL REVENTON: fogonazo, onda y chispas quebradas hacia fuera.
		if tr < 0.12:
			BarridoAire.brillo(capa, fin, 26.0 * (1.0 - tr / 0.12), Color(RAYO_CLARO, 0.55 * (1.0 - tr / 0.12)))
		_anillo(capa, fin, 4.0 + 16.0 * (1.0 - pow(1.0 - k2, 2.0)), 3.0, Color(RAYO, 0.75 * (1.0 - k2)), K)
		BarridoAire.destello(capa, fin, 20.0 * (1.0 - k2 * 0.5), Color(RAYO_CLARO, 1.0 - k2), 0.3)
		if tr < 0.22:
			for j in 6:
				var a3: float = TAU * float(j) / 6.0 + _ruido(float(_semilla), float(j)) * 0.8
				var largo_c: float = 10.0 + 8.0 * _ruido(float(j), 9.0)
				_quebrado(capa, fin, fin + Vector2(cos(a3), sin(a3) * K) * largo_c * (0.5 + tr / 0.22 * 0.5), RAYO, RAYO_CLARO,
					chispa * 17.0 + float(j), 4, 2.6, 1.8, 1.0 - tr / 0.22)
	elif capa == _suelo:
		var suelo_p: Vector2 = fin - _alto(ALTO_MANO)
		var apaga: float = 1.0 - clampf(tr / 0.9, 0.0, 1.0)
		BarridoAire.brillo(capa, suelo_p, 11.0, Color(CHAMUSCADO, 0.4 * apaga))
		BarridoAire.brillo(capa, suelo_p, 6.0, Color(RAYO, 0.3 * apaga * apaga))


func _arco(capa: Node2D) -> void:
	# El salto aparece un pelo antes del impacto y chisporrotea un rato: cambia de quiebro cada T_REJITTER.
	if _t < -0.04 or capa != _brillo:
		return
	var k: float = clampf((_t + 0.04) / T_ARCO, 0.0, 1.0)
	var alfa: float = (1.0 - k) * (0.7 + 0.3 * _ruido(floor(_t / T_REJITTER), 5.0))
	var claro: Color = color.lerp(Color.WHITE, 0.75)
	var sem: float = floor(_t / T_REJITTER) * 29.0 + float(_semilla % 97)
	var largo: float = _desde.distance_to(_hasta)
	var tramos: int = clampi(int(largo / 9.0), 4, 12)
	_quebrado(capa, _desde, _hasta, color, claro, sem, tramos, clampf(largo * 0.09, 2.5, 7.0), 3.4, alfa)
	# Una rama suelta que sale del medio.
	var medio: Vector2 = _desde.lerp(_hasta, 0.45 + 0.2 * _ruido(sem, 1.0))
	var rama: Vector2 = medio + (_hasta - _desde).normalized().rotated(0.9 * (1.0 if _ruido(sem, 2.0) < 0.5 else -1.0)) * 9.0
	_quebrado(capa, medio, rama, color, claro, sem + 5.0, 3, 2.0, 1.8, alfa * 0.7)
	if _t >= 0.0:
		var k2: float = clampf(_t / 0.18, 0.0, 1.0)
		BarridoAire.destello(capa, _hasta, 11.0 * (1.0 - k2 * 0.5), Color(claro, 1.0 - k2), sem)


# ------------------------------------------------------------
#  LA ANDANADA: bolas de fuego del cielo
# ------------------------------------------------------------
func _andanada(capa: Node2D) -> void:
	if _t < 0.0:
		return
	for i in _puntos.size():
		var p: Vector2 = _puntos[i]
		var t0: float = T_ENTRE_BOLAS * float(i)
		var tb: float = _t - t0
		if tb < 0.0:
			continue
		var cae: float = clampf(tb / T_CAE_BOLA, 0.0, 1.0)
		var tr: float = tb - T_CAE_BOLA   # desde que revienta
		if capa == _suelo:
			if tr < 0.0:
				# LA SOMBRA de la bola, que crece y se oscurece segun baja.
				BarridoAire.brillo(capa, p, 4.0 + 8.0 * cae, Color(CHAMUSCADO, 0.45 * cae))
			else:
				var apaga: float = 1.0 - clampf((tr - 0.3) / 1.0, 0.0, 1.0)
				BarridoAire.brillo(capa, p, R_BOLA * 1.05, Color(CHAMUSCADO, 0.5 * apaga))
				if tr < 0.35:
					_anillo(capa, p, 3.0 + R_BOLA * 1.3 * (1.0 - pow(1.0 - tr / 0.35, 2.0)), 3.0, Color(FUEGO_NARANJA, 0.7 * (1.0 - tr / 0.35)))
			continue
		if capa == _delante:
			if tr < 0.0:
				# LA BOLA cayendo: cola de fuego hacia arriba y humo detras.
				var alto: float = ALTO_CAIDA * (1.0 - cae * cae)
				var c: Vector2 = p + _alto(alto)
				BarridoAire.cometa(capa, c + _alto(26.0), c, 5.0, Color(FUEGO_ROJO, 0.55))
				BarridoAire.cometa(capa, c + _alto(16.0), c, 3.2, Color(FUEGO_AMARILLO, 0.8))
				_bocanada(capa, c, 5.0, 0.1, float(i) * 7.0)
			elif tr < 0.5:
				# EL REVENTON: una bocanada que se abre y se hace humo.
				var k: float = tr / 0.5
				_bocanada(capa, p + _alto(4.0 + 10.0 * k), 5.0 + R_BOLA * 0.9 * (1.0 - pow(1.0 - k, 2.0)), k, float(i) * 13.0)
			continue
		if capa == _brillo:
			if tr < 0.0:
				BarridoAire.brillo(capa, p + _alto(ALTO_CAIDA * (1.0 - cae * cae)), 10.0, Color(FUEGO_NARANJA, 0.4))
			elif tr < 0.2:
				BarridoAire.brillo(capa, p + _alto(5.0), R_BOLA * 1.6 * (1.0 - tr / 0.2), Color(FUEGO_AMARILLO, 0.5 * (1.0 - tr / 0.2)))
				BarridoAire.destello(capa, p + _alto(6.0), 14.0 * (1.0 - tr / 0.2), Color(FUEGO_BLANCO, 1.0 - tr / 0.2), float(i))
	# LAS ASCUAS de cada reventon.
	if capa == _suelo:
		for a in _ascuas:
			var b: int = int(a["b"])
			if b >= _puntos.size():
				continue
			var tr2: float = _t - T_ENTRE_BOLAS * float(b) - T_CAE_BOLA
			if tr2 < 0.0:
				continue
			var vida: float = 1.0 - clampf((tr2 - 0.2) / float(a["vida"]), 0.0, 1.0)
			if vida <= 0.0:
				continue
			var late: float = 0.6 + 0.4 * sin(_t * 11.0 + float(a["fase"]))
			var q: Vector2 = (_puntos[b] as Vector2) + Vector2(cos(float(a["a"])), sin(float(a["a"]))) * float(a["d"])
			BarridoAire.brillo(capa, q, float(a["tam"]) * 2.4, Color(FUEGO_NARANJA, 0.5 * vida * late))
			BarridoAire.brillo(capa, q, float(a["tam"]), Color(FUEGO_AMARILLO, vida * late))


# ------------------------------------------------------------
#  LA OLA: agua que se levanta y recorre la franja
# ------------------------------------------------------------
func _ola(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var k: float = clampf(_t / T_OLA, 0.0, 1.0)
	var frente: float = _largo * k
	var rompe: float = clampf((_t - T_OLA) / 0.3, 0.0, 1.0)   # al llegar al fondo se desploma
	var n: int = 14
	if capa == _suelo:
		# EL SUELO MOJADO detras de la ola, y charcos que se secan.
		var seca: float = 1.0 - clampf((_t - T_OLA) / 1.5, 0.0, 1.0)
		for ch in _charcos:
			var u: float = float(ch["u"])
			if u * _largo > frente:
				continue
			var c: Vector2 = _o + _dir * _largo * u + _lat * _ancho * float(ch["v"])
			BarridoAire.brillo(capa, c, float(ch["r"]) * 1.4, Color(CHARCO, 0.45 * seca))
			BarridoAire.brillo(capa, c + Vector2(-2.0, -2.0), float(ch["r"]) * 0.4, Color(AGUA_CLARA, 0.35 * seca))
		return
	if capa == _delante:
		if rompe >= 1.0:
			return
		# LA OLA SIN CORTES (26/09: "no es muy cortado directamente?"): a lo ancho se redondea (alta y opaca en el
		# centro, baja y transparente en los lados), el frente se curva (el centro va delante) y ondula, la base se
		# funde con el agua de detras y la lamina se deshace por los bordes.
		var alto: float = ALTO_OLA * (0.55 + 0.45 * sin(minf(k * 3.0, 1.0) * PI * 0.5)) * (1.0 - rompe)
		var fondo: float = 44.0
		var apaga: float = 1.0 - rompe
		var pv := PackedVector2Array()
		var pc := PackedColorArray()
		var pi := PackedInt32Array()
		# LA LAMINA DE AGUA que arrastra detras, de ti a la ola: una rejilla que se difumina a los lados y hacia ti.
		var cols: int = 10
		var filas_l: int = 6
		var hasta: float = maxf(0.0, frente - fondo * 0.6)
		for j in cols + 1:
			var v: float = lerpf(-0.5, 0.5, float(j) / float(cols))
			for f in filas_l + 1:
				var q: float = float(f) / float(filas_l)
				var ancho_q: float = 0.85 + 0.15 * sin(q * 7.0 + _t * 6.0 + v * 3.0)
				pv.append(_o + _dir * hasta * q + _lat * _ancho * 1.15 * v * ancho_q)
				pc.append(Color(AGUA, 0.4 * pow(cos(v * PI), 0.8) * q * apaga))
		for j in cols:
			for f in filas_l:
				var a0: int = j * (filas_l + 1) + f
				var b0: int = (j + 1) * (filas_l + 1) + f
				pi.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])
		RenderingServer.canvas_item_add_triangle_array(capa.get_canvas_item(), pi, pv, pc)
		# EL CUERPO: de la base (atras, en el suelo, transparente) a la cresta (delante, en alto).
		pv = PackedVector2Array()
		pc = PackedColorArray()
		pi = PackedInt32Array()
		var filas: int = 5
		for j in n + 1:
			var v: float = lerpf(-0.5, 0.5, float(j) / float(n))
			var perfil: float = pow(cos(v * PI), 0.35)
			var curva: float = -10.0 * pow(v * 2.0, 2.0)   # el centro por delante
			var ondula: float = sin(v * 9.0 + _t * 10.0) * 2.5 + sin(v * 17.0 - _t * 7.0) * 1.2
			for f in filas + 1:
				var q: float = float(f) / float(filas)   # 0 atras (suelo) .. 1 cresta
				var d: float = maxf(0.0, frente - fondo * (1.0 - q) + (curva + ondula) * q)
				var h: float = alto * perfil * sin(q * PI * 0.5)
				pv.append(_o + _dir * d + _lat * _ancho * 1.2 * v * (0.9 + 0.1 * q) + _alto(h))
				pc.append(Color(AGUA_HONDA.lerp(AGUA, q), (0.25 + 0.7 * q) * q * perfil * apaga))
		for j in n:
			for f in filas:
				var a: int = j * (filas + 1) + f
				var b: int = (j + 1) * (filas + 1) + f
				pi.append_array([a, a + 1, b, a + 1, b + 1, b])
		RenderingServer.canvas_item_add_triangle_array(capa.get_canvas_item(), pi, pv, pc)
		# LA CRESTA DE ESPUMA: gorda en el centro y afilada hacia los lados, siguiendo la curva del frente.
		var cresta := PackedVector2Array()
		var anchos := PackedFloat32Array()
		var bordes := PackedColorArray()
		var nucleos := PackedColorArray()
		for j in n + 1:
			var v2: float = lerpf(-0.5, 0.5, float(j) / float(n))
			var perfil2: float = pow(cos(v2 * PI), 0.35)
			var curva2: float = -10.0 * pow(v2 * 2.0, 2.0)
			var ondula2: float = sin(v2 * 9.0 + _t * 10.0) * 2.5 + sin(v2 * 17.0 - _t * 7.0) * 1.2
			cresta.append(_o + _dir * maxf(0.0, frente + curva2 + ondula2) + _lat * _ancho * 1.2 * v2 + _alto(alto * perfil2 + 1.5))
			anchos.append(0.5 + 4.2 * perfil2)
			bordes.append(Color(AGUA_CLARA, 0.8 * perfil2 * apaga))
			nucleos.append(Color(ESPUMA, perfil2 * apaga))
		_lengua(capa, cresta, anchos, bordes, nucleos)
		# Motas de espuma que se desprenden por la cara de la ola.
		for j in 7:
			var v3: float = lerpf(-0.36, 0.36, float(j) / 6.0) + sin(_t * 5.0 + float(j)) * 0.03
			var perfil3: float = pow(cos(v3 * PI), 0.6)
			var q3: float = 0.55 + 0.35 * (0.5 + 0.5 * sin(_t * 13.0 + float(j) * 2.1))
			var p3: Vector2 = _o + _dir * maxf(0.0, frente - fondo * (1.0 - q3) - 10.0 * pow(v3 * 2.0, 2.0) * q3) + _lat * _ancho * v3 \
				+ _alto(alto * perfil3 * sin(q3 * PI * 0.5))
			BarridoAire.brillo(capa, p3, 2.4, Color(ESPUMA, 0.55 * perfil3 * apaga))
		return
	if capa == _brillo:
		# LA ROCIADA que salta por delante de la cresta.
		for g in _gotas:
			var tg: float = _t - float(g["t0"])
			if tg < 0.0 or tg > 0.35:
				continue
			var base: Vector2 = _o + _dir * (_largo * clampf(float(g["t0"]) / T_OLA, 0.0, 1.0)) + _lat * _ancho * float(g["v"]) \
				+ _alto(ALTO_OLA * 0.9)
			var vel: Vector2 = g["vel"]
			var pos: Vector2 = base + _dir * vel.x * tg + Vector2(0.0, vel.y * tg + 90.0 * tg * tg)
			var ant: Vector2 = base + _dir * vel.x * maxf(0.0, tg - 0.05) + Vector2(0.0, vel.y * maxf(0.0, tg - 0.05))
			BarridoAire.cometa(capa, ant, pos, 1.6, Color(ESPUMA, 0.9 * (1.0 - tg / 0.35)))
		# Y el desplome al fondo: una salpicadura grande.
		if rompe > 0.0 and rompe < 1.0:
			var fin: Vector2 = _o + _dir * _largo
			for j in 5:
				var v3: float = lerpf(-0.4, 0.4, float(j) / 4.0)
				BarridoAire.brillo(capa, fin + _lat * _ancho * v3 + _alto(8.0 * (1.0 - rompe)), 9.0 * (1.0 + rompe), Color(AGUA_CLARA, 0.3 * (1.0 - rompe)))


# ------------------------------------------------------------
#  EL RAYO DEL CIELO
# ------------------------------------------------------------
func _rayo_cielo(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var p: Vector2 = forma.centro
	var tr: float = _t - T_RAYO_CAE
	var chispa: float = floor(_t / T_REJITTER)
	if capa == _suelo:
		if tr >= 0.0:
			var apaga: float = 1.0 - clampf(tr / 0.9, 0.0, 1.0)
			BarridoAire.brillo(capa, p, 14.0, Color(CHAMUSCADO, 0.5 * apaga))
			if tr < 0.3:
				_anillo(capa, p, 4.0 + 22.0 * (1.0 - pow(1.0 - tr / 0.3, 2.0)), 3.0, Color(RAYO, 0.75 * (1.0 - tr / 0.3)))
		return
	if capa != _brillo:
		return
	if tr < 0.0:
		# EL AVISO: un hilo tenue que tantea desde arriba antes del golpe.
		var baja: float = clampf(_t / T_RAYO_CAE, 0.0, 1.0)
		_quebrado(capa, p + _alto(ALTO_RAYO), p + _alto(ALTO_RAYO * (1.0 - baja)), RAYO, RAYO_CLARO, chispa * 7.0, 8, 5.0, 1.4, 0.45)
		return
	if tr < 0.3:
		# EL RELAMPAGO: grueso, chisporroteando, y se apaga a tirones.
		var alfa: float = (1.0 - tr / 0.3) * (0.65 + 0.35 * _ruido(chispa, 3.0))
		_quebrado(capa, p + _alto(ALTO_RAYO), p, RAYO, RAYO_CLARO, chispa * 11.0, 12, 7.0, 6.5, alfa)
		# Una rama suelta.
		var medio: Vector2 = p + _alto(ALTO_RAYO * (0.45 + 0.2 * _ruido(chispa, 4.0)))
		_quebrado(capa, medio, medio + Vector2((12.0 if _ruido(chispa, 5.0) < 0.5 else -12.0), 14.0), RAYO, RAYO_CLARO,
			chispa * 5.0, 4, 3.0, 2.4, alfa * 0.7)
	if tr < 0.14:
		BarridoAire.brillo(capa, p + _alto(8.0), 34.0 * (1.0 - tr / 0.14), Color(RAYO_CLARO, 0.55 * (1.0 - tr / 0.14)))
	if tr < 0.3:
		BarridoAire.destello(capa, p + _alto(4.0), 24.0 * (1.0 - tr / 0.3 * 0.6), Color(RAYO_CLARO, 1.0 - tr / 0.3), 0.3)
	# Chispas que saltan del sitio.
	if tr < 0.4:
		for m in _motas:
			var pm: Vector2 = p + (m["d"] as Vector2) * float(m["v"]) * tr + Vector2(0.0, -30.0 * tr + 60.0 * tr * tr)
			BarridoAire.brillo(capa, pm, float(m["tam"]), Color(RAYO_CLARO, 1.0 - tr / 0.4))


# ------------------------------------------------------------
#  LA HELICE: dos orbes que giran uno alrededor del otro
# ------------------------------------------------------------
# Donde va el orbe 'cual' (0/1) a los 't' segundos: avanza por la linea y gira alrededor del eje (a lo ancho en el
# suelo y en altura), el otro medio giro por detras. Al llegar se juntan (la amplitud se cierra al final).
func _pos_helice(t: float, cual: int) -> Vector2:
	var d: float = clampf(t * V_HELICE, 0.0, _largo)
	var fase: float = d / PASO_HELICE * TAU + PI * float(cual)
	var cierra: float = clampf((_largo - d) / 20.0, 0.0, 1.0) * clampf(d / 10.0, 0.0, 1.0)
	var a: float = AMPLITUD_HELICE * cierra
	return _o + _dir * (6.0 + d) + _lat * sin(fase) * a + _alto(ALTO_MANO + cos(fase) * a * 0.8)


func _helice(capa: Node2D) -> void:
	if _t < 0.0 or capa != _brillo:
		return
	var t_llega: float = _largo / V_HELICE
	var falla: bool = modo == Modo.HELICE_FALLA
	if _t < t_llega:
		for cual in 2:
			var p: Vector2 = _pos_helice(_t, cual)
			var fase: float = clampf(_t * V_HELICE, 0.0, _largo) / PASO_HELICE * TAU + PI * float(cual)
			var delante: float = 0.75 + 0.25 * cos(fase)   # el de detras, un pelo mas apagado
			# La ESTELA: sigue la espiral, a trocitos de cometa.
			for k in 8:
				var ta: float = _t - float(k + 1) * 0.02
				var tb: float = _t - float(k) * 0.02
				if ta < 0.0:
					break
				BarridoAire.cometa(capa, _pos_helice(ta, cual), _pos_helice(tb, cual), 5.0 - 0.6 * float(k),
					Color(ARCANO, 0.55 * delante * (1.0 - float(k) / 6.0)))
			BarridoAire.brillo(capa, p, 13.0, Color(ARCANO, 0.5 * delante))
			BarridoAire.brillo(capa, p, 5.2, Color(ARCANO_CLARO, delante))
			BarridoAire.destello(capa, p, 9.0, Color(ARCANO_CLARO, 0.55 * delante), _t * 9.0 + float(cual))
		return
	var tr: float = _t - t_llega
	var fin: Vector2 = _pos_helice(t_llega, 0)
	if falla:
		var kf: float = clampf(tr / T_REVIENTA, 0.0, 1.0)
		if kf < 1.0:
			BarridoAire.brillo(capa, fin, 10.0 * (1.0 - kf), Color(ARCANO, 0.4 * (1.0 - kf)))
			BarridoAire.brillo(capa, fin, 4.0 * (1.0 - kf), Color(ARCANO_CLARO, 1.0 - kf))
		return
	# DOS REVENTONES seguidos (dos impactos): anillo, destello y motas.
	for golpe in 2:
		var tg: float = tr - 0.08 * float(golpe)
		if tg < 0.0:
			continue
		var k2: float = clampf(tg / T_REVIENTA, 0.0, 1.0)
		if k2 >= 1.0:
			continue
		if tg < 0.1:
			BarridoAire.brillo(capa, fin, 20.0 * (1.0 - tg / 0.1), Color(ARCANO_CLARO, 0.45 * (1.0 - tg / 0.1)))
		_anillo(capa, fin, 4.0 + (18.0 + 6.0 * float(golpe)) * (1.0 - pow(1.0 - k2, 2.0)), 4.0, Color(ARCANO, 0.8 * (1.0 - k2)), K)
		BarridoAire.destello(capa, fin, 18.0 * (1.0 - k2 * 0.6), Color(ARCANO_CLARO, 1.0 - k2), 0.4 + 0.8 * float(golpe))
	if tr < 0.45:
		for m in _motas:
			var pm: Vector2 = fin + (m["d"] as Vector2) * float(m["v"]) * tr + Vector2(0.0, 40.0 * tr * tr)
			BarridoAire.brillo(capa, pm, float(m["tam"]), Color(ARCANO_CLARO, 1.0 - tr / 0.45))


# ------------------------------------------------------------
#  EL VENDAJE DE LUZ, sobre el aliado
# ------------------------------------------------------------
func _cura(capa: Node2D) -> void:
	if _t < -0.1:
		return
	var k: float = clampf((_t + 0.1) / T_CURA, 0.0, 1.0)
	var vida: float = sin(k * PI)
	var pies: Vector2 = _desde
	var pecho: Vector2 = _hasta
	if capa == _suelo:
		# Un circulo de luz calida a sus pies.
		BarridoAire.brillo(capa, pies, _ancho * 1.3, Color(LUZ_CALIDA, 0.35 * vida))
		return
	if capa != _brillo:
		return
	# LA COLUMNA que baja: mas ancha arriba, se mete en el cuerpo.
	var baja: float = clampf((_t + 0.1) / 0.2, 0.0, 1.0)
	var arriba: Vector2 = pies + _alto(70.0)
	var abajo: Vector2 = arriba.lerp(pies, baja)
	var col := PackedVector2Array([arriba, arriba.lerp(abajo, 0.5), abajo])
	_lengua(capa, col, PackedFloat32Array([_ancho * 0.9, _ancho * 0.75, _ancho * 0.55]),
		PackedColorArray([Color(LUZ_CALIDA, 0.0), Color(LUZ_CALIDA, 0.35 * vida), Color(LUZ_CALIDA, 0.45 * vida)]),
		PackedColorArray([Color(LUZ_BLANCA, 0.0), Color(LUZ_BLANCA, 0.55 * vida), Color(LUZ_BLANCA, 0.7 * vida)]))
	# LA VENDA: un anillo de luz que se ciñe al pecho y sube un poco.
	if _t > 0.0:
		var kv: float = clampf(_t / 0.5, 0.0, 1.0)
		_anillo(capa, pecho + Vector2(0.0, 4.0 - 8.0 * kv), _ancho * (0.95 - 0.25 * kv), 2.2, Color(LUZ_CALIDA, 0.85 * (1.0 - kv * kv)), K * 0.55)
		if _t < 0.18:
			BarridoAire.destello(capa, pecho, 14.0 * (1.0 - _t / 0.18), Color(LUZ_BLANCA, 1.0 - _t / 0.18), 0.2)
	# DESTELLOS que suben.
	for m in _motas:
		var tm: float = _t - float(m["t0"])
		if tm < 0.0 or tm > 0.45:
			continue
		var q: Vector2 = pies + Vector2(float(m["x"]) * _ancho, -_largo * 0.3) + _alto(float(m["sube"]) * tm / 0.45)
		BarridoAire.destello(capa, q, float(m["tam"]) * sin(tm / 0.45 * PI), Color(LUZ_BLANCA, 0.9), tm * 4.0)


# ------------------------------------------------------------
#  LA LAVA: el suelo se raja y arde
# ------------------------------------------------------------
func _en_franja(u: float, v: float) -> Vector2:
	return _o + _dir * _largo * u + _lat * _ancho * v


# Lo enfriado (0 al rojo .. 1 costra negra) y lo que queda (1 .. 0 deshecho) del trozo a la fraccion 'u' del largo.
func _enfria_en(u: float) -> float:
	return clampf((_t - u * T_LAVA - T_VIVE_LAVA) / T_ENFRIA_LAVA, 0.0, 1.0)


func _queda_en(u: float) -> float:
	return 1.0 - clampf((_t - u * T_LAVA - T_VIVE_LAVA - T_ENFRIA_LAVA) / T_DESHACE_LAVA, 0.0, 1.0)


func _lava(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var frente: float = clampf(_t / T_LAVA, 0.0, 1.0)
	var enfria: float = _enfria_en(0.5)   # el de en medio, para lo que no va por trozos
	var vida: float = _queda_en(1.0)
	if capa == _suelo:
		# LA SUPERFICIE: una malla a lo largo y a lo ancho de la franja, hasta donde ha llegado; cada vertice con su
		# color de lava (el ruido se mueve despacio: se ve fluir) y los bordes irregulares y difuminados.
		var cols: int = 12
		var filas: int = int(clampf(_largo / 9.0, 10.0, 22.0))
		var pv := PackedVector2Array()
		var pc := PackedColorArray()
		var pi := PackedInt32Array()
		var paso_t: float = floor(_t * 6.0)
		for j in cols + 1:
			var v: float = lerpf(-0.5, 0.5, float(j) / float(cols))
			for f in filas + 1:
				var u: float = float(f) / float(filas)
				var dentro: float = clampf((frente - u) * 5.0, 0.0, 1.0)
				var orilla: float = 0.42 + 0.06 * sin(u * 23.0 + float(j)) + 0.04 * _ruido(float(f), 11.0)
				var lado: float = 1.0 - smoothstep(orilla - 0.08, orilla, absf(v))
				var n: float = 0.5 + 0.5 * sin(u * 13.0 + v * 9.0 + _t * 2.2) * cos(v * 7.0 - u * 5.0 - _t * 1.6)
				var vivo: Color = FUEGO_ROJO.lerp(LAVA, smoothstep(0.2, 0.6, n)).lerp(LAVA_CLARA, smoothstep(0.7, 0.95, n))
				# El borde del frente, al blanco: la lava recien salida.
				vivo = vivo.lerp(FUEGO_BLANCO, 0.6 * (1.0 - clampf(absf(frente - u) * 12.0, 0.0, 1.0)) * (1.0 - frente * frente))
				var frio: Color = COSTRA.lerp(FUEGO_ROJO, 0.5 * smoothstep(0.8, 1.0, n))   # vetas que aun brillan
				pv.append(_en_franja(u, v))
				var arranca: float = smoothstep(0.0, 0.1, u + 0.02 * sin(v * 17.0))   # a tus pies se funde, sin corte
				pc.append(Color(vivo.lerp(frio, _enfria_en(u)), 0.95 * dentro * lado * _queda_en(u) * arranca))
		for j in cols:
			for f in filas:
				var a0: int = j * (filas + 1) + f
				var b0: int = (j + 1) * (filas + 1) + f
				pi.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])
		RenderingServer.canvas_item_add_triangle_array(capa.get_canvas_item(), pi, pv, pc)
		# LAS LOSAS: se abren cuando pasa el frente (suben un poco y se separan); piedra oscura con la cara de arriba
		# algo mas clara y su canto en sombra. Lo que queda entre ellas es la grieta con la lava.
		for pl in _charcos:
			var t_pl: float = _t - float(pl["u"]) * T_LAVA
			if t_pl < 0.0:
				continue
			var sube: float = clampf(t_pl / 0.14, 0.0, 1.0)
			var enf_l: float = _enfria_en(float(pl["u"]))
			var queda: float = _queda_en(float(pl["u"]))
			if queda <= 0.0:
				continue
			var alto_l: float = 2.2 * sube * (1.0 - 0.4 * enf_l) - 2.5 * (1.0 - queda)   # al deshacerse, se hunde
			var cen: Vector2 = pl["cen"]
			var tono: float = float(pl["tono"])
			var canto := Color(0.06, 0.05, 0.05, queda)
			var cara_c := Color(0.17 + tono, 0.15 + tono, 0.16 + tono, queda)
			var cara_b := Color(0.09 + tono, 0.08 + tono, 0.09 + tono, queda)
			var encoge: float = 0.55 + 0.45 * queda   # y se desmorona hacia su centro
			var pts: Array = pl["pts"]
			var n_l: int = pts.size()
			# El canto (sombra, abajo) y la cara (arriba, un pelo mas alta), cada una en abanico desde su centro.
			for capa_l in 2:
				var off: Vector2 = Vector2(0.0, 1.4) if capa_l == 0 else _alto(alto_l)
				var pv3 := PackedVector2Array([_en_losa(cen) + off])
				var pc3 := PackedColorArray([canto if capa_l == 0 else cara_c])
				var pi3 := PackedInt32Array()
				for q in pts:
					pv3.append(_en_losa(cen + ((q as Vector2) - cen) * encoge) + off)
					pc3.append(canto if capa_l == 0 else cara_b)
				for k3 in n_l:
					pi3.append_array([0, 1 + k3, 1 + (k3 + 1) % n_l])
				RenderingServer.canvas_item_add_triangle_array(capa.get_canvas_item(), pi3, pv3, pc3)
			if queda < 1.0:
				BarridoAire.brillo(capa, _en_losa(cen) + _alto(4.0 * (1.0 - queda)), float(pl["r"]) * (0.8 + 0.6 * (1.0 - queda)),
					Color(SueloRoto.POLVO, 0.45 * sin((1.0 - queda) * PI)))
		# ASCUAS que quedan latiendo sobre la costra.
		for a in _ascuas:
			var u3: float = float(a["u"])
			var enf_a: float = _enfria_en(u3)
			if u3 > frente or enf_a <= 0.0:
				continue
			var late: float = 0.6 + 0.4 * sin(_t * 9.0 + float(a["fase"]))
			var pa: Vector2 = _en_franja(u3, float(a["v"]))
			BarridoAire.brillo(capa, pa, float(a["tam"]) * 2.2, Color(FUEGO_NARANJA, 0.5 * enf_a * _queda_en(u3) * late))
		return
	if capa == _delante:
		# EL FRENTE que avanza: una erupcion de punta a punta de la franja (llamas altas y seguidas) mientras corre.
		if frente < 1.0:
			for j3 in 7:
				var v3: float = lerpf(-0.36, 0.36, float(j3) / 6.0)
				var kf: float = fmod(_t * 3.0 + float(j3) * 0.37, 1.0)
				var cf: Vector2 = _en_franja(frente, v3) + _alto(4.0 + 20.0 * kf)
				_bocanada(capa, cf + _alto(6.0 * kf), 6.0 + 9.0 * sin(kf * PI), kf * 0.6, float(j3) * 9.0 + floor(_t * 3.0))
		# LAS PIEDRAS que salta al abrirse: trozos de costra que vuelan y caen.
		for pz in _chispas:
			var tz: float = _t - float(pz["u"]) * T_LAVA
			if tz < 0.0 or tz > 0.6:
				continue
			var vz: Vector2 = pz["vel"]
			var pz0: Vector2 = _en_franja(float(pz["u"]), float(pz["v"]))
			var pos: Vector2 = pz0 + _dir * vz.x * tz + Vector2(0.0, vz.y * tz + 160.0 * tz * tz)
			if pos.y > pz0.y + 1.0:
				continue
			if bool(pz["piedra"]):
				capa.draw_circle(pos, float(pz["tam"]), Color(COSTRA, 0.95))
				capa.draw_circle(pos + Vector2(-0.4, -0.4), float(pz["tam"]) * 0.45, Color(FUEGO_ROJO, 0.9))
			else:
				BarridoAire.cometa(capa, pos + Vector2(0.0, 5.0), pos, 1.6, Color(FUEGO_AMARILLO, 1.0 - tz / 0.6))
		# LOS GEISERES: chorros de gotas de lava que saltan de las grietas al pasar el frente y caen.
		for gz in _gotas:
			var tg: float = _t - float(gz["u"]) * T_LAVA - float(gz["t0"])
			if tg < 0.0 or tg > 0.75:
				continue
			var base_g: Vector2 = _en_franja(float(gz["u"]), float(gz["v"]))
			for k4 in 7:
				var tk: float = tg - float(k4) * 0.035
				if tk < 0.0 or tk > 0.55:
					continue
				var ang_g: float = -PI * 0.5 + (float(k4) - 3.0) * 0.14 + float(gz["giro"])
				var vel_g: float = float(gz["fuerza"]) * (0.85 + 0.05 * float(k4 % 3))
				var pg: Vector2 = base_g + Vector2(cos(ang_g) * vel_g * 0.35, sin(ang_g) * vel_g) * tk + Vector2(0.0, 150.0 * tk * tk)
				if pg.y > base_g.y + 1.0:
					continue
				var tam_g: float = 2.6 - 0.2 * float(k4)
				BarridoAire.brillo(capa, pg, tam_g * 2.0, Color(LAVA, 0.6 * (1.0 - tk / 0.55)))
				capa.draw_circle(pg, tam_g, Color(LAVA_CLARA.lerp(LAVA, tk / 0.55), 1.0 - tk / 0.55))
		# EL MURO DE LLAMAS: bocanadas grandes que suben de toda la superficie mientras esta viva.
		for bo in _bocanadas:
			var u4: float = float(bo["u"])
			if _enfria_en(u4) > 0.4:
				continue
			var tf: float = _t - u4 * T_LAVA - float(bo["t0"])
			if tf < 0.0:
				continue
			var k: float = tf / float(bo["vida"])
			if k >= 1.0:
				continue
			var c: Vector2 = _en_franja(u4, float(bo["v"])) + _alto(3.0 + 26.0 * k)
			_bocanada(capa, c, (3.0 + 5.0 * sin(k * PI)) * float(bo["tam"]), k, float(bo["fase"]))
		return
	if capa == _brillo:
		# EL ESTALLIDO donde nace la grieta (a tus pies, delante), como en su referencia: una estrella de lava.
		if _t < 0.4:
			var ke: float = _t / 0.4
			var pe: Vector2 = _en_franja(0.08, 0.0)
			BarridoAire.brillo(capa, pe, 40.0 * (1.0 - ke), Color(LAVA_CLARA, 0.55 * (1.0 - ke)))
			BarridoAire.destello(capa, pe, 34.0 * (1.0 - ke * 0.6), Color(LAVA_CLARA, 1.0 - ke), 0.3)
			_anillo(capa, pe, 6.0 + 40.0 * (1.0 - pow(1.0 - ke, 2.0)), 4.0, Color(LAVA, 0.7 * (1.0 - ke)), K)
		# Cada losa, al abrirse, suelta un resplandor por sus bordes.
		for pl2 in _charcos:
			var t2: float = _t - float(pl2["u"]) * T_LAVA
			if t2 < 0.0 or t2 > 0.35:
				continue
			BarridoAire.brillo(capa, _en_losa(pl2["cen"]), float(pl2["r"]) * 1.2, Color(LAVA, 0.35 * (1.0 - t2 / 0.35)))
		# EL CALOR: un resplandor naranja sobre la franja mientras esta al rojo.
		var n2: int = int(clampf(_largo / 25.0, 4.0, 8.0))
		for j2 in n2:
			var u5: float = (float(j2) + 0.5) / float(n2)
			if u5 > frente:
				continue
			BarridoAire.brillo(capa, _en_franja(u5, 0.0) + _alto(6.0), _ancho * 0.6, Color(LAVA, 0.3 * (1.0 - _enfria_en(u5)) * _queda_en(u5)))


# ------------------------------------------------------------
#  LA JABALINA: dos lanzas de rayo, rectas
# ------------------------------------------------------------
func _pos_lanza(t: float) -> Vector2:
	return _o + _dir * (6.0 + clampf(t * V_JABALINA, 0.0, _largo)) + _alto(ALTO_MANO)


func _jabalina(capa: Node2D) -> void:
	if _t < 0.0 or capa != _brillo:
		return
	var t_llega: float = _largo / V_JABALINA
	var falla: bool = modo == Modo.JABALINA_FALLA
	var chispa: float = floor(_t / T_REJITTER)
	for lanza in 2:
		var tl: float = _t - T_ENTRE_LANZAS * float(lanza)
		if tl < 0.0:
			continue
		if tl < t_llega:
			var p: Vector2 = _pos_lanza(tl)
			var cola: Vector2 = p - _dir * 46.0 * minf(1.0, tl * V_JABALINA / 46.0)
			# EL ASTA: una lengua larga y afilada, nucleo blanco y halo amarillo.
			var asta := PackedVector2Array([cola, cola.lerp(p, 0.55), p + _dir * 6.0])
			_lengua(capa, asta, PackedFloat32Array([0.8, 5.2, 0.8]),
				PackedColorArray([Color(RAYO, 0.0), Color(RAYO, 0.75), Color(RAYO, 0.9)]),
				PackedColorArray([Color(RAYO_CLARO, 0.2), Color(RAYO_CLARO, 1.0), Color(RAYO_CLARO, 1.0)]))
			BarridoAire.brillo(capa, p, 15.0, Color(RAYO, 0.45))
			BarridoAire.brillo(capa, p + _dir * 3.0, 5.0, Color(RAYO_CLARO, 0.9))
			# Chisporroteo a lo largo del asta.
			for j in 3:
				var q0: Vector2 = cola.lerp(p, 0.2 + 0.3 * float(j))
				var ang: float = TAU * _ruido(chispa + float(j) * 5.0 + float(lanza) * 17.0, 2.0)
				_quebrado(capa, q0, q0 + Vector2(cos(ang), sin(ang) * K) * 11.0, RAYO, RAYO_CLARO,
					chispa * 9.0 + float(j), 3, 2.6, 2.0, 0.9)
			continue
		var tr: float = tl - t_llega
		var fin: Vector2 = _pos_lanza(t_llega)
		var k2: float = clampf(tr / T_REVIENTA, 0.0, 1.0)
		if k2 >= 1.0:
			continue
		if falla:
			BarridoAire.brillo(capa, fin, 8.0 * (1.0 - k2), Color(RAYO, 0.4 * (1.0 - k2)))
			continue
		# EL CHISPAZO: fogonazo, onda y chispas quebradas.
		if tr < 0.1:
			BarridoAire.brillo(capa, fin, 24.0 * (1.0 - tr / 0.1), Color(RAYO_CLARO, 0.5 * (1.0 - tr / 0.1)))
		_anillo(capa, fin, 4.0 + 16.0 * (1.0 - pow(1.0 - k2, 2.0)), 3.0, Color(RAYO, 0.75 * (1.0 - k2)), K)
		BarridoAire.destello(capa, fin, 18.0 * (1.0 - k2 * 0.5), Color(RAYO_CLARO, 1.0 - k2), 0.3 + float(lanza))
		if tr < 0.2:
			for j in 5:
				var a3: float = TAU * float(j) / 5.0 + _ruido(float(lanza), float(j)) * 0.9
				_quebrado(capa, fin, fin + Vector2(cos(a3), sin(a3) * K) * 12.0 * (0.5 + tr / 0.2 * 0.5), RAYO, RAYO_CLARO,
					chispa * 13.0 + float(j), 3, 2.2, 1.6, 1.0 - tr / 0.2)


# ------------------------------------------------------------
#  LA MALDICION y LA FORTALEZA, sobre un cuerpo
# ------------------------------------------------------------
# Un galon (una "V" rellena) en 'c', de ancho 'w', apuntando hacia abajo (dir 1) o hacia arriba (dir -1).
func _galon(ci: CanvasItem, c: Vector2, w: float, dir: float, col: Color) -> void:
	var g: float = w * 0.28
	var pts := PackedVector2Array([c + Vector2(-w * 0.5, -dir * w * 0.35), c + Vector2(0.0, dir * w * 0.15),
		c + Vector2(w * 0.5, -dir * w * 0.35), c + Vector2(w * 0.5, -dir * w * 0.35 + -dir * g),
		c + Vector2(0.0, dir * w * 0.15 - dir * g), c + Vector2(-w * 0.5, -dir * w * 0.35 - dir * g)])
	ci.draw_colored_polygon(pts, col)


func _sobre(capa: Node2D) -> void:
	if _t < -0.05:
		return
	var k: float = clampf((_t + 0.05) / T_SOBRE, 0.0, 1.0)
	var vida: float = sin(k * PI)
	var pies: Vector2 = _desde
	var maldito: bool = modo == Modo.MALDICION
	var col: Color = MALDITO if maldito else FUERZA
	var claro: Color = MALDITO_OSCURO if maldito else FUERZA_CLARA
	if capa == _suelo:
		# Un anillo a sus pies: se CIERRA sobre el maldito, se ABRE en el fortalecido.
		var r: float = _ancho * (1.3 - 0.7 * k) if maldito else _ancho * (0.5 + 0.9 * k)
		_anillo(capa, pies, r, 2.2, Color(col, 0.75 * vida))
		BarridoAire.brillo(capa, pies, _ancho * 0.9, Color(claro if maldito else col, (0.45 if maldito else 0.25) * vida))
		return
	if capa == _delante:
		if maldito:
			# LA NIEBLA que cae y lo envuelve: bultos oscuros que bajan por el cuerpo.
			for j in 4:
				var q: float = fmod(k * 1.4 + float(j) * 0.25, 1.0)
				var p: Vector2 = pies + Vector2(sin(float(j) * 2.1) * _ancho * 0.3, -_largo * (1.3 - q * 1.2))
				BarridoAire.brillo(capa, p, _ancho * 0.45, Color(MALDITO_OSCURO, 0.5 * vida * sin(q * PI)))
		# LOS GALONES: hacia abajo aplastando (maldicion) o hacia arriba subiendo (fortaleza), en fila.
		for j in 3:
			var q2: float = fmod(k * 1.8 + float(j) / 3.0, 1.0)
			var y: float = _largo * (1.2 - q2 * 1.1) if maldito else _largo * (0.1 + q2 * 1.1)
			_galon(capa, pies + Vector2(0.0, -y), _ancho * 0.8, 1.0 if maldito else -1.0,
				Color(col if maldito else FUERZA_CLARA, 0.8 * vida * sin(q2 * PI)))
		return
	if capa == _brillo:
		if maldito:
			# Gotas oscuras que caen de el.
			for m in _motas:
				var tm: float = _t - float(m["t0"])
				if tm < 0.0 or tm > 0.4:
					continue
				var q3: Vector2 = pies + Vector2(float(m["x"]) * _ancho, -_largo * 0.6 + _largo * 0.6 * tm / 0.4)
				BarridoAire.cometa(capa, q3 + Vector2(0.0, -5.0), q3, 1.6, Color(MALDITO, 0.8 * (1.0 - tm / 0.4)))
		else:
			# Llamitas de aura que suben por los lados y un destello en el pecho.
			for m in _motas:
				var tm2: float = _t - float(m["t0"])
				if tm2 < 0.0 or tm2 > 0.45:
					continue
				var q4: Vector2 = pies + Vector2(float(m["x"]) * _ancho, -_largo * 0.9 * tm2 / 0.45)
				BarridoAire.cometa(capa, q4 + Vector2(0.0, 7.0), q4, 2.0, Color(FUERZA, 0.8 * (1.0 - tm2 / 0.45)))
			if _t >= 0.0 and _t < 0.2:
				BarridoAire.destello(capa, _hasta, 14.0 * (1.0 - _t / 0.2), Color(FUERZA_CLARA, 1.0 - _t / 0.2), 0.3)


# ------------------------------------------------------------
#  EL FILO: el elemento viaja en arco de tu mano a su arma
# ------------------------------------------------------------
func _pos_filo(u: float) -> Vector2:
	var alto: float = 18.0 + _desde.distance_to(_hasta) * 0.15
	return _desde.lerp(_hasta, u) + Vector2(0.0, -alto * sin(u * PI))


func _filo(capa: Node2D) -> void:
	if capa != _brillo:
		return
	var viaje: float = _largo   # lo que dura el viaje (el vuelo)
	var claro: Color = color.lerp(Color.WHITE, 0.7)
	var u: float = clampf((_t + viaje) / viaje, 0.0, 1.0)
	if _t < 0.0:
		# La CINTA del elemento: una cometa que sigue el arco, con la cabeza brillante.
		for k in 6:
			var ua: float = clampf(u - 0.07 * float(k + 1), 0.0, 1.0)
			var ub: float = clampf(u - 0.07 * float(k), 0.0, 1.0)
			BarridoAire.cometa(capa, _pos_filo(ua), _pos_filo(ub), 4.0 - 0.5 * float(k), Color(color, 0.7 * (1.0 - float(k) / 6.0)))
		BarridoAire.brillo(capa, _pos_filo(u), 8.0, Color(color, 0.5))
		BarridoAire.brillo(capa, _pos_filo(u), 3.2, Color(claro, 1.0))
		return
	# AL LLEGAR: el arma se enciende de golpe (destello y onda del color del elemento).
	var k2: float = clampf(_t / 0.4, 0.0, 1.0)
	if k2 >= 1.0:
		return
	BarridoAire.brillo(capa, _hasta, 16.0 * (1.0 - k2), Color(color, 0.5 * (1.0 - k2)))
	_anillo(capa, _hasta, 3.0 + 12.0 * (1.0 - pow(1.0 - k2, 2.0)), 2.5, Color(color, 0.8 * (1.0 - k2)), K)
	BarridoAire.destello(capa, _hasta, 14.0 * (1.0 - k2 * 0.5), Color(claro, 1.0 - k2), 0.7)


# ------------------------------------------------------------
#  LA MIASMA: la maldicion que cae y se extiende por el suelo
# ------------------------------------------------------------
func _miasma(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var c: Vector2 = forma.centro
	var r: float = maxf(forma.radio, 8.0)
	var cae: float = clampf(_t / T_CAE_MALDICION, 0.0, 1.0)
	var tr: float = _t - T_CAE_MALDICION        # desde que revienta
	var abre: float = clampf(tr / T_EXPANDE, 0.0, 1.0)
	var apaga: float = 1.0 - clampf((tr - T_EXPANDE - 0.2) / 0.8, 0.0, 1.0)
	if capa == _suelo:
		if tr < 0.0:
			# LA SOMBRA de lo que cae: una mancha que se oscurece y aprieta.
			BarridoAire.brillo(capa, c, r * (0.7 - 0.35 * cae), Color(MALDITO_OSCURO, 0.55 * cae))
			return
		# LA MANCHA de miasma que se abre hasta el borde, y la ola violeta en su frente.
		BarridoAire.brillo(capa, c, r * (0.3 + 0.95 * abre), Color(MALDITO_OSCURO, 0.62 * apaga))
		if abre < 1.0:
			_anillo(capa, c, r * (1.0 - pow(1.0 - abre, 2.0)), 4.5, Color(MALDITO, 0.85 * (1.0 - abre * 0.4)))
		elif apaga > 0.0:
			_anillo(capa, c, r, 2.5, Color(MALDITO, 0.45 * apaga))
		return
	if capa == _delante:
		if tr < 0.0:
			# LA BOLA DE MALDICION bajando: un nucleo oscuro con bocanadas de humo violeta que se quedan atras.
			var alto: float = ALTO_MALDICION * (1.0 - cae * cae)
			var p: Vector2 = c + _alto(alto)
			for j in 4:
				var q: float = float(j + 1) * 0.08
				var pj: Vector2 = c + _alto(ALTO_MALDICION * (1.0 - pow(maxf(0.0, cae - q), 2.0))) + Vector2(sin(_t * 9.0 + float(j)) * 2.5, 0.0)
				BarridoAire.brillo(capa, pj, 6.0 - float(j), Color(MALDITO_OSCURO, 0.5 - 0.1 * float(j)))
			BarridoAire.brillo(capa, p, 8.0, Color(MALDITO_OSCURO, 0.9))
			return
		# LA NIEBLA que sale rodando hacia fuera y se deshace.
		for h in _humos:
			var k: float = tr / float(h["vida"])
			if k < 0.0 or k >= 1.0:
				continue
			var d: float = r * float(h["d"]) * (1.0 - pow(1.0 - minf(1.0, k * 1.6), 2.0))
			var pm: Vector2 = c + Vector2(cos(float(h["a"])), sin(float(h["a"]))) * d + _alto(3.0 + 8.0 * k)
			BarridoAire.brillo(capa, pm, float(h["r"]) * (0.8 + 0.6 * k), Color(MALDITO_OSCURO, 0.55 * sin(k * PI)))
		return
	if capa == _brillo:
		if tr < 0.0:
			var p2: Vector2 = c + _alto(ALTO_MALDICION * (1.0 - cae * cae))
			BarridoAire.brillo(capa, p2, 12.0, Color(MALDITO, 0.45))
			BarridoAire.brillo(capa, p2, 3.5, Color(0.95, 0.8, 1.0, 0.9))
			return
		# EL REVENTON: destello violeta y un fogonazo corto.
		if tr < 0.22:
			BarridoAire.brillo(capa, c + _alto(4.0), r * 0.8 * (1.0 - tr / 0.22), Color(MALDITO, 0.5 * (1.0 - tr / 0.22)))
			BarridoAire.destello(capa, c + _alto(5.0), 18.0 * (1.0 - tr / 0.22 * 0.5), Color(0.95, 0.8, 1.0, 1.0 - tr / 0.22), 0.5)


# ------------------------------------------------------------
#  LA ONDA DE FUERZA: la Fortaleza sale de ti
# ------------------------------------------------------------
func _onda_fuerza(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var c: Vector2 = forma.centro
	var r: float = maxf(forma.radio, 8.0)
	var pecho: Vector2 = c + _alto(ALTO_PECHO)
	var tr: float = _t - T_CARGA
	var abre: float = clampf(tr / T_ONDA_FUERZA, 0.0, 1.0)
	if capa == _suelo:
		if tr < 0.0:
			BarridoAire.brillo(capa, c, 14.0 * (_t / T_CARGA), Color(FUERZA, 0.3 * (_t / T_CARGA)))
			return
		# LA ONDA: un anillo rojo que corre por el suelo hasta el borde, con un velo detras que se apaga.
		var apaga: float = 1.0 - clampf((tr - T_ONDA_FUERZA) / 0.5, 0.0, 1.0)
		BarridoAire.brillo(capa, c, r * (0.3 + 0.8 * abre), Color(FUERZA, 0.18 * apaga))
		if abre < 1.0:
			_anillo(capa, c, 6.0 + (r - 6.0) * (1.0 - pow(1.0 - abre, 2.0)), 5.0, Color(FUERZA, 0.85 * (1.0 - abre * 0.5)))
		# Polvo que levanta al pasar.
		for h in _humos:
			var k: float = (tr - abre * 0.0) / float(h["vida"])
			if k < 0.0 or k >= 1.0:
				continue
			var ph: Vector2 = c + Vector2(cos(float(h["a"])), sin(float(h["a"]))) * r * (1.0 - pow(1.0 - minf(1.0, k * 1.4), 2.0)) * 0.95
			BarridoAire.brillo(capa, ph, float(h["r"]) * (1.0 + k), Color(SueloRoto.POLVO, 0.35 * sin(k * PI)))
		return
	if capa == _brillo:
		if tr < 0.0:
			# CONCENTRA EL PODER: motas rojas que vienen de alrededor hacia tu pecho, y el pecho se enciende.
			var kc: float = clampf(_t / T_CARGA, 0.0, 1.0)
			for m in _motas:
				var km: float = clampf((_t - float(m["t0"])) / (T_CARGA - float(m["t0"])), 0.0, 1.0)
				var desde: Vector2 = pecho + Vector2(cos(float(m["a"])), sin(float(m["a"])) * K) * float(m["d"])
				var pm: Vector2 = desde.lerp(pecho, km * km)
				BarridoAire.cometa(capa, desde.lerp(pecho, maxf(0.0, km * km - 0.15)), pm, float(m["tam"]) * 1.4, Color(FUERZA, 0.8))
			BarridoAire.brillo(capa, pecho, 6.0 + 8.0 * kc, Color(FUERZA, 0.4 * kc))
			return
		# EL FOGONAZO al soltarla.
		if tr < 0.25:
			BarridoAire.brillo(capa, pecho, 22.0 * (1.0 - tr / 0.25), Color(FUERZA_CLARA, 0.5 * (1.0 - tr / 0.25)))
			BarridoAire.destello(capa, pecho, 18.0 * (1.0 - tr / 0.25 * 0.5), Color(FUERZA_CLARA, 1.0 - tr / 0.25), 0.2)


# ------------------------------------------------------------
#  LAS LOSAS del Mar de brasas
# ------------------------------------------------------------
# Punto local de la franja (x a lo largo en px, y a lo ancho en px desde el eje) a mundo.
func _en_losa(q: Vector2) -> Vector2:
	return _o + _dir * q.x + _lat * q.y


# Las losas: celdas de Voronoi de unas semillas repartidas por la franja, recortadas por su contorno (un
# rectangulo con las esquinas muy achaflanadas, sin cortes rectos en las puntas) y encogidas 'HUECO' px hacia
# su centro: ese hueco es la grieta. [{pts (locales), cen, u (a que fraccion del largo), r, tono}]
const HUECO_LOSA := 2.0

func _losas_de_la_franja() -> Array:
	var w: float = _largo
	var h: float = _ancho * 0.47
	var nx: int = int(clampf(w / 20.0, 5.0, 10.0))
	var celda: float = w / float(nx)
	var ny: int = 3
	# El contorno de la franja: una CAPSULA (puntas redondas). Las semillas de dentro dan losas; las de un anillo
	# por FUERA son suelo que no se rompe: sus celdas se tiran, y asi el borde lo forman los cantos quebrados de las
	# losas (26/09: "los cortes no son muy rectos?").
	var r_cap: float = minf(h, w * 0.5)
	var dentro: Array = []
	for i in nx:
		for j in ny:
			var q := Vector2((float(i) + 0.5 + _rng.randf_range(-0.35, 0.35)) / float(nx) * w,
				((float(j) + 0.5 + _rng.randf_range(-0.3, 0.3)) / float(ny) - 0.5) * 2.0 * h * 0.9)
			if _dist_capsula(q, w, r_cap) < -1.0:
				dentro.append(q)
	var fuera: Array = []
	var perimetro: int = int((2.0 * (w - 2.0 * r_cap) + TAU * r_cap) / (celda * 0.8)) + 4
	for k in perimetro:
		var q2: Vector2 = _en_capsula(float(k) / float(perimetro) + _rng.randf_range(-0.02, 0.02), w, r_cap)
		var nrm: Vector2 = _normal_capsula(q2, w, r_cap)
		fuera.append(q2 + nrm * celda * _rng.randf_range(0.35, 0.75))
	var caja: Array = [Vector2(-celda * 2.0, -h - celda * 2.0), Vector2(w + celda * 2.0, -h - celda * 2.0),
		Vector2(w + celda * 2.0, h + celda * 2.0), Vector2(-celda * 2.0, h + celda * 2.0)]
	var todas: Array = dentro + fuera
	var out: Array = []
	for a in dentro.size():
		var poly: Array = caja.duplicate()
		for b in todas.size():
			if a == b:
				continue
			poly = _recorta_mitad(poly, todas[a], todas[b])
			if poly.size() < 3:
				break
		if poly.size() < 3:
			continue
		var cen := Vector2.ZERO
		for q in poly:
			cen += q
		cen /= float(poly.size())
		var enc: Array = []
		var r: float = 0.0
		for q in poly:
			var d: Vector2 = (q as Vector2) - cen
			var l: float = d.length()
			enc.append(cen + d * maxf(0.0, 1.0 - HUECO_LOSA / maxf(l, 0.01)))
			r = maxf(r, l)
		out.append({"pts": enc, "cen": cen, "u": clampf(cen.x / maxf(w, 1.0), 0.0, 1.0), "r": r,
			"tono": _rng.randf_range(-0.03, 0.04)})
	return out


# La capsula de largo 'w' (de x=0 a x=w) y radio 'r' en las puntas: distancia con signo (negativo = dentro),
# un punto de su contorno por fraccion del perimetro, y la normal hacia fuera.
static func _dist_capsula(q: Vector2, w: float, r: float) -> float:
	var x: float = clampf(q.x, r, w - r)
	return q.distance_to(Vector2(x, 0.0)) - r


static func _en_capsula(f: float, w: float, r: float) -> Vector2:
	var recto: float = maxf(w - 2.0 * r, 0.0)
	var total: float = 2.0 * recto + TAU * r
	var d: float = fposmod(f, 1.0) * total
	if d < recto:
		return Vector2(r + d, -r)
	d -= recto
	if d < PI * r:
		var a: float = -PI * 0.5 + d / r
		return Vector2(w - r, 0.0) + Vector2(cos(a), sin(a)) * r
	d -= PI * r
	if d < recto:
		return Vector2(w - r - d, r)
	d -= recto
	var a2: float = PI * 0.5 + d / r
	return Vector2(r, 0.0) + Vector2(cos(a2), sin(a2)) * r


static func _normal_capsula(q: Vector2, w: float, r: float) -> Vector2:
	var x: float = clampf(q.x, r, w - r)
	var d: Vector2 = q - Vector2(x, 0.0)
	return d.normalized() if d.length_squared() > 0.0001 else Vector2.UP


# Sutherland-Hodgman contra UN semiplano: se queda con lo que esta mas cerca de 'a' que de 'b'.
static func _recorta_mitad(poly: Array, a: Vector2, b: Vector2) -> Array:
	var out: Array = []
	var m: Vector2 = (a + b) * 0.5
	var nrm: Vector2 = b - a
	var n: int = poly.size()
	for i in n:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % n]
		var dp: float = (p - m).dot(nrm)
		var dq: float = (q - m).dot(nrm)
		if dp <= 0.0:
			out.append(p)
		if (dp < 0.0 and dq > 0.0) or (dp > 0.0 and dq < 0.0):
			out.append(p + (q - p) * (dp / (dp - dq)))
	return out
