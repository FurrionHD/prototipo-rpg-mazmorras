# ============================================================
#  tactico_trent.gd  (class_name TacticoTrent)
#  LO QUE SE VE ENCIMA DE LOS CUERPOS POR LOS MUTANTES DEL TRENT Y SUS BICHOS (03/11/2026, paso 5 de trent-mutante),
#  en el mapa de la pelea. Aparte de CombatTactico para no engordarlo: lo crea el y lo llama cada fotograma.
#  Todo sale de lo que ya viaja al espejo (los estados, las animaciones, la vida): se ve igual en todas las maquinas
#  sin mandar nada.
#    RESINADO     el cepo de ambar en los pies (TrentAire.RESINA); al soltarle, a trozos.
#    SAVIA NEGRA  el humo violeta, mas espeso cuantas mas cargas (TrentAire.HUMO).
#    PRINGADO     los pegotes y las moscas (AmbarAire.PRINGUE).
#    PICOR        las ronchas (AmbarAire.PICOR).
#    EL GEISER    mientras carga (su animacion 'geiser_carga'), la grieta de la espalda brilla (TrentAire.CARGA).
#    MAS SECO     el Espantajo con tramos de rabia: las grietas que laten (TrentAire.SECO).
#  El ESTALLIDO de la costra lo lanza CombatTactico._tick_costra al romperse (ahi se cambia su hoja); el de la CAPA DE
#  AMBAR de los tuyos (set Ambar), aqui.
#    LOS PUNTOS   (04/11, los pidio el jefe) quien lleva costra (el Tocon, o tu con el set Ambar activo): el contador de
#                 las arañas en ambar. Enteros con la capa puesta; rota, se van encendiendo hasta que vuelve.
# ============================================================
extends RefCounted
class_name TacticoTrent

var _t = null   # CombatTactico (sin tipo: se nombran el uno al otro)
# cada uno: Combatant -> el nodo (TrentAire / AmbarAire)
var _resina: Dictionary = {}
var _humo: Dictionary = {}
var _pringue: Dictionary = {}
var _picor: Dictionary = {}
var _carga: Dictionary = {}
var _seco: Dictionary = {}
var _capa: Dictionary = {}   # Combatant -> si llevaba la capa de ambar (set Ambar) el fotograma anterior
var _puntos: Dictionary = {}   # Combatant -> su contador (AranaAire)


func _init(t) -> void:
	_t = t


func tick() -> void:
	var arena: ArenaCombate = _t._arena()
	if arena == null:
		return
	var todos: Array = []
	todos.append_array(_t._pantalla._aliados)
	todos.append_array(_t._pantalla._enemies)
	for c in todos:
		var cb: Combatant = c
		var vivo: bool = cb.is_alive() and _t.cuerpo_de(cb) != null and (_t.cuerpo_de(cb) as Node2D).visible
		var caja: Rect2 = _t.bulto_visual(cb) if vivo else Rect2()
		var sav = cb.get_status(StatusEffects.Id.SAVIA_NEGRA) if vivo else null
		_tick_puntos(arena, cb, vivo)
		var tramos: int = cb.rabia_tramos() if vivo and cb.rabia_tramo > 0.0 and not cb.rabia_tramos_velocidad else 0
		_uno(arena, _resina, cb, vivo and cb.has_status(StatusEffects.Id.RESINADO), caja, 1, TrentAire.Modo.RESINA, false)
		_uno(arena, _humo, cb, sav != null, caja, int(sav.stacks) if sav != null else 1, TrentAire.Modo.HUMO, false)
		_uno(arena, _pringue, cb, vivo and cb.has_status(StatusEffects.Id.PRINGADO), caja, 1, AmbarAire.Modo.PRINGUE, true)
		_uno(arena, _picor, cb, vivo and cb.has_status(StatusEffects.Id.PICOR), caja, 1, AmbarAire.Modo.PICOR, true)
		_uno(arena, _carga, cb, vivo and _cargando_geiser(cb), caja, 1, TrentAire.Modo.CARGA, false)
		_uno(arena, _seco, cb, tramos > 0, caja, tramos, TrentAire.Modo.SECO, false)
		# LA CAPA DE AMBAR de los tuyos (set Ambar): al romperse, el mismo estallido de grumos que la costra del Tocon.
		if cb.costra_max > 0.0 and _t._pantalla._aliados.has(cb):
			var tenia: bool = bool(_capa.get(cb, cb.costra_vista() > 0.0))
			if tenia and cb.costra_vista() <= 0.0 and vivo:
				TrentAire.estallido(arena, caja, _t._cod(cb) + randi() % 97)
			_capa[cb] = cb.costra_vista() > 0.0


func _tick_puntos(arena: ArenaCombate, c: Combatant, vivo: bool) -> void:
	var n = _puntos.get(c)
	if not vivo or c.costra_max <= 0.0:
		if n != null:
			if is_instance_valid(n):
				n.secar()
			_puntos.erase(c)
		return
	# Encima de lo que se ve: los tuyos, del muñeco entero (su caja de choque es solo la parte de abajo).
	var m = (_t.cuerpo_de(c) as Node2D).get("_muneco")
	var caja: Rect2 = _t.rect_dibujo_entero(m) if m is Node2D else Rect2()
	if not caja.has_area():
		caja = _t.bulto_visual(c)
	if n == null or not is_instance_valid(n):
		n = AranaAire.puntos(arena, caja, _t._cod(c))
		_puntos[c] = n
	n.seguir(caja)
	var tope: int = maxi(c.costra_turnos, 1)
	n.poner_nivel(tope if c.costra_vista() > 0.0 else tope - clampi(c.costra_espera, 0, tope), tope)


# Pone, sigue o seca el de 'c' en 'tabla' (de TrentAire o, con 'de_ambar', de AmbarAire). 'nivel': las cargas del humo,
# los tramos de lo seco.
func _uno(arena: ArenaCombate, tabla: Dictionary, c: Combatant, quiere: bool, caja: Rect2, nivel: int, modo: int,
		de_ambar: bool) -> void:
	var n = tabla.get(c)
	var hay: bool = n != null and is_instance_valid(n)
	if quiere:
		if not hay:
			var cu_g: Node2D = _t.cuerpo_de(c)
			var spr_g = cu_g.get("_sprite") if cu_g != null else null
			n = AmbarAire.pegado(arena, modo, caja, _t._cod(c)) if de_ambar \
				else TrentAire.pegado(arena, modo, caja, nivel, _t._cod(c), spr_g as AnimatedSprite2D if spr_g is AnimatedSprite2D else null)
			if n == null:
				return
			tabla[c] = n
		n.call("seguir", caja)
		if not de_ambar:
			n.call("poner_nivel", nivel)
	elif n != null:
		tabla.erase(c)
		if hay:
			n.call("secar")


# El Geiser cargando: su animacion de carga en marcha (viaja con el gesto: lo ven todos).
func _cargando_geiser(c: Combatant) -> bool:
	var cu: Node2D = _t.cuerpo_de(c)
	var spr = cu.get("_sprite") if cu != null else null
	return spr is AnimatedSprite2D and String((spr as AnimatedSprite2D).animation).begins_with("geiser_carga")


# Al cerrar la pelea: todo fuera.
func quitar() -> void:
	for tabla in [_resina, _humo, _pringue, _picor, _carga, _seco]:
		for c in tabla.keys():
			if is_instance_valid(tabla[c]):
				(tabla[c] as Node).queue_free()
		tabla.clear()
	_capa.clear()
	for c in _puntos.keys():
		if is_instance_valid(_puntos[c]):
			(_puntos[c] as Node).queue_free()
	_puntos.clear()
