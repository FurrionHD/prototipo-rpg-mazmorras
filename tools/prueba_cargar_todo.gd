# PRUEBA: carga TODOS los scripts para que Godot los compile y cante los errores.
extends Node

func _ready() -> void:
	var n := 0
	var malos := 0
	var pila := ["res://scripts"]
	while not pila.is_empty():
		var dir: String = pila.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			pila.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s = load(dir.path_join(f))
				n += 1
				if s == null or not (s as GDScript).can_instantiate():
					malos += 1
					print("[cargar] ROTO: ", dir.path_join(f))
	print("[cargar] %d scripts, %d rotos" % [n, malos])
	get_tree().quit()
