# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_viento.tscn
#
# EL ELEMENTO VIENTO (05/11/2026): la tabla de lo que recibe cada uno con sus fichas de verdad, lo de ir en el aire (+0,5), que
# aviva al quemado (x1,5), el tope (x2), y que no sale al azar en las imbuciones (aun no tiene manto ni colores).
extends Node

const V := Elementos.Elemento.VIENTO

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if cond else "MAL", que])
	if not cond:
		_mal += 1


func _mult(nombre: String, en_vuelo: bool, quemado: bool) -> float:
	var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % nombre)
	var c: Combatant = ed.crear_combatant(0.5, false)
	if en_vuelo:
		c.vuela = true
	if quemado:
		c.apply_status(StatusEffects.Id.QUEMADURA)
	return Elementos.mult_recibido(V, c)


func _casi(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _ready() -> void:
	print("1) LA TABLA")
	# [ficha, normal, en el aire, en el aire y quemado]. La segadora es neutra; polilla y chillon van siempre en el aire.
	for fila in [["gargola", 0.5, 1.0, 1.5], ["coloso", 0.5, 1.0, 1.5], ["golem_arcilla", 0.5, 1.0, 1.5],
			["segadora", 1.0, 1.5, 2.0], ["miconido", 1.25, 1.75, 2.0], ["chillon", 1.75, 1.75, 2.0], ["polilla", 2.0, 2.0, 2.0]]:
		_ok(_casi(_mult(fila[0], false, false), fila[1]), "%s: x%s (sale %.2f)" % [fila[0], fila[1], _mult(fila[0], false, false)])
		_ok(_casi(_mult(fila[0], true, false), fila[2]), "%s en el aire: x%s" % [fila[0], fila[2]])
		_ok(_casi(_mult(fila[0], true, true), fila[3]), "%s en el aire y quemado: x%s (con tope)" % [fila[0], fila[3]])
	_ok(_casi(_mult("segadora", false, true), 1.5), "quemado sin volar: x1,5")

	print("2) SOLO EL VIENTO")
	var c: Combatant = (load("res://scenes/actors/enemy/polilla.tres") as EnemyData).crear_combatant(0.5, false)
	var fuego: float = Elementos.mult_recibido(Elementos.Elemento.FUEGO, c)
	_ok(_casi(fuego, 1.6), "ir en el aire no le cambia el fuego a la polilla (x1,6)")
	c.apply_status(StatusEffects.Id.QUEMADURA)
	var agua: float = Elementos.mult_recibido(Elementos.Elemento.AGUA, c)
	_ok(_casi(agua, 1.5), "el agua sobre quemado sigue igual, sin tope de viento (x1,5)")

	print("3) EN EL AIRE")
	var g: Combatant = (load("res://scenes/actors/enemy/gargola.tres") as EnemyData).crear_combatant(0.5, false)
	_ok(not g.en_el_aire(), "la gargola posada no va en el aire")
	g.charging = load("res://resources/abilities/gargola_picado.tres")
	_ok(g.en_el_aire() and g.volando(), "cargando el Picado, si")
	_ok(_casi(Elementos.mult_recibido(V, g), 1.0), "y el viento le entra a x1,0 aunque resiste")
	_ok(not c.volando(), "la polilla va en el aire pero el cuerpo a cuerpo le sigue llegando")

	print("4) AL AZAR")
	_ok(Elementos.TODOS.has(V), "sale en la ficha de los enemigos")
	_ok(not Elementos.AZAR_MAGIA.has(V), "no sale en el Manto prismatico ni en los grimorios al azar")
	_ok(Elementos.AZAR_MAGIA.size() == 5, "siguen saliendo los cinco de antes")
	_ok(Elementos.Elemento.OSCURIDAD == 5 and V == 6, "va al final: no cambia los numeros de los demas")
	_ok(Elementos.nombre(V) == "Viento" and Elementos.tiene_color(V), "tiene nombre y color")

	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)
