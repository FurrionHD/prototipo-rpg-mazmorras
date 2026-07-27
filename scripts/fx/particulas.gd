# ============================================================
#  particulas.gd  (class_name Particulas)
#  FABRICA de los dos efectos de particulas del juego. Estatica, sin estado propio: mismo
#  patron que MenuScaffold (todo por codigo, el arte va al final).
#
#  Son DOS COMPORTAMIENTOS, no uno con parametros distintos, y la diferencia es semantica:
#
#   - ascendentes()  CUERPOS VIVOS (imbuicion del jugador, enemigo elemental). Cuadraditos que
#                    SUBEN y se desvanecen, y se quedan ATRAS al andar (local_coords = false).
#                    Dice "esto esta emanando algo".
#   - destellos()    OBJETOS (vetas, drops, equipo). Un cuadradito APARECE en un punto al azar
#                    de la pieza, se apaga, y aparece otro en otro sitio. No se mueve, y viaja
#                    con el objeto (local_coords = true). Dice "esto es valioso".
#
#  Se usa CPUParticles2D y NO GPUParticles2D a proposito: el proyecto renderiza con GL
#  Compatibility (ver project.godot), donde las de GPU han dado guerra historicamente. Con 2-8
#  particulas por emisor el coste en CPU es irrelevante y asi se ven seguro en cualquier maquina.
#
#  La TEXTURA es un blanco de 4x4 generado por codigo. Sin ella, una particula se dibuja de 1px
#  y no se ve: es lo unico que hace falta para que los "cuadraditos" sean cuadrados de verdad.
# ============================================================

extends RefCounted
class_name Particulas

# Lado del cuadradito en pixeles. 4 sobre un cuerpo de 32 se lee como una mota, que es lo que se
# busca; subirlo lo convierte en un bloque.
const LADO := 4

# Cacheadas: son inmutables y las comparten TODOS los emisores del juego. Crear una Image y una
# Curve por veta seria tirar memoria por cada nodo del piso.
static var _tex: ImageTexture = null
static var _curva_menguante: Curve = null


# El blanco de 4x4. El color real lo pone la rampa de cada emisor (multiplica sobre este blanco).
static func textura() -> ImageTexture:
	if _tex == null:
		var img := Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_tex = ImageTexture.create_from_image(img)
	return _tex


# RASTRO ASCENDENTE para un cuerpo vivo. 'intensidad' (0..1) sube la cantidad y el brillo: un
# bicho "tocado" por el elemento humea menos que uno hecho de fuego. 'alto' es a que altura llega,
# y se escala con el tamaño del cuerpo (un elite grande no puede tener particulas de enano).
static func ascendentes(padre: Node, color: Color, intensidad := 1.0, alto := 24.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = textura()
	# false = las particulas ya emitidas NO siguen al nodo: se quedan donde nacieron y el cuerpo
	# las deja atras al andar. Es lo que hace que parezca un rastro y no una peluca.
	p.local_coords = false
	p.amount = maxi(2, roundi(7.0 * intensidad))
	p.lifetime = 1.0
	p.lifetime_randomness = 0.35
	p.randomness = 1.0
	p.direction = Vector2.UP
	p.spread = 16.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = alto * 0.55
	p.initial_velocity_max = alto
	# Nacen repartidas por el ancho del cuerpo, no todas del mismo punto.
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(alto * 0.3, alto * 0.16)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _curva()
	p.color_ramp = _rampa_rastro(color, intensidad)
	padre.add_child(p)
	return p


# DESTELLOS sobre un objeto. 'zona' es el TAMAÑO de la pieza (no la mitad): el destello puede
# nacer en cualquier punto de ella, que es justo el "y aparece otro en otro lado".
# Quien llama coloca el nodo (p.position) si la pieza no esta centrada en el origen.
static func destellos(padre: Node, color: Color, zona: Vector2, intensidad := 1.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = textura()
	# true = el destello pertenece al objeto y viaja con el (al reves que el rastro).
	p.local_coords = true
	p.amount = maxi(1, roundi(1.0 + 3.0 * intensidad))
	# Un destello dura ~1s. Nada de parpadeos de 3 frames: a esa velocidad no se lee como un brillo,
	# se lee como ruido y cansa la vista. La aleatoriedad se queda BAJA (0.25 -> entre 0.82 y 1.1s)
	# porque con randomness alta la mitad de los cuadrados salian de 0.3s y volvia el nervio.
	#
	# OJO: 'amount' es el maximo de particulas VIVAS a la vez, asi que subir la vida no las multiplica
	# -- baja el ritmo de nacimiento y deja el mismo numero en pantalla, cada una mas rato. Que es
	# exactamente lo que se busca.
	p.lifetime = 1.1
	p.lifetime_randomness = 0.25
	# 1.0 = cada destello va a su ritmo. A compas esto no parece un brillo, parece un indicador
	# de UI parpadeando; el ritmo irregular es la mitad del efecto.
	p.randomness = 1.0
	p.explosiveness = 0.0
	# Quieto donde nace: sin velocidad ni gravedad. Es un parpadeo, no una nubecilla.
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector2.ZERO
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = zona * 0.5
	# Escala FIJA (sin curva): un destello no se deshace, se apaga.
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.color_ramp = _rampa_destello(color, intensidad)
	padre.add_child(p)
	return p


# Cambia color/cantidad de un emisor YA creado, sin recrear el nodo. La usan los cuerpos, que se
# repintan cuando cambia la imbuicion (ver player._pintar_cuerpo).
static func repintar(p: CPUParticles2D, color: Color, intensidad := 1.0) -> void:
	if p == null:
		return
	p.amount = maxi(2, roundi(7.0 * intensidad))
	p.color_ramp = _rampa_rastro(color, intensidad)
	p.emitting = true


# Deja de emitir SIN borrar lo ya emitido. Va antes de los fundidos de muerte/agotado: si no, el
# bicho sigue soltando cuadraditos mientras se desvanece.
static func apagar(p: CPUParticles2D) -> void:
	if p != null:
		p.emitting = false


# --- interno ---

# Mengua de 1 a 1/4 a lo largo de la vida. Solo la usa el rastro.
static func _curva() -> Curve:
	if _curva_menguante == null:
		_curva_menguante = Curve.new()
		_curva_menguante.add_point(Vector2(0.0, 1.0))
		_curva_menguante.add_point(Vector2(1.0, 0.25))
	return _curva_menguante


# Rastro: entra opaco y se desvanece.
static func _rampa_rastro(color: Color, intensidad: float) -> Gradient:
	var a: float = clampf(0.55 + 0.45 * intensidad, 0.0, 1.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([
		Color(color.r, color.g, color.b, a),
		Color(color.r, color.g, color.b, 0.0),
	])
	return g


# Destello: APARECE, SE QUEDA un rato y desaparece. Es la diferencia con el rastro, que solo se va.
#
# La MESETA (los dos puntos centrales con la misma alpha) es lo que lo hace parecer un cuadrado que
# esta ahi y luego se apaga. Con un triangulo 0->1->0 el brillo nunca se para: sube y baja sin
# descanso, y se lee como un latido en vez de como un destello.
static func _rampa_destello(color: Color, intensidad: float) -> Gradient:
	var a: float = clampf(0.35 + 0.65 * intensidad, 0.0, 1.0)
	var transp := Color(color.r, color.g, color.b, 0.0)
	var pleno := Color(color.r, color.g, color.b, a)
	var g := Gradient.new()
	# Entra en el primer 20%, se mantiene hasta el 70%, y se va en el 30% restante (la salida mas
	# lenta que la entrada: apagarse de golpe canta mucho mas que encenderse de golpe).
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	g.colors = PackedColorArray([transp, pleno, pleno, transp])
	return g
