# EL MICONIDO Y SUS MUTANTES CON SUS EFECTOS EN PIXEL, EN VIVO (10/11/2026, el jefe tiene que verlos en el juego): el suelo
# de verdad de la mazmorra, los tres cuerpos con su hoja horneada y un objetivo; en bucle, cada ataque con LAS PIEZAS DEL JUEGO
# (EfectoPixel con las hojas de assets/sprites/efectos/miconido, PiezaPixel para la nube y el atado, CintaPixel para el
# cordon). Los pies, como los cuenta la pelea (rect_dibujo + centro_suelo de su ficha). Con ventana; se cierra sola.
#   godot --path . res://tools/ver_miconido_pixel.tscn
extends Node2D

const ZOOM := 3.0
const PISO := 8
const TACTICO := preload("res://scripts/ui/combat_tactico.gd")

var _rotulo: Label = null
var _cuerpos: Dictionary = {}   # "normal" | "campana" | "florecido" -> {nodo, spr, pies}
var _victima: Node2D = null
var _pies_v: Vector2 = Vector2(60, 40)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.06))
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position = Vector2(20, 0)
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


func _cuerpo(mut: StringName) -> Dictionary:
	var ed: EnemyData = load("res://scenes/actors/enemy/miconido.tres")
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


# Los pies como los cuenta la pelea: el centro de su dibujo y la altura de suelo de su ficha.
func _pies(d: Dictionary) -> Vector2:
	var r: Rect2 = TACTICO.rect_dibujo(d["nodo"])
	var ed: EnemyData = d["ed"]
	# (10/11: rect_dibujo ya va en MUNDO; antes se le sumaba otra vez la posicion del nodo y los pies salian movidos)
	return Vector2(r.get_center().x, r.position.y + r.size.y * ed.centro_suelo_real())


func _objetivo() -> void:
	_victima = Node2D.new()
	add_child(_victima)
	var cuerpo := ColorRect.new()
	cuerpo.color = Color(0.23, 0.38, 0.7)
	cuerpo.size = Vector2(10, 16)
	cuerpo.position = _pies_v - Vector2(5, 16)
	_victima.add_child(cuerpo)
	var cara := ColorRect.new()
	cara.color = Color(0.87, 0.71, 0.59)
	cara.size = Vector2(7, 6)
	cara.position = _pies_v - Vector2(3.5, 22)
	_victima.add_child(cara)


func _anim(d: Dictionary, base: String) -> void:
	var spr: AnimatedSprite2D = d["spr"]
	var n: StringName = StringName("%s_1" % base)
	SpriteLienzo.asegurar_anim(spr.sprite_frames, n)
	if spr.sprite_frames.has_animation(n):
		spr.play(n)


func _lanzar(nombre: String, pos: Vector2, dir: int = 0, sigue: Node2D = null, espera: float = 0.0, dura: float = -1.0) -> void:
	EfectoPixel.lanzar(self, "miconido", nombre, pos, dir, sigue, espera, dura)


# EL DESTELLO COMO EN LA PELEA: su cono (la ficha) desde el frente de sus pies hacia el objetivo, por SueloRoto (FocoAire).
func _foco(nodo: Node2D, p: Vector2) -> void:
	var ab: AbilityData = load("res://resources/abilities/miconido_destello.tres")
	var d: Vector2 = (_pies_v - p).normalized()
	var o: Vector2 = p + d * TACTICO.frente_dibujo(nodo, p, d) * TACTICO.FRENTE_METIDO
	var f := CombatFormas.cono(o, d, ab.forma_radio, ab.forma_apertura)
	# (10/11 tarde) en CIRCULO alrededor de sus pies: solo los haces; al objetivo le llega si le pilla el circulo
	if ab.forma == CombatFormas.Tipo.CIRCULO:
		f = CombatFormas.circulo(p, ab.forma_radio)
		SueloRoto.lanzar(self, f, ab.suelo_roto, 1, 0.0, 0.0)
		var caja := Rect2(_pies_v - Vector2(5, 16), Vector2(10, 16))
		if f.toca(caja):
			_lanzar("destello_golpe", _pies_v, 0, null, SueloRoto.retraso_caja(f, caja, ab.suelo_roto))
		return
	SueloRoto.lanzar(self, f, ab.suelo_roto, 1, 0.0, 0.0)
	_lanzar("destello_golpe", _pies_v, 0, null, SueloRoto.retraso_caja(f, Rect2(_pies_v - Vector2(5, 16), Vector2(10, 16)), ab.suelo_roto))


func _paso(texto: String, segundos: float) -> void:
	_rotulo.text = texto
	# (VER_CAPTURA=<carpeta>: fotos de cada paso cada 0,15 s, para mirarlas sin ventana delante)
	var carpeta: String = OS.get_environment("VER_CAPTURA")
	var t: float = 0.0
	var siguiente: float = 0.0
	while t < segundos:
		await get_tree().process_frame
		t += get_process_delta_time()
		if carpeta != "" and texto != "" and t >= siguiente:
			siguiente += 0.15
			get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [carpeta, texto.validate_filename().replace(" ", "_"), int(t / 0.15)])


func _bucle() -> void:
	_objetivo()
	var dir: int = 1   # sureste: hacia el objetivo
	for vuelta in 2:
		for cual in ["normal", "campana", "florecido"]:
			for k in _cuerpos.keys():
				(_cuerpos[k]["nodo"] as Node2D).queue_free()
			_cuerpos.clear()
			var d: Dictionary = _cuerpo(&"" if cual == "normal" else StringName(cual))
			_cuerpos[cual] = d
			(d["nodo"] as Node2D).position = Vector2.ZERO
			await get_tree().process_frame
			var p: Vector2 = _pies(d)
			# que sus pies queden a 70 px del objetivo, hacia el noroeste
			(d["nodo"] as Node2D).position += (_pies_v - Vector2(36, 30)) - p
			await get_tree().process_frame
			p = _pies(d)
			var nodo: Node2D = d["nodo"]
			match cual:
				"normal":
					_anim(d, "embestida")
					_lanzar("porrazo", _pies_v, 0, null, 0.35)
					await _paso("MICONIDO · porrazo (basico)", 1.6)
					_anim(d, "esporas")
					var f := CombatFormas.circulo(_pies_v + Vector2(0, -6), 40.0)
					var nube = SlimeAire.nube_pixel(self, f, Color8(176, 148, 104), 0.3)
					_lanzar("tos_espora", _pies_v, 0, null, 0.4)
					await _paso("MICONIDO · Bocanada: tos y la nube que se queda", 2.6)
					if nube != null:
						nube.secar()
					_anim(d, "micelio")
					var mano: Vector2 = p + Vector2(10, -34)
					var c = CintaPixel.lanzar(self, mano, _pies_v - Vector2(0, 4), PackedColorArray([Color8(40, 32, 26),
						Color8(160, 146, 120), Color8(244, 238, 222)]), 0.2, 0.35, 0.25, 0.25)
					if c != null:
						c.forma(1, 0.0, 1.6, 0.45, 2.0, 3.0)
					var atado = PiezaPixel.crear(self, "miconido", "atado_sale", "atado_dura", "atado_vete", _pies_v, 0, PackedColorArray(), 0.5)
					await _paso("MICONIDO · Latigazo de micelio y el atado", 2.4)
					if atado != null:
						atado.secar()
					await _paso("", 0.4)
				"campana":
					_anim(d, "embestida")
					_lanzar("filamentos", EfectoPixel.centro_sprite(nodo, p), dir, nodo, 0.0, 0.9)
					_lanzar("filamentos_golpe", _pies_v, 0, null, 0.45)
					await _paso("CAMPANA · Latigazo de filamentos (y el velo de Ciego)", 1.8)
					_anim(d, "esporas")
					var f2 := CombatFormas.circulo(_pies_v + Vector2(0, -6), 40.0)
					var nube2 = SlimeAire.nube_pixel(self, f2, Color8(120, 232, 214), 0.3)
					_lanzar("tos_luz", _pies_v, 0, null, 0.4)
					await _paso("CAMPANA · Esporas luminosas", 2.4)
					if nube2 != null:
						nube2.secar()
					_anim(d, "destello_carga")
					var carga = EfectoPixel.lanzar(self, "miconido", "campana_destello_carga", EfectoPixel.centro_sprite(nodo, p), SpriteLienzo.dir8(_pies_v - EfectoPixel.centro_sprite(nodo, p)), nodo)
					await _paso("CAMPANA · Destello: la carga", 1.6)
					if carga != null:
						carga.queue_free()
					_anim(d, "destello")
					_foco(nodo, p)
					await _paso("CAMPANA · Destello: la luz alrededor", 1.6)
					_anim(d, "idle")
					_lanzar("atrae", EfectoPixel.centro_sprite(nodo, p), 0, nodo)
					await _paso("CAMPANA · Luz que atrae", 1.6)
				"florecido":
					_anim(d, "embestida")
					_lanzar("tajo", EfectoPixel.centro_sprite(nodo, p), dir, nodo, 0.0, 1.0)
					_lanzar("tajo_golpe", _pies_v, 0, null, 0.55)
					await _paso("FLORECIDO · Tajo oxidado", 1.8)
					_anim(d, "estocada")
					_lanzar("estocada", EfectoPixel.centro_sprite(nodo, p), dir, nodo, 0.0, 0.62)
					_lanzar("estocada_golpe", _pies_v, dir, null, 0.3)
					await _paso("FLORECIDO · Estocada del muerto", 1.6)
					_anim(d, "esporas")
					var f3 := CombatFormas.circulo(_pies_v + Vector2(0, -6), 40.0)
					var nube3 = SlimeAire.nube_pixel(self, f3, Color8(236, 150, 60), 0.3)
					_lanzar("tos_seta", _pies_v, 0, null, 0.4)
					await _paso("FLORECIDO · Esporas de infeccion", 2.4)
					if nube3 != null:
						nube3.secar()
					_anim(d, "destello")
					_foco(nodo, p)
					await _paso("FLORECIDO · Destello", 1.4)
	get_tree().quit(0)
