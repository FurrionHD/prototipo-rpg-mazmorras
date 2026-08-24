# ============================================================
#  ver_nucleos.gd  --  HERRAMIENTA, no parte del juego.
#  Saca la tabla de PAREJAS de nucleos, que es de lo que vive la mejora del farolillo: pide uno de
#  cada rama de la misma banda. Si a alguna banda le falta su pareja, ese tramo de mejoras es
#  IMPOSIBLE y no hay forma de darse cuenta jugando -- solo se ve el boton en gris.
#
#  Va como ESCENA y no con --script: los .tres de material dependen del autoload Game, y
#  --script arranca sin autoloads, asi que ahi load() devuelve null en silencio y la tabla sale
#  vacia diciendo que todo esta bien.
#  godot --headless --path . res://tools/ver_nucleos.tscn
# ============================================================
extends Node

const NUCLEOS := [
	"res://resources/materials/nucleo_slime.tres", "res://resources/materials/nucleo_rata.tres",
	"res://resources/materials/nucleo_venenoso.tres", "res://resources/materials/nucleo_rey_rata.tres",
	"res://resources/materials/nucleo_fuego.tres", "res://resources/materials/nucleo_jabali.tres",
	"res://resources/materials/nucleo_slime_abisal.tres", "res://resources/materials/nucleo_trent.tres",
	"res://resources/materials/nucleo_rey_slime.tres",
	"res://resources/materials/nucleo_arana.tres", "res://resources/materials/nucleo_ciempies.tres",
	"res://resources/materials/nucleo_aberracion.tres", "res://resources/materials/nucleo_gargola.tres",
	"res://resources/materials/nucleo_escarabajo.tres", "res://resources/materials/nucleo_golem.tres",
	"res://resources/materials/nucleo_bestia.tres", "res://resources/materials/nucleo_coloso.tres",
	"res://resources/materials/nucleo_minotauro.tres",
]

const USO := ["cualquiera", "ARMA", "ARMADURA"]

func _ready() -> void:
	var todos: Array = []
	for r in NUCLEOS:
		var m: MaterialData = load(r) as MaterialData
		if m != null:
			todos.append(m)
	todos.sort_custom(func(a, b): return int(a.mejora_min) < int(b.mejora_min))

	print("PAREJAS DE NUCLEOS  (las que gasta la mejora del farolillo: una de cada rama)")
	print("")
	print("  %-22s %-10s %-6s %-7s -> %s" % ["nucleo", "uso", "banda", "t.equipo", "pareja"])
	print("  " + "-".repeat(78))
	var huerfanos: int = 0
	for m in todos:
		var par: MaterialData = Forge.pareja_nucleo(m, todos)
		if par == null:
			huerfanos += 1
		print("  %-22s %-10s %-6s %-7s -> %s" % [m.nombre, USO[int(m.uso_mejora)],
			"%d-%d" % [int(m.mejora_min), int(m.mejora_max)], str(int(m.tier_equipo)),
			par.nombre if par != null else "*** SIN PAREJA ***"])
	print("")
	if huerfanos == 0:
		print("=== TODOS EMPAREJADOS ===")
	else:
		print("=== %d SIN PAREJA: esos tramos no se pueden mejorar en el farolillo ===" % huerfanos)
	get_tree().quit(0)
