# ============================================================
#  ver_peces.gd  --  HERRAMIENTA, no parte del juego.
#
#  Dibuja los peces del charco y los deja como PNG para poder MIRARLOS. Cada salida contesta UNA
#  pregunta distinta, y por eso son cinco y no una:
#
#    peces_hoja_<id>   la hoja horneada cruda, a zoom 6. Pixel a pixel: ¿el barbillon esta pegado al
#                      morro?, ¿la cola se sale del lienzo?
#    peces_tabla       las cinco especies en todas sus tallas, sobre gris neutro. Contesta la
#                      pregunta de la SILUETA: ¿se distingue un bagre de una lubina sin leer nada?
#    peces_en_el_agua  EL DECISIVO. El lago de verdad, con su capa "hondo", y encima cada especie
#                      con el modulate EXACTO del juego. Es el unico que contesta lo que importa:
#                      ¿se lee la silueta A TRAVES del agua? Sobre fondo blanco se estaria midiendo
#                      el dato de al lado.
#    peces_giro        los cuatro frames por ocho rumbos, rotados como los rota el juego. El pixel
#                      art girado se emborrona, y mas vale saberlo aqui que en la partida.
#    peces_libro       la foto del libro de pesca en sus dos estados (conocida / por descubrir).
#
#  Se lanza con ver_peces.bat. No toca nada del juego: solo escribe en tools/salida/.
#
#  Va como ESCENA y no como --script suelto (que seria lo natural para un volcado a PNG): las
#  fichas de los peces son MaterialData, y material_data.gd habla con el autoload Game. En modo
#  --script no hay autoloads, asi que ni siquiera carga la tabla.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const TABLA := "res://resources/world/peces.tres"

# Los mismos numeros con los que el charco calcula el largo de un pez (FishingSpot). Si alli
# cambian, aqui tambien: este visor tiene que dibujar LAS TALLAS QUE SALEN DE VERDAD, no un rango
# bonito inventado por la herramienta.
const PX_POR_CM := 0.6
const LARGO_MIN := 10.0
const LARGO_MAX := 53.0        # minf(tam del charco) * LARGO_MAX_FRAC, con el charco de 5x4

# El tinte que el charco le pone a un pez sumergido y el del que esta peleando un compañero.
const TONO_SUMERGIDO := Color(0.42, 0.55, 0.72, 0.88)
const TONO_OCUPADO := Color(0.72, 0.82, 0.95, 0.95)

const SEM := 20260905
const LAGO_TAM := Vector2i(5, 4)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var t0: int = Time.get_ticks_msec()
	var peces: Array[MaterialData] = _especies()
	if peces.is_empty():
		print("No he encontrado ninguna especie de pez en ", TABLA)
		get_tree().quit()
		return

	# Hornear primero: lo que se mira tiene que ser lo que el juego va a cargar, no una generacion
	# al vuelo que podria diferir del PNG de disco.
	for d in peces:
		var n: int = PezSprites.hornear(d, PX_POR_CM, LARGO_MIN, LARGO_MAX)
		print("  %-20s %.1f KB · tallas %s" % [d.id, float(n) / 1024.0,
			str(PezSprites.tallas_de(d, PX_POR_CM, LARGO_MIN, LARGO_MAX))])
		_guardar(PezSprites.hoja(d, PX_POR_CM, LARGO_MIN, LARGO_MAX), "peces_hoja_" + d.id, 6)

	_guardar(_tabla(peces), "peces_tabla", 4)
	_guardar(_en_el_agua(peces), "peces_en_el_agua", 3)
	_guardar(_giro(peces), "peces_giro", 4)
	_guardar(_libro(peces), "peces_libro", 2)
	_avisar(peces)
	print("Listo en %.1f s. Mira los PNG en %s" % [(Time.get_ticks_msec() - t0) / 1000.0, SALIDA])
	get_tree().quit()


func _especies() -> Array[MaterialData]:
	var tabla := load(TABLA) as MaterialTable
	var out: Array[MaterialData] = []
	if tabla == null:
		return out
	for e in tabla.entradas:
		if e != null and e.material != null and not out.has(e.material):
			out.append(e.material)
	return out


func _guardar(img: Image, nombre: String, zoom: int) -> void:
	var g := img.duplicate() as Image
	g.resize(g.get_width() * zoom, g.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	g.save_png(ProjectSettings.globalize_path(SALIDA + nombre + ".png"))
	print("  %-28s %dx%d" % [nombre + ".png", img.get_width(), img.get_height()])


# Un frame suelto de una especie a una talla, ya recortado de su hoja.
func _frame(d: MaterialData, talla: int, f: int) -> Image:
	var hoja: Image = PezSprites.hoja(d, PX_POR_CM, LARGO_MIN, LARGO_MAX)
	var tallas: Array[int] = PezSprites.tallas_de(d, PX_POR_CM, LARGO_MIN, LARGO_MAX)
	var celda: Vector2i = PezSprites.lienzo(tallas.back())
	var fila: int = PezSprites.fila_de(d, talla, PX_POR_CM, LARGO_MIN, LARGO_MAX)
	return hoja.get_region(Rect2i(Vector2i(f * celda.x, fila * celda.y), celda))


# ============================================================
#  LA TABLA: ¿se distinguen las cinco por su silueta?
# ============================================================
func _tabla(peces: Array[MaterialData]) -> Image:
	var celda: Vector2i = PezSprites.lienzo(PezSprites.TALLA_MAX)
	var cols: int = PezSprites.TALLA_MAX - PezSprites.TALLA_MIN + 1
	var img := Image.create(celda.x * cols, celda.y * peces.size(), false, Image.FORMAT_RGBA8)
	# GRIS NEUTRO y no blanco ni negro: un pez oscuro sobre negro y uno claro sobre blanco se ven
	# los dos mal, y aqui lo que se juzga es la forma, no el contraste.
	img.fill(Color(0.42, 0.42, 0.45))
	for fila in peces.size():
		var d: MaterialData = peces[fila]
		for t in PezSprites.tallas_de(d, PX_POR_CM, LARGO_MIN, LARGO_MAX):
			var tr: Image = _frame(d, t, 0)
			img.blend_rect(tr, Rect2i(Vector2i.ZERO, tr.get_size()),
				Vector2i((t - PezSprites.TALLA_MIN) * celda.x, fila * celda.y))
	return img


# ============================================================
#  EL DECISIVO: bajo el agua de verdad
# ============================================================
func _en_el_agua(peces: Array[MaterialData]) -> Image:
	var atlas: Image = TerrenoSprites.generar("roca")
	var L: int = TerrenoSprites.LADO
	# Un lago de verdad, ancho, para que quepan los cinco nadando.
	var w: int = 22
	var h: int = 4 + peces.size() * 3
	var agua: Dictionary = {}
	for y in range(2, h - 2):
		for x in range(1, w - 1):
			agua[Vector2i(x, y)] = true
	var hondo: Dictionary = Decorado.nucleo_lago(agua)
	var img := Image.create(w * L, h * L, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.03, 0.04))
	for y in h:
		for x in w:
			_baldosa(img, atlas, TerrenoSprites.celda_para("suelo", Vector2i(x, y), 0, SEM),
				Vector2i(x, y))
	for c in agua:
		var m: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool: return agua.has(v))
		_baldosa(img, atlas, TerrenoSprites.celda_para("agua", c, m, SEM), c)
	for c in hondo:
		var m2: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool: return hondo.has(v))
		_baldosa(img, atlas, TerrenoSprites.celda_para("hondo", c, m2, SEM), c)

	# Y encima los peces, con el modulate EXACTO del juego. La ultima columna lleva el tono del pez
	# que esta peleando un compañero, que es el otro estado que se ve en el agua.
	for fila in peces.size():
		var d: MaterialData = peces[fila]
		var tallas: Array[int] = PezSprites.tallas_de(d, PX_POR_CM, LARGO_MIN, LARGO_MAX)
		var y: int = (3 + fila * 3) * L
		var x: int = L
		for t in tallas:
			var tr: Image = _frame(d, t, 0)
			_teñir(img, tr, Vector2i(x, y - tr.get_height() / 2), TONO_SUMERGIDO)
			x += tr.get_width() + 4
		var ult: Image = _frame(d, tallas.back(), 0)
		_teñir(img, ult, Vector2i((w - 2) * L - ult.get_width(), y - ult.get_height() / 2),
			TONO_OCUPADO)
	return img


# ============================================================
#  EL GIRO: el pixel art rotado se emborrona
# ============================================================
func _giro(peces: Array[MaterialData]) -> Image:
	var celda: Vector2i = PezSprites.lienzo(PezSprites.TALLA_MAX)
	var img := Image.create(celda.x * 8, celda.y * peces.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.42, 0.42, 0.45))
	for fila in peces.size():
		var d: MaterialData = peces[fila]
		var t: int = PezSprites.tallas_de(d, PX_POR_CM, LARGO_MIN, LARGO_MAX).back()
		for r in 8:
			# Con NEAREST, que es el filtro con el que el juego lo va a dibujar. Con el suave de por
			# defecto este PNG mentiria justo en lo que viene a enseñar.
			var g: Image = _rotar(_frame(d, t, r % PezSprites.FRAMES), TAU * float(r) / 8.0)
			img.blend_rect(g, Rect2i(Vector2i.ZERO, g.get_size()),
				Vector2i(r * celda.x, fila * celda.y))
	return img


# Rotacion por VECINO MAS CERCANO, hecha a mano: es como rota Godot un Sprite2D con
# texture_filter NEAREST, y es justo el emborronado que hay que poder ver.
func _rotar(src: Image, ang: float) -> Image:
	var w: int = src.get_width()
	var h: int = src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector2(float(w), float(h)) * 0.5
	var ca: float = cos(-ang)
	var sa: float = sin(-ang)
	for y in h:
		for x in w:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - c
			var q := Vector2(p.x * ca - p.y * sa, p.x * sa + p.y * ca) + c
			var sx: int = int(floor(q.x))
			var sy: int = int(floor(q.y))
			if sx < 0 or sy < 0 or sx >= w or sy >= h:
				continue
			out.set_pixel(x, y, src.get_pixel(sx, sy))
	return out


# ============================================================
#  EL LIBRO: a color si la conoces, en silueta si no
# ============================================================
func _libro(peces: Array[MaterialData]) -> Image:
	var celda: Vector2i = PezSprites.lienzo(PezSprites.TALLA_MAX)
	var img := Image.create(celda.x * peces.size(), celda.y * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.10, 0.13))
	for i in peces.size():
		var d: MaterialData = peces[i]
		var t: int = PezSprites.tallas_de(d, PX_POR_CM, LARGO_MIN, LARGO_MAX).back()
		var tr: Image = _frame(d, t, 0)
		img.blend_rect(tr, Rect2i(Vector2i.ZERO, tr.get_size()), Vector2i(i * celda.x, 0))
		_teñir(img, tr, Vector2i(i * celda.x, celda.y), Color(0.06, 0.09, 0.14))
	return img


# ============================================================
#  AVISOS: lo que el ojo no ve de un vistazo
# ============================================================
# Los dos fallos que este generador va a tener, y los dos son invisibles hasta que los buscas: una
# cola que se sale del lienzo (se ve recortada en el agua, no en la hoja) y un barbillon que se ha
# quedado suelto del cuerpo (a un pixel de distancia parece pegado al zoom del PNG).
func _avisar(peces: Array[MaterialData]) -> void:
	var recortes: int = 0
	var islas: int = 0
	for d in peces:
		for t in PezSprites.tallas_de(d, PX_POR_CM, LARGO_MIN, LARGO_MAX):
			for f in PezSprites.FRAMES:
				var img: Image = _frame(d, t, f)
				if _toca_el_borde(img):
					print("  !! %s talla %d frame %d TOCA EL BORDE del lienzo" % [d.id, t, f])
					recortes += 1
				var n: int = _manchas(img)
				if n > 1:
					print("  !! %s talla %d frame %d sale en %d trozos sueltos" % [d.id, t, f, n])
					islas += 1
	print("  peces: %d recortes, %d con trozos sueltos" % [recortes, islas])


func _toca_el_borde(img: Image) -> bool:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for x in w:
		if img.get_pixel(x, 0).a > 0.0 or img.get_pixel(x, h - 1).a > 0.0:
			return true
	for y in h:
		if img.get_pixel(0, y).a > 0.0 or img.get_pixel(w - 1, y).a > 0.0:
			return true
	return false


func _manchas(img: Image) -> int:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var visto: Dictionary = {}
	var n: int = 0
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a <= 0.0 or visto.has(Vector2i(x, y)):
				continue
			n += 1
			var cola: Array[Vector2i] = [Vector2i(x, y)]
			visto[Vector2i(x, y)] = true
			var cab: int = 0
			while cab < cola.size():
				var c: Vector2i = cola[cab]
				cab += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var v: Vector2i = c + Vector2i(dx, dy)
						if v.x < 0 or v.y < 0 or v.x >= w or v.y >= h or visto.has(v):
							continue
						if img.get_pixel(v.x, v.y).a <= 0.0:
							continue
						visto[v] = true
						cola.append(v)
	return n


func _baldosa(img: Image, atlas: Image, celda: Vector2i, en: Vector2i) -> void:
	var L: int = TerrenoSprites.LADO
	img.blend_rect(atlas, Rect2i(celda * L, Vector2i(L, L)), en * L)


# Pega `src` sobre `img` multiplicado por `tinte`, que es lo que hace un modulate.
func _teñir(img: Image, src: Image, en: Vector2i, tinte: Color) -> void:
	var t := src.duplicate() as Image
	for y in t.get_height():
		for x in t.get_width():
			var c: Color = t.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			t.set_pixel(x, y, Color(c.r * tinte.r, c.g * tinte.g, c.b * tinte.b, c.a * tinte.a))
	img.blend_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), en)
