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

# LA FILA DE TIPOS (como el inventario y la herreria): "Todas" y cada tipo. 'clave' = Runas-agnostica, ver _tipo_de.
# (Arco y ballesta van con el icono generico de espada: aun no tienen el suyo en la barra.)
const SUBS_ARMAS := [
	{"clave": "", "nombre": "Todas", "icono": "todo"},
	{"clave": "w1", "nombre": "Daga", "icono": "daga"},
	{"clave": "w2", "nombre": "Espada corta", "icono": "espada_corta"},
	{"clave": "w3", "nombre": "Espada larga", "icono": "espada_larga"},
	{"clave": "w4", "nombre": "Mandoble", "icono": "mandoble"},
	{"clave": "w5", "nombre": "Estoque", "icono": "estoque"},
	{"clave": "w6", "nombre": "Hacha grande", "icono": "hacha"},
	{"clave": "w7", "nombre": "Maza pequeña", "icono": "maza"},
	{"clave": "w8", "nombre": "Martillo grande", "icono": "martillo"},
	{"clave": "w9", "nombre": "Bastón", "icono": "baston"},
	{"clave": "w10", "nombre": "Arco", "icono": "espada"},
	{"clave": "w11", "nombre": "Ballesta", "icono": "espada"},
	{"clave": "escudo", "nombre": "Escudos", "icono": "escudo_med"},
	{"clave": "varita", "nombre": "Varitas", "icono": "varita"},
]
const CORTE_ARMAS := 7
const SUBS_ARMADURAS := [
	{"clave": "", "nombre": "Todas", "icono": "todo"},
	{"clave": "a0", "nombre": "Casco", "icono": "casco"},
	{"clave": "a1", "nombre": "Pecho", "icono": "coraza"},
	{"clave": "a2", "nombre": "Manos", "icono": "mano"},
	{"clave": "a3", "nombre": "Pantalones", "icono": "pantalon"},
	{"clave": "a4", "nombre": "Botas", "icono": "botas"},
]
var _sub: Array = [0, 0]   # el tipo elegido en cada pestaña

# LA BARRA DE ABAJO: Filtros y Orden, con la mecanica de la tienda (dentro de un grupo "o", entre grupos "y"; volver a
# pulsar el mismo orden le da la vuelta). Por pestaña.
const ORDENES := [
	{"campo": "", "nombre": "Predeterminado"},
	{"campo": "rareza", "nombre": "Rareza"},
	{"campo": "tier", "nombre": "Tier"},
	{"campo": "subs", "nombre": "Sub-stats"},
	{"campo": "nombre", "nombre": "Nombre"},
]
var _orden: Array = [{"campo": "", "desc": true}, {"campo": "", "desc": true}]
var _filtros: Array = [{}, {}]   # por pestaña: {grupo: [valores]}
var _barra_pie: HBoxContainer = null
var _modal_capa: Control = null
var _modal_cuerpo: VBoxContainer = null
var _sin_filtrar: Array = []


func _ready() -> void:
	add_to_group("runas_menu")
	montar("Taller de runas", TABS, TAB_ICONOS)
	# La barra de abajo, debajo de la rejilla (en su columna, fuera del scroll).
	_barra_pie = HBoxContainer.new()
	_barra_pie.add_theme_constant_override("separation", 10)
	_scroll_lista.get_parent().add_child(_barra_pie)


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
	# Aqui no trabaja nadie con oficio: fuera la fila de retratos de los otros talleres (salia vacia).
	_fila_artesano_rotulo.visible = false
	(_fila_artesano.get_parent().get_parent() as Control).visible = false
	if Net.activo:
		Net.hogar.reservar({})   # todo es instantaneo: no se aparta nada mientras miras
	# La fila de tipos.
	var subs: Array = SUBS_ARMADURAS if _tab == TAB_ARMADURAS else SUBS_ARMAS
	var nombres: Array = []
	var iconos: Array = []
	for s in subs:
		nombres.append(s["nombre"])
		iconos.append(s["icono"])
	_sub[_tab] = clampi(int(_sub[_tab]), 0, subs.size() - 1)
	filtros_dos_filas(nombres, iconos, int(_sub[_tab]), _on_sub_tipo,
		subs.size() if _tab == TAB_ARMADURAS else CORTE_ARMAS)
	var tipo: String = String(subs[int(_sub[_tab])]["clave"])
	var items: Array = []
	var fuente: Array = Game.owned_armor if _tab == TAB_ARMADURAS else Game.owned_weapons
	for it in fuente:
		if Runas.admite_runas(it) and (tipo == "" or _tipo_de(it) == tipo):
			items.append(it)
	_sin_filtrar = items
	items = _ordenar(_filtrar(items))
	_pintar_barra_pie()
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
		# En DOS columnas (lo pidio el usuario: que entre todo sin bajar) y con su RANGO debajo: de cuanto a cuanto
		# puede salir en esta pieza.
		var opciones: Array = []
		for sub in subs:
			opciones.append({"nombre": "%s\n%s" % [Runas.sub_txt(sub), Runas.rango_txt(str(sub["s"]), item)]})
		MenuScaffold.chips(vb, "ELIGE UNA PARA CAMBIARLA O RE-TIRARLA  ·  debajo, de cuánto a cuánto puede salir",
			opciones, [_sub_idx], _on_sub, 2)
		# Las dos columnas al mismo ancho (chips las deja a lo que mida su texto).
		var rejilla: Node = vb.get_child(vb.get_child_count() - 1)
		if rejilla is GridContainer:
			for b in rejilla.get_children():
				(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


# ============================================================
#  TIPOS, FILTROS Y ORDEN
# ============================================================
static func _tipo_de(it: Resource) -> String:
	if it is ArmorData:
		return "a%d" % int((it as ArmorData).slot)
	if it is ShieldData:
		return "escudo"
	if it is WandData:
		return "varita"
	if it is WeaponData:
		return "w%d" % int((it as WeaponData).tipo)
	return ""


func _on_sub_tipo(i: int) -> void:
	if i == int(_sub[_tab]):
		return
	_sub[_tab] = i
	cambiar_pantalla()


# Los grupos del modal de filtros: {clave, titulo, opciones: [{nombre, valor}]}.
func _grupos() -> Array:
	var sets: Array = [{"nombre": "Sin set", "valor": 0}]
	var i: int = 1
	for s in Runas.sets():
		if int((s as RunaSetData).tipo) == (RunaSetData.Tipo.ARMADURA if _tab == TAB_ARMADURAS else RunaSetData.Tipo.ARMA):
			sets.append({"nombre": (s as RunaSetData).nombre, "valor": i})
		i += 1
	var rarezas: Array = []
	for r in Upgrades.RAREZA_NOMBRE.size():
		rarezas.append({"nombre": Upgrades.RAREZA_NOMBRE[r], "valor": r})
	return [
		{"clave": "set", "titulo": "SET", "opciones": sets},
		{"clave": "subs", "titulo": "SUB-STATS", "opciones": [{"nombre": "Ninguna", "valor": 0}, {"nombre": "Una", "valor": 1},
			{"nombre": "Dos", "valor": 2}, {"nombre": "Tres", "valor": 3}, {"nombre": "Cuatro", "valor": 4}]},
		{"clave": "rareza", "titulo": "RAREZA", "opciones": rarezas},
		{"clave": "tier", "titulo": "TIER", "opciones": [{"nombre": "T1", "valor": 1}, {"nombre": "T2", "valor": 2},
			{"nombre": "T3", "valor": 3}]},
		{"clave": "puesta", "titulo": "DÓNDE", "opciones": [{"nombre": "En el baúl", "valor": 0},
			{"nombre": "Puesta", "valor": 1}]},
	]


func _valor(it: Resource, grupo: String) -> int:
	var m: Dictionary = Game.meta_de(it)
	match grupo:
		"set":
			var s: RunaSetData = Runas.set_de(it)
			return 0 if s == null else Runas.sets().find(s) + 1
		"subs":
			return Runas.subs_de(it).size()
		"rareza":
			return int(m.get("rareza", 0))
		"tier":
			return int(m.get("tier", 1))
		"puesta":
			return 1 if Game.quien_lleva(it) != null else 0
	return -9999


func _filtrar(items: Array) -> Array:
	var f: Dictionary = _filtros[_tab]
	var out: Array = []
	for it in items:
		var pasa: bool = true
		for g in f:
			var marcados: Array = f[g]
			if not marcados.is_empty() and not marcados.has(_valor(it, String(g))):
				pasa = false
				break
		if pasa:
			out.append(it)
	return out


func _ordenar(items: Array) -> Array:
	var o: Dictionary = _orden[_tab]
	var campo: String = String(o["campo"])
	if campo == "":
		return items
	var desc: bool = bool(o["desc"])
	var claves: Array = []
	for i in items.size():
		var it: Resource = items[i]
		var v: Variant = Game.item_display_name(it) if campo == "nombre" else float(_valor(it, campo))
		claves.append({"i": i, "v": v})
	claves.sort_custom(func(a, b):
		if a["v"] == b["v"]:
			return int(a["i"]) < int(b["i"])
		return (a["v"] > b["v"]) if desc else (a["v"] < b["v"]))
	var out: Array = []
	for k in claves:
		out.append(items[int(k["i"])])
	return out


func _hay_filtro() -> bool:
	for g in (_filtros[_tab] as Dictionary).values():
		if not (g as Array).is_empty():
			return true
	return false


func _pintar_barra_pie() -> void:
	MenuScaffold.vaciar(_barra_pie)
	var embudo: Button = MenuScaffold.pastilla(_barra_pie, "Filtros", _abrir_filtros, false)
	if _hay_filtro():
		MenuScaffold.estilo_chip(embudo, true)
		embudo.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_PASTILLA)
	var o: Dictionary = _orden[_tab]
	var nom: String = "Predeterminado"
	for c in ORDENES:
		if String(c["campo"]) == String(o["campo"]):
			nom = String(c["nombre"])
	var flecha: String = "" if String(o["campo"]) == "" else ("  ↓" if bool(o["desc"]) else "  ↑")
	MenuScaffold.pastilla(_barra_pie, "Orden: %s%s" % [nom, flecha], _abrir_orden, false)


func _abrir_orden() -> void:
	_cerrar_modal()
	var m: Dictionary = MenuScaffold.modal(_root, "Orden", MenuScaffold.ANCHO_MODAL, _cerrar_modal)
	_modal_capa = m["capa"]
	var o: Dictionary = _orden[_tab]
	var marcadas: Array = []
	for i in ORDENES.size():
		if String(ORDENES[i]["campo"]) == String(o["campo"]):
			marcadas.append(i)
	MenuScaffold.chips(m["cuerpo"], "", ORDENES, marcadas, func(i: int):
		var campo: String = String(ORDENES[i]["campo"])
		if String(o["campo"]) == campo and campo != "":
			o["desc"] = not bool(o["desc"])
		else:
			o["campo"] = campo
			o["desc"] = true
		_cerrar_modal()
		sel = 0
		rebuild(), 3)
	MenuScaffold.nota(m["cuerpo"], "Vuelve a pulsar el mismo criterio para invertirlo.")
	MenuScaffold.pastilla(m["acciones"], "Cerrar", _cerrar_modal, false)


func _abrir_filtros() -> void:
	_cerrar_modal()
	var m: Dictionary = MenuScaffold.modal(_root, "Filtros", MenuScaffold.ANCHO_MODAL, _cerrar_modal)
	_modal_capa = m["capa"]
	_modal_cuerpo = m["cuerpo"]
	_refrescar_filtros()
	MenuScaffold.pastilla(m["acciones"], "Quitar todo", func():
		_filtros[_tab] = {}
		sel = 0
		_refrescar_filtros()
		rebuild(), false)
	MenuScaffold.pastilla(m["acciones"], "Listo", _cerrar_modal)


func _refrescar_filtros() -> void:
	if _modal_cuerpo == null or not is_instance_valid(_modal_cuerpo):
		return
	MenuScaffold.vaciar(_modal_cuerpo)
	var f: Dictionary = _filtros[_tab]
	for g in _grupos():
		var grupo: String = String(g["clave"])
		var marcados: Array = f.get(grupo, [])
		var vals: Array = g["opciones"]
		var opciones: Array = []
		var marcadas: Array = []
		for i in vals.size():
			var valor: int = int(vals[i]["valor"])
			var n: int = 0
			for it in _sin_filtrar:
				if _valor(it, grupo) == valor:
					n += 1
			opciones.append({"nombre": String(vals[i]["nombre"]), "cuantos": n})
			if marcados.has(valor):
				marcadas.append(i)
		MenuScaffold.chips(_modal_cuerpo, String(g["titulo"]), opciones, marcadas, func(idx: int):
			var lista: Array = f.get(grupo, [])
			var v: int = int(vals[idx]["valor"])
			if lista.has(v):
				lista.erase(v)
			else:
				lista.append(v)
			f[grupo] = lista
			sel = 0
			_refrescar_filtros()
			rebuild(), 4)


func _cerrar_modal() -> void:
	if _modal_capa != null and is_instance_valid(_modal_capa):
		_modal_capa.queue_free()
	_modal_capa = null
	_modal_cuerpo = null


func _al_cerrar() -> void:
	_cerrar_modal()


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
