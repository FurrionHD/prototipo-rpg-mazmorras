# ============================================================
#  tactico_arana.gd  (class_name TacticoArana)
#  LO QUE SE VE ENCIMA DE LAS ARAÑAS MUTANTES (03/11/2026, arana-mutante), en el mapa de la pelea. Aparte de CombatTactico
#  para no engordarlo: lo crea el y lo llama cada fotograma. Sale de lo que ya viaja al espejo (las cargas), asi que se
#  ve igual en todas las maquinas sin mandar nada.
#    LAS CARGAS  chispazos o ascuas y el contador encima (AranaAire.CARGA), y los hilos del globo de la Tormentosa:
#                cuantas mas cargas, mas tiempo encendidos y menos apagados.
# ============================================================
extends RefCounted
class_name TacticoArana

# [lo que dura encendido un grupo de hilos, y la espera minima y maxima hasta el siguiente], por cargas.
const HILOS := [[0.5, 1.2, 3.0], [0.6, 0.8, 2.0], [0.8, 0.4, 1.2], [1.1, 0.1, 0.5], [1.1, 0.05, 0.2]]

var _t = null   # CombatTactico (sin tipo: se nombran el uno al otro)
var _cargas: Dictionary = {}   # Combatant -> su AranaAire
var _nivel: Dictionary = {}    # Combatant -> las cargas con las que se le puso el ritmo a los hilos


func _init(t) -> void:
	_t = t


func tick() -> void:
	var arena: ArenaCombate = _t._arena()
	if arena == null:
		return
	for c in _t._pantalla._enemies:
		var cb: Combatant = c
		if cb.carga_tope <= 0:
			continue
		var cu: Node2D = _t.cuerpo_de(cb)
		var vivo: bool = cb.is_alive() and cu != null and cu.visible
		var n = _cargas.get(cb)
		if not vivo:
			if n != null and is_instance_valid(n):
				n.secar()
			_cargas.erase(cb)
			continue
		if n == null or not is_instance_valid(n):
			n = AranaAire.pegado(arena, _t.bulto_visual(cb), cb.mutacion == &"tejedora", _t._cod(cb))
			_cargas[cb] = n
		n.seguir(_t.bulto_visual(cb))
		n.poner_nivel(cb.cargas, cb.carga_tope)
		_ritmo_hilos(cb, cu)


func _ritmo_hilos(c: Combatant, cu: Node2D) -> void:
	if int(_nivel.get(c, -1)) == c.cargas:
		return
	var spr = cu.get("_sprite")
	if spr is AnimatedSprite2D:
		_nivel[c] = c.cargas
		var r: Array = HILOS[clampi(c.cargas, 0, HILOS.size() - 1)]
		Parpadeo.ritmo(spr, float(r[0]), float(r[1]), float(r[2]))


func quitar() -> void:
	for c in _cargas:
		var n = _cargas[c]
		if n != null and is_instance_valid(n):
			n.queue_free()
	_cargas.clear()
	_nivel.clear()
