# ============================================================
#  lampara.gd  (class_name Lampara)
#  La MATH del farolillo. Estatica y sin estado, como Upgrades y StatsMath: game.gd le pasa los
#  datos del objeto y le devuelve el radio. Aqui no se lee ni un autoload.
#
# ------------------------------------------------------------
#  QUE PROBLEMA RESUELVE
# ------------------------------------------------------------
#  La mazmorra esta a oscuras y el radio de luz es EL recurso que decide si puedes jugar en un
#  piso. La regla, cerrada con el usuario:
#
#      radio(piso) = MINIMO + (TOPE - MINIMO) * clamp(potencia / requisito(piso))
#
#  Se lee asi: EL MISMO FAROLILLO ALUMBRA MENOS CUANTO MAS BAJAS. El requisito del piso sube con
#  la profundidad, asi que para recuperar el corro hay que subir de sub-tier, de tier, sacar mejor
#  tirada en la forja o meterle mejoras. Es la misma forma que ya tiene la recoleccion
#  (Game._exigencia_material): una rampa por profundidad contra la que compite tu equipo.
#
#  Y HAY UN SUELO DURO. Por hondo que vayas -- aunque el requisito fuese diez mil millones --
#  nunca bajas de RADIO_MINIMO. Es una promesa al jugador: la oscuridad puede dejarte casi ciego,
#  ciego del todo nunca. Sin ese suelo, un piso hondo sin farolillo bueno seria injugable en vez
#  de dificil.
#
#  'piso' entra como PARAMETRO y no se lee de Game.current_floor, igual que en la recoleccion: asi
#  la ficha del inventario puede enseñarte "en el piso 9 tendrias X" sin que estes en el 9.
#
#  TODOS ESTOS NUMEROS SON PROVISIONALES -> Excel, y se calibran jugando.
# ============================================================

extends RefCounted
class_name Lampara

# El suelo duro y el techo, en CELDAS de mapa. El minimo lo fija Vision (es la promesa de que
# siempre ves tu corro) y se repite aqui como referencia de lectura, no como copia: el que manda
# es Vision.RADIO_MINIMO y de ahi lo lee radio().
const RADIO_TOPE := 14.0

# El requisito del piso 1 y su rampa. 1.14 por piso compone a x2 cada cinco pisos, que es
# aproximadamente el ritmo al que sube todo lo demas de la mazmorra.
const REQ_BASE := 100.0
const REQ_FACTOR := 1.14

# POTENCIA por tier del metal. Misma forma que Upgrades.TOOL_AFINIDAD_TIER: el tier es el salto
# gordo, la rareza y la veta lo afinan.
#
# CALIBRADO CONTRA EL REQUISITO, no a ojo. La primera version puso 100 aqui, o sea justo el
# requisito del piso 1, y con eso el farolillo mas cutre del juego daba YA el radio maximo nada
# mas empezar: no habia nada que mejorar y el sistema entero era decorativo.
#
# El ancla es: un farolillo COMUN y sin mejoras, en el PRIMER piso de su tramo, tiene que dar
# ~7 celdas (algo mas del doble del suelo duro: se nota muchisimo, pero se queda corto). Eso es
# t = 0.36, o sea potencia = 0.36 x requisito = 36. Y x2 por tier, que es lo que crece el
# requisito en los seis pisos que dura cada tramo (1.14^5 = 1.93).
#
# El techo se alcanza con la pieza cuidada: rareza (x1.65) por veta (x1.25) por mejoras (hasta
# x2.5) son x5.16 sobre la base, asi que un farolillo prístino y bien mejorado SI llega al tope
# en los pisos de su tramo. Esa es la recompensa de haberlo trabajado.
const POT_TIER := [36.0, 72.0, 144.0]

# La rareza y la veta (sub-tier del metal) usan las MISMAS tablas que las herramientas de
# recoleccion, a proposito: son el mismo objeto para el jugador (algo que forjas y que rinde
# segun lo bien que salio), asi que tienen que premiar igual.
#   rareza -> Upgrades.TOOL_AFINIDAD_RAREZA
#   veta   -> Upgrades.TOOL_AFINIDAD_VETA

# Lo que suma CADA mejora. El farolillo es la primera herramienta mejorable y su mejora es "a
# secas": no eliges categoria, cada punto sube la potencia y ya (ver Upgrades.LUMINOSIDAD). El
# +10% es el mismo paso que usa el resto del equipo (Upgrades.UPGRADE_PCT), para que una mejora
# valga lo que vale una mejora en cualquier otra cosa.
const MEJORA_PCT := 0.10


# La potencia de un farolillo concreto. 'mejoras' es el numero de puntos de LUMINOSIDAD que lleva.
static func potencia(tier: int, rareza: int, banda: int, mejoras: int) -> float:
	var t: int = clampi(tier - 1, 0, POT_TIER.size() - 1)
	var r: int = clampi(rareza, 0, Upgrades.TOOL_AFINIDAD_RAREZA.size() - 1)
	var col: int = Upgrades.banda_columna(banda)
	return float(POT_TIER[t]) * float(Upgrades.TOOL_AFINIDAD_RAREZA[r]) \
		* float(Upgrades.TOOL_AFINIDAD_VETA[col]) * (1.0 + MEJORA_PCT * float(maxi(0, mejoras)))


static func requisito(piso: int) -> float:
	return REQ_BASE * pow(REQ_FACTOR, float(maxi(1, piso) - 1))


# EL RADIO, en celdas. 'potencia' a 0 (sin farolillo, apagado o sin carbon) devuelve el minimo.
static func radio(pot: float, piso: int) -> float:
	var t: float = clampf(pot / requisito(piso), 0.0, 1.0)
	return Vision.RADIO_MINIMO + (RADIO_TOPE - Vision.RADIO_MINIMO) * t


# ============================================================
#  EL CARBON
# ============================================================
# Cuanto arde cada carbon, en SEGUNDOS de reloj de mazmorra. Va por id del material y no por un
# campo del .tres porque es una propiedad del SISTEMA de luz, no del material: el mismo carbon
# vale para cocinar el dia que haga falta y no tiene por que arrastrar ahi una duracion de llama.
#
# La escalera esta pensada para que llevar del bueno se note pero el barato nunca sea inutil: el
# vegetal se fabrica gratis en la carpinteria con madera, el mineral hay que picarlo.
#
# CORTAS a proposito. Con 5 y 12 minutos una expedicion entera se hacia con dos trozos y el carbon
# dejaba de ser una decision: lo llevabas y te olvidabas. A 2 y 5 tienes que contar cuanto te
# queda, y quedarte a oscuras en el piso 6 es un riesgo real, que es justo lo que le da sentido a
# picar carbon abajo en vez de bajar con la mochila llena de otra cosa.
#
# LA ESCALERA VEGETAL TIENE TECHO, Y ES LA REGLA QUE LA ORDENA: el mejor carbon que puedes
# FABRICAR (el negro, 4:30) se queda por debajo del peor que hay que BAJAR A PICAR (el mineral,
# 5:00). Si el vegetal alcanzara al mineral, la veta de carbon sobraria y no habria razon para
# arriesgarse abajo a por combustible: te quedarias en el pueblo quemando lena.
const DURACION := {
	# Vegetal: se hace en la carbonera del carpintero, uno por cada madera.
	&"carbon_vegetal": 120.0,       # 2:00   madera comun        (T1 base)
	&"carbon_veta": 150.0,          # 2:30   madera de veta      (T1 +1)
	&"carbon_anillado": 180.0,      # 3:00   madera anillada     (T1 +2)
	&"carbon_duro": 200.0,          # 3:20   madera dura         (T2 base)
	&"carbon_ferreo": 220.0,        # 3:40   madera ferrea       (T2 +1)
	&"carbon_petrificado": 240.0,   # 4:00   madera petrificada  (T2 +2)
	&"carbon_negro": 270.0,         # 4:30   madera negra        (T3)  <- el techo de lo fabricable
	# Mineral: se pica en la mazmorra. Empieza donde acaba el vegetal.
	&"carbon_mineral": 300.0,       # 5:00
	&"antracita": 700.0,            # ~12 min (T2, con los pisos 7+)
}

# Y la CALIDAD del trozo lo estira o lo encoge. Se usa score_calidad() y NUNCA int(calidad):
# MaterialItem.Calidad no esta ordenado por calidad (PURO va el ultimo), asi que comparar el
# entero es un bug clasico de este proyecto.
const CALIDAD_MULT := 0.5     # un PURO dura un 50% mas que un ROTO

static func duracion(m: MaterialItem) -> float:
	if m == null or m.data == null:
		return 0.0
	var base: float = float(DURACION.get(m.data.id, 240.0))
	return base * (1.0 + CALIDAD_MULT * m.score_calidad())


static func es_combustible(m: MaterialItem) -> bool:
	return m != null and m.data != null and int(m.data.tipo) == MaterialData.Tipo.COMBUSTIBLE
