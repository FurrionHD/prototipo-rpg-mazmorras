# ============================================================
#  fishing_spot.gd
#  EL CHARCO. Una sala por piso lleva uno (ver DungeonFloor._elegir_estanque) y es el unico sitio
#  donde se pesca. A diferencia de una veta, el charco NO SE AGOTA: los peces vuelven.
#
#  Lo que lo separa de los otros tres oficios es que su minijuego NO TAPA EL MUNDO. Picar una veta
#  abre una pantalla negra y te saca de la mazmorra; pescar te deja plantado en la orilla, viendo
#  el agua, el hilo y al pez resistiendose. Por eso el ciclo vive AQUI, en un nodo del mundo, y la
#  barra de tension (fishing.gd) es solo una capa encima que no esconde nada.
#
#  EL CICLO:
#    LIBRE     no estas pescando. F abre el MENU DE PESCA (hace falta CAÑA equipada: sin ella no hay
#              pesca). Ahi eliges cebo y tiras la caña; el menu es tambien donde el cebo significa
#              algo, porque es el unico sitio del juego donde ponerlo hace efecto.
#    APUNTANDO eliges DONDE cae el corcho: A/D giran la mira (una linea de puntos) y MANTENER
#              ESPACIO llena el medidor de fuerza. Sueltas y sale. La fuerza es DISTANCIA, no
#              punteria: media barra cae a media travesia del charco y la barra llena casi en la
#              orilla de enfrente. El punto SIEMPRE cae dentro del agua — no se recorta a posteriori,
#              es que la mira solo admite angulos cuyo rayo corta la balsa (ver _tramo_de_agua).
#    LANZANDO  el hilo vuela en ARCO desde el personaje hasta el agua (~0.4 s).
#    ESPERA    el corcho flota. Los peces nadan. El PRIMERO que choca con el corcho se engancha.
#    PICANDO   2-4 toques flojos: el corcho tiembla y vuelve. Pulsar aqui ESPANTA al pez.
#    TIRON     temblor fuerte y el corcho SE HUNDE. ESPACIO en esta ventana -> a la lucha.
#    LUCHA     la barra de tension (fishing.gd). El mundo sigue viendose.
#    COBRO     el pez viaja por el hilo hasta tus manos. El aviso de "has conseguido X" sale
#              cuando LLEGA, no cuando se llena la barra: el pez no es tuyo hasta que lo tienes.
#
#  Y ES UN BUCLE: cobrar la pieza, perderla o recoger el sedal NO te echan de la pesca, te devuelven
#  a APUNTANDO con el cebo todavia puesto (ver _volver_a_apuntar). Antes cada pez te soltaba al mundo
#  y repetir la accion que acababas de hacer costaba F + menu + "Tirar la caña": tres pantallas para
#  volver a lo mismo. De la pesca se sale cuando lo pides tu — F o ESC apuntando, ESC directamente
#  con el sedal echado — o cuando el charco se queda seco y ya no hay nada que sacar.
#
#  UN PEZ A LA VEZ: mientras hay uno enganchado, los demas rebotan contra el corcho y siguen
#  nadando. Sin esa regla, con 6 peces dando vueltas en un charco de 4x3 celdas la mordida seria
#  instantanea y continua, y la espera -que es media pesca- desapareceria.
#
#  EL CEBO (Game.cebo_activo) es lo unico que hace que los peces VENGAN: dentro de su radio viran
#  hacia el corcho en vez de deambular. SIN CEBO NO HAY ATRACCION NINGUNA, a proposito — la pesca a
#  pelo es la de siempre y el cebo es lo que compras cuando quieres elegir tu sitio y que el charco
#  acuda. Lo que NO toca el cebo es quien muerde: la mordida sigue siendo por colision (_paso_espera)
#  y el minijuego sigue siendo cosa de la caña. Ver ConsumableData.cebo_radio.
#
#  EL BANCO: el charco NO es una fuente infinita. Guarda hasta 10 peces y solo enseña 4-6 a la vez;
#  cada pieza que te llevas tarda 10 minutos en volver, con su propio contador. Dentro de una visita
#  la reposicion es rapida (4 s) y no te quedas mirando el agua vacia; el freno lo pone el banco, no
#  el temporizador. Ver el bloque de constantes para el porque de los dos relojes.
#
#  MULTIJUGADOR: el charco lo SIMULA el dueño del piso y los demas lo ven en espejo, igual que los
#  bichos. Antes cada maquina corria su propio charco, y eso significaba que dos personas en la misma
#  orilla sacaban veinte peces de un sitio que tiene diez, cada uno viendo un banco distinto.
#
#  El reparto de trabajo:
#    - EL DUEÑO simula: los peces nadan, el banco baja, los sellos de 10 minutos corren y se guardan
#      en SU save. Y decide las mordidas de TODOS, porque una mordida es una colision y las
#      colisiones solo existen donde hay simulacion.
#    - EL ESPEJO no simula nada: recibe la foto del banco (~10 Hz) y coloca sus rectangulos. Cuando
#      echa el sedal, le manda al dueño donde ha caido el corcho y espera a que le diga que ha picado.
#
#  UN PEZ SOLO LO PESCA UNO: el que esta enganchado lleva de QUIEN es. Para los demas rebota como si
#  no estuviera, y en el espejo se pinta mas claro — ves como tu compañero lo esta peleando.
#
#  En SOLITARIO no cambia nada: Net.simulo_mi_piso() devuelve true y todo corre como siempre.
#
#  Aspecto placeholder por codigo (el arte va al final): el agua es un ColorRect y cada pez es un
#  rectangulo alargado mas oscuro que el agua, con el largo sacado de sus centimetros.
# ============================================================

extends Node2D

enum { LIBRE, APUNTANDO, LANZANDO, ESPERA, PICANDO, TIRON, LUCHA, COBRO }

# --- Lo que le pone DungeonFloor al crearlo ---
var celda: Vector2i = Vector2i.ZERO
var tam_celdas: Vector2i = Vector2i(4, 3)
var tabla: MaterialTable = null

# --- Peces nadando: [{rect: ColorRect, data, cm, vel: Vector2, largo, alto}] ---
var _peces: Array = []
# LOS QUE SE TE HAN ESCAPADO y esperan turno para volver al agua: [{data, cm}]. Vuelven ELLOS, con su
# talla, no un pez nuevo sorteado (ver _escapar / _nacer_pez). Es de la VISITA: si te vas del piso se
# pierde, lo cual esta bien -- lo que no puede pasar es que se te escape el pez de tu vida y a los
# tres segundos salga otro distinto.
var _escapados: Array = []
var _estado: int = LIBRE
var _pez: Dictionary = {}        # el enganchado (vacio si ninguno)
var _t: float = 0.0              # cronometro del estado actual
var _toques: int = 0             # picotazos dados en PICANDO
var _toques_max: int = 3
var _ventana: float = 1.2        # duracion de la ventana del TIRON, en segundos
var _press_was: bool = false
# La F del frame anterior, para recoger el sedal con una pulsacion NUEVA. Arranca en true porque la
# F con la que lanzas sigue apretada en el primer frame: sin esto, echar el sedal y recogerlo serian
# la misma pulsacion y no llegarias a pescar nunca.
var _f_was: bool = true
# La ESC del frame anterior, con la misma trampa que la F. ESC sale de la pesca de un tiron desde
# cualquier punto con el sedal echado; la F hace los dos pasos (recoger -> apuntando -> salir).
var _esc_was: bool = true
# El ultimo cebo con el que echaste el sedal, para volver a ponerlo entre tiro y tiro (ver
# _volver_a_apuntar).
var _ultimo_cebo: ConsumableData = null
# ¿Se ha soltado el ESPACIO desde que estamos apuntando? El medidor no empieza a cargar hasta que si.
# Sin esto, la MISMA pulsacion que espanta a un pez (o que gana la pelea) seguia cargando el tiro
# siguiente y se te escapaba un lanzamiento flojo sin haberlo pedido. Es el patron de "pulsacion
# NUEVA" que ya usan la mineria (mining.gd, estado READY) y la extraccion.
var _espacio_libre: bool = false

# --- Aspecto ---
var _agua: ColorRect = null
var _lbl: Label = null
var _hilo: Line2D = null
var _corcho: ColorRect = null
var _corcho_base: Vector2 = Vector2.ZERO   # donde flota (sin el temblor encima)

# --- La MIRA del lanzamiento (solo existe mientras APUNTANDO) ---
var _mira: Node2D = null              # contenedor de la linea de puntos, el aro y el medidor
var _mira_puntos: Array = []          # los ColorRect de la linea de puntos, reutilizados
var _mira_aro: Line2D = null          # el circulo del punto de caida
var _barra_fondo: ColorRect = null
var _barra_relleno: ColorRect = null
var _mira_lbl: Label = null
var _ang: float = 0.0                 # hacia donde apunta la caña ahora mismo
var _ang_base: float = 0.0            # de ti al centro del agua: el centro de la apertura
var _fuerza: float = 0.0              # 0..1, lo que lleva cargado el medidor

# --- Numeros del ciclo ---
# CUANTOS peces se VEN nadando a la vez. Es el aforo del agua, no lo que hay: el charco guarda hasta
# STOCK_MAX y solo saca a la superficie hasta el aforo (ver el bloque de EL BANCO).
const PECES_MIN := 4
const PECES_MAX := 6
# Velocidad de crucero de un pez, px/s. El grande no nada mas rapido: nada mas RECTO (gira menos),
# que es lo que lo hace dificil de cruzarte y facil de ver venir.
const VEL_PEZ := 18.0
const VEL_PEZ_VAR := 10.0
# Cada cuanto un pez decide un rumbo nuevo (segundos, se tira entre los dos).
const GIRO_MIN := 1.2
const GIRO_MAX := 3.5
# Escala de la silueta: px de largo por centimetro de pez. Un gobio de 12 cm son ~7 px y un espejo
# abisal de 150 cm son ~90: se distinguen desde la otra punta de la sala, que es el objetivo.
const PX_POR_CM := 0.6
const LARGO_MIN := 6.0
# TECHO del largo, en fraccion del lado corto del charco. Sin el, un espejo abisal de 165 cm sale de
# 99 px y no CABE en un charco de 128x96: se quedaba clavado contra los bordes o asomando fuera.
# Los tamaños siguen distinguiendose (un gobio son 7 px y el trofeo llena media balsa), pero el
# charco manda: nada nada mas grande que el agua en la que nada.
const LARGO_MAX_FRAC := 0.42

# El vuelo del hilo al lanzar, y lo alto que sube el arco por encima del jugador.
const VUELO := 0.4
const ARCO_ALTO := 46.0

# ============================================================
#  EL LANZAMIENTO: apuntar y cargar
# ============================================================
# Rad/s que gira la mira con A/D, y cuanto puede abrirse a cada lado de la linea que va de ti al
# centro del agua. La apertura no es para que no te salgas —de eso ya se encarga _tramo_de_agua, que
# solo admite angulos que corten la balsa— sino para que no puedas apuntar HACIA ATRAS y quedarte
# mirando a la pared con la caña en la mano.
const GIRO_MIRA := 2.2
const ANGULO_MAX := 1.25
# De 0 a 1 en ~1.1 s. La barra NO rebota al llegar arriba: se queda llena. La fuerza es una eleccion
# de distancia, no una prueba de reflejos — quien quiera el borde de enfrente lo tiene mantiendo, y
# lo que cuesta de verdad es acertar el sitio donde estan los peces.
const CARGA_VEL := 0.9
# Lo que el corcho se queda del borde del agua, en px. Sin este margen la fuerza maxima dejaba el
# corcho pegado a la pared y los peces (que rebotan a medio largo del borde) no llegaban nunca.
const MIRA_MARGEN := 6.0
# Que fraccion del tramo de agua cubre ya la fuerza MINIMA. No es 0: soltar el medidor de inmediato
# tiene que dejar el corcho en el agua, no en la orilla.
const TIRO_MIN := 0.18
# Cuantos puntos dibuja la linea de la mira.
const MIRA_PUNTOS := 14

# Rad/s a los que un pez atraido por el cebo se gira hacia el corcho. Es un VIRAJE, no un iman: el
# pez conserva su velocidad y va nadando hasta alli, asi que uno grande y lento llega despues que un
# gobio. Con un giro instantaneo todos caian encima del corcho a la vez y la espera desaparecia.
#
# El numero NO es libre: un perseguidor que solo puede girar a GIRO_CEBO y nunca frena describe
# circulos alrededor de su presa con un radio de hasta 2*v/GIRO_CEBO. Con 2.6 rad/s y un pez rapido
# (VEL_PEZ + VEL_PEZ_VAR = 28 px/s) eso son 21 px: medido, el pez se quedaba ORBITANDO el corcho a
# 13 px sin llegar a morder nunca. A 4.5 la orbita peor cae a ~12 px, por debajo de EMBESTIDA.
const GIRO_CEBO := 4.5
# Y a partir de aqui el pez ya no vira: SE TIRA al cebo en linea recta. Es lo que remata la escena
# (el ultimo tramo tiene que ser una embestida, no una curva) y lo que garantiza la mordida: sin
# ella, el que orbite un poco mas ancho de la cuenta no la cruza nunca.
const EMBESTIDA := 16.0

# PICOTEO: cada toque flojo dura esto y separa al siguiente. Es el aviso de que hay algo ahi.
const TOQUE_DUR := 0.35
const TOQUE_AMP := 2.0
# TIRON: la ventana base para clavarlo, y lo que la ALARGA cada punto de la caña (tool_mods).
# El mismo numero vive en MenuScaffold.VENTANA_TIRON_POR_PUNTO, que es quien lo enseña en la ficha.
const VENTANA_BASE := 1.1
const VENTANA_POR_PUNTO := 0.15
const TIRON_AMP := 7.0
# Lo que tarda el pez en llegar a tus manos por el hilo.
const COBRO_DUR := 0.55
# ============================================================
#  EL BANCO: cuantos peces hay de verdad, y cada cuanto vuelven
# ============================================================
#  Dos numeros distintos, y confundirlos es lo que hacia que la pesca fuese barra libre:
#
#    STOCK   lo que HAY en el charco. Hasta 10. Es el presupuesto de verdad.
#    AFORO   lo que se VE nadando a la vez. Entre 4 y 6. Es solo la superficie.
#
#  Los visibles SALEN del stock: no son peces aparte. Asi una visita da como mucho 10 piezas, se
#  vean 4 o 6 a la vez.
#
#  Los dos relojes:
#    - REPONER (4 s reales): sale uno del banco al agua. RAPIDO a proposito -- dentro de una visita
#      no quiero que estes mirando el agua vacia, quiero que el limite lo ponga el banco.
#    - STOCK_REGEN (10 min de tiempo_mazmorra): cada pez PESCADO vuelve al banco, con SU PROPIO
#      contador. Diez minutos despues del ultimo que sacaste, el charco vuelve a estar lleno.
#      Este es el gate de verdad, y usa el reloj de la mazmorra (que corre TAMBIEN en el pueblo,
#      igual que el respawn de las vetas): irte a vender no lo congela.
#
#  El AFORO se vuelve a sortear cada 10 min y NO mata a nadie: si baja de 6 a 4 con cinco nadando,
#  simplemente no repone hasta que queden menos de cuatro. El charco cambia de humor sin que
#  desaparezca nada delante de tus narices.
#
#  Y todo esto se PERSISTE por piso y celda (Game.persistente_piso -> "charcos"), como los sellos de
#  las vetas agotadas. Sin eso el gate de 10 minutos no valdria nada: bastaria con bajar un piso y
#  subir para encontrarte el charco lleno otra vez.
const STOCK_MAX := 10
const STOCK_REGEN := 600.0      # segundos de tiempo_mazmorra que tarda en volver UN pez pescado
const AFORO_REVISION := 600.0   # cada cuanto el charco vuelve a sortear su aforo

# Lo que tarda en salir al agua el siguiente pez del banco.
const REPONER := 4.0
var _t_reponer: float = 0.0
# Peces que HAY (los que nadan mas los que esperan turno).
var _stock: int = STOCK_MAX
# Cuantos se ven a la vez ahora mismo. Se re-sortea cada AFORO_REVISION.
var _aforo: int = PECES_MIN
var _t_aforo: float = 0.0       # tiempo_mazmorra del ultimo sorteo
# Sellos de tiempo_mazmorra en los que vuelve al banco cada pez pescado. Uno por pieza: es lo que
# hace que diez capturas seguidas tarden diez minutos en volver y no diez veces diez.
var _vuelven: Array = []
# Contador de nacimientos, para sembrar cada pez nuevo (ver _rng_pez).
var _nonce: int = 0

# --- MULTIJUGADOR ---
# Cada cuanto el dueño manda la foto del banco. 10 Hz: los peces van despacio y el espejo interpola,
# asi que subirlo solo gastaria red. (Los bichos van a 20 porque persiguen y hay que ver el amago.)
const RED_TICK := 0.1
var _t_red: float = 0.0
# ESPEJO: hacia donde va cada pez segun la ultima foto, para moverlo suave entre paquete y paquete.
var _destinos: Array = []
const SUAVIZADO_RED := 12.0
# DUEÑO: el corcho de cada pescador remoto -> {pos: Vector2 local, activo: bool}. Con esto el dueño
# puede resolver la mordida del otro sin que el otro simule nada.
var _corchos: Dictionary = {}
# El pez que YO tengo enganchado, por indice en _peces. Solo lo usa el espejo: el dueño trabaja con
# el diccionario del pez directamente (_pez).
var _idx_enganchado: int = -1
# ESPEJO: ¿estoy esperando a que el dueño me diga si ha picado algo? Evita mandarle el corcho como
# "nuevo" en cada frame.
var _espero_mordida: bool = false


# ¿Simulo YO este charco? En solitario siempre. En multi, solo el dueño del piso.
func _soy_dueno() -> bool:
	return Net.simulo_mi_piso()


func _ready() -> void:
	add_to_group("recolectable")
	# Y ademas en su propio grupo, para el MAPA. En "recolectable" el charco es el raro: no tiene
	# material_data (su pez se sortea en cada captura), y Game.capturar_mapa filtra justo por eso, asi
	# que el estanque se caia del plano — el unico sitio del piso al que vuelves a proposito y el
	# unico que no salia marcado. Con grupo propio se cartografia como lo que es: un hito, no un nodo.
	add_to_group("estanque")
	# El ciclo tiene que seguir corriendo con el arbol PAUSADO: en solitario, plantarse a pescar
	# empuja un modal (ver interactuar) y eso para el arbol entero. Sin esto, el corcho se
	# congelaria en el aire y no habria pesca que jugar. Misma trampa que los menus (Game.abrir_menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_aspecto()
	# MULTI: Net necesita saber cual es el charco de este piso para encaminarle los paquetes.
	Net.registrar_charco(self)
	# El ESPEJO no puebla: sus peces llegan en la primera foto del dueño. Poblar aqui crearia peces
	# que no existen para nadie mas y que la primera foto tendria que borrar (parpadeo garantizado).
	if _soy_dueno():
		_poblar()


func _exit_tree() -> void:
	Net.olvidar_charco(self)


# ------------------------------------------------------------
#  ASPECTO
# ------------------------------------------------------------
func tam_px() -> Vector2:
	return Vector2(tam_celdas) * float(DungeonGenerator.CELDA)


# Cuanto SOBRESALE el charco de su centro. Lo lee player._mas_cercano_en_grupo para medir la
# distancia contra el BORDE del agua y no contra su centro: si no, un charco de 4x3 celdas te
# obligaria a meterte dentro para que la F llegase.
var radio_extra: float:
	get: return tam_px().length() * 0.5


func _crear_aspecto() -> void:
	var tam: Vector2 = tam_px()
	_agua = ColorRect.new()
	_agua.size = tam
	_agua.position = -tam * 0.5
	_agua.color = Color(0.11, 0.19, 0.30, 0.85)
	add_child(_agua)

	# MURO INVISIBLE. El charco es agua, no suelo: se pesca DESDE LA ORILLA y no metido dentro. Es
	# la excepcion a la regla de resource_node.gd ("los recolectables no tienen colision, estorbar no
	# es interesante"): aqui la colision no estorba, DEFINE el sitio -- sin ella el jugador se planta
	# encima de los peces y el hilo, y toda la puesta en escena deja de tener sentido.
	# Capa por defecto, la misma que los muros del piso (ver DungeonFloor._construir_geometria).
	var cuerpo := StaticBody2D.new()
	var forma := RectangleShape2D.new()
	forma.size = tam
	var col := CollisionShape2D.new()
	col.shape = forma
	cuerpo.add_child(col)
	add_child(cuerpo)

	_lbl = Label.new()
	_lbl.text = "[F]"
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 10)
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl.add_theme_constant_override("outline_size", 3)
	_lbl.offset_left = -20.0
	_lbl.offset_top = -tam.y * 0.5 - 20.0
	_lbl.offset_right = 20.0
	_lbl.offset_bottom = -tam.y * 0.5 - 4.0
	add_child(_lbl)

	# El hilo y el corcho nacen escondidos: solo existen mientras pescas.
	_hilo = Line2D.new()
	_hilo.width = 1.5
	_hilo.default_color = Color(0.92, 0.90, 0.82, 0.9)
	_hilo.visible = false
	add_child(_hilo)

	_corcho = ColorRect.new()
	_corcho.size = Vector2(7, 5)
	_corcho.color = Color(0.90, 0.32, 0.22)
	_corcho.rotation = 0.35   # ligeramente inclinado, como en el boceto
	_corcho.visible = false
	add_child(_corcho)

	_crear_mira()


# LA MIRA. Hecha de nodos sueltos y no de un _draw() porque este script ya dibuja debajo del agua:
# lo que se pinta en el _draw de un Node2D queda POR DEBAJO de sus hijos, y el ColorRect del agua es
# uno de ellos. Con nodos propios y z_index alto se ve encima de todo, peces incluidos (que nacen
# despues y se colarian por delante).
#
# La linea es de PUNTOS y semitransparente a proposito: tiene que leerse como una intencion y no
# como un laser. Los ColorRect se crean una sola vez y se recolocan cada frame; crear catorce nodos
# por frame mientras apuntas seria tirar basura al recolector para nada.
func _crear_mira() -> void:
	_mira = Node2D.new()
	_mira.z_index = 10
	_mira.visible = false
	add_child(_mira)

	for _i in range(MIRA_PUNTOS):
		var punto := ColorRect.new()
		punto.size = Vector2(2, 2)
		punto.color = Color(0.92, 0.90, 0.82, 0.35)
		_mira.add_child(punto)
		_mira_puntos.append(punto)

	# El aro del punto de caida: un circulo de 12 lados, dibujado UNA vez y movido con position.
	_mira_aro = Line2D.new()
	_mira_aro.width = 1.0
	_mira_aro.default_color = Color(0.92, 0.90, 0.82, 0.6)
	_mira_aro.closed = true
	var aro := PackedVector2Array()
	for i in range(12):
		aro.append(Vector2.from_angle(TAU * float(i) / 12.0) * 5.0)
	_mira_aro.points = aro
	_mira.add_child(_mira_aro)

	# El medidor de fuerza: VERTICAL y pegado al jugador, como el de la mineria (mining.gd). Se llena
	# de abajo arriba, que es lo que pide el gesto de cargar un lanzamiento.
	_barra_fondo = ColorRect.new()
	_barra_fondo.size = Vector2(6, 40)
	_barra_fondo.color = Color(0.10, 0.10, 0.12, 0.75)
	_mira.add_child(_barra_fondo)

	_barra_relleno = ColorRect.new()
	_barra_relleno.color = Color(0.95, 0.72, 0.36)
	_mira.add_child(_barra_relleno)

	_mira_lbl = Label.new()
	_mira_lbl.text = "A/D apunta  ·  MANTÉN ESPACIO  ·  F o ESC salen"
	_mira_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mira_lbl.add_theme_font_size_override("font_size", 9)
	_mira_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_mira_lbl.add_theme_constant_override("outline_size", 3)
	_mira_lbl.offset_left = -110.0
	_mira_lbl.offset_right = 110.0
	_mira.add_child(_mira_lbl)


# ------------------------------------------------------------
#  LOS PECES
# ------------------------------------------------------------
# Nacen con su especie y su talla YA sorteadas: lo que ves nadar es exactamente lo que vas a sacar.
# El sorteo va sembrado con (semilla del piso, celda del charco, indice del pez) para que el
# invitado vea los mismos sin que viaje nada por la red.
func _poblar() -> void:
	if tabla == null:
		return
	_cargar_estado()
	# Al llegar a la sala los peces YA estan nadando: nadie se queda mirando el agua vacia 24 s.
	# Lo que sale es lo que el banco permite, que puede ser menos que el aforo si vienes de vaciarlo.
	for i in range(mini(_aforo, _stock)):
		_nacer_pez(_rng_pez())
	# Si el banco no da para llenar el agua, que empiece a contar ya para cuando le entre uno.
	_armar_reposicion()


# ------------------------------------------------------------
#  ESTADO PERSISTENTE del charco (por piso y celda)
# ------------------------------------------------------------
# Vive donde los sellos de las vetas agotadas: Game.persistente_piso(piso). Se escribe en el momento
# de cada cambio y no al salir de la escena, porque el nodo se libera de golpe al regenerar el piso y
# un _exit_tree no es sitio para tocar el save.
#
# MULTIJUGADOR: lo escribe EL DUEÑO del piso, que es el unico que lleva el banco de verdad. Misma
# regla que los sellos de las vetas (Net._registrar_agotado): el mundo es el suyo, asi que los sellos
# de diez minutos van a SU save. El invitado no escribe nada — vaciarle el charco al host no puede
# dejar rastro en la partida propia del invitado, que es de otro mundo y otra semilla.
func _guardar_estado() -> void:
	if not _soy_dueno():
		return
	var piso: Dictionary = Game.persistente_piso(Game.current_floor)
	if not piso.has("charcos"):
		piso["charcos"] = {}   # las partidas anteriores a la pesca no traen la clave
	(piso["charcos"] as Dictionary)[celda] = {
		"stock": _stock, "vuelven": _vuelven.duplicate(),
		"aforo": _aforo, "t_aforo": _t_aforo,
	}


func _cargar_estado() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_semilla(), celda.x, celda.y])
	_aforo = rng.randi_range(PECES_MIN, PECES_MAX)
	_t_aforo = Game.tiempo_mazmorra
	_stock = STOCK_MAX
	_vuelven = []

	# Solo el dueño lee del save, por lo mismo que solo el escribe (ver _guardar_estado). El invitado
	# arranca vacio y su banco lo pone la primera foto que le llega.
	var guardado: Dictionary = {}
	if _soy_dueno():
		guardado = ((Game.persistente_piso(Game.current_floor).get("charcos", {}) as Dictionary)
			.get(celda, {}) as Dictionary)
	if guardado.is_empty():
		return   # charco virgen: lleno, como debe estar
	_stock = int(guardado.get("stock", STOCK_MAX))
	_vuelven = (guardado.get("vuelven", []) as Array).duplicate()
	_aforo = int(guardado.get("aforo", _aforo))
	_t_aforo = float(guardado.get("t_aforo", Game.tiempo_mazmorra))
	# Lo que haya vencido mientras no mirabas entra ahora: el reloj corre aunque no estes en el piso.
	_cobrar_vueltas()
	_revisar_aforo()


# Devuelve al banco los peces cuyo contador de 10 minutos ya ha vencido.
func _cobrar_vueltas() -> void:
	var quedan: Array = []
	for t in _vuelven:
		if Game.tiempo_mazmorra >= float(t):
			_stock = mini(STOCK_MAX, _stock + 1)
		else:
			quedan.append(t)
	_vuelven = quedan


# Cada AFORO_REVISION el charco decide cuantos peces enseña. NO mata a los que ya nadan: si el aforo
# baja, simplemente deja de reponer hasta que sobren. El sorteo va sembrado con el TRAMO de tiempo,
# asi que los dos jugadores de una partida en red ven el mismo humor sin hablarse.
func _revisar_aforo() -> void:
	if Game.tiempo_mazmorra - _t_aforo < AFORO_REVISION:
		return
	var tramo: int = int(Game.tiempo_mazmorra / AFORO_REVISION)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_semilla(), celda.x, celda.y, tramo, "aforo"])
	_aforo = rng.randi_range(PECES_MIN, PECES_MAX)
	_t_aforo = Game.tiempo_mazmorra


func _semilla() -> int:
	var piso = get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("_semilla_del_piso"):
		return int(piso._semilla_del_piso())
	return int(Game.semilla_mundo)


# El RNG del PROXIMO pez que nazca en este charco. Sembrado con (semilla del piso, celda, nonce),
# igual que el material de una veta al reaparecer (ver DungeonFloor._material_del_sitio): asi el
# invitado ve nadar exactamente los mismos bichos que el host sin que viaje nada por el cable, y
# eso sigue siendo cierto DESPUES del primer respawn.
#
# Antes el pez repuesto salia del randf() global y en multi cada uno veia una especie distinta en el
# mismo charco. En solitario no se notaba; en cuanto hay dos, la escena deja de ser la misma.
func _rng_pez() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_semilla(), celda.x, celda.y, _nonce])
	_nonce_usado = _nonce   # con cual nacio el pez de este sorteo (lo guarda _nacer_pez)
	_nonce += 1
	return r


# El nonce del ULTIMO sorteo. Es la IDENTIDAD del pez de cara a la red: el espejo solo recibe este
# numero y con el rehace la especie y la talla por su cuenta (ver _nacer_pez_espejo).
var _nonce_usado: int = 0


func _nacer_pez(rng: RandomNumberGenerator = null) -> void:
	var r: RandomNumberGenerator = rng if rng != null else _rng_pez()
	var d: MaterialData
	var cm: float
	var nonce: int = _nonce_usado
	# LOS QUE SE TE ESCAPARON VUELVEN PRIMERO, y vuelven ellos: misma especie y mismos centimetros.
	# Solo entonces se sortea uno nuevo.
	if not _escapados.is_empty():
		var vuelve: Dictionary = _escapados.pop_front()
		d = vuelve["data"]
		cm = float(vuelve["cm"])
		# Y vuelve con SU nonce, el de cuando nacio. Es lo que le deja al espejo seguir sacando la
		# misma especie y la misma talla del sorteo sembrado: con un nonce nuevo, al invitado se le
		# convertiria en otro pez justo al reaparecer.
		nonce = int(vuelve.get("nonce", _nonce_usado))
	else:
		d = tabla.elegir(Game.current_floor, r)
		if d == null:
			return
		cm = d.talla_desde(MaterialData.tirada_talla(r))
	if d == null:
		return
	var tam_agua: Vector2 = tam_px()
	var largo: float = clampf(cm * PX_POR_CM, LARGO_MIN,
		minf(tam_agua.x, tam_agua.y) * LARGO_MAX_FRAC)
	var alto: float = maxf(2.0, largo / maxf(1.2, d.esbeltez))

	var rect := ColorRect.new()
	rect.size = Vector2(largo, alto)
	# GIRA SOBRE SU CENTRO. Un Control pivota por defecto en su esquina superior izquierda: sin
	# esto, orientar al pez con su rumbo lo hacia describir un arco alrededor de esa esquina y se
	# le veia asomar FUERA del agua mientras su posicion logica seguia dentro.
	rect.pivot_offset = rect.size * 0.5
	# La SOMBRA no es el color del pez: es el agua oscurecida. Todos los peces se ven igual de
	# oscuros bajo el agua; lo que los distingue de un vistazo es el TAMAÑO, no el tono.
	rect.color = Color(0.04, 0.07, 0.12, 0.45)
	add_child(rect)

	var margen: float = largo * 0.5 + 1.0
	var pos := Vector2(
		r.randf_range(-tam_agua.x * 0.5 + margen, tam_agua.x * 0.5 - margen),
		r.randf_range(-tam_agua.y * 0.5 + margen, tam_agua.y * 0.5 - margen))
	var ang: float = r.randf() * TAU
	var vel: float = VEL_PEZ + r.randf_range(-VEL_PEZ_VAR, VEL_PEZ_VAR)
	_peces.append({
		"rect": rect, "data": d, "cm": cm, "largo": largo, "alto": alto,
		"pos": pos, "vel": Vector2(cos(ang), sin(ang)) * vel,
		"t_giro": r.randf_range(GIRO_MIN, GIRO_MAX),
		# ¿Ha olido ya el cebo? Ver _atrae_el_cebo: una vez dentro del radio, viene aunque salga.
		"cebo": false,
		# MULTI: el peer que lo tiene enganchado (0 = libre, nadie lo esta peleando). Es el candado
		# por pez: para los demas corchos este bicho no existe, y en el espejo se pinta mas claro.
		"de": 0,
		# MULTI: su identidad de cara a la red (ver _rng_pez).
		"nonce": nonce,
	})
	_colocar(_peces.back())


func _colocar(p: Dictionary) -> void:
	var rect: ColorRect = p["rect"]
	rect.position = (p["pos"] as Vector2) - rect.size * 0.5


func _nadar(delta: float) -> void:
	var tam: Vector2 = tam_px()
	for p in _peces:
		# El pez ENGANCHADO no deambula: se queda forcejeando junto al corcho. Vale tanto para el mio
		# como para el que este peleando un compañero (p["de"] != 0): mientras alguien lo tiene en el
		# anzuelo, ese pez no es del banco.
		if _pez_es(p) and _estado != ESPERA:
			continue
		if int(p.get("de", 0)) != 0:
			continue
		if _atrae_el_cebo(p):
			# EL CEBO manda mientras el pez este dentro de su radio: en vez de tirar su dado de rumbo,
			# vira hacia el corcho. Conservando el modulo de la velocidad, o sea que cada uno va a lo
			# suyo y llega cuando llega.
			var atraido: Vector2 = p["vel"]
			var hacia: Vector2 = _corcho_base - (p["pos"] as Vector2)
			if hacia.length() <= EMBESTIDA:
				p["vel"] = hacia.normalized() * atraido.length()   # ultimo tramo: se tira a por el
			else:
				p["vel"] = atraido.rotated(clampf(angle_difference(atraido.angle(), hacia.angle()),
					-GIRO_CEBO * delta, GIRO_CEBO * delta))
			# Se le re-arma el reloj del rumbo: al salir del radio sigue nadando, no da un volantazo
			# en el frame siguiente por un contador que venia vencido de antes.
			p["t_giro"] = randf_range(GIRO_MIN, GIRO_MAX)
		else:
			p["t_giro"] = float(p["t_giro"]) - delta
			if float(p["t_giro"]) <= 0.0:
				# Giro SUAVE (no un rumbo nuevo de cero): un pez no da volantazos de 180 grados.
				var v: Vector2 = p["vel"]
				p["vel"] = v.rotated(randf_range(-1.1, 1.1))
				p["t_giro"] = randf_range(GIRO_MIN, GIRO_MAX)
		var pos: Vector2 = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		# Rebote en las paredes del charco. El margen es MEDIO LARGO EN LOS DOS EJES, no largo en x
		# y alto en y: el pez esta GIRADO, asi que nadando en diagonal su morro ocupa en vertical
		# casi tanto como su largo. Midiendolo por ejes, una anguila cruzando en diagonal se salia
		# del agua por la punta.
		var margen: float = float(p["largo"]) * 0.5 + 1.0
		var lim: Vector2 = (tam * 0.5 - Vector2(margen, margen)).maxf(2.0)
		if absf(pos.x) > lim.x:
			pos.x = clampf(pos.x, -lim.x, lim.x)
			p["vel"] = Vector2(-(p["vel"] as Vector2).x, (p["vel"] as Vector2).y)
		if absf(pos.y) > lim.y:
			pos.y = clampf(pos.y, -lim.y, lim.y)
			p["vel"] = Vector2((p["vel"] as Vector2).x, -(p["vel"] as Vector2).y)
		p["pos"] = pos
		# El cuerpo se orienta con el rumbo: asi la anguila se lee como anguila al cruzar el charco.
		(p["rect"] as ColorRect).rotation = (p["vel"] as Vector2).angle()
		_colocar(p)


# ¿Este pez esta oliendo el cebo? Hacen falta las tres cosas: que el corcho este flotando y libre
# (en ESPERA y sin nadie enganchado), que lleves cebo puesto, y que el pez haya ENTRADO en su radio.
# Sin cebo esto devuelve false SIEMPRE y los peces deambulan como toda la vida.
#
# UNA VEZ DENTRO, SE QUEDA ENGANCHADO (el pestillo "cebo" del pez) hasta que recojas o piques. Sin
# ese pestillo el radio no servia de nada: un pez que entraba dandole la espalda al corcho tardaba
# mas de un segundo en dar la vuelta (GIRO_CEBO es un viraje, no un iman) y para entonces ya habia
# salido del radio, asi que rebotaba en el borde y se iba. Medido: entrando a 22 px de un cebo de
# 26, acababa a 55 px. Con el pestillo, lo que el radio decide es QUIEN se entera del cebo, y el que
# se entera viene.
func _atrae_el_cebo(p: Dictionary) -> bool:
	if _estado != ESPERA or not _pez.is_empty() or Game.cebo_radio() <= 0.0:
		p["cebo"] = false
		return false
	if bool(p.get("cebo", false)):
		return true
	var r: float = Game.cebo_radio()
	p["cebo"] = ((p["pos"] as Vector2) - _corcho_base).length_squared() <= r * r
	return bool(p["cebo"])


func _pez_es(p: Dictionary) -> bool:
	return not _pez.is_empty() and p["rect"] == _pez["rect"]


# ------------------------------------------------------------
#  ENTRADA: la F del jugador
# ------------------------------------------------------------
func interactuar() -> void:
	if _estado != LIBRE:
		return
	# Sin CAÑA no se pesca, y punto. Es la unica herramienta sin version "de serie" (ver Game.cana):
	# picar a mano se puede, pescar sin sedal no.
	if Game.cana() == null:
		_decir("Necesitas una caña de pescar. Te la forja el herrero.")
		return
	if _peces.is_empty():
		# Puede ser por dos motivos y conviene distinguirlos: o lo has vaciado (y toca esperar a que
		# el banco se reponga) o simplemente aun no ha salido el siguiente.
		if _stock <= 0:
			_decir("Has dejado el charco seco. Dale un rato y volverán.")
		else:
			_decir("El agua está quieta. Espera un momento.")
		return
	# La F ya no lanza: abre el MENU DE PESCA, que es donde eliges cebo y desde donde se tira. El
	# menu vuelve por empezar_apuntado(). Si por lo que sea no esta montado, se apunta directamente:
	# quedarse sin poder pescar por un menu que falta seria peor que no tener cebos.
	var menu: Node = get_tree().get_first_node_in_group("fishing_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir(self)
	else:
		empezar_apuntado()


func _decir(txt: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast(txt)


# ------------------------------------------------------------
#  EL CICLO
# ------------------------------------------------------------
# Lo llama el MENU DE PESCA al darle a "Tirar la caña" (o interactuar(), si el menu no esta). A
# partir de aqui mandan A/D y ESPACIO, y el mundo se queda quieto.
func empezar_apuntado() -> void:
	if _estado != LIBRE:
		return
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador == null:
		return
	# El modal BLOQUEA al jugador (player consulta Game.hay_modal para no moverse ni atacar) y en
	# solitario ademas pausa el arbol, que es justo lo que quiero: los bichos se paran mientras
	# peleas con el pez. Ojo: por eso este nodo es PROCESS_MODE_ALWAYS.
	Game.entrar_modal(Game.Modal.RECOLECCION, self)

	# La mira nace mirando de TI al centro del agua, que es el tiro que siempre vale. A/D la abren
	# desde ahi hasta ANGULO_MAX a cada lado.
	_ang_base = (-_origen_hilo()).angle()
	_ang = _ang_base
	_fuerza = 0.0
	_estado = APUNTANDO
	_t = 0.0
	# Ni la F con la que has abierto el menu ni el click de "Tirar la caña" pueden contar como el
	# ESPACIO de cargar o como la F de cancelar.
	_press_was = Input.is_action_pressed(&"recolectar")
	_f_was = true
	_esc_was = true
	_espacio_libre = false
	_mira.visible = true
	_montar_tactil()
	_pintar_mira()


func _paso_apuntando(delta: float) -> void:
	# A/D giran la mira. Un angulo solo se acepta si (a) sigue dentro de la apertura y (b) su rayo
	# CORTA el agua: asi el corcho no puede caer fuera del charco ni recortandolo despues, que es lo
	# que haria que la linea de puntos te mintiera.
	if _pad != null and _pad.hay_dedo():
		# Con los dedos se apunta ARRASTRANDO: donde tengas el dedo en horizontal es hacia donde mira
		# la caña, de un extremo a otro de la apertura. La fuerza la sigue dando el rato que aguantes,
		# asi que apuntar y cargar son el MISMO gesto, y sueltas cuando lo tengas.
		var nuevo_t: float = _ang_base + (_pad.x_norm() * 2.0 - 1.0) * ANGULO_MAX
		if _tramo_de_agua(nuevo_t).x >= 0.0:
			_ang = nuevo_t
	else:
		var giro: float = 0.0
		if Input.is_action_pressed(&"move_left"):
			giro -= 1.0
		if Input.is_action_pressed(&"move_right"):
			giro += 1.0
		if giro != 0.0:
			var nuevo: float = _ang + giro * GIRO_MIRA * delta
			if absf(angle_difference(_ang_base, nuevo)) <= ANGULO_MAX and _tramo_de_agua(nuevo).x >= 0.0:
				_ang = nuevo

	var pulsa: bool = Input.is_action_pressed(&"recolectar")
	if not pulsa:
		_espacio_libre = true   # a partir de aqui, la siguiente pulsacion ya es tuya
	if pulsa and _espacio_libre:
		_fuerza = minf(1.0, _fuerza + CARGA_VEL * delta)
	elif not pulsa and _press_was and _fuerza > 0.0:
		_lanzar()   # has soltado: ahi va el sedal
		return
	_pintar_mira()


func _lanzar() -> void:
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador == null:
		return
	_corcho_base = _punto_de_tiro(_ang)
	_mira.visible = false
	_ultimo_cebo = Game.cebo_activo   # con el que vuelves a la mira si este tiro te lo gasta

	_estado = LANZANDO
	_t = 0.0
	_espero_mordida = false   # tiro nuevo: vuelvo a estar a la espera de que el dueño me diga algo
	_idx_enganchado = -1
	_press_was = true   # la F de lanzar no debe contar como el ESPACIO del tiron
	_f_was = true       # ni como la F de recoger (ver _process)
	_hilo.visible = true
	_corcho.visible = true
	_pintar_corcho(Vector2.ZERO)


func _process(delta: float) -> void:
	# EL BANCO: lo mueve el dueño y lo copia el espejo. Todo lo de abajo (la caña, el corcho, las
	# teclas) es IGUAL para los dos: cada uno maneja su sedal, lo unico que cambia es quien decide
	# donde estan los peces y quien muerde.
	if _soy_dueno():
		_nadar(delta)
		_reponer(delta)
		_mordidas_remotas()
		_t_red += delta
		if _t_red >= RED_TICK:
			_t_red = 0.0
			Net.difundir_charco(estado_red())
	else:
		_interpolar_peces(delta)
		_publicar_mi_corcho()
	if _estado == LIBRE:
		return
	# RECOGER EL SEDAL con la misma F con la que lo echaste. Mientras esperas estas dentro de un
	# modal, asi que la F no le llega al jugador y sin esto te quedabas plantado en la orilla para
	# siempre si el pez no picaba (o si te habias equivocado de sitio).
	#
	# Solo hasta el TIRON incluido: a partir de LUCHA manda la barra de tension, que tiene su propio
	# final, y en COBRO el pez ya es tuyo y viene por el hilo. Recoger no espanta a nadie ni gasta
	# stock: no has llegado a sacar nada.
	if _estado in [APUNTANDO, LANZANDO, ESPERA, PICANDO, TIRON]:
		# ESC ES LA PUERTA: sale de la pesca de un tiron desde donde estes, sin pasar por la mira. No
		# choca con el menu de pausa porque ese se planta si Game.hay_modal(), y pescar mantiene un
		# modal RECOLECCION puesto de principio a fin (ver pause_menu._unhandled_input).
		var esc_ahora: bool = Input.is_action_pressed(&"cancelar")
		if esc_ahora and not _esc_was:
			_esc_was = true
			_guardar_cana()
			return
		_esc_was = esc_ahora

		var f_ahora: bool = Input.is_action_pressed(&"interactuar")
		if f_ahora and not _f_was:
			_f_was = true
			_recoger_sedal()
			return
		_f_was = f_ahora
	_t += delta
	match _estado:
		APUNTANDO: _paso_apuntando(delta)
		LANZANDO: _paso_lanzando()
		ESPERA: _paso_espera()
		PICANDO: _paso_picando()
		TIRON: _paso_tiron()
		# Mientras luchas, el hilo VIBRA: es lo que hace que la barra de tension de la capa de
		# arriba se lea como algo que esta pasando en el agua y no como un widget suelto.
		LUCHA: _pintar_corcho(Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 3.0)))
		COBRO: _paso_cobro(delta)
	_press_was = Input.is_action_pressed(&"recolectar")


# Saca UNO del banco al agua cada REPONER segundos, y RE-ARMA el reloj mientras el agua siga por
# debajo del aforo. Sin ese re-armado solo volvia un pez por temporizador: quitar dos seguidos
# (pescar uno y perder otro) dejaba el charco permanentemente corto.
#
# Aqui tambien se atienden los dos relojes lentos, que corren aunque no estes pescando: los peces que
# vuelven al banco y la revision del aforo.
func _reponer(delta: float) -> void:
	var antes: int = _stock
	_cobrar_vueltas()
	_revisar_aforo()
	if _stock != antes:
		_guardar_estado()
		_armar_reposicion()   # ha entrado uno al banco: que salga al agua si hace falta

	if _t_reponer <= 0.0:
		return
	_t_reponer -= delta
	if _t_reponer > 0.0:
		return
	if _hay_sitio_en_el_agua():
		_nacer_pez()
	_armar_reposicion()


# ¿Cabe otro pez en el agua? Hacen falta las DOS cosas: hueco en la superficie (aforo) y una pieza
# en el banco. Es lo que separa "solo se ven cuatro" de "solo quedan cuatro".
func _hay_sitio_en_el_agua() -> bool:
	return _peces.size() < _aforo and _peces.size() < _stock


func _armar_reposicion() -> void:
	if _t_reponer <= 0.0 and _hay_sitio_en_el_agua():
		_t_reponer = REPONER


func _paso_lanzando() -> void:
	var t: float = clampf(_t / VUELO, 0.0, 1.0)
	_pintar_hilo(_corcho_base, t)
	if t >= 1.0:
		_estado = ESPERA
		_t = 0.0


# El pez que CHOCA con el corcho se engancha. Solo puede haber uno: si ya hay enganchado, este
# metodo ni corre (el estado ya no es ESPERA) y los demas siguen nadando tan tranquilos.
func _paso_espera() -> void:
	_pintar_corcho(Vector2(0.0, sin(_t * 2.2) * 1.2))   # cabeceo tonto en el agua
	# EL ESPEJO NO DECIDE MORDIDAS. La colision solo existe donde estan los peces de verdad, asi que
	# aqui solo se manda el corcho (lo hace _publicar_mi_corcho en _process) y se espera el aviso del
	# dueño (Net -> me_ha_picado). Sin esta puerta, las dos maquinas resolverian la misma mordida por
	# su cuenta y cada una engancharia un pez distinto.
	if not _soy_dueno():
		return
	var p: Dictionary = _pez_que_choca(_corcho_base)
	if not p.is_empty():
		_morder(p)


func _morder(p: Dictionary) -> void:
	_pez = p
	_estado = PICANDO
	_t = 0.0
	_toques = 0
	_toques_max = randi_range(2, 4)
	# La CAÑA se cobra AQUI: su 'golpes_menos' no quita tirones (no hay), alarga la ventana en la
	# que puedes clavarlo. Es donde de verdad se pierden los peces cuando empiezas.
	var tm: Dictionary = Game.tool_mods(Game.cana())
	_ventana = VENTANA_BASE + float(int(tm["golpes_menos"])) * VENTANA_POR_PUNTO


func _paso_picando() -> void:
	# Pulsar durante el picoteo ESPANTA al pez: el toque flojo es una finta, no la mordida.
	if _espacio_nuevo():
		_escapar("Has tirado demasiado pronto: el pez suelta el cebo.")
		return
	var fase: float = _t / TOQUE_DUR
	_pintar_corcho(Vector2(0.0, sin(fase * TAU) * TOQUE_AMP))
	if fase >= 1.0:
		_t = 0.0
		_toques += 1
		if _toques >= _toques_max:
			_estado = TIRON


func _paso_tiron() -> void:
	# El corcho SE HUNDE y tiembla fuerte: es la señal, y dura lo que dure la ventana.
	_pintar_corcho(Vector2(randf_range(-1.5, 1.5), TIRON_AMP + randf_range(-2.0, 2.0)))
	if _espacio_nuevo():
		_pelear()
		return
	if _t >= _ventana:
		_escapar("Se te ha escapado: has tardado en tirar.")


func _espacio_nuevo() -> bool:
	return Input.is_action_pressed(&"recolectar") and not _press_was


# GUARDAR LA CAÑA: sales de la pesca de un tiron desde donde estes, sin pasar por la mira. Es lo que
# hace el ESC y lo que hace el boton "Salir" de la capa tactil.
func _guardar_cana() -> void:
	_decir("Guardas la caña.")
	# `_pez = {}` y NO `_pez.clear()`: los Dictionary van por REFERENCIA, y este es el MISMO que esta
	# dentro de `_peces`. Vaciarlo le borraba los datos al pez de la lista y `_nadar` petaba al
	# buscarle el 't_giro' en el frame siguiente. Aqui solo hay que soltarlo: el pez sigue vivo.
	_pez = {}
	_soltar()


# RECOGER: hace los DOS pasos. Con el sedal fuera lo recoge y te deja apuntando; ya apuntando, esa es
# la que sale. Asi con lo mismo con lo que pescas dejas de pescar, y ninguna de las dos cosas te pilla
# por sorpresa. Es la F, y el boton "Recoger" de la capa tactil.
func _recoger_sedal() -> void:
	_decir("Guardas la caña." if _estado == APUNTANDO else "Recoges el sedal.")
	_pez = {}
	if _estado == APUNTANDO:
		_soltar()
	else:
		_volver_a_apuntar()


func _pelear() -> void:
	_estado = LUCHA
	_t = 0.0
	# La lucha monta SU propia zona de toque (ver fishing.gd) y las dos empujarian la misma accion:
	# con las dos puestas, levantar el dedo soltaba solo una y el sedal se quedaba tirando solo.
	_quitar_tactil()
	Game.start_pesca(self, _pez["data"], float(_pez["cm"]))


# Lo llama Game al terminar el minijuego. 'logrado' = has llenado la barra de tension.
func terminar_lucha(logrado: bool) -> void:
	if _estado != LUCHA:
		return
	if not logrado:
		_escapar("El pez se suelta y se va al fondo.")
		return
	_estado = COBRO
	_t = 0.0


# Se te ha escapado. El pez se va DEL AGUA (si se quedase volveria a morder a los tres segundos y
# fallar no costaria nada) pero NO SALE DEL BANCO: sigue vivo en el charco y vuelve a salir en unos
# segundos. Perder una pieza cuesta el rato y la excelia, no tu presupuesto de diez minutos.
#
# Y vuelve EL MISMO, con su especie y sus centimetros: es el mismo animal, no otro. Antes se borraba
# y el charco sorteaba uno nuevo, asi que perder el espejo abisal de tu vida y que reapareciera un
# gobio era lo normal — justo el momento en el que mas duele que el juego reparta de nuevo.
func _escapar(motivo: String) -> void:
	_decir(motivo)
	if not _pez.is_empty():
		# Con su NONCE: es el mismo animal, y en multi ese numero es su identidad (ver _nacer_pez).
		_escapados.append({"data": _pez["data"], "cm": float(_pez["cm"]),
			"nonce": int(_pez.get("nonce", 0))})
	_quitar_pez(false)
	_volver_a_apuntar()   # fallar no te echa de la pesca: te devuelve a la mira


# 'pescado' distingue las dos formas de salir del agua:
#   true  -> te lo llevas: sale del BANCO y arranca SU contador de 10 minutos para volver.
#   false -> se te ha escapado: el banco no se toca, solo vuelve a la cola de salida.
func _quitar_pez(pescado: bool) -> void:
	if _pez.is_empty():
		return
	var i: int = _peces.find(_pez)
	# MULTI (espejo): el banco no es mio, asi que aqui NO se toca — se le dice al dueño como acabo y
	# el lo apunta en el de verdad (resolver_pez_remoto). Mi copia se limpia igual para que el
	# minijuego siga su curso; la proxima foto la reconcilia.
	if not _soy_dueno():
		Net.resolver_pesca(_idx_enganchado if _idx_enganchado >= 0 else i, pescado)
		_pez = {}
		_idx_enganchado = -1
		_espero_mordida = false
		return
	if i >= 0:
		(_peces[i]["rect"] as ColorRect).queue_free()
		_peces.remove_at(i)
	_pez = {}
	_idx_enganchado = -1
	if pescado:
		_cobrar_del_banco()
	_armar_reposicion()


# Una pieza SALE del banco: baja el stock y arranca SU contador de 10 minutos. Suelto porque lo
# llaman dos caminos —el pescador local (_quitar_pez) y el remoto (resolver_pez_remoto)— y el banco
# es uno solo: si el invitado saca un pez, el charco del dueño tiene que notarlo igual.
func _cobrar_del_banco() -> void:
	_stock = maxi(0, _stock - 1)
	# SU propio sello, no uno compartido: diez capturas seguidas son diez vueltas escalonadas y
	# no una sola espera. Es lo que hace que vaciar el charco cueste de verdad.
	_vuelven.append(Game.tiempo_mazmorra + STOCK_REGEN)
	_guardar_estado()


# VUELVES A LA MIRA, no al mundo. Es el hermano de _soltar() y la diferencia es todo: NO saca el
# modal de la pila y NO le devuelve el control al jugador, porque no has terminado de pescar — has
# terminado UN LANZAMIENTO. Cobrar una pieza, perderla o recoger el sedal te dejan con la caña en la
# mano, listo para el siguiente tiro.
#
# El peaje que quita: antes, cada pez te echaba al mundo y repetir la accion que acababas de hacer
# costaba F + menu del estanque + "Tirar la caña". De la pesca ahora solo se sale cuando lo pides tu
# (F o ESC), o cuando el charco se queda seco y ya no hay nada que pescar.
func _volver_a_apuntar() -> void:
	_hilo.visible = false
	_corcho.visible = false
	# LA UNICA SALIDA AUTOMATICA. Si te has llevado la ultima pieza no tiene sentido dejarte apuntando
	# a un agua vacia diez minutos: eso no es un bucle, es una sala de espera. Mientras quede banco si
	# te quedas, que repone uno cada REPONER segundos y se ve llegar.
	if _stock <= 0:
		_soltar()
		_decir("Has dejado el charco seco. Dale un rato y volverán.")
		return
	# El cebo sigue puesto de un tiro al siguiente. Game.cebo_activo solo se vacia al gastar la ultima
	# unidad, asi que esto casi nunca llega a hacer nada: va para que la regla ("si te quedan mas,
	# sigue puesto") este escrita aqui y no dependa de un detalle de gastar_cebo_al_cobrar.
	if Game.cebo_activo == null and _ultimo_cebo != null:
		Game.poner_cebo(_ultimo_cebo)   # el se niega solo si te quedan 0

	# Se conserva el ANGULO (estas trabajando el mismo sitio del agua: re-apuntar a mano despues de
	# cada pez seria el mismo peaje por otro camino) y se tira la FUERZA, que es la decision del tiro.
	_ang_base = (-_origen_hilo()).angle()
	_ang = _ang_base + clampf(angle_difference(_ang_base, _ang), -ANGULO_MAX, ANGULO_MAX)
	if _tramo_de_agua(_ang).x < 0.0:
		_ang = _ang_base   # por si el angulo de antes ya no corta el agua
	_fuerza = 0.0
	_estado = APUNTANDO
	_t = 0.0
	# El ESPACIO con el que has ganado la pelea (o la F con la que has recogido) no puede contar como
	# el ESPACIO que carga el tiro siguiente ni como la F que sale. Misma trampa que en _lanzar().
	_press_was = true
	_f_was = true
	_esc_was = true
	_espacio_libre = false
	_mira.visible = true
	_montar_tactil()   # la lucha se llevo la suya por delante; si volvemos a apuntar, vuelve la nuestra
	_pintar_mira()


# ------------------------------------------------------------
#  LA CAPA TACTIL de la pesca (solo en el movil)
#  Vive de empezar_apuntado() a _soltar(), o hasta que empieza la lucha (que trae la suya). Lleva
#  la zona de arrastre para apuntar y los DOS botones que resuelven lo que sin teclado no tenia
#  salida: "Recoger" (la F: clava el tiron si ha picado, y si no recoge el sedal) y "Salir" (el ESC).
# ------------------------------------------------------------
const _TOUCH_PAD := preload("res://scripts/ui/touch_pad.gd")
var _capa_tactil: CanvasLayer = null
var _pad: Control = null


func _montar_tactil() -> void:
	if not Tactil.activo or _pad != null:
		return
	_capa_tactil = CanvasLayer.new()
	# Por debajo de la barra de tension de la lucha (100), por encima del HUD.
	_capa_tactil.layer = 90
	_capa_tactil.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_capa_tactil)
	_pad = _TOUCH_PAD.new()
	_capa_tactil.add_child(_pad)
	_pad.anadir_boton("Recoger", Color(0.20, 0.30, 0.42)).pressed.connect(_recoger_sedal)
	_pad.anadir_boton("Salir", Color(0.42, 0.20, 0.22)).pressed.connect(_guardar_cana)


func _quitar_tactil() -> void:
	_pad = null
	if is_instance_valid(_capa_tactil):
		_capa_tactil.queue_free()
	_capa_tactil = null


func _soltar() -> void:
	_estado = LIBRE
	_t = 0.0
	_quitar_tactil()
	_hilo.visible = false
	_corcho.visible = false
	_mira.visible = false
	_fuerza = 0.0
	Game.salir_modal(self)
	# El minijuego se juega a espaciazos y lanzar es F: sin esto, la ultima pulsacion vuelve a
	# echar el sedal (o te lanza contra el bicho que tengas al lado) nada mas soltar.
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador != null and jugador.has_method("bloquear_interaccion"):
		jugador.bloquear_interaccion()


# --- COBRO: el pez viene por el hilo, y SOLO al llegar es tuyo ---
func _paso_cobro(_delta: float) -> void:
	var jugador = get_tree().get_first_node_in_group("player")
	var destino: Vector2 = to_local(jugador.global_position) if jugador != null else Vector2.ZERO
	var t: float = clampf(_t / COBRO_DUR, 0.0, 1.0)
	var aqui: Vector2 = _corcho_base.lerp(destino, ease(t, 0.4))
	_pintar_corcho_en(aqui)
	if not _pez.is_empty():
		var rect: ColorRect = _pez["rect"]
		rect.position = aqui - rect.size * 0.5
	if t >= 1.0:
		_cobrar()


func _cobrar() -> void:
	var d: MaterialData = _pez.get("data", null)
	var cm: float = float(_pez.get("cm", 0.0))
	_quitar_pez(true)   # este SI sale del banco: te lo llevas puesto
	# EL ORDEN IMPORTA: primero se cobra y se paga el cebo, y la vuelta a la mira va LA ULTIMA. Al
	# reves, el re-equipado de _volver_a_apuntar pondria un cebo que la linea siguiente se gasta.
	if d != null:
		Game.cobrar_pesca(d, cm)
		# EL CEBO SE PAGA AQUI Y SOLO AQUI: con la pieza ya en la mano. Ni al escaparse el pez ni al
		# recoger el sedal, para que fallar el tiron no cueste dos veces.
		var aviso: String = Game.gastar_cebo_al_cobrar()
		if aviso != "":
			_decir(aviso)
	_volver_a_apuntar()


# ------------------------------------------------------------
#  GEOMETRIA DEL TIRO
# ------------------------------------------------------------
# La punta de la caña en coordenadas locales del charco: el jugador, subido un poco. De aqui salen
# TANTO el hilo como la linea de puntos de la mira, para que apuntes desde donde luego sale.
func _origen_hilo() -> Vector2:
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador == null:
		return Vector2.ZERO
	return to_local(jugador.global_position) + Vector2(0.0, -10.0)


# EL TRAMO DE AGUA que atraviesa un tiro en ese angulo: (t de entrada, t de salida) en px desde la
# punta de la caña. Devuelve (-1, -1) si ese angulo NO corta la balsa.
#
# Es la interseccion clasica rayo-rectangulo por "slabs", contra el agua encogida MIRA_MARGEN por
# cada lado. Todo el lanzamiento cuelga de esto: como el punto se elige DENTRO del tramo, el corcho
# no puede caer fuera del agua por construccion y no hace falta ningun clamp que falsee la mira.
func _tramo_de_agua(ang: float) -> Vector2:
	var lim: Vector2 = tam_px() * 0.5 - Vector2(MIRA_MARGEN, MIRA_MARGEN)
	if lim.x <= 0.0 or lim.y <= 0.0:
		return Vector2(-1.0, -1.0)
	var ini: Vector2 = _origen_hilo()
	var dir: Vector2 = Vector2.from_angle(ang)
	var t0: float = -INF
	var t1: float = INF
	for eje in 2:
		var d: float = dir.x if eje == 0 else dir.y
		var o: float = ini.x if eje == 0 else ini.y
		var l: float = lim.x if eje == 0 else lim.y
		if absf(d) < 0.0001:
			# Paralelo a este eje: o ya estas dentro de la franja, o no entras nunca.
			if absf(o) > l:
				return Vector2(-1.0, -1.0)
			continue
		var ta: float = (-l - o) / d
		var tb: float = (l - o) / d
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	t0 = maxf(t0, 0.0)
	if t1 <= t0:
		return Vector2(-1.0, -1.0)
	return Vector2(t0, t1)


# DONDE CAE EL CORCHO con la fuerza cargada ahora mismo. Fuerza 0 cae justo pasada la orilla (ver
# TIRO_MIN), media barra a MEDIA TRAVESIA del charco y la barra llena casi en el borde de enfrente.
func _punto_de_tiro(ang: float) -> Vector2:
	var tramo: Vector2 = _tramo_de_agua(ang)
	if tramo.x < 0.0:
		return Vector2.ZERO   # angulo imposible: al centro del agua, que siempre vale
	var cerca: float = tramo.x + (tramo.y - tramo.x) * TIRO_MIN
	return _origen_hilo() + Vector2.from_angle(ang) * lerpf(cerca, tramo.y, clampf(_fuerza, 0.0, 1.0))


func _pintar_mira() -> void:
	var ini: Vector2 = _origen_hilo()
	var fin: Vector2 = _punto_de_tiro(_ang)
	# La linea de puntos NO llega hasta el final: el ultimo tramo se lo queda el aro, para que el
	# punto de caida se lea como un sitio y no como el ultimo punto de una fila.
	for i in _mira_puntos.size():
		var u: float = float(i + 1) / float(_mira_puntos.size() + 1)
		var punto: ColorRect = _mira_puntos[i]
		punto.position = ini.lerp(fin, u) - punto.size * 0.5
	_mira_aro.position = fin

	# El medidor va pegado al jugador y NO gira con la mira: es cuanto has cargado, no hacia donde.
	var barra: Vector2 = ini + Vector2(14.0, -_barra_fondo.size.y * 0.5)
	_barra_fondo.position = barra
	_barra_relleno.size = Vector2(_barra_fondo.size.x, _barra_fondo.size.y * clampf(_fuerza, 0.0, 1.0))
	_barra_relleno.position = barra + Vector2(0.0, _barra_fondo.size.y - _barra_relleno.size.y)
	_mira_lbl.position = ini + Vector2(0.0, -34.0)


# ------------------------------------------------------------
#  PINTAR la caña
# ------------------------------------------------------------
# El hilo NO es una recta: sale del personaje, sube a un pico por encima de el y cae al agua, tal y
# como se lanza de verdad. 'vuelo' < 1 lo dibuja a medio camino (el lanzamiento).
func _pintar_hilo(punta: Vector2, vuelo: float = 1.0) -> void:
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador == null:
		_hilo.visible = false
		return
	var ini: Vector2 = _origen_hilo()
	var fin: Vector2 = ini.lerp(punta, clampf(vuelo, 0.0, 1.0))
	# El pico del arco: el punto medio, subido. Se dibuja con una parabola de tres puntos por
	# Bezier cuadratica, muestreada en unos pocos tramos (un Line2D no curva solo).
	var alto: Vector2 = (ini + fin) * 0.5 + Vector2(0.0, -ARCO_ALTO * clampf(vuelo, 0.2, 1.0))
	var pts := PackedVector2Array()
	for i in range(9):
		var u: float = float(i) / 8.0
		pts.append(ini.lerp(alto, u).lerp(alto.lerp(fin, u), u))
	_hilo.points = pts


func _pintar_corcho(desvio: Vector2) -> void:
	_pintar_corcho_en(_corcho_base + desvio)


func _pintar_corcho_en(pos: Vector2) -> void:
	_corcho.position = pos - _corcho.size * 0.5
	_pintar_hilo(pos)


# ============================================================
#  MULTIJUGADOR
#  El dueño del piso simula el charco entero; los demas lo ven en espejo y le mandan su corcho.
#  Ver la cabecera del archivo para el reparto completo.
# ============================================================

# Color del pez que esta peleando OTRO. Mas claro que el resto: es la señal de "eso ya lo tiene tu
# compañero". No hace falta mas: el charco es pequeño y el contraste con el agua ya canta.
const COLOR_PEZ_OCUPADO := Color(0.35, 0.55, 0.70, 0.55)


# El pez LIBRE que choca con un corcho puesto en 'donde' (coordenadas locales del charco), o null.
# Suelto porque lo usan las dos mordidas: la mia (_paso_espera) y la de cada pescador remoto
# (_mordidas_remotas). Una sola regla de colision para todos, que es justo lo que hace que las dos
# maquinas no puedan discrepar sobre quien ha picado.
func _pez_que_choca(donde: Vector2) -> Dictionary:
	for p in _peces:
		if int(p.get("de", 0)) != 0 or _pez_es(p):
			continue   # ya lo esta peleando alguien
		var d: Vector2 = (p["pos"] as Vector2) - donde
		if absf(d.x) < float(p["largo"]) * 0.5 + 6.0 and absf(d.y) < float(p["alto"]) * 0.5 + 6.0:
			return p
	return {}   # {} = ninguno, el mismo convenio que _pez en todo el archivo


# DUEÑO: resuelve la mordida de los pescadores remotos. Corre en cada frame porque los peces se
# mueven en cada frame; es una pasada por una lista de seis como mucho.
func _mordidas_remotas() -> void:
	if _corchos.is_empty():
		return
	for peer in _corchos:
		var c: Dictionary = _corchos[peer]
		if not bool(c.get("activo", false)):
			continue
		var p: Dictionary = _pez_que_choca(c["pos"])
		if p.is_empty():
			continue
		# Se le reserva AQUI, antes de avisarle. Si esperase a su respuesta, en ese viaje de ida y
		# vuelta el mismo pez podria picarle tambien a otro.
		p["de"] = peer
		c["activo"] = false   # ya tiene pieza: su corcho deja de pescar hasta que resuelva
		Net.avisar_mordida(peer, _peces.find(p))


# ESPEJO: le mando al dueño donde tengo el corcho, y solo mientras de verdad este pescando. Fuera de
# ESPERA no hay nada que pescar (o ya tengo pieza), y mandarlo igual haria que me picase un pez
# mientras peleo con otro.
func _publicar_mi_corcho() -> void:
	var pescando: bool = _estado == ESPERA and _pez.is_empty() and not _espero_mordida
	Net.publicar_corcho(_corcho_base, pescando)


# DUEÑO: llega el corcho de un pescador remoto (o el aviso de que lo ha recogido).
func corcho_remoto(peer: int, pos: Vector2, activo: bool) -> void:
	if not _soy_dueno():
		return
	if not activo and not _corchos.has(peer):
		return
	if not _corchos.has(peer):
		_corchos[peer] = {}
	_corchos[peer]["pos"] = pos
	_corchos[peer]["activo"] = activo
	if not activo:
		_soltar_peces_de(peer)


# ESPEJO: el dueño me dice que me ha picado el pez 'idx'. A partir de aqui el minijuego es MIO y va
# en local (el picoteo, el tiron y la barra de tension): lo unico que el dueño necesita saber es como
# acaba, y eso se lo digo en Net.resolver_pesca.
func me_ha_picado(idx: int) -> void:
	if _soy_dueno() or _estado != ESPERA:
		return
	if idx < 0 or idx >= _peces.size():
		return
	_idx_enganchado = idx
	_espero_mordida = false
	_morder(_peces[idx])


# DUEÑO: un pescador remoto ha terminado con su pez. Es el unico sitio donde el banco baja por culpa
# de otro, y por eso pasa por aqui y no por _quitar_pez: el que cobra es EL, con su charco espejado;
# aqui solo se apunta el resultado en el banco de verdad.
func resolver_pez_remoto(peer: int, idx: int, cobrado: bool) -> void:
	if not _soy_dueno():
		return
	if idx < 0 or idx >= _peces.size():
		_soltar_peces_de(peer)   # el indice ya no vale: al menos que no se quede el candado puesto
		return
	var p: Dictionary = _peces[idx]
	if int(p.get("de", 0)) != peer:
		return   # no era suyo: llega tarde (ya se lo solto la desconexion, o el indice ha bailado)
	p["de"] = 0
	if not cobrado:
		return
	# Se lo lleva: fuera del agua y fuera del banco, con su sello de diez minutos.
	(p["rect"] as ColorRect).queue_free()
	_peces.remove_at(idx)
	_cobrar_del_banco()
	_armar_reposicion()


# DUEÑO: suelta lo que tuviera reservado un peer (recoge el sedal, se va del piso, se desconecta).
func _soltar_peces_de(peer: int) -> void:
	for p in _peces:
		if int(p.get("de", 0)) == peer:
			p["de"] = 0


func soltar_todo_de(peer: int) -> void:
	if not _soy_dueno():
		return
	_corchos.erase(peer)
	_soltar_peces_de(peer)


# La FOTO del charco que viaja a los espejos. Un pez son cuatro cosas y ninguna sobra:
#   nonce -> con el, el espejo saca especie y talla del MISMO sorteo determinista que el dueño, asi
#            que no hace falta mandar ni el MaterialData ni los centimetros.
#   pos   -> donde nada (lo unico que cambia en cada foto).
#   ang   -> hacia donde mira, para que el rectangulo no vaya de lado.
#   de    -> quien lo tiene enganchado, 0 = libre. Es lo que el espejo pinta distinto.
func estado_red() -> Dictionary:
	var lista: Array = []
	for p in _peces:
		lista.append([int(p.get("nonce", 0)), p["pos"], (p["vel"] as Vector2).angle(),
			int(p.get("de", 0))])
	return {"peces": lista, "stock": _stock, "aforo": _aforo}


# ESPEJO: llega la foto. Se reconcilia POR NONCE y no por indice: si se pierde un paquete y el banco
# ha cambiado, por indice cada pez heredaria los datos del que ocupaba su sitio (una anguila pasaria
# a ser un gobio sin avisar). Con el nonce, cada uno sigue siendo quien es.
func aplicar_red(snap: Dictionary) -> void:
	if _soy_dueno():
		return   # el dueño no se aplica su propia foto
	_stock = int(snap.get("stock", _stock))
	_aforo = int(snap.get("aforo", _aforo))
	var filas: Array = snap.get("peces", [])

	var mios: Dictionary = {}
	for p in _peces:
		mios[int(p.get("nonce", 0))] = p

	var nuevos: Array = []
	var destinos: Array = []
	for f in filas:
		var nonce: int = int(f[0])
		var p: Dictionary = mios.get(nonce, {})
		if p.is_empty():
			p = _nacer_pez_espejo(nonce, f[1])
			if p.is_empty():
				continue
		else:
			mios.erase(nonce)
		p["de"] = int(f[3])
		# El enganchado por OTRO se pinta mas claro: es la señal de "eso lo esta peleando tu
		# compañero, no le tires encima". El que engancho YO se queda como esta.
		(p["rect"] as ColorRect).color = COLOR_PEZ_OCUPADO if int(f[3]) != 0 \
			else Color(0.04, 0.07, 0.12, 0.45)
		nuevos.append(p)
		destinos.append([f[1], f[2]])

	# Lo que ya no viene en la foto se ha ido del agua (lo pesco alguien, o se retiro).
	for sobra in mios.values():
		if _pez_es(sobra):
			_pez = {}   # me lo han quitado de debajo: suelto la referencia antes de liberarlo
		(sobra["rect"] as ColorRect).queue_free()
	_peces = nuevos
	_destinos = destinos
	_idx_enganchado = _peces.find(_pez) if not _pez.is_empty() else -1


# ESPEJO: crea el rectangulo de un pez que aun no tenia. La especie y la talla NO viajan: salen del
# mismo sorteo sembrado que uso el dueño (semilla del piso + celda + nonce), asi que las dos maquinas
# sacan exactamente el mismo bicho sin gastar un byte en ello.
func _nacer_pez_espejo(nonce: int, pos: Vector2) -> Dictionary:
	if tabla == null:
		return {}
	var r := RandomNumberGenerator.new()
	r.seed = hash([_semilla(), celda.x, celda.y, nonce])
	var d: MaterialData = tabla.elegir(Game.current_floor, r)
	if d == null:
		return {}
	var cm: float = d.talla_desde(MaterialData.tirada_talla(r))
	var tam_agua: Vector2 = tam_px()
	var largo: float = clampf(cm * PX_POR_CM, LARGO_MIN,
		minf(tam_agua.x, tam_agua.y) * LARGO_MAX_FRAC)
	var alto: float = maxf(2.0, largo / maxf(1.2, d.esbeltez))
	var rect := ColorRect.new()
	rect.size = Vector2(largo, alto)
	rect.pivot_offset = rect.size * 0.5
	rect.color = Color(0.04, 0.07, 0.12, 0.45)
	add_child(rect)
	var p: Dictionary = {
		"rect": rect, "data": d, "cm": cm, "largo": largo, "alto": alto,
		"pos": pos, "vel": Vector2.RIGHT, "t_giro": 0.0, "cebo": false, "de": 0, "nonce": nonce,
	}
	_colocar(p)
	return p


# ESPEJO: entre foto y foto (10 Hz) los peces se acercan a su ultimo destino conocido. Sin esto se
# moverian a tirones de diez por segundo, que es exactamente lo que se ve mal.
func _interpolar_peces(delta: float) -> void:
	var t: float = 1.0 - exp(-SUAVIZADO_RED * delta)
	for i in mini(_peces.size(), _destinos.size()):
		var p: Dictionary = _peces[i]
		var destino: Vector2 = _destinos[i][0]
		p["pos"] = (p["pos"] as Vector2).lerp(destino, t)
		var rect: ColorRect = p["rect"]
		rect.rotation = lerp_angle(rect.rotation, float(_destinos[i][1]), t)
		_colocar(p)
