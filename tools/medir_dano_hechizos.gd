# MEDIR EL DAÑO TOTAL DE CADA HECHIZO EN EL MAPA (10/11, revision del daño de hechizos antes del proximo mutante).
# No es una prueba de BIEN/MAL: saca una tabla. Para cada hechizo de ATAQUE, lo lanza de verdad por
# CombatMagia._resolver_hechizo (la misma resolucion de la pelea) contra 3 enemigos colocados a mano y suma lo que
# reciben, en "golpes al 100 %" (lo que haria un golpe del hechizo con escala 1 a ese enemigo: asi no cuentan sus
# resistencias ni el poder magico). Sin criticos y con muchas tiradas, para quitar el azar.
#   ANTES = la cuenta de la fila de siempre (tools/prueba_magias_regla.gd: principal + los de al lado + rebotes).
#   Disposiciones: SOLO (1 contra 1), LADO (3 en fila de lado, a 35 px), FILA (3 uno detras de otro, a 35 px),
#   LADO60 (de lado, a 60 px entre centros: guardando su hueco).
#   godot --headless --path . res://tools/medir_dano_hechizos.tscn
extends Node

const CARPETA := "res://resources/spells/"
const TIRADAS := 30
const SEP := 35.0
const DIST := 90.0

var sala = null


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


func _pantalla() -> Node:
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					return h
	return null


func _colocar(combat: Node, e: Combatant, pos: Vector2) -> void:
	var c: Node2D = combat.turno_mapa.cuerpo_de(e)
	if c != null:
		c.global_position = pos
	combat.turno_mapa._pos[e] = pos


# Lo que le haria un golpe al 100 % de este hechizo a 'e' (media, sin criticos).
func _unidad(yo: Combatant, e: Combatant, spell: SpellData) -> float:
	var t: float = 0.0
	for _i in 400:
		t += float(StatsMath.resolve_spell(yo, e, spell, spell.elemento, 1.0).damage)
	return t / 400.0


# Lanza 'spell' TIRADAS veces y devuelve la media del total en golpes al 100 %.
func _medir(combat: Node, spell: SpellData, en: Array, apunta: Combatant) -> float:
	var yo: Combatant = combat._aliados[0]
	combat._player = yo
	var unidades: Dictionary = {}
	for e in en:
		unidades[e] = maxf(_unidad(yo, e, spell), 0.0001)
	var total: float = 0.0
	for _t in TIRADAS:
		var antes: Dictionary = {}
		for e in en:
			e.max_hp = 999999.0
			e.current_hp = 999999.0
			antes[e] = e.current_hp
		combat._casteos[yo] = {"punto": combat.turno_mapa.pies_de(apunta), "spell": spell, "idx": 0}
		combat.magia._bolas_elegidas = []
		combat.magia._resolver_hechizo(spell, apunta)
		for e in en:
			total += (float(antes[e]) - e.current_hp) / float(unidades[e])
		# que ningun estado (mojado, quemado...) pase de una tirada a la siguiente
		for e in en:
			e.statuses.clear()
	return total / float(TIRADAS)


# La cuenta de siempre (prueba_magias_regla._total), en golpes al 100 %.
func _antes(s: SpellData) -> float:
	var vecinos: float = 0.0
	if s.salpica():
		vecinos = 2.0 if (s.alcance == SpellData.Alcance.TODOS or not s.dispersa) else 4.0 / 3.0
	var salp: float = s.dano_salpicon * vecinos
	if s.dispersa:
		salp *= s.peso_elemento(s.elemento)
	return s.dano_objetivo + salp + float(s.rebotes_n()) * s.dano_rebote


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("medir_dano_hechizos", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	for i in 3:
		sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(90, (i - 1) * 50.0), {})
	await _esperar(25)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var bichos: Array = get_tree().get_nodes_in_group("enemy")
	bichos.sort_custom(func(a, b): return a.global_position.distance_to(jug.global_position) < b.global_position.distance_to(jug.global_position))
	if bichos.size() < 3 or await sala.pelear(bichos.slice(0, 3), false) == null:
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(10)
	var combat: Node = _pantalla()
	await _esperar(10)
	combat.set_process(false)
	var es: Array = combat._enemies
	if es.size() < 3:
		print("MAL: solo %d enemigos en la pelea" % es.size())
		get_tree().quit(1)
		return
	for e in es:
		e.crit_resist = 10.0   # sin criticos
		e.elemento = 0         # sin afinidad: cada golpe pesa lo mismo sea del elemento que sea
		e.resist_elemental = {}
	var yo_p: Vector2 = combat.turno_mapa.pos_de(combat._aliados[0])
	var lejos := Vector2(0, 2000)
	var disp := {
		"solo": [yo_p + Vector2(DIST, 0), yo_p + lejos, yo_p + lejos * 1.5],
		"lado": [yo_p + Vector2(DIST, 0), yo_p + Vector2(DIST, -SEP), yo_p + Vector2(DIST, SEP)],
		"fila": [yo_p + Vector2(DIST, 0), yo_p + Vector2(DIST + SEP, 0), yo_p + Vector2(DIST - SEP, 0)],
		"lado60": [yo_p + Vector2(DIST, 0), yo_p + Vector2(DIST, -60.0), yo_p + Vector2(DIST, 60.0)],
	}
	print("[medir] %-22s %5s %5s | %6s %6s %6s %6s | %s" % ["hechizo", "base", "ANTES", "solo", "lado", "fila", "lado60", "ficha"])
	for archivo in ResourceLoader.list_directory(CARPETA):
		if not archivo.ends_with(".tres"):
			continue
		var s := load(CARPETA + archivo) as SpellData
		if s == null or s.tipo != SpellData.TipoEfecto.ATAQUE or s.dano_base <= 0.0 or s.es_imbuicion():
			continue
		var fila_txt: Array = []
		for k in ["solo", "lado", "fila", "lado60"]:
			for i in 3:
				_colocar(combat, es[i], disp[k][i])
			var en: Array = [es[0]] if k == "solo" else es.slice(0, 3)
			fila_txt.append(await _medir(combat, s, en, es[0]))
		print("[medir] %-22s %5.2f %5.2f | %6.2f %6.2f %6.2f %6.2f | obj %.2f salp %.2f reb %dx%.2f hits %d forma %d r%.0f" % [
			s.nombre, s.dano_base, _antes(s), fila_txt[0], fila_txt[1], fila_txt[2], fila_txt[3],
			s.dano_objetivo, s.dano_salpicon, s.rebotes_n(), s.dano_rebote, s.golpes(), s.forma, s.forma_radio])
	print("[medir] FIN")
	get_tree().quit(0)
