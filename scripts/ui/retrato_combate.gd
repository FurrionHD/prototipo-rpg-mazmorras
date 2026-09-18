# ============================================================
#  retrato_combate.gd  (sin class_name: se usa por preload)
#  EL RETRATO PEQUEÑO DE UN COMBATIENTE: la cara que va en cada casilla de la barra de turnos.
#
#  Hasta el 18/09/2026 esas casillas eran un cuadrado de color (con tu foto encima si la llevabas):
#  cuatro aliados sin foto eran cuatro cuadrados casi iguales y un enemigo era su color y un numero.
#  El usuario lo pidio asi:
#    - TUS personajes: tu FOTO si la tienes; si no, TU CARA -- la cabeza del muñeco con sus ojos, su
#      boca y su pelo, y SIN la armadura: con un casco puesto la casilla seria un casco, y lo que
#      tiene que decir es QUIEN es.
#    - LOS ENEMIGOS: algo que se reconozca de un vistazo. Es su propio sprite, el primer fotograma,
#      recortado a lo que se ve (sin el aire que traen los fotogramas del horno).
#
#  Vive aqui y no en turn_timeline porque la miniatura del enemigo ya existia en la ficha de detalle
#  (combate_detalle.gd) y dos copias de ese recorte se separan a la primera que se toque una.
# ============================================================
extends RefCounted

# Cuanto de la cabeza entra en el retrato, en pixeles de sprite (la cabeza con su pelo mide ~26).
const VENTANA_CABEZA := 23.0
# Cuanto se baja el encuadre desde el centro de la cabeza, en fraccion del lado: la cara esta en la
# mitad de abajo (arriba es pelo), asi que centrar en la cabeza dejaria la cara en el borde.
const BAJA_CARA := 0.30


# Rellena 'padre' (un Control cuadrado, con clip) con el retrato de 'c'. Devuelve si ha pintado algo;
# si no, quien llama se queda con el color que ya tuviera de fondo.
static func poner(padre: Control, c: Combatant) -> bool:
	var pj: PersonajeData = Game.pj_de_combatant(c)
	if pj != null:
		var foto: Texture2D = pj.textura()
		if foto != null:
			padre.add_child(_textura(foto, false))
			return true
		return _cara_de_muneco(padre, pj)
	var mini: Texture2D = miniatura_enemigo(c)
	if mini != null:
		padre.add_child(_textura(mini, true))
		return true
	return false


# El primer fotograma del enemigo, RECORTADO A LO QUE SE VE. Devuelve null si no tiene sprite (los
# que siguen siendo un cuadrado de color), y entonces se pinta su color.
#
# Los fotogramas del horno traen mucho aire transparente (el sitio que necesitan las animaciones que
# se mueven), asi que en pequeño el bicho salia como una mota: el jabali y el trent eran ilegibles.
# Se busca la caja util de la imagen y se pinta solo esa.
static func miniatura_enemigo(c: Combatant) -> Texture2D:
	if c == null or c.sprite_res == "" or not ResourceLoader.exists(c.sprite_res):
		return null
	var ed: EnemyData = load(c.sprite_res) as EnemyData
	if ed == null:
		return null
	var frames: SpriteFrames = SpritesEnemigo.frames_de(ed, c.sprite_t)
	if frames == null or not frames.has_animation(&"idle_0"):
		return null
	var tex: Texture2D = frames.get_frame_texture(&"idle_0", 0)
	var at := tex as AtlasTexture
	if at == null or at.atlas == null:
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var usado: Rect2i = img.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return tex
	var recorte := AtlasTexture.new()
	recorte.atlas = at.atlas
	recorte.region = Rect2(at.region.position + Vector2(usado.position), Vector2(usado.size))
	return recorte


static func _textura(tex: Texture2D, pixel: bool) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_LINEAR
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# TU CARA SACADA DEL MUÑECO. Se monta un personaje de mentira con SOLO tu aspecto (piel, ojos, boca,
# pelo y ropa) y nada de equipo: sin armadura ni casco ni arma, que en un cuadrado de 40 px taparian
# justo lo que sirve para reconocerte. Y se encuadra la CABEZA, no el cuerpo entero.
static func _cara_de_muneco(padre: Control, pj: PersonajeData) -> bool:
	var solo := PersonajeData.new()
	solo.color = pj.color
	solo.aspecto = PersonajeData.aspecto_nuevo(pj.color)
	solo.aplicar_aspecto({"piezas": pj.aspecto_completo()["piezas"]})
	var m := MunecoJugador.new()
	m.montar(solo)
	m.tenir(solo.color, 0.0)
	if not m.hay_dibujo():
		m.free()
		return false
	var hueco := Control.new()
	hueco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hueco.clip_contents = true
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(hueco)
	hueco.add_child(m)
	_z_relativo(m)
	# De frente y QUIETO: un retrato que respira hace bailar la barra entera.
	m.fijar("idle_0", 0)

	# Donde cae el centro de la cabeza respecto al NODO del muñeco, en unidades de mundo. El nodo esta
	# a la altura de los pies menos PIES_BAJO_NODO (ver PoseJugador.offset_sprite), y el centro de la
	# cabeza sale de la misma cuenta que usan los ojos (CaraSprites.centro_cabeza), asi el retrato
	# encuadra exactamente la cabeza que se dibuja.
	var esq: Dictionary = PoseJugador.esqueleto("idle", 0, 0)
	var cab_px: Vector2 = Vector2(CaraSprites.centro_cabeza(esq)) + Vector2(0.5, 0.5)
	var rel: Vector2 = (cab_px - PoseJugador.origen()) * PoseJugador.escala_sprite() \
		+ Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
	var colocar := func() -> void:
		var z: Vector2 = hueco.size
		if z.x <= 1.0 or z.y <= 1.0:
			return
		var lado: float = minf(z.x, z.y)
		var k: float = lado / (VENTANA_CABEZA * PoseJugador.escala_sprite())
		m.scale = Vector2.ONE * k
		m.position = z * 0.5 + Vector2(0.0, -lado * BAJA_CARA) - rel * k
	hueco.resized.connect(colocar)
	colocar.call()
	return true


# DEVUELVE EL MUÑECO AL Z RELATIVO, que es lo unico que hace falta para que se VEA dentro de una UI.
# MunecoJugador nace con z_as_relative = false a proposito (en el mapa sus capas se ordenan contra el
# mundo), y en su _ready lo pone; asi que si todavia no ha corrido, hay que esperarle. Mismo arreglo
# que la tira de retratos de combate_detalle.gd.
static func _z_relativo(m: MunecoJugador) -> void:
	m.z_as_relative = true
	m.z_index = 0
	if m.is_node_ready():
		return
	m.ready.connect(func() -> void:
		m.z_as_relative = true
		m.z_index = 0, CONNECT_ONE_SHOT)
