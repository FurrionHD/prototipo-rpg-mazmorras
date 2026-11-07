extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/ui/combat_espejo.gd
# LO QUE PIDE EL BASICO DE UN BICHO VIAJA POR LA RED (07/11, log de la sala del .exe: "la animacion 'golpe_6_8' no esta
# en ANIMS_SUELTAS: no viaja"). El basico no sale de una AbilityData: pide su animacion por el nombre
# (EnemyData.anim_basico), y por la red ese nombre va por su puesto en combat_espejo.ANIMS_SUELTAS. Uno que falte ahi
# no llega a los demas PCs.

const Espejo = preload("res://scripts/ui/combat_espejo.gd")


func test_cada_anim_basico_de_los_enemigos_viaja() -> void:
	var faltan: Array = []
	for d in ["res://scenes/actors/enemy", "res://resources"]:
		var pila: Array = [d]
		while not pila.is_empty():
			var dir: String = pila.pop_back()
			for sub in DirAccess.get_directories_at(dir):
				pila.append(dir + "/" + sub)
			for a in DirAccess.get_files_at(dir):
				if not a.ends_with(".tres"):
					continue
				var t: String = FileAccess.get_file_as_string(dir + "/" + a)
				var k: int = t.find("anim_basico = ")
				if k < 0:
					continue
				var resto: String = t.substr(k + "anim_basico = ".length()).split("\n")[0]
				var nombre: StringName = StringName(resto.trim_prefix("&").trim_prefix("\"").trim_suffix("\""))
				if nombre != &"" and not Espejo.ANIMS_SUELTAS.has(nombre) and not faltan.has(nombre):
					faltan.append(nombre)
	igual(faltan, [], "anim_basico que no estan en combat_espejo.ANIMS_SUELTAS (apuntarlas AL FINAL)")


func test_ida_y_vuelta() -> void:
	for n in Espejo.ANIMS_SUELTAS:
		igual(Espejo.anim_de_cod(Espejo.cod_anim(n)), n, "el codigo de '%s' vuelve al mismo nombre" % n)
