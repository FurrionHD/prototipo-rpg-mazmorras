extends Node
# Vuelca a la consola lo que lee el jugador de cada estado (pase de textos 06/11): la ficha del chip (Instance.resumen,
# con 3 turnos, 2 acumulaciones y 5 de daño por turno de ejemplo), la coletilla de las fichas (efecto_legible) y la
# descripcion de sabor. Al final, el chip de dos imbuiciones de ejemplo. Sin ventana:
#   godot --headless --path . res://tools/volcar_textos_estados.tscn


func _ready() -> void:
	await get_tree().process_frame   # los autoloads tienen que estar listos
	var ids: Array = StatusEffects.all_ids()
	ids.sort()
	for id in ids:
		var d: Dictionary = StatusEffects.def(int(id))
		var inst := StatusEffects.Instance.new(d, 3, 2 if int(d.get("max_stacks", 1)) > 1 else 1)
		inst.magnitude = 5.0
		print("=== %s  [%d]" % [str(d.get("nombre", "?")), int(id)])
		print("  " + inst.resumen().replace("\n", "\n  "))
		var col: String = StatusEffects.efecto_legible(int(id))
		if col != "":
			print("  Coletilla: " + col)
		if str(d.get("descripcion", "")) != "":
			print("  Sabor: " + str(d["descripcion"]))
	# Dos imbuiciones de ejemplo: un Manto de Fuego (cuerpo) y un Filo emponzoñado (sin elemento, con escalera).
	var c := Combatant.new("Ejemplo", 1, Abilities.new(), 100.0, 1.0, 1.0, 1.0)
	c.aplicar_imbue(Elementos.Elemento.FUEGO, 0.15, 10, true, StatusEffects.Id.QUEMADURA, 0.15)
	print("=== CHIP: Manto de brasas\n  " + c.imbue_resumen().replace("\n", "\n  "))
	var c2 := Combatant.new("Ejemplo", 1, Abilities.new(), 100.0, 1.0, 1.0, 1.0)
	c2.aplicar_imbue(Elementos.Elemento.NINGUNO, 0.0, 8, false, StatusEffects.Id.VENENO, 0.7)
	print("=== CHIP: Filo emponzoñado\n  " + c2.imbue_resumen().replace("\n", "\n  "))
	get_tree().quit()
