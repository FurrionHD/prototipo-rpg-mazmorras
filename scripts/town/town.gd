# ============================================================
#  town.gd  --  EL PUEBLO, montado desde el plano (PuebloPlano).
#
#  La escena town.tscn ya solo trae al jugador: el suelo, los choques, las casas con su puerta, la
#  escalera de la mazmorra y el altar salen de aqui. Cada puerta lleva EL MISMO script de oficio de
#  siempre (herrero.gd, shop.gd...), asi que abrir un oficio sigue siendo "F sobre un interactable":
#  lo unico que ha cambiado es DONDE esta ese nodo.
#
#  Nada de esto depende de nombres de nodo: el juego detecta el pueblo por la ruta de la escena
#  (Game.en_pueblo) y el multijugador coloca a los demas por posicion.
# ============================================================
extends Node2D

# El suelo y lo que va pegado a el, por DEBAJO del jugador (que esta a z 0).
var _suelo: Node2D = null
var _tm: Dictionary = {}


func _ready() -> void:
	_suelo = Node2D.new()
	_suelo.name = "Suelo"
	_suelo.z_index = -1
	add_child(_suelo)
	move_child(_suelo, 0)
	_pintar_suelo()
	_crear_murallas()
	_crear_choques()
	_crear_casas()
	_crear_escalera()
	_crear_jardin()
	_crear_canas()
	Net.semilla_pueblo_cambiada.connect(_crear_canas)
	_colocar_jugador()


# En solitario, irse del pueblo (bajar a la mazmorra) estrena semilla: al volver, las cañas estan en
# otro sitio. En sesion no se toca: la renueva el host para todos (ver Game.semilla_pueblo).
func _exit_tree() -> void:
	if not Net.activo:
		Game.semilla_pueblo = randi() | 1


# ------------------------------------------------------------
#  LAS CAÑAS DE PESCAR del muelle: tres al azar, las mismas para todos (ver PuebloPlano.canas).
#  Decorado puro: ni chocan ni se tocan. Se rehacen si llega otra semilla estando en el pueblo.
# ------------------------------------------------------------
var _canas: Node2D = null

func _crear_canas() -> void:
	if _canas != null and is_instance_valid(_canas):
		_canas.queue_free()
	_canas = Node2D.new()
	_canas.name = "Canas"
	add_child(_canas)
	for c in PuebloPlano.canas(Game.semilla_pueblo_actual()):
		var s := Sprite2D.new()
		s.texture = PuebloSprites.textura("cana_" + String(c[1]))
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_as_relative = false
		s.z_index = -1
		s.position = PuebloPlano.centro_px(c[0]) - Vector2(PuebloSprites.CANA_TAM) * 0.5
		_canas.add_child(s)


# ------------------------------------------------------------
#  SUELO
# ------------------------------------------------------------
func _pintar_suelo() -> void:
	var ts: TileSet = PuebloTerreno.tileset()
	for capa in PuebloTerreno.CAPAS_ORDEN:
		var tml := TileMapLayer.new()
		tml.name = "TM_" + capa
		tml.tile_set = ts
		# POR NODO, que el proyecto no lo pone globalmente (misma nota que en enemy.gd).
		tml.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_suelo.add_child(tml)
		_tm[capa] = tml
	var S := PuebloPlano.Suelo
	var es := func(tipos: Array) -> Callable:
		return func(v: Vector2i) -> bool: return tipos.has(PuebloPlano.suelo(v))
	var soy_calle: Callable = es.call([S.CALLE])
	# El agua no hace orilla contra la madera: el muelle esta DENTRO del agua, no en su borde.
	var soy_agua: Callable = es.call([S.AGUA, S.MADERA])
	var soy_madera: Callable = es.call([S.MADERA])
	for y in PuebloPlano.ALTO:
		for x in PuebloPlano.ANCHO:
			var c := Vector2i(x, y)
			var s: int = PuebloPlano.suelo(c)
			# Hierba debajo de TODO: la orilla del agua y el canto de la calle se desvanecen a alfa y
			# por ahi tiene que verse algo.
			_poner("hierba", c, 0)
			match s:
				S.CALLE:
					_poner("calle", c, TerrenoSprites.mascara(c, soy_calle))
				S.AGUA:
					_poner("agua", c, TerrenoSprites.mascara(c, soy_agua))
					var arriba := c + Vector2i(0, -1)
					if PuebloPlano.suelo(arriba) == S.MADERA:
						_poner("pilote", c, TerrenoSprites.mascara(arriba, soy_madera))
				S.MADERA:
					_poner("madera", c, TerrenoSprites.mascara(c, soy_madera))
				# La MURALLA ya no es la baldosa de la mazmorra: es una imagen por tramo (_crear_murallas).


func _poner(capa: String, c: Vector2i, mask: int) -> void:
	(_tm[capa] as TileMapLayer).set_cell(c, 0, PuebloTerreno.celda_para(capa, c, mask))


# ------------------------------------------------------------
#  LA MURALLA: tres tramos dibujados (MurallaSprites), con sus portones. Por debajo de los personajes:
#  cabe en su huella, asi que quien se arrima esta siempre delante.
# ------------------------------------------------------------
func _crear_murallas() -> void:
	var celda: float = float(PuebloPlano.CELDA)
	var tramos := [
		["muralla_oeste", Vector2(0, 0)],
		["muralla_este", Vector2(float(PuebloPlano.ANCHO - 2) * celda, 0)],
		["muralla_norte", Vector2(0, 0)],
	]
	for t in tramos:
		var s := Sprite2D.new()
		s.name = String(t[0])
		s.texture = MurallaSprites.textura(String(t[0]))
		s.centered = false
		s.position = t[1]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_as_relative = false
		s.z_index = -1
		add_child(s)


# ------------------------------------------------------------
#  CHOQUES: una caja por rectangulo fundido del plano.
# ------------------------------------------------------------
func _crear_choques() -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Choques"
	add_child(cuerpo)
	var celda: float = float(PuebloPlano.CELDA)
	for r in PuebloPlano.solidos_fusionados():
		var forma := RectangleShape2D.new()
		forma.size = Vector2(r.size) * celda
		var col := CollisionShape2D.new()
		col.shape = forma
		col.position = (Vector2(r.position) + Vector2(r.size) * 0.5) * celda
		cuerpo.add_child(col)
	# Y lo pequeño, con la caja de lo que se VE (barriles, yunque, columna, verjas).
	for rp in PuebloPlano.cajas_pequenas():
		var forma2 := RectangleShape2D.new()
		forma2.size = rp.size
		var col2 := CollisionShape2D.new()
		col2.shape = forma2
		col2.position = rp.get_center()
		cuerpo.add_child(col2)


# ------------------------------------------------------------
#  CASAS
# ------------------------------------------------------------
func _crear_casas() -> void:
	var n_vacia: int = 0
	for casa in PuebloPlano.CASAS:
		var clave: String = casa["clave"]
		var r: Rect2i = casa["rect"]
		var nodo := Node2D.new()
		nodo.name = "Casa_" + clave
		add_child(nodo)
		# Cada oficio con SU casa (CasaSprites). Las de relleno van turnandose entre sus variantes.
		var dibujo: String = clave
		if clave == "vacia":
			dibujo = "vacia_%d" % (n_vacia % CasaSprites.VARIANTES_VACIA)
			n_vacia += 1
		var pieza: PiezaPueblo = PiezaPueblo.crear("casa_" + dibujo, r)
		nodo.add_child(pieza)
		# El humo de sus chimeneas, que sube de verdad (HumoChimenea).
		for b in CasaSprites.bocas_humo(dibujo):
			var humo: HumoChimenea = HumoChimenea.crear(bool(b[1]))
			humo.position = pieza.position + (b[0] as Vector2)
			nodo.add_child(humo)
		for a in PuebloPlano.ADORNOS.get(clave, []):
			var celda_a: Vector2i = PuebloPlano.puerta_de(casa) + Vector2i(int(a[1]), 0)
			nodo.add_child(PiezaPueblo.crear(String(a[0]), Rect2i(celda_a, Vector2i.ONE), true))
		var guion: String = String(casa.get("script", ""))
		if guion == "":
			continue
		nodo.add_child(_puerta(guion, PuebloPlano.puerta_de(casa), String(casa.get("nombre", clave))))


# El nodo de la puerta: el script del oficio de siempre, pegado a la fachada. Desde la casilla de
# delante, la distancia al jugador queda muy por debajo de su interact_range (40 px).
func _puerta(guion: String, c: Vector2i, nombre: String) -> Node2D:
	var p := Node2D.new()
	p.name = "Puerta"
	p.set_script(load(guion))
	p.position = Vector2(c) * float(PuebloPlano.CELDA) + Vector2(PuebloPlano.CELDA * 0.5, 6.0)
	var l := Label.new()
	l.name = "Label"
	l.text = nombre
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(140, 16)
	l.position = Vector2(-70, 8)
	l.z_index = 1
	p.add_child(l)
	return p


# ------------------------------------------------------------
#  LA ESCALERA DE CARACOL (la entrada a la mazmorra): la pieza dibujada y door.gd de siempre en su boca.
# ------------------------------------------------------------
func _crear_escalera() -> void:
	var r: Rect2i = PuebloPlano.ESCALERA
	add_child(PiezaPueblo.crear("escalera_caracol", r))
	# La puerta va en el CENTRO del pozo con radio_extra: asi se entra desde cualquier lado. 48 es el
	# medio lado de la escalera; desde el norte el origen del jugador queda a ~66 px del centro (sus pies
	# van por debajo de su origen), y 66 - 48 = 18 cae dentro de su interact_range (40).
	var celda: float = float(PuebloPlano.CELDA)
	var p: Node2D = _puerta("res://scripts/town/door.gd", r.position, "→ MAZMORRA")
	p.position = (Vector2(r.position) + Vector2(r.size) * 0.5) * celda
	p.radio_extra = float(r.size.x) * celda * 0.5
	(p.get_node("Label") as Label).position.y = float(r.size.y) * celda * 0.5 + 4.0
	add_child(p)


# ------------------------------------------------------------
#  EL JARDIN DEL HOGAR: verjas y la columna del altar. Las dos son piezas ESTRECHAS, asi que van
#  'dinamicas' (ver PiezaPueblo): su parte alta solo tapa a quien pasa por detras.
# ------------------------------------------------------------
func _crear_jardin() -> void:
	var j: Rect2i = PuebloPlano.JARDIN
	for y in range(j.position.y, j.end.y):
		for x in range(j.position.x, j.end.x):
			var c := Vector2i(x, y)
			if not PuebloPlano.es_verja(c):
				continue
			# INVERTIDA: TerrenoSprites.mascara pone el bit donde el vecino NO es verja (es una mascara de
			# BORDES, la del autotile), y el dibujo de la verja quiere los lados hacia donde SIGUE. Sin el
			# 15 - m salian las verjas del reves: tramos de frente en los laterales y postes sueltos abajo.
			var m: int = 15 - TerrenoSprites.mascara(c, func(v: Vector2i) -> bool: return PuebloPlano.se_une_la_verja(v))
			add_child(PiezaPueblo.crear("verja_%d" % m, Rect2i(c, Vector2i.ONE), true))
	var a: Vector2i = PuebloPlano.ALTAR
	var columna: PiezaPueblo = PiezaPueblo.crear("altar_columna", Rect2i(a, Vector2i.ONE), true)
	add_child(columna)
	# El fuego blanco del altar, de verdad (LlamaAltar), en la boca del cuenco.
	columna.acompanar(LlamaAltar.crear(), PuebloSprites.boca_altar())
	add_child(_puerta("res://scripts/town/altar.gd", a + Vector2i(0, 1), "ALTAR"))


# ------------------------------------------------------------
#  EL JUGADOR: aparece en la plaza, y la camara no enseña lo que hay fuera del plano.
# ------------------------------------------------------------
func _colocar_jugador() -> void:
	var jugador: Node2D = get_node_or_null("Player") as Node2D
	if jugador == null:
		return
	jugador.global_position = PuebloPlano.aparicion_px()
	var cam: Camera2D = jugador.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tam: Vector2 = PuebloPlano.tam_px()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(tam.x)
	cam.limit_bottom = int(tam.y)
	cam.reset_smoothing()
