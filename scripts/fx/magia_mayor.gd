# ============================================================
#  magia_mayor.gd
#  LOS EFECTOS DE LAS MAGIAS DE 3 FRASES en el mapa (26/09/2026, los eligio el usuario). Van aparte de MagiaAire
#  (que ya pasa de las 1900 lineas) pero con sus mismas piezas (MagiaAire._anillo, BarridoAire.brillo...).
#  POR EL SUELO (SueloRoto.Tipo.MAGIA_SOL.., en el orden de Modo: no reordenar, viajan por red):
#    SOL       Estallido solar: una CHISPA sale de tu mano con estela de destellos y se para en el sitio; ahi NACE un
#              sol pequeño con su corona de rayos girando, crece, se aprieta un instante y REVIENTA en una onda de luz
#              que llena el circulo del centro hacia fuera; el resplandor que deja se apaga desde el centro.
#    VORAGINE  Voragine de sombra (sus referencias: remolino negro en media luna con pinceladas rotas y un ojo rojo de
#              anillos; "ojos de muerte" negros con iris rojo): un ORBE negro sale de tu mano con estela de humo y se
#              HUNDE en el sitio; se abre un REMOLINO de mechones negros de tinta (26/09, su referencia: llamas oscuras
#              con puntas y vetas grises de pincel girando hacia dentro) con un OJO DE ECLIPSE dorado en medio (pupila
#              negra, aro claro, halo y destello en cruz). En cada tiron los mechones se enroscan y se cierran de golpe,
#              el ojo se enciende y el humo y los trozos caen dentro. Al final se cierra en un punto.
#              (Los ojos de muerte se probaron aqui y no; _ojo_muerte queda para una magia futura.)
#    SHOCK     Shock termico (26/09: todo EN EL SITIO, nada sale de ti): el suelo se pone AL ROJO desde el centro con
#              grietas de lava y llamas (el golpe de fuego); encima se junta una ESFERA DE AGUA que cae de golpe, vapor
#              (el golpe de agua); el suelo se enfria a negro y REVIENTA en pinchos y esquirlas de OBSIDIANA con vetas
#              de lava que se apagan.
#    TORMENTA  Tormenta (el OJO DE TORMENTA que eligio): un remolino de viento sube de tu mano al cielo del sitio; alli
#              la nube se enrosca en tres brazos alrededor de un ojo, llueve en espiral y relampaguea dentro. Los golpes
#              de rayo caen del BORDE DEL OJO sobre quien reciben (rayo_tormenta, sobre el cuerpo) y saltan en arco a los
#              de al lado (el salpicon). Al acabar el ojo se abre y la nube se deshace.
#    LUZ       Luz restauradora (pilar y onda dorada): un PILAR de luz sube de quien la lanza y arriba se abre en FLOR;
#              de el sale una ONDA calida por el suelo hasta el borde, levantando motas, y lo que deja se apaga desde el
#              centro. A cada uno de los tuyos le cae su COLUMNA DE LUZ cuando le llega (columna_luz, sobre el cuerpo):
#              plumas que bajan, motas que suben y un halo sobre la cabeza. Tambien fuera de combate (AreaCuracion).
#    PRISMA    Manto prismatico (27/09): motas de arcoiris se juntan en el pecho del que lo lanza, destello y un anillo
#              multicolor que se abre por el suelo; a cada uno de los tuyos le vuela un CHORRO DE PETALOS de arcoiris
#              con pinchos y anillos (su referencia) que le envuelve y revienta en chispas (petalos_prisma).
#    ECLIPSE   Eclipse (27/09, sus referencias): un orbe sube de tu mano al cielo del circulo y alli nace un DISCO NEGRO
#              con su CORONA de llamas blanco-azuladas de borde magenta; en el golpe de oscuridad revientan ESQUIRLAS
#              negras con aberracion cromatica (cian, magenta, amarillo) y el circulo se oscurece; en el de luz la corona
#              ESTALLA en petalos de luz. Al final el disco se cierra en un punto.
#  Criterio (el suyo): siluetas llenas de 3-4 tonos con halo, efecto previo que lo dispare, nada de rayas peladas.
#  Coordenadas de MUNDO; el suelo SIN achatar; lo que va en el aire, a su altura por K. Todo sale de una semilla.
# ============================================================
extends Node2D
class_name MagiaMayor

# Los cinco primeros van en el orden de SueloRoto.Tipo.MAGIA_SOL..; los de despues son SOBRE UN CUERPO (no viajan
# como suelo).
enum Modo { SOL, VORAGINE, SHOCK, TORMENTA, LUZ, PRISMA, ECLIPSE, RAYO_TORMENTA, COLUMNA_LUZ, PETALOS_PRISMA }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ALTO_MANO := 12.0

# EL SOL
const T_CARGA_SOL := 0.14        # la chispa se concentra en tu mano
const V_CHISPA := 340.0          # y vuela a esta velocidad hasta el sitio
const T_CRECE := 0.42            # el sol nace y crece
const T_APRIETA := 0.12          # se aprieta antes de reventar
const T_ONDA_SOL := 0.3          # lo que tarda la onda en llegar al borde
const T_RESPLANDOR := 0.75       # y lo que dura el resplandor que deja
const ALTO_SOL := 22.0
const SOL_BLANCO := Color(1.0, 0.99, 0.9)
const SOL_AMARILLO := Color(1.0, 0.86, 0.32)
const SOL_NARANJA := Color(1.0, 0.6, 0.14)
const SOL_ROJIZO := Color(0.88, 0.32, 0.07)

# LA VORAGINE
const V_ORBE_SOMBRA := 300.0
const T_HUNDE := 0.14            # el orbe se mete en el suelo
const T_ABRE_POZO := 0.3         # el pozo se abre hasta su tamaño
const T_PULSO := 0.22            # entre tiron y tiron (los tres golpes)
const TIRONES := 3
const T_CIERRA := 0.35           # y lo que tarda en cerrarse en un punto
const NEGRO := Color(0.03, 0.02, 0.04)
# (26/09: "en vez de rojo usa blanco") negro y blanco, como su dibujo.
const SOMBRA_CLARA := Color(0.95, 0.94, 0.97)
const SOMBRA_GRIS := Color(0.26, 0.24, 0.3)
const BLANCO_OJO := Color(0.96, 0.95, 0.98)
# El remolino de tinta y el ojo de eclipse (su referencia; el eclipse en BLANCO FRIO, 26/09: el dorado se leia como luz).
const TINTA := Color(0.05, 0.04, 0.03)
const TINTA_MEDIA := Color(0.2, 0.17, 0.13)
const TINTA_CLARA := Color(0.58, 0.54, 0.47)
const ECLIPSE := Color(0.55, 0.62, 0.72)
const ECLIPSE_CLARO := Color(0.95, 0.97, 1.0)
const ALTO_OJO_ECLIPSE := 8.0

# EL SHOCK TERMICO
const T_CALIENTA := 0.28         # el frente al rojo llega al borde (el golpe de fuego)
const T_AGUA_NACE := 0.08        # la esfera de agua empieza a juntarse
const T_AGUA_BAJA := 0.16        # lo que tarda en caer
const T_AGUA_CAE := 0.46         # cuando toca el suelo (el golpe de agua va detras del de fuego)
const T_ROMPE := 0.58            # cuando revienta en obsidiana
const T_VIVE_OBSIDIANA := 0.8    # lo que se queda antes de deshacerse
const ALTO_AGUA := 55.0
# EL ECLIPSE
const V_ORBE_ECLIPSE := 320.0
const T_FORMA_ECLIPSE := 0.45    # el disco nace (el primer golpe, el de oscuridad, cae con el hecho)
const T_ENTRE_ECLIPSE := 0.2     # de la oscuridad a la luz
const T_VIVE_ECLIPSE := 0.9
const T_CIERRA_ECLIPSE := 0.3
const ALTO_ECLIPSE := 55.0
const LENGUAS_ECLIPSE := 30
# (27/09: "blanco, amarillo, morado, azul y negro: los colores de esas magias", no un arcoiris)
const CORONA_BLANCA := Color(0.92, 0.95, 1.0)
const ECLIPSE_LUZ := Color(1.0, 0.95, 0.72)       # blanco-amarillo: la luz
const ECLIPSE_AZUL := Color(0.45, 0.62, 1.0)
const ECLIPSE_MORADO := Color(0.55, 0.22, 0.85)   # la oscuridad
const CORONA_MAGENTA := ECLIPSE_MORADO

# EL MANTO PRISMATICO
const T_CARGA_PRISMA := 0.3
const T_ESPIRAL_PRISMA := 0.7
const PETALOS_CHORRO := 9

# LA LUZ RESTAURADORA
const T_PILAR_LUZ := 0.26        # el pilar sube (y arriba se abre la flor)
const T_ONDA_LUZ := 0.45         # la onda llega al borde
const T_APAGA_LUZ := 0.5
const ALTO_PILAR_LUZ := 70.0
const LUZ_DORADA := Color(1.0, 0.84, 0.42)
const LUZ_BLANCA := Color(1.0, 0.98, 0.9)

# LA TORMENTA
const T_SUBE_VIENTO := 0.22      # el remolino sube de tu mano a la nube
const T_FORMA_NUBE := 0.35       # la nube se enrosca (el primer golpe cae con ella hecha)
const T_LLUEVE_TORMENTA := 1.75  # lo que llueve (los 20 golpes caen en ~1,3 s)
const T_SE_VA_TORMENTA := 0.5
const T_GOTA_TORMENTA := 0.32
const T_RAYO_TORMENTA := 0.3
const ALTO_NUBE_TORMENTA := 62.0
const R_OJO_TORMENTA := 0.2      # el ojo, en fraccion del radio
const ALFA_NUBE_TORMENTA := 0.68
const Z_RAYOS_TORMENTA := Z_ENCIMA - 3   # los rayos y la lluvia, por DEBAJO de la nube
const NUBE_HONDA := Color(0.1, 0.12, 0.19)
const NUBE_MEDIA := Color(0.33, 0.38, 0.5)
const BORLAS_NUBE := 16
const CIELO_OJO := Color(0.55, 0.75, 1.0)
const T_BARRE_SHOCK := 0.35      # lo que tarda el deshacerse en ir del centro al borde
const T_DESHACE_SHOCK := 0.3     # lo que tarda cada trozo en irse
const OBSIDIANA := Color(0.07, 0.05, 0.1)
const OBSIDIANA_BRILLO := Color(0.42, 0.36, 0.62)
const OBSIDIANA_CARA := Color(0.66, 0.6, 0.92)     # la cara de los pinchos (que se lean sobre el suelo negro)
const VAPOR := Color(0.72, 0.74, 0.78)
const AGUA_MEDIA := Color(0.3, 0.55, 0.92)
const VAPOR_CLARO := Color(0.95, 0.96, 0.98)
const PINCEL := Color(0.8, 0.78, 0.84)
const VIOLETA_HONDO := Color(0.24, 0.07, 0.3)

var modo: int = Modo.SOL
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _semilla: int = 1
var _c: Vector2 = Vector2.ZERO       # el centro del circulo (en el suelo)
var _o: Vector2 = Vector2.ZERO       # de donde sale (tus pies)
var _r: float = 30.0
var _motas: Array = []
var _trozos: Array = []
var _rayos: Array = []
var _gotas: Array = []
var _duracion_vuelo: float = 0.6
var _esquirlas: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null
var _lluvia: Node2D = null


static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> MagiaMayor:
	if padre == null or f == null:
		return null
	var e := MagiaMayor.new()
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
	e._preparar()
	return e


# DE DONDE SALE lo que se lanza a un circulo: tus pies, 'ancho' px hacia atras por su 'dir' (ver
# CombatTactico.forma_hechizo, que lo guarda ahi porque por red solo viaja el centro).
static func origen(f: CombatFormas.Forma) -> Vector2:
	var d: Vector2 = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	return f.centro - d * f.ancho


# Lo que tarda la chispa (o lo que se lance) en llegar al centro, carga incluida.
static func t_llega(f: CombatFormas.Forma) -> float:
	return T_CARGA_SOL + maxf(f.ancho - 6.0, 0.0) / V_CHISPA


# CUANDO LE LLEGA a 'p', en segundos desde que se lanza.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.SOL:
			var u: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
			# La onda avanza como 1 - (1 - k)^2: llega a 'u' en k = 1 - sqrt(1 - u).
			return t_llega(f) + T_CRECE + T_APRIETA + T_ONDA_SOL * (1.0 - sqrt(1.0 - u))
		Modo.VORAGINE:
			# El primer tiron, con el pozo ya abierto (los otros dos van detras, al paso de los golpes).
			return t_llega_orbe(f) + T_HUNDE + T_ABRE_POZO
		Modo.TORMENTA:
			return t_llega_tormenta(f) + T_FORMA_NUBE
		Modo.ECLIPSE:
			return t_llega_eclipse(f) + T_FORMA_ECLIPSE
		Modo.PRISMA:
			return T_CARGA_PRISMA
		Modo.LUZ:
			var u_l: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
			return T_PILAR_LUZ + T_ONDA_LUZ * (1.0 - sqrt(1.0 - u_l))
		Modo.SHOCK:
			# El de fuego, cuando el suelo al rojo le llega (el de agua va detras, al paso de los golpes).
			return _llega_calor(p.distance_to(f.centro) / maxf(f.radio, 1.0))
	return 0.0


static func t_llega_orbe(f: CombatFormas.Forma) -> float:
	return T_CARGA_SOL + maxf(f.ancho - 6.0, 0.0) / V_ORBE_SOMBRA


static func t_salir(m: int) -> float:
	match m:
		Modo.SOL: return T_CARGA_SOL + T_CRECE + T_APRIETA + T_ONDA_SOL
		Modo.VORAGINE: return T_CARGA_SOL + T_HUNDE + T_ABRE_POZO
		Modo.SHOCK: return T_CALIENTA
		Modo.TORMENTA: return T_CARGA_SOL + T_SUBE_VIENTO + T_FORMA_NUBE
		Modo.LUZ: return T_PILAR_LUZ + T_ONDA_LUZ
		Modo.ECLIPSE: return T_CARGA_SOL + T_FORMA_ECLIPSE
		Modo.PRISMA: return T_CARGA_PRISMA
	return 0.3


func duracion() -> float:
	match modo:
		Modo.SOL: return t_llega(forma) + T_CRECE + T_APRIETA + T_ONDA_SOL + T_RESPLANDOR + 0.3
		Modo.VORAGINE: return _t_cierra() + T_CIERRA + 0.3
		Modo.SHOCK: return T_ROMPE + T_VIVE_OBSIDIANA + T_BARRE_SHOCK + T_DESHACE_SHOCK + 0.1
		Modo.TORMENTA: return _t_se_va_tormenta() + T_SE_VA_TORMENTA + 0.1
		Modo.RAYO_TORMENTA: return T_RAYO_TORMENTA + 0.5
		Modo.LUZ: return T_PILAR_LUZ + T_ONDA_LUZ + T_APAGA_LUZ + 0.3
		Modo.COLUMNA_LUZ: return 1.0
		Modo.ECLIPSE: return t_llega_eclipse(forma) + T_FORMA_ECLIPSE + T_VIVE_ECLIPSE + T_CIERRA_ECLIPSE + 0.2
		Modo.PRISMA: return T_CARGA_PRISMA + 0.7
		Modo.PETALOS_PRISMA: return T_ESPIRAL_PRISMA + 0.9
	return 1.0


# Desde que se lanza hasta que el pozo empieza a cerrarse: se queda abierto un rato tras el ultimo tiron.
func _t_cierra() -> float:
	return t_llega_orbe(forma) + T_HUNDE + T_ABRE_POZO + T_PULSO * float(TIRONES) + 0.35


func _preparar() -> void:
	_c = forma.centro
	_o = origen(forma)
	_r = maxf(forma.radio, 8.0)
	match modo:
		Modo.SOL:
			# Motas de luz que se meten en tu mano (la carga) y las que el sol se traga al apretarse.
			for i in 10:
				_motas.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(12.0, 22.0),
					"t0": _rng.randf_range(0.0, 0.05), "tam": _rng.randf_range(1.2, 2.0)})
			# Los TROZOS de luz que salen despedidos al reventar (siluetas de destello, no puntos).
			for i in 22:
				var a: float = _rng.randf_range(0.0, TAU)
				_trozos.append({"d": Vector2(cos(a), sin(a)), "v": _rng.randf_range(0.7, 1.15),
					"sube": _rng.randf_range(10.0, 40.0), "tam": _rng.randf_range(3.0, 6.0), "giro": _rng.randf_range(0.0, TAU)})
			# Los RAYOS ANCHOS del estallido: cuñas rellenas que salen del centro.
			for i in 8:
				_rayos.append({"a": TAU * float(i) / 8.0 + _rng.randf_range(-0.12, 0.12),
					"largo": _rng.randf_range(0.8, 1.05), "ancho": _rng.randf_range(0.2, 0.28)})
		Modo.VORAGINE:
			for i in 10:
				_motas.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(12.0, 22.0),
					"t0": _rng.randf_range(0.0, 0.05), "tam": _rng.randf_range(1.4, 2.4)})
			# Los OJOS DE MUERTE alrededor del area: donde, cuanto miden, su giro y cuando se abren.
			# Los MECHONES del remolino: de fuera hacia dentro, cada uno una llama de tinta que se enrosca.
			for i in 42:
				var d0: float = _rng.randf_range(0.25, 1.0)
				_rayos.append({"a": _rng.randf_range(0.0, TAU), "d": d0, "vuelta": _rng.randf_range(0.9, 1.7),
					"cae": _rng.randf_range(0.18, 0.42), "ancho": _rng.randf_range(0.08, 0.14) * (0.6 + 0.6 * d0),
					"sem": _rng.randf_range(0.0, 50.0), "claro": _rng.randf() < 0.45, "t0": _rng.randf_range(0.0, 0.18) * (1.0 - d0)})
			# Gotas de tinta sueltas alrededor.
			for i in 14:
				_gotas.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(0.9, 1.2), "t0": _rng.randf_range(0.0, 0.3),
					"tam": _rng.randf_range(0.8, 1.8)})
			# El HUMO y los TROZOS de suelo que el pozo arrastra hacia dentro.
			for i in 26:
				_trozos.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(0.5, 1.1), "tam": _rng.randf_range(2.0, 4.5),
					"t0": _rng.randf_range(0.0, T_PULSO * float(TIRONES) + 0.2), "piedra": _rng.randf() < 0.4,
					"giro": _rng.randf_range(0.0, TAU)})
		Modo.ECLIPSE:
			for i in 34:
				var a_e: float = _rng.randf_range(0.0, TAU)
				_esquirlas.append({"dir": Vector2(cos(a_e), sin(a_e)), "d": _rng.randf_range(0.25, 1.0),
					"alto": _rng.randf_range(0.4, 1.0), "largo": _rng.randf_range(22.0, 46.0), "ancho": _rng.randf_range(7.0, 15.0)})
		Modo.PRISMA:
			for i in 12:
				_motas.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(14.0, 24.0),
					"t0": _rng.randf_range(0.0, 0.08), "h": float(i) / 12.0})
		Modo.LUZ:
			for i in 30:
				_motas.append({"a": _rng.randf_range(0.0, TAU), "d": sqrt(_rng.randf()) * 0.97, "tam": _rng.randf_range(3.0, 5.0)})
		Modo.TORMENTA:
			_tormenta_c = _c
			_tormenta_r = _r
			_tormenta_hay = true
			# Los BULTOS de la nube en tres brazos: 'u' de dentro (el ojo) a fuera, y cuando entran.
			for brazo in 3:
				for k in 11:
					var u_b: float = (float(k) + _rng.randf_range(0.0, 0.6)) / 11.0
					_motas.append({"a": TAU * float(brazo) / 3.0 + _rng.randf_range(-0.25, 0.25), "u": u_b,
						"r": _rng.randf_range(0.11, 0.17) * _r, "t0": (1.0 - u_b) * 0.12 + _rng.randf_range(0.0, 0.06)})
			for i in 90:
				_gotas.append({"a": _rng.randf_range(0.0, TAU), "d": sqrt(_rng.randf()) * 0.98, "t0": _rng.randf_range(0.0, 0.35)})
			for i in 9:
				var ac: float = _rng.randf_range(0.0, TAU)
				_trozos.append({"dir": Vector2(cos(ac), sin(ac)), "d": sqrt(_rng.randf()) * 0.85, "tam": _rng.randf_range(6.0, 11.0)})
		Modo.SHOCK:
			_rayos = _losas_circulo()
			for i in 16:
				_gotas.append({"a": _rng.randf_range(0.0, TAU), "d": 0.9 * sqrt(_rng.randf()), "tam": _rng.randf_range(4.0, 7.0),
					"sem": _rng.randf_range(0.0, 50.0)})
			for i in 10:
				_motas.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(8.0, 14.0), "tam": _rng.randf_range(1.5, 2.5)})
			for i in 16:
				var av: float = _rng.randf_range(0.0, TAU)
				_trozos.append({"dir": Vector2(cos(av), sin(av)), "d": _rng.randf_range(0.2, 0.9), "t0": _rng.randf(),
					"vida": _rng.randf_range(0.6, 1.0), "sube": _rng.randf_range(25.0, 50.0), "tam": _rng.randf_range(9.0, 16.0)})
			for i in 10:
				var ap2: float = _rng.randf_range(0.0, TAU)
				var dp: float = _rng.randf_range(0.15, 0.85)
				_esquirlas.append({"pincho": true, "dir": Vector2(cos(ap2), sin(ap2)), "d": dp, "tam": _rng.randf_range(5.0, 9.0),
					"t0": dp * 0.1})
			for i in 22:
				var ae: float = _rng.randf_range(0.0, TAU)
				_esquirlas.append({"pincho": false, "dir": Vector2(cos(ae), sin(ae)), "d": _rng.randf_range(0.0, 0.8),
					"vel": Vector2(_rng.randf_range(50.0, 110.0), _rng.randf_range(80.0, 140.0)), "tam": _rng.randf_range(3.5, 7.0),
					"giro": _rng.randf_range(0.0, TAU), "gira": _rng.randf_range(-12.0, 12.0), "lados": _rng.randi_range(3, 4),
					"sem": _rng.randf_range(0.0, 50.0), "t0": _rng.randf_range(0.0, 0.05)})
	_suelo = _capa(SueloRoto.Z_SUELO, false)
	_delante = _capa(Z_ENCIMA, false)
	_brillo = _capa(Z_ENCIMA + 1, true)
	if modo == Modo.TORMENTA:
		# (26/09: "la nube mas transparente" y "los rayos parecen estar por encima") la NUBE en un CanvasGroup para
		# que sea transparente de una pieza (sin que los solapes se oscurezcan); la LLUVIA y los RAYOS por debajo.
		_delante.queue_free()
		var g := CanvasGroup.new()
		g.z_as_relative = false
		g.z_index = Z_ENCIMA
		g.self_modulate = Color(1.0, 1.0, 1.0, ALFA_NUBE_TORMENTA)
		add_child(g)
		# Lo que se dibuja va en un HIJO del grupo (el CanvasGroup junta a sus hijos, no su propio dibujo).
		var hoja_n := Node2D.new()
		g.add_child(hoja_n)
		hoja_n.draw.connect(_dibujar_capa.bind(hoja_n))
		_delante = hoja_n
		_lluvia = _capa(Z_RAYOS_TORMENTA + 1, false)


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
	for n in [_suelo, _delante, _brillo, _lluvia]:
		if n != null:
			(n as Node2D).queue_redraw()


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.SOL: _sol(capa)
		Modo.VORAGINE: _voragine(capa)
		Modo.SHOCK: _shock(capa)
		Modo.TORMENTA: _tormenta(capa)
		Modo.RAYO_TORMENTA: _rayo_tormenta(capa)
		Modo.LUZ: _luz(capa)
		Modo.COLUMNA_LUZ: _columna_luz(capa)
		Modo.ECLIPSE: _eclipse(capa)
		Modo.PRISMA: _prisma(capa)
		Modo.PETALOS_PRISMA: _petalos_prisma(capa)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
static func _alto(h: float) -> Vector2:
	return Vector2(0.0, -h * K)


# UNA ESTRELLA RELLENA de 'n' puntas (la corona del sol): radio de dentro 'r_in', puntas hasta 'r_out' (las pares
# mas largas), color del centro al borde. 'achata' la aplasta en vertical (en el aire, 1; en el suelo, 1).
static func _estrella(ci: CanvasItem, c: Vector2, r_in: float, r_out: float, n: int, giro: float, col_c: Color,
		col_b: Color, alterna: float = 0.6) -> void:
	if r_out <= 0.3 or col_c.a <= 0.0:
		return
	var pv := PackedVector2Array([c])
	var pc := PackedColorArray([col_c])
	var pi := PackedInt32Array()
	var m: int = n * 2
	for i in m:
		var a: float = giro + TAU * float(i) / float(m)
		var rr: float = r_in
		if i % 2 == 0:
			rr = r_out if (i >> 1) & 1 == 0 else lerpf(r_in, r_out, alterna)
		pv.append(c + Vector2(cos(a), sin(a)) * rr)
		pc.append(col_b)
	for i in m:
		pi.append_array([0, 1 + i, 1 + (i + 1) % m])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# UN DISCO relleno de un color con el borde de otro (sin rayas: el borde es un degradado).
static func _disco(ci: CanvasItem, c: Vector2, r: float, col_c: Color, col_b: Color, achata: float = 1.0) -> void:
	if r <= 0.3:
		return
	var pv := PackedVector2Array([c])
	var pc := PackedColorArray([col_c])
	var pi := PackedInt32Array()
	var n: int = 24
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pv.append(c + Vector2(cos(a), sin(a) * achata) * r)
		pc.append(col_b)
	for i in n:
		pi.append_array([0, 1 + i, 1 + (i + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# UNA CUÑA de luz rellena desde 'c' hacia 'a' radianes (un petalo ancho), que se apaga en la punta.
static func _cuna(ci: CanvasItem, c: Vector2, a: float, r0: float, r1: float, abre: float, col: Color, achata: float = 1.0) -> void:
	if r1 <= r0 or col.a <= 0.0:
		return
	var d := Vector2(cos(a), sin(a) * achata)
	var n := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5) * achata)
	# Un PETALO: nace en r0, es mas ancho a un tercio del largo y se afila hasta la punta.
	var medio: float = lerpf(r0, r1, 0.35)
	var w: float = r1 * tan(abre) * 0.5 + 1.5
	var p0: Vector2 = c + d * r0
	var pm: Vector2 = c + d * medio
	var punta: Vector2 = c + d * r1
	ci.draw_primitive(PackedVector2Array([p0, pm + n * w, pm - n * w]), PackedColorArray([col, col, col]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([pm + n * w, punta, pm - n * w]),
		PackedColorArray([col, Color(col, 0.0), col]), PackedVector2Array())


# ------------------------------------------------------------
#  EL SOL (Estallido solar)
# ------------------------------------------------------------
const LENGUAS_SOL := 11

# UNA LENGUA DE LLAMA que sale del borde del sol y se curva al girar (tono plano, sin degradado: silueta de las de sus
# referencias). Nace en el angulo 'a' a 'r0' del centro, mide 'largo', se tuerce 'curva' radianes y afila hasta la punta.
static func _lengua_sol(ci: CanvasItem, c: Vector2, a: float, r0: float, largo: float, curva: float, ancho: float,
		col: Color) -> void:
	if largo <= 0.5 or col.a <= 0.0:
		return
	var n: int = 7
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for k in n + 1:
		var u: float = float(k) / float(n)
		var ang: float = a + curva * u * u
		var d := Vector2(cos(ang), sin(ang))
		var eje: Vector2 = c + d * (r0 + largo * u)
		var w: float = ancho * pow(1.0 - u, 0.75) * (0.75 + 0.5 * sin(minf(u * 2.2, 1.0) * PI * 0.5))
		var t := Vector2(-d.y, d.x)
		pv.append(eje + t * w)
		pv.append(eje - t * w)
		pc.append(col)
		pc.append(col)
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# EL CUERPO DEL SOL (26/09, "mejoralo, sobre todo el sol"): corona de LENGUAS de llama curvas que giran, en capas de
# tonos planos (rojiza fuera, naranja, amarilla), un aro naranja, el disco amarillo con MANCHAS (huecos de negativo),
# un anillo claro que gira en espiral por dentro, el nucleo blanco y GOTITAS de llama sueltas que orbitan. 'corona'
# (1 -> 0) recoge las lenguas al apretarse y 'blanco' (0 -> 1) lo quema todo a blanco.
func _cuerpo_sol(ci: CanvasItem, sol: Vector2, rr: float, corona: float, blanco: float) -> void:
	var paso: float = floor(_t * 14.0)                     # las llamas cambian a saltos, como el fuego de pixel
	var giro: float = _t * 2.2
	var capas: Array = [
		[SOL_ROJIZO, 1.0, 0.55, 0.0],
		[SOL_NARANJA, 0.72, 0.42, 0.33],
		[SOL_AMARILLO, 0.45, 0.3, 0.66]]
	for cp in capas:
		var col: Color = (cp[0] as Color).lerp(SOL_BLANCO, blanco * 0.8)
		for i in LENGUAS_SOL:
			var a: float = giro + TAU * (float(i) + float(cp[3])) / float(LENGUAS_SOL)
			var salto: float = MagiaAire._ruido(float(i) + paso * 1.7, float(cp[3]) * 9.0 + float(_semilla % 31))
			var largo: float = rr * (0.7 + 0.9 * salto) * float(cp[1]) * corona
			_lengua_sol(ci, sol, a, rr * 0.8, largo, 0.85, rr * float(cp[2]), col)
	# GOTITAS de llama sueltas que orbitan y se escapan de las puntas.
	for i in 7:
		var ag: float = -giro * 0.7 + TAU * float(i) / 7.0
		var dg: float = rr * (1.75 + 0.35 * sin(_t * 5.0 + float(i) * 2.0)) * (0.4 + 0.6 * corona)
		var pg: Vector2 = sol + Vector2(cos(ag), sin(ag)) * dg
		_lengua_sol(ci, pg + Vector2(cos(ag - 1.2), sin(ag - 1.2)) * rr * 0.12, ag + PI * 0.5 + PI, 0.0, rr * 0.35, 0.6,
			rr * 0.1, Color(SOL_NARANJA.lerp(SOL_BLANCO, blanco), 0.95 * corona))
	# EL DISCO: aro naranja, disco amarillo, manchas, espiral y nucleo.
	_disco(ci, sol, rr * 1.04, SOL_NARANJA.lerp(SOL_BLANCO, blanco), SOL_NARANJA.lerp(SOL_BLANCO, blanco))
	_disco(ci, sol, rr * 0.9, SOL_AMARILLO.lerp(SOL_BLANCO, blanco), SOL_AMARILLO.lerp(SOL_BLANCO, blanco))
	if blanco < 0.9:
		for i in 4:
			var am: float = giro * 0.6 + TAU * float(i) / 4.0 + 0.4 * MagiaAire._ruido(float(i), 5.0)
			var pm: Vector2 = sol + Vector2(cos(am), sin(am)) * rr * (0.55 + 0.15 * MagiaAire._ruido(float(i), 7.0))
			_disco(ci, pm, rr * (0.1 + 0.05 * MagiaAire._ruido(float(i), 3.0)), Color(SOL_NARANJA, 1.0 - blanco),
				Color(SOL_NARANJA, 1.0 - blanco), 0.8)
	# El anillo claro en espiral: tres arcos rellenos que giran por dentro.
	for i in 3:
		var a0: float = -giro * 1.4 + TAU * float(i) / 3.0
		for k in 5:
			var u0: float = float(k) / 5.0
			var u1: float = float(k + 1) / 5.0
			var q0 := Vector2(cos(a0 + u0 * 1.4), sin(a0 + u0 * 1.4)) * rr * lerpf(0.42, 0.72, u0)
			var q1 := Vector2(cos(a0 + u1 * 1.4), sin(a0 + u1 * 1.4)) * rr * lerpf(0.42, 0.72, u1)
			var w0: float = rr * 0.09 * (1.0 - u0 * 0.7)
			var w1: float = rr * 0.09 * (1.0 - u1 * 0.7)
			var n0: Vector2 = q0.normalized() * w0
			var n1: Vector2 = q1.normalized() * w1
			ci.draw_primitive(PackedVector2Array([sol + q0 - n0, sol + q0 + n0, sol + q1 + n1]),
				PackedColorArray([SOL_BLANCO, SOL_BLANCO, SOL_BLANCO]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([sol + q0 - n0, sol + q1 + n1, sol + q1 - n1]),
				PackedColorArray([SOL_BLANCO, SOL_BLANCO, SOL_BLANCO]), PackedVector2Array())
	_disco(ci, sol + Vector2(-rr * 0.08, -rr * 0.1), rr * (0.38 + 0.3 * blanco), SOL_BLANCO, SOL_BLANCO)


func _pos_chispa(u: float) -> Vector2:
	# De tu mano al sitio del sol, en un arco suave hacia arriba.
	var a: Vector2 = _o + _alto(ALTO_MANO)
	var b: Vector2 = _c + _alto(ALTO_SOL)
	return a.lerp(b, u) + _alto(12.0 * sin(u * PI))


func _sol(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var tl: float = t_llega(forma)
	var t_nace: float = _t - tl                              # desde que la chispa llega al sitio
	var t_rev: float = t_nace - T_CRECE - T_APRIETA          # desde que revienta
	var sol: Vector2 = _c + _alto(ALTO_SOL)
	var r_sol: float = clampf(_r * 0.22, 12.0, 26.0)
	var giro: float = _t * 1.6
	# 1) LA CARGA en tu mano y 2) EL VUELO de la chispa.
	if t_nace < 0.0:
		if capa != _brillo:
			return
		var mano: Vector2 = _o + _alto(ALTO_MANO)
		if _t < T_CARGA_SOL:
			var kc: float = _t / T_CARGA_SOL
			for m in _motas:
				var km: float = clampf((_t - float(m["t0"])) / (T_CARGA_SOL - float(m["t0"])), 0.0, 1.0)
				var desde: Vector2 = mano + Vector2(cos(float(m["a"])), sin(float(m["a"])) * K) * float(m["d"])
				BarridoAire.cometa(capa, desde.lerp(mano, maxf(0.0, km * km - 0.2)), desde.lerp(mano, km * km),
					float(m["tam"]) * 1.4, Color(SOL_AMARILLO, 0.85))
			BarridoAire.brillo(capa, mano, 5.0 + 9.0 * kc, Color(SOL_NARANJA, 0.5 * kc))
			BarridoAire.destello(capa, mano, 5.0 + 7.0 * kc, Color(SOL_BLANCO, kc), _t * 6.0)
			return
		var u: float = clampf((_t - T_CARGA_SOL) / maxf(tl - T_CARGA_SOL, 0.01), 0.0, 1.0)
		var p: Vector2 = _pos_chispa(u)
		# La ESTELA: cometas doradas que se afinan y destellos pequeños que se quedan atras parpadeando.
		for k in 6:
			var ua: float = clampf(u - 0.045 * float(k + 1), 0.0, 1.0)
			var ub: float = clampf(u - 0.045 * float(k), 0.0, 1.0)
			BarridoAire.cometa(capa, _pos_chispa(ua), _pos_chispa(ub), 6.0 - 0.8 * float(k),
				Color(SOL_NARANJA.lerp(SOL_AMARILLO, 1.0 - float(k) / 6.0), 0.75 * (1.0 - float(k) / 6.0)))
		for k2 in 5:
			var ut: float = u - 0.08 * float(k2 + 1)
			if ut < 0.0:
				break
			var q: Vector2 = _pos_chispa(ut) + Vector2(sin(float(k2) * 2.1 + _t * 9.0) * 3.0, 6.0 * float(k2 + 1) * 0.08)
			BarridoAire.destello(capa, q, 5.0 - 0.6 * float(k2), Color(SOL_AMARILLO, 0.8 - 0.14 * float(k2)), float(k2) + _t * 5.0)
		BarridoAire.brillo(capa, p, 13.0, Color(SOL_NARANJA, 0.5))
		BarridoAire.brillo(capa, p, 5.0, Color(SOL_BLANCO, 1.0))
		BarridoAire.destello(capa, p, 11.0, Color(SOL_BLANCO, 0.85), _t * 8.0)
		return
	# 3) EL SOL que nace, crece y se aprieta.
	if t_rev < 0.0:
		var kn: float = clampf(t_nace / T_CRECE, 0.0, 1.0)
		var crece: float = 1.0 - pow(1.0 - kn, 3.0)
		var aprieta: float = clampf((t_nace - T_CRECE) / T_APRIETA, 0.0, 1.0)
		var rr: float = r_sol * (0.25 + 0.75 * crece) * (1.0 - 0.3 * aprieta * aprieta)
		var corona: float = (1.0 - 0.6 * aprieta)
		# El latido: un pelo mas grande y mas chico, cada vez mas rapido.
		rr *= 1.0 + 0.05 * sin(t_nace * (18.0 + 30.0 * kn))
		if capa == _suelo:
			# La LUZ en el suelo bajo el sol, que crece con el; y su sombra calida justo debajo.
			BarridoAire.brillo(capa, _c, _r * (0.25 + 0.5 * crece), Color(SOL_NARANJA, 0.22 + 0.2 * aprieta))
			BarridoAire.brillo(capa, _c, rr * 1.2, Color(SOL_AMARILLO, 0.35 + 0.3 * aprieta))
			return
		if capa == _delante:
			_cuerpo_sol(capa, sol, rr, corona, aprieta)
			return
		if capa == _brillo:
			BarridoAire.brillo(capa, sol, rr * 3.2, Color(SOL_NARANJA, 0.35 + 0.25 * aprieta))
			BarridoAire.brillo(capa, sol, rr * 1.6, Color(SOL_AMARILLO, 0.35 + 0.4 * aprieta))
			# Motas que se traga al apretarse.
			if aprieta > 0.0:
				for m in _motas:
					var da: float = float(m["d"]) * 1.8 * (1.0 - aprieta)
					var pm: Vector2 = sol + Vector2(cos(float(m["a"])), sin(float(m["a"])) * K) * (rr + da)
					BarridoAire.brillo(capa, pm, float(m["tam"]) * 1.5, Color(SOL_BLANCO, aprieta))
			return
		return
	# 4) EL ESTALLIDO: la onda que llena el circulo, los rayos anchos, los trozos y el resplandor que se apaga desde el
	#    centro.
	var ko: float = clampf(t_rev / T_ONDA_SOL, 0.0, 1.0)
	var frente: float = _r * (1.0 - pow(1.0 - ko, 2.0))
	var t_apaga: float = t_rev - T_ONDA_SOL
	var ka: float = clampf(t_apaga / T_RESPLANDOR, 0.0, 1.0)
	if capa == _suelo:
		# El SUELO ENCENDIDO: un disco dorado hasta el frente; al acabar la onda se vacia desde el centro (el hueco crece
		# hasta el borde) y lo que queda se enfria a naranja.
		var hueco: float = _r * (1.0 - pow(1.0 - ka, 2.0))
		if ka <= 0.0:
			BarridoAire.brillo(capa, _c, frente * 1.05, Color(SOL_AMARILLO, 0.5))
			_disco(capa, _c, frente, Color(SOL_BLANCO, 0.35), Color(SOL_NARANJA, 0.3))
		elif ka < 1.0:
			MagiaAire._anillo(capa, _c, lerpf(hueco, _r, 0.5), maxf((_r - hueco) * 0.6, 2.0),
				Color(SOL_NARANJA.lerp(SOL_ROJIZO, ka), 0.5 * (1.0 - ka)))
		# El frente de la onda por el suelo: anillo grueso y dorado con el borde blanco.
		if ko < 1.0:
			MagiaAire._anillo(capa, _c, frente, 9.0, Color(SOL_AMARILLO, 0.9 * (1.0 - ko * 0.4)))
			MagiaAire._anillo(capa, _c, frente, 3.5, Color(SOL_BLANCO, 1.0 - ko * 0.5))
		return
	if capa == _delante:
		# Los RAYOS ANCHOS que salen del centro por el suelo (cuñas rellenas de dos tonos), hasta mas alla del frente.
		if ko < 1.0 or ka < 0.4:
			var alfa_r: float = (1.0 - ko * 0.3) * (1.0 - clampf(ka / 0.4, 0.0, 1.0))
			for ry in _rayos:
				var largo_r: float = minf(frente * 1.15, _r * float(ry["largo"]) * 1.15)
				var a_r: float = float(ry["a"]) + giro * 0.2
				_cuna(capa, _c, a_r, 6.0, largo_r, float(ry["ancho"]), Color(SOL_NARANJA, 0.7 * alfa_r))
				_cuna(capa, _c, a_r, 5.0, largo_r * 0.85, float(ry["ancho"]) * 0.65, Color(SOL_AMARILLO, 0.85 * alfa_r))
				_cuna(capa, _c, a_r, 4.0, largo_r * 0.6, float(ry["ancho"]) * 0.35, Color(SOL_BLANCO, 0.95 * alfa_r))
		# Los TROZOS DE LUZ que saltan del centro y caen: estrellitas rellenas que giran.
		if t_rev < 0.7:
			var kt: float = t_rev / 0.7
			for tz in _trozos:
				var d: float = _r * float(tz["v"]) * (1.0 - pow(1.0 - minf(1.0, kt * 1.4), 2.0))
				var h: float = float(tz["sube"]) * sin(minf(1.0, kt * 1.2) * PI) + ALTO_SOL * (1.0 - minf(1.0, kt * 2.0))
				var pt: Vector2 = _c + (tz["d"] as Vector2) * d + _alto(h)
				var tam: float = float(tz["tam"]) * (1.0 - kt * 0.7)
				_estrella(capa, pt, tam * 0.3, tam, 4, float(tz["giro"]) + t_rev * 7.0, Color(SOL_BLANCO, 1.0 - kt),
					Color(SOL_AMARILLO, 0.8 * (1.0 - kt)), 0.45)
		return
	if capa == _brillo:
		# EL FOGONAZO en el sitio del sol, el destello grande y la onda de luz en el aire (un velo que se abre).
		if t_rev < 0.18:
			var kf: float = t_rev / 0.18
			BarridoAire.brillo(capa, sol, r_sol * 5.0 * (1.0 - kf * 0.5), Color(SOL_BLANCO, 0.75 * (1.0 - kf)))
		if t_rev < 0.45:
			var kd: float = t_rev / 0.45
			BarridoAire.destello(capa, sol, r_sol * 3.4 * (1.0 - kd * 0.5), Color(SOL_BLANCO, 1.0 - kd), 0.3 + kd * 0.4)
		if ko < 1.0:
			BarridoAire.brillo(capa, _c + _alto(6.0), frente * 1.1, Color(SOL_NARANJA, 0.22 * (1.0 - ko)))


# ------------------------------------------------------------
#  LA VORAGINE (Voragine de sombra)
# ------------------------------------------------------------
# Lo apretado que esta el remolino a los 'tp' segundos desde que se abre el pozo: un golpe seco en cada tiron que se
# suelta despacio (0 suelto, 1 en el pico).
static func _aprieton(tp: float) -> float:
	var v: float = 0.0
	for k in TIRONES:
		var dt: float = tp - T_ABRE_POZO - T_PULSO * float(k)
		if dt >= 0.0 and dt < T_PULSO * 1.4:
			v = maxf(v, exp(-dt * 14.0) * minf(1.0, dt * 40.0))
	return v


# UN BRAZO DEL REMOLINO: media luna negra que se enrosca de 'r_out' a 'r_in' (en el SUELO, sin achatar), mas gorda
# por el medio, con su PINCELADA clara rota por el borde de fuera (las pinceladas blancas de su referencia).
func _brazo(ci: CanvasItem, c: Vector2, a0: float, r_in: float, r_out: float, vuelta: float, grueso: float, alfa: float,
		sem: float) -> void:
	var n: int = 14
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	var bordes: Array = []
	for k in n + 1:
		var u: float = float(k) / float(n)
		var ang: float = a0 + vuelta * u
		var rr: float = lerpf(r_out, r_in, u)
		var d := Vector2(cos(ang), sin(ang))
		var w: float = grueso * sin(u * PI) * (0.85 + 0.3 * MagiaAire._ruido(float(k), sem))
		pv.append(c + d * (rr + w))
		pv.append(c + d * maxf(rr - w * 0.4, 0.0))
		pc.append(Color(NEGRO, alfa))
		pc.append(Color(NEGRO, alfa))
		bordes.append([c + d * (rr + w), d, w, u])
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
	# La pincelada: trozos cortos y afilados por fuera del brazo, con huecos (no una raya seguida).
	for k in n:
		if MagiaAire._ruido(float(k) * 1.7, sem + 3.0) < 0.35:
			continue
		var e0: Array = bordes[k]
		var e1: Array = bordes[k + 1]
		var off0: Vector2 = (e0[1] as Vector2) * (1.5 + float(e0[2]) * 0.25)
		var off1: Vector2 = (e1[1] as Vector2) * (1.5 + float(e1[2]) * 0.25)
		var g0: float = 0.4 + 1.3 * sin(float(e0[3]) * PI)
		var g1: float = 0.4 + 1.3 * sin(float(e1[3]) * PI)
		var p0: Vector2 = (e0[0] as Vector2) + off0
		var p1: Vector2 = (e1[0] as Vector2) + off1
		var t: Vector2 = (p1 - p0).normalized().orthogonal()
		ci.draw_primitive(PackedVector2Array([p0 - t * g0, p1 - t * g1 * 0.2, p1 + t * g1 * 0.2, p0 + t * g0]),
			PackedColorArray([Color(PINCEL, alfa), Color(PINCEL, 0.0), Color(PINCEL, 0.0), Color(PINCEL, alfa)]),
			PackedVector2Array())


# ANILLOS ROJOS ROTOS alrededor de 'c' (el ojo del centro del pozo, su referencia): arcos rellenos con huecos que giran.
static func _anillos_rotos(ci: CanvasItem, c: Vector2, r: float, giro: float, alfa: float) -> void:
	if r <= 0.5:
		return
	_disco(ci, c, r * 1.1, Color(NEGRO, alfa), Color(NEGRO, alfa))
	var radios: Array = [0.95, 0.72, 0.5]
	for j in radios.size():
		var rr: float = r * float(radios[j])
		var trozos: int = 5 + j * 2
		for k in trozos:
			var a0: float = giro * (1.0 if j % 2 == 0 else -1.3) + TAU * float(k) / float(trozos)
			var a1: float = a0 + TAU / float(trozos) * 0.62
			var m: int = 4
			for q in m:
				var b0: float = lerpf(a0, a1, float(q) / float(m))
				var b1: float = lerpf(a0, a1, float(q + 1) / float(m))
				var w: float = r * 0.09
				var d0 := Vector2(cos(b0), sin(b0))
				var d1 := Vector2(cos(b1), sin(b1))
				var cr := Color(SOMBRA_CLARA, alfa)
				ci.draw_primitive(PackedVector2Array([c + d0 * (rr - w), c + d0 * (rr + w), c + d1 * (rr + w), c + d1 * (rr - w)]),
					PackedColorArray([cr, cr, cr, cr]), PackedVector2Array())
	_disco(ci, c, r * 0.24, Color(SOMBRA_CLARA, alfa), Color(SOMBRA_CLARA, alfa))
	_disco(ci, c, r * 0.12, Color(NEGRO, alfa), Color(NEGRO, alfa))


# UN OJO DE MUERTE (su referencia): almendra negra de borde de pincel con una punta larga a un lado y un gancho al otro,
# dentro un iris ROJO con anillos negros que se aplastan contra los parpados. 'abre' 0 cerrado .. 1 abierto; 'mira'
# mueve la pupila (-1..1 a lo largo). 'cola' pone la punta a un lado u otro.
# CURVADO (su dibujo, 26/09: "los ojos en los bordes tienen que quedar con la curvatura"): con 'arco_r' > 0 el ojo se
# dobla sobre el circulo de centro 'arco_c' y radio 'arco_r'; 'giro' es entonces su angulo en ese circulo y 'c' no
# se usa (a lo largo = por el borde; hacia fuera = y negativa, el parpado de arriba mira hacia fuera).
var _arco_c: Vector2 = Vector2.ZERO
var _arco_r: float = 0.0
var _arco_a: float = 0.0
const ARCO_INCLINA := 0.32

func _ojo_p(c: Vector2, eje: Vector2, nor: Vector2, q: Vector2) -> Vector2:
	if _arco_r <= 0.0:
		return c + eje * q.x + nor * q.y
	var a: float = _arco_a + q.x / _arco_r
	# Inclinado: la punta (x > 0) se abre hacia fuera, como las hojas de un molinillo.
	return _arco_c + Vector2(cos(a), sin(a)) * (_arco_r - q.y + q.x * ARCO_INCLINA)


func _ojo_muerte(ci: CanvasItem, c: Vector2, largo: float, giro: float, abre: float, mira: float, cola: float,
		sem: float, alfa: float) -> void:
	if abre <= 0.02 or alfa <= 0.0:
		return
	var alto: float = largo * 0.2 * abre
	var eje := Vector2(cos(giro), sin(giro))
	var nor := Vector2(-eje.y, eje.x)
	_arco_a = giro
	var n: int = 12
	var arriba: Array = []
	var abajo: Array = []
	for k in n + 1:
		var u: float = float(k) / float(n)
		var x: float = (u - 0.5) * largo
		var cur: float = pow(sin(u * PI), 0.7)
		var diente: float = 0.8 + 0.4 * MagiaAire._ruido(float(k), sem)
		arriba.append(Vector2(x, -alto * cur * diente - 1.2))
		abajo.append(Vector2(x, alto * 0.8 * cur * (0.85 + 0.3 * MagiaAire._ruido(float(k), sem + 1.0)) + 1.2))
	# Punta larga del lado de la cola y gancho del otro.
	var punta := Vector2(cola * largo * 0.9, -alto * 0.6 - largo * 0.12)
	var gancho := Vector2(-cola * largo * 0.56, alto * 0.25)
	var pts: Array = []
	for q in arriba:
		pts.append(q)
	for i in range(abajo.size() - 1, -1, -1):
		pts.append(abajo[i])
	var poly := PackedVector2Array()
	for i in pts.size():
		var q: Vector2 = pts[i]
		poly.append(_ojo_p(c, eje, nor, q))
		if i == n:
			poly.append(_ojo_p(c, eje, nor, punta if cola > 0.0 else gancho))
		elif i == pts.size() - 1:
			poly.append(_ojo_p(c, eje, nor, gancho if cola > 0.0 else punta))
	if Geometry2D.triangulate_polygon(poly).size() > 0:
		ci.draw_colored_polygon(poly, Color(NEGRO, alfa))
	# (26/09, su referencia del ojo: "intenta que sean asi" y "en vez de rojo usa blanco") dentro, una MEDIA LUNA
	# blanca que sigue el parpado de arriba; el IRIS de anillos blancos rotos hacia la punta; y por fuera PINCELADAS
	# blancas rotas.
	if alto > 1.2:
		var luna := PackedVector2Array()
		var n_l: int = 10
		for k in n_l + 1:
			var u: float = lerpf(0.12, 0.72, float(k) / float(n_l))
			var x: float = (u - 0.5) * largo
			var cur: float = pow(sin(u * PI), 0.7)
			var g: float = alto * 0.22 * sin(float(k) / float(n_l) * PI)
			luna.append(_ojo_p(c, eje, nor, Vector2(x, -alto * cur * 0.42 - g)))
		for k in range(n_l, -1, -1):
			var u2: float = lerpf(0.12, 0.72, float(k) / float(n_l))
			var x2: float = (u2 - 0.5) * largo
			var cur2: float = pow(sin(u2 * PI), 0.7)
			var g2: float = alto * 0.22 * sin(float(k) / float(n_l) * PI)
			luna.append(_ojo_p(c, eje, nor, Vector2(x2, -alto * cur2 * 0.42 + g2)))
		if Geometry2D.triangulate_polygon(luna).size() > 0:
			ci.draw_colored_polygon(luna, Color(BLANCO_OJO, alfa))
		# El iris: anillos blancos rotos que giran, hacia la punta del ojo.
		var iris: Vector2 = _ojo_p(c, eje, nor, Vector2(largo * (0.16 + 0.05 * mira), alto * 0.18))
		_anillos_rotos(ci, iris, alto * 0.72, _t * 3.0 + sem, alfa)
		# Las pinceladas blancas por fuera del parpado de arriba (el borde de fuera del ojo), con huecos.
		for k in n:
			if MagiaAire._ruido(float(k) * 1.3, sem + 5.0) < 0.4:
				continue
			var e0: Vector2 = arriba[k]
			var e1: Vector2 = arriba[k + 1]
			var w0: float = 0.5 + 1.2 * sin(float(k) / float(n) * PI)
			var p0: Vector2 = _ojo_p(c, eje, nor, e0 + Vector2(0.0, -2.2))
			var p1: Vector2 = _ojo_p(c, eje, nor, e1 + Vector2(0.0, -2.2 - w0 * 0.5))
			var t: Vector2 = (p1 - p0).normalized().orthogonal()
			ci.draw_primitive(PackedVector2Array([p0 - t * w0, p1, p0 + t * w0]),
				PackedColorArray([Color(BLANCO_OJO, alfa), Color(BLANCO_OJO, 0.0), Color(BLANCO_OJO, alfa)]),
				PackedVector2Array())


# UN MECHON DE TINTA: una llama oscura que se enrosca alrededor de 'c' (en el SUELO, sin achatar) de 'r0' a 'r1' en
# 'vuelta' radianes; gorda a un tercio, con la cola afilada hacia fuera y la cabeza redonda hacia dentro, y un par
# de PUNTAS que le salen por fuera (las llamas con pinchos de su referencia).
func _mechon(ci: CanvasItem, c: Vector2, a0: float, r0: float, r1: float, vuelta: float, ancho: float, col: Color,
		sem: float, puntas: bool) -> void:
	if ancho <= 0.3 or col.a <= 0.0:
		return
	var n: int = 12
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for k in n + 1:
		var u: float = float(k) / float(n)
		var ang: float = a0 + vuelta * u
		var rr: float = lerpf(r0, r1, u)
		var d := Vector2(cos(ang), sin(ang))
		# De dentro (u = 0, redondeada) a fuera (u = 1, afilada).
		var w: float = ancho * pow(sin(minf(u * 1.5, 1.0) * PI * 0.5), 0.6) * pow(1.0 - u, 0.9)
		w = maxf(w, ancho * 0.25 * (1.0 - u))
		pv.append(c + d * (rr + w))
		pv.append(c + d * maxf(rr - w, 0.0))
		pc.append(col)
		pc.append(col)
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
	if not puntas:
		return
	for j in 2:
		var u2: float = 0.35 + 0.3 * float(j) + 0.1 * MagiaAire._ruido(sem, float(j))
		var ang2: float = a0 + vuelta * u2
		var rr2: float = lerpf(r0, r1, u2)
		var d2 := Vector2(cos(ang2), sin(ang2))
		var t2 := Vector2(-d2.y, d2.x) * signf(vuelta)
		var w2: float = ancho * 0.55
		var base: Vector2 = c + d2 * (rr2 + w2 * 0.6)
		var punta: Vector2 = base + (d2 * 0.9 + t2 * 0.8).normalized() * ancho * (1.6 + MagiaAire._ruido(sem, 4.0 + float(j)))
		ci.draw_primitive(PackedVector2Array([base - t2 * w2, punta, base + t2 * w2]), PackedColorArray([col, col, col]),
			PackedVector2Array())


func _voragine(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var tl: float = t_llega_orbe(forma)
	var t_hunde: float = _t - tl
	var tp: float = t_hunde - T_HUNDE                         # desde que se abre el pozo
	var abre: float = 1.0 - pow(1.0 - clampf(tp / T_ABRE_POZO, 0.0, 1.0), 3.0)
	var cierra: float = clampf((_t - _t_cierra()) / T_CIERRA, 0.0, 1.0)
	var vivo: float = abre * (1.0 - cierra * cierra)
	var ap: float = _aprieton(tp)
	# El giro acelera en cada tiron (se enrosca de golpe) y el pozo se encoge un poco.
	var giro: float = -_t * 2.4 - ap * 0.9 - float(clampi(int((tp - T_ABRE_POZO) / T_PULSO) + 1, 0, TIRONES)) * 0.9
	var r_pozo: float = _r * 0.34 * vivo * (1.0 - 0.18 * ap)
	# 1) CARGA y ORBE hasta el sitio.
	if t_hunde < 0.0:
		if capa != _brillo and capa != _delante:
			return
		var mano: Vector2 = _o + _alto(ALTO_MANO)
		if _t < T_CARGA_SOL:
			if capa != _delante:
				return
			var kc: float = _t / T_CARGA_SOL
			for m in _motas:
				var km: float = clampf((_t - float(m["t0"])) / (T_CARGA_SOL - float(m["t0"])), 0.0, 1.0)
				var desde: Vector2 = mano + Vector2(cos(float(m["a"])), sin(float(m["a"])) * K) * float(m["d"])
				BarridoAire.cometa(capa, desde.lerp(mano, maxf(0.0, km * km - 0.2)), desde.lerp(mano, km * km),
					float(m["tam"]) * 1.4, Color(NEGRO, 0.85))
			_disco(capa, mano, 2.0 + 4.0 * kc, NEGRO, Color(SOMBRA_GRIS, 0.9))
			return
		var u: float = clampf((_t - T_CARGA_SOL) / maxf(tl - T_CARGA_SOL, 0.01), 0.0, 1.0)
		var a: Vector2 = mano
		var b: Vector2 = _c + _alto(8.0)
		var p: Vector2 = a.lerp(b, u) + _alto(10.0 * sin(u * PI))
		if capa == _delante:
			# La ESTELA de humo negro: bocanadas que se quedan atras y se deshacen.
			for k in 7:
				var uk: float = u - 0.06 * float(k + 1)
				if uk < 0.0:
					break
				var pk: Vector2 = a.lerp(b, uk) + _alto(10.0 * sin(uk * PI) + 3.0 * float(k)) \
					+ Vector2(sin(float(k) * 2.3 + _t * 8.0) * 2.5, 0.0)
				_disco(capa, pk, 5.5 - 0.5 * float(k), Color(NEGRO, 0.75 - 0.09 * float(k)), Color(VIOLETA_HONDO, 0.0))
			_disco(capa, p, 7.0, TINTA, Color(TINTA, 0.9))
			_disco(capa, p, 3.2, ECLIPSE_CLARO, ECLIPSE)
			_disco(capa, p, 1.6, TINTA, TINTA)
			return
		BarridoAire.brillo(capa, p, 13.0, Color(ECLIPSE, 0.4))
		return
	# 2) EL POZO.
	if capa == _suelo:
		# La SOMBRA que se extiende por todo el circulo (mas negra hacia el centro).
		BarridoAire.brillo(capa, _c, _r * (0.5 + 0.6 * vivo), Color(NEGRO, 0.55 * vivo))
		BarridoAire.brillo(capa, _c, _r * 0.7 * vivo, Color(VIOLETA_HONDO, 0.35 * vivo))
		if tp < 0.0:
			# El orbe se hunde: un charco negro que se abre bajo el.
			var kh: float = clampf(t_hunde / T_HUNDE, 0.0, 1.0)
			_disco(capa, _c, 5.0 + 8.0 * kh, NEGRO, Color(NEGRO, 0.6))
			return
		# EL REMOLINO DE TINTA: una masa negra en medio, y los mechones por capas (el halo marron, la tinta negra y
		# las vetas grises encima), enroscandose hacia dentro; en cada tiron se cierran hacia el centro.
		var cierre: float = 1.0 - 0.22 * ap
		BarridoAire.brillo(capa, _c, _r * 0.85 * vivo, Color(TINTA, 0.9 * vivo))
		_disco(capa, _c, _r * 0.42 * vivo * cierre, TINTA, Color(TINTA, 0.95 * vivo))
		for pasada in 3:
			for mc in _rayos:
				var km: float = clampf((tp - float(mc["t0"])) / 0.25, 0.0, 1.0)
				if km <= 0.0:
					continue
				var crece: float = (1.0 - pow(1.0 - km, 2.0)) * vivo
				var r_fuera: float = _r * float(mc["d"]) * cierre
				var r_dentro: float = maxf(r_fuera - _r * float(mc["cae"]), _r * 0.08)
				var a_m: float = float(mc["a"]) + giro * (1.3 - 0.6 * float(mc["d"]))
				var w_m: float = _r * float(mc["ancho"]) * crece
				match pasada:
					0:
						_mechon(capa, _c, a_m, r_dentro * crece, r_fuera * crece, -float(mc["vuelta"]), w_m * 1.5,
							Color(TINTA_MEDIA, 0.75 * vivo), float(mc["sem"]), false)
					1:
						_mechon(capa, _c, a_m, r_dentro * crece, r_fuera * crece, -float(mc["vuelta"]), w_m,
							Color(TINTA, vivo), float(mc["sem"]), true)
					2:
						if bool(mc["claro"]):
							_mechon(capa, _c, a_m - 0.1, r_dentro * crece * 1.05, r_fuera * crece * 0.92,
								-float(mc["vuelta"]) * 0.8, w_m * 0.32, Color(TINTA_CLARA, 0.8 * vivo), float(mc["sem"]), false)
		# Las gotas de tinta que salpican alrededor.
		for gt in _gotas:
			var kg: float = clampf((tp - float(gt["t0"])) / 0.3, 0.0, 1.0)
			if kg <= 0.0:
				continue
			var pg: Vector2 = _c + Vector2(cos(float(gt["a"]) + giro * 0.3), sin(float(gt["a"]) + giro * 0.3)) * _r * float(gt["d"]) * vivo
			_disco(capa, pg, float(gt["tam"]) * vivo, Color(TINTA, 0.9), Color(TINTA, 0.9))
		return
	if capa == _delante:
		if tp < 0.0:
			return
		# EL OJO DE ECLIPSE, flotando un pelo sobre el centro (encima de quien este ahi): halo de oro, aro claro y la
		# pupila negra.
		var r_ojo: float = _r * 0.11 * vivo * (1.0 + 0.25 * ap)
		var ojo: Vector2 = _c + _alto(ALTO_OJO_ECLIPSE)
		_disco(capa, ojo, r_ojo * 1.6, Color(ECLIPSE, 0.9 * vivo), Color(ECLIPSE, 0.0))
		_disco(capa, ojo, r_ojo, Color(ECLIPSE_CLARO, vivo), Color(ECLIPSE, vivo))
		_disco(capa, ojo, r_ojo * 0.52, Color(TINTA, vivo), Color(TINTA, vivo))
		# El HUMO y los TROZOS que el pozo se traga: salen del borde y van en espiral al centro.
		for tz in _trozos:
			var tk: float = (tp - float(tz["t0"])) / 0.55
			if tk < 0.0 or tk >= 1.0 or vivo <= 0.0:
				continue
			var d: float = _r * float(tz["d"]) * (1.0 - tk * tk)
			var ang: float = float(tz["a"]) - tk * 2.2
			var pz: Vector2 = _c + Vector2(cos(ang), sin(ang)) * d + _alto(3.0 * (1.0 - tk))
			var tam: float = float(tz["tam"]) * (1.0 - tk * 0.6)
			if bool(tz["piedra"]):
				_estrella(capa, pz, tam * 0.5, tam, 3, float(tz["giro"]) + tk * 6.0, Color(0.2, 0.16, 0.18, vivo),
					Color(0.12, 0.09, 0.1, vivo), 0.8)
			else:
				_disco(capa, pz, tam * 1.2, Color(NEGRO, 0.7 * vivo * sin(tk * PI)), Color(VIOLETA_HONDO, 0.0))
		return
	if capa == _brillo:
		if tp < 0.0:
			var kh2: float = clampf(t_hunde / T_HUNDE, 0.0, 1.0)
			BarridoAire.brillo(capa, _c, 18.0 * kh2, Color(SOMBRA_CLARA, 0.5 * kh2))
			return
		# El resplandor rojo del ojo, que late con los tirones, y el destello rojo al cerrarse.
		# El HALO DORADO del eclipse y su destello en cruz, que se encienden en cada tiron.
		# (sin nucleo blanco: la pupila negra tiene que seguir viendose)
		var r_o: float = _r * 0.11 * vivo
		var ojo_b: Vector2 = _c + _alto(ALTO_OJO_ECLIPSE)
		MagiaAire._anillo(capa, ojo_b, r_o * 1.25, r_o * (0.9 + 0.6 * ap), Color(ECLIPSE, (0.3 + 0.35 * ap) * vivo))
		for k in 4:
			var a_c: float = PI * 0.5 * float(k)
			_cuna(capa, ojo_b, a_c, r_o * 1.05, r_o * (3.2 + 2.0 * ap), 0.05, Color(ECLIPSE_CLARO, (0.75 + 0.25 * ap) * vivo))
		if cierra > 0.0 and cierra < 1.0:
			BarridoAire.destello(capa, ojo_b, 24.0 * (1.0 - cierra), Color(ECLIPSE_CLARO, 1.0 - cierra), 0.0)


# ------------------------------------------------------------
#  EL SHOCK TERMICO (todo en el sitio, 26/09: "que ocurra directo en el sitio, no lanzandolo desde el personaje")
# ------------------------------------------------------------
# Lo que va del suelo al rojo a 'u' (0 centro .. 1 borde): el frente sale del centro como 1 - (1 - k)^2.
static func _llega_calor(u: float) -> float:
	return T_CALIENTA * (1.0 - sqrt(1.0 - clampf(u, 0.0, 1.0)))


# UNA ESQUIRLA DE OBSIDIANA: cristal negro afilado (3-4 puntas) con una cara brillante violacea y una veta de lava.
# UNA LLAMA de las de sus referencias (fuego estilizado): silueta llena que nace redonda en 'base' y sube en una punta
# que se mece, con una segunda punta a un lado; cuatro capas de tono plano (roja, naranja, amarilla y el nucleo casi
# blanco), cada una mas pequeña y pegada a la base. Cambia de forma a saltos ('paso') como el fuego de pixel.
func _llama(ci: CanvasItem, base: Vector2, tam: float, sem: float, paso: float) -> void:
	if tam <= 0.5:
		return
	var capas: Array = [[1.0, MagiaAire.FUEGO_ROJO], [0.74, MagiaAire.FUEGO_NARANJA], [0.5, MagiaAire.FUEGO_AMARILLO],
		[0.26, MagiaAire.FUEGO_BLANCO]]
	var alto: float = tam * (3.2 + 1.2 * MagiaAire._ruido(paso, sem))
	var ancho: float = tam * 1.05
	var lado: float = -1.0 if MagiaAire._ruido(paso + 7.0, sem) < 0.5 else 1.0
	var mece: float = (MagiaAire._ruido(paso + 3.0, sem) - 0.5) * tam * 1.4
	for cp in capas:
		var e: float = float(cp[0])
		var h: float = alto * (0.35 + 0.65 * e)
		var w: float = ancho * e
		var b: Vector2 = base + Vector2(0.0, -w * 0.15)
		var pts := PackedVector2Array()
		var m: int = 8
		# Lado izquierdo de abajo arriba, la punta y el derecho de arriba abajo, y la panza redonda por debajo.
		for side in [-1.0, 1.0]:
			for k in m + 1:
				if side > 0.0 and k == 0:
					continue   # la punta ya la puso el lado izquierdo
				var kk: int = k if side < 0.0 else m - k
				var u: float = float(kk) / float(m)
				# Ancha abajo (la panza) y afilandose hasta la punta, sin tramos de ancho cero (Godot no rellena
				# un contorno con puntos repetidos en linea).
				var wu: float = w * pow(1.0 - u, 0.8) * (0.8 + 0.3 * sin(minf(u * 2.5, 1.0) * PI * 0.5))
				# La segunda punta: un lobulo que sale a un lado a media altura.
				if side == lado and u > 0.45 and u < 0.75:
					wu += w * 0.55 * sin((u - 0.45) / 0.3 * PI) * (1.0 - absf(u - 0.6) * 3.0)
				var x: float = side * wu + mece * u * u
				pts.append(b + Vector2(x, -h * u))
		for k in 5:
			var a: float = PI * float(k + 1) / 6.0
			pts.append(b + Vector2(cos(a) * w * 0.85, sin(a) * w * 0.45))
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			ci.draw_colored_polygon(pts, cp[1])


# UNA GOTA/ESFERA DE AGUA de contorno que tiembla, estirada en vertical 'estira' veces.
func _gota_agua(ci: CanvasItem, c: Vector2, r: float, estira: float, col: Color) -> void:
	if r <= 0.3:
		return
	var n: int = 18
	var pts := PackedVector2Array()
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var rr: float = r * (1.0 + 0.07 * sin(a * 3.0 + _t * 18.0) + 0.04 * sin(a * 5.0 - _t * 11.0))
		pts.append(c + Vector2(cos(a) * rr / sqrt(estira), sin(a) * rr * estira))
	ci.draw_colored_polygon(pts, col)


static func _esquirla(ci: CanvasItem, p: Vector2, tam: float, giro: float, lados: int, sem: float, alfa: float,
		brasa: float) -> void:
	if tam <= 0.4 or alfa <= 0.0:
		return
	var pts := PackedVector2Array()
	for k in lados:
		var a: float = giro + TAU * float(k) / float(lados) + 0.5 * (MagiaAire._ruido(float(k), sem) - 0.5)
		var rr: float = tam * (0.55 + 0.6 * MagiaAire._ruido(float(k) + 3.0, sem))
		if k == 0:
			rr = tam * 1.5   # una punta larga
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, Color(OBSIDIANA, alfa))
	# La cara que brilla: el triangulo entre el centro y las dos primeras puntas.
	ci.draw_colored_polygon(PackedVector2Array([p, pts[0], pts[1]]), Color(OBSIDIANA_BRILLO, 0.85 * alfa))
	# La veta de lava que aun queda dentro, apagandose.
	if brasa > 0.0:
		var m: Vector2 = p.lerp(pts[lados - 1], 0.5)
		ci.draw_colored_polygon(PackedVector2Array([p, m + (pts[lados - 1] - p).orthogonal().normalized() * tam * 0.18,
			m.lerp(pts[lados - 1], 0.6)]), Color(MagiaAire.LAVA_CLARA, brasa * alfa))


# LAS LOSAS del circulo (como las del Mar de brasas, que le gustaron): anillos partidos en sectores con los vertices
# movidos, el borde de fuera quebrado (nada de cortes rectos) y cada losa encogida hacia su centro: el hueco es la
# grieta por la que se ve la lava. Puntos relativos al centro; 'u' = lo lejos del centro (0..1).
func _losas_circulo() -> Array:
	var out: Array = []
	var anillos: Array = [[0.0, 0.3, 3], [0.3, 0.64, 6], [0.64, 1.0, 9]]
	var jit: Dictionary = {}
	for an in anillos:
		var n: int = int(an[2])
		var giro: float = _rng.randf_range(0.0, TAU)
		for k in n:
			var a0: float = giro + TAU * float(k) / float(n)
			var a1: float = giro + TAU * float(k + 1) / float(n)
			var r0: float = float(an[0]) * _r
			var r1: float = float(an[1]) * _r
			var pts: Array = []
			# Borde de fuera en 3 tramos (con ruido), y el de dentro igual pero al reves.
			for q in 4:
				var a: float = lerpf(a0, a1, float(q) / 3.0)
				var ruido: float = 0.0 if q == 0 or q == 3 else _rng.randf_range(-0.06, 0.06) * _r
				pts.append(Vector2(cos(a), sin(a)) * (r1 + ruido))
			if r0 > 0.5:
				for q in range(3, -1, -1):
					var a2: float = lerpf(a0, a1, float(q) / 3.0)
					var ruido2: float = 0.0 if q == 0 or q == 3 else _rng.randf_range(-0.04, 0.04) * _r
					pts.append(Vector2(cos(a2), sin(a2)) * (r0 + ruido2))
			else:
				pts.append(Vector2.ZERO)
			var cen := Vector2.ZERO
			for q2 in pts:
				cen += q2
			cen /= float(pts.size())
			var poly := PackedVector2Array()
			for q3 in pts:
				var d: Vector2 = (q3 as Vector2) - cen
				poly.append(cen + d * maxf(0.0, 1.0 - 2.2 / maxf(d.length(), 1.0)))
			out.append({"pts": poly, "cen": cen, "u": clampf(cen.length() / _r, 0.0, 1.0)})
	return out


# La losa encogida hacia su centro a 'k' de su tamaño (al desmoronarse).
func _losa_encogida(ci: CanvasItem, lo: Dictionary, k: float, col: Color, brillo: Color) -> void:
	var cen: Vector2 = lo["cen"]
	var pts := PackedVector2Array()
	for q in (lo["pts"] as PackedVector2Array):
		pts.append(cen + (q - cen) * k + Vector2(0.0, (1.0 - k) * 2.0))
	_losa(ci, {"pts": pts, "cen": cen}, col, brillo)


func _losa(ci: CanvasItem, lo: Dictionary, col: Color, brillo: Color) -> void:
	var poly: PackedVector2Array = lo["pts"]
	var pv := PackedVector2Array()
	for q in poly:
		pv.append(_c + q)
	if Geometry2D.triangulate_polygon(pv).size() == 0:
		return
	ci.draw_colored_polygon(pv, col)
	# La cara que brilla (de obsidiana, o la parte mas caliente de la losa al rojo).
	if brillo.a > 0.0 and pv.size() >= 3:
		var cen: Vector2 = _c + (lo["cen"] as Vector2)
		ci.draw_colored_polygon(PackedVector2Array([cen, pv[0], pv[1]]), brillo)


# Lo que queda de lo que esta a 'u' del centro (1 entero .. 0 ya se ha ido).
func _queda_shock(u: float) -> float:
	var t0: float = T_ROMPE + T_VIVE_OBSIDIANA + clampf(u, 0.0, 1.0) * T_BARRE_SHOCK
	return 1.0 - clampf((_t - t0) / T_DESHACE_SHOCK, 0.0, 1.0)


func _shock(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var t_cae: float = _t - T_AGUA_CAE                        # desde que el agua toca el suelo
	var t_rompe: float = _t - T_ROMPE                         # desde que revienta en obsidiana
	var enfria: float = clampf(t_cae / 0.18, 0.0, 1.0)        # rojo -> negro, desde el centro
	# (26/09, su regla: las areas se van en el mismo orden en que nacen) SE DESHACE DESDE EL CENTRO: 'fin' es lo que
	# queda de lo de en medio y _queda_shock(u) lo de cada sitio; el borde es lo ultimo en irse.
	var fin: float = _queda_shock(1.0)
	if capa == _suelo:
		# LA LAVA de debajo, que asoma por las grietas entre losas: se enciende con el frente y se apaga tras el agua.
		var k_rojo: float = clampf(_t / T_CALIENTA, 0.0, 1.0)
		var frente: float = _r * (1.0 - pow(1.0 - k_rojo, 2.0))
		var brasa: float = (1.0 - clampf(t_cae / 1.0, 0.0, 1.0) * 0.8) * _queda_shock(0.0)
		BarridoAire.brillo(capa, _c, frente * 1.2, Color(MagiaAire.FUEGO_ROJO, 0.5 * brasa))
		_disco(capa, _c, frente, Color(MagiaAire.LAVA_CLARA, brasa), Color(MagiaAire.LAVA, brasa))
		if k_rojo < 1.0:
			MagiaAire._anillo(capa, _c, frente, 5.0, Color(MagiaAire.LAVA_CLARA, 0.9))
		# LAS LOSAS: al rojo cuando les llega el frente, NEGRAS (obsidiana) cuando les llega el frio del agua (tambien
		# desde el centro), y al reventar se levantan un pelo y se apagan.
		var frio: float = _r * (1.0 - pow(1.0 - enfria, 2.0)) * 1.05
		for lo in _rayos:
			var u: float = float(lo["u"])
			var t_l: float = _t - _llega_calor(u)
			var queda: float = _queda_shock(u)
			if t_l < 0.0 or queda <= 0.0:
				continue
			var nace: float = clampf(t_l / 0.08, 0.0, 1.0)
			if (lo["cen"] as Vector2).length() <= frio and enfria > 0.0:
				if queda < 1.0:
					# Se DESMORONA: el polvo que suelta, y la losa encogiendose hacia su centro.
					var cen_l: Vector2 = _c + (lo["cen"] as Vector2)
					BarridoAire.brillo(capa, cen_l, _r * 0.12 * (1.6 - queda), Color(SueloRoto.POLVO, 0.55 * sin(queda * PI)))
					_losa_encogida(capa, lo, queda, Color(OBSIDIANA, queda), Color(OBSIDIANA_BRILLO, 0.7 * queda))
				else:
					_losa(capa, lo, Color(OBSIDIANA, 1.0), Color(OBSIDIANA_BRILLO, 0.7))
			else:
				var cal: Color = MagiaAire.FUEGO_ROJO.lerp(MagiaAire.LAVA, 0.35 + 0.3 * MagiaAire._ruido(u * 10.0, 2.0))
				_losa(capa, lo, Color(cal.darkened(0.25), nace), Color(MagiaAire.LAVA_CLARA, 0.55 * nace))
		# Los CHARCOS de la salpicadura, que se evaporan.
		if t_cae >= 0.0 and t_cae < 0.6:
			var ks: float = t_cae / 0.6
			MagiaAire._anillo(capa, _c, _r * (0.3 + 0.8 * (1.0 - pow(1.0 - ks, 2.0))), 5.0,
				Color(MagiaAire.AGUA_CLARA, 0.85 * (1.0 - ks)))
		return
	if capa == _delante:
		# (26/09: "el fuego se puede mejorar") LLAMAS GRANDES de las suyas: siluetas llenas en cuatro tonos que se mecen
		# y cambian a saltos; un MURO de llamas corre con el frente al rojo, y ASCUAS que suben. Se apagan con el agua
		# (desde el centro, como el frio). De atras hacia delante, para que las de delante tapen a las de atras.
		if enfria < 1.0:
			var paso: float = floor(_t * 12.0)
			var k_fr: float = clampf(_t / T_CALIENTA, 0.0, 1.0)
			var r_fr: float = _r * (1.0 - pow(1.0 - k_fr, 2.0))
			var frio_l: float = _r * (1.0 - pow(1.0 - enfria, 2.0)) * 1.05
			var orden: Array = []
			for ll in _gotas:
				var u: float = float(ll["d"])
				var t_ll: float = _t - _llega_calor(u)
				if t_ll < 0.0:
					continue
				var pl: Vector2 = _c + Vector2(cos(float(ll["a"])), sin(float(ll["a"]))) * _r * u
				if enfria > 0.0 and u * _r <= frio_l:
					continue
				var viva: float = clampf(t_ll / 0.09, 0.0, 1.0)
				orden.append([pl, float(ll["tam"]) * viva, float(ll["sem"])])
			# El muro: llamas en el frente mientras avanza.
			if k_fr < 1.0:
				for j in 14:
					var a_m: float = TAU * float(j) / 14.0 + 0.2 * MagiaAire._ruido(float(j), 2.0)
					orden.append([_c + Vector2(cos(a_m), sin(a_m)) * r_fr, 4.5 * (1.0 - k_fr * 0.4), float(j) * 3.7])
			orden.sort_custom(func(x, y): return (x[0] as Vector2).y < (y[0] as Vector2).y)
			for o in orden:
				_llama(capa, o[0], float(o[1]), float(o[2]), paso)
			# Las ascuas que suben del suelo al rojo.
			for m in _motas:
				var tm: float = fmod(_t * 0.9 + float(m["d"]) * 0.1, 0.6)
				var pa: Vector2 = _c + Vector2(cos(float(m["a"])), sin(float(m["a"]))) * _r * 0.6 * (float(m["d"]) / 14.0) \
					+ _alto(tm * 70.0) + Vector2(sin(_t * 6.0 + float(m["a"])) * 3.0, 0.0)
				_disco(capa, pa, float(m["tam"]) * (1.0 - tm / 0.6), Color(MagiaAire.FUEGO_AMARILLO, 1.0 - enfria),
					Color(MagiaAire.FUEGO_NARANJA, 1.0 - enfria))
		# LA ESFERA DE AGUA: se junta sobre el centro y cae de golpe.
		var t_esfera: float = _t - T_AGUA_NACE
		if t_esfera >= 0.0 and t_cae < 0.0:
			var kf: float = clampf(t_esfera / 0.14, 0.0, 1.0)
			var kc: float = clampf((_t - (T_AGUA_CAE - T_AGUA_BAJA)) / T_AGUA_BAJA, 0.0, 1.0)
			var h: float = ALTO_AGUA * (1.0 - kc * kc)
			var r_e: float = clampf(_r * 0.45, 16.0, 28.0) * (0.3 + 0.7 * kf)
			var pe: Vector2 = _c + _alto(h)
			# Gotas que se juntan en la esfera mientras se forma.
			for m in _motas:
				var km: float = clampf(t_esfera / 0.14, 0.0, 1.0)
				var desde: Vector2 = pe + Vector2(cos(float(m["a"])), sin(float(m["a"])) * K) * float(m["d"]) * 2.0
				if km < 1.0:
					_disco(capa, desde.lerp(pe, km), float(m["tam"]) * 1.3, Color(MagiaAire.AGUA_CLARA, 0.9), Color(MagiaAire.AGUA, 0.8))
			# Estirada al caer (una gota gorda), en tonos planos: el borde hondo, el cuerpo, la cara clara y el reflejo;
			# el contorno tiembla (agua viva) y suelta gotas por arriba al bajar.
			var estira: float = 1.0 + 0.35 * kc
			# (26/09: "el agua tiene mucho borde") sin borde oscuro: un halo suave, el cuerpo, la parte de abajo algo
			# mas honda, un remolino de espuma que gira dentro y el reflejo.
			BarridoAire.brillo(capa, pe, r_e * 1.5, Color(MagiaAire.AGUA, 0.35))
			_gota_agua(capa, pe, r_e, estira, Color(AGUA_MEDIA, 0.95))
			_gota_agua(capa, pe + Vector2(-r_e * 0.14, -r_e * 0.16 * estira), r_e * 0.7, estira, Color(MagiaAire.AGUA, 0.9))
			# Dos medias lunas de ESPUMA que giran dentro (bandas rellenas, no puntos).
			for j in 2:
				var a_e: float = _t * 7.0 + PI * float(j)
				var pts_e := PackedVector2Array()
				var n_e: int = 8
				for q in n_e + 1:
					var u0: float = float(q) / float(n_e)
					var ang: float = a_e + u0 * 2.0
					var rr0: float = r_e * 0.66
					var w0: float = r_e * 0.1 * sin(u0 * PI)
					pts_e.append(pe + Vector2(cos(ang) / sqrt(estira), sin(ang) * estira) * (rr0 + w0))
				for q in range(n_e, -1, -1):
					var u1: float = float(q) / float(n_e)
					var ang1: float = a_e + u1 * 2.0
					var w1: float = r_e * 0.1 * sin(u1 * PI)
					pts_e.append(pe + Vector2(cos(ang1) / sqrt(estira), sin(ang1) * estira) * (r_e * 0.66 - w1))
				if Geometry2D.triangulate_polygon(pts_e).size() > 0:
					capa.draw_colored_polygon(pts_e, Color(MagiaAire.ESPUMA, 0.85))
			_gota_agua(capa, pe + Vector2(-r_e * 0.32, -r_e * 0.34 * estira), r_e * 0.26, estira, Color(MagiaAire.AGUA_CLARA, 0.9))
			_disco(capa, pe + Vector2(-r_e * 0.38, -r_e * 0.44 * estira), r_e * 0.1, Color.WHITE, Color.WHITE)
			if kc > 0.0:
				for j in 4:
					var pj: Vector2 = pe + _alto(r_e * (1.2 + 0.5 * float(j)) * kc) + Vector2((float(j) - 1.5) * r_e * 0.35, 0.0)
					_gota_agua(capa, pj, r_e * (0.18 - 0.03 * float(j)), 1.4, Color(MagiaAire.AGUA_CLARA, 0.9 * (1.0 - kc * 0.5)))
		# EL VAPOR: bocanadas grises blancas que suben y se abren al tocar el agua el suelo rojo.
		if t_cae >= 0.0:
			for v in _trozos:
				var tv: float = t_cae - float(v["t0"]) * 0.25
				var kv: float = tv / float(v["vida"])
				if kv < 0.0 or kv >= 1.0:
					continue
				var pv: Vector2 = _c + (v["dir"] as Vector2) * _r * float(v["d"]) * (0.4 + 0.6 * kv) \
					+ _alto(6.0 + float(v["sube"]) * kv)
				var rv: float = float(v["tam"]) * (0.6 + 1.2 * kv)
				_disco(capa, pv, rv, Color(VAPOR, 0.75 * sin(kv * PI)), Color(VAPOR, 0.0))
				_disco(capa, pv + Vector2(-rv * 0.2, -rv * 0.25), rv * 0.55, Color(VAPOR_CLARO, 0.6 * sin(kv * PI)),
					Color(VAPOR_CLARO, 0.0))
		# LOS PINCHOS DE OBSIDIANA que brotan del suelo al reventar, y las ESQUIRLAS que saltan.
		if t_rompe >= 0.0 and fin > 0.0:
			for pz in _esquirlas:
				if bool(pz["pincho"]):
					var kp: float = clampf((t_rompe - float(pz["t0"])) / 0.08, 0.0, 1.0)
					var q_p: float = _queda_shock(float(pz["d"]))
					if kp <= 0.0 or q_p <= 0.0:
						continue
					var base: Vector2 = _c + (pz["dir"] as Vector2) * _r * float(pz["d"])
					# Al irse se HUNDE en el suelo (se acorta) y se oscurece.
					var alto_p: float = float(pz["tam"]) * 3.2 * (1.0 - pow(1.0 - kp, 3.0)) * q_p
					var w: float = float(pz["tam"]) * 0.7
					var incl: Vector2 = (pz["dir"] as Vector2) * alto_p * 0.35
					var punta: Vector2 = base + _alto(alto_p) + incl
					capa.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0.0), punta, base + Vector2(w, 0.0),
						base + Vector2(0.0, w * 0.4)]), Color(OBSIDIANA, fin))
					capa.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0.0), punta, base + Vector2(-w * 0.1, 0.0)]),
						Color(OBSIDIANA_CARA, fin))
					var brasa_p: float = 1.0 - clampf(t_rompe / 0.7, 0.0, 1.0)
					if brasa_p > 0.0:
						capa.draw_colored_polygon(PackedVector2Array([base + Vector2(w * 0.15, 0.0), base.lerp(punta, 0.55),
							base + Vector2(w * 0.45, 0.0)]), Color(MagiaAire.LAVA_CLARA, brasa_p * fin))
				else:
					var ke: float = (t_rompe - float(pz["t0"])) / 0.75
					if ke < 0.0 or ke >= 1.0:
						continue
					var te: float = ke * 0.75
					var p0: Vector2 = _c + (pz["dir"] as Vector2) * _r * float(pz["d"])
					var vel: Vector2 = pz["vel"]
					var h2: float = maxf(0.0, vel.y * te - 160.0 * te * te)
					var pe2: Vector2 = p0 + (pz["dir"] as Vector2) * vel.x * te + _alto(h2)
					_esquirla(capa, pe2, float(pz["tam"]) * (1.0 - ke * 0.3), float(pz["giro"]) + te * float(pz["gira"]),
						int(pz["lados"]), float(pz["sem"]), 1.0 - smoothstep(0.75, 1.0, ke), 1.0 - ke)
		return
	if capa == _brillo:
		# El resplandor del calor y el fogonazo del choque (agua contra roca al rojo) y el crujido al reventar.
		if enfria < 1.0:
			var k_r: float = clampf(_t / T_CALIENTA, 0.0, 1.0)
			BarridoAire.brillo(capa, _c + _alto(6.0), _r * (0.3 + 0.7 * k_r), Color(MagiaAire.FUEGO_NARANJA, 0.3 * (1.0 - enfria)))
		if t_cae >= 0.0 and t_cae < 0.22:
			var kf2: float = t_cae / 0.22
			BarridoAire.brillo(capa, _c + _alto(4.0), _r * 0.8 * (1.0 - kf2 * 0.4), Color(VAPOR_CLARO, 0.5 * (1.0 - kf2)))
		# La base de cada pincho brilla a lava un rato (asi se leen sobre el suelo negro).
		if t_rompe >= 0.0 and fin > 0.0:
			var kb: float = 1.0 - clampf(t_rompe / 0.8, 0.0, 1.0)
			for pz in _esquirlas:
				if bool(pz["pincho"]):
					var bp: Vector2 = _c + (pz["dir"] as Vector2) * _r * float(pz["d"])
					BarridoAire.brillo(capa, bp, float(pz["tam"]) * 2.2, Color(MagiaAire.LAVA, 0.55 * kb * fin))
		if t_rompe >= 0.0 and t_rompe < 0.3:
			var kr: float = t_rompe / 0.3
			BarridoAire.destello(capa, _c + _alto(6.0), _r * 0.55 * (1.0 - kr * 0.5), Color(MagiaAire.LAVA_CLARA, 1.0 - kr), 0.35)


# ------------------------------------------------------------
#  LA TORMENTA (el ojo de tormenta)
# ------------------------------------------------------------
# Donde esta la ultima tormenta que se abrio en ESTA maquina (quien resuelve y el espejo la lanzan cada uno): de ahi
# salen los rayos de cada golpe (rayo_tormenta), del borde de su ojo.
static var _tormenta_c: Vector2 = Vector2.ZERO
static var _tormenta_r: float = 0.0
static var _tormenta_hay: bool = false


func _t_se_va_tormenta() -> float:
	return t_llega_tormenta(forma) + T_FORMA_NUBE + T_LLUEVE_TORMENTA


static func t_llega_tormenta(_f: CombatFormas.Forma) -> float:
	return T_CARGA_SOL + T_SUBE_VIENTO


func _pos_nube(a: float, u: float) -> Vector2:
	# Un punto de la nube: angulo 'a' y fraccion 'u' del radio (el ojo en u ~ R_OJO), en el aire.
	return _c + Vector2(cos(a), sin(a)) * _r * u + _alto(ALTO_NUBE_TORMENTA)


# UNA BANDA DE NUBE que se enrosca alrededor de 'c' de 'r0' (el ojo) a 'r1' en 'vuelta' radianes: gorda por el
# medio y redondeada en las puntas, con BULTOS en el borde de fuera (discos del mismo tono que se funden con ella).
func _banda_nube(ci: CanvasItem, c: Vector2, a0: float, r0: float, r1: float, vuelta: float, ancho: float, col: Color,
		sem: float) -> void:
	if ancho <= 0.5 or col.a <= 0.0:
		return
	var n: int = 16
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for k in n + 1:
		var u: float = float(k) / float(n)
		var ang: float = a0 - vuelta * u
		var rr: float = lerpf(r0, r1, u)
		var d := Vector2(cos(ang), sin(ang))
		var w: float = ancho * pow(sin(u * PI), 0.45)
		pv.append(c + d * (rr + w * 0.6))
		pv.append(c + d * maxf(rr - w * 0.6, r0 * 0.9))
		pc.append(col)
		pc.append(col)
		# Los bultos del borde de fuera.
		if k > 0 and k < n and k % 2 == 0 and ancho > _r * 0.2:
			var rb: float = w * (0.45 + 0.25 * MagiaAire._ruido(float(k), sem))
			ci.draw_circle(c + d * (rr + w * 0.45), rb, col)
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# LA NUBE (26/09, tercera: "cerrada, no acabada en puntas; que parezca una nube"): un bulto REDONDO con el borde en
# BORLAS de distintos tamaños (la sombra honda por debajo, el cuerpo y la luz arriba en cada borla), y POR DENTRO la
# espiral en un tono mas claro que se enrosca hacia el OJO, que es un hueco oscuro con el borde encendido. Se forma
# creciendo desde el ojo y al irse el ojo se abre.
func _nube_tormenta(ci: CanvasItem, forma_n: float, viva: float, giro: float, r_ojo: float) -> void:
	var c: Vector2 = _c + _alto(ALTO_NUBE_TORMENTA)
	var R: float = _r * lerpf(0.5, 1.0, forma_n)
	var n_b: int = BORLAS_NUBE
	# 1) La SOMBRA de debajo: las borlas y el cuerpo, un pelo mas abajo y mas oscuros.
	for pasada in 2:
		var col: Color = NUBE_HONDA if pasada == 0 else MagiaAire.NUBE
		var off: Vector2 = Vector2(0.0, 6.0) if pasada == 0 else Vector2.ZERO
		_disco(ci, c + off, R * 0.84, col, col)
		for i in n_b:
			var a: float = TAU * float(i) / float(n_b) + giro * 0.25
			var rb: float = R * (0.2 + 0.08 * MagiaAire._ruido(float(i), 3.0))
			ci.draw_circle(c + off + Vector2(cos(a), sin(a)) * (R - rb * 0.55), rb, col)
	# 2) LA LUZ en TODAS las borlas (26/09: "¿por que solo hay circulos en el de arriba?"): un bulto claro hacia arriba
	# a la izquierda, mas fuerte en las de arriba y mas suave en las de abajo, para que el borde se lea entero. Y un
	# segundo anillo de borlas por DENTRO, que le da volumen a toda la nube.
	for i in n_b:
		var a2: float = TAU * float(i) / float(n_b) + giro * 0.25
		var rb2: float = R * (0.2 + 0.08 * MagiaAire._ruido(float(i), 3.0))
		var pb: Vector2 = c + Vector2(cos(a2), sin(a2)) * (R - rb2 * 0.55) + Vector2(-rb2 * 0.15, -rb2 * 0.25)
		var luz: float = 0.35 + 0.65 * (0.5 - 0.5 * sin(a2))
		ci.draw_circle(pb, rb2 * 0.62, MagiaAire.NUBE.lerp(NUBE_MEDIA, luz))
	var n_d: int = 10
	for i in n_d:
		var a3: float = TAU * (float(i) + 0.5) / float(n_d) - giro * 0.2
		var rb3: float = R * (0.17 + 0.06 * MagiaAire._ruido(float(i), 9.0))
		var pd: Vector2 = c + Vector2(cos(a3), sin(a3)) * R * 0.56
		ci.draw_circle(pd + Vector2(0.0, rb3 * 0.2), rb3, NUBE_HONDA.lerp(MagiaAire.NUBE, 0.55))
		ci.draw_circle(pd + Vector2(-rb3 * 0.15, -rb3 * 0.2), rb3 * 0.7, MagiaAire.NUBE.lerp(NUBE_MEDIA, 0.35 + 0.4 * (0.5 - 0.5 * sin(a3))))
	# 3) La ESPIRAL de dentro: bandas claras que se enroscan hacia el ojo y se afilan a los dos lados (dentro del bulto).
	for brazo in 4:
		var a_b: float = giro + TAU * float(brazo) / 4.0
		_banda_nube(ci, c, a_b, R * r_ojo * 1.1, R * 0.8, 2.6, R * 0.16, NUBE_MEDIA, float(brazo) * 5.0)
	for brazo2 in 4:
		var a_b2: float = giro + TAU * float(brazo2) / 4.0 - 0.15
		_banda_nube(ci, c + Vector2(-1.0, -2.0), a_b2, R * r_ojo * 1.2, R * 0.72, 2.4, R * 0.07, MagiaAire.NUBE_LUZ,
			float(brazo2) * 5.0 + 2.0)
	# 4) EL OJO: el hueco oscuro.
	_disco(ci, c, R * r_ojo, NUBE_HONDA, NUBE_HONDA.darkened(0.2))


func _tormenta(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var tl: float = t_llega_tormenta(forma)
	var tn: float = _t - tl                                   # desde que empieza a formarse la nube
	var forma_n: float = 1.0 - pow(1.0 - clampf(tn / T_FORMA_NUBE, 0.0, 1.0), 2.0)
	var se_va: float = clampf((_t - _t_se_va_tormenta()) / T_SE_VA_TORMENTA, 0.0, 1.0)
	var viva: float = forma_n * (1.0 - se_va)
	var giro: float = _t * 1.3
	var mano: Vector2 = _o + _alto(ALTO_MANO)
	# 1) LA CARGA y EL REMOLINO DE VIENTO que sube de tu mano al cielo del sitio.
	if tn < 0.0:
		if capa != _brillo:
			return
		if _t < T_CARGA_SOL:
			var kc: float = _t / T_CARGA_SOL
			for j in 3:
				var q: Vector2 = mano + Vector2(cos(_t * 20.0 + float(j) * 2.1), sin(_t * 20.0 + float(j) * 2.1) * K) * 9.0 * (1.0 - kc)
				MagiaAire._quebrado(capa, mano, q, MagiaAire.RAYO, MagiaAire.RAYO_CLARO, floor(_t / 0.045) + float(j), 3, 2.0, 1.6, 0.9)
			BarridoAire.brillo(capa, mano, 5.0 + 8.0 * kc, Color(MagiaAire.AGUA, 0.5 * kc))
			return
		var u: float = clampf((_t - T_CARGA_SOL) / T_SUBE_VIENTO, 0.0, 1.0)
		var arriba: Vector2 = _c + _alto(ALTO_NUBE_TORMENTA)
		for j in 3:
			var fase: float = TAU * float(j) / 3.0
			for k in 6:
				var ua: float = clampf(u - 0.07 * float(k + 1), 0.0, 1.0)
				var ub: float = clampf(u - 0.07 * float(k), 0.0, 1.0)
				var pa: Vector2 = mano.lerp(arriba, ua) + _alto(18.0 * sin(ua * PI)) + Vector2(cos(ua * 12.0 + fase), sin(ua * 12.0 + fase) * K) * 6.0
				var pb: Vector2 = mano.lerp(arriba, ub) + _alto(18.0 * sin(ub * PI)) + Vector2(cos(ub * 12.0 + fase), sin(ub * 12.0 + fase) * K) * 6.0
				BarridoAire.cometa(capa, pa, pb, 4.0 - 0.5 * float(k), Color(MagiaAire.NUBE_LUZ, 0.8 * (1.0 - float(k) / 6.0)))
		BarridoAire.brillo(capa, mano.lerp(arriba, u) + _alto(18.0 * sin(u * PI)), 8.0, Color(MagiaAire.AGUA_CLARA, 0.6))
		return
	if viva <= 0.0:
		return
	var r_ojo: float = R_OJO_TORMENTA * (1.0 + 0.8 * se_va)          # al irse el ojo se abre
	if capa == _suelo:
		# LA SOMBRA de la nube y el suelo MOJADO con sus charcos; las salpicaduras de la lluvia.
		BarridoAire.brillo(capa, _c, _r * 1.05, Color(0.05, 0.07, 0.12, 0.5 * viva))
		for ch in _trozos:
			var cp: Vector2 = _c + (ch["dir"] as Vector2) * _r * float(ch["d"])
			var rch: float = float(ch["tam"]) * clampf(tn / 0.8, 0.0, 1.0)
			BarridoAire.brillo(capa, cp, rch * 1.3, Color(MagiaAire.CHARCO, 0.45 * viva))
			MagiaAire._anillo(capa, cp, rch * 0.85, 1.4, Color(MagiaAire.AGUA, 0.3 * viva))
		for g in _gotas:
			var tg: float = fmod(tn - float(g["t0"]), T_GOTA_TORMENTA)
			if tn - float(g["t0"]) < T_GOTA_TORMENTA * 0.9 or tg > 0.2:
				continue
			var a_g: float = float(g["a"]) + giro + 0.6
			var pg: Vector2 = _c + Vector2(cos(a_g), sin(a_g)) * _r * float(g["d"])
			MagiaAire._anillo(capa, pg, 1.5 + 5.0 * tg / 0.2, 1.4, Color(MagiaAire.AGUA_CLARA, 0.8 * (1.0 - tg / 0.2) * viva))
		return
	if capa == _lluvia:
		# LA LLUVIA EN ESPIRAL: gotas que caen de la nube y se van girando con el remolino.
		for g in _gotas:
			if tn < float(g["t0"]):
				continue
			var tg2: float = fmod(tn - float(g["t0"]), T_GOTA_TORMENTA)
			var kg: float = tg2 / T_GOTA_TORMENTA
			if kg > 0.95:
				continue
			var a_g2: float = float(g["a"]) + giro + 0.6 * kg
			var base: Vector2 = _c + Vector2(cos(a_g2), sin(a_g2)) * _r * float(g["d"])
			var h: float = ALTO_NUBE_TORMENTA * (1.0 - kg)
			var cab: Vector2 = base + _alto(h)
			var cola: Vector2 = cab + _alto(9.0) + Vector2(-sin(a_g2), cos(a_g2)) * 3.0
			BarridoAire.cometa(capa, cola, cab, 1.8, Color(MagiaAire.AGUA_CLARA, 0.85 * viva))
		return
	if capa == _delante:
		_nube_tormenta(capa, forma_n, viva, giro, r_ojo)
		return
	if capa == _brillo:
		# EL OJO: su borde brilla frio y dentro se ve el cielo claro; y los RELAMPAGOS dentro de la nube (fogonazos
		# que encienden un trozo de nube y ramas quebradas que la cruzan).
		var ojo: Vector2 = _c + _alto(ALTO_NUBE_TORMENTA)
		MagiaAire._anillo(capa, ojo, _r * r_ojo, 5.0, Color(MagiaAire.AGUA_CLARA, 0.45 * viva))
		BarridoAire.brillo(capa, ojo, _r * r_ojo * 0.9, Color(CIELO_OJO, 0.35 * viva))
		var tic: float = floor(tn / 0.09)
		for j in 2:
			if MagiaAire._ruido(tic, float(j) + float(_semilla % 17)) < 0.55:
				continue
			var a_r: float = TAU * MagiaAire._ruido(tic + 3.0, float(j))
			var u_r: float = lerpf(r_ojo + 0.1, 0.9, MagiaAire._ruido(tic + 5.0, float(j)))
			var pr: Vector2 = _pos_nube(a_r, u_r)
			BarridoAire.brillo(capa, pr, _r * 0.28, Color(MagiaAire.RAYO_CLARO, 0.45 * viva))
			var q2: Vector2 = _pos_nube(a_r + 0.5, u_r * 0.8)
			MagiaAire._quebrado(capa, pr, q2, MagiaAire.RAYO, MagiaAire.RAYO_CLARO, tic * 7.0 + float(j), 5, 4.0, 2.4, 0.9 * viva)


# EL RAYO DE UN GOLPE de la Tormenta sobre un cuerpo ('caja'): sale del borde del ojo de la tormenta (o del cielo, si
# aqui no hay ninguna) y cae en sus pies; fogonazo, onda, chispazos que saltan a los lados y la chamusquina.
static func rayo_tormenta(padre: Node, caja: Rect2, semilla: int, espera: float, ritmo: float) -> MagiaMayor:
	if padre == null:
		return null
	var e := MagiaMayor.new()
	e.modo = Modo.RAYO_TORMENTA
	e.set_meta("bajo_nube", true)
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	var pies := Vector2(caja.get_center().x, caja.end.y)
	e._c = pies
	if _tormenta_hay:
		var d: Vector2 = pies - _tormenta_c
		var dir: Vector2 = d.normalized() if d.length_squared() > 1.0 else Vector2.RIGHT
		e._o = _tormenta_c + dir * _tormenta_r * R_OJO_TORMENTA + _alto(ALTO_NUBE_TORMENTA)
	else:
		e._o = pies + _alto(ALTO_NUBE_TORMENTA) + Vector2(-10.0, 0.0)
	e.z_as_relative = false
	e.z_index = Z_RAYOS_TORMENTA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	for i in 6:
		var a: float = e._rng.randf_range(0.0, TAU)
		e._motas.append({"a": a, "largo": e._rng.randf_range(9.0, 16.0)})
	e._suelo = e._capa(SueloRoto.Z_SUELO, false)
	e._brillo = e._capa(Z_RAYOS_TORMENTA, true)
	return e


func _rayo_tormenta(capa: Node2D) -> void:
	if _t < -0.04:
		return
	var k: float = clampf((_t + 0.04) / T_RAYO_TORMENTA, 0.0, 1.0)
	var tic: float = floor(_t / 0.04)
	if capa == _suelo:
		if _t >= 0.0:
			var ks: float = clampf(_t / 0.5, 0.0, 1.0)
			BarridoAire.brillo(capa, _c, 10.0, Color(MagiaAire.CHAMUSCADO, 0.5 * (1.0 - ks)))
			MagiaAire._anillo(capa, _c, 4.0 + 16.0 * (1.0 - pow(1.0 - minf(1.0, _t / 0.25), 2.0)), 3.0,
				Color(MagiaAire.RAYO_CLARO, 0.8 * (1.0 - minf(1.0, _t / 0.25))))
		return
	if capa != _brillo or k >= 1.0:
		return
	var alfa: float = (1.0 - k) * (0.75 + 0.25 * MagiaAire._ruido(tic, 5.0))
	var largo: float = _o.distance_to(_c)
	var tramos: int = clampi(int(largo / 8.0), 5, 14)
	# El RAYO GORDO: el halo ancho y encima el nucleo, quebrado, que cambia de forma cada poco.
	MagiaAire._quebrado(capa, _o, _c, MagiaAire.RAYO, MagiaAire.RAYO_CLARO, tic * 13.0 + float(_semilla % 91), tramos,
		clampf(largo * 0.08, 3.0, 8.0), 7.0, alfa * 0.6)
	MagiaAire._quebrado(capa, _o, _c, MagiaAire.RAYO, Color.WHITE, tic * 13.0 + float(_semilla % 91), tramos,
		clampf(largo * 0.08, 3.0, 8.0), 3.4, alfa)
	# Una rama que se suelta del medio.
	var medio: Vector2 = _o.lerp(_c, 0.5)
	MagiaAire._quebrado(capa, medio, medio + (_c - _o).normalized().rotated(0.8) * 14.0, MagiaAire.RAYO, MagiaAire.RAYO_CLARO,
		tic * 3.0, 3, 2.4, 2.0, alfa * 0.7)
	if _t >= 0.0:
		# EL IMPACTO: fogonazo, destello y CHISPAZOS que saltan a los lados (el rayo salpica).
		var ki: float = clampf(_t / 0.2, 0.0, 1.0)
		BarridoAire.brillo(capa, _c + _alto(6.0), 22.0 * (1.0 - ki * 0.5), Color(MagiaAire.RAYO_CLARO, 0.6 * (1.0 - ki)))
		BarridoAire.destello(capa, _c + _alto(4.0), 18.0 * (1.0 - ki * 0.4), Color(MagiaAire.RAYO_CLARO, 1.0 - ki), 0.3)
		for m in _motas:
			var a: float = float(m["a"])
			var q: Vector2 = _c + Vector2(cos(a), sin(a) * 0.5) * float(m["largo"]) * (0.4 + 0.6 * ki)
			MagiaAire._quebrado(capa, _c, q, MagiaAire.RAYO, MagiaAire.RAYO_CLARO, tic + a, 3, 2.2, 1.8, 1.0 - ki)


# ------------------------------------------------------------
#  LA LUZ RESTAURADORA (pilar y onda dorada)
# ------------------------------------------------------------
# Una PLUMA de luz: hoja alargada rellena en dos tonos (el borde calido y el raquis claro por el medio), ladeada 'giro'.
static func _pluma(ci: CanvasItem, p: Vector2, largo: float, giro: float, alfa: float) -> void:
	if largo <= 0.5 or alfa <= 0.0:
		return
	var eje := Vector2(cos(giro), sin(giro))
	var nor := Vector2(-eje.y, eje.x)
	var pts := PackedVector2Array()
	var n: int = 8
	for k in n + 1:
		var u: float = float(k) / float(n)
		pts.append(p + eje * (u - 0.5) * largo + nor * largo * 0.2 * sin(u * PI) * (1.0 - 0.3 * u))
	for k in range(n - 1, 0, -1):
		var u2: float = float(k) / float(n)
		pts.append(p + eje * (u2 - 0.5) * largo - nor * largo * 0.16 * sin(u2 * PI) * (1.0 - 0.3 * u2))
	ci.draw_colored_polygon(pts, Color(LUZ_DORADA, alfa))
	ci.draw_colored_polygon(PackedVector2Array([p - eje * largo * 0.5, p + eje * largo * 0.45 + nor * largo * 0.03,
		p + eje * largo * 0.45 - nor * largo * 0.03]), Color(LUZ_BLANCA, alfa))


func _luz(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var alto_p: float = ALTO_PILAR_LUZ
	var sube: float = 1.0 - pow(1.0 - clampf(_t / T_PILAR_LUZ, 0.0, 1.0), 2.0)
	var t_o: float = _t - T_PILAR_LUZ                       # desde que sale la onda
	var ko: float = clampf(t_o / T_ONDA_LUZ, 0.0, 1.0)
	var frente: float = _r * (1.0 - pow(1.0 - ko, 2.0))
	var t_fin: float = t_o - T_ONDA_LUZ
	var apaga: float = 1.0 - clampf(t_fin / T_APAGA_LUZ, 0.0, 1.0)
	var flor: float = clampf((_t - T_PILAR_LUZ * 0.7) / 0.18, 0.0, 1.0)
	var top: Vector2 = _c + _alto(alto_p * sube)
	if capa == _suelo:
		# El suelo encendido bajo el pilar y la ONDA DORADA que sale hacia fuera; lo que deja se apaga desde el centro.
		BarridoAire.brillo(capa, _c, 18.0 + 10.0 * sube, Color(LUZ_DORADA, 0.5 * apaga))
		if t_o >= 0.0:
			if ko < 1.0:
				MagiaAire._anillo(capa, _c, frente, 14.0, Color(LUZ_DORADA, 0.55))
				MagiaAire._anillo(capa, _c, frente, 4.0, Color(LUZ_BLANCA, 0.9))
				BarridoAire.brillo(capa, _c, frente, Color(LUZ_DORADA, 0.12))
			else:
				var hueco: float = _r * (1.0 - pow(1.0 - clampf(t_fin / T_APAGA_LUZ, 0.0, 1.0), 2.0))
				MagiaAire._anillo(capa, _c, lerpf(hueco, _r, 0.5), maxf((_r - hueco) * 0.5, 2.0), Color(LUZ_DORADA, 0.18 * apaga))
		return
	if capa == _delante:
		# Los PETALOS de la flor que se abre arriba del pilar (siluetas llenas), y luego caen deshaciendose en motas.
		if flor > 0.0 and apaga > 0.0:
			var abre_f: float = 1.0 - pow(1.0 - flor, 3.0)
			for i in 8:
				var a: float = TAU * float(i) / 8.0 + _t * 0.8
				var largo_f: float = 30.0 * abre_f * (0.8 + 0.2 * float(i % 2))
				var dir := Vector2(cos(a), sin(a) * K)
				_pluma(capa, top + dir * largo_f * 0.5, largo_f, dir.angle(), apaga)
		# Las MOTAS que levanta la onda al pasar, subiendo.
		if t_o >= 0.0:
			for m in _motas:
				var u_m: float = float(m["d"])
				var tm: float = t_o - T_ONDA_LUZ * (1.0 - sqrt(1.0 - u_m))
				if tm < 0.0 or tm > 0.8:
					continue
				var pm: Vector2 = _c + Vector2(cos(float(m["a"])), sin(float(m["a"]))) * _r * u_m + _alto(tm * 40.0)
				_estrella(capa, pm, float(m["tam"]) * 0.35, float(m["tam"]), 4, _t * 3.0, Color(LUZ_BLANCA, 1.0 - tm / 0.8),
					Color(LUZ_DORADA, 0.8 * (1.0 - tm / 0.8)), 0.4)
		return
	if capa == _brillo:
		# EL PILAR: una columna calida con el nucleo blanco que sube de tus pies, y su resplandor.
		if apaga > 0.0:
			var ancho_p: float = 17.0 * (1.0 - 0.4 * clampf(t_fin / T_APAGA_LUZ, 0.0, 1.0))
			# Relleno en tres bandas verticales: bordes transparentes, centro opaco (sin rayas).
			for j in 2:
				var s: float = -1.0 if j == 0 else 1.0
				capa.draw_primitive(PackedVector2Array([_c + Vector2(s * ancho_p, 0.0), _c, top, top + Vector2(s * ancho_p * 0.6, 0.0)]),
					PackedColorArray([Color(LUZ_DORADA, 0.0), Color(LUZ_DORADA, 0.85 * apaga), Color(LUZ_DORADA, 0.6 * apaga),
						Color(LUZ_DORADA, 0.0)]), PackedVector2Array())
				capa.draw_primitive(PackedVector2Array([_c + Vector2(s * ancho_p * 0.35, 0.0), _c, top, top + Vector2(s * ancho_p * 0.2, 0.0)]),
					PackedColorArray([Color(LUZ_BLANCA, 0.0), Color(LUZ_BLANCA, 0.9 * apaga), Color(LUZ_BLANCA, 0.7 * apaga),
						Color(LUZ_BLANCA, 0.0)]), PackedVector2Array())
			BarridoAire.brillo(capa, top, 14.0 + 8.0 * flor, Color(LUZ_DORADA, 0.35 * apaga))
			BarridoAire.destello(capa, top, 10.0 + 4.0 * flor, Color(LUZ_BLANCA, 0.8 * apaga), _t * 0.8)


# LA COLUMNA DE LUZ sobre uno de los tuyos al curarlo ('caja' = su cuerpo): la luz le cae encima, bajan PLUMAS
# meciendose, suben MOTAS doradas y se le queda un HALO sobre la cabeza un momento.
static func columna_luz(padre: Node, caja: Rect2, semilla: int, espera: float, ritmo: float) -> MagiaMayor:
	if padre == null:
		return null
	var e := MagiaMayor.new()
	e.modo = Modo.COLUMNA_LUZ
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._c = Vector2(caja.get_center().x, caja.end.y)       # sus pies
	e._r = maxf(caja.size.y, 20.0)                         # su alto
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	for i in 5:
		e._trozos.append({"x": e._rng.randf_range(-12.0, 12.0), "t0": e._rng.randf_range(0.0, 0.25),
			"largo": e._rng.randf_range(5.0, 8.0), "fase": e._rng.randf_range(0.0, TAU)})
	for i in 10:
		e._motas.append({"x": e._rng.randf_range(-10.0, 10.0), "t0": e._rng.randf_range(0.05, 0.5),
			"tam": e._rng.randf_range(1.6, 2.8)})
	e._suelo = e._capa(SueloRoto.Z_SUELO, true)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


func _columna_luz(capa: Node2D) -> void:
	if _t < -0.08:
		return
	var alto_c: float = _r * 1.6
	var baja: float = clampf((_t + 0.08) / 0.12, 0.0, 1.0)
	var vive: float = 1.0 - clampf((_t - 0.35) / 0.45, 0.0, 1.0)
	var cabeza: Vector2 = _c + Vector2(0.0, -_r - 6.0)
	if capa == _suelo:
		if _t >= 0.0:
			var ks: float = clampf(_t / 0.4, 0.0, 1.0)
			MagiaAire._anillo(capa, _c, 5.0 + 16.0 * (1.0 - pow(1.0 - ks, 2.0)), 3.0, Color(LUZ_DORADA, 0.8 * (1.0 - ks)))
			BarridoAire.brillo(capa, _c, 14.0, Color(LUZ_DORADA, 0.45 * vive))
		return
	if capa == _delante:
		# Las PLUMAS que bajan meciendose alrededor del cuerpo.
		for pl in _trozos:
			var tp: float = _t - float(pl["t0"])
			if tp < 0.0 or tp > 0.9:
				continue
			var kp: float = tp / 0.9
			var p: Vector2 = _c + Vector2(float(pl["x"]) + sin(tp * 6.0 + float(pl["fase"])) * 5.0, -alto_c * (1.0 - kp) * 0.9)
			_pluma(capa, p, float(pl["largo"]), 0.6 * sin(tp * 6.0 + float(pl["fase"])) + PI * 0.5 * 0.3, sin(kp * PI))
		# El HALO sobre la cabeza.
		if _t >= 0.05:
			var kh: float = clampf((_t - 0.05) / 0.15, 0.0, 1.0)
			var al_h: float = kh * (1.0 - clampf((_t - 0.6) / 0.35, 0.0, 1.0))
			MagiaAire._anillo(capa, cabeza, 6.5, 2.4, Color(LUZ_DORADA, al_h), 0.4)
			MagiaAire._anillo(capa, cabeza, 6.5, 1.0, Color(LUZ_BLANCA, al_h), 0.4)
		return
	if capa == _brillo:
		# LA COLUMNA que le cae encima (banda calida con nucleo blanco) y las MOTAS que suben.
		if vive > 0.0:
			var arriba: Vector2 = _c + Vector2(0.0, -alto_c)
			var bajo: Vector2 = arriba.lerp(_c, baja)
			var w: float = 9.0
			for j in 2:
				var s: float = -1.0 if j == 0 else 1.0
				capa.draw_primitive(PackedVector2Array([arriba + Vector2(s * w, 0.0), arriba, bajo, bajo + Vector2(s * w, 0.0)]),
					PackedColorArray([Color(LUZ_DORADA, 0.0), Color(LUZ_DORADA, 0.55 * vive), Color(LUZ_DORADA, 0.8 * vive),
						Color(LUZ_DORADA, 0.0)]), PackedVector2Array())
				capa.draw_primitive(PackedVector2Array([arriba + Vector2(s * w * 0.3, 0.0), arriba, bajo, bajo + Vector2(s * w * 0.3, 0.0)]),
					PackedColorArray([Color(LUZ_BLANCA, 0.0), Color(LUZ_BLANCA, 0.6 * vive), Color(LUZ_BLANCA, 0.9 * vive),
						Color(LUZ_BLANCA, 0.0)]), PackedVector2Array())
		for m in _motas:
			var tm: float = _t - float(m["t0"])
			if tm < 0.0 or tm > 0.6:
				continue
			var pm: Vector2 = _c + Vector2(float(m["x"]), -tm * 60.0)
			BarridoAire.destello(capa, pm, float(m["tam"]) * 2.2, Color(LUZ_BLANCA, 1.0 - tm / 0.6), tm * 4.0)
		if _t >= 0.0 and _t < 0.2:
			BarridoAire.brillo(capa, _c + Vector2(0.0, -_r * 0.5), 20.0 * (1.0 - _t / 0.2), Color(LUZ_BLANCA, 0.5 * (1.0 - _t / 0.2)))


# ------------------------------------------------------------
#  EL ECLIPSE (sus referencias: disco negro con corona de llamas blanco-azuladas de borde magenta; esquirlas negras con
#  los bordes partidos en cian, magenta y amarillo, tipo glitch)
# ------------------------------------------------------------
static func t_llega_eclipse(f: CombatFormas.Forma) -> float:
	return T_CARGA_SOL + maxf(f.ancho - 6.0, 0.0) / V_ORBE_ECLIPSE


# UNA ESQUIRLA de la oscuridad: cristal negro con el filo MORADO a un lado y BLANCO al otro (la oscuridad y la luz:
# 27/09, sin los colores de arcoiris de antes). Dos copias desplazadas y la negra encima.
static func _esquirla_glitch(ci: CanvasItem, pts: PackedVector2Array, off: float, alfa: float) -> void:
	if alfa <= 0.0 or pts.size() < 3:
		return
	var copias: Array = [[Vector2(-off, -off * 0.5), ECLIPSE_MORADO], [Vector2(off, off * 0.5), CORONA_BLANCA]]
	for cp in copias:
		var q := PackedVector2Array()
		for p in pts:
			q.append(p + (cp[0] as Vector2))
		ci.draw_colored_polygon(q, Color(cp[1] as Color, 0.9 * alfa))
	ci.draw_colored_polygon(pts, Color(NEGRO, alfa))


# EL CAMINO de una llama de la corona: sale del borde en 'a', sube 'largo' y hace una S (y la punta se riza). 'u' de 0
# (el borde) a 1 (la punta). Las capas de una misma llama siguen el MISMO camino y por eso encajan (su referencia).
func _camino_llama(c: Vector2, a: float, r0: float, largo: float, fase: float, u: float) -> Vector2:
	var d := Vector2(cos(a), sin(a))
	var t := Vector2(-d.y, d.x)
	var ola: float = sin(u * 3.2 + fase + _t * 4.0) * largo * 0.17 * u
	var rizo: float = pow(u, 3.0) * largo * 0.22 * sin(fase * 1.7)
	return c + d * (r0 + largo * u) + t * (ola + rizo)


# Una capa de la llama: banda por el camino, de 'u0' a 'u1', con su ancho maximo 'w' (gorda abajo, punta fina).
func _banda_llama(ci: CanvasItem, c: Vector2, a: float, r0: float, largo: float, fase: float, u0: float, u1: float,
		w: float, desvio: float, col: Color) -> void:
	if w <= 0.2 or col.a <= 0.0 or u1 <= u0:
		return
	var n: int = 10
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for k in n + 1:
		var u: float = lerpf(u0, u1, float(k) / float(n))
		var p0: Vector2 = _camino_llama(c, a, r0, largo, fase, u)
		var p1: Vector2 = _camino_llama(c, a, r0, largo, fase, minf(u + 0.03, 1.0))
		var tg: Vector2 = (p1 - p0).normalized() if p1.distance_squared_to(p0) > 0.0001 else Vector2(cos(a), sin(a))
		var nor := Vector2(-tg.y, tg.x)
		var k2: float = float(k) / float(n)
		var ww: float = w * pow(1.0 - k2, 0.8) * (0.75 + 0.35 * sin(minf(k2 * 3.0, 1.0) * PI * 0.5))
		var centro: Vector2 = p0 + nor * desvio * w
		pv.append(centro + nor * ww)
		pv.append(centro - nor * ww)
		pc.append(col)
		pc.append(col)
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# LA CORONA (27/09, tercera, su referencia): una MELENA de llamas en S muy juntas; cada llama es UNA forma con sus capas
# encajadas: el BORDE MORADO (la mas ancha y larga, con la punta en hebra), el CUERPO AZUL, y la VETA BLANCO-AMARILLA
# brillante por dentro. Entre llama y llama, HEBRAS finas que se rizan. Y el ARO BLANCO grueso pegado al disco.
func _corona_eclipse(ci: CanvasItem, c: Vector2, r: float, largo: float, alfa: float) -> void:
	if alfa <= 0.0 or largo <= 0.5:
		return
	var paso: float = floor(_t * 8.0)
	var n: int = LENGUAS_ECLIPSE
	for i in n:
		var a: float = TAU * float(i) / float(n) + _t * 0.2 + 0.08 * sin(float(i) * 2.3)
		var salto: float = MagiaAire._ruido(float(i) + paso * 0.7, float(_semilla % 29))
		var l: float = largo * (0.65 + 0.5 * MagiaAire._ruido(float(i), 4.0) + 0.12 * salto)
		var fase: float = float(i) * 2.1
		var w: float = r * 0.2
		_banda_llama(ci, c, a, r * 0.92, l, fase, 0.0, 1.0, w, 0.0, Color(ECLIPSE_MORADO, alfa))
		_banda_llama(ci, c, a, r * 0.92, l, fase, 0.0, 0.8, w * 0.72, -0.15, Color(ECLIPSE_AZUL, alfa))
		_banda_llama(ci, c, a, r * 0.92, l, fase, 0.0, 0.62, w * 0.3, -0.35, Color(ECLIPSE_LUZ, alfa))
		# La hebra que sale entre esta llama y la siguiente.
		var a2: float = a + PI / float(n)
		_banda_llama(ci, c, a2, r * 0.95, l * 0.8, fase + 1.3, 0.1, 1.0, r * 0.06, 0.0, Color(ECLIPSE_AZUL.lightened(0.3), 0.85 * alfa))
	MagiaAire._anillo(ci, c, r * 1.04, r * 0.2, Color(ECLIPSE_AZUL.lightened(0.4), alfa))
	MagiaAire._anillo(ci, c, r * 1.0, r * 0.1, Color(1.0, 1.0, 1.0, alfa))


func _eclipse(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var tl: float = t_llega_eclipse(forma)
	var tn: float = _t - tl                                  # desde que nace el disco
	var t_osc: float = tn - T_FORMA_ECLIPSE                  # desde el golpe de oscuridad
	var t_luz: float = t_osc - T_ENTRE_ECLIPSE               # desde el de luz
	var nace: float = 1.0 - pow(1.0 - clampf(tn / T_FORMA_ECLIPSE, 0.0, 1.0), 3.0)
	var cierra: float = clampf((t_osc - T_VIVE_ECLIPSE) / T_CIERRA_ECLIPSE, 0.0, 1.0)
	var vivo: float = nace * (1.0 - cierra * cierra)
	var disco: Vector2 = _c + _alto(ALTO_ECLIPSE)
	var r_d: float = clampf(_r * 0.24, 22.0, 36.0) * vivo
	var mano: Vector2 = _o + _alto(ALTO_MANO)
	# 1) LA CARGA y el ORBE (negro con el borde blanco) que sube de tu mano al cielo del circulo.
	if tn < 0.0:
		if capa != _delante:
			return
		if _t < T_CARGA_SOL:
			var kc: float = _t / T_CARGA_SOL
			_disco(capa, mano, 2.0 + 5.0 * kc, NEGRO, NEGRO)
			MagiaAire._anillo(capa, mano, 3.0 + 5.0 * kc, 2.0, Color(CORONA_BLANCA, kc))
			return
		var u: float = clampf((_t - T_CARGA_SOL) / maxf(tl - T_CARGA_SOL, 0.01), 0.0, 1.0)
		var p: Vector2 = mano.lerp(disco, u) + _alto(14.0 * sin(u * PI))
		for k in 5:
			var uk: float = u - 0.07 * float(k + 1)
			if uk < 0.0:
				break
			var pk: Vector2 = mano.lerp(disco, uk) + _alto(14.0 * sin(uk * PI))
			MagiaAire._anillo(capa, pk, 4.0 - 0.5 * float(k), 1.6, Color(ECLIPSE_MORADO if k % 2 == 0 else ECLIPSE_LUZ, 0.8 - 0.14 * float(k)))
		_disco(capa, p, 6.0, NEGRO, NEGRO)
		MagiaAire._anillo(capa, p, 6.0, 2.0, Color(CORONA_BLANCA, 1.0))
		return
	if vivo <= 0.0 and cierra >= 1.0:
		return
	if capa == _suelo:
		# LA SOMBRA que se traga el circulo (mas negra en el golpe de oscuridad) y luego la LUZ que lo barre.
		var osc: float = clampf(tn / T_FORMA_ECLIPSE, 0.0, 1.0) * 0.45 + (0.35 * exp(-maxf(t_osc, 0.0) * 3.0) if t_osc >= 0.0 else 0.0)
		BarridoAire.brillo(capa, _c, _r * 1.1, Color(NEGRO, osc * (1.0 - cierra)))
		if t_luz >= 0.0 and t_luz < 0.6:
			var kl: float = t_luz / 0.6
			var fr: float = _r * (1.0 - pow(1.0 - kl, 2.0))
			MagiaAire._anillo(capa, _c, fr, 12.0, Color(CORONA_BLANCA, 0.7 * (1.0 - kl)))
			MagiaAire._anillo(capa, _c, fr, 5.0, Color(ECLIPSE_LUZ, 0.8 * (1.0 - kl)))
		# El borde del circulo, una raya de luz fria mientras dura (que se sepa hasta donde llega).
		MagiaAire._anillo(capa, _c, _r, 4.0, Color(CORONA_BLANCA, 0.25 * vivo))
		return
	if capa == _delante:
		# LAS ESQUIRLAS del golpe de oscuridad: cristales negros afilados que salen del disco hacia fuera por todo el
		# circulo y caen, con su aberracion cromatica.
		if t_osc >= 0.0 and t_osc < 0.75:
			var ke: float = t_osc / 0.75
			for ez in _esquirlas:
				var d: float = _r * float(ez["d"]) * (1.0 - pow(1.0 - minf(1.0, ke * 1.5), 2.0))
				var dir: Vector2 = ez["dir"]
				var h: float = ALTO_ECLIPSE * (1.0 - minf(1.0, ke * 1.3)) * float(ez["alto"])
				var base: Vector2 = _c + dir * d + _alto(h)
				var largo: float = float(ez["largo"]) * (1.0 - ke * 0.4)
				var ancho: float = float(ez["ancho"])
				var eje: Vector2 = (dir + Vector2(0.0, -0.3 * (1.0 - ke))).normalized()
				var nor := Vector2(-eje.y, eje.x)
				var pts := PackedVector2Array([base - eje * largo * 0.3 + nor * ancho, base + eje * largo,
					base - eje * largo * 0.3 - nor * ancho * 0.6])
				_esquirla_glitch(capa, pts, 3.0, 1.0 - smoothstep(0.7, 1.0, ke))
		# EL DISCO y su CORONA: negro puro, con las llamas alrededor; en el golpe de luz la corona ESTALLA hacia fuera.
		var estalla: float = 0.0
		if t_luz >= 0.0:
			estalla = exp(-t_luz * 4.0) * minf(1.0, t_luz * 20.0)
		var largo_c: float = r_d * (2.2 + 1.8 * estalla) * (0.6 + 0.4 * vivo)
		_corona_eclipse(capa, disco, r_d, largo_c, vivo)
		_disco(capa, disco, r_d, NEGRO, NEGRO)
		MagiaAire._anillo(capa, disco, r_d, 2.5, Color(CORONA_BLANCA, vivo))
		return
	if capa == _brillo:
		# El resplandor frio del borde del disco; el FOGONAZO del golpe de luz y sus PETALOS de luz por todo el circulo;
		# y el destello al cerrarse.
		# (un aro, no un brillo encima: el disco tiene que seguir negro)
		MagiaAire._anillo(capa, disco, r_d * 1.15, r_d * 0.5, Color(CORONA_BLANCA, 0.3 * vivo))
		if t_luz >= 0.0 and t_luz < 0.5:
			var kf: float = t_luz / 0.5
			# (un aro, no un brillo encima: el disco sigue negro tambien en la luz)
			MagiaAire._anillo(capa, disco, r_d * (1.6 + 1.5 * kf), r_d * 1.2, Color(ECLIPSE_LUZ, 0.5 * (1.0 - kf)))
			for i in 10:
				var a: float = TAU * float(i) / 10.0 + 0.3
				var l2: float = _r * (0.5 + 0.6 * kf) * (0.8 + 0.2 * float(i % 2))
				# Desde el BORDE del disco (no desde el centro: cruzaban por encima del negro).
				_cuna(capa, disco, a, r_d * 1.1, r_d * 1.1 + l2, 0.16, Color(ECLIPSE_LUZ, 0.6 * (1.0 - kf)))
				_cuna(capa, disco, a, r_d * 1.1, r_d * 1.1 + l2 * 0.8, 0.08, Color(1.0, 1.0, 1.0, 0.8 * (1.0 - kf)))
		if cierra > 0.0 and cierra < 1.0:
			BarridoAire.destello(capa, disco, 34.0 * (1.0 - cierra), Color(CORONA_BLANCA, 1.0 - cierra), 0.4)


# ------------------------------------------------------------
#  EL MANTO PRISMATICO
# ------------------------------------------------------------
# El color del arcoiris de 'h' (0..1), plano y vivo.
static func arcoiris(h: float, v: float = 1.0) -> Color:
	return Color.from_hsv(fposmod(h, 1.0), 0.72, v)


# UN PETALO PRISMATICO (su referencia): hoja de tono plano con PINCHOS en el borde de fuera y un ANILLO dentro (un
# ojo claro con nucleo), orientada por 'eje'; 'blanco' la hace silueta blanca (los de delante del chorro).
static func _petalo_prisma(ci: CanvasItem, p: Vector2, eje: Vector2, largo: float, col: Color, alfa: float, sem: float,
		blanco: bool) -> void:
	if largo <= 0.8 or alfa <= 0.0:
		return
	var nor := Vector2(-eje.y, eje.x)
	var pts := PackedVector2Array()
	var n: int = 9
	for k in n + 1:
		var u: float = float(k) / float(n)
		var w: float = largo * 0.34 * sin(u * PI) * (1.0 - 0.25 * u)
		# Los pinchos, por el lado de fuera.
		if k % 3 == 1:
			w *= 1.45
		pts.append(p + eje * (u - 0.5) * largo + nor * w)
	for k in range(n - 1, 0, -1):
		var u2: float = float(k) / float(n)
		pts.append(p + eje * (u2 - 0.5) * largo - nor * largo * 0.26 * sin(u2 * PI) * (1.0 - 0.25 * u2))
	var fondo: Color = Color(1.0, 1.0, 1.0, alfa) if blanco else Color(col, alfa)
	if Geometry2D.triangulate_polygon(pts).size() > 0:
		ci.draw_colored_polygon(pts, fondo)
	# El anillo de dentro (un "ojo"): circulo claro con el nucleo del color.
	var ojo: Vector2 = p + eje * largo * 0.05
	var r_o: float = largo * 0.16
	ci.draw_circle(ojo, r_o, Color(col.lightened(0.55) if not blanco else col, alfa))
	ci.draw_circle(ojo, r_o * 0.55, Color(col.darkened(0.15) if not blanco else Color(1, 1, 1), alfa))
	if MagiaAire._ruido(sem, 3.0) < 0.5:
		ci.draw_circle(ojo, r_o * 0.25, Color(1.0, 1.0, 1.0, alfa))


func _prisma(capa: Node2D) -> void:
	# EL ARRANQUE en el que la lanza: motas de arcoiris que se juntan en su pecho, un destello en estrella y un ANILLO
	# multicolor que se abre por el suelo hasta el borde (80 px): a quien pille, le llega su chorro de petalos.
	if _t < 0.0:
		return
	var pecho: Vector2 = _c + _alto(14.0)
	var kc: float = clampf(_t / T_CARGA_PRISMA, 0.0, 1.0)
	var t_o: float = _t - T_CARGA_PRISMA
	if capa == _suelo:
		if t_o >= 0.0 and t_o < 0.6:
			var ko: float = t_o / 0.6
			var fr: float = _r * (1.0 - pow(1.0 - ko, 2.0))
			for j in 6:
				MagiaAire._anillo(capa, _c, fr - float(j) * 3.0, 3.0, Color(arcoiris(float(j) / 6.0 + _t), 0.8 * (1.0 - ko)))
		return
	if capa == _delante:
		if t_o < 0.0:
			for m in _motas:
				var km: float = clampf((_t - float(m["t0"])) / (T_CARGA_PRISMA - float(m["t0"])), 0.0, 1.0)
				var desde: Vector2 = pecho + Vector2(cos(float(m["a"])), sin(float(m["a"])) * K) * float(m["d"])
				_petalo_prisma(capa, desde.lerp(pecho, km * km), (pecho - desde).normalized(), 7.0 * (1.0 - km * 0.6),
					arcoiris(float(m["h"])), 1.0, float(m["h"]) * 10.0, false)
		return
	if capa == _brillo:
		if t_o < 0.0:
			BarridoAire.brillo(capa, pecho, 6.0 + 10.0 * kc, Color(arcoiris(_t * 2.0), 0.5 * kc))
		elif t_o < 0.45:
			var kd: float = t_o / 0.45
			BarridoAire.destello(capa, pecho, 26.0 * (1.0 - kd * 0.5), Color(1.0, 1.0, 1.0, 1.0 - kd), 0.3)
			for j in 6:
				BarridoAire.brillo(capa, pecho + Vector2(cos(TAU * float(j) / 6.0), sin(TAU * float(j) / 6.0) * K) * 10.0 * kd,
					7.0, Color(arcoiris(float(j) / 6.0), 0.6 * (1.0 - kd)))


# EL CHORRO DE PETALOS hasta uno de los tuyos (su referencia): petalos de arcoiris que vuelan en arco de 'desde' a su
# cuerpo, le dan vueltas subiendole por el cuerpo y revientan en chispas de colores sobre su cabeza.
static func petalos_prisma(padre: Node, desde: Vector2, caja: Rect2, semilla: int, espera: float, ritmo: float) -> MagiaMayor:
	if padre == null:
		return null
	var e := MagiaMayor.new()
	e.modo = Modo.PETALOS_PRISMA
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._o = desde
	e._c = Vector2(caja.get_center().x, caja.end.y)      # sus pies
	e._r = maxf(caja.size.y, 16.0) / K                   # su alto ("altura")
	e._duracion_vuelo = maxf(espera, 0.1)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	for i in PETALOS_CHORRO:
		e._trozos.append({"h": float(i) / float(PETALOS_CHORRO) + e._rng.randf_range(-0.03, 0.03),
			"retraso": float(i) * 0.035, "lado": e._rng.randf_range(-8.0, 8.0), "largo": e._rng.randf_range(11.0, 16.0)})
	for i in 12:
		var a: float = e._rng.randf_range(0.0, TAU)
		e._motas.append({"d": Vector2(cos(a), sin(a) * K), "v": e._rng.randf_range(30.0, 70.0), "h": e._rng.randf()})
	e._suelo = e._capa(SueloRoto.Z_SUELO, true)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


func _pos_chorro(u: float, lado: float) -> Vector2:
	var pecho: Vector2 = _c + _alto(_r * 0.5)
	var d: Vector2 = pecho - _o
	var nor: Vector2 = d.normalized().orthogonal() if d.length_squared() > 1.0 else Vector2.UP
	return _o.lerp(pecho, u) + _alto(20.0 * sin(u * PI)) + nor * lado * sin(u * PI)


func _petalos_prisma(capa: Node2D) -> void:
	var t_vuelo: float = _t + _duracion_vuelo            # desde que salen
	if capa == _suelo:
		if _t >= 0.0 and _t < 0.8:
			var ks: float = _t / 0.8
			for j in 3:
				MagiaAire._anillo(capa, _c, 6.0 + 20.0 * (1.0 - pow(1.0 - ks, 2.0)) - float(j) * 3.0, 2.5,
					Color(arcoiris(float(j) / 3.0 + _t), 0.8 * (1.0 - ks)))
		return
	if capa == _delante:
		for pt in _trozos:
			var tp: float = t_vuelo - float(pt["retraso"])
			if tp < 0.0:
				continue
			var u: float = tp / _duracion_vuelo
			var col: Color = arcoiris(float(pt["h"]) + _t * 0.3)
			var blanco: bool = float(pt["retraso"]) < 0.04        # el de delante del chorro, en silueta blanca
			if u < 1.0:
				# EL VUELO en arco hasta su pecho.
				var p: Vector2 = _pos_chorro(u, float(pt["lado"]))
				var sig: Vector2 = _pos_chorro(minf(u + 0.05, 1.0), float(pt["lado"]))
				var eje: Vector2 = (sig - p).normalized() if sig.distance_squared_to(p) > 0.01 else Vector2.RIGHT
				_petalo_prisma(capa, p, eje, float(pt["largo"]), col, 1.0, float(pt["h"]) * 10.0, blanco)
			else:
				# LA ESPIRAL por su cuerpo, de los pies a la cabeza, y se deshace.
				var ks2: float = (tp - _duracion_vuelo) / T_ESPIRAL_PRISMA
				if ks2 >= 1.0:
					continue
				var a: float = ks2 * TAU * 2.0 + float(pt["h"]) * TAU
				var r_e: float = 11.0
				var p2: Vector2 = _c + Vector2(cos(a) * r_e, sin(a) * r_e * K) + _alto(_r * ks2)
				var eje2 := Vector2(-sin(a), cos(a) * K).normalized()
				_petalo_prisma(capa, p2, eje2, float(pt["largo"]) * (1.0 - ks2 * 0.5), col, 1.0 - smoothstep(0.7, 1.0, ks2),
					float(pt["h"]) * 10.0, false)
		return
	if capa == _brillo:
		# LAS CHISPAS de colores sobre la cabeza cuando llega la espiral arriba.
		var t_r: float = _t - T_ESPIRAL_PRISMA * 0.8
		if t_r >= 0.0 and t_r < 0.5:
			var kr: float = t_r / 0.5
			var cabeza: Vector2 = _c + _alto(_r + 4.0)
			BarridoAire.destello(capa, cabeza, 20.0 * (1.0 - kr * 0.5), Color(1.0, 1.0, 1.0, 1.0 - kr), kr)
			for m in _motas:
				var pm: Vector2 = cabeza + (m["d"] as Vector2) * float(m["v"]) * t_r + Vector2(0.0, 50.0 * t_r * t_r)
				BarridoAire.destello(capa, pm, 4.0, Color(arcoiris(float(m["h"])), 1.0 - kr), t_r * 6.0)
