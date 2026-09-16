# ============================================================
#  peleteria_refinar.gd  --  pestañas CURTIR y CORREAS de la peleteria (ver tannery_menu.gd, que
#  es el armazon). Son la MISMA pantalla con otro material:
#    - CURTIR:  N pieles de la misma calidad -> 1 cuero curtido de esa calidad.
#    - CORREAS: N cueros curtidos de la misma calidad -> 1 correa de ese tier.
#
#  LA REJILLA SON LOS MONTONES, uno por material Y CALIDAD, igual que se ven en el baul: el color
#  de la celda dice la calidad y la banda dice cuantos hay. Antes esto era un selector de dos
#  niveles (gama y sub-tier) mas una fila de botones de tier para las correas, y en ninguno de los
#  dos se veia lo que tenias: habia que elegir a ciegas y leer los contadores despues.
#
#  Eso se lleva por delante los tres selectores viejos: con una celda por monton, el material, su
#  tier y su calidad ya estan en la rejilla.
#
#  Las calidades NO se mezclan (es un refinado), asi que cada monton es una operacion aparte: por
#  eso son celdas distintas y no una sola celda con un desplegable de calidad.
# ============================================================
extends RefCounted

# El lado de las celdas de "ya tienes", dentro de la ficha. Mas pequeñas que las de la rejilla (96):
# ahi no se pulsa, solo se mira cuanto llevas.
const LADO_CELDA_ALMACEN := 64.0

var t = null   # el armazon (tannery_menu.gd)
# El tier que se esta mirando. 0 = todos. Se recuerda entre pestañas a proposito: quien esta
# trabajando el T2 lo esta trabajando en las dos.
var _tier: int = 0
# Cuantas tandas se van a hacer del monton elegido. -1 = que la ficha elija (el maximo que salga).
var _cant: int = -1
# De QUE monton es esa cantidad. Sin esto se arrastraba: elegias 2 en un monton, pulsabas otro que
# daba para 5 y la ficha seguia diciendo 2 (visto en captura, al pasar de Curtir a Correas).
var _cant_de: String = ""


func _init(armazon) -> void:
	t = armazon


# ============================================================
#  PINTAR
# ============================================================

func build(correas: bool) -> void:
	var todos: Array = _recoger(correas)
	# EL FILTRO POR TIER, en su fila encima de la rejilla. Solo sale si hay mas de un tier que
	# elegir: con una sola piel conocida, una fila de un boton no filtra nada y estorba.
	var tiers: Array = _tiers_de(todos)
	var montones: Array = todos
	if tiers.size() > 1:
		var nombres: Array = ["Todo"]
		var iconos: Array = ["todo"]
		for tier in tiers:
			nombres.append("Tier %d" % int(tier))
			iconos.append("tier_%d" % int(tier))
		var activa: int = 0 if _tier <= 0 else maxi(0, tiers.find(_tier) + 1)
		MenuScaffold.subpestanas(t.barra_sub, nombres, iconos, activa,
			func(i: int) -> void: _on_tier(0 if i == 0 else int(tiers[i - 1])))
		if _tier > 0:
			montones = []
			for m in todos:
				if int(m["tier"]) == _tier:
					montones.append(m)
			t.titulo_seccion("%s  ·  Tier %d" % [t.TABS[t._tab], _tier])
	else:
		_tier = 0
	t.stacks = montones
	# Arrancar en el primer monton QUE DE PARA ALGO, no en el primero a secas: los montones van por
	# calidad (puro delante, como en el baul) y con un solo puro la pantalla abria en un "dan para 0"
	# con el boton apagado, que parece que la peleteria esta rota.
	if t.sel == 0:
		var i: int = _primero_util(montones)
		if i > 0:
			t.sel = i
	t.contador(_contador(correas, montones))
	var piezas: Array = []
	for m in montones:
		# EL DIBUJO ES LO QUE VA A SALIR, no la piel que metes (lo pidio el usuario): esta pantalla
		# es para fabricar, y lo que buscas con el ojo es el cuero (o la correa) que quieres tener.
		# De que sale y cuanto llevas lo dicen el pie, el tooltip y la ficha.
		# Los nombres salen del MaterialData ('mat' / 'destino') y NO de los MaterialItem que se
		# pintan: castear un MaterialItem a MaterialData da null, no el data de dentro.
		# La CALIDAD va escrita en la esquina y no solo en el color: la rejilla tiene hasta cuatro
		# montones del mismo material, uno por calidad, y son operaciones distintas -- pulsar el que
		# no era gasta del bueno.
		piezas.append(t.pieza(m["sale"], "x%d" % int(m["tengo"]),
			"%s (%s)  ·  de %s  ·  tienes %d" % [(m["destino"] as MaterialData).nombre,
				t.cal_txt(int(m["cal"])), (m["mat"] as MaterialData).nombre, int(m["tengo"])],
			t.cal_txt(int(m["cal"]))))
	t.grid_detail(piezas, func(vb: VBoxContainer) -> void: _ficha(vb, correas), _vacio(correas))


# El contador de arriba: cuanto material de esta pestaña tienes en total. No es del monton elegido
# (eso va en la ficha): es el estado del almacen, que es lo que decide si bajas a por mas.
func _contador(correas: bool, montones: Array) -> String:
	var total: int = 0
	for m in montones:
		total += int(m["tengo"])
	if total <= 0:
		return ""
	return "%d %s" % [total, "cueros curtidos" if correas else "pieles"]


# El primer monton que da para al menos una pieza, o 0 si ninguno (entonces se queda el primero y la
# ficha ya explica que no llega).
func _primero_util(montones: Array) -> int:
	for i in montones.size():
		var m: Dictionary = montones[i]
		if int(m["tengo"]) / maxi(1, int(m["por_uno"])) > 0:
			return i
	return 0


func _vacio(correas: bool) -> String:
	if correas:
		return "No tienes cuero curtido. Cúrtelo primero en la pestaña Curtir."
	return "No tienes pieles guardadas en el Hogar. Las sueltan los bichos con pelo; guárdalas al volver."


# ============================================================
#  QUE HAY PARA REFINAR
#  Un monton por material y calidad: {modelo, cal, tengo, destino, por_uno, tier}
# ============================================================

func _recoger(correas: bool) -> Array:
	var out: Array = []
	# CURTIR: una piel por sub-tier (las que conoces). CORREAS: el curtido BASE de cada tier, que es
	# el que hace de tela -- cada tier de mochila pide la correa de SU tier, asi que subir de tier no
	# sale gratis por dos de los tres ingredientes.
	var origenes: Array = []
	if correas:
		for c in Game.correas_forja():
			var tier: int = int((c as MaterialData).tier)
			var cuero: MaterialData = Game.cuero_de_tier(tier)
			if cuero != null:
				origenes.append(cuero)
	else:
		origenes = Game.cueros_crudos_conocidos()

	var por_uno: int = Forge.CUERO_POR_CORREA if correas else Forge.CUERO_POR_CURTIDO
	for o in origenes:
		var origen: MaterialData = o as MaterialData
		if origen == null:
			continue
		var destino: MaterialData = Game.correa_de_tier(int(origen.tier)) if correas \
			else Game.curtido_de(origen)
		if destino == null:
			continue
		for cal in t.CALIDADES:
			# disponible_ (y no items_): en multi resta lo que el compañero tenga reservado.
			var tengo: int = Game.disponible_calidad_en_hogar(origen, int(cal))
			if tengo <= 0:
				continue
			out.append({
				# 'sale' es lo que se pinta en la celda (lo que vas a crear) y 'modelo' lo que
				# gastas: los dos se necesitan, y los dos con la MISMA calidad -- el refinado no
				# mezcla, asi que de un monton intacto sale un curtido intacto.
				"sale": MaterialItem.crear(destino, int(cal)),
				"modelo": MaterialItem.crear(origen, int(cal)),
				"mat": origen, "cal": int(cal), "tengo": tengo,
				"destino": destino, "por_uno": por_uno, "tier": int(origen.tier),
			})
	return out


# Los tiers que hay entre los montones, de menor a mayor.
func _tiers_de(montones: Array) -> Array:
	var vistos: Dictionary = {}
	for m in montones:
		vistos[int(m["tier"])] = true
	var out: Array = vistos.keys()
	out.sort()
	return out


func _on_tier(tier: int) -> void:
	if tier == _tier:
		return
	_tier = tier
	t.cambiar_pantalla()


# ============================================================
#  LA FICHA
# ============================================================

func _ficha(vb: VBoxContainer, correas: bool) -> void:
	var s: Dictionary = t.stacks[t.sel]
	var origen: MaterialData = s["mat"]
	var destino: MaterialData = s["destino"]
	var por_uno: int = int(s["por_uno"])
	var tengo: int = int(s["tengo"])
	var salen: int = tengo / maxi(1, por_uno)

	# LO QUE SALE, con su banner: es la pregunta de esta pantalla, no lo que metes (que ya lo estas
	# viendo marcado en la rejilla).
	MenuScaffold.titulo_item(vb, "%s (%s)" % [destino.nombre, t.cal_txt(int(s["cal"]))],
		IconoItem.color_escala(destino))
	MenuScaffold.banner_item(vb, MaterialItem.crear(destino, int(s["cal"])), "",
		"Tier %d" % int(destino.tier))
	vb.add_child(HSeparator.new())
	t.row(vb, "De", "%s (%s)" % [origen.nombre, t.cal_txt(int(s["cal"]))])
	t.row(vb, "Hacen falta", "%d por cada uno" % por_uno)
	t.row(vb, "Tienes", "%d  ·  dan para %d" % [tengo, salen], t.VERDE if salen > 0 else t.ROJO)
	_en_el_almacen(vb, destino)
	if correas:
		t.note(vb, "Son los tirantes de la mochila: sin ellas, un fardo de cuero es un fardo de cuero. Cada tier de mochila pide la correa de SU tier.")
	else:
		t.note(vb, "Las calidades no se mezclan: juntando pieles rotas no sale una buena. Solo la Peletería puede regalarte un escalón.")
	t.estado_peleteria(vb)

	_pie(correas, s, salen)


# LO QUE YA TIENES DE ESO, en celdas y no en una linea de texto. Ocupa el hueco que quedaba entre la
# ficha y el pie, y de paso contesta la pregunta que uno se hace antes de curtir otra tanda: cuanto
# llevo ya, y de que calidad. Una fila "En el almacen: 9 cuero simple" no dice de que calidad son.
func _en_el_almacen(vb: VBoxContainer, destino: MaterialData) -> void:
	var hay: Array = []
	for cal in t.CALIDADES:
		var n: int = Game.items_calidad_en_hogar(destino, int(cal))
		if n > 0:
			hay.append({"cal": int(cal), "n": n})
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "YA TIENES", 13)
	if hay.is_empty():
		t.note(vb, "Ningún %s todavía." % destino.nombre.to_lower())
		return
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	vb.add_child(fila)
	for h in hay:
		MenuScaffold.celda_suelta(fila, MaterialItem.crear(destino, int(h["cal"])),
			LADO_CELDA_ALMACEN, "x%d" % int(h["n"]), t.cal_txt(int(h["cal"])))


# El pie fijo: cuantas tandas y el boton. Fuera del scroll de la ficha, siempre a la vista.
func _pie(correas: bool, s: Dictionary, salen: int) -> void:
	var vb: VBoxContainer = t.acciones()
	vb.add_child(HSeparator.new())
	# Monton nuevo: se arranca al MAXIMO. Es lo que se quiere casi siempre (curtir todo lo que
	# llevas), y bajar es un toque.
	var clave: String = "%s|%d" % [String((s["mat"] as MaterialData).id), int(s["cal"])]
	if clave != _cant_de or _cant < 1 or _cant > maxi(1, salen):
		_cant = maxi(1, salen)
		_cant_de = clave
	var total := Label.new()
	total.add_theme_font_size_override("font_size", 15)
	var refrescar := func(n: int) -> void:
		total.text = "Salen %d  ·  gastas %d" % [n, n * int(s["por_uno"])]
		total.add_theme_color_override("font_color", t.AMBAR)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = "Cantidad"
	k.custom_minimum_size = Vector2(90, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	fila.add_child(k)
	# El numero vale AL ESCRIBIR, sin Enter (ver MenuScaffold.stepper): el total se reescribe en
	# sitio, sin rehacer el panel, que es la trampa que avisa el propio stepper.
	MenuScaffold.stepper(fila, _cant, 1, maxi(1, salen),
		func(n: int) -> void:
			_cant = n
			refrescar.call(n),
		func(n: int) -> void:
			_cant = n
			refrescar.call(n))
	vb.add_child(fila)
	refrescar.call(_cant)
	vb.add_child(total)

	MenuScaffold.pastilla(vb, "Hacer correas" if correas else "Curtir",
		func() -> void: _refinar(correas, s), true, salen > 0)


func _refinar(correas: bool, s: Dictionary) -> void:
	var veces: int = clampi(_cant, 1, maxi(1, int(s["tengo"]) / maxi(1, int(s["por_uno"]))))
	if Net.activo and not await Net.hogar.abrir_taller():
		t.ocupado()
		t.rebuild()
		return
	var n: int = Game.hacer_correa(int(s["cal"]), veces, int(s["tier"])) if correas \
		else Game.curtir(int(s["cal"]), veces, s["mat"] as MaterialData)
	if Net.activo:
		Net.hogar.cerrar_taller()
	if n > 0:
		t.decir("Sacas %d %s de calidad %s." % [n,
			"correa(s)" if correas else "cuero(s)", t.cal_txt(int(s["cal"])).to_lower()])
	else:
		t.decir("No te llega el material.", false)
	# El montón se ha encogido (o ha desaparecido): la cantidad vuelve a salir del nuevo máximo.
	_cant = -1
	t.rebuild()
