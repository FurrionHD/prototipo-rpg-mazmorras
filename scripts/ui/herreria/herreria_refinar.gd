# ============================================================
#  herreria_refinar.gd  --  los REFINADOS de la herreria y la carpinteria (ver forge_menu.gd, el
#  armazon). Es la misma pantalla que CURTIR en la peleteria (peleteria_refinar.gd) con otro material:
#    - FUNDIR:    N minerales de la misma calidad  -> 1 lingote de esa calidad.
#    - CHAPAS:    N lingotes                       -> 1 chapa (lo que pide la armadura).
#    - HEBILLAS:  N lingotes                       -> 1 juego de hebillas (mochilas y armadura de cuero).
#    - TABLONES:  N maderas                        -> 1 tablon (el mango de las armas).
#    - CARBONERA: N maderas                        -> 1 carbon (el combustible del farolillo).
#
#  LA REJILLA SON LOS MONTONES, uno por material Y CALIDAD, como en el baul, y la celda pinta LO QUE
#  SALE. Sustituye al selector de dos niveles (gama y veta) y a la lista de filas con su boton: con una
#  celda por monton, el material, su veta y su calidad ya estan a la vista.
#
#  Las calidades NO se mezclan (es un refinado): cada monton es una operacion aparte. Solo el oficio
#  (Herreria o Carpinteria) puede regalar un escalon.
# ============================================================
extends RefCounted

enum Que { FUNDIR, CHAPAS, HEBILLAS, TABLONES, CARBON }

const LADO_CELDA_ALMACEN := 64.0

var t = null   # el armazon (forge_menu.gd)
# El tier que se esta mirando. 0 = todos. Se recuerda entre pestañas: quien trabaja el T2 lo trabaja
# en todas.
var _tier: int = 0
# Cuantas tandas se van a hacer del monton elegido, y de QUE monton es (si no, se arrastraba al
# cambiar de celda).
var _cant: int = 1
var _cant_de: String = ""


func _init(armazon) -> void:
	t = armazon


# ============================================================
#  PINTAR
# ============================================================

func build(que: int) -> void:
	var todos: Array = _recoger(que)
	var tiers: Array = _tiers_de(todos)
	var montones: Array = todos
	# EL FILTRO POR TIER, solo si hay mas de un tier que elegir.
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
			montones = todos.filter(func(m): return int(m["tier"]) == _tier)
			t.titulo_seccion("%s  ·  Tier %d" % [t.nombre_tab(), _tier])
	else:
		_tier = 0
	t.stacks = montones
	# Arrancar en el primer monton QUE DE PARA ALGO: abrir en un "dan para 0" con el boton apagado
	# parece que el taller esta roto.
	if t.sel == 0:
		for i in montones.size():
			if int(montones[i]["tengo"]) / maxi(1, int(montones[i]["por_uno"])) > 0:
				t.sel = i
				break
	t.contador(_contador(que, montones))
	var piezas: Array = []
	for m in montones:
		# EL DIBUJO ES LO QUE VA A SALIR, no lo que metes. La CALIDAD va escrita en la esquina y no solo
		# en el color: hay hasta cuatro montones del mismo material y pulsar el que no era gasta del bueno.
		piezas.append(t.pieza(m["sale"], "x%d" % int(m["tengo"]),
			"%s (%s)  ·  de %s  ·  tienes %d" % [(m["destino"] as MaterialData).nombre,
				t.cal_txt(int(m["cal"])), (m["mat"] as MaterialData).nombre, int(m["tengo"])],
			t.cal_txt(int(m["cal"]))))
	t.grid_detail(piezas, func(vb: VBoxContainer) -> void: _ficha(vb, que), _vacio(que))


func _contador(que: int, montones: Array) -> String:
	if que == Que.CARBON:
		# En la carbonera lo que importa es cuanta luz te queda, no cuanta madera hay.
		var trozos: int = Game.carbon.size()
		return "" if trozos == 0 else "Carbón: %s de luz" % _mmss(Game.luz_total_restante() - Game.lampara_llama)
	var total: int = 0
	for m in montones:
		total += int(m["tengo"])
	if total <= 0:
		return ""
	match que:
		Que.FUNDIR: return "%d minerales" % total
		Que.TABLONES: return "%d maderas" % total
		_: return "%d lingotes" % total


func _vacio(que: int) -> String:
	match que:
		Que.FUNDIR: return "No tienes mineral en el Hogar. Pica vetas en la mazmorra y guárdalo al volver."
		Que.CHAPAS, Que.HEBILLAS: return "No tienes lingotes. Fúndelos primero en la pestaña Fundir."
		_: return "No tienes madera en el Hogar. Tala árboles y enredaderas en la mazmorra y guárdala al volver."


# ============================================================
#  QUE HAY PARA REFINAR
#  Un monton por material y calidad: {sale, mat, cal, tengo, destino, por_uno, tier}
# ============================================================

func _recoger(que: int) -> Array:
	var pares: Array = []   # [origen, destino]
	var vistos: Dictionary = {}
	match que:
		Que.TABLONES, Que.CARBON:
			for md in Game.maderas_conocidas():
				var madera: MaterialData = md as MaterialData
				pares.append([madera, Game.carbon_de(madera) if que == Que.CARBON else Game.tablon_de(madera)])
		_:
			for fila in Game.metales_forja_conocidos():
				# HEBILLAS: solo el metal BASE de cada tier. La hebilla no tiene banda de mejora, y batirla
				# de cobre veteado seria gastar mejor metal para obtener exactamente lo mismo.
				if que == Que.HEBILLAS and int((fila["mineral"] as MaterialData).mejora_min) != 0:
					continue
				var origen: MaterialData = fila["mineral"] if que == Que.FUNDIR else fila["lingote"]
				var clave: String = {Que.FUNDIR: "lingote", Que.CHAPAS: "chapa"}.get(que, "hebillas")
				pares.append([origen, fila[clave]])
	var por_uno: int = _por_uno(que)
	var out: Array = []
	for par in pares:
		var origen: MaterialData = par[0]
		var destino: MaterialData = par[1]
		if origen == null or destino == null or vistos.has(origen):
			continue
		vistos[origen] = true
		for cal in t.CALIDADES:
			# disponible_ (y no items_): en multi resta lo que el compañero tenga reservado.
			var tengo: int = Game.disponible_calidad_en_hogar(origen, int(cal))
			if tengo <= 0:
				continue
			out.append({"sale": MaterialItem.crear(destino, int(cal)), "mat": origen, "cal": int(cal),
				"tengo": tengo, "destino": destino, "por_uno": por_uno, "tier": int(origen.tier)})
	return out


static func _por_uno(que: int) -> int:
	match que:
		Que.CHAPAS: return Forge.LINGOTE_POR_CHAPA
		Que.HEBILLAS: return Forge.LINGOTE_POR_HEBILLAS
		Que.TABLONES: return Forge.MADERA_POR_TABLON
		Que.CARBON: return Forge.MADERA_POR_CARBON
		_: return Forge.MINERAL_POR_LINGOTE


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

func _ficha(vb: VBoxContainer, que: int) -> void:
	var s: Dictionary = t.stacks[t.sel]
	var origen: MaterialData = s["mat"]
	var destino: MaterialData = s["destino"]
	var cal: int = int(s["cal"])
	var por_uno: int = int(s["por_uno"])
	var tengo: int = int(s["tengo"])
	var salen: int = tengo / maxi(1, por_uno)

	MenuScaffold.titulo_item(vb, "%s (%s)" % [destino.nombre, t.cal_txt(cal)], IconoItem.color_escala(destino))
	MenuScaffold.banner_item(vb, MaterialItem.crear(destino, cal), "", "Tier %d" % int(destino.tier))
	vb.add_child(HSeparator.new())
	t.row(vb, "De", "%s (%s)" % [origen.nombre, t.cal_txt(cal)])
	t.row(vb, "Hacen falta", "%d por cada uno" % por_uno)
	t.row(vb, "Tienes", "%d  ·  dan para %d" % [tengo, salen], t.VERDE if salen > 0 else t.ROJO)
	if que == Que.CARBON:
		# LA DURACION ES DE ESTA CALIDAD, no la base: el mismo carbon dura mas si es intacto.
		t.row(vb, "Llama", "%s por carbón" % _mmss(Lampara.duracion_de(destino, cal)))
		_en_la_carbonera(vb)
	else:
		_en_el_almacen(vb, destino)
	t.note(vb, _nota(que, por_uno))
	_pie(que, s, salen)


func _nota(que: int, por_uno: int) -> String:
	match que:
		Que.CHAPAS:
			return "Las chapas son lo que pide la ARMADURA; el arma se golpea del lingote directamente."
		Que.HEBILLAS:
			return "Salen caras en metal (son muchos herrajes pequeños). Sujetan una MOCHILA y una ARMADURA DE CUERO: las dos se cosen en la peletería."
		Que.TABLONES:
			return "El tablón es el mango del arma; la madera cruda no va directa a la forja. Solo la Carpintería puede regalarte un escalón."
		Que.CARBON:
			return "Cuanto más densa la madera, más rato aguanta la brasa. El carbón no va al almacén: va con el farolillo, y no pesa."
		_:
			return "%d minerales de la MISMA calidad dan un lingote de esa calidad: juntando dañados no sale un normal. Solo la Herrería puede regalarte un escalón." % por_uno


# LO QUE YA TIENES DE ESO, en celdas: cuanto llevo ya, y de que calidad.
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


func _en_la_carbonera(vb: VBoxContainer) -> void:
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "EN LA CARBONERA", 13)
	var trozos: int = Game.carbon.size()
	if trozos == 0:
		t.note(vb, "No te queda carbón.")
		return
	t.row(vb, "Llevas", "%d trozos  ·  %s de luz en total" % [
		trozos, _mmss(Game.luz_total_restante() - Game.lampara_llama)])


# Segundos como "m:ss": los escalones del carbon son de 30 s y en minutos a secas no se verian.
static func _mmss(seg: float) -> String:
	var s: int = int(round(seg))
	return "%d:%02d" % [s / 60, s % 60]


# El pie fijo: cuantas tandas y el boton. Arranca en UNO, nunca en el maximo.
func _pie(que: int, s: Dictionary, salen: int) -> void:
	var vb: VBoxContainer = t.acciones()
	vb.add_child(HSeparator.new())
	var clave: String = "%d|%s|%d" % [que, String((s["mat"] as MaterialData).id), int(s["cal"])]
	if clave != _cant_de or _cant < 1 or _cant > maxi(1, salen):
		_cant = 1
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
	# El numero vale AL ESCRIBIR (ver MenuScaffold.stepper): el total se reescribe en sitio.
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
	MenuScaffold.pastilla(vb, _verbo(que), func() -> void: refinar(que, s), true, salen > 0)


static func _verbo(que: int) -> String:
	match que:
		Que.CHAPAS: return "Batir chapas"
		Que.HEBILLAS: return "Hacer hebillas"
		Que.TABLONES: return "Aserrar"
		Que.CARBON: return "Quemar"
		_: return "Fundir"


func refinar(que: int, s: Dictionary) -> void:
	var veces: int = clampi(_cant, 1, maxi(1, int(s["tengo"]) / maxi(1, int(s["por_uno"]))))
	if Net.activo and not await Net.hogar.abrir_taller():
		t.ocupado()
		t.rebuild()
		return
	var origen: MaterialData = s["mat"]
	var cal: int = int(s["cal"])
	var n: int = 0
	match que:
		Que.CHAPAS: n = Game.batir_chapa(origen, cal, veces)
		Que.HEBILLAS: n = Game.hacer_hebillas(origen, cal, veces)
		Que.TABLONES: n = Game.aserrar(origen, cal, veces)
		Que.CARBON: n = Game.carbonizar(origen, cal, veces)
		_: n = Game.fundir(origen, cal, veces)
	if Net.activo:
		Net.hogar.cerrar_taller()
	if n > 0:
		t.decir("Sacas %d × %s de calidad %s." % [n, (s["destino"] as MaterialData).nombre.to_lower(),
			t.cal_txt(cal).to_lower()])
	else:
		t.decir("No te llega el material.", false)
	# El montón se ha encogido (o ha desaparecido): la cantidad vuelve a 1.
	_cant = 1
	t.rebuild()
