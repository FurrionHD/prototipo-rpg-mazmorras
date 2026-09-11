# ============================================================
#  retrato_pieza.gd  (se usa por preload, sin class_name)
#  LA PIEZA DE EQUIPO SOLA Y EN GRANDE: el casco, el peto o la espada tal como se ven puestos en el
#  muñeco, pero sin el muñeco y a mas resolucion. Es lo que enseña la vitrina de Cambiar equipo.
#
#  NO HAY DIBUJO NUEVO. Las capas del muñeco se pintan con elipses sobre el esqueleto (ver
#  CapaJugador), y el pintor admite escala: pidiendole UN fotograma a x4 sale la misma pieza con
#  cuatro veces mas celdas, no la de siempre ampliada a pixelotes. El dia que se retoque un casco, su
#  retrato cambia solo -- es la misma funcion.
#
#  QUE FOTOGRAMA: de pie, primer fotograma, mirando al SUR (de frente a camara). Es el unico en el que
#  una pieza enseña su cara buena; al norte el casco es una nuca.
#
#  Y EL COLOR, EL DE VERDAD: la capa se pinta con la rampa de indices y la tiñe paleta_equipo.gdshader
#  con la tabla de su tier y su +N, igual que en el muñeco. Por eso devuelve la textura Y el material:
#  sin el material, la pieza sale en los grises de la rampa.
# ============================================================
extends RefCounted

const SHADER_PALETA: Shader = preload("res://shaders/paleta_equipo.gdshader")
# A cuanto se pinta, SEGUN DONDE SE ENSEÑE. La idea es que cada celda del dibujo caiga en uno o dos
# pixeles de pantalla enteros:
#   - la VITRINA (~300 px): x4, ~100 celdas de ancho un peto -> dos pixeles por celda.
#   - la CELDA de la rejilla y la tira de la ficha (~55-85 px): x2. A x4 habria que ENCOGERLA a
#     menos de un pixel por celda, y encoger pixel-art con NEAREST se come filas sueltas: el
#     contorno salia mordido a trozos.
const ESC := 4.0
const ESC_CELDA := 2.0
const ANIM := "idle"
const DIR_SUR := 0
# El hueco entre dos capas que se retratan JUNTAS (los dos guanteletes), en fraccion de su ancho.
const HUECO_PAR := 0.25

static var _cache: Dictionary = {}   # clave de capa(s) -> ImageTexture ya recortada


# ============================================================
#  LO QUE USAN LAS PANTALLAS
# ============================================================
# El TextureRect donde se enseña un retrato. Va en un nodo PROPIO, y no con draw_texture en quien lo
# enseña, porque lleva el shader de la paleta: un material se aplica al CanvasItem ENTERO, y el fondo
# de la celda (o el halo de la vitrina) saldria "traducido" a los colores de la pieza.
static func nodo() -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.visible = false
	return tr


# Carga en 'tr' el retrato de 'item' con SU tier y SU +N. Devuelve false si no tiene dibujo (un
# material, una pocion, los puños): entonces 'tr' se esconde y quien lo enseña pinta su icono.
static func poner(tr: TextureRect, item: Resource, esc: float) -> bool:
	var r: Dictionary = {}
	if item != null:
		r = de(item, int(Game.meta_de(item).get("tier", 1)), Game.mejoras_actuales(item), esc)
	tr.visible = not r.is_empty()
	tr.texture = r.get("tex", null)
	tr.material = r.get("material", null)
	tr.set_meta("esc", esc)
	return tr.visible


# Coloca 'tr' centrado en 'centro' y encajado en un cuadrado de lado 'caja', sin deformarlo (manda
# su lado largo). Y le ajusta el destello: el shader lo mide en PIXELES DE PANTALLA con numeros
# pensados para la pieza a su tamaño del mapa, asi que sin escalarlo la linea cruzaria como un hilo.
static func encajar(tr: TextureRect, centro: Vector2, caja: float) -> void:
	var tex: Texture2D = tr.texture
	if tex == null:
		return
	var k: float = caja / float(maxi(tex.get_width(), tex.get_height()))
	var tam := Vector2(tex.get_width(), tex.get_height()) * k
	tr.position = centro - tam * 0.5
	tr.size = tam
	var mat := tr.material as ShaderMaterial
	if mat != null:
		var f: float = k * float(tr.get_meta("esc", ESC))
		mat.set_shader_parameter("grosor", 7.0 * f)
		mat.set_shader_parameter("recorrido", maxf(38.0 * f, tam.length() * 0.6))


# {tex: ImageTexture, material: ShaderMaterial} o {} si esa pieza no tiene dibujo (los puños, un
# objeto que no es equipo). 'tier' y 'mejoras' son los de ESTA instancia: dos yelmos iguales a +0 y a
# +15 no son del mismo color.
static func de(item: Resource, tier: int, mejoras: int, esc: float = ESC) -> Dictionary:
	var d: Dictionary = _datos(item)
	if d.is_empty():
		return {}
	var tex: ImageTexture = _textura(d["claves"], d["pintor"], String(d.get("anim", ANIM)),
		int(d.get("dir", DIR_SUR)), bool(d.get("voltear", false)), esc)
	if tex == null:
		return {}
	var m := ShaderMaterial.new()
	m.shader = SHADER_PALETA
	m.set_shader_parameter("paleta", PaletaEquipo.lut(d["clave_roles"], d["roles"], d["familia"],
		maxi(tier, 1), mejoras))
	m.set_shader_parameter("tonos", float(CapaJugador.RAMPA_TONOS))
	m.set_shader_parameter("metal", PaletaEquipo.metal_de(d["familia"], mejoras))
	m.set_shader_parameter("luz_ref", PaletaEquipo.luz_ref(d["familia"], maxi(tier, 1), mejoras))
	return {"tex": tex, "material": m}


# QUE CAPA(S) ES y con que pintor y paleta. Es el mismo reparto que JugadorSprites._capas_armadura /
# _arma_de / _escudo_de, pero para UN objeto suelto en vez de para lo que lleva un personaje.
static func _datos(item: Resource) -> Dictionary:
	if item is ArmorData:
		var a := item as ArmorData
		var slot: String = ArmaduraSprites.SLOT_NOMBRE[clampi(int(a.slot), 0, 4)]
		if not ArmaduraSprites.SLOTS_HECHOS.has(slot):
			return {}
		var tipo: String = ArmaduraSprites.TIPO_NOMBRE[clampi(int(a.tipo), 0,
			ArmaduraSprites.TIPO_NOMBRE.size() - 1)]
		var base: String = ArmaduraSprites.clave(tipo, slot)
		# Los guanteletes son dos capas, una por mano: se pintan las dos en el mismo lienzo.
		var claves: Array = [base + "_der", base + "_izq"] \
			if ArmaduraSprites.SLOTS_POR_MANO.has(slot) else [base]
		return {"claves": claves, "pintor": ArmaduraSprites.pintar,
			"clave_roles": ArmaduraSprites.CLAVE_ROLES, "roles": ArmaduraSprites.ROLES,
			"familia": ArmaduraSprites.familia_de(tipo)}
	# LAS ARMAS Y EL ESCUDO, EN GUARDIA: la capa de la mano solo pinta con el arma FUERA (ver
	# ArmaSprites._ANIM_MANO); de pie va envainada y en la mano no hay nada que retratar.
	if item is ShieldData:
		var tn: String = EscudoSprites.TAMANO_NOMBRE[clampi(int((item as ShieldData).tamano), 0,
			EscudoSprites.TAMANO_NOMBRE.size() - 1)]
		# De frente: el escudo va en la izquierda y mira a camara con su cara buena.
		return {"claves": ["escudo_%s_mano_izq" % tn], "pintor": EscudoSprites.pintar,
			"anim": "guardia", "dir": DIR_SUR,
			"clave_roles": EscudoSprites.CLAVE_ROLES, "roles": EscudoSprites.ROLES,
			"familia": PaletaEquipo.METAL}
	var tn2: String = ""
	if item is WandData:
		tn2 = "varita"
	elif item is WeaponData:
		if int((item as WeaponData).tipo) == WeaponData.Tipo.PUNOS:
			return {}
		tn2 = ArmaSprites.TIPO_NOMBRE[int((item as WeaponData).tipo)]
	else:
		return {}
	# LAS ARMAS NO SALEN DE NINGUNA POSE DEL MUÑECO: en todas las de guardia cuelgan con la punta hacia
	# abajo y escorzadas (se miro en una hoja de contactos de las ocho direcciones). Tienen un pintor
	# de retrato propio que las dibuja enteras, rectas y en diagonal: ArmaSprites.pintar_retrato. La
	# "clave" que se le pasa es el TIPO de arma.
	return {"claves": [tn2], "pintor": ArmaSprites.pintar_retrato,
		"clave_roles": ArmaSprites.CLAVE_ROLES, "roles": ArmaSprites.ROLES,
		"familia": ArmaSprites.familia_de(tn2)}


# Cada capa pintada y RECORTADA a lo que ocupa, sin la sombra del suelo. Si son varias (los dos
# guanteletes) se ponen UNA AL LADO DE OTRA y no donde caen en el lienzo: ahi van cada una en su
# mano, con el ancho de un cuerpo entre las dos, y en la vitrina salian dos manchas en los bordes del
# aro. El color es el de la rampa (el gris que dice el numero de tono): lo pone el shader.
static func _textura(claves: Array, pintor: Callable, anim: String, dir: int,
		voltear: bool = false, esc: float = ESC) -> ImageTexture:
	var ck: String = "%s_%s_%d_%s_%.2f" % ["|".join(claves), anim, dir, voltear, esc]
	if _cache.has(ck):
		return _cache[ck]
	var trozos: Array = []   # [{celdas, w, h}]
	for c in claves:
		var t: Dictionary = _recorte(CapaJugador.plantilla(pintor.bind(String(c)), anim, 0, dir, esc),
			esc)
		if not t.is_empty():
			trozos.append(t)
	if trozos.is_empty():
		_cache[ck] = null
		return null   # el pintor no dibuja nada en esta pose: sin retrato, sale el icono de siempre
	# Uno al lado del otro, alineados por ABAJO (dos guanteletes apoyados en la misma linea).
	var hueco: int = int(float(trozos[0]["w"]) * HUECO_PAR) if trozos.size() > 1 else 0
	var w: int = -hueco
	var h: int = 0
	for t in trozos:
		w += int(t["w"]) + hueco
		h = maxi(h, int(t["h"]))
	var celdas := PackedByteArray()
	celdas.resize(w * h)
	celdas.fill(0)
	var x0: int = 0
	for t in trozos:
		var tw: int = t["w"]
		var th: int = t["h"]
		var src: PackedByteArray = t["celdas"]
		for y in th:
			for x in tw:
				celdas[(h - th + y) * w + x0 + x] = src[y * tw + x]
		x0 += tw + hueco
	var cols: Array = CapaJugador.rampa_indices(CapaJugador.RAMPA_TONOS)
	var tex: ImageTexture = SpriteLienzo.a_textura(celdas, SpriteLienzo.paleta(cols), w, h)
	if voltear:
		var img: Image = tex.get_image()
		img.flip_y()
		tex = ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex


# UNA capa recortada a lo que ocupa de verdad. Sin el recorte, un casco es una mancha pequeña arriba
# de un lienzo pensado para el cuerpo entero, y no habria forma de centrarlo ni de agrandarlo.
static func _recorte(p: PackedByteArray, esc: float) -> Dictionary:
	var lz: Vector2i = PoseJugador.lienzo(esc)
	var x0: int = lz.x
	var y0: int = lz.y
	var x1: int = -1
	var y1: int = -1
	for y in lz.y:
		for x in lz.x:
			var v: int = p[y * lz.x + x]
			# La SOMBRA DEL SUELO no cuenta: en el muñeco es la mancha que lo apoya; en una pieza suelta
			# seria una sombra flotando debajo de un casco.
			if v != CapaJugador.T_VACIO and v != CapaJugador.T_SOMBRA_SUELO:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return {}
	var w: int = x1 - x0 + 1
	var h: int = y1 - y0 + 1
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var v: int = p[(y0 + y) * lz.x + x0 + x]
			out[y * w + x] = 0 if v == CapaJugador.T_SOMBRA_SUELO else v
	return {"celdas": out, "w": w, "h": h}
