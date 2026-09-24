# ============================================================
#  aura_capa.gd  (sin class_name: la carga MunecoJugador por preload)
#  LA COPIA DE UNA CAPA DEL MUÑECO sobre la que se pinta la imbuicion (shaders/aura_imbue.gdshader).
#
#  POR QUE NO ES UN AnimatedSprite2D, que era lo obvio: los fotogramas horneados van RECORTADOS a lo
#  dibujado (SpriteLienzo: un AtlasTexture con 'margin'), y un sprite solo pinta dentro de esa caja.
#  Para un arma eso es la caja del arma y NADA MAS: las llamas, los rayitos y las gotas, que viven
#  justo FUERA del dibujo, no tenian donde salir (lo que se vio en la primera hoja: la hoja cambiaba de
#  color y alrededor no salia nada).
#
#  Asi que aqui se dibuja el trozo de la hoja con AIRE alrededor (MARGEN pixeles por cada lado), y al
#  shader se le dice donde acaba el fotograma de verdad ('region', en UV del atlas): lo que caiga
#  fuera se lee como vacio, y el fotograma vecino de la hoja no se cuela.
# ============================================================
extends Node2D

# Cuanto aire alrededor del fotograma, en pixeles de textura: lo mas lejos que puede llegar una llama.
const MARGEN := 12.0

var desfase: Vector2 = Vector2.ZERO   # el 'offset' del sprite del que es copia
var _tex: Texture2D = null


func poner(tex: Texture2D) -> void:
	if tex == _tex:
		return
	_tex = tex
	queue_redraw()


func _draw() -> void:
	var at := _tex as AtlasTexture
	if at == null or at.atlas == null or not (material is ShaderMaterial):
		return
	var r: Rect2 = at.region
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var tam: Vector2 = at.atlas.get_size()
	(material as ShaderMaterial).set_shader_parameter("region",
		Vector4(r.position.x / tam.x, r.position.y / tam.y, r.end.x / tam.x, r.end.y / tam.y))
	var m := Vector2(MARGEN, MARGEN)
	var donde := Rect2(desfase + at.margin.position - m, r.size + m * 2.0)
	draw_texture_rect_region(at.atlas, donde, Rect2(r.position - m, r.size + m * 2.0))
