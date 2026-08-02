# ============================================================
#  tannery_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del PELETERO. Tres pestañas:
#    1) CURTIR   - cuero crudo -> CUERO CURTIDO (lo unico que admite la forja).
#    2) CORREAS  - cuero curtido -> CORREAS (los tirantes de la mochila).
#    3) MOCHILAS - hebillas (del herrero) + correas + cuero curtido -> MOCHILA.
#
#  Curtir y hacer correas son REFINADOS: NO se mezclan calidades (N piezas de la MISMA calidad
#  dan una de esa calidad); solo la Peleteria puede regalarte un escalon. Coser la mochila, en
#  cambio, SI mezcla: la calidad media tira su RAREZA, que es lo unico que la diferencia (no
#  lleva mejoras). El TIER lo ponen las hebillas.
#
#  La math vive en Game/Forge; aqui solo se pinta.
# ============================================================

extends CanvasLayer

const TABS := ["Curtir", "Correas", "Mochilas"]

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

# De mejor a peor (el enum de calidad NO esta ordenado: PURO se añadio al final).
const CALIDADES := [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO,
	MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]

var _root: Control = null
var _header: VBoxContainer = null    # cabecera FIJA
var _content: VBoxContainer = null   # lo que se desplaza
var _aviso_lbl: Label = null         # linea de aviso, de altura fija (no empuja el titulo)
var _tab_buttons: Array = []
var _aviso: String = ""
var _aviso_ok: bool = true

var _tab: int = 0

# --- CURTIR ---
# Cual de las pieles conocidas se esta curtiendo (indice en Game.cueros_crudos_conocidos()).
# Antes solo habia una y no habia nada que elegir; con los sub-tiers hay hasta seis.
var _cue_tier: int = 0
var _cue_idx: int = 0

# --- MOCHILAS ---
var _heb_idx: int = 0                # metal de las hebillas (fija el tier)
# Tier de correa que se esta cosiendo en la pestaña CORREAS. Cada tier sale de SU curtido base,
# asi que aqui si hay que elegir (antes solo existia la de T1 y no habia nada que elegir).
var _cor_tier: int = 0
var _sel_heb: Dictionary = {}
var _sel_cor: Dictionary = {}
var _sel_cue: Dictionary = {}
# CUANTAS mochilas quieres que rellene el Auto. Es solo del boton Auto: lo que se cose de verdad sale
# de la seleccion (Game.piezas_de_coste), asi que si pides 5 y solo da para 4, salen 4.
var _cantidad: int = 1
# Tope de columnas de la rejilla de rareza de una tanda (ver MenuScaffold.tramos_por_calidad).
const MAX_COLUMNAS_RAREZA := 12


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("tannery_menu")

	# MULTI: refresco en vivo cuando el compañero toca el baul o su reserva (ver forge_menu).
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(_on_cambio_externo)
	if Net.has_signal("reservas_cambiadas"):
		Net.reservas_cambiadas.connect(_on_cambio_externo)

	var m: Dictionary = MenuScaffold.construir(self, "PELETERO",
		"Curte las pieles que traigas de la mazmorra. Sin cuero curtido no hay armadura que valga... ni mochila que te deje cargar con el botín.",
		_cerrar)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_aviso_lbl = m["aviso"]
	# El peletero no tiene cuadricula de piezas: una sola columna, a lo ancho.
	(m["lista_scroll"] as ScrollContainer).visible = false

	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		(m["side"] as VBoxContainer).add_child(b)
		_tab_buttons.append(b)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	# MULTI: ya no se coge el candado al abrir (los dos a la vez). Se coge solo al crear, y lo
	# seleccionado en Mochilas se RESERVA para el otro. Ver forge_menu.
	_tab = 0
	_aviso = ""
	_limpiar()
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu(self)
	if Net.activo:
		Net.liberar_mis_reservas()


func _on_cambio_externo() -> void:
	if _root != null and _root.visible:
		_rebuild()


func _ocupado() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("Un momento: tu compañero está creando algo justo ahora.")


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _limpiar() -> void:
	_sel_heb = {}
	_sel_cor = {}
	_sel_cue = {}


func _on_tab(i: int) -> void:
	_tab = i
	_aviso = ""
	_limpiar()
	_rebuild()


func _rebuild() -> void:
	for zona in [_header, _content]:
		MenuScaffold.vaciar(zona)
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	# Solo la pestaña MOCHILAS reserva (seleccion persistente); curtir/correas son instantaneas.
	if Net.activo and _tab != 2:
		Net.reservar({})

	match _tab:
		0: _build_refinar(false)   # piel -> cuero curtido
		1: _build_refinar(true)    # cuero curtido -> correa
		2: _build_mochilas()


# ============================================================
#  CURTIR y CORREAS: el mismo refinado, distinto material
# ============================================================

func _build_refinar(correas: bool) -> void:
	# CURTIR: se elige QUE piel (hay una por sub-tier). CORREAS: siempre del curtido base, que es
	# el que hace de tela para las mochilas.
	var pieles: Array = Game.cueros_crudos_conocidos()
	var piel: MaterialData = _piel_elegida()
	if piel == null:
		piel = Game.cuero_crudo()

	# CORREAS: hay una por TIER, y cada una se cose con el curtido BASE de su mismo tier. Asi la
	# cadena entera de una mochila T2 es de T2 (hebillas T2 + correa T2 + curtido T2) y subir de tier
	# no sale gratis por dos de los tres ingredientes.
	var correas_disp: Array = Game.correas_forja()
	var cor_tier: int = 1
	if correas and not correas_disp.is_empty():
		var idx: int = clampi(_cor_tier, 0, correas_disp.size() - 1)
		cor_tier = int((correas_disp[idx] as MaterialData).tier)

	var origen: MaterialData = Game.cuero_de_tier(cor_tier) if correas else piel
	var destino: MaterialData = Game.correa_de_tier(cor_tier) if correas else Game.curtido_de(piel)
	var por_uno: int = Forge.CUERO_POR_CORREA if correas else Forge.CUERO_POR_CURTIDO
	if destino == null:
		destino = Game.cuero_forja()
	if origen == null:
		origen = Game.cuero_forja()

	MenuScaffold.titulo(_header, "HACER CORREAS" if correas else "CURTIR")
	if correas:
		MenuScaffold.nota(_header, "%d de %s de la MISMA calidad = 1 correa de ese tier. Son los tirantes de la mochila: sin ellas, un fardo de cuero es un fardo de cuero. Cada tier de mochila pide la correa de SU tier." % [por_uno, origen.nombre.to_lower()])
	else:
		MenuScaffold.nota(_header, "%d pieles de la MISMA calidad = 1 cuero curtido de esa calidad. No se mezclan: juntando pieles rotas no sale una buena. Solo la Peletería puede regalarte un escalón." % por_uno)
	_header.add_child(HSeparator.new())

	# CORREAS: una fila de botones con los tiers que existen. No se usa selector_material porque no hay
	# sub-tiers que elegir dentro de un tier -- solo el tier.
	if correas:
		if correas_disp.size() > 1:
			var etiquetas: Array = []
			for c in correas_disp:
				etiquetas.append("%s  T%d" % [(c as MaterialData).nombre, int((c as MaterialData).tier)])
			MenuScaffold.cuadricula(_content, etiquetas, clampi(_cor_tier, 0, correas_disp.size() - 1),
				_on_correa_tier, MenuScaffold.COLUMNAS_SELECTOR, MenuScaffold.TAM_SELECTOR,
				MenuScaffold.colores_de(correas_disp))
			_content.add_child(HSeparator.new())

	# Selector en DOS niveles, igual que el herrero y el carpintero (ver
	# MenuScaffold.selector_material). Solo para CURTIR: ahi si hay una piel por sub-tier.
	if not correas:
		var elegida: MaterialData = MenuScaffold.selector_material(_content, pieles, "Piel",
			_cue_tier, _cue_idx, _on_piel_tier, _on_piel)
		if elegida != null:
			origen = elegida
			destino = Game.curtido_de(elegida)
		_content.add_child(HSeparator.new())
	_row("Sale", "%s  ·  Tier %d" % [destino.nombre, destino.tier])

	var tengo_algo: bool = false
	for cal in CALIDADES:
		var tengo: int = Game.disponible_calidad_en_hogar(origen, int(cal))   # resta lo reservado por el otro
		if int(cal) == MaterialItem.Calidad.PURO and tengo <= 0:
			continue
		tengo_algo = tengo_algo or tengo > 0
		var salen: int = tengo / maxi(1, por_uno)
		var c: int = int(cal)
		MenuScaffold.fila_refino(_content, "%s  ·  tienes %d  (máx %d)" % [_cal_txt(c), tengo, salen],
			salen, func(n: int) -> void: _on_refinar(correas, c, n))
	if not tengo_algo:
		if correas:
			_note("No tienes %s. Cúrtelo primero en la pestaña Curtir." % origen.nombre.to_lower())
		else:
			_note("No tienes pieles guardadas en el Hogar. Las sueltan los bichos con pelo; guárdalas al volver.")

	_content.add_child(HSeparator.new())
	MenuScaffold.titulo(_content, "EN EL ALMACÉN")
	var alguno: bool = false
	for cal in CALIDADES:
		var n: int = Game.items_calidad_en_hogar(destino, int(cal))
		if n > 0:
			alguno = true
			_row("%s (%s)" % [destino.nombre, _cal_txt(int(cal))], str(n))
	if not alguno:
		_note("Ningún %s todavía." % destino.nombre.to_lower())

	_estado_peleteria()


# Tier de la correa que se esta cosiendo ahora mismo en la pestaña CORREAS.
func _tier_correa() -> int:
	var lista: Array = Game.correas_forja()
	if lista.is_empty():
		return 1
	return int((lista[clampi(_cor_tier, 0, lista.size() - 1)] as MaterialData).tier)


func _on_correa_tier(i: int) -> void:
	_cor_tier = i
	_rebuild()


func _on_piel_tier(i: int) -> void:
	_cue_tier = i
	_cue_idx = 0   # al cambiar de gama se vuelve a la base
	_rebuild()


func _on_piel(i: int) -> void:
	_cue_idx = i
	_rebuild()


# La piel elegida ahora mismo, resolviendo los dos niveles del selector.
func _piel_elegida() -> MaterialData:
	var pieles: Array = Game.cueros_crudos_conocidos()
	var tiers: Array = MenuScaffold.tiers_de(pieles)
	if tiers.is_empty():
		return null
	var subs: Array = MenuScaffold.del_tier(pieles, int(tiers[clampi(_cue_tier, 0, tiers.size() - 1)]))
	if subs.is_empty():
		return null
	return subs[clampi(_cue_idx, 0, subs.size() - 1)] as MaterialData


func _on_refinar(correas: bool, cal: int, veces: int) -> void:
	if Net.activo and not await Net.abrir_taller():
		_ocupado()
		_rebuild()
		return
	var n: int = Game.hacer_correa(cal, veces, _tier_correa()) if correas 		else Game.curtir(cal, veces, _piel_elegida())
	if Net.activo:
		Net.cerrar_taller()
	if n > 0:
		_decir("Sacas %d %s de calidad %s." % [n, "correa(s)" if correas else "cuero(s)",
			_cal_txt(cal).to_lower()])
	else:
		_decir("No te llega el material.", false)
	_rebuild()


# ============================================================
#  MOCHILAS
# ============================================================

func _build_mochilas() -> void:
	MenuScaffold.titulo(_header, "COSER UNA MOCHILA")
	MenuScaffold.nota(_header, "Lo único que sube tu capacidad de carga. El METAL de las hebillas le pone el tier; la CALIDAD de lo que metas tira su rareza, que es lo único que la diferencia (una mochila no se mejora con núcleos). Y la Fuerza la aprovecha: multiplica el zurrón entero, mochila incluida.")
	_header.add_child(HSeparator.new())

	# Solo los metales que conoces (mismo criterio que el herrero: ver Game.materiales_vistos).
	var hebillas: Array = Game.hebillas_conocidas()
	if hebillas.is_empty():
		MenuScaffold.nota(_header, "No conoces ningún metal, y sin hebillas no hay mochila que valga. Pica una veta y pásate por el herrero.")
		return
	_heb_idx = clampi(_heb_idx, 0, hebillas.size() - 1)
	var heb: MaterialData = hebillas[_heb_idx]
	var coste: Dictionary = Game.MOCHILA_COSTE

	# --- El METAL, que es lo que fija el TIER de la mochila ---
	# Va con la MISMA pinta que el resto de los selectores de material del juego (4 por fila y botones
	# compactos, ver MenuScaffold.COLUMNAS_SELECTOR): esto era una rejilla a mano de 2 columnas que se
	# estiraban a todo el ancho, con botones de medio metro para escribir tres palabras.
	#
	# Y las etiquetas van con el nombre CORTO del metal ("Cobre T1"), como en el herrero: en una fila
	# de botones que dicen "Hebillas de cobre / Hebillas de hierro / Hebillas de acero", lo unico que
	# NO estas eligiendo es la palabra que repiten -- y encima hacia que la rejilla pareciera la fila
	# de ingredientes de abajo, repetida. Lo que eliges aqui es el metal; las hebillas son el
	# ingrediente, y salen abajo con sus contadores.
	MenuScaffold.titulo(_content, "Tier de la mochila (lo pone el metal de las hebillas)", 13)
	var etiquetas: Array = []
	var apagados: Array = []
	var pistas: Array = []
	for i in hebillas.size():
		var h: MaterialData = hebillas[i]
		var tengo: int = Game.disponible_unidades_material_en_hogar(h)
		etiquetas.append("T%d" % int(h.tier))
		# El nombre y las existencias, a un hover. Aqui se ven ADEMAS abajo, en los contadores del
		# ingrediente, asi que en el boton eran la tercera copia de lo mismo.
		pistas.append("%s  ·  tienes %d unidades" % [h.nombre, tengo])
		if tengo <= 0:
			apagados.append(i)
	MenuScaffold.cuadricula(_content, etiquetas, _heb_idx, _on_hebillas,
		MenuScaffold.COLUMNAS_SELECTOR, MenuScaffold.TAM_SELECTOR,
		MenuScaffold.colores_de(hebillas), apagados, pistas)

	# Aqui habia una fila "Tier: T2 (por las hebillas de hebillas de hierro)" -- con el nombre
	# duplicado por un bug de texto, y encima repitiendo lo que ya dicen el boton pulsado (el tier) y
	# el contador de abajo (que hebillas son). Fuera: lo que aporta el tier se ve en la tabla de
	# "Rareza que puede salir", que ya da la carga de cada rareza a ESTE tier.
	var tier: int = Forge.tier_de_metal(heb)

	# La CORREA y el CUERO son los de ESE tier, no los de T1: las hebillas mandan y el resto de la
	# cadena las sigue. Si a ese tier aun no le existe su correa (o su curtido), no hay mochila que
	# coser y se dice en vez de dejarte pelear con contadores vacios.
	var cor: MaterialData = Game.correa_de_mochila(heb)
	var cue: MaterialData = Game.cuero_de_mochila(heb)
	if cor == null or cue == null:
		_note("Todavía no hay correas ni cuero a la altura del T%d: esa mochila no se puede coser aún." % tier)
		return

	# --- Contadores de los tres materiales ---
	_content.add_child(HSeparator.new())
	# MULTI: capar cada seleccion a lo disponible (por si el compañero reservó de lo mismo).
	_capar(heb, _sel_heb)
	_capar(cor, _sel_cor)
	_capar(cue, _sel_cue)
	# ... y publicar las tres como MI reserva, para que el otro las vea apartadas en vivo.
	if Net.activo:
		var claim: Dictionary = {}
		_sumar_claim(claim, heb, _sel_heb)
		_sumar_claim(claim, cor, _sel_cor)
		_sumar_claim(claim, cue, _sel_cue)
		Net.reservar(claim)
	# CUANTAS mochilas salen con lo elegido: los contadores cuentan la TANDA entera, no una pieza.
	var mats: Array = [heb, cor, cue]
	var sels: Array = [_sel_heb, _sel_cor, _sel_cue]
	var uds: Array = [int(coste["hebillas"]), int(coste["correa"]), int(coste["cuero"])]
	var piezas: int = Game.piezas_de_coste(mats, sels, uds)
	var cuantas: int = maxi(1, piezas)
	for i in mats.size():
		_contadores(mats[i], sels[i], int(uds[i]) * cuantas)
	_note("Puro = 4 unidades · intacto = 3 · normal = 2 · dañado = 1. Meter buen material no abarata la mochila: mejora la RAREZA, y con ella lo que te cabe dentro.")

	# --- Rareza EN VIVO, y lo que daria cada una ---
	# Con una TANDA, cada mochila se cose con SU lote de material (el mejor va a las primeras, ver
	# Game.lotes_de_seleccion) y por tanto tira su propia rareza: eso va en rejilla de columnas, con
	# la carga de cada rareza debajo como leyenda.
	_content.add_child(HSeparator.new())
	var materiales: Array = []
	if piezas > 1:
		var gastos: Array = []
		for i in mats.size():
			gastos.append(Game.recortar_seleccion(sels[i], int(uds[i]) * piezas))
		for lote in Game.lotes_de_seleccion(gastos, uds, piezas):
			materiales.append(Game.score_uds(lote))
	var tramos: Array = MenuScaffold.tramos_por_calidad(materiales, MAX_COLUMNAS_RAREZA)
	if piezas > 1 and tramos.size() > 1:
		MenuScaffold.titulo(_content, "Rareza que puede salir  ·  %d mochilas, cada una con su material" % piezas)
		# La carga de cada rareza va en la ULTIMA columna de la misma rejilla, no en una tabla aparte
		# debajo: separada, la lista de rarezas salia dos veces en la misma pantalla.
		var cargas: Array = []
		for i in Upgrades.RAREZA_NOMBRE.size():
			cargas.append("+%.0f de carga" % _carga_de(tier, i))
		_rejilla_mochila(materiales, tramos, heb, cargas)
	else:
		var score: float = Game.score_mochila(heb, _sel_heb, _sel_cor, _sel_cue)
		MenuScaffold.titulo(_content, "Rareza que puede salir%s" % (
			"" if piezas <= 1 else "  ·  %d mochilas con el mismo material" % piezas))
		var probs: Array = Forge.probs_rareza(score)
		for i in probs.size():
			var p: float = float(probs[i])
			if p <= 0.0:
				continue
			_row(Upgrades.rareza_nombre(i), "%s%%   →  +%.0f de carga" % [
				str(snappedf(p * 100.0, 0.1)), _carga_de(tier, i)],
				Upgrades.rareza_color(i))
	_row("Llevas ahora", "%d de capacidad" % roundi(Game.capacidad_carga()))

	# --- Cantidad + los dos Autos, igual que en el herrero ---
	_content.add_child(HSeparator.new())
	var acc := HBoxContainer.new()
	acc.add_theme_constant_override("separation", 8)
	var cant_lbl := Label.new()
	cant_lbl.text = "Cantidad"
	acc.add_child(cant_lbl)
	MenuScaffold.stepper(acc, _cantidad, 1, 99, func(v: int) -> void: _cantidad = v)
	var auto_mej := Button.new()
	auto_mej.text = "Auto ▲"
	auto_mej.tooltip_text = "Rellena empezando por el MEJOR material que tengas (puro, intacto...). Sube la rareza que puede salir."
	auto_mej.pressed.connect(_on_auto.bind(true))
	acc.add_child(auto_mej)
	var auto_peor := Button.new()
	auto_peor.text = "Auto ▼"
	auto_peor.tooltip_text = "Rellena empezando por el PEOR material que tengas (dañado, normal...). Para gastar lo que sobra sin tocar lo bueno."
	auto_peor.pressed.connect(_on_auto.bind(false))
	acc.add_child(auto_peor)
	var limpiar := Button.new()
	limpiar.text = "Limpiar"
	limpiar.pressed.connect(_on_limpiar_mochila)
	acc.add_child(limpiar)
	_content.add_child(acc)

	var txt: String = "Faltan materiales"
	if piezas == 1:
		txt = "Coser la mochila"
	elif piezas > 1:
		txt = "Coser (%d mochilas)" % piezas
	var b_hacer := Button.new()
	b_hacer.text = txt
	b_hacer.disabled = piezas < 1
	b_hacer.custom_minimum_size = Vector2(0, 36)
	b_hacer.pressed.connect(_on_coser)
	_content.add_child(b_hacer)

	_estado_peleteria()


# La rejilla de una tanda de mochilas: una columna por tramo de piezas iguales, una fila por rareza.
# Misma forma que la del herrero (MenuScaffold.rejilla_probs), que las dos tiran con score_final.
func _rejilla_mochila(materiales: Array, tramos: Array, heb: MaterialData, cargas: Array) -> void:
	var oficio: float = Forge.bonus_herreria(Game.peleteria_activa())
	var bono_metal: float = Forge.bonus_metal(heb)
	var corto: bool = tramos.size() > 6
	var cabeceras: Array = []
	var calidad: Array = []
	var tier_pct: Array = []
	var aporta: bool = false
	var probs_col: Array = []
	var sale: Dictionary = {}
	for tramo in tramos:
		var mat_c: float = float(materiales[int(tramo["i"])])
		cabeceras.append(MenuScaffold.numeros_tramo(tramo))
		calidad.append("%d%%" % roundi(mat_c * 100.0))
		# El empujon del TIER solo se enseña si empuja: con hebillas T1, o con material intacto (el
		# tope de score_final no le deja sumar), es siempre cero.
		var p_t: int = roundi((Forge.score_final(mat_c, oficio, bono_metal)
			- Forge.score_final(mat_c, oficio, 0.0)) * 100.0)
		tier_pct.append("%+d%%" % p_t)
		aporta = aporta or p_t != 0
		var probs: Array = Forge.probs_rareza(Forge.score_final(mat_c, oficio, bono_metal))
		probs_col.append(probs)
		for i in probs.size():
			if float(probs[i]) > 0.0:
				sale[i] = true
	var filas: Array = [{"etiqueta": "calidad", "color": GRIS, "valores": calidad}]
	if aporta:
		filas.append({"etiqueta": "categoría", "color": GRIS, "valores": tier_pct})
	var rarezas: Array = sale.keys()
	rarezas.sort()
	for r in rarezas:
		var valores: Array = []
		for c in probs_col.size():
			var p: float = float((probs_col[c] as Array)[int(r)])
			if p <= 0.0:
				valores.append(MenuScaffold.GUION)
			else:
				valores.append("%d%%" % roundi(p * 100.0) if corto
					else "%s%%" % str(snappedf(p * 100.0, 0.1)))
		filas.append({"etiqueta": Upgrades.rareza_nombre(int(r)),
			"color": Upgrades.rareza_color(int(r)), "valores": valores,
			"extra": str(cargas[int(r)]) if int(r) < cargas.size() else ""})
	MenuScaffold.rejilla_probs(_content, "pieza", cabeceras, filas, "aporta", _content.size.x)


# Los dos Autos: ▲ empieza por el mejor material, ▼ por el peor. Rellenan para `_cantidad` mochilas;
# si no llega, rellenan lo que salga (el boton de coser ya dice cuantas cubre eso).
func _on_auto(mejor_primero: bool) -> void:
	var hebillas: Array = Game.hebillas_conocidas()
	if hebillas.is_empty():
		return
	var heb: MaterialData = hebillas[clampi(_heb_idx, 0, hebillas.size() - 1)]
	var cor: MaterialData = Game.correa_de_mochila(heb)
	var cue: MaterialData = Game.cuero_de_mochila(heb)
	if cor == null or cue == null:
		return
	var veces: int = maxi(1, _cantidad)
	var coste: Dictionary = Game.MOCHILA_COSTE
	_sel_heb = _auto_sel(heb, int(coste["hebillas"]) * veces, mejor_primero)
	_sel_cor = _auto_sel(cor, int(coste["correa"]) * veces, mejor_primero)
	_sel_cue = _auto_sel(cue, int(coste["cuero"]) * veces, mejor_primero)
	_rebuild()


# Rellena una seleccion con `necesita` unidades de `mat`, de mejor a peor (o al reves). Lee lo
# DISPONIBLE, no el stock a secas: en multijugador no se pide lo que el compañero tiene reservado.
func _auto_sel(mat: MaterialData, necesita: int, mejor_primero: bool) -> Dictionary:
	var sel: Dictionary = {}
	var restante: int = necesita
	var orden: Array = CALIDADES.duplicate()
	if not mejor_primero:
		orden.reverse()
	for cal in orden:
		if restante <= 0:
			break
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))
		var uds: int = MaterialItem.crear(null, int(cal)).unidades_crafteo()
		if disp <= 0 or uds <= 0:
			continue
		var usar: int = mini(int(ceil(float(restante) / float(uds))), disp)
		if usar > 0:
			sel[cal] = usar
			restante -= usar * uds
	return sel


func _on_limpiar_mochila() -> void:
	_limpiar()
	_rebuild()


# Lo que daria una mochila de este tier y esta rareza (derivado, nunca escrito a mano).
func _carga_de(tier: int, rareza: int) -> float:
	return Game.mochila_base().capacidad * Game.mochila_tier_factor(tier) \
		* Upgrades.rareza_mult_capacidad(rareza)


func _on_hebillas(i: int) -> void:
	_heb_idx = i
	_sel_heb = {}
	_rebuild()


func _on_coser() -> void:
	var hebillas: Array = Game.hebillas_conocidas()
	if hebillas.is_empty():
		return
	var heb: MaterialData = hebillas[clampi(_heb_idx, 0, hebillas.size() - 1)]
	if Net.activo and not await Net.abrir_taller():
		_ocupado()
		_rebuild()
		return
	# TANDA: se cosen todas las que cubra lo elegido, cada una con su lote de material y su tirada.
	var coste: Dictionary = Game.MOCHILA_COSTE
	var piezas: int = Game.piezas_de_coste(
		[heb, Game.correa_de_mochila(heb), Game.cuero_de_mochila(heb)],
		[_sel_heb, _sel_cor, _sel_cue],
		[int(coste["hebillas"]), int(coste["correa"]), int(coste["cuero"])])
	var hechas: Array = Game.fabricar_mochila_tanda(heb, _sel_heb, _sel_cor, _sel_cue, piezas)
	if Net.activo:
		Net.cerrar_taller()
		Net.liberar_mis_reservas()   # consumido: suelto la reserva
	if hechas.size() == 1:
		_decir("Coses %s: +%.0f de carga. Equípala en el menú de personaje [C]." % [
			Game.item_display_name(hechas[0]), Game.capacidad_mochila(hechas[0] as BackpackData)])
	elif hechas.size() > 1:
		var nombres: PackedStringArray = []
		for m in hechas:
			nombres.append(Game.item_display_name(m as Resource))
		_decir("Coses %d mochilas: %s. Están en tu baúl [C]." % [hechas.size(), ", ".join(nombres)])
	else:
		_decir("Te faltan materiales.", false)
	_limpiar()
	_rebuild()


# MULTI: capa una seleccion {cal: count} a lo DISPONIBLE de 'mat' (resta lo reservado por el otro).
func _capar(mat: MaterialData, sel: Dictionary) -> void:
	if mat == null:
		return
	for cal in sel.keys():
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))
		var n: int = clampi(int(sel[cal]), 0, disp)
		if n <= 0:
			sel.erase(cal)
		else:
			sel[cal] = n


# Suma una seleccion {cal: count} de 'mat' al claim {"mat_id|cal": count}.
func _sumar_claim(claim: Dictionary, mat: MaterialData, sel: Dictionary) -> void:
	if mat == null:
		return
	for cal in sel:
		var n: int = int(sel[cal])
		if n > 0:
			var clave: String = "%s|%d" % [mat.id, int(cal)]
			claim[clave] = int(claim.get(clave, 0)) + n


# Fila "material: −  n  +" por cada calidad que tengas en el baul (igual que en el herrero).
func _contadores(mat: MaterialData, sel: Dictionary, necesita: int) -> void:
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
	_content.add_child(row)

	# Si te pasas, decir lo que se gasta DE VERDAD (el resto se queda en el Hogar).
	if uds >= necesita and necesita > 0:
		var gasto: Dictionary = Game.recortar_seleccion(sel, necesita)
		var gastadas: int = Game.uds_seleccion(gasto)
		var sobra: int = gastadas - necesita
		var partes: PackedStringArray = []
		if uds > gastadas:
			partes.append("se gastan %d uds y el resto se queda en el Hogar" % gastadas)
		if sobra > 0:
			partes.append("sobran %d uds del recorte: vuelven como %d dañado(s)" % [sobra, sobra])
		if not partes.is_empty():
			_note("   " + "; ".join(partes) + ".")

	var hubo: bool = false
	for cal in CALIDADES:
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))   # resta lo reservado por el otro
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
		_content.add_child(r)
	if not hubo:
		_note("   No tienes %s en el Hogar." % mat.nombre.to_lower())


# Fija (absoluto) la cantidad elegida de `cal` en `sel`, acotada a `disp`. Lo llama el stepper
# editable. No rebuildea si no cambia (evita el bucle de focus_exited al liberar el LineEdit).
func _set_sel_mat(sel: Dictionary, cal: int, disp: int, n: int) -> void:
	var nuevo: int = clampi(n, 0, disp)
	if nuevo == int(sel.get(cal, 0)):
		return
	if nuevo <= 0:
		sel.erase(cal)
	else:
		sel[cal] = nuevo
	_rebuild()


# Linea de sabor del oficio, SIN numeros (misma regla que en la forja, ver Forge_menu._estado_oficio):
# el contador es OCULTO porque es lo que decide si la habilidad te sale al subir de nivel. Bloqueada
# -> no se pinta nada, ni el separador. Los numeros, en el panel de debug.
func _estado_peleteria() -> void:
	if not Game.tiene_desarrollo("peleteria"):
		return
	_content.add_child(HSeparator.new())
	_row("Peletería", "activa")
	_note("Tira por sacar el cuero un escalón por encima de la piel que metas.")


func _decir(txt: String, ok: bool = true) -> void:
	_aviso = txt
	_aviso_ok = ok


func _cal_txt(cal: int) -> String:
	match cal:
		MaterialItem.Calidad.PURO: return "Puro"
		MaterialItem.Calidad.INTACTO: return "Intacto"
		MaterialItem.Calidad.NORMAL: return "Normal"
		MaterialItem.Calidad.DANADO: return "Dañado"
		_: return "Roto"


func _row(etiqueta: String, valor: String, color_valor: Variant = null) -> void:
	MenuScaffold.fila(_content, etiqueta, valor, 200, color_valor)


func _note(txt: String) -> void:
	MenuScaffold.nota(_content, txt)
