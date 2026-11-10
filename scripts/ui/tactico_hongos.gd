# ============================================================
#  tactico_hongos.gd  (class_name TacticoHongos)
#  LOS FLORECIDOS EN EL MAPA DE LA PELEA (09/11/2026, miconido-mutante, parte C): a quien lleva el estado FLORECIDO le
#  brotan las setas por arriba (HongosPixel) y su cuerpo se apaga (gris de muerto). El gris va en el SELF_MODULATE de su
#  sprite: el modulate lo reescriben otros (el aviso del golpe en enemy/remote_enemy, y en la pelea el bicho esta en
#  pausa) y el self_modulate se multiplica encima sin pisar a nadie. Como TacticoTrent: lo crea CombatTactico y lo llama
#  cada fotograma; todo sale del ESTADO, que ya viaja al espejo.
# ============================================================
extends RefCounted
class_name TacticoHongos

const MARCA := &"florecido"
const TINTE := Color(0.62, 0.66, 0.58)   # el gris de muerto (la lamina: menos color y mas oscuro)

var _t = null   # CombatTactico
var _setas: Dictionary = {}   # Combatant -> HongosPixel


func _init(t) -> void:
	_t = t


func tick() -> void:
	var arena: ArenaCombate = _t._arena()
	if arena == null:
		return
	for c in _t._pantalla._enemies:
		var cb: Combatant = c
		var cuerpo: Node2D = _t.cuerpo_de(cb)
		var quiere: bool = cb.is_alive() and cuerpo != null and cuerpo.visible and cb.has_status(StatusEffects.Id.FLORECIDO)
		if cuerpo != null:
			if quiere:
				# tu personaje florecido: su muñeco de pie (en el espejo lo tumbo su caida)
				if _t.cuerpo_prestado(cb):
					_t.levantar_prestado(cb)
				cuerpo.set_meta(MARCA, true)
				_gris(cuerpo, TINTE)
			elif cuerpo.has_meta(MARCA):
				cuerpo.remove_meta(MARCA)
				_gris(cuerpo, Color.WHITE)
		var n = _setas.get(cb)
		if quiere:
			if n == null or not is_instance_valid(n):
				n = HongosPixel.poner(arena, _t.bulto_visual(cb), _t._cod(cb), _sprite_de(cuerpo))
				_setas[cb] = n
			if n != null:
				n.seguir(_t.bulto_visual(cb), _sprite_de(cuerpo))
		elif n != null:
			_setas.erase(cb)
			if is_instance_valid(n):
				n.secar()


# El dibujo donde se clavan las setas (10/11): el sprite del bicho, o en tu personaje florecido la capa del CUERPO de
# su muñeco (la piel: va debajo de todo y la ropa se le pega).
static func _sprite_de(cuerpo: Node2D) -> AnimatedSprite2D:
	var mu = cuerpo.get("_muneco")
	if mu is MunecoJugador:
		var s: AnimatedSprite2D = (mu as MunecoJugador).capa_nodo("cuerpo")
		if s != null:
			return s
	var spr = cuerpo.get("_sprite")
	return spr if spr is AnimatedSprite2D else null


func _gris(cuerpo: Node2D, col: Color) -> void:
	# El bicho: el self_modulate de su sprite (el dibujo es ese nodo).
	var spr = cuerpo.get("_sprite")
	if spr is CanvasItem:
		(spr as CanvasItem).self_modulate = col
	# TU PERSONAJE FLORECIDO: su MUÑECO. (09/11, la foto del cliente) El muñeco es un Node2D y lo que se ve son sus CAPAS
	# (AnimatedSprite2D hijos): el self_modulate no baja a los hijos y el gris no se veia. Su modulate si baja, y nadie mas
	# lo toca (cada capa lleva su color en SU modulate; los shaders de capa multiplican por COLOR, que ya lo trae).
	var mu = cuerpo.get("_muneco")
	if mu is CanvasItem:
		(mu as CanvasItem).modulate = col


# Al cerrar la pelea: todo fuera.
func quitar() -> void:
	for c in _setas.keys():
		var n = _setas[c]
		if is_instance_valid(n):
			n.secar()
	_setas.clear()
