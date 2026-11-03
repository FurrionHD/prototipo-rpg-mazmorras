# LOS EFECTOS DEL TRENT Y SUS BICHOS TAL COMO SALEN EN EL JUEGO (03/11, paso 5 de trent-mutante), en una hoja para el
# jefe, paso a paso sobre suelo de mazmorra, con los sprites horneados y las cajas de su dibujo (CombatTactico.rect_dibujo,
# lo mismo que usa la pelea). Filas: la RESINA (el goteron y el cepo en los pies, que al final se suelta a trozos), la
# SAVIA NEGRA (goteron, charco negro y el humo), el GEISER (su carga y la nube), el ESTALLIDO de la costra, MAS SECO
# (grietas con 3 tramos y humo de 5 cargas), CHUPAR, la BOLA de caca y el Pringado, el PICOR y el REVENTON de la
# garrapata. Con ventana:
#   godot --path . res://tools/ver_efectos_trent_juego.tscn
# -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/trent_efectos_juego.png
extends Node2D

const CombatTactico = preload("res://scripts/ui/combat_tactico.gd")

const LADO := 300
const ZOOM := 1.15
const ESCALA := 1.15           # SpriteLienzo.UNIDADES_POR_CELDA
const SUELO := Color(0.13, 0.12, 0.14)
const T := [0.0, 0.2, 0.35, 0.5, 0.7, 0.9, 1.1, 1.4, 1.7, 2.1]

var _rotulo: Label = null
var _hoja: Image = null
var _fila: int = 0
var _nodos: Array = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(SUELO)
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(cam)
	cam.make_current()
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 12)
	capa.add_child(_rotulo)
	call_deferred("_hacer")


# Un cuerpo como los del juego: un Node2D con su AnimatedSprite2D dentro (rect_dibujo mira a los hijos).
func _cuerpo(sf: SpriteFrames, anim: String, pos: Vector2, ed: EnemyData = null) -> AnimatedSprite2D:
	var cu := Node2D.new()
	cu.position = pos
	cu.z_as_relative = false
	cu.z_index = SueloRoto.Z_SUELO + 1   # como en la pelea: los cuerpos encima de lo del suelo
	add_child(cu)
	_nodos.append(cu)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.animation = StringName(anim) if sf.has_animation(anim) else &"idle_1"
	spr.frame = 0
	spr.pause()
	spr.scale = Vector2.ONE * (SpritesEnemigo.escala_de(ed) if ed != null else ESCALA)   # la del juego (Enemy)
	cu.add_child(spr)
	return spr


func _caja(spr: AnimatedSprite2D) -> Rect2:
	return CombatTactico.rect_dibujo(spr.get_parent() as Node2D)


func _a_tiempo(spr: AnimatedSprite2D, anim: String, t: float) -> void:
	if spr.sprite_frames.has_animation(anim):
		spr.animation = StringName(anim)
	var n: int = spr.sprite_frames.get_frame_count(spr.animation)
	var fps: float = spr.sprite_frames.get_animation_speed(spr.animation)
	spr.frame = clampi(int(t * fps), 0, n - 1) if not spr.sprite_frames.get_animation_loop(spr.animation) else int(t * fps) % n


func _efecto(n: Node) -> Node:
	if n != null:
		n.set_process(false)
		_nodos.append(n)
	return n


func _avanzar(n: Node, t: float) -> void:
	if n != null and is_instance_valid(n):
		n.call("avanzar_a", t)


func _limpiar() -> void:
	for n in _nodos:
		if is_instance_valid(n):
			n.queue_free()
	_nodos.clear()
	_fila += 1


func _hacer() -> void:
	_hoja = Image.create(LADO * T.size(), LADO * 9, false, Image.FORMAT_RGBA8)
	BarridoAire.ritmo = 1.0
	var trent: EnemyData = load("res://scenes/actors/enemy/trent.tres")
	var rata_ed: EnemyData = load("res://scenes/actors/enemy/rata.tres")
	var sf_amb: SpriteFrames = SpritesEnemigo.frames_de(trent, 0.5, true, &"ambarino")
	var sf_amb_r: SpriteFrames = SpritesEnemigo.frames_variante(trent, &"ambarino", &"sin_costra")
	var sf_esp: SpriteFrames = SpritesEnemigo.frames_de(trent, 0.5, true, &"espantajo")
	var sf_rata: SpriteFrames = SpritesEnemigo.frames_de(rata_ed, 0.5)
	var victima := Vector2(55, 40)

	# 1. LA RESINA: el Tocon escupe, el pegote cae y se queda el cepo; al final se suelta a trozos.
	var amb := _cuerpo(sf_amb, "escupir_1", Vector2(-60, 20), trent)
	var rata := _cuerpo(sf_rata, "idle_5", victima, rata_ed)
	var f := CombatFormas.circulo(victima, 20.0)
	f.dir = (victima - Vector2(-60, 20)).normalized()
	f.ancho = victima.distance_to(Vector2(-60, 20))
	var got: Node = _efecto(TrentAire.area(self, f, TrentAire.Modo.RESINA, 3, 0.0))
	var cepo: TrentAire = null
	for i in T.size():
		var t: float = float(T[i])
		_a_tiempo(amb, "escupir_1", t)
		_avanzar(got, t)
		if t >= TrentAire.T_GOTERON and cepo == null:
			cepo = _efecto(TrentAire.pegado(self, TrentAire.Modo.RESINA, _caja(rata), 1, 4))
		if cepo != null:
			if t >= 1.4:
				cepo.secar()
			_avanzar(cepo, t - TrentAire.T_GOTERON)
		await _viñeta(i, "resina  %.2f s" % t)
	_limpiar()

	# 2. LA SAVIA NEGRA: el goteron negro, su charco negro y el humo violeta (1 carga).
	var esp := _cuerpo(sf_esp, "escupir_1", Vector2(-70, 30), trent)
	rata = _cuerpo(sf_rata, "idle_5", victima, rata_ed)
	f = CombatFormas.circulo(victima, 20.0)
	f.dir = (victima - Vector2(-70, 30)).normalized()
	f.ancho = victima.distance_to(Vector2(-70, 30))
	got = _efecto(TrentAire.area(self, f, TrentAire.Modo.HUMO, 5, 0.0))
	var charco: BestiaAire = null
	var humo: TrentAire = null
	for i in T.size():
		var t: float = float(T[i])
		_a_tiempo(esp, "escupir_1", t)
		_avanzar(got, t)
		if t >= TrentAire.T_GOTERON and charco == null:
			charco = _efecto(BestiaAire.charco(self, CombatFormas.circulo(victima + Vector2(0, 4), 20.0), 6, 0.0))
			charco.vestir_savia_negra()
			humo = _efecto(TrentAire.pegado(self, TrentAire.Modo.HUMO, _caja(rata), 1, 7))
		if charco != null:
			charco.set("_t", t - TrentAire.T_GOTERON + 0.3)
			for c in charco.get_children():
				(c as Node2D).queue_redraw()
			_avanzar(humo, t - TrentAire.T_GOTERON)
		await _viñeta(i, "savia negra  %.2f s" % t)
	_limpiar()

	# 3. EL GEISER: su carga (la grieta brilla) y, en el golpe, el chorro, la nube y la lluvia sobre el circulo.
	esp = _cuerpo(sf_esp, "geiser_carga_1", Vector2(-70, 40), trent)
	var pies_e := Vector2(-70, 40)
	f = CombatFormas.circulo(Vector2(50, 40), 45.0)
	f.dir = Vector2.RIGHT
	f.ancho = 120.0
	var carga: TrentAire = _efecto(TrentAire.pegado(self, TrentAire.Modo.CARGA, _caja(esp), 1, 8))
	var gei: Node = null
	const T_GOLPE := 0.5   # la carga hasta aqui; luego su animacion 'geiser' (se arquea en el 0,35 de ella)
	for i in T.size():
		var t: float = float(T[i])
		if t < T_GOLPE:
			_a_tiempo(esp, "geiser_carga_1", t)
			carga.avanzar_a(t)
		else:
			if gei == null:
				carga.secar()
				gei = _efecto(TrentAire.area(self, f, TrentAire.Modo.GEISER, 9, 0.35))
			_a_tiempo(esp, "geiser_1", t - T_GOLPE)
			carga.avanzar_a(t)
			_avanzar(gei, TrentAire.T_SALE - 0.35 + (t - T_GOLPE))
		await _viñeta(i, "geiser  %.2f s" % t)
	_limpiar()

	# 4. EL ESTALLIDO DE LA COSTRA: se rompe, cambia a su hoja sin ambar y los grumos salen.
	amb = _cuerpo(sf_amb, "idle_1", Vector2(0, 40), trent)
	var est: TrentAire = _efecto(TrentAire.estallido(self, _caja(amb), 11))
	amb.sprite_frames = sf_amb_r
	amb.animation = &"idle_1"
	for i in T.size():
		var t: float = float(T[i]) * 0.6
		est.avanzar_a(t)
		await _viñeta(i, "costra rota  %.2f s" % t)
	_limpiar()

	# 5. MAS SECO (3 tramos) y humo de 5 cargas, en el Espantajo.
	esp = _cuerpo(sf_esp, "idle_1", Vector2(0, 60), trent)
	var seco: TrentAire = _efecto(TrentAire.pegado(self, TrentAire.Modo.SECO, _caja(esp), 3, 12))
	humo = _efecto(TrentAire.pegado(self, TrentAire.Modo.HUMO, _caja(esp), 5, 13))
	for i in T.size():
		var t: float = float(T[i])
		_a_tiempo(esp, "idle_1", t)
		seco.avanzar_a(t)
		humo.avanzar_a(t)
		await _viñeta(i, "seco 3 tramos + humo 5  %.2f s" % t)
	_limpiar()

	# 6. CHUPAR (hilos) a una rata resinada.
	esp = _cuerpo(sf_esp, "idle_1", Vector2(-70, 40), trent)
	rata = _cuerpo(sf_rata, "idle_5", victima, rata_ed)
	cepo = _efecto(TrentAire.pegado(self, TrentAire.Modo.RESINA, _caja(rata), 1, 14))
	var chu: Node = _efecto(TrentAire.chupar(self, victima, Vector2(-70, 40), 0, 15))
	for i in T.size():
		var t: float = float(T[i]) * 0.7
		cepo.avanzar_a(t + 1.0)
		_avanzar(chu, t)
		await _viñeta(i, "chupar  %.2f s" % t)
	_limpiar()

	# 7. LA BOLA DE CACA: rueda por su linea, pilla a la rata y la deja pringada.
	var pel_ed: EnemyData = load("res://resources/enemigos_invocados/bicho_pelotero.tres")
	var pel := _cuerpo(SpritesEnemigo.frames_de(pel_ed, 0.5), "bola_2", Vector2(-80, 40), pel_ed)
	rata = _cuerpo(sf_rata, "idle_5", Vector2(10, 40), rata_ed)
	var fl := CombatFormas.linea(Vector2(-70, 40), Vector2.RIGHT, 100.0, 14.0)
	var bola: Node = _efecto(AmbarAire.bola(self, fl, 16, 0.0))
	var pri: AmbarAire = null
	for i in T.size():
		var t: float = float(T[i])
		_a_tiempo(pel, "bola_2", t)
		_avanzar(bola, t)
		var llega: float = AmbarAire.retraso_bola(fl, Vector2(10, 40))
		if t >= llega and pri == null:
			pri = _efecto(AmbarAire.pegado(self, AmbarAire.Modo.PRINGUE, _caja(rata), 17))
		if pri != null:
			pri.avanzar_a(t - llega)
		await _viñeta(i, "bola de caca + pringado  %.2f s" % t)
	_limpiar()

	# 8. EL PICOR del mosquito, en una rata.
	rata = _cuerpo(sf_rata, "idle_5", Vector2(0, 30), rata_ed)
	var pic: AmbarAire = _efecto(AmbarAire.pegado(self, AmbarAire.Modo.PICOR, _caja(rata), 18))
	for i in T.size():
		var t: float = float(T[i]) * 0.5
		pic.avanzar_a(t)
		await _viñeta(i, "picor  %.2f s" % t)
	_limpiar()

	# 9. EL REVENTON de la garrapata hinchada (r 30).
	var gar_ed: EnemyData = load("res://resources/enemigos_invocados/bicho_garrapata.tres")
	var gar := _cuerpo(SpritesEnemigo.frames_variante(gar_ed, &"", &"h3"), "muerte_1", Vector2(0, 30), gar_ed)
	var rev: Node = _efecto(AmbarAire.revienta(self, Vector2(0, 30), 30.0, 19))
	for i in T.size():
		var t: float = float(T[i]) * 0.5
		_a_tiempo(gar, "muerte_1", t)
		_avanzar(rev, t)
		await _viñeta(i, "reventon garrapata  %.2f s" % t)
	_limpiar()

	var carpeta: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/ataques_mapa/enemigos/prueba_3d/mutantes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var ruta: String = carpeta + "/trent_efectos_juego.png"
	_hoja.save_png(ruta)
	print("[hoja] ", ruta)
	get_tree().quit(0)


func _viñeta(col: int, texto: String) -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_rotulo.text = texto
	_rotulo.position = tam * 0.5 - Vector2(LADO, LADO) * 0.5 + Vector2(6, 4)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var cen: Vector2i = img.get_size() / 2
	_hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)), Vector2i(col * LADO, _fila * LADO))
