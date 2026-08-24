# ============================================================
#  slime_sprites.gd  (class_name SlimeSprites)
#  Sprite del slime DIBUJADO POR CODIGO (Image.create + set_pixel), igual que las texturas de
#  particulas.gd -- ni un solo archivo .png. Es el placeholder "cutrecillo" acordado: cuando haya
#  arte de verdad, basta con rellenar EnemyData.sprite_frames y este generador deja de usarse solo
#  (ver enemy.gd, que prueba sprite_frames antes que esto).
#
#  8 DIRECCIONES (0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW) x 3 animaciones (idle/walk/embestida) x
#  FRAMES imagenes, generadas UNA vez y compartidas por TODOS los slimes del mismo color (ver cache
#  por color: un slime elemental algun dia podria pedir generar(color_del_fuego) sin pisar el rojo
#  del normal -- que es el que le toca: EnemyData.color por defecto es rojo y slime.tres no lo
#  cambia, asi que sale rojo solo con pasarle data.color_visual(), no hace falta tocar nada aqui).
#
#  EL CUERPO es la union de dos elipses (la cupula redonda arriba + la base achatada abajo,
#  recortada en seco a una fila fija para que el fondo sea PLANO) mas dos orejitas -- elipses
#  pequeñas aparte. Es matematica, no una rejilla dibujada a mano: mover un parametro cambia la
#  silueta entera sin tener que recontar caracteres uno a uno.
#
#  IDLE/WALK se generan con una FORMULA (seno/coseno) en vez de una lista de valores por frame:
#  cambiar FRAMES no obliga a rehacer ninguna tabla. EMBESTIDA no es periodica (agazapar -> lanzar
#  -> impacto -> recuperar), asi que va por TRAMOS (puntos clave interpolados).
# ============================================================

extends RefCounted
class_name SlimeSprites

# --- Cuantos frames tiene cada animacion. Subir esto no rompe nada: las formulas de abajo se
# adaptan solas (ver _montar_idle/_montar_walk/_montar_embestida). ---
const FRAMES := 8

# --- Rejilla logica y escalado a pixel real. El CUERPO (CX/DOME_*/BASE_*) vive centrado dentro de
# un lienzo con MARGEN de sobra alrededor: el bote del walk y el vuelo de la embestida ESTIRAN y
# DESPLAZAN la silueta, y sin hueco alrededor esos frames se recortaban contra el borde del lienzo
# (se veian "cortados" por arriba, por los lados o por abajo segun la direccion). El tamaño en
# PANTALLA no depende de este margen: escala_base() lo calcula sobre el DIAMETRO DEL CUERPO en
# reposo, no sobre el lienzo entero (ver mas abajo). ---
const MARGEN_ARRIBA := 19.0   # la corona (pico central a -15.5) llega mas arriba que las orejas (-9)
const MARGEN_ABAJO := 14.0
const MARGEN_LADOS := 10.0
const GRID_W := 40 + int(MARGEN_LADOS) * 2
const GRID_H := 32 + int(MARGEN_ARRIBA) + int(MARGEN_ABAJO)
# La textura se genera a 1 celda = 1 PIXEL y es el NODO el que la amplia (con filtro NEAREST, ver
# escala_base y quien la usa). Antes cada celda se escribia como un bloque de 3x3 pixeles: nueve
# veces mas trabajo y nueve veces mas memoria para exactamente la misma imagen en pantalla.
const PX := 1
const IMG_W := GRID_W * PX
const IMG_H := GRID_H * PX

# Diametro en unidades de MUNDO al que debe verse un slime normal (el cuerpo de siempre es 32x32).
# Un pelin mas grande a proposito: la base achatada se sale un poco de su propia caja, que es como
# se ve un charco de verdad asomando por los bordes de su hitbox.
# OJO: se mide sobre el CUERPO (DOME_RX*2), NO sobre IMG_W -- el lienzo lleva margen de sobra para
# que el bote/la embestida no se recorten, y ese margen no puede hacer que el cuerpo se vea mas chico.
const WORLD_DIAMETRO := 34.0
static func escala_base() -> float:
	return WORLD_DIAMETRO / (DOME_RX * 2.0 * PX)

# --- Silueta base (direccion S, sin squash), CENTRADA dentro del margen de arriba/lados. ---
#
# UNA SOLA elipse, cortada por ENCIMA de su ecuador. Dos intentos anteriores fallaron por aqui:
#   1. Dos elipses (cupula + base mas ancha): donde una asomaba de la otra quedaba un ESCALON --
#      los "hombros" cuadrados que se veian por mucho que se tocaran los radios.
#   2. Una elipse cortada por DEBAJO del ecuador: el tramo del ecuador es casi VERTICAL, asi que
#      los costados salian rectos como los de un cubo y seguia sin verse redondo.
# Cortandola por ENCIMA del ecuador el semiancho crece sin parar hasta el suelo: el contorno es un
# arco continuo desde la coronilla hasta la base, que es lo mas ancho -- una cupula/campana, que es
# la forma pedida (redondito arriba, plano abajo donde toca el suelo).
#
# La geometria se declara por lo que se VE (donde esta la coronilla, cuanto mide de alto, cuanto de
# ancho en la base) y la elipse que lo produce se DERIVA de eso: tocar la forma es tocar estos tres
# numeros, no resolver a mano donde cae el centro de una elipse que ni siquiera es visible.
const CX := 20.0 + MARGEN_LADOS
const CABEZA_TOP := 2.0 + MARGEN_ARRIBA   # fila del punto mas alto del cuerpo
const ALTO_CUERPO := 22.0
const DOME_RX := 15.0                     # semiancho MAXIMO (en la base, antes del labio)
const FLAT_BOTTOM_ROW := CABEZA_TOP + ALTO_CUERPO   # por debajo de esta fila se recorta: el suelo
# Elipse maestra: una BOLA APOYADA, o sea con su ECUADOR (la parte mas ancha) a media altura del
# cuerpo y cortada por debajo de el, de forma que hacia el suelo el contorno vuelve a CERRARSE un
# poco. Eso es lo que se lee como redondo, y las tres variantes que se probaron antes no:
#   * dos elipses (cupula + base ancha) -> ESCALON en los hombros;
#   * media elipse con el centro en el suelo -> el ancho solo crece, nunca cierra: TRAPECIO;
#   * elipse cortada por debajo del ecuario con el centro muy abajo -> costados casi verticales.
# La forma correcta la marco el usuario a boceto: lo mas ancho a media altura y la base plana solo
# donde toca el suelo, como una gota posada.
const CINTURA_FRAC := 0.59          # a que fraccion del alto queda la parte mas ancha
const ELIPSE_RY := ALTO_CUERPO * CINTURA_FRAC
const ELIPSE_CY := CABEZA_TOP + ELIPSE_RY
# Centro y semialto VISUALES (los del cuerpo que se ve, no los de la elipse maestra, que cae muy por
# debajo del sprite). Los usan los brillos especulares para colocarse.
const DOME_CY := CABEZA_TOP + ALTO_CUERPO * 0.5
const DOME_RY := ALTO_CUERPO * 0.5
# LABIO del charco: en las ultimas filas el cuerpo se ensancha un poco mas, como la baba que se
# derrama al posarse. Va con t² (no lineal) para que nazca de la nada y no vuelva a crear escalon.
# OJO al subir esto: un ensanche marcado en las ultimas filas deja de leerse como panza y se lee
# como el ALA DE UN SOMBRERO, porque rompe en seco la curva de la cupula justo donde acaba.
const CHARCO_ALTO := 6.0
const CHARCO_ENSANCHE := 1.5
# Cuanto se ARQUEA la linea que separa la panza en sombra del cuerpo claro. Recta (0) se lee como
# un corte de tijera; arqueada es la elipse del suelo vista en perspectiva, que es lo que hay ahi.
const SOMBRA_ARQUEO := 2.2
const BASE_RX := 17.0               # solo para el ancho de la sombra de contacto en el suelo
const EAR_RX := 2.6
const EAR_RY := 5.0
const LUNGE_DIST := 7.0             # cuanto viaja el cuerpo en la embestida, en unidades de rejilla

# --- Vectores de las 8 direcciones (pantalla: +Y es hacia ABAJO) ---
const DIR_VECS := [
	Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0), Vector2(0.7, -0.7),
	Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(-1, 0), Vector2(-0.7, 0.7),
]

# --- Cache: un SpriteFrames por color (compartido entre instancias, igual que Particulas) ---
static var _cache: Dictionary = {}


# 'corona' = true para el Rey Slime (EnemyData.corona_slime): cambia las dos orejas por una CORONA
# de 5 puntas hecha del mismo gel (ver _corona_para) -- el resto (cuerpo, ojos, animaciones) es
# identico al slime normal, asi que se cachea aparte con su propia clave.
# CUANTIZAR EL COLOR ANTES DE CACHEAR NO ES UN DETALLE, ES LO QUE HACE QUE EL CACHE EXISTA (ver
# SpriteLienzo.cuantizar): el color llega de EnemyData.color_visual(current_t) y current_t es un
# randf() POR BICHO, asi que sin redondearlo hay tantas variantes como bichos.
const COLOR_PASOS := 6.0


# --- Contrato de SpritesEnemigo (el registro que decide quien dibuja a quien) ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.corona_slime)


static func ancho_px(_escala: float = 1.0) -> int:
	return IMG_W


# false: el slime genera SIEMPRE la misma textura y es enemy.gd quien la estira con escala_visual,
# asi que a los grandes (el de fuego a 1.6, el Rey a 2.6) les salen los pixeles gordos. Esta
# pendiente de arreglarse a la vez que su paso a la perspectiva de 45 grados, que le rehace la
# geometria de todas formas -- hacerlo ahora seria cambiarle el aspecto dos veces. La receta ya
# hecha esta en rata_sprites.gd.
static func dimensiona_por_escala() -> bool:
	return false


static func generar(color: Color = Color(1.0, 0.2, 0.2), corona: bool = false) -> SpriteFrames:
	var col: Color = SpriteLienzo.cuantizar(color, COLOR_PASOS)
	var clave: String = col.to_html(false) + ("_corona" if corona else "")
	if _cache.has(clave):
		return _cache[clave]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_montar_idle(sf, col, corona)
	_montar_walk(sf, col, corona)
	_montar_embestida(sf, col, corona)
	_cache[clave] = sf
	return sf


# Respira: squash casi plano, oscilando muy poco. Sin desplazamiento.
static func _montar_idle(sf: SpriteFrames, color: Color, corona: bool) -> void:
	var squash_fn := func(t: float) -> float: return 1.0 + 0.03 * sin(TAU * t)
	var offset_fn := func(_t: float, _dv: Vector2) -> Vector2: return Vector2.ZERO
	_montar_animacion(sf, color, corona, "idle", true, 4.0, squash_fn, offset_fn, false)


# Bote al andar: aplastado al tocar suelo (t=0), estirado en el aire (t=0.5). El bote vertical usa
# la MISMA fase, asi que el cuerpo esta mas alto justo cuando esta mas estirado -- es lo que lo hace
# leer como un salto y no como un cuadrado respirando.
static func _montar_walk(sf: SpriteFrames, color: Color, corona: bool) -> void:
	var squash_fn := func(t: float) -> float: return 1.0 - 0.17 * cos(TAU * t)
	var bob: float = DOME_RY * 0.25
	var offset_fn := func(t: float, _dv: Vector2) -> Vector2: return Vector2(0.0, -bob * sin(PI * t))
	_montar_animacion(sf, color, corona, "walk", true, 8.0, squash_fn, offset_fn, false)


# Agazapar -> lanzar -> impacto -> recuperar. NO es periodica (no vuelve al punto de partida), asi
# que va por TRAMOS en vez de una formula trigonometrica.
static func _montar_embestida(sf: SpriteFrames, color: Color, corona: bool) -> void:
	var squash_keys := [[0.0, 1.0], [0.25, 0.60], [0.55, 1.25], [0.75, 0.70], [1.0, 0.95]]
	var offset_keys := [[0.0, 0.0], [0.25, 0.0], [0.55, 0.90], [0.75, 0.95], [1.0, 0.70]]
	var squash_fn := func(t: float) -> float: return SpriteLienzo.tramos(t, squash_keys)
	var offset_fn := func(t: float, dv: Vector2) -> Vector2: \
		return dv * SpriteLienzo.tramos(t, offset_keys) * LUNGE_DIST
	_montar_animacion(sf, color, corona, "embestida", false, 10.0, squash_fn, offset_fn, true)


# Registra las 8 direcciones de UNA animacion, llamando a squash_fn/offset_fn con la fase 't' de
# cada frame. 'ultimo_incluido' = true para embestida (t recorre 0..1 INCLUSIVE, el ultimo frame es
# el reposo final); false para idle/walk (t recorre 0..1 SIN llegar a 1, porque el frame 1.0 seria
# identico al 0.0 del siguiente bucle -- incluirlo daria un frame de mas que se queda quieto).
static func _montar_animacion(sf: SpriteFrames, color: Color, corona: bool, nombre: String, loop: bool, fps: float,
		squash_fn: Callable, offset_fn: Callable, ultimo_incluido: bool) -> void:
	var divisor: float = float(FRAMES - 1) if ultimo_incluido else float(FRAMES)
	var paleta: PackedByteArray = SpriteLienzo.paleta(_colores(color, corona))
	for dir in 8:
		var anim: String = "%s_%d" % [nombre, dir]
		sf.add_animation(anim)
		sf.set_animation_loop(anim, loop)
		sf.set_animation_speed(anim, fps)
		for i in FRAMES:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, corona) y NO por color: el
			# segundo slime rojo de otro tono reusa estas mismas plantillas y solo repinta.
			var clave: String = "%s_%d_%d_%d" % [nombre, i, dir, 1 if corona else 0]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				var t: float = float(i) / divisor
				plant = _plantilla(dir, squash_fn.call(t), offset_fn.call(t, DIR_VECS[dir]), corona)
				_cache_plantillas[clave] = plant
			sf.add_frame(anim, SpriteLienzo.a_textura(plant, paleta, GRID_W, GRID_H))


# TONOS de la plantilla: la geometria no guarda COLORES, guarda a que "capa" pertenece cada celda.
# Asi la parte cara (elipses, raices, contorno) se calcula UNA vez y sirve para cualquier color:
# pintar otra variante es solo mapear tonos -> colores (ver SpriteLienzo).
# El enum es SUYO, no del motor: la rata tiene otras ranuras (cola, dientes) y no arrastra estas.
enum Tono { VACIO, SOMBRA_SUELO, BORDE, SOMBRA, BASE, CLARO, CLARO_TENUE, CORONA, OJO, GEMA }

# Plantillas ya calculadas, por clave geometrica (animacion + frame + direccion + corona). NO
# depende del color, que es justo lo que la hace reutilizable entre variantes.
static var _cache_plantillas: Dictionary = {}


# La GEOMETRIA de un frame: que tono le toca a cada celda. 'squash' < 1 = aplastado (impacto/
# contacto), > 1 = estirado (vuelo/aire); el volumen se conserva a ojo (lo que se pierde de alto se
# gana de ancho, y viceversa).
static func _plantilla(dir: int, squash: float, offset: Vector2, corona: bool) -> PackedByteArray:
	var plant := PackedByteArray()
	plant.resize(GRID_W * GRID_H)

	var sy: float = squash
	var sx: float = 1.0 / sqrt(maxf(0.2, squash))
	var cx: float = CX + offset.x
	var dome_cy: float = DOME_CY * sy + offset.y
	var flat_row: float = FLAT_BOTTOM_ROW * sy + offset.y
	var dome_rx: float = DOME_RX * sx
	var dome_ry: float = DOME_RY * sy
	var elipse_cy: float = ELIPSE_CY * sy + offset.y
	var elipse_ry: float = ELIPSE_RY * sy

	# SOMBRA DE CONTACTO: una elipse plana y oscura, SIEMPRE en el suelo real (no sube ni baja con
	# el squash/bote), asi vende que el cuerpo esta en el aire cuando se separa de ella (walk/vuelo
	# de la embestida) y que esta "sentado" encima cuando coinciden (idle, contacto).
	var suelo_cy: float = FLAT_BOTTOM_ROW + 1.2
	_pintar_elipse(plant, CX, suelo_cy, BASE_RX * 0.75, 1.6, Tono.SOMBRA_SUELO)

	var cara: Dictionary = _cara_para(dir)
	var ojos: Array = cara["ojos"]
	# ORNAMENTOS de la cabeza: las dos orejas del slime normal, o las 5 puntas de la corona del Rey
	# (ver _corona_para) -- mismo mecanismo, cada uno con su propio radio.
	var ornamentos: Array = _corona_para(dir) if corona else _orejas_para(dir)

	# MASCARA primero, SEPARADA del coloreado: hace falta la forma COMPLETA (cuerpo + orejas/corona
	# ya fusionados) antes de poder saber que celdas son BORDE. Sin ese contorno oscuro las orejas y
	# la corona se perdian contra el cuerpo (mismo color, ninguna linea que las separe).
	#
	# Y los ornamentos llevan PROFUNDIDAD, que es lo que hace que se entienda cual esta delante:
	#   MASK_DELANTE  el que esta del lado hacia el que mira -> se pinta ENCIMA del cuerpo y lleva su
	#                 propio contorno tambien contra el cuerpo, asi se ve recortado por delante.
	#   MASK_DETRAS   el otro -> el CUERPO LE GANA (queda tapado por la cabeza, solo asoma la punta)
	#                 y ademas va en tono de sombra: lo de detras se ve mas apagado.
	var mask := PackedByteArray()
	mask.resize(GRID_W * GRID_H)
	# CAJA de trabajo: fuera de ella no hay nada que mirar ni que pintar. Con el lienzo lleno de
	# margen para el bote y la embestida, recorrerlo entero era mirar mucho hueco vacio.
	var caja: Rect2i = _caja_de_trabajo(cx, dome_rx, ornamentos, flat_row, offset, sx, sy)

	# Los ORNAMENTOS se marcan por su caja envolvente (ocupan 4-5 celdas cada uno); mirarlos desde
	# el bucle general obligaba a preguntar por TODOS ellos en CADA celda del sprite.
	for orn in ornamentos:
		var opos: Vector2 = orn["pos"]
		var orad: Vector2 = orn["radio"]
		_pintar_elipse(mask, cx + opos.x * sx, opos.y * sy + offset.y, orad.x * sx, orad.y * sy,
			MASK_DELANTE if bool(orn["delante"]) else MASK_DETRAS)

	# El CUERPO, POR FILAS: el semiancho de una fila es el mismo para todas sus celdas, asi que la
	# raiz cuadrada se saca UNA vez por fila en vez de una por celda (eran ~2.500 raices por frame x
	# 192 frames). Ademas el recorrido horizontal se limita ya a ese semiancho.
	var y0: int = maxi(caja.position.y, 0)
	var y1: int = mini(int(ceil(flat_row)), GRID_H - 1)
	var lip_alto: float = CHARCO_ALTO * sy
	var lip_desde: float = flat_row - lip_alto
	for gy in range(y0, y1 + 1):
		var yf: float = float(gy) + 0.5
		if yf > flat_row:
			continue
		var u: float = (yf - elipse_cy) / elipse_ry
		if absf(u) > 1.0:
			continue
		var half: float = dome_rx * sqrt(1.0 - u * u)
		if yf > lip_desde and lip_alto > 0.01:
			var lt: float = clampf((yf - lip_desde) / lip_alto, 0.0, 1.0)
			half += CHARCO_ENSANCHE * sx * lt * lt
		var gx0: int = maxi(0, int(floor(cx - half - 0.5)))
		var gx1: int = mini(GRID_W - 1, int(ceil(cx + half - 0.5)))
		var fila: int = gy * GRID_W
		for gx in range(gx0, gx1 + 1):
			if absf(float(gx) + 0.5 - cx) > half:
				continue
			# El cuerpo gana a lo de DETRAS y pierde contra lo de DELANTE.
			if mask[fila + gx] != MASK_DELANTE:
				mask[fila + gx] = MASK_CUERPO

	var fila_sombra: float = flat_row - 5.0 * sy
	var inv_rx: float = 1.0 / maxf(1.0, dome_rx)
	for gy in range(caja.position.y, caja.end.y):
		var fila: int = gy * GRID_W
		for gx in range(caja.position.x, caja.end.x):
			var idx: int = fila + gx
			var codigo: int = mask[idx]
			if codigo == MASK_FUERA:
				continue
			var t: int
			# BORDE en linea (sin llamada): dentro de la silueta con algun vecino fuera de ella.
			if gx <= 0 or gx >= GRID_W - 1 or gy <= 0 or gy >= GRID_H - 1 \
					or mask[idx + 1] == MASK_FUERA or mask[idx - 1] == MASK_FUERA \
					or mask[idx + GRID_W] == MASK_FUERA or mask[idx - GRID_W] == MASK_FUERA:
				t = Tono.BORDE
			elif codigo == MASK_DETRAS:
				t = Tono.SOMBRA          # lo que queda por detras, mas apagado
			elif codigo == MASK_DELANTE:
				# Ornamento de delante, SIN el sombreado del cuerpo: una oreja no se ensombrece por
				# estar "abajo del todo" solo porque su Y absoluta cae baja en el lienzo.
				t = Tono.CORONA if corona else Tono.BASE
			else:
				# Sombra hacia la base: da volumen sin degradado de verdad. El limite va ARQUEADO
				# (es la elipse del suelo en perspectiva); recto se lee como un corte de tijera.
				var dx: float = (float(gx) + 0.5 - cx) * inv_rx
				t = Tono.SOMBRA if float(gy) > fila_sombra + SOMBRA_ARQUEO * dx * dx else Tono.BASE
			plant[idx] = t

	# BRILLOS especulares: dos manchas claras en la cresta, pintadas DESPUES y solo sobre el cuerpo
	# ya coloreado. Antes se preguntaba por las dos elipses en cada celda del sprite; asi solo se
	# miran las pocas celdas que cubren.
	_pintar_elipse(plant, cx - dome_rx * 0.36, dome_cy - dome_ry * 0.60, dome_rx * 0.28, dome_ry * 0.24,
		Tono.CLARO, [Tono.BASE])
	_pintar_elipse(plant, cx + dome_rx * 0.30, dome_cy - dome_ry * 0.62, dome_rx * 0.14, dome_ry * 0.14,
		Tono.CLARO_TENUE, [Tono.BASE])

	for o in ojos:
		var ecx: float = cx + float(o["pos"].x) * sx
		var ecy: float = float(o["pos"].y) * sy + offset.y
		var esc: float = float(o["escala"])
		_pintar_elipse(plant, ecx, ecy, 2.2 * esc * sx, 3.2 * esc * sy, Tono.OJO)

	# GEMAS: una motita brillante en la PUNTA de cada pico de la corona -- lo que la hace leer como
	# joya y no como una segunda fila de orejas puntiagudas.
	if corona:
		for orn in ornamentos:
			var opos: Vector2 = orn["pos"]
			var orad: Vector2 = orn["radio"]
			var gcx: float = cx + opos.x * sx
			var gcy: float = opos.y * sy + offset.y - orad.y * sy * 0.55
			_pintar_elipse(plant, gcx, gcy, 1.0 * sx, 1.1 * sy, Tono.GEMA)

	return plant


# Los colores de cada Tono para un color de slime dado, EN EL ORDEN DEL ENUM (es el contrato con
# SpriteLienzo.paleta: el motor no sabe que es cada tono, solo mapea indice -> color).
static func _colores(color: Color, corona: bool) -> Array:
	return [
		Color(0, 0, 0, 0),                  # VACIO
		Color(0, 0, 0, 0.22),               # SOMBRA_SUELO
		color.darkened(0.55),               # BORDE
		color.darkened(0.28),               # SOMBRA
		color,                              # BASE
		color.lightened(0.30),              # CLARO
		color.lightened(0.16),              # CLARO_TENUE
		color.lightened(0.4) if corona else color,   # CORONA
		Color(0.95, 0.97, 0.85),            # OJO
		Color(1.0, 0.95, 0.72),             # GEMA
	]


# Codigos de la mascara de silueta (ver _dibujar_frame).
const MASK_FUERA := 0
const MASK_CUERPO := 1
# SIEMPRE fundido con el cuerpo, sin linea interior que los separe. Se probo darle contorno propio
# contra el cuerpo para "recortarlo" por delante y quedaba peor: como el cuerno nace justo en el
# filo de la cabeza, esa linea lo convierte en una pastilla suelta pegada al costado en vez de en
# algo que sale de ella. La profundidad ya la cuentan el TAMAÑO (el de delante se ve entero) y la
# SOMBRA del otro, que ademas queda tapado por la cabeza.
const MASK_DELANTE := 2
const MASK_DETRAS := 3     # el del lado contrario: el cuerpo lo tapa y va en tono de sombra


# NOTA: aqui vivian _en_cuerpo() y _es_borde(). Se borraron al optimizar: el cuerpo pasa a
# calcularse POR FILAS dentro de _plantilla (un sqrt por fila en vez de uno por celda) y el test de
# borde va EN LINEA en el bucle de coloreado (sin llamada por celda). Quedaron definidas pero sin
# usar hasta que se limpiaron. _en_elipse se mudo a SpriteLienzo.


# Zona del lienzo donde puede haber cuerpo u ornamentos, con UNA celda de aire alrededor (el
# contorno mira a los vecinos, asi que la caja tiene que dar para ese vecino vacio).
static func _caja_de_trabajo(cx: float, dome_rx: float, ornamentos: Array, flat_row: float,
		offset: Vector2, sx: float, sy: float) -> Rect2i:
	var x0: float = cx - dome_rx - CHARCO_ENSANCHE * sx
	var x1: float = cx + dome_rx + CHARCO_ENSANCHE * sx
	var y0: float = CABEZA_TOP * sy + offset.y
	for orn in ornamentos:
		var opos: Vector2 = orn["pos"]
		var orad: Vector2 = orn["radio"]
		x0 = minf(x0, cx + opos.x * sx - orad.x * sx)
		x1 = maxf(x1, cx + opos.x * sx + orad.x * sx)
		y0 = minf(y0, opos.y * sy + offset.y - orad.y * sy)
	return SpriteLienzo.caja(x0, y0, x1, flat_row, GRID_W, GRID_H)


# Atajo local: el motor pide las dimensiones del lienzo y aqui son siempre las mismas.
static func _pintar_elipse(plant: PackedByteArray, cx: float, cy: float, rx: float, ry: float,
		tono: int, solo_sobre: Array = []) -> void:
	SpriteLienzo.elipse(plant, GRID_W, GRID_H, cx, cy, rx, ry, tono, 0.0, solo_sobre)


# OREJAS y OJOS: puntos FIJOS pegados a la cabeza, en su posicion de FRENTE (direccion S).
# Al mirar hacia otro lado NO se mueven de altura (nada de "girar" de verdad: eso fue lo que salio
# mal la primera vez -- un punto simetrico que sube por un lado y baja por el otro se lee como la
# cara derritiendose). Lo unico que cambia es cuanto se ACERCAN AL CENTRO y hacia que lado se
# desliza el par entero. Ver _en_cabeza().
# Las posiciones van RELATIVAS A LA CORONILLA (CABEZA_TOP), con Y hacia abajo: es la referencia
# estable de la silueta -- la elipse maestra que la genera tiene el centro muy por debajo del
# sprite, asi que medir desde ella no dice nada. Las X estan elegidas para que cada pieza caiga
# JUSTO SOBRE el arco a su altura (calculado con el semiancho de esa fila), y asi nacen pegadas a
# la silueta en vez de flotando sueltas o hundidas dentro.
const OREJA_L_REL := Vector2(-7.5, 2.0)   # desde la coronilla, mirando al jugador (S)
const OREJA_R_REL := Vector2(7.5, 2.0)
const OJO_L_REL := Vector2(-5.2, 11.0)
const OJO_R_REL := Vector2(5.2, 11.0)
# De perfil el par colapsa hacia UN punto pegado al BORDE de la cabeza (no al centro): un slime
# visto de canto tiene la oreja/ojo cerca del filo delantero, no flotando en medio de la cupula.
# El lean de las orejas es CORTO a proposito: viven arriba, donde la cabeza todavia es estrecha, y
# un desplazamiento tan grande como el ancho de la base las dejaria flotando fuera de la silueta.
const LEAN_OREJA := 3.0     # cuanto se desplaza el par entero hacia el lado que mira (orejas/corona)
const LEAN_OJOS := 7.5      # lo mismo para los ojos, que van mas abajo (ahi el cuerpo ya es ancho)

# CORONA del Rey Slime: 5 puntas APOYADAS EN EL ARCO de la cupula (las de fuera mas bajas, la del
# medio en lo alto), HECHA DE SU PROPIO GEL -- no oro ajeno, por eso se colorea a partir de 'color'
# y no con un tono fijo (ver corona_color en _dibujar_frame). Sustituye a las orejas, no se suma.
const CORONA_REL := [
	Vector2(-10.5, 3.7), Vector2(-5.5, 0.9), Vector2(0.0, 0.0),
	Vector2(5.5, 0.9), Vector2(10.5, 3.7),
]
const CORONA_RADIO := [
	Vector2(2.0, 3.0), Vector2(2.0, 3.8), Vector2(2.2, 4.6),
	Vector2(2.0, 3.8), Vector2(2.0, 3.0),
]

# Punto FIJO de la cabeza (posicion de FRENTE) -> posicion para 'dir'. 'lado' = DIR_VECS[dir].x
# (-1..1: cuanto mira a izquierda/derecha; 0 en S y N). El punto se ACERCA AL CENTRO en proporcion a
# |lado| y el par entero se desliza 'lean' hacia el lado que mira. LA ALTURA (rel.y) NUNCA CAMBIA.
static func _en_cabeza(rel: Vector2, dir: int, lean: float) -> Vector2:
	var lado: float = DIR_VECS[dir].x
	var dx: float = rel.x * (1.0 - absf(lado) * 0.55) + lado * lean
	return Vector2(dx, CABEZA_TOP + rel.y)


# ¿Este ornamento (por su X de FRENTE) queda DELANTE de la cabeza o detras? Es lo que da la
# sensacion de volumen al girar: de medio lado, el cuerno del lado hacia el que mira se ve entero y
# recortado sobre el cuerpo, y el otro queda tapado por la cabeza y en sombra.
#   * De espaldas (mira hacia arriba de la pantalla): los DOS quedan detras.
#   * De frente exacto: los dos delante (no hay lado mas cercano).
#   * En cualquier giro: delante el que este del lado hacia el que mira.
static func _es_delante(rel_x: float, dir: int) -> bool:
	var lado: float = DIR_VECS[dir].x
	if DIR_VECS[dir].y <= -0.5:
		return false
	if is_zero_approx(lado):
		return true
	return signf(rel_x) == signf(lado) or is_zero_approx(rel_x)


# Lo que esta DETRAS se dibuja mas pequeño: sin esto los dos cuernos asoman casi iguales por la
# coronilla y parecen gemelos, que es justo lo contrario de lo que tienen que contar.
const ORNAMENTO_DETRAS_ESC := 0.75

static func _orejas_para(dir: int) -> Array:
	var out: Array = []
	for rel in [OREJA_L_REL, OREJA_R_REL]:
		var delante: bool = _es_delante(rel.x, dir)
		var radio := Vector2(EAR_RX, EAR_RY)
		out.append({"pos": _en_cabeza(rel, dir, LEAN_OREJA),
			"radio": radio if delante else radio * ORNAMENTO_DETRAS_ESC, "delante": delante})
	return out


static func _corona_para(dir: int) -> Array:
	var out: Array = []
	for i in CORONA_REL.size():
		var delante: bool = _es_delante(CORONA_REL[i].x, dir)
		var radio: Vector2 = CORONA_RADIO[i]
		out.append({"pos": _en_cabeza(CORONA_REL[i], dir, LEAN_OREJA),
			"radio": radio if delante else radio * ORNAMENTO_DETRAS_ESC, "delante": delante})
	return out


# Los OJOS. De espaldas, ninguno. De perfil PURO (E/W) uno solo: el de detras quedaria al otro lado
# de la cabeza. En todo lo demas -- de frente y de medio lado -- se ven LOS DOS, pero el par se
# desplaza hacia donde mira y su separacion se COMPRIME con el giro: asi de medio lado uno queda
# casi tocando el borde y el otro mas hacia el centro, en vez de fundirse en un borron. El de detras
# ademas se dibuja algo mas pequeño, que es lo que lo manda visualmente al fondo.
const OJO_SEP := 10.4       # separacion entre los dos ojos mirando de frente
static func _cara_para(dir: int) -> Dictionary:
	var frente: float = DIR_VECS[dir].y
	var lado: float = DIR_VECS[dir].x
	if frente <= -0.5:
		return {"ojos": []}
	var y: float = CABEZA_TOP + OJO_L_REL.y
	if absf(lado) >= 0.9:
		return {"ojos": [{"pos": Vector2(lado * LEAN_OJOS, y), "escala": 1.0}]}
	var centro: float = lado * LEAN_OJOS
	var sep: float = OJO_SEP * (1.0 - absf(lado) * 0.5)
	var delantero := Vector2(centro + signf(lado) * sep * 0.5, y) if not is_zero_approx(lado) \
		else Vector2(centro + sep * 0.5, y)
	var trasero := Vector2(centro - signf(lado) * sep * 0.5, y) if not is_zero_approx(lado) \
		else Vector2(centro - sep * 0.5, y)
	return {"ojos": [
		{"pos": trasero, "escala": 1.0 if is_zero_approx(lado) else 0.82},
		{"pos": delantero, "escala": 1.0},
	]}
