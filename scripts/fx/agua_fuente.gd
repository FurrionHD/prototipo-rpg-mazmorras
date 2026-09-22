# ============================================================
#  agua_fuente.gd  (class_name AguaFuente)
#  EL AGUA QUE SE MUEVE de la fuente de la plaza: el chorro de la taza, las cortinas que caen al pilon,
#  las ondas y las salpicaduras. Son fotogramas del tamaño del dibujo de la fuente
#  (PlazaSprites.agua_fotograma) que se pintan encima de ella, con el mismo encuadre: basta con ponerlo
#  en la esquina de la pieza. Mismo planteamiento que la llama del altar (LlamaAltar): una animacion
#  dibujada por codigo, no particulas.
# ============================================================
extends AnimatedSprite2D
class_name AguaFuente

static var _frames: SpriteFrames = null


static func crear() -> AguaFuente:
	var a := AguaFuente.new()
	a.name = "Agua"
	a.sprite_frames = _fotogramas()
	a.centered = false
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return a


func _ready() -> void:
	play("corre")


static func _fotogramas() -> SpriteFrames:
	if _frames != null:
		return _frames
	var sf := SpriteFrames.new()
	sf.add_animation("corre")
	sf.set_animation_loop("corre", true)
	sf.set_animation_speed("corre", PlazaSprites.AGUA_FPS)
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for k in PlazaSprites.AGUA_FOTOGRAMAS:
		sf.add_frame("corre", ImageTexture.create_from_image(PlazaSprites.agua_fotograma(k)))
	_frames = sf
	return _frames
