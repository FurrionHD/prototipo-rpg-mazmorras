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
var _enc_grupos: Dictionary = {0: 100}   # el OBJETIVO: Encargos.Grupo -> porcentaje (suman 100)
var _enc_uids: Array = []            # quienes van
var _enc_utiles: Array = []          # ids de entradas del cofre asignadas
var _enc_faena: Dictionary = {}      # uid -> [Encargos.Grupo]; vacia = "lo que haga falta"
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
			_enc_faena[uid] = Encargos.faenas_validas(_enc_faena[uid], _enc_grupos)
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
	var grupos: Dictionary = e.get("grupos", {})
	for g in grupos:
		tipos.append("%s %d%%" % [String(Encargos.NOMBRE_GRUPO.get(int(g), "?")), int(grupos[g])])

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
	if int(inf.get("dinero", 0)) > 0:
		t += " y %d monedas en cristales para la hucha" % int(inf["dinero"])
	if int(inf.get("rotos", 0)) > 0:
		t += "; rompieron %d" % int(inf["rotos"])
	if int(inf.get("perdido", 0)) > 0:
		t += "; se dejaron %d por peso" % int(inf["perdido"])
	return t + ". Está en el almacén; lo aprendido, en el altar."


# --- El formulario de "Mandar uno" ---
#
# Trabaja sobre FICHAS del roster (dicts), no sobre PersonajeData, y es el MISMO camino en solitario
# y en multi: el invitado NO tiene los PersonajeData de los personajes de su compañero.
func _build_encargos_nuevo() -> void:
	var libres: Array = _libres_del_hogar()
	_purgar_seleccion(libres)

	# --- Izquierda: a por qué van, cuánto de cada cosa, dónde y cuánto rato.
	_enc_piso = clampi(_enc_piso, 1, _piso_tope())
	_build_objetivo()
	_build_reparto()
	_build_piso()
	_build_duracion()

	# --- Derecha: quién va, con qué, y el pronóstico.
	_build_encargo_gente(libres)
	_build_encargo_utiles()
	_build_encargo_pronostico(libres)


# ============================================================
#  IZQUIERDA
# ============================================================

# Nombres CORTOS para el pie de la celda: el pie o cabe entero o no se pinta (ver CeldaObjeto), y
# "Materiales de poción" no cabe en 80 px. El nombre largo va en el tooltip.
const CORTO_GRUPO := {
	Encargos.Grupo.MINERAL: "Mineral", Encargos.Grupo.MADERA: "Madera",
	Encargos.Grupo.PLANTA: "Plantas", Encargos.Grupo.COMIDA: "Comida",
	Encargos.Grupo.PESCADO: "Pescado", Encargos.Grupo.CUERO: "Cuero",
	Encargos.Grupo.NUCLEO: "Núcleos", Encargos.Grupo.POCION: "Pociones",
	Encargos.Grupo.CRISTAL: "Cristales",
}
const LADO_CELDA_GRUPO := 82.0
const COLUMNAS_GRUPO := 5

# HASTA DONDE HAS LLEGADO: la libreta del mapa (los pisos traidos a salvo al pueblo). No
# Game.pisos_desbloqueados(), que son los ATAJOS de los jefes y devolvia [1] hasta matar al Rey Slime.
func _piso_tope() -> int:
	var tope: int = 1
	for p in Game.mapa_visible().keys():
		tope = maxi(tope, int(p))
	return tope


# EL OBJETIVO: una celda de inventario por grupo, con la cara del material mas comun de ese grupo en
# el piso elegido. Pulsar la marca (marco ambar) y volver a pulsar la quita. Nunca se queda vacio.
func _build_objetivo() -> void:
	MenuScaffold.titulo(hogar._lista, "Objetivo", 14)
	var grid := GridContainer.new()
	grid.columns = COLUMNAS_GRUPO
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	hogar._lista.add_child(grid)
	for g_ in Encargos.Grupo.values():
		var g: int = int(g_)
		var c := CeldaObjeto.new()
		c.custom_minimum_size = Vector2(LADO_CELDA_GRUPO, LADO_CELDA_GRUPO)
		c.button_pressed = _enc_grupos.has(g)
		var pool: Array = Encargos.opciones(g, _enc_piso)
		var hay: bool = g == Encargos.Grupo.CRISTAL or not pool.is_empty()
		c.tooltip_text = _tooltip_grupo(g, pool)
		# Un grupo que no sale en este piso se apaga, salvo que ya estuviera marcado: asi se puede quitar.
		if hay or _enc_grupos.has(g):
			c.pressed.connect(func():
				_enc_grupos = Encargos.alternar_grupo(_enc_grupos, g)
				hogar._rebuild())
		else:
			c.disabled = true
		grid.add_child(c)
		# DESPUES de meterla en el arbol: configurar() repinta y un nodo suelto aun no tiene tamaño.
		c.configurar(_icono_grupo(g, pool), String(CORTO_GRUPO.get(g, "?")), "", 0)


# La cara del grupo: su material MAS COMUN en el piso, como objeto de inventario para que la celda lo
# pinte igual que en la bolsa. Los cristales no tienen material: un cristal de la categoria que mas
# sale ahi abajo.
func _icono_grupo(g: int, pool: Array) -> Resource:
	if g == Encargos.Grupo.CRISTAL:
		var c := Cristal.new()
		c.categoria = _categoria_tipica(_enc_piso)
		c.calidad = Cristal.Calidad.NORMAL
		return c
	var mejor: Dictionary = {}
	for o in pool:
		if mejor.is_empty() or float(o["peso"]) > float(mejor["peso"]):
			mejor = o
	if mejor.is_empty():
		return null
	return MaterialItem.crear(mejor["material"] as MaterialData, MaterialItem.Calidad.NORMAL)


# La categoria de cristal del bicho que MAS sale en el piso. Solo es para la cara de la celda.
func _categoria_tipica(piso: int) -> int:
	var tabla: SpawnTable = load(Game.TABLA_SPAWNS) as SpawnTable
	if tabla == null:
		return 1
	var mejor: Dictionary = {}
	for f in tabla.aplanar(piso):
		if mejor.is_empty() or float(f["prob"]) > float(mejor["prob"]):
			mejor = f
	return (mejor["data"] as EnemyData).crystal_category_min if not mejor.is_empty() else 1


# Lo que puede salir de ese grupo en el piso, de lo mas comun a lo menos. Es el dato que decide si
# merece la pena marcarlo, y no cabe en la celda.
func _tooltip_grupo(g: int, pool: Array) -> String:
	var nombre: String = String(Encargos.NOMBRE_GRUPO.get(g, "?"))
	if g == Encargos.Grupo.CRISTAL:
		return "%s\nUno por cada enemigo que maten. Se venden al recoger el encargo y el dinero va a la hucha." % nombre
	if pool.is_empty():
		return "%s\nEn este piso no hay nada de esto." % nombre
	var total: float = 0.0
	for o in pool:
		total += float(o["peso"])
	var orden: Array = pool.duplicate()
	orden.sort_custom(func(a, b): return float(a["peso"]) > float(b["peso"]))
	var lineas: PackedStringArray = [nombre]
	for i in mini(orden.size(), 6):
		lineas.append("  %s  %s%%" % [(orden[i]["material"] as MaterialData).nombre,
			snappedf(100.0 * float(orden[i]["peso"]) / maxf(0.001, total), 0.1)])
	if orden.size() > 6:
		lineas.append("  y %d más" % (orden.size() - 6))
	if Encargos.es_de_caza(g):
		lineas.append("Sale de los enemigos que maten, con la suerte de cada uno.")
	return "\n".join(lineas)


# CUANTO DE CADA COSA: un deslizador por grupo marcado, siempre en el orden fijo de los grupos.
#
# SE ACTUALIZA EN VIVO Y SIN REPINTAR EL PANEL. Al mover uno, los demas se recolocan en el acto para
# que siempre sumen 100; si en vez de eso se rehiciera el menu, el deslizador que tienes cogido
# desapareceria bajo el raton a mitad de arrastre.
var _desliz: Dictionary = {}   # grupo -> {"s": HSlider, "l": Label}

func _build_reparto() -> void:
	_desliz.clear()
	_aire(hogar._lista)
	MenuScaffold.titulo(hogar._lista, "Reparto", 14)
	if _enc_grupos.size() == 1:
		MenuScaffold.nota(hogar._lista, "Todo a %s. Marca más cosas arriba para repartir." %
			String(Encargos.NOMBRE_GRUPO.get(int(_enc_grupos.keys()[0]), "?")).to_lower())
		return
	for g_ in Encargos.Grupo.values():
		var g: int = int(g_)
		if not _enc_grupos.has(g):
			continue
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		hogar._lista.add_child(fila)
		var nombre := Label.new()
		nombre.text = String(CORTO_GRUPO.get(g, "?"))
		nombre.custom_minimum_size = Vector2(84, 0)
		nombre.add_theme_font_size_override("font_size", 14)
		fila.add_child(nombre)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 1
		s.value = int(_enc_grupos[g])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.focus_mode = Control.FOCUS_NONE
		_estilo_deslizador(s)
		fila.add_child(s)
		var pct := Label.new()
		pct.custom_minimum_size = Vector2(46, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.add_theme_font_size_override("font_size", 14)
		pct.add_theme_color_override("font_color", AMBAR)
		pct.text = "%d%%" % int(_enc_grupos[g])
		fila.add_child(pct)
		_desliz[g] = {"s": s, "l": pct}
		s.value_changed.connect(func(v: float): _mover_reparto(g, int(round(v))))
	MenuScaffold.nota(hogar._lista, "Si la mochila se llena, cada cosa ocupa su parte, y como mucho un 10% más si sobra sitio.")


func _mover_reparto(g: int, v: int) -> void:
	_enc_grupos = Encargos.ajustar_porcentaje(_enc_grupos, g, v)
	for k in _desliz:
		var d: Dictionary = _desliz[k]
		var nuevo: int = int(_enc_grupos.get(int(k), 0))
		# set_value_no_signal: mover los otros no puede volver a llamar aqui (serian ecos infinitos).
		if int(k) != g:
			(d["s"] as HSlider).set_value_no_signal(nuevo)
		(d["l"] as Label).text = "%d%%" % nuevo


# El deslizador del hogar: carril oscuro redondeado y el tramo lleno en AMBAR, el color de "lo que
# has elegido" en todo el menu (el marco de la celda marcada, los chips).
func _estilo_deslizador(s: HSlider) -> void:
	var carril := StyleBoxFlat.new()
	carril.bg_color = Color(1, 1, 1, 0.08)
	carril.set_corner_radius_all(4)
	carril.content_margin_top = 4
	carril.content_margin_bottom = 4
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = AMBAR
	lleno.set_corner_radius_all(4)
	lleno.content_margin_top = 4
	lleno.content_margin_bottom = 4
	var lleno_hover := lleno.duplicate() as StyleBoxFlat
	lleno_hover.bg_color = AMBAR.lightened(0.15)
	s.add_theme_stylebox_override("slider", carril)
	s.add_theme_stylebox_override("grabber_area", lleno)
	s.add_theme_stylebox_override("grabber_area_highlight", lleno_hover)
	s.custom_minimum_size = Vector2(0, 28)


# EL PISO: − Piso N +, en chips. Hasta el ultimo piso que has traido a salvo al pueblo.
func _build_piso() -> void:
	_aire(hogar._lista)
	MenuScaffold.titulo(hogar._lista, "Piso", 14)
	var tope: int = _piso_tope()
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	hogar._lista.add_child(fila)
	var menos := Button.new()
	menos.text = "−"
	menos.focus_mode = Control.FOCUS_NONE
	MenuScaffold.estilo_chip(menos, false)
	menos.custom_minimum_size = Vector2(ALTO_CHIP_GRANDE, ALTO_CHIP_GRANDE)
	menos.add_theme_font_size_override("font_size", 20)
	menos.disabled = _enc_piso <= 1
	menos.pressed.connect(func():
		_enc_piso = maxi(1, _enc_piso - 1)
		hogar._rebuild())
	fila.add_child(menos)
	var lbl := Label.new()
	lbl.text = "Piso %d" % _enc_piso
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	fila.add_child(lbl)
	var mas := Button.new()
	mas.text = "+"
	mas.focus_mode = Control.FOCUS_NONE
	MenuScaffold.estilo_chip(mas, false)
	mas.custom_minimum_size = Vector2(ALTO_CHIP_GRANDE, ALTO_CHIP_GRANDE)
	mas.add_theme_font_size_override("font_size", 20)
	mas.disabled = _enc_piso >= tope
	mas.pressed.connect(func():
		_enc_piso = mini(tope, _enc_piso + 1)
		hogar._rebuild())
	fila.add_child(mas)
	var hasta := Label.new()
	hasta.text = "hasta el %d" % tope
	hasta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hasta.add_theme_font_size_override("font_size", 12)
	hasta.add_theme_color_override("font_color", GRIS)
	fila.add_child(hasta)

const ALTO_CHIP_GRANDE := 40.0


# CUANTO RATO: tres chips, el marcado en ambar.
func _build_duracion() -> void:
	_aire(hogar._lista)
	MenuScaffold.titulo(hogar._lista, "Cuánto tiempo", 14)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	hogar._lista.add_child(fila)
	for i in Encargos.DURACIONES.size():
		var b := Button.new()
		b.text = "%d h" % (int(Encargos.DURACIONES[i]) / 3600)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MenuScaffold.estilo_chip(b, i == _enc_dur)
		b.custom_minimum_size = Vector2(0, ALTO_CHIP_GRANDE)
		b.add_theme_font_size_override("font_size", 16)
		var idx: int = i
		b.pressed.connect(func():
			_enc_dur = idx
			hogar._rebuild())
		fila.add_child(b)


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
		if va:
			_build_ordenes(t["caja"] as VBoxContainer, ficha)


# Las dos ordenes que le das a UNA persona: a por que va, y con que pelea.
func _build_ordenes(caja: VBoxContainer, ficha: Dictionary) -> void:
	var uid: String = String(ficha.get("uid", ""))
	var suyas: Array = _enc_faena.get(uid, [])
	var et: Array = []
	var vals: Array = []
	for g in _enc_grupos:
		et.append("%s %s" % ["☑" if suyas.has(int(g)) else "☐", String(Encargos.NOMBRE_GRUPO.get(int(g), "?"))])
		vals.append(int(g))
	MenuScaffold.nota(caja, "A por qué va" if not suyas.is_empty()
		else "A por qué va  ·  sin marcar nada, a lo que haga falta")
	MenuScaffold.cuadricula(caja, et, -1, func(i: int):
		var lista: Array = (_enc_faena.get(uid, []) as Array).duplicate()
		var g: int = int(vals[i])
		if lista.has(g):
			lista.erase(g)
		else:
			lista.append(g)
		_enc_faena[uid] = lista
		hogar._rebuild(), 3, Vector2(0, 26))

	var disp: Array = ficha.get("clases", [int(Encargos.Clase.GUERRERO)])
	var et_c: Array = []
	var vals_c: Array = []
	var off: Array = []
	var tips: Array = []
	for c in Encargos.Clase.values():
		if not disp.has(int(c)):
			off.append(vals_c.size())
		et_c.append(String(Encargos.ABREV_CLASE.get(c, "?")))
		vals_c.append(int(c))
		tips.append(String(Encargos.NOMBRE_CLASE.get(c, "?")) if disp.has(int(c))
			else String(Encargos.REQUISITO_CLASE.get(c, "")))
	var actual: int = int(_enc_clase.get(uid, int(disp[0]) if not disp.is_empty() else 0))
	if not disp.has(actual):
		actual = int(disp[0]) if not disp.is_empty() else int(Encargos.Clase.GUERRERO)
	# Se deja escrito el que se enseña: si no, quien no toque la fila iria con la clase por defecto.
	_enc_clase[uid] = actual
	MenuScaffold.nota(caja, "Con qué pelea")
	MenuScaffold.cuadricula(caja, et_c, vals_c.find(actual), func(i: int):
		_enc_clase[uid] = int(vals_c[i])
		hogar._rebuild(), 3, Vector2(0, 26), [], off, tips)


func _build_encargo_utiles() -> void:
	MenuScaffold.titulo(hogar._content, "Útiles del cofre", 14)
	var hay: bool = false
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
		fila.add_child(l)
		var ap := Label.new()
		ap.text = ("+%.0f kg" if clase == "mochila" else "+%.0f afinidad") % Encargos.aporte_util(entrada)
		ap.add_theme_color_override("font_color", VERDE)
		fila.add_child(ap)
		var b := Button.new()
		var puesta: bool = _enc_utiles.has(id)
		b.text = "Quitar" if puesta else "Llevar"
		b.disabled = ocupada != 0
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
	var fuerzas: Array = []
	for f in fichas:
		poderes.append(float((f as Dictionary).get("poder", 0)))
		fuerzas.append(float(((f as Dictionary).get("stats", {}) as Dictionary).get("fuerza", 0.0)))
	var entradas: Array = []
	for id in _enc_utiles:
		for entrada in Net.hogar.cofre_visible():
			if int((entrada as Dictionary).get("id", -1)) == int(id):
				entradas.append(entrada)
				break

	var pg: float = Encargos.poder_grupo_de(poderes)
	var probs: Array = Encargos.probs_desenlace(pg, _enc_piso)
	MenuScaffold.fila(hogar._content, "Poder del grupo", "%d" % int(round(pg)))
	MenuScaffold.fila(hogar._content, "El piso %d pide" % _enc_piso,
		"%d" % int(round(Encargos.requisito_mostrado(_enc_piso))))
	var exito := Label.new()
	var pct: float = 100.0 * float(probs[0])
	exito.text = "ÉXITO %s   ·   éxito parcial %s   ·   fracaso %s" % [
		Encargos.pct(float(probs[0])), Encargos.pct(float(probs[1])), Encargos.pct(float(probs[2]))]
	exito.add_theme_font_size_override("font_size", 16)
	exito.add_theme_color_override("font_color",
		VERDE if pct > 85.0 else (AMBAR if pct >= 60.0 else Color(0.90, 0.45, 0.40)))
	hogar._content.add_child(exito)
	MenuScaffold.fila(hogar._content, "Pueden cargar", "%.0f kg" % Encargos.tope_carga_de(fuerzas, entradas))

	var dur: int = int(Encargos.DURACIONES[_enc_dur])
	var pega: String = Encargos.motivo_no_puede(_enc_grupos, entradas, fichas.size())
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
		Net.hogar.solicitar_encargo(_enc_piso, _enc_grupos.duplicate(), dur, _enc_uids, _enc_utiles,
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


# Un respiro entre apartados: sin el, cada titulo iba pegado a lo de encima y la columna se leia
# como un solo bloque.
func _aire(vb: VBoxContainer, alto: float = 10.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	vb.add_child(c)
