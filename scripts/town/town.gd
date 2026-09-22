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
	# RED DE SEGURIDAD de la arena: se llegue al pueblo por donde se llegue (puerta, caer, piedra de
	# retorno, una caida de la sala...), lo de la arena no sale de ella.
	_de_la_arena = Game.es_arena() or Game.en_foto_de_arena() or Game.vuelta_de_arena
	Game.salir_de_arena()
	Game.vuelta_de_arena = false
	_suelo = Node2D.new()
	_suelo.name = "Suelo"
	_suelo.z_index = -1
	add_child(_suelo)
	move_child(_suelo, 0)
	# La luz ANTES que nada: las casas y el altar se apuntan en ella al montarse.
	_crear_luz()
	_pintar_suelo()
	_crear_murallas()
	_crear_choques()
	_crear_casas()
	_crear_escalera()
	_crear_jardin()
	add_child(_puerta("res://scripts/town/porton_arena.gd", PuebloPlano.PORTON_ARENA, ""))
	_crear_canas()
	_crear_luces()
	_crear_carteles()
	_crear_plaza_y_mercado()
	_crear_guardias()
	Net.semilla_pueblo_cambiada.connect(_crear_canas)
	_colocar_jugador()


# ------------------------------------------------------------
#  EL DIA Y LA NOCHE (LuzPueblo + CicloDia).
# ------------------------------------------------------------
var luz: LuzPueblo = null

func _crear_luz() -> void:
	luz = LuzPueblo.new()
	luz.name = "Luz"
	add_child(luz)


# ------------------------------------------------------------
#  LAS LUCES DE NOCHE: postes con antorcha y braseros (PuebloPlano.POSTES / BRASEROS). El soporte es una
#  pieza con altura (se pasa por detras); el fuego, una Antorcha en su boca que se enciende sola al
#  anochecer y suena de cerca; la luz, un foco en LuzPueblo.
#  Cada una con su fuego y su retraso sacados de su CASILLA: iguales para todos en multi.
# ------------------------------------------------------------
func _crear_luces() -> void:
	for l in PuebloPlano.luces():
		var clave: String = l[0]
		var c: Vector2i = l[1]
		var brasero: bool = clave == "brasero"
		var pieza: PiezaPueblo = PiezaPueblo.crear(clave, Rect2i(c, Vector2i.ONE), true)
		add_child(pieza)
		var lista: Array = FuegoSprites.BRASEROS if brasero else FuegoSprites.ANTORCHAS
		var perfil: int = lista[int(PuebloSprites._rnd(c.x, c.y, 401) * float(lista.size())) % lista.size()]
		var retraso: float = PuebloSprites._rnd(c.x, c.y, 402)
		var boca: Vector2 = PuebloSprites.boca_brasero() if brasero else PuebloSprites.boca_poste()
		var fuego: Antorcha = Antorcha.crear(perfil, retraso, c.x * 1000 + c.y)
		pieza.acompanar(fuego, boca)
		var centro: Vector2 = pieza.position + boca + Vector2(0, -6)
		if brasero:
			luz.poner_foco(centro + Vector2(0, 14), 120.0, Color(1.0, 0.80, 0.52), 1.0, retraso, false, 0.20, 0.5)
		else:
			luz.poner_foco(centro + Vector2(0, 22), 95.0, Color(1.0, 0.84, 0.58), 1.0, retraso, false, 0.16, 0.45)


# ------------------------------------------------------------
#  LOS CARTELES INDICADORES de los cruces (PuebloPlano.CARTELES): la pieza, estrecha como el poste de
#  antorcha, y encima el nodo que se lee con F (cartel_indicador.gd).
# ------------------------------------------------------------
func _crear_carteles() -> void:
	for c in PuebloPlano.CARTELES:
		var casilla: Vector2i = c["casilla"]
		add_child(PiezaPueblo.crear("cartel_indicador", Rect2i(casilla, Vector2i.ONE), true))
		var p: Node2D = _puerta("res://scripts/town/cartel_indicador.gd", casilla, "")
		p.name = "Cartel"
		p.destinos = c["destinos"]
		add_child(p)


# ------------------------------------------------------------
#  LA PLAZA DE LA FUENTE Y EL MERCADILLO (PuebloPlano.PARQUE / MERCADO): la fuente con su agua animada
#  encima, y los muebles. Todos 'dinamicos' salvo la fuente: son de una casilla de fondo, y quien se
#  arrima por delante mete la cabeza en lo que sobresale (el toldo, la copa del arbol).
# ------------------------------------------------------------
func _crear_plaza_y_mercado() -> void:
	var fuente: PiezaPueblo = PiezaPueblo.crear("fuente", PuebloPlano.FUENTE)
	add_child(fuente)
	# El agua va con el pilon (por debajo de quien este delante), pintada despues de el.
	var agua: AguaFuente = AguaFuente.crear()
	agua.z_as_relative = false
	agua.z_index = PiezaPueblo.Z_DEBAJO
	fuente.add_child(agua)
	for m in PuebloPlano.MUEBLES:
		var clave: String = m[0]
		add_child(PiezaPueblo.crear(clave, m[1], clave != "parterre"))


# ------------------------------------------------------------
#  LOS GUARDIAS de los portones con su cambio de turno (GuardiasPlan / GuardiaPueblo). Cada uno se
#  coloca solo segun la hora: aqui solo se crean.
# ------------------------------------------------------------
func _crear_guardias() -> void:
	for i in GuardiasPlan.GUARDIAS.size():
		add_child(GuardiaPueblo.crear(i))


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
			if s == S.HIERBA:
				var f: int = PuebloTerreno.flor_de(c)
				if f >= 0:
					(_tm["flores"] as TileMapLayer).set_cell(c, 0, PuebloTerreno.celda_de("flores", f))
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
		_encender_ventanas(pieza, dibujo)
		_colgar_cartel(pieza, dibujo)
		for a in PuebloPlano.ADORNOS.get(clave, []):
			var celda_a: Vector2i = PuebloPlano.puerta_de(casa) + Vector2i(int(a[1]), 0)
			nodo.add_child(PiezaPueblo.crear(String(a[0]), Rect2i(celda_a, Vector2i.ONE), true))
		var guion: String = String(casa.get("script", ""))
		if guion == "":
			continue
		# SIN ROTULO: lo que es cada casa lo dice su cartel (lo pidio el usuario).
		nodo.add_child(_puerta(guion, PuebloPlano.puerta_de(casa), ""))


# EL CARTEL DEL OFICIO, colgado de un lado de la fachada y asomando fuera de ella (CasaSprites.cartel).
# Se ordena como la PARED de la que cuelga (ver PiezaPueblo.colgar): lo de delante lo tapa.
func _colgar_cartel(pieza: PiezaPueblo, dibujo: String) -> void:
	var icono: String = String(CasaSprites.CASAS[dibujo].get("cartel", ""))
	if icono == "":
		return
	var s := Sprite2D.new()
	s.name = "Cartel"
	s.texture = ImageTexture.create_from_image(CasaSprites.cartel(icono, CasaSprites.cartel_a_la_izq(dibujo)))
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pieza.colgar(s, Vector2(CasaSprites.posicion_cartel(dibujo)))


# LAS VENTANAS DE NOCHE: el vidrio encendido encima de cada una (con la fachada, z de la parte de abajo)
# y un corro de luz pequeño delante. Cada casa se enciende con su retraso, y sus ventanas casi a la vez.
func _encender_ventanas(pieza: PiezaPueblo, dibujo: String) -> void:
	var retraso_casa: float = PuebloSprites._rnd(int(pieza.position.x), int(pieza.position.y), 311)
	var i: int = 0
	var ventanas: Array = CasaSprites.ventanas(dibujo)
	if ventanas.is_empty():
		return
	# La imagen de la casa TAL CUAL se pinta (la horneada si la hay): el vidrio se recorta contra ella.
	var casa_img: Image = PuebloSprites.textura("casa_" + dibujo).get_image()
	if casa_img.is_compressed():
		casa_img.decompress()
	for v in ventanas:
		var esq: Vector2i = v[0]
		var luz_v: String = v[1]
		var vidrio := Sprite2D.new()
		vidrio.texture = CasaSprites.textura_vidrio(dibujo, esq, luz_v, casa_img)
		vidrio.centered = false
		vidrio.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vidrio.z_as_relative = false
		vidrio.z_index = PiezaPueblo.Z_DEBAJO
		vidrio.position = Vector2(esq)
		pieza.add_child(vidrio)
		var retraso: float = clampf(retraso_casa + 0.05 * float(i), 0.0, 1.0)
		luz.poner_encendible(vidrio, retraso)
		var centro: Vector2 = pieza.position + Vector2(esq) + Vector2.ONE * float(CasaSprites.TAM_VENTANA) * 0.5
		luz.poner_foco(centro + Vector2(0, 6), 34.0, CasaSprites.color_luz(luz_v), 0.9, retraso, false, 0.10, 0.7)
		i += 1


# El nodo de la puerta: el script del oficio de siempre, pegado a la fachada. Desde la casilla de
# delante, la distancia al jugador queda muy por debajo de su interact_range (40 px).
func _puerta(guion: String, c: Vector2i, nombre: String) -> Node2D:
	var p := Node2D.new()
	p.name = "Puerta"
	p.set_script(load(guion))
	p.position = Vector2(c) * float(PuebloPlano.CELDA) + Vector2(PuebloPlano.CELDA * 0.5, 6.0)
	if nombre == "":
		return p
	var l := Label.new()
	l.name = "Label"
	l.text = nombre
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(140, 16)
	l.position = Vector2(-70, 8)
	Game.elevar_letrero(l)
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
	# Sin rotulo, como las casas: lo que hace la F lo dice el boton flotante del HUD (ver hud.gd).
	var p: Node2D = _puerta("res://scripts/town/door.gd", r.position, "")
	p.position = (Vector2(r.position) + Vector2(r.size) * 0.5) * celda
	p.radio_extra = float(r.size.x) * celda * 0.5
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
	# Y de noche alumbra el claro, en BLANCO (lo pidio el usuario): siempre encendido, se nota al oscurecer.
	var boca: Vector2 = columna.position + PuebloSprites.boca_altar() + Vector2(0, -12)
	luz.poner_foco(boca + Vector2(0, 20), 130.0, Color(0.93, 0.96, 1.0), 1.0, 0.0, true, 0.22, 0.45)
	add_child(_puerta("res://scripts/town/altar.gd", a + Vector2i(0, 1), ""))


# ------------------------------------------------------------
#  EL JUGADOR: aparece en la plaza, y la camara no enseña lo que hay fuera del plano.
# ------------------------------------------------------------
var _de_la_arena := false

func _colocar_jugador() -> void:
	var jugador: Node2D = get_node_or_null("Player") as Node2D
	if jugador == null:
		return
	# Vuelves de la ARENA: por su porton, no por la escalera de la plaza.
	var donde: Vector2 = PuebloPlano.vuelta_de_arena_px() if _de_la_arena else PuebloPlano.aparicion_px()
	# RECOLOCAR y no mover a pelo: el sequito se sembro en el _ready del jugador, en el sitio donde lo
	# deja la escena y antes de que existiera el pueblo. Moviendolo a pelo, la fila se quedaba alli (ver
	# party_trail.teletransportar).
	if jugador.has_method("recolocar"):
		jugador.recolocar(donde)
	else:
		jugador.global_position = donde
	var cam: Camera2D = jugador.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tam: Vector2 = PuebloPlano.tam_px()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(tam.x)
	cam.limit_bottom = int(tam.y)
	cam.reset_smoothing()
