# ============================================================
#  home_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del HOGAR. Dos cosas, que son las dos que se hacen en casa:
#    1) EQUIPO   - quien de tu plantilla baja hoy a la mazmorra (como mucho Game.PARTY_MAX) y en
#                  que orden. La plantilla no tiene tope: aqui se montan equipos distintos sin
#                  perder a nadie (nadie se despide nunca).
#    2) ALMACEN  - guardar en casa los materiales que traigas en la bolsa (lo que antes hacia la
#                  tecla F a secas). Se consulta en la pestaña "Materiales" del inventario (I).
#
#  El ORDEN del equipo importa: el de arriba es el que va EN CABEZA (el cuerpo que mueves por el
#  mapa, el que mina y el que gasta aguante). Se puede cambiar tambien sobre la marcha con las
#  teclas 1/2/3, pero aqui es donde se decide con quien sales de casa.
# ============================================================

extends CanvasLayer

# Almacen del hogar. Bote y Cofre son tu almacen personal (persiste en la partida); en multi
# pasan a ser los del host (compartidos). Siempre visibles.
const TABS := ["Equipo", "Encargos", "Almacén", "Cofre"]

# Los dos apartados de Encargos, por ID como los del cofre (ver COFRE_SUBS).
const ENCARGO_SUBS := [["En marcha", "curso"], ["Mandar uno", "nuevo"]]

# Los apartados del cofre, [etiqueta, id]. Van por ID y no por indice porque el numero cambia en
# cuanto se mete uno nuevo en medio, y un `_cofre_sub == 2` suelto pasa a significar otra cosa sin
# avisar. Mismo criterio que las pestañas de forge_menu.
# La HUCHA es un apartado mas del cofre y no una pestaña suya arriba: es lo mismo que el resto
# (algo que dejas en casa y que en multi es comun), y sola en su pantalla se quedaba una fila de
# tres numeros perdida en medio de un vacio enorme.
const COFRE_SUBS := [["Armas", "armas"], ["Armaduras", "armaduras"],
	["Mochilas y herram.", "utiles"], ["Consumibles", "consumibles"], ["Monedas", "monedas"]]
# Que 'clase' de las que guarda el cofre se enseña en cada apartado (ver Game.serializar_equipo).
const COFRE_CLASES := {
	"armas": ["arma"],
	"armaduras": ["armadura"],
	"utiles": ["mochila", "herramienta"],
}

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

var _root: Control = null
var _header: VBoxContainer = null
var _content: VBoxContainer = null
var _lista: VBoxContainer = null
# La COLUMNA de la lista, para poder esconderla en las pestañas que no la usan: si se queda ahi
# vacia, se lleva 330 px de ancho y el contenido de al lado se apretuja contra el borde.
var _lista_scroll: ScrollContainer = null
var _aviso_lbl: Label = null
var _tab_buttons: Array = []
var _side: VBoxContainer = null
var _aviso: String = ""
var _aviso_ok: bool = true
var _tab: int = 0
var _cofre_sub: int = 0   # indice dentro de COFRE_SUBS (el que MANDA es su id, no el numero)
var _bote_input: String = ""   # cantidad escrita en el bote (se conserva entre re-dibujos)

# --- Lo que se esta montando en "Mandar uno". Se conserva entre re-dibujos: cada casilla que marcas
# rehace el panel entero (hay que recalcular el pronostico) y sin esto se perderia la seleccion.
var _enc_sub: int = 0
var _enc_piso: int = 1
var _enc_dur: int = 0                # indice en Encargos.DURACIONES
var _enc_tipos: Array = [0]          # Encargos.Tipo marcados
var _enc_uids: Array = []            # quienes van
var _enc_utiles: Array = []          # ids de entradas del cofre asignadas
var _enc_faena: Dictionary = {}      # uid -> Encargos.Tipo, o -1 = "lo que haga falta"
var _enc_clase: Dictionary = {}      # uid -> Encargos.Clase (con que pelea)


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("home_menu")

	var m: Dictionary = MenuScaffold.construir(self, "HOGAR",
		"Tu casa: aquí se decide con quién bajas y aquí se guarda lo que traes.",
		_cerrar)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_lista = m["lista"]
	_lista_scroll = m["lista_scroll"]
	_aviso_lbl = m["aviso"]
	_side = m["side"]
	# Las pestañas se rehacen en cada _rebuild: en sesion multi aparecen Bote y Cofre.
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(_on_hogar_cambiado)


# El OTRO jugador cambio el estado compartido: si tengo el hogar abierto, me re-dibujo.
func _on_hogar_cambiado() -> void:
	if _root != null and _root.visible:
		_rebuild()


func _tabs() -> Array:
	return TABS


func _rehacer_tabs() -> void:
	for b in _tab_buttons:
		(b as Button).queue_free()
	_tab_buttons.clear()
	var etiquetas: Array = _tabs()
	_tab = clampi(_tab, 0, etiquetas.size() - 1)
	for i in etiquetas.size():
		var b := Button.new()
		b.text = etiquetas[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
		b.pressed.connect(_on_tab.bind(i))
		_side.add_child(b)
		_tab_buttons.append(b)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_tab = 0
	_aviso = ""
	_root.visible = true
	Game.abrir_menu(self)
	_rebuild()


func _cerrar() -> void:
	# Si has mandado a TODOS a casa, alguien tiene que llevar el cuerpo: baja tu original.
	# Va aqui porque _cerrar es el embudo de los TRES caminos de cierre -- la tecla Esc (_input de
	# abajo), el boton del scaffold, y el cierre a la fuerza cuando te embiste un bicho
	# (Game.cerrar_menus_abiertos). Game.lider() ya rellena con el original el solo; esto solo lo
	# adelanta para que sea determinista y para poder avisar.
	if Game.party.is_empty():
		var solo: PersonajeData = Game.lider()
		var p: Node = get_tree().get_first_node_in_group("player")
		if p != null and p.has_method("refrescar_lider"):
			p.refrescar_lider()
		var hud: Node = get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("mostrar_toast"):
			hud.mostrar_toast("No dejaste a nadie en el equipo: %s baja contigo." % solo.nombre)
	_root.visible = false
	Game.cerrar_menu(self)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _on_tab(i: int) -> void:
	_tab = i
	_aviso = ""
	_rebuild()


# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO. Es el mismo guardia que
# lleva el herrero desde que se cazo alli.
var _reconstruyendo := false
# Y lo que llego MIENTRAS. Salir en seco perdia la señal: un hogar_cambiado que entra a mitad de un
# rebuild (los RPC llegan con el arbol pausado y este menu es PROCESS_MODE_ALWAYS) dejaba la pestaña
# mintiendo hasta que el jugador la tocara -- justo lo que no puede pasar con el roster en vivo.
var _rebuild_pendiente := false

func _rebuild() -> void:
	if _reconstruyendo:
		_rebuild_pendiente = true
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false
	if _rebuild_pendiente:
		_rebuild_pendiente = false
		_rebuild()


func _rebuild_real() -> void:
	_rehacer_tabs()
	for zona in [_header, _content, _lista]:
		MenuScaffold.vaciar(zona)
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)

	# La columna de la lista solo la usan el Cofre (sus dos columnas: lo tuyo / lo que hay dentro) y
	# los Encargos. En las demas se esconde: vacia se quedaba con 330 px y el contenido de al lado se
	# apretujaba en lo que sobraba (los tres botones del baul no cabian en una fila por esto).
	var con_lista: bool = _tabs()[_tab] in ["Cofre", "Encargos", "Equipo"]
	if _lista_scroll != null:
		_lista_scroll.visible = con_lista

	match _tabs()[_tab]:
		"Equipo": _build_equipo()
		"Encargos": _build_encargos()
		"Almacén": _build_almacen()
		# La HUCHA ya no tiene pestaña propia: es un apartado dentro del cofre (ver COFRE_SUBS).
		"Cofre": _build_cofre()


# ============================================================
#  ENCARGOS: mandar a los del hogar a recolectar por RELOJ REAL
#  Dos apartados: los que estan fuera y el formulario para mandar uno nuevo.
# ============================================================

func _build_encargos() -> void:
	MenuScaffold.titulo(_header, "ENCARGOS", 18)
	MenuScaffold.pestanas(_header, [ENCARGO_SUBS[0][0], ENCARGO_SUBS[1][0]], _enc_sub,
		func(i: int):
			_enc_sub = i
			_aviso = ""
			_rebuild())
	# Al abrir la pestaña se repasa: puede haber vencido alguno mientras no mirabas. De cliente esto
	# es una PETICION al host (el unico que puede resolver), asi que la respuesta llega despues por
	# hogar_cambiado y re-dibuja sola; aqui no se puede avisar de nada todavia.
	Net.pedir_repasar_encargos()
	# La purga va AQUI y no solo dentro de "Mandar uno": el roster cambia en vivo (tu compañero mete a
	# alguien en su equipo y se le cae del selector a todo el mundo), y si solo se limpiara al pintar
	# esa sub-pestaña, mirando "En marcha" te quedaria una seleccion mentirosa esperando.
	_purgar_seleccion(_libres_del_hogar())
	if String(ENCARGO_SUBS[_enc_sub][1]) == "curso":
		_build_encargos_curso()
	else:
		_build_encargos_nuevo()


# Los del hogar a los que se puede mandar AHORA: ni bajando con su dueño, ni ya de encargo.
func _libres_del_hogar() -> Array:
	var out: Array = []
	for f in Net.roster_hogar():
		var ficha := f as Dictionary
		if not bool(ficha.get("en_equipo", false)) and not bool(ficha.get("de_encargo", false)):
			out.append(ficha)
	return out


# Quita de la seleccion a quien ya no esta libre y LO DICE. Antes se hacia en silencio: marcabas a
# tres, tu compañero se llevaba a uno a su equipo, y al mandar el encargo iban dos sin que nadie te
# explicara por que.
func _purgar_seleccion(libres: Array) -> void:
	var por_uid: Dictionary = {}
	for f in libres:
		por_uid[String((f as Dictionary).get("uid", ""))] = true
	# El nombre hay que cogerlo del roster COMPLETO: el que se cae ya no esta en 'libres'.
	var nombres: Dictionary = {}
	for f in Net.roster_hogar():
		nombres[String((f as Dictionary).get("uid", ""))] = String((f as Dictionary).get("nombre", "?"))

	var vivos: Array = []
	var caidos: Array = []
	for uid in _enc_uids:
		if por_uid.has(String(uid)):
			vivos.append(uid)
		else:
			caidos.append(String(nombres.get(String(uid), "Alguien")))
	if caidos.is_empty() and vivos.size() == _enc_uids.size():
		_limpiar_ordenes_sueltas()
		return
	_enc_uids = vivos
	if not caidos.is_empty():
		_aviso = "%s ya no está%s disponible%s: %s." % [
			", ".join(caidos), "" if caidos.size() == 1 else "n", "" if caidos.size() == 1 else "s",
			"lo han metido en un equipo o se ha ido de encargo" if caidos.size() == 1
				else "los han metido en un equipo o se han ido de encargo"]
		_aviso_ok = false
		# Repintar la linea A MANO: _rebuild_real ya la pinto ANTES de llamar aqui, asi que sin esto el
		# aviso no saldria hasta el siguiente rebuild -- justo cuando ya no hace falta.
		MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	_limpiar_ordenes_sueltas()


# Las ordenes de los que ya no van, o las faenas que apuntaban a un tipo que has desmarcado: si no se
# limpian, mandas gente "a las plantas" en un encargo que ya no lleva plantas.
func _limpiar_ordenes_sueltas() -> void:
	for uid in _enc_faena.keys():
		if not _enc_uids.has(uid):
			_enc_faena.erase(uid)
		else:
			_enc_faena[uid] = Encargos.faenas_validas(_enc_faena[uid], _enc_tipos)
	for uid in _enc_clase.keys():
		if not _enc_uids.has(uid):
			_enc_clase.erase(uid)


func _build_encargos_curso() -> void:
	var lista: Array = Net.encargos_visibles()
	MenuScaffold.titulo(_lista, "En marcha (%d)" % lista.size(), 14)
	if lista.is_empty():
		MenuScaffold.nota(_lista, "No hay nadie fuera. En «Mandar uno» eliges a quién mandas, a qué "
			+ "piso y cuánto tiempo. Cuentan por reloj real, así que siguen aunque cierres el juego.")
		return
	for e_ in lista:
		_fila_encargo(e_ as Dictionary)


func _fila_encargo(e: Dictionary) -> void:
	var listo: bool = int(e.get("estado", 0)) == Encargos.ESTADO_LISTO
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	_lista.add_child(caja)

	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 6)
	caja.add_child(cab)
	var nombres: PackedStringArray = []
	for m in (e.get("miembros", []) as Array):
		nombres.append(String((m as Dictionary).get("nombre", "?")))
	var tipos: PackedStringArray = []
	for t in (e.get("tipos", []) as Array):
		tipos.append(String(Encargos.NOMBRE_TIPO.get(int(t), "?")))

	var l := Label.new()
	l.text = "Piso %d · %s  ·  %s" % [int(e.get("piso", 1)), ", ".join(tipos), ", ".join(nombres)]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(l)

	var est := Label.new()
	if listo:
		est.text = "¡De vuelta!"
		est.add_theme_color_override("font_color", AMBAR)
	else:
		est.text = "faltan %s" % Encargos.texto_restante(e)
		est.add_theme_color_override("font_color", GRIS)
	cab.add_child(est)

	if not listo:
		var barra := ProgressBar.new()
		barra.custom_minimum_size = Vector2(0, 6)
		barra.show_percentage = false
		var dur: float = maxf(1.0, float(e.get("duracion", 1)))
		barra.value = 100.0 * clampf(1.0 - float(Encargos.restante(e)) / dur, 0.0, 1.0)
		caja.add_child(barra)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 6)
	caja.add_child(acciones)

	if listo:
		var recoger := Button.new()
		recoger.text = "Recoger"
		recoger.pressed.connect(func():
			# De cliente el informe llega por _aviso_remoto: el botin lo reparte el host.
			if Net._soy_cliente():
				Net.solicitar_recoger_encargo(int(e["id"]))
				_aviso = "Recogiendo…"
				_aviso_ok = true
			else:
				var inf: Dictionary = Game.recoger_encargo(int(e["id"]))
				_aviso = _texto_informe(inf)
				_aviso_ok = int(inf.get("desenlace", 0)) != Encargos.FRACASO
				Net._difundir_hogar()
			_rebuild())
		acciones.add_child(recoger)
	else:
		var traer := Button.new()
		traer.text = "Traer de vuelta"
		traer.tooltip_text = "Los hace volver YA, con lo que lleven recogido hasta ahora. A media " \
			+ "faena traen la mitad: el trabajo hecho no se pierde."
		traer.pressed.connect(func():
			Net.solicitar_traer_encargo(int(e["id"]))
			_aviso = "Vuelven a casa con lo que llevaban. Recógelo aquí mismo."
			_aviso_ok = true
			_rebuild())
		acciones.add_child(traer)

		# --- BOTON DE DEV (temporal, quitar antes de publicar) ---
		# No es lo mismo que "Traer de vuelta": aquel acorta la duracion y por eso vuelven con lo
		# proporcional; este RETRASA EL INICIO, asi que el encargo cuenta COMPLETO y da exactamente
		# lo mismo que si hubieras esperado las ocho horas. Es el unico que sirve para mirar el
		# balance sin esperar de verdad. Va aqui y no solo en el panel de dev porque asi se puede
		# terminar UNO concreto, y porque se ve en el .exe exportado (el panel de dev tambien, pero
		# esto es un clic en vez de abrirlo y buscar la seccion).
		var dev := Button.new()
		dev.text = "⚡ Terminar ya [dev]"
		dev.tooltip_text = "Como si hubiera pasado su tiempo ENTERO: el resultado es idéntico al de "
		dev.tooltip_text += "esperarlo de verdad. Botón de pruebas, se quitará."
		dev.modulate = Color(0.75, 0.85, 1.0)
		dev.pressed.connect(func():
			Net.solicitar_dev_terminar_encargo(int(e["id"]))
			_aviso = "[dev] Encargo terminado al 100%. Ya se puede recoger."
			_aviso_ok = true
			_rebuild())
		acciones.add_child(dev)


func _texto_informe(inf: Dictionary) -> String:
	if inf.is_empty():
		return "Ese encargo ya no está."
	if bool(inf.get("ocupado", false)):
		# El almacén del hogar es común y ahora mismo lo tiene otro. No se fuerza: el encargo espera.
		return "Tu compañero está en el taller. Vuelve en un momento: no se pierde nada."
	var t: String = "%s. Traen %d material%s" % [
		Encargos.NOMBRE_DESENLACE[int(inf.get("desenlace", 0))],
		int(inf.get("materiales", 0)), "" if int(inf.get("materiales", 0)) == 1 else "es"]
	if int(inf.get("perdido", 0)) > 0:
		t += ", y se dejaron %d por peso (mándales una mochila mejor)" % int(inf["perdido"])
	return t + ". Está en el almacén; lo aprendido, en el altar."


# --- El formulario de "Mandar uno" ---
#
# Trabaja sobre FICHAS del roster (dicts), no sobre PersonajeData, y es el MISMO camino en solitario
# y en multi: en solitario el roster se construye al vuelo de tu plantilla, y de cliente llega del
# host. Tiene que ser asi porque el invitado NO tiene los PersonajeData de los personajes de su
# compañero -- viven en la maquina del host -- y aun asi puede mandarlos.
func _build_encargos_nuevo() -> void:
	var libres: Array = _libres_del_hogar()
	_purgar_seleccion(libres)

	# --- Izquierda: a qué van, dónde y cuánto.
	MenuScaffold.titulo(_lista, "Tipo de encargo", 14)
	var etiquetas: Array = []
	var marcados: Array = []
	for t in range(0, int(Encargos.Tipo.BICHO) + 1):
		etiquetas.append("%s %s" % ["☑" if _enc_tipos.has(t) else "☐",
			String(Encargos.NOMBRE_TIPO.get(t, "?"))])
		marcados.append(t)
	MenuScaffold.cuadricula(_lista, etiquetas, -1, func(i: int):
		var t: int = int(marcados[i])
		if _enc_tipos.has(t):
			if _enc_tipos.size() > 1:      # siempre tiene que quedar uno marcado
				_enc_tipos.erase(t)
		else:
			_enc_tipos.append(t)
		_rebuild(), 3, Vector2(150, 34))
	if _enc_tipos.size() > 1:
		MenuScaffold.nota(_lista, "Con %d marcados reparten el tiempo: menos de cada cosa, y lo que "
			% _enc_tipos.size() + "aprenden se reparte entre varias habilidades.")

	MenuScaffold.titulo(_lista, "Piso", 14)
	# HASTA DONDE HAS LLEGADO, que es la libreta del mapa (los pisos traidos a salvo al pueblo).
	# Antes se preguntaba a Game.pisos_desbloqueados(), que NO es eso: es la lista de ATAJOS
	# abiertos por jefes, y como solo hay jefes en el 6 y en el 12, devolvia [1] hasta matar al Rey
	# Slime. Con cuatro pisos explorados el selector no se movia del 1.
	var tope: int = 1
	for p in Game.mapa_visible().keys():
		tope = maxi(tope, int(p))
	var fila_piso := HBoxContainer.new()
	_lista.add_child(fila_piso)
	_enc_piso = clampi(_enc_piso, 1, tope)
	MenuScaffold.stepper(fila_piso, _enc_piso, 1, tope, func(v: int):
		_enc_piso = v
		_rebuild())
	for t in _enc_tipos:
		_linea_materiales(int(t), _enc_piso)

	MenuScaffold.titulo(_lista, "Cuánto tiempo", 14)
	var horas: Array = []
	for d in Encargos.DURACIONES:
		horas.append("%d hora%s" % [int(d) / 3600, "" if int(d) == 3600 else "s"])
	MenuScaffold.cuadricula(_lista, horas, _enc_dur, func(i: int):
		_enc_dur = i
		_rebuild(), 3, Vector2(130, 36))

	# --- Derecha: quién va, con qué, y el pronóstico.
	_build_encargo_gente(libres)
	_build_encargo_utiles()
	_build_encargo_pronostico(libres)


# Lo que sale de un tipo en un piso, con CADA MATERIAL DE SU COLOR (el de su rango: gris el bruto,
# verde el veteado, azul el profundo...). No se usa MaterialTable.resumen porque devuelve una String
# pelada y aqui hace falta un Label por material para poder teñirlos; y asi ademas el mismo codigo
# sirve para los enemigos, que no tienen MaterialTable.
const MATS_A_LA_VISTA := 6

func _linea_materiales(tipo: int, piso: int) -> void:
	var pool: Array = Encargos.opciones(tipo, piso)
	if pool.is_empty():
		MenuScaffold.nota(_lista, "%s: nada que sacar en este piso." % String(Encargos.NOMBRE_TIPO[tipo]))
		return
	var total: float = 0.0
	for o in pool:
		total += float(o["peso"])
	pool.sort_custom(func(a, b): return float(a["peso"]) > float(b["peso"]))

	var flujo := HFlowContainer.new()
	flujo.add_theme_constant_override("h_separation", 4)
	flujo.add_theme_constant_override("v_separation", 0)
	_lista.add_child(flujo)

	var cab := Label.new()
	cab.text = "%s:" % String(Encargos.NOMBRE_TIPO[tipo])
	cab.add_theme_font_size_override("font_size", 12)
	cab.add_theme_color_override("font_color", GRIS)
	flujo.add_child(cab)

	var n: int = mini(pool.size(), MATS_A_LA_VISTA)
	for i in n:
		var o := pool[i] as Dictionary
		var m := o["material"] as MaterialData
		var l := Label.new()
		l.text = "%s %s%%%s" % [m.nombre,
			snappedf(100.0 * float(o["peso"]) / maxf(0.001, total), 0.1),
			"" if i == n - 1 else ","]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", m.color_rango())
		flujo.add_child(l)
	if pool.size() > n:
		var mas := Label.new()
		mas.text = "y %d más ⓘ" % (pool.size() - n)
		mas.add_theme_font_size_override("font_size", 12)
		mas.add_theme_color_override("font_color", AMBAR)
		# El resto, al pasar el raton por encima. Los enemigos sueltan hasta 15 cosas distintas por
		# piso y listarlas todas en linea llenaba media pantalla, pero esconderlas del todo tampoco
		# vale: son las que decides al marcar la casilla.
		# OJO: un Label nace con MOUSE_FILTER_IGNORE, o sea que sin esto el tooltip nunca saldria.
		mas.mouse_filter = Control.MOUSE_FILTER_STOP
		var resto: PackedStringArray = []
		for i in range(n, pool.size()):
			var o := pool[i] as Dictionary
			resto.append("%s  %s%%" % [(o["material"] as MaterialData).nombre,
				snappedf(100.0 * float(o["peso"]) / maxf(0.001, total), 0.1)])
		mas.tooltip_text = "También pueden traer:\n" + "\n".join(resto)
		flujo.add_child(mas)


func _build_encargo_gente(libres: Array) -> void:
	MenuScaffold.titulo(_content, "Quién va (%d de %d)" % [_enc_uids.size(), Encargos.MIEMBROS_MAX], 14)
	if libres.is_empty():
		MenuScaffold.nota(_content, "No hay nadie libre en casa. Manda a alguien del equipo al hogar "
			+ "en la pestaña «Equipo», o contrata gente en la taberna.")
		return
	for f in libres:
		var ficha := f as Dictionary
		var uid: String = String(ficha.get("uid", ""))
		var t: Dictionary = _tarjeta(_content)
		var fila: HBoxContainer = t["info"]
		fila.add_child(_punto_color(ficha.get("color", Color.WHITE)))
		var l := Label.new()
		# En mundo compartido, de quién es. Sin esto no sabes a quién le estás prestando la gente.
		var de_quien: String = ""
		if Net.activo and String(ficha.get("dueno", "")) != Identidad.id:
			de_quien = "  (de %s)" % String(ficha.get("dueno_nombre", "tu compañero"))
		l.text = "%s  ·  Nv.%d  ·  Poder %d%s" % [String(ficha.get("nombre", "?")),
			int(ficha.get("level", 1)), int(ficha.get("poder", 0)), de_quien]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if de_quien != "":
			l.add_theme_color_override("font_color", GRIS)
		fila.add_child(l)
		var b := Button.new()
		var va: bool = _enc_uids.has(uid)
		b.text = "Quitar" if va else "Que vaya"
		b.disabled = not va and _enc_uids.size() >= Encargos.MIEMBROS_MAX
		b.pressed.connect(func():
			if _enc_uids.has(uid):
				_enc_uids.erase(uid)
			else:
				_enc_uids.append(uid)
			_rebuild())
		(t["botones"] as HBoxContainer).add_child(b)
		# Las ordenes solo tienen sentido para el que va: al que dejas en casa no le mandas nada.
		if va:
			_build_ordenes(t["caja"] as VBoxContainer, ficha)


# Las dos ordenes que le das a UNA persona: a que va, y con que pelea.
#
# La de CLASE sale siempre, aunque no los mandes a por bichos: ahi abajo hay bichos igual y de esa
# pelea se llevan excelia. La de FAENA solo tiene sentido si hay mas de un tipo marcado (con uno
# solo no hay nada que elegir).
func _build_ordenes(caja: VBoxContainer, ficha: Dictionary) -> void:
	var uid: String = String(ficha.get("uid", ""))

	# OJO con el ancho: estas cuadrículas van DENTRO de una tarjeta de la columna derecha, que es
	# estrecha. Con ancho mínimo la rejilla empuja la columna entera fuera de la pantalla, así que se
	# deja en 0 y que el EXPAND_FILL reparta lo que haya.
	# A qué va es MULTISELECCIÓN, como el "Tipo de encargo" de la izquierda: a uno le puedes mandar a
	# pescar Y a por bichos. Sin nada marcado va a lo que haga falta, que es lo de siempre.
	# SALE SIEMPRE, tambien con un solo tipo marcado. Antes se escondia con uno solo porque "no hay
	# nada que elegir", y con la vieja formula era verdad. Desde que la calidad va por la MEDIA de los
	# que trabajan ese tipo (ver Encargos.poder_recolector_de), marcar decide QUIEN lo trabaja aunque
	# el tipo sea uno: mandar a las vetas solo al fuerte sube la calidad del mineral, y dejarlo sin
	# marcar la baja con la media de los cuatro. Es una decision de verdad y tiene que verse.
	if not _enc_tipos.is_empty():
		var suyas: Array = _enc_faena.get(uid, [])
		var et: Array = []
		var vals: Array = []
		var tips_f: Array = []
		for t in _enc_tipos:
			var n: String = String(Encargos.NOMBRE_TIPO.get(int(t), "?"))
			et.append("%s %s" % ["☑" if suyas.has(int(t)) else "☐", n])
			vals.append(int(t))
			tips_f.append("Trabaja %s. La calidad sale de la media de los que van a esto." % n.to_lower())
		MenuScaffold.nota(caja, "A qué va" if not suyas.is_empty()
			else "A qué va  ·  sin marcar nada, a lo que haga falta")
		MenuScaffold.cuadricula(caja, et, -1, func(i: int):
			var lista: Array = (_enc_faena.get(uid, []) as Array).duplicate()
			var t: int = int(vals[i])
			if lista.has(t):
				lista.erase(t)
			else:
				lista.append(t)
			_enc_faena[uid] = lista
			_rebuild(), 3, Vector2(0, 26), [], [], tips_f)

	# Las clases DISPONIBLES viajan ya calculadas en la ficha del roster: dependen de lo que lleve
	# puesto, y de los personajes del compañero no tenemos el equipo (solo lo que publica el host).
	var disp: Array = ficha.get("clases", [int(Encargos.Clase.GUERRERO)])
	var et_c: Array = []
	var vals_c: Array = []
	var off: Array = []
	var tips: Array = []
	for c in Encargos.Clase.values():
		if not disp.has(int(c)):
			off.append(vals_c.size())   # `deshabilitados` va por INDICE, no por booleano
		et_c.append(String(Encargos.ABREV_CLASE.get(c, "?")))
		vals_c.append(int(c))
		# El nombre entero siempre en el tooltip (la casilla va abreviada), y si no puede, el motivo.
		tips.append(String(Encargos.NOMBRE_CLASE.get(c, "?")) if disp.has(int(c))
			else String(Encargos.REQUISITO_CLASE.get(c, "")))
	# Por defecto, la primera que SI puede: nunca se queda sin clase ni con una imposible.
	var actual: int = int(_enc_clase.get(uid, int(disp[0]) if not disp.is_empty() else 0))
	if not disp.has(actual):
		actual = int(disp[0]) if not disp.is_empty() else int(Encargos.Clase.GUERRERO)
	# Se deja escrito el que se está enseñando: si no, quien no toque la fila mandaría al personaje
	# con la clase por defecto del host en vez de con la que ve marcada en pantalla.
	_enc_clase[uid] = actual
	MenuScaffold.nota(caja, "Con qué pelea")
	MenuScaffold.cuadricula(caja, et_c, vals_c.find(actual), func(i: int):
		_enc_clase[uid] = int(vals_c[i])
		_rebuild(), 3, Vector2(0, 26), [], off, tips)


func _build_encargo_utiles() -> void:
	MenuScaffold.titulo(_content, "Útiles del cofre", 14)
	var hay: bool = false
	# Net.cofre_visible() y no Game.cofre_equipo: de cliente el cofre del hogar es el del HOST.
	for entrada_ in Net.cofre_visible():
		var entrada := entrada_ as Dictionary
		var clase: String = String(entrada.get("clase", ""))
		if clase != "herramienta" and clase != "mochila":
			continue
		hay = true
		var id: int = int(entrada.get("id", -1))
		var ocupada: int = int(entrada.get("encargo", 0))
		var tar: Dictionary = _tarjeta(_content)
		var fila: HBoxContainer = tar["info"]
		var l := Label.new()
		l.text = String(entrada.get("desc", "?"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Lo que APORTA a este encargo, para que se vea por qué merece la pena mandarla.
		var aporta: String = ""
		if clase == "mochila":
			aporta = "+%.0f kg" % Encargos.capacidad_util(entrada)
		else:
			var mejor: float = 0.0
			for t in _enc_tipos:
				mejor = maxf(mejor, float(Encargos.mods_util(entrada, int(t))["afinidad"]))
			aporta = "+%.0f afinidad" % mejor if mejor > 0.0 else "no sirve para esto"
			if mejor <= 0.0:
				l.add_theme_color_override("font_color", GRIS)
		fila.add_child(l)
		var ap := Label.new()
		ap.text = aporta
		ap.add_theme_color_override("font_color", VERDE if aporta.begins_with("+") else GRIS)
		fila.add_child(ap)
		var b := Button.new()
		var puesta: bool = _enc_utiles.has(id)
		b.text = "Quitar" if puesta else "Llevar"
		b.disabled = ocupada != 0
		if ocupada != 0:
			b.tooltip_text = "En uso en otro encargo."
		b.pressed.connect(func():
			if _enc_utiles.has(id):
				_enc_utiles.erase(id)
			else:
				_enc_utiles.append(id)
			_rebuild())
		(tar["botones"] as HBoxContainer).add_child(b)
	if not hay:
		MenuScaffold.nota(_content, "El cofre no tiene herramientas ni mochilas. Mete ahí las que "
			+ "quieras prestarles: mientras están fuera nadie puede sacarlas.")


func _build_encargo_pronostico(libres: Array) -> void:
	var fichas: Array = []
	for uid in _enc_uids:
		for f in libres:
			if String((f as Dictionary).get("uid", "")) == String(uid):
				fichas.append(f)
				break
	MenuScaffold.titulo(_content, "Pronóstico", 14)
	if fichas.is_empty():
		MenuScaffold.nota(_content, "Elige a alguien para ver cómo le iría.")
		return
	var poderes: Array = []
	for f in fichas:
		poderes.append(float((f as Dictionary).get("poder", 0)))

	var entradas: Array = []
	for id in _enc_utiles:
		for entrada in Net.cofre_visible():
			if int((entrada as Dictionary).get("id", -1)) == int(id):
				entradas.append(entrada)
				break

	# --- Eje 1: ¿vuelven bien?
	var pg: float = Encargos.poder_grupo_de(poderes)
	var req: float = Encargos.requisito_combate(_enc_piso)
	var probs: Array = Encargos.probs_desenlace(pg, _enc_piso)
	MenuScaffold.fila(_content, "Poder del grupo", "%d" % int(round(pg)))
	MenuScaffold.fila(_content, "El piso %d pide" % _enc_piso, "%d" % int(round(req)))
	var exito := Label.new()
	var pct: float = 100.0 * float(probs[0])
	exito.text = "ÉXITO %s   ·   a medias %s   ·   fracaso %s" % [
		Encargos.pct(float(probs[0])), Encargos.pct(float(probs[1])), Encargos.pct(float(probs[2]))]
	exito.add_theme_font_size_override("font_size", 16)
	exito.add_theme_color_override("font_color",
		VERDE if pct > 85.0 else (AMBAR if pct >= 60.0 else Color(0.90, 0.45, 0.40)))
	_content.add_child(exito)
	if pct < 60.0:
		MenuScaffold.nota(_content, "Van muy justos: ahí abajo hay bichos. Manda a más gente, o "
			+ "vísteles mejor antes de que salgan.")

	# --- Eje 2: qué traen.
	var dur: int = int(Encargos.DURACIONES[_enc_dur])
	var golpes: int = 0
	var afin_media: float = 0.0
	for t in _enc_tipos:
		var mejor: float = 0.0
		for entrada in entradas:
			var m: Dictionary = Encargos.mods_util(entrada as Dictionary, int(t))
			mejor = maxf(mejor, float(m["afinidad"]))
			golpes = maxi(golpes, int(m["golpes_menos"]))
		afin_media += mejor
	afin_media /= maxf(1.0, float(_enc_tipos.size()))

	var trabajadas: int = Encargos.unidades(dur, fichas.size(), golpes, 1.0)
	var tope: float = Encargos.tope_carga_de(_fuerzas(fichas), entradas)
	# Cuántas caben, con el peso medio de lo que van a traer.
	var peso_ud: float = _peso_medio_unidad()
	var caben: int = int(tope / maxf(0.1, peso_ud))
	MenuScaffold.fila(_content, "Trabajarán", "%d unidades" % trabajadas)
	MenuScaffold.fila(_content, "Les caben", "%d  (%.0f kg)" % [caben, tope])
	_build_reparto_botin(trabajadas)
	if caben < trabajadas:
		var faltan := Label.new()
		faltan.text = "Se dejarán ~%d por peso: mándales una mochila." % (trabajadas - caben)
		faltan.add_theme_color_override("font_color", Color(0.90, 0.45, 0.40))
		_content.add_child(faltan)

	# CALIDADES POR MATERIAL, nunca una media del tipo.
	# Una sola fila por "Vetas" era mentira: con 0 de Fuerza el cobre en bruto (exigencia 30) sale
	# casi siempre intacto y el veteado (150) no lo pillan ni de casualidad, y promediarlos daba un
	# "37% normal" que no le pasa a ningun material de verdad. Lo que decide la calidad es CADA
	# material, asi que se enseña material a material.
	_build_tabla_calidades(fichas, entradas, pg / req)

	# --- Mandar.
	var pega: String = Encargos.motivo_no_puede(_enc_tipos, entradas)
	if not pega.is_empty():
		var aviso := Label.new()
		aviso.text = pega
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		aviso.add_theme_color_override("font_color", Color(0.90, 0.45, 0.40))
		_content.add_child(aviso)
	var b := Button.new()
	b.text = "Mandarlos"
	b.disabled = not pega.is_empty()
	b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	b.pressed.connect(func():
		Net.solicitar_encargo(_enc_piso, _enc_tipos, dur, _enc_uids, _enc_utiles,
			_enc_faena.duplicate(), _enc_clase.duplicate())
		_aviso = "En marcha. Vuelven en %d h." % (dur / 3600)
		_aviso_ok = true
		_enc_uids.clear()
		_enc_utiles.clear()
		_enc_faena.clear()
		_enc_clase.clear()
		_enc_sub = 0
		_rebuild())
	_content.add_child(b)


# QUÉ PARTE DEL BOTÍN es cada material, para poder ver lo que van a traer SIN tener que mandarlos
# primero. Los tipos se reparten el rato a partes iguales, así que el % de cada material es el de su
# tipo por el peso que tiene dentro de su tabla: con seis tipos marcados, un tipo al 16,7% con dos
# materiales al 50/50 son dos materiales al 8,3%.
func _build_reparto_botin(trabajadas: int) -> void:
	var por_tipo: Dictionary = Encargos.repartir(trabajadas, _enc_tipos)
	var filas: Array = []
	for t in _enc_tipos:
		var tipo: int = int(t)
		var uds: int = int(por_tipo.get(tipo, 0))
		var cuota: float = float(uds) / maxf(1.0, float(trabajadas))
		var pool: Array = Encargos.opciones(tipo, _enc_piso)
		var peso_total: float = 0.0
		for o in pool:
			peso_total += float(o["peso"])
		for o in pool:
			var m := o["material"] as MaterialData
			filas.append({"etiqueta": m.nombre, "color": m.color_rango(), "orden": cuota
				* float(o["peso"]) / maxf(0.001, peso_total)})
	if filas.is_empty():
		return
	filas.sort_custom(func(a, b): return float(a["orden"]) > float(b["orden"]))
	var recorte: Array = filas.slice(0, CALIDADES_A_LA_VISTA)
	for f in recorte:
		(f as Dictionary)["valores"] = [Encargos.pct(float((f as Dictionary)["orden"]))]
	MenuScaffold.titulo(_content, "Cuánto de cada cosa", 13)
	MenuScaffold.rejilla_probs(_content, "Material", ["Del botín"], recorte)
	if filas.size() > recorte.size():
		MenuScaffold.nota(_content, "(y %d material%s más, con menos)" % [filas.size() - recorte.size(),
			"" if filas.size() - recorte.size() == 1 else "es"])


# Una fila por MATERIAL con la calidad que le sacarían. Se ordenan por exigencia (de lo fácil a lo
# difícil), que es como se lee la progresión de un vistazo: lo de arriba te lo traes entero y lo de
# abajo es lo que te falta stat para conseguir.
const CALIDADES_A_LA_VISTA := 8

func _build_tabla_calidades(fichas: Array, entradas: Array, r_combate: float) -> void:
	var filas: Array = []
	for t in _enc_tipos:
		var tipo: int = int(t)
		# La afinidad de la herramienta de ESE tipo (la mejor asignada), como en la resolución.
		var afin: float = 0.0
		for entrada in entradas:
			afin = maxf(afin, float(Encargos.mods_util(entrada as Dictionary, tipo)["afinidad"]))
		# SOLO los que van a ese tipo: si mandaste al fuerte a las vetas, el torpe que se fue a las
		# hierbas no le estropea el mineral. Con nadie asignado, la regla de Encargos devuelve a todos.
		var poder_reco: float = Encargos.poder_recolector_de(
			_stats(_fichas_faena(fichas, tipo), tipo), tipo, afin)
		var pool: Array = Encargos.opciones(tipo, _enc_piso)
		pool.sort_custom(func(a, b):
			return Game._exigencia_material(a["material"] as MaterialData, _enc_piso) \
				< Game._exigencia_material(b["material"] as MaterialData, _enc_piso))
		for o in pool:
			var m := o["material"] as MaterialData
			var margen: float = Encargos.margen_calidad(tipo, m, _enc_piso, poder_reco, r_combate)
			var q: Dictionary = Encargos.reparto_calidades(margen)
			filas.append({"etiqueta": m.nombre, "color": m.color_rango(), "valores": [
				Encargos.pct(float(q["intacto"])), Encargos.pct(float(q["normal"])),
				Encargos.pct(float(q["danado"]))]})
	if filas.is_empty():
		return
	# Con varios tipos marcados esto se va a treinta filas. Se enseñan las primeras y se dice cuántas
	# faltan: la tabla es para decidir, no para consultarla entera.
	var recorte: Array = filas.slice(0, CALIDADES_A_LA_VISTA)
	MenuScaffold.rejilla_probs(_content, "Qué calidad", ["Intacto", "Normal", "Dañado"], recorte)
	if filas.size() > recorte.size():
		MenuScaffold.nota(_content, "(y %d material%s más)" % [filas.size() - recorte.size(),
			"" if filas.size() - recorte.size() == 1 else "es"])


# Las stats que salen en las fichas del roster. Se leen del dict y no de PersonajeData porque de
# los personajes del compañero solo tenemos lo que publica el host.
func _fuerzas(fichas: Array) -> Array:
	var out: Array = []
	for f in fichas:
		out.append(float(((f as Dictionary).get("stats", {}) as Dictionary).get("fuerza", 0.0)))
	return out


# Las fichas de los que van a trabajar ESE tipo. La regla ("si no hay nadie asignado lo hacen
# todos") vive en Encargos y se llama desde aquí en vez de copiarla: el pronóstico y la resolución
# de verdad tienen que decir lo mismo o la tabla es mentira.
func _fichas_faena(fichas: Array, tipo: int) -> Array:
	var trabajan: Array = Encargos.uids_trabajando(_miembros_previstos(), tipo, _enc_uids)
	var out: Array = []
	for f in fichas:
		if trabajan.has(String((f as Dictionary).get("uid", ""))):
			out.append(f)
	return out if not out.is_empty() else fichas


# Los `miembros` tal y como van a quedar en el encargo, para poder preguntarle a Encargos con la
# misma forma de datos que usará la resolución.
func _miembros_previstos() -> Array:
	var out: Array = []
	for uid in _enc_uids:
		out.append({"uid": String(uid), "faenas": _enc_faena.get(uid, []),
			"clase": int(_enc_clase.get(uid, Encargos.Clase.GUERRERO))})
	return out


func _stats(fichas: Array, tipo: int) -> Array:
	var clave: String = String(Encargos.oficio_de(tipo)["stat"])
	var out: Array = []
	for f in fichas:
		out.append(float(((f as Dictionary).get("stats", {}) as Dictionary).get(clave, 0.0)))
	return out


# El peso de una unidad media de lo marcado, para poder decir cuántas caben ANTES de mandarlos.
func _peso_medio_unidad() -> float:
	var suma: float = 0.0
	var peso: float = 0.0
	for t in _enc_tipos:
		for o in Encargos.opciones(int(t), _enc_piso):
			var m: MaterialData = o["material"] as MaterialData
			suma += m.peso_base * 0.9 * float(o["peso"])   # 0.9 = calidad NORMAL, la mas comun
			peso += float(o["peso"])
	return suma / maxf(0.001, peso) if peso > 0.0 else 1.0


# ============================================================
#  EQUIPO: los que bajan (izquierda) y el banquillo (derecha)
# ============================================================

func _build_equipo() -> void:
	MenuScaffold.titulo(_header, "QUIÉN BAJA CONTIGO", 18)

	MenuScaffold.titulo(_lista, "El equipo (%d de %d)" % [Game.party.size(), Game.PARTY_MAX], 14)
	for i in Game.party.size():
		_fila_equipo(i)
	if Game.party.is_empty():
		MenuScaffold.nota(_lista, "No baja nadie. Si cierras así, %s (tu personaje original) se pone "
			% Game.original().nombre + "al frente solo: alguien tiene que llevar el cuerpo.")
	MenuScaffold.nota(_lista, "El de la 👑 va EN CABEZA: es el cuerpo que mueves por el mapa, el "
		+ "que recolecta y el que gasta aguante. Cada uno tiene su hueco fijo (su número); cambiar "
		+ "de cabeza con «Al frente» o las teclas 1/2/3 no los mueve de sitio.")

	MenuScaffold.titulo(_content, "En casa (%d)" % Game.en_el_banquillo().size(), 14)
	var banquillo: Array = Game.en_el_banquillo()
	if banquillo.is_empty():
		MenuScaffold.nota(_content, "No hay nadie esperando en casa. Se contrata gente en la taberna.")
	for pj in banquillo:
		_fila_banquillo(pj)


func _fila_equipo(i: int) -> void:
	var pj: PersonajeData = Game.party[i]
	var t: Dictionary = _tarjeta(_lista)
	var fila: HBoxContainer = t["botones"]

	(t["info"] as HBoxContainer).add_child(_punto(pj))

	var es_lider: bool = pj == Game.lider()
	var l := Label.new()
	# El numero es el de la tecla que lo pone en cabeza (1/2/3), y es FIJO: cada uno tiene su hueco.
	l.text = "%d. %s%s  ·  Nv.%d  ·  Poder %d" % [i + 1, "👑 " if es_lider else "", pj.nombre,
		pj.level, int(round(Encargos.poder(pj)))]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if es_lider:
		l.add_theme_color_override("font_color", AMBAR)
	(t["info"] as HBoxContainer).add_child(l)

	# Ponerlo EN CABEZA. Ya no reordena el equipo (las posiciones son fijas): solo mueve la corona,
	# lo mismo que hace su tecla. Deshabilitado si ya va delante.
	var frente := Button.new()
	frente.text = "👑 Al frente"
	frente.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	frente.disabled = es_lider
	frente.tooltip_text = "Ponlo en cabeza (tecla %d). El cuerpo que mueves pasa a ser el suyo." % (i + 1)
	frente.pressed.connect(func():
		if Game.cambiar_lider(i):
			_aviso = "%s va en cabeza." % pj.nombre
			_aviso_ok = true
			_avisar_cambio_lider()
			_rebuild())
	fila.add_child(frente)

	var fuera := Button.new()
	fuera.text = "A casa"
	fuera.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	# CUALQUIERA puede quedarse en casa, el original incluido, y el equipo puede quedarse vacio: al
	# cerrar el Hogar baja el original solo (ver _cerrar).
	fuera.tooltip_text = "Lo deja en el Hogar. No se despide a nadie: sigue en tu plantilla." \
		+ ("\nSi no dejas a nadie en el equipo, al cerrar bajará tu personaje original." \
			if Game.party.size() <= 1 else "")
	fuera.pressed.connect(func():
		if Game.sacar_del_equipo(pj):
			_aviso = "%s se queda en casa." % pj.nombre
			_aviso_ok = true
			_avisar_cambio_lider()
			_rebuild())
	fila.add_child(fuera)

	fila.add_child(_boton_aspecto(pj))


func _fila_banquillo(pj: PersonajeData) -> void:
	var t: Dictionary = _tarjeta(_content)
	var fila: HBoxContainer = t["botones"]

	(t["info"] as HBoxContainer).add_child(_punto(pj))

	# ¿Está fuera, de encargo? Entonces no se le puede tocar hasta que vuelva.
	var enc_id: int = Game.uid_de_encargo(String(pj.uid))
	var enc: Dictionary = Game.encargo_por_id(enc_id) if enc_id != 0 else {}
	var fuera_txt: String = ""
	if not enc.is_empty():
		fuera_txt = "  ·  De encargo (%s)" % ("¡de vuelta!" \
			if int(enc.get("estado", 0)) == Encargos.ESTADO_LISTO else Encargos.texto_restante(enc))

	var l := Label.new()
	l.text = "%s  ·  Nv.%d  ·  Poder %d%s" % [pj.nombre, pj.level,
		int(round(Encargos.poder(pj))), fuera_txt]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if enc_id != 0:
		l.add_theme_color_override("font_color", GRIS)
	(t["info"] as HBoxContainer).add_child(l)

	var dentro := Button.new()
	dentro.text = "Que baje"
	# En sesion multi el cupo puede ser menor que PARTY_MAX (Net.cupo_party; en solitario es 4).
	var cupo: int = mini(Game.PARTY_MAX, Net.cupo_party())
	dentro.disabled = Game.party.size() >= cupo or enc_id != 0
	if enc_id != 0:
		dentro.tooltip_text = "Está fuera, en un encargo. Recógelo primero."
	dentro.pressed.connect(func():
		if Game.meter_en_equipo(pj):
			_aviso = "%s se une al equipo." % pj.nombre
			_aviso_ok = true
			_rebuild()
		else:
			_aviso = "El equipo ya va lleno (%d)." % mini(Game.PARTY_MAX, Net.cupo_party())
			_aviso_ok = false
			_rebuild())
	fila.add_child(dentro)

	# Quedarse en casa NO le desequipa: lo suyo sigue siendo suyo y al volver a bajar sigue vestido.
	# Pero entonces su espada no se puede vender ni fundir ni ponersela a otro sin robarsela, asi que
	# hace falta una forma de reclamarla sin tener que meterlo otra vez en el equipo.
	var lleva: int = _piezas_puestas(pj)
	var quitar := Button.new()
	quitar.text = "Recoger su equipo"
	# Y estando de encargo tampoco: su equipo es lo que decide si vuelve entero, y el pronostico ya
	# se calculo con el puesto. Desnudarlo a media faena seria hacer trampa al reves.
	quitar.disabled = lleva == 0 or enc_id != 0
	quitar.tooltip_text = "Está fuera, en un encargo: no puedes desvestirle a media faena." \
		if enc_id != 0 else ("Le quita lo que lleve puesto y lo devuelve al baúl, para dárselo a " \
		+ "otro, venderlo o fundirlo." if lleva > 0 else "No lleva nada puesto.")
	quitar.pressed.connect(func():
		var n: int = Game.desequipar_todo(pj)
		_aviso = "%s deja %d pieza%s en el baúl." % [pj.nombre, n, "" if n == 1 else "s"]
		_aviso_ok = true
		_rebuild())
	fila.add_child(quitar)

	fila.add_child(_boton_aspecto(pj))


# Editar la CARA de cualquiera de los tuyos, esten en el equipo o en el banquillo. Antes solo el
# personaje de la ranura se podia retocar (desde el menu principal) y los companeros se quedaban
# con el aspecto del dia que los contrataste para siempre.
# TARJETA de una persona: los datos en una linea y los botones en OTRA, dentro de un panelito.
#
# Antes era todo una fila sola y no cabia: con tres botones detras del nombre, el ultimo se salia de
# la pantalla y no habia forma de pulsarlo. Poniendo los botones debajo cabe cualquier combinacion
# sin depender de lo largo que sea un nombre ni de cuantos botones lleve esa fila.
func _tarjeta(padre: VBoxContainer) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _fondo_tarjeta())
	padre.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	panel.add_child(caja)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	caja.add_child(info)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 4)
	caja.add_child(botones)
	# `caja` es el VBox entero: quien quiera colgar mas filas debajo de los botones (las ordenes de un
	# encargo, por ejemplo) las mete ahi.
	return {"info": info, "botones": botones, "caja": caja}


func _fondo_tarjeta() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.14, 0.85)
	sb.border_color = Color(0.30, 0.33, 0.40, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


func _boton_aspecto(pj: PersonajeData) -> Button:
	var b := Button.new()
	b.text = "Aspecto"
	b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	b.tooltip_text = "Cambia su cara, su pelo y su ropa. Ni su progreso ni su equipo se tocan."
	b.pressed.connect(func(): _editar_aspecto(pj))
	return b


func _editar_aspecto(pj: PersonajeData) -> void:
	CreadorPersonaje.abrir(self, "ASPECTO  ·  %s" % pj.nombre,
		"Solo cambia cómo se ve. Su progreso y su equipo no se tocan.",
		"Guardar cambios",
		{"nombre": pj.nombre, "color": pj.color, "metalico": pj.metalico,
			"color_alpha": pj.color_alpha, "imagen": pj.imagen,
			"piezas": pj.aspecto_completo()["piezas"]},
		func(nombre: String, asp: Dictionary):
			var limpio: String = nombre.strip_edges()
			pj.nombre = limpio if limpio != "" else pj.nombre
			pj.aplicar_aspecto(asp)
			# Repintar el cuerpo y el sequito: si no, el cambio no se ve hasta cambiar de escena.
			var jugador: Node = get_tree().get_first_node_in_group("player")
			if jugador != null and jugador.has_method("refrescar_grupo"):
				jugador.refrescar_grupo()
			# MULTI: y re-difundirlo, o el compañero no lo veria hasta cambiar de escena. Se anuncian
			# los DOS (lider y sequito) porque el editado puede ser cualquiera; es barato.
			if Net.activo:
				Net.anunciar_aspecto()
				Net.anunciar_grupo()
			_aviso = "%s cambia de aspecto." % pj.nombre
			_aviso_ok = true
			_rebuild())


# Cuantas piezas lleva puestas (para no ofrecer "recoger" a quien va desnudo).
func _piezas_puestas(pj: PersonajeData) -> int:
	var n: int = 0
	for slot in Game.EQUIP_SLOTS:
		if pj.get("equipped_" + slot) != null:
			n += 1
	return n


# El cuerpo del personaje, del tamaño de un icono: mismo color y mismo material que por el mapa.
func _punto(pj: PersonajeData) -> ColorRect:
	var punto := ColorRect.new()
	punto.custom_minimum_size = Vector2(18, 18)
	punto.color = pj.color
	punto.material = Game.material_de(pj)
	return punto


# El mismo punto pero SOLO con el color, para las filas que salen del roster: de un personaje de tu
# compañero no tienes el PersonajeData (ni su imagen), solo lo que el host publica.
func _punto_color(c: Variant) -> ColorRect:
	var punto := ColorRect.new()
	punto.custom_minimum_size = Vector2(18, 18)
	punto.color = c if c is Color else Color.WHITE
	return punto


# Tocar el orden del equipo puede cambiar QUIEN va en cabeza, y de eso dependen el cuerpo que se
# ve por el mapa, el aguante y la velocidad. Se le avisa al jugador para que se repinte solo.
func _avisar_cambio_lider() -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("refrescar_lider"):
		p.refrescar_lider()


# ============================================================
#  ALMACEN: guardar en casa lo que traes en la bolsa
# ============================================================

func _build_almacen() -> void:
	MenuScaffold.titulo(_header, "EL BAÚL DE CASA", 18)
	MenuScaffold.fila(_content, "En la bolsa", "%d materiales" % Game.materiales.size())
	MenuScaffold.fila(_content, "Guardado en casa", "%d materiales" % Game.almacen_materiales.size())
	MenuScaffold.nota(_content, "Los cristales NO se guardan: esos hay que venderlos en la tienda.")

	# LOS TRES EN UNA FILA. Son las tres cosas que se pueden hacer aqui y se comparan entre ellas
	# (guardar / recoger todo / recoger lo que quepa): en columna ocupaban tres renglones de pantalla
	# y parecian tres pasos de algo. Se reparten el ancho a partes iguales (EXPAND_FILL).
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(fila)

	# Etiquetas CORTAS y el matiz en el tooltip: tres botones en una fila no dan para una frase, y
	# el aviso de la sobrecarga ya esta escrito en la nota de abajo.
	var b := MenuScaffold.boton(fila, "Guardar todo", _on_guardar, not Game.materiales.is_empty())
	b.tooltip_text = "Deja en el baúl todo lo que traes en la bolsa."
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# EL CAMINO DE VUELTA. Hasta ahora del baul solo se salia vendiendo o crafteando, y hace falta
	# poder vaciarlo: al entrar en un mundo compartido solo viaja la BOLSA, asi que para llevarte tus
	# materiales al mundo de un companero primero tienes que recogerlos aqui.
	var vacio: bool = Game.almacen_materiales.is_empty()
	var todo := MenuScaffold.boton(fila, "Recoger TODO", _on_recoger.bind(true), not vacio)
	todo.tooltip_text = "Saca del baúl todo lo que hay, aunque te deje sobrecargado."
	todo.clip_text = true
	todo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cabe := MenuScaffold.boton(fila, "Recoger lo que quepa", _on_recoger.bind(false), not vacio)
	cabe.tooltip_text = "Saca solo lo que puedas cargar sin quedarte lento."
	cabe.clip_text = true
	cabe.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	MenuScaffold.fila(_content, "Tu carga", "%.1f / %.1f%s" % [
		Game.peso_actual(), Game.capacidad_carga(),
		"    ¡SOBRECARGADO!" if Game.esta_sobrecargado() else ""])
	MenuScaffold.nota(_content, "Ir sobrecargado no te bloquea: te mueves más lento, y cuanto "
		+ "más te pases, más. Para mudarte a un mundo compartido llévatelo todo y ya lo repartes allí.")


func _on_guardar() -> void:
	# MULTIJUGADOR: depositar toca el baul compartido -> coger el candado un momento, guardar y
	# soltarlo. Si tu companero esta en el taller, "ocupado".
	if Net.activo:
		if not await Net.abrir_taller():
			_aviso = "El hogar está ocupado (tu compañero está en el taller)."
			_aviso_ok = false
			_rebuild()
			return
		var n: int = Game.guardar_materiales_en_hogar()
		Net.cerrar_taller()
		_aviso = "Guardas %d materiales en casa." % n
		_aviso_ok = true
		_rebuild()
		return
	var n: int = Game.guardar_materiales_en_hogar()
	_aviso = "Guardas %d materiales en casa." % n
	_aviso_ok = true
	_rebuild()


# Sacar del baul a la bolsa. Mismo baile del candado que al depositar: en multi el baul es del host.
func _on_recoger(todo: bool) -> void:
	if Net.activo:
		if not await Net.abrir_taller():
			_aviso = "El hogar está ocupado (tu compañero está en el taller)."
			_aviso_ok = false
			_rebuild()
			return
		var n_multi: int = Game.recoger_materiales_del_hogar(todo)
		Net.cerrar_taller()
		_decir_recogida(n_multi, todo)
		return
	var n: int = Game.recoger_materiales_del_hogar(todo)
	_decir_recogida(n, todo)


# El aviso de la recogida dice lo que ha pasado de verdad: cuantos, si se quedaron fuera por peso, y
# si te has quedado sobrecargado (que no es un error, pero conviene saberlo antes de bajar).
func _decir_recogida(n: int, todo: bool) -> void:
	if n == 0:
		_aviso = "No hay nada guardado en casa." if todo \
			else "Ya vas cargado: recoger más te dejaría lento."
		_aviso_ok = false
	else:
		_aviso = "Recoges %d material%s." % [n, "" if n == 1 else "es"]
		if not Game.almacen_materiales.is_empty():
			_aviso += " Quedan %d en casa." % Game.almacen_materiales.size()
		if Game.esta_sobrecargado():
			_aviso += "  ¡Vas SOBRECARGADO: te moverás lento!"
		_aviso_ok = true
	_rebuild()


# ============================================================
#  BOTE del hogar (multi): dinero comun. Tu dinero de bolsillo sigue siendo tuyo.
# ============================================================

# La HUCHA, que es un apartado del cofre (el titulo grande lo pone _build_cofre).
func _build_bote() -> void:
	# Los otros apartados del cofre usan las dos columnas (lo tuyo / lo que hay dentro); este no, asi
	# que se esconde la de la lista o la fila de la cantidad se queda sin sitio y se sale por la
	# derecha.
	if _lista_scroll != null:
		_lista_scroll.visible = false
	MenuScaffold.titulo(_content, "La hucha de casa", 14)
	MenuScaffold.fila(_content, "En la hucha", "%d monedas" % Net.bote_visible())
	MenuScaffold.fila(_content, "En tu bolsillo", "%d monedas" % Game.money)
	var nota: String = "Guarda dinero en casa. " + ("En multijugador es común: deposita para que "
		+ "tu compañero pueda cogerlo." if Net.activo else "Se guarda con tu partida.")
	MenuScaffold.nota(_content, nota)

	# Cantidad escrita a mano; los dos botones siempre disponibles.
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_content.add_child(caja)

	var etq := Label.new()
	etq.text = "Cantidad:"
	etq.custom_minimum_size = Vector2(150, 0)
	etq.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	caja.add_child(etq)

	var le := LineEdit.new()
	le.text = _bote_input
	le.placeholder_text = "0"
	# Alto de dedo como todo lo demas, y ancho ACOTADO: estirado a toda la pantalla parecia el campo
	# de un formulario web, y aqui se escriben cuatro cifras.
	le.custom_minimum_size = Vector2(220, MenuScaffold.ALTO_BOTON)
	le.add_theme_font_size_override("font_size", 18)
	le.text_changed.connect(func(t: String): _bote_input = t)   # se conserva al re-dibujar
	caja.add_child(le)

	var dep := Button.new()
	dep.text = "Depositar"
	dep.custom_minimum_size = Vector2(150, MenuScaffold.ALTO_BOTON)
	dep.pressed.connect(func():
		var n: int = _cantidad_bote()
		if n <= 0:
			_aviso = "Escribe una cantidad."; _aviso_ok = false
		elif Net.depositar_bote(n):
			_aviso = "Depositas %d en el bote." % n; _aviso_ok = true
		else:
			_aviso = "No tienes tanto en el bolsillo."; _aviso_ok = false
		_rebuild())
	caja.add_child(dep)

	var ret := Button.new()
	ret.text = "Retirar"
	ret.custom_minimum_size = Vector2(150, MenuScaffold.ALTO_BOTON)
	ret.pressed.connect(func():
		var n: int = _cantidad_bote()
		if n <= 0:
			_aviso = "Escribe una cantidad."; _aviso_ok = false
		else:
			Net.retirar_bote(n)   # el host valida que hay tanto (si no, avisa por toast)
			_aviso = "Pides retirar %d del bote." % n; _aviso_ok = true
		_rebuild())
	caja.add_child(ret)


# Lee la cantidad escrita como entero (0 si no es un numero valido).
func _cantidad_bote() -> int:
	var t: String = _bote_input.strip_edges()
	return int(t) if t.is_valid_int() else 0


# ============================================================
#  COFRE del hogar (multi): equipo para traspasar, por apartados (ver COFRE_SUBS). Ver paso 3.
# ============================================================

func _build_cofre() -> void:
	MenuScaffold.titulo(_header, "COFRE COMPARTIDO", 18)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 8)
	_header.add_child(sub)
	for i in COFRE_SUBS.size():
		var b := Button.new()
		b.text = str(COFRE_SUBS[i][0])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)   # alto de dedo, como el resto
		b.button_pressed = (_cofre_sub == i)
		b.pressed.connect(func():
			_cofre_sub = i
			_rebuild())
		sub.add_child(b)

	_cofre_sub = clampi(_cofre_sub, 0, COFRE_SUBS.size() - 1)
	# 'sub_id' y no 'id': mas abajo cada entrada del cofre tiene su propio id (un numero).
	var sub_id: String = str(COFRE_SUBS[_cofre_sub][1])
	if sub_id == "consumibles":
		_build_cofre_consumibles()
		return
	if sub_id == "monedas":
		_build_bote()
		return

	# TUYAS (baul propio, sin equipar): se pueden depositar.
	MenuScaffold.titulo(_lista, "Tuyas (para depositar)", 14)
	# SIN TIPAR a proposito: en "utiles" se juntan dos arrays de clases distintas
	# (Array[BackpackData] + Array[ToolData]), y un .has() con la clase equivocada sobre un array
	# tipado no devuelve false: escupe un error del motor.
	var mias: Array = []
	match sub_id:
		"armas": mias = Game.owned_weapons.duplicate()
		"armaduras": mias = Game.owned_armor.duplicate()
		# La mochila y las tres herramientas son del GRUPO, no de un personaje, y ninguna se mejora:
		# van juntas en su propio apartado, igual que en el inventario ([I] -> Equipo).
		"utiles": mias = Game.owned_mochilas + Game.owned_tools
	var alguna := false
	for item in mias:
		# item_equipado y NO quien_lleva: la MOCHILA no vive en un equipped_* (es del GRUPO), asi que
		# quien_lleva no la ve y la que llevabas puesta salia aqui como suelta.
		if Game.item_equipado(item):
			continue   # equipada: no se deposita
		alguna = true
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		_lista.add_child(fila)
		var l := Label.new()
		l.text = Game.item_display_name(item)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", Game.color_rareza_de(item))
		fila.add_child(l)
		var meter := Button.new()
		meter.text = "Al cofre"
		meter.custom_minimum_size = Vector2(120, MenuScaffold.ALTO_BOTON)
		meter.pressed.connect(func():
			if Net.meter_en_cofre(item):
				_aviso = "Guardas %s en el cofre." % Game.item_display_name(item)
				_aviso_ok = true
			else:
				_aviso = "Esa pieza no se puede compartir (o la llevas puesta)."
				_aviso_ok = false
			_rebuild())
		fila.add_child(meter)
	if not alguna:
		MenuScaffold.nota(_lista, "No tienes piezas sueltas de este tipo para depositar.")

	# EN EL COFRE: se pueden sacar. La 'clase' la pone Game.serializar_equipo al depositar.
	MenuScaffold.titulo(_content, "En el cofre", 14)
	var clases: Array = COFRE_CLASES[sub_id]
	var hay := false
	for entrada in Net.cofre_visible():
		if not clases.has(str(entrada.get("clase", ""))):
			continue
		hay = true
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		_content.add_child(fila)
		var l := Label.new()
		l.text = str(entrada.get("desc", "?"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# La rareza viaja YA dentro de la entrada serializada (ver Game._item_a_dict del cofre), asi que
		# aqui no hay que reconstruir la pieza para saber de que color va su nombre.
		l.add_theme_color_override("font_color", Upgrades.rareza_color(int(entrada.get("rareza", 0))))
		# EN USO en un encargo: se ve en gris y no se puede sacar. El host lo rechaza igualmente
		# (ver Net._resolver_saca_cofre); esto es solo para no ofrecer un boton que no va a funcionar.
		var en_encargo: bool = int(entrada.get("encargo", 0)) != 0
		if en_encargo:
			l.text += "   · en un encargo"
			l.add_theme_color_override("font_color", GRIS)
		fila.add_child(l)
		var sacar := Button.new()
		sacar.text = "Sacar"
		sacar.custom_minimum_size = Vector2(120, MenuScaffold.ALTO_BOTON)
		sacar.disabled = en_encargo
		if en_encargo:
			sacar.tooltip_text = "Se la han llevado a un encargo. Vuelve cuando lo recojas."
		var id: int = int(entrada.get("id", 0))
		sacar.pressed.connect(func():
			Net.sacar_de_cofre(id)
			_aviso = "Sacas la pieza del cofre."
			_aviso_ok = true
			_rebuild())
		fila.add_child(sacar)
	if not hay:
		MenuScaffold.nota(_content, "El cofre está vacío para este tipo.")


# Submenu de Consumibles del cofre: pociones y grimorios (stackean). Depositar/sacar de 1 en 1.
func _build_cofre_consumibles() -> void:
	MenuScaffold.titulo(_lista, "Tuyos (para depositar)", 14)
	var alguno := false
	for c in Game.consumables:
		var cant: int = int(Game.consumables[c])
		if cant <= 0:
			continue
		alguno = true
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		_lista.add_child(fila)
		var l := Label.new()
		l.text = "%s  x%d" % [str(c.get("nombre")), cant]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var ruta: String = c.resource_path
		var meter := Button.new()
		meter.text = "Al cofre"
		meter.custom_minimum_size = Vector2(120, MenuScaffold.ALTO_BOTON)
		meter.pressed.connect(func():
			Net.meter_consumible_cofre(ruta, 1)
			_aviso = "Guardas 1 en el cofre."
			_aviso_ok = true
			_rebuild())
		fila.add_child(meter)
	if not alguno:
		MenuScaffold.nota(_lista, "No llevas pociones ni grimorios.")

	MenuScaffold.titulo(_content, "En el cofre", 14)
	var hay := false
	var consum: Dictionary = Net.cofre_consumibles_visible()
	for ruta in consum:
		var cant: int = int(consum[ruta])
		if cant <= 0:
			continue
		hay = true
		var c: Resource = load(ruta)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		_content.add_child(fila)
		var l := Label.new()
		l.text = "%s  x%d" % [str(c.get("nombre")) if c != null else ruta, cant]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var sacar := Button.new()
		sacar.text = "Sacar"
		sacar.custom_minimum_size = Vector2(120, MenuScaffold.ALTO_BOTON)
		sacar.pressed.connect(func():
			Net.sacar_consumible_cofre(ruta, 1)
			_aviso = "Sacas 1 del cofre."
			_aviso_ok = true
			_rebuild())
		fila.add_child(sacar)
	if not hay:
		MenuScaffold.nota(_content, "No hay consumibles en el cofre.")
