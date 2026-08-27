# ============================================================
#  sprite_lienzo.gd  (class_name SpriteLienzo)
#  El MOTOR que comparten los generadores de sprites por codigo (SlimeSprites, RataSprites...).
#  No sabe dibujar ningun bicho: sabe manejar una PLANTILLA -- una rejilla de bytes donde cada
#  celda guarda a que "tono" pertenece -- y convertirla en textura con una paleta.
#
#  POR QUE LA PLANTILLA GUARDA TONOS Y NO COLORES: es lo que separa la parte CARA (geometria:
#  elipses, raices, contornos) de la BARATA (pintar). La geometria no depende del color, asi que se
#  calcula una vez y sirve para todas las variantes de color del mismo bicho. Sin esta separacion,
#  cada tono de slime regeneraba sus 192 texturas y entrar a un piso congelaba el juego varios
#  segundos (ver el historial de slime_sprites.gd).
#
#  EL ENUM DE TONOS LO DECLARA CADA GENERADOR, no este archivo: aqui un tono es solo un indice, y
#  la paleta es un array de colores en ese mismo orden. Asi el slime puede tener CORONA/GEMA y la
#  rata COLA/DIENTE sin que ninguno arrastre las ranuras del otro.
#
#  LO QUE NO ESTA AQUI, A PROPOSITO: los bucles que recorren celda por celda (silueta, sombreado,
#  contorno). Son el codigo CALIENTE -- miles de iteraciones por frame -- y viven dentro de cada
#  generador con las cuentas puestas en linea. Sacarlos aqui costaria una llamada a funcion por
#  celda, que es justo lo que se quito para que esto fuera rapido.
# ============================================================

extends RefCounted
class_name SpriteLienzo

# Tono 0 = fuera de la figura. Lo unico que este motor da por supuesto de los enums ajenos.
const VACIO := 0

# ============================================================
#  EL TAMAÑO DEL PIXEL ES UNO PARA TODO EL JUEGO
# ============================================================
# Cuantas unidades de mundo mide UNA celda de cualquier sprite generado. Es EL numero que mantiene
# coherente el pixel-art: un enemigo mas grande se dibuja con MAS CELDAS, nunca con celdas mas
# gordas.
#
# Antes se hacia justo al reves -- se generaba una textura del mismo tamaño para todos y se estiraba
# el nodo con 'escala_visual' -- y por eso el Rey Slime (escala 2.6) tenia unos pixelotes casi el
# triple de grandes que un slime normal, y el Rey Rata lo mismo. Se ve enseguida y canta: en un
# juego de pixel-art la rejilla tiene que ser la misma para todo lo que aparece en pantalla.
#
# CONSECUENCIA para quien escriba un generador: 'escala_base()' devuelve SIEMPRE esto (no depende
# del bicho), y es la GEOMETRIA la que se multiplica por escala_visual, junto con el tamaño del
# lienzo. Y enemy.gd NO debe volver a escalar el sprite: eso solo vale para la caja de colision.
# 1.15: el pixel-art tiene que LEERSE como pixel-art. Nacio en 0.62 -- copiado del tamaño que le
# quedaba bien a la rata -- y con el los bichos salian tan finos que se perdia el estilo: "se ven
# poco pixelados". 1.15 es, casi clavado, el grosor que ya tenia el slime antes de su rework, o sea
# el aspecto conocido, pero ahora igual para TODOS.
#
# Y no es solo estetica: la memoria y el tiempo de generacion van con el CUADRADO de este numero.
# Medido con los diez tipos dibujados de hoy:
#     0.62 -> 231,7 MB de VRAM y 9,1 s de generar todo
#     1.15 ->  66,8 MB           y 2,9 s
# Ese es el margen que hace viable precargarlo todo de una vez.
const UNIDADES_POR_CELDA := 1.15


# ============================================================
#  LA CAMARA ES UNA PARA TODO EL JUEGO: 45 GRADOS
# ============================================================
# Todos los bichos se ven desde el mismo sitio, y ese sitio se decide AQUI. Cada pieza vive en 3D
# (x a lo ancho, y a lo largo, z de altura) y se proyecta:
#       pantalla_x = x
#       pantalla_y = y * COS_CAM - z * SIN_CAM
# Ese "- z" es lo que pone el lomo por encima de las patas y hace que de perfil se vea el COSTADO y
# no la planta. Ni cenital pura (que se lee como un mapa y queda rara) ni de perfil.
#
# Estaba declarado por separado en cada generador. Con dos aun colaba; en cuanto son cuatro, una de
# las copias se queda atras y ese bicho pasa a verse desde otro sitio que el resto -- que es
# exactamente el problema que este rework vino a arreglar.
const CAMARA_GRADOS := 45.0
const COS_CAM := cos(deg_to_rad(CAMARA_GRADOS))   # cuanto se encoge la PROFUNDIDAD
const SIN_CAM := sin(deg_to_rad(CAMARA_GRADOS))   # cuanto sube en pantalla la ALTURA


# Cuanto se aplasta en pantalla una pieza de semiejes (ry a lo largo, rz de alto): el valor que hay
# que pasarle a 'elipse' como 'persp'. NO es un numero a ojo -- un elipsoide proyectado sobre el eje
# (cos45, -sin45) mide sqrt(ry²cos² + rz²sin²) -- y de ahi salen solos los dos casos limite:
#   * una cosa PLANA tumbada en el suelo (rz = 0) sale en cos(45) = 0.707;
#   * una ESFERA (ry == rz) sale en 1.0, o sea circulo mire por donde se mire.
# Con esto no hacen falta las constantes a ojo por tipo de pieza que llevaba la rata.
static func persp_de(ry: float, rz: float) -> float:
	var r: float = maxf(0.01, ry)
	return sqrt(r * r * COS_CAM * COS_CAM + rz * rz * SIN_CAM * SIN_CAM) / r


# ------------------------------------------------------------
#  Color y paleta
# ------------------------------------------------------------

# REDONDEA el color a unos pocos escalones. Es lo que hace que la cache de un generador ACIERTE:
# el color de un bicho sale de EnemyData.color_visual(current_t) y 'current_t' es un randf() POR
# BICHO, asi que sin cuantizar hay tantas variantes como bichos y no se reutiliza ni una.
static func cuantizar(c: Color, pasos: float = 6.0) -> Color:
	return Color(round(c.r * pasos) / pasos, round(c.g * pasos) / pasos,
		round(c.b * pasos) / pasos, c.a)


# Lo mismo, pero SIN TOCAR EL TONO: escalona solo saturacion y brillo.
#
# Hace falta para los bichos de color apagado. Redondeando canal a canal, dos canales parecidos se
# igualan y el color CAMBIA DE TONO: el leonado del Rey rata (0.71, 0.61, 0.46) salia (0.67, 0.67,
# 0.50), o sea verde oliva, porque el rojo y el verde caian en el mismo escalon. Con un rojo puro
# como el del slime eso no pasa (su canal rojo esta clavado en 1), por eso alli no se vio.
#
# El tono es justo lo que NO debe moverse -- 'color_visual' solo aclara al bicho segun su fuerza --
# asi que se conserva exacto y se redondea el resto.
static func cuantizar_hsv(c: Color, pasos: float = 6.0) -> Color:
	var out := Color.from_hsv(c.h, round(c.s * pasos) / pasos, round(c.v * pasos) / pasos)
	out.a = c.a
	return out


# LA TEXTURA DE UN FOTOGRAMA VACIO: un pixel transparente, uno solo para todo el juego.
#
# Existe porque un fotograma sin nada dibujado NO puede ser un AtlasTexture. Se probaron las dos
# formas de hacerlo con el atlas y las dos se ven:
#   * region de tamaño CERO -> Godot no dibuja "nada", dibuja LA HOJA ENTERA. En pantalla es un
#     cuadro de ruido de puntos (que son todos los fotogramas de la capa amontonados).
#   * region de 1x1 sobre un pixel transparente reservado -> al ampliar x3 se cuela el borde de la
#     hoja y queda una raya vertical al lado del personaje.
# Con una textura propia no hay atlas del que colarse nada.
#
# Hasta ahora no hacia falta porque ninguna capa tenia fotogramas vacios; la CARA si (mirando al
# norte no hay ojos que dibujar: es una nuca).
static var _vacia: ImageTexture = null

static func vacia() -> ImageTexture:
	if _vacia == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_vacia = ImageTexture.create_from_image(img)
	return _vacia


# Colores (en el orden del enum de tonos del generador) -> bytes RGBA listos para el pintado.
static func paleta(cols: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cols.size() * 4)
	for i in cols.size():
		var c: Color = cols[i]
		out[i * 4] = int(round(c.r * 255.0))
		out[i * 4 + 1] = int(round(c.g * 255.0))
		out[i * 4 + 2] = int(round(c.b * 255.0))
		out[i * 4 + 3] = int(round(c.a * 255.0))
	return out


# Plantilla + paleta -> textura. Es la parte BARATA: ni una elipse, solo copiar 4 bytes por celda.
# Por eso la segunda variante de color de un mismo bicho sale casi gratis.
static func a_textura(celdas: PackedByteArray, pal: PackedByteArray, w: int, h: int) -> ImageTexture:
	var datos := PackedByteArray()
	datos.resize(w * h * 4)
	# EL 'fill' ES OBLIGATORIO, y aqui ponia lo contrario: 'resize' NO inicializa a cero, solo reserva
	# sitio. Como abajo se saltan las celdas vacias, sin esto quedan con basura de memoria y el sprite
	# sale rodeado de ruido -- unas veces si y otras no, segun lo que hubiera antes en ese bloque.
	datos.fill(0)
	for i in celdas.size():
		# El VACIO se salta: ya esta a cero, que es exactamente el transparente que le tocaria. En un
		# lienzo con margen la mayoria de las celdas estan fuera del bicho, asi que esto se ahorra
		# ocho indexaciones en la mayor parte del recorrido.
		if celdas[i] == VACIO:
			continue
		var o: int = i * 4
		var p: int = int(celdas[i]) * 4
		datos[o] = pal[p]
		datos[o + 1] = pal[p + 1]
		datos[o + 2] = pal[p + 2]
		datos[o + 3] = pal[p + 3]
	return ImageTexture.create_from_image(
		Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, datos))


# ============================================================
#  EL ATLAS: un SpriteFrames entero en UNA textura
# ============================================================
# Antes cada frame era su propia ImageTexture del tamaño del lienzo completo. Y el lienzo es
# necesariamente GRANDE -- tiene que dar para las 8 direcciones y para el desplazamiento de la
# embestida --, pero un frame concreto solo usa una esquina de el. Medido: entre el 62% y el 86% de
# cada frame era aire transparente, y se subia a la tarjeta igual.
#
# Los numeros de antes de esto, MEDIDOS con el monitor del motor (no calculados): los sprites de
# cinco enemigos ocupaban 387 MB de VRAM. Recortando cada frame a su caja real: 86 MB. Y ojo, el
# driver cobra ~33% MAS de lo que sale de multiplicar ancho x alto x 4, asi que la cuenta a mano se
# quedaba corta.
#
# Aqui cada SpriteFrames pasa a ser UNA sola imagen con todos sus frames recortados y empaquetados,
# y cada frame es un AtlasTexture que apunta a su trozo. El 'margin' del AtlasTexture es lo que
# devuelve el hueco recortado, asi que el sprite se sigue dibujando EXACTAMENTE donde estaba y nadie
# mas se entera del cambio.

# Caja de las celdas NO vacias de una plantilla. Es lo que de verdad ocupa este frame.
static func _caja_usada(celdas: PackedByteArray, w: int, h: int) -> Rect2i:
	var x0: int = w
	var y0: int = h
	var x1: int = -1
	var y1: int = -1
	for y in h:
		var fila: int = y * w
		for x in w:
			if celdas[fila + x] == VACIO:
				continue
			if x < x0:
				x0 = x
			if x > x1:
				x1 = x
			if y < y0:
				y0 = y
			if y > y1:
				y1 = y
	if x1 < 0:
		return Rect2i(0, 0, 0, 0)     # frame entero vacio (no deberia pasar, pero no revienta)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


# Monta un SpriteFrames completo a partir de sus plantillas, empaquetado en un solo atlas.
#
# 'anims' = [{"nombre": String, "loop": bool, "fps": float, "plantillas": Array[PackedByteArray]}]
# Todas las plantillas son del mismo lienzo (w x h), que es el tamaño que el sprite debe APARENTAR.
static func montar_frames(anims: Array, pal: PackedByteArray, w: int, h: int) -> SpriteFrames:
	# 1. Medir cada frame y ordenarlos por alto: empaquetar por ESTANTES (una fila tras otra) deja
	#    mucho menos hueco si los de altura parecida van juntos.
	var trozos: Array = []
	for a in anims:
		for i in a["plantillas"].size():
			var celdas: PackedByteArray = a["plantillas"][i]
			trozos.append({"celdas": celdas, "caja": _caja_usada(celdas, w, h),
				"anim": a["nombre"], "idx": i})
	var orden: Array = trozos.duplicate()
	orden.sort_custom(func(p, q): return int(p["caja"].size.y) > int(q["caja"].size.y))

	# 2. Colocarlos por estantes en una hoja lo mas cuadrada posible.
	var area: int = 0
	for t in orden:
		area += int(t["caja"].size.x) * int(t["caja"].size.y)
	# UN PIXEL DE SEPARACION ENTRE FOTOGRAMAS. Sin el, al AMPLIAR el sprite en pantalla (la vista
	# previa lo pone a x3,4) la GPU muestrea medio pixel de mas y se cuela el borde del fotograma
	# vecino: se ve como una RAYA fina pegada al personaje. No sale en las hojas de contacto porque
	# esas se componen leyendo las imagenes a mano, sin pasar por la GPU -- o sea que es un fallo que
	# solo existe en el juego.
	var SEP := 1
	var ancho_hoja: int = maxi(w, int(ceil(sqrt(float(area)) * 1.15)))
	var cx: int = 0
	var cy: int = 0
	var alto_estante: int = 0
	for t in orden:
		var c: Rect2i = t["caja"]
		if c.size.x <= 0:
			t["en"] = Vector2i.ZERO
			continue
		if cx + c.size.x > ancho_hoja:
			cx = 0
			cy += alto_estante + SEP
			alto_estante = 0
		t["en"] = Vector2i(cx, cy)
		cx += c.size.x + SEP
		alto_estante = maxi(alto_estante, c.size.y)
	var alto_hoja: int = maxi(1, cy + alto_estante + SEP)

	# 3. Pintar. Se escribe DIRECTO sobre los bytes de la hoja, sin crear una imagen por frame.
	var datos := PackedByteArray()
	datos.resize(ancho_hoja * alto_hoja * 4)
	# 'resize' NO PONE CEROS: reserva sitio y deja lo que hubiera en esa memoria. Aqui solo se
	# escriben las celdas que NO son vacio, asi que sin este 'fill' todo el hueco de la hoja -- entre
	# fotograma y fotograma, y el margen del empaquetado -- queda con basura. Se ve como ruido de
	# puntos blancos y negros alrededor de los sprites, y aparece o no segun lo que el proceso tuviera
	# antes en esa memoria: o sea que un dia se ve y otro no.
	datos.fill(0)
	for t in orden:
		var c: Rect2i = t["caja"]
		if c.size.x <= 0:
			continue
		var celdas: PackedByteArray = t["celdas"]
		var en: Vector2i = t["en"]
		for y in c.size.y:
			var origen: int = (c.position.y + y) * w + c.position.x
			var destino: int = ((en.y + y) * ancho_hoja + en.x) * 4
			for x in c.size.x:
				var tono: int = celdas[origen + x]
				if tono == VACIO:
					continue
				var o: int = destino + x * 4
				var p: int = tono * 4
				datos[o] = pal[p]
				datos[o + 1] = pal[p + 1]
				datos[o + 2] = pal[p + 2]
				datos[o + 3] = pal[p + 3]
	var hoja := ImageTexture.create_from_image(
		Image.create_from_data(ancho_hoja, alto_hoja, false, Image.FORMAT_RGBA8, datos))

	# 4. Un AtlasTexture por frame. El 'margin' repone el hueco que se recorto, asi que la textura
	#    sigue midiendo w x h y dibujandose donde estaba: quien la use no nota nada.
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in anims:
		sf.add_animation(a["nombre"])
		sf.set_animation_loop(a["nombre"], a["loop"])
		sf.set_animation_speed(a["nombre"], a["fps"])
	for t in trozos:
		var c: Rect2i = t["caja"]
		var at := AtlasTexture.new()
		at.atlas = hoja
		# UN FOTOGRAMA VACIO NO USA EL ATLAS: lleva su propia textura transparente (ver 'vacia').
		if c.size.x <= 0 or c.size.y <= 0:
			sf.add_frame(t["anim"], vacia())
			continue
		at.region = Rect2(t["en"].x, t["en"].y, c.size.x, c.size.y)
		# OJO CON ESTO: el tamaño final de un AtlasTexture es region.size + margin.SIZE, y
		# margin.POSITION es donde empieza a dibujarse. O sea que el size del margen es el hueco
		# TOTAL que falta (w - recorte), no "lo que sobra por el otro lado". Restandole ademas la
		# posicion, la textura salia mas pequeña de lo que debia y el bicho aparecia CORTADO EN SECO
		# por abajo y por la derecha.
		at.margin = Rect2(c.position.x, c.position.y, w - c.size.x, h - c.size.y)
		at.filter_clip = true     # sin esto, al ampliar se cuela el pixel del frame vecino
		sf.add_frame(t["anim"], at)
	return sf


# ============================================================
#  HORNEAR: dejar el atlas en disco como un PNG normal y corriente
# ============================================================
# Generar los sprites cuesta ~3 s por partida y obliga a precalentarlos antes de que nazca nadie.
# Guardados en disco no cuesta NADA: cargar un PNG son milisegundos, Godot los importa con
# compresion de textura (que una imagen creada en runtime no puede aprovechar) y ademas se pueden
# abrir y retocar a mano. Y ocupan una miseria: los diez enemigos dibujados, con todas sus variantes
# de color, son 1,5 MB -- el pixel-art con pocos colores comprime muchisimo.
#
# El generador NO se tira: pasa de ejecutarse en cada partida a ser la herramienta que produce el
# PNG. Y si el horneado no esta (porque estas tocando un generador), SpritesEnemigo genera al vuelo
# como siempre, asi que el desarrollo no se rompe.
#
# Se guardan DOS ficheros por variante: el .png con el atlas y un .json con donde cae cada frame.
# El json y no un SpriteFrames .tres porque un .tres con AtlasTexture apuntando a una textura recien
# creada obliga a reimportar a media herramienta; con el json se controla todo y no hay bailes.

# La carpeta POR DEFECTO. Va como argumento opcional en 'hornear' y 'cargar_horneado' porque el
# jugador se hornea en la suya (assets/sprites/player/): son ~35 capas que no pintan nada mezcladas
# con los bichos, y separarlas deja ver de un vistazo cuanto ocupa cada cosa. Con el valor por
# defecto puesto, los cuatro generadores de bichos no se enteran del cambio.
const CARPETA_HORNO := "res://assets/sprites/enemigos/"


# Los datos de un SpriteFrames hecho con montar_frames, listos para guardar como json.
static func describir(sf: SpriteFrames) -> Dictionary:
	var anims: Array = []
	var w: int = 0
	var h: int = 0
	var nombres: PackedStringArray = sf.get_animation_names()
	nombres.sort()
	for a in nombres:
		var marcos: Array = []
		for i in sf.get_frame_count(a):
			var at: AtlasTexture = sf.get_frame_texture(a, i) as AtlasTexture
			# LOS FOTOGRAMAS VACIOS NO SON AtlasTexture (ver 'vacia'), y aqui se SALTABAN: eso los
			# borraba del horneado, asi que al cargarlo la animacion venia con menos fotogramas que
			# antes y todo lo posterior se corria un sitio. Se guardan con tamaño cero, que es como
			# vuelven a reconocerse.
			if at == null:
				marcos.append([0, 0, 0, 0, 0, 0])
				continue
			marcos.append([int(at.region.position.x), int(at.region.position.y),
				int(at.region.size.x), int(at.region.size.y),
				int(at.margin.position.x), int(at.margin.position.y)])
			w = int(at.region.size.x + at.margin.size.x)
			h = int(at.region.size.y + at.margin.size.y)
		anims.append({"n": a, "loop": sf.get_animation_loop(a), "fps": sf.get_animation_speed(a),
			"f": marcos})
	return {"w": w, "h": h, "anims": anims}


# Escribe el par .png + .json de una variante ya generada. Devuelve los bytes del png, o 0 si falla.
static func hornear(sf: SpriteFrames, clave: String, carpeta: String = CARPETA_HORNO) -> int:
	var at: AtlasTexture = sf.get_frame_texture(sf.get_animation_names()[0], 0) as AtlasTexture
	if at == null:
		return 0
	DirAccess.make_dir_recursive_absolute(carpeta)
	var png: String = carpeta + clave + ".png"
	if at.atlas.get_image().save_png(ProjectSettings.globalize_path(png)) != OK:
		return 0
	var f := FileAccess.open(carpeta + clave + ".json", FileAccess.WRITE)
	if f == null:
		return 0
	f.store_string(JSON.stringify(describir(sf)))
	f.close()
	var g := FileAccess.open(png, FileAccess.READ)
	var n: int = g.get_length() if g != null else 0
	if g != null:
		g.close()
	return n


# Reconstruye el SpriteFrames desde el horneado, o null si esa variante no esta en disco.
static func cargar_horneado(clave: String, carpeta: String = CARPETA_HORNO) -> SpriteFrames:
	var png: String = carpeta + clave + ".png"
	var js: String = carpeta + clave + ".json"
	if not ResourceLoader.exists(png) or not FileAccess.file_exists(js):
		return null
	var hoja: Texture2D = load(png) as Texture2D
	if hoja == null:
		return null
	var f := FileAccess.open(js, FileAccess.READ)
	if f == null:
		return null
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return null
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in d["anims"]:
		sf.add_animation(a["n"])
		sf.set_animation_loop(a["n"], bool(a["loop"]))
		sf.set_animation_speed(a["n"], float(a["fps"]))
		for m in a["f"]:
			# Fotograma vacio: se guardo con tamaño cero y vuelve como la textura transparente.
			if int(m[2]) <= 0 or int(m[3]) <= 0:
				sf.add_frame(a["n"], vacia())
				continue
			var at := AtlasTexture.new()
			at.atlas = hoja
			at.region = Rect2(m[0], m[1], m[2], m[3])
			at.margin = Rect2(m[4], m[5], int(d["w"]) - int(m[2]), int(d["h"]) - int(m[3]))
			at.filter_clip = true
			sf.add_frame(a["n"], at)
	return sf


# ------------------------------------------------------------
#  Formas
# ------------------------------------------------------------

static func en_elipse(gx: int, gy: int, cx: float, cy: float, rx: float, ry: float) -> bool:
	if rx <= 0.01 or ry <= 0.01:
		return false
	var dx: float = (float(gx) + 0.5 - cx) / rx
	var dy: float = (float(gy) + 0.5 - cy) / ry
	return dx * dx + dy * dy <= 1.0


# Elipse GIRADA (y opcionalmente vista EN PERSPECTIVA): el punto de pantalla se lleva al sistema de
# la elipse -- primero deshaciendo el aplastado, luego el giro -- y ahi se compara como siempre.
# Se le pasan el coseno y el seno ya calculados porque esto se llama por celda.
#
# 'persp' < 1 aplasta el eje vertical, que es lo que convierte una vista CENITAL PURA (camara justo
# encima, se ve solo el lomo) en la vista inclinada de un acion-RPG top-down, donde ademas de la
# espalda se le intuye la cara al bicho. Deshacerlo aqui, en el test, es exacto y gratis: una
# elipse aplastada sigue siendo una elipse.
static func en_elipse_rot(gx: int, gy: int, cx: float, cy: float, rx: float, ry: float,
		cos_a: float, sin_a: float, persp: float = 1.0) -> bool:
	if rx <= 0.01 or ry <= 0.01:
		return false
	var px: float = float(gx) + 0.5 - cx
	var py: float = (float(gy) + 0.5 - cy) / maxf(0.05, persp)
	var dx: float = (px * cos_a + py * sin_a) / rx
	var dy: float = (-px * sin_a + py * cos_a) / ry
	return dx * dx + dy * dy <= 1.0


# Marca una elipse en la plantilla recorriendo SOLO su caja envolvente: por cada ojo o cada mota de
# 3 celdas, recorrer la rejilla entera era casi todo el coste de un frame.
# 'ang' la gira (0 = sin giro, y ahi coge la rama rapida sin senos ni cosenos).
# 'solo_sobre' limita el pintado a celdas que ya tengan uno de esos tonos: es lo que permite echar
# un brillo encima del cuerpo sin que se derrame sobre las orejas o el contorno.
static func elipse(plant: PackedByteArray, w: int, h: int, cx: float, cy: float,
		rx: float, ry: float, tono: int, ang: float = 0.0, solo_sobre: Array = [],
		persp: float = 1.0) -> void:
	if rx <= 0.01 or ry <= 0.01:
		return
	var deformada: bool = not is_zero_approx(ang) or not is_equal_approx(persp, 1.0)
	var cos_a: float = cos(ang)
	var sin_a: float = sin(ang)
	# Caja envolvente EXACTA de la elipse girada (y aplastada): las proyecciones de sus semiejes.
	# Usar el radio mayor por los dos lados es lo facil, pero para una pieza alargada -- el cuerpo
	# del bicho -- pinta un cuadrado donde cabria un rectangulo, y se recorre hueco de mas en la
	# parte mas cara del generador.
	var ex: float = rx
	var ey: float = ry
	if deformada:
		var cs: float = cos_a * cos_a
		var sn: float = sin_a * sin_a
		ex = sqrt(rx * rx * cs + ry * ry * sn)
		ey = sqrt(rx * rx * sn + ry * ry * cs) * persp
	var x0: int = maxi(0, int(floor(cx - ex)))
	var x1: int = mini(w - 1, int(ceil(cx + ex)))
	var y0: int = maxi(0, int(floor(cy - ey)))
	var y1: int = mini(h - 1, int(ceil(cy + ey)))
	var filtra: bool = not solo_sobre.is_empty()

	# RUTA POR FILAS, para la elipse SIN GIRAR (aunque este en perspectiva). Sin giro los ejes de la
	# elipse son los de la rejilla, asi que el semiancho es el mismo en toda la fila: sale de UN sqrt
	# por fila y el tramo se rellena de un tiron, sin preguntar celda por celda ni llamar a nadie.
	#
	# No es un adorno. El slime dibuja cuatro elipses del tamaño del bicho entero, y por la ruta
	# general -- una llamada a en_elipse_rot por celda -- generar sus sprites pasaba de 0,1 a 1,1
	# segundos, y los del Rey Slime a SIETE. Es exactamente el mismo truco que ya se le hizo en su dia
	# al cuerpo del slime cuando se calculaba a mano.
	if is_zero_approx(ang):
		var ryp: float = ry * persp
		for gy in range(y0, y1 + 1):
			var dy: float = (float(gy) + 0.5 - cy) / ryp
			if absf(dy) > 1.0:
				continue
			var half: float = rx * sqrt(1.0 - dy * dy)
			var fila: int = gy * w
			var gx0: int = maxi(x0, int(ceil(cx - half - 0.5)))
			var gx1: int = mini(x1, int(floor(cx + half - 0.5)))
			for gx in range(gx0, gx1 + 1):
				var idx: int = fila + gx
				if filtra and not (int(plant[idx]) in solo_sobre):
					continue
				plant[idx] = tono
		return

	for gy in range(y0, y1 + 1):
		var fila: int = gy * w
		for gx in range(x0, x1 + 1):
			var dentro: bool = en_elipse_rot(gx, gy, cx, cy, rx, ry, cos_a, sin_a, persp) if deformada \
				else en_elipse(gx, gy, cx, cy, rx, ry)
			if not dentro:
				continue
			var idx: int = fila + gx
			if filtra and not (int(plant[idx]) in solo_sobre):
				continue
			plant[idx] = tono


# Caja de trabajo recortada al lienzo, con una celda de aire alrededor (el contorno mira a los
# vecinos, asi que hace falta sitio para ese vecino vacio).
static func caja(x0: float, y0: float, x1: float, y1: float, w: int, h: int) -> Rect2i:
	var ix0: int = clampi(int(floor(x0)) - 1, 0, w - 1)
	var ix1: int = clampi(int(ceil(x1)) + 2, 0, w)
	var iy0: int = clampi(int(floor(y0)) - 1, 0, h - 1)
	var iy1: int = clampi(int(ceil(y1)) + 2, 0, h)
	return Rect2i(ix0, iy0, maxi(0, ix1 - ix0), maxi(0, iy1 - iy0))


# Caja que envuelve a un array de piezas {pos: Vector2, radio: Vector2, persp: float}, con aire para
# el contorno. Cada generador la repetia igual.
static func caja_de_piezas(piezas: Array, w: int, h: int) -> Rect2i:
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		# Si la pieza GIRA, el radio que manda es el mayor de los dos (puede caer en cualquier eje);
		# si solo esta aplastada, la vertical es su radio por la perspectiva.
		var rx: float = maxf(r.x, r.y) if bool(p.get("gira_forma", false)) else r.x
		var ry: float = maxf(r.x, r.y) if bool(p.get("gira_forma", false)) \
			else r.y * float(p.get("persp", 1.0))
		x0 = minf(x0, pos.x - rx)
		x1 = maxf(x1, pos.x + rx)
		y0 = minf(y0, pos.y - ry)
		y1 = maxf(y1, pos.y + ry)
	return caja(x0, y0, x1, y1, w, h)


# Repasa la silueta y convierte en 'borde' las celdas que tocan el vacio.
#
# Trabaja sobre una COPIA porque, si no, el borde recien puesto contaria como relleno para su vecino
# y la linea se comeria la figura hacia dentro.
#
# Se perfila la forma ENTERA YA FUSIONADA, nunca pieza a pieza: si no, cada elipse traeria su propio
# circulito marcado por dentro y los cuernos dejarian de leerse como parte del bicho.
#
# 'hueco_a' y 'hueco_b' son los dos tonos que cuentan como "fuera" (normalmente VACIO y la sombra
# del suelo, que no debe llevar contorno). Van como enteros sueltos y el test va EN LINEA a
# proposito: son cuatro vecinos por celda y decenas de miles de celdas por frame x 192 frames, o sea
# millones de comprobaciones. Una llamada a funcion por vecino aqui se nota en segundos.
static func contornear(plant: PackedByteArray, cj: Rect2i, w: int, h: int, borde: int,
		hueco_a: int, hueco_b: int) -> void:
	var copia := plant.duplicate()
	for gy in range(cj.position.y, cj.end.y):
		var fila: int = gy * w
		for gx in range(cj.position.x, cj.end.x):
			var idx: int = fila + gx
			var t: int = copia[idx]
			if t == hueco_a or t == hueco_b:
				continue
			# EL BORDE DEL LIENZO SE MIRA ANTES DE LEER A LOS VECINOS, y no a la vez.
			#
			# Estaban en el mismo 'or', asi que los cuatro vecinos se leian SIEMPRE -- tambien en la
			# ultima fila, donde 'idx + w' ya esta fuera del array. Nunca habia saltado porque las
			# figuras no llegaban a tocar el borde exacto del lienzo (todos estan medidos con holgura),
			# pero en cuanto una lo toca, revienta con un 'Out of bounds' que no dice de que bicho es.
			# El resultado no cambia: estar en el borde ya contaba como tocar el vacio.
			if gx <= 0 or gx >= w - 1 or gy <= 0 or gy >= h - 1:
				plant[idx] = borde
				continue
			var a: int = copia[idx + 1]
			var b: int = copia[idx - 1]
			var c: int = copia[idx + w]
			var d: int = copia[idx - w]
			if a == hueco_a or a == hueco_b or b == hueco_a or b == hueco_b \
					or c == hueco_a or c == hueco_b or d == hueco_a or d == hueco_b:
				plant[idx] = borde


# ------------------------------------------------------------
#  Animacion
# ------------------------------------------------------------

# UNA DIRECCION DE PANTALLA (+Y abajo) A UNO DE LOS 8 SECTORES:
#     0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW
# que es el orden en que TODO lo que se dibuja por codigo nombra sus animaciones.
#
# Vivia en SpritesEnemigo, y se subio aqui al entrar el jugador: la convencion de direcciones es del
# JUEGO, no de los bichos. El jugador y el enemigo se cruzan en el mapa y tienen que mirarse a la
# cara, asi que no puede haber dos funciones que traduzcan un vector a un sector -- el dia que una
# se corrigiera medio sector, el bicho miraria a un sitio y el jugador a otro y nadie sabria cual de
# los dos esta mal. SpritesEnemigo la conserva como delegado para no tocar a quien ya la llamaba.
static func dir8(dir: Vector2) -> int:
	var ang: float = dir.angle()   # 0 = derecha (E), crece en sentido horario (Y abajo)
	var sector: int = int(round((PI / 2.0 - ang) / (PI / 4.0)))
	return ((sector % 8) + 8) % 8

# Interpolacion lineal entre puntos clave [t, valor] ordenados por t. Fuera del rango se queda con
# el extremo mas cercano (no extrapola). Para movimientos que NO son periodicos -- una embestida es
# agazaparse, lanzarse, chocar y recuperarse, no una onda.
static func tramos(t: float, claves: Array) -> float:
	if t <= claves[0][0]:
		return claves[0][1]
	for i in range(claves.size() - 1):
		var a: Array = claves[i]
		var b: Array = claves[i + 1]
		if t <= b[0]:
			var f: float = clampf((t - a[0]) / maxf(0.0001, b[0] - a[0]), 0.0, 1.0)
			return lerpf(a[1], b[1], f)
	return claves[-1][1]
