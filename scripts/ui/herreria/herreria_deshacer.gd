# ============================================================
#  herreria_deshacer.gd  --  DESHACER una pieza (equipo -> material). Ver forge_menu.gd.
#
#  A la fragua otra vez: recuperas la MITAD de lo que costo hacerla, nucleos incluidos, como material
#  NORMAL. No se llama "Fundir" porque esa ya es la primera pestaña (mineral -> lingote).
#
#  La rejilla es tu equipo SIN lo que llevas puesto (no vas a fundir lo que llevas encima) y con las
#  mochilas y las herramientas; el filtro por ranura es el de Mejorar. La ficha dice lo que pierdes y
#  lo que recuperas, en celdas.
# ============================================================
extends RefCounted

const HerreriaMejorar = preload("res://scripts/ui/herreria/herreria_mejorar.gd")
const LADO_CELDA_DEVUELVE := 64.0

var t = null   # el armazon (forge_menu.gd)
var _filtro: int = 0


func _init(armazon) -> void:
	t = armazon


func build() -> void:
	var items: Array = HerreriaMejorar.piezas_del_baul(t, true, _filtro, _on_filtro)
	t.stacks = items
	t.grid_detail(HerreriaMejorar.celdas(items, false), _ficha,
		"No tienes nada de esto en el baúl. Lo que llevas puesto no sale aquí: quítatelo primero [C].")


func _on_filtro(i: int) -> void:
	if i == _filtro:
		return
	_filtro = i
	t.cambiar_pantalla()


func _ficha(vb: VBoxContainer) -> void:
	var item: Resource = t.stacks[t.sel]
	MenuScaffold.titulo_item(vb, Game.item_display_name(item), Game.color_rareza_de(item),
		Game.intensidad_rareza_de(item))
	MenuScaffold.banner_item(vb, item, "", "En el baúl")
	vb.add_child(HSeparator.new())
	# LO QUE PIERDES. Una mochila o una herramienta no se mejoran ni se desgastan: de ellas importa lo
	# que cargan o lo que te ahorran.
	if item is BackpackData:
		t.row(vb, "Capacidad", "+%.0f de carga" % Game.capacidad_mochila(item as BackpackData))
	elif item is ToolData:
		t.row(vb, "Aporta", MenuScaffold.texto_efecto_herramienta(item as ToolData, Game.tool_mods(item as ToolData)))
	else:
		t.row(vb, "Mejoras", "+%d" % Game.mejoras_actuales(item))
		t.row(vb, "Durabilidad", Game.durabilidad_txt_item(item), Game.durabilidad_color(item))

	var d: Dictionary = Game.fundir_devuelve(item)
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "RECUPERAS", 13)
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 8)
	fila.add_theme_constant_override("v_separation", 8)
	vb.add_child(fila)
	var algo: bool = false
	for m in (d["materiales"] as Array):
		MenuScaffold.celda_suelta(fila, MaterialItem.crear(m["material"] as MaterialData, MaterialItem.Calidad.NORMAL),
			LADO_CELDA_DEVUELVE, "%d uds" % int(m["uds"]))
		algo = true
	var nucleos: Dictionary = d["nucleos"]
	for n in nucleos:
		MenuScaffold.celda_suelta(fila, n as MaterialData, LADO_CELDA_DEVUELVE, "x%d" % int(nucleos[n]))
		algo = true
	if not algo:
		t.note(vb, "De esta no sale nada aprovechable.")
	t.note(vb, "Vuelve como material NORMAL: es chatarra reaprovechable, no material de primera. Y solo la mitad: la otra mitad se queda en el suelo de la fragua.")

	var pie: VBoxContainer = t.acciones()
	pie.add_child(HSeparator.new())
	MenuScaffold.pastilla(pie, "Deshacer", func() -> void: _deshacer(item), true, Game.puede_fundir(item))


func _deshacer(item: Resource) -> void:
	var nombre: String = Game.item_display_name(item)
	if Net.activo and not await Net.hogar.abrir_taller():
		t.ocupado()
		t.rebuild()
		return
	var ok: bool = Game.fundir_item(item)
	if Net.activo:
		Net.hogar.cerrar_taller()
	if ok:
		t.sel = 0   # la pieza ya no existe
		t.decir("Deshaces %s. El material está en tu baúl." % nombre)
	else:
		t.decir("Esa pieza no se puede deshacer.", false)
	t.rebuild()
