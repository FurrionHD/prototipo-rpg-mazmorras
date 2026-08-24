# ============================================================
#  trent_sprites.gd  (class_name TrentSprites)
#  Sprite del TRENT dibujado por codigo, con el motor comun (SpriteLienzo) y la camara de 45 grados
#  que comparten todos los bichos. Aparece en los pisos 4-6.
#
#  ES UN ARBOL ANDANTE BIPEDO, y ENCORVADO: el tronco se inclina hacia delante y la copa cuelga por
#  encima como una cabeza demasiado grande, con flecos de hojas colgando. No es el ent noble y
#  erguido -- esa postura jorobada es lo que lo hace leerse como bicho y no como decorado.
#
#  VA POR EL PATRON DEL SLIME, NO POR EL DE LA RATA: un tronco es casi redondo en planta, o sea que
#  se ve igual desde los ocho lados. Girar el cuerpo entero no cambiaria nada y solo costaria. Lo
#  que SI gira son los BRAZOS, la CARA y la GRIETA, clavados por direccion con el mismo mecanismo
#  que los cuernos del slime (_en_el_tronco + _rama).
#
#  ES EL PRIMER ENEMIGO ALTO DEL JUEGO. Con la camara a 45 grados la altura sube en pantalla por
#  sin(45), asi que su lienzo crece MUCHO hacia arriba: es rectangular y con el origen bajo, igual
#  que el del slime, porque el origen es el punto que toca el suelo y todo el bicho queda encima.
#
#  Su identidad sale de sus habilidades: "escupe por una GRIETA DE LA CORTEZA un chorro espeso"
#  (savia corrosiva), "gira medio cuerpo y te barre con una RAMA del grosor de un brazo" (ramazo),
#  "el suelo se abre bajo tus pies y sube algo que no piensa soltarte" (raices atenazantes). O sea
#  CORTEZA AGRIETADA, BRAZOS-RAMA y RAICES -- y las tres estan dibujadas.
#
#  Es lentisimo (Agilidad 10, el mas bajo del juego) y durisimo (Resistencia 55, el mas alto), y eso
#  manda en sus animaciones: nada de botes ni de nervio, todo es peso y balanceo.
# ============================================================

extends RefCounted
class_name TrentSprites

const FRAMES := 8

# --- El trent mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia donde
# mira, +Z hacia arriba). A escala 1.0 mide unas 26 unidades de ancho de copa. ---
const ANCHO_MUNDO := 26.0

# TRONCO: el cuerpo. Va INCLINADO hacia delante (su centro cae adelantado respecto a los pies), que
# es lo que da la postura encorvada. Redondo en planta -- por eso el cuerpo no necesita girar.
const TRONCO := Vector3(0.0, 1.6, 19.0)
const TRONCO_R := Vector3(6.2, 5.4, 13.0)
# Para CLAVAR los adornos hace falta un radio redondo en planta: si se usara el del dibujo, un
# tronco con menos fondo que ancho pondria los brazos a distinta distancia segun hacia donde mire y
# entrarian y saldrian del cuerpo al girar.
const TRONCO_ANCLA_R := Vector3(6.2, 6.2, 13.0)
# COPA: la masa de hojas. Va ARRIBA y ADELANTADA -- cuelga por delante, como una cabeza pesada.
# Menos ancha y mas alta que el primer intento: con 13 de radio salia un CHAMPIÑON -- una seta con
# patas -- y se comia el tronco entero. La copa tiene que dejar ver el arbol que hay debajo.
const COPA := Vector3(0.0, 4.0, 34.0)
const COPA_R := Vector3(10.5, 8.2, 10.5)
# Y el radio REDONDO EN PLANTA con el que se clavan los ojos y los cuernos. Es el MENOR de los dos
# de la copa a proposito: asi el adorno cae dentro de la fronda mire hacia donde mire. Anclandolos
# en COPA_R (que tiene mas ancho que fondo) los ojos se iban al filo al girar y asomaban por fuera
# -- el mismo fallo que ya tuvo el slime, y por eso el tambien tiene su radio de anclaje aparte.
const COPA_ANCLA_R := Vector3(8.2, 8.2, 10.5)
# La copa iluminada: la misma masa, algo menor y subida. Deja por debajo la sombra de la fronda.
const COPA_SUBE := 0.26
const COPA_ESC := 0.93
# GRIETA de la corteza, por donde escupe la savia. Va en el frente del tronco.
const GRIETA_DIR := Vector3(0.0, 0.92, -0.39)
const GRIETA_R := Vector3(2.3, 2.3, 5.6)
const GRIETA_HUNDE := 1.2

# PIERNAS-TRONCO: dos, cortas y gruesas. El trent no tiene piernas largas: es un tocon que anda.
const PIERNA_X := 4.6
const PIERNA_R := Vector3(2.9, 2.9, 6.0)
const PIERNA_Z := 6.5
# CUANTO ADELANTA Y LEVANTA cada pie al dar el paso. Corto y bajo a proposito: tiene Agilidad 10 y
# tiene que leerse como que arrastra los pies, no como que trota.
const PASO_LARGO := 2.8
const PASO_ALZA := 1.2
# RAICES-PIE: matas de raices abiertas en el suelo. Cada pie son varias puntas alrededor.
#
# EL ANILLO VA CEÑIDO A LA PIERNA, no abierto. Abierto a 3.6 las raices solapaban con la pierna
# 0,8 unidades: a la resolucion vieja era casi una celda y a la nueva, ninguna -- y las matas
# aparecian SUELTAS bajo el bicho, flotando, en 188 de los 192 frames. Mismo fallo que los cuernos.
# Un solape de una celda no es un solape.
const RAICES_POR_PIE := 5
const RAIZ_RADIO := 2.4
const RAIZ_R := Vector3(2.0, 2.0, 1.3)

# BRAZOS-RAMA: dos, largos y CAIDOS, colgando a los lados. Se hacen en cadena de segmentos (como la
# cola de la rata): una sola pieza alargada no se curva, y una rama recta parece un palo clavado.
# Salen ALTO y a los LADOS, y se abren hacia fuera antes de caer. En el primer intento se abrian
# poco y caian mucho, asi que se cruzaban por delante del tronco y se leian como dos cuernos
# apuntando al centro en vez de como brazos colgando.
const BRAZO_DIR := Vector3(0.94, 0.16, 0.30)   # de donde SALEN del tronco
const BRAZO_SEGMENTOS := 6
# EL PASO TIENE QUE SER MENOR QUE EL GROSOR o el brazo sale a TROZOS SUELTOS -- una hilera de
# bolitas flotando al lado del bicho. Es la misma trampa que ya mordio la cola de la rata. Ojo: lo
# que cuenta es el paso EFECTIVO, o sea PASO * hipotenusa(ABRE, CAIDA), no el PASO a secas.
const BRAZO_PASO := 2.3
const BRAZO_R0 := 2.1
const BRAZO_R1 := 1.15
const BRAZO_ABRE := 0.50           # cuanto se separa del tronco cada segmento
const BRAZO_CAIDA := 0.78          # y cuanto baja: CUELGA, no sale en horizontal

# CUERNOS-RAMA: ramas retorcidas que salen de lo alto de la copa.
#
# VAN MUY HUNDIDOS, y no es capricho. Antes rozaban la copa: el de atras solapaba con ella UNA sola
# unidad de mundo. A la resolucion vieja eso eran dos celdas y colaba; al engordar el pixel se quedo
# en una, el redondeo se la comio, y los cuatro cuernos aparecieron FLOTANDO sobre la copa en 188 de
# los 192 frames.
#
# La leccion general: un solape de una o dos celdas no es un solape, es una casualidad. Lo que une
# dos piezas tiene que medir varias celdas para que aguante un cambio de resolucion. Y hay un test
# que lo caza solo -- contar islas de pixeles, ver dev_islas.gd.
const CUERNOS := 4
const CUERNO_ANILLO := 0.72
const CUERNO_ALTO := 0.62          # mas bajo en la copa: nace de la masa, no de la coronilla
const CUERNO_R := Vector3(1.5, 1.5, 6.0)
const CUERNO_HUNDE := 4.5          # la base bien METIDA en la fronda

# OJOS: dos puntos claros dentro de la sombra de la copa. Son LO QUE LO HACE CRIATURA -- sin ellos
# es un arbusto con brazos. Van bajos en la copa, o sea asomando por debajo de la fronda.
const OJO_DIR := Vector3(0.20, 0.92, -0.34)
const OJO_R := Vector3(1.15, 1.15, 1.25)
const OJO_HUNDE := 2.2
# Hasta donde puede irse un ojo hacia atras y seguir viendose (Y de su direccion, ya girada). Mismo
# criterio que el slime: de frente y de medio lado los dos, de perfil uno, de espaldas ninguno.
const OJO_VISIBLE := -0.15

# FLECOS: hojas colgando del borde de la copa, lo que le da el aire desgreñado.
const FLECOS := 7
const FLECO_R := Vector3(1.6, 1.6, 3.2)

# AQUI NO HAY ESCORZO COMPRIMIDO, y la razon merece quedar escrita porque costo un rato:
#
# El slime comprime la profundidad de sus cuernos para que el par se lea junto desde los ocho lados.
# Aqui eso NO SE PUEDE HACER, porque el tronco y la copa se dibujan SIN comprimir: si el cuerpo se
# proyecta con la Y entera y lo que va clavado en el con la Y a la mitad, en cuanto giran los dos
# dejan de coincidir y el adorno SE DESPEGA. Salia justo eso -- "se le salen separados los cuernos"
# y "en los ataques hacia los lados se le salen los ojos".
#
# La regla, para el proximo bicho: el escorzo de una pieza tiene que ser el MISMO que el de la pieza
# a la que va pegada. Comprimir solo vale cuando lo que sujeta al adorno es una bola que se ve igual
# desde todos lados (el slime), no cuando hay un cuerpo con forma detras.
const DETRAS_ESC := 0.80

const LUNGE_DIST := 5.0            # se mueve poco: es lentisimo

# --- EL LIENZO, en multiplos del ancho de la copa. Rectangular y con el origen BAJO, porque el
# origen es el punto que toca el suelo y todo el bicho crece hacia arriba. Los tres numeros salen de
# MEDIR la caja real de los 192 frames, no de calcularla a mano.
const LIENZO_ANCHO := 1.62
const LIENZO_ARRIBA := 2.10        # del suelo (el origen) hacia arriba: es un bicho ALTO
const LIENZO_ABAJO := 0.40

# TONOS propios. El motor no sabe que es cada uno; solo mapea indice -> color (ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, RAIZ, CORTEZA_OSC, CORTEZA, FRONDA_OSC, FRONDA, FRONDA_CLARA,
	GRIETA_T, SAVIA, OJO_T }

const DIR_VECS := [
	Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0), Vector2(0.7, -0.7),
	Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(-1, 0), Vector2(-0.7, 0.7),
]

const COLOR_PASOS := 6.0
static var _cache: Dictionary = {}
static var _cache_plantillas: Dictionary = {}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.escala_visual)


# La CLAVE de esta variante: la del cache y la del fichero horneado (ver SpriteLienzo.hornear).
static func clave_de(ed: EnemyData, t: float) -> String:
	return _clave(SpriteLienzo.cuantizar_hsv(ed.color_visual(t), COLOR_PASOS),
		snappedf(ed.escala_visual, 0.05))


static func _clave(col: Color, esc: float) -> String:
	return "trent_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta para la colision: SOLO EL TRONCO. La copa y los brazos NO cuentan, igual que
# la cola de la rata no cuenta -- lo que estorba de un arbol es el tronco, no lo que le cuelga.
# Redondo, asi que su colision no necesita girar.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	# LAS RAICES NO CUENTAN, igual que no cuenta la cola de la rata: son adorno pegado al suelo, y
	# metiendolas el trent medía 33,5 de lado -- mas que la CELDA de 32 px de la mazmorra, o sea que
	# no cabia por un pasillo de una celda y se quedaba trabado. Lo que estorba es el tronco y las
	# piernas.
	var lado: float = maxf(TRONCO_R.x, PIERNA_X + PIERNA_R.x) * 2.0
	return Vector2(lado, lado) * escala


static func _lienzo(escala: float) -> Vector2i:
	var u: float = ANCHO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(u * LIENZO_ANCHO))
	var h: int = int(ceil(u * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))


# Donde cae el ORIGEN (el punto que toca el suelo) dentro del lienzo: centrado a lo ancho y BAJO a
# lo alto, porque el bicho crece hacia arriba desde ahi.
static func _origen(escala: float) -> Vector2:
	var l: Vector2i = _lienzo(escala)
	return Vector2(float(l.x) * 0.5, float(l.y) * LIENZO_ARRIBA / (LIENZO_ARRIBA + LIENZO_ABAJO))


static func generar(color: Color = Color(0.35, 0.5, 0.25), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv: el verde del trent es apagado y redondear canal a canal le cambiaria el TONO.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	# Todo en UN atlas recortado (ver SpriteLienzo.montar_frames): dos tercios de cada frame del
	# lienzo completo eran aire transparente.
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	var lz: Vector2i = _lienzo(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lz.x, lz.y)
	_cache[clave] = sf
	return sf


# Quieto: la copa se mece, muy despacio. A 3 fps -- el mas lento del juego, y a proposito: tiene
# Agilidad 10 y tiene que LEERSE lento antes de que te des cuenta mirando su barra.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "mece": 0.5 * sin(TAU * t), "balanceo": 0.0,
			"brazos": 0.25 * sin(TAU * t + 0.8), "alza": 0.0, "patas": 0.0}
	_montar_animacion(anims, esc, "idle", true, 3.0, pose, false)


# Andando: NADA DE BOTE. Un arbol no salta; se BALANCEA de un lado al otro y arrastra el peso de un
# pie al otro. El balanceo lateral es lo que hace que se lea como un paso pesado.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "mece": 0.9 * sin(TAU * t), "balanceo": sin(TAU * t),
			"brazos": 0.8 * sin(TAU * t), "alza": 0.0, "patas": sin(TAU * t)}
	_montar_animacion(anims, esc, "walk", true, 5.0, pose, false)


# ALZA LOS BRAZOS Y DESCARGA. No es una carga a la carrera como la del jabali -- este bicho no corre
# -- sino el ramazo de su habilidad: "gira medio cuerpo y te barre con una rama". Se echa atras,
# levanta las ramas y las deja caer hacia delante.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var alza_keys := [[0.0, 0.0], [0.35, 1.0], [0.55, -0.9], [0.75, -0.4], [1.0, 0.0]]
	var avance_keys := [[0.0, 0.0], [0.35, -1.0], [0.55, 3.4], [0.75, 3.8], [1.0, 2.4]]
	var mece_keys := [[0.0, 0.0], [0.35, -1.2], [0.55, 1.6], [0.75, 0.8], [1.0, 0.2]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 3.8),
			"mece": SpriteLienzo.tramos(t, mece_keys), "balanceo": 0.0,
			"brazos": 0.0, "alza": SpriteLienzo.tramos(t, alza_keys),
			# Al descargar el ramazo PLANTA los pies y no da paso: el golpe sale del tronco.
			"patas": 0.0}
	_montar_animacion(anims, esc, "embestida", false, 8.0, pose, true)


static func _montar_animacion(anims: Array, esc: float, nombre: String,
		loop: bool, fps: float, pose_fn: Callable, ultimo_incluido: bool) -> void:
	var divisor: float = float(FRAMES - 1) if ultimo_incluido else float(FRAMES)
	for dir in 8:
		var plantillas: Array = []
		for i in FRAMES:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
#
# Un arbol son DOS materiales, y hay que verlo: la CORTEZA (marron, leñosa) y la FRONDA (verde, la
# de su ficha). El verde se queda tal cual porque ese color lo usa ya el resto del juego para el
# (particulas, tinte por fuerza); el marron se DERIVA de el, para que un trent aclarado por su 't'
# tenga tambien la madera aclarada y no se despareje.
static func _colores(color: Color) -> Array:
	var madera: Color = Color.from_hsv(0.09, 0.52, clampf(color.v * 0.72, 0.12, 0.62))
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.24),                 # SOMBRA_SUELO
		madera.darkened(0.70),                # BORDE
		madera.darkened(0.42),                # RAIZ (lo que arrastra por el suelo, sucio)
		madera.darkened(0.24),                # CORTEZA_OSC (el costado del tronco, en penumbra)
		madera,                               # CORTEZA
		color.darkened(0.34),                 # FRONDA_OSC (la hoja en sombra, bajo la copa)
		color,                                # FRONDA
		color.lightened(0.26),                # FRONDA_CLARA (lo alto de la copa, a la luz)
		madera.darkened(0.58),                # GRIETA_T (el tajo en la corteza)
		# SAVIA: amarillo verdoso y BRILLANTE, no un verde mas del monton. Es lo que sale por la
		# grieta, o sea su habilidad marca, y tiene que cantar contra la corteza oscura.
		Color(0.78, 0.86, 0.30),              # SAVIA
		Color(0.95, 0.93, 0.62),              # OJO_T (dos puntos claros en la sombra de la copa)
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Una direccion desde el centro del TRONCO -> el punto de su superficie en esa direccion, metido
# 'hunde' hacia dentro. Es lo que garantiza que ningun adorno flote: la superficie esta a distinta
# distancia en cada direccion, asi que un punto puesto a mano encaja mirando a un lado y se despega
# mirando al otro.
static func _en_el_tronco(dir: Vector3, hunde: float, centro: Vector3, radio: Vector3) -> Vector3:
	var d: Vector3 = dir.normalized()
	return centro + Vector3(radio.x * d.x, radio.y * d.y, radio.z * d.z) - d * hunde


# Las PIEZAS del trent para una pose, ya proyectadas a pantalla. El orden ES la profundidad: de lo
# mas bajo y lejano (sombra, raices, el brazo de detras) a lo mas alto y cercano (copa, ojos).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var origen: Vector2 = _origen(esc)
	var mece: float = float(pose["mece"])
	var balanceo: float = float(pose["balanceo"])
	var fase_brazos: float = float(pose["brazos"])
	var alza: float = float(pose["alza"])
	var avance: float = float(pose["avance"])

	var piezas: Array = []
	# El avance se rota UNA vez y lo llevan todas las piezas por igual: sumarlo a la Y local antes de
	# rotar dejaria al tronco (que no gira) saliendo siempre hacia el sur de la pantalla mientras los
	# brazos y la cara se van hacia donde de verdad mira.
	var desp := Vector2(0.0, avance).rotated(ang)
	# 'gira' = false para lo que no sigue al bicho al cambiar de rumbo: el tronco, la copa y sus
	# luces (un arbol se ve igual desde los ocho lados) y la sombra del suelo.
	# EL MECEO VA AQUI, DESPUES DE ROTAR, Y NO EN LAS COORDENADAS LOCALES DE CADA PIEZA.
	#
	# Estaba antes de rotar y era un desastre silencioso: el tronco y la copa NO giran y los adornos
	# SI, asi que el mismo meceo movia la copa en vertical y a los ojos y los cuernos en horizontal.
	# Se separaban del cuerpo justo en los frames de mas meceo -- los del medio de la embestida --,
	# que es exactamente cuando se mira. La regla general: todo lo que desplace al bicho ENTERO
	# (el avance, el meceo) se aplica en pantalla, igual para las piezas que giran y para las que no.
	#
	# Y se dobla POR EL TRONCO, o sea que cuanto mas alta la pieza mas se mueve: la copa va y viene y
	# las raices no se despegan del suelo.
	var mece_v := Vector2(balanceo * 1.6, mece * 1.5)
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			gira: bool = true) -> void:
		var p := Vector2(local.x, local.y)
		var alto: float = clampf(local.z / COPA.z, 0.0, 1.4)
		var rot: Vector2 = (p.rotated(ang) if gira else p) + desp + mece_v * alto
		var sx: float = origen.x + rot.x * u
		var sy: float = origen.y + (rot.y * SpriteLienzo.COS_CAM
			- local.z * SpriteLienzo.SIN_CAM) * u
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(r.x * u, r.y * u),
			"persp": SpriteLienzo.persp_de(r.y, r.z), "tono": tono, "solo_sobre": solo_sobre})

	# 1. SOMBRA DE CONTACTO, a ras de suelo.
	poner.call(Vector3(0.0, 0.0, 0.0), Vector3(TRONCO_R.x * 1.25, TRONCO_R.y * 1.25, 0.0),
		Tono.SOMBRA_SUELO, [], false)

	# LOS PIES, calculados una vez porque los usan las raices y las piernas.
	#
	# GIRAN CON EL BICHO (a diferencia del tronco y la copa, que son redondos y no giran) y DAN EL
	# PASO: uno adelante y otro atras, en contrafase. Estaban puestos sin girar y sin ciclo, o sea
	# clavados a los lados mirara a donde mirara y quietos mientras andaba -- un arbol deslizandose.
	# El que va adelantado se LEVANTA un poco; poco, que esto pesa y arrastra mas que pisa.
	var fase_patas: float = float(pose["patas"])
	var pies: Array = []
	for lado in [-1.0, 1.0]:
		var swing: float = fase_patas * lado
		pies.append(Vector3(lado * PIERNA_X, swing * PASO_LARGO,
			PIERNA_Z + maxf(0.0, swing) * PASO_ALZA))

	# 2. RAICES-PIE: una mata de puntas alrededor de cada pie, y se va CON el (si no, el pie da el
	#    paso y sus raices se quedan atras).
	for k2 in pies.size():
		var pie: Vector3 = pies[k2]
		for k in RAICES_POR_PIE:
			var a: float = TAU * float(k) / float(RAICES_POR_PIE) + (0.4 if k2 == 1 else 0.0)
			poner.call(Vector3(pie.x + cos(a) * RAIZ_RADIO, pie.y + sin(a) * RAIZ_RADIO,
				pie.z - PIERNA_Z + 1.0), RAIZ_R, Tono.RAIZ)

	# 3. EL BRAZO DE DETRAS. Cual es cual sale de su Y YA GIRADA -- una prueba de profundidad de
	#    verdad, no una tabla por direccion que haya que mantener.
	var brazos: Array = []
	for lado in [-1.0, 1.0]:
		var raiz: Vector3 = _en_el_tronco(
			Vector3(lado * BRAZO_DIR.x, BRAZO_DIR.y, BRAZO_DIR.z), 1.0, TRONCO, TRONCO_ANCLA_R)
		brazos.append({"lado": lado, "raiz": raiz,
			"delante": Vector2(raiz.x, raiz.y).rotated(ang).y > 0.0})
	for b in brazos:
		if not bool(b["delante"]):
			_rama(poner, b, fase_brazos, alza, DETRAS_ESC, Tono.CORTEZA_OSC)

	# 4. PIERNAS-TRONCO: cortas y gruesas, cada una sobre su pie.
	for pie in pies:
		poner.call(pie, PIERNA_R, Tono.CORTEZA_OSC)

	# 5. EL TRONCO, entero en penumbra...
	poner.call(TRONCO, TRONCO_R, Tono.CORTEZA_OSC, [], false)
	# ...y encima el mismo, algo menor y subido, a plena luz. Lo que queda sin cubrir por abajo es la
	# base del tronco en sombra, y la frontera sale curvada sola (es una elipse en perspectiva).
	poner.call(Vector3(TRONCO.x, TRONCO.y, TRONCO.z + TRONCO_R.z * 0.22),
		TRONCO_R * 0.94, Tono.CORTEZA, [Tono.CORTEZA_OSC], false)

	# 6. LA GRIETA de la corteza, por donde escupe la savia. Va en el frente del tronco y GIRA con
	#    el: si no, un trent visto de espaldas seguiria enseñandola.
	var gr: Vector3 = _en_el_tronco(GRIETA_DIR, GRIETA_HUNDE, TRONCO, TRONCO_ANCLA_R)
	if Vector2(gr.x, gr.y).rotated(ang).y > 0.0:
		poner.call(gr, GRIETA_R, Tono.GRIETA_T)
		poner.call(Vector3(gr.x, gr.y, gr.z - GRIETA_R.z * 0.45), GRIETA_R * 0.42, Tono.SAVIA)

	# 7. LA COPA, entera en hoja de sombra...
	var copa: Vector3 = COPA
	poner.call(copa, COPA_R, Tono.FRONDA_OSC, [], false)
	# 8. ...y encima la masa iluminada. Lo que queda debajo es la fronda en penumbra, y es justo
	#    donde viven los ojos: una cara en la sombra de la copa, que es lo que da el aire siniestro.
	poner.call(Vector3(copa.x, copa.y, copa.z + COPA_R.z * COPA_SUBE), COPA_R * COPA_ESC,
		Tono.FRONDA, [Tono.FRONDA_OSC], false)
	poner.call(Vector3(copa.x, copa.y - COPA_R.y * 0.25, copa.z + COPA_R.z * 0.55),
		COPA_R * 0.55, Tono.FRONDA_CLARA, [Tono.FRONDA], false)

	# 9. FLECOS: hojas colgando del borde de la copa. Es lo desgreñado de la referencia, y ademas
	#    rompe la silueta para que la copa no se lea como una pelota.
	for k in FLECOS:
		var a: float = PI * (0.15 + 0.70 * float(k) / float(FLECOS - 1))
		poner.call(Vector3(copa.x + cos(a) * COPA_R.x * 0.88,
				copa.y + COPA_R.y * 0.35, copa.z - COPA_R.z * 0.55 - absf(sin(a)) * 1.5),
			FLECO_R, Tono.FRONDA_OSC, [], false)

	# 10. CUERNOS-RAMA: ramas retorcidas saliendo de lo alto de la copa, en anillo.
	for k in CUERNOS:
		var a: float = PI * 0.5 + TAU * float(k) / float(CUERNOS)
		var base: Vector3 = _en_el_tronco(
			Vector3(cos(a) * CUERNO_ANILLO, sin(a) * CUERNO_ANILLO, CUERNO_ALTO),
			CUERNO_HUNDE, copa, COPA_ANCLA_R)
		var detras: bool = Vector2(base.x - copa.x, base.y - copa.y).rotated(ang).y <= 0.0
		var r: Vector3 = CUERNO_R * (DETRAS_ESC if detras else 1.0)
		poner.call(Vector3(base.x, base.y, base.z + r.z), r,
			Tono.CORTEZA_OSC if detras else Tono.CORTEZA)

	# 11. EL BRAZO DE DELANTE, ya sobre el cuerpo.
	for b in brazos:
		if bool(b["delante"]):
			_rama(poner, b, fase_brazos, alza, 1.0, Tono.CORTEZA)

	# 12. OJOS: dos puntos claros en la sombra de la copa. De espaldas no se le ven -- un bicho que
	#     se aleja enseña la nuca, y eso es lo que hace que se lea de un vistazo si viene o si huye.
	var ojos: Array = []
	for l in [-1.0, 1.0]:
		var d := Vector3(l * OJO_DIR.x, OJO_DIR.y, OJO_DIR.z)
		var fondo: float = Vector2(d.x, d.y).rotated(ang).y
		if fondo > OJO_VISIBLE:
			# SOBRE 'COPA', LA DE VERDAD, Y NO SOBRE 'copa'. Esta segunda ya lleva el meceo aplicado, y
			# clavando el ojo en ella para luego volver a mecerlo se INCLINABA DOS VECES: en el idle
			# apenas se notaba, pero en la embestida -- que es cuando el meceo se dispara -- los ojos
			# salian volando fuera de la copa. Todo lo que se clava en una pieza se ancla en su
			# posicion EN REPOSO y se mece una sola vez, al final, como la grieta.
			ojos.append({"pos": _en_el_tronco(d, OJO_HUNDE, COPA, COPA_ANCLA_R),
				"fondo": fondo})
	# DE PERFIL PURO, UNO SOLO: ahi los dos caen en la misma X de pantalla y se separan solo en
	# vertical, y dos ojos uno encima del otro se leen como un borron, no como una cara.
	if absf(DIR_VECS[dir].x) >= 0.9 and ojos.size() == 2:
		ojos = [ojos[0] if float(ojos[0]["fondo"]) > float(ojos[1]["fondo"]) else ojos[1]]
	for o in ojos:
		poner.call(o["pos"], OJO_R, Tono.OJO_T)

	return piezas


# Un BRAZO-RAMA: cadena de segmentos que sale del tronco, se abre y CAE. En cadena y no de una pieza
# porque una rama recta parece un palo clavado; encadenada se curva.
# 'alza' > 0 la levanta (el aviso del ramazo) y < 0 la descarga hacia delante y abajo.
static func _rama(poner: Callable, b: Dictionary, fase: float, alza: float,
		esc: float, tono: int) -> void:
	var lado: float = float(b["lado"])
	var raiz: Vector3 = b["raiz"]
	for k in BRAZO_SEGMENTOS:
		var f: float = float(k) / float(BRAZO_SEGMENTOS - 1)
		# Se abre hacia fuera y hacia delante, y va CAYENDO. El meneo crece hacia la punta: la base
		# apenas se mueve, como en un brazo de verdad.
		var abre: float = BRAZO_PASO * float(k)
		var p := Vector3(
			raiz.x + lado * abre * BRAZO_ABRE + lado * fase * f * 1.2,
			raiz.y + abre * 0.18 + alza * f * f * 2.4 + fase * f * 1.0,
			# OJO al tocar esto: 'alza' no puede estirar mucho la cadena o los segmentos se separan y
			# el brazo vuelve a salir a trozos sueltos justo durante el ataque, que es cuando se mira.
			raiz.z - abre * BRAZO_CAIDA * (1.0 - alza * 0.55) + fase * f * 0.8)
		var r: float = lerpf(BRAZO_R0, BRAZO_R1, f) * esc
		poner.call(p, Vector3(r, r, r), tono)


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, esc: float) -> PackedByteArray:
	var lz: Vector2i = _lienzo(esc)
	var plant := PackedByteArray()
	plant.resize(lz.x * lz.y)
	var piezas: Array = _piezas(dir, pose, esc)
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			0.0, p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
