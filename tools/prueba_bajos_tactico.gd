# LOS ENEMIGOS DE LOS PISOS BAJOS EN EL TACTICO (28/09): rata, rey rata, jabali y trent. Sin ventana:
#   godot --headless --path . res://tools/prueba_bajos_tactico.tscn
# Para cada uno pone a dos de los tuyos delante (a su alcance) y a un tercero lejos, y dice a quien pilla
# cada habilidad. Y la Embestida del jabali: arrolla y APARTA a los lados. Acaba con BIEN/MAL.
extends Node

const ENEMIGOS := ["rata", "rey_rata", "jabali", "trent"]
var _mal: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	# Muy separados: cada uno se prueba en su sitio, sin que los otros estorben.
	for i in ENEMIGOS.size():
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % ENEMIGOS[i],
			jug.global_position + Vector2(-150 + 100 * i, 60), {})
	await _esperar(25)
	if not Game.start_combat(get_tree().get_nodes_in_group("enemy"), false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	var al: Array = combat._aliados
	for a in al:
		a.max_hp = 99999.0
		a.current_hp = 99999.0
	var por_nombre: Dictionary = {}
	for e in combat._enemies:
		por_nombre[String(e.nombre)] = e
	print("enemigos: %s" % str(por_nombre.keys()))

	# Lo que se espera de cada uno: [habilidad, a cuantos de los dos de delante, o -1 = no se mira]
	var casos := {
		"rata": [["rata_frenesi_dentelladas", 2]],
		"rey_rata": [["rey_rata_dentellada_real", 2], ["rey_rata_chillido", 2], ["rey_rata_yugular", 1]],
		"jabali": [["jabali_embestida", 2], ["jabali_pisoton", 2], ["jabali_cornada", -1]],
		"trent": [["trent_savia_corrosiva", -1], ["trent_ramazo", 2], ["trent_raices_atenazantes", 2]],
	}
	for e in combat._enemies:
		var ed: EnemyData = t.cuerpo_de(e).get("data") if t.cuerpo_de(e) != null else null
		if ed == null:
			continue
		var clave: String = String(ed.resource_path).get_file().get_basename()
		if not casos.has(clave):
			continue
		print("--- %s (alcance %.0f) ---" % [clave, t.alcance_de(e)])
		# Dos delante, a su alcance (uno un poco arriba y otro abajo), el tercero lejos; el resto, mas lejos.
		var pe: Vector2 = t.pies_de(e)
		var hueco: float = t.radio_pisa(e) + t.alcance_de(e) * 0.7
		var sitios: Array = [pe + Vector2(hueco, -8), pe + Vector2(hueco + 2, 10), pe + Vector2(-190, 0)]
		for i in al.size():
			var s: Vector2 = sitios[i] if i < sitios.size() else pe + Vector2(-200 - 40 * i, 70)
			t._colocar(al[i], t.cuerpo_de(al[i]), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
		await _esperar(2)
		for caso in casos[clave]:
			var ab: AbilityData = load("res://resources/abilities/%s.tres" % caso[0])
			var plan: Dictionary = t.mejor_apunte(e, ab, al[0])
			var f = t.forma_de(ab, e, plan["punto"])
			var rep: Array = t._reparto_en(ab, e, f)
			var quienes: Array = []
			for d in rep:
				quienes.append("%s x%.2f" % [d["c"].nombre, float(d["escala"])])
			print("  %s: %s, pilla %d [%s]" % [caso[0], str(f), rep.size(), ", ".join(quienes)])
			if int(caso[1]) >= 0:
				_ver(rep.size() == int(caso[1]), "%s pilla a %d (y no al de lejos)" % [caso[0], int(caso[1])])

		# LA EMBESTIDA: los aparta a los lados de su linea.
		if clave == "jabali":
			var emb: AbilityData = load("res://resources/abilities/jabali_embestida.tres")
			var antes: Array = [t.pos_de(al[0]), t.pos_de(al[1])]
			combat.enemigos._enemy_use_ability(e, emb, al[0])
			combat._fx.arrancar_cola()
			await get_tree().create_timer(3.5, true, false, true).timeout
			var f_emb = t.ultima_forma_enemigo
			var perp := Vector2(-f_emb.dir.y, f_emb.dir.x)
			for k in 2:
				var mov: Vector2 = t.pos_de(al[k]) - Vector2(antes[k])
				# Lo lejos que esta del eje de la embestida, antes y despues: tiene que haberse alejado.
				var eje_antes: float = absf((Vector2(antes[k]) - f_emb.origen).dot(perp))
				var eje_despues: float = absf((t.pos_de(al[k]) - f_emb.origen).dot(perp))
				print("  %s: se movio %s; del eje %.1f -> %.1f" % [al[k].nombre, str(mov.round()), eje_antes, eje_despues])
				_ver(eje_despues > eje_antes + 10.0 and absf(mov.dot(f_emb.dir)) < 3.0,
					"la Embestida aparta a %s hacia SU lado (de lado, no hacia delante)" % al[k].nombre)

	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
