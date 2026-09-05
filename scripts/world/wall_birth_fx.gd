# ============================================================
#  wall_birth_fx.gd
#  El AVISO de la pared: antes de parir, la celda de roca late y tiembla. Es la unica
#  advertencia que tienes -por eso existe: un bicho que aparece de la nada, sin aviso,
#  es una emboscada barata; con aviso, decides si te quedas o te largas.
#  Cuanto mas gordo es el parto (un brote), mas fuerte tiembla y mas se avisa.
#  Aspecto placeholder por codigo; el arte va al final.
# ============================================================

extends Node2D

var _rects: Array[ColorRect] = []
var _dur: float = 1.2      # cuanto dura el aviso
var _t: float = 0.0        # tiempo transcurrido
var _amp: float = 2.5      # amplitud del temblor (px)
var _origen: Vector2 = Vector2.ZERO
var _color: Color = Color(0.85, 0.35, 0.30)
# > 0 = me borro solo a los tantos segundos (solo los avisos REPLICADOS; ver borrarse_al_acabar).
var _auto_borrar: float = 0.0

# --- LA PIEDRA PRESTADA (camino de iniciar_capa) ---
# Las celdas se MUDAN del TileMapLayer del piso a uno propio -este nodo-, que es el que se agita, y
# al terminar vuelven a su sitio tal cual estaban. Antes esto era un ColorRect de color plano encima
# y cantaba: la mazmorra ya tiene su arte, y se veia un rectangulo de otro juego pegado a la pared.
#
# LA COLISION NO SE TOCA. La pared no se abre de verdad -el bicho nace en la celda de SUELO de al
# lado, ver SpawnZone._abrir_pared-, asi que esto es puramente visual: ni la roca deja de chocar, ni
# la navegacion cambia, ni la oscuridad se entera. Es lo que permite pintar y despintar sin miedo.
var _piso: Node = null                # quien lleva el registro de celdas en obras
var _capa: TileMapLayer = null        # de donde salieron las celdas y adonde vuelven
var _celdas: Array[Vector2i] = []
var _guardadas: Array = []            # para devolverlas IGUAL que estaban
var _mio: TileMapLayer = null         # mi copia: la que tiembla
# ¿Lo que revienta es MURO o SUELO? El jefe no sale de una pared, sale del suelo de su sala, y las
# dos cosas no se ven igual desde 45 grados (ver _caras_de).
var _es_muro: bool = true

# EL HALO: las celdas de al lado, que tiemblan MENOS. Sin esto se ve un bloque suelto moviendose
# dentro de una pared quieta, con una costura dura en el borde -y eso no se lee como piedra a punto
# de reventar, se lee como un fallo de dibujo. Tembando un poco tambien lo de alrededor, el
# movimiento se reparte y el ojo lo acepta: la pared entera se resiente, mas fuerte en el centro.
const HALO_FUERZA := 0.35     # cuanto del temblor les llega
# Lo que se multiplica la amplitud cuando lo que tiembla es la PIEDRA (ver _process).
const AMP_PIEDRA := 1.25
var _halo: TileMapLayer = null
var _celdas_halo: Array[Vector2i] = []
var _guardadas_halo: Array = []

# LAS GRIETAS. Desde que el aviso dejo de teñir la roca de rojo, son -con el temblor- lo que avisa
# de que ahi va a salir algo: van rajando la pared segun se acerca el parto.
const _CRACK := preload("res://scripts/world/wall_crack_fx.gd")
var _grietas: Node2D = null
# A partir de que punto del aviso empiezan a verse. Antes no: el primer tercio es solo temblor, y
# que la piedra se raje DESPUES de empezar a moverse es lo que cuenta la historia en el orden bueno.
const GRIETAS_DESDE := 0.3

# --- LO QUE TARDA LA PIEDRA EN REHACERSE ---
# Pedido asi: "30 segundos o asi", y que lo gordo tarde mas. Un corro de veinticinco celdas no se
# puede cerrar en lo mismo que una piedra suelta. Hay tope para que un brote enorme no deje la sala
# en obras media partida.
const REPARAR_BASE := 30.0        # una celda suelta: medio minuto
const REPARAR_POR_CELDA := 1.2    # cada celda de mas
const REPARAR_TOPE := 75.0
# En que parte de la reparacion se han cerrado ya todas las grietas. Poco mas de la mitad: para
# entonces solo queda el boquete, que es la herida gorda.
const GRIETAS_CURAN := 0.55
# Lo que tarda el boquete en ABRIRSE del todo, en segundos. Corto: es una rotura, no una animacion.
const ABRIR_DUR := 0.22

enum Fase { AVISO, ROTA }
var _fase: int = Fase.AVISO
var _t_rota: float = 0.0
var _t_abre: float = 0.0
var _dur_rota: float = REPARAR_BASE


# UN parto normal: una sola celda. lado = tamaño de celda; dur = aviso; amp = temblor.
func iniciar(lado: float, dur: float, amp: float, color: Color) -> void:
	iniciar_tramo(lado, dur, amp, color, [position])


# EL CAMINO BUENO: hacer temblar la piedra DE VERDAD. 'capa' es el TileMapLayer de donde salen las
# celdas (el muro en un brote, el suelo en el parto del jefe) y 'celdas' las de rejilla.
#
# Devuelve false si no ha podido (no hay capa, o ninguna de esas celdas tiene nada pintado). Quien
# llama se cae entonces al camino de siempre (iniciar_tramo, el rectangulo de color): un aviso feo
# es muchisimo mejor que ningun aviso, porque sin el los bichos salen de la nada.
func iniciar_capa(piso: Node, capa: TileMapLayer, celdas: Array, lado: float, dur: float,
		amp: float, color: Color, es_muro: bool = true) -> bool:
	if capa == null or not is_instance_valid(capa) or celdas.is_empty():
		return false
	# PRIMERO se apunta todo y SOLO DESPUES se borra nada: si a mitad del reparto apareciera una
	# celda vacia, hay que poder irse sin haber tocado ni una del piso.
	var buenas: Array[Vector2i] = []
	var datos: Array = []
	for c in celdas:
		var cel: Vector2i = c as Vector2i
		var src: int = capa.get_cell_source_id(cel)
		if src < 0:
			continue   # ahi no hay nada pintado: esa celda no es mia
		buenas.append(cel)
		datos.append({"src": src, "atlas": capa.get_cell_atlas_coords(cel),
			"alt": capa.get_cell_alternative_tile(cel)})
	if buenas.is_empty():
		return false

	_piso = piso
	_capa = capa
	_es_muro = es_muro
	_celdas = buenas
	_guardadas = datos
	_dur = maxf(0.05, dur)
	_amp = amp
	_color = color
	_origen = position

	# Mi copia: el MISMO TileSet, asi que sale con el arte del tramo que toque sin tener que saber
	# cual es.
	_mio = TileMapLayer.new()
	_mio.tile_set = capa.tile_set
	_mio.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_mio)
	for i in _celdas.size():
		var d: Dictionary = _guardadas[i]
		_mio.set_cell(_celdas[i], int(d["src"]), d["atlas"], int(d["alt"]))
		# LA ORIGINAL SE QUEDA DEBAJO, QUIETA. Se probo a borrarla -- la copia era la unica piedra -- y
		# al temblar dejaba JUNTAS NEGRAS por donde se veia el fondo: se leia como bloques sueltos
		# deslizandose, no como una pared vibrando. Dejandola, la copia se sacude ENCIMA de su propia
		# textura y no hay ni un hueco. Ademas hace todo esto mucho mas seguro: si el nodo muere de
		# mala manera, la pared ya estaba entera y no hay nada que restaurar.

	# Y EL HALO: las de al lado, en su propia copia para poder moverlas con menos fuerza.
	_halo = TileMapLayer.new()
	_halo.tile_set = capa.tile_set
	_halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_halo)
	for cel in _vecinas_de(buenas):
		var src2: int = _capa.get_cell_source_id(cel)
		if src2 < 0:
			continue
		_celdas_halo.append(cel)
		_guardadas_halo.append({"src": src2, "atlas": _capa.get_cell_atlas_coords(cel),
			"alt": _capa.get_cell_alternative_tile(cel)})
		_halo.set_cell(cel, src2, _capa.get_cell_atlas_coords(cel),
			_capa.get_cell_alternative_tile(cel))
		# Su original tambien se queda debajo, por lo mismo (ver arriba).
	# EL HALO NO SE REGISTRA COMO "EN OBRAS", y esto costo un rato de entender. Se registraba, y con
	# la reparacion durando medio minuto eso dejaba bloqueadas TODAS las celdas de alrededor: el
	# siguiente brote no podia extenderse por ellas y se quedaba en una sola celda -- "el brote parece
	# un parto de uno", que es exactamente lo que se veia.
	#
	# Y no hace falta: el registro existe para que dos efectos no se peleen por la misma celda, y el
	# halo ni siquiera la toma prestada de verdad (la original se queda debajo, quieta). Que una
	# vecina tiemble un poco no es motivo para vetarle un parto durante medio minuto.

	# LAS GRIETAS, que son lo que avisa junto con el temblor desde que se quito el brillo rojo. Salen
	# del centro de cada celda que va a reventar y van creciendo segun se acerca el parto.
	#
	# Cuelgan de MI NODO, asi que tiemblan con la piedra: una grieta quieta sobre una pared que se
	# sacude se despega y canta. Y van DESPUES de _mio en el orden de hijos, o sea por encima.
	_grietas = Node2D.new()
	_grietas.set_script(_CRACK)
	add_child(_grietas)
	var focos: Array = []
	for cel in _celdas:
		focos.append(Vector2(cel) * lado + Vector2(lado, lado) * 0.5)
	_grietas.preparar(focos, _zona_de_grietas(), lado, _semilla_grietas())
	_recolocar()
	return true


# POR DONDE PUEDE CORRER LA GRIETA. Todo lo que este PINTADO -- muro o suelo -- a GRIETA_ALCANCE
# celdas de las que revientan.
#
# Estuvo atada a las celdas que estallan y su halo, y era demasiado poco: una pared que revienta se
# raja tambien hacia el SUELO que tiene delante y hacia las paredes de al lado, que es justamente lo
# que se ve en las referencias. Lo unico que sigue estando prohibido es dibujar sobre el vacio, que
# ahi no hay nada que partir -- y el alcance evita que una grieta cruce media mazmorra.
const GRIETA_ALCANCE := 3

func _zona_de_grietas() -> Array:
	var out: Dictionary = {}
	for c in _celdas:
		for dy in range(-GRIETA_ALCANCE, GRIETA_ALCANCE + 1):
			for dx in range(-GRIETA_ALCANCE, GRIETA_ALCANCE + 1):
				var v: Vector2i = c + Vector2i(dx, dy)
				if out.has(v):
					continue
				if _piso != null and _piso.has_method("celda_pintada") and not _piso.celda_pintada(v):
					continue
				out[v] = true
	return out.keys()


# La semilla de las grietas. Sale de la PRIMERA CELDA del destrozo, que es un dato que las dos
# maquinas de una sesion tienen igual: asi el compañero ve exactamente la misma rotura sin que nadie
# mande un dibujo por red.
func _semilla_grietas() -> int:
	if _celdas.is_empty():
		return 0
	return hash(Vector2i(_celdas[0].x, _celdas[0].y))


# Las celdas pegadas a las que revientan y que TAMBIEN estan pintadas en esta capa. Se sacan de la
# capa y no del generador porque lo que se mueve tiene que ser lo que se ve: si ahi no hay baldosa,
# no hay nada que temblar. Las que ya tiene otro parto se dejan en paz.
func _vecinas_de(rotas: Array[Vector2i]) -> Array:
	var suyas: Dictionary = {}
	for c in rotas:
		suyas[c] = true
	var out: Dictionary = {}
	for c in rotas:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var v: Vector2i = c + d
			if suyas.has(v) or out.has(v):
				continue
			if _piso != null and _piso.has_method("celda_rota") and _piso.celda_rota(v):
				continue
			out[v] = true
	return out.keys()


# Mi copia pinta en coordenadas ABSOLUTAS de rejilla, asi que hay que descontarle donde estoy yo.
#
# CONTRA EL ORIGEN, NO CONTRA position, y en esa diferencia se va TODO EL TEMBLOR. Yo tiemblo
# moviendo position (origen + tembleque); si al hijo se le pone -position, su global queda en
# origen + tembleque - origen - tembleque = SIEMPRE LO MISMO: la piedra se queda clavada y lo unico
# que se mueve es mi nodo, que no pinta nada. Con -origen, el hijo queda en la rejilla mas el
# tembleque, que es lo que se queria.
#
# Estuvo mal escrito y no se vio en las medidas, porque lo que se midio fue MI position (que si se
# movia) y no la de la piedra. Se veia parpadear y no temblar.
func _recolocar() -> void:
	if _mio != null and is_instance_valid(_mio):
		_mio.position = -_origen
	# EL HALO se mueve MENOS: se le devuelve parte del tembleque para dejarlo a HALO_FUERZA. Mi
	# desplazamiento es (position - _origen), asi que restandole lo que sobra queda con su fraccion.
	if _halo != null and is_instance_valid(_halo):
		# Tambien a pixel entero, por lo mismo que el temblor de arriba: una fraccion aqui deja el
		# halo desalineado del muro que tiene al lado y se ve la costura.
		var suyo: Vector2 = (position - _origen) * HALO_FUERZA
		_halo.position = -position + Vector2(roundf(suyo.x), roundf(suyo.y))
	# Las grietas van pegadas a la piedra que se raja, asi que tiemblan LO MISMO que _mio: una grieta
	# quieta sobre una pared que se sacude se despega del muro y canta.
	if _grietas != null and is_instance_valid(_grietas):
		_grietas.position = -_origen


# UN BROTE: un TRAMO de pared (varias celdas) que late y tiembla EN BLOQUE. 'paredes' son los
# centros (en mundo) de cada celda de roca que se va a abrir. Todas comparten _t y _origen, asi que
# laten y tiemblan a la vez: se lee como que ese cacho de muro entero se va a caer, no como varios
# avisos sueltos. El nodo se coloca en la primera y las demas se pintan como hijos a su offset.
func iniciar_tramo(lado: float, dur: float, amp: float, color: Color, paredes: Array) -> void:
	_dur = maxf(0.05, dur)
	_amp = amp
	_color = color
	_origen = position
	for centro in paredes:
		var r := ColorRect.new()
		var local: Vector2 = (centro as Vector2) - position   # a coordenadas del nodo
		r.offset_left = local.x - lado * 0.5
		r.offset_top = local.y - lado * 0.5
		r.offset_right = local.x + lado * 0.5
		r.offset_bottom = local.y + lado * 0.5
		r.color = _color
		add_child(r)
		_rects.append(r)


# Que se borre solo al cumplirse el aviso. Lo usa el AVISO REPLICADO (ver
# DungeonFloor.pintar_aviso_pared): el que solo espeja el piso no tiene reloj de parto que lo quite,
# porque los bichos no nacen en su maquina. Los avisos propios NO usan esto: los borra SpawnZone al
# abrir la pared, que es cuando de verdad se convierten en bichos.
func borrarse_al_acabar(dur: float) -> void:
	_auto_borrar = maxf(0.05, dur)


# YA HAN SALIDO: la piedra se queda ROTA y empieza a cerrarse sola. Lo llama SpawnZone en vez del
# queue_free de antes, y DungeonFloor tras el parto del jefe.
#
# Si este aviso iba por el camino de respaldo (sin piedra prestada) no hay nada que agrietar y se
# borra, que es exactamente lo que hacia siempre hasta ahora.
func romper() -> void:
	if _capa == null or _fase == Fase.ROTA:
		queue_free()
		return
	_fase = Fase.ROTA
	_t_rota = 0.0
	_t_abre = 0.0
	_tapiar()
	_dur_rota = minf(REPARAR_TOPE,
		REPARAR_BASE + REPARAR_POR_CELDA * float(maxi(0, _celdas.size() - 1)))
	position = _origen        # deja de temblar: la piedra ya esta donde va a quedarse
	_recolocar()
	if _grietas != null and is_instance_valid(_grietas):
		_grietas.avance(1.0)   # la grieta, entera: por ahi es por donde ha reventado
		_grietas.romper(_celdas, _caras_de(_celdas), _semilla_grietas())
		_grietas.cerrar(0.0)   # y el hueco arranca CERRADO: lo abre _process_rota


# QUE CELDAS ENSEÑAN SU CARA A LA CAMARA. El juego se mira desde 45 grados: de una pared se ve la
# cara solo cuando tiene suelo POR DEBAJO (esa es la que te mira de frente). La de abajo de una sala
# se ve de canto, no tiene cara que agujerear, y un boquete pintado ahi se lee como una mancha tirada
# en el suelo -- por eso a esas solo les quedan las grietas.
#
# Se pregunta a la CAPA y no al generador: lo que se pinta tiene que casar con lo que se ve. Y si la
# capa es la del suelo (el parto del jefe), debajo tampoco hay muro, asi que sale cara para todas --
# que es lo correcto: un agujero en el suelo se ve entero desde arriba.
func _caras_de(celdas: Array[Vector2i]) -> Array:
	var out: Array = []
	for c in celdas:
		# EL SUELO SIEMPRE LLEVA AGUJERO. Se mira cenital, asi que un boquete en el suelo se ve entero
		# y no hay "cara" que valga. La comprobacion de abajo es SOLO para el muro -- y preguntandosela
		# al suelo salia que NO para todas (debajo de una celda de suelo hay otra celda de suelo), asi
		# que el jefe se quedaba sin boquete: solo grietas.
		if not _es_muro:
			out.append(true)
			continue
		out.append(_capa == null or _capa.get_cell_source_id(c + Vector2i.DOWN) < 0)
	return out


func _process(delta: float) -> void:
	if _fase == Fase.ROTA:
		_process_rota(delta)
		return
	if _capa == null and _rects.is_empty():
		return
	_t += delta
	if _auto_borrar > 0.0 and _t >= _auto_borrar:
		# El aviso REPLICADO se apaga solo. Si tiene piedra prestada pasa por la rotura como el propio
		# (romper() se encarga): el compañero tiene que ver el MISMO boquete que el que simula el piso,
		# y cerrarse igual. Sin piedra, romper() se limita a borrarse, como siempre.
		romper()
		return
	var p: float = clampf(_t / _dur, 0.0, 1.0)

	# Late cada vez mas rapido segun se acerca el parto (de ~2 a ~9 latidos/s).
	var freq: float = lerpf(2.0, 9.0, p)
	var latido: float = 0.5 + 0.5 * sin(_t * freq * TAU)
	if _capa != null:
		# LA PIEDRA NO SE TIÑE. El aviso es que la pared TIEMBLA y SE RAJA: un brillo rojo encima es
		# otra vez pintarle un color a la roca, que es de lo que se venia huyendo.
		#
		# El latido se queda, pero movido al TEMBLOR (ver abajo): la pared se sacude a tirones cada vez
		# mas seguidos en vez de parpadear de color.
		#
		# Y LA GRIETA CRECE, de nada a entera en lo que queda de aviso. Empieza pasado GRIETAS_DESDE
		# para que el orden sea el que cuenta la historia: primero se mueve, luego se raja, luego
		# revienta.
		if _grietas != null and is_instance_valid(_grietas):
			_grietas.avance(clampf((p - GRIETAS_DESDE) / (1.0 - GRIETAS_DESDE), 0.0, 1.0))
	else:
		# El camino de respaldo (sin piedra prestada) sigue con su rectangulo de color: ahi no hay
		# piedra que sacudir, y algo tiene que avisar.
		var col := Color(_color.r, _color.g, _color.b, lerpf(0.15, 0.9, latido * p))
		for r in _rects:
			r.color = col

	# TIEMBLA MAS FUERTE AL FINAL, y a TIRONES: la amplitud crece con 'p' y ademas la modula el
	# latido, que va acelerando. Asi la pared se sacude por rachas cada vez mas seguidas -- que es lo
	# que antes decia el parpadeo del color, dicho ahora con movimiento, que es lo que se queria.
	var amp: float = _amp * p * lerpf(0.35, 1.0, latido)
	# Sobre la piedra de verdad se tiembla MAS FUERTE. Las amplitudes de siempre (2,5 px el parto
	# suelto, 7,5 el brote) estaban puestas cuando el aviso lo daba un color que parpadeaba y el
	# temblor era el acompañamiento; ahora el temblor es LO UNICO que avisa y a 2 px no se ve. Va como
	# factor aparte y no tocando aviso_amp para no cambiarle la amplitud al camino de respaldo.
	if _capa != null:
		amp *= AMP_PIEDRA
	# A PIXELES ENTEROS. El juego es pixel art con filtro nearest: un desplazamiento de 3,7 px deja la
	# piedra a medio pixel de la rejilla, y entonces el tile se remuestrea y se ve borroso y bailando
	# -- justo el defecto que delata que algo no esta dibujado con el resto del arte. Redondeando, la
	# pared salta de pixel en pixel, que ademas es como tiembla el pixel art de verdad.
	position = _origen + Vector2(roundf(randf_range(-amp, amp)), roundf(randf_range(-amp, amp)))
	_recolocar()


# ============================================================
#  EL BOQUETE NO SE PUEDE CRUZAR (mientras esta abierto)
# ============================================================
# Un agujero por el que se pasa andando no es un agujero. Se le pone colision mientras dura y se le
# quita al cerrarse, celda a celda y EN EL MISMO ORDEN en que se repara: las de fuera vuelven a ser
# suelo antes que la del centro, igual que se ve.
#
# EL BORDE DEL AGUJERO ES PARED, sin mas. Va en la MISMA capa que la roca de la mazmorra (la 1), no
# en una suya, y eso no es un detalle: las antenas con las que los bichos esquivan muros lanzan sus
# rayos contra esa capa (Enemy.CAPA_ROCA). En una capa aparte el obstaculo existia para la fisica
# pero NO PARA LA IA -- el jefe chocaba contra algo que no sabia que estaba ahi y se quedaba
# empujando el borde sin entender por que no avanzaba. Siendo pared, lo rodea como rodea cualquier
# muro, y todo lo demas (jugador, companeros, bichos) lo trata igual sin una sola excepcion.
#
# ¿Y como sale el jefe, si nace dentro? Su salida es una ANIMACION con el proceso congelado (ver
# DungeonFloor._emerger): mueve la posicion directamente, asi que la colision no le frena. Sale
# trepando y, cuando recupera el control, ya esta fuera.
#
# Solo en el SUELO: en una pared el boquete cae sobre roca, que ya no se cruza.
const CAPA_BOQUETE := 1

var _tapias: Array = []   # [{cuerpo: StaticBody2D, r: float}] -- 'r' es cuando le toca cerrarse
# CUANTO del boquete corta el paso, en celdas desde su centro. Lo pone quien lo lanza a partir del
# TAMAÑO DEL JEFE (ver DungeonFloor._radio_solido_de): tapiarlo entero deja al bicho encajonado entre
# su propio agujero y la pared. -1 = no se tapia nada, que es lo que toca cuando el jefe es tan
# grande respecto a su corro que cualquier parte solida lo encerraria.
var solido_radio: int = 9999
var solido_centro := Vector2i.MAX

func _tapiar() -> void:
	if _es_muro or _capa == null:
		return   # una pared ya no se cruza; esto es solo para el suelo
	var lado: float = float(DungeonGenerator.CELDA)
	var caras: Array = _caras_de(_celdas)
	# El centro del destrozo, para saber que celdas son de fuera (se cierran antes) -- el mismo
	# criterio que usa el dibujo, para que lo que ves y lo que chocas vayan a la par.
	var centro := Vector2.ZERO
	for c in _celdas:
		centro += Vector2(c)
	centro /= maxf(1.0, float(_celdas.size()))
	var radio_max: float = 0.0
	for c in _celdas:
		radio_max = maxf(radio_max, Vector2(c).distance_to(centro))

	if solido_radio < 0:
		return   # este jefe no cabe rodeando: su agujero se queda en dibujo
	for i in _celdas.size():
		if i < caras.size() and not bool(caras[i]):
			continue   # sin agujero pintado, sin tapia
		var cel: Vector2i = _celdas[i]
		# SOLO EL CENTRO. Fuera de ese radio se pinta el agujero pero se puede pisar: es el anillo por
		# el que el jefe rodea su propio hoyo para llegar hasta ti.
		if solido_centro != Vector2i.MAX:
			var d2: Vector2i = cel - solido_centro
			if maxi(absi(d2.x), absi(d2.y)) > solido_radio:
				continue
		var cuerpo := StaticBody2D.new()
		cuerpo.collision_layer = CAPA_BOQUETE
		cuerpo.collision_mask = 0     # no vigila a nadie: solo esta para que choquen con el
		var forma := RectangleShape2D.new()
		# ALGO MAS PEQUEÑA QUE LA CELDA. El agujero pintado tampoco se la come entera (deja el marco
		# de piedra que lo sujeta), y una caja a celda completa te frenaba con el hoyo todavia a un
		# palmo -- se nota enseguida al rozarlo.
		forma.size = Vector2(lado, lado) * 0.86
		var col := CollisionShape2D.new()
		col.shape = forma
		cuerpo.add_child(col)
		cuerpo.global_position = Vector2(cel) * lado + Vector2(lado, lado) * 0.5
		# Del PADRE del piso, no de mi nodo: yo tiemblo, y una pared de colision que tiembla te
		# empuja. Ademas asi no le afecta mi escala ni mi posicion.
		var mundo: Node = get_parent()
		if mundo == null:
			mundo = self
		mundo.add_child(cuerpo)
		var d: float = 0.0 if radio_max <= 0.001 else Vector2(cel).distance_to(centro) / radio_max
		# Se quita cuando su celda ya esta casi cerrada. Mismo reparto que el dibujo: las de fuera
		# antes. El 0,75 es para que el suelo vuelva a pisarse un pelin ANTES de que el agujero acabe
		# de cerrarse del todo -- quedarte frenado sobre suelo entero es peor que pisar un hoyo casi
		# cerrado.
		_tapias.append({"cuerpo": cuerpo, "r": (0.15 + 0.5 * (1.0 - d)) * 0.75})
	_apartar_a_quien_este_dentro()


# A QUIEN LE REVIENTE BAJO LOS PIES. Si alguien esta encima cuando se abre el hoyo, se queda dentro
# de una caja de colision y no puede salir: clavado ahi hasta que se repare. Se le empuja al borde
# mas cercano en el mismo momento de abrirse.
#
# JUGADORES Y BICHOS, los dos. Cuando la tapia solo estorbaba a los jugadores bastaba con sacarlos a
# ellos; ahora el boquete es PARED DE VERDAD (misma capa que la roca) y encierra a cualquiera, asi
# que un slime que estuviera merodeando por esa celda se quedaria emparedado en el agujero.
#
# El jefe no entra en esta cuenta porque todavia no ha nacido: sale despues, y sale por animacion.
func _apartar_a_quien_este_dentro() -> void:
	if _tapias.is_empty():
		return
	var lado: float = float(DungeonGenerator.CELDA)
	var dentro: Dictionary = {}
	for c in _celdas:
		dentro[c] = true
	var atrapables: Array = []
	atrapables.append_array(get_tree().get_nodes_in_group("player"))
	atrapables.append_array(get_tree().get_nodes_in_group("aliado"))
	atrapables.append_array(get_tree().get_nodes_in_group("enemy"))
	for quien in atrapables:
		if not (quien is Node2D) or not is_instance_valid(quien):
			continue
		var n: Node2D = quien
		var suya: Vector2i = Vector2i(
			int(floor(n.global_position.x / lado)), int(floor(n.global_position.y / lado)))
		if not dentro.has(suya):
			continue
		# La celda libre mas cercana, en anillos: casi siempre la de al lado.
		for r in range(1, 6):
			var salida := Vector2.INF
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var v: Vector2i = suya + Vector2i(dx, dy)
					if dentro.has(v):
						continue
					if _piso != null and _piso.has_method("celda_pintada") \
							and not _piso.celda_pintada(v):
						continue
					var p: Vector2 = Vector2(v) * lado + Vector2(lado, lado) * 0.5
					if salida == Vector2.INF or p.distance_to(n.global_position) \
							< salida.distance_to(n.global_position):
						salida = p
					# (se queda la mas cercana del anillo, para sacarte por el borde que tienes al
					# lado y no de un tiron a la otra punta del agujero)
			if salida != Vector2.INF:
				n.global_position = salida
				break


# Quita las tapias que ya les toca, segun lo reparado. 'p' es lo que lleva la reparacion (0 a 1).
func _destapiar(p: float) -> void:
	if _tapias.is_empty():
		return
	var quedan: Array = []
	for t in _tapias:
		if p >= float(t["r"]):
			var cuerpo = t["cuerpo"]
			if cuerpo != null and is_instance_valid(cuerpo):
				(cuerpo as Node).queue_free()
			continue
		quedan.append(t)
	_tapias = quedan


# LA PIEDRA SE CIERRA SOLA. El boquete se come hacia dentro y las grietas se apagan con el, hasta
# que la pared vuelve a estar entera y este nodo sobra.
func _process_rota(delta: float) -> void:
	# PRIMERO SE ABRE. El boquete aparecia ya a tamaño completo en el frame en que salia el bicho, y
	# se leia como una pegatina puesta encima de la pared: el agujero tiene que REVENTAR, no aparecer.
	# En ABRIR_DUR el hueco crece de nada a entero, que a ese ritmo son un par de frames largos -- lo
	# justo para que el ojo vea que algo se ha partido ahi.
	if _t_abre < ABRIR_DUR:
		_t_abre += delta
		if _grietas != null and is_instance_valid(_grietas):
			# Con raiz: el area es lo que se ve y va con el radio al cuadrado, asi que el agujero se
			# abre de golpe y frena al final, como una rotura de verdad.
			_grietas.cerrar(sqrt(clampf(_t_abre / ABRIR_DUR, 0.0, 1.0)))
		return
	_t_rota += delta
	var p: float = clampf(_t_rota / _dur_rota, 0.0, 1.0)
	_destapiar(p)
	if _grietas != null and is_instance_valid(_grietas):
		# LO PEQUEÑO CURA ANTES QUE LO GRANDE, como una herida. Las GRIETAS son fisuras: se sellan
		# primero, en el primer tramo de la reparacion. El BOQUETE es el destrozo gordo y tarda todo
		# el rato -- es lo ultimo que queda abierto.
		#
		# Y bajando el avance, las grietas se van EN ORDEN INVERSO al que salieron: los hilos finos de
		# las puntas desaparecen antes que los troncos, que es exactamente como cerraria una piedra.
		_grietas.avance(1.0 - clampf(p / GRIETAS_CURAN, 0.0, 1.0))
		# 1 -> 0. No es lineal a proposito: al principio apenas se mueve (la piedra "aguanta rota" un
		# buen rato, que es lo que se lee como un destrozo de verdad) y se cierra deprisa al final.
		_grietas.cerrar(1.0 - p * p)
	if p >= 1.0:
		queue_free()


# La piedra vuelve a su sitio, EXACTAMENTE como estaba (misma fuente, mismo atlas, misma variante).
# Va en _exit_tree y no solo al final a proposito: un piso que se regenera se lleva por delante el
# TileMapLayer y a nosotros con el, y sin esto un aviso a medias dejaria un agujero permanente en la
# pared. Es la red de seguridad de todo esto.
func _exit_tree() -> void:
	# LAS TAPIAS, FUERA SIEMPRE. Cuelgan del padre del piso, asi que no se las lleva mi queue_free: si
	# el piso se regenera con un boquete abierto, quedarian cajas de colision invisibles flotando en
	# el mapa nuevo y el jugador chocaria con nada.
	for t in _tapias:
		var cuerpo = t["cuerpo"]
		if cuerpo != null and is_instance_valid(cuerpo):
			(cuerpo as Node).queue_free()
	_tapias.clear()
	if _capa == null:
		return
	# NO HAY NADA QUE RESTAURAR: la piedra original nunca se llego a borrar, la copia solo se pinta
	# encima (ver iniciar_capa). Lo unico que hay que soltar es el registro de "en obras".
	# Y se sueltan del registro de "en obras" AUNQUE la capa ya no valga: si no, un piso regenerado
	# heredaria celdas marcadas para siempre y esa pared no volveria a parir nunca.
	if _piso != null and is_instance_valid(_piso) and _piso.has_method("soltar_celdas_rotas"):
		_piso.soltar_celdas_rotas(_celdas)
		_piso.soltar_celdas_rotas(_celdas_halo)
	_capa = null
