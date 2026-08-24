# ============================================================
#  material_data.gd
#  PLANTILLA de un material (un .tres por material). Es la IDENTIDAD: que es, de que
#  familia, cuanto pesa y cuanto vale. Lo que llevas en la bolsa NO es esto, es un
#  MaterialItem (esta plantilla + la calidad con la que lo conseguiste).
#
#  Las dos FAMILIAS no se mezclan y es lo que la tienda y la forja van a mirar:
#    - CORRIENTE: babas, plantas, minerales, cuero. De aqui salen las POCIONES.
#    - NUCLEO:    el drop raro del monstruo. De aqui sale la MEJORA DE EQUIPO.
#
#  La 'descripcion' es SOLO SABOR: ni un numero escrito a mano. Los numeros los
#  deriva resumen() de los campos.
# ============================================================

extends Resource
class_name MaterialData

enum Familia { CORRIENTE, NUCLEO }
# LINGOTE y MADERA van los ULTIMOS a proposito: los .tres guardan el enum como numero, asi que
# meter uno en medio le cambiaria el tipo a todos los materiales que ya existen. Cualquier tipo
# nuevo va SIEMPRE al final.
#   LINGOTE no se recolecta: sale de FUNDIR mineral en el herrero.
#   MADERA se saca con el HACHA de los arboles y las enredaderas de los pasillos.
#   TABLON no se recolecta: sale de ASERRAR madera en el carpintero, y es el MANGO de las armas
#   (la madera cruda ya no va directa a la forja; asi no sobra tanta).
#   CARNE es el primer ingrediente de COCINA: no se recolecta ni mejora nada, cae de los bichos que
#   tienen algo que descuartizar (ver EnemyData.drop_extra) y su unico destino es el fogon.
#   PESCADO sale del ESTANQUE de la mazmorra (ver fishing_spot.gd). Es el unico material con un
#   TAMAÑO propio por ejemplar: dos lubinas no son la misma lubina. Ver cm_min/cm_max y
#   MaterialItem.cm.
#   DESPENSA es TODO lo demas que se come: la sal, las verduras, el pan, el queso, el aceite. Uno
#   solo para los tres, y no un tipo por cada cosa, porque la diferencia "condimento vs verdura" la
#   marca la RECETA nombrando el material, no un enum. Ojo: el tipo NO dice con que se saca —la sal
#   se pica con el pico y el puerro se corta con la hoz siendo los dos DESPENSA—; quien decide la
#   herramienta es el NODO del mapa (ver ResourceNode.Tipo), no esto.
#   COMBUSTIBLE es lo que ARDE en el farolillo: el carbon. Tiene una particularidad que no tiene
#   ningun otro material -- NO PESA (ver Game.peso_actual) --, y no por capricho: la luz no es
#   equipo opcional sino el requisito para ver, asi que cobrar carga por llevar con que ver seria
#   cobrar dos veces por lo mismo. Vive igual en la bolsa que el resto (con su calidad, su
#   minijuego y su pila); lo unico que cambia es que la balanza no lo mira.
enum Tipo { BABA, PLANTA, MINERAL, CUERO, NUCLEO, LINGOTE, MADERA, TABLON, CARNE, PESCADO, DESPENSA,
	COMBUSTIBLE }
# A QUE se le puede meter este nucleo. Los del slime van al ARMA; el de la rata, a la
# ARMADURA. CUALQUIERA = comodin (no lo usa ningun nucleo hoy, pero el campo lo admite).
enum UsoMejora { CUALQUIERA, ARMA, ARMADURA }

@export var id: StringName = &"material"
@export var nombre: String = "Material"
@export var descripcion: String = ""

@export var familia: Familia = Familia.CORRIENTE
@export var tipo: Tipo = Tipo.MINERAL

# GRADO del material: sube el VALOR (en curva, ver MaterialItem.valor_estimado). Es el eje "de que
# profundidad viene esto". El PESO no lo toca: ese sale de peso_base y la calidad, y nada mas.
@export var tier: int = 1

# Lo que CUESTA sacarlo del sitio: dureza de la veta (mineral) o fragilidad del tallo
# (planta). Es la entrada de la dificultad del minijuego, contra tu Fuerza o tu Destreza.
# Los materiales que NO se recolectan (baba, cuero, nucleo) no la usan.
@export var exigencia: float = 30.0

@export var peso_base: float = 1.5
@export var valor_base: int = 20

# --- SOLO para la familia NUCLEO: hasta donde deja subir el equipo ---
# El nucleo no es "un material mas caro": es el PERMISO para seguir mejorando. Un nucleo
# de slime te deja llegar a +3; uno de un bicho hondo, mucho mas lejos. El techo real del
# sistema es el de la rareza mas alta (Upgrades.RAREZA_SLOTS, hoy el pristino = 15): no se
# escribe aqui a mano, se lee de alli (ver mejora_tope), asi que sube solo si aparece una
# rareza nueva por encima.
# 0 = este material no mejora nada (todos los CORRIENTES).
@export var mejora_max: int = 0
# Y desde DONDE empieza su liga: el nivel de mejora a partir del cual este nucleo es el que
# toca. Junto con mejora_max delimita su BANDA (el de slime cubre el +1..+3, el venenoso el
# +4..+5, el de fuego el +6..+7). El coste en nucleos se cuenta DENTRO de la banda: al saltar
# al nucleo siguiente vuelve a empezar en 1.
#
# Sin esto el coste era acumulativo global (mejoras+1), y como el nucleo tambien marca el
# techo, al llegar al +3 te obligaba a cambiar de nucleo Y te cobraba 4 del nuevo de golpe:
# llegar al +7 pedia 13 nucleos de slime de fuego, un bicho 1/50. Nadie iba a llegar nunca.
@export var mejora_min: int = 0
@export var uso_mejora: UsoMejora = UsoMejora.CUALQUIERA

# TIER de equipo al que sirve este nucleo. Cada tier de arma/armadura tiene su propia escalera de
# nucleos: un nucleo de T1 (slime, rata...) NO mejora una pieza T2, y al reves. 0 = comodin (sin
# gate por tier, retrocompatible). Ver Forge.nucleo_vale.
@export var tier_equipo: int = 0

# Placeholder visual (el arte va al final): color del nodo en el mapa y del item del suelo.
@export var color: Color = Color(0.7, 0.7, 0.75)

# En que profundidad aparece. piso_max = 0 -> sin tope (mismo criterio que SpawnEntry).
@export var piso_min: int = 1
@export var piso_max: int = 0

# --- SOLO para PESCADO: la talla de un ejemplar, en centimetros ---
# El pez es el unico material que se mide por PIEZA: lo que coleccionas no es "una lubina", es "una
# lubina de 41 cm". Estos dos son los extremos de la especie; el sorteo real (con cola larga hacia
# el maximo, ver fishing_spot) vive en el nodo del estanque y el resultado se guarda en
# MaterialItem.cm. El libro del Pescador lleva la cuenta de tu mayor y tu menor.
@export var cm_min: float = 0.0
@export var cm_max: float = 0.0

# Proporcion LARGO/ANCHO de la silueta en el agua (y de la "foto" del libro). Es lo que separa de un
# vistazo a la anguila del bagre teniendo los dos el mismo rectangulo por cuerpo.
@export var esbeltez: float = 3.0


func disponible(piso: int) -> bool:
	if piso < piso_min:
		return false
	return piso_max <= 0 or piso <= piso_max


func familia_texto() -> String:
	return "Corriente" if familia == Familia.CORRIENTE else "Núcleo"


func tipo_texto() -> String:
	match tipo:
		Tipo.BABA: return "Baba"
		Tipo.PLANTA: return "Planta"
		Tipo.MINERAL: return "Mineral"
		Tipo.CUERO: return "Cuero"
		Tipo.LINGOTE: return "Lingote"
		Tipo.MADERA: return "Madera"
		Tipo.TABLON: return "Tablón"
		Tipo.CARNE: return "Carne"
		Tipo.PESCADO: return "Pescado"
		Tipo.DESPENSA: return "Despensa"
		_: return "Núcleo"


# ¿Se saca con el PICO? (mineral) ¿Con la HOZ? (planta) ¿Con el HACHA? (madera)
# El resto cae de los monstruos.
func es_veta() -> bool:
	return tipo == Tipo.MINERAL

func es_planta() -> bool:
	return tipo == Tipo.PLANTA

func es_madera() -> bool:
	return tipo == Tipo.MADERA

# ¿Con la CAÑA? El pescado no se recolecta de un nodo del mapa: se saca del estanque.
func es_pescado() -> bool:
	return tipo == Tipo.PESCADO


# Talla de UN ejemplar: 0..1 LINEAL sobre la horquilla de la especie. Sin curva aqui a proposito —
# la rareza de los extremos la pone el SORTEO (tirada_talla), no esta conversion. Que sea lineal es
# lo que permite que las coronas se definan como franjas del TAMAÑO ("el 5% mas grande") y que sus
# cortes en centimetros salgan de una regla de tres que cualquiera puede comprobar.
func talla_desde(t: float) -> float:
	if cm_max <= 0.0:
		return 0.0
	var lo: float = minf(cm_min, cm_max)
	return lo + (cm_max - lo) * clampf(t, 0.0, 1.0)


# EL SORTEO: media de dos tiradas, o sea una CAMPANA (distribucion triangular). La mayoria de los
# peces salen del monton y los extremos son raros POR LOS DOS LADOS, que es lo que hace que tanto el
# ejemplar de museo como el enano de coleccion valgan algo.
#
# Estuvo sesgado hacia el minimo con una potencia (t^2.2) y era un error medido: amontonaba una de
# cada cuatro capturas en el 5% mas bajo de la horquilla, asi que la minicorona de oro -que deberia
# ser el premio raro de la punta pequeña- caia el 26% de las veces. Con la campana, cada corona sale
# en torno al 0.5% y cada plata al 1.5%.
static func tirada_talla(rng: RandomNumberGenerator = null) -> float:
	if rng == null:
		return (randf() + randf()) * 0.5
	return (rng.randf() + rng.randf()) * 0.5


# ============================================================
#  CORONAS (criterio Monster Hunter)
# ============================================================
#  La corona NO la da tu record personal: la da la TALLA en si, contra la horquilla de la especie.
#  Un ejemplar de museo lo es aunque sea el primero que pescas, y sigue siendolo cuando saques otro
#  mayor. Eso es lo que la convierte en algo que se colecciona y se enseña.
#
#  Cuatro premios, dos por cada punta de la horquilla:
#    GRANDE:      el 10%-5% mas alto -> PLATA      el 5%-0% mas alto -> ORO
#    MINIATURA:   el 10%-5% mas bajo -> PLATA      el 5%-0% mas bajo -> ORO
#  Fuera de esas franjas, un pez es un pez.
enum Corona { NINGUNA, MINI_PLATA, MINI_ORO, PLATA, ORO }

const CORONA_PLATA := 0.10   # la decima parte de cada punta
const CORONA_ORO := 0.05     # y la vigesima, dentro de ella


# Que corona le toca a un ejemplar de 'cm'. Devuelve Corona.NINGUNA en todo lo que no es pescado.
func corona_de(cm: float) -> int:
	if cm <= 0.0 or cm_max <= cm_min:
		return Corona.NINGUNA
	var t: float = clampf((cm - cm_min) / (cm_max - cm_min), 0.0, 1.0)
	if t >= 1.0 - CORONA_ORO:
		return Corona.ORO
	if t >= 1.0 - CORONA_PLATA:
		return Corona.PLATA
	if t <= CORONA_ORO:
		return Corona.MINI_ORO
	if t <= CORONA_PLATA:
		return Corona.MINI_PLATA
	return Corona.NINGUNA


# El corte, en CENTIMETROS, a partir del cual (o por debajo del cual) cae cada corona. Lo enseña el
# libro para que sepas exactamente que te falta, y sale de los campos: nadie lo escribe a mano.
func corona_umbral(corona: int) -> float:
	var rango: float = cm_max - cm_min
	match corona:
		Corona.ORO: return cm_min + rango * (1.0 - CORONA_ORO)
		Corona.PLATA: return cm_min + rango * (1.0 - CORONA_PLATA)
		Corona.MINI_ORO: return cm_min + rango * CORONA_ORO
		Corona.MINI_PLATA: return cm_min + rango * CORONA_PLATA
	return 0.0


# Prefijo corto para el nombre en la bolsa. El GLIFO dice el tipo (corona = grande, rombo =
# miniatura) y el color de la letra lo pone quien lo pinte; aqui va tambien la inicial para que se
# lea sin color, que es como se ve en una lista de texto.
static func corona_glifo(corona: int) -> String:
	match corona:
		Corona.ORO: return "👑O"
		Corona.PLATA: return "👑P"
		Corona.MINI_ORO: return "◆O"
		Corona.MINI_PLATA: return "◆P"
	return ""


static func corona_texto(corona: int) -> String:
	match corona:
		Corona.ORO: return "Corona de oro"
		Corona.PLATA: return "Corona de plata"
		Corona.MINI_ORO: return "Minicorona de oro"
		Corona.MINI_PLATA: return "Minicorona de plata"
	return "—"


# Color del premio, para pintarlo en la ficha. Las miniaturas van del mismo color que su hermana
# grande: el metal dice lo raro que es, y el glifo si es por arriba o por abajo.
static func corona_color(corona: int) -> Color:
	match corona:
		Corona.ORO, Corona.MINI_ORO: return Color(0.95, 0.80, 0.30)
		Corona.PLATA, Corona.MINI_PLATA: return Color(0.80, 0.84, 0.90)
	return Color(0.6, 0.63, 0.7)


# ¿Este material es un nucleo que sirve para MEJORAR el equipo?
func mejora_equipo() -> bool:
	return familia == Familia.NUCLEO and mejora_max > 0


# ¿Este material cubre el nivel de mejora `n`? (n = mejoras que YA tiene la pieza; llevarla al
# n+1 es lo que se esta pagando.) La banda es SEMIABIERTA [mejora_min, mejora_max), igual que la
# de los nucleos (ver Forge._material_de_nivel): asi dos bandas contiguas 0..3 y 3..9 no se solapan
# en el 3.
#
# mejora_max <= 0 = SIN BANDA: sirve para cualquier nivel. Hoy lo tienen los materiales que son la
# CIMA de su tier sin sub-tiers todavia (acero, madera negra, tablon negro) y los que no entran en
# la forja (babas). El metal, la madera y el cuero de T1/T2 SI estan divididos en sub-tiers y
# llevan su banda escrita, asi que ahi el gate si filtra.
func cubre_mejora(n: int) -> bool:
	if mejora_max <= 0:
		return true
	return n >= mejora_min and n < mejora_max

# Tope de mejora EFECTIVO: el campo, pero nunca por encima del maximo real del sistema
# (la rareza mas alta de Upgrades). Asi un .tres no puede prometer un +20 que no existe.
func mejora_tope() -> int:
	return clampi(mejora_max, 0, Upgrades.RAREZA_SLOTS[Upgrades.RAREZA_SLOTS.size() - 1])

func uso_mejora_texto() -> String:
	match uso_mejora:
		UsoMejora.ARMA: return "armas"
		UsoMejora.ARMADURA: return "armaduras"
		_: return "equipo"


# ============================================================
#  RANGO DE COLOR: cada material se mide por el eje de SU oficio
# ============================================================
#  El color de las particulas (veta en el mapa, drop en el suelo) dice lo bueno que es el material.
#  No hay UNA escalera: la herreria mide en +N de mejora y la alqumia en fase de pocion, asi que
#  forzar un eje unico mentiria sobre uno de los dos. Tres escalas, y el TECHO de cada una sale de
#  cuantas cosas hay en ella:
#
#   A1  recolectado y forjado (mineral/lingote/chapa/hebillas/cuero/curtido/madera/tablon/PLANTA)
#       -> 3 por tier, asi que 3 peldaños y TECHO AZUL. La banda (mejora_min) da el peldaño, y
#          reinicia en cada tier: cobre gris/verde/azul y hierro gris/verde/azul.
#   A2  nucleos -> sus bandas van de 3 en 3 y cubren el 0..15 entero: 5 peldaños, TECHO AMARILLO.
#          El amarillo cae solo en los dos nucleos de BOSS (rey slime, minotauro) sin marcarlos.
#   A3  babas -> son lo que define la fase de la pocion: 4 fases, 4 babas por linea, TECHO MORADO.
#
#  OJO con el error facil: la sanguinaria y el liquen abisal entran en el +3 de su pocion, pero son
#  PLANTAS y su techo es AZUL. El morado del +3 lo pone la baba, no la planta.
#
#  Las dos escalas no se solapan en ningun material: las babas no tienen banda y las plantas no
#  miran la receta, asi que no hay ninguna regla de prioridad que mantener.

# Los 5 peldaños, en orden. Son los MISMOS que las 5 primeras rarezas de Upgrades (ver
# color_rango): un verde tiene que significar lo mismo en una veta y en una espada.
enum Rango { GRIS, VERDE, AZUL, MORADO, AMARILLO }

# id de baba -> fase de pocion (0 = base ... 3 = +3). Se construye UNA vez desde las recetas, que
# son la unica fuente de verdad. Ver _indice_fases().
static var _fase_de_baba: Dictionary = {}
static var _fases_listas: bool = false


# El peldaño (0..4) de este material en la escala de su oficio.
func rango_color() -> int:
	if familia == Familia.NUCLEO:
		# Bandas de 3 en 3 sobre el 0..15: 0..3 gris, 3..6 verde, 6..9 azul, 9..12 morado,
		# 12..15 amarillo.
		return clampi(mejora_min / 3, Rango.GRIS, Rango.AMARILLO)
	if tipo == Tipo.BABA:
		return clampi(_fase_pocion(), Rango.GRIS, Rango.MORADO)
	# Sin banda = es la base de su tier (acero, madera negra...), no un material pobre. Gris, y
	# cuando le pongan el veteado y el profundo la escalera se completa sola.
	if mejora_max <= 0:
		return Rango.GRIS
	if mejora_min >= 9:
		return Rango.AZUL
	if mejora_min >= 3:
		return Rango.VERDE
	return Rango.GRIS


# El color del peldaño. Se lee de Upgrades.RAREZA_COLOR en vez de tener tabla propia: sus 5
# primeras rarezas son justo gris/verde/azul/morado/amarillo, asi que la escala de materiales es un
# PREFIJO de la de rareza. Una sola paleta en todo el proyecto -> imposible que se desincronicen.
func color_rango() -> Color:
	return Upgrades.rareza_color(rango_color())


# Lo ALTO que esta este material en su escala, 0..1. Alimenta el brillo de los destellos (el titulo de
# su ficha y su nodo en el mapa): un cobre corriente da un parpadeo tenue y un nucleo de boss
# centellea. Se normaliza con AMARILLO, el tope de las tres escalas de material, para que un verde de
# mineral y un verde de baba brillen igual.
func rango_intensidad() -> float:
	return clampf(float(rango_color()) / float(Rango.AMARILLO), 0.0, 1.0)


# Fase de pocion mas alta a la que sirve esta baba (0 = base). -1 si no esta en ninguna receta.
func _fase_pocion() -> int:
	return int(_indice_fases().get(id, 0))


# Recorre las recetas y saca la fase de cada baba. La fase NO se lee del nombre del archivo (el
# "_3" es una convencion, no un dato): se deriva de la CADENA, que es lo que hace que la linea T3
# se coloree sola el dia que la montes. RecipeData.pocion_base == null es la fase 0, y cada receta
# de mejora es un escalon sobre la pocion que consume.
static func _indice_fases() -> Dictionary:
	if _fases_listas:
		return _fase_de_baba
	var recetas: Array = Game.recetas_boticaria()
	if recetas.is_empty():
		# Game aun no esta listo. NO se cachea: se reintenta a la siguiente.
		return {}

	# 1) Fase de cada POCION. Varias pasadas porque una mejora necesita que su pocion_base ya
	#    tenga fase, y el orden de la lista no lo garantiza.
	var fase_pocion: Dictionary = {}
	for _pasada in range(recetas.size()):
		var cambio := false
		for r in recetas:
			var rec := r as RecipeData
			if rec == null or rec.resultado == null or fase_pocion.has(rec.resultado):
				continue
			if rec.pocion_base == null:
				fase_pocion[rec.resultado] = 0
				cambio = true
			elif fase_pocion.has(rec.pocion_base):
				fase_pocion[rec.resultado] = int(fase_pocion[rec.pocion_base]) + 1
				cambio = true
		if not cambio:
			break

	# 2) Cada baba se queda con la fase MAS ALTA a la que sirve. La rareza mide el techo, igual que
	#    mejora_tope() en los nucleos.
	for r in recetas:
		var rec := r as RecipeData
		if rec == null or not fase_pocion.has(rec.resultado):
			continue
		var fase: int = int(fase_pocion[rec.resultado])
		for ing in rec.ingredientes:
			if ing == null or ing.material == null:
				continue
			var mat := ing.material as MaterialData
			if mat == null or mat.tipo != Tipo.BABA:
				continue
			if fase > int(_fase_de_baba.get(mat.id, -1)):
				_fase_de_baba[mat.id] = fase

	_fases_listas = true
	return _fase_de_baba


# Los NUMEROS visibles salen de aqui, no de la descripcion.
func resumen() -> String:
	var partes: PackedStringArray = [
		"%s · %s · grado %d" % [familia_texto(), tipo_texto(), tier],
		"valor base %d" % valor_base,
		"peso %.1f" % peso_base,
	]
	# La DESPENSA va con un "y ademas": la mitad se recolecta (sal, silvestres) y la otra mitad se
	# compra hecha (verduras, pan), asi que aqui manda la exigencia y no el tipo. Los demas siguen
	# preguntandose por tipo porque hay .tres de baba/cuero con la exigencia por defecto sin limpiar.
	if es_veta() or es_planta() or es_madera() or es_pescado() \
			or (tipo == Tipo.DESPENSA and exigencia > 0.0):
		partes.append("exigencia %d" % roundi(exigencia))
	if es_pescado() and cm_max > 0.0:
		partes.append("talla %.1f-%.1f cm" % [cm_min, cm_max])
	if mejora_equipo():
		var uso: String = uso_mejora_texto()
		if tier_equipo > 0:
			uso = "%s T%d" % [uso, tier_equipo]
		partes.append("mejora hasta +%d · %s" % [mejora_tope(), uso])
	# El PISO ya no sale aqui: en la ficha de un material que YA TIENES, saber de que profundidad
	# venia no te sirve para nada. piso_min/piso_max siguen intactos -- los usa la generacion.
	return "  ·  ".join(partes)
