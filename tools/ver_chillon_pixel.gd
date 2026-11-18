# EL CHILLON Y SUS MUTANTES CON SUS EFECTOS EN PIXEL, EN VIVO (18/11/2026, el jefe tiene que verlos en el juego): el suelo de
# verdad de la mazmorra, los cuerpos con su hoja horneada y tres muñecos alrededor; en bucle, cada ataque con LAS PIEZAS DEL
# JUEGO (SueloRoto para la sombra y el cono, EfectoPixel con las hojas de assets/sprites/efectos/chillon). Los pies, como los
# cuenta la pelea (rect_dibujo + centro_suelo de su ficha). Con ventana; se cierra sola.
#   godot --path . res://tools/ver_chillon_pixel.tscn          (VER_CAPTURA=<carpeta>: fotos de cada paso)
extends Node2D

const ZOOM := 3.0
const PISO := 8
const TACTICO := preload("res://scripts/ui/combat_tactico.gd")
const CELDA := SpriteLienzo.UNIDADES_POR_CELDA

var _rotulo: Label = null
var _cuerpo_d: Dictionary = {}
var _victimas: Array = []   # pies de los tres muñecos


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.06))
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position = Vector2(0, 0)
	add_child(cam)
	cam.make_current()
	var suelo := TileMapLayer.new()
	suelo.tile_set = TerrenoSprites.tileset_de_tramos(TerrenoSprites.tramos_de(PISO))
	suelo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	suelo.z_index = -100
	for y in range(-14, 14):
		for x in range(-16, 16):
			suelo.set_cell(Vector2i(x, y), 0, TerrenoSprites.celda_para("suelo", Vector2i(x, y), 0, 3))
	add_child(suelo)
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 16)
	_rotulo.position = Vector2(12, 8)
	capa.add_child(_rotulo)
	call_deferred("_bucle")


func _cuerpo(ruta: String, mut: StringName) -> Dictionary:
	var ed: EnemyData = load(ruta)
	var nodo := Node2D.new()
	nodo.z_index = Game.Z_PERSONAJES
	nodo.z_as_relative = false
	add_child(nodo)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5, mut != &"", mut)
	spr.scale = Vector2.ONE * SpritesEnemigo.escala_de(ed)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.name = "_sprite"
	nodo.add_child(spr)
	nodo.set("_sprite", spr)
	spr.play(&"idle_1")
	return {"nodo": nodo, "spr": spr, "ed": ed}


func _pies(d: Dictionary) -> Vector2:
	var r: Rect2 = TACTICO.rect_dibujo(d["nodo"])
	var ed: EnemyData = d["ed"]
	return Vector2(r.get_center().x, r.position.y + r.size.y * ed.centro_suelo_real())


func _muneco(p: Vector2) -> void:
	var n := Node2D.new()
	n.z_index = Game.Z_PERSONAJES
	n.z_as_relative = false
	add_child(n)
	var cuerpo := ColorRect.new()
	cuerpo.color = Color(0.23, 0.38, 0.7)
	cuerpo.size = Vector2(10, 16)
	cuerpo.position = p - Vector2(5, 16)
	n.add_child(cuerpo)
	var cara := ColorRect.new()
	cara.color = Color(0.87, 0.71, 0.59)
	cara.size = Vector2(7, 6)
	cara.position = p - Vector2(3.5, 22)
	n.add_child(cara)


func _anim(d: Dictionary, base: String, dir: int = 1) -> void:
	var spr: AnimatedSprite2D = d["spr"]
	var n: StringName = StringName("%s_%d" % [base, dir])
	SpriteLienzo.asegurar_anim(spr.sprite_frames, n)
	if spr.sprite_frames.has_animation(n):
		spr.play(n)


func _lanzar(nombre: String, pos: Vector2, dir: int = 0, espera: float = 0.0) -> EfectoPixel:
	return EfectoPixel.lanzar(self, "chillon", nombre, pos, dir, null, espera)


func _paso(texto: String, segundos: float) -> void:
	_rotulo.text = texto
	var carpeta: String = OS.get_environment("VER_CAPTURA")
	var t: float = 0.0
	var siguiente: float = 0.0
	while t < segundos:
		await get_tree().process_frame
		t += get_process_delta_time()
		if carpeta != "" and texto != "" and t >= siguiente:
			siguiente += 0.15
			get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [carpeta, texto.validate_filename().replace(" ", "_"), int(t / 0.15)])


func _poner(ruta: String, mut: StringName) -> Vector2:
	if not _cuerpo_d.is_empty():
		(_cuerpo_d["nodo"] as Node2D).queue_free()
	_cuerpo_d = _cuerpo(ruta, mut)
	await get_tree().process_frame
	var p: Vector2 = _pies(_cuerpo_d)
	(_cuerpo_d["nodo"] as Node2D).position += -p   # sus pies en el (0, 0)
	await get_tree().process_frame
	return _pies(_cuerpo_d)


# EL CHILLIDO DE OSCURIDAD como en la pelea: la sombra por el suelo (SueloRoto) y, a cada uno cuando le llega, su luz que se
# apaga y las motas de vuelta al bicho.
func _oscuro(p: Vector2, radio: float) -> void:
	var f := CombatFormas.circulo(p, radio)
	SueloRoto.lanzar(self, f, SueloRoto.Tipo.CHILLON_SOMBRA, 1, 0.0, 0.0)
	var hasta: Vector2 = EfectoPixel.centro_sprite(_cuerpo_d["nodo"], p)
	for v in _victimas:
		if v.distance_to(p) > radio:
			continue
		var llega: float = SueloRoto.retraso(f, v, SueloRoto.Tipo.CHILLON_SOMBRA)
		_lanzar("farol", v, 0, llega)
		var dur: float = 4.0 / 12.0
		for i in 4:
			var sale: float = llega + (3.0 + float(i) * 0.7) / 12.0
			var m: EfectoPixel = _lanzar("mota_entra", hasta, 0, sale + dur)
			if m != null:
				m.poner_vuelo("chillon", "mota", v - Vector2(0, 25.0 * CELDA) + Vector2(randf_range(-3, 3), randf_range(-3, 3)) * CELDA,
					hasta, 10.0 * CELDA, dur)


func _bucle() -> void:
	# tres muñecos alrededor, a 2/3 del radio de 70 (el de la cria, de 45, solo pilla a los de cerca)
	for k in 3:
		var a: float = 0.5 + k * TAU / 3.0
		var v := Vector2(cos(a), sin(a) * 0.8) * 48.0
		_victimas.append(v)
		_muneco(v)
	var CH := "res://scenes/actors/enemy/chillon.tres"
	var CRIA := "res://resources/enemigos_invocados/chillon_cria.tres"
	var cerca: Vector2 = _victimas[0]
	for vuelta in 2:
		# EL NORMAL
		var p: Vector2 = await _poner(CH, &"")
		var d: Vector2 = cerca - p
		_anim(_cuerpo_d, "embestida", SpriteLienzo.dir8(d))
		_lanzar("paletos", cerca, SpriteLienzo.dir8(d), 0.35)
		await _paso("CHILLON · basico y Picado (los paletos)", 1.4)
		_anim(_cuerpo_d, "chillido", SpriteLienzo.dir8(d))
		var fc := CombatFormas.cono(p, d.normalized(), 60.0, 100.0)
		SueloRoto.lanzar(self, fc, SueloRoto.Tipo.CHILLON_CONO, 1, 0.0, 0.0)
		for v in _victimas:
			if fc.toca(Rect2(v - Vector2(5, 16), Vector2(10, 16))):
				_lanzar("oidos", v, 0, SueloRoto.retraso(fc, v, SueloRoto.Tipo.CHILLON_CONO))
		await _paso("CHILLON · Chillido (ondas y oidos en blanco)", 1.8)
		# LOS MUTANTES
		for par in [[CH, &"apagaluces", "APAGALUCES", 70.0], [CH, &"pina", "PIÑA NEGRA", 70.0], [CRIA, &"", "CRIA", 45.0]]:
			p = await _poner(par[0], par[1])
			_anim(_cuerpo_d, "chillido_oscuro", 1)
			_oscuro(p, par[3])
			await _paso("%s · Chillido de oscuridad (r %d)" % [par[2], int(par[3])], 2.4)
			if par[1] != &"pina":
				_anim(_cuerpo_d, "embestida", SpriteLienzo.dir8(cerca - p))
				_lanzar("paletos", cerca, SpriteLienzo.dir8(cerca - p), 0.35)
				await _paso("%s · basico (los paletos)" % par[2], 1.2)
	get_tree().quit(0)
