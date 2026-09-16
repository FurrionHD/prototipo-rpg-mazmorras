# ============================================================
#  tavern_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de la TABERNA: donde se contrata gente para el grupo.
#
#  Contratar es CREAR un personaje: se abre la MISMA pantalla con la que te creaste tu
#  (CreadorPersonaje: nombre, color, brillo e imagen propia). No hay lista de candidatos que
#  rotan ni tiradas: eliges tu quien se une y que cara tiene.
#
#  EL PRIMERO ES GRATIS y trae un ARMA DE REGALO a elegir (las del pack de la tienda), ya equipada:
#  el inicio se hacia cuesta arriba y el compañero bajaba a puños (decision del usuario, 16/09/2026).
#  Los siguientes llegan A CERO y DESNUDOS: nivel 1, las cinco habilidades a 0 y sin equipo.
#
#  REHECHA el 16/09/2026 con la cara del inventario, sobre la base de los talleres (taller_menu.gd):
#  arriba los retratos de TU GENTE (quien baja y quien se queda en el Hogar), en la rejilla las armas
#  a elegir cuando toca regalo, y en la ficha el trato con el boton en el pie.
#
#  Aqui NO se despide a nadie: quien ficha se queda para siempre en la PLANTILLA. Quien BAJA
#  contigo (como mucho Game.PARTY_MAX) se decide en el Hogar, en el gestor de equipo.
# ============================================================

extends "res://scripts/ui/taller_menu.gd"

const ANCHO_FICHA_TABERNA := 780.0


func _ready() -> void:
	add_to_group("tavern_menu")
	montar("Taberna", ["Contratar"], ["persona"], ANCHO_REJILLA_MIN, ANCHO_FICHA_TABERNA)


func abrir() -> void:
	_tab = 0
	abrir_taller()


func _al_cerrar() -> void:
	_vaciar_vitrina()


func _pintar() -> void:
	_titulo_seccion.text = "Contratar"
	# Con una sola pestaña no hay nada que elegir arriba.
	for b in _tab_buttons:
		(b as Button).visible = false
	contador("%d monedas" % Game.money)
	var gente: Array = []
	gente.append_array(Game.party)
	gente.append_array(Game.en_el_banquillo())
	pintar_personas("TU GENTE", gente, -1, Game.party.size(), func(_i: int) -> void: pass)
	# Con uno solo (tu) retratos() no pinta nada; el rotulo si, para que se lea que aun vas solo.
	_fila_artesano_rotulo.visible = true
	if gente.size() <= 1:
		_fila_artesano_rotulo.text = "TU GENTE  ·  de momento vas solo"

	if Game.fichaje_gratis():
		stacks = []
		var piezas: Array = []
		for ruta in Game.PACK_ARMAS:
			var base: Resource = load(ruta)
			if base == null:
				continue
			stacks.append(base)
			piezas.append(pieza(_vitrina(base), "Regalo", "%s  ·  de regalo para tu primer compañero" %
				str(base.get("nombre"))))
		grid_detail(piezas, _ficha_gratis)
	else:
		stacks = []
		MenuScaffold.nota(_lista, "El arma de regalo era para el primero. Los que vengan ahora llegan sin nada: equípalos desde el menú de personaje (C).")
		_cols_pintadas = _columnas()
		_ficha_pago(_content)


# ============================================================
#  LA FICHA
# ============================================================

func _ficha_gratis(vb: VBoxContainer) -> void:
	var base: Resource = stacks[sel]
	MenuScaffold.titulo_item(vb, "Tu primer compañero  ·  GRATIS", AMBAR)
	MenuScaffold.banner_item(vb, _vitrina(base), "", "Trae de regalo")
	vb.add_child(HSeparator.new())
	row(vb, "Cuesta", "Nada: el primero es gratis", VERDE)
	row(vb, "Trae", "%s  ·  T1 %s, ya equipada" % [str(base.get("nombre")),
		Upgrades.rareza_nombre(Upgrades.Rareza.COMUN)])
	_filas_comunes(vb)
	note(vb, "Elige su arma aquí al lado: así no baja a puños. Después eliges su nombre y su aspecto.")
	note(vb, "Los siguientes ya se pagan: el segundo cuesta %d monedas, y cada uno cuesta el doble que el anterior. Se paga UNA vez: no hay sueldos ni cuotas." % roundi(Game.PRECIO_FICHAR_BASE * Game.PRECIO_FICHAR_MULT))
	var pie: VBoxContainer = acciones()
	pie.add_child(HSeparator.new())
	MenuScaffold.pastilla(pie, "Contratar gratis con %s" % str(base.get("nombre")).to_lower(),
		func() -> void: _abrir_creador(base), true, true)


func _ficha_pago(vb: VBoxContainer) -> void:
	var precio: int = Game.precio_fichar()
	MenuScaffold.titulo_item(vb, "Contratar a alguien más", AMBAR)
	vb.add_child(HSeparator.new())
	row(vb, "Cuesta", "%d monedas" % precio, VERDE if Game.puede_pagar(precio) else ROJO)
	row(vb, "Tienes", "%d monedas" % Game.money)
	_filas_comunes(vb)
	note(vb, "Cada contrato cuesta el doble que el anterior. Se paga UNA vez: no hay sueldos ni cuotas, pero armar y reparar a tres cuesta lo que cuesta.")
	note(vb, "Llega a nivel 1, con las cinco habilidades a 0 y sin nada equipado. Se le pone equipo desde el menú de personaje (C) y sube sus habilidades peleando, como tú.")
	var pie: VBoxContainer = acciones()
	pie.add_child(HSeparator.new())
	var txt: String = "Contratar por %d monedas" % precio
	if not Game.puede_pagar(precio):
		txt = "Te faltan %d monedas" % (precio - Game.money)
	MenuScaffold.pastilla(pie, txt, func() -> void: _abrir_creador(null), true, Game.puede_pagar(precio))


func _filas_comunes(vb: VBoxContainer) -> void:
	row(vb, "Llega", "Nivel 1, con las cinco habilidades a 0")
	row(vb, "En plantilla", "%d" % Game.plantilla.size())
	row(vb, "Bajan contigo", "%d de %d" % [Game.party.size(), Game.PARTY_MAX])
	if Game.party.size() >= Game.PARTY_MAX:
		note(vb, "Tu equipo ya va lleno: quien contrates ahora se queda en el Hogar hasta que lo metas en el equipo desde allí.")


func _abrir_creador(arma: Resource) -> void:
	var gratis: bool = Game.fichaje_gratis()
	var precio: int = Game.precio_fichar()
	CreadorPersonaje.abrir(self,
		"CONTRATAR  ·  GRATIS" if gratis else "CONTRATAR  ·  %d monedas" % precio,
		"Llega a nivel 1 y trae %s de regalo." % str(arma.get("nombre")).to_lower() if gratis and arma != null
			else "Llega a nivel 1, sin habilidades y sin equipo. Lo demás lo pones tú.",
		"Contratar", {"color": CreadorPersonaje.COLOR_INICIAL},
		func(nombre: String, asp: Dictionary):
			var pj: PersonajeData = Game.fichar_en_taberna(nombre, asp, arma)
			if pj == null:
				decir("No te llega el dinero.", false)
			elif Game.party.has(pj):
				decir("%s se une al grupo%s. Baja contigo desde ya." % [pj.nombre,
					" con su arma puesta" if pj.equipped_main != null else ""])
			else:
				decir("%s se une, pero tu equipo va lleno: te espera en el Hogar." % pj.nombre)
			sel = 0
			_rebuild())


# ============================================================
#  LAS COPIAS DE ESCAPARATE: el arma con su T1 en la celda, sin registrar (irian a tu baul) y con
#  su meta borrada al cerrar.
# ============================================================

var _vitrinas: Dictionary = {}

func _vitrina(base: Resource) -> Resource:
	if not _vitrinas.has(base):
		_vitrinas[base] = Game.crear_item(base, 1, Upgrades.Rareza.COMUN, {}, false)
	return _vitrinas[base]


func _vaciar_vitrina() -> void:
	for copia in _vitrinas.values():
		Game.item_meta.erase(copia)
	_vitrinas.clear()
