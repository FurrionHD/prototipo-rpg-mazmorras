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
		amp: float, color: Color) -> bool:
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
	# El halo tambien queda EN OBRAS mientras dura: si otro parto cogiera una de estas celdas, al
	# devolverla el primero se quedaria un agujero. Lo registra el aviso y no montar_aviso porque es
	# aqui donde se decide cuales son.
	if _piso != null and _piso.has_method("marcar_celdas_rotas"):
		_piso.marcar_celdas_rotas(_celdas_halo)

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
		_halo.position = -_origen - (position - _origen) * (1.0 - HALO_FUERZA)
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


func _process(delta: float) -> void:
	if _capa == null and _rects.is_empty():
		return
	_t += delta
	if _auto_borrar > 0.0 and _t >= _auto_borrar:
		queue_free()
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
	position = _origen + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	_recolocar()


# La piedra vuelve a su sitio, EXACTAMENTE como estaba (misma fuente, mismo atlas, misma variante).
# Va en _exit_tree y no solo al final a proposito: un piso que se regenera se lleva por delante el
# TileMapLayer y a nosotros con el, y sin esto un aviso a medias dejaria un agujero permanente en la
# pared. Es la red de seguridad de todo esto.
func _exit_tree() -> void:
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
