# ============================================================
#  icono_item.gd
#  EL DIBUJO DE UN OBJETO, en un solo sitio.
#
#  Un item se ve igual en los dos lugares donde aparece: tirado en el SUELO de la mazmorra
#  (drop_pickup.gd) y en la CUADRICULA del inventario. Antes el dibujo vivia entero dentro de
#  drop_pickup, asi que la bolsa no tenia forma de pintar lo mismo sin copiarlo -- y una copia se
#  desparejaria el dia que se retoque el color de una pocion.
#
#  Es un PLACEHOLDER a proposito, igual que el resto de la UI: cuando cada objeto tenga su sprite,
#  se cambia el cuerpo de pintar() y cambian los dos sitios a la vez. Esa es toda la gracia de que
#  esto exista.
#
#  Las formas dicen QUE CLASE de cosa es y el color dice CUAL en concreto:
#     cubo     -> material o cristal        frasco -> pocion (la forma cambia con el tier)
#     libro    -> grimorio                  cuenco -> plato de cocina
#
#  DOS COLORES QUE NO SON EL MISMO, y confundirlos es el error facil:
#     color_de()     el color del PROPIO objeto (el cobre es marron, la pocion de vida roja).
#                    Es lo que se pinta.
#     color_escala() el color de su PELDAÑO en la escala de su eje (gris/verde/azul/...).
#                    Es lo que enmarca la celda y lo que dice "esto es bueno".
#  Un lingote de cobre es marron Y gris a la vez: marron por ser cobre, gris por ser el peldaño
#  bajo de su tier. Las dos cosas se ven en la celda y cada una en su sitio.
#
#  Es estatico (como MenuScaffold / StatsMath): solo dibuja y calcula, no guarda nada.
# ============================================================

extends RefCounted
class_name IconoItem

# El lado con el que se diseñaron los perfiles de los frascos: son 16 filas de 1 px. Todo lo demas
# se escala desde aqui, asi que un icono de 48 px es exactamente el del suelo a 3x.
const LADO_BASE := 16.0


# ============================================================
#  PINTAR
# ============================================================

# CUANTO OCUPA CADA FORMA dentro del hueco que le dan, cuando se pide 'encajar'.
#
# Existe porque las formas NO miden lo mismo de ancho: un cubo llena su cuadrado entero y una
# probeta de tier 1 mide 5 px de los 16. En el SUELO eso esta bien y es informacion (una pocion es
# una cosita y un mineral un pedrusco), pero en una CUADRICULA no: alli cada icono tiene su celda y
# lo unico que consigue la diferencia de tamaño es que el cubo aplaste a todo lo demas -- que es
# exactamente lo que pasaba en la primera version.
const ENCAJE := {"cubo": 0.68, "frasco": 1.0, "libro": 0.92, "cuenco": 1.0}


# Dibuja el item CENTRADO en 'centro', ocupando un cuadrado de 'lado'. 'ci' es cualquier CanvasItem
# en mitad de su _draw() (el Node2D del suelo, la celda del inventario).
#
# 'encajar' = cada forma se escala para llenar su hueco (ver ENCAJE). Lo pide la CUADRICULA; el
# suelo NO, porque alli los tamaños relativos entre objetos dicen algo.
static func pintar(ci: CanvasItem, centro: Vector2, lado: float, item: Resource,
		encajar: bool = false) -> void:
	if item == null:
		return
	if item is ConsumableData:
		var cd := item as ConsumableData
		if cd.es_grimorio():
			_libro(ci, centro, lado * (ENCAJE["libro"] if encajar else 1.0), cd.color_suelo())
		elif cd.es_plato():
			_cuenco(ci, centro, lado * (ENCAJE["cuenco"] if encajar else 1.0), cd.color_suelo())
		else:
			var l: float = lado * (ENCAJE["frasco"] if encajar else 1.0)
			_frasco(ci, centro, l / LADO_BASE, cd.color_suelo(), cd.tier)
		return
	# Material y cristal: el cubo de siempre.
	_cubo(ci, centro, lado * (ENCAJE["cubo"] if encajar else 1.0), color_de(item))


# EL CUBO. En el suelo es un cuadrado plano de 16 px y ahi funciona. En la celda del inventario NO:
# un cuadrado dentro de un cuadrado se lee como un error de carga, no como un objeto. Por eso lleva
# un bisel de verdad -- cara superior clara, frontal a su color y lateral derecho oscuro -- que a 16
# px casi no se nota y a 40 lo convierte en un BULTO. Es el mismo color en los tres, solo aclarado y
# oscurecido, asi que sigue leyendose como "el marron del cobre".
static func _cubo(ci: CanvasItem, centro: Vector2, lado: float, col: Color) -> void:
	var h: float = lado * 0.5
	var o: Vector2 = centro - Vector2(h, h)
	var b: float = lado * 0.22   # grosor de las caras superior y lateral
	ci.draw_rect(Rect2(o, Vector2(lado, lado)), col)
	ci.draw_rect(Rect2(o, Vector2(lado, b)), col.lightened(0.42))
	ci.draw_rect(Rect2(o + Vector2(lado - b, b), Vector2(b, lado - b)), col.darkened(0.42))
	# Un filo claro en la arista de arriba a la izquierda: es el detalle barato que hace que la cara
	# superior parezca iluminada en vez de ser otra banda de color.
	var f: float = maxf(1.0, lado * 0.055)
	ci.draw_rect(Rect2(o, Vector2(lado - b, f)), col.lightened(0.72))
	ci.draw_rect(Rect2(o, Vector2(f, lado)), col.lightened(0.18))


# ============================================================
#  LOS FRASCOS, POR TIER
#  El TIER cambia la FORMA y el contenido cambia el COLOR: son dos ejes independientes, asi que una
#  pocion de vida menor y una media se distinguen por el bulto aunque las dos sean rojas, y una de
#  vida y una de maná del mismo tier se distinguen por el color aunque tengan el mismo bulto. Con
#  todas del mismo tamaño, lo unico que quedaba era el tono, y "rojo oscuro" contra "rojo vivo" no
#  se lee en mitad de una pelea.
#
#  Cada perfil es el SEMIANCHO de cada fila de pixeles, de arriba abajo (16 filas de 1 px). Se
#  describe asi y no con rectangulos porque es lo unico que deja curvar los hombros y la panza: un
#  bulbo hecho con tres rectangulos se ve como una escalera.
# ============================================================

# tier 1: probeta estrecha y alta. tier 2: matraz con hombros. tier 3: bulbo panzudo.
const PERFILES := [
	[0.0, 2.0, 2.0, 1.5, 1.5, 2.0, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.0, 0.0],
	[0.0, 2.0, 2.0, 1.5, 1.5, 2.0, 3.0, 4.0, 4.5, 5.0, 5.0, 5.0, 5.0, 4.5, 3.5, 0.0],
	[2.0, 2.0, 1.5, 1.5, 2.5, 4.0, 5.0, 6.0, 6.5, 6.5, 6.5, 6.0, 5.5, 4.5, 3.0, 0.0],
]
# Filas de TAPON y de CUELLO en cada perfil (el resto es cuerpo). El bulbo del tier 3 empieza una
# fila mas arriba porque necesita el sitio para la panza.
const TAPON_FILAS := [[1, 2], [1, 2], [0, 1]]
const CUELLO_FILAS := [[3, 4], [3, 4], [2, 3]]
# Primera fila con LIQUIDO: por encima queda aire, que es lo que hace que se lea como un frasco
# medio lleno y no como un bloque de color.
const NIVEL_FILA := [6, 6, 5]

const CORCHO := Color(0.55, 0.40, 0.24)
const VIDRIO := Color(0.86, 0.90, 0.92, 0.55)


# 'k' es la escala (1.0 = los 16 px del suelo). Cada fila del perfil se dibuja como una banda de
# k px de alto, asi que el frasco crece sin dejar huecos entre filas.
static func _frasco(ci: CanvasItem, centro: Vector2, k: float, col: Color, tier: int) -> void:
	var i: int = clampi(tier - 1, 0, PERFILES.size() - 1)
	var perfil: Array = PERFILES[i]
	var tapon: Array = TAPON_FILAS[i]
	var cuello: Array = CUELLO_FILAS[i]
	var nivel: int = NIVEL_FILA[i]
	var y0: float = centro.y - LADO_BASE * 0.5 * k
	for fila in perfil.size():
		var w: float = float(perfil[fila]) * k
		if w <= 0.0:
			continue
		var c: Color
		if fila >= int(tapon[0]) and fila <= int(tapon[1]):
			c = CORCHO
		elif fila >= int(cuello[0]) and fila <= int(cuello[1]):
			c = VIDRIO
		elif fila < nivel:
			c = VIDRIO                     # el aire de encima del liquido
		else:
			c = col
		ci.draw_rect(Rect2(Vector2(centro.x - w, y0 + float(fila) * k), Vector2(w * 2.0, k)), c)
	# Brillo: una columna de vidrio pegada al borde izquierdo del liquido. Es lo que hace que se
	# vea vidrio y no una mancha, sobre todo con las pociones oscuras.
	var alto: float = float(perfil.size() - 1 - nivel) * k
	ci.draw_rect(Rect2(
		Vector2(centro.x - float(perfil[nivel + 1]) * k + k, y0 + float(nivel) * k),
		Vector2(k, alto)), Color(1, 1, 1, 0.30))


# EL LIBRO (grimorios). Tapa de su color, lomo mas oscuro a la izquierda y el canto de las hojas
# en crema a la derecha: con esos tres bloques ya no se confunde con un frasco a 16 px.
static func _libro(ci: CanvasItem, centro: Vector2, lado: float, col: Color) -> void:
	var h: float = lado * 0.5
	var c := centro
	ci.draw_rect(Rect2(c + Vector2(-h * 0.8, -h * 0.85), Vector2(h * 1.6, h * 1.7)), col)
	ci.draw_rect(Rect2(c + Vector2(-h * 0.8, -h * 0.85), Vector2(h * 0.35, h * 1.7)), col.darkened(0.45))
	ci.draw_rect(Rect2(c + Vector2(h * 0.45, -h * 0.65), Vector2(h * 0.35, h * 1.3)),
		Color(0.92, 0.89, 0.78))
	# El cierre metalico, que es lo que lo hace "grimorio" y no "cuaderno".
	ci.draw_rect(Rect2(c + Vector2(-h * 0.1, -h * 0.15), Vector2(h * 0.5, h * 0.3)),
		Color(0.85, 0.78, 0.45))


# EL CUENCO (comida). Visto un poco desde arriba: el borde de barro por fuera, el contenido de su
# color HUNDIDO dentro. El contenido tiene que ser MAS ESTRECHO que el cuenco o deja de leerse como
# un cuenco lleno y parece un sombrero (primera version, vista al renderizarlo).
static func _cuenco(ci: CanvasItem, centro: Vector2, lado: float, col: Color) -> void:
	var h: float = lado * 0.5
	var c := centro
	var barro := Color(0.62, 0.50, 0.41)
	# Borde del cuenco: la pieza mas ancha de todas, es la que da la silueta.
	ci.draw_rect(Rect2(c + Vector2(-h * 0.95, -h * 0.55), Vector2(h * 1.9, h * 0.4)), barro)
	# El caldo, metido dentro del borde.
	ci.draw_rect(Rect2(c + Vector2(-h * 0.7, -h * 0.5), Vector2(h * 1.4, h * 0.3)), col)
	# Panza y pie del cuenco, estrechandose hacia abajo.
	ci.draw_rect(Rect2(c + Vector2(-h * 0.8, -h * 0.15), Vector2(h * 1.6, h * 0.55)), barro.darkened(0.15))
	ci.draw_rect(Rect2(c + Vector2(-h * 0.45, h * 0.4), Vector2(h * 0.9, h * 0.35)), barro.darkened(0.4))
	# Un tropezon asomando por encima del borde: es lo que lo hace "comida" y no "vasija".
	ci.draw_rect(Rect2(c + Vector2(-h * 0.2, -h * 0.85), Vector2(h * 0.45, h * 0.32)), col.lightened(0.3))


# ============================================================
#  LOS DOS COLORES
# ============================================================

# El color del PROPIO objeto: el marron del cobre, el rojo de la pocion de vida. Es lo que se pinta.
# Los cristales tiran a cian/violeta segun su calidad; los materiales llevan SU color (el del .tres)
# apagado o realzado por la calidad (ver MaterialItem.color()).
static func color_de(item: Resource) -> Color:
	if item is MaterialItem:
		return (item as MaterialItem).color()
	if item is MaterialData:
		return (item as MaterialData).color
	if item is ConsumableData:
		return (item as ConsumableData).color_suelo()
	if item is Cristal:
		match (item as Cristal).calidad:
			Cristal.Calidad.INTACTO: return Color(0.4, 1.0, 0.9)   # cian brillante
			Cristal.Calidad.NORMAL: return Color(0.5, 0.8, 0.85)   # cian apagado
			_: return Color(0.45, 0.45, 0.55)                       # dañado: gris azulado
	# EQUIPO: no tiene color propio (todavia no hay sprites), asi que va en ACERO, un neutro.
	#
	# Antes se le daba el color de su rareza, y eso era pintar el objeto del mismo tono que su fondo:
	# un cubo morado sobre una celda morada casi no se veia, y el icono dejaba de decir "aqui hay una
	# pieza" justo en las rarezas altas, que son las que mas se miran. El fondo ya dice lo buena que
	# es; el icono solo tiene que destacar contra el.
	return ACERO


# El neutro del equipo sin sprite. Tira a frio y claro para que se vea sobre los ocho fondos de
# rareza, incluido el blanco-cian del pristino.
const ACERO := Color(0.78, 0.81, 0.86)


# El color del PELDAÑO de este item en la escala de SU eje, que es lo que enmarca la celda:
#   equipo (arma/escudo/varita/armadura/mochila/herramienta) -> su RAREZA (0..7)
#   material                                                 -> su RANGO (0..4)
#   cristal                                                  -> su CALIDAD (escala propia)
#   consumible                                               -> su TIER (0..2)
# No se delega en MenuScaffold.color_de_item porque aquel devuelve null para lo que no tiene escala
# y aqui hace falta SIEMPRE un color: una celda sin marco no se puede dibujar.
static func color_escala(item: Resource) -> Color:
	return Upgrades.rareza_color(escalon(item))


# El peldaño 0..7 en la escala de su eje. Es de donde salen las marcas de rareza de la celda.
#
# OJO: cada eje tiene SU techo y no son el mismo (la rareza del equipo llega a 7 y el rango de un
# material a 4). El numero de marcas dice "cuanto queda por encima de esto EN SU ESCALA", que es la
# pregunta que se hace mirando la bolsa; comparar un pristino con un nucleo de boss no la responde
# nadie porque no compiten por nada.
static func escalon(item: Resource) -> int:
	if item is MaterialItem:
		var d: MaterialData = (item as MaterialItem).data
		return d.rango_color() if d != null else 0
	if item is MaterialData:
		return (item as MaterialData).rango_color()
	if item is ConsumableData:
		return clampi((item as ConsumableData).tier - 1, 0, 2)
	if item is Cristal:
		# Su escala propia: intacto arriba, dañado abajo. La CATEGORIA no entra aqui -- es el tier del
		# bicho del que salio, no lo bueno que es el cristal, y meterla haria que un cristal roto de
		# piso 12 luciera mas que uno intacto de piso 2.
		match (item as Cristal).calidad:
			Cristal.Calidad.INTACTO: return 2
			Cristal.Calidad.NORMAL: return 1
			_: return 0
	if item is WeaponData or item is ShieldData or item is WandData or item is ArmorData \
			or item is BackpackData or item is ToolData:
		return int(Game.meta_de(item)["rareza"])
	return 0


# El TECHO de la escala de este item: cuantos peldaños tiene en total. Es lo que deja dibujar las
# marcas como "3 de 5" y no como un numero suelto sin referencia.
static func techo(item: Resource) -> int:
	if item is MaterialItem or item is MaterialData:
		return int(MaterialData.Rango.AMARILLO)
	if item is ConsumableData:
		return 2
	if item is Cristal:
		return 2
	if item is WeaponData or item is ShieldData or item is WandData or item is ArmorData \
			or item is BackpackData or item is ToolData:
		return Upgrades.RAREZA_COLOR.size() - 1
	return 0


# ============================================================
#  LA ESCALERA DEL TIER
#  El fondo de la celda dice la RAREZA. El tier no lo decia nada: habia que pulsar la pieza para
#  enterarse, y cinco piezas de armadura seguidas se veian exactamente iguales.
#
#  TIENE QUE AGUANTAR T20 Y MAS. Hoy son tres, pero esto se puede alargar sin final, asi que una
#  lista de tres colores escritos a mano no vale: el dia que llegue el T4 alguien tiene que
#  acordarse de inventarse un color, y a partir del T8 ya no quedan colores que se distingan.
#
#  Por eso va en DOS EJES, que es lo unico que escala de verdad:
#    - EL TONO da la posicion dentro de la vuelta (seis tonos bien separados en la rueda). Se repite
#      cada TIER_POR_VUELTA, igual que se repiten las unidades al contar.
#    - LA VUELTA sube el BRILLO y pinta un punto por cada una encima de la muesca. Asi un T2 y un T8
#      comparten tono pero no se confunden: el segundo es mas claro y lleva un punto.
#  Es leer un numero: el tono es la unidad y los puntos la decena. Con eso, T1..T6 son seis colores
#  a secas —lo unico que hay hoy— y el sistema sigue valiendo en el T37 sin tocar nada.
#
#  Los tonos se eligieron para NO chocar con los ocho de rareza del fondo (ver Upgrades.RAREZA_COLOR):
#  van mas oscuros y menos saturados, porque la muesca es pequeña y va SOBRE el fondo de rareza.
# ============================================================

const TIER_POR_VUELTA := 6
const TIER_TONOS := [
	Color(0.45, 0.49, 0.57),   # acero
	Color(0.35, 0.66, 0.42),   # verde
	Color(0.28, 0.70, 0.73),   # cian
	Color(0.33, 0.54, 0.88),   # azul
	Color(0.62, 0.44, 0.86),   # violeta
	Color(0.86, 0.42, 0.45),   # carmesi
]


# El color de la muesca para ese tier. Nunca falla y nunca se queda sin colores: el tono da la
# vuelta y el brillo sube.
static func color_tier(tier: int) -> Color:
	var t: int = maxi(tier, 1) - 1
	var base: Color = TIER_TONOS[t % TIER_POR_VUELTA]
	var vuelta: int = t / TIER_POR_VUELTA
	if vuelta <= 0:
		return base
	# Cada vuelta ACLARA, con tope: sin el, a la cuarta vuelta todo seria blanco y dejarian de
	# distinguirse los tonos entre si. El tope llega antes que el numero de puntos, que es el que
	# sigue contando sin limite.
	var subida: float = minf(0.12 * float(vuelta), 0.42)
	return Color.from_hsv(base.h, maxf(base.s - subida * 0.5, 0.12),
		minf(base.v + subida, 1.0), base.a)


# Cuantas VUELTAS lleva dado este tier: 0 para T1..T6, 1 para T7..T12, etc. Son los puntos que se
# pintan sobre la muesca, y es lo que separa un T2 de un T8.
static func vueltas_tier(tier: int) -> int:
	return (maxi(tier, 1) - 1) / TIER_POR_VUELTA


# El TIER de un item, o 0 si eso no tiene tier (un cristal, una pocion sin tier). El equipo lo lleva
# en su meta por instancia (una espada T2 y otra T3 son el mismo .tres); los materiales, en el .tres.
#
# ⚠️ CUIDADO CON `MaterialData.tier`: NO es el tier de la mazmorra, es el GRADO del material -- el
# eje de "de que profundidad viene esto", que sube el VALOR (ver el comentario de su @export). Los
# nucleos llegan a grado 4 y 5, asi que leerlo como tier pintaba "T5" en un juego donde solo hay
# tres tiers, y encima el nucleo de gargola salia morado (T5) mientras su ficha decia "armas T2".
#
# El eje bueno para un nucleo es `tier_equipo`: A QUE tier de equipo sirve, que es lo que la ficha
# llama "armas T2" y lo unico que se puede comparar con el tier de una espada. Para los minerales y
# las plantas no existe ese campo, pero ahi el grado SI es el tier que fabricas (cobre 1, acero 3,
# ver el crafteo), asi que vale el mismo numero.
static func tier_de(item: Resource) -> int:
	if item is MaterialItem:
		var d: MaterialData = (item as MaterialItem).data
		return d.tier_de_equipo() if d != null else 0
	if item is MaterialData:
		return (item as MaterialData).tier_de_equipo()
	if item is ConsumableData:
		return int((item as ConsumableData).tier)
	if item is WeaponData or item is ShieldData or item is WandData or item is ArmorData \
			or item is BackpackData or item is ToolData:
		return int(Game.meta_de(item)["tier"])
	return 0


# Lo alto que esta en su escala, 0..1. Alimenta el BRILLO (el destello de la celda): un cobre
# corriente apenas parpadea y un nucleo de boss centellea. Se normaliza contra el techo de SU eje,
# que es lo que hace que el verde de un mineral y el verde de una espada brillen igual.
static func intensidad(item: Resource) -> float:
	var t: int = techo(item)
	if t <= 0:
		return 0.0
	return clampf(float(escalon(item)) / float(t), 0.0, 1.0)
