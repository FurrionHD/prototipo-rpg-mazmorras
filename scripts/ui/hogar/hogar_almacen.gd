# ============================================================
#  hogar_almacen.gd  --  seccion ALMACEN y COFRE del menu del HOGAR (ver home_menu.gd, que es el armazon).
#  Es un RefCounted y no un nodo: lo que pinta va en las zonas del armazon (hogar._lista, hogar._content...)
#  y el estado de la pantalla (el aviso, el guardia de _rebuild) vive alli, igual que las piezas de
#  combat.gd (combat_altas, combat_figuras...).
# ============================================================
extends RefCounted

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

var hogar = null   # el armazon (home_menu.gd). Sin tipo: con CanvasLayer no se ven sus variables


func _init(pantalla: CanvasLayer) -> void:
	hogar = pantalla

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

var _cofre_sub: int = 0   # indice dentro de COFRE_SUBS (el que MANDA es su id, no el numero)
var _bote_input: String = ""   # cantidad escrita en el bote (se conserva entre re-dibujos)


# ============================================================
#  ALMACEN: guardar en casa lo que traes en la bolsa
# ============================================================

func _build_almacen() -> void:
	MenuScaffold.titulo(hogar._header, "EL BAÚL DE CASA", 18)
	MenuScaffold.fila(hogar._content, "En la bolsa", "%d materiales" % Game.materiales.size())
	MenuScaffold.fila(hogar._content, "Guardado en casa", "%d materiales" % Game.almacen_materiales.size())
	MenuScaffold.nota(hogar._content, "Los cristales NO se guardan: esos hay que venderlos en la tienda.")

	# LOS TRES EN UNA FILA. Son las tres cosas que se pueden hacer aqui y se comparan entre ellas
	# (guardar / recoger todo / recoger lo que quepa): en columna ocupaban tres renglones de pantalla
	# y parecian tres pasos de algo. Se reparten el ancho a partes iguales (EXPAND_FILL).
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hogar._content.add_child(fila)

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

	MenuScaffold.fila(hogar._content, "Tu carga", "%.1f / %.1f%s" % [
		Game.peso_actual(), Game.capacidad_carga(),
		"    ¡SOBRECARGADO!" if Game.esta_sobrecargado() else ""])
	MenuScaffold.nota(hogar._content, "Ir sobrecargado no te bloquea: te mueves más lento, y cuanto "
		+ "más te pases, más. Para mudarte a un mundo compartido llévatelo todo y ya lo repartes allí.")


func _on_guardar() -> void:
	# MULTIJUGADOR: depositar toca el baul compartido -> coger el candado un momento, guardar y
	# soltarlo. Si tu companero esta en el taller, "ocupado".
	if Net.activo:
		if not await Net.hogar.abrir_taller():
			hogar._aviso = "El hogar está ocupado (tu compañero está en el taller)."
			hogar._aviso_ok = false
			hogar._rebuild()
			return
		var n: int = Game.guardar_materiales_en_hogar()
		Net.hogar.cerrar_taller()
		hogar._aviso = "Guardas %d materiales en casa." % n
		hogar._aviso_ok = true
		hogar._rebuild()
		return
	var n: int = Game.guardar_materiales_en_hogar()
	hogar._aviso = "Guardas %d materiales en casa." % n
	hogar._aviso_ok = true
	hogar._rebuild()


# Sacar del baul a la bolsa. Mismo baile del candado que al depositar: en multi el baul es del host.
func _on_recoger(todo: bool) -> void:
	if Net.activo:
		if not await Net.hogar.abrir_taller():
			hogar._aviso = "El hogar está ocupado (tu compañero está en el taller)."
			hogar._aviso_ok = false
			hogar._rebuild()
			return
		var n_multi: int = Game.recoger_materiales_del_hogar(todo)
		Net.hogar.cerrar_taller()
		_decir_recogida(n_multi, todo)
		return
	var n: int = Game.recoger_materiales_del_hogar(todo)
	_decir_recogida(n, todo)


# El aviso de la recogida dice lo que ha pasado de verdad: cuantos, si se quedaron fuera por peso, y
# si te has quedado sobrecargado (que no es un error, pero conviene saberlo antes de bajar).
func _decir_recogida(n: int, todo: bool) -> void:
	if n == 0:
		hogar._aviso = "No hay nada guardado en casa." if todo \
			else "Ya vas cargado: recoger más te dejaría lento."
		hogar._aviso_ok = false
	else:
		hogar._aviso = "Recoges %d material%s." % [n, "" if n == 1 else "es"]
		if not Game.almacen_materiales.is_empty():
			hogar._aviso += " Quedan %d en casa." % Game.almacen_materiales.size()
		if Game.esta_sobrecargado():
			hogar._aviso += "  ¡Vas SOBRECARGADO: te moverás lento!"
		hogar._aviso_ok = true
	hogar._rebuild()


# ============================================================
#  BOTE del hogar (multi): dinero comun. Tu dinero de bolsillo sigue siendo tuyo.
# ============================================================

# La HUCHA, que es un apartado del cofre (el titulo grande lo pone _build_cofre).
func _build_bote() -> void:
	# Los otros apartados del cofre usan las dos columnas (lo tuyo / lo que hay dentro); este no, asi
	# que se esconde la de la lista o la fila de la cantidad se queda sin sitio y se sale por la
	# derecha.
	if hogar._lista_scroll != null:
		hogar._lista_scroll.visible = false
	MenuScaffold.titulo(hogar._content, "La hucha de casa", 14)
	MenuScaffold.fila(hogar._content, "En la hucha", "%d monedas" % Net.hogar.bote_visible())
	MenuScaffold.fila(hogar._content, "En tu bolsillo", "%d monedas" % Game.money)
	var nota: String = "Guarda dinero en casa. " + ("En multijugador es común: deposita para que "
		+ "tu compañero pueda cogerlo." if Net.activo else "Se guarda con tu partida.")
	MenuScaffold.nota(hogar._content, nota)

	# Cantidad escrita a mano; los dos botones siempre disponibles.
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	hogar._content.add_child(caja)

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
			hogar._aviso = "Escribe una cantidad."; hogar._aviso_ok = false
		elif Net.hogar.depositar_bote(n):
			hogar._aviso = "Depositas %d en el bote." % n; hogar._aviso_ok = true
		else:
			hogar._aviso = "No tienes tanto en el bolsillo."; hogar._aviso_ok = false
		hogar._rebuild())
	caja.add_child(dep)

	var ret := Button.new()
	ret.text = "Retirar"
	ret.custom_minimum_size = Vector2(150, MenuScaffold.ALTO_BOTON)
	ret.pressed.connect(func():
		var n: int = _cantidad_bote()
		if n <= 0:
			hogar._aviso = "Escribe una cantidad."; hogar._aviso_ok = false
		else:
			Net.hogar.retirar_bote(n)   # el host valida que hay tanto (si no, avisa por toast)
			hogar._aviso = "Pides retirar %d del bote." % n; hogar._aviso_ok = true
		hogar._rebuild())
	caja.add_child(ret)


# Lee la cantidad escrita como entero (0 si no es un numero valido).
func _cantidad_bote() -> int:
	var t: String = _bote_input.strip_edges()
	return int(t) if t.is_valid_int() else 0


# ============================================================
#  COFRE del hogar (multi): equipo para traspasar, por apartados (ver COFRE_SUBS). Ver paso 3.
# ============================================================

func _build_cofre() -> void:
	MenuScaffold.titulo(hogar._header, "COFRE COMPARTIDO", 18)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 8)
	hogar._header.add_child(sub)
	for i in COFRE_SUBS.size():
		var b := Button.new()
		b.text = str(COFRE_SUBS[i][0])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)   # alto de dedo, como el resto
		b.button_pressed = (_cofre_sub == i)
		b.pressed.connect(func():
			_cofre_sub = i
			hogar._rebuild())
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
	MenuScaffold.titulo(hogar._lista, "Tuyas (para depositar)", 14)
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
		hogar._lista.add_child(fila)
		var l := Label.new()
		l.text = Game.item_display_name(item)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", Game.color_rareza_de(item))
		fila.add_child(l)
		var meter := Button.new()
		meter.text = "Al cofre"
		meter.custom_minimum_size = Vector2(120, MenuScaffold.ALTO_BOTON)
		meter.pressed.connect(func():
			if Net.hogar.meter_en_cofre(item):
				hogar._aviso = "Guardas %s en el cofre." % Game.item_display_name(item)
				hogar._aviso_ok = true
			else:
				hogar._aviso = "Esa pieza no se puede compartir (o la llevas puesta)."
				hogar._aviso_ok = false
			hogar._rebuild())
		fila.add_child(meter)
	if not alguna:
		MenuScaffold.nota(hogar._lista, "No tienes piezas sueltas de este tipo para depositar.")

	# EN EL COFRE: se pueden sacar. La 'clase' la pone Game.serializar_equipo al depositar.
	MenuScaffold.titulo(hogar._content, "En el cofre", 14)
	var clases: Array = COFRE_CLASES[sub_id]
	var hay := false
	for entrada in Net.hogar.cofre_visible():
		if not clases.has(str(entrada.get("clase", ""))):
			continue
		hay = true
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		hogar._content.add_child(fila)
		var l := Label.new()
		l.text = str(entrada.get("desc", "?"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# La rareza viaja YA dentro de la entrada serializada (ver Game._item_a_dict del cofre), asi que
		# aqui no hay que reconstruir la pieza para saber de que color va su nombre.
		l.add_theme_color_override("font_color", Upgrades.rareza_color(int(entrada.get("rareza", 0))))
		# EN USO en un encargo: se ve en gris y no se puede sacar. El host lo rechaza igualmente
		# (ver Net.hogar._resolver_saca_cofre); esto es solo para no ofrecer un boton que no va a funcionar.
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
			Net.hogar.sacar_de_cofre(id)
			hogar._aviso = "Sacas la pieza del cofre."
			hogar._aviso_ok = true
			hogar._rebuild())
		fila.add_child(sacar)
	if not hay:
		MenuScaffold.nota(hogar._content, "El cofre está vacío para este tipo.")


# Submenu de Consumibles del cofre: pociones y grimorios (stackean). Depositar/sacar de 1 en 1.
func _build_cofre_consumibles() -> void:
	MenuScaffold.titulo(hogar._lista, "Tuyos (para depositar)", 14)
	var alguno := false
	for c in Game.consumables:
		var cant: int = int(Game.consumables[c])
		if cant <= 0:
			continue
		alguno = true
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		hogar._lista.add_child(fila)
		var l := Label.new()
		l.text = "%s  x%d" % [str(c.get("nombre")), cant]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var ruta: String = c.resource_path
		var meter := Button.new()
		meter.text = "Al cofre"
		meter.custom_minimum_size = Vector2(120, MenuScaffold.ALTO_BOTON)
		meter.pressed.connect(func():
			Net.hogar.meter_consumible_cofre(ruta, 1)
			hogar._aviso = "Guardas 1 en el cofre."
			hogar._aviso_ok = true
			hogar._rebuild())
		fila.add_child(meter)
	if not alguno:
		MenuScaffold.nota(hogar._lista, "No llevas pociones ni grimorios.")

	MenuScaffold.titulo(hogar._content, "En el cofre", 14)
	var hay := false
	var consum: Dictionary = Net.hogar.cofre_consumibles_visible()
	for ruta in consum:
		var cant: int = int(consum[ruta])
		if cant <= 0:
			continue
		hay = true
		var c: Resource = load(ruta)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		hogar._content.add_child(fila)
		var l := Label.new()
		l.text = "%s  x%d" % [str(c.get("nombre")) if c != null else ruta, cant]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var sacar := Button.new()
		sacar.text = "Sacar"
		sacar.custom_minimum_size = Vector2(120, MenuScaffold.ALTO_BOTON)
		sacar.pressed.connect(func():
			Net.hogar.sacar_consumible_cofre(ruta, 1)
			hogar._aviso = "Sacas 1 del cofre."
			hogar._aviso_ok = true
			hogar._rebuild())
		fila.add_child(sacar)
	if not hay:
		MenuScaffold.nota(hogar._content, "No hay consumibles en el cofre.")
