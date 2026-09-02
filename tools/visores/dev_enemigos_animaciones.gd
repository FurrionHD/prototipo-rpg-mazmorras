# ============================================================
#  dev_enemigos_animaciones.gd  -- EL VISOR DE ANIMACIONES DE MOVIMIENTO
#  El hermano de dev_enemigos_ataques.gd (que enseña los GOLPES): este enseña como se ve el
#  enemigo ANDANDO por el mapa -- idle, deambular/perseguir y la embestida, en las 8 direcciones --
#  y ademas COMO ENCAJA Y COMO MUERE, que son las que menos se ven jugando y las que mas falta hace
#  poder mirar despacio. Las que no son ciclicas se repiten solas tras una pausa.
#  Nace con los slimes (SlimeSprites, dibujado por codigo) pero lee TODOS los EnemyData: en cuanto
#  otro bicho tenga sprite_frames (real o generado), sale aqui solo.
#
#  Se lanza con:
#    Godot_v4.7-stable_win64.exe --path . res://tools/visores/dev_enemigos_animaciones.tscn
#
#  TECLAS
#    ESPACIO / →   siguiente animacion (solo las que TIENE este bicho)   ←   la anterior
#    A / D         girar la direccion (una de las 8)
#    B / V         siguiente / anterior ENEMIGO (salta a los que tengan sprite)
#    P             parar / seguir el avance de frame
#    +/-           mas lento / mas rapido
#    F12            guarda una captura en user://capturas
# ============================================================

extends Node2D

const DIR_ENEMIGOS := "res://scenes/actors/enemy"
# LAS ANIMACIONES DE ESTE BICHO. No hay lista fija: se recalcula cada vez que se cambia de enemigo.
#
# MUERTE y CADAVER estan aqui aunque no sean animaciones de MOVIMIENTO, que es lo que dice el nombre
# de este visor. Se meten porque son las que mas falta hace mirar y las que menos se ven jugando: la
# muerte pasa una vez, deprisa y en mitad de un combate, y el cadaver solo aparece si vuelves a una
# sala. Este es el unico sitio donde se pueden juzgar.
#
# SE SACA DEL BICHO QUE SE ESTA MIRANDO, Y SOLO DE ESE. Antes era una lista escrita a mano aqui, y
# una lista a mano en la herramienta de MIRAR es la peor de todas: cuando alguien añade una animacion
# a un generador, el sitio donde iria a comprobar que ha quedado bien es justamente el que no la
# conoce -- el bicho la tiene, el juego la reproduce, y el visor la esconde.
#
# PERO TAMPOCO VALE JUNTAR LAS DE TODOS. Se probo, y con veintitantos nombres en la lista comun había
# que pasar por 'cornada', 'pisoton', 'brote', 'telarana'... para llegar a la muerte de un bicho que
# tiene cinco animaciones. La pantalla avisaba de "este enemigo no tiene X", asi que no engañaba,
# pero recorrer dieciocho carteles de error para ver cinco poses es peor herramienta que la de antes.
#
# El ORDEN de ORDEN_BASE es el que importa (idle y walk primero, muerte y cadaver al final); las
# propias del bicho van detras, ordenadas, asi que una animacion nueva aparece sola el dia que se
# crea y solo en el bicho que la tiene.
const ORDEN_BASE := ["idle", "walk", "embestida", "encaje", "muerte", "cadaver"]
var ANIMS: Array = ORDEN_BASE.duplicate()


# Las animaciones de ESTE bicho, sin la direccion (el "_3" del final). Se recalcula al cambiar de
# enemigo con B/V.
func _censar_anims() -> void:
	var frames: SpriteFrames = _frames_de(_lista[_idx])
	if frames == null:
		ANIMS = ORDEN_BASE.duplicate()      # sin sprite: la lista de siempre, para poder navegar
		_anim_i = 0
		return
	var vistas: Dictionary = {}
	for a in frames.get_animation_names():
		# "embestida_3" -> "embestida". Se corta por el ULTIMO guion bajo y solo si lo que hay detras
		# es un numero: si no, un nombre con guion bajo dentro se quedaria a medias.
		var n: String = String(a)
		var i: int = n.rfind("_")
		if i > 0 and n.substr(i + 1).is_valid_int():
			n = n.substr(0, i)
		vistas[n] = true
	var extra: Array = []
	for n in vistas:
		if not ORDEN_BASE.has(n):
			extra.append(n)
	extra.sort()
	ANIMS = []
	for n in ORDEN_BASE:
		if vistas.has(n):
			ANIMS.append(n)
	ANIMS.append_array(extra)
	if ANIMS.is_empty():
		ANIMS = ORDEN_BASE.duplicate()
	# AL CAMBIAR DE BICHO SE INTENTA SEGUIR EN LA MISMA ANIMACION. Comparando bichos se mira lo mismo
	# en los dos (el andar de este contra el andar del otro), y volver a 'idle' en cada salto obliga a
	# rehacer el camino cada vez. Si el nuevo no la tiene, al principio.
	var antes: String = String(_anim_actual)
	_anim_i = maxi(0, ANIMS.find(antes))
	_anim_actual = ANIMS[_anim_i]


# Lo que espera antes de repetir una animacion que NO es ciclica (embestida, encaje, muerte...).
# Sin esto se quedan clavadas en su ultimo fotograma y hay que cambiar de animacion y volver para
# verlas otra vez -- justo en las que hay que mirar varias veces porque duran medio segundo. La
# pausa existe para que dé tiempo a ver la pose final antes de que vuelva a empezar.
const PAUSA_REPETIR := 0.7
const DIR_NOMBRES := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const DIR_VECS := [
	Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0), Vector2(0.7, -0.7),
	Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(-1, 0), Vector2(-0.7, 0.7),
]
const RASTRO_INTERVALO := 0.35

var _lista: Array = []   # de EnemyData
var _idx := 0
var _dir := 0
var _anim_i := 0
# El NOMBRE de la animacion elegida, aparte del indice: al cambiar de bicho la lista cambia de
# tamaño y de contenido, asi que el indice solo no dice en que estabas (ver _censar_anims).
var _anim_actual: String = "idle"
var _vel := 1.0
var _auto := true

var _sprite: AnimatedSprite2D
var _placeholder: ColorRect
var _flecha: Line2D
var _titulo: Label
var _sub: Label
var _ayuda: Label
var _rastro_timer: float = 0.0
# Cuenta atras para volver a lanzar una animacion no ciclica que ya ha terminado. <= 0 = nada que
# repetir (o esta corriendo una ciclica, que no termina nunca).
var _repetir_en: float = 0.0

const CENTRO := Vector2(640, 340)


func _ready() -> void:
	_cargar_enemigos()
	if _lista.is_empty():
		push_error("[visor animaciones] no he encontrado ningun EnemyData en %s" % DIR_ENEMIGOS)
		get_tree().quit()
		return
	_censar_anims()

	var fondo := ColorRect.new()
	fondo.size = Vector2(1280, 720)
	fondo.color = Color(0.11, 0.12, 0.15)
	add_child(fondo)

	_placeholder = ColorRect.new()
	_placeholder.size = Vector2(32, 32)
	_placeholder.position = CENTRO - _placeholder.size * 0.5
	_placeholder.visible = false
	add_child(_placeholder)

	_sprite = AnimatedSprite2D.new()
	_sprite.position = CENTRO
	# Bien grande en pantalla ("ver facil"), calculado a partir del tamaño real de la textura y no
	# de un factor fijo: si SlimeSprites cambia de resolucion, esto no se descuadra.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # o el pixel-art sale borroso
	add_child(_sprite)   # el zoom se pone por bicho en _mostrar: cada uno tiene su propia rejilla
	# Las animaciones ciclicas NO emiten esto nunca, asi que la repeticion solo la arrancan las que
	# terminan de verdad: embestida, encaje, muerte, cadaver.
	_sprite.animation_finished.connect(func() -> void: _repetir_en = PAUSA_REPETIR)

	_flecha = Line2D.new()
	_flecha.width = 3.0
	_flecha.default_color = Color(1, 1, 1, 0.6)
	add_child(_flecha)

	_titulo = Label.new()
	_titulo.position = Vector2(24, 20)
	_titulo.add_theme_font_size_override("font_size", 30)
	_titulo.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	add_child(_titulo)
	_sub = Label.new()
	_sub.position = Vector2(24, 60)
	_sub.add_theme_font_size_override("font_size", 17)
	_sub.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82))
	add_child(_sub)
	_ayuda = Label.new()
	_ayuda.position = Vector2(24, 668)
	_ayuda.add_theme_font_size_override("font_size", 15)
	_ayuda.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
	_ayuda.text = "ESPACIO/→ animacion   ← anterior   A/D direccion   B/V enemigo   P pausa   +/- velocidad"
	add_child(_ayuda)

	_mostrar()


# Igual que dev_enemigos_ataques._cargar_bichos: lee todos los .tres, ordenados por nombre de
# archivo para que el recorrido sea siempre el mismo.
func _cargar_enemigos() -> void:
	var d := DirAccess.open(DIR_ENEMIGOS)
	if d == null:
		return
	var archivos: Array = []
	for f in d.get_files():
		var n: String = f.trim_suffix(".remap")
		if n.ends_with(".tres"):
			archivos.append(n)
	archivos.sort()
	for n in archivos:
		var ed = load("%s/%s" % [DIR_ENEMIGOS, n])
		if ed != null and ed is EnemyData:
			_lista.append(ed)


# El visor NO decide nada por su cuenta: pregunta al mismo sitio que el juego (SpritesEnemigo). Si
# tuviera su propia copia de la regla acabarian divergiendo y estaria enseñando algo que en la
# mazmorra no se ve -- justo lo contrario de para lo que sirve.
func _frames_de(ed: EnemyData) -> SpriteFrames:
	return SpritesEnemigo.frames_de(ed, 1.0)


func _process(delta: float) -> void:
	if not _auto or not _sprite.visible:
		return
	# REPETIR las que no son ciclicas, pasada su pausa (ver PAUSA_REPETIR).
	if _repetir_en > 0.0:
		_repetir_en -= delta
		if _repetir_en <= 0.0 and _sprite.sprite_frames != null \
				and _sprite.sprite_frames.has_animation(_sprite.animation):
			_sprite.play(_sprite.animation)
	if ANIMS[_anim_i] == "walk":
		_rastro_timer -= delta * _vel
		if _rastro_timer <= 0.0:
			_rastro_timer = RASTRO_INTERVALO
			Particulas.marca_en_suelo(self, _sprite.position, _lista[_idx].color_visual(1.0))


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var k: int = (ev as InputEventKey).keycode
	if k == KEY_SPACE or k == KEY_RIGHT:
		_anim_i = (_anim_i + 1) % ANIMS.size()
		_anim_actual = ANIMS[_anim_i]
		_mostrar()
	elif k == KEY_LEFT:
		_anim_i = (_anim_i - 1 + ANIMS.size()) % ANIMS.size()
		_anim_actual = ANIMS[_anim_i]
		_mostrar()
	elif k == KEY_A:
		_dir = (_dir - 1 + 8) % 8
		_mostrar()
	elif k == KEY_D:
		_dir = (_dir + 1) % 8
		_mostrar()
	elif k == KEY_B:
		_idx = (_idx + 1) % _lista.size()
		_censar_anims()
		_mostrar()
	elif k == KEY_V:
		_idx = (_idx - 1 + _lista.size()) % _lista.size()
		_censar_anims()
		_mostrar()
	elif k == KEY_P:
		_auto = not _auto
		_sprite.speed_scale = 0.0 if not _auto else _vel
	elif k == KEY_EQUAL or k == KEY_KP_ADD:
		_vel = minf(_vel * 1.35, 4.0)
		_sprite.speed_scale = _vel
	elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		_vel = maxf(_vel / 1.35, 0.15)
		_sprite.speed_scale = _vel
	elif k == KEY_F12:
		_foto()
	elif k == KEY_ESCAPE:
		get_tree().quit()


func _mostrar() -> void:
	var ed: EnemyData = _lista[_idx]
	var frames: SpriteFrames = _frames_de(ed)
	var nota: String = ""
	if frames == null:
		_sprite.visible = false
		_placeholder.visible = true
		_placeholder.color = ed.color_visual(1.0)
		_flecha.visible = false
	else:
		_placeholder.visible = false
		_sprite.visible = true
		_sprite.sprite_frames = frames
		_sprite.scale = Vector2.ONE * SpritesEnemigo.zoom_visor(ed, 420.0)
		_sprite.speed_scale = _vel if _auto else 0.0
		# Misma degradacion que en el juego: si la animacion no tiene ESTA direccion se cae a la 0.
		# 'encaje' y 'muerte' son de una sola direccion a proposito (en combate solo se ve de frente),
		# asi que girar con A/D sobre ellas tiene que seguir enseñando algo.
		var anim: String = "%s_%d" % [ANIMS[_anim_i], _dir]
		if not frames.has_animation(anim):
			anim = "%s_0" % ANIMS[_anim_i]
			nota = "   (una sola direccion)" if frames.has_animation(anim) else ""
		if frames.has_animation(anim):
			_repetir_en = 0.0
			_sprite.play(anim)
		else:
			_sprite.stop()
			nota = "   ⚠ este enemigo no tiene '%s'" % ANIMS[_anim_i]
		_flecha.visible = true
		_flecha.points = PackedVector2Array([CENTRO, CENTRO + DIR_VECS[_dir] * 90.0])

	_titulo.text = "%s  ·  %s (%s)" % [ed.enemy_name, ANIMS[_anim_i], DIR_NOMBRES[_dir]]
	var aviso: String = nota if frames != null else "   ⚠ sin sprite: placeholder ColorRect (como en el mapa)"
	_sub.text = "bicho %d/%d   ·   anim %d/%d      x%.2f%s%s" % [_idx + 1, _lista.size(),
		_anim_i + 1, ANIMS.size(), _vel, "" if _auto else "   (PAUSA)", aviso]


func _foto() -> void:
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var img: Image = get_viewport().get_texture().get_image()
	var ed: EnemyData = _lista[_idx]
	var nom: String = String(ed.enemy_name).to_lower().replace(" ", "_")
	var f: String = "user://capturas/anim_%s_%s_%s.png" % [nom, ANIMS[_anim_i], DIR_NOMBRES[_dir]]
	img.save_png(f)
	print("[visor animaciones] ", ProjectSettings.globalize_path(f))
