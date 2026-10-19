# ============================================================
#  PRUEBA: EL MUÑECO SIGUE ANIMANDOSE (optimizacion 1E, 19/10/2026)
#  MunecoJugador._process solo reescribe sus capas cuando cambia el fotograma de la animacion. Comprueba que:
#   1) andando, el fotograma avanza (pasa por varios) y TODAS las capas van en el mismo;
#   2) una animacion que no se repite acaba en su ultimo fotograma y avisa 'finished' UNA vez;
#   3) volver a montarlo (otra ropa) con la misma animacion deja las capas en el fotograma de ahora.
#    godot --headless --path . res://tools/prueba_muneco_anima.tscn
# ============================================================
extends Node

var _mal: int = 0


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	var mu := MunecoJugador.new()
	add_child(mu)
	mu.montar(Game.lider())
	_ver(mu._capas.size() > 3, "el muñeco tiene capas (%d)" % mu._capas.size())

	# 1) ANDANDO
	var andar: String = PoseJugador.animacion(Vector2.DOWN, 1, true, false, false)
	mu.animar(andar)
	var vistos: Dictionary = {}
	var juntas: bool = true
	for k in 90:
		await get_tree().process_frame
		var f0: int = (mu._capas[0]["nodo"] as AnimatedSprite2D).frame
		vistos[f0] = true
		for c in mu._capas:
			var s: AnimatedSprite2D = c["nodo"]
			if s.visible and s.frame != f0:
				juntas = false
	_ver(vistos.size() >= 3, "andando (%s) pasa por varios fotogramas (%d)" % [andar, vistos.size()])
	_ver(juntas, "todas las capas visibles van siempre en el mismo fotograma")

	# 2) UNA QUE NO SE REPITE
	var avisos: Array = [0]
	mu.finished.connect(func() -> void: avisos[0] += 1)
	var golpe: String = ""
	for c in ["golpe_2m_0", "tajo_espada_0", "estocada_larga_0", "floritura_0"]:
		if SpriteLienzo.asegurar_anim((mu._capas[0]["nodo"] as AnimatedSprite2D).sprite_frames, c):
			golpe = c
			break
	_ver(golpe != "", "hay un golpe para probar (%s)" % golpe)
	if golpe != "":
		mu.animar(golpe)
		var ultimo: int = mu._marcos - 1
		for k in 240:
			await get_tree().process_frame
			if avisos[0] > 0:
				break
		for k in 20:
			await get_tree().process_frame
		_ver(avisos[0] == 1, "acaba y avisa 'finished' una sola vez (%d)" % avisos[0])
		_ver((mu._capas[0]["nodo"] as AnimatedSprite2D).frame == ultimo, "y se queda en su ultimo fotograma (%d)" % ultimo)

	# 3) REMONTAR CON LA MISMA ANIMACION
	mu.animar(andar)
	for k in 10:
		await get_tree().process_frame
	mu.montar(Game.lider())
	await get_tree().process_frame
	await get_tree().process_frame
	var f_ahora: int = mu._marco_actual()
	var bien: bool = true
	for c in mu._capas:
		var s: AnimatedSprite2D = c["nodo"]
		if s.visible and s.frame != f_ahora:
			bien = false
	_ver(bien, "tras volver a montarlo, las capas estan en el fotograma de ahora (%d)" % f_ahora)

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
