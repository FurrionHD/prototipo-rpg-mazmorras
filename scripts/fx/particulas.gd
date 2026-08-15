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
static var _tex_cruz: ImageTexture = null
static var _tex_gota: ImageTexture = null
static var _curva_menguante: Curve = null


# El blanco de 4x4. El color real lo pone la rampa de cada emisor (multiplica sobre este blanco).
static func textura() -> ImageTexture:
	if _tex == null:
		var img := Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_tex = ImageTexture.create_from_image(img)
	return _tex


# RASTRO ASCENDENTE para un cuerpo vivo. 'intensidad' (0..1) sube la cantidad y el brillo: un
# bicho "tocado" por el elemento humea menos que uno hecho de fuego. 'alto' es el LADO DEL CUERPO
# (todos los que llaman pasan eso): de ahi salen a la vez el ancho de la boquilla y la altura a la
# que llegan, para que un elite grande no lleve particulas de enano.
#
# La boquilla es MAS ANCHA QUE EL CUERPO a proposito (1.2 lados: se derrama un 10% por cada
# costado) y esta BAJADA hacia los pies. Ceñida al centro se leia como una columnita de humo por
# detras del bicho; desbordando por los lados y naciendo abajo se lee como algo que le arde por
# todo el cuerpo, que es lo que tiene que decir un slime de fuego.
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
	# Algo mas abierto que antes: con la boquilla ancha, un abanico estrecho volvia a juntarlas
	# todas en el centro segun subian y se perdia el ancho recien ganado.
	p.spread = 24.0
	p.gravity = Vector2.ZERO
	# Suben ~1.5 cuerpos (la vida es 1s, asi que la velocidad ES la altura en pixeles).
	p.initial_velocity_min = alto * 0.85
	p.initial_velocity_max = alto * 1.5
	# Nacen repartidas por TODO el ancho del cuerpo y un poco por fuera, no todas del mismo punto.
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(alto * 0.6, alto * 0.22)
	# Y desde la MITAD DE ABAJO del cuerpo (el cuerpo esta centrado en el origen; +Y es hacia los
	# pies). Asi la llama empieza en el suelo del bicho y le sube por encima, en vez de brotarle de
	# la coronilla -- que es lo que cantaba en los cuerpos grandes.
	p.position.y = alto * 0.2
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _curva()
	p.color_ramp = _rampa_rastro(color, intensidad)
	padre.add_child(p)
	return p


# DESTELLOS sobre un objeto. 'zona' es el TAMAÑO de la pieza (no la mitad): el destello puede
# nacer en cualquier punto de ella, que es justo el "y aparece otro en otro lado".
# Quien llama coloca el nodo (p.position) si la pieza no esta centrada en el origen.
# 'mult_cantidad' multiplica SOLO el numero de destellos, sin tocar el brillo. Va aparte de
# 'intensidad' justo por eso: en una zona ancha (el nombre de un objeto en su ficha) hacen falta mas
# cuadraditos para que se note, pero NO mas brillantes.
#
# LO QUE SUBE CON EL RANGO es CUANTOS son y CUANTO MIDEN, no lo transparentes que son. Antes el
# escalon bajo salia con UN cuadrado al 35% de opacidad: sobre un cuerpo claro (un tablon, una
# planta) eso no es un destello tenue, es nada. Un comun ahora centellea POCO (3 motas pequeñas) y
# un amarillo centellea MUCHO (7 y mas gordas), pero los dos SE VEN.
static func destellos(padre: Node, color: Color, zona: Vector2, intensidad := 1.0,
		mult_cantidad := 1.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = textura()
	# true = el destello pertenece al objeto y viaja con el (al reves que el rastro).
	p.local_coords = true
	p.amount = maxi(3, roundi((3.0 + 4.0 * intensidad) * maxf(0.1, mult_cantidad)))
	# Un destello dura ~1.4s. Nada de parpadeos de 3 frames: a esa velocidad no se lee como un brillo,
	# se lee como ruido y cansa la vista. La aleatoriedad se queda BAJA (0.25) porque con randomness
	# alta la mitad de los cuadrados salian de 0.3s y volvia el nervio.
	#
	# La vida importa MAS de lo que parece: los tramos de la rampa (ver _rampa_destello) son
	# porcentajes de ELLA, asi que con 1.1s la entrada duraba 0.4s y todavia se leia como un pop.
	#
	# OJO: 'amount' es el maximo de particulas VIVAS a la vez, asi que subir la vida no las multiplica
	# -- baja el ritmo de nacimiento y deja el mismo numero en pantalla, cada una mas rato. Que es
	# exactamente lo que se busca.
	p.lifetime = 1.4
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
	# Escala FIJA (sin curva): un destello no se deshace, se apaga. El TAMAÑO es la otra mitad de
	# "lo bueno que es": 4px el comun, ~5.5px el amarillo.
	var lado: float = 1.0 + 0.35 * clampf(intensidad, 0.0, 1.0)
	p.scale_amount_min = lado
	p.scale_amount_max = lado
	p.color_ramp = _rampa_destello(_realzar(color), intensidad)
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


# CRUCES que suben. Es lo que se te pone encima cuando algo te esta CURANDO: verde para la vida y
# azul para el maná. Va aparte de los destellos por un motivo de lectura, no de estetica -- un
# cuadradito brillante dice "esto es valioso" y sirve igual para una veta que para un veneno; una
# cruz solo puede querer decir una cosa, y por eso no se confunde con un debuff del mismo color.
#
# Suben MAS DESPACIO que el rastro y duran mas: una cura no es una llamarada, es algo que te va
# subiendo por el cuerpo. Y NO menguan (sin curva de escala): una cruz pequeña deja de leerse como
# una cruz y pasa a ser una mota.
static func cruces(padre: Node, color: Color, intensidad := 1.0, alto := 24.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = textura_cruz()
	p.local_coords = true    # pertenecen al cuerpo que se cura y viajan con el
	p.amount = maxi(2, roundi(4.0 * intensidad))
	p.lifetime = 1.6
	p.lifetime_randomness = 0.3
	p.randomness = 1.0
	p.direction = Vector2.UP
	p.spread = 12.0          # casi rectas hacia arriba: es un goteo ordenado, no una hoguera
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = alto * 0.35
	p.initial_velocity_max = alto * 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(alto * 0.5, alto * 0.18)
	p.position.y = alto * 0.25
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.3
	p.color_ramp = _rampa_destello(_realzar(color), intensidad)
	padre.add_child(p)
	return p


# CHORRETONES: gotas gordas que CAEN despacio y se quedan. Es lo contrario del rastro ascendente
# (que emana) y del destello (que centellea): esto es algo que te ha caido encima y te escurre.
# Lo pide el Pegajoso, que con destellos se leia como si te estuvieran curando.
#
# Lo que lo hace legible como baba y no como lluvia: van LENTAS, GORDAS y opacas casi toda su vida
# (ver _rampa_baba), y nacen repartidas por todo el ancho, arriba.
static func chorretones(padre: Node, color: Color, zona: Vector2, intensidad := 1.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = textura_gota()
	p.local_coords = true    # la baba va pegada al cuerpo, no se queda atras
	p.amount = maxi(3, roundi(5.0 * intensidad))
	p.lifetime = 1.8
	p.lifetime_randomness = 0.4
	p.randomness = 1.0
	p.direction = Vector2.DOWN
	p.spread = 6.0
	p.gravity = Vector2(0.0, 22.0)   # poquita: escurre, no se cae
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(zona.x * 0.44, zona.y * 0.08)
	p.position.y = -zona.y * 0.34   # nacen ARRIBA de la caja y bajan por ella
	p.scale_amount_min = 1.1
	p.scale_amount_max = 2.0
	p.color_ramp = _rampa_baba(color)
	padre.add_child(p)
	return p


# La CRUZ de curar: un mas, de 7x7, con los brazos de 3 px. No se usa la de 4x4 escalada porque
# escalar un cuadrado da un cuadrado; la forma es todo el mensaje aqui.
static func textura_cruz() -> ImageTexture:
	if _tex_cruz == null:
		var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		# Brazos de 3 px de grueso: la barra horizontal son las filas 2-4 y la vertical las
		# columnas 2-4. Cruzandolas sale el mas.
		for i in 7:
			for k in range(2, 5):
				img.set_pixel(i, k, Color.WHITE)
				img.set_pixel(k, i, Color.WHITE)
		_tex_cruz = ImageTexture.create_from_image(img)
	return _tex_cruz


# El GOTERON de la baba: un circulo relleno de 8x8. Un cuadrado no escurre.
static func textura_gota() -> ImageTexture:
	if _tex_gota == null:
		var lado := 8
		var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		var c := (float(lado) - 1.0) * 0.5
		for x in lado:
			for y in lado:
				var d: float = Vector2(float(x) - c, float(y) - c).length()
				if d <= c + 0.15:
					# El borde a media alfa suaviza el circulo sin tirar de mipmaps.
					img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d <= c - 0.6 else 0.55))
		_tex_gota = ImageTexture.create_from_image(img)
	return _tex_gota


# --- interno ---

# Baba: entra rapido, se queda OPACA casi toda la vida y se va al final. Nada de parpadeo -- lo
# que distingue una gota de baba de un destello es justo que la baba no titila, esta ahi.
static func _rampa_baba(color: Color) -> Gradient:
	var transp := Color(color.r, color.g, color.b, 0.0)
	var pleno := Color(color.r, color.g, color.b, 0.9)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.72, 1.0])
	g.colors = PackedColorArray([transp, pleno, pleno, transp])
	return g


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


# El color del RANGO, subido a brillo de destello. Existe por un choque concreto: el cuerpo de una
# pieza lleva el color de LO QUE ES (una baba de veneno es verde) y el destello el de LO BUENO QUE
# ES (poco comun = verde). Verde sobre verde no se ve, y lo mismo pasaba con el gris del comun
# sobre un tablon claro.
#
# La solucion no es cambiar la paleta (es UNA sola en todo el proyecto: ver Upgrades.RAREZA_COLOR):
# es que el destello este SIEMPRE mas alto en luz que el cuerpo que tiene debajo, y todos los
# cuerpos del juego son tonos medios. Se sube el VALOR al tope y se le quita solo un pellizco de
# saturacion: verde de rango sobre baba verde pasa a ser un verde casi luminoso sobre un verde
# medio, que si se despega. El TONO se conserva casi entero a proposito -- es el dato (que rango
# es), y desaturar hasta el blanco lo borraria y haria iguales los cinco escalones.
static func _realzar(color: Color) -> Color:
	var c := Color.from_hsv(color.h, color.s * 0.8, 1.0)
	c.a = color.a
	return c


# Destello: NACE DE LA NADA, sube, se queda a full UN INSTANTE y se desvanece. Es la diferencia con
# el rastro, que solo se va.
#
# El reparto del tiempo es lo unico que hace que esto se lea como un brillo y no como un cuadrado
# que aparece y desaparece de golpe. La meseta es CORTA (el 20% de su vida): con la meseta larga que
# habia antes -- entraba en el 20%, se mantenia hasta el 70% -- y el pico ya opaco, el destello se
# pasaba media vida plano y las transiciones no se veian. Ahora se pasa el 80% del tiempo yendo o
# viniendo, que es donde esta el efecto.
#
# Y la SALIDA es mas larga que la entrada (45% contra 35%), con un punto extra a media bajada para
# que la cola no sea una recta: apagarse de golpe canta mucho mas que encenderse de golpe.
static func _rampa_destello(color: Color, intensidad: float) -> Gradient:
	# El PICO sigue siendo practicamente opaco, y eso no se toca: la escala de rango se cuenta en
	# cuantos son y como de grandes (ver destellos), no en cuanto se transparentan. Media opacidad
	# sobre un cuerpo claro desaparece, y un destello que no se ve no dice nada del material.
	var a: float = clampf(0.85 + 0.15 * intensidad, 0.0, 1.0)
	var transp := Color(color.r, color.g, color.b, 0.0)
	var pleno := Color(color.r, color.g, color.b, a)
	var cola := Color(color.r, color.g, color.b, a * 0.4)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.55, 0.78, 1.0])
	g.colors = PackedColorArray([transp, pleno, pleno, cola, transp])
	return g
