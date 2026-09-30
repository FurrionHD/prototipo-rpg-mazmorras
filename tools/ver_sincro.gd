# LA SINCRONIA DE LOS GOLPES DE LOS ENEMIGOS (30/09, lo pidio el usuario tras el golem: "que primero realice la animacion
# y en el momento de impacto salga el efecto"). Para cada enemigo y cada ataque (el basico y sus habilidades), su
# animacion TAL COMO LA PONE LA PELEA en el mapa:
#   - el gesto arranca el ADELANTO antes del golpe (CombatFX.IMPACTO_ANIM_MAPA con su fx_anim, o T_ANIM_ADELANTO),
#   - y la animacion se ESTIRA a lo que dura el gesto (adelanto + golpes + cola; CombatTactico._poner_anim_bicho),
#     salvo las que van a su ritmo (_GESTO_A_SU_RITMO).
# Una fila por ataque y direccion (E y S), del arranque del gesto al final, y la columna del IMPACTO con marco rojo:
# ahi es cuando sale el efecto. Si en esa columna el golpe aun no ha llegado (o ya paso), esta descuadrado. CON VENTANA.
#   SINCRO_SALIDA=/carpeta [SINCRO_LISTA=rata,jabali] godot --path . res://tools/ver_sincro.tscn
extends Node2D

const LADO := 240
const COLS := 9
const DIRS := [["E", Vector2(1, 0)], ["S", Vector2(0, 1)]]
const _TACTICO := preload("res://scripts/ui/combat_tactico.gd")

var _cam: Camera2D
var _rotulo: Label


func _ready() -> void:
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 13)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 5)
	capa.add_child(_rotulo)
	call_deferred("_correr")


func _draw() -> void:
	var r: int = 400
	for x in range(-r, r, 16):
		for y in range(-r, r, 16):
			var v: float = 0.17 + 0.015 * float((x / 16 + y / 16) % 2)
			draw_rect(Rect2(x, y, 16, 16), Color(v, v + 0.02, v + 0.035))


# Los ataques de un enemigo: [{nombre, anim (lo que pide), key (la clave del impacto), golpes}].
func _ataques(ed: EnemyData) -> Array:
	var out: Array = [{"nombre": "basico", "pide": String(ed.anim_basico), "key": String(ed.anim_basico), "golpes": 1}]
	for h in ed.habilidades:
		var ab: AbilityData = h
		if ab.dano_mult <= 0.0 and ab.fx_anim == &"":
			continue   # un buff sin gesto propio (el cuerpo no ataca)
		out.append({"nombre": ab.resource_path.get_file().get_basename(), "pide": String(ab.fx_anim),
			"key": String(ab.fx_anim), "golpes": maxi(ab.golpes_max, 1)})
	return out


# La animacion que pone la pelea (CombatTactico.gesto_bicho_en_mapa + _poner_anim_bicho): la primera de lo que pide,
# o 'basico', o su embestida.
func _anim_de(frames: SpriteFrames, pide: String, d8: int) -> StringName:
	var base: String = pide.split(">", false)[0] if pide != "" else "basico"
	# Un nombre que solo dice su tiempo (anim_basico): si no es una animacion suya, la de siempre (como la pelea).
	if not frames.has_animation(StringName("%s_%d" % [base, d8])) and not frames.has_animation(StringName("%s_0" % base)):
		base = "basico"
	for cand in ["%s_%d" % [base, d8], "%s_0" % base, "embestida_%d" % d8]:
		if frames.has_animation(StringName(cand)):
			return StringName(cand)
	return &""


func _correr() -> void:
	var salida: String = OS.get_environment("SINCRO_SALIDA")
	if salida == "":
		salida = "user://sincro"
	DirAccess.make_dir_recursive_absolute(salida)
	var lista: String = OS.get_environment("SINCRO_LISTA")
	var dir := DirAccess.open("res://scenes/actors/enemy")
	var nombres: Array = []
	for f in dir.get_files():
		if f.ends_with(".tres") and (lista == "" or f.get_basename() in lista.split(",")):
			nombres.append(f.get_basename())
	nombres.sort()
	for nom in nombres:
		var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % nom)
		if ed == null or SpritesEnemigo.frames_de(ed, 0.5) == null:
			continue
		if OS.get_environment("SINCRO_TIRAS") != "":
			await _tiras(ed, nom, salida)
		else:
			await _hoja(ed, nom, salida)
	get_tree().quit(0)


func _hoja(ed: EnemyData, nom: String, salida: String) -> void:
	var cuerpo := Node2D.new()
	add_child(cuerpo)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5)
	spr.scale = Vector2.ONE * SpritesEnemigo.escala_de(ed)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cuerpo.add_child(spr)
	spr.play(&"idle_0")
	spr.pause()
	var rd: Rect2 = _TACTICO.rect_dibujo(cuerpo)
	spr.position = -Vector2(rd.get_center().x, rd.position.y + rd.size.y * ed.centro_suelo_real())
	var alto: float = maxf(rd.size.y, rd.size.x)
	var z: float = float(LADO) / (alto * 1.35)
	_cam.zoom = Vector2(z, z)
	_cam.global_position = Vector2(0.0, -rd.size.y * 0.45)
	var ataques: Array = _ataques(ed)
	var filas: Array = []
	for at in ataques:
		for d in DIRS:
			filas.append([at, d])
	var hoja := Image.create(LADO * COLS, LADO * filas.size(), false, Image.FORMAT_RGBA8)
	var informe: Array = []
	for fi in filas.size():
		var at: Dictionary = filas[fi][0]
		var dvec: Vector2 = (filas[fi][1][1] as Vector2).normalized()
		var d8: int = SpriteLienzo.dir8(dvec)
		var anim: StringName = _anim_de(spr.sprite_frames, String(at["pide"]), d8)
		if anim == &"":
			continue
		var n: int = spr.sprite_frames.get_frame_count(anim)
		var fps: float = maxf(spr.sprite_frames.get_animation_speed(anim), 0.1)
		var natural: float = float(n) / fps
		var adel: float = float(CombatFX.IMPACTO_ANIM_MAPA.get(String(at["key"]), CombatFX.T_ANIM_ADELANTO))
		var span: float = CombatFX.T_ENCADENADO * float(int(at["golpes"]) - 1)
		var base: String = String(anim).rsplit("_", true, 1)[0]
		var dur: float = adel + span + CombatFX.T_ANIM_COLA
		var ritmo: float = 1.0 if base in _TACTICO._GESTO_A_SU_RITMO else natural / dur
		# El marco que se ve en el instante del impacto (t = 0 es el golpe; el gesto arranco en -adel).
		var marco_imp: int = clampi(int(floor(adel * ritmo * fps)), 0, n - 1)
		# EL MARCO DEL GOLPE, medido: mirando al E, el marco en el que el dibujo llega MAS LEJOS hacia delante (en un golpe,
		# ahi toca). Y el adelanto que haria falta para que en el golpe se vea ese marco (a mitad de el).
		var k_max: int = -1
		var x_max: int = -1
		if fi % 2 == 0:
			for k in n:
				var tex: Texture2D = spr.sprite_frames.get_frame_texture(anim, k)
				if tex == null:
					continue
				var img: Image = tex.get_image()
				var xm: int = -1
				for x in range(img.get_width() - 1, -1, -1):
					var hay: bool = false
					for y in img.get_height():
						if img.get_pixel(x, y).a > 0.5:
							hay = true
							break
					if hay:
						xm = x
						break
				if xm > x_max:
					x_max = xm
					k_max = k
			var f_obj: float = (float(k_max) + 0.5) / float(n)
			var adel_obj: float = (span + CombatFX.T_ANIM_COLA) * f_obj / maxf(1.0 - f_obj, 0.05)
			informe.append("MEDIDO %s/%s: golpe (mas lejos) en el marco %d de %d; ahora se ve el %d; adelanto justo %.2f (ahora %.2f)" % [
				nom, at["nombre"], k_max + 1, n, marco_imp + 1, adel_obj, adel])
		if fi % 2 == 0:
			informe.append("%s/%s: anim '%s' %d marcos a %.0f fps, adelanto %.2f, dura %.2f -> en el golpe se ve el marco %d de %d" % [
				nom, at["nombre"], base, n, fps, adel, dur, marco_imp + 1, n])
		for c in COLS:
			# De -adel a +cola en COLS columnas; una de ellas, exactamente el golpe.
			var t: float = lerpf(-adel, span + CombatFX.T_ANIM_COLA, float(c) / float(COLS - 1))
			var es_imp: bool = false
			var c_imp: int = int(round(adel / (dur) * float(COLS - 1)))
			if c == c_imp:
				t = 0.0
				es_imp = true
			spr.animation = anim
			spr.frame = clampi(int(floor((t + adel) * ritmo * fps)), 0, n - 1)
			await _viñeta(hoja, c, fi, "%s · %s · %s · %s%.2f s (marco %d/%d)" % [ed.enemy_name, at["nombre"], filas[fi][1][0],
				"IMPACTO " if es_imp else "", t, spr.frame + 1, n], es_imp)
	cuerpo.queue_free()
	await get_tree().process_frame
	var ruta: String = "%s/%s.png" % [salida, nom]
	hoja.save_png(ruta)
	print("[hoja] ", ruta)
	for l in informe:
		print("   ", l)


func _viñeta(hoja: Image, col: int, fila: int, texto: String, marco: bool) -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_rotulo.text = texto
	_rotulo.position = tam * 0.5 - Vector2(LADO, LADO) * 0.5 + Vector2(6, 3)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var cen: Vector2i = img.get_size() / 2
	hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)), Vector2i(col * LADO, fila * LADO))
	if marco:
		var rojo := Color(1.0, 0.2, 0.2)
		for i in 4:
			for x in LADO:
				hoja.set_pixel(col * LADO + x, fila * LADO + i, rojo)
				hoja.set_pixel(col * LADO + x, fila * LADO + LADO - 1 - i, rojo)
			for y in LADO:
				hoja.set_pixel(col * LADO + i, fila * LADO + y, rojo)
				hoja.set_pixel(col * LADO + LADO - 1 - i, fila * LADO + y, rojo)


# LAS TIRAS (SINCRO_TIRAS=1): cada ataque, mirando al SE, con TODOS sus marcos numerados, para ver a ojo en cual toca.
func _tiras(ed: EnemyData, nom: String, salida: String) -> void:
	var cuerpo := Node2D.new()
	add_child(cuerpo)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5)
	spr.scale = Vector2.ONE * SpritesEnemigo.escala_de(ed)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cuerpo.add_child(spr)
	spr.play(&"idle_0")
	spr.pause()
	var rd: Rect2 = _TACTICO.rect_dibujo(cuerpo)
	spr.position = -Vector2(rd.get_center().x, rd.position.y + rd.size.y * ed.centro_suelo_real())
	var z: float = float(LADO) / (maxf(rd.size.y, rd.size.x) * 1.5)
	_cam.zoom = Vector2(z, z)
	_cam.global_position = rd.get_center() + spr.position
	var ataques: Array = _ataques(ed)
	var d8: int = SpriteLienzo.dir8(Vector2(1, 0.6))
	var max_n: int = 1
	for at in ataques:
		var an: StringName = _anim_de(spr.sprite_frames, String(at["pide"]), d8)
		if an != &"":
			max_n = maxi(max_n, spr.sprite_frames.get_frame_count(an))
	var hoja := Image.create(LADO * max_n, LADO * ataques.size(), false, Image.FORMAT_RGBA8)
	for fi in ataques.size():
		var at: Dictionary = ataques[fi]
		var anim: StringName = _anim_de(spr.sprite_frames, String(at["pide"]), d8)
		if anim == &"":
			continue
		var n: int = spr.sprite_frames.get_frame_count(anim)
		var adel: float = float(CombatFX.IMPACTO_ANIM_MAPA.get(String(at["key"]), CombatFX.T_ANIM_ADELANTO))
		var span: float = CombatFX.T_ENCADENADO * float(int(at["golpes"]) - 1)
		var base: String = String(anim).rsplit("_", true, 1)[0]
		var dur: float = adel + span + CombatFX.T_ANIM_COLA
		var fps: float = maxf(spr.sprite_frames.get_animation_speed(anim), 0.1)
		var ritmo: float = 1.0 if base in _TACTICO._GESTO_A_SU_RITMO else (float(n) / fps) / dur
		var marco_imp: int = clampi(int(floor(adel * ritmo * fps)), 0, n - 1)
		for k in n:
			spr.animation = anim
			spr.frame = k
			await _viñeta(hoja, k, fi, "%s %s '%s' %d/%d%s" % [nom, at["nombre"], base, k + 1, n,
				"  <- AHORA" if k == marco_imp else ""], k == marco_imp)
	cuerpo.queue_free()
	await get_tree().process_frame
	var ruta: String = "%s/tiras_%s.png" % [salida, nom]
	hoja.save_png(ruta)
	print("[hoja] ", ruta)
