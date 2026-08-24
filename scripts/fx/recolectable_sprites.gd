# ============================================================
#  recolectable_sprites.gd  (class_name RecolectableSprites)
#  Los sprites de lo que se RECOLECTA en la mazmorra: vetas, arboles, matas, sal, carbon y huerto.
#  Tercer generador por codigo del proyecto, detras de los bichos (SpritesEnemigo) y del terreno
#  (TerrenoSprites), y usa el mismo motor que el primero: SpriteLienzo.
#
# ------------------------------------------------------------
#  VARIOS MODELOS POR FAMILIA
# ------------------------------------------------------------
#  Una veta no puede ser SIEMPRE el mismo pedrusco: con un solo dibujo, una sala con tres vetas se
#  lee como tres copias pegadas y canta mas que el ColorRect que habia antes. Cada familia trae
#  MODELOS siluetas distintas (un afloramiento, un racimo de cristales, un pedrusco vetado...) y el
#  modelo se elige por la CELDA, asi que es estable: la misma veta se ve igual cada vez que
#  reconstruyes el piso, y en multijugador el invitado ve la misma que el host.
#
# ------------------------------------------------------------
#  DOS IMAGENES POR MODELO: CUERPO Y TINTE
# ------------------------------------------------------------
#  El problema de tintar: si se pinta el sprite entero con material_data.color, el cobre tiñe
#  tambien la roca que lo rodea y todas las vetas acaban siendo un manchurron del color del metal.
#  Y si no se tiñe nada, el cobre y el hierro son el mismo dibujo.
#
#  Asi que cada modelo se hornea DOS veces desde la MISMA plantilla, cambiando solo la paleta:
#    CUERPO -> la roca / el tronco / las hojas. Neutro, no se tiñe nunca.
#    TINTE  -> solo las vetas de mineral (o el fruto), en blanco, para que el juego lo module con
#              material_data.color y salga cobre, hierro o sal sin redibujar nada.
#  En el mapa son dos Sprite2D, uno encima del otro. Es la misma idea que la plantilla de tonos de
#  SpriteLienzo -- separar la geometria (cara) del color (barata) -- llevada al disco.
# ============================================================

extends RefCounted
class_name RecolectableSprites

const CARPETA := "res://assets/sprites/recolectables/"

# Cuantas siluetas distintas tiene cada familia.
const MODELOS := 4

# --- Tonos de la plantilla ---
# El 0 es el VACIO de SpriteLienzo. Los tonos de MINERAL son los unicos que van al TINTE.
enum {
	VACIO = 0,
	BORDE,
	ROCA_OSC, ROCA, ROCA_CLARA,
	TRONCO_OSC, TRONCO, TRONCO_CLARO,
	HOJA_OSC, HOJA, HOJA_CLARA,
	MINERAL, MINERAL_BRILLO,
}

# Paleta del CUERPO: el mineral va transparente (lo pone la otra imagen).
const PAL_CUERPO := [
	Color(0, 0, 0, 0),                # VACIO
	Color(0.03, 0.03, 0.05),          # BORDE
	Color(0.16, 0.15, 0.19),          # ROCA_OSC
	Color(0.27, 0.26, 0.32),          # ROCA
	Color(0.38, 0.36, 0.44),          # ROCA_CLARA
	Color(0.16, 0.11, 0.07),          # TRONCO_OSC
	Color(0.26, 0.18, 0.11),          # TRONCO
	Color(0.36, 0.26, 0.16),          # TRONCO_CLARO
	Color(0.08, 0.19, 0.10),          # HOJA_OSC
	Color(0.13, 0.30, 0.15),          # HOJA
	Color(0.20, 0.42, 0.21),          # HOJA_CLARA
	Color(0, 0, 0, 0),                # MINERAL
	Color(0, 0, 0, 0),                # MINERAL_BRILLO
]

# Paleta del TINTE: solo el mineral, y en claro para que el modulate del juego lo lleve al color
# del material sin ensuciarlo (modular un gris oscuro da un color apagado siempre).
const PAL_TINTE := [
	Color(0, 0, 0, 0), Color(0, 0, 0, 0),
	Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0),
	Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0),
	Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0),
	Color(0.78, 0.78, 0.78),          # MINERAL
	Color(1.00, 1.00, 1.00),          # MINERAL_BRILLO
]


# ============================================================
#  LAS FAMILIAS
# ============================================================
# El lienzo es POR FAMILIA porque un arbol y una mata de sal no miden lo mismo ni de lejos. El
# ORIGEN es donde se apoya el sprite en el mundo: se dibuja con el pie en la celda, no centrado,
# porque estas cosas se plantan EN el suelo y si se centran flotan.
const FAMILIAS := {
	"veta":    {"w": 34, "h": 30},
	"carbon":  {"w": 34, "h": 30},
	"sal":     {"w": 28, "h": 24},
	# Un arbol tiene que ser MAS ALTO QUE EL JUGADOR (que mide una celda, 32 px). A 46x56 se
	# quedaba por debajo de su cabeza y no se leia como arbol, sino como un arbusto raro.
	"madera":  {"w": 68, "h": 104},
	"planta":  {"w": 30, "h": 28},
	"huerto":  {"w": 32, "h": 26},
}


static func lienzo(familia: String) -> Vector2i:
	var d: Dictionary = FAMILIAS.get(familia, FAMILIAS["veta"])
	return Vector2i(int(d["w"]), int(d["h"]))


# ============================================================
#  RUIDO (el mismo truco que TerrenoSprites, sin periodicidad: aqui no hay que casar bordes)
# ============================================================
static func _rnd(x: int, y: int, s: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + s * 1013904223
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


# ============================================================
#  TRAZO: la herramienta para dibujar cosas que SALEN de otras
# ============================================================
# Una cadena de circulos que se van afilando a lo largo de una direccion, con la direccion
# girando poco a poco ('curva'). Sustituye a "una elipse girada puesta ahi al lado", que era como
# estaban las ramas del arbol seco y se veia el fallo enseguida: la elipse tiene su centro
# DESPLAZADO del tronco, asi que la rama nacia en el aire y quedaba flotando al lado del arbol.
#
# Con un trazo eso no puede pasar: se empieza DENTRO de la pieza de la que sale, asi que la union
# esta siempre cubierta. Y como el radio decae, la rama acaba en punta sin que haya que dibujar
# la punta a mano.
static func _trazo(p: PackedByteArray, w: int, h: int, desde: Vector2, ang: float, largo: float,
		r0: float, r1: float, tono: int, curva: float = 0.0) -> void:
	var pos: Vector2 = desde
	var a: float = ang
	var pasos: int = maxi(2, int(largo))
	for i in pasos + 1:
		var t: float = float(i) / float(pasos)
		var r: float = lerpf(r0, r1, t)
		SpriteLienzo.elipse(p, w, h, pos.x, pos.y, r, r, tono)
		pos += Vector2(cos(a), sin(a)) * (largo / float(pasos))
		a += curva


# ============================================================
#  MODELOS
# ============================================================
# Cada uno rellena la plantilla. Coordenadas en celdas del lienzo, con el pie abajo del todo.

# --- VETA / CARBON: roca con mineral incrustado ---
static func _veta(p: PackedByteArray, w: int, h: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	match modelo:
		0:
			# Afloramiento ancho y bajo: dos lomos pegados al suelo.
			SpriteLienzo.elipse(p, w, h, cx - 5.0, pie - 6.0, 10.0, 7.0, ROCA)
			SpriteLienzo.elipse(p, w, h, cx + 6.0, pie - 4.5, 8.0, 5.5, ROCA)
		1:
			# Racimo de cristales: agujas que SALEN de la base de roca, no husos posados encima.
			# Con elipses giradas se veian planos y despegados; con trazos que arrancan dentro de
			# la base y se afilan, se leen como cristales clavados en la piedra.
			SpriteLienzo.elipse(p, w, h, cx, pie - 4.0, 11.0, 4.5, ROCA)
			var largos := [13.0, 9.0, 11.0, 7.0]
			for i in 4:
				var ang: float = deg_to_rad(-90.0 + (float(i) - 1.5) * 21.0)
				var lx: float = cx + (float(i) - 1.5) * 4.6
				_trazo(p, w, h, Vector2(lx, pie - 4.0), ang, largos[i], 2.6, 0.6, MINERAL)
		2:
			# Pedrusco alto y vetado.
			SpriteLienzo.elipse(p, w, h, cx, pie - 9.0, 11.0, 10.0, ROCA)
			SpriteLienzo.elipse(p, w, h, cx - 6.0, pie - 3.0, 6.0, 4.0, ROCA_OSC)
		3:
			# Boca de mina: un hueco oscuro con el filon dentro.
			SpriteLienzo.elipse(p, w, h, cx, pie - 7.0, 13.0, 8.5, ROCA)
			SpriteLienzo.elipse(p, w, h, cx, pie - 6.0, 7.0, 5.0, ROCA_OSC)
	# Vetas de mineral: motas por dentro de la roca, no encima.
	if modelo != 1:
		for y in h:
			for x in w:
				var i: int = y * w + x
				if p[i] != ROCA and p[i] != ROCA_OSC:
					continue
				if _rnd(x, y, sem) > 0.86:
					p[i] = MINERAL
	# Brillo: la cara de arriba a la izquierda del mineral.
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == MINERAL and _rnd(x, y, sem + 7) > 0.72:
				p[i] = MINERAL_BRILLO
	# Sombreado general: la mitad de abajo de la roca, mas oscura.
	for y in range(h / 2, h):
		for x in w:
			var i: int = y * w + x
			if p[i] == ROCA and _rnd(x, y, sem + 3) > 0.55:
				p[i] = ROCA_OSC


# --- SAL: costra cristalina, terrones sueltos ---
static func _sal(p: PackedByteArray, w: int, h: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	# Costra de sal: un monton bajo y ancho del que asoman terrones angulosos. Antes eran cuatro
	# ovalos sueltos del mismo tamaño y se leia como un charco de motas, no como una veta.
	SpriteLienzo.elipse(p, w, h, cx, pie - 3.0, 10.0, 4.0, ROCA_OSC)
	var n: int = 4 + modelo
	for i in n:
		var f: float = (float(i) - float(n - 1) * 0.5)
		var lx: float = cx + f * 3.4
		var alto: float = 4.5 + absf(sin(float(i) * 2.1 + float(modelo))) * 4.5
		_trazo(p, w, h, Vector2(lx, pie - 3.0), deg_to_rad(-90.0 + f * 13.0), alto,
			2.9, 1.1, MINERAL)
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == MINERAL and _rnd(x, y, sem) > 0.55:
				p[i] = MINERAL_BRILLO


# --- MADERA: arboles. Cuatro portes bien distintos ---
static func _madera(p: PackedByteArray, w: int, h: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	# TODAS las medidas van en proporcion al lienzo. Estaban puestas a pelo para un lienzo de 56
	# de alto, asi que agrandar el arbol obligaba a repasar cuarenta numeros a mano; con esto,
	# cambiar la talla en FAMILIAS reescala el dibujo entero y ya.
	var k: float = float(h) / 56.0
	match modelo:
		0:
			# Frondoso: tronco que se ensancha al pie (raices) y copa de tres masas.
			_trazo(p, w, h, Vector2(cx, pie), deg_to_rad(-90.0), 15.0 * k, 4.5 * k, 2.8 * k, TRONCO)
			_trazo(p, w, h, Vector2(cx, pie - k), deg_to_rad(-160.0), 5.0 * k, 2.5 * k, 1.2 * k, TRONCO)
			_trazo(p, w, h, Vector2(cx, pie - k), deg_to_rad(-20.0), 5.0 * k, 2.5 * k, 1.2 * k, TRONCO)
			SpriteLienzo.elipse(p, w, h, cx, pie - 26.0 * k, 14.0 * k, 12.0 * k, HOJA)
			SpriteLienzo.elipse(p, w, h, cx - 8.0 * k, pie - 20.0 * k, 8.0 * k, 7.0 * k, HOJA)
			SpriteLienzo.elipse(p, w, h, cx + 8.0 * k, pie - 21.0 * k, 8.0 * k, 7.0 * k, HOJA)
		1:
			# Conifera: tres pisos en punta.
			_trazo(p, w, h, Vector2(cx, pie), deg_to_rad(-90.0), 10.0 * k, 3.5 * k, 2.5 * k, TRONCO)
			for i in 3:
				var f: float = float(i)
				SpriteLienzo.elipse(p, w, h, cx, pie - (14.0 + f * 9.0) * k, (13.0 - f * 3.5) * k,
					(7.0 - f * 1.2) * k, HOJA)
		2:
			# SECO Y RETORCIDO. Todo son trazos que nacen DENTRO de la pieza anterior, asi que
			# esta cosido: el tronco sale del suelo, las ramas del tronco y las ramitas de las
			# ramas. Antes eran tres elipses giradas sueltas y se veia el truco -- la rama
			# derecha flotaba al lado del arbol y el conjunto parecia un pico, no un arbol.
			_trazo(p, w, h, Vector2(cx + k, pie), deg_to_rad(-93.0), 26.0 * k, 5.0 * k, 2.2 * k,
				TRONCO, deg_to_rad(0.55) / k)
			# raices
			_trazo(p, w, h, Vector2(cx + k, pie - k), deg_to_rad(-165.0), 6.0 * k, 2.8 * k,
				1.0 * k, TRONCO)
			_trazo(p, w, h, Vector2(cx + k, pie - k), deg_to_rad(-12.0), 6.0 * k, 2.8 * k,
				1.0 * k, TRONCO)
			# ramas: arrancan bien metidas en el tronco
			_trazo(p, w, h, Vector2(cx - 0.5 * k, pie - 13.0 * k), deg_to_rad(-148.0), 13.0 * k,
				2.6 * k, 0.9 * k, TRONCO, deg_to_rad(-1.6) / k)
			_trazo(p, w, h, Vector2(cx + 1.5 * k, pie - 19.0 * k), deg_to_rad(-38.0), 14.0 * k,
				2.6 * k, 0.9 * k, TRONCO, deg_to_rad(1.4) / k)
			_trazo(p, w, h, Vector2(cx + 0.5 * k, pie - 24.0 * k), deg_to_rad(-118.0), 8.0 * k,
				1.8 * k, 0.8 * k, TRONCO, deg_to_rad(-1.2) / k)
			# ramitas de segundo orden: lo que lo remata como arbol muerto y no como horca
			_trazo(p, w, h, Vector2(cx - 8.0 * k, pie - 20.0 * k), deg_to_rad(-95.0), 6.0 * k,
				1.3 * k, 0.7 * k, TRONCO)
			_trazo(p, w, h, Vector2(cx + 9.0 * k, pie - 26.0 * k), deg_to_rad(-70.0), 6.0 * k,
				1.3 * k, 0.7 * k, TRONCO)
		3:
			# TOCON: un tronco SERRADO, con su cara de corte y sus anillos. Lo que lo hace legible
			# es la elipse clara de arriba (la madera fresca del corte, que se ve en escorzo
			# porque la camara mira desde arriba); sin ella es un cilindro marron y ya.
			#
			# La primera version le puso DOS brotes verdes simetricos arriba y parecia una rana
			# con dos ojos. Ahora el brote es UNO y va a un lado.
			_trazo(p, w, h, Vector2(cx, pie), deg_to_rad(-90.0), 13.0 * k, 10.0 * k, 9.5 * k,
				TRONCO)
			# raices que agarran, las tres a distinto largo
			_trazo(p, w, h, Vector2(cx - 6.0 * k, pie - 1.5 * k), deg_to_rad(-168.0), 7.0 * k,
				3.0 * k, 1.0 * k, TRONCO)
			_trazo(p, w, h, Vector2(cx + 6.0 * k, pie - 1.5 * k), deg_to_rad(-14.0), 5.5 * k,
				2.8 * k, 1.0 * k, TRONCO)
			_trazo(p, w, h, Vector2(cx + 3.0 * k, pie - 1.0 * k), deg_to_rad(-40.0), 4.0 * k,
				2.2 * k, 0.9 * k, TRONCO)
			# la cara del corte y sus anillos
			SpriteLienzo.elipse(p, w, h, cx, pie - 13.5 * k, 9.6 * k, 3.6 * k, TRONCO_CLARO)
			SpriteLienzo.elipse(p, w, h, cx, pie - 13.5 * k, 6.0 * k, 2.2 * k, TRONCO)
			SpriteLienzo.elipse(p, w, h, cx, pie - 13.5 * k, 2.6 * k, 1.0 * k, TRONCO_CLARO)
			# un solo brote, a un lado, saliendo del canto del tocon
			_trazo(p, w, h, Vector2(cx + 6.0 * k, pie - 13.0 * k), deg_to_rad(-58.0), 9.0 * k,
				1.5 * k, 0.8 * k, TRONCO)
			SpriteLienzo.elipse(p, w, h, cx + 11.0 * k, pie - 21.0 * k, 4.6 * k, 4.0 * k, HOJA)
			SpriteLienzo.elipse(p, w, h, cx + 7.5 * k, pie - 18.5 * k, 3.0 * k, 2.6 * k, HOJA)
	# Volumen: el lado izquierdo (de donde viene la luz) se aclara, el derecho se apaga.
	for y in h:
		for x in w:
			var i: int = y * w + x
			var t: int = p[i]
			var claro: bool = float(x) < cx - 2.0 and _rnd(x, y, sem) > 0.45
			var osc: bool = float(x) > cx + 3.0 and _rnd(x, y, sem + 5) > 0.5
			if t == HOJA:
				p[i] = HOJA_CLARA if claro else (HOJA_OSC if osc else HOJA)
			elif t == TRONCO:
				p[i] = TRONCO_CLARO if claro else (TRONCO_OSC if osc else TRONCO)


# --- PLANTA: matas de herboristeria. El fruto va en MINERAL para que lo tiña el material ---
static func _planta(p: PackedByteArray, w: int, h: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	match modelo:
		0:
			# Mata redonda con bayas.
			SpriteLienzo.elipse(p, w, h, cx, pie - 7.0, 10.0, 7.5, HOJA)
			for i in 4:
				SpriteLienzo.elipse(p, w, h, cx - 6.0 + float(i) * 4.0,
					pie - 10.0 - float(i % 2) * 3.0, 1.8, 1.8, MINERAL)
		1:
			# Helechos: frondas en abanico.
			for i in 5:
				var a: float = deg_to_rad(-90.0 + float(i - 2) * 24.0)
				SpriteLienzo.elipse(p, w, h, cx + float(i - 2) * 3.0, pie - 8.0, 2.2, 9.0,
					HOJA, a)
		2:
			# Tallo con flor.
			SpriteLienzo.elipse(p, w, h, cx, pie - 7.0, 1.5, 8.0, HOJA)
			SpriteLienzo.elipse(p, w, h, cx - 5.0, pie - 6.0, 5.0, 2.0, HOJA, deg_to_rad(-25.0))
			SpriteLienzo.elipse(p, w, h, cx + 5.0, pie - 9.0, 5.0, 2.0, HOJA, deg_to_rad(20.0))
			SpriteLienzo.elipse(p, w, h, cx, pie - 16.0, 4.5, 4.0, MINERAL)
		3:
			# Enredadera baja, pegada al suelo.
			SpriteLienzo.elipse(p, w, h, cx, pie - 3.5, 12.0, 4.0, HOJA)
			SpriteLienzo.elipse(p, w, h, cx - 7.0, pie - 7.0, 4.0, 4.0, HOJA)
			SpriteLienzo.elipse(p, w, h, cx + 6.0, pie - 8.0, 3.5, 3.5, MINERAL)
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == HOJA and _rnd(x, y, sem) > 0.6:
				p[i] = HOJA_CLARA if x < int(cx) else HOJA_OSC


# --- HUERTO: la despensa. Hojas fuera, la pieza comestible asomando (va en MINERAL) ---
static func _huerto(p: PackedByteArray, w: int, h: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	var n: int = 2 + modelo % 3
	for i in n:
		var lx: float = cx + (float(i) - float(n - 1) * 0.5) * 8.0
		SpriteLienzo.elipse(p, w, h, lx, pie - 4.0, 4.5, 4.5, MINERAL)
		SpriteLienzo.elipse(p, w, h, lx, pie - 9.0, 5.5, 4.0, HOJA)
		SpriteLienzo.elipse(p, w, h, lx - 3.0, pie - 11.0, 3.0, 3.5, HOJA)
		SpriteLienzo.elipse(p, w, h, lx + 3.0, pie - 11.0, 3.0, 3.5, HOJA)
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == HOJA and _rnd(x, y, sem) > 0.6:
				p[i] = HOJA_CLARA


static func _dibujar(familia: String, modelo: int) -> PackedByteArray:
	var t: Vector2i = lienzo(familia)
	var p := PackedByteArray()
	p.resize(t.x * t.y)
	var sem: int = hash(familia) + modelo * 7919
	match familia:
		"veta", "carbon":
			_veta(p, t.x, t.y, modelo, sem)
		"sal":
			_sal(p, t.x, t.y, modelo, sem)
		"madera":
			_madera(p, t.x, t.y, modelo, sem)
		"planta":
			_planta(p, t.x, t.y, modelo, sem)
		"huerto":
			_huerto(p, t.x, t.y, modelo, sem)
	# El contorno se echa sobre la forma YA FUSIONADA, nunca pieza a pieza (misma regla que los
	# bichos): si no, cada elipse trae su propio circulito marcado por dentro.
	SpriteLienzo.contornear(p, Rect2i(1, 1, t.x - 2, t.y - 2), t.x, t.y, BORDE, VACIO, VACIO)
	return p


# ============================================================
#  EL ATLAS
# ============================================================
# Una hoja por familia: MODELOS columnas x 2 filas (fila 0 cuerpo, fila 1 tinte). Rejilla regular
# para poder recortarla con AtlasTexture sin json de por medio.
const FILA_CUERPO := 0
const FILA_TINTE := 1


static func _volcar(img: Image, p: PackedByteArray, o: Vector2i, t: Vector2i, pal: Array) -> void:
	for y in t.y:
		for x in t.x:
			img.set_pixel(o.x + x, o.y + y, pal[p[y * t.x + x]])


static func generar(familia: String) -> Image:
	var t: Vector2i = lienzo(familia)
	var img := Image.create(t.x * MODELOS, t.y * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for m in MODELOS:
		var p: PackedByteArray = _dibujar(familia, m)
		_volcar(img, p, Vector2i(m * t.x, FILA_CUERPO * t.y), t, PAL_CUERPO)
		_volcar(img, p, Vector2i(m * t.x, FILA_TINTE * t.y), t, PAL_TINTE)
	return img


static func hornear(familia: String) -> int:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var png: String = CARPETA + familia + ".png"
	if generar(familia).save_png(ProjectSettings.globalize_path(png)) != OK:
		return 0
	var f := FileAccess.open(png, FileAccess.READ)
	var n: int = f.get_length() if f != null else 0
	if f != null:
		f.close()
	return n


static var _cache: Dictionary = {}

static func hoja_de(familia: String) -> Texture2D:
	if _cache.has(familia):
		return _cache[familia]
	var tex: Texture2D = null
	var png: String = CARPETA + familia + ".png"
	if ResourceLoader.exists(png):
		tex = load(png) as Texture2D
	if tex == null:
		tex = ImageTexture.create_from_image(generar(familia))
	_cache[familia] = tex
	return tex


# La textura recortada de un modelo. 'tinte' = la capa que hay que modular con el color del
# material; false = el cuerpo neutro.
static func textura(familia: String, modelo: int, tinte: bool) -> AtlasTexture:
	var t: Vector2i = lienzo(familia)
	var at := AtlasTexture.new()
	at.atlas = hoja_de(familia)
	at.region = Rect2(posmod(modelo, MODELOS) * t.x, (FILA_TINTE if tinte else FILA_CUERPO) * t.y,
		t.x, t.y)
	at.filter_clip = true      # sin esto, al ampliar se cuela el pixel del modelo vecino
	return at


# QUE modelo le toca a esta celda. Por la celda y no al azar: asi es estable entre reconstrucciones
# del piso y, en multijugador, el invitado ve el mismo que el host sin que viaje nada por la red.
static func modelo_de(celda: Vector2i, semilla: int = 0) -> int:
	return posmod(hash(Vector3i(celda.x, celda.y, semilla)), MODELOS)
