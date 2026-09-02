# ============================================================
#  paleta_equipo.gd  (class_name PaletaEquipo)
#  DE QUE COLOR VA UNA PIEZA DE EQUIPO SEGUN SU TIER Y SU MEJORA.
#
#  Una espada recien forjada y esa misma espada a +15 eran EL MISMO DIBUJO CON EL MISMO COLOR, asi
#  que mejorar no se notaba en el personaje. Esto es lo que hace que se note.
#
#  LA ESCALA NO ESTA INVENTADA AQUI: YA EXISTIA EN EL JUEGO. Los materiales de la forja llevan desde
#  siempre tres peldaños por tier, con su banda de mejora declarada en el propio .tres
#  (mejora_min / mejora_max), y son exactamente estos:
#
#      METAL   T1  cobre     ->  cobre veteado    ->  cobre profundo
#              T2  hierro    ->  hierro templado  ->  hierro negro
#              T3  acero     ->  acero plegado    ->  acero espejo
#      CUERO   T1  simple    ->  curado           ->  bruñido
#              T2  reforzado ->  endurecido       ->  placado
#              T3  minotauro (SIN bandas: es el unico)
#      MADERA  T1  comun     ->  de veta          ->  anillada
#              T2  dura      ->  ferrea           ->  petrificada
#              T3  negra     ->  calcinada        ->  latente
#
#  Asi que esto no es una escala nueva: es PINTAR la que ya se juega. Un arma de tier 1 a +10 se ve
#  de cobre profundo porque esta hecha de cobre profundo.
#
#  POR QUE LOS COLORES NO SE LEEN DE LOS .tres, QUE LOS TIENEN. Porque estan calibrados para otra
#  cosa: el icono del item y el nodo del mapa, que se miran quietos y de cerca. Entre 'lingote_cobre'
#  (0.82, 0.50, 0.31) y 'lingote_cobre_veteado' (0.78, 0.47, 0.33) hay cuatro centesimas -- en un
#  muñeco de 84 pixeles moviendose eso no existe. Aqui estan SEPARADOS a mano hasta que se distinguen
#  jugando, que es lo unico que importa.
#
#  LA REGLA AL SEPARARLOS, y es lo que hay que respetar si algun dia se retocan:
#    * DENTRO de un tier, la banda mueve sobre todo el VALOR y la SATURACION (cobre claro -> cobre
#      apagado -> cobre oscuro). Es un cambio fino, para verlo de cerca.
#    * ENTRE tiers, lo que se mueve es el MATIZ (naranja -> gris -> azul). Es un cambio de golpe, para
#      reconocerlo de lejos sin mirar numeros.
#  Si las dos cosas cambiaran a la vez, T1+15 y T2+0 se parecerian y el salto de tier dejaria de
#  leerse, que es el que de verdad importa.
#
#  ESTA TABLA ES SOLO VISUAL. No crea materiales, no toca la forja y no hace forjable nada que hoy no
#  lo sea -- solo dice de que color se ve. Lo unico que tiene peldaños sin material detras es el
#  CUERO T3, y van marcados uno por uno.
# ============================================================

extends RefCounted
class_name PaletaEquipo

# QUE PAPEL HACE CADA TONO de una capa, que es lo que cada generador declara en vez de un color.
#
# Es lo que permite que una sola tabla sirva para un yelmo y para una espada: el generador dice "mi
# tono 4 es el material de la pieza y mi tono 3 es el cuero del mango", y aqui se resuelve cada papel
# con el material que toque. Sin esto habria que escribir una tabla de colores por generador y las
# tres se desincronizarian a la primera.
enum Rol {
	BORDE,          # el contorno casi negro: no depende del material
	SOMBRA,         # la sombra de suelo (negro semitransparente)
	OSCURO,         # huecos y ranuras: la visera de un yelmo
	ACENTO,         # el oro de una cresta, el laton de una junta
	MATERIAL_S,     # el material DE LA PIEZA en penumbra
	MATERIAL,       # el material de la pieza, tono base
	MATERIAL_L,     # el material de la pieza, por donde da la luz
	CUERO_S,        # el cuero de una empuñadura o una correa, en penumbra
	CUERO,          # el cuero, tono base
	MADERA_S,       # la madera de un asta o un escudo, en penumbra
	MADERA,         # la madera, tono base
	MADERA_L,       # la madera, luz
}

# LAS FAMILIAS DE MATERIAL. 'MATERIAL' se resuelve con la que le toque a la pieza: una armadura de
# cuero va por CUERO y una de placas por METAL, aunque las dos sean del mismo tier.
const METAL := "metal"
const FIBRA := "cuero"
const LEÑO := "madera"

# DONDE SALTA LA BANDA, en niveles de mejora. Son las MISMAS que declaran los materiales en su .tres
# (mejora_min / mejora_max): 0..3, 3..9, 9..15.
#
# ESTAN COPIADAS Y NO LEIDAS, y hay que saberlo: leerlas de los materiales seria mas seguro, pero el
# CUERO T3 no declara bandas y habria que inventarse el caso justo donde no hay dato. Si algun dia se
# mueven alli, hay que moverlas aqui.
#
# (Este comentario decia "el TIER 3 no tiene bandas". Era falso para el metal y la madera, y esa
# frase es la que hizo que nadie mirara si el acero salia del color de su material. No lo hacia.)
const BANDAS := [3, 9]


# ============================================================
#  LA TABLA
# ============================================================
# El tono BASE de cada (familia, tier, banda). La sombra y la luz salen de el (ver _derivar), asi que
# aqui hay un color por peldaño y no tres: tres a mano se descuadran en cuanto se retoca uno.
#
# EL TIER 3 SI TIENE PELDAÑOS, Y ESTE COMENTARIO DECIA LO CONTRARIO. Durante un tiempo puso que los
# dos ultimos escalones del T3 eran inventados "porque como material no existen", y que daba igual
# porque "el equipo T3 tampoco se puede mejorar (no hay nucleo de tier 3)". Las dos cosas eran falsas
# y son las que taparon que el acero saliera de un color y su material de otro:
#     acero -> acero plegado -> acero espejo          (resources/materials/, con sus bandas)
#     madera negra -> calcinada -> latente
#     nucleo_minotauro.tres cubre mejora_min 12 .. mejora_max 15
# Un comentario que dice "esto no se puede ver" es la mejor manera de que nadie mire.
#
# EL UNICO QUE SIGUE SIN BANDAS ES EL CUERO T3: 'cuero_t3.tres' no declara mejora_min/max, asi que sus
# dos escalones de aqui abajo si son inventados de verdad. Van marcados uno por uno.
#
# Y EL T3 VA AL REVES QUE LOS OTROS DOS: T1 y T2 se OSCURECEN al mejorar (cobre profundo, hierro
# negro), pero por debajo del hierro negro no queda sitio -- "mas oscuro que negro" no se ve en
# pantalla. El T3 ACLARA, que ademas es lo que le da al acero una identidad propia frente al hierro:
# uno acaba en negro y el otro en blanco. El material se cambio para que dijera lo mismo (el antiguo
# "acero pavonado" -- pavonar es ennegrecer -- es ahora ACERO ESPEJO).
#
# OJO CON EL VECINO DE AL LADO, QUE HA CAMBIADO: antes el riesgo era que el T3 mejorado chocase con el
# T2 mejorado (los dos oscuros). Ahora es al reves -- el acero espejo (casi blanco) contra el HIERRO
# EN BRUTO (0,66 0,69 0,74, gris claro). Los separan el matiz (azul contra gris neutro), la luminancia
# y sobre todo que solo el T3 llega a destellar.
const TABLA := {
	METAL: [
		# T1 - COBRE: calido y anaranjado. Al mejorar se apaga y se vuelve rojizo.
		[Color(0.85, 0.52, 0.30),   # cobre en bruto
		 Color(0.72, 0.40, 0.24),   # cobre veteado
		 Color(0.55, 0.28, 0.20)],  # cobre profundo
		# T2 - HIERRO: gris neutro que se va a azul oscuro.
		[Color(0.66, 0.69, 0.74),   # hierro en bruto
		 Color(0.50, 0.55, 0.64),   # hierro templado
		 Color(0.30, 0.33, 0.40)],  # hierro negro
		# T3 - ACERO: azulado y claro, subiendo hasta casi blanco.
		#
		# EL PRIMER PELDAÑO VA AZUL DE VERDAD y no gris claro, porque a ojo se confundia con el hierro
		# en bruto del T2: los dos salian grises y el salto de tier -- que es el que de verdad importa
		# -- no se leia. Y el ultimo se va a blanco puro por lo mismo, para separarse del de en medio.
		[Color(0.52, 0.64, 0.82),   # acero en bruto
		 Color(0.70, 0.84, 0.92),   # acero plegado
		 Color(0.95, 0.97, 1.00)],  # acero espejo
	],
	FIBRA: [
		# T1 - CUERO CLARO, que se curte y se oscurece.
		[Color(0.60, 0.44, 0.28),   # cuero simple
		 Color(0.48, 0.33, 0.20),   # cuero curado
		 Color(0.38, 0.25, 0.15)],  # cuero bruñido
		# T2 - CUERO GRISACEO, casi placa.
		[Color(0.45, 0.34, 0.30),   # cuero reforzado
		 Color(0.36, 0.27, 0.26),   # cuero endurecido
		 Color(0.28, 0.22, 0.24)],  # cuero placado
		# T3 - ROJIZO, que es lo que lo separa del marron de los otros dos.
		# EL UNICO TIER QUE DE VERDAD NO TIENE BANDAS: 'cuero_t3.tres' no declara mejora_min/max, asi
		# que estos dos escalones no corresponden a ningun material y son inalcanzables. Aqui si vale
		# lo que antes se decia de todo el T3.
		[Color(0.52, 0.30, 0.30),   # cuero de minotauro
		 Color(0.60, 0.34, 0.36),   # cuero sellado     (INVENTADO: cuero_t3 no tiene bandas)
		 Color(0.70, 0.44, 0.44)],  # cuero de escama   (INVENTADO: cuero_t3 no tiene bandas)
	],
	LEÑO: [
		[Color(0.55, 0.42, 0.26),   # madera comun
		 Color(0.46, 0.34, 0.20),   # madera de veta
		 Color(0.38, 0.28, 0.17)],  # madera anillada
		[Color(0.40, 0.32, 0.24),   # madera dura
		 Color(0.33, 0.28, 0.24),   # madera ferrea
		 Color(0.26, 0.24, 0.24)],  # madera petrificada
		# LA MADERA T3 VA AL REVES QUE EL ACERO, y esta bien asi: el acero es el eje CLARO del juego y
		# la madera el OSCURO. Acababa en un hueso de 0,66 0,62 0,56 mientras su material acaba en
		# 'madera latente', que es rojo BRASA -- se aclaraba justo donde el material se apaga.
		[Color(0.26, 0.23, 0.24),   # madera negra
		 Color(0.32, 0.27, 0.25),   # madera calcinada
		 Color(0.34, 0.20, 0.19)],  # madera latente (el rescoldo: lo unico calido del tier)
	],
}

# EL ACENTO (el oro de una cresta) NO sigue al material: si lo siguiera dejaria de ser un acento y la
# pieza volveria a ser de un solo color, que es justo lo que se quiso evitar. Lo unico que hace con el
# tier es subir de laton a oro.
const ACENTOS := [
	Color(0.62, 0.52, 0.30),   # T1 laton
	Color(0.72, 0.60, 0.32),   # T2 bronce
	Color(0.86, 0.74, 0.38),   # T3 oro
]

const C_BORDE := Color(0.08, 0.08, 0.10)
const C_OSCURO := Color(0.11, 0.11, 0.14)
const C_SOMBRA := Color(0.0, 0.0, 0.0, 0.20)


# ============================================================
#  EL BRILLO METALICO
# ============================================================
# Hoy TODA la armadura sale mate: MunecoJugador forzaba 'metal' a cero en la rama de las capas sin
# tinte, asi que unas placas de acero se veian tan apagadas como el cuero, aunque el shader sabe hacer
# metal desde el principio.
#
# Lo enciende la MEJORA, no el tier: es la lectura que se pidio -- que se vea que la estas mejorando
# -- y ademas es la que mas se nota, porque el destello se mueve.
#
# Y SOLO EL METAL BRILLA. El cuero y la madera se quedan mates en los tres tiers: un peto de cuero
# reluciente parece de plastico, y ademas el brillo dejaria de significar "metal bueno".
const METAL_MAX := 0.85

static func metal_de(familia: String, mejoras: int) -> float:
	if familia != METAL:
		return 0.0
	return clampf(float(mejoras) / 15.0, 0.0, 1.0) * METAL_MAX


# LO CLARO QUE ES EL TONO DE LUZ DE ESTE MATERIAL, que es lo que el shader necesita para saber DONDE
# poner el destello.
#
# HACE FALTA PORQUE EL BRILLO NO SE VEIA NUNCA, y era el fallo mas gordo de todo esto: el shader
# encendia el destello solo en pixeles que ya pasaban de 0,72 de luminancia (un umbral fijo), pero
# 'metal' SUBE con la mejora y la paleta OSCURECE con la mejora. Las dos curvas iban en direcciones
# contrarias y se cancelaban justo donde importa:
#
#     hierro en bruto (+0)   luz 0,89 -> pasa el umbral   pero metal 0,00
#     hierro templado (+6)   luz 0,74 -> lo roza          y   metal 0,34   -> destello 0,007
#     hierro negro   (+15)   luz 0,45 -> NO pasa          y   metal 0,85   -> destello CERO
#
# O sea que con el brillo a tope no quedaba ni un pixel bastante claro para destellar. Solo brillaba
# el T3, que es claro.
#
# Con esto el umbral deja de ser absoluto y pasa a ser RELATIVO a la pieza: destella lo que es la luz
# DE ESTE material, sea un acero espejo o un hierro negro. Es lo que hace el mineral, que suma su
# barrido sin mirar lo oscura que sea la veta (ver shaders/metal.gdshader).
#
# Y SALE DE '_derivar' Y NO DE UNA COPIA DE LA FORMULA: si se escribiera el 1,24 otra vez aqui, el dia
# que se retoque el tono de luz el destello se quedaria apuntando al brillo de ayer.
static func luz_ref(familia: String, tier: int, mejoras: int) -> float:
	if familia != METAL:
		return 0.0
	var luz: Color = _derivar(base(familia, tier, mejoras), 1.24, 0.68)
	return luz.r * 0.299 + luz.g * 0.587 + luz.b * 0.114


# ============================================================
#  DE UN +N A UN PELDAÑO
# ============================================================
static func banda(mejoras: int) -> int:
	var b: int = 0
	for corte in BANDAS:
		if mejoras >= int(corte):
			b += 1
	return b


# El color base de un (familia, tier, mejoras). 'tier' es 1..3 como en los datos, no un indice.
static func base(familia: String, tier: int, mejoras: int) -> Color:
	var filas: Array = TABLA.get(familia, TABLA[METAL])
	var t: int = clampi(tier - 1, 0, filas.size() - 1)
	var fila: Array = filas[t]
	return fila[clampi(banda(mejoras), 0, fila.size() - 1)]


# La sombra y la luz salen del tono base y NO de la tabla: escritos a mano, los tres se descuadran en
# cuanto se retoca uno, y lo que hay que poder retocar es el material -- no sus tres escalones.
#
# La sombra ademas SATURA un poco y la luz DESATURA, que es como se comporta un material de verdad y
# lo que hace que no parezcan el mismo color con el brillo subido.
static func _derivar(c: Color, f: float, sat: float) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * sat, 0.0, 1.0), clampf(c.v * f, 0.0, 1.0), 1.0)


# ============================================================
#  EL LUT
# ============================================================
# Una textura de 16x1 donde el pixel N es el color del tono N. El shader lee la luminancia del gris
# horneado, la convierte en N y saca el color de aqui (ver paleta_equipo.gdshader).
#
# NEAREST Y SIN MIPMAPS, y no es opcional: con filtrado, el shader lee un color a medio camino entre
# dos tonos -- un color que nadie eligio -- y la pieza sale con bordes de colores sucios.
const LUT_ANCHO := 16

static var _cache: Dictionary = {}

static func lut(clave_roles: String, roles: Array, familia: String, tier: int,
		mejoras: int) -> ImageTexture:
	var ck: String = "%s_%s_%d_%d" % [clave_roles, familia, tier, banda(mejoras)]
	if _cache.has(ck):
		return _cache[ck]
	var cols: Array = colores_de(roles, familia, tier, mejoras)
	var img := Image.create(LUT_ANCHO, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in mini(cols.size(), LUT_ANCHO):
		img.set_pixel(i, 0, cols[i])
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex


# Los mismos colores, como Array. Lo usa el LUT de arriba y tambien las herramientas que componen a
# mano y no pueden pasar por un shader (ver tools/ver_jugador.gd): si esas tuvieran su propia copia de
# la tabla, la hoja de contacto acabaria enseñando colores que el juego no usa -- que es la peor
# manera de que una herramienta de mirar mienta.
static func colores_de(roles: Array, familia: String, tier: int, mejoras: int) -> Array:
	var col: Color = base(familia, tier, mejoras)
	var cuero: Color = base(FIBRA, tier, mejoras)
	var madera: Color = base(LEÑO, tier, mejoras)
	var acento: Color = ACENTOS[clampi(tier - 1, 0, ACENTOS.size() - 1)]
	var out: Array = []
	for r in roles:
		out.append(_color_de(int(r), col, cuero, madera, acento))
	return out


static func _color_de(rol: int, mat: Color, cuero: Color, madera: Color, acento: Color) -> Color:
	match rol:
		Rol.BORDE: return C_BORDE
		Rol.SOMBRA: return C_SOMBRA
		Rol.OSCURO: return C_OSCURO
		Rol.ACENTO: return acento
		Rol.MATERIAL_S: return _derivar(mat, 0.62, 1.12)
		Rol.MATERIAL: return mat
		Rol.MATERIAL_L: return _derivar(mat, 1.24, 0.68)
		Rol.CUERO_S: return _derivar(cuero, 0.62, 1.12)
		Rol.CUERO: return cuero
		Rol.MADERA_S: return _derivar(madera, 0.62, 1.12)
		Rol.MADERA: return madera
		Rol.MADERA_L: return _derivar(madera, 1.24, 0.68)
		_: return C_BORDE
