# ============================================================
#  forge_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del HERRERO. Lo abre el herrero del pueblo (herrero.gd -> abrir()). Congela al
#  jugador via Game.inventory_open mientras esta abierto.
#
#  Cuatro pestañas:
#   1) FUNDIR  - mineral en bruto -> LINGOTES.
#   2) CHAPAS  - lingotes -> CHAPAS (lo que pide la armadura; el arma se golpea del lingote).
#      Las dos refinan igual: NO se mezclan calidades (N piezas de la MISMA calidad dan una de
#      esa calidad) y suben el contador de Metalurgia, que es lo que desbloquea la habilidad de
#      subirlo un escalon (hasta el PURO). El contador es OCULTO: no se pinta en el menu.
#   3) FORJAR  - eliges la pieza, el METAL (lingote para armas, chapa para armaduras: fija el
#      TIER) y cuanto metes de cada calidad, mas la FIBRA que la remata: MADERA si es un arma
#      (el mango) y CUERO si es una armadura, siempre de la altura del metal. Aqui SI se mezcla.
#      La RAREZA es una tirada y su tabla se pinta EN VIVO con el score real. Sube el contador
#      de Herreria.
#   4) MEJORAR - eliges una pieza de tu baul, un NUCLEO y una categoria. Cada nucleo cubre un
#      tramo de mejoras y dentro de el cada una cuesta un nucleo mas; al saltar al nucleo
#      siguiente la cuenta vuelve a empezar. Ademas del nucleo, gasta MATERIAL del tier de la
#      pieza (el nucleo es el permiso, pero la pieza hay que rehacerla).
#   5) DESHACER - la pieza vuelve a la fragua y recuperas la MITAD de lo que costo hacerla,
#      nucleos incluidos. La unica salida del equipo que no querias era venderlo.
#
#  Toda la MATH vive en Game/Forge; aqui solo se pinta y se derivan los numeros de los campos.
# ============================================================

extends CanvasLayer

# Este mismo menu vale para el HERRERO y para el CARPINTERO: cambia el juego de pestañas (`_tabs`)
# y algun texto, pero la maquinaria (forjar, refinar, la cuadricula) es la misma. El modo se fija
# ANTES de add_child (ver player.gd), asi _ready ya sabe cual es.
@export var modo: String = "herrero"   # "herrero" | "carpintero"

# Las pestañas van por ID (no por indice fijo): asi cada oficio enseña las suyas sin romper el
# dispatch. La etiqueta visible sale de TAB_LABEL.
const TAB_LABEL := {
	"fundir": "Fundir", "chapas": "Chapas", "hebillas": "Hebillas", "tablones": "Tablones",
	"forjar": "Forjar", "herramientas": "Herramientas",
	"mejorar": "Mejorar", "deshacer": "Deshacer", "reparar": "Reparar",
}
const TABS_HERRERO := ["fundir", "chapas", "hebillas", "forjar", "herramientas", "mejorar", "deshacer", "reparar"]
# El carpintero solo asierra tablones y forja armas magicas (bastones/varitas).
const TABS_CARPINTERO := ["tablones", "forjar"]
# Las pestañas con CUADRICULA de piezas (las demas ocupan el ancho entero).
const TABS_CON_GRID := ["forjar", "mejorar", "deshacer"]
# Los tres refinados de metal comparten pantalla (_build_refinar): solo cambian de que salen,
# en que se convierten y cuantos hacen falta.
enum Refinado { LINGOTE, CHAPA, HEBILLAS }
const SUBS_FORJA := ["Armas", "Secundarias", "Armaduras"]
# Dentro de Armaduras, un submenu por juego (si no, son 20 piezas de golpe en la cuadricula).
const ARMOR_LABELS := ["Cuero", "Hierro", "Hierro completo", "Placas"]

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]
# De mejor a peor (el enum NO esta ordenado: PURO se añadio al final para no romper partidas).
const CALIDADES := [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO,
	MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]

const CAT_ARMAS: Array[String] = [
	"res://resources/weapons/daga.tres",
	"res://resources/weapons/estoque.tres",
	"res://resources/weapons/espada_corta.tres",
	"res://resources/weapons/espada_larga.tres",
	"res://resources/weapons/maza_peq.tres",
	"res://resources/weapons/mandobles.tres",
	"res://resources/weapons/hacha_grande.tres",
	"res://resources/weapons/martillo_grande.tres",
	"res://resources/weapons/baston.tres",
]
const CAT_SECUNDARIAS: Array[String] = [
	"res://resources/shields/escudo_pequeno.tres",
	"res://resources/shields/escudo_normal.tres",
	"res://resources/shields/escudo_grande.tres",
	"res://resources/wands/varita.tres",
]
const ARMOR_TIPOS: Array[String] = ["cuero", "hierro", "hierro_completo", "placas"]

var _root: Control = null
var _header: VBoxContainer = null       # cabecera FIJA (titulo + pestañas)
var _lista: VBoxContainer = null        # cuadricula de piezas, con su propio scroll
var _scroll_lista: ScrollContainer = null
var _content: VBoxContainer = null      # panel de detalle, con el suyo
var _aviso_lbl: Label = null            # linea de aviso, de altura fija (no empuja el titulo)
var _tab_buttons: Array = []

var _tab: int = 0
var _sub: int = 0
var _sel: int = 0                  # pieza seleccionada (catalogo o baul)
var _stacks: Array = []
var _aviso: String = ""
var _aviso_ok: bool = true

# --- FUNDIR / CHAPAS ---
var _metal_idx: int = 0            # cual de Game.metales_forja() (se DERIVA de los dos de abajo)
# Selector en dos niveles: primero la gama (T1/T2/T3), luego el sub-tier dentro de ella.
var _metal_tier: int = 0
var _metal_sub: int = 0
var _madera_tier: int = 0
# --- TABLONES (carpintero) ---
var _madera_idx: int = 0           # cual de las maderas (T1/T2/T3)

# --- FORJAR ---
var _armor_idx: int = 0            # juego de armadura (submenu de la subpestaña Armaduras)
var _lingote_idx: int = 0          # metal elegido (indice en lingotes o chapas, misma lista)
# Una seleccion {calidad: cantidad} por INGREDIENTE (metal, madera, cuero...), en paralelo a
# Game.ingredientes_forja. Antes eran dos dicts sueltos (metal + fibra); ahora las armas llevan
# tres materiales, asi que va en lista y se trata todo con un bucle.
var _sel_forja: Array = []

# --- HERRAMIENTAS ---
var _herr_tipo: int = ToolData.Tipo.PICO   # cual de las tres se forja
# El metal va en DOS niveles, como en fundir/aserrar/curtir (MenuScaffold.selector_material): primero
# la gama (Metal T1/T2/T3) y luego la veta de esa gama. En plano eran siete botones repitiendo el
# tier ("T1 bruto, T1 veteado, T1 profundo, T2 bruto...") y escondian que el tier es el eje gordo.
var _herr_tier: int = 0
var _herr_sub: int = 0
var _sel_herr_met: Dictionary = {}
var _sel_herr_tab: Dictionary = {}

# --- MEJORAR ---
# El nucleo ya no se elige a mano (lo pone Game.nucleo_auto por el +N); solo queda la categoria.
var _cat_idx: int = 0


func _es_carpintero() -> bool:
	return modo == "carpintero"

# Las pestañas de ESTE oficio, por id.
func _tabs() -> Array:
	return TABS_CARPINTERO if _es_carpintero() else TABS_HERRERO


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("forge_menu" if not _es_carpintero() else "carpinteria_menu")

	# MULTI: si el compañero deposita, craftea o reserva material, hay que redibujar para que el
	# "disponible" cambie en vivo (los dos estamos en la profesion a la vez).
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(_on_cambio_externo)
	if Net.has_signal("reservas_cambiadas"):
		Net.reservas_cambiadas.connect(_on_cambio_externo)

	var titulo: String = "CARPINTERO" if _es_carpintero() else "HERRERO"
	var subtitulo: String = "Se asierra la madera en tablones y se forjan los bastones. Todo sale de lo que tengas guardado en el Hogar." if _es_carpintero() \
		else "Primero se funde el metal, después se golpea. Todo sale de lo que tengas guardado en el Hogar."
	var m: Dictionary = MenuScaffold.construir(self, titulo, subtitulo, _cerrar)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_scroll_lista = m["lista_scroll"]
	_content = m["content"]
	_aviso_lbl = m["aviso"]

	var ids: Array = _tabs()
	for i in ids.size():
		var b := Button.new()
		b.text = str(TAB_LABEL[ids[i]])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		(m["side"] as VBoxContainer).add_child(b)
		_tab_buttons.append(b)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	# MULTI: ya NO se coge el candado al abrir -> los dos podeis estar en la profesion a la vez. El
	# candado se coge solo el instante de crear (ver _crear_con_taller), y mientras tanto lo que
	# seleccionas se RESERVA para que el otro lo vea apartado (ver _claim_reserva).
	_tab = 0
	_sub = 0
	_sel = 0
	_aviso = ""
	_limpiar_seleccion()
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild()


func _ocupado() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("Un momento: tu compañero está creando algo justo ahora.")


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu(self)
	if Net.activo:
		Net.liberar_mis_reservas()   # suelto lo que tenia seleccionado: vuelve al pool del otro


# MULTI: el compañero tocó el baul o su reserva -> redibujo para que el disponible cambie en vivo.
func _on_cambio_externo() -> void:
	if _root != null and _root.visible:
		_rebuild()


# Coge el candado, ejecuta la accion de crafteo y lo suelta. Devuelve false si el compañero lo tiene
# justo en ese instante (crear es casi instantaneo, asi que el choque es rarisimo). En solitario no
# hay candado. La reserva se PUBLICA aparte (mientras seleccionas); esto es solo el consumo.
func _crear_con_taller(accion: Callable) -> bool:
	if Net.activo and not await Net.abrir_taller():
		_ocupado()
		return false
	accion.call()
	if Net.activo:
		Net.cerrar_taller()
	return true




func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _limpiar_seleccion() -> void:
	_sel_forja = []   # se redimensiona en _preview_forjar segun cuantos ingredientes tenga la pieza


func _on_tab(i: int) -> void:
	_tab = i
	_sub = 0
	_sel = 0
	_aviso = ""
	_limpiar_seleccion()
	_rebuild()


func _on_sub(i: int) -> void:
	_sub = i
	_sel = 0
	_limpiar_seleccion()
	_rebuild()


func _pick(i: int) -> void:
	_sel = i
	_limpiar_seleccion()   # otra pieza = otro coste: lo elegido antes ya no vale
	_rebuild()


# Guarda de REENTRADA. Este menu es el unico al que le llegan tres reconstrucciones que pueden
# pisarse: el focus_exited del stepper salta al liberar el LineEdit con foco (y su on_set acaba
# llamando aqui otra vez, a mitad de este mismo pintado), y encima Net.hogar_cambiado /
# reservas_cambiadas entran por red en cualquier momento — incluso disparadas por el propio
# _preview_forjar, que publica reserva mientras pinta. Reconstruir dentro de una reconstruccion
# pintaba la mitad de un menu sobre la otra mitad del anterior. Ver MenuScaffold.vaciar.
var _reconstruyendo: bool = false

# MULTI: lo que MI seleccion actual tiene apartado, {"mat_id|calidad": uds}. Lo rellena el build de la
# pestaña que reserve (forjar y herramientas hoy) y lo publica _rebuild_real UNA SOLA VEZ al final.
#
# Esa unica publicacion por rebuild es lo importante, no un detalle de estilo. Antes cada rebuild
# soltaba la reserva al empezar (`Net.reservar({})`) y el build la volvia a pedir: DOS reservas
# distintas, asi que la deduplicacion de Net.reservar nunca las cortaba. En el HOST daba igual (el
# eco es sincrono y lo descarta la guarda de reentrada de arriba), pero en el CLIENTE la respuesta de
# cada una llega en OTRO frame, cuando la guarda ya no esta puesta -> otro rebuild -> otras dos
# reservas -> cuatro respuestas... El trafico y los repintados se doblaban solos hasta que el juego
# se cerraba. Le pasaba a la pestaña de HERRAMIENTAS, que reserva y no estaba en la excepcion.
#
# Publicando una vez, con la pestaña que sea, el valor es ESTABLE entre rebuilds: la deduplicacion
# corta y no hay eco. Y una pestaña que no reserve deja el dict vacio, con lo que suelta lo que
# hubiera apartado sin necesidad de acordarse de hacerlo.
var _claim_reserva: Dictionary = {}

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


func _rebuild_real() -> void:
	for zona in [_header, _lista, _content]:
		MenuScaffold.vaciar(zona)
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	var ids: Array = _tabs()
	_tab = clampi(_tab, 0, ids.size() - 1)
	var id: String = str(ids[_tab])
	# Solo forjar/mejorar/deshacer tienen cuadricula de piezas; el resto ocupa el ancho entero.
	_scroll_lista.visible = id in TABS_CON_GRID
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	# MULTI: parto de "no tengo nada apartado". Lo que reserve esta pestaña lo apunta su build aqui.
	_claim_reserva = {}

	match id:
		"fundir": _build_refinar(Refinado.LINGOTE)    # mineral -> lingote
		"chapas": _build_refinar(Refinado.CHAPA)      # lingote -> chapa (armaduras)
		"hebillas": _build_refinar(Refinado.HEBILLAS) # lingote -> hebillas (mochilas)
		"tablones": _build_aserrar()                  # madera -> tablon (carpintero)
		"forjar": _build_forjar()
		"herramientas": _build_herramientas()
		"mejorar": _build_mejorar()
		"deshacer": _build_deshacer()                 # equipo -> material (recuperas la mitad)
		"reparar": _build_reparar()                   # mantenimiento: pagar por reparar el desgaste

	# Y AQUI, una sola vez, ya con la pestaña pintada: ver el comentario de _claim_reserva. Va al
	# final a proposito — que un build se corte antes de tiempo (sin metal conocido, sin tablon a
	# juego...) no puede dejarme material apartado a espaldas del compañero.
	if Net.activo:
		Net.reservar(_claim_reserva)


func _decir(txt: String, ok: bool = true) -> void:
	_aviso = txt
	_aviso_ok = ok


# ============================================================
#  Helpers de UI
# ============================================================

func _title(vb: VBoxContainer, txt: String, color: Color = AMBAR) -> void:
	MenuScaffold.titulo(vb, txt, 16, color)

func _row(vb: VBoxContainer, etiqueta: String, valor: String, color_valor: Variant = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(170, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if color_valor != null:
		v.add_theme_color_override("font_color", color_valor)
	row.add_child(v)
	vb.add_child(row)

# Fila de ATRIBUTO para el preview de mejora: etiqueta · valor actual · (+delta) en verde. El
# delta sale vacio si la mejora seleccionada no toca ese stat. El valor va a la derecha del
# nombre y el delta pegado, para que se lea "Ataque  42.0  (+4.2)".
func _row_attr(vb: VBoxContainer, etiqueta: String, valor: String, delta: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(170, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	row.add_child(v)
	if delta != "":
		var d := Label.new()
		d.text = delta
		d.add_theme_color_override("font_color", VERDE)
		row.add_child(d)
	vb.add_child(row)

func _note(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", GRIS)
	l.add_theme_font_size_override("font_size", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Sin ancho MINIMO: en el panel de detalle (que es estrecho) un minimo de 420 px empuja la
	# columna entera fuera de la pantalla. Que se ajuste a lo que haya y parta las lineas.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(l)

func _boton(vb: VBoxContainer, txt: String, cb: Callable, activo: bool = true) -> void:
	var b := Button.new()
	b.text = txt
	b.disabled = not activo
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	vb.add_child(b)


# Solo el METAL, sin la forma: "Lingote de cobre" / "Chapa de cobre" -> "Cobre". En los
# botones estrechos del panel de detalle lo que importa es cual de los tres metales es.
func _metal_corto(m: MaterialData) -> String:
	return MenuScaffold.metal_corto(m)


# Texto de una calidad (el enum no esta ordenado: siempre pasar por aqui).
func _cal_txt(cal: int) -> String:
	match cal:
		MaterialItem.Calidad.PURO: return "Puro"
		MaterialItem.Calidad.INTACTO: return "Intacto"
		MaterialItem.Calidad.NORMAL: return "Normal"
		MaterialItem.Calidad.DANADO: return "Dañado"
		_: return "Roto"

# Unidades de crafteo que aporta un item de esta calidad (puro 4 / intacto 3 / normal 2 / dañado 1).
func _uds(cal: int) -> int:
	return MaterialItem.crear(null, cal).unidades_crafteo()


# Las subpestañas van a la CABECERA: no se van con el scroll.
func _subpestanas(nombres: Array) -> void:
	MenuScaffold.pestanas(_header, nombres, _sub, _on_sub)
	_header.add_child(HSeparator.new())


# La cuadricula va a la columna de la LISTA y la ficha al panel de DETALLE: cada una con su
# scroll, y la cabecera quieta arriba.
# 'tam' sube a tres lineas en Mejorar, que ademas del nombre y el tier dice quien la lleva puesta.
func _grid_detail(labels: Array, preview: Callable, tam: Vector2 = Vector2(150, 44)) -> void:
	if labels.is_empty():
		_note(_content, "(nada por aquí)")
		return
	_sel = clampi(_sel, 0, labels.size() - 1)
	# Los colores salen de _stacks, la MISMA lista de la que salieron las etiquetas: asi no pueden
	# desalinearse del nombre que acompañan (ver MenuScaffold.colores_de).
	MenuScaffold.cuadricula(_lista, labels, _sel, _pick, 2, tam,
		MenuScaffold.colores_de(_stacks))
	preview.call(_content)


# EN QUE SLOT va esta pieza. Hace falta porque owned_weapons es Array[Resource] y lleva dentro
# armas, escudos y varitas mezclados: sin esto no se pueden separar por su sitio en el cuerpo.
func _slot_de(item: Resource) -> String:
	if item is ArmorData:
		# ArmorData.Slot (CASCO..BOTAS) es 1:1 con Game.ARMOR_SLOT_ORDEN, en el mismo orden.
		var i: int = int((item as ArmorData).slot)
		return String(Game.ARMOR_SLOT_ORDEN[i]) if i >= 0 and i < Game.ARMOR_SLOT_ORDEN.size() else "pecho"
	if item is BackpackData:
		return "mochila"
	if item is ToolData:
		return "herramienta"
	if item is ShieldData or item is WandData:
		return "off"
	return "main"


# Fila de subpestañas por SLOT. Son 7 (8 en Deshacer, con la mochila) y no caben en una fila de
# MenuScaffold.pestanas, que es un HBox y no envuelve: se usa la cuadricula, que es un Grid y las
# reparte en dos filas de cuatro sin que se salgan por el lado.
func _subpestanas_slot(slots: Array) -> void:
	var labels: Array = []
	for s in slots:
		var etq: String = "Arma" if s == "main" else 			("Mochila" if s == "mochila" else ("Herram." if s == "herramienta" else SLOT_NOMBRES[s]))
		labels.append(etq)
	MenuScaffold.cuadricula(_header, labels, _sub, _on_sub, 4, Vector2(0, 30))
	_header.add_child(HSeparator.new())


# ============================================================
#  Pestañas FUNDIR (mineral -> lingote) y CHAPAS (lingote -> chapa)
#  Son la MISMA operacion (refinar), asi que las pinta la misma funcion: solo cambian el
#  material de entrada, el de salida y cuantos hacen falta.
# ============================================================

func _build_refinar(que: int) -> void:
	# Solo los metales que CONOCES. Con una partida nueva no conoces ninguno, y entonces aqui no
	# hay nada que enseñar (ni siquiera una fila vacia: se dice y ya).
	var metales: Array = Game.metales_forja_conocidos()
	if metales.is_empty():
		_title(_header, _titulo_refinado(que))
		_note(_header, "No traes ningún metal. Baja a la mazmorra y pica una veta: el herrero no puede fundir lo que no tiene.")
		return
	var de_lingote: bool = que != Refinado.LINGOTE   # chapas y hebillas parten del lingote
	var clave: String = "lingote" if de_lingote else "mineral"
	var por_uno: int = _por_uno(que)

	_title(_header, _titulo_refinado(que))
	_note(_header, _nota_refinado(que, por_uno))
	_header.add_child(HSeparator.new())

	# HEBILLAS: solo el metal BASE de cada tier. La mochila no tiene banda de mejora, asi que su
	# sub-tier no tendria donde notarse (fabricar_mochila solo mira el tier), y batir hebillas de cobre
	# veteado seria gastar mejor metal para obtener exactamente lo mismo. Al quedar una sola opcion por
	# tier, selector_material esconde su segunda fila el solo.
	if que == Refinado.HEBILLAS:
		metales = metales.filter(func(m): return int((m["mineral"] as MaterialData).mejora_min) == 0)

	# Selector en DOS niveles (Metal T1/T2/T3 -> cual de esa gama). Ver
	# MenuScaffold.selector_material. Se le pasa la columna que toque (mineral para fundir,
	# lingote para batir) y luego se resuelve de vuelta a QUE FILA de la cadena es.
	var origen: MaterialData = MenuScaffold.selector_material(_content, _columna(metales, clave),
		"Metal", _metal_tier, _metal_sub, _on_metal_tier, _on_metal)
	if origen == null:
		return
	_metal_idx = _fila_de(metales, clave, origen)
	var destino: MaterialData = metales[_metal_idx][_clave_destino(que)]
	_content.add_child(HSeparator.new())

	_row(_content, "Sale", "%s  ·  Tier %d" % [destino.nombre, destino.tier])

	# Una fila por calidad: se ven TODAS las estandar del tier aunque tengas 0 (en gris), para saber
	# qué se puede hacer. El PURO solo aparece si YA lo tienes (no se recolecta: sale de refinar con
	# oficio). Cada fila trae su stepper editable + "Crear".
	var tengo_algo: bool = false
	for cal in CALIDADES:
		# DISPONIBLE (resta lo que el compañero tiene reservado): lo que puedo seleccionar de verdad.
		var tengo: int = Game.disponible_calidad_en_hogar(origen, int(cal))
		if int(cal) == MaterialItem.Calidad.PURO and tengo <= 0:
			continue
		tengo_algo = tengo_algo or tengo > 0
		var salen: int = tengo / maxi(1, por_uno)
		var c: int = int(cal)
		MenuScaffold.fila_refino(_content, "%s  ·  tienes %d  (máx %d)" % [_cal_txt(c), tengo, salen],
			salen, func(n: int) -> void: _on_refinar(que, c, n))
	if not tengo_algo:
		if de_lingote:
			_note(_content, "No tienes %s. Fúndelo primero en la pestaña Fundir." % origen.nombre.to_lower())
		else:
			_note(_content, "No tienes %s guardado en el Hogar. Pica vetas en la mazmorra y guárdalo al volver." % origen.nombre.to_lower())

	# Lo que ya tienes de la salida.
	_content.add_child(HSeparator.new())
	_title(_content, "En el almacén")
	var alguno: bool = false
	for cal in CALIDADES:
		var n: int = Game.items_calidad_en_hogar(destino, int(cal))
		if n > 0:
			alguno = true
			_row(_content, "%s (%s)" % [destino.nombre, _cal_txt(int(cal))],
				"%d  ·  %d unidades de forja" % [n, n * _uds(int(cal))])
	if not alguno:
		_note(_content, "Ningún %s todavía." % destino.nombre.to_lower())

	_estado_oficio(_content, "Metalurgia", Game.tiene_desarrollo("metalurgia"),
		"Tira por sacar el metal un escalón por encima de lo que metas (y con oficio de sobra, un intacto puede salir PURO).")


# --- Los tres refinados de metal, en tablas (la pantalla es la misma) ---

func _clave_destino(que: int) -> String:
	match que:
		Refinado.CHAPA: return "chapa"
		Refinado.HEBILLAS: return "hebillas"
		_: return "lingote"

func _por_uno(que: int) -> int:
	match que:
		Refinado.CHAPA: return Forge.LINGOTE_POR_CHAPA
		Refinado.HEBILLAS: return Forge.LINGOTE_POR_HEBILLAS
		_: return Forge.MINERAL_POR_LINGOTE

func _titulo_refinado(que: int) -> String:
	match que:
		Refinado.CHAPA: return "BATIR CHAPAS"
		Refinado.HEBILLAS: return "HACER HEBILLAS"
		_: return "FUNDIR"

func _nota_refinado(que: int, por_uno: int) -> String:
	match que:
		Refinado.CHAPA:
			return "%d lingote(s) = 1 chapa de la MISMA calidad. Las chapas son lo que pide la ARMADURA; el arma se golpea del lingote directamente." % por_uno
		Refinado.HEBILLAS:
			return "%d lingotes = 1 juego de hebillas de la MISMA calidad. Salen caras en metal (son muchos herrajes pequeños, y hay que hacerlos de uno en uno), y es lo que sujeta una MOCHILA: la cose el peletero." % por_uno
		_:
			return "%d minerales de la MISMA calidad = 1 lingote de esa calidad. No se mezclan: juntando dañados no sale un normal. Solo la Metalurgia puede regalarte un escalón." % por_uno


func _on_metal_tier(i: int) -> void:
	_metal_tier = i
	_metal_sub = 0   # al cambiar de gama se vuelve a la base: la de abajo ya no existe
	_rebuild()


func _on_metal(i: int) -> void:
	_metal_sub = i
	_rebuild()


# Una COLUMNA de la cadena de metales (los minerales, o los lingotes...). El selector trabaja con
# MaterialData sueltos; la cadena son filas.
func _columna(metales: Array, clave: String) -> Array:
	var out: Array = []
	for m in metales:
		out.append(m[clave])
	return out


# La vuelta: de un MaterialData a la FILA de la cadena a la que pertenece.
func _fila_de(metales: Array, clave: String, mat: MaterialData) -> int:
	for i in metales.size():
		if metales[i][clave] == mat:
			return i
	return 0


# El metal elegido ahora mismo, resolviendo los dos niveles.
func _metal_elegido(clave: String) -> MaterialData:
	var metales: Array = Game.metales_forja_conocidos()
	if metales.is_empty():
		return null
	var col: Array = _columna(metales, clave)
	var tiers: Array = MenuScaffold.tiers_de(col)
	if tiers.is_empty():
		return null
	var subs: Array = MenuScaffold.del_tier(col, int(tiers[clampi(_metal_tier, 0, tiers.size() - 1)]))
	if subs.is_empty():
		return null
	return subs[clampi(_metal_sub, 0, subs.size() - 1)] as MaterialData


func _on_refinar(que: int, cal: int, veces: int) -> void:
	var metales: Array = Game.metales_forja_conocidos()
	var clave: String = "mineral" if que == Refinado.LINGOTE else "lingote"
	var origen: MaterialData = _metal_elegido(clave)
	if origen == null:
		return
	_metal_idx = _fila_de(metales, clave, origen)
	# MULTI: coger el candado solo este instante (los dos podeis estar en la profesion a la vez).
	if Net.activo and not await Net.abrir_taller():
		_ocupado()
		_rebuild()
		return
	var n: int = 0
	match que:
		Refinado.CHAPA: n = Game.batir_chapa(origen, cal, veces)
		Refinado.HEBILLAS: n = Game.hacer_hebillas(origen, cal, veces)
		_: n = Game.fundir(origen, cal, veces)
	if Net.activo:
		Net.cerrar_taller()
	if n > 0:
		_decir("Sacas %d x %s de calidad %s." % [n,
			metales[_metal_idx][_clave_destino(que)].nombre.to_lower(),
			_cal_txt(cal).to_lower()])
	else:
		_decir("No te llega el material.", false)
	_rebuild()


# Linea de sabor del oficio, SIN numeros. El contador es OCULTO por diseño (es lo que decide si
# la habilidad te sale al subir de nivel), asi que aqui no se enseña ni el progreso ni el rango:
# solo, si ya la tienes, QUE hace. Bloqueada -> ni una palabra, ni el separador: el jugador no
# tiene que saber que la Metalurgia existe hasta que le aparezca en el altar.
# Los numeros se miran desde el panel de debug.
func _estado_oficio(vb: VBoxContainer, nombre: String, activa: bool, que_hace: String) -> void:
	if not activa:
		return
	vb.add_child(HSeparator.new())
	_row(vb, nombre, "activa")
	_note(vb, que_hace)


# ============================================================
#  Pestaña TABLONES (carpintero): madera cruda -> tablon. Misma operacion que fundir/curtir
#  (refinar), pero con maderas y con el oficio de Carpinteria.
# ============================================================

func _build_aserrar() -> void:
	# Solo las maderas que CONOCES (T1 siempre; T2/T3 al descubrirlas), como el metal del herrero.
	var maderas: Array = Game.maderas_conocidas()

	_title(_header, "ASERRAR TABLONES")
	_note(_header, "%d maderas de la MISMA calidad = 1 tablón de esa calidad. El tablón es el mango del arma; la madera cruda ya no va directa a la forja. No se mezclan calidades: solo la Carpintería puede regalarte un escalón." % Forge.MADERA_POR_TABLON)
	_header.add_child(HSeparator.new())

	if maderas.is_empty():
		_note(_content, "No conoces ninguna madera todavía. Tala árboles y enredaderas en la mazmorra y vuelve.")
		return

	# Selector en DOS niveles: arriba la gama (Madera T1/T2/T3), abajo cual de esa gama. Ver
	# MenuScaffold.selector_material: con los sub-tiers, una fila plana repetia el tier en cada
	# boton y se hacia ilegible.
	var origen: MaterialData = MenuScaffold.selector_material(_content, maderas, "Madera",
		_madera_tier, _madera_idx, _on_madera_tier, _on_madera)
	if origen == null:
		return
	var destino: MaterialData = Game.tablon_de(origen)
	var por_uno: int = Forge.MADERA_POR_TABLON
	_content.add_child(HSeparator.new())

	if destino == null:
		_note(_content, "Esta madera no tiene tablón definido.")
		return
	_row(_content, "Sale", "%s  ·  Tier %d" % [destino.nombre, destino.tier])

	var tengo_algo: bool = false
	for cal in CALIDADES:
		var tengo: int = Game.disponible_calidad_en_hogar(origen, int(cal))
		if int(cal) == MaterialItem.Calidad.PURO and tengo <= 0:
			continue
		tengo_algo = tengo_algo or tengo > 0
		var salen: int = tengo / maxi(1, por_uno)
		var c: int = int(cal)
		MenuScaffold.fila_refino(_content, "%s  ·  tienes %d  (máx %d)" % [_cal_txt(c), tengo, salen],
			salen, func(n: int) -> void: _on_aserrar(c, n))
	if not tengo_algo:
		_note(_content, "No tienes %s en el Hogar. Tala árboles y enredaderas en la mazmorra y guárdalo al volver." % origen.nombre.to_lower())

	_content.add_child(HSeparator.new())
	_title(_content, "En el almacén")
	var alguno: bool = false
	for cal in CALIDADES:
		var n: int = Game.items_calidad_en_hogar(destino, int(cal))
		if n > 0:
			alguno = true
			_row(_content, "%s (%s)" % [destino.nombre, _cal_txt(int(cal))],
				"%d  ·  %d unidades de forja" % [n, n * _uds(int(cal))])
	if not alguno:
		_note(_content, "Ningún %s todavía." % destino.nombre.to_lower())

	_estado_oficio(_content, "Carpintería", Game.tiene_desarrollo("carpinteria"),
		"Al aserrar, tira por sacar el tablón un escalón por encima de la madera que metas.")


func _on_madera_tier(i: int) -> void:
	_madera_tier = i
	_madera_idx = 0   # al cambiar de gama se vuelve a la base: la de abajo ya no existe
	_rebuild()


func _on_madera(i: int) -> void:
	_madera_idx = i
	_rebuild()


# La madera elegida ahora mismo, resolviendo los dos niveles. null si no conoces ninguna.
func _madera_elegida() -> MaterialData:
	var maderas: Array = Game.maderas_conocidas()
	var tiers: Array = MenuScaffold.tiers_de(maderas)
	if tiers.is_empty():
		return null
	var subs: Array = MenuScaffold.del_tier(maderas,
		int(tiers[clampi(_madera_tier, 0, tiers.size() - 1)]))
	if subs.is_empty():
		return null
	return subs[clampi(_madera_idx, 0, subs.size() - 1)] as MaterialData


func _on_aserrar(cal: int, veces: int) -> void:
	var origen: MaterialData = _madera_elegida()
	if origen == null:
		return
	if Net.activo and not await Net.abrir_taller():
		_ocupado()
		_rebuild()
		return
	var n: int = Game.aserrar(origen, cal, veces)
	if Net.activo:
		Net.cerrar_taller()
	if n > 0:
		_decir("Sacas %d x %s de calidad %s." % [n, Game.tablon_de(origen).nombre.to_lower(), _cal_txt(cal).to_lower()])
	else:
		_decir("No te llega el material.", false)
	_rebuild()


# ============================================================
#  Pestaña FORJAR
# ============================================================

# ¿Esta pieza es un arma MAGICA (baston/varita)? Las forja el CARPINTERO; el herrero, el resto.
func _es_magica(base: Resource) -> bool:
	return base is WandData or (base is WeaponData and (base as WeaponData).es_magica)


func _build_forjar() -> void:
	var rutas: Array = []
	if _es_carpintero():
		# El carpintero solo forja armas magicas: sin subpestañas, una lista pelada.
		_title(_header, "FORJAR BASTONES Y VARITAS")
		_header.add_child(HSeparator.new())
		for ruta in CAT_ARMAS + CAT_SECUNDARIAS:
			var b: Resource = load(ruta)
			if b != null and _es_magica(b):
				rutas.append(ruta)
	else:
		_title(_header, "FORJAR")
		_subpestanas(SUBS_FORJA)
		match _sub:
			0: rutas = _sin_magicas(CAT_ARMAS)          # las magicas se forjan en el carpintero
			1: rutas = _sin_magicas(CAT_SECUNDARIAS)
			2:
				# Submenu por JUEGO de armadura: las 20 piezas de golpe no se leen.
				_juegos_armadura()
				rutas = _rutas_armaduras(ARMOR_TIPOS[_armor_idx])

	_stacks = []
	for ruta in rutas:
		var base: Resource = load(ruta)
		if base != null:
			_stacks.append({"modelo": base})
	var labels: Array = []
	for s in _stacks:
		labels.append(str((s["modelo"] as Resource).get("nombre")))
	_grid_detail(labels, _preview_forjar)


# Quita de una lista de rutas las que sean armas magicas (van al carpintero, no al herrero).
func _sin_magicas(rutas: Array) -> Array:
	var out: Array = []
	for ruta in rutas:
		var b: Resource = load(ruta)
		if b != null and not _es_magica(b):
			out.append(ruta)
	return out


# Fila de botones con los cuatro juegos de armadura (tambien en la cabecera fija).
func _juegos_armadura() -> void:
	_armor_idx = clampi(_armor_idx, 0, ARMOR_TIPOS.size() - 1)
	MenuScaffold.pestanas(_header, ARMOR_LABELS, _armor_idx, _on_juego, 130)
	_header.add_child(HSeparator.new())


func _on_juego(i: int) -> void:
	_armor_idx = i
	_sel = 0
	_limpiar_seleccion()
	_rebuild()


func _rutas_armaduras(tipo: String) -> Array:
	var out: Array = []
	for slot in Game.ARMOR_SLOT_ORDEN:
		out.append("res://resources/armor/%s_%s.tres" % [tipo, slot])
	return out


func _preview_forjar(vb: VBoxContainer) -> void:
	var base: Resource = _stacks[_sel]["modelo"]
	var coste: Dictionary = Forge.coste(base)
	var usa_chapa: bool = bool(coste["usa_chapa"])
	# El metal de una ARMADURA son CHAPAS; el de un ARMA, lingotes.
	var metales: Array = Game.chapas_conocidas() if usa_chapa else Game.lingotes_conocidos()
	if metales.is_empty():
		_title(vb, str(base.get("nombre")))
		_note(vb, "No conoces ningún metal todavía. Pica una veta en la mazmorra y vuelve.")
		return
	_lingote_idx = clampi(_lingote_idx, 0, metales.size() - 1)
	var metal: MaterialData = metales[_lingote_idx]

	# INGREDIENTES de esta pieza con este metal (metal + madera + cuero...). Fuente unica: la usa
	# la math y esta UI. Si algun material es null, no existe a la altura del metal -> no forjable.
	var ings: Array = Game.ingredientes_forja(base, metal)
	var falta_algo: bool = false
	var nombres_ing: PackedStringArray = []
	for ing in ings:
		if ing["material"] == null:
			falta_algo = true
			nombres_ing.append("(nada a la altura de este metal)")
		else:
			nombres_ing.append((ing["material"] as MaterialData).nombre)
	# Redimensionar la seleccion a los ingredientes de esta pieza (una {} por ingrediente).
	if _sel_forja.size() != ings.size():
		_sel_forja = []
		for _i in ings.size():
			_sel_forja.append({})
	# MULTI: capar mi seleccion a lo DISPONIBLE (por si el compañero reservó de lo mismo mientras yo
	# lo tenia elegido) y apuntarla como reserva, para que el otro la vea apartada en vivo.
	_capar_y_apuntar_seleccion(ings)

	_title(vb, str(base.get("nombre")))
	if base is ArmorData:
		_row(vb, "Slot", ARMOR_SLOT_LABELS[clampi(int((base as ArmorData).slot), 0, 4)])
	_row(vb, "Lleva", ", ".join(nombres_ing))

	# --- El TIER de la pieza (lo pone el metal) ---
	# Los botones dicen el TIER y NADA mas. Lo que eliges aqui es el tier: solo entra un metal por tier
	# (lingotes_conocidos usa _formas_base), asi que el nombre del metal en cada boton era la palabra
	# que menos pintaba -- y encima ya esta escrito arriba, en la fila "Lleva", que lista los
	# ingredientes de verdad.
	#
	# Aqui habia ADEMAS una fila "Metal: Lingote de cobre -> Tier 1 (x1.00 al daño/defensa)" que
	# repetia el nombre (ya en "Lleva") y el tier (ya en el boton pulsado). Fuera entera: el
	# multiplicador se va al tooltip, que no gasta sitio, y donde de verdad se ve lo que aporta el tier
	# es en la ficha de la pieza acabada.
	#
	# Y al quedar la etiqueta corta se caen los DOS por fila que habia: aquello era porque "Lingote de
	# acero" no cabia en un panel estrecho, no una preferencia. Ahora van 4, como el resto de los
	# selectores del juego (MenuScaffold.COLUMNAS_SELECTOR).
	vb.add_child(HSeparator.new())
	var etiquetas: Array = []
	var apagados: Array = []
	var pistas: Array = []
	for i in metales.size():
		var m: MaterialData = metales[i]
		var tengo: int = Game.disponible_unidades_material_en_hogar(m)
		var t_m: int = Forge.tier_de_metal(m)
		etiquetas.append("T%d" % t_m)
		pistas.append("%s  ·  tienes %d unidades  ·  ×%.2f al daño/defensa" % [
			m.nombre, tengo, Game.tier_mult(t_m)])
		if tengo <= 0:
			apagados.append(i)
	# El tinte va por el RANGO del material. Hoy los tres son banda base, asi que salen los tres grises
	# (o sea, igual que sin tinte): se deja puesto para que el dia que entre un sub-tier en esta lista
	# ya diga lo que tiene que decir, sin acordarse de volver aqui.
	MenuScaffold.cuadricula(vb, etiquetas, _lingote_idx, _on_lingote,
		MenuScaffold.COLUMNAS_SELECTOR, MenuScaffold.TAM_SELECTOR,
		MenuScaffold.colores_de(metales), apagados, pistas)

	# Si a este metal le falta algun material a su altura, no hay nada que forjar: se corta y explica.
	if falta_algo:
		vb.add_child(HSeparator.new())
		_note(vb, "No hay con qué rematar una pieza de este metal. Una coraza de %s pide un cuero de su altura, y el único que se conoce es el de rata: sirve para el cobre y para nada más. Hasta que no aparezca una bestia con mejor piel, este metal solo vale para ARMAS." % _metal_corto(metal).to_lower())
		return

	# --- Contadores de material: uno por INGREDIENTE ---
	vb.add_child(HSeparator.new())
	for i in ings.size():
		_contadores(vb, ings[i]["material"], _sel_forja[i], int(ings[i]["uds"]))
	_note(vb, "Puro = 4 unidades · intacto = 3 · normal = 2 · dañado = 1. Meter buen material no abarata la pieza: mejora la RAREZA que te va a tocar.")

	# --- Tabla de rareza EN VIVO, con el score REAL (material + metal + herrería) ---
	vb.add_child(HSeparator.new())
	var score: float = Game.score_forja(base, metal, _sel_forja)
	var t := Label.new()
	t.text = "Rareza que puede salir"
	t.add_theme_color_override("font_color", AMBAR)
	vb.add_child(t)
	# La calidad que cuenta es la de lo que se GASTA (el sobrante no entra en la media). Sale de
	# Game y NO de restarle los bonos al score: score_final ya no es una suma (el metal se capa en
	# el techo del material recolectado), asi que restar daria un numero falso.
	# El empujon de la HERRERIA entra en el 'score' (y por tanto en las probabilidades de abajo,
	# que son las de verdad), pero NO se desglosa: el rango del oficio es oculto y ponerlo aqui
	# como un "+X%" lo cantaba.
	var material: float = Game.score_material_forja(base, metal, _sel_forja)
	# Lo que aporta el metal DE VERDAD: la diferencia entre tirar con el y sin el. Si ya vas por
	# encima del techo (llevas material puro), el metal no suma y aqui se ve un +0%.
	# El empujon de oficio es Carpinteria en las armas magicas, Herreria en el resto.
	var oficio_factor: float = Game.carpinteria_activa() if _es_magica(base) else Game.herreria_activa()
	var herr: float = Forge.bonus_herreria(oficio_factor)
	var met_ef: float = score - Forge.score_final(material, herr, 0.0)
	_note(vb, "Calidad del material %d%%  +  metal %+d%%" % [
		roundi(material * 100.0), roundi(met_ef * 100.0)])
	var probs: Array = Forge.probs_rareza(score)
	for i in probs.size():
		var p: float = float(probs[i])
		if p <= 0.0:
			continue
		_row(vb, Upgrades.rareza_nombre(i), "%s%%   (%d huecos de mejora)" % [
			str(snappedf(p * 100.0, 0.1)), Upgrades.rareza_slots(i)],
			Upgrades.rareza_color(i))

	vb.add_child(HSeparator.new())
	var acc := HBoxContainer.new()
	acc.add_theme_constant_override("separation", 8)
	var auto := Button.new()
	auto.text = "Auto (mejor primero)"
	auto.pressed.connect(_on_auto)
	acc.add_child(auto)
	var limpiar := Button.new()
	limpiar.text = "Limpiar"
	limpiar.pressed.connect(_on_limpiar)
	acc.add_child(limpiar)
	vb.add_child(acc)

	var ok: bool = Game.forja_valida(base, metal, _sel_forja)
	_boton(vb, "Forjar" if ok else "Faltan materiales", _on_forjar, ok)

	if _es_magica(base):
		_estado_oficio(vb, "Carpintería", Game.tiene_desarrollo("carpinteria"),
			"Empuja la tirada de rareza del arma mágica a tu favor, como si la madera fuera mejor de lo que es.")
	else:
		_estado_oficio(vb, "Herrería", Game.tiene_desarrollo("herreria"),
			"Empuja la tirada de rareza a tu favor, como si el metal fuera mejor de lo que es.")


# MULTI: capa mi seleccion de forja a lo DISPONIBLE (por si el compañero reservó de lo mismo) y la
# apunta como reserva. Aplana _sel_forja a {"mat_id|cal": count}. En solitario el capado no quita
# nada (disponible == lo que hay) y apuntar no lleva a ninguna parte.
#
# APUNTA, no publica: la publicacion es UNA por rebuild y la hace _rebuild_real al final (ver
# _claim_reserva). Publicar desde aqui era la mitad del bucle que colgaba a los clientes.
func _capar_y_apuntar_seleccion(ings: Array) -> void:
	var claim: Dictionary = {}
	for i in mini(ings.size(), _sel_forja.size()):
		var mat: MaterialData = ings[i]["material"]
		if mat == null:
			continue
		var sel: Dictionary = _sel_forja[i]
		for cal in sel.keys():
			var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))
			var n: int = clampi(int(sel[cal]), 0, disp)
			if n <= 0:
				sel.erase(cal)
			else:
				sel[cal] = n
				var clave: String = "%s|%d" % [mat.id, int(cal)]
				claim[clave] = int(claim.get(clave, 0)) + n
	_claim_reserva = claim


# Fila "material: −  n  +" por cada calidad que tengas en el baul.
func _contadores(vb: VBoxContainer, mat: MaterialData, sel: Dictionary, necesita: int) -> void:
	var uds: int = Game.uds_seleccion(sel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = mat.nombre
	k.custom_minimum_size = Vector2(170, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = "%d / %d unidades" % [uds, necesita]
	v.add_theme_color_override("font_color", VERDE if uds >= necesita else ROJO)
	row.add_child(v)
	vb.add_child(row)

	# Si te has pasado, decir QUE se va a gastar de verdad: el sobrante se queda en el baul. Y
	# de lo que se gasta, las unidades que sobren del ultimo trozo pueden volver (el recorte).
	if uds >= necesita and necesita > 0:
		var gasto: Dictionary = Game.recortar_seleccion(sel, necesita)
		var gastadas: int = Game.uds_seleccion(gasto)
		var partes: PackedStringArray = []
		for cal in CALIDADES:
			var n: int = int(gasto.get(cal, 0))
			if n > 0:
				partes.append("%d %s" % [n, _cal_txt(int(cal)).to_lower()])
		var txt: String = "   Se gastarán %s (%d uds)" % [", ".join(partes), gastadas]
		if uds > gastadas:
			txt += "; el resto se queda en el Hogar"
		var sobra: int = gastadas - necesita
		if sobra > 0:
			txt += ".  Sobran %d uds del recorte: vuelven al Hogar como %d dañado(s)" % [sobra, sobra]
		_note(vb, txt + ".")

	var hubo: bool = false
	for cal in CALIDADES:
		# DISPONIBLE (resta lo reservado por el otro): el tope del stepper de cada calidad.
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))
		if disp <= 0:
			continue
		hubo = true
		var cur: int = int(sel.get(cal, 0))
		var ci: int = int(cal)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var lab := Label.new()
		lab.text = "   %s  (tienes %d)" % [_cal_txt(ci), disp]
		lab.custom_minimum_size = Vector2(190, 0)
		r.add_child(lab)
		MenuScaffold.stepper(r, cur, 0, disp, func(n: int) -> void: _set_sel_mat(sel, ci, disp, n))
		vb.add_child(r)
	if not hubo:
		_note(vb, "   No tienes %s en el Hogar." % mat.nombre.to_lower())


# Fija (absoluto) la cantidad elegida de `cal` en la seleccion `sel`, acotada a `disp`. Lo llama el
# stepper editable. No rebuildea si no cambia (evita el bucle de focus_exited al liberar el LineEdit).
func _set_sel_mat(sel: Dictionary, cal: int, disp: int, n: int) -> void:
	var nuevo: int = clampi(n, 0, disp)
	if nuevo == int(sel.get(cal, 0)):
		return
	if nuevo <= 0:
		sel.erase(cal)
	else:
		sel[cal] = nuevo
	_rebuild()


func _on_lingote(i: int) -> void:
	_lingote_idx = i
	_limpiar_seleccion()   # otro metal, otras maderas/cueros: la seleccion se rehace
	_rebuild()


# Rellena con lo MEJOR primero. En la FORJA la calidad del material sube la rareza, asi que el
# atajo "Auto" mete tus mejores piezas para maximizar la tirada. (En las MEJORAS es al reves: la
# calidad no importa, y Game gasta lo peor para no malgastar el material bueno.)
func _on_auto() -> void:
	var base: Resource = _stacks[_sel]["modelo"]
	var metal: MaterialData = Game.metal_de_forja(base, _lingote_idx)
	if metal == null:
		return
	var ings: Array = Game.ingredientes_forja(base, metal)
	_sel_forja = []
	for ing in ings:
		var mat: MaterialData = ing["material"]
		_sel_forja.append({} if mat == null else _auto_sel(mat, int(ing["uds"])))
	_rebuild()


func _auto_sel(mat: MaterialData, necesita: int) -> Dictionary:
	var sel: Dictionary = {}
	var restante: int = necesita
	# CALIDADES ya va de MEJOR a peor (puro, intacto, normal, dañado): mejor primero.
	for cal in CALIDADES:
		if restante <= 0:
			break
		var disp: int = Game.items_calidad_en_hogar(mat, int(cal))
		var uds: int = _uds(int(cal))
		if disp <= 0 or uds <= 0:
			continue
		var usar: int = mini(int(ceil(float(restante) / float(uds))), disp)
		if usar > 0:
			sel[cal] = usar
			restante -= usar * uds
	return sel


func _on_limpiar() -> void:
	_limpiar_seleccion()
	_rebuild()


func _on_forjar() -> void:
	var base: Resource = _stacks[_sel]["modelo"]
	var metal: MaterialData = Game.metal_de_forja(base, _lingote_idx)
	if Net.activo and not await Net.abrir_taller():
		_ocupado()
		_rebuild()
		return
	var item: Resource = Game.forjar(base, metal, _sel_forja)
	if Net.activo:
		Net.cerrar_taller()
		Net.liberar_mis_reservas()   # ya consumido: suelto la reserva ya
	if item != null:
		_decir("Forjas %s. Está en tu baúl: equípalo en el menú de personaje [C]." % Game.item_display_name(item))
	else:
		_decir("Te faltan materiales.", false)
	_limpiar_seleccion()
	_rebuild()


# ============================================================
#  Pestaña MEJORAR
# ============================================================

# ============================================================
#  Pestaña HERRAMIENTAS (pico / hoz / hacha)
#
#  Hermana de la mochila del peletero: coste FIJO, dos ingredientes y la rareza como unico eje de
#  calidad (una herramienta no se mejora con nucleos). Lo que la distingue de TODO lo demas del
#  herrero es que aqui SI se forja con el sub-tier del metal: ver Game.lingotes_herramienta.
# ============================================================

func _build_herramientas() -> void:
	_title(_header, "FORJAR UNA HERRAMIENTA")
	_note(_header, "El pico, la hoz y el hacha no te entrenan más rápido: hacen el trabajo menos hostil y te dejan sacar más material por rato. Cuenta el TIER del metal y también su VETA (en bruto, veteado, profundo): las dos suben lo que te ayuda, y la veta además te ahorra golpes. Es lo único que se forja con veta — en un arma, el cobre profundo haría exactamente la misma espada.")
	_note(_header, "El mango va a juego con la cabeza: cobre en bruto pide tablón común, veteado pide tablón de veta y profundo pide tablón anillado. No se elige.")
	_header.add_child(HSeparator.new())

	var lingotes: Array = Game.lingotes_herramienta()
	if lingotes.is_empty():
		_note(_header, "No conoces ningún metal. Pica una veta y vuelve.")
		return

	# --- QUE herramienta ---
	_title(_content, "Qué forjas", 13)
	var tipos: Array = [ToolData.Tipo.PICO, ToolData.Tipo.HOZ, ToolData.Tipo.HACHA, ToolData.Tipo.CANA]
	var etq_t: Array = []
	var pistas_t: Array = []
	for tp in tipos:
		var b: ToolData = Game.herramienta_base(int(tp))
		etq_t.append(b.tipo_texto() if b != null else "?")
		pistas_t.append(_para_que(int(tp)))
	MenuScaffold.cuadricula(_content, etq_t, tipos.find(_herr_tipo), _on_herr_tipo,
		4, MenuScaffold.TAM_SELECTOR, [], [], pistas_t)

	# --- CON QUE metal: DOS niveles (gama -> veta) ---
	# El tier y la veta son dos preguntas distintas y responden a dos cosas distintas (el tier pone la
	# afinidad, la veta los golpes que ahorras), asi que se preguntan por separado. Es el mismo
	# componente que usan fundir, aserrar y curtir.
	_content.add_child(HSeparator.new())
	_title(_content, "Metal  ·  el tier pone la afinidad, la veta los golpes", 13)
	var lingote: MaterialData = MenuScaffold.selector_material(_content, lingotes, "",
		_herr_tier, _herr_sub, _on_herr_tier, _on_herr_sub)
	if lingote == null:
		return

	var tier: int = Forge.tier_de_metal(lingote)
	var banda: int = int(lingote.mejora_min)
	var tab: MaterialData = Game.tablon_de_herramienta(lingote)
	if tab == null:
		_note(_content, "No hay tablón a juego con ese metal: el mango tiene que ser de la misma veta que la cabeza.")
		return

	# --- Los dos ingredientes ---
	_content.add_child(HSeparator.new())
	_capar_herr(lingote, _sel_herr_met)
	_capar_herr(tab, _sel_herr_tab)
	# Se APUNTA la reserva; la publica _rebuild_real al final, una sola vez (ver _claim_reserva).
	var claim: Dictionary = {}
	_sumar_claim_herr(claim, lingote, _sel_herr_met)
	_sumar_claim_herr(claim, tab, _sel_herr_tab)
	_claim_reserva = claim
	_contadores(_content, lingote, _sel_herr_met, int(Game.HERRAMIENTA_COSTE["metal"]))
	_contadores(_content, tab, _sel_herr_tab, int(Game.HERRAMIENTA_COSTE["tablon"]))
	_note(_content, "Puro = 4 unidades · intacto = 3 · normal = 2 · dañado = 1. Meter buen material no abarata la herramienta: mejora la RAREZA, y con ella los golpes que te ahorras.")

	# --- Rareza EN VIVO, con lo que daria cada una CON ESTA VETA ---
	_content.add_child(HSeparator.new())
	var score: float = Game.score_herramienta(lingote, _sel_herr_met, _sel_herr_tab)
	_title(_content, "Rareza que puede salir  ·  %s" % lingote.nombre)
	var base_t: ToolData = Game.herramienta_base(_herr_tipo)
	var probs: Array = Forge.probs_rareza(score)
	# Cada rareza con LAS DOS cosas que da, porque las dos suben con la tirada: la afinidad (lo que
	# te abre la ventana) y el ahorro de golpes. Aqui salia solo el ahorro y una nota aparte diciendo
	# que la afinidad era igual para todas — y con eso, gastar metal bueno o querer una tirada alta
	# no parecia servir para nada.
	for i in probs.size():
		var p: float = float(probs[i])
		if p <= 0.0:
			continue
		var md: Dictionary = Upgrades.tool_mods(_herr_tipo, tier, i, banda)
		var n: int = int(md["golpes_menos"])
		var efecto: String = "afinidad +%.0f" % float(md["afinidad"])
		if n > 0:
			efecto += ",  -%d %s" % [n, base_t.unidad_golpes(n)]
		_row(_content, Upgrades.rareza_nombre(i), "%s%%   →  %s" % [
			str(snappedf(p * 100.0, 0.1)), efecto], Upgrades.rareza_color(i))
	var puesta: ToolData = Game.herramienta_de_tipo(_herr_tipo)
	var pm: Dictionary = Game.tool_mods(puesta)
	_row(_content, "Llevas ahora", "afinidad +%.0f, -%d %s" % [
		float(pm["afinidad"]), int(pm["golpes_menos"]),
		base_t.unidad_golpes(int(pm["golpes_menos"]))])

	_content.add_child(HSeparator.new())
	var ok: bool = Game.herramienta_valida(lingote, _sel_herr_met, _sel_herr_tab)
	var b_hacer := Button.new()
	b_hacer.text = "Forjar" if ok else "Faltan materiales"
	b_hacer.disabled = not ok
	b_hacer.custom_minimum_size = Vector2(0, 36)
	b_hacer.pressed.connect(_on_forjar_herramienta)
	_content.add_child(b_hacer)
	_estado_oficio(_content, "Herrería", Game.tiene_desarrollo("herreria"),
		"Empuja la tirada de rareza a tu favor, como si el metal fuera mejor de lo que es.")


func _para_que(tipo: int) -> String:
	match tipo:
		ToolData.Tipo.PICO: return "Vetas de mineral  ·  entrena Fuerza"
		ToolData.Tipo.HOZ: return "Plantas  ·  entrena Destreza"
		ToolData.Tipo.CANA: return "Estanques  ·  entrena Resistencia"
		_: return "Madera  ·  entrena Agilidad"


func _on_herr_tipo(i: int) -> void:
	_herr_tipo = [ToolData.Tipo.PICO, ToolData.Tipo.HOZ, ToolData.Tipo.HACHA, ToolData.Tipo.CANA][clampi(i, 0, 3)]
	_rebuild()


func _on_herr_tier(i: int) -> void:
	_herr_tier = i
	_herr_sub = 0   # al cambiar de gama se vuelve a la veta base: la de abajo ya no existe
	_limpiar_sel_herr()
	_rebuild()


func _on_herr_sub(i: int) -> void:
	_herr_sub = i
	_limpiar_sel_herr()
	_rebuild()


# Otro metal = otras existencias: lo que hubieras elegido del anterior ya no vale.
func _limpiar_sel_herr() -> void:
	_sel_herr_met.clear()
	_sel_herr_tab.clear()


# El lingote elegido AHORA, resuelto desde (tier, veta). Lo necesita el boton de forjar, que no pinta
# el selector y por tanto no tiene el que devuelve selector_material. Misma resolucion que el, para
# que lo que se forja sea exactamente lo que se estaba enseñando.
func _herr_lingote() -> MaterialData:
	var lingotes: Array = Game.lingotes_herramienta()
	if lingotes.is_empty():
		return null
	var tiers: Array = MenuScaffold.tiers_de(lingotes)
	if tiers.is_empty():
		return null
	var t: int = int(tiers[clampi(_herr_tier, 0, tiers.size() - 1)])
	var subs: Array = MenuScaffold.del_tier(lingotes, t)
	if subs.is_empty():
		return null
	return subs[clampi(_herr_sub, 0, subs.size() - 1)] as MaterialData


# MULTI: capa la seleccion a lo DISPONIBLE (por si el compañero reservó de lo mismo).
func _capar_herr(mat: MaterialData, sel: Dictionary) -> void:
	if mat == null:
		return
	for cal in sel.keys():
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))
		var n: int = clampi(int(sel[cal]), 0, disp)
		if n <= 0:
			sel.erase(cal)
		else:
			sel[cal] = n


func _sumar_claim_herr(claim: Dictionary, mat: MaterialData, sel: Dictionary) -> void:
	if mat == null:
		return
	for cal in sel:
		var clave: String = "%s|%d" % [mat.id, int(cal)]
		claim[clave] = int(claim.get(clave, 0)) + int(sel[cal])


func _on_forjar_herramienta() -> void:
	var lingote: MaterialData = _herr_lingote()
	if lingote == null:
		return
	# El candado del taller y la reserva, igual que _on_forjar: sin esto, en multi dos jugadores
	# pueden gastar el mismo lingote.
	if Net.activo and not await Net.abrir_taller():
		_ocupado()
		_rebuild()
		return
	var item: Resource = Game.fabricar_herramienta(_herr_tipo, lingote, _sel_herr_met, _sel_herr_tab)
	if Net.activo:
		Net.cerrar_taller()
		Net.liberar_mis_reservas()
	if item != null:
		_decir("Forjas %s. Equípala en el inventario [I], pestaña Equipo." % Game.item_display_name(item))
	else:
		_decir("Te faltan materiales.", false)
	_sel_herr_met.clear()
	_sel_herr_tab.clear()
	_rebuild()


# Los slots que se ofrecen como subpestaña. Las MOCHILAS y las HERRAMIENTAS solo en DESHACER: no se
# mejoran (no tienen ranuras), asi que en la pestaña de mejorar saldrian siempre vacias.
func _slots_sub(con_mochila: bool) -> Array:
	var out: Array = []
	for s in Game.EQUIP_SLOTS:
		out.append(s)
	if con_mochila:
		out.append("mochila")
		out.append("herramienta")
	return out


func _build_mejorar() -> void:
	_title(_header, "MEJORAR")
	_note(_header, "Cada mejora sube el número base de la pieza (daño o defensa) y, además, lo suyo propio. El NÚCLEO manda: uno de slime no te lleva más allá de +3 por muchos huecos que tenga la pieza.")
	var slots: Array = _slots_sub(false)
	_sub = clampi(_sub, 0, slots.size() - 1)
	_subpestanas_slot(slots)
	# Tres lineas (nombre, tier/rareza y QUIEN la lleva), asi que el boton necesita mas alto.
	_grid_detail(_labels_del_baul(false, String(slots[_sub]), true), _preview_mejorar,
		Vector2(150, 58))


# La cuadricula del baul (armas + armaduras). La comparten MEJORAR y DESHACER, pero no enseñan
# lo mismo: MEJORAR SI lista lo que llevas puesto (mejorar el arma que tienes en la mano la
# mejora de verdad, sin desequiparla), y DESHACER no (no vas a fundir lo que llevas encima, y
# enseñar una fila que no puedes tocar es peor que no enseñarla).
#
# 'solo_slot' filtra por el sitio del cuerpo (la subpestaña activa); vacio = todo.
# 'con_portador' añade quien la lleva puesta. Solo tiene sentido en MEJORAR: en DESHACER lo
# equipado ni se lista, asi que ahi la respuesta seria siempre "nadie".
func _labels_del_baul(sin_equipado: bool = false, solo_slot: String = "",
		con_portador: bool = false) -> Array:
	_stacks = []
	var todo: Array = []
	for w in Game.owned_weapons:
		todo.append(w)
	for a in Game.owned_armor:
		todo.append(a)
	for mo in Game.owned_mochilas:
		todo.append(mo)
	for t in Game.owned_tools:
		todo.append(t)
	for item in todo:
		if sin_equipado and Game.item_equipado(item):
			continue
		if solo_slot != "" and _slot_de(item) != solo_slot:
			continue
		_stacks.append({"modelo": item})
	var labels: Array = []
	for s in _stacks:
		var item: Resource = s["modelo"]
		var linea: String = "%s%s\nT%d %s" % [str(item.get("nombre")), Game.item_plus(item),
			int(Game.meta_de(item)["tier"]), Upgrades.rareza_nombre(int(Game.meta_de(item)["rareza"]))]
		if con_portador:
			# quien_lleva mira la PLANTILLA entera, no solo al lider: con grupo, saber de quien es
			# cada pieza es justo lo que falta para no mejorar la del que no toca.
			var duenno: PersonajeData = Game.quien_lleva(item)
			linea += "\n%s" % (duenno.nombre if duenno != null else "en el baúl")
		labels.append(linea)
	return labels


# ============================================================
#  Pestaña DESHACER (equipo -> material). No se llama "Fundir" porque esa ya es la primera
#  pestaña (mineral -> lingote) y dos cosas distintas con el mismo nombre confunden.
# ============================================================

func _build_deshacer() -> void:
	_title(_header, "DESHACER UNA PIEZA")
	_note(_header, "A la fragua otra vez: recuperas la mitad de lo que costó hacerla, núcleos incluidos. Lo que llevas puesto ni sale aquí: quítatelo primero [C].")
	var slots: Array = _slots_sub(true)
	_sub = clampi(_sub, 0, slots.size() - 1)
	_subpestanas_slot(slots)
	# Sin portador: aqui lo equipado no se lista, asi que seria siempre "en el baúl".
	_grid_detail(_labels_del_baul(true, String(slots[_sub])), _preview_deshacer)


func _preview_deshacer(vb: VBoxContainer) -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	MenuScaffold.titulo_item(vb, Game.item_display_name(item), Game.color_rareza_de(item),
		Game.intensidad_rareza_de(item))

	var d: Dictionary = Game.fundir_devuelve(item)
	# Una mochila no se mejora ni se desgasta: enseñarle "+0" y una durabilidad seria ruido. Lo que
	# importa de ella es lo que carga, que es lo que se pierde al descoserla.
	if item is BackpackData:
		_row(vb, "Capacidad", "+%.0f de carga" % Game.capacidad_mochila(item as BackpackData))
	elif item is ToolData:
		# Tampoco se mejora ni se desgasta: lo que pierdes al deshacerla es lo que te ahorraba.
		var tm: Dictionary = Game.tool_mods(item as ToolData)
		var n: int = int(tm["golpes_menos"])
		_row(vb, "Afinidad", "+%.0f" % float(tm["afinidad"]))
		_row(vb, "Ahorro", "sin ahorro" if n <= 0 else "-%d %s" % [n, (item as ToolData).unidad_golpes(n)])
	else:
		_row(vb, "Mejoras", "+%d" % Game.mejoras_actuales(item))
		_row(vb, "Durabilidad", Game.durabilidad_txt_item(item), Game.durabilidad_color(item))
	vb.add_child(HSeparator.new())

	var t := Label.new()
	t.text = "Recuperas"
	t.add_theme_color_override("font_color", AMBAR)
	vb.add_child(t)

	var algo: bool = false
	for m in (d["materiales"] as Array):
		_row(vb, (m["material"] as MaterialData).nombre, "%d uds" % int(m["uds"]))
		algo = true
	var nucleos: Dictionary = d["nucleos"]
	for n in nucleos:
		_row(vb, (n as MaterialData).nombre, "%d" % int(nucleos[n]))
		algo = true
	if not algo:
		_note(vb, "De esta no sale nada aprovechable.")

	_note(vb, "Vuelve como material NORMAL: lo que sale de una pieza deshecha es chatarra reaprovechable, no material de primera. Y solo la mitad: la otra mitad se queda en el suelo de la fragua.")

	vb.add_child(HSeparator.new())
	_boton(vb, "Deshacer", _on_deshacer, Game.puede_fundir(item))


func _on_deshacer() -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	var nombre: String = Game.item_display_name(item)
	if Net.activo and not await Net.abrir_taller():
		_ocupado()
		_rebuild()
		return
	var ok: bool = Game.fundir_item(item)
	if Net.activo:
		Net.cerrar_taller()
	if ok:
		_sel = 0   # la pieza ya no existe: la cuadricula se rehace desde el principio
		_decir("Deshaces %s. El material está en tu baúl." % nombre)
	else:
		_decir("Esa pieza no se puede deshacer.", false)
	_rebuild()


# ============================================================
#  Pestaña REPARAR (mantenimiento): el equipo se desgasta al usarlo y se paga por dejarlo a punto.
#  El precio sube con el % roto (y un poco con tier / nº de mejoras). Ver Game.precio_reparar.
# ============================================================

const SLOT_NOMBRES := {"main": "Arma principal", "off": "Secundaria", "casco": "Casco",
	"pecho": "Pecho", "manos": "Manos", "pantalones": "Pantalones", "botas": "Botas"}


# UNA FILA de pieza: nombre a la izquierda, estado en su columna, y el boton SIEMPRE a la derecha.
#
# El boton se pinta este la pieza como este (a punto o hecha polvo) y con ancho FIJO. Antes era un
# boton de ancho completo DEBAJO de la fila, y solo si habia algo que pagar: la lista se partia en
# bloques y la columna bailaba segun que pieza estuviera rota. Manteniendo el hueco, el bloque no
# cambia de forma y el ojo encuentra siempre el boton en el mismo sitio.
func _fila_reparar(vb: VBoxContainer, etiqueta: String, estado: String, precio: int,
		cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # se come el hueco sobrante
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	# Ancho minimo para que la columna de numeros quede a plomo entre filas.
	var v := Label.new()
	v.text = estado
	v.custom_minimum_size = Vector2(170, 0)
	row.add_child(v)
	var b := Button.new()
	b.text = "Reparar · %d" % precio if precio > 0 else "A punto"
	b.disabled = precio <= 0 or not Game.puede_pagar(precio)
	b.custom_minimum_size = Vector2(150, 32)
	b.clip_text = true
	if precio > 0:
		b.pressed.connect(cb)
	row.add_child(b)
	vb.add_child(row)


# Las piezas de 'pj' que pasan por el herrero, en el orden de EQUIP_SLOTS.
func _piezas_reparables(pj: PersonajeData) -> Array:
	var out: Array = []
	for slot in Game.EQUIP_SLOTS:
		var item = pj.get("equipped_" + slot)
		if item == null or (slot == "off" and not (item is WeaponData)):
			continue   # la off puede llevar escudo/varita: eso no se repara aqui
		out.append({"slot": slot, "item": item})
	return out


func _build_reparar() -> void:
	_title(_header, "REPARAR EQUIPO")
	_note(_header, "El equipo se desgasta al usarlo: gastado pega/protege menos, y ROTO se va a los suelos. El precio depende de lo roto que esté; el tier y las mejoras lo suben un poco. La mejora de Durabilidad hace que aguante más (y no encarece reparar).")

	# EL BOTON GLOBAL VA ARRIBA Y ANCLADO. Estaba al final de la lista, y como la lista se salia de
	# la pantalla no habia manera de llegar a el. Mismo formato que el "Vender TODOS los cristales"
	# de la tienda: un clic, sin modal, con el precio en el texto.
	# Se queda SIEMPRE (apagado si no hay nada que hacer), igual que los botones de cada pieza: si
	# apareciera y desapareciera, la cabecera daria un salto cada vez que reparas algo.
	var total: int = Game.precio_reparar_todo()
	_boton(_header, "REPARAR TODO EL GRUPO  ·  %d monedas" % total if total > 0
		else "Todo el grupo está a punto", _on_reparar_todo, total > 0 and Game.puede_pagar(total))
	_row(_header, "Tu dinero", "%d monedas" % Game.money)

	if Game.party.is_empty():
		return
	# Una subpestaña por persona. El _sub se CLAMPA: si alguien sale del grupo con su pestaña
	# abierta, el indice se quedaria fuera del array.
	_sub = clampi(_sub, 0, Game.party.size() - 1)
	if Game.party.size() > 1:
		var labels: Array = []
		for i in Game.party.size():
			var corona: String = "👑 " if Game.party[i] == Game.lider() else ""
			labels.append("%d. %s%s" % [i + 1, corona, Game.party[i].nombre])
		_subpestanas(labels)
	else:
		_header.add_child(HSeparator.new())

	# Y LA LISTA VA AL PANEL CON SCROLL, no a la cabecera. Meterla en _header era el bug: la
	# cabecera del scaffold NUNCA scrollea, asi que con el grupo lleno lo de abajo no se veia.
	var pj: PersonajeData = Game.party[_sub]
	var piezas: Array = _piezas_reparables(pj)
	if piezas.is_empty():
		_note(_content, "%s no lleva nada equipado que se pueda reparar aquí." % pj.nombre)
		return
	for p in piezas:
		var slot: String = String(p["slot"])
		var item = p["item"]
		var frac: float = Game.durabilidad_slot(slot, pj)
		var maxd: float = Game.max_durabilidad(slot, pj)
		# % (lo que manda para el precio) y, entre parentesis, los PUNTOS: el maximo sube con
		# tier/rareza/mejoras, asi se ve de un vistazo cuanto aguanta esta pieza en concreto.
		var estado: String = "ROTO  (0 / %.1f)" % maxd if frac <= 0.0 \
			else "%d%%  (%.1f / %.1f)" % [int(round(frac * 100.0)), frac * maxd, maxd]
		_fila_reparar(_content, "%s · %s" % [SLOT_NOMBRES[slot], str(item.get("nombre"))],
			estado, Game.precio_reparar(slot, pj), _on_reparar_slot.bind(slot, pj))

	_content.add_child(HSeparator.new())
	# El "todo lo de esta persona". precio_reparar_todo/reparar_todo ya aceptan un pj y caen a la
	# party entera si va null, asi que el de arriba y este son la misma funcion con y sin argumento.
	var suyo: int = Game.precio_reparar_todo(pj)
	_boton(_content, "Reparar todo lo de %s  ·  %d monedas" % [pj.nombre, suyo] if suyo > 0
		else "%s está a punto" % pj.nombre,
		_on_reparar_todo.bind(pj), suyo > 0 and Game.puede_pagar(suyo))


func _on_reparar_slot(slot: String, pj: PersonajeData) -> void:
	if Game.reparar_slot(slot, pj):
		_decir("Reparada. Como nueva.")
	else:
		_decir("No te llega para repararla.", false)
	_rebuild()


# Sin pj = el grupo entero (el boton de la cabecera); con pj = solo el suyo.
func _on_reparar_todo(pj: PersonajeData = null) -> void:
	var gastado: int = Game.reparar_todo(pj)
	if gastado > 0:
		_decir("%s reparado por %d monedas." % ["Equipo de " + pj.nombre if pj != null else "Equipo del grupo", gastado])
	else:
		_decir("No te llega para repararlo todo.", false)
	_rebuild()


func _preview_mejorar(vb: VBoxContainer) -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	MenuScaffold.titulo_item(vb, Game.item_display_name(item), Game.color_rareza_de(item),
		Game.intensidad_rareza_de(item))

	# Quien la lleva puesta, arriba del todo: si mejoras la pieza equivocada no hay vuelta atras
	# (el material se gasta), asi que conviene verlo antes de tocar nada.
	var duenno: PersonajeData = Game.quien_lleva(item)
	_row(vb, "La lleva", duenno.nombre if duenno != null else "nadie (en el baúl)")

	var meta: Dictionary = Game.meta_de(item)
	var rareza: int = int(meta["rareza"])
	var actuales: int = Game.mejoras_actuales(item)
	var por_rareza: int = Upgrades.rareza_slots(rareza)
	_row(vb, "Huecos por rareza", str(por_rareza))
	# La durabilidad numerica va MAS ABAJO, con los atributos: alli se ve el +N que le mete una
	# mejora de Durabilidad (el % a secas no cambia al mejorar el maximo, solo suben los puntos).

	# El nucleo YA NO se elige a mano: lo pone el sistema segun el +N (cada nucleo cubre su tramo).
	# nucleo_auto devuelve el que TOCA aunque no lo tengas, para poder decir cual falta y en rojo.
	var nucleo: MaterialData = Game.nucleo_auto(item)
	var al_tope: bool = actuales >= por_rareza or nucleo == null
	var cuesta: int = 0
	if nucleo != null:
		cuesta = Forge.nucleos_para_mejora(actuales, nucleo, item)
		var tengo_n: int = Game.nucleos_en_hogar(nucleo)
		_row(vb, "Núcleo", "%d × %s  (tienes %d)" % [cuesta, nucleo.nombre, tengo_n],
			ROJO if tengo_n < cuesta else VERDE)
	else:
		_row(vb, "Núcleo", "— (la pieza ya está al máximo de su rareza)")

	# El MATERIAL de refuerzo: el mismo con el que se forjo, del mismo tier. En rojo si no llega.
	var mats: Dictionary = Game.materiales_mejora(item)
	# Con los materiales delante: el coste se reparte dentro de la banda de SU sub-tier, asi que
	# sin pasarlos esta previsualizacion cobraria distinto de lo que cobra Game.mejorar_item.
	var cmat: Dictionary = Forge.material_para_mejora(actuales, item, mats["metal"], mats["fibra"])
	for clave in ["metal", "fibra"]:
		var m: MaterialData = mats[clave]
		if m == null:
			_row(vb, "Material", "no existe a este tier: esta pieza no se puede reforzar")
			continue
		var necesita: int = int(cmat[clave])
		var tengo: int = Game.disponible_unidades_material_en_hogar(m)   # resta lo reservado por el otro
		_row(vb, m.nombre, "%d uds  (tienes %d)" % [necesita, tengo],
			ROJO if tengo < necesita else VERDE)
	_note(vb, "El núcleo lo elige el sistema por el nivel de la pieza: cada uno cubre su tramo de mejoras y dentro de él cada mejora cuesta un núcleo más que la anterior. El núcleo es el permiso, pero la pieza hay que rehacerla: gasta también material de su tier, y del peor que tengas (la rareza ya está echada y no se toca).")

	vb.add_child(HSeparator.new())
	var cats: Array = _categorias(item)
	if cats.is_empty():
		_note(vb, "Esta pieza no admite mejoras.")
		return
	_cat_idx = clampi(_cat_idx, 0, cats.size() - 1)
	# DOS por fila: con tres, los nombres largos ("Resistencia (estados)") se salian del panel.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mj: Dictionary = meta["mejoras"]
	for i in cats.size():
		var cat: String = str(cats[i])
		var b := Button.new()
		b.text = "%s  (%d)" % [Upgrades.cat_nombre(cat), int(mj.get(cat, 0))]
		b.toggle_mode = true
		b.button_pressed = (i == _cat_idx)
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 30)
		b.pressed.connect(_on_cat.bind(i))
		grid.add_child(b)
	vb.add_child(grid)

	# ATRIBUTOS de la pieza, con en verde lo que sube la mejora de la categoria seleccionada. El
	# delta se oculta si la pieza esta al tope (no hay mejora que previsualizar).
	vb.add_child(HSeparator.new())
	var cat_sel: String = str(cats[_cat_idx])
	for f in MenuScaffold.filas_mejora(item, int(meta["tier"]), rareza, mj, cat_sel):
		_row_attr(vb, str(f[0]), str(f[1]), "" if al_tope else str(f[2]))

	# DURABILIDAD numerica: puntos actuales / maximo (y el %). Una mejora de Durabilidad sube el
	# MAXIMO (+30% por nivel), no el %, asi que aqui se enseña el +N de puntos que gana el tope
	# cuando la categoria seleccionada es Durabilidad. Al tope no hay delta que previsualizar.
	var maxd: float = Game.max_durabilidad_item(item)
	var frac: float = Game.durabilidad_item(item)
	var dur_val: String = "%d / %d pts  (%d%%)" % [
		round(frac * maxd), round(maxd), round(frac * 100.0)]
	var dur_delta: String = ""
	if cat_sel == Upgrades.DURABILIDAD and not al_tope:
		var n_dur: int = int((mj as Dictionary).get(Upgrades.DURABILIDAD, 0))
		var nuevo_max: float = maxd / (1.0 + float(n_dur) * Game.DURABILIDAD_MEJORA_PCT) \
			* (1.0 + float(n_dur + 1) * Game.DURABILIDAD_MEJORA_PCT)
		dur_delta = "+%d pts máx" % round(nuevo_max - maxd)
	_row_attr(vb, "Durabilidad", dur_val, dur_delta)

	vb.add_child(HSeparator.new())
	var puede: bool = nucleo != null and Game.puede_mejorar(item, nucleo)
	var txt: String = "Al máximo que permite la rareza (+%d)" % por_rareza
	if not al_tope:
		txt = "Mejorar  (%d × %s)" % [cuesta, nucleo.nombre]
		if Game.nucleos_en_hogar(nucleo) < cuesta:
			txt = "Te faltan núcleos (%d de %d)" % [Game.nucleos_en_hogar(nucleo), cuesta]
	_boton(vb, txt, _on_mejorar, puede)


# Categorias que admite la pieza (Upgrades ya sabe cuales, por tipo de arma/armadura/escudo).
func _categorias(item: Resource) -> Array:
	if item is ArmorData:
		return Upgrades.armor_categories(item as ArmorData)
	if item is WandData:
		return Upgrades.wand_categories()
	if item is ShieldData:
		return Upgrades.shield_categories()
	if item is WeaponData:
		return Upgrades.weapon_categories(item as WeaponData)
	return []


func _on_cat(i: int) -> void:
	_cat_idx = i
	_rebuild()


func _on_mejorar() -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	var nucleo: MaterialData = Game.nucleo_auto(item)
	if nucleo == null:
		_decir("No se pudo mejorar.", false)
		return
	var cats: Array = _categorias(item)
	var cat: String = str(cats[clampi(_cat_idx, 0, cats.size() - 1)])
	if Net.activo and not await Net.abrir_taller():
		_ocupado()
		_rebuild()
		return
	var ok: bool = Game.mejorar_item(item, cat, nucleo)
	if Net.activo:
		Net.cerrar_taller()
	if ok:
		_decir("%s ahora es %s." % [Upgrades.cat_nombre(cat), Game.item_display_name(item)])
	else:
		_decir("No se pudo mejorar.", false)
	_rebuild()