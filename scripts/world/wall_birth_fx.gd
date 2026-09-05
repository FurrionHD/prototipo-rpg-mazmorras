# ============================================================
#  wall_birth_fx.gd
#  El AVISO de la pared: antes de parir, la celda de roca late y tiembla. Es la unica
#  advertencia que tienes -por eso existe: un bicho que aparece de la nada, sin aviso,
#  es una emboscada barata; con aviso, decides si te quedas o te largas.
#  Cuanto mas gordo es el parto (un brote), mas fuerte tiembla y mas se avisa.
#  Aspecto placeholder por codigo; el arte va al final.
# ============================================================

extends Node2D

# Cuanto llega a teñirse la piedra en lo mas fuerte del aviso. No 1.0: a tope pierde su textura y
# vuelve a parecer el rectangulo de color que esto viene a quitar.
const TINTE_MAX := 0.8

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
		_capa.erase_cell(_celdas[i])   # del piso desaparece: la tengo yo
	_recolocar()
	return true


# Mi copia pinta en coordenadas ABSOLUTAS de rejilla, asi que hay que deshacerle mi posicion. Y en
# CADA FRAME del temblor: si no, la piedra se queda quieta y lo unico que se mueve es mi nodo vacio.
func _recolocar() -> void:
	if _mio != null and is_instance_valid(_mio):
		_mio.position = -position


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
		# Sobre la piedra de verdad el latido va en el MODULATE, no en un color plano encima: asi la
		# roca sigue siendo la roca de este tramo y lo que hace es CALENTARSE, que es lo que se queria
		# decir desde el principio.
		#
		# CON SUELO, no directamente por el latido: el seno pasa por cero en cada ciclo, y multiplicando
		# a pelo la pared volvia a verse NORMAL la mitad del tiempo -medido: modulate (0.996, 0.984,
		# 0.983), o sea blanco-. Asi el tinte nunca baja del 30% de lo que le toque por 'p', y el latido
		# va por encima: la piedra se calienta y ADEMAS palpita, en vez de parpadear.
		var calor: float = p * lerpf(0.3, 1.0, latido)
		_mio.modulate = Color.WHITE.lerp(_color, TINTE_MAX * calor)
	else:
		var col := Color(_color.r, _color.g, _color.b, lerpf(0.15, 0.9, latido * p))
		for r in _rects:
			r.color = col

	# Y tiembla mas fuerte al final (todo el tramo a una).
	var amp: float = _amp * p
	position = _origen + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	_recolocar()


# La piedra vuelve a su sitio, EXACTAMENTE como estaba (misma fuente, mismo atlas, misma variante).
# Va en _exit_tree y no solo al final a proposito: un piso que se regenera se lleva por delante el
# TileMapLayer y a nosotros con el, y sin esto un aviso a medias dejaria un agujero permanente en la
# pared. Es la red de seguridad de todo esto.
func _exit_tree() -> void:
	if _capa == null:
		return
	if is_instance_valid(_capa):
		for i in _celdas.size():
			var d: Dictionary = _guardadas[i]
			_capa.set_cell(_celdas[i], int(d["src"]), d["atlas"], int(d["alt"]))
	# Y se sueltan del registro de "en obras" AUNQUE la capa ya no valga: si no, un piso regenerado
	# heredaria celdas marcadas para siempre y esa pared no volveria a parir nunca.
	if _piso != null and is_instance_valid(_piso) and _piso.has_method("soltar_celdas_rotas"):
		_piso.soltar_celdas_rotas(_celdas)
	_capa = null
