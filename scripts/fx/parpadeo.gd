# ============================================================
#  parpadeo.gd  (class_name Parpadeo)
#  EL PARPADEO (05/10, lo pidio el jefe para los slimes: "que los ojos vayan sueltos del sprite, para que parpadee y que
#  no sea una vez por repeticion de la animacion, porque estaria parpadeando cada segundo").
#  Una capa HIJA del sprite del enemigo con la hoja de los PARPADOS (solo los ojos cerrados, sacada del mismo modelo:
#  ver tools/sprites_sdf, PARPADOS). Copia la animacion y el fotograma del sprite y SOLO se ve mientras parpadea: un
#  rato corto cada pocos segundos, al azar, asi que cada enemigo parpadea a su aire y no al ritmo de su animacion.
#  Al ser hija hereda la posicion, la escala y el tinte (el latido del mutante, el aviso del golpe).
# ============================================================
extends AnimatedSprite2D
class_name Parpadeo

const NOMBRE := "Parpados"
const CERRADO := 0.13          # lo que dura con los ojos cerrados
const ESPERA_MIN := 2.0        # entre parpadeo y parpadeo, al azar entre estos dos
const ESPERA_MAX := 6.0

var _principal: AnimatedSprite2D = null
var _espera: float = 0.0
var _cerrado: float = -1.0


# Le pone (o le cambia) los parpados a 'sprite'. Sin hoja de parpados, se los quita.
static func poner(sprite: AnimatedSprite2D, frames: SpriteFrames) -> void:
	if sprite == null:
		return
	var p: Parpadeo = sprite.get_node_or_null(NOMBRE) as Parpadeo
	if frames == null:
		if p != null:
			p.queue_free()
		return
	if p == null:
		p = Parpadeo.new()
		p.name = NOMBRE
		sprite.add_child(p)
	p._principal = sprite
	p.sprite_frames = frames
	p.texture_filter = sprite.texture_filter


func _ready() -> void:
	visible = false
	_espera = randf_range(0.3, ESPERA_MAX)   # que no empiecen todos a la vez


func _process(delta: float) -> void:
	if _principal == null or not is_instance_valid(_principal):
		return
	if _cerrado >= 0.0:
		_cerrado -= delta
		if _cerrado < 0.0:
			visible = false
			_espera = randf_range(ESPERA_MIN, ESPERA_MAX)
		else:
			_copiar()
		return
	_espera -= delta
	if _espera <= 0.0 and _puede():
		_cerrado = CERRADO
		_copiar()


# Muerto no parpadea (tirado con los ojos cerrados de golpe quedaria raro), ni en lo que no tenga parpados.
func _puede() -> bool:
	var a: String = String(_principal.animation)
	if a.begins_with("muerte") or a.begins_with("cadaver"):
		return false
	return sprite_frames != null and sprite_frames.has_animation(_principal.animation)


func _copiar() -> void:
	if not _puede():
		visible = false
		return
	if animation != _principal.animation:
		animation = _principal.animation
	frame = _principal.frame
	centered = _principal.centered
	offset = _principal.offset
	flip_h = _principal.flip_h
	visible = true
