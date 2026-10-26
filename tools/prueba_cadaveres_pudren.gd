# LOS CADAVERES SE PUDREN DE VERDAD (12/10, playtest 11/10: "los cadaveres no se descomponen; sigue habiendo
# cadaveres de las pruebas de hace 2 dias"). En multi el tiempo de pudrirse no viajaba en las fotos del piso y cada
# traspaso o congelado les daba otros 5 minutos. Sin red:
#   1) la foto de red lleva lo que le queda y la hora; al restaurarla se descuenta el tiempo REAL que ha pasado
#      (un piso congelado 200 s con un cadaver al que le quedaban 100 -> vuelve ya podrido);
#   2) el que aun no ha cumplido conserva lo que le queda (no vuelve a los 5 minutos);
#   3) el tinte: recien caido se ve normal, a punto de irse rancio;
#   4) en un piso de verdad, un cadaver con el sello cumplido se desvanece en el barrido y su cristal queda en el
#      suelo, y uno a medias se ve tintado.
#   godot --headless --path . res://tools/prueba_cadaveres_pudren.tscn
extends Node

var mi_sala = null   # su sala: tools/prueba_sala_propia.gd

var _mal: int = 0
const _TINTE = preload("res://scripts/fx/tinte_podrido.gd")


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _correr() -> void:
	var slime: EnemyData = load("res://scenes/actors/enemy/slime.tres")

	print("1) la foto de red y un piso congelado 200 s")
	Game.tiempo_mazmorra = 1000.0
	var mem := {"enemigos": [
		{"data": slime, "pos": Vector2.ZERO, "t": 0.5, "zona": -1, "muerto": true, "pudre": 1100.0},   # le quedan 100
		{"data": slime, "pos": Vector2.ZERO, "t": 0.5, "zona": -1, "muerto": true, "pudre": 1290.0},   # le quedan 290
		{"data": slime, "pos": Vector2.ZERO, "t": 0.5, "zona": -1, "muerto": false, "pudre": -1.0},
	]}
	var red: Dictionary = Net.pisos._mem_a_red(mem)
	var e0: Dictionary = red["enemigos"][0]
	_ver(is_equal_approx(float(e0["pudre_q"]), 100.0), "viaja lo que le queda (%.1f s)" % float(e0["pudre_q"]))
	_ver(float(red["enemigos"][2]["pudre_q"]) < 0.0, "un vivo no lleva tiempo de pudrirse")
	# Congelado 200 s de reloj de verdad (se adelanta la hora de la foto) y en OTRA maquina con otro reloj de expedicion.
	for d in red["enemigos"]:
		d["pudre_reloj"] = float(d["pudre_reloj"]) - 200.0
	Game.tiempo_mazmorra = 50.0
	var vuelta: Dictionary = Net.pisos._mem_de_red(red)
	var p0: float = float(vuelta["enemigos"][0]["pudre"])
	var p1: float = float(vuelta["enemigos"][1]["pudre"])
	_ver(p0 <= Game.tiempo_mazmorra, "al que le quedaban 100 vuelve ya podrido (sello %.1f, reloj %.1f)" % [p0, Game.tiempo_mazmorra])
	print("2) el que no ha cumplido")
	_ver(absf((p1 - Game.tiempo_mazmorra) - 90.0) < 2.0, "al de 290 le quedan ~90 (%.1f), no 300" % (p1 - Game.tiempo_mazmorra))
	_ver(float(vuelta["enemigos"][2]["pudre"]) < 0.0, "el vivo sigue sin sello")
	var vieja: Dictionary = Net.pisos._mem_de_red({"enemigos": [{"ruta": slime.resource_path, "pos": Vector2.ZERO,
		"t": 0.5, "zona": -1, "muerto": true}]})
	_ver(float(vieja["enemigos"][0]["pudre"]) < 0.0, "una foto vieja (sin el dato) no se inventa nada")

	print("3) el tinte")
	_ver(_TINTE.tinte(0.0).is_equal_approx(Color.WHITE), "recien caido: sin tinte")
	var fin: Color = _TINTE.tinte(1.0)
	_ver(fin.g > fin.b + 0.1 and fin.r < 0.7, "a punto de irse: rancio (%s)" % str(fin))

	print("4) en un piso de verdad")
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala, con el piso montado como lo monta ella.
	mi_sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(mi_sala)
	if not await mi_sala.arrancar("prueba_cadaveres_pudren", 1, 424242, false):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	await _esperar(30)
	var bichos: Array = get_tree().get_nodes_in_group("enemy")
	if bichos.size() < 2:
		print("MAL: hacen falta dos enemigos en el piso")
		get_tree().quit(1)
		return
	var viejo: Node2D = bichos[0]
	var medio: Node2D = bichos[1]
	viejo.sello_pudre = Game.tiempo_mazmorra + 0.2   # se le pasa en el siguiente barrido
	viejo.morir()
	medio.sello_pudre = Game.tiempo_mazmorra + 150.0   # a medio pudrir
	medio.morir()
	var donde: Vector2 = viejo.global_position
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(viejo) and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	_ver(not is_instance_valid(viejo) or viejo.is_queued_for_deletion(), "el cadaver cumplido se desvanece")
	var cristal_cerca := false
	for n in get_tree().get_nodes_in_group("pickup"):
		if n is Node2D and (n as Node2D).global_position.distance_to(donde) < 40.0:
			cristal_cerca = true
	_ver(cristal_cerca, "y deja su cristal en el suelo")
	var tinte_medio: Color = medio._sprite.self_modulate
	_ver(not tinte_medio.is_equal_approx(Color.WHITE), "el que va a medias ya se ve tintado (%s)" % str(tinte_medio))

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
