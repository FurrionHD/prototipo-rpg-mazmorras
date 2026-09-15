# ============================================================
#  PRUEBA: LA FORMACION MANDA EN LA FILA DEL COMBATE
#  Monta una pelea con el grupo de la partida de referencia (la de la huella) poniendo la FORMACION al
#  reves que el orden en que entran, y comprueba sin ventana que:
#    1) las columnas de los aliados se colocan en el orden de la formacion;
#    2) "los de al lado" de un area enemiga salen de ese orden y no del array;
#    3) _aliados NO se ha tocado (combat_finished y la red cruzan por indice);
#    4) un aliado que entra el ULTIMO se coloca en SU puesto de la formacion, no al final.
#
#    godot --headless --path . res://tools/prueba_formacion_combate.tscn
# ============================================================
extends Node

const MUNDO_REF := "res://tools/huellas/mundo_ref.tres"
var _fallos: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	if not FileAccess.file_exists(MUNDO_REF):
		print("[formacion] SIN PARTIDA DE REFERENCIA: no se puede probar")
		get_tree().quit()
		return
	Game.importar_partida(ResourceLoader.load(MUNDO_REF, "", ResourceLoader.CACHE_MODE_IGNORE))
	Game.asegurar_uids()
	var pjs: Array = [Game.lider()]
	for comp in Game.companeros():
		pjs.append(comp)
	if pjs.size() < 3:
		print("[formacion] la partida de referencia tiene menos de 3 personajes: no se puede probar")
		get_tree().quit()
		return

	# LA FORMACION AL REVES: en solitario es el orden de Game.party.
	var al_reves: Array[PersonajeData] = []
	for i in range(pjs.size() - 1, -1, -1):
		al_reves.append(pjs[i])
	Game.party.assign(al_reves)

	# Entran todos MENOS el primero de la formacion, que entrara el ultimo (caso 4).
	var tardio: PersonajeData = al_reves[0]
	var pcs: Array = []
	var entran: Array = []
	for pj in pjs:
		if pj == tardio:
			continue
		entran.append(pj)
		var c: Combatant = Game.crear_player_combatant(pj)
		c.max_energy = 100.0
		c.current_energy = 100.0
		pcs.append(c)
	Game._active_player_pjs = entran
	Game._active_player_cs = pcs
	var ed: EnemyData = load("res://scenes/actors/enemy/slime.tres")
	var pelea: Node = load("res://scenes/ui/combat.tscn").instantiate()
	pelea.setup(pcs, [ed.crear_combatant(0.5, false, false)], false)
	add_child(pelea)
	for _i in 3:
		await get_tree().process_frame

	_comprobar(pelea, "al empezar")
	for i in pcs.size():
		_esperar(pelea._aliados[i] == pcs[i], "3) _aliados[%d] sigue siendo el que entro %d" % [i, i])

	# 4) EL TARDIO: entra el ultimo y tiene que ir el PRIMERO.
	var ct: Combatant = Game.crear_player_combatant(tardio)
	ct.max_energy = 100.0
	ct.current_energy = 100.0
	pelea.altas.anadir_aliado(ct)
	for _i in 2:
		await get_tree().process_frame
	_comprobar(pelea, "tras entrar el ultimo")
	_esperar(pelea._aliados[pelea._aliados.size() - 1] == ct, "3) el que entra tarde va al FINAL del array")

	print("[formacion] RESULTADO: %s" % ("TODO BIEN" if _fallos == 0 else "%d FALLOS" % _fallos))
	get_tree().quit()


func _comprobar(pelea: Node, cuando: String) -> void:
	var esperado: Array = []
	for pj in Game.party:
		for c in pelea._aliados:
			if c.uid_formacion == String(pj.uid):
				esperado.append(c.nombre)
	# 1) Las columnas, en el orden en que se ven.
	var vistas: Array = []
	for col in pelea.montaje._aliados_box.get_children():
		for i in pelea._bloques_aliados.size():
			if pelea._bloques_aliados[i].get("columna") == col:
				vistas.append(pelea._aliados[i].nombre)
	_esperar(vistas == esperado, "1) %s: columnas %s == formacion %s" % [cuando, vistas, esperado])
	# 2) Los de al lado del del medio.
	var fila: Array = pelea.altas._fila_visual_aliados()
	if fila.size() >= 3:
		var medio: Combatant = fila[1]
		var vecinos: Array = pelea.objetivos._adyacentes_aliados_vivos(medio).map(func(c): return c.nombre)
		var bien: Array = [fila[0].nombre, fila[2].nombre]
		_esperar(vecinos == bien, "2) %s: vecinos de %s = %s (tocan %s)" % [cuando, medio.nombre, vecinos, bien])


func _esperar(ok: bool, que: String) -> void:
	print("[formacion] %s  %s" % ["OK   " if ok else "FALLA", que])
	if not ok:
		_fallos += 1
