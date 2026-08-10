# ============================================================
#  casteo_mapa.gd
#  RECITAR UN HECHIZO EN LA MAZMORRA, fuera de combate: es la forma que tiene un mago de ABRIR la
#  pelea. Mantienes el boton de atacar, eliges hechizo, recitas sus frases aqui mismo y, si lo
#  cantas entero, sale disparado hacia el bicho. Al impactar se abre el combate con el como
#  objetivo principal y el hechizo se resuelve DENTRO, tal cual (ver player._lanzar_conjuro_mapa).
#
#  TRES COSAS QUE LO HACEN DISTINTO DEL RECITADO DE COMBATE:
#
#  1) EL MUNDO NO SE PARA. Esto no es un menu y no entra en la pila modal de Game (los menus pausan
#     el arbol: ver Game.abrir_menu). Los bichos siguen andando mientras cantas, y por eso mismo...
#  2) ...CANTAR HACE RUIDO. Mientras el panel esta abierto se le pone ruido_extra al jugador (los
#     bichos oyen por VELOCIDAD, asi que quieto serias mudo) y se ceba el medidor de alboroto.
#  3) FALLAR AQUI ES PEOR. El backfire puede matarte (ver StatsMath.backfire_damage), el conjuro
#     revienta con un estallido que se oye lejos... y NO se abre combate: te quedas tu, tocado y
#     con lo que venga acercandose. Peleas o corres, tu decides.
#
#  Lo que se PINTA se parte en dos a proposito: el bocadillo sobre la cabeza (globo_casteo.gd) lleva
#  el estado del canto, y las opciones a/b/c/d van en la banda de abajo, que es donde cae el pulgar.
#  Las frases son largas y no caben sobre un cuerpo de 32 px sin tapar media pantalla.
# ============================================================

extends CanvasLayer
class_name CasteoMapa

const GloboCasteoS = preload("res://scripts/ui/globo_casteo.gd")

# Se ha cantado entero: sale el conjuro. El mana YA esta cobrado.
signal lanzado(spell: SpellData, objetivo: Node)
# Se ha fallado una frase: backfire ya aplicado (daño y mana). 'muerto' = te ha matado.
signal fallado(spell: SpellData, dano: float, muerto: bool)
# Se ha cerrado sin cantar nada (Volver, o interrumpido): no se ha cobrado nada.
signal cancelado()

# Los MISMOS numeros que el recitado de combate (ver combat.ALTO_BOTON_ACCION y compañia): esto se
# aprende una vez y tiene que sentirse igual en los dos sitios.
const COLUMNAS := 3
# Las FRASES van a dos columnas y no a tres: lo que hay dentro es una frase entera ("Que el cielo
# descargue su furia"), no el nombre corto de un hechizo.
const COLUMNAS_FRASES := 2
const ALTO_BOTON := 76.0
const ALTO_BOTON_VOLVER := 56.0
const N_OPCIONES_TEST := 4

# RUIDO del canto, en "px/s equivalentes" (ver player.ruido_oido). Por encima de correr (~170): un
# encantamiento recitado en voz alta en un pasillo de piedra se oye mas que unas botas.
const RUIDO_CANTANDO := 200.0
# Y el estallido de un conjuro que se descontrola: el maximo, y dura unos segundos.
const RUIDO_ESTALLIDO := 400.0
const RUIDO_ESTALLIDO_DUR := 3.0
# Alboroto (el medidor de los brotes) por segundo cantando. Al ritmo de correr: hacer ruido en la
# mazmorra tiene el mismo precio lo hagas con los pies o con la boca.
const ALBOROTO_CANTANDO := 3.0

# Lo que ocupan los mandos tactiles por la DERECHA (ver touch_controls._colocar: actuar + atacar +
# curar, cada uno con su margen). El panel se queda a su izquierda en vez de subirse por encima:
# abajo es donde va -es donde cae el pulgar y donde el usuario lo pidio-, y asi los botones redondos
# se siguen alcanzando mientras cantas, que para eso el mundo no se para.
const ANCHO_BANDA_TACTIL := 340.0

var _pj: PersonajeData = null
var _jugador: Node2D = null
var _objetivo: Node = null          # el bicho al que va (se fija al empezar)
var _spell: SpellData = null
var _frase: int = 0                 # por que frase vamos (0 = ninguna recitada aun)
var _cerrado: bool = false

var _panel: VBoxContainer = null
var _globo: Node2D = null
# Los botones de las OPCIONES de la frase actual. Se guardan porque se apagan y se encienden solos
# segun puedas recitar o no (ver _refrescar_bloqueo). El "◄ Volver" NO entra en la lista: cancelar
# tiene que poder hacerse siempre, tambien corriendo y con una pared en medio.
var _botones_frase: Array[Button] = []
# Por que NO se puede recitar ahora mismo ("" = se puede). Es lo que se pinta en el globo.
var _bloqueo: String = ""

# Por encima de esta velocidad se considera que te estas MOVIENDO y no se puede recitar: cantar es
# plantarse. No es 0 exacto porque el cuerpo tiene rebotes de colision de un frame suelto.
const VEL_QUIETO := 6.0


# 'objetivo' es el bicho al que ira el conjuro: se fija AQUI y no al terminar de cantar, para que no
# se cuele otro por delante mientras recitas.
func setup(pj: PersonajeData, jugador: Node2D, objetivo: Node) -> void:
	_pj = pj
	_jugador = jugador
	_objetivo = objetivo


func _ready() -> void:
	# POR ENCIMA DE LOS MANDOS TACTILES (capa 6). No es un capricho de dibujo: la zona del joystick
	# es la MITAD IZQUIERDA ENTERA de la pantalla con MOUSE_FILTER_STOP, asi que desde una capa mas
	# baja se comia los toques de las frases y, en su lugar, te sacaba el joystick encima.
	layer = 7
	_panel = VBoxContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 16.0 + Tactil.borde.x
	# Con mandos tactiles se para ANTES de ellos, no por encima: el panel va abajo (es donde cae el
	# pulgar) y los botones redondos siguen alcanzables mientras cantas.
	_panel.offset_right = -16.0 - Tactil.borde.x - (ANCHO_BANDA_TACTIL if Tactil.activo else 0.0)
	_panel.offset_bottom = -16.0 - Tactil.borde.y
	_panel.offset_top = _panel.offset_bottom - ALTO_BOTON * 2.0 - 20.0
	_panel.alignment = BoxContainer.ALIGNMENT_END
	_panel.add_theme_constant_override("separation", 12)
	add_child(_panel)

	# El bocadillo cuelga del JUGADOR (no de esta capa): asi lo sigue solo, sin recolocarlo cada
	# frame ni convertir coordenadas del mundo a pantalla.
	if is_instance_valid(_jugador):
		_globo = GloboCasteoS.new()
		_jugador.add_child(_globo)

	_menu_hechizos()


func _exit_tree() -> void:
	_soltar_ruido()
	if is_instance_valid(_globo):
		_globo.queue_free()


# ------------------------------------------------------------
#  PASO 1: que hechizo
# ------------------------------------------------------------
func _menu_hechizos() -> void:
	_vaciar()
	var spells: Array = _pj.equipped_spells.duplicate()
	spells.sort_custom(func(a, b): return _coste(a) > _coste(b))
	var grid := _rejilla()
	for sp in spells:
		if sp == null:
			continue
		var b := Button.new()
		var coste: float = _coste(sp)
		b.text = "%s  (%.2f MP)" % [sp.nombre, coste]
		b.tooltip_text = sp.descripcion_mecanica(sp.dano_mostrado() * Game.poder_magico(_pj))
		if Game.player_mp(_pj) < coste:
			b.disabled = true
			b.tooltip_text = "⛔ Maná insuficiente\n\n%s" % b.tooltip_text
		elif sp.frases.is_empty():
			# Un hechizo sin frases no se puede recitar: aqui no hay turnos que gastar en su lugar.
			b.disabled = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, ALTO_BOTON)
		b.clip_text = true
		b.pressed.connect(_elegir.bind(sp))
		grid.add_child(b)
	_boton_ancho("◄ Volver", ALTO_BOTON_VOLVER, _cancelar)
	# El panel se ajusta a las FILAS que ocupen los hechizos. Sin esto se quedaba con el alto de dos
	# filas de _vaciar(), y en cuanto tenias 4 hechizos (2 filas + el Volver) el contenido sobraba y
	# se salia por debajo de la pantalla: el Volver acababa detras de la barra de tareas.
	var filas: int = maxi(1, ceili(grid.get_child_count() / float(COLUMNAS)))
	_panel.offset_top = _panel.offset_bottom \
		- (filas * ALTO_BOTON + (filas - 1) * 10.0 + 12.0 + ALTO_BOTON_VOLVER) - 20.0
	_globo_estado("🔮 ¿Qué vas a recitar?", Color(0.75, 0.75, 0.9))
	# El ruido empieza AQUI: ya estas plantado en mitad del pasillo sacando el grimorio.
	_coger_ruido()


func _elegir(sp: SpellData) -> void:
	_spell = sp
	_frase = 0
	_mostrar_frase()


# ------------------------------------------------------------
#  PASO 2: recitar
# ------------------------------------------------------------
func _mostrar_frase() -> void:
	_vaciar()
	var correcta: String = _spell.frases[_frase]
	var opciones: Array = SpellBook.opciones_test(correcta, _otras_frases(), N_OPCIONES_TEST)
	# En REJILLA, como los hechizos y las habilidades: cuadradas y pegadas unas a otras. Una por fila
	# a lo ancho de la pantalla dejaba unas tiras larguisimas de las que solo se usaba el trocito del
	# texto, y el ojo tenia que recorrer todo el ancho para leer cuatro opciones.
	# DOS columnas y no tres: aqui el texto es una FRASE entera, no el nombre de un hechizo.
	# ...y a UNA si a dos no cabe la frase mas larga: una opcion recortada no se puede leer, y sin
	# poder leerla la eliges a ciegas y te comes el backfire.
	var cols: int = SpellBook.columnas_para_frases(opciones, _panel.size.x,
		_panel.get_theme_default_font(), 17, COLUMNAS_FRASES)
	var grid := _rejilla(cols)
	var letras := ["a", "b", "c", "d", "e", "f"]
	for i in opciones.size():
		var b := Button.new()
		b.text = "%s)  %s" % [letras[i], opciones[i]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, ALTO_BOTON)
		b.add_theme_font_size_override("font_size", 17)
		b.clip_text = true
		b.pressed.connect(_responder.bind(String(opciones[i]), correcta))
		grid.add_child(b)
		_botones_frase.append(b)
	# Echarse atras SOLO antes de la primera frase, igual que en combate: en cuanto sueltas una, el
	# conjuro esta en marcha y ya no se para.
	var filas: int = ceili(opciones.size() / float(cols))
	var alto: float = filas * ALTO_BOTON + (filas - 1) * 10.0
	if _frase == 0:
		_boton_ancho("◄ Volver (aún no has recitado nada)", ALTO_BOTON_VOLVER, _menu_hechizos)
		alto += 12.0 + ALTO_BOTON_VOLVER
	_panel.offset_top = _panel.offset_bottom - alto - 20.0
	_bloqueo = ""   # se recalcula en el proximo _process, que es quien pinta el estado del globo
	_refrescar_bloqueo()


func _responder(elegida: String, correcta: String) -> void:
	# El boton esta apagado cuando no se puede recitar, pero se vuelve a preguntar: entre que se
	# pinta y llega el clic puede haber echado a andar (o el bicho haberse tapado).
	if _cerrado or _motivo_bloqueo() != "":
		return
	if elegida != correcta:
		_backfire()
		return
	_frase += 1
	Game.contar_frase_recitada(_pj)   # el mismo contador oculto que en combate (Encantamiento rapido)
	if _frase < _spell.longitud():
		_mostrar_frase()
	else:
		_completar()


# ------------------------------------------------------------
#  DESENLACES
# ------------------------------------------------------------
# Cantado entero: se cobra el mana (al SOLTARLO, igual que en combate) y sale el conjuro.
func _completar() -> void:
	# ULTIMA COMPROBACION antes de cobrar: sin linea de visión (o en movimiento) el conjuro NO sale.
	# Los botones ya se apagan solos (ver _motivo_bloqueo) y _responder lo vuelve a mirar, asi que
	# esto solo salta en una carrera rarisima; esta porque el maná se paga AQUI y de aqui no se
	# vuelve. Se retrocede una frase para no dejar el panel muerto: la repites y ya.
	if _motivo_bloqueo() != "":
		_frase = maxi(0, _frase - 1)
		_mostrar_frase()
		return
	var coste: float = _coste(_spell)
	Game.gastar_mana(_pj, coste)
	print("[casteo] %s lanza %s desde el mapa | -%.2f MP" % [_pj.nombre, _spell.nombre, coste])
	var sp := _spell
	var obj := _objetivo
	_cerrar()
	lanzado.emit(sp, obj)


# Fallar una frase EN EL MAPA. Mismo precio que en combate (mana + daño), pero aqui puede matarte y
# ademas el estallido se oye: los bichos de alrededor vienen a ver que ha pasado. NO se abre pelea.
func _backfire() -> void:
	var sp := _spell
	Game.gastar_mana(_pj, _coste(sp))
	var vida_max: float = Game.player_max_hp(_pj)
	var dano: float = StatsMath.backfire_damage(sp, _frase, sp.longitud(), vida_max)
	var antes: float = Game.player_hp(_pj)
	var muerto: bool = dano >= antes
	_pj.current_hp = maxf(0.0, antes - dano)
	print("[casteo] BACKFIRE de %s en el mapa | frase %d/%d | %.1f de daño | HP %.1f/%.1f%s" % [
		sp.nombre, _frase + 1, sp.longitud(), dano, _pj.current_hp, vida_max,
		"  MUERTO" if muerto else ""])
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("💥 El conjuro se te descontrola: %.0f de daño." % dano)
	# El estallido: ruido a saco (aunque el panel ya se cierre) y alboroto de golpe.
	if is_instance_valid(_jugador) and _jugador.has_method("hacer_ruido"):
		_jugador.hacer_ruido(RUIDO_ESTALLIDO, RUIDO_ESTALLIDO_DUR)
	Game.sumar_alboroto(ALBOROTO_CANTANDO * RUIDO_ESTALLIDO_DUR)
	_cerrar()
	fallado.emit(sp, dano, muerto)
	if muerto:
		Game.morir_jugador()


func _cancelar() -> void:
	_cerrar()
	cancelado.emit()


# Lo llama el jugador si algo de fuera se lleva el canto por delante (un bicho que te alcanza y abre
# la pelea, cambiar de piso...). No cobra nada, que es la regla de siempre: el maná se paga al
# soltarlo o al fallar.
#
# Devuelve por donde ibas ({} si no habias empezado ninguno). Que te interrumpan NO tira el conjuro:
# si lo que te ha cortado es una pelea, sigues cantandolo DENTRO por la frase que llevabas (ver
# player.interrumpir_casteo -> Game.apuntar_canto_a_medias). Perder tres frases porque un bicho te
# alcanza en la ultima era el peor momento posible para castigar.
func interrumpir() -> Dictionary:
	if _cerrado:
		return {}
	var a_medias: Dictionary = {}
	if _spell != null:
		a_medias = {"spell": _spell, "frase": _frase}
		print("[casteo] canto interrumpido en la frase %d/%d: se sigue dentro del combate" % [
			_frase + 1, _spell.longitud()])
	_cerrar()
	cancelado.emit()
	return a_medias


func _cerrar() -> void:
	_cerrado = true
	_soltar_ruido()
	_globo_estado("", Color.WHITE)   # se apaga el bocadillo, aqui y en las otras pantallas
	queue_free()


# ------------------------------------------------------------
#  RUIDO
# ------------------------------------------------------------
func _process(delta: float) -> void:
	if _cerrado:
		return
	# El objetivo se ha muerto o lo ha limpiado el reciclador mientras cantabas: el conjuro se queda
	# sin a quien ir. Se cae SIN cobrar (aun no habias soltado nada).
	if _objetivo != null and not is_instance_valid(_objetivo):
		interrumpir()
		return
	Game.sumar_alboroto(ALBOROTO_CANTANDO * delta)
	_refrescar_bloqueo()


# ¿SE PUEDE RECITAR AHORA MISMO? Devuelve el motivo por el que NO ("" = si se puede).
#
#   MOVIENDOTE  -> cantar es plantarse. Recitar corriendo quitaba toda la tension: te ibas leyendo
#                  las frases de camino y el ruido no significaba nada.
#   TRAS UNA PARED -> si el bicho se te mete detras de un muro, el conjuro no tiene por donde salir.
#                  No se cancela (eso seria castigar el conjuro por un paso suyo): se ESPERA. Si se
#                  vuelve a asomar, sigues por donde ibas.
#
# El "◄ Volver" no se toca nunca: cancelar tiene que poder hacerse en cualquiera de los dos casos.
func _motivo_bloqueo() -> String:
	if not is_instance_valid(_jugador):
		return ""
	if (_jugador.velocity as Vector2).length() > VEL_QUIETO:
		return "quieto para recitar"
	if _objetivo is Node2D and _jugador.has_method("ve_a") \
			and not _jugador.ve_a((_objetivo as Node2D).global_position):
		return "sin línea de visión"
	return ""


func _refrescar_bloqueo() -> void:
	var motivo: String = _motivo_bloqueo()
	if motivo == _bloqueo and not _botones_frase.is_empty():
		return   # nada que repintar: sigue igual que el frame anterior
	_bloqueo = motivo
	for b in _botones_frase:
		if is_instance_valid(b):
			b.disabled = motivo != ""
	if _spell == null:
		return
	# El aviso va en el GLOBO, que es donde ya estas mirando mientras cantas, y en gris para que se
	# vea de un vistazo que ahora mismo no toca.
	var txt: String = "🔮 %s · %d/%d" % [_spell.nombre, _frase + 1, _spell.longitud()]
	if motivo == "":
		_globo_estado(txt, _color_spell())
	else:
		_globo_estado("%s — %s" % [txt, motivo], Color(0.55, 0.55, 0.6))


func _coger_ruido() -> void:
	if is_instance_valid(_jugador) and "ruido_extra" in _jugador:
		_jugador.ruido_extra = RUIDO_CANTANDO


func _soltar_ruido() -> void:
	if is_instance_valid(_jugador) and "ruido_extra" in _jugador:
		_jugador.ruido_extra = 0.0


# ------------------------------------------------------------
#  UTILIDADES DE PINTADO
# ------------------------------------------------------------
func _vaciar() -> void:
	_botones_frase.clear()
	for c in _panel.get_children():
		c.queue_free()
	_panel.offset_top = _panel.offset_bottom - ALTO_BOTON * 2.0 - 20.0


func _rejilla(columnas: int = COLUMNAS) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columnas
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(grid)
	return grid


func _boton_ancho(texto: String, alto: float, al: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, alto)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(al)
	_panel.add_child(b)


# El bocadillo, aqui y en las otras pantallas: tus compañeros tienen que ver que estas cantando (y
# que no es momento de atropellarte la pelea). Texto vacio = ya no canto.
func _globo_estado(texto: String, color: Color) -> void:
	if is_instance_valid(_globo):
		if texto.is_empty():
			_globo.ocultar()
		else:
			_globo.mostrar(texto, color)
	Net.anunciar_canto(texto, color)


func _color_spell() -> Color:
	if _spell != null and Elementos.tiene_color(_spell.elemento):
		return Elementos.color(_spell.elemento)
	return Color(0.75, 0.75, 0.9)


# Frases de los OTROS hechizos equipados, para nutrir los distractores (igual que en combate).
func _otras_frases() -> Array:
	var pool: Array = []
	for sp in _pj.equipped_spells:
		if sp != null and sp != _spell:
			for f in sp.frases:
				pool.append(f)
	return pool


func _coste(sp: SpellData) -> float:
	return Game.coste_mana_efectivo(sp, _pj)
