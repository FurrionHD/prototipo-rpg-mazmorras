# ============================================================
#  ver_jugador.gd  --  HERRAMIENTA, no parte del juego.
#
#  Saca HOJAS DE CONTACTO del personaje para poder MIRARLO. Es el hermano de ver_animacion.gd (que
#  saca tiras de un bicho) y cubre lo que aquel no puede: aqui lo que hay que juzgar no es solo el
#  movimiento, es que las OCHO DIRECCIONES se lean como el mismo cuerpo girando.
#
#  Dos modos:
#      ver_jugador.bat [animacion]     una hoja con las 8 direcciones (filas) x los fotogramas
#      ver_jugador.bat todas           una hoja con TODAS las animaciones, una por fila
#
#  Cada fotograma se compone en su LIENZO ENTERO (region + margin), no en su recorte: pegando los
#  recortes a secas cada uno saldria centrado en si mismo y la hoja mentiria justo sobre lo unico
#  que importa -- cuanto se mueve el personaje de un fotograma al siguiente y si las capas encajan.
#
#  APILA LAS CAPAS que se le pidan, que es para lo que existe de verdad: una capa suelta puede estar
#  perfecta y aun asi no encajar con las de debajo, y eso solo se ve apilado.
#
#  Va como ESCENA y no como script suelto: con '--script' Godot no arranca los autoloads.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const HUECO := 4
# El pixel-art a tamaño real no se puede juzgar en un PNG. 4 vale para ver el conjunto; para decidir
# si una pieza se despega de otra hace falta subirlo, y por eso va por argumento.
var ZOOM := 4
const FONDO := Color(0.11, 0.12, 0.15)
const DIR_NOMBRES := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var que: String = args[0] if args.size() > 0 else "idle"
	if args.size() > 1 and int(args[1]) > 0:
		ZOOM = clampi(int(args[1]), 1, 16)
	DirAccess.make_dir_recursive_absolute(SALIDA)

	var modelos := PackedStringArray()
	for i in range(2, args.size()):
		modelos.append(args[i])
	var capas: Array = _capas(modelos)
	if que == "todas":
		_hoja_animaciones(capas)
	else:
		_hoja_direcciones(capas, que)
	get_tree().quit()


# Las capas que se apilan, de abajo arriba. El cuerpo siempre; el pelo y la ropa, los que se pidan
# por argumento:
#
#     ver_jugador.bat idle 6 coleta camisa pantalon
#
# Sin argumentos sale el cuerpo desnudo, que es como estaba antes. Los nombres son los modelos de
# JugadorSprites.CATALOGO y se aceptan en cualquier orden: cada uno cae en su pieza solo.
#
# Se APILAN, que es para lo que existe de verdad esta herramienta: una capa suelta puede estar
# perfecta y aun asi no encajar con las de debajo.
func _capas(modelos: PackedStringArray) -> Array:
	var pedidos := {}
	var armaduras: Array = []
	for m in modelos:
		# LA ARMADURA NO ESTA EN EL CATALOGO, porque no es aspecto: es equipo, y sale de lo que lleves
		# puesto. Pero sin poder pedirla aqui no hay forma de sacar una hoja de contacto con un casco,
		# y sin hoja de contacto no se puede juzgar el dibujo. Se pide por TIPO y RANURA con un guion:
		#     ver_jugador.bat idle 6 casco_placas largo
		if "_" in m and ArmaduraSprites.SLOT_NOMBRE.has(m.get_slice("_", 0)):
			var slot: String = m.get_slice("_", 0)
			var tipo: String = m.trim_prefix(slot + "_")
			if ArmaduraSprites.TIPO_NOMBRE.has(tipo):
				armaduras.append(ArmaduraSprites.clave(tipo, slot))
				continue
		for pieza in JugadorSprites.CATALOGO:
			if (JugadorSprites.CATALOGO[pieza]["modelos"] as Dictionary).has(m):
				pedidos[pieza] = m
	var out: Array = []
	# LO QUE CUELGA (la melena, la cola de la coleta) va DEBAJO del cuerpo, que es donde se pinta en
	# el juego mirando de frente. En el juego eso lo decide la direccion (ver JugadorSprites); aqui se
	# pone fijo detras, porque la hoja de contacto se mira sobre todo de frente.
	for pieza in PersonajeData.PIEZAS:
		if not pedidos.has(pieza):
			continue
		var c: Dictionary = JugadorSprites.CATALOGO[pieza]
		var m: String = String(pedidos[pieza])
		if bool((c["modelos"][m] as Dictionary).get("cuelga", false)):
			out.append(c["gen"].generar(m + PeloSprites.SUFIJO_ATRAS, 1.0))
	out.append(CuerpoSprites.generar(1.0))
	# En el ORDEN DE APILADO de verdad (PersonajeData.PIEZAS), no en el que se hayan escrito los
	# argumentos: si no, escribir el pelo antes que la camisa lo pintaria debajo de ella.
	for pieza in PersonajeData.PIEZAS:
		if not pedidos.has(pieza):
			continue
		# CON CASCO NO SE PINTA EL CASQUETE DEL PELO, igual que en el juego (ver JugadorSprites.capas_de).
		# Si aqui saliera y en el juego no, la hoja de contacto estaria mintiendo justo sobre lo que se
		# viene a mirar.
		if pieza == "pelo" and not armaduras.is_empty():
			continue
		# Y LOS CASCOS ABIERTOS VAN JUSTO ANTES DE LA CARA, que es el orden que les da su z (2047 contra
		# 2048): se les ve la cara por debajo. Los cerrados van al final del todo, encima de todo.
		if pieza == "cara":
			_apilar_armaduras(out, armaduras, false)
		var cat: Dictionary = JugadorSprites.CATALOGO[pieza]
		out.append(cat["gen"].generar(String(pedidos[pieza]), 1.0))
	if not pedidos.has("cara"):
		_apilar_armaduras(out, armaduras, false)
	_apilar_armaduras(out, armaduras, true)
	return out


func _apilar_armaduras(out: Array, claves: Array, cerrados: bool) -> void:
	for clave in claves:
		var tipo: String = String(ArmaduraSprites._parse(clave).get("tipo", ""))
		if ArmaduraSprites.cerrado(tipo) != cerrados:
			continue
		out.append(ArmaduraSprites.generar(clave, 1.0))


# UNA ANIMACION, LAS OCHO DIRECCIONES. Una fila por direccion. Es la hoja con la que se juzga si el
# personaje gira de verdad o si hay direcciones que se parecen demasiado entre si (el fallo tipico:
# SE y E salen casi iguales y el personaje parece que no acaba de girar).
func _hoja_direcciones(capas: Array, anim: String) -> void:
	var fila: Dictionary = _fila(anim)
	if fila.is_empty():
		push_error("[ver jugador] no existe la animacion '%s'. Hay: %s" % [anim, _nombres()])
		return
	var dirs: int = int(fila["dirs"])
	var marcos: int = int(fila["marcos"])
	var caja: Rect2i = _caja_comun(capas, [anim])
	var w: int = caja.size.x * ZOOM
	var h: int = caja.size.y * ZOOM
	var out := Image.create(HUECO + marcos * (w + HUECO), HUECO + dirs * (h + HUECO),
		false, Image.FORMAT_RGBA8)
	out.fill(FONDO)
	for d in dirs:
		for i in marcos:
			var img: Image = _componer(capas, "%s_%d" % [anim, d], i, caja)
			out.blend_rect(img, Rect2i(0, 0, w, h),
				Vector2i(HUECO + i * (w + HUECO), HUECO + d * (h + HUECO)))
	var ruta: String = "%shoja_jugador_%s.png" % [SALIDA, anim]
	out.save_png(ruta)
	print("[ver jugador] %s  ·  %d direcciones x %d fotogramas a %.0f fps"
		% [anim, dirs, marcos, float(fila["fps"])])
	print("[ver jugador] filas = %s" % ", ".join(DIR_NOMBRES.slice(0, dirs)))
	print("[ver jugador] ", ProjectSettings.globalize_path(ruta))


# TODAS LAS ANIMACIONES, una por fila, en la direccion que mas enseña. De perfil (E) se ve la
# zancada, el brazo que se echa atras y la inclinacion del tronco; de frente casi todo eso apunta a
# la camara y no se aprecia.
func _hoja_animaciones(capas: Array) -> void:
	# UNA CAJA POR FILA, y no una comun a todas. Con una sola, la muerte -- que acaba tumbado y ocupa
	# a lo ancho el triple que de pie -- estiraba la caja de todo el mundo, y las siete animaciones
	# restantes salian de miniatura en mitad de un campo vacio. Lo que hay que poder juzgar en cada
	# fila es esa fila.
	var cajas: Array = []
	var celda := Vector2i.ZERO
	for a in PoseJugador.ANIMS:
		var c: Rect2i = _caja_comun(capas, [a["n"]])
		cajas.append(c)
		celda = Vector2i(maxi(celda.x, c.size.x), maxi(celda.y, c.size.y))
	var w: int = celda.x * ZOOM
	var h: int = celda.y * ZOOM
	var filas: int = PoseJugador.ANIMS.size()
	var cols: int = 0
	for a in PoseJugador.ANIMS:
		cols = maxi(cols, int(a["marcos"]))
	var out := Image.create(HUECO + cols * (w + HUECO), HUECO + filas * (h + HUECO),
		false, Image.FORMAT_RGBA8)
	out.fill(FONDO)
	for f in filas:
		var a: Dictionary = PoseJugador.ANIMS[f]
		# La de una sola direccion (encaje, muerte) solo tiene la 0; el resto se enseña de perfil.
		var d: int = 0 if int(a["dirs"]) == 1 else 2
		var caja: Rect2i = cajas[f]
		for i in int(a["marcos"]):
			var img: Image = _componer(capas, "%s_%d" % [a["n"], d], i, caja)
			# Centrado en su celda: las filas no miden lo mismo, y alineadas por la esquina la mitad
			# parecerian estar flotando.
			var dx: int = (w - img.get_width()) / 2
			var dy: int = h - img.get_height()
			out.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()),
				Vector2i(HUECO + i * (w + HUECO) + dx, HUECO + f * (h + HUECO) + dy))
	var ruta: String = "%shoja_jugador_todas.png" % SALIDA
	out.save_png(ruta)
	print("[ver jugador] filas, de arriba abajo: %s" % _nombres())
	print("[ver jugador] ", ProjectSettings.globalize_path(ruta))


# Un fotograma con TODAS las capas apiladas, recortado a la caja comun y ampliado.
func _componer(capas: Array, nom: String, i: int, caja: Rect2i) -> Image:
	var lienzo: Image = null
	for sf in capas:
		if not sf.has_animation(nom) or i >= sf.get_frame_count(nom):
			continue
		var at: AtlasTexture = sf.get_frame_texture(nom, i) as AtlasTexture
		if at == null:
			continue
		var w: int = int(at.region.size.x + at.margin.size.x)
		var h: int = int(at.region.size.y + at.margin.size.y)
		if lienzo == null:
			lienzo = Image.create(w, h, false, Image.FORMAT_RGBA8)
			lienzo.fill(Color(0, 0, 0, 0))
		var src: Image = at.atlas.get_image()
		src.convert(Image.FORMAT_RGBA8)
		# blend y no blit: las capas de arriba tienen que dejar ver lo de debajo por sus huecos.
		lienzo.blend_rect(src, Rect2i(at.region), Vector2i(at.margin.position))
	if lienzo == null:
		return Image.create(caja.size.x * ZOOM, caja.size.y * ZOOM, false, Image.FORMAT_RGBA8)
	var amp: Image = lienzo.get_region(caja)
	amp.resize(caja.size.x * ZOOM, caja.size.y * ZOOM, Image.INTERPOLATE_NEAREST)
	return amp


# La caja que contiene a TODOS los fotogramas de las animaciones pedidas. Se recorta a la vez para
# todos, y no uno a uno, porque lo que hay que poder juzgar es cuanto se mueve entre fotogramas.
func _caja_comun(capas: Array, anims: Array) -> Rect2i:
	var caja := Rect2i()
	var primero := true
	for sf in capas:
		for base in anims:
			for nom in sf.get_animation_names():
				if not str(nom).begins_with(str(base) + "_"):
					continue
				for i in sf.get_frame_count(nom):
					var at: AtlasTexture = sf.get_frame_texture(nom, i) as AtlasTexture
					if at == null or at.region.size.x <= 0:
						continue
					var r := Rect2i(Vector2i(at.margin.position), Vector2i(at.region.size))
					caja = r if primero else caja.merge(r)
					primero = false
	var lz: Vector2i = PoseJugador.lienzo(1.0)
	if primero:
		return Rect2i(0, 0, lz.x, lz.y)
	return caja.grow(2).intersection(Rect2i(0, 0, lz.x, lz.y))


func _fila(anim: String) -> Dictionary:
	for a in PoseJugador.ANIMS:
		if a["n"] == anim:
			return a
	return {}


func _nombres_lista() -> Array:
	var out: Array = []
	for a in PoseJugador.ANIMS:
		out.append(a["n"])
	return out


func _nombres() -> String:
	return ", ".join(PackedStringArray(_nombres_lista()))
