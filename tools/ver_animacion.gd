# ============================================================
#  ver_animacion.gd  --  HERRAMIENTA, no parte del juego.
#
#  Saca una TIRA PNG con los fotogramas de una animacion, uno al lado del otro y ampliados, para
#  poder MIRARLA. El visor con ventana (herramientas/ver_enemigos_animaciones.bat) sirve para ver el movimiento;
#  esto sirve para lo otro: juzgar frame a frame, que es lo que hace falta cuando se esta dibujando
#  una animacion nueva y hay que decidir si un aplaston se pasa o se queda corto.
#
#  Cada frame se compone en su LIENZO ENTERO (region + margin del AtlasTexture), no en su recorte:
#  si se pegaran los recortes a secas, cada uno saldria centrado en si mismo y la tira mentiria
#  justo sobre lo unico que importa aqui -- cuanto se mueve el bicho de un frame al siguiente.
#
#  Se lanza con herramientas/ver_animacion.bat [enemigo] [anim] [dir], p.ej.:
#      herramientas/ver_animacion.bat slime encaje
#      herramientas/ver_animacion.bat rey_slime muerte
#  No toca nada del juego: solo escribe en tools/salida/.
#
#  Va como ESCENA (Node) y no como script suelto de SceneTree: con '--script' Godot no arranca los
#  autoloads, y EnemyData usa Game, asi que ni siquiera compila.
# ============================================================
extends Node

const DIR_ENEMIGOS := "res://scenes/actors/enemy/"
const SALIDA := "res://tools/salida/"
const ZOOM := 4                       # el pixel-art a tamaño real no se puede juzgar en un PNG
const HUECO := 4                      # celdas de separacion entre fotogramas, ya ampliadas
const FONDO := Color(0.11, 0.12, 0.15)


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var enemigo: String = args[0] if args.size() > 0 else "slime"
	var anim: String = args[1] if args.size() > 1 else "encaje"
	var dir: int = int(args[2]) if args.size() > 2 else 0

	var ed = load(DIR_ENEMIGOS + enemigo + ".tres")
	if ed == null or not (ed is EnemyData):
		push_error("[ver animacion] no encuentro %s%s.tres" % [DIR_ENEMIGOS, enemigo])
		get_tree().quit(1)
		return
	var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 1.0)
	if sf == null:
		push_error("[ver animacion] %s no tiene sprite generado" % enemigo)
		get_tree().quit(1)
		return

	# Degradacion igual que la del juego: una animacion de UNA sola direccion (encaje, muerte) se
	# pide por su nombre completo y se cae a la 0 si esa direccion no existe.
	var nom: String = "%s_%d" % [anim, dir]
	if not sf.has_animation(nom):
		nom = "%s_0" % anim
	if not sf.has_animation(nom):
		push_error("[ver animacion] %s no tiene la animacion '%s'. Tiene: %s"
			% [enemigo, anim, ", ".join(sf.get_animation_names())])
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(SALIDA)
	var tira: Image = _tira(sf, nom)
	var ruta: String = "%stira_%s_%s.png" % [SALIDA, enemigo, nom]
	tira.save_png(ruta)
	print("[ver animacion] %s  ·  %d fotogramas a %.0f fps%s"
		% [nom, sf.get_frame_count(nom), sf.get_animation_speed(nom),
			"  (loop)" if sf.get_animation_loop(nom) else ""])
	print("[ver animacion] ", ProjectSettings.globalize_path(ruta))
	get_tree().quit()


func _tira(sf: SpriteFrames, nom: String) -> Image:
	var n: int = sf.get_frame_count(nom)
	# El lienzo del bicho: region + margin es lo que la textura APARENTA medir (ver montar_frames).
	var uno: AtlasTexture = sf.get_frame_texture(nom, 0) as AtlasTexture
	var w: int = int(uno.region.size.x + uno.margin.size.x)
	var h: int = int(uno.region.size.y + uno.margin.size.y)

	# EL RECORTE COMUN A TODOS LOS FOTOGRAMAS: la caja que los contiene a todos, y no el lienzo
	# entero. El lienzo lleva el aire que necesitan las animaciones mas amplias -- el trent, que se
	# dibuja tumbado, es cuatro veces mas ancho que el arbol --, asi que enseñandolo entero el bicho
	# sale de miniatura en mitad de un fondo vacio. Se recorta a la vez para todos, no uno a uno,
	# porque lo que hay que poder juzgar aqui es cuanto se mueve de un fotograma al siguiente.
	var caja := Rect2i(w, h, 0, 0)
	for i in n:
		var a0: AtlasTexture = sf.get_frame_texture(nom, i) as AtlasTexture
		var r0 := Rect2i(Vector2i(a0.margin.position), Vector2i(a0.region.size))
		caja = r0 if i == 0 else caja.merge(r0)
	caja = caja.grow(2).intersection(Rect2i(0, 0, w, h))
	var out := Image.create((caja.size.x * ZOOM + HUECO) * n + HUECO, caja.size.y * ZOOM + HUECO * 2,
		false, Image.FORMAT_RGBA8)
	out.fill(FONDO)
	for i in n:
		var at: AtlasTexture = sf.get_frame_texture(nom, i) as AtlasTexture
		var lienzo := Image.create(w, h, false, Image.FORMAT_RGBA8)
		lienzo.fill(Color(0, 0, 0, 0))
		var src: Image = at.atlas.get_image()
		src.convert(Image.FORMAT_RGBA8)
		lienzo.blit_rect(src, Rect2i(at.region), Vector2i(at.margin.position))
		var amp: Image = lienzo.get_region(caja)
		amp.resize(caja.size.x * ZOOM, caja.size.y * ZOOM, Image.INTERPOLATE_NEAREST)
		var x0: int = HUECO + i * (caja.size.x * ZOOM + HUECO)
		# El fondo debajo de cada frame, para que las zonas transparentes no salgan negras.
		out.blend_rect(amp, Rect2i(0, 0, amp.get_width(), amp.get_height()), Vector2i(x0, HUECO))
	return out
