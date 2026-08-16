# ============================================================
#  iconos_equipo.gd
#  Las ARMAS, los ESCUDOS y las PIEZAS DE ARMADURA, dibujados con CUBITOS.
#
#  Hermano de iconos.gd (misma idea: nada de emoji ni de texturas, que se ven distinto en cada
#  aparato), pero con otra tecnica: aqui no hay arcos ni lineas, hay una REJILLA. Cada dibujo es una
#  tabla de texto donde un caracter distinto de espacio es un cubito lleno, y se pinta un draw_rect
#  por celda. Es lo que le da el aire del juego, y ademas se retoca a ojo editando la tabla.
#
#  CADA ARMA TIENE SU SILUETA, y se reconoce sin leer nada: la daga es corta y con la punta curva de
#  cuchillo, el estoque tiene su cazoleta, el hacha su media luna. Lo unico que comparten es la
#  tecnica. Por eso cada una es su propia tabla y no un parametro de otra: si una no se lee bien, se
#  toca ESA y nadie mas se entera.
#
#  Las tablas se leen de ARRIBA a ABAJO, asi que la punta del arma va en la primera fila.
#  Los caracteres:
#     '#' = la pieza (se pinta del color que se pase, normalmente el del desgaste)
#     '.' = detalle oscuro (mango, cuero, agarre): NO se tiñe, para que el arma no sea una mancha
#     ' ' = vacio
# ============================================================

class_name IconosEquipo

# El mango/agarre va siempre de este marron oscuro: es lo que separa la hoja del puño de un vistazo
# y lo que evita que un arma entera teñida de rojo se lea como un borron.
const COLOR_MANGO := Color(0.35, 0.24, 0.16)
# Una ranura VACIA (sin casco, peleando a puños): la silueta se dibuja igual pero apagada, para que
# se vea que ALLI FALTA ALGO. Un tanque sin peto tiene que cantar.
const COLOR_VACIO := Color(0.30, 0.31, 0.35, 0.55)


# --- ARMAS -----------------------------------------------------------------------------------
# A una mano: rejillas de 5 de ancho. La punta arriba, el pomo abajo.
#
# 5 y no 7 A PROPOSITO: en el cuadro caben DOS (una mano cada una), asi que a lo ancho hay la mitad
# de sitio. Con 7 columnas el cubito salia de 3 px y el mango marron desaparecia; con 5 se ve el
# arma entera, mango incluido, que es lo que hace que una daga no parezca una espada pequeña.

const DAGA := [
	"  #  ",
	"  ## ",   # la punta sube en ESCALON hacia un lado: es el filo curvo del cuchillo
	" ### ",
	" ##  ",
	"#####",   # guarda minima, apenas un tope
	"  .  ",
	" ... ",
]

const ESPADA_CORTA := [
	"  #  ",
	" ### ",
	" ### ",
	" ### ",
	"#####",   # guarda cruzada
	"  .  ",
	"  .  ",
	" ... ",   # pomo
]

const ESPADA_LARGA := [
	"  #  ",
	" ### ",
	" ### ",
	" ### ",
	" ### ",
	" ### ",
	"#####",   # guarda a la misma altura, pero con mucha mas hoja encima
	"  .  ",
	"  .  ",
	" ... ",
]

const ESTOQUE := [
	"  #  ",
	"  #  ",
	"  #  ",
	"  #  ",   # hoja de UN cubito: finisima
	"  #  ",
	"  #  ",
	" ### ",
	"#####",   # la CAZOLETA redonda, lo que no tiene ninguna espada
	" ### ",
	"  .  ",
	" ... ",
]

const MAZA_PEQ := [
	" # # ",   # pinchos
	"#####",
	"#####",   # cabeza corta y gorda
	"#####",
	" # # ",
	"  .  ",
	"  .  ",
	" ... ",
]

const PUNOS := [
	"     ",
	" ### ",
	"#####",
	"#####",   # el guante cerrado
	"#####",
	" #.# ",
	" ... ",
	"     ",
]

const VARITA := [
	" ### ",
	"#####",   # la GEMA, gorda y arriba del todo
	" ### ",
	"  .  ",
	"  .  ",
	"  .  ",   # y el palo corto: la mitad que el baston
	" ... ",
]

# A dos manos (y el baston): rejillas de 9 de ancho, y se pintan a lo ALTO del cuadro entero.

const MANDOBLE := [
	"    #    ",
	"   ###   ",
	"  #####  ",
	"  #####  ",
	"  #####  ",
	"  #####  ",   # hoja ANCHA
	"  #####  ",
	"  #####  ",
	"#########",   # guarda larga
	"    .    ",
	"    .    ",
	"    .    ",   # empuñadura de dos puños
	"   ...   ",
]

const HACHA_GRANDE := [
	"   ##    ",
	"  ####   ",
	" #####   ",
	"######   ",   # la MEDIA LUNA, toda a un lado del mango
	"######   ",
	" #####   ",
	"  ####   ",
	"   ##.   ",
	"    ..   ",
	"    ..   ",
	"    ..   ",
	"    ..   ",
	"   ....  ",
]

const MARTILLO_GRANDE := [
	"         ",
	"#########",
	"#########",
	"#########",   # cabeza rectangular, el doble de gorda que la maza
	"#########",
	"#########",
	"    .    ",
	"    .    ",
	"    .    ",
	"    .    ",
	"    .    ",
	"   ...   ",
	"         ",
]

const BASTON := [
	"   ###   ",
	"  #####  ",
	"   ###   ",   # remate del mago
	"    .    ",
	"    .    ",
	"    .    ",
	"    .    ",
	"    .    ",   # y el palo LARGO: es lo que lo separa de la varita
	"    .    ",
	"    .    ",
	"    .    ",
	"   ...   ",
	"         ",
]

# --- ESCUDOS: uno por tamaño, y se distinguen por la FORMA, no solo por el tamaño --------------

const ESCUDO_PEQ := [
	" ### ",
	"#####",
	"#####",   # rodela: redondo y chato
	" ### ",
]

const ESCUDO_NORMAL := [
	"#####",
	"#####",
	"#####",
	" ### ",   # gota: se estrecha hacia abajo
	" ### ",
	"  #  ",
]

const ESCUDO_GRANDE := [
	"#####",
	"#####",
	"#####",
	"#####",
	"#####",   # torre: un pedazo de tabla de arriba abajo
	"#####",
	"#####",
	" ### ",
	"  #  ",
]

# --- ARMADURA: el monigote, una tabla por zona -----------------------------------------------
# Las cinco van sobre la MISMA rejilla de 13x15, cada una en su sitio, para que juntas formen una
# figura. Se pintan por separado porque cada pieza lleva SU color de desgaste.
#
# DOS REGLAS que salieron de verlo en pantalla:
#  1) Cada pieza SEPARADA de las vecinas por una fila o columna vacia. Pegadas se fundian en una
#     mancha y no se distinguia cual era la que estaba roja.
#  2) El PECHO es la pieza mas grande y la CABEZA una de las pequeñas, que es como son de verdad.
#     Antes el casco ocupaba tres filas de once y el monigote parecia un cabezon.
# La rejilla es grande (13x15) justo para que quepan esos huecos sin que las piezas se queden en
# nada: lo que se ve pequeño no son los cubitos, son las piezas, que es lo que se buscaba.

const ARM_CASCO := [
	"             ",
	"     ###     ",   # la cabeza: tres cubitos de ancho y nada mas
	"     ###     ",
	"             ",   # <- hueco: separa cabeza de torso
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
]

const ARM_PECHO := [
	"             ",
	"             ",
	"             ",
	"             ",
	"    #####    ",   # el torso: la pieza MAS grande de las cinco
	"    #####    ",
	"    #####    ",
	"    #####    ",
	"             ",   # <- hueco: separa torso de piernas
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
]

const ARM_MANOS := [
	"             ",
	"             ",
	"             ",
	"             ",
	" ##       ## ",   # las manos, despegadas del torso por una columna vacia a cada lado
	" ##       ## ",
	" ##       ## ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
]

const ARM_PANTALONES := [
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"    ## ##    ",   # dos piernas, con su hueco en medio
	"    ## ##    ",
	"    ## ##    ",
	"             ",   # <- hueco: separa piernas de botas
	"             ",
	"             ",
]

const ARM_BOTAS := [
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"             ",
	"   ### ###   ",   # los pies, un pelin mas anchos que la pierna
	"   ### ###   ",
]


# --- EL PINTOR -------------------------------------------------------------------------------

# Pinta una rejilla dentro de la caja dada. La rejilla se ESCALA para caber entera manteniendo la
# proporcion, y se centra: asi la misma tabla sirve para un cuadro de 40 px y para uno de 200.
#
# 'col' tiñe los '#'. Los '.' van siempre del marron del mango (o apagados, si la ranura esta vacia).
static func rejilla(c: CanvasItem, filas: Array, caja: Rect2, col: Color, apagado: bool = false) -> void:
	if filas.is_empty():
		return
	var n_f: int = filas.size()
	var n_c: int = 0
	for f in filas:
		n_c = maxi(n_c, String(f).length())
	if n_c == 0:
		return
	# Un cubito CUADRADO: se coge el lado que quepa en los dos ejes, no uno por eje (si no, los
	# dibujos salen estirados y dejan de parecer del mismo juego).
	var lado: float = minf(caja.size.x / float(n_c), caja.size.y / float(n_f))
	var ox: float = caja.position.x + (caja.size.x - lado * float(n_c)) * 0.5
	var oy: float = caja.position.y + (caja.size.y - lado * float(n_f)) * 0.5
	var col_mango: Color = COLOR_VACIO if apagado else COLOR_MANGO
	var col_pieza: Color = COLOR_VACIO if apagado else col
	for i in n_f:
		var fila: String = String(filas[i])
		for j in fila.length():
			var ch: String = fila[j]
			if ch == " ":
				continue
			var r := Rect2(ox + float(j) * lado, oy + float(i) * lado, lado, lado)
			# Los cubitos se pintan con un pelin de solape (el +0.5) para que no queden costuras
			# blancas entre ellos cuando el lado no cae en un pixel entero.
			r.size += Vector2(0.5, 0.5)
			c.draw_rect(r, col_pieza if ch == "#" else col_mango, true)


# La tabla que le toca a un objeto de mano. Despacha por CLASE primero y por tipo despues: la varita
# NO es un WeaponData (es WandData, su propia clase) y el escudo tampoco, asi que mirar solo el
# 'tipo' se los dejaria fuera a los dos. Ver PersonajeData.equipped_off, que admite las tres.
static func tabla_de_mano(item: Resource) -> Array:
	if item is WeaponData:
		match int((item as WeaponData).tipo):
			WeaponData.Tipo.DAGA: return DAGA
			WeaponData.Tipo.ESPADA_CORTA: return ESPADA_CORTA
			WeaponData.Tipo.ESPADA_LARGA: return ESPADA_LARGA
			WeaponData.Tipo.MANDOBLE: return MANDOBLE
			WeaponData.Tipo.ESTOQUE: return ESTOQUE
			WeaponData.Tipo.HACHA_GRANDE: return HACHA_GRANDE
			WeaponData.Tipo.MAZA_PEQ: return MAZA_PEQ
			WeaponData.Tipo.MARTILLO_GRANDE: return MARTILLO_GRANDE
			WeaponData.Tipo.BASTON: return BASTON
			_: return PUNOS
	if item is ShieldData:
		match int((item as ShieldData).tamano):
			ShieldData.Tamano.GRANDE: return ESCUDO_GRANDE
			ShieldData.Tamano.NORMAL: return ESCUDO_NORMAL
			_: return ESCUDO_PEQ
	if item is WandData:
		return VARITA
	return PUNOS   # mano vacia: el guante, que se pintara apagado
