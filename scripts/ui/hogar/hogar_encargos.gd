# ============================================================
#  hogar_encargos.gd  --  seccion ENCARGOS del menu del HOGAR (ver home_menu.gd, que es el armazon).
#  Es un RefCounted y no un nodo: lo que pinta va en las zonas del armazon (hogar._lista, hogar._content...)
#  y el estado de la pantalla (el aviso, el guardia de _rebuild) vive alli, igual que las piezas de
#  combat.gd (combat_altas, combat_figuras...).
# ============================================================
extends RefCounted

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

var hogar = null   # el armazon (home_menu.gd). Sin tipo: con CanvasLayer no se ven sus variables


func _init(pantalla: CanvasLayer) -> void:
	hogar = pantalla

# Los dos apartados de Encargos, por ID como los del cofre (ver COFRE_SUBS).
const ENCARGO_SUBS := [["En marcha", "curso"], ["Mandar uno", "nuevo"]]

# --- Lo que se esta montando en "Mandar uno". Se conserva entre re-dibujos: cada casilla que marcas
# rehace el panel entero (hay que recalcular el pronostico) y sin esto se perderia la seleccion.
var _enc_sub: int = 0
var _enc_piso: int = 1
var _enc_dur: int = 0                # indice en Encargos.DURACIONES
var _enc_tipos: Array = [0]          # Encargos.Tipo marcados
var _enc_uids: Array = []            # quienes van
var _enc_utiles: Array = []          # ids de entradas del cofre asignadas
var _enc_faena: Dictionary = {}      # uid -> Encargos.Tipo, o -1 = "lo que haga falta"
var _enc_clase: Dictionary = {}      # uid -> Encargos.Clase (con que pelea)

# ============================================================
#  ENCARGOS: mandar a los del hogar a recolectar por RELOJ REAL
#  Dos apartados: los que estan fuera y el formulario para mandar uno nuevo.
# ============================================================

func _build_encargos() -> void:
	# Las dos subpestañas con icono, en la fila de subpestañas del armazon (como las del inventario); el
	# nombre del apartado sale arriba a la izquierda, bajo "Hogar".
	MenuScaffold.subpestanas(hogar.barra_sub, [ENCARGO_SUBS[0][0], ENCARGO_SUBS[1][0]],
		["correr", "pergamino"], _enc_sub, func(i: int):
			_enc_sub = i
			hogar._aviso = ""
			hogar._rebuild())
	hogar._titulo_seccion.text = str(ENCARGO_SUBS[_enc_sub][0])
	# Al abrir la pestaña se repasa: puede haber vencido alguno mientras no mirabas. De cliente esto
	# es una PETICION al host (el unico que puede resolver), asi que la respuesta llega despues por
	# hogar_cambiado y re-dibuja sola; aqui no se puede avisar de nada todavia.
	Net.hogar.pedir_repasar_encargos()
	# La purga va AQUI y no solo dentro de "Mandar uno": el roster cambia en vivo (tu compañero mete a
	# alguien en su equipo y se le cae del selector a todo el mundo), y si solo se limpiara al pintar
	# esa sub-pestaña, mirando "En marcha" te quedaria una seleccion mentirosa esperando.
	_purgar_seleccion(_libres_del_hogar())
	if String(ENCARGO_SUBS[_enc_sub][1]) == "curso":
		_build_encargos_curso()
	else:
		_build_encargos_nuevo()


# Los del hogar a los que se puede mandar AHORA: ni bajando con su dueño, ni ya de encargo.
func _libres_del_hogar() -> Array:
	var out: Array = []
	for f in Net.hogar.roster_hogar():
		var ficha := f as Dictionary
		if not bool(ficha.get("en_equipo", false)) and not bool(ficha.get("de_encargo", false)):
			out.append(ficha)
	return out


# Quita de la seleccion a quien ya no esta libre y LO DICE. Antes se hacia en silencio: marcabas a
# tres, tu compañero se llevaba a uno a su equipo, y al mandar el encargo iban dos sin que nadie te
# explicara por que.
func _purgar_seleccion(libres: Array) -> void:
	var por_uid: Dictionary = {}
	for f in libres:
		por_uid[String((f as Dictionary).get("uid", ""))] = true
	# El nombre hay que cogerlo del roster COMPLETO: el que se cae ya no esta en 'libres'.
	var nombres: Dictionary = {}
	for f in Net.hogar.roster_hogar():
		nombres[String((f as Dictionary).get("uid", ""))] = String((f as Dictionary).get("nombre", "?"))

	var vivos: Array = []
	var caidos: Array = []
	for uid in _enc_uids:
		if por_uid.has(String(uid)):
			vivos.append(uid)
		else:
			caidos.append(String(nombres.get(String(uid), "Alguien")))
	if caidos.is_empty() and vivos.size() == _enc_uids.size():
		_limpiar_ordenes_sueltas()
		return
	_enc_uids = vivos
	if not caidos.is_empty():
		hogar._aviso = "%s ya no está%s disponible%s: %s." % [
			", ".join(caidos), "" if caidos.size() == 1 else "n", "" if caidos.size() == 1 else "s",
			"lo han metido en un equipo o se ha ido de encargo" if caidos.size() == 1
				else "los han metido en un equipo o se han ido de encargo"]
		hogar._aviso_ok = false
		# Repintar la linea A MANO: _rebuild_real ya la pinto ANTES de llamar aqui, asi que sin esto el
		# aviso no saldria hasta el siguiente rebuild -- justo cuando ya no hace falta.
		MenuScaffold.decir(hogar._aviso_lbl, hogar._aviso, hogar._aviso_ok)
	_limpiar_ordenes_sueltas()


# Las ordenes de los que ya no van, o las faenas que apuntaban a un tipo que has desmarcado: si no se
# limpian, mandas gente "a las plantas" en un encargo que ya no lleva plantas.
func _limpiar_ordenes_sueltas() -> void:
	for uid in _enc_faena.keys():
		if not _enc_uids.has(uid):
			_enc_faena.erase(uid)
		else:
			_enc_faena[uid] = Encargos.faenas_validas(_enc_faena[uid], _enc_tipos)
	for uid in _enc_clase.keys():
		if not _enc_uids.has(uid):
			_enc_clase.erase(uid)


func _build_encargos_curso() -> void:
	var lista: Array = Net.hogar.encargos_visibles()
	MenuScaffold.titulo(hogar._lista, "En marcha (%d)" % lista.size(), 14)
	if lista.is_empty():
		MenuScaffold.nota(hogar._lista, "No hay nadie fuera. En «Mandar uno» eliges a quién mandas, a qué "
			+ "piso y cuánto tiempo. Cuentan por reloj real, así que siguen aunque cierres el juego.")
		return
	for e_ in lista:
		_fila_encargo(e_ as Dictionary)


func _fila_encargo(e: Dictionary) -> void:
	var listo: bool = int(e.get("estado", 0)) == Encargos.ESTADO_LISTO
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	hogar._lista.add_child(caja)

	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 6)
	caja.add_child(cab)
	var nombres: PackedStringArray = []
	for m in (e.get("miembros", []) as Array):
		nombres.append(String((m as Dictionary).get("nombre", "?")))
	var tipos: PackedStringArray = []
	for t in (e.get("tipos", []) as Array):
		tipos.append(String(Encargos.NOMBRE_TIPO.get(int(t), "?")))

	var l := Label.new()
	l.text = "Piso %d · %s  ·  %s" % [int(e.get("piso", 1)), ", ".join(tipos), ", ".join(nombres)]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(l)

	var est := Label.new()
	if listo:
		est.text = "¡De vuelta!"
		est.add_theme_color_override("font_color", AMBAR)
	else:
		est.text = "faltan %s" % Encargos.texto_restante(e)
		est.add_theme_color_override("font_color", GRIS)
	cab.add_child(est)

	if not listo:
		var barra := ProgressBar.new()
		barra.custom_minimum_size = Vector2(0, 6)
		barra.show_percentage = false
		var dur: float = maxf(1.0, float(e.get("duracion", 1)))
		barra.value = 100.0 * clampf(1.0 - float(Encargos.restante(e)) / dur, 0.0, 1.0)
		caja.add_child(barra)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 6)
	caja.add_child(acciones)

	if listo:
		var recoger := Button.new()
		recoger.text = "Recoger"
		recoger.pressed.connect(func():
			# De cliente el informe llega por _aviso_remoto: el botin lo reparte el host.
			if Net._soy_cliente():
				Net.hogar.solicitar_recoger_encargo(int(e["id"]))
				hogar._aviso = "Recogiendo…"
				hogar._aviso_ok = true
			else:
				var inf: Dictionary = Game.recoger_encargo(int(e["id"]))
				hogar._aviso = _texto_informe(inf)
				hogar._aviso_ok = int(inf.get("desenlace", 0)) != Encargos.FRACASO
				Net.hogar._difundir_hogar()
			hogar._rebuild())
		acciones.add_child(recoger)
	else:
		var traer := Button.new()
		traer.text = "Traer de vuelta"
		traer.tooltip_text = "Los hace volver YA, con lo que lleven recogido hasta ahora. A media " \
			+ "faena traen la mitad: el trabajo hecho no se pierde."
		traer.pressed.connect(func():
			Net.hogar.solicitar_traer_encargo(int(e["id"]))
			hogar._aviso = "Vuelven a casa con lo que llevaban. Recógelo aquí mismo."
			hogar._aviso_ok = true
			hogar._rebuild())
		acciones.add_child(traer)

		# --- BOTON DE DEV (temporal, quitar antes de publicar) ---
		# No es lo mismo que "Traer de vuelta": aquel acorta la duracion y por eso vuelven con lo
		# proporcional; este RETRASA EL INICIO, asi que el encargo cuenta COMPLETO y da exactamente
		# lo mismo que si hubieras esperado las ocho horas. Es el unico que sirve para mirar el
		# balance sin esperar de verdad. Va aqui y no solo en el panel de dev porque asi se puede
		# terminar UNO concreto, y porque se ve en el .exe exportado (el panel de dev tambien, pero
		# esto es un clic en vez de abrirlo y buscar la seccion).
		var dev := Button.new()
		dev.text = "⚡ Terminar ya [dev]"
		dev.tooltip_text = "Como si hubiera pasado su tiempo ENTERO: el resultado es idéntico al de "
		dev.tooltip_text += "esperarlo de verdad. Botón de pruebas, se quitará."
		dev.modulate = Color(0.75, 0.85, 1.0)
		dev.pressed.connect(func():
			Net.hogar.solicitar_dev_terminar_encargo(int(e["id"]))
			hogar._aviso = "[dev] Encargo terminado al 100%. Ya se puede recoger."
			hogar._aviso_ok = true
			hogar._rebuild())
		acciones.add_child(dev)


func _texto_informe(inf: Dictionary) -> String:
	if inf.is_empty():
		return "Ese encargo ya no está."
	if bool(inf.get("ocupado", false)):
		# El almacén del hogar es común y ahora mismo lo tiene otro. No se fuerza: el encargo espera.
		return "Tu compañero está en el taller. Vuelve en un momento: no se pierde nada."
	var t: String = "%s. Traen %d material%s" % [
		Encargos.NOMBRE_DESENLACE[int(inf.get("desenlace", 0))],
		int(inf.get("materiales", 0)), "" if int(inf.get("materiales", 0)) == 1 else "es"]
	if int(inf.get("perdido", 0)) > 0:
		t += ", y se dejaron %d por peso (mándales una mochila mejor)" % int(inf["perdido"])
	return t + ". Está en el almacén; lo aprendido, en el altar."


# --- El formulario de "Mandar uno" ---
#
# Trabaja sobre FICHAS del roster (dicts), no sobre PersonajeData, y es el MISMO camino en solitario
# y en multi: en solitario el roster se construye al vuelo de tu plantilla, y de cliente llega del
# host. Tiene que ser asi porque el invitado NO tiene los PersonajeData de los personajes de su
# compañero -- viven en la maquina del host -- y aun asi puede mandarlos.
func _build_encargos_nuevo() -> void:
	var libres: Array = _libres_del_hogar()
	_purgar_seleccion(libres)

	# --- Izquierda: a qué van, dónde y cuánto.
	MenuScaffold.titulo(hogar._lista, "Tipo de encargo", 14)
	var etiquetas: Array = []
	var marcados: Array = []
	for t in range(0, int(Encargos.Tipo.BICHO) + 1):
		etiquetas.append("%s %s" % ["☑" if _enc_tipos.has(t) else "☐",
			String(Encargos.NOMBRE_TIPO.get(t, "?"))])
		marcados.append(t)
	MenuScaffold.cuadricula(hogar._lista, etiquetas, -1, func(i: int):
		var t: int = int(marcados[i])
		if _enc_tipos.has(t):
			if _enc_tipos.size() > 1:      # siempre tiene que quedar uno marcado
				_enc_tipos.erase(t)
		else:
			_enc_tipos.append(t)
		hogar._rebuild(), 3, Vector2(150, 34))
	if _enc_tipos.size() > 1:
		MenuScaffold.nota(hogar._lista, "Con %d marcados reparten el tiempo: menos de cada cosa, y lo que "
			% _enc_tipos.size() + "aprenden se reparte entre varias habilidades.")

	MenuScaffold.titulo(hogar._lista, "Piso", 14)
	# HASTA DONDE HAS LLEGADO, que es la libreta del mapa (los pisos traidos a salvo al pueblo).
	# Antes se preguntaba a Game.pisos_desbloqueados(), que NO es eso: es la lista de ATAJOS
	# abiertos por jefes, y como solo hay jefes en el 6 y en el 12, devolvia [1] hasta matar al Rey
	# Slime. Con cuatro pisos explorados el selector no se movia del 1.
	var tope: int = 1
	for p in Game.mapa_visible().keys():
		tope = maxi(tope, int(p))
	var fila_piso := HBoxContainer.new()
	hogar._lista.add_child(fila_piso)
	_enc_piso = clampi(_enc_piso, 1, tope)
	MenuScaffold.stepper(fila_piso, _enc_piso, 1, tope, func(v: int):
		_enc_piso = v
		hogar._rebuild())
	for t in _enc_tipos:
		_linea_materiales(int(t), _enc_piso)

	MenuScaffold.titulo(hogar._lista, "Cuánto tiempo", 14)
	var horas: Array = []
	for d in Encargos.DURACIONES:
		horas.append("%d hora%s" % [int(d) / 3600, "" if int(d) == 3600 else "s"])
	MenuScaffold.cuadricula(hogar._lista, horas, _enc_dur, func(i: int):
		_enc_dur = i
		hogar._rebuild(), 3, Vector2(130, 36))

	# --- Derecha: quién va, con qué, y el pronóstico.
	_build_encargo_gente(libres)
	_build_encargo_utiles()
	_build_encargo_pronostico(libres)


# Lo que sale de un tipo en un piso, con CADA MATERIAL DE SU COLOR (el de su rango: gris el bruto,
# verde el veteado, azul el profundo...). No se usa MaterialTable.resumen porque devuelve una String
# pelada y aqui hace falta un Label por material para poder teñirlos; y asi ademas el mismo codigo
# sirve para los enemigos, que no tienen MaterialTable.
const MATS_A_LA_VISTA := 6

func _linea_materiales(tipo: int, piso: int) -> void:
	var pool: Array = Encargos.opciones(tipo, piso)
	if pool.is_empty():
		MenuScaffold.nota(hogar._lista, "%s: nada que sacar en este piso." % String(Encargos.NOMBRE_TIPO[tipo]))
		return
	var total: float = 0.0
	for o in pool:
		total += float(o["peso"])
	pool.sort_custom(func(a, b): return float(a["peso"]) > float(b["peso"]))

	var flujo := HFlowContainer.new()
	flujo.add_theme_constant_override("h_separation", 4)
	flujo.add_theme_constant_override("v_separation", 0)
	hogar._lista.add_child(flujo)

	var cab := Label.new()
	cab.text = "%s:" % String(Encargos.NOMBRE_TIPO[tipo])
	cab.add_theme_font_size_override("font_size", 12)
	cab.add_theme_color_override("font_color", GRIS)
	flujo.add_child(cab)

	var n: int = mini(pool.size(), MATS_A_LA_VISTA)
	for i in n:
		var o := pool[i] as Dictionary
		var m := o["material"] as MaterialData
		var l := Label.new()
		l.text = "%s %s%%%s" % [m.nombre,
			snappedf(100.0 * float(o["peso"]) / maxf(0.001, total), 0.1),
			"" if i == n - 1 else ","]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", m.color_rango())
		flujo.add_child(l)
	if pool.size() > n:
		var mas := Label.new()
		mas.text = "y %d más ⓘ" % (pool.size() - n)
		mas.add_theme_font_size_override("font_size", 12)
		mas.add_theme_color_override("font_color", AMBAR)
		# El resto, al pasar el raton por encima. Los enemigos sueltan hasta 15 cosas distintas por
		# piso y listarlas todas en linea llenaba media pantalla, pero esconderlas del todo tampoco
		# vale: son las que decides al marcar la casilla.
		# OJO: un Label nace con MOUSE_FILTER_IGNORE, o sea que sin esto el tooltip nunca saldria.
		mas.mouse_filter = Control.MOUSE_FILTER_STOP
		var resto: PackedStringArray = []
		for i in range(n, pool.size()):
			var o := pool[i] as Dictionary
			resto.append("%s  %s%%" % [(o["material"] as MaterialData).nombre,
				snappedf(100.0 * float(o["peso"]) / maxf(0.001, total), 0.1)])
		mas.tooltip_text = "También pueden traer:\n" + "\n".join(resto)
		flujo.add_child(mas)


func _build_encargo_gente(libres: Array) -> void:
	MenuScaffold.titulo(hogar._content, "Quién va (%d de %d)" % [_enc_uids.size(), Encargos.MIEMBROS_MAX], 14)
	if libres.is_empty():
		MenuScaffold.nota(hogar._content, "No hay nadie libre en casa. Manda a alguien del equipo al hogar "
			+ "en la pestaña «Equipo», o contrata gente en la taberna.")
		return
	for f in libres:
		var ficha := f as Dictionary
		var uid: String = String(ficha.get("uid", ""))
		var t: Dictionary = hogar._tarjeta(hogar._content)
		var fila: HBoxContainer = t["info"]
		fila.add_child(hogar._punto_color(ficha.get("color", Color.WHITE)))
		var l := Label.new()
		# En mundo compartido, de quién es. Sin esto no sabes a quién le estás prestando la gente.
		var de_quien: String = ""
		if Net.activo and String(ficha.get("dueno", "")) != Identidad.id:
			de_quien = "  (de %s)" % String(ficha.get("dueno_nombre", "tu compañero"))
		l.text = "%s  ·  Nv.%d  ·  Poder %d%s" % [String(ficha.get("nombre", "?")),
			int(ficha.get("level", 1)), int(ficha.get("poder", 0)), de_quien]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if de_quien != "":
			l.add_theme_color_override("font_color", GRIS)
		fila.add_child(l)
		var b := Button.new()
		var va: bool = _enc_uids.has(uid)
		b.text = "Quitar" if va else "Que vaya"
		b.disabled = not va and _enc_uids.size() >= Encargos.MIEMBROS_MAX
		b.pressed.connect(func():
			if _enc_uids.has(uid):
				_enc_uids.erase(uid)
			else:
				_enc_uids.append(uid)
			hogar._rebuild())
		(t["botones"] as HBoxContainer).add_child(b)
		# Las ordenes solo tienen sentido para el que va: al que dejas en casa no le mandas nada.
		if va:
			_build_ordenes(t["caja"] as VBoxContainer, ficha)


# Las dos ordenes que le das a UNA persona: a que va, y con que pelea.
#
# La de CLASE sale siempre, aunque no los mandes a por bichos: ahi abajo hay bichos igual y de esa
# pelea se llevan excelia. La de FAENA solo tiene sentido si hay mas de un tipo marcado (con uno
# solo no hay nada que elegir).
func _build_ordenes(caja: VBoxContainer, ficha: Dictionary) -> void:
	var uid: String = String(ficha.get("uid", ""))

	# OJO con el ancho: estas cuadrículas van DENTRO de una tarjeta de la columna derecha, que es
	# estrecha. Con ancho mínimo la rejilla empuja la columna entera fuera de la pantalla, así que se
	# deja en 0 y que el EXPAND_FILL reparta lo que haya.
	# A qué va es MULTISELECCIÓN, como el "Tipo de encargo" de la izquierda: a uno le puedes mandar a
	# pescar Y a por bichos. Sin nada marcado va a lo que haga falta, que es lo de siempre.
	# SALE SIEMPRE, tambien con un solo tipo marcado. Antes se escondia con uno solo porque "no hay
	# nada que elegir", y con la vieja formula era verdad. Desde que la calidad va por la MEDIA de los
	# que trabajan ese tipo (ver Encargos.poder_recolector_de), marcar decide QUIEN lo trabaja aunque
	# el tipo sea uno: mandar a las vetas solo al fuerte sube la calidad del mineral, y dejarlo sin
	# marcar la baja con la media de los cuatro. Es una decision de verdad y tiene que verse.
	if not _enc_tipos.is_empty():
		var suyas: Array = _enc_faena.get(uid, [])
		var et: Array = []
		var vals: Array = []
		var tips_f: Array = []
		for t in _enc_tipos:
			var n: String = String(Encargos.NOMBRE_TIPO.get(int(t), "?"))
			et.append("%s %s" % ["☑" if suyas.has(int(t)) else "☐", n])
			vals.append(int(t))
			tips_f.append("Trabaja %s. La calidad sale de la media de los que van a esto." % n.to_lower())
		MenuScaffold.nota(caja, "A qué va" if not suyas.is_empty()
			else "A qué va  ·  sin marcar nada, a lo que haga falta")
		MenuScaffold.cuadricula(caja, et, -1, func(i: int):
			var lista: Array = (_enc_faena.get(uid, []) as Array).duplicate()
			var t: int = int(vals[i])
			if lista.has(t):
				lista.erase(t)
			else:
				lista.append(t)
			_enc_faena[uid] = lista
			hogar._rebuild(), 3, Vector2(0, 26), [], [], tips_f)

	# Las clases DISPONIBLES viajan ya calculadas en la ficha del roster: dependen de lo que lleve
	# puesto, y de los personajes del compañero no tenemos el equipo (solo lo que publica el host).
	var disp: Array = ficha.get("clases", [int(Encargos.Clase.GUERRERO)])
	var et_c: Array = []
	var vals_c: Array = []
	var off: Array = []
	var tips: Array = []
	for c in Encargos.Clase.values():
		if not disp.has(int(c)):
			off.append(vals_c.size())   # `deshabilitados` va por INDICE, no por booleano
		et_c.append(String(Encargos.ABREV_CLASE.get(c, "?")))
		vals_c.append(int(c))
		# El nombre entero siempre en el tooltip (la casilla va abreviada), y si no puede, el motivo.
		tips.append(String(Encargos.NOMBRE_CLASE.get(c, "?")) if disp.has(int(c))
			else String(Encargos.REQUISITO_CLASE.get(c, "")))
	# Por defecto, la primera que SI puede: nunca se queda sin clase ni con una imposible.
	var actual: int = int(_enc_clase.get(uid, int(disp[0]) if not disp.is_empty() else 0))
	if not disp.has(actual):
		actual = int(disp[0]) if not disp.is_empty() else int(Encargos.Clase.GUERRERO)
	# Se deja escrito el que se está enseñando: si no, quien no toque la fila mandaría al personaje
	# con la clase por defecto del host en vez de con la que ve marcada en pantalla.
	_enc_clase[uid] = actual
	MenuScaffold.nota(caja, "Con qué pelea")
	MenuScaffold.cuadricula(caja, et_c, vals_c.find(actual), func(i: int):
		_enc_clase[uid] = int(vals_c[i])
		hogar._rebuild(), 3, Vector2(0, 26), [], off, tips)


func _build_encargo_utiles() -> void:
	MenuScaffold.titulo(hogar._content, "Útiles del cofre", 14)
	var hay: bool = false
	# Net.hogar.cofre_visible() y no Game.cofre_equipo: de cliente el cofre del hogar es el del HOST.
	for entrada_ in Net.hogar.cofre_visible():
		var entrada := entrada_ as Dictionary
		var clase: String = String(entrada.get("clase", ""))
		if clase != "herramienta" and clase != "mochila":
			continue
		hay = true
		var id: int = int(entrada.get("id", -1))
		var ocupada: int = int(entrada.get("encargo", 0))
		var tar: Dictionary = hogar._tarjeta(hogar._content)
		var fila: HBoxContainer = tar["info"]
		var l := Label.new()
		l.text = String(entrada.get("desc", "?"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Lo que APORTA a este encargo, para que se vea por qué merece la pena mandarla.
		var aporta: String = ""
		if clase == "mochila":
			aporta = "+%.0f kg" % Encargos.capacidad_util(entrada)
		else:
			var mejor: float = 0.0
			for t in _enc_tipos:
				mejor = maxf(mejor, float(Encargos.mods_util(entrada, int(t))["afinidad"]))
			aporta = "+%.0f afinidad" % mejor if mejor > 0.0 else "no sirve para esto"
			if mejor <= 0.0:
				l.add_theme_color_override("font_color", GRIS)
		fila.add_child(l)
		var ap := Label.new()
		ap.text = aporta
		ap.add_theme_color_override("font_color", VERDE if aporta.begins_with("+") else GRIS)
		fila.add_child(ap)
		var b := Button.new()
		var puesta: bool = _enc_utiles.has(id)
		b.text = "Quitar" if puesta else "Llevar"
		b.disabled = ocupada != 0
		if ocupada != 0:
			b.tooltip_text = "En uso en otro encargo."
		b.pressed.connect(func():
			if _enc_utiles.has(id):
				_enc_utiles.erase(id)
			else:
				_enc_utiles.append(id)
			hogar._rebuild())
		(tar["botones"] as HBoxContainer).add_child(b)
	if not hay:
		MenuScaffold.nota(hogar._content, "El cofre no tiene herramientas ni mochilas. Mete ahí las que "
			+ "quieras prestarles: mientras están fuera nadie puede sacarlas.")


func _build_encargo_pronostico(libres: Array) -> void:
	var fichas: Array = []
	for uid in _enc_uids:
		for f in libres:
			if String((f as Dictionary).get("uid", "")) == String(uid):
				fichas.append(f)
				break
	MenuScaffold.titulo(hogar._content, "Pronóstico", 14)
	if fichas.is_empty():
		MenuScaffold.nota(hogar._content, "Elige a alguien para ver cómo le iría.")
		return
	var poderes: Array = []
	for f in fichas:
		poderes.append(float((f as Dictionary).get("poder", 0)))

	var entradas: Array = []
	for id in _enc_utiles:
		for entrada in Net.hogar.cofre_visible():
			if int((entrada as Dictionary).get("id", -1)) == int(id):
				entradas.append(entrada)
				break

	# --- Eje 1: ¿vuelven bien?
	var pg: float = Encargos.poder_grupo_de(poderes)
	var req: float = Encargos.requisito_combate(_enc_piso)
	var probs: Array = Encargos.probs_desenlace(pg, _enc_piso)
	MenuScaffold.fila(hogar._content, "Poder del grupo", "%d" % int(round(pg)))
	MenuScaffold.fila(hogar._content, "El piso %d pide" % _enc_piso, "%d" % int(round(req)))
	var exito := Label.new()
	var pct: float = 100.0 * float(probs[0])
	exito.text = "ÉXITO %s   ·   a medias %s   ·   fracaso %s" % [
		Encargos.pct(float(probs[0])), Encargos.pct(float(probs[1])), Encargos.pct(float(probs[2]))]
	exito.add_theme_font_size_override("font_size", 16)
	exito.add_theme_color_override("font_color",
		VERDE if pct > 85.0 else (AMBAR if pct >= 60.0 else Color(0.90, 0.45, 0.40)))
	hogar._content.add_child(exito)
	if pct < 60.0:
		MenuScaffold.nota(hogar._content, "Van muy justos: ahí abajo hay bichos. Manda a más gente, o "
			+ "vísteles mejor antes de que salgan.")

	# --- Eje 2: qué traen.
	var dur: int = int(Encargos.DURACIONES[_enc_dur])
	var golpes: int = 0
	var afin_media: float = 0.0
	for t in _enc_tipos:
		var mejor: float = 0.0
		for entrada in entradas:
			var m: Dictionary = Encargos.mods_util(entrada as Dictionary, int(t))
			mejor = maxf(mejor, float(m["afinidad"]))
			golpes = maxi(golpes, int(m["golpes_menos"]))
		afin_media += mejor
	afin_media /= maxf(1.0, float(_enc_tipos.size()))

	var trabajadas: int = Encargos.unidades(dur, fichas.size(), golpes, 1.0)
	var tope: float = Encargos.tope_carga_de(_fuerzas(fichas), entradas)
	# Cuántas caben, con el peso medio de lo que van a traer.
	var peso_ud: float = _peso_medio_unidad()
	var caben: int = int(tope / maxf(0.1, peso_ud))
	MenuScaffold.fila(hogar._content, "Trabajarán", "%d unidades" % trabajadas)
	MenuScaffold.fila(hogar._content, "Les caben", "%d  (%.0f kg)" % [caben, tope])
	_build_reparto_botin(trabajadas)
	if caben < trabajadas:
		var faltan := Label.new()
		faltan.text = "Se dejarán ~%d por peso: mándales una mochila." % (trabajadas - caben)
		faltan.add_theme_color_override("font_color", Color(0.90, 0.45, 0.40))
		hogar._content.add_child(faltan)

	# CALIDADES POR MATERIAL, nunca una media del tipo.
	# Una sola fila por "Vetas" era mentira: con 0 de Fuerza el cobre en bruto (exigencia 30) sale
	# casi siempre intacto y el veteado (150) no lo pillan ni de casualidad, y promediarlos daba un
	# "37% normal" que no le pasa a ningun material de verdad. Lo que decide la calidad es CADA
	# material, asi que se enseña material a material.
	_build_tabla_calidades(fichas, entradas, pg / req)

	# --- Mandar.
	var pega: String = Encargos.motivo_no_puede(_enc_tipos, entradas)
	if not pega.is_empty():
		var aviso := Label.new()
		aviso.text = pega
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		aviso.add_theme_color_override("font_color", Color(0.90, 0.45, 0.40))
		hogar._content.add_child(aviso)
	var b := Button.new()
	b.text = "Mandarlos"
	b.disabled = not pega.is_empty()
	b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	b.pressed.connect(func():
		Net.hogar.solicitar_encargo(_enc_piso, _enc_tipos, dur, _enc_uids, _enc_utiles,
			_enc_faena.duplicate(), _enc_clase.duplicate())
		hogar._aviso = "En marcha. Vuelven en %d h." % (dur / 3600)
		hogar._aviso_ok = true
		_enc_uids.clear()
		_enc_utiles.clear()
		_enc_faena.clear()
		_enc_clase.clear()
		_enc_sub = 0
		hogar._rebuild())
	hogar._content.add_child(b)


# QUÉ PARTE DEL BOTÍN es cada material, para poder ver lo que van a traer SIN tener que mandarlos
# primero. Los tipos se reparten el rato a partes iguales, así que el % de cada material es el de su
# tipo por el peso que tiene dentro de su tabla: con seis tipos marcados, un tipo al 16,7% con dos
# materiales al 50/50 son dos materiales al 8,3%.
func _build_reparto_botin(trabajadas: int) -> void:
	var por_tipo: Dictionary = Encargos.repartir(trabajadas, _enc_tipos)
	var filas: Array = []
	for t in _enc_tipos:
		var tipo: int = int(t)
		var uds: int = int(por_tipo.get(tipo, 0))
		var cuota: float = float(uds) / maxf(1.0, float(trabajadas))
		var pool: Array = Encargos.opciones(tipo, _enc_piso)
		var peso_total: float = 0.0
		for o in pool:
			peso_total += float(o["peso"])
		for o in pool:
			var m := o["material"] as MaterialData
			filas.append({"etiqueta": m.nombre, "color": m.color_rango(), "orden": cuota
				* float(o["peso"]) / maxf(0.001, peso_total)})
	if filas.is_empty():
		return
	filas.sort_custom(func(a, b): return float(a["orden"]) > float(b["orden"]))
	var recorte: Array = filas.slice(0, CALIDADES_A_LA_VISTA)
	for f in recorte:
		(f as Dictionary)["valores"] = [Encargos.pct(float((f as Dictionary)["orden"]))]
	MenuScaffold.titulo(hogar._content, "Cuánto de cada cosa", 13)
	MenuScaffold.rejilla_probs(hogar._content, "Material", ["Del botín"], recorte)
	if filas.size() > recorte.size():
		MenuScaffold.nota(hogar._content, "(y %d material%s más, con menos)" % [filas.size() - recorte.size(),
			"" if filas.size() - recorte.size() == 1 else "es"])


# Una fila por MATERIAL con la calidad que le sacarían. Se ordenan por exigencia (de lo fácil a lo
# difícil), que es como se lee la progresión de un vistazo: lo de arriba te lo traes entero y lo de
# abajo es lo que te falta stat para conseguir.
const CALIDADES_A_LA_VISTA := 8

func _build_tabla_calidades(fichas: Array, entradas: Array, r_combate: float) -> void:
	var filas: Array = []
	for t in _enc_tipos:
		var tipo: int = int(t)
		# La afinidad de la herramienta de ESE tipo (la mejor asignada), como en la resolución.
		var afin: float = 0.0
		for entrada in entradas:
			afin = maxf(afin, float(Encargos.mods_util(entrada as Dictionary, tipo)["afinidad"]))
		# SOLO los que van a ese tipo: si mandaste al fuerte a las vetas, el torpe que se fue a las
		# hierbas no le estropea el mineral. Con nadie asignado, la regla de Encargos devuelve a todos.
		var poder_reco: float = Encargos.poder_recolector_de(
			_stats(_fichas_faena(fichas, tipo), tipo), tipo, afin)
		var pool: Array = Encargos.opciones(tipo, _enc_piso)
		pool.sort_custom(func(a, b):
			return Game._exigencia_material(a["material"] as MaterialData, _enc_piso) \
				< Game._exigencia_material(b["material"] as MaterialData, _enc_piso))
		for o in pool:
			var m := o["material"] as MaterialData
			var margen: float = Encargos.margen_calidad(tipo, m, _enc_piso, poder_reco, r_combate)
			var q: Dictionary = Encargos.reparto_calidades(margen)
			filas.append({"etiqueta": m.nombre, "color": m.color_rango(), "valores": [
				Encargos.pct(float(q["intacto"])), Encargos.pct(float(q["normal"])),
				Encargos.pct(float(q["danado"]))]})
	if filas.is_empty():
		return
	# Con varios tipos marcados esto se va a treinta filas. Se enseñan las primeras y se dice cuántas
	# faltan: la tabla es para decidir, no para consultarla entera.
	var recorte: Array = filas.slice(0, CALIDADES_A_LA_VISTA)
	MenuScaffold.rejilla_probs(hogar._content, "Qué calidad", ["Intacto", "Normal", "Dañado"], recorte)
	if filas.size() > recorte.size():
		MenuScaffold.nota(hogar._content, "(y %d material%s más)" % [filas.size() - recorte.size(),
			"" if filas.size() - recorte.size() == 1 else "es"])


# Las stats que salen en las fichas del roster. Se leen del dict y no de PersonajeData porque de
# los personajes del compañero solo tenemos lo que publica el host.
func _fuerzas(fichas: Array) -> Array:
	var out: Array = []
	for f in fichas:
		out.append(float(((f as Dictionary).get("stats", {}) as Dictionary).get("fuerza", 0.0)))
	return out


# Las fichas de los que van a trabajar ESE tipo. La regla ("si no hay nadie asignado lo hacen
# todos") vive en Encargos y se llama desde aquí en vez de copiarla: el pronóstico y la resolución
# de verdad tienen que decir lo mismo o la tabla es mentira.
func _fichas_faena(fichas: Array, tipo: int) -> Array:
	var trabajan: Array = Encargos.uids_trabajando(_miembros_previstos(), tipo, _enc_uids)
	var out: Array = []
	for f in fichas:
		if trabajan.has(String((f as Dictionary).get("uid", ""))):
			out.append(f)
	return out if not out.is_empty() else fichas


# Los `miembros` tal y como van a quedar en el encargo, para poder preguntarle a Encargos con la
# misma forma de datos que usará la resolución.
func _miembros_previstos() -> Array:
	var out: Array = []
	for uid in _enc_uids:
		out.append({"uid": String(uid), "faenas": _enc_faena.get(uid, []),
			"clase": int(_enc_clase.get(uid, Encargos.Clase.GUERRERO))})
	return out


func _stats(fichas: Array, tipo: int) -> Array:
	var clave: String = String(Encargos.oficio_de(tipo)["stat"])
	var out: Array = []
	for f in fichas:
		out.append(float(((f as Dictionary).get("stats", {}) as Dictionary).get(clave, 0.0)))
	return out


# El peso de una unidad media de lo marcado, para poder decir cuántas caben ANTES de mandarlos.
func _peso_medio_unidad() -> float:
	var suma: float = 0.0
	var peso: float = 0.0
	for t in _enc_tipos:
		for o in Encargos.opciones(int(t), _enc_piso):
			var m: MaterialData = o["material"] as MaterialData
			suma += m.peso_base * 0.9 * float(o["peso"])   # 0.9 = calidad NORMAL, la mas comun
			peso += float(o["peso"])
	return suma / maxf(0.001, peso) if peso > 0.0 else 1.0
