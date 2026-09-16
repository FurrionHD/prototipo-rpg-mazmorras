# ============================================================
#  taller_recetas.gd  --  la pantalla de RECETAS de la boticaria y la cocina (ver craft_menu.gd, el
#  armazon, que dice en cual de los dos estamos con t.es_cocina()).
#
#  LA REJILLA SON LAS RECETAS del tier, una celda por receta, y la celda pinta LO QUE SALE (la poción o
#  el plato), no lo que metes. En las pociones van en orden de cadena (vida, maná, antídotos) y encima
#  hay un filtro Todo / Vida / Maná / Antídotos; la cocina no lo lleva (cada plato es de un eje
#  distinto y ya lo dice su ficha).
#
#  LA FICHA, ANCHA: que hace, la poción base si es una mejora, los ingredientes EN COLUMNAS con una
#  fila por calidad (como Mochilas en la peleteria) y la racion doble. En el pie fijo: la cantidad, los
#  dos Autos, Limpiar y Fabricar / Cocinar.
#
#  Lo que se fabrica de verdad sale de la SELECCION (Game.pociones_de_seleccion), no de la cantidad: si
#  pides 5 y solo da para 4, salen 4. La cantidad es solo para los Autos.
# ============================================================
extends RefCounted

# El lado de la celdita que acompaña a cada ingrediente (ver peleteria_mochilas).
const LADO_CELDA_ING := 48.0
# En cuantas columnas van los ingredientes: tres en la cocina (un plato lleva hasta seis) y dos en la
# boticaria, que tiene la ficha mas estrecha (ver craft_menu, EL REPARTO DEL ANCHO).
const COLUMNAS_ING_COCINA := 3
const COLUMNAS_ING_POCIONES := 2

# El filtro de las pociones: 0 = todo, y luego el tipo de Game (ver _tipo_de) + 1.
const FILTROS := ["Todo", "Vida", "Maná", "Antídotos"]
const FILTRO_ICONOS := ["todo", "vida", "mana", "antidoto"]
const TIPO_VIDA := 0
const TIPO_MANA := 1
# LOS ANTIDOTOS VAN APARTE: "curan" algo de vida, asi que antes caian en Vida mezclados con las pociones
# de verdad, y no se hacen para lo mismo -- se hacen para quitarte un veneno. Por eso se miran antes que
# la cura.
const TIPO_ANTIDOTO := 2

var t = null   # el armazon (craft_menu.gd)
var _filtro: int = 0
# SELECCION de materiales de la receta elegida: Array paralelo a receta.ingredientes; cada entrada un
# {calidad: cantidad}. Se vacia al cambiar de receta, NO en cada rebuild (borraria lo que vas poniendo).
var _seleccion: Array = []
# CUANTAS piezas quieres que rellene el Auto. Arranca en UNO al abrir y en cada receta nueva, nunca en
# el maximo (la regla de la peleteria).
var _cantidad: int = 1


func _init(armazon) -> void:
	t = armazon


func abrir() -> void:
	_filtro = 0
	cambio_de_receta()


# La receta elegida ya no es la misma: la seleccion y la cantidad empiezan de cero.
func cambio_de_receta() -> void:
	_seleccion = []
	_cantidad = 1


# ============================================================
#  PINTAR
# ============================================================

func build() -> void:
	var todas: Array = Game.recetas_cocina_tier(t.tier) if t.es_cocina() \
		else Game.recetas_boticaria_tier(t.tier)
	var lista: Array = todas
	if not t.es_cocina():
		lista = _en_orden_de_cadena(todas)
		lista = _filtrar(lista)
	t.stacks = lista
	# Arrancar en la primera receta QUE SE PUEDA HACER, no en la primera a secas: abrir en una con el
	# boton apagado parece que el taller esta roto.
	if t.sel == 0:
		for i in lista.size():
			if _hay_material_para(lista[i]):
				t.sel = i
				break
	t.contador(_contador(lista))
	var piezas: Array = []
	for r in lista:
		var rec: RecipeData = r as RecipeData
		var llevas: int = int(Game.consumables.get(rec.resultado, 0))
		piezas.append({"item": rec.resultado, "pie": "x%d" % llevas if llevas > 0 else "",
			"marca": "", "activo": true,
			"tooltip": "%s  ·  %s%s" % [rec.nombre(),
				"tienes material" if _hay_material_para(rec) else "te falta material",
				"  ·  llevas %d" % llevas if llevas > 0 else ""]})
	if Net.activo and lista.is_empty():
		Net.hogar.reservar({})   # sin receta no reservo nada
	t.grid_detail(piezas, _ficha, "No hay recetas aquí todavía.")


# Vida, maná y antídotos, cada cadena en su orden de escalon (base, +1, +2...). Asi, con cuatro
# columnas, cada fila de la rejilla es una cadena.
func _en_orden_de_cadena(recetas: Array) -> Array:
	var out: Array = []
	for tipo in [TIPO_VIDA, TIPO_MANA, TIPO_ANTIDOTO]:
		for r in recetas:
			var res: ConsumableData = (r as RecipeData).resultado
			if res != null and _tipo_de(res) == tipo:
				out.append(r)
	return out


# El filtro de encima de la rejilla. Antídotos solo sale si el tier los tiene.
func _filtrar(recetas: Array) -> Array:
	var nombres: Array = FILTROS.slice(0, 3)
	var iconos: Array = FILTRO_ICONOS.slice(0, 3)
	var hay_antidotos: bool = recetas.any(func(r): return _tipo_de((r as RecipeData).resultado) == TIPO_ANTIDOTO)
	if hay_antidotos:
		nombres.append(FILTROS[3])
		iconos.append(FILTRO_ICONOS[3])
	if _filtro >= nombres.size():
		_filtro = 0
	MenuScaffold.subpestanas(t.barra_sub, nombres, iconos, _filtro, _on_filtro)
	if _filtro == 0:
		return recetas
	t.titulo_seccion("%s  ·  %s" % [t.tabs()[t.tier - 1], FILTROS[_filtro]])
	return recetas.filter(func(r): return _tipo_de((r as RecipeData).resultado) == _filtro - 1)


func _on_filtro(i: int) -> void:
	if i == _filtro:
		return
	_filtro = i
	t.cambiar_pantalla()


static func _tipo_de(res: ConsumableData) -> int:
	if res == null:
		return -1
	if res.es_brebaje_de_estado():
		return TIPO_ANTIDOTO
	return TIPO_VIDA if res.cura_hp() else (TIPO_MANA if res.da_mana() else -1)


# Lo que llevas encima de lo que se hace aqui: es lo que decide si hace falta otra tanda.
func _contador(lista: Array) -> String:
	var total: int = 0
	for r in lista:
		total += int(Game.consumables.get((r as RecipeData).resultado, 0))
	if total <= 0:
		return ""
	return "Llevas %d %s" % [total, t.pieza_txt(total)]


# ¿Hay material EN PRINCIPIO para esta receta? (sin mirar la seleccion): poción base si es mejora +
# unidades totales suficientes por ingrediente.
func _hay_material_para(r: RecipeData) -> bool:
	if r == null or r.resultado == null:
		return false
	if r.es_mejora() and int(Game.consumables.get(r.pocion_base, 0)) <= 0:
		return false
	for ing in r.ingredientes:
		if ing == null or ing.material == null:
			continue
		if Game.disponible_unidades_material_en_hogar(ing.material) < ing.unidades:
			return false
	return true


# ============================================================
#  LA FICHA
# ============================================================

func _ficha(vb: VBoxContainer) -> void:
	var r: RecipeData = t.stacks[t.sel]
	var res: ConsumableData = r.resultado
	if _seleccion.size() != r.ingredientes.size():
		_seleccion = []
		for _ing in r.ingredientes:
			_seleccion.append({})
	# MULTI: capar mi seleccion a lo disponible y publicarla como reserva (el otro la ve apartada).
	_capar_y_publicar(r)

	MenuScaffold.titulo_item(vb, r.nombre(), IconoItem.color_escala(res))
	# La etiqueta dice lo que NO pone el titulo: de que es la poción (y de cual sale, si es mejora) o
	# cuantas raciones rinde el plato. El tier ya se lee arriba a la izquierda.
	var etiqueta: String = ""
	if t.es_cocina():
		etiqueta = "Rinde %d raciones" % r.unidades_resultado if r.unidades_resultado > 1 else ""
	else:
		etiqueta = String(FILTROS[_tipo_de(res) + 1]) if _tipo_de(res) >= 0 else ""
		if r.es_mejora():
			etiqueta += "  ·  mejora de %s" % r.pocion_base.nombre
	MenuScaffold.banner_item(vb, res, "", etiqueta)

	# QUE HACE, antes de gastar los ingredientes. En un plato son varias lineas (lo que sube y cuanto
	# dura), todo derivado de sus efectos: aqui no hay ni una cifra escrita a mano.
	MenuScaffold.titulo(vb, "LO QUE HACE", 13)
	var hace := Label.new()
	hace.text = res.resumen(Game.player_max_hp(), Game.player_max_mp())
	hace.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	vb.add_child(hace)
	if res.descripcion != "":
		t.note(vb, res.descripcion)

	var hornadas: int = Game.pociones_de_seleccion(r, _seleccion)
	var cuantas: int = maxi(1, hornadas)

	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "LO QUE LLEVA", 13)
	# La poción BASE de una mejora: coste FIJO, uno por hornada, no se elige.
	if r.es_mejora():
		var tengo_p: int = int(Game.consumables.get(r.pocion_base, 0))
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		MenuScaffold.celda_suelta(fila, r.pocion_base, LADO_CELDA_ING)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		# ESTIRADA: sin esto la columna nace a ancho cero, el autowrap de la ficha parte el nombre y sale
		# una letra por renglon (visto en captura).
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nom := Label.new()
		nom.text = r.pocion_base.nombre
		nom.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
		col.add_child(nom)
		var val := Label.new()
		val.text = "%d / %d en la bolsa" % [tengo_p, cuantas]
		val.add_theme_color_override("font_color", t.VERDE if tengo_p >= cuantas else t.ROJO)
		col.add_child(val)
		fila.add_child(col)
		vb.add_child(fila)

	# LOS INGREDIENTES, EN COLUMNAS: en vertical un plato de seis eran veinte renglones y la racion
	# doble quedaba fuera de la vista con media pantalla en blanco al lado.
	var cols := GridContainer.new()
	cols.columns = mini(COLUMNAS_ING_COCINA if t.es_cocina() else COLUMNAS_ING_POCIONES,
		maxi(1, r.ingredientes.size()))
	cols.add_theme_constant_override("h_separation", 12)
	cols.add_theme_constant_override("v_separation", 12)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	for i in r.ingredientes.size():
		var ing = r.ingredientes[i]
		if ing == null or ing.material == null:
			continue
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		col.add_theme_constant_override("separation", 2)
		cols.add_child(col)
		_ingrediente(col, i, ing.material, int(ing.unidades) * cuantas)
	t.note(vb, "Puro = 4 unidades · intacto = 3 · normal = 2 · dañado = 1. Mejor material = más probabilidad de que salga doble.")

	_doble(vb, r, hornadas)
	_pie(r, hornadas)


# ============================================================
#  UN INGREDIENTE: su celda, lo que llevas puesto y una fila por calidad
# ============================================================

func _ingrediente(vb: VBoxContainer, i: int, mat: MaterialData, necesita: int) -> void:
	var sel: Dictionary = _seleccion[i]
	var puestas: int = Game.uds_seleccion(sel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	MenuScaffold.celda_suelta(fila, mat, LADO_CELDA_ING, "T%d" % int(mat.tier))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nom := Label.new()
	nom.text = mat.nombre
	nom.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	col.add_child(nom)
	var val := Label.new()
	val.text = "%d / %d unidades" % [puestas, necesita]
	val.add_theme_color_override("font_color", t.VERDE if puestas >= necesita else t.ROJO)
	col.add_child(val)
	fila.add_child(col)
	vb.add_child(fila)

	# Si te pasas, decir lo que se gasta DE VERDAD (el resto se queda en el Hogar).
	if puestas >= necesita and necesita > 0:
		var gasto: Dictionary = Game.recortar_seleccion(sel, necesita)
		var gastadas: int = Game.uds_seleccion(gasto)
		var sobra: int = gastadas - necesita
		var partes: PackedStringArray = []
		if puestas > gastadas:
			partes.append("se gastan %d uds y el resto se queda en el Hogar" % gastadas)
		if sobra > 0:
			partes.append("sobran %d uds del recorte: vuelven como %d dañado(s)" % [sobra, sobra])
		if not partes.is_empty():
			t.note(vb, "; ".join(partes) + ".")

	var hubo: bool = false
	for cal in t.CALIDADES:
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))   # resta lo reservado
		if disp <= 0:
			continue
		hubo = true
		var ci: int = int(cal)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var lab := Label.new()
		lab.text = "%s (%d)" % [t.cal_txt(ci), disp]
		lab.custom_minimum_size = Vector2(88, 0)
		lab.add_theme_color_override("font_color", MaterialItem.crear(mat, ci).color())
		r.add_child(lab)
		MenuScaffold.stepper(r, int(sel.get(cal, 0)), 0, disp,
			func(n: int) -> void: _set_sel(i, ci, n),
			func(n: int) -> void: _set_sel(i, ci, n, false))
		vb.add_child(r)
	if not hubo:
		t.note(vb, "No tienes en el Hogar.")


# ============================================================
#  LA RACION DOBLE
# ============================================================

# Segun lo que se va a GASTAR (en vivo). Es POR pieza fabricada, y cada una tira con SU material (ver
# Game.lotes_de_seleccion): con material bueno para dos y del malo para otros dos, los dos primeros van
# al tope y los otros dos abajo.
func _doble(vb: VBoxContainer, r: RecipeData, hornadas: int) -> void:
	vb.add_child(HSeparator.new())
	var gasto: Array = Game.gasto_crafteo(r, _seleccion)
	var probs: Array = Game.probs_doble_por_pieza(r, gasto, hornadas)
	var pieza: String = t.pieza_txt()
	if probs.size() <= 1:
		var prob: float = float(probs[0]) if probs.size() == 1 else Game.prob_doble_desde_seleccion(r, gasto)
		MenuScaffold.titulo(vb, "SALE DOBLE", 13)
		var l := Label.new()
		l.text = "%d%%  por %s" % [roundi(prob * 100.0), pieza]
		l.add_theme_color_override("font_color", t.VERDE if prob > 0.0 else t.GRIS)
		vb.add_child(l)
		return
	MenuScaffold.titulo(vb, "SALE DOBLE  ·  cada %s con su material" % pieza, 13)
	var claves: Array = []
	for p in probs:
		claves.append(roundi(float(p) * 100.0))
	for tramo in MenuScaffold.tramos_iguales(claves):
		var p2: float = float(probs[int(tramo["i"])])
		var l2 := Label.new()
		l2.text = "%s  ·  %d%%" % [
			MenuScaffold.etiqueta_tramo(tramo, pieza.capitalize(), t.pieza_txt(2).capitalize()),
			roundi(p2 * 100.0)]
		l2.add_theme_color_override("font_color", t.VERDE if p2 > 0.0 else t.GRIS)
		vb.add_child(l2)


# ============================================================
#  EL PIE FIJO: cantidad, los dos Autos, Limpiar y el boton
# ============================================================

func _pie(r: RecipeData, hornadas: int) -> void:
	var vb: VBoxContainer = t.acciones()
	vb.add_child(HSeparator.new())
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	var k := Label.new()
	k.text = "Cantidad"
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	fila.add_child(k)
	MenuScaffold.stepper(fila, _cantidad, 1, 99, func(v: int) -> void: _cantidad = v)
	var auto_mej := Button.new()
	auto_mej.text = "Auto ▲"
	auto_mej.tooltip_text = "Rellena empezando por el MEJOR material que tengas (puro, intacto...). Más probabilidad de que salga doble."
	auto_mej.pressed.connect(_on_auto.bind(true))
	fila.add_child(auto_mej)
	var auto_peor := Button.new()
	auto_peor.text = "Auto ▼"
	auto_peor.tooltip_text = "Rellena empezando por el PEOR material que tengas (dañado, normal...). Para gastar lo que sobra sin tocar lo bueno."
	auto_peor.pressed.connect(_on_auto.bind(false))
	fila.add_child(auto_peor)
	var limpiar := Button.new()
	limpiar.text = "Limpiar"
	limpiar.pressed.connect(_on_limpiar)
	fila.add_child(limpiar)
	vb.add_child(fila)

	# CUANTAS salen de verdad: cada hornada rinde unidades_resultado piezas (2 en cocina). Sin
	# multiplicar, el boton prometia la mitad de los platos que salian.
	var piezas: int = hornadas * maxi(1, r.unidades_resultado)
	var verbo: String = "Cocinar" if t.es_cocina() else "Fabricar"
	var txt: String = "Elige materiales suficientes"
	if hornadas >= 1:
		txt = "%s  (%d %s)" % [verbo, piezas, t.pieza_txt(piezas)]
	MenuScaffold.pastilla(vb, txt, _on_fabricar, true, hornadas >= 1)


# Fija (absoluto) el contador de (ingrediente i, calidad cal) a `n`, acotado a lo que tienes en el
# baul. No rebuildea si el valor no cambia (evita que el focus_exited del LineEdit, al liberarse en el
# rebuild, se realimente). repintar=false: se esta ESCRIBIENDO; se guarda ya y se repinta al salir.
var _escrito_sin_repintar := false

func _set_sel(i: int, cal: int, n: int, repintar: bool = true) -> void:
	if i < 0 or i >= _seleccion.size() or t.stacks.is_empty():
		return
	var ing = (t.stacks[t.sel] as RecipeData).ingredientes[i]
	if ing == null or ing.material == null:
		return
	var disp: int = Game.disponible_calidad_en_hogar(ing.material, int(cal))
	var d: Dictionary = _seleccion[i]
	var nuevo: int = clampi(n, 0, disp)
	var cambia: bool = nuevo != int(d.get(cal, 0))
	if cambia:
		if nuevo <= 0:
			d.erase(cal)
		else:
			d[cal] = nuevo
	if not repintar:
		_escrito_sin_repintar = _escrito_sin_repintar or cambia
		return
	if cambia or _escrito_sin_repintar:
		_escrito_sin_repintar = false
		t.rebuild()


# Los dos Autos: ▲ empieza por el mejor material, ▼ por el peor. Rellenan para `_cantidad` hornadas;
# si no llega, rellenan lo que salga (el boton ya dice cuantas cubre eso).
func _on_auto(mejor_primero: bool) -> void:
	if t.stacks.is_empty():
		return
	_seleccion = Game.seleccion_auto(t.stacks[t.sel], _cantidad, mejor_primero)
	t.rebuild()


func _on_limpiar() -> void:
	_seleccion = []
	t.rebuild()


func _on_fabricar() -> void:
	if t.stacks.is_empty():
		return
	var receta: RecipeData = t.stacks[t.sel]
	var nombre: String = receta.nombre()
	if Net.activo and not await Net.hogar.abrir_taller():
		t.ocupado()
		t.rebuild()
		return
	var total: int = Game.craftear_con(receta, _seleccion)
	if Net.activo:
		Net.hogar.cerrar_taller()
		Net.hogar.liberar_mis_reservas()   # consumido: suelto la reserva
	if total > 0:
		t.decir("%s %d × %s. Está en tu bolsa." % ["Cocinas" if t.es_cocina() else "Fabricas", total, nombre])
		_seleccion = []   # los materiales cambiaron: empezar limpio
	else:
		t.decir("No te llega el material.", false)
	t.rebuild()


# ============================================================
#  MULTI: capar y publicar la seleccion
# ============================================================

# Capa mi seleccion a lo disponible (por si el compañero reservó de lo mismo) y la publica como
# reserva, aplanada a {"mat_id|cal": count}.
func _capar_y_publicar(r: RecipeData) -> void:
	var claim: Dictionary = {}
	for i in mini(r.ingredientes.size(), _seleccion.size()):
		var ing = r.ingredientes[i]
		if ing == null or ing.material == null:
			continue
		var sel: Dictionary = _seleccion[i]
		for cal in sel.keys():
			var disp: int = Game.disponible_calidad_en_hogar(ing.material, int(cal))
			var n: int = clampi(int(sel[cal]), 0, disp)
			if n <= 0:
				sel.erase(cal)
			else:
				sel[cal] = n
				var clave: String = "%s|%d" % [ing.material.id, int(cal)]
				claim[clave] = int(claim.get(clave, 0)) + n
	if Net.activo:
		Net.hogar.reservar(claim)
