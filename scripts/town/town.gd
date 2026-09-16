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

# Colores de relleno de las casas mientras no tengan su dibujo (los de los cuadrados de antes).
const COLOR_CASA := {
	"hogar": Color(0.35, 0.25, 0.55),
	"boticaria": Color(0.3, 0.55, 0.35),
	"maestro": Color(0.68, 0.24, 0.28),
	"tienda": Color(0, 0.6, 0.8),
	"herreria": Color(0.45, 0.42, 0.5),
	"cocina": Color(0.9, 0.62, 0.3),
	"taberna": Color(0.72, 0.35, 0.18),
	"carpinteria": Color(0.6, 0.45, 0.28),
	"peleteria": Color(0.55, 0.38, 0.25),
	"pescador": Color(0.22, 0.48, 0.62),
	"vacia": Color(0.42, 0.38, 0.34),
}

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
	_crear_choques()
	_crear_casas()
	_crear_escalera()
	_crear_jardin()
	_colocar_jugador()


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
	var soy_muralla: Callable = es.call([S.MURALLA])
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
				S.MURALLA:
					_poner("muralla", c, TerrenoSprites.mascara(c, soy_muralla))


func _poner(capa: String, c: Vector2i, mask: int) -> void:
	(_tm[capa] as TileMapLayer).set_cell(c, 0, PuebloTerreno.celda_para(capa, c, mask))


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


# ------------------------------------------------------------
#  CASAS
# ------------------------------------------------------------
func _crear_casas() -> void:
	var celda: float = float(PuebloPlano.CELDA)
	for casa in PuebloPlano.CASAS:
		var clave: String = casa["clave"]
		var r: Rect2i = casa["rect"]
		var nodo := Node2D.new()
		nodo.name = "Casa_" + clave
		add_child(nodo)
		# De momento, la huella en su color (el dibujo de cada casa llega despues, una a una).
		var caja := ColorRect.new()
		caja.color = COLOR_CASA.get(clave, COLOR_CASA["vacia"])
		caja.position = Vector2(r.position) * celda
		caja.size = Vector2(r.size) * celda
		caja.z_index = -1
		nodo.add_child(caja)
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
#  LA ESCALERA DE CARACOL (la entrada a la mazmorra). door.gd de siempre, en su boca.
# ------------------------------------------------------------
func _crear_escalera() -> void:
	var celda: float = float(PuebloPlano.CELDA)
	var r: Rect2i = PuebloPlano.ESCALERA
	var hueco := ColorRect.new()
	hueco.color = Color(0.06, 0.05, 0.07)
	hueco.position = Vector2(r.position) * celda
	hueco.size = Vector2(r.size) * celda
	hueco.z_index = -1
	add_child(hueco)
	var boca := Vector2i(r.position.x + r.size.x / 2, r.end.y)
	add_child(_puerta("res://scripts/town/door.gd", boca, "→ MAZMORRA"))


# ------------------------------------------------------------
#  EL JARDIN DEL HOGAR: verjas y la columna del altar.
# ------------------------------------------------------------
func _crear_jardin() -> void:
	var celda: float = float(PuebloPlano.CELDA)
	var j: Rect2i = PuebloPlano.JARDIN
	for y in range(j.position.y, j.end.y):
		for x in range(j.position.x, j.end.x):
			var c := Vector2i(x, y)
			if not PuebloPlano.es_verja(c):
				continue
			var v := ColorRect.new()
			v.color = Color(0.20, 0.18, 0.17)
			v.position = Vector2(c) * celda + Vector2(12, 12)
			v.size = Vector2(8, 8)
			v.z_index = -1
			add_child(v)
	var a: Vector2i = PuebloPlano.ALTAR
	var col := ColorRect.new()
	col.color = Color(0.784314, 0.627451, 0.00392157)
	col.position = Vector2(a) * celda + Vector2(6, -26)
	col.size = Vector2(20, 58)
	col.z_index = -1
	add_child(col)
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
