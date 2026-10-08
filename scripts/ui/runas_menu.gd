# ============================================================
#  runas_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  EL TALLER DE RUNAS (08/10/2026, fase 5 del plan de mecanicas). Dos pestañas, ARMAS (armas, varitas y escudos) y
#  ARMADURAS. A la izquierda tus piezas (tambien las equipadas: activar en lo que llevas puesto vale de verdad); a la
#  derecha la ficha:
#    - SIN SET: los sets que admite como chips, su descripcion (de los datos) y lo que cuesta activarlo;
#    - CON SET: su set, sus sub-stats (se elige una para cambiarla o re-tirarla) y las acciones, cada una por 1 runa;
#      desencantar la deja limpia (las runas no vuelven).
#  UI placeholder por codigo, sobre la base de los talleres (taller_menu.gd). La MATH vive en Runas.
# ============================================================
extends "res://scripts/ui/taller_menu.gd"

const TABS := ["Armas", "Armaduras"]
const TAB_ICONOS := ["espada", "coraza"]
const TAB_ARMAS := 0
const TAB_ARMADURAS := 1
const LADO_CELDA_COSTE := 48.0
const ANCHO_FICHA_RUNAS := 520.0

var _set_idx: int = 0   # el set elegido en la ficha de una pieza sin set
var _sub_idx: int = 0   # la sub-stat elegida para cambiar / re-tirar


func _ready() -> void:
	add_to_group("runas_menu")
	montar("Taller de runas", TABS, TAB_ICONOS)


func abrir() -> void:
	_tab = TAB_ARMAS
	abrir_taller()


func _al_cambiar_pantalla() -> void:
	_set_idx = 0
	_sub_idx = 0


func _al_elegir_otra() -> void:
	_set_idx = 0
	_sub_idx = 0


func _pintar() -> void:
	_titulo_seccion.text = TABS[_tab]
	anchos(ANCHO_REJILLA_MIN, ANCHO_FICHA_RUNAS)
	if Net.activo:
		Net.hogar.reservar({})   # todo es instantaneo: no se aparta nada mientras miras
	var items: Array = []
	var fuente: Array = Game.owned_armor if _tab == TAB_ARMADURAS else Game.owned_weapons
	for it in fuente:
		if Runas.admite_runas(it):
			items.append(it)
	stacks = items
	contador("%d piezas" % items.size())
	var celdas: Array = []
	for it in items:
		var duenno: PersonajeData = Game.quien_lleva(it)
		var s: RunaSetData = Runas.set_de(it)
		celdas.append({"item": it, "pie": "", "activo": true,
			"marca": duenno.nombre if duenno != null else "",
			"tooltip": "%s%s%s" % [Game.item_display_name(it), "  ·  set %s" % s.nombre if s != null else "",
				"  ·  la lleva %s" % duenno.nombre if duenno != null else ""]})
	grid_detail(celdas, _ficha, "No tienes piezas de este tipo.")


func _ficha(vb: VBoxContainer) -> void:
	var item: Resource = stacks[sel]
	MenuScaffold.titulo_item(vb, Game.item_display_name(item), Game.color_rareza_de(item),
		Game.intensidad_rareza_de(item))
	var duenno: PersonajeData = Game.quien_lleva(item)
	MenuScaffold.banner_item(vb, item, "", "La lleva %s" % duenno.nombre if duenno != null else "En el baúl")
	var s: RunaSetData = Runas.set_de(item)
	if s == null:
		_ficha_sin_set(vb, item)
	else:
		_ficha_con_set(vb, item, s)


# --- SIN SET: elegir cual y activarlo ---
func _ficha_sin_set(vb: VBoxContainer, item: Resource) -> void:
	var posibles: Array = []
	for s in Runas.sets():
		if int((s as RunaSetData).tipo) == Runas.tipo_set_de(item):
			posibles.append(s)
	vb.add_child(HSeparator.new())
	if posibles.is_empty():
		note(vb, "Ningún set admite esta pieza.")
		return
	_set_idx = clampi(_set_idx, 0, posibles.size() - 1)
	var opciones: Array = []
	for s in posibles:
		opciones.append({"nombre": (s as RunaSetData).nombre})
	MenuScaffold.chips(vb, "ELIGE UN SET", opciones, [_set_idx], _on_set, 3)
	var sd: RunaSetData = posibles[_set_idx]
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, sd.nombre.to_upper(), 13)
	note(vb, Runas.descripcion_set(sd))
	if Runas.dos_manos(item):
		note(vb, "Arma a dos manos: cuenta como 2 piezas del set y sus sub-stats valen el doble.")
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "LO QUE CUESTA ACTIVARLO", 13)
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 16)
	fila.add_theme_constant_override("v_separation", 8)
	vb.add_child(fila)
	_coste(fila, sd.material, sd.coste_material, Game.unidades_material_en_hogar(sd.material), " uds")
	_coste(fila, sd.nucleo, sd.coste_nucleo, Game.nucleos_en_hogar(sd.nucleo), "")
	note(vb, "Con el set activo, cada %s le pone una sub-stat (hasta %d), cambia una o re-tira su valor." % [
		sd.runa.nombre if sd.runa != null else "runa", Runas.MAX_SUBS])
	var puede: bool = Runas.puede_activar(item, sd)
	var pie: VBoxContainer = acciones()
	pie.add_child(HSeparator.new())
	MenuScaffold.pastilla(pie, "Activar %s" % sd.nombre if puede else "Te falta material",
		func() -> void: _hacer(func() -> String: return Runas.activar(item, sd), "Set %s activado." % sd.nombre),
		true, puede)


# --- CON SET: sus sub-stats y las acciones ---
func _ficha_con_set(vb: VBoxContainer, item: Resource, s: RunaSetData) -> void:
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "SET  %s" % s.nombre.to_upper(), 13)
	note(vb, Runas.descripcion_set(s))
	var subs: Array = Runas.subs_de(item)
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "SUB-STATS  %d de %d" % [subs.size(), Runas.MAX_SUBS], 13)
	if subs.is_empty():
		note(vb, "Aún ninguna: cada runa le pone una al azar.")
	else:
		_sub_idx = clampi(_sub_idx, 0, subs.size() - 1)
		var opciones: Array = []
		for sub in subs:
			opciones.append({"nombre": Runas.sub_txt(sub)})
		MenuScaffold.chips(vb, "ELIGE UNA PARA CAMBIARLA O RE-TIRARLA", opciones, [_sub_idx], _on_sub, 1)
	vb.add_child(HSeparator.new())
	var tienes: int = Runas.runas_en_hogar(s)
	var fila := HFlowContainer.new()
	vb.add_child(fila)
	_coste(fila, s.runa, 1, tienes, "")
	var hay: bool = tienes >= 1
	var pie: VBoxContainer = acciones()
	pie.add_child(HSeparator.new())
	var lleno: bool = subs.size() >= Runas.MAX_SUBS
	MenuScaffold.pastilla(pie, "Añadir sub-stat" if not lleno else "Ya tiene %d sub-stats" % Runas.MAX_SUBS,
		func() -> void: _hacer(func() -> String: return Runas.subir(item), "Nueva sub-stat."), true, hay and not lleno)
	if not subs.is_empty():
		var i: int = _sub_idx
		MenuScaffold.pastilla(pie, "Cambiar la elegida por otra",
			func() -> void: _hacer(func() -> String: return Runas.cambiar(item, i), "Sub-stat cambiada."), false, hay)
		MenuScaffold.pastilla(pie, "Re-tirar su valor",
			func() -> void: _hacer(func() -> String: return Runas.retirar(item, i), "Valor re-tirado."), false, hay)
	MenuScaffold.pastilla(pie, "Desencantar (las runas no vuelven)",
		func() -> void: _hacer(func() -> String: return Runas.desencantar(item), "La pieza queda limpia."), false, true)


func _on_set(i: int) -> void:
	_set_idx = i
	rebuild()


func _on_sub(i: int) -> void:
	_sub_idx = i
	rebuild()


# Una accion del taller, con el candado del hogar en multi (como la herreria: se gasta del baul compartido).
func _hacer(accion: Callable, ok_txt: String) -> void:
	if Net.activo and not await Net.hogar.abrir_taller():
		ocupado()
		rebuild()
		return
	var err: String = accion.call()
	if Net.activo:
		Net.hogar.cerrar_taller()
	decir(ok_txt if err == "" else err, err == "")
	rebuild()


# Un COSTE en su celda: el material, cuanto pide y cuanto tienes (en rojo si no llega). Como en la herreria.
func _coste(fila: Container, mat: MaterialData, pide: int, tienes: int, uds: String) -> void:
	if mat == null:
		return
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	MenuScaffold.celda_suelta(caja, mat, LADO_CELDA_COSTE, "T%d" % int(mat.tier))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size = Vector2(160, 0)
	var nom := Label.new()
	nom.text = mat.nombre
	nom.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	col.add_child(nom)
	var v := Label.new()
	v.text = "%d%s  (tienes %d)" % [pide, uds, tienes]
	v.add_theme_color_override("font_color", ROJO if tienes < pide else VERDE)
	col.add_child(v)
	caja.add_child(col)
	fila.add_child(caja)
