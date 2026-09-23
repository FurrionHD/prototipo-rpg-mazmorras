extends SceneTree

# Compara, bicho a bicho, lo que mide su COLISION (lo que yo medía) con lo que mide su SPRITE (lo
# que se ve). Si la teoría es buena, en los bichos grandes el sprite debe ser bastante mayor.
func _init() -> void:
	var nombres := ["slime", "rey_slime", "trent", "rata", "aberracion", "jabali"]
	print("%-14s %-16s %-16s" % ["bicho", "colision", "sprite (lo que se ve)"])
	for n in nombres:
		var ruta := "res://scenes/actors/enemy/%s.tres" % n
		if not ResourceLoader.exists(ruta):
			print("%-14s (no existe)" % n)
			continue
		var ed: EnemyData = load(ruta)
		var col: Vector2 = SpritesEnemigo.tam_cuerpo(ed)
		var esc: float = SpritesEnemigo.escala_de(ed)
		if col == Vector2.ZERO:
			col = Vector2(32, 32) * maxf(0.1, ed.escala_visual)
		var frames: SpriteFrames = SpritesEnemigo.frames_de(ed, 1.0)
		var spr := Vector2.ZERO
		if frames != null:
			var anims := frames.get_animation_names()
			if anims.size() > 0 and frames.get_frame_count(anims[0]) > 0:
				var tex: Texture2D = frames.get_frame_texture(anims[0], 0)
				if tex != null:
					spr = Vector2(tex.get_size()) * esc
		print("%-14s %-16s %-16s  sprite/colision = %.2fx ancho, %.2fx alto" % [
			n, str(col.round()), str(spr.round()),
			spr.x / maxf(col.x, 1.0), spr.y / maxf(col.y, 1.0)])
	quit()
