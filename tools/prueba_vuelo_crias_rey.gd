# EL VUELO DE LAS CRIAS DEL REY (09/10, el 16 del playtest 08/10: "estaban dentro del Rey y de repente aparecieron
# detras mio, como un teletransporte"). El Brote de verdad (rey_slime_invocacion), con la pelea corriendo, y se mide
# fotograma a fotograma: los pies de cada cria tienen que ir del Rey a su sitio POCO A POCO y su dibujo subir y bajar.
#   godot --headless --path . res://tools/prueba_vuelo_crias_rey.tscn
extends Node

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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _barra_se_ve(combat: Node, c: Combatant) -> bool:
	var idx: int = combat._enemies.find(c)
	for b in combat._bloques:
		if int((b as Dictionary).get("idx", -99)) == idx:
			var col = (b as Dictionary).get("columna")
			return col is Control and (col as Control).is_visible_in_tree()
	return false


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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/rey_slime.tres", jug.global_position + Vector2(130, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	if not Game.start_combat([nodo], false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(40)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	var tm = combat.turno_mapa
	var e: Combatant = combat._enemies[0]
	e.charging = null
	tm.olvidar_carga(e)
	await _esperar(5)
	var p_rey: Vector2 = tm.pos_de(e)
	var inv: AbilityData = load("res://resources/abilities/rey_slime_invocacion.tres")
	# Cuando sale cada escupitajo (CRIA_LANZADA) en el mapa: la cria tiene que esperar a el.
	var t0: int = Time.get_ticks_msec()
	var escupe: Dictionary = {}   # cuerpo de la cria -> ms
	combat._fx.dibujo_en_mapa.connect(func(ev: Dictionary, _vuelo: float) -> void:
		if int(ev.get("estilo", 0)) == CombatFX.Estilo.CRIA_LANZADA:
			var v: Combatant = tm._de_bloque(ev["bv"])
			if v != null and not escupe.has(v):
				escupe[v] = Time.get_ticks_msec() - t0)
	combat.enemigos._enemy_use_ability(e, inv)
	var crias: Array = []
	for c in combat._enemies:
		if c != e:
			crias.append(c)
	print("rey en %s, %d crias" % [str(p_rey.round()), crias.size()])
	_ver(crias.size() > 0, "el Brote saca crias")
	# Fotograma a fotograma, 2 s: pies (cuerpo.global_position), lo que sube el dibujo (_sprite.position.y) y si se ve.
	var rastro: Dictionary = {}
	while Time.get_ticks_msec() - t0 < 2000:
		for c in crias:
			var cu: Node2D = tm.cuerpo_de(c)
			if cu == null:
				continue
			var sp = cu.get("_sprite")
			if not rastro.has(c):
				rastro[c] = []
			(rastro[c] as Array).append([Time.get_ticks_msec() - t0, cu.global_position,
				(sp as Node2D).position.y if sp is Node2D else 0.0, cu.is_visible_in_tree(), _barra_se_ve(combat, c),
				"%s/%s" % [(sp as AnimatedSprite2D).animation, str(tm._gestos_bicho.get(cu, {}).get("dur", "-"))]])
		await get_tree().process_frame
	for c in crias:
		var cux: Node2D = tm.cuerpo_de(c)
		var spx = cux.get("_sprite")
		var idx: int = combat._enemies.find(c)
		var hay_bloque: bool = false
		for b in combat._bloques:
			if int((b as Dictionary).get("idx", -99)) == idx:
				hay_bloque = true
		print("    [diag] gesto %s sin_formar %s, anim %s jugando %s, por_nacer %s, bloque %s idx %d" % [str(tm._gestos_bicho.get(cux, {})), tm.cria_sin_formar(cux),
			(spx as AnimatedSprite2D).animation, (spx as AnimatedSprite2D).is_playing(), tm._por_nacer.has(c), hay_bloque, idx])
	for c in crias:
		var r: Array = rastro.get(c, [])
		_ver(r.size() > 10, "la cria %s tiene cuerpo (%d fotogramas)" % [c.nombre, r.size()])
		if r.size() < 2:
			continue
		var ini: Vector2 = r[0][1]
		var fin: Vector2 = r[-1][1]
		var largo: float = ini.distance_to(fin)
		var salto_max: float = 0.0
		var a_medias: int = 0
		var y0: float = float(r[0][2])
		var sube: float = 0.0
		for i in r.size():
			if i > 0:
				salto_max = maxf(salto_max, (r[i][1] as Vector2).distance_to(r[i - 1][1]))
			var hecho: float = (r[i][1] as Vector2).distance_to(ini)
			if hecho > largo * 0.15 and hecho < largo * 0.85:
				a_medias += 1
			sube = maxf(sube, y0 - float(r[i][2]))
		print("    %s: de %s a %s (%.0f px), mayor salto en un fotograma %.1f px, %d fotogramas a medio camino, sube %.1f px" % [
			c.nombre, str(ini.round()), str(fin.round()), largo, salto_max, a_medias, sube])
		# Cuando sale (se mueve 2 px) y cuando llega; y si se veia antes de salir (dentro del Rey).
		var t_sale: int = -1
		var t_llega: int = -1
		var vista_dentro: bool = false
		for i in r.size():
			var lejos: float = (r[i][1] as Vector2).distance_to(ini)
			if t_sale < 0 and lejos > 2.0:
				t_sale = int(r[i][0])
			if bool(r[i][3]) and int(r[i][0]) < int(escupe.get(c, 1 << 30)):
				vista_dentro = true
			if t_llega < 0 and (r[i][1] as Vector2).distance_to(fin) < 1.0:
				t_llega = int(r[i][0])
		var t_esc: int = int(escupe.get(c, -1))
		print("    escupitajo a los %d ms; sale a los %d ms, llega a los %d ms (vuela %d ms); antes de salir se ve: %s" % [
			t_esc, t_sale, t_llega, t_llega - t_sale, vista_dentro])
		_ver(t_esc >= 0, "el Rey la escupe (CRIA_LANZADA)")
		_ver(t_esc >= 0 and t_sale >= t_esc and t_sale - t_esc < 60, "sale CON el escupitajo, no antes")
		_ver(not vista_dentro, "no se ve dentro del Rey antes de salir")
		_ver(t_llega - t_sale >= 250, "y el vuelo se ve (%d ms)" % (t_llega - t_sale))
		_ver(bool(r[-1][3]), "y al final se ve")
		var barra_en_aire: bool = false
		for i in r.size():
			if int(r[i][0]) <= t_llega and bool(r[i][4]):
				barra_en_aire = true
		_ver(not barra_en_aire, "su barra de vida no sale mientras vuela")
		_ver(bool(r[-1][4]), "y sale cuando ya se ha formado en el suelo")
		var cambios: Array = []
		for i in r.size():
			if i == 0 or str(r[i][5]) != str(r[i - 1][5]):
				cambios.append("%dms %s" % [int(r[i][0]), str(r[i][5])])
		print("      anim: ", " | ".join(cambios))
		var muestra: Array = []
		for i in range(0, r.size(), maxi(1, r.size() / 12)):
			muestra.append("%dms %s %.0f" % [int(r[i][0]), str((r[i][1] as Vector2).round()), float(r[i][2])])
		print("      ", " | ".join(muestra))
		_ver(ini.distance_to(p_rey) < 40.0, "sale de donde esta el Rey (%.0f px)" % ini.distance_to(p_rey))
		# FUERA DEL CUERPO DEL REY, no "a mas de 60 px" (21/10): la cria cae DETRAS del jugador mas cercano para acorralarlo
		# (sitio_cria_acorrala, 09/10), y si ese jugador esta pegado al Rey cae a ~50 px de el, que es lo correcto.
		var caja_rey: Rect2 = tm.bulto_de(e)
		_ver(not caja_rey.grow(4.0).has_point(fin) and largo > 30.0,
			"y acaba fuera del Rey (a %.0f px; su cuerpo mide %.0fx%.0f)" % [largo, caja_rey.size.x, caja_rey.size.y])
		_ver(a_medias >= 4, "pasa por el camino (no aparece de golpe)")
		_ver(salto_max < largo * 0.5, "sin saltos de golpe")
		_ver(sube > 20.0, "y su dibujo sube por el aire (%.0f px)" % sube)
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
