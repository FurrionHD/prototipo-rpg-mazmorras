# ============================================================
#  herreria_reparar.gd  --  REPARAR el equipo (mantenimiento). Ver forge_menu.gd.
#
#  El equipo se desgasta al usarlo: gastado pega/protege menos y ROTO se va a los suelos. El precio
#  depende de lo roto que este; el tier y las mejoras lo suben un poco (Game.precio_reparar).
#
#  Forma que eligio el usuario (16/09/2026): la fila de retratos elige DE QUIEN es el equipo (solo el
#  grupo que baja: lo del Hogar no se gasta), la rejilla son sus piezas puestas con su desgaste en el
#  pie, y la ficha dice el estado y el precio. En el pie: reparar esta, todo lo suyo o todo el grupo.
# ============================================================
extends RefCounted

const SLOT_NOMBRES := {"main": "Arma principal", "off": "Secundaria", "casco": "Casco",
	"pecho": "Pecho", "manos": "Manos", "pantalones": "Pantalones", "botas": "Botas"}

var t = null   # el armazon (forge_menu.gd)
var _persona: int = 0


func _init(armazon) -> void:
	t = armazon


func build() -> void:
	t.contador("%d monedas" % Game.money)
	if Game.party.is_empty():
		t.stacks = []
		t.grid_detail([], func(_vb): pass, "No hay nadie en el grupo.")
		return
	_persona = clampi(_persona, 0, Game.party.size() - 1)
	t.pintar_personas("DE QUIÉN", Game.party, _persona, Game.party.size(), _on_persona)
	var pj: PersonajeData = Game.party[_persona]
	var piezas: Array = _reparables(pj)
	t.stacks = piezas
	var celdas: Array = []
	for p in piezas:
		var frac: float = Game.durabilidad_slot(String(p["slot"]), pj)
		celdas.append({"item": p["item"], "activo": true, "marca": "",
			"pie": "ROTO" if frac <= 0.0 else "%d%%" % roundi(frac * 100.0),
			"tooltip": "%s  ·  %s" % [SLOT_NOMBRES[p["slot"]], str(p["item"].get("nombre"))]})
	t.grid_detail(celdas, func(vb: VBoxContainer) -> void: _ficha(vb, pj),
		"%s no lleva nada equipado que se pueda reparar aquí." % pj.nombre)
	if piezas.is_empty():
		_pie(pj, {})


func _on_persona(i: int) -> void:
	if i == _persona:
		return
	_persona = i
	t.cambiar_pantalla()


# Las piezas de 'pj' que pasan por el herrero, en el orden de EQUIP_SLOTS.
func _reparables(pj: PersonajeData) -> Array:
	var out: Array = []
	for slot in Game.EQUIP_SLOTS:
		var item = pj.get("equipped_" + slot)
		if item == null or (slot == "off" and not (item is WeaponData)):
			continue   # la off puede llevar escudo/varita: eso no se repara aqui
		out.append({"slot": slot, "item": item})
	return out


func _ficha(vb: VBoxContainer, pj: PersonajeData) -> void:
	var p: Dictionary = t.stacks[t.sel]
	var slot: String = String(p["slot"])
	var item: Resource = p["item"]
	MenuScaffold.titulo_item(vb, Game.item_display_name(item), Game.color_rareza_de(item),
		Game.intensidad_rareza_de(item))
	MenuScaffold.banner_item(vb, item, "", "%s  ·  %s" % [SLOT_NOMBRES[slot], pj.nombre])
	vb.add_child(HSeparator.new())
	var frac: float = Game.durabilidad_slot(slot, pj)
	var maxd: float = Game.max_durabilidad(slot, pj)
	# % (lo que manda para el precio) y los PUNTOS: el maximo sube con tier/rareza/mejoras.
	t.row(vb, "Estado", "ROTO  (0 / %.1f)" % maxd if frac <= 0.0
		else "%d%%  (%.1f / %.1f)" % [roundi(frac * 100.0), frac * maxd, maxd], Game.durabilidad_color(item))
	var precio: int = Game.precio_reparar(slot, pj)
	t.row(vb, "Reparar", "%d monedas" % precio if precio > 0 else "A punto")
	t.note(vb, "Gastado pega o protege menos, y roto se va a los suelos. La mejora de Durabilidad hace que aguante más y no encarece reparar.")
	_pie(pj, p)


# El pie: esta pieza, todo lo de esta persona y todo el grupo. Los tres se quedan SIEMPRE (apagados si
# no hay nada que hacer): si aparecieran y desaparecieran, el pie daria un salto cada vez que reparas.
func _pie(pj: PersonajeData, p: Dictionary) -> void:
	var vb: VBoxContainer = t.acciones()
	vb.add_child(HSeparator.new())
	if not p.is_empty():
		var precio: int = Game.precio_reparar(String(p["slot"]), pj)
		MenuScaffold.pastilla(vb, "Reparar  ·  %d monedas" % precio if precio > 0 else "Está a punto",
			func() -> void: _reparar(String(p["slot"]), pj), true, precio > 0 and Game.puede_pagar(precio))
	var suyo: int = Game.precio_reparar_todo(pj)
	MenuScaffold.pastilla(vb, "Todo lo de %s  ·  %d monedas" % [pj.nombre, suyo] if suyo > 0
		else "%s está a punto" % pj.nombre,
		func() -> void: _reparar_todo(pj), false, suyo > 0 and Game.puede_pagar(suyo))
	var total: int = Game.precio_reparar_todo()
	MenuScaffold.pastilla(vb, "Todo el grupo  ·  %d monedas" % total if total > 0
		else "Todo el grupo está a punto",
		func() -> void: _reparar_todo(null), false, total > 0 and Game.puede_pagar(total))


func _reparar(slot: String, pj: PersonajeData) -> void:
	if Game.reparar_slot(slot, pj):
		t.decir("Reparada. Como nueva.")
	else:
		t.decir("No te llega para repararla.", false)
	t.rebuild()


# Sin pj = el grupo entero.
func _reparar_todo(pj: PersonajeData) -> void:
	var gastado: int = Game.reparar_todo(pj)
	if gastado > 0:
		t.decir("%s reparado por %d monedas." % ["Equipo de " + pj.nombre if pj != null else "Equipo del grupo", gastado])
	else:
		t.decir("No te llega para repararlo todo.", false)
	t.rebuild()
