# ============================================================
#  celda_kit.gd
#  LA CELDA DE UNA HABILIDAD O UNA MAGIA en la pantalla del kit (ver character_menu, seccion
#  Habilidades). Es la de arriba (una ranura del set) y la de abajo (algo que puedes colocar): las
#  dos son esta misma pieza, y lo unico que las separa es el campo 'es_ranura'.
#
#  LO QUE APORTA sobre un Button normal es ARRASTRAR Y SOLTAR, que es la unica forma comoda de
#  decidir EN QUE hueco va cada cosa. El boton de "Poner" mete en el primer hueco libre, y eso vale
#  para colocar; pero el orden de los cuatro es del jugador -- el hueco 1 es el que tiene mas a mano
#  en combate -- y para ordenarlos hace falta poder soltarlos donde uno quiera.
#
#  Godot lo resuelve con tres virtuales de Control: _get_drag_data (que empieza el arrastre y
#  devuelve lo que viaja), _can_drop_data (si este sitio lo admite) y _drop_data (soltarlo). No hay
#  que tocar eventos de raton: el motor lleva el gesto, tambien con el dedo.
#
#  Sigue siendo pulsable: un toque normal selecciona y saca la ficha a la derecha, como siempre. El
#  arrastre solo arranca si mueves; quien no descubra el gesto puede seguir usando los botones.
# ============================================================

extends Button
class_name CeldaKit

# El "paquete" que viaja mientras arrastras lleva esta marca. Sin ella, un arrastre de OTRA parte
# del juego (una celda del inventario) se dejaria soltar aqui y llegaria un Resource cualquiera.
const MARCA := "kit_personaje"

# EL PAQUETE QUE VUELA AHORA MISMO, y si alguna celda lo ha RECOGIDO. Son de la clase (no de cada
# celda) porque solo puede haber un arrastre a la vez, y hacen falta para lo unico que Godot no
# cuenta: SOLTAR EN NINGUNA PARTE.
#
# Quitar una arrastrandola fuera tiene que funcionar sueltes donde sueltes (en el fondo, en la
# ficha de la derecha, entre dos celdas), y no se puede resolver poniendo una zona de descarte
# debajo: al soltar, Godot sube por los padres del control que hay bajo el dedo pero PARA en el
# primero que tenga mouse_filter STOP -- y todos los contenedores del menu lo tienen. Asi que se
# hace al reves: la celda que recoge lo apunta aqui, y quien no vea la marca al terminar el gesto
# (NOTIFICATION_DRAG_END) sabe que se solto en el vacio. Ver character_menu._notification.
static var en_vuelo: Dictionary = {}
static var recogido: bool = false

var item: Resource = null      # lo que hay en la celda (null = ranura vacia)
var indice: int = -1           # su posicion: el hueco si es ranura, el orden si es del pool
var es_ranura: bool = false    # true = una de las ranuras del set; false = del monton de abajo
# Se llama al soltar algo encima: al_soltar.call(item_que_viene, indice_origen, era_ranura).
var al_soltar: Callable = Callable()
# Si esta celda deja que la arrastren. Una ranura vacia no: no hay nada que coger.
var arrastrable: bool = true

var _resaltada := false        # hay algo encima ahora mismo esperando a soltarse


func _ready() -> void:
	# La celda se pinta por encima del estilo del tema, igual que CeldaObjeto, para poder marcar el
	# "sueltalo aqui" sin depender de los styleboxes.
	draw.connect(_pintar_marca)
	# EN MOVIL, EL GESTO ES SUYO. La columna donde vive esta celda lleva "deslizar con el dedo"
	# (ArrastreScroll), que escucha en _input —o sea ANTES que la GUI— y se queda el gesto en cuanto
	# el dedo recorre 16 px... que es exactamente lo que hace quien arrastra una celda. Sin esta
	# marca, en el movil arrastrar una habilidad desplazaba la lista y no cogia nada.
	#
	# Solo si HAY algo que coger: sobre una ranura vacia el dedo tiene que poder seguir deslizando
	# la lista como en cualquier otra parte del menu.
	if arrastrable and item != null:
		set_meta(ArrastreScroll.META_ARRASTRE_PROPIO, true)


# --- ARRASTRAR ---

func _get_drag_data(_pos: Vector2) -> Variant:
	if not arrastrable or item == null:
		return null
	# LA VISTA PREVIA que sigue al cursor. Un Control suelto y no una copia del boton: el boton vive
	# dentro de un contenedor y reusarlo lo sacaria de su sitio.
	var vista := Label.new()
	vista.text = str(item.get("nombre"))
	vista.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	var caja := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.14, 0.19, 0.95)
	sb.border_color = Color(0.95, 0.72, 0.36)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	caja.add_theme_stylebox_override("panel", sb)
	caja.add_child(vista)
	set_drag_preview(caja)
	var paquete: Dictionary = {"marca": MARCA, "item": item, "indice": indice, "es_ranura": es_ranura}
	en_vuelo = paquete
	recogido = false
	return paquete


# --- SOLTAR ---

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or String((data as Dictionary).get("marca", "")) != MARCA:
		return false
	# Devolverla a SU PROPIA celda se acepta (aunque no se resalte: no va a pasar nada). Es como se
	# cancela un arrastre, y tiene que contar como recogido: si no, el "soltar en el vacio quita"
	# entenderia que la has tirado y te la quitaria justo cuando te habias arrepentido.
	if bool(data["es_ranura"]) == es_ranura and int(data["indice"]) == indice:
		return true
	_resaltar(true)
	return true


func _drop_data(_pos: Vector2, data: Variant) -> void:
	_resaltar(false)
	recogido = true   # alguien se ha quedado el paquete: ya no es un "soltar fuera"
	if not al_soltar.is_valid() or not (data is Dictionary):
		return
	al_soltar.call(data["item"] as Resource, int(data["indice"]), bool(data["es_ranura"]))


# Godot NO avisa de que el puntero se ha ido con el paquete a otra parte: _can_drop_data deja de
# llamarse y ya esta. Sin esto, la celda se quedaba encendida hasta el siguiente repintado.
func _notification(que: int) -> void:
	if que == NOTIFICATION_DRAG_END or que == NOTIFICATION_MOUSE_EXIT:
		_resaltar(false)


func _resaltar(si: bool) -> void:
	if _resaltada == si:
		return
	_resaltada = si
	queue_redraw()


func _pintar_marca() -> void:
	if not _resaltada:
		return
	# El borde ambar grueso y un velo claro: "aqui es donde va a caer". Se dibuja DESPUES del
	# stylebox del tema (el draw del Button ya ha pasado), asi que se ve por encima.
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.95, 0.72, 0.36, 0.14))
	draw_rect(r, Color(0.95, 0.72, 0.36), false, 2.0)
