# ============================================================
#  PRUEBA: EL SUELO DEL PUEBLO COPIADO ES EL MISMO QUE EL CALCULADO (optimizacion 1E, 19/10/2026)
#  Desde la segunda visita el suelo no se calcula: se pega lo que salio la primera (town.gd, _suelo_hecho). Entra al
#  pueblo (calculado), apunta cada baldosa de cada capa, entra otra vez (copiado) y compara baldosa a baldosa.
#    godot --headless --path . res://tools/prueba_pueblo_suelo.tscn
# ============================================================
extends Node

var _mal: int = 0


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.current_floor = 0
	var visitas: Array = []
	for vez in 2:
		get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
		for k in 300:
			await get_tree().process_frame
			if get_tree().get_first_node_in_group("player") != null:
				break
		await get_tree().process_frame
		visitas.append(_baldosas())
	var a: Dictionary = visitas[0]
	var b: Dictionary = visitas[1]
	var total: int = 0
	for capa in a:
		total += (a[capa] as Dictionary).size()
	_ver(total > 1000, "la primera visita pinta el suelo (%d baldosas en %d capas)" % [total, a.size()])
	_ver(a.keys() == b.keys(), "las mismas capas en las dos visitas")
	for capa in a:
		var ca: Dictionary = a[capa]
		var cb: Dictionary = b.get(capa, {})
		var distintas: int = 0
		for c in ca:
			if cb.get(c) != ca[c]:
				distintas += 1
		_ver(ca.size() == cb.size() and distintas == 0, "capa %s: %d baldosas, %d distintas" % [capa, ca.size(), distintas])
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)


# capa -> {celda: [fuente, coordenada del atlas, alternativa]}
func _baldosas() -> Dictionary:
	var out: Dictionary = {}
	var escena: Node = get_tree().current_scene
	var suelo: Node = escena.get_node_or_null("Suelo") if escena != null else null
	if suelo == null:
		return out
	for tml in suelo.get_children():
		if not (tml is TileMapLayer):
			continue
		var d: Dictionary = {}
		for c in (tml as TileMapLayer).get_used_cells():
			d[c] = [tml.get_cell_source_id(c), tml.get_cell_atlas_coords(c), tml.get_cell_alternative_tile(c)]
		out[String(tml.name)] = d
	return out
