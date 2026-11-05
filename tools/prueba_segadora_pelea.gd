# LAS PASIVAS DE LOS MUTANTES DE LA SEGADORA EN UNA PELEA DE VERDAD (05/11), en la arena y sin ventana:
#   - ZONA DE SIEGA (la de sierra): andar por dentro de su alcance te cuesta un tajo, UNA vez por turno; por fuera, nada.
#   - CORTES DE VIENTO (el Vendaval rojo): tras su golpe, el corte le llega a quien lo encaja y a quien este detras.
#   - VUELO CORTO (el Vendaval rojo): al encajar cuerpo a cuerpo salta atras y suelta un corte.
#   - EL VENDAVAL DE CORTES: el reparto cobra una por linea del abanico.
#   godot --headless --path . res://tools/prueba_segadora_pelea.tscn
extends Node

var sala = null
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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _log(combat: Node) -> String:
	return "\n".join(combat.log_entero().map(func(l): return str(l)))


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_segadora_pelea", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/segadora.tres", Vector2(140, 0), {"mutacion": "sierra"})
	sala.poner("res://scenes/actors/enemy/segadora.tres", Vector2(0, 170), {"mutacion": "vendaval"})
	await _esperar(20)
	if (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false)) == null:
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(5)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	var t = combat.turno_mapa
	var sierra: Combatant = null
	var vendaval: Combatant = null
	for e in combat._enemies:
		if e.zona_siega > 0.0:
			sierra = e
		if e.cortes_viento > 0.0:
			vendaval = e
	_ver(sierra != null and vendaval != null, "en la pelea estan la de sierra y el vendaval")
	if sierra == null or vendaval == null:
		get_tree().quit(1)
		return
	var yo: Combatant = combat._aliados[0]
	yo.max_hp = 100000.0
	yo.current_hp = 100000.0

	print("1) ZONA DE SIEGA")
	var ps: Vector2 = t.pies_de(sierra)
	var lejos_a: Vector2 = ps + Vector2(-600, -400)
	var lejos_b: Vector2 = ps + Vector2(-600, 400)
	t._segados.clear()
	t._zona_siega(yo, lejos_a, lejos_b)
	_ver(not t._segados.has(yo), "andando lejos de ella, nada")
	var antes_log: int = combat.log_entero().size()
	t._zona_siega(yo, ps + Vector2(-300, 0), ps + Vector2(-20, 0))
	_ver(t._segados.get(yo, {}).has(sierra), "metiendose en su alcance, le cae el tajo")
	_ver(_log(combat).contains("Zona de siega"), "y lo dice el registro")
	var tras_uno: int = combat.log_entero().size()
	t._zona_siega(yo, ps + Vector2(-20, 0), ps + Vector2(-20, 30))
	_ver(combat.log_entero().size() == tras_uno, "moviendose otra vez dentro en el mismo turno, no repite")
	t.charcos_empezar_turno(yo)
	_ver(not t._segados.has(yo), "turno nuevo: puede volver a cortarle")
	print("   (log %d -> %d lineas)" % [antes_log, tras_uno])

	print("2) CORTES DE VIENTO")
	var hp0: float = yo.current_hp
	combat.enemigos.cortes_tras_golpe(vendaval, yo)
	_ver(_log(combat).contains("corte de viento"), "el corte sale tras su golpe")
	var d1: float = hp0 - yo.current_hp
	print("   corte: %.2f de daño (o esquivado)" % d1)
	var ocultos: Array = t.en_linea_detras(vendaval, yo, 70.0, 18.0)
	_ver(not ocultos.has(yo), "la linea de detras no se cuenta a si misma")

	print("3) VUELO CORTO")
	vendaval.vuelo_corto_prob = 1.0
	var pv: Vector2 = t.pies_de(vendaval)
	var cu: Node2D = t.cuerpo_de(yo)
	t._colocar(yo, cu, pv + Vector2(0, -(t.bulto_de(vendaval).size.y * 0.5 + 10.0)) - (t.pies_de(yo) - t.pos_de(yo)))
	await _esperar(2)
	print("   hueco al vendaval: %.1f" % t.hueco_entre(yo, vendaval))
	var deslices_antes: int = t._deslices.size()
	combat._vuelo_corto(vendaval, yo)
	_ver(_log(combat).contains("salta atrás"), "pegandole de cerca, salta atras y suelta un corte")
	_ver(t._deslices.size() > deslices_antes, "y el salto va en camino")

	print("4) EL VENDAVAL DE CORTES EN EL REPARTO")
	var ven: AbilityData = load("res://resources/abilities/vendaval_cortes.tres")
	var f = t.forma_de(ven, vendaval, t.pies_de(yo))
	var rep: Array = t._reparto_en(ven, vendaval, f)
	var mio: Dictionary = {}
	for d in rep:
		if d["c"] == yo:
			mio = d
	_ver(f.abanico == 3, "su huella son tres lineas")
	_ver(not mio.is_empty() and float(mio["escala"]) >= 1.0, "le pilla, con %s linea(s)" % (str(mio.get("escala", 0))))

	print("")
	print("[segadora-pelea] FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(1 if _mal > 0 else 0)
