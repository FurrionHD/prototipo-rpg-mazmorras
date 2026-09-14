# Lo que comparten los dos guiones de la prueba de dos jugadores: la FASE (un fichero que escribe el host y
# lee el jugador B, estan en la misma maquina) y pelear desde el espejo pulsando botones de verdad.
extends Node

const FASE := "user://logs/prueba_dos_fase.txt"
var fallos: Array = []
var prefijo := ""


func _ok(cond: bool, texto: String) -> void:
	print(prefijo + ("[PASA] " if cond else "[FALLA] ") + texto)
	if not cond:
		fallos.append(texto)


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func escribir_fase(n: int, datos: Array = []) -> void:
	var f := FileAccess.open(FASE, FileAccess.WRITE)
	f.store_string(" ".join([str(n)] + datos.map(func(x): return str(x))))
	f.close()


# [numero, datos...] de la fase actual ([-1] si no hay fichero).
func leer_fase() -> Array:
	if not FileAccess.file_exists(FASE):
		return [-1]
	var f := FileAccess.open(FASE, FileAccess.READ)
	var partes := f.get_as_text().strip_edges().split(" ")
	f.close()
	var out: Array = [int(partes[0])]
	for i in range(1, partes.size()):
		out.append(partes[i])
	return out


func esperar_fase(n: int, plazo: float) -> Array:
	var t := 0.0
	while int(leer_fase()[0]) < n and t < plazo:
		await _esperar(0.25)
		t += 0.25
	return leer_fase()


func pantalla() -> Node:
	return Net.peleas._pantalla_combate()


func caja_abierta(p: Node) -> bool:
	for caja in ["_cast_box", "_ability_box", "_objeto_box", "_spell_box"]:
		var c: Control = p.get(caja)
		if c != null and c.visible:
			return true
	return false


# Pulsa la accion 'id' (0 Atacar, 3 Defender, 5 Huir) si me toca elegir. Devuelve si ha pulsado.
func pulsar(id: int) -> bool:
	var p: Node = pantalla()
	if p == null or int(p.get("_state")) != 1 or caja_abierta(p):
		return false
	var b: BaseButton = (p.get("_action_buttons") as Dictionary).get(id)
	if b == null or b.disabled or not b.is_visible_in_tree():
		return false
	b.pressed.emit()
	return true


# Pulsa Atacar en mis turnos hasta que la pelea acabe; luego Continuar. Devuelve si acabo en plazo.
func pelear_hasta_el_final(plazo: float) -> bool:
	var t := 0.0
	var p: Node = pantalla()
	while p != null and is_instance_valid(p) and not p.acabada() and t < plazo:
		pulsar(0)
		await _esperar(0.25)
		t += 0.25
		p = pantalla()
	var acabo: bool = p != null and is_instance_valid(p) and p.acabada()
	if acabo:
		p._on_continue_pressed()
	t = 0.0
	while (Game.hay_pelea_en_pantalla() or Net.peleas._desgaste_pendiente) and t < 10.0:
		await _esperar(0.25)
		t += 0.25
	return acabo


# El enemigo vivo y suelto mas LEJOS de 'lejos_de' (o el que se pide por id), para no pisarle la pelea al otro.
func enemigo_libre(lejos_de: Vector2 = Vector2.INF, id: int = 0) -> Node2D:
	var mejor: Node2D = null
	var mejor_d := -1.0
	for nid in Net.enemigos._enem_nodos:
		var n = Net.enemigos._enem_nodos[nid]
		if not is_instance_valid(n) or n.esta_muerto():
			continue
		if id != 0:
			if int(nid) == id:
				return n
			continue
		if int(n.get("pelea_de")) != 0:
			continue
		var d: float = 0.0 if lejos_de == Vector2.INF else (n as Node2D).global_position.distance_to(lejos_de)
		if d > mejor_d:
			mejor_d = d
			mejor = n
	return mejor


# Me planto al lado de 'presa' y, si no me embiste sola, le ataco. Espera a tener pantalla.
func pelear_con(presa: Node2D) -> void:
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null or presa == null:
		print(prefijo, "[dev] no hay jugador o enemigo")
		return
	jugador.recolocar(presa.global_position + Vector2(40, 0))
	var t := 0.0
	while not Game.hay_pelea_en_pantalla() and t < 2.0:
		await _esperar(0.25)
		t += 0.25
	if not Game.hay_pelea_en_pantalla() and is_instance_valid(presa):
		presa.atacado_por_jugador(0.3)
		t = 0.0
		while not Game.hay_pelea_en_pantalla() and t < 8.0:
			await _esperar(0.25)
			t += 0.25


func agilidad_grupo() -> float:
	var s := 0.0
	for pj in [Game.lider()] + Game.companeros():
		s += float((pj.ability_internal as Dictionary).get("agilidad", 0.0))
	return s


func excelia_grupo() -> float:
	var s := 0.0
	for pj in [Game.lider()] + Game.companeros():
		for k in (pj.ability_internal as Dictionary):
			s += float(pj.ability_internal[k])
	return s


# 'cuales' = posiciones en la plantilla de la partida de referencia. Dos personajes cada uno (el cupo de dos
# humanos) y DISTINTOS entre jugadores (otros uid). Ojo con la 1: es un personaje enorme que acaba las
# peleas del piso 1 antes de que al otro le llegue un turno.
func cargar_grupo(cuales: Array) -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	var pl: Array = Game.plantilla
	var elegidos: Array = cuales.filter(func(i): return i < pl.size()).map(func(i): return pl[i])
	if elegidos.size() == cuales.size():
		Game.party.clear()
		for pj in elegidos:
			Game.party.append(pj)
		Game.lider_idx = 0
	print(prefijo, "[dev] mi grupo: ", ", ".join(Game.party.map(func(p): return p.nombre)))
