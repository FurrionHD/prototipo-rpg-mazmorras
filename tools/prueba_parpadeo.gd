# EL PARPADEO DE LOS SLIMES (05/10): que el normal y el mutante lleven su capa de parpados y que parpadeen a ratos, no
# al ritmo de la animacion. Sin ventana:
#   godot --headless --path . res://tools/prueba_parpadeo.tscn
extends Node

var _mal: int = 0


func _ready() -> void:
	call_deferred("_correr")


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/slime.tres")
	for mut in [false, true]:
		print("slime %s" % ("MUTANTE" if mut else "normal"))
		var pf: SpriteFrames = SpritesEnemigo.parpados_de(ed, 0.5, mut)
		_ver(pf != null, "tiene hoja de parpados")
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, mut)
		_ver(sf != null and sf.has_animation(&"idle_0"), "tiene sprite")
		if pf == null or sf == null:
			continue
		_ver(pf.has_animation(&"idle_0") and pf.has_animation(&"walk_3"), "los parpados tienen idle y walk")
		var tex: Texture2D = pf.get_frame_texture(&"idle_0", 0)
		var tex_s: Texture2D = sf.get_frame_texture(&"idle_0", 0)
		_ver(tex != null and tex.get_size() == tex_s.get_size(), "mismo tamaño de fotograma que el sprite (%s)" % [tex.get_size()])
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = sf
		add_child(spr)
		spr.play(&"idle_0")
		Parpadeo.poner(spr, pf)
		var p: Parpadeo = spr.get_node_or_null(Parpadeo.NOMBRE)
		_ver(p != null, "lleva la capa")
		var veces: int = 0
		var antes: bool = false
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 9000:
			await get_tree().process_frame
			if p.visible and not antes:
				veces += 1
				_ver(p.animation == spr.animation and p.frame == spr.frame, "cerrado en el mismo fotograma que el sprite")
			antes = p.visible
		_ver(veces >= 1 and veces <= 5, "parpadea a ratos en 9 s (%d veces)" % veces)
		spr.play(&"muerte_0")
		await get_tree().create_timer(0.1).timeout
		p._espera = 0.0
		await get_tree().process_frame
		_ver(not p.visible, "muerto no parpadea")
		spr.queue_free()
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
