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
#  EL AGUA NO SE PINTA AQUI. La pinta el TileMapLayer del piso, con la MISMA capa "agua" que el
#  riachuelo (ver Decorado._trazar_lago): por eso el charco tiene forma, ondas y orilla, y por eso
#  la junta con el riachuelo no existe en vez de disimularse. Lo que queda aqui es la FORMA como
#  dato (`celdas`, y hay_agua() para preguntarle), la colision, los peces, el hilo y el corcho.
#
#  Y LOS PECES tienen silueta propia por especie (PezSprites): se hornean a todo color y aqui se les
#  pone el tinte del agua con un modulate, asi que la misma hoja vale para el charco y para el libro
#  de pesca. La talla se redondea a un escalon horneado -- nada de `scale`, que rompe la rejilla de
#  pixeles. Todo eso pasa por _crear_sprite_pez, que es el UNICO sitio donde se decide como se ve
#  un pez: el dueño y el espejo de red llaman los dos ahi.
# ============================================================

extends Node2D

enum { LIBRE, APUNTANDO, LANZANDO, ESPERA, PICANDO, TIRON, LUCHA, COBRO }

# --- Lo que le pone DungeonFloor al crearlo ---
var celda: Vector2i = Vector2i.ZERO
var tam_celdas: Vector2i = Vector2i(4, 3)
# LA FORMA DEL AGUA, en celdas absolutas del mapa (la calcula Decorado.forma_lago). El charco dejo
# de ser un rectangulo, asi que esta es la unica fuente de verdad de "¿aqui hay agua?": la MISMA
# rejilla que dibuja las baldosas, y por eso nunca puede haber desacuerdo entre lo que se ve y
# donde se puede pescar.
var celdas: Dictionary = {}
# El corazon del lago: donde el agua es honda y donde un pez cabe seguro. Ahi nacen.
var celdas_hondas: Dictionary = {}
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
# SUELO del largo. Subio de 6 a 10 al llegar las siluetas: en 7x3 px no hay pez que dibujar --
# cabeza, cola y aleta caen en el mismo pixel y vuelve a salir la mancha que esto venia a quitar.
# Los peces mas chicos se ven un pelin mas grandes de lo que les tocaria por sus centimetros; a
# cambio TODOS tienen forma.
const LARGO_MIN := 10.0
# TECHO del largo, en fraccion del lado corto del charco. Sin el, un espejo abisal de 165 cm sale de
# 99 px y no CABE en un charco de 128x96: se quedaba clavado contra los bordes o asomando fuera.
# Los tamaños siguen distinguiendose (un gobio son 7 px y el trofeo llena media balsa), pero el
# charco manda: nada nada mas grande que el agua en la que nada.
const LARGO_MAX_FRAC := 0.42
# Frames de coleteo por pixel recorrido. A la velocidad de crucero (18 px/s) sale un ciclo completo
# cada 1.4 s, que es un bateo tranquilo; el que se tira a por el cebo bate al doble.
const ALETEO_POR_PX := 0.155

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
#    - STOCK_REGEN (10 min de reloj de pared): cada pez PESCADO vuelve al banco, con SU PROPIO
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
# RELOJ DE PARED los dos (Game.reloj_mundo), no tiempo_mazmorra. Aqui importaba mas que en ningun
# otro sitio: pescar ES estar quieto abriendo menus, y tiempo_mazmorra se congela con cualquiera de
# ellos, asi que el banco no se reponia justo mientras pescabas. Y el sorteo del aforo va sembrado
# con el TRAMO de reloj para que las dos maquinas vean el mismo humor: con un reloj local eso no
# podia funcionar (cada una lleva el suyo), con el de pared si.
const STOCK_REGEN := 600.0      # segundos de reloj que tarda en volver UN pez pescado
const AFORO_REVISION := 600.0   # cada cuanto el charco vuelve a sortear su aforo

# Lo que tarda en salir al agua el siguiente pez del banco.
const REPONER := 4.0
var _t_reponer: float = 0.0
# Peces que HAY (los que nadan mas los que esperan turno).
var _stock: int = STOCK_MAX
# Cuantos se ven a la vez ahora mismo. Se re-sortea cada AFORO_REVISION.
var _aforo: int = PECES_MIN
var _t_aforo: float = 0.0       # reloj de pared del ultimo sorteo
# Sellos de reloj de pared en los que vuelve al banco cada pez pescado. Uno por pieza: es lo que
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
# ESPEJO: lo ultimo que le dije al dueño sobre mi corcho, para no repetirselo cada frame (ver
# _publicar_mi_corcho). El latido lo reenvia igual de vez en cuando por si se perdio el paquete.
const CORCHO_LATIDO := 0.5
var _corcho_ultimo_pos: Vector2 = Vector2.INF
var _corcho_ultimo_activo: bool = false
var _t_corcho: float = 0.0


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
	# EL AGUA SE OYE al acercarte. Va colgado del charco y no de una capa global a proposito: es lo
	# que hace que se note DONDE esta sin tener que verlo.
	Ambiente.pegar(self, "charco", -3.0, 340.0)
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


# ============================================================
#  LA FORMA DEL AGUA
# ============================================================
# El charco tiene forma, asi que "¿esto esta dentro del agua?" ya no se contesta con un Rect2. Se
# contesta MIRANDO LA CELDA, que es la misma rejilla con la que se pintan las baldosas: lo que se
# ve y lo que se puede pescar no pueden discrepar porque son el mismo dato.
#
# Todo lo de aqui trabaja en PIXELES LOCALES (el origen es el centro del charco). El +0.5 del
# redondeo no es cosmetico: `position = gen.centro_px(celda)`, o sea que el origen local cae en el
# CENTRO de su celda y no en su esquina. Sin ese medio pixel, la rejilla logica sale corrida media
# celda de la que se dibuja.
var _centro_agua: Vector2 = Vector2.ZERO    # centroide del agua, pegado a una celda mojada
var _aabb: Rect2 = Rect2()                  # lo que ocupa el agua, en px locales
var _hondas_px: Array[Vector2] = []         # centros de las celdas hondas, para ahi nacer los peces


func _celda_de(p: Vector2) -> Vector2i:
	var cl: float = float(DungeonGenerator.CELDA)
	return celda + Vector2i(floori(p.x / cl + 0.5), floori(p.y / cl + 0.5))


func _px_de(c: Vector2i) -> Vector2:
	return Vector2(c - celda) * float(DungeonGenerator.CELDA)


func hay_agua(p: Vector2) -> bool:
	return celdas.has(_celda_de(p))


func hay_hondo(p: Vector2) -> bool:
	return celdas_hondas.has(_celda_de(p))


# El rectangulo de siempre, para cuando nadie ha dado la forma (ver _crear_aspecto).
func _rellenar_forma_rectangular() -> void:
	var mitad := Vector2i(tam_celdas.x / 2, tam_celdas.y / 2)
	for dx in tam_celdas.x:
		for dy in tam_celdas.y:
			celdas[celda - mitad + Vector2i(dx, dy)] = true
	if celdas_hondas.is_empty():
		celdas_hondas[celda] = true


# El centroide, el bounding box y la lista de celdas hondas. Se calcula UNA vez: la forma no cambia.
func _medir_agua() -> void:
	var cl: float = float(DungeonGenerator.CELDA)
	var suma := Vector2.ZERO
	var min_c := Vector2(INF, INF)
	var max_c := Vector2(-INF, -INF)
	for c in celdas:
		var p: Vector2 = _px_de(c)
		suma += p
		min_c = min_c.min(p - Vector2(cl, cl) * 0.5)
		max_c = max_c.max(p + Vector2(cl, cl) * 0.5)
	_aabb = Rect2(min_c, max_c - min_c)
	var centroide: Vector2 = suma / float(celdas.size())
	# PEGADO A UNA CELDA MOJADA, no el centroide a secas: en un lago con una cala en medio el
	# centroide puede caer en tierra, y este punto es el "sitio del agua que siempre vale" que usan
	# la mira y el lanzamiento por defecto.
	_centro_agua = centroide
	var mejor: float = INF
	for c in celdas:
		var p: Vector2 = _px_de(c)
		var d: float = p.distance_squared_to(centroide)
		if d < mejor:
			mejor = d
			_centro_agua = p
	_hondas_px.clear()
	for c in celdas_hondas:
		_hondas_px.append(_px_de(c))
	if _hondas_px.is_empty():
		_hondas_px.append(_centro_agua)


# El agua troceada en tiras horizontales de celdas contiguas, en px locales. Es como se monta la
# colision: menos formas que una por celda, y describe el mismo borde.
func _tiras_de_agua() -> Array[Rect2]:
	var cl: float = float(DungeonGenerator.CELDA)
	var filas: Dictionary = {}
	for c in celdas:
		var f: int = c.y
		if not filas.has(f):
			filas[f] = []
		(filas[f] as Array).append(c.x)
	var tiras: Array[Rect2] = []
	for f in filas:
		var xs: Array = filas[f]
		xs.sort()
		var i: int = 0
		while i < xs.size():
			var j: int = i
			while j + 1 < xs.size() and int(xs[j + 1]) == int(xs[j]) + 1:
				j += 1
			var izq: Vector2 = _px_de(Vector2i(int(xs[i]), int(f))) - Vector2(cl, cl) * 0.5
			tiras.append(Rect2(izq, Vector2(cl * float(j - i + 1), cl)))
			i = j + 1
	return tiras


# Cuanto SOBRESALE el charco de su centro. Lo lee player._mas_cercano_en_grupo para medir la
# distancia contra el BORDE del agua y no contra su centro: si no, un charco de 4x3 celdas te
# obligaria a meterte dentro para que la F llegase.
var radio_extra: float:
	get: return tam_px().length() * 0.5


func _crear_aspecto() -> void:
	var tam: Vector2 = tam_px()
	# EL AGUA YA NO SE PINTA AQUI: la pinta el TileMapLayer del piso, con la misma capa "agua" que
	# el riachuelo (ver Decorado._trazar_lago y TerrenoSprites._pintar_agua). Lo que habia era un
	# ColorRect de un color plano, y se veia como lo que era.
	#
	# EL CHARCO DE EMERGENCIA. Si nadie le ha dado la forma (un piso construido por un camino que no
	# pasa por Decorado, un save raro), se cae al rectangulo de siempre CON su ColorRect. Degradar
	# al charco viejo es feo pero se juega; degradar a un charco INVISIBLE con colision es un bug de
	# campo imposible de diagnosticar -- el jugador ve suelo y choca contra la nada.
	if celdas.is_empty():
		push_warning("[pesca] el charco no ha recibido su forma: se cae al rectangulo")
		_rellenar_forma_rectangular()
		_agua = ColorRect.new()
		_agua.size = tam
		_agua.position = -tam * 0.5
		_agua.color = Color(0.11, 0.19, 0.30, 0.85)
		add_child(_agua)
	_medir_agua()

	# MURO INVISIBLE. El charco es agua, no suelo: se pesca DESDE LA ORILLA y no metido dentro. Es
	# la excepcion a la regla de resource_node.gd ("los recolectables no tienen colision, estorbar no
	# es interesante"): aqui la colision no estorba, DEFINE el sitio -- sin ella el jugador se planta
	# encima de los peces y el hilo, y toda la puesta en escena deja de tener sentido.
	# Capa por defecto, la misma que los muros del piso (ver DungeonFloor._construir_geometria).
	#
	# UNA CAJA POR TIRA HORIZONTAL de celdas y no una por celda: un lago de veinte celdas se cubre
	# con cuatro o cinco cajas en vez de veinte. Y no un CollisionPolygon2D, que seria concavo (hay
	# calas) y habria que descomponerlo, para acabar describiendo el mismo borde de rejilla.
	var cuerpo := StaticBody2D.new()
	for tira in _tiras_de_agua():
		var forma := RectangleShape2D.new()
		forma.size = tira.size
		var col := CollisionShape2D.new()
		col.shape = forma
		col.position = tira.get_center()
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
	# Las cuatro, no A/D: la mira va hacia donde pulses, y cual manda depende de donde estes plantado
	# (ver _paso_apuntando). Decir "A/D" mandaba a pelearse con la tecla que no hacia nada.
	# Y en tactil no se dice ninguna tecla, que ahi no hay: se toca el agua y se mantiene Lanzar.
	_mira_lbl.text = "Toca el agua  ·  MANTÉN LANZAR" if Tactil.activo \
		else "WASD apunta  ·  MANTÉN ESPACIO  ·  F o ESC salen"
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
	rng.seed = hash([_semilla(), Game.epoca_actual(), celda.x, celda.y])
	_aforo = rng.randi_range(PECES_MIN, PECES_MAX)
	_t_aforo = Game.reloj_mundo()
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
	_t_aforo = float(guardado.get("t_aforo", Game.reloj_mundo()))
	# Lo que haya vencido mientras no mirabas entra ahora: el reloj corre aunque no estes en el piso.
	_cobrar_vueltas()
	_revisar_aforo()


# Devuelve al banco los peces cuyo contador de 10 minutos ya ha vencido.
func _cobrar_vueltas() -> void:
	var quedan: Array = []
	for t in _vuelven:
		if Game.reloj_mundo() >= float(t):
			_stock = mini(STOCK_MAX, _stock + 1)
		else:
			quedan.append(t)
	_vuelven = quedan


# Cada AFORO_REVISION el charco decide cuantos peces enseña. NO mata a los que ya nadan: si el aforo
# baja, simplemente deja de reponer hasta que sobren. El sorteo va sembrado con el TRAMO de tiempo,
# asi que los dos jugadores de una partida en red ven el mismo humor sin hablarse.
func _revisar_aforo() -> void:
	if Game.reloj_mundo() - _t_aforo < AFORO_REVISION:
		return
	var tramo: int = int(Game.reloj_mundo() / AFORO_REVISION)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_semilla(), Game.epoca_actual(), celda.x, celda.y, tramo, "aforo"])
	_aforo = rng.randi_range(PECES_MIN, PECES_MAX)
	_t_aforo = Game.reloj_mundo()


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
#
# Y lleva la EPOCA (ver Game.epoca_mazmorra): sin ella el charco daba SIEMPRE los mismos peces, en el
# mismo orden y con las mismas tallas, durante toda la partida —el _nonce arranca en 0 en cada
# instancia, asi que el primer pez de cada visita era literalmente el mismo bicho—. Con la epoca,
# cada expedicion estrena banco; dentro de una, subir y bajar sigue dando lo mismo.
func _rng_pez() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_semilla(), Game.epoca_actual(), celda.x, celda.y, _nonce])
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

	var spr: Sprite2D = _crear_sprite_pez(d, largo)

	# DONDE NACE: en una celda del CORAZON del lago (las que no tocan tierra), que es donde un pez
	# cabe seguro. Se comprueban sus dos puntas y, si no cabe, se prueba otra celda.
	#
	# OJO AL ORDEN DE LAS TIRADAS: todo esto va DESPUES de `tabla.elegir` y de `tirada_talla`, que
	# son las dos que _nacer_pez_espejo repite letra por letra del stream sembrado. Una tirada nueva
	# metida ANTES le cambiaria al invitado la especie y la talla, y sin dar ningun error.
	var ang: float = r.randf() * TAU
	var pos: Vector2 = _centro_agua
	for _intento in 8:
		var base: Vector2 = _hondas_px[r.randi_range(0, _hondas_px.size() - 1)]
		var cl: float = float(DungeonGenerator.CELDA) * 0.5 - 2.0
		var tanteo: Vector2 = base + Vector2(r.randf_range(-cl, cl), r.randf_range(-cl, cl))
		if _cabe(tanteo, Vector2.from_angle(ang), largo):
			pos = tanteo
			break
	var vel: float = VEL_PEZ + r.randf_range(-VEL_PEZ_VAR, VEL_PEZ_VAR)
	_peces.append({
		"spr": spr, "data": d, "cm": cm, "largo": largo, "alto": alto,
		"talla": PezSprites.talla_de(largo),
		# El reloj del coleteo. Es SUYO y no global: si todos batieran a la vez, un banco de peces
		# se leeria como un mecanismo y no como cinco bichos.
		"aleteo": r.randf() * float(PezSprites.FRAMES),
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


# ============================================================
#  EL ASPECTO DE UN PEZ
# ============================================================
# EL UNICO SITIO donde se decide como se ve un pez. Lo llaman _nacer_pez (el dueño, que lo simula) y
# _nacer_pez_espejo (el invitado, que lo recrea desde el nonce). Antes eran dos ColorRect escritos
# por separado, y mientras un pez era un rectangulo liso eso se podia mantener a mano; con una
# silueta, una talla y un coleteo, dos copias es cuestion de tiempo que enseñen bichos distintos en
# cada maquina.
#
# LA TALLA sale de PezSprites.talla_de, que es pura: las dos maquinas parten del mismo `largo` y
# llegan al mismo escalon sin que viaje nada por el cable.
func _crear_sprite_pez(d: MaterialData, largo: float) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = PezSprites.textura(d, PX_POR_CM, LARGO_MIN,
		minf(tam_px().x, tam_px().y) * LARGO_MAX_FRAC)
	spr.region_enabled = true
	spr.region_rect = _region_pez(d, PezSprites.talla_de(largo), 0)
	# POR NODO, que el proyecto no lo pone globalmente (misma nota que en enemy.gd y en
	# dungeon_floor). Sin esto el pez sale emborronado justo donde se le mira de cerca.
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	return spr


# La ventana de la hoja que le toca a (especie, talla, frame del coleteo).
func _region_pez(d: MaterialData, talla: int, frame: int) -> Rect2:
	var techo: float = minf(tam_px().x, tam_px().y) * LARGO_MAX_FRAC
	var tallas: Array[int] = PezSprites.tallas_de(d, PX_POR_CM, LARGO_MIN, techo)
	var celda: Vector2i = PezSprites.lienzo(tallas.back())
	var fila: int = PezSprites.fila_de(d, talla, PX_POR_CM, LARGO_MIN, techo)
	return Rect2(Vector2(float(frame * celda.x), float(fila * celda.y)), Vector2(celda))


# EL TINTE DEL AGUA. La hoja se hornea a todo color y es esto lo que lo apaga: multiplicar conserva
# la silueta entera -- contorno, cola, barbillones -- y a la vez lo vira al azul, asi que sigue
# leyendose "esta sumergido" pero ya tiene forma. Antes el pez ERA el color oscuro, y por eso todos
# se veian igual.
#
# La PROFUNDIDAD sale del nonce y no de una tirada: el espejo la reproduce sin gastar numero del
# stream sembrado, que es lo unico que no se puede tocar sin descuadrarle la especie al invitado.
const TONO_SUMERGIDO := Color(0.42, 0.55, 0.72, 0.88)
# El que esta peleando un compañero se pinta MAS CLARO: se ve que alguien lo tiene en el anzuelo.
const TONO_OCUPADO := Color(0.72, 0.82, 0.95, 0.95)
# Cuanto puede llegar a apagarse un pez por nadar hondo.
const HONDURA_MIN := 0.74

func _tono_pez(p: Dictionary) -> Color:
	if int(p.get("de", 0)) != 0:
		return TONO_OCUPADO
	var h: float = float(int(hash([p.get("nonce", 0), "hondura"])) % 1000) / 1000.0
	var f: float = lerpf(HONDURA_MIN, 1.0, h)
	# Y ademas se apaga si esta sobre el corazon del lago: es lo que lo ata al agua en vez de
	# dejarlo flotando por encima de ella.
	if hay_hondo(p.get("pos", Vector2.ZERO)):
		f *= 0.88
	return Color(TONO_SUMERGIDO.r * f, TONO_SUMERGIDO.g * f, TONO_SUMERGIDO.b * f,
		TONO_SUMERGIDO.a)


# ¿Cabe el pez ahi, con ese rumbo? Se miran el centro y las dos puntas: un pez es un segmento, no
# un punto, y el morro es justo lo que se salia del agua cuando esto se medía por ejes.
func _cabe(pos: Vector2, vel: Vector2, largo: float) -> bool:
	if not hay_agua(pos):
		return false
	var dir: Vector2 = vel.normalized() * (largo * 0.5)
	return hay_agua(pos + dir) and hay_agua(pos - dir)


func _colocar(p: Dictionary) -> void:
	# Un Sprite2D es `centered`: su posicion YA es su centro. Con el ColorRect habia que restarle
	# media caja a mano y ademas fijarle el pivote para que girara sobre si mismo.
	(p["spr"] as Sprite2D).position = p["pos"]


func _nadar(delta: float) -> void:
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
		# REBOTE contra la orilla de verdad. Antes era un clamp a los lados del rectangulo con un
		# margen de MEDIO LARGO en los dos ejes -- isotropo porque el pez esta GIRADO y en diagonal
		# su morro ocupa en vertical casi tanto como su largo.
		#
		# Ahora se prueban las DOS PUNTAS del pez contra el agua, que es la pregunta que aquel margen
		# aproximaba. Sale mejor y no solo compatible: la anguila puede acercarse de verdad a la
		# orilla en vez de nadar dentro de un rectangulo encogido medio metro por su propio largo.
		if not _cabe(pos, p["vel"], float(p["largo"])):
			# El paso se CANCELA en vez de recortarse: recortando, un pez podia quedarse con el morro
			# metido en tierra hasta que el rumbo nuevo lo sacara.
			var v: Vector2 = p["vel"]
			var paso: float = float(p["largo"]) * 0.5 + 2.0
			var seco_x: bool = not hay_agua((p["pos"] as Vector2) + Vector2(signf(v.x) * paso, 0.0))
			var seco_y: bool = not hay_agua((p["pos"] as Vector2) + Vector2(0.0, signf(v.y) * paso))
			# Si no da seco por ninguno de los dos (una cala en diagonal), se invierten los dos: dar
			# media vuelta siempre saca de donde se ha entrado.
			if not seco_x and not seco_y:
				seco_x = true
				seco_y = true
			p["vel"] = Vector2(-v.x if seco_x else v.x, -v.y if seco_y else v.y)
			pos = p["pos"]
			# Ultimo recurso: si ya estaba en seco (una celda que se ha quedado aislada), se le
			# empuja al corazon del lago en vez de dejarlo temblando contra la pared.
			if not hay_agua(pos):
				pos = pos.move_toward(_centro_agua, maxf(1.0, (p["vel"] as Vector2).length() * delta))
		p["pos"] = pos
		# El cuerpo se orienta con el rumbo: asi la anguila se lee como anguila al cruzar el charco.
		var spr: Sprite2D = p["spr"]
		spr.rotation = (p["vel"] as Vector2).angle()
		# EL COLETEO VA CON LA VELOCIDAD. Es una linea y es la mitad de la sensacion de vida: el pez
		# que huye del corcho bate deprisa y el que deambula va suave. A cadencia fija los cinco
		# baten igual y se nota que es un bucle.
		p["aleteo"] = fmod(float(p["aleteo"]) + delta * (p["vel"] as Vector2).length() * ALETEO_POR_PX,
			float(PezSprites.FRAMES))
		spr.region_rect = _region_pez(p["data"], int(p["talla"]), int(p["aleteo"]))
		spr.modulate = _tono_pez(p)
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
	return not _pez.is_empty() and p["spr"] == _pez["spr"]


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
	# Al CENTRO DEL AGUA y no al origen local (que es el centro del rectangulo): con forma organica
	# ese punto puede caer en una cala seca, y la apertura de la mira se abriria centrada en tierra.
	_ang_base = (_centro_agua - _origen_hilo()).angle()
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
		# CON EL DEDO SE APUNTA AL SITIO: tocas el trozo de agua al que quieres tirar y la caña mira
		# ahi. Antes esto mapeaba la MITAD IZQUIERDA/DERECHA de la pantalla a los dos extremos de la
		# apertura, que no se parece a nada: tocabas a la izquierda y la mira se iba a un sitio que no
		# tenia que ver con tu dedo, y ademas el mismo toque ya cargaba la fuerza.
		var destino: Vector2 = _mundo_desde_pantalla(_pad.pos_ultima())
		if destino != Vector2.INF:
			var nuevo_t: float = (to_local(destino) - _origen_hilo()).angle()
			# Se recorta a la apertura en vez de descartarse: si tocas detras de ti, la caña se va al
			# extremo de lo que puede y se queda ahi. Descartarlo dejaria la mira quieta sin decir por
			# que, que desde el movil se lee como que el toque no ha entrado.
			var fuera: float = angle_difference(_ang_base, nuevo_t)
			nuevo_t = _ang_base + clampf(fuera, -ANGULO_MAX, ANGULO_MAX)
			if _tramo_de_agua(nuevo_t).x >= 0.0:
				_ang = nuevo_t
	else:
		# LA MIRA VA HACIA DONDE PULSAS, se ponga uno donde se ponga. Antes A/D sumaban y restaban al
		# angulo a pelo, y eso solo se lee bien desde UN lado del charco: plantado al norte, la mira
		# apunta hacia abajo, y sumarle angulo la lleva hacia la IZQUIERDA de la pantalla. O sea que
		# la D movia a la izquierda. Desde el sur iba bien. Un control que se invierte segun por donde
		# llegues es imposible de aprender, porque no hay nada que aprender.
		#
		# Ahora las cuatro teclas son una DIRECCION EN PANTALLA y se proyecta sobre la tangente de la
		# mira (hacia donde se mueve el punto de caida cuando el angulo crece). Sale solo:
		#   - de pie al norte, la mira va hacia abajo -> su tangente es horizontal -> mandan A y D;
		#   - de pie al este, la mira va hacia la izquierda -> la tangente es vertical -> mandan W y S.
		# Y el signo siempre cuadra, porque es el que dice el producto escalar y no una tabla de casos
		# con sus cuatro cuadrantes y sus costuras en las diagonales.
		#
		# La tecla que apunta A LO LARGO de la mira (W estando al norte) da escalar ~0 y no hace nada,
		# que es lo correcto: acercar o alejar el corcho no es el angulo, es el medidor de fuerza.
		var dir := Vector2(
			Input.get_axis(&"move_left", &"move_right"),
			Input.get_axis(&"move_up", &"move_down"))
		if dir != Vector2.ZERO:
			# LA TANGENTE: hacia donde se desplaza el punto de caida cuando el angulo CRECE. El escalar
			# de tu direccion contra ella ES el sentido del giro, con su fuerza.
			#
			# OJO CON EL SIGNO: Vector2.orthogonal() devuelve (y, -x), que gira -90°, y el angulo al
			# crecer gira +90° (la Y va hacia abajo). O sea que la tangente es orthogonal() CAMBIADA DE
			# SIGNO. Sin este menos las cuatro teclas salen invertidas -- exactamente el bug que se
			# venia a arreglar, pero ahora en los cuatro lados en vez de en dos.
			var giro: float = dir.normalized().dot(-Vector2.from_angle(_ang).orthogonal())
			if not is_zero_approx(giro):
				var nuevo: float = _ang + giro * GIRO_MIRA * delta
				if absf(angle_difference(_ang_base, nuevo)) <= ANGULO_MAX \
						and _tramo_de_agua(nuevo).x >= 0.0:
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
		_caducar_candados()
		_mordidas_remotas()
		_t_red += delta
		if _t_red >= RED_TICK:
			_t_red = 0.0
			Net.difundir_charco(estado_red())
	else:
		_interpolar_peces(delta)
	# EL CORCHO SE PUBLICA SIEMPRE, tambien si el piso es mio: es lo que los demas pintan para verme
	# pescar (ver Net.publicar_corcho). Y los sedales ajenos se repintan siempre, este yo pescando o
	# no: ver a tu compañero con la caña echada desde la orilla es medio motivo de que esto exista.
	_publicar_mi_corcho(delta)
	_pintar_sedales(delta)
	# QUE HACE EL DEDO depende de la fase, y las fases cambian desde media docena de sitios (lanzar,
	# picar, recoger, volver a la mira tras cobrar un pez). Se refresca aqui, que es el unico punto
	# por el que pasan todas: engancharlo a cada transicion es la clase de lista a la que se le
	# escapa una, y la que se escape deja el dedo apuntando cuando tendria que estar peleando.
	_refrescar_tactil()
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
		# POR NONCE, no por indice. El indice es una posicion en un array que en el dueño cambia
		# entre la foto y esta respuesta (un pez que sale, otro que nace), asi que llegaba apuntando
		# a otro pez -o a ninguno- y el cobro se caia en silencio: la pieza se quedaba en el agua y
		# en el banco. Eso es lo que hacia que los peces del invitado "se auto-sustituyeran". El nonce
		# es la identidad del animal y no baila (ver _nacer_pez).
		Net.resolver_pesca(int(_pez.get("nonce", 0)), pescado)
		_pez = {}
		_idx_enganchado = -1
		_espero_mordida = false
		return
	if i >= 0:
		(_peces[i]["spr"] as Sprite2D).queue_free()
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
	_vuelven.append(Game.reloj_mundo() + STOCK_REGEN)
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
	# Al CENTRO DEL AGUA y no al origen local (que es el centro del rectangulo): con forma organica
	# ese punto puede caer en una cala seca, y la apertura de la mira se abriria centrada en tierra.
	_ang_base = (_centro_agua - _origen_hilo()).angle()
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
# El boton de LANZAR (solo se ve apuntando; ver _refrescar_tactil). Se mantiene pulsado para cargar
# la fuerza, igual que el ESPACIO en el teclado.
var _boton_lanzar: Button = null


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
	# LANZAR ES SU PROPIO BOTON, Y SE MANTIENE. Antes apuntar y cargar eran el MISMO dedo: tocabas
	# para elegir a donde tirar y con ese mismo toque ya se estaba llenando el medidor, asi que no
	# habia forma de corregir la punteria sin lanzar. Ahora son dos decisiones seguidas, que es como
	# se lanza una caña: primero eliges el sitio, luego cargas.
	#
	# Va con button_down/button_up y no con 'pressed' porque la fuerza ES el rato que aguantas: el
	# minijuego lee la accion "recolectar" con is_action_pressed, asi que se pulsa y se suelta a mano.
	_boton_lanzar = _pad.anadir_boton("Lanzar", Color(0.22, 0.38, 0.26))
	_boton_lanzar.button_down.connect(func(): Tactil.pulsar(&"recolectar"))
	_boton_lanzar.button_up.connect(func(): Tactil.soltar(&"recolectar"))
	_pad.anadir_boton("Recoger", Color(0.20, 0.30, 0.42)).pressed.connect(_recoger_sedal)
	_pad.anadir_boton("Salir", Color(0.42, 0.20, 0.22)).pressed.connect(_guardar_cana)
	_refrescar_tactil()


# QUE HACE EL DEDO EN CADA FASE. Apuntando, el toque elige el SITIO y no toca la accion (de cargar
# se encarga el boton Lanzar). En cuanto el sedal esta en el agua se vuelve al modo de siempre, que
# es lo que la lucha necesita: ahi mantener la pantalla ES la mecanica.
func _refrescar_tactil() -> void:
	if _pad == null:
		return
	var apuntando: bool = _estado == APUNTANDO
	_pad.modo_apuntar(apuntando)
	if is_instance_valid(_boton_lanzar):
		_boton_lanzar.visible = apuntando


func _quitar_tactil() -> void:
	_pad = null
	# El boton de Lanzar pulsa la accion a mano (button_down) y la suelta en button_up: si el pad se
	# va con el dedo encima, ese button_up no llega nunca y la accion se queda pulsada para siempre.
	# El jugador saldria al mapa dando espadazos solo. Es la misma red que TouchPad._exit_tree.
	if is_instance_valid(_boton_lanzar) and _boton_lanzar.button_pressed:
		Tactil.soltar(&"recolectar")
	_boton_lanzar = null
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
		_pez["pos"] = aqui
		_colocar(_pez)
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
# De pixeles de PANTALLA a coordenadas del MUNDO. El pad vive en un CanvasLayer, asi que sus toques
# vienen en coordenadas de pantalla y hay que deshacer la camara para saber a que trozo de agua
# apuntan. Vector2.INF si no hay nada que tocar todavia (o no hay viewport).
func _mundo_desde_pantalla(pos: Vector2) -> Vector2:
	if pos == Vector2.INF:
		return Vector2.INF
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2.INF
	return vp.get_canvas_transform().affine_inverse() * pos


func _origen_hilo() -> Vector2:
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador == null:
		return Vector2.ZERO
	return to_local(jugador.global_position) + Vector2(0.0, -10.0)


# EL TRAMO DE AGUA que atraviesa un tiro en ese angulo: (t de entrada, t de salida) en px desde la
# punta de la caña. Devuelve (-1, -1) si ese angulo NO corta la balsa.
#
# Era la interseccion rayo-RECTANGULO por slabs. Ahora el agua tiene forma, asi que se recorre el
# rayo a pasos cortos preguntandole a hay_agua(). Sigue siendo la pieza de la que cuelga todo el
# lanzamiento: como el punto se elige DENTRO del tramo, el corcho no puede caer fuera del agua por
# construccion, sin ningun clamp que falsee la mira.
#
# SE DEVUELVE EL PRIMER TRAMO CONTIGUO, no de la primera a la ultima gota de agua del rayo. Es lo
# que hace falta ahora que hay calas: si un tiro roza una lengua de tierra y vuelve a entrar al agua
# por detras, con el tramo entero la barra llena mandaria el corcho al otro lado de la tierra.
const MARCHA_PASO := 3.0
const MARCHA_MAX := 900.0

func _tramo_de_agua(ang: float) -> Vector2:
	var ini: Vector2 = _origen_hilo()
	var dir: Vector2 = Vector2.from_angle(ang)
	var t: float = 0.0
	var entra: float = -1.0
	while t <= MARCHA_MAX:
		if hay_agua(ini + dir * t):
			if entra < 0.0:
				entra = t
		elif entra >= 0.0:
			break         # se acabo el primer tramo: lo de mas alla ya no es este charco
		t += MARCHA_PASO
	if entra < 0.0:
		return Vector2(-1.0, -1.0)
	var sale: float = minf(t, MARCHA_MAX)
	# Encogido por los dos extremos para que el corcho no quede pegado al canto de la baldosa, que es
	# lo que hacia MIRA_MARGEN cuando esto era un rectangulo.
	entra += MIRA_MARGEN
	sale -= MIRA_MARGEN
	if sale <= entra:
		return Vector2(-1.0, -1.0)
	return Vector2(entra, sale)


# DONDE CAE EL CORCHO con la fuerza cargada ahora mismo. Fuerza 0 cae justo pasada la orilla (ver
# TIRO_MIN), media barra a MEDIA TRAVESIA del charco y la barra llena casi en el borde de enfrente.
func _punto_de_tiro(ang: float) -> Vector2:
	var tramo: Vector2 = _tramo_de_agua(ang)
	if tramo.x < 0.0:
		# Angulo imposible: al centro del agua. Y `_centro_agua` y no Vector2.ZERO, porque el origen
		# local es el centro del RECTANGULO y con forma organica ese punto puede caer en una cala
		# seca -- el corcho aterrizaria en tierra sin que nadie se quejara.
		return _centro_agua
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
# El sedal de OTRO: mas apagado que el tuyo, para que de un vistazo sepas cual es el tuyo.
const COLOR_HILO_AJENO := Color(0.75, 0.72, 0.60, 0.55)
const CABECEO_VEL := 14.0    # rad/s del corcho ajeno cuando a ese le ha picado
const CABECEO_ALTO := 2.5    # px de sube-y-baja

# Los sedales de los demas pescadores: peer -> {hilo, corcho, pos}. Ver corcho_de.
var _sedales: Dictionary = {}
var _t_cabeceo: float = 0.0


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
		p["de_t"] = Game.reloj_mundo()   # cuando se le reservo (ver _caducar_candados)
		c["activo"] = false   # ya tiene pieza: su corcho deja de pescar hasta que resuelva
		Net.avisar_mordida(peer, int(p.get("nonce", 0)))


# ESPEJO: le mando al dueño donde tengo el corcho, y solo mientras de verdad este pescando. Fuera de
# ESPERA no hay nada que pescar (o ya tengo pieza), y mandarlo igual haria que me picase un pez
# mientras peleo con otro.
#
# SOLO CUANDO CAMBIA (mas un latido de seguridad): esto corre en CADA frame del espejo, y el corcho
# no se mueve mientras esperas —solo cabecea, y eso es pintura, no _corcho_base—. Mandarlo 60 veces
# por segundo era un RPC por frame para repetir el mismo Vector2. El latido esta porque el transporte
# es unreliable: si se pierde el unico paquete del cambio, el dueño no sabria que estoy pescando.
func _publicar_mi_corcho(delta: float) -> void:
	var pescando: bool = _estado == ESPERA and _pez.is_empty() and not _espero_mordida
	# NI PESCO NI PESCABA: no hay nada que contar. Sin esto, ahora que esto corre tambien para el dueño
	# y con la pesca cerrada, cada charco del piso mandaria un "no estoy pescando" cada CORCHO_LATIDO
	# para siempre.
	if not pescando and not _corcho_ultimo_activo:
		return
	_t_corcho -= delta
	if pescando == _corcho_ultimo_activo and _corcho_base.distance_to(_corcho_ultimo_pos) < 1.0 \
			and _t_corcho > 0.0:
		return
	_t_corcho = CORCHO_LATIDO
	_corcho_ultimo_activo = pescando
	_corcho_ultimo_pos = _corcho_base
	Net.publicar_corcho(_corcho_base, pescando)


# LA PUERTA UNICA del corcho de otro. Dos cosas distintas y no hay que confundirlas:
#   - PINTARLO lo hace todo el mundo (asi se ve quien esta pescando y donde tiene el corcho).
#   - DECIDIR con el (mordidas) solo el dueño del piso, ahi abajo en corcho_remoto.
# Y el mio no cuenta por ninguna de las dos: ese lo pinta el sedal de siempre y sus mordidas las
# resuelve _paso_espera.
func corcho_de(peer: int, pos: Vector2, activo: bool) -> void:
	if peer == Net.mi_peer():
		return
	_corcho_visual(peer, pos, activo)
	corcho_remoto(peer, pos, activo)


# EL SEDAL DE OTRO: su hilo y su corcho en el agua. Se guarda la posicion y se repinta cada frame en
# _pintar_sedales, porque el ORIGEN (su cuerpo) se mueve aunque el corcho no.
func _corcho_visual(peer: int, pos: Vector2, activo: bool) -> void:
	if not activo:
		var viejo: Dictionary = _sedales.get(peer, {})
		if not viejo.is_empty():
			(viejo["hilo"] as Node).queue_free()
			(viejo["corcho"] as Node).queue_free()
			_sedales.erase(peer)
		return
	if not _sedales.has(peer):
		var hilo := Line2D.new()
		hilo.width = 1.0
		hilo.default_color = COLOR_HILO_AJENO
		add_child(hilo)
		var corcho := ColorRect.new()
		corcho.size = Vector2(5.0, 5.0)
		corcho.color = COLOR_HILO_AJENO
		corcho.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(corcho)
		_sedales[peer] = {"hilo": hilo, "corcho": corcho, "pos": pos}
	_sedales[peer]["pos"] = pos


# Repinta los sedales ajenos. El arco del hilo es el MISMO de _pintar_hilo (misma parabola de tres
# puntos), solo que colgando de SU cuerpo en vez del mio.
#
# Y el corcho CABECEA cuando ese pescador tiene un pez enganchado -- se sabe sin mandar nada nuevo:
# el 'de' de cada pez ya viaja en la foto del charco y es su peer id. Ese cabeceo es todo el aviso
# visual de "a tu compañero le ha picado".
func _pintar_sedales(delta: float) -> void:
	if _sedales.is_empty():
		return
	_t_cabeceo += delta
	for peer in _sedales:
		var s: Dictionary = _sedales[peer]
		var cuerpo = Net.cuerpo_de(peer)
		var hilo: Line2D = s["hilo"]
		var corcho: ColorRect = s["corcho"]
		if cuerpo == null:
			hilo.visible = false
			corcho.visible = false
			continue
		hilo.visible = true
		corcho.visible = true
		var fin: Vector2 = s["pos"]
		if _tiene_pieza(peer):
			fin += Vector2(0.0, sin(_t_cabeceo * CABECEO_VEL) * CABECEO_ALTO)
		var ini: Vector2 = to_local(cuerpo.global_position) + Vector2(0.0, -10.0)
		var alto: Vector2 = (ini + fin) * 0.5 + Vector2(0.0, -ARCO_ALTO)
		var pts := PackedVector2Array()
		for i in range(9):
			var u: float = float(i) / 8.0
			pts.append(ini.lerp(alto, u).lerp(alto.lerp(fin, u), u))
		hilo.points = pts
		corcho.position = fin - corcho.size * 0.5


# ¿Ese pescador tiene un pez enganchado? El 'de' de cada pez es su peer id y viaja en la foto, asi
# que esto vale igual en el dueño y en un espejo.
func _tiene_pieza(peer: int) -> bool:
	for p in _peces:
		if int(p.get("de", 0)) == peer:
			return true
	return false


# DUEÑO: llega el corcho de un pescador remoto (o el aviso de que lo ha recogido).
#
# ⚠️ UN CORCHO INACTIVO NO SUELTA SUS PECES, y esto era EL bug de la pesca en multi. La secuencia:
# le reservo el pez y le aviso -> en su maquina entra en PICANDO -> al frame siguiente su corcho ya
# no esta "pescando" (correcto: no puede enganchar un segundo pez mientras pelea con este) y publica
# activo=false -> y aqui se le soltaba el candado del pez que acababa de morder. A partir de ahi el
# pez volvia a nadar en el dueño (por eso no se quedaba quieto en la caña), se lo podia enganchar
# otro a la vez, y al cobrarlo resolver_pez_remoto lo rechazaba por 'de != peer': la pieza no salia
# nunca del agua ni del banco, o sea el "se auto-sustituyen por ellos mismos".
#
# Soltar el candado es cosa de resolver_pez_remoto (acabo la pelea), de soltar_todo_de (se fue o se
# desconecto) y del caducado de abajo (red de seguridad).
func corcho_remoto(peer: int, pos: Vector2, activo: bool) -> void:
	if not _soy_dueno():
		return
	if not activo and not _corchos.has(peer):
		return
	if not _corchos.has(peer):
		_corchos[peer] = {}
	_corchos[peer]["pos"] = pos
	_corchos[peer]["activo"] = activo


# DUEÑO: red de seguridad de los candados. Un pez reservado a alguien que nunca contesta -su juego se
# cerro a mitad de la pelea, o se perdio el aviso- se quedaria bloqueado para siempre: sin nadar,
# sin poder pescarlo nadie y ocupando sitio en el aforo. Es el hermano de la reserva de bichos.
const CANDADO_MAX := 180.0   # segundos de reloj; una pelea con un pez dura unos pocos


func _caducar_candados() -> void:
	for p in _peces:
		if int(p.get("de", 0)) == 0:
			continue
		if Game.reloj_mundo() - float(p.get("de_t", 0.0)) > CANDADO_MAX:
			p["de"] = 0


# ESPEJO: el dueño me dice que me ha picado el pez 'idx'. A partir de aqui el minijuego es MIO y va
# en local (el picoteo, el tiron y la barra de tension): lo unico que el dueño necesita saber es como
# acaba, y eso se lo digo en Net.resolver_pesca.
#
# Llega el NONCE del pez, no su indice: el indice del dueño y el mio no tienen por que coincidir (una
# fila que no se pudo reconstruir en aplicar_red desalinea el array entero), y el nonce es la
# identidad del animal en las dos maquinas.
func me_ha_picado(nonce: int) -> void:
	if _soy_dueno() or _estado != ESPERA:
		return
	var idx: int = _idx_por_nonce(nonce)
	if idx < 0:
		return
	_idx_enganchado = idx
	_espero_mordida = false
	_morder(_peces[idx])


func _idx_por_nonce(nonce: int) -> int:
	for i in _peces.size():
		if int(_peces[i].get("nonce", 0)) == nonce:
			return i
	return -1


# DUEÑO: un pescador remoto ha terminado con su pez. Es el unico sitio donde el banco baja por culpa
# de otro, y por eso pasa por aqui y no por _quitar_pez: el que cobra es EL, con su charco espejado;
# aqui solo se apunta el resultado en el banco de verdad.
# Cruza por NONCE (ver _quitar_pez): por indice llegaba apuntando a otro pez en cuanto el array del
# dueño hubiera cambiado entre la foto y la respuesta, y el cobro se perdia sin decir nada.
func resolver_pez_remoto(peer: int, nonce: int, cobrado: bool) -> void:
	if not _soy_dueno():
		return
	var idx: int = _idx_por_nonce(nonce)
	if idx < 0:
		_soltar_peces_de(peer)   # ese pez ya no esta: al menos que no se quede ningun candado suyo
		return
	var p: Dictionary = _peces[idx]
	if int(p.get("de", 0)) != peer:
		return   # no era suyo: llega tarde (ya se lo solto la desconexion o el caducado)
	p["de"] = 0
	if not cobrado:
		return
	# Se lo lleva: fuera del agua y fuera del banco, con su sello de diez minutos.
	(p["spr"] as Sprite2D).queue_free()
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
		p["pos"] = f[1]
		(p["spr"] as Sprite2D).modulate = _tono_pez(p)
		nuevos.append(p)
		destinos.append([f[1], f[2]])

	# Lo que ya no viene en la foto se ha ido del agua (lo pesco alguien, o se retiro).
	for sobra in mios.values():
		if _pez_es(sobra):
			_pez = {}   # me lo han quitado de debajo: suelto la referencia antes de liberarlo
		(sobra["spr"] as Sprite2D).queue_free()
	_peces = nuevos
	_destinos = destinos
	_idx_enganchado = _peces.find(_pez) if not _pez.is_empty() else -1


# ESPEJO: crea el rectangulo de un pez que aun no tenia. La especie y la talla NO viajan: salen del
# mismo sorteo sembrado que uso el dueño (semilla del piso + epoca + celda + nonce), asi que las dos
# maquinas sacan exactamente el mismo bicho sin gastar un byte en ello.
#
# LA FORMULA TIENE QUE SER LA MISMA QUE LA DE _rng_pez, letra por letra. Si se le añade algo alli y
# aqui no, el invitado ve otra especie y otra talla en el mismo pez y no da ni un error.
func _nacer_pez_espejo(nonce: int, pos: Vector2) -> Dictionary:
	if tabla == null:
		return {}
	var r := RandomNumberGenerator.new()
	r.seed = hash([_semilla(), Game.epoca_actual(), celda.x, celda.y, nonce])
	var d: MaterialData = tabla.elegir(Game.current_floor, r)
	if d == null:
		return {}
	var cm: float = d.talla_desde(MaterialData.tirada_talla(r))
	var tam_agua: Vector2 = tam_px()
	var largo: float = clampf(cm * PX_POR_CM, LARGO_MIN,
		minf(tam_agua.x, tam_agua.y) * LARGO_MAX_FRAC)
	var alto: float = maxf(2.0, largo / maxf(1.2, d.esbeltez))
	# EL MISMO constructor que usa el dueño: es lo que garantiza que el invitado vea el mismo bicho.
	var spr: Sprite2D = _crear_sprite_pez(d, largo)
	var p: Dictionary = {
		"spr": spr, "data": d, "cm": cm, "largo": largo, "alto": alto,
		"talla": PezSprites.talla_de(largo), "aleteo": 0.0,
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
		# EL QUE TENGO ENGANCHADO NO. Ese lo lleva el minijuego (esta clavado en la punta del sedal),
		# y perseguir su destino de la foto era lo que le hacia pasearse por el charco mientras
		# forcejeabas con el. Con el candado arreglado el dueño ya no lo mueve, pero la ultima foto
		# antes de la mordida sigue de camino: esto lo remata.
		if _pez_es(p):
			continue
		var destino: Vector2 = _destinos[i][0]
		p["pos"] = (p["pos"] as Vector2).lerp(destino, t)
		var spr: Sprite2D = p["spr"]
		spr.rotation = lerp_angle(spr.rotation, float(_destinos[i][1]), t)
		# El espejo NO simula, pero el coleteo si es suyo: bate por su cuenta a la velocidad a la
		# que le ve moverse. Sin esto los peces del invitado se deslizarian tiesos.
		p["aleteo"] = fmod(float(p["aleteo"]) + delta * (destino - (p["pos"] as Vector2)).length()
			* SUAVIZADO_RED * ALETEO_POR_PX, float(PezSprites.FRAMES))
		spr.region_rect = _region_pez(p["data"], int(p["talla"]), int(p["aleteo"]))
		_colocar(p)
