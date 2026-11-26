# ============================================================
#  ability_data.gd  (KAN-57)
#  RECURSO con los DATOS de una HABILIDAD de arma. Se guarda como .tres.
#  Las arma/escudo TRAEN sus habilidades (WeaponData.habilidades / ShieldData.habilidades);
#  el loadout las junta y el jugador puede usarlas en combate (acción "Habilidad"),
#  gastando ENERGIA (= stamina de entrada, KAN-57). Reutiliza StatusApplication para
#  los estados que aplica (sangrado, aturdido...), como los hechizos.
# ============================================================

extends Resource
class_name AbilityData

@export var nombre: String = "Habilidad"
@export_multiline var descripcion: String = ""

# --- APRENDIZAJE (maestro de habilidades) ---
# El arma define su POOL entero, pero de ese pool solo puedes usar lo que SABES y lo que
# llevas EQUIPADO (Game.MAX_HABILIDADES a la vez). Estos dos campos son la parte de "lo que
# sabes": inicial = viene de fabrica con el arma (si no, comprar un arma nueva te dejaria sin
# nada que pulsar); el resto te las tiene que enseñar el maestro del pueblo por `precio`.
# Las habilidades de ENEMIGO se quedan con los valores por defecto: no pasan por aqui.
@export var inicial: bool = false
@export var precio: int = 0

# Energia que gasta al usarla (KAN-57). El DUAL gasta mas (mete mas golpes con la
# misma arma), en vez de bajar el daño por golpe. coste_energia_dual = 0 -> igual que base.
@export var coste_energia: float = 20.0
@export var coste_energia_dual: float = 0.0

# --- GOLPES (daño): rango ALEATORIO de impactos. El dual usa su propio rango (una
# Ráfaga con dos dagas da mas tajos). Si golpes_dual_max = 0, el dual usa el rango normal.
@export var golpes_min: int = 1
@export var golpes_max: int = 1
@export var golpes_dual_min: int = 0
@export var golpes_dual_max: int = 0

# ESCALA DE GOLPES POR MULTITUD (flurries 1H): golpes EXTRA por cada enemigo vivo ADICIONAL al
# primero. Es la respuesta multi-target de las armas de una mano: en grupo meten MÁS tajos (que
# la redirección al matar reparte solos entre los enemigos). Las dagas escalan más que el resto
# (más rápidas): Ráfaga 1.15/enemigo, Fintas/Doble tajo 0.70. El dual mete aún más (variante
# propia; 0 = usa el valor base). Todo redondeado hacia abajo y con tope (que no se dispare).
@export var golpes_extra_por_enemigo: float = 0.0
@export var golpes_extra_por_enemigo_dual: float = 0.0
@export var golpes_extra_max: int = 4

# Daño por impacto respecto a un ataque normal (1.0 = como un básico; <1 = flurry).
@export var dano_mult: float = 1.0

# ROBO DE VIDA: fracción del daño HECHO que se cura el que pega. 0 = ninguno (lo normal).
# 0.5 = se cura la mitad de lo que saca.
#
# Se mide sobre el daño que de verdad ha ENTRADO (ya mitigado por la defensa y la armadura), no
# sobre el daño teórico: contra un tanque, drenar tiene que rendir poco — que es justo lo que hace
# que valga la pena ir a por el que va ligero.
#
# Vale para las DOS ramas. Lo estrena el Drenaje del chupasimas, pero está en AbilityData y no en
# el enemigo a propósito: el día que una técnica del jugador robe vida, funciona sola.
@export var robo_vida: float = 0.0
# (20/11, el Cazador lunar) El robo de vida SOLO en esa fase de la luna de quien la lanza (-1 = siempre): la Caida de la
# luna en la menguante. Ver robo_vida_en().
@export var robo_vida_fase: int = -1

const FASES_LUNA_TXT := ["luna nueva", "luna creciente", "luna llena", "luna menguante"]


# Lo que roba con la fase de la luna de quien la lanza (-1 = no tiene fases).
func robo_vida_en(fase: int) -> float:
	return robo_vida if robo_vida_fase < 0 or fase == robo_vida_fase else 0.0
# (18/11, los mutantes de la chupasimas) BEBE MANA: le quita a quien muerde esta parte de su mana MAXIMO, una vez por uso
# (si conecta algun golpe), y lo que bebe CARGA el Rayo de mana de quien la usa (Combatant.mana_bebido).
@export var roba_mana: float = 0.0
# EL RAYO DE MANA: su daño sale de lo bebido (RAYO_BASE + RAYO_POR_MANA x mana, hasta RAYO_TOPE) y al soltarlo se vacia.
# Cuando lo suelta lo decide MutacionData (rayo_tope / rayo_min / rayo_prob).
@export var rayo_mana: bool = false
const RAYO_BASE := 0.5
const RAYO_POR_MANA := 0.12
const RAYO_TOPE := 2.0
# LO CARGADO QUE VA SE VE (18/11): el haz engorda con la carga (0..1 de su tope). Viaja en el PESO del golpe, que ya va en
# el paquete de impactos (0..1,98 en pasos de 1/64): el espejo pinta el mismo grosor sin mandar nada mas. El peso de
# siempre es 1; el del rayo, PESO_RAYO_MIN + la carga (CombatTactico._chupasimas_pixel lo deshace con carga_de_peso).
const PESO_RAYO_MIN := 0.2


static func peso_rayo(bebido: float, tope: float) -> float:
	return PESO_RAYO_MIN + (clampf(bebido / tope, 0.0, 1.0) if tope > 0.0 else 0.0)


static func carga_de_peso(peso: float) -> float:
	return clampf(peso - PESO_RAYO_MIN, 0.0, 1.0)
# SE APARTA (el Sorbo de la Vidriada): acabados sus golpes se aleja esto de su victima. 0 = se queda.
@export var se_aparta: float = 0.0

# Lo que aporta la SEGUNDA MANO pega ALGO MENOS: los golpes EXTRA que solo existen porque
# llevas dos armas (los que pasan del rango de UNA mano) pegan a este multiplicador. A 0.6 el
# dual vale ~1.6x la version a una mano (subido de 0.5/~1.5x: las ligeras/dual iban ~8% bajo el
# techo y se les acerca un pelin sin PASARLO, que romperia el eje "dual < 2 manos en bruto").
# PROVISIONAL: al tocarlo hay que RE-MEDIR la tabla de armas contra el techo, no fiarse (ver
# memoria ajuste-curvas-holistico). Todas las armas que van a dual son ligeras, asi que sube el
# grupo entero por igual y su balance INTERNO no cambia.
@export var dual_golpe_mult: float = 0.6
# MULTIPLICADOR EXPLICITO POR GOLPE (índice 0-based). Vacío = manda la regla del dual (arriba).
# Lo usan las técnicas de ARMA + ESCUDO (Aplastamiento, Guardia rota): el 1er golpe es con el ARMA
# (más daño) y el 2º con el ESCUDO (menos). Cada golpe se simula distinto sin dos armas de por
# medio. Si el índice pasa del array, se repite el último valor.
@export var mults_golpe: Array = []
# Tipo de daño forzado: -1 = el del arma; 0 CORTE, 1 CONTUNDENTE (golpe de escudo).
@export var dano_tipo_override: int = -1

# GOLPES CON EL ESCUDO: indice del primer golpe que se da con el ESCUDO (-1 = ninguno).
# Del indice en adelante, el golpe NO escala con tu ATAQUE sino con tu DEFENSA (ver
# Combatant.atk_escudo). Es lo que hace que un escudazo sea del ESCUDO y no del arma que llevas
# en la otra mano: antes, un golpe de escudo con mandobles pegaba mas que con daga, que no tiene
# ningun sentido — el escudo es el mismo.
#
# Ademas convierte el escudazo en la jugada del TANQUE: quien va con armadura pesada y Resistencia
# alta pega fuerte con el, y quien se cuelga un escudo llevando build de daño, no. Se combina con
# mults_golpe: en Guardia rota / Aplastamiento el golpe 0 es del ARMA (con tu Ataque) y el 1 del
# ESCUDO (con tu Defensa), cada uno con su atributo.
@export var escudo_desde_golpe: int = -1
# Y AL REVES (26/11, el Avance cubierto del estoque con rodela): del golpe 0 HASTA este (incluido) van con el ESCUDO y
# los de despues con el arma: primero el rodelazo y luego la estocada. -1 = ninguno.
@export var escudo_hasta_golpe: int = -1

# ¿Este golpe (0-indexado) se da con el escudo?
func golpe_es_de_escudo(i: int) -> bool:
	return (escudo_desde_golpe >= 0 and i >= escudo_desde_golpe) or (escudo_hasta_golpe >= 0 and i <= escudo_hasta_golpe)


# ¿Alguno de sus golpes es de escudo? (para decir en el log con QUE pega cada uno)
func tiene_golpe_de_escudo() -> bool:
	return escudo_desde_golpe >= 0 or escudo_hasta_golpe >= 0


# ¿TODOS sus golpes son de escudo? Es decir: ¿es una tecnica de escudo entera, y no un ataque de arma
# que ademas remata con el?
#
# Solo lo mira el DIBUJO (ver _resolver_golpe_hab en combat.gd). Un golpe de escudo se pinta como un
# ESCUDAZO por defecto, y esta bien para la Guardia rota o el Aplastamiento -- alli el golpe 0 es del
# arma y el 1 del escudo, y con el estilo de la habilidad para los dos salian dos tajos iguales.
#
# Pero cuando la habilidad ENTERA se da con el escudo, ese respaldo estorba: la Embestida ("bajas el
# hombro detras del escudo y le entras encima") no es un empujon de plancha, es una carga, y sin esto
# no habia forma de que pidiera su propio gesto. La regla queda: el escudazo es el respaldo de un
# golpe de escudo SUELTO; si la tecnica es toda suya y pide dibujo, manda el suyo.
func es_toda_de_escudo() -> bool:
	return escudo_desde_golpe == 0


# ============================================================
#  IMBUICION DESDE EL ARMA (el veneno de la daga)
#  Hasta ahora solo imbuian los HECHIZOS (SpellData.imbue_*). Estos campos son su espejo, y
#  reutilizan toda la maquinaria que ya existe: Combatant.aplicar_imbue, el gasto de UNA carga por
#  ATAQUE (no por golpe), la persistencia entre combates en PersonajeData.imbue y los chips.
#
#  La diferencia esta en la TIRADA: dos escalones (60% un stack, 10% dos) y por DESTREZA en vez de
#  por Magia, porque un picaro que envenena su daga no tiene Magia que valga. Ver roll_imbue.
# ============================================================
@export var imbue_estado: int = -1        # StatusEffects.Id (-1 = esta habilidad no imbuye)
@export var imbue_usos: int = 0           # duracion en ATAQUES, no en turnos
@export var imbue_pct: float = 0.0        # fraccion de daño elemental extra (0 = no añade daño)
@export var imbue_elemento: int = 0       # Elementos.Elemento; NINGUNO si solo mete estado
@export var imbue_prob: float = 0.0       # prob. de UN stack, en igualdad de stat vs Resistencia
@export var imbue_prob_doble: float = 0.0 # prob. de DOS stacks de golpe (se tira antes)
@export var imbue_por_destreza: bool = false
# LA ESCALERA POR TIER (03/10, su decision). Dos tiradas: imbue_prob dice si PRENDE (la unica que tocan
# Destreza/Resistencia, eficacia y resistencia a estados); si prende, la fila del TIER del arma reparte
# cuantas dosis SUMA: fila[i] = prob. de +(i+1). Ej. T2 [0.6, 0.3, 0.1] = 60% +1, 30% +2, 10% +3.
# El TOPE del tier es el largo de su fila (T1 2, T2 3, T3 4, T4 5), y es el del ENEMIGO en total: cuatro
# dagas envenenadas no lo suben. Un tier por encima de la ultima fila usa la ultima. Vacia = la tirada
# vieja (imbue_prob +1 / imbue_prob_doble +2, sin tope propio).
@export var imbue_escalera: Array = []

# La fila de la escalera con un arma de 'tier' ([] = sin escalera).
func imbue_reparto(tier: int) -> Array:
	if imbue_escalera.is_empty():
		return []
	return imbue_escalera[clampi(tier, 1, imbue_escalera.size()) - 1]

# El tope con un arma de 'tier' (-1 = sin tope propio).
func imbue_tope(tier: int) -> int:
	var fila: Array = imbue_reparto(tier)
	return fila.size() if not fila.is_empty() else -1

# "1 acumulación (60 %), 2 (30 %) o 3 (10 %)" (lo usan la ficha y el chip de la imbuicion; pase de textos 06/11).
static func texto_reparto(fila: Array) -> String:
	var partes: Array = []
	for i in fila.size():
		if float(fila[i]) <= 0.0:
			continue   # (24/11) en los tiers pares no se mete 1 sola: no se nombra
		partes.append("%d%s (%d %%)" % [i + 1, ("" if not partes.is_empty() else (" acumulación" if i == 0 else " acumulaciones")),
			roundi(float(fila[i]) * 100.0)])
	if partes.size() <= 1:
		return "1 acumulación" if partes.is_empty() else String(partes[0])
	return ", ".join(partes.slice(0, partes.size() - 1)) + " o " + String(partes[partes.size() - 1])

func es_imbuicion() -> bool:
	return imbue_estado >= 0 and imbue_usos > 0


# ============================================================
#  APOYO: apuntar a un ALIADO, limpiar debuffs y recortar cooldowns
# ============================================================
# A QUIEN va la habilidad. 0 = al enemigo (lo de siempre). 1 = a UN ALIADO que eliges (pasa por el
# mismo selector que los Filos, ver combat.gd._elegir_objetivo_aliado). 2 = a TODO el grupo.
# Es lo que permite curaciones y limpiezas sin un camino aparte por habilidad.
enum Objetivo { ENEMIGO, ALIADO, GRUPO }
@export var objetivo_aliado: int = Objetivo.ENEMIGO

# Cuantos DEBUFFS quita a cada objetivo (0 = ninguno, 99 = todos). Solo toca lo que el catalogo
# marca con "debuff": un buff tuyo (Fortaleza, Regeneracion) NO se limpia, ni el Mojado (que te
# protege de la quemadura) ni la Guardia de carne (te la has puesto tu, y quitarla te bajaria la
# vida de golpe). Si quita menos de los que hay, elige AL AZAR.
@export var limpia_debuffs: int = 0

# Turnos que le quita al cooldown de tus OTRAS habilidades. Nunca al suyo propio: si se
# autorredujera saldria gratis y el cooldown dejaria de significar nada.
@export var reduce_cooldowns: int = 0

# ============================================================
#  ÁREA / MULTI-OBJETIVO (habilidades melee). Dos modos distintos:
#   SPLASH  -> el PRINCIPAL recibe todos los golpes al 100%; cada SECUNDARIO los recibe
#              x area_secundario. El TOTAL CRECE con cada enemigo tocado (martillazo/cleave
#              que reparte de más). Golpe sísmico/Onda: 100/50 a toda la fila; Hendedura: 100/60
#              a como mucho 2 (area_max=2).
#   BARRIDO -> TODOS los objetivos reciben TODOS los golpes, pero cada golpe se multiplica por
#              area_falloff^(n-1), con n = enemigos VIVOS alcanzados EN ESE golpe (se recalcula
#              golpe a golpe). Así "cada objetivo extra baja el daño por golpe" y, si uno cae,
#              n baja y los golpes que quedan pegan más fuerte al que sobrevive (Molinete).
# Ambos limitados por area_max (tope de enemigos, incluido el principal; 99 = toda la fila viva).
enum AreaModo { NINGUNO, SPLASH, BARRIDO }
@export var area_modo: int = AreaModo.NINGUNO
@export var area_max: int = 99            # tope de enemigos alcanzados (incl. principal)
@export var area_secundario: float = 0.5  # SPLASH: fracción de daño a cada secundario (con 2 enemigos)
# SPLASH que se DILUYE con la multitud: el % de los secundarios BAJA esto por cada enemigo por
# encima de 2 (más cuerpos que absorben la onda = menos toca a cada uno). 0 = fijo (area_secundario
# siempre). Ej. 0.6 base con decay 0.10: 2 enemigos 60%, 3 → 50%, 4 → 40%, 5 → 30%. El principal
# siempre al 100%. Ver secundario_para().
@export var area_secundario_decay: float = 0.0
@export var area_falloff: float = 0.7     # BARRIDO: cada golpe x falloff^(n-1)
# ¿El AREA aplica también los ESTADOS de la habilidad a los secundarios (adyacentes)? (solo enemigos)
# false = los estados se quedan en el principal, los lados solo encajan el DAÑO reducido (Aplastamiento:
#         50% a los lados, pero el aturdir/pegajoso solo al de debajo).
# true  = los lados también reciben los estados, con la MISMA prob y la magnitud escalada por
#         area_secundario (Combustión: fuego de la mitad a los adyacentes con la misma probabilidad).
@export var area_efectos_secundarios: bool = false
# Multiplicador de la PROBABILIDAD de los estados en los SECUNDARIOS (adyacentes/fila), independiente
# del daño. 1.0 = misma prob que el principal (Combustión: el fuego a los lados prende igual);
# < 1.0 = menos probable a los lados (Pisotón sísmico: el lento pilla menos a los de al lado).
@export var area_prob_secundario: float = 1.0

# --- LA FORMA EN EL MAPA (combate tactico) -----------------------------------------------------
# QUE TROZO DE SUELO tapa esta habilidad cuando se pelea en el mapa. En la pantalla de fila esto no
# se usa para nada: alli "al lado" es la columna de al lado y basta con area_max.
#
#   -1 = DEDUCELA (lo que hace hoy cada habilidad sin tocar su ficha)
#    0 = PUNTO        un objetivo y ya
#    1 = CIRCULO      cae redondo. Sobre el objetivo (golpe sismico) o sobre TI (molinete):
#                     lo decide forma_desde_quien_ataca
#    2 = CONO         abanico hacia donde apuntas (hachazo brutal, alientos)
#    3 = LINEA        la franja recta entre tu y el fondo (lanza, estocada, rayo)
#    4 = RECTANGULO   una caja (huellas de cuerpo que cae)
# Van como ENTEROS y no como un enum importado a proposito: esto es scripts/items y no tiene por
# que saber nada de la pantalla de combate. Los nombres viven en CombatFormas.Tipo.
#
# LA FICHA MANDA. La deduccion es solo el valor por defecto para no tener que tocar las 120
# habilidades de golpe: la idea es ir rellenando esto UNA A UNA, que es donde se decide de verdad
# como se siente cada habilidad.
@export var forma: int = -1
# HACEN FALTA LAS DOS CABEZAS (05/11, la Pinza del Bicefalo): con una dormida (Dos mentes) no la puede usar.
@export var pide_dos_cabezas: bool = false
# El tamaño de la forma en px (0 = el de por defecto). Radio en CIRCULO y CONO, largo en LINEA,
# lado en RECTANGULO.
@export var forma_radio: float = 0.0
# El abanico ENTERO del cono, en grados (0 = el de por defecto).
@export var forma_apertura: float = 0.0
# ¿La forma nace en QUIEN ATACA o donde apunta? Es la diferencia entre el molinete (sales tu en el
# centro) y el golpe sismico (cae donde pegas). Solo lo miran CIRCULO y RECTANGULO: el cono y la
# linea salen siempre del que ataca.
@export var forma_desde_quien_ataca: bool = false
# COMO SE APUNTA EN EL MAPA (combate tactico). -1 = todavia no se ha hecho esta habilidad para el
# mapa: se resuelve como en la fila. Se rellena UNA A UNA, arma por arma (decision del usuario):
#    0 = OBJETIVO     pulsas a un enemigo
#    1 = DELANTE      la forma cae en la PUNTA DE TU ARMA (su alcance), hacia donde apuntas con el
#                     raton: el golpe sismico, el martillo de guerra
#    2 = ALREDEDOR    centrada en ti: el temblor
#    3 = LIBRE        un punto del suelo dentro de un rango (la magia)
# Los nombres viven en CombatFormas.Apunte. En el mapa NO hay tope de enemigos: le da a todo lo que
# la huella roce (area_max es cosa de la fila).
@export var forma_apunte: int = -1
# EL NUCLEO de un circulo: la zona de impacto, con el daño entero. Lo de fuera (el anillo) cobra
# area_secundario. 0 = sin nucleo, todo el circulo al daño entero. Es el golpe sismico que dibujo el
# usuario: un punto de impacto y los alrededores con menos.
@export var forma_nucleo: float = 0.0
# SIN NUCLEO, con cuanto le entra a TODOS los que pilla la huella (1.0 = el daño entero). Es el Temblor:
# un circulo grande que les da a todos al 70%. Con nucleo no se mira: fuera del nucleo manda
# area_secundario.
@export var forma_escala: float = 1.0
# LOS TROZOS DE UN CONO (0 o 1 = uno solo). El cono se parte en tantos tramos iguales a lo largo y cada
# uno pega forma_tramo_baja menos que el anterior: con 3 y 0.25, 100% / 75% / 50%. Es la Onda
# expansiva, que se va apagando al alejarse (lo pidio el usuario). La probabilidad de los estados baja
# con el daño, como en todas las areas. Cada uno cobra el tramo MAS CERCANO que le toque.
@export var forma_tramos: int = 0
# SE ELEVA mientras la carga (el Picado de la gargola, 30/09): ahi arriba no le llegan los golpes cuerpo a cuerpo
# (Combatant.volando, Pantalla._aplicar_pasivas y CombatTactico.llega). La magia si.
@export var eleva: bool = false
@export var forma_tramo_baja: float = 0.25
# EL ANCHO DE UNA LINEA, al salir de ti y al llegar al fondo (0 = el de por defecto; el del fondo < 0 =
# igual que al salir). Con el del fondo a casi 0 es el Tajo del verdugo: un cono al reves, ancho pegado
# a ti y afilado hasta una punta (su dibujo, 24/09). Los TRAMOS de arriba valen tambien para la linea.
@export var forma_ancho: float = 0.0
@export var forma_ancho_fin: float = -1.0
# (-2 = CombatFormas.BOLAS: no una franja sino una FILA DE CIRCULOS de forma_ancho, uno cada 35 px; los Carambanos.)
# EL SUELO SE ROMPE (solo en el mapa): -1 = no; 0 = GRIETAS (Temblor), 1 = LOSAS (Golpe sismico, Onda
# expansiva), 2 = ESTALLIDO (Martillo de guerra: geiser de polvo y grietas), 3 = ESTELA (Rompecorazas:
# no rompe nada, es la estela del arma; pega en el instante del golpe), 4 = CORTE (Tajo del verdugo: una
# cuchilla de aire que corre por la linea), 5 = GIRO (Molinete), 6 = SIEGA (Segar), 7 = GRITO (Grito de guerra).
# El HACHA GRANDE (HachaAire): 9 = HACHAZO (Hachazo brutal), 10 = CARNICERIA, 11 = DESGARRO, 12 = HENDEDURA,
# 13 = MIRADA (Sed de sangre). 14 = HUMO (Desaparecer de la daga). 15 = DANZA (Danza de acero: no pinta
# nada, es el compas al que avanza el cuerpo y caen las estocadas).
# Ver SueloRoto.Tipo. Con esto el golpe NO cae a la vez sobre todos: a cada uno le llega
# cuando la rotura alcanza su cuerpo, saliendo del centro de la huella (del que golpea, en el cono).
@export var suelo_roto: int = -1
# LOS GOLPES SE REPARTEN por la huella (solo en el mapa): en vez de caerle cada golpe a TODOS los que
# pilla, cada uno va a UNO, por turnos y del mas cercano al centro al mas lejano (golpe 1 al primero,
# golpe 2 al segundo... y vuelta a empezar). Con uno solo dentro, se los come todos. Es la Carniceria:
# tres hachazos repartidos por el cono, cada uno por su lado (24/09).
@export var forma_reparte: bool = false
# EL TIRON (solo en el mapa): px que se ARRASTRA hacia quien golpea a cada enemigo que encaja el golpe,
# en el instante en que se ve llegar. Nunca hasta meterselo encima. 0 = no tira. El Desgarro (24/09).
# NEGATIVO = EMPUJA, alejandolo de quien golpea (la Embestida, 25/09).
@export var tiron: float = 0.0
# APARTA A LOS LADOS (solo en el mapa, con LINEA): px que se lleva a un lado de la linea, al suyo, a cada uno
# que encaja el golpe. La Embestida del jabali (28/09): "que empuje hacia los lados a los que choca".
@export var aparta_lados: float = 0.0
# HASTA DONDE SE APUNTA una forma LIBRE, en px desde el borde de lo que pisas (0 = el alcance del arma,
# como DELANTE). El Oportunista de la daga se pone hasta 150 px lejos (24/09).
@export var forma_rango: float = 0.0
# A LA ESPALDA (solo en el mapa): la huella elige UN enemigo (el mas cercano a su centro) y el que la
# lanza aparece detras de el antes de golpear. Detras = del otro lado del que viene. Sin nadie dentro no
# hay salto ni golpe. El Oportunista de la daga (24/09).
@export var salto_espalda: bool = false
# SOLO AL PRIMERO (solo en el mapa): de todo lo que pilla la huella, le pega solo al MAS CERCANO a quien
# ataca. La Punzada al nervio (24/09): una linea larga, "que llega", pero la punta se clava en uno.
@export var forma_solo_primero: bool = false
# EL PASO (solo en el mapa): la huella LIBRE marca a donde das el paso (se recorta si hay pared o un
# enemigo en medio) y la estocada va a UNO, segun su regla (24/09, el Paso ligero):
#   - si al empezar tienes a alguien al alcance -> le pegas y DESPUES das el paso (para irte);
#   - si no, das el paso y, si al llegar tienes a alguien al alcance, le pegas a ese;
#   - si no hay nadie ni antes ni despues, solo el paso (y lo que te ponga a ti, la Presteza).
@export var paso: bool = false
# EL AVANCE (solo en el mapa, con LINEA): cruzas la linea entera ATRAVESANDO a los enemigos y los golpes
# caen por el camino, del primero al ultimo. La linea se corta donde haya pared o el borde, y nunca
# acabas encima de nadie. La Danza de acero (24/09).
@export var avance: bool = false
# LA HUELLA ES PARA LOS TUYOS (solo en el mapa): lo que pilla no son enemigos sino aliados, contando al que
# la lanza si queda dentro. Con objetivo ALIADO es el mas cercano al centro (Escolta, Muro: se apunta a
# uno); con buffs a_todo_el_grupo, solo los de dentro (Voz de mando, Cobertura). En la fila, como siempre.
# La espada larga y el escudo (25/09).
@export var forma_a_aliados: bool = false
# SIGUE AL ALIADO (la Escolta, 25/09): su estado propio va AL QUE LA LANZA, no al elegido, y le engancha a
# el (Combatant.escoltando_a): solo entra detras de los golpes de ESE. "Te pegas a uno de los tuyos".
@export var sigue_al_aliado: bool = false
# PONE EN DEFENSA (como el boton Defender) a los tuyos: en el mapa, a los que pilla la huella; en la fila,
# a todo el grupo. El Voto de guardia (25/09): "que todos entren en posicion de defensa cerca de ti".
@export var defensa_a_aliados: bool = false
# CIERRA FILAS (solo en el mapa): los tuyos que pilla la huella dan un paso de estos px HACIA el que la lanza,
# sin meterse encima de nadie. 0 = nadie se mueve. El Muro de aliados de la maza (25/09): "cierras la formacion".
@export var junta_aliados: float = 0.0
# LAS DOS A LA VEZ (con dos armas): sus golpes caen JUNTOS, en un solo gesto de las dos manos, en vez de uno con
# cada mano por turnos. El Golpe demoledor a dos mazas (25/09). Con un arma no cambia nada.
@export var dual_a_la_vez: bool = false
# EL ESCUDAZO TIENE SU PROPIA HUELLA (solo en el mapa): los golpes de escudo (escudo_desde_golpe) no caen
# en la forma de la habilidad sino en una LINEA de este largo, hacia donde apuntas, y los estados que no
# son por golpe van solo a los que se comen el escudazo. El ancho lo pone el escudo (ShieldData.
# ANCHO_ESCUDAZO). 0 = no hay. La Guardia rota (25/09): el cono del tajo y, dentro, la linea del escudo.
@export var forma_escudo_largo: float = 0.0
# CARGAR MUNICION (02/10, arco y ballesta): no pega; abre la lista de flechas (o virotes) que llevas en la bolsa y
# carga hasta ESTAS. Los proximos disparos pegan con su bonus. 0 = no es Cargar. Va siempre con el arma, fuera de
# los cuatro huecos (ver Game._aplicar_loadout). Es una PREPARACION (ver es_preparacion): no acaba el turno.
@export var cargar_municion: int = 0

# PREPARACION (03/10, su decision): Cargar (y Untar) NO acaban el turno. Despues de una solo te deja la OTRA
# preparacion, el basico, Defender o Pasar: nada de habilidades, magia ni objetos (ver combat._preps_turno).
func es_preparacion() -> bool:
	return cargar_municion > 0 or untar

# UNTAR (03/10, arco y ballesta): abre la lista de UNTURAS de la bolsa (ConsumableData.es_untura) y pone la elegida
# como imbuicion del arma. Va siempre con el arma, fuera de los cuatro huecos, y es una PREPARACION como Cargar.
@export var untar: bool = false
# CUANTA MUNICION CARGADA GASTA al soltarse (arco y ballesta, 02/10): una por proyectil. La Lluvia (3 flechas) y la
# Andanada (3 virotes) gastan 3; las que no disparan, 0. Si quedan menos, gasta las que haya y pega con su bonus.
@export var municion_por_uso: int = 1
# LA CARGA (solo en el mapa, con LINEA): corres por la linea hasta el PRIMERO que pille y le pegas; sin
# nadie, hasta el final. La Embestida del escudo (25/09).
@export var carga: bool = false
# EL CHARCO QUE SE QUEDA (solo en el mapa, 29/09, la Savia del trent): su huella se queda en el suelo estos TURNOS
# DE QUIEN LA LANZA (0 = nada), y a los del otro bando que la pisen -al pasar andando o al empezar su turno dentro-
# les tira los estados de 'efectos', una vez por turno como mucho. Ver CombatTactico.poner_charco.
@export var charco_turnos: int = 0
# Lo que se lee en el log cuando alguien lo pisa ("X pisa <esto>"). La Telaraña de la araña (29/09) es el segundo.
@export var charco_texto: String = "la savia"
# COMO SE VE lo que se queda: 0 = el charco de savia (BestiaAire.charco), 1 = la telaraña (InsectoAire.red). Viaja en la
# 'apertura' de su huella (el circulo no la usa): ver CombatTactico.poner_charco.
@export var charco_estilo: int = 0
# (06/10, las mutaciones del slime normal) 3 = charco de BABA del color del slime; 4 = baba con PINCHOS de cristal.
# (03/11) 11 = el charco de SAVIA NEGRA del Espantajo (BestiaAire.vestir_savia_negra).
# EL RASTRO: lo que se queda no es un charco donde cae sino la LINEA que ha recorrido (el Placaje del slime brotado).
@export var rastro: bool = false
# Los estados que mete el charco/rastro al pisarlo. Vacio = los de 'efectos' (como la Savia de siempre).
@export var charco_efectos: Array = []
# DAÑO al pisarlo, en fraccion de su ataque (0 = nada): el rastro de pinchos del brotado punzante, 0,5.
@export var charco_dano: float = 0.0
# (06/10, los mutantes del slime venenoso) 5 = NUBE DE MIASMA (la nube de esporas del miconido, en verde: se respira).
# EN QUE HUECO va el charco (0 = el de siempre). Un enemigo puede tener uno vivo por hueco: el miasma deja a la vez la
# nube del Escupitajo (1), la del Exhalar (2) y el rastro de su Placaje (el rastro va aparte, por 'rastro').
@export var charco_hueco: int = 0
# El RADIO del charco/nube que se queda, si no es el de su huella (0 = el de la huella): el Escupitajo del miasma pega en
# un circulo pequeño y deja una nube mas grande.
@export var charco_radio: float = 0.0
# EL COLOR DE SU EFECTO en el mapa, si no es el de quien la lanza (alfa 0 = el suyo): la ceniza escupe brasas naranjas
# pero su Sacudida y su Nube son de ceniza GRIS (06/10).
@export var color_fx: Color = Color(0, 0, 0, 0)
# LAS BURBUJAS FLOTANTES (06/10, idea del jefe para el slime pestilente): sin carga, suelta entre burbujas_min y
# burbujas_max burbujas a sitios AL AZAR alrededor suyo (entre burbuja_cerca y burbuja_lejos px de sus pies). Se quedan
# flotando: si uno de los tuyos la ATRAVIESA, revienta encima (burbuja_dano de su ataque + 'efectos'); si nadie la toca,
# revienta SOLA al cabo de burbuja_turnos_min..max turnos suyos, en un circulo de burbuja_estalla. 0 = no suelta.
@export var burbujas_max: int = 0
@export var burbujas_min: int = 2
@export var burbuja_cerca: float = 30.0
@export var burbuja_lejos: float = 140.0
@export var burbuja_radio: float = 22.0
@export var burbuja_estalla: float = 35.0
@export var burbuja_dano: float = 0.6
@export var burbuja_turnos_min: int = 1
@export var burbuja_turnos_max: int = 3
# (07/10, los mutantes del REY SLIME, numeros aprobados; solo en el mapa)
# PIEZAS QUE SE QUEDAN EN EL SUELO tras pegar: 'piezas' charquitos de charco_radio al azar dentro de su huella, durante
# pieza_turnos turnos suyos. Al pisarlos: charco_dano de su ataque + charco_efectos (como un charco), y la pieza se
# acaba (la aplastas). PIEZA_PEDAZO = los pedazos de la Escision del destronado: los que queden al acabarse sus turnos
# SE LE VUELVEN A JUNTAR (le curan pieza_cura de su vida cada uno). PIEZA_ESQUIRLA = las esquirlas de su corona, que se
# quedan clavadas (trampas: no se recogen).
enum Pieza { NINGUNA, PEDAZO, ESQUIRLA }
@export var pieza: int = Pieza.NINGUNA
@export var piezas: int = 0
@export var pieza_turnos: int = 2
@export var pieza_cura: float = 0.0
# EL DECRETO (el Rey tirano): sin daño; marca a uno de los tuyos 'decreto_turnos' (estado DECRETO, sin tirada): sus
# subditos solo van a por el y le hacen decreto_mult de daño.
@export var decreto_turnos: int = 0
@export var decreto_mult: float = 1.2
# (06/10, los mutantes del slime ABISAL, solo en el mapa)
# LLUVIA DE ESTRELLAS: 'estrellas_fugaces' caen AL AZAR dentro de su circulo (los puntos salen de la huella:
# AbisalAire.puntos_lluvia); a cada uno de los tuyos le pega cada una que caiga a 'fugaz_radio' de su cuerpo.
@export var estrellas_fugaces: int = 0
@export var fugaz_radio: float = 20.0
# CONSTELACION: rayos de luz que unen SUS ESTRELLAS en orden (de la mas vieja a la mas nueva) y la ultima con el; a quien
# cruce un rayo le pega (una vez). Necesita 'min_estrellas'.
@export var constelacion: bool = false
@export var min_estrellas: int = 0
# MIRADA ESTELAR: rayo de el a su PRESA (la que fijo al cargar, carga_persigue) y uno de CADA ESTRELLA a ella. La presa se
# lleva un golpe por rayo; a los demas que crucen un rayo, 'rayo_otros' por rayo. Si alguien se pone DELANTE en el rayo
# principal, se lo come el (y la presa no).
@export var mirada: bool = false
@export var rayo_ancho: float = 12.0
@export var rayo_otros: float = 0.5
# ATRAE hacia el centro de su huella estos px a quien le entre (el Agujero negro; como la Voragine).
@export var atrae: float = 0.0
# (04/11, el escarabajo) EN EL AIRE: mientras la carga no se le puede elegir (Id.EN_VUELO); un area lo baja y la pierde.
@export var en_vuelo: bool = false
# ARRASTRA AL PRIMERO hasta el final de su linea (la Embestida imantada).
@export var arrastra_primero: bool = false
# GASTA LAS LIMADURAS: +limaduras_mult de daño por cada una que lleve, y se quedan a cero (la Embestida imantada).
@export var gasta_limaduras: bool = false
# NO FALLA: sus golpes no se esquivan (la Mirada estelar).
@export var infalible: bool = false
# DESDE LAS SOMBRAS (30/10, el Mordisco sombrio): si quien la lanza esta EN LAS SOMBRAS, su PRIMER golpe no se esquiva.
@export var primero_infalible_en_sombras: bool = false
# POR LA ESPALDA (30/10, el Mordisco a traicion): + este % de daño si quien la lanza pega desde detras de su presa (la
# mitad de atras de hacia donde mira).
@export var extra_espalda: float = 0.0
# EL ELEMENTO DE SUS GOLPES si no es el de quien la lanza (-1 = el suyo): las estrellas del abisal son de LUZ.
@export var elemento_golpe: int = -1
# MAGICA (08/10/2026, de momento solo las de los slimes): pega con la MAGIA del que la lanza contra tu DEFENSA MAGICA y
# la reduccion magica de tu armadura. Defendiendo con escudo (17/11) tambien su Defensa magica, el bloqueo a medias y el
# critico a la mitad. Ver StatsMath.resolve_magico_enemigo.
@export var es_magico: bool = false
# (09/11, las Esporas de infeccion del Aventurero florecido, memoria miconido-mutante) LA INFECCION TAMBIEN A LOS SUYOS: a
# cada enemigo (de su bando) dentro de su area al soltarla, y a los que empiecen su turno dentro de su nube, esta prob. de
# quedar INFECTADO (sin daño: son los suyos). Si caen asi, se levantan con hongos.
@export var infecta_suyos: float = 0.0
# EN ABANICO (05/11, el Vendaval de cortes del Vendaval rojo): una LINEA se lanza 'lineas_abanico' veces, repartidas en
# 'lineas_angulo' grados (el abanico ENTERO). Quien quede donde se cruzan se come varias. 0/1 = una sola.
@export var lineas_abanico: int = 0
@export var lineas_angulo: float = 40.0
# ATRAVIESA (solo en el mapa, con LINEA y 'carga'): no se para en el primero, rueda hasta el final de la linea
# arrollando a todos por el camino; el primero se lleva el golpe entero y los demas area_secundario, hasta
# area_max. La Embestida rodante del escarabajo (29/09).
@export var atraviesa: bool = false
# EL PISOTON DEL FINAL (solo en el mapa, con 'atraviesa'): radio del circulo que cae donde acaba la linea; a quien pille
# le entra el golpe ENTERO (fuera del tope de area_max). Se pinta en rojo con la linea mientras carga. La Carga
# acorazada de la bestia (30/09): arrolla y al pararse pisa.
@export var pisoton_final: float = 0.0
# RECORRE SU LINEA (solo en el mapa, con LINEA y sin carga): el enemigo va por ella hasta el final, sin pararse, mientras
# pega; a cada uno le llegan sus golpes cuando el cuerpo le pasa por encima (lo retrasa su suelo). La Oleada de patas
# del ciempies (29/09, idea del usuario: "te pasa por encima o por el lado mientras te golpea con las patas").
@export var recorre: bool = false
# LAS DOS MITADES (solo en el mapa, con CONO de 2 golpes): el golpe 1 cae en la mitad IZQUIERDA del cono y el
# 2 en la DERECHA (vistas desde quien lo lanza); el que quede en medio se come los dos. La Doble guadaña de la
# segadora (29/09, idea suya: "uno por cada lado").
@export var forma_mitades: bool = false
# PERSIGUE A SU PRESA (solo en el mapa, carga de un ENEMIGO con LINEA): al empezar a cargar no pinta la huella
# en el suelo, MARCA A UNO de los tuyos (nunca al de mas aggro si hay otro) y al soltar la linea sale hacia
# donde este entonces. Apartarse no sirve: se evita aturdiendole o metiendo a otro en medio (la linea es de
# forma_solo_primero). El Ensarte de la segadora (29/09).
@export var carga_persigue: bool = false
# ENROSCA (solo en el mapa): si el golpe entra, el que la lanza se queda enroscado en su victima y los dos
# clavados (CombatTactico.empezar_enrosque). El Enrosque del ciempies (29/09).
@export var enrosca: bool = false
# CAPULLO (03/11, la Tejedora de brasas): si el golpe entra, teje un Capullo de ceniza alrededor del golpeado (ver
# CombatEnemigos.poner_capullo).
@export var capullo: bool = false
# PEGA (solo en el mapa): si el golpe entra, el que la lanza se queda PEGADO encima de su victima y va con ella a donde
# vaya, chupandole cada turno suyo (CombatTactico.empezar_pegada). El Adherirse del chupasimas (30/09).
@export var pega: bool = false
# VUELVE (solo en el mapa, con 'salta'): acabados los golpes, el que la lanza vuelve de otro salto a donde estaba. El
# Picado del chillon (30/09): "cae, muerde y ya esta otra vez arriba" (CombatTactico.mover_enemigo).
@export var vuelve: bool = false
# LOS TRAMOS BAJAN TAMBIEN LA PROBABILIDAD de sus estados (solo en el mapa, con forma_tramos): cuanto mas lejos, menos
# daño Y menos probable que prenda. El Aleteo cegador de la polilla (30/09, idea del usuario).
@export var tramos_bajan_prob: bool = false
# EL SALTO (solo en el mapa, con CIRCULO): el que la lanza se echa por el aire y cae en el centro de su huella,
# sin quedar encima de nadie. El Reventon del slime y el Aplastamiento del Rey (28/09): "el slime hinchandose
# y saltando sobre los personajes".
@export var salta: bool = false
# CRITICO DE MAS de esta habilidad, sumado a la probabilidad de siempre (0.3 = +30 puntos).
@export var crit_extra: float = 0.0
# DEFENSA QUE IGNORA DE MAS esta habilidad, sumada a la penetracion del arma (0.2 = un 20% mas de la
# defensa del cuerpo). La Estocada penetrante (24/09, idea suya: "por algo es penetrante").
@export var penetracion_extra: float = 0.0

# REPARTO POR GOLPE (solo ENEMIGOS, multi-golpe a un solo objetivo): cada golpe elige objetivo al
# azar entre TU grupo vivo, en vez de descargarlos todos sobre el mismo. Con 2 golpes pueden caer
# los dos al mismo aliado o uno a cada uno; con más, se reparten. Es distinto del área: no salpica
# a los lados, cada golpe es un impacto pleno sobre quien le toque. No hace nada en las armas del
# jugador (ahi los golpes ya se redirigen al matar). Ver combat.gd._enemy_use_ability.
@export var reparto_por_golpe: bool = false

# REDIRECCIÓN AL MATAR (flurries a un solo objetivo, area_modo NINGUNO): si el objetivo cae y
# aún quedan golpes, en vez de perderlos saltan al siguiente enemigo VIVO y siguen pegando ahí.
# Es la identidad multi-target de las armas de una mano/dagas: nunca desperdician overkill y
# esparcen sus estados (sangrado, aturdido...) al rematar. Solo tiene efecto en multi-golpe.
@export var redirige_al_morir: bool = false

# ¿Golpea en área? (modo distinto de NINGUNO). Atajo para la UI y el core de combate.
func es_area() -> bool:
	return area_modo != AreaModo.NINGUNO


# Fracción de daño que recibe cada SECUNDARIO de un SPLASH según cuántos enemigos hay EN TOTAL
# (incluido el principal). Sin decay es fija; con decay baja por cada enemigo por encima de 2, con
# suelo en 0 (nunca daño negativo). El principal no pasa por aquí: siempre pega al 100%.
func secundario_para(n_enemigos: int) -> float:
	var extra: int = maxi(0, n_enemigos - 2)
	return maxf(0.0, area_secundario - area_secundario_decay * float(extra))


# Estados que aplica al enemigo (Array[StatusApplication], con su prob).
@export var efectos: Array = []
# EL ARBOL de esta ficha (22/11, memoria rangos-magias-y-habilidades): sus nodos (scripts/items/nodo_mejora.gd), que
# la van modificando. Lo monta Mejoras.montar para la pelea con los que haya cogido cada personaje.
@export var arbol: Array = []
# LA POTENCIA DEL NIVEL (24/11, el prestamo): la fijan los nodos con ["presupuesto", parte] y Mejoras la hornea al montar
# (daño x potencia, energia x potencia_coste) y la deja en 1. En la ficha, siempre 1.
@export var potencia: float = 1.0
@export var potencia_coste: float = 1.0
# COMO SE LLAMA SU GOLPE en la ficha de los nodos de su arbol ("de cada tajo", "del salto"): «Daño del salto: 70 % -> 77 %».
# Vacio = «de cada golpe».
@export var golpe_txt: String = ""
# --- LO QUE TOCAN LOS NODOS DE LOS ARBOLES (24/11; memoria empezar-habilidades-24-11) ---
# x la probabilidad base de los estados que le pone al ENEMIGO (Mil cortes de la Rafaga, Herida abierta de la Puñalada).
@export var efectos_prob_mult: float = 1.0
# CARGAS DE MAS por cada estado que le pone al enemigo, y CADA CARGA CON SU TIRADA (Arteria de la Puñalada: 2 cargas, cada
# una con su 90 %). Con 0 va como siempre: una tirada y entran todas sus cargas o ninguna.
@export var efectos_cargas_extra: int = 0
# LOS QUE CAEN A MITAD (Tajos que persiguen): por cada enemigo que tumba esta habilidad, los golpes que le quedan pegan
# este % de MAS (multiplica la habilidad entera), hasta bonus_por_baja_max bajas.
@export var bonus_por_baja: float = 0.0
@export var bonus_por_baja_max: int = 3
# EL REMATE (Remate de la Rafaga): el ULTIMO golpe pega x remate_mult a quien lleve el estado remate_estado (-1 = nada).
@export var remate_estado: int = -1
@export var remate_mult: float = 1.0
# HASTA EL MANGO (Puñalada): sus golpes CRITICOS pegan x esto (multiplica, sobre el critico de siempre).
@export var crit_dano_mult: float = 1.0
# ASESINATO (Puñalada): + este % de daño a enemigos por debajo de vida_baja_umbral de su vida maxima.
@export var bonus_vida_baja: float = 0.0
@export var vida_baja_umbral: float = 0.3
# DESANGRAR (Puñalada): si el golpe le entra y ya lleva este estado (un daño por turno), le inflige YA todo lo que le
# quedaba por hacer (cada carga: su daño por turno x sus turnos) y se lo quita. -1 = nada.
@export var detona_estado: int = -1
# EJECUCION (Puñalada): si derriba a alguien, se recarga al instante (el enfriamiento vuelve a 0).
@export var recarga_al_matar: bool = false
# --- DESAPARECER (24/11, su arbol) ---
# SOMBRA LARGA: turnos de mas de los estados que se pone quien la usa (el Sigilo).
@export var efectos_turnos_extra: int = 0
# Lo que trae su Sigilo mientras dure (Combatant.sigilo_extra): PIES EN LA NIEBLA (esquiva), RECARGA EN LAS SOMBRAS (% de
# la energia maxima al empezar cada turno oculto) y SALIR DE LAS SOMBRAS (el primer ataque oculto pega este % de mas).
@export var sigilo_esquiva: float = 0.0
@export var sigilo_energia: float = 0.0
@export var sigilo_golpe: float = 0.0
# DESVIO: los enemigos te olvidan (tu amenaza en sus tablas, a 0) y buscan a otro.
@export var desvia_amenaza: bool = false
# HUMO PARA TODOS: los aliados que pilla su huella tambien quedan en Sigilo estos turnos (0 = nadie).
@export var oculta_aliados_turnos: int = 0
# HUMO ESPESO: deja la nube en el suelo estos turnos (solo en el mapa); el enemigo que empieza su turno dentro se lleva
# nube_estado (la Ceguera) con nube_prob.
@export var nube_turnos: int = 0
@export var nube_estado: int = -1
@export var nube_prob: float = 0.0
# ESCABULLIRSE: tras usarla, quien la usa se mueve hasta esto (solo en el mapa) hacia el sitio de un SEGUNDO clic al
# lanzarla (combat_tactico: _eligiendo_retirada, apunte_mueve, pedir_escabullirse).
@export var se_mueve: float = 0.0
# --- FILO EMPONZOÑADO (24/11, su arbol): lo que lleva la imbuicion que pone (Combatant.imbue_*) ---
@export var imbue_fuerza: float = 1.0        # x la fuerza del veneno (su "daño": la potencia de los nodos va aqui)
@export var imbue_peldano: int = 0           # DOSIS CARGADAS: la escalera de dosis, como la de un arma de mas tier
@export var imbue_comparte_usos: int = 0     # COMPARTIR EL FRASCO: el aliado mas cercano tambien, con estos ataques
@export var imbue_acido: float = 0.0         # ACIDO: cada golpe impregnado que acierta, -esto de defensa (hasta 3, 3 turnos)
@export var imbue_con_sangre: float = 0.0    # PONZOÑA Y SANGRE: envenenado y sangrando, los dos hacen este % de mas
@export var imbue_revienta: bool = false     # TOXINA QUE REVIENTA: al tope de dosis, todo lo que le quedaba de golpe
@export var imbue_senal: float = 0.0         # SEÑAL DEL VENENO: golpe a un envenenado, este % de tu energia maxima
# --- OPORTUNISTA (24/11, su arbol): cambian el estado Oportunista que se pone (0 = lo del catalogo) ---
@export var oport_usos: int = 0              # MAS HUECOS / ENTRAR A FONDO: entradas que tiene
@export var oport_seguimiento: float = 0.0   # ENTRAR A FONDO: el seguimiento, en fraccion de un basico
@export var oport_alcance: float = 0.0       # OJO DE HALCON: hasta donde entra (px en el mapa)
@export var oport_cadena: int = 0            # CRITICO EN CADENA: cada seguimiento que critea, +1 entrada (hasta esto)
@export var oport_oculto: int = 0            # SIN DEJAR RASTRO: tras cada seguimiento, Sigilo estos turnos
@export var oport_energia: float = 0.0       # APROVECHADO: cada seguimiento repone este % de la energia maxima
@export var oport_dual_entero: bool = false  # ENTRAR LOS DOS: con dos armas, el 2o golpe del seguimiento pega entero
# DESEQUILIBRAR (Oportunista) y cualquier otra: el golpe que acierta deja este estado (-1 = nada) con su prob y turnos.
@export var estado_golpe: int = -1
@export var estado_golpe_prob: float = 1.0
@export var estado_golpe_turnos: int = 1
# --- ESTOCADA PENETRANTE (25/11, su arbol) ---
# ENSARTAR: en su linea, cada enemigo detras del primero (por cercania a quien la usa) recibe esto de daño MAS que el
# anterior (0,15: el 2o +15 %, el 3o +30 %...). Solo el daño: la probabilidad de sus estados no sube.
@export var bonus_tras_primero: float = 0.0
# HERIDA QUE SE ABRE: los estados que causa a los ENEMIGOS duran estos turnos de mas (efectos_turnos_extra es para los
# que se pone quien la usa).
@export var efectos_turnos_enemigo: int = 0
# DESEQUILIBRIO: si un golpe es critico, echa atras en la barra de turno a quien lo recibe (CombatPantalla.echar_atras).
@export var retrasa_si_critico: bool = false
# ESTOCADA DOBLE: los golpes despues del primero pegan x esto (0,5 = la segunda punzada a la mitad).
@export var golpe_siguiente_mult: float = 1.0
# --- EN GUARDIA (25/11, su arbol): lo que lleva la postura (Combatant.guardia_*, se quita en salir_de_guardia) ---
# La CAPA de esquiva de la guardia es evasion_bonus (la sube cada nivel) + esto (GUARDIA ALTA).
@export var guardia_capa_extra: float = 0.0
@export var guardia_todos_lados: bool = false   # OJOS EN LA ESPALDA: la guardia cubre tambien por los lados y la espalda
@export var guardia_reto: bool = false          # RETO: al ponerte en guardia, los enemigos de cerca van a por ti
@export var guardia_contra_critico: bool = false  # RIPOSTE PERFECTO: la contra siempre critea
@export var guardia_paso: float = 0.0           # SALIR AL PASO: hasta esto (px) hacia el que no llegas, para devolversela
@export var guardia_respiro: float = 0.0        # RESPIRO: cada golpe esquivado en guardia, este % de tu energia maxima
@export var guardia_paciencia: bool = false     # PACIENCIA: cada golpe esquivado en guardia, una carga de Al acecho
@export var guardia_no_cae: bool = false        # GUARDIA QUE NO CAE: al salir, la mitad de su capa 1 turno (Esquivo)
# Al USAR la habilidad (la postura), te quita tus efectos de mas velocidad (el jefe: para que la guardia dure de verdad).
@export var guardia_quita_prisa: bool = false
# --- PASO LIGERO (25/11, su arbol) ---
# AL COSTADO: la estocada pega este % de mas si le entra de lado o por la espalda (fuera de su frente; solo en el mapa).
@export var extra_costado: float = 0.0
# PASAR CORTANDO: a los que cruzas con el paso (sin contar al de la estocada), un corte de este % (0 = nada).
@export var corte_al_pasar: float = 0.0
# ENCADENAR: tu SIGUIENTE habilidad cuesta este % menos de energia (Combatant.descuento_hab).
@export var descuento_siguiente: float = 0.0
# PASO QUE DESPISTA: al acabar, tu amenaza en la tabla de cada enemigo x esto (0,5 = la mitad). 1 = nada.
@export var amenaza_tras_usar: float = 1.0
# PASO DE GUARDIA: si no le entra a nadie, entras en guardia (la de tu En guardia) SIN frenar tu barra ni quitarte la prisa.
@export var guardia_si_no_golpea: bool = false
# --- PUNZADA AL NERVIO (25/11, su arbol) ---
# TEMBLOR: el Debil que pone baja ademas la probabilidad de critico de quien lo lleva en esto (0,1 = -10 puntos).
@export var debil_quita_critico: float = 0.0
# CLAVADO: si tras el golpe el enemigo queda Lento, esta probabilidad base de Enraizado 1 turno.
@export var enraiza_si_lento: float = 0.0
# CADENA NERVIOSA: salta al enemigo mas cercano al primero (hasta CombatTactico.CADENA_RADIO), con esta escala de daño (y
# la probabilidad de sus estados con ella, como un secundario). 0 = no salta.
@export var salto_cadena: float = 0.0
# SOBRE LO TOCADO: este % de mas a quien ya este Debil o Lento.
@export var extra_si_tocado: float = 0.0
# LEÑA AL CAIDO: la fuerza del estado_golpe (como StatusApplication.mult; 0 = la del catalogo). La Marca, x1,10.
@export var estado_golpe_mult: float = 0.0
# --- AVANCE CUBIERTO (26/11, estoque + rodela, su arbol) ---
# PESO DE LA CARRERA: los golpes de ARMA pegan hasta este % de mas, segun lo que hayas corrido de la linea (entera = todo).
@export var carga_peso_max: float = 0.0
# ABRIRLE LA GUARDIA: al que le entra un golpe de ESCUDO, los de arma que le sigan son criticos seguro.
@export var escudo_abre_critico: bool = false
# RETO: al que le entra, va solo a por ti estos turnos tuyos (te deja provocandole a EL; Combatant.provocar_turnos).
@export var reto_turnos: int = 0
# ESCUDO QUE DEVUELVE: hasta tu siguiente turno, tu escudo devuelve el golpe que paras con esta probabilidad de mas.
@export var escudo_contra_extra: float = 0.0
# LLEGAR CUBIERTO: la guardia que te deja (bloqueo_turnos) te dura estos turnos tuyos de mas.
@export var guardia_turnos_extra: int = 0
# --- LA FUERZA Y LA PROBABILIDAD DE CADA ESTADO, por nodo (25/11: Presteza mayor, Nervio del brazo/pierna, Pulso firme).
# Estado (StatusEffects.Id) -> valor, por encima de lo que diga su StatusApplication (mult = el nivel del estado de stat,
# como StatusApplication.mult; prob = la probabilidad base). Los nodos los juntan con "add" (Mejoras mezcla diccionarios).
@export var efectos_mult_de: Dictionary = {}
@export var efectos_prob_de: Dictionary = {}
# --- COMPARTIDAS DEL ESTOQUE (25/11: Fintas, Danza de acero, Paso ligero...) ---
# BUSCAR EL HUECO / COMPAS: cada golpe pega esto MAS que el anterior (0,1: el 2o +10 %, el 3o +20 %...).
@export var golpe_creciente: float = 0.0
# ULTIMA ESTOCADA / REMATE DEL BAILE: el ULTIMO golpe pega x esto (a quien sea; Remate de la Rafaga pide un estado).
@export var ultimo_golpe_mult: float = 1.0
# ACOSO (Fintas): con UN solo enemigo en la huella, estos golpes de mas.
@export var golpes_si_uno: int = 0
# NINGUNO SE LIBRA (Fintas): por lo menos un golpe a cada uno de los que pilla (golpes = max(golpes, enemigos)).
@export var golpe_a_cada_uno: bool = false
# FINTA ENGAÑOSA: estado_golpe solo al PRINCIPAL (al primero), no a cada uno que toca.
@export var estado_golpe_solo_principal: bool = false
# HERIDA EN CRUZ (Danza de acero): al ULTIMO que golpea (si sigue en pie) este estado estos turnos (-1 = nada).
@export var estado_al_ultimo: int = -1
@export var estado_al_ultimo_turnos: int = 2
# SIN GUARDIA (Danza de acero): a los que les entra, se les quita la guardia, el Defender y el Baluarte.
@export var quita_guardia: bool = false
# LA ENERGIA que devuelve, en % de la maxima de quien la usa: RESPIRACION (por cada golpe critico), BAILE QUE ALIMENTA
# (por cada enemigo distinto al que le entra) y RECOBRAR ALIENTO (si no le entra a nadie).
@export var energia_por_critico: float = 0.0
@export var energia_por_enemigo: float = 0.0
@export var energia_sin_golpe: float = 0.0
# BAILAR ESQUIVANDO / ESQUIVA EN EL PASO: al acabar, una CAPA de esquiva de esto (segunda tirada si el golpe pasa tu
# esquiva normal, como la de En guardia) estos turnos: el estado Esquivo (Combatant.capas_esquiva).
@export var capa_esquiva: float = 0.0
@export var capa_esquiva_turnos: int = 1
# ENTRAR BAILANDO (Rafaga): antes de golpear se acerca hasta esto hacia donde apunta, y su huella sale de alli (solo en
# el mapa; combat_tactico.pies_tras_acercarse / pedir_acercarse).
@export var acercarse: float = 0.0
# true  -> se tiran en CADA golpe que acierta (Ráfaga: cada tajo 40% de sangrado ->
#          mas golpes = mas sangrado, cada hit con su tirada, mas realista).
# false -> UNA sola tirada tras la habilidad si conecto algo (golpe de escudo: 1 stun).
@export var efectos_por_golpe: bool = false

# Activa la GUARDIA (Defender) durante N turnos tras usarla (golpe de escudo).
@export var bloqueo_turnos: int = 0

# MANÁ FIJO que RECUPERA al usarla (0 = ninguno). Una habilidad de PURA UTILIDAD (sin
# daño) se marca con dano_mult = 0: no golpea, solo su efecto.
@export var mana_gain: float = 0.0
# Y en % del mana MAXIMO, una vez por uso si algun golpe CONECTA (23/11: el Bastonazo, 0,08, el doble que el basico del
# baston: lo pagas con energia).
@export var mana_gain_pct: float = 0.0

# CONVERSION energía->maná (LEGACY, ya no lo usa Canalizar; reemplazado por foco_cargas): si
# > 0, la habilidad GASTA TODA la energía y da 1 de maná por cada 'energia_a_mana'. Se deja
# por si alguna habilidad futura quiere el modelo de conversion directa.
@export var energia_a_mana: float = 0.0

# FOCO ARCANO (Canalización reworkeada, KAN-56/57): si > 0, la habilidad NO da maná; concede
# N CARGAS de Foco arcano (Combatant.foco_cargas). Cada hechizo ofensivo gasta 1 carga y pega
# +30%. No se puede volver a usar mientras te queden cargas (recuperacion por hechizos, no
# por turnos). Utilitaria: dano_mult = 0. Coste alto de energia (es una jugada de pico).
@export var foco_cargas: int = 0

# ATAQUE DE CARGA (telegrafiado): N > 0 = la habilidad NO pega el turno que la anuncia;
# se "carga" durante N turnos (el enemigo pierde esos turnos preparandola) y se dispara al
# terminar. Te da margen para defender, curarte o interrumpirla ATURDIENDO al enemigo (un
# stun cancela la carga). Pensada para golpes MUY fuertes (dano_mult alto). Solo la usan los
# enemigos de momento (el jugador no tiene cargas). 0 = ataque instantaneo normal.
@export var carga_turnos: int = 0

# INVOCACION (Rey Slime, jefe piso 6): habilidad que mete slimes VIVOS en el combate en curso.
# invoca_cantidad > 0 la marca como "de invocacion" (como dano_mult marca las de daño); es de pura
# utilidad (dano_mult = 0). invoca_pool = EnemyData entre los que elige al azar cada slime que saca.
# Suele ir telegrafiada (carga_turnos) para dar contrajuego. Ver combat.gd._invocar_slime.
@export var invoca_pool: Array = []      # Array[EnemyData]; vacio = no invoca nada
@export var invoca_cantidad: int = 0     # cuantos slimes por lanzamiento (el Rey saca 2)
# LA LLAMADA (31/10, los mutantes del rey rata): esta habilidad (el Chillido) trae a la camada SI quien la usa tiene
# Llamada (Combatant.llamada_max > 0; el rey rata normal no). Ver CombatEnemigos._llamada.
@export var llama_camada: bool = false
# LOS COLMILLOS QUE SE ROMPEN (31/10, la Cornada de cristal de los mutantes del jabali): al usarla, a quien la usa se
# le parten los colmillos (StatusEffects.Id.COLMILLOS_ROTOS, 'rompe_colmillos' turnos suyos) y, mientras los tenga
# rotos, en su lugar usa 'rota' (la de los muñones). Ver CombatEnemigos._enemy_use_ability.
@export var rompe_colmillos: int = 0
@export var rota: AbilityData = null

# --- HUELLA: para las de CUERPO QUE CAE ------------------------------------------------------
# El area normal es "el objetivo y sus vecinos". Para un bicho que se deja caer eso no vale: lo que
# manda es DONDE ATERRIZA y CUANTO MIDE. Cayendo pegado al borde de la fila tapa a tres (media
# huella se pierde fuera); cayendo centrado los tapa a los cuatro.
#
# area_centrada = la huella no cae sobre el objetivo, sino CENTRADA en el grupo vivo. Es lo del
# Aplastamiento del Rey: es tan grande que da igual a quien mirase, cae en medio y los pilla a
# todos. El Reventon del slime comun NO la lleva: es pequeño y cae donde cae.
@export var area_centrada: bool = false

# COMO SE REPARTE el daño segun A CUANTOS alcanza. Una entrada por numero de alcanzados: la de
# indice 0 es para cuando alcanza a 1, la de indice 1 para 2, etc. Cada entrada es un Array de
# fracciones, de MAS a MENOS, que se reparten por cercania al centro de la huella.
#
# Existe porque "100% al principal y 50% a todos los demas" hace pequeño a un bicho enorme: si el
# Rey te cae encima a ti y a otro, a los dos os tiene que aplastar igual. La tabla del Rey es
# [[1.0], [1.0, 1.0], [1.0, 0.8, 0.8], [1.0, 1.0, 0.5, 0.5]]: con dos, los dos al 100%; con cuatro,
# el 100% para los dos que le caen mas cerca.
#
# VACIO = se comporta como siempre (area_secundario para todos los que no son el principal), asi que
# ninguna otra habilidad del juego cambia por esto.
@export var area_escalas: Array = []


# --- COMO SE VE (solo presentacion; no toca una sola cuenta) ----------------------------------
# QUE DIBUJO lleva esta habilidad. -1 = lo de siempre (la tarjeta embiste, CombatFX.Estilo.MELEE);
# cualquier otro valor es un CombatFX.Estilo.
#
# Existe porque TODOS los ataques enemigos se veian igual: daba lo mismo que te escupieran acido,
# que te cayera un slime encima o que te barriera una marea, era el mismo empujon de tarjeta. La
# maquinaria de dibujos ya estaba montada (CapaHechizos) pero solo la usaban los hechizos del
# jugador; esto es lo que deja que un bicho pida la suya.
# EL COLOR no se pide aqui: lo decide combat.gd._color_golpe. Manda el elemento si lo hay y, si no,
# el color del propio bicho. Con eso los slimes ya atacan de su color (ninguno lleva elemento salvo
# el de fuego, que es naranja de todas formas) sin necesidad de un campo aparte -- y sobre todo sin
# tener que mandarlo por red, porque el espejo deriva el mismo color de su propio Combatant.
@export var fx_estilo: int = -1

# QUE HACE EL CUERPO del que ataca. Hermano de fx_estilo: aquel dice que se DIBUJA, este dice como se
# MUEVE el bicho. Son cosas distintas y hasta ahora solo existia la primera, asi que un mordisco, una
# embestida y un aplastamiento eran el mismo empujoncito de 26 px.
#
#   AUTO      lo de siempre: un paso adelante si el estilo es cuerpo a cuerpo, y quieto si no. Es el
#             valor por defecto A PROPOSITO -- asi las ~70 habilidades que ya existen y todo el
#             camino del jugador siguen viendose exactamente igual sin tocar un solo .tres.
#   QUIETO    no se mueve nada (lo que sale de el ya viaja solo: escupitajos, auras).
#   EN_SITIO  hace el gesto de atacar, UNA VEZ POR GOLPE, pero sin ir a por nadie. Es lo que pide el
#             Frenesi de dentelladas: muerde seis veces desde su puesto. Con el paso de siempre se
#             teletransportaba a cada victima, que es lo que se veia raro.
#   PASO      el empujon de 26 px hacia la victima.
#   VIAJE     va HASTA la victima y vuelve (la Embestida del jabali).
#   SALTO     coge aire, se infla hasta cubrir a los que va a golpear, salta y cae encima
#             (el Aplastamiento del Rey Slime).
#   ATRAVESAR reservado: cruzar la fila golpeando a varios de paso (la Embestida acorazada, que
#             todavia no tiene sprite). Declarado para que el diseño lo admita; sin implementar.
#
# Los gestos que SUSTITUYEN al dibujo de su estilo son SALTO y ATRAVESAR: ahi lo que te golpea es el
# cuerpo, asi que pintar ademas el efecto seria contar el mismo golpe dos veces. Los demas conviven
# con el suyo -- los mordiscos del Frenesi siguen saliendo igual.
enum Gesto { AUTO = -1, QUIETO, EN_SITIO, PASO, VIAJE, SALTO, ATRAVESAR }
@export var gesto: int = Gesto.AUTO

# QUE ANIMACION del bicho se reproduce al hacerlo. Vacio = "embestida", que es el gesto de atacar
# que tienen todos. Se pide por nombre porque hay habilidades que necesitan la SUYA: el Rey Slime
# coge aire antes de saltar ("inflar"), el trent clava los brazos en el suelo antes de que broten
# las raices ("raices"). El nombre es el de la animacion en el generador del bicho, sin la
# direccion (el "_0" lo pone el combate segun hacia donde mire).
#
# Si el bicho no tiene esa animacion se cae a su embestida, asi que pedir una que no existe no
# rompe nada: simplemente ataca como siempre.
#
# EN CADENA (28/09, los slimes en el mapa): "hinchado>aplaston>deshincharse". La primera se ajusta al
# gesto; las demas salen detras, cada una a su ritmo. Va en el mismo nombre para que viaje por red tal
# cual en el paquete de impactos. En la fila (la tarjeta) solo cuenta la primera.
@export var fx_anim: StringName = &""
# LO QUE HACE SU CUERPO MIENTRAS CARGA (solo en el mapa): cadena como la de arriba y la ULTIMA se
# queda en bucle hasta que suelta ("inflar>hinchado" en el Reventon). Vacio = nada, como siempre.
# Lo lee el combate mirando 'charging', que ya viaja al espejo: no hace falta mandar nada mas.
@export var fx_anim_carga: StringName = &""
# Y si le INTERRUMPEN la carga (aturdido): el Reventon se deshincha. Vacio = vuelve a reposo.
@export var fx_anim_interrumpe: StringName = &""
# EL DIBUJO EN EL MAPA si es otro que el de la fila (-1 = el mismo, fx_estilo). Los slimes (28/09): en la fila el
# escupitajo es su ESCUPITAJO de tarjeta; en el mapa, SLIME_ESCUPE sobre el cuerpo. Solo lo lee el mapa.
@export var fx_estilo_mapa: int = -1

# QUE TE ECHAS TU ENCIMA, aparte de lo que le hagas al enemigo. -1 = nada.
#
# Existe porque hay habilidades que hacen LAS DOS COSAS: el Voto de guardia pega un tajo Y te deja
# en guardia. Con un solo campo no salia: el dibujo de una habilidad que hace daño se pinta sobre el
# OBJETIVO, asi que poniendole aqui la postura defensiva, el escudo aparecia sobre el bicho -- como
# si le estuvieras pegando con el escudo en vez de cubrirte tu.
#
# La lista CombatFX.SOBRE_SI_MISMO no basta: solo la mira _fx_adorno, que es la ruta de las que NO
# hacen daño. Estas si lo hacen.
#
# El dibujo sale al FINAL de la accion (ver _fx_sobre_mi en combat.gd), que es el orden que se lee:
# primero pegas, y despues te cubres.
@export var fx_sobre_mi: int = -1

# COOLDOWN (KAN-57): turnos que debes ESPERAR para volver a usarla. 0 = sin cooldown
# (usable cada turno). N = tras usarla, no vuelve a estar disponible hasta N turnos
# tuyos despues. El estado (turnos restantes) vive en el Combatant, no aqui (recurso
# compartido). Junto al coste, convierte las habilidades en jugadas de COMPROMISO.
@export var cooldown: int = 0

# true -> tecnica de ARMA + ESCUDO: solo aparece en el loadout si llevas un ESCUDO
# equipado (Game filtra estas si equipped_off no es ShieldData). Ej: la espada larga,
# que se combina a menudo con escudo, trae "Guardia rota" (bash + tajo + guardia).
@export var requiere_escudo: bool = false

# true -> tecnica de UNA MANO LIBRE: solo aparece si la mano secundaria esta VACIA o lleva
# una VARITA (WandData, que no pesa ni estorba). Inverso de requiere_escudo. Ej: el estoque,
# que trae "En guardia" (postura de contraataque de duelo). Game la filtra en el loadout.
@export var requiere_off_libre: bool = false
# QUE ESCUDOS VALEN (26/11, el jefe: "estoque con rodela; la espada larga, mediano; la maza, mediano y grande"), por
# ShieldData.Tamano. Con requiere_escudo: solo con estos (vacio = cualquiera). Con requiere_off_libre: con la mano libre
# O con uno de estos (En guardia, tambien con rodela). Lo mira Game.pool_habilidades.
@export var escudos_tamanos: Array = []
# LAS QUE TAPA (26/11): si esta sale, estas no (En guardia con rodela se come la Postura de rodela: serian dos posturas
# casi iguales; la suya ya hace lo de la rodela, ver CombatHabilidades.poner_guardia).
@export var sustituye: Array = []


# ¿Vale con este escudo? (para requiere_escudo / requiere_off_libre; ver escudos_tamanos)
func vale_con_escudo(sh: ShieldData) -> bool:
	if sh == null:
		return false
	if escudos_tamanos.is_empty():
		return requiere_escudo
	return escudos_tamanos.has(int(sh.tamano))

# PROVOCACION (taunt de escudo): N > 0 = al usarla, quien la lanza queda PROVOCANDO N turnos suyos.
# Mientras dure, los enemigos TIENDEN a pegarle mas a el (pesa mas en su sorteo de objetivo), pero
# NO todos los golpes van a el: solo inclina la balanza. De pura utilidad (dano_mult = 0). El estado
# (turnos restantes) vive en el Combatant (recurso compartido). Ver combat.gd._elegir_objetivo_enemigo.
@export var provoca_turnos: int = 0

# --- POSTURA DE CONTRAATAQUE (estoque, "En guardia"): dura hasta tu proxima accion, como
# el Defender. Bajas tu velocidad a cambio de mas reduccion de daño (rama defending) y mas
# evasion; cada golpe que ESQUIVAS lo devuelves (riposte). Marca dano_mult = 0 (utilitaria). ---
@export var postura_contraataque: bool = false
# Multiplicador de velocidad mientras aguantas en guardia (< 1.0 = mas lento). El estoque
# es rapido de base, asi que la postura pega un frenazo fuerte (0.5 = mitad de velocidad).
@export var guardia_spd_mult: float = 0.5
# Esquiva EXTRA que da la habilidad (se suma a tu esquiva). Si > 0, rompe el tope normal
# de esquiva (0.35 -> 0.65). Generico: cualquier habilidad/buff de esquiva puede usarlo.
@export var evasion_bonus: float = 0.0
# Daño del contraataque (riposte) respecto a un básico (1.0 = golpe normal).
@export var contra_mult: float = 1.0
# Mientras dure la postura, lo que devuelves (al esquivar Y al parar) es un ESCUDAZO: pega con tu Defensa
# y se ve como un golpe de escudo. La Postura de rodela (25/09): "que devuelva los escudazos y ya".
@export var contra_con_escudo: bool = false

# --- COBERTURA REAL (escudo torre, "Muro"): te plantas DELANTE de un aliado N turnos suyos y los
# golpes que el sorteo le manda a el te llegan a TI. Es lo unico del juego que MUEVE un golpe de
# un objetivo a otro; la Provocacion solo inclina la balanza del sorteo.
# El golpe se resuelve entero contra el que cubre, asi que su defensa, su defend_defense y su
# bloqueo entran solos: te tapa con SU escudo, sin tocar StatsMath.
# Pide objetivo_aliado = ALIADO (a alguien hay que ponerse delante). El estado (a quien y cuantos
# turnos) vive en el Combatant, como provocar_turnos. Ver combat.gd._elegir_objetivo_enemigo.
@export var protege_turnos: int = 0

# ¿Se puede usar sobre UNO MISMO? No, si lo que hace es ponerse delante de otro: cubrirte a ti mismo
# no mitiga nada y te cobraba la energia igual (playtest del 11/09/2026, el Muro). Sale del campo y no
# de una bandera aparte para que ninguna habilidad nueva de cobertura se olvide de marcarla.
func excluye_al_lanzador() -> bool:
	return protege_turnos > 0 or sigue_al_aliado   # ni cubrirte ni escoltarte a ti mismo


# Nº de impactos (aleatorio dentro del rango; dual usa su rango si lo tiene). 'enemigos' = nº de
# rivales VIVOS: si la habilidad escala por multitud (golpes_extra_por_enemigo), suma golpes
# extra por cada enemigo adicional al primero, con tope (golpes_extra_max).
func num_golpes(manos: int, enemigos: int = 1) -> int:
	var base: int
	if manos >= 2 and golpes_dual_max > 0:
		base = randi_range(maxi(1, golpes_dual_min), maxi(golpes_dual_min, golpes_dual_max))
	else:
		base = randi_range(maxi(1, golpes_min), maxi(golpes_min, golpes_max))
	var por: float = golpes_extra_por_enemigo
	if manos >= 2 and golpes_extra_por_enemigo_dual > 0.0:
		por = golpes_extra_por_enemigo_dual
	if por > 0.0 and enemigos > 1:
		base += mini(golpes_extra_max, int(floor(por * float(enemigos - 1))))
	return base

# Multiplicador del golpe 'i' (0-indexado) segun el loadout. Los primeros golpes_max (el
# tope del rango a UNA mano) van al 100%; los que vengan detras son los que pone la segunda
# arma, y valen dual_golpe_mult. Con 1 mano siempre 1.0.
func mult_golpe(i: int, manos: int) -> float:
	if not mults_golpe.is_empty():
		return float(mults_golpe[mini(i, mults_golpe.size() - 1)])
	if manos >= 2 and golpes_dual_max > 0 and i >= golpes_max:
		return dual_golpe_mult
	return 1.0

# PLAN de golpes: para cada golpe (0..total-1) devuelve {hand, mult}. 'hand' = índice DENTRO de la
# lista de manos que aporta la habilidad (0 = principal/arma, 1 = segunda mano); 'mult' = su
# multiplicador de daño. INTERCALA las manos del dual (principal, segunda, principal, segunda...) en
# vez de agrupar todos los flojos al final: el jugador ve "der izq der izq", no dos fuertes y luego
# dos flojos. El NÚMERO de golpes de cada mano no cambia (mismo daño total), solo el orden. Para
# arma+escudo (mults_golpe) va por índice con una sola mano; con una mano normal, todo al 100%.
func plan_golpes(total: int, manos: int) -> Array:
	var plan: Array = []
	if not mults_golpe.is_empty():
		for i in total:
			plan.append({"hand": 0, "mult": float(mults_golpe[mini(i, mults_golpe.size() - 1)])})
		return plan
	if manos >= 2 and golpes_dual_max > 0:
		var p: int = mini(golpes_max, total)   # golpes de mano PRINCIPAL (100%)
		var s: int = total - p                 # los que pone la SEGUNDA mano (dual_golpe_mult)
		var quiere_principal: bool = true      # se empieza por la principal
		while plan.size() < total:
			if quiere_principal and p > 0:
				plan.append({"hand": 0, "mult": 1.0}); p -= 1
			elif not quiere_principal and s > 0:
				plan.append({"hand": 1, "mult": dual_golpe_mult}); s -= 1
			elif p > 0:                          # se acabó una: se vacía la otra en orden
				plan.append({"hand": 0, "mult": 1.0}); p -= 1
			else:
				plan.append({"hand": 1, "mult": dual_golpe_mult}); s -= 1
			quiere_principal = not quiere_principal
		return plan
	for i in total:
		plan.append({"hand": 0, "mult": 1.0})
	return plan

# Coste de energia segun el loadout (dual gasta mas si tiene coste propio).
# (25/11) LA FUERZA Y LA PROBABILIDAD DE UN ESTADO DE ESTA HABILIDAD, con lo que le hayan puesto los nodos (efectos_*_de).
func mult_de_efecto(a) -> float:
	return float(efectos_mult_de.get(int(a.estado), a.mult)) if a != null else 0.0


func prob_de_efecto(a) -> float:
	return float(efectos_prob_de.get(int(a.estado), a.prob)) if a != null else 0.0


func coste(manos: int) -> float:
	if manos >= 2 and coste_energia_dual > 0.0:
		return coste_energia_dual
	return coste_energia


# Numero compacto: "1.4", "2", "0.75" (sin ceros de cola sobrantes).
func _num(x: float) -> String:
	var s: String = "%.2f" % x
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s

# Texto del ÁREA de las que aun se resuelven como en la FILA (sin huella en el mapa: forma_apunte o forma < 0). "" si no
# golpea en area. 'rec' = como se llama a quien la recibe ("enemigo" / "objetivo").
func _area_txt(rec: String = "enemigo") -> String:
	match area_modo:
		AreaModo.SPLASH:
			var alcance: String = "todos los %ss" % rec if area_max >= 99 else "hasta %d %ss" % [area_max, rec]
			var base: String = "Salpica a %s: los adyacentes reciben un %s de ese daño." % [
				alcance, _pct_txt(area_secundario)]
			if area_secundario_decay > 0.0:
				return base + " Ese daño se reduce en un %s por cada %s de más." % [_pct_txt(area_secundario_decay), rec]
			return base
		AreaModo.BARRIDO:
			var alcance2: String = "todos los %ss" % rec if area_max >= 99 else "hasta %d %ss" % [area_max, rec]
			return "Alcanza a %s a la vez; el daño se reduce en un %s por cada %s de más." % [
				alcance2, _pct_txt(1.0 - area_falloff), rec]
	return ""


# ------------------------------------------------------------
#  LA FICHA AL ESTILO HSR (17/11, repaso de frases; docs/guia_textos.md). El daño sale de la STAT (StatsMath.damage es
#  proporcional al Ataque: dano_mult = «un X % del Ataque»), no «del daño de un ataque basico». Las de los personajes:
#  «del Ataque de quien la usa ... a un enemigo»; las de los enemigos: «de su Ataque ... a un objetivo». La FORMA (la
#  huella del mapa) en su propia linea, en CASILLAS (DungeonGenerator.CELDA = 32 px = el personaje).
# ------------------------------------------------------------
const CASILLA_PX := 32.0
# Los tamaños por defecto de CombatFormas (R_BASE, APERTURA_BARRIDO, PASO), repetidos aqui porque scripts/items no
# conoce la pantalla de combate (ver la cabecera de 'forma'). Los vigila tools/unitarias/test_resumen_habilidad.
const _R_BASE := 40.0
const _APERTURA_BASE := 110.0
const _PASO_RADIO := 28.0
const _NOMBRE_FORMA := ["", "círculo", "cono", "línea", "rectángulo"]
# «del círculo», «de la línea».
const _DEL_FORMA := ["", "del círculo", "del cono", "de la línea", "del rectángulo"]

# "media casilla", "1 casilla", "2,5 casillas" (redondeado a media casilla).
# LA FRASE DE UNA MEJORA (24/11, ficha del nodo del arbol): lo que cambia 'campo' de 'antes' a esta, para las mecanicas
# que no son un numero de la tabla del arbol (arbol_mejoras_ui.FILAS_ANTES_DESPUES). "" = no tiene frase propia.
func frase_mejora(campo: String, antes: AbilityData) -> String:
	if antes == null or not (campo in self) or get(campo) == antes.get(campo):
		return ""
	match campo:
		"infalible":
			return "Sus golpes ya no se pueden esquivar." if infalible else ""
		"efectos_prob_mult":
			var partes: Array = []
			for a in efectos:
				if a == null or int(a.estado) < 0 or not a.en_objetivo:
					continue
				var nom: String = str(StatusEffects.def(int(a.estado)).get("nombre", "?"))
				partes.append("Probabilidad base de causar %s%s: %s → %s" % [nom, " (solo con crítico)" if a.solo_crit else "",
					_pct_entero(float(a.prob) * antes.efectos_prob_mult), _pct_entero(float(a.prob) * efectos_prob_mult)])
			return "\n".join(PackedStringArray(partes))
		"crit_dano_mult":
			return "Daño de sus golpes críticos: aumenta en un %s (sobre el crítico de siempre)." % _pct_entero(crit_dano_mult - 1.0)
		"bonus_vida_baja":
			return "Contra enemigos con menos del %s de su vida máxima, inflige un %s más." % [
				_pct_entero(vida_baja_umbral), _pct_entero(bonus_vida_baja)]
		"detona_estado":
			if detona_estado < 0:
				return ""
			return "Si el enemigo ya tiene %s, le inflige de golpe todo el daño que le quedaba por hacer y se lo quita." % (
				str(StatusEffects.def(detona_estado).get("nombre", "?")))
		"recarga_al_matar":
			return "Si derriba a un enemigo, vuelve a estar lista al instante." if recarga_al_matar else ""
		"capa_esquiva", "capa_esquiva_turnos":
			if capa_esquiva <= 0.0:
				return ""
			return "Al acabar, de los golpes que te alcancen esquivas además un %s, %d turno%s." % [_pct_entero(capa_esquiva),
				capa_esquiva_turnos, "" if capa_esquiva_turnos == 1 else "s"]
		"guardia_capa_extra":
			return ("En guardia esquivas además un %s más de los golpes que te alcanzan." % _pct_entero(guardia_capa_extra)) \
				if guardia_capa_extra > 0.0 else ""
		"guardia_todos_lados":
			return "La guardia te cubre también por los lados y por la espalda." if guardia_todos_lados else ""
		"guardia_reto":
			return "Al ponerte en guardia, los enemigos de cerca van a por ti." if guardia_reto else ""
		"guardia_contra_critico":
			return "El golpe que devuelves al esquivar es siempre crítico." if guardia_contra_critico else ""
		"guardia_paso":
			return ("Si el que te ataca no está a tu alcance, das un paso de hasta %s hacia él para devolvérsela." \
				% casillas_txt(guardia_paso)) if guardia_paso > 0.0 else ""
		"guardia_respiro":
			return ("Cada golpe que esquivas en guardia te devuelve un %s de tu energía máxima." % _pct_entero(guardia_respiro)) \
				if guardia_respiro > 0.0 else ""
		"guardia_paciencia":
			return "Cada golpe que esquivas en guardia te deja Al acecho: tu siguiente ataque pega un 10 % más (hasta 3 veces)." \
				if guardia_paciencia else ""
		"guardia_no_cae":
			return "Al salir de la guardia, conservas la mitad de su esquiva un turno más." if guardia_no_cae else ""
		"guardia_spd_mult":
			return ("En guardia tu barra de turno va al %s (dura más: más golpes que devolver)." % _pct_entero(guardia_spd_mult)) \
				if guardia_spd_mult < 1.0 else ""
		"evasion_bonus":
			return ("De los golpes que te alcanzan en guardia, esquivas además: %s → %s." % [_pct_entero(antes.evasion_bonus),
				_pct_entero(evasion_bonus)]) if postura_contraataque else ""
		"golpe_creciente":
			return ("Cada golpe hace un %s más de daño que el anterior." % _pct_entero(golpe_creciente)) \
				if golpe_creciente > 0.0 else ""
		"ultimo_golpe_mult":
			return ("El último golpe hace x%s." % str(snappedf(ultimo_golpe_mult, 0.01)).replace(".", ",")) \
				if not is_equal_approx(ultimo_golpe_mult, 1.0) else ""
		"golpes_si_uno":
			return ("Si solo pilla a un enemigo, %d golpe%s más." % [golpes_si_uno, "" if golpes_si_uno == 1 else "s"]) \
				if golpes_si_uno > 0 else ""
		"golpe_a_cada_uno":
			return "Por lo menos un golpe a cada enemigo que pilla." if golpe_a_cada_uno else ""
		"estado_golpe_solo_principal":
			return "Ese estado, solo al primero al que golpea." if estado_golpe_solo_principal else ""
		"estado_al_ultimo", "estado_al_ultimo_turnos":
			if estado_al_ultimo < 0:
				return ""
			return "El último al que golpea queda %s %d turno%s." % [str(StatusEffects.def(estado_al_ultimo).get("nombre", "?")),
				estado_al_ultimo_turnos, "" if estado_al_ultimo_turnos == 1 else "s"]
		"quita_guardia":
			return "A los que golpea se les quita la guardia, el Defender y el Baluarte que tuvieran puestos." if quita_guardia else ""
		"energia_por_critico":
			return ("Cada golpe crítico te devuelve un %s de tu energía máxima." % _pct_entero(energia_por_critico)) \
				if energia_por_critico > 0.0 else ""
		"energia_por_enemigo":
			return ("Cada enemigo distinto al que golpea te devuelve un %s de tu energía máxima." % _pct_entero(energia_por_enemigo)) \
				if energia_por_enemigo > 0.0 else ""
		"energia_sin_golpe":
			return ("Si no golpea a nadie, te devuelve un %s de tu energía máxima." % _pct_entero(energia_sin_golpe)) \
				if energia_sin_golpe > 0.0 else ""
		"debil_quita_critico":
			return ("El Débil que causa también le quita %d puntos de probabilidad de crítico." % roundi(debil_quita_critico * 100.0)) 				if debil_quita_critico > 0.0 else ""
		"enraiza_si_lento":
			return ("Si el enemigo queda Lento, probabilidad base del %s de dejarlo Enraizado 1 turno." % _pct_entero(enraiza_si_lento)) 				if enraiza_si_lento > 0.0 else ""
		"salto_cadena":
			return ("Salta al enemigo más cercano al primero, con el %s del daño y de la probabilidad de sus estados." 				% _pct_entero(salto_cadena)) if salto_cadena > 0.0 else ""
		"extra_si_tocado":
			return ("Hace un %s más de daño a quien ya esté Débil o Lento." % _pct_entero(extra_si_tocado)) 				if extra_si_tocado > 0.0 else ""
		"extra_costado":
			return ("Si golpea de lado o por la espalda, hace un %s más de daño." % _pct_entero(extra_costado)) \
				if extra_costado > 0.0 else ""
		"corte_al_pasar":
			return ("A los enemigos que cruzas con el paso les haces un corte del %s del daño." % _pct_entero(corte_al_pasar)) \
				if corte_al_pasar > 0.0 else ""
		"descuento_siguiente":
			return ("Tu siguiente habilidad cuesta un %s menos de energía." % _pct_entero(descuento_siguiente)) \
				if descuento_siguiente > 0.0 else ""
		"amenaza_tras_usar":
			return ("Al acabar, los enemigos te tienen un %s menos de amenaza." % _pct_entero(1.0 - amenaza_tras_usar)) \
				if amenaza_tras_usar < 1.0 else ""
		"guardia_si_no_golpea":
			return "Si no golpea a nadie, entras en guardia (la de tu En guardia) sin que tu barra de turno vaya más lenta." \
				if guardia_si_no_golpea else ""
		"vuelve":
			return "Tras el paso y la estocada, vuelves a donde estabas." if vuelve else ""
		"efectos_mult_de":
			var fuerzas: Array = []
			for a in efectos:
				if a != null and efectos_mult_de.has(int(a.estado)):
					fuerzas.append("%s: %s → %s" % [str(StatusEffects.def(int(a.estado)).get("nombre", "?")),
						StatusEffects.efecto_legible(int(a.estado), antes.mult_de_efecto(a)),
						StatusEffects.efecto_legible(int(a.estado), mult_de_efecto(a))])
			return "\n".join(PackedStringArray(fuerzas))
		"efectos_prob_de":
			var probs: Array = []
			for a in efectos:
				if a != null and efectos_prob_de.has(int(a.estado)):
					probs.append("Probabilidad base de causar %s: %s → %s" % [str(StatusEffects.def(int(a.estado)).get("nombre", "?")),
						_pct_entero(antes.prob_de_efecto(a)), _pct_entero(prob_de_efecto(a))])
			return "\n".join(PackedStringArray(probs))
		"bonus_tras_primero":
			return ("En su línea, cada enemigo detrás del primero recibe un %s más de daño que el anterior." \
				% _pct_entero(bonus_tras_primero)) if bonus_tras_primero > 0.0 else ""
		"efectos_turnos_enemigo":
			return ("Los estados que causa duran %d turno%s más." % [efectos_turnos_enemigo,
				"" if efectos_turnos_enemigo == 1 else "s"]) if efectos_turnos_enemigo > 0 else ""
		"retrasa_si_critico":
			return "Si un golpe es crítico, echa atrás en la barra de turno a quien lo recibe." if retrasa_si_critico else ""
		"golpe_siguiente_mult":
			return ("Los golpes después del primero hacen el %s de su daño." % _pct_entero(golpe_siguiente_mult)) \
				if not is_equal_approx(golpe_siguiente_mult, 1.0) else ""
		"acercarse":
			return "Antes de golpear, quien la usa se acerca hasta %s hacia el objetivo." % casillas_txt(acercarse) \
				if acercarse > 0.0 else ""
		"efectos_turnos_extra":
			var propios: Array = []
			for a in efectos:
				if a != null and int(a.estado) >= 0 and not a.en_objetivo:
					propios.append(str(StatusEffects.def(int(a.estado)).get("nombre", "?")))
			return "%s dura %d turno%s más." % [("El " + " y el ".join(PackedStringArray(propios))) if not propios.is_empty() else "Lo que se pone",
				efectos_turnos_extra, "" if efectos_turnos_extra == 1 else "s"]
		"sigilo_esquiva":
			return "Mientras dura su Sigilo, quien la usa suma un %s a su probabilidad de esquivar." % _pct_entero(sigilo_esquiva)
		"sigilo_energia":
			return "Mientras dura su Sigilo, al empezar cada turno quien la usa recupera un %s de su energía máxima." % (
				_pct_entero(sigilo_energia))
		"sigilo_golpe":
			return "El primer ataque de quien la usa mientras dura su Sigilo inflige un %s más, y el Sigilo se acaba." % (
				_pct_entero(sigilo_golpe))
		"desvia_amenaza":
			return "Los enemigos olvidan a quien la usa y buscan otro objetivo." if desvia_amenaza else ""
		"oculta_aliados_turnos":
			return "Los aliados dentro de su alcance también reciben Sigilo durante %d turnos." % oculta_aliados_turnos \
				if oculta_aliados_turnos > 0 else ""
		"nube_turnos", "nube_estado", "nube_prob":
			if nube_turnos <= 0 or nube_estado < 0:
				return ""
			return "El humo se queda %d turnos; el enemigo que empiece su turno dentro tiene una probabilidad base del %s de quedar con %s." % [
				nube_turnos, _pct_entero(nube_prob), str(StatusEffects.def(nube_estado).get("nombre", "?"))]
		"imbue_peldano":
			return "Las dosis que mete y el tipo de veneno son los de un arma de %d tier%s más." % [
				imbue_peldano, "" if imbue_peldano == 1 else "s"] if imbue_peldano > 0 else ""
		"imbue_comparte_usos":
			return "También impregna el arma del aliado más cercano, durante %d ataques." % imbue_comparte_usos \
				if imbue_comparte_usos > 0 else ""
		"imbue_acido":
			return "Cada golpe impregnado que acierta reduce la Defensa del enemigo en un %s (hasta 3 veces, durante 3 turnos)." % (
				_pct_entero(imbue_acido))
		"imbue_con_sangre":
			return "Si el enemigo tiene a la vez veneno y Sangrado, los dos le hacen un %s más de daño." % _pct_entero(imbue_con_sangre)
		"imbue_revienta":
			return "Cuando el enemigo llega al tope de dosis, el veneno le inflige de golpe todo el daño que le quedaba y se le quita." \
				if imbue_revienta else ""
		"imbue_senal":
			return "Cada golpe a un enemigo que ya tiene veneno devuelve un %s de la energía máxima de quien la usa." % (
				_pct_entero(imbue_senal))
		"oport_usos":
			return "Veces que entra detrás: %d → %d" % [_oport_usos_de(antes), _oport_usos_de(self)]
		"oport_seguimiento":
			return "Cada vez que entra detrás inflige un %s del daño de su ataque básico (antes, un %s)." % [
				_pct_entero(oport_seguimiento), _pct_entero(_oport_pct_de(antes))]
		"oport_alcance":
			return "Entra detrás de enemigos hasta a %s (antes, %s)." % [casillas_txt(oport_alcance),
				casillas_txt(float(StatusEffects.def(StatusEffects.Id.OPORTUNISTA).get("alcance_mapa", 150.0)))]
		"oport_cadena":
			return "Cada vez que entra detrás con un crítico, gana una entrada más (hasta %d)." % oport_cadena
		"oport_oculto":
			return "Cada vez que entra detrás, queda con Sigilo durante %d turno%s." % [oport_oculto, "" if oport_oculto == 1 else "s"]
		"oport_energia":
			return "Cada vez que entra detrás, recupera un %s de su energía máxima." % _pct_entero(oport_energia)
		"oport_dual_entero":
			return "Con dos armas, el golpe de la segunda al entrar detrás inflige el daño entero." if oport_dual_entero else ""
		"estado_golpe", "estado_golpe_prob", "estado_golpe_turnos", "estado_golpe_mult":
			if estado_golpe < 0:
				return ""
			# (25/11) con su fuerza propia (Leña al caido: la Marca al +10 %), que se diga
			var que_hace: String = StatusEffects.efecto_legible(estado_golpe, estado_golpe_mult)
			return "Tiene una probabilidad base del %s de causar %s al enemigo que golpea durante %d turno%s%s." % [
				_pct_entero(estado_golpe_prob), str(StatusEffects.def(estado_golpe).get("nombre", "?")), estado_golpe_turnos,
				"" if estado_golpe_turnos == 1 else "s", (" (%s)" % que_hace) if que_hace != "" else ""]
		"se_mueve":
			return "Tras usarla, quien la usa se mueve hasta %s adonde elija." % casillas_txt(se_mueve) if se_mueve > 0.0 else ""
		"efectos_cargas_extra":
			var noms: Array = []
			for a in efectos:
				if a != null and int(a.estado) >= 0 and a.en_objetivo:
					var nm: String = str(StatusEffects.def(int(a.estado)).get("nombre", "?"))
					if not noms.has(nm):
						noms.append(nm)
			return "Cada vez que causa %s, mete %d cargas en vez de 1, y cada carga tiene su propia probabilidad." % [
				" o ".join(PackedStringArray(noms)), 1 + efectos_cargas_extra]
		"bonus_por_baja":
			return "Por cada enemigo que derriba, los golpes que le quedan infligen un %s más (hasta %d veces)." % [
				_pct_txt(bonus_por_baja), bonus_por_baja_max]
		"carga_peso_max":
			return ("Sus golpes de arma infligen hasta un %s más según lo que corras antes de chocar (con la carrera entera, todo)." \
				% _pct_entero(carga_peso_max)) if carga_peso_max > 0.0 else ""
		"escudo_abre_critico":
			return "Si el golpe de escudo le entra, los golpes de arma que le siguen son siempre críticos." if escudo_abre_critico else ""
		"reto_turnos":
			return ("Al que le entra va solo a por ti durante %d turno%s tuyo%s." % [reto_turnos, "" if reto_turnos == 1 else "s",
				"" if reto_turnos == 1 else "s"]) if reto_turnos > 0 else ""
		"escudo_contra_extra":
			return ("Hasta tu siguiente turno, la probabilidad de devolver con el escudo el golpe que paras sube un %s." \
				% _pct_entero(escudo_contra_extra)) if escudo_contra_extra > 0.0 else ""
		"guardia_turnos_extra":
			return ("La guardia en la que te deja dura %d turno%s tuyo%s más." % [guardia_turnos_extra,
				"" if guardia_turnos_extra == 1 else "s", "" if guardia_turnos_extra == 1 else "s"]) if guardia_turnos_extra > 0 else ""
		"forma_escudo_largo":
			return ("El golpe de escudo alcanza a todos los de su línea hasta %s." % casillas_txt(forma_escudo_largo)) \
				if forma_escudo_largo > 0.0 else ""
		"tiron":
			if tiron < 0.0:
				return "Empuja %s a cada enemigo que golpea." % casillas_txt(-tiron)
			return ("Arrastra %s hacia quien golpea a cada enemigo que alcanza." % casillas_txt(tiron)) if tiron > 0.0 else ""
		"mults_golpe":
			if mults_golpe.size() <= (antes.mults_golpe as Array).size():
				return ""
			return "Un golpe más al final, al %s de los de arma." % _pct_entero(float(mults_golpe[-1]) / maxf(float(mults_golpe[-2]), 0.0001))
		"remate_estado", "remate_mult":
			if remate_estado < 0:
				return ""
			return "El último golpe inflige un %s más a los enemigos con %s." % [_pct_txt(remate_mult - 1.0),
				str(StatusEffects.def(remate_estado).get("nombre", "?"))]
	return ""


static func _oport_usos_de(a: AbilityData) -> int:
	return a.oport_usos if a.oport_usos > 0 else int(StatusEffects.def(StatusEffects.Id.OPORTUNISTA).get("usos", 5))


static func _oport_pct_de(a: AbilityData) -> float:
	return a.oport_seguimiento if a.oport_seguimiento > 0.0 \
		else float(StatusEffects.def(StatusEffects.Id.OPORTUNISTA).get("seguimiento_pct", 0.75))


const _NOMBRE_TAMANO_ESCUDO := ["escudo pequeño", "escudo normal", "escudo grande"]

# «escudo», «escudo pequeño», «escudo normal o escudo grande»
func _escudos_txt() -> String:
	if escudos_tamanos.is_empty():
		return "escudo"
	var n: Array = []
	for tm in escudos_tamanos:
		n.append(_NOMBRE_TAMANO_ESCUDO[clampi(int(tm), 0, _NOMBRE_TAMANO_ESCUDO.size() - 1)])
	return " o ".join(PackedStringArray(n))


static func _pct_entero(f: float) -> String:
	return "%d %%" % roundi(f * 100.0)


static func casillas_txt(px: float) -> String:
	var v: float = maxf(0.5, roundf(px / CASILLA_PX * 2.0) / 2.0)
	if is_equal_approx(v, 0.5):
		return "media casilla"
	if is_equal_approx(v, 1.0):
		return "1 casilla"
	var t: String = str(roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v).replace(".", ",")
	return "%s casillas" % t


# El ELEMENTO DEL ARMA (17/11, su peticion: "no lo descartes"): hoy todas las armas son fisicas sin elemento, asi que
# NINGUNO. Si algun dia hay armas elementales, se mira aqui y todas las fichas lo dicen solas.
static func elemento_de_arma(_quien = null) -> int:
	return Elementos.Elemento.NINGUNO


# [tipo, radio, apertura] de la huella que dice la ficha, o la deducida (como CombatFormas.de_habilidad). tipo -1 = un
# solo objetivo (sin forma que contar).
func _forma_para_texto() -> Array:
	var t: int = forma
	var r: float = forma_radio
	var ap: float = forma_apertura
	if t < 0:
		if not es_area() or area_max <= 1 or area_max >= 99:
			return [-1, 0.0, 0.0]
		if area_modo == AreaModo.BARRIDO:
			return [2, maxf(_R_BASE + _PASO_RADIO * float(area_max - 1), _R_BASE), _APERTURA_BASE]
		return [1, _R_BASE + _PASO_RADIO * float(area_max - 1), 0.0]
	if t == 0:
		return [-1, 0.0, 0.0]
	return [t, r if r > 0.0 else _R_BASE, ap if ap > 0.0 else _APERTURA_BASE]


# «Forma: cono · 2 casillas · 120° · delante». "" si pega a uno solo.
func _forma_txt(de_enemigo: bool) -> String:
	var f: Array = _forma_para_texto()
	var t: int = int(f[0])
	if t < 0:
		return ""
	# A UN ALIADO (la Escolta, el Muro): la huella solo sirve para elegirlo; no es un area.
	if forma_a_aliados and objetivo_aliado == Objetivo.ALIADO:
		if forma_apunte == 3 and forma_rango > 0.0:
			return "Forma: un aliado · hasta %s." % casillas_txt(forma_rango)
		return "Forma: un aliado."
	var partes: Array = [_NOMBRE_FORMA[t]]
	match t:
		1:
			partes.append("%s de radio" % casillas_txt(float(f[1])))
		2:
			partes.append(casillas_txt(float(f[1])))
			partes.append("%d°" % roundi(float(f[2])))
		3:
			partes.append("%s de largo" % casillas_txt(float(f[1])))
		4:
			partes.append("%s de lado" % casillas_txt(float(f[1])))
	# DONDE CAE. El cono y la linea salen siempre de quien la usa.
	var donde: String = ""
	if t == 2 or t == 3:
		donde = "delante"
	elif forma_apunte == 2 or (forma_apunte < 0 and forma_desde_quien_ataca):
		donde = "a su alrededor" if de_enemigo else "alrededor de quien la usa"
	elif forma_apunte == 1:
		donde = "delante"
	elif forma_apunte == 3:
		donde = ("donde apunte, hasta %s" % casillas_txt(forma_rango)) if forma_rango > 0.0 \
			else "donde apunte, al alcance de su arma"
	elif forma_apunte == 0:
		donde = "sobre un objetivo" if de_enemigo else "sobre un enemigo"
	if donde != "":
		partes.append(donde)
	return "Forma: " + " · ".join(partes) + "."


# «del Ataque de quien la usa» / «de su Ataque» (y el magico y la Defensa del escudazo).
func _base_txt(de_enemigo: bool, escudo: bool) -> String:
	var stat: String = "Defensa" if escudo else ("Ataque mágico" if es_magico else "Ataque")
	if de_enemigo:
		return "de su %s" % stat
	return ("de la %s de quien la usa" % stat) if escudo else ("del %s de quien la usa" % stat)


# «como Daño Físico», «como Daño Mágico de Oscuridad».
func _tipo_txt(de_enemigo: bool, quien = null) -> String:
	var elem: int = elemento_de_arma(quien)
	if de_enemigo:
		elem = elemento_golpe if elemento_golpe >= 0 else Elementos.Elemento.NINGUNO
	var t: String = "como Daño %s" % ("Mágico" if es_magico else "Físico")
	if elem != Elementos.Elemento.NINGUNO:
		t += " de %s" % Elementos.nombre(elem)
	return t


# ------------------------------------------------------------
#  LAS CIFRAS DE LAS FICHAS (17/11, su decision): el % y, al lado, el numero con el personaje que la lleva («un 200 %
#  (48) del Ataque de quien la usa»), en habilidades y hechizos por igual. Lo elige el jugador en Ajustes (el menu de
#  opciones, por hacer): 0 = solo el %, 1 = solo el numero («Inflige 48 de Daño Físico»), 2 = los dos. Sin personaje
#  delante (ref <= 0) va siempre solo el %.
# ------------------------------------------------------------
enum ModoCifras { PORCENTAJE, NUMERO, LOS_DOS }
static var modo_cifras: int = ModoCifras.LOS_DOS


static func _solo_numero(ref: float) -> bool:
	return ref > 0.0 and modo_cifras == ModoCifras.NUMERO


# Una cifra suelta para listas: «un 130 % (52)», «un 130 %» o «52».
static func cifra_txt(f: float, ref: float) -> String:
	if _solo_numero(ref):
		return num_txt(f * ref)
	if ref > 0.0 and modo_cifras == ModoCifras.LOS_DOS:
		return "un %s (%s)" % [_pct_txt(f), num_txt(f * ref)]
	return "un " + _pct_txt(f)


# Lo que inflige, entero: «un 200 % (48) del Ataque de quien la usa como Daño Físico» o, en modo numero, «48 de Daño
# Físico». 'base' = «del Ataque de quien la usa»; 'tipo' = «como Daño Físico».
static func cuanto_txt(f: float, ref: float, base: String, tipo: String) -> String:
	if _solo_numero(ref):
		return "%s %s" % [num_txt(f * ref), tipo.replace("como Daño", "de Daño")]
	return "%s %s %s" % [cifra_txt(f, ref), base, tipo]


# Varias cifras seguidas (tramos, cuñas): «un 130 %, un 97,5 % y un 65 % del Ataque de quien la usa como Daño Físico» o
# «52, 39 y 26 de Daño Físico».
static func lista_cuanto_txt(fs: Array, ref: float, base: String, tipo: String) -> String:
	var partes: Array = []
	for f in fs:
		partes.append(cifra_txt(float(f), ref))
	var y_txt: String = partes[0] if partes.size() == 1 else "%s y %s" % [", ".join(partes.slice(0, partes.size() - 1)), partes[-1]]
	if _solo_numero(ref):
		return "%s %s" % [y_txt, tipo.replace("como Daño", "de Daño")]
	return "%s %s %s" % [y_txt, base, tipo]


# Un numero de daño: sin decimales si es grande, con uno y coma si es pequeño («48», «3,5»).
static func num_txt(v: float) -> String:
	if v >= 10.0 or is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	return ("%.1f" % v).replace(".", ",")


# Lo que vale el 100 % de la stat de la que sale el daño, con 'quien' (un Combatant): su Ataque, su Ataque magico o lo
# que pega con el escudo. 0 sin nadie delante.
func _ref_de(quien, escudo: bool) -> float:
	if quien == null or not (quien is Object) or not quien.has_method("atk"):
		return 0.0
	if escudo:
		return float(quien.atk_escudo()) / StatsMath.ESCUDO_DEF_A_ATAQUE if quien.has_method("atk_escudo") else 0.0
	if es_magico:
		return float(quien.atk_magico()) if quien.has_method("atk_magico") else 0.0
	return float(quien.atk())


# LA FRASE DEL DAÑO (y la de a quien). Varias lineas si hace falta.
func _dano_txt(manos: int, de_enemigo: bool, quien = null) -> Array:
	var l: Array = []
	var rec: String = "objetivo" if de_enemigo else "enemigo"
	var g: String = _golpes_txt(manos)
	var escudo_todo: bool = escudo_desde_golpe == 0
	var k: float = StatsMath.ESCUDO_DEF_A_ATAQUE if escudo_todo else 1.0
	var base: String = _base_txt(de_enemigo, escudo_todo)
	var tipo: String = _tipo_txt(de_enemigo, quien)
	var ref: float = _ref_de(quien, escudo_todo)
	var f: Array = _forma_para_texto()
	var t: int = int(f[0])
	var del_f: String = _DEL_FORMA[t] if t > 0 else "del área"
	var huella: bool = forma >= 0 and forma_apunte >= 0
	var pct: float = dano_mult * k
	var a_quien: String = "a un %s" % rec
	var cada: String = ""          # lo que va despues ("y un 50 % ... a los del resto")
	# Lo de los de detras / el resto, en la misma moneda (en modo numero, solo el numero).
	var resto := func(fr: float) -> String:
		return num_txt(fr * ref) if _solo_numero(ref) else "%s %s" % [cifra_txt(fr, ref), base]
	if t > 0 and huella:
		if forma_solo_primero:
			a_quien = "solo al primer %s que encuentra" % rec
		elif atraviesa:
			a_quien = "al primer %s que cruza" % rec
			var tope: String = ""
			if area_max > 0 and area_max < 99:
				tope = " (hasta %d %ss en total)" % [area_max, rec]
			cada = " y %s a los que van detrás%s" % [resto.call(pct * area_secundario), tope]
		elif avance and forma_reparte and num_golpes_max(manos) > 1:
			a_quien = "a los %ss que cruza al avanzar, repartidos en el orden en que los cruza" % rec
			pct *= forma_escala
		elif forma_reparte and num_golpes_max(manos) > 1:
			a_quien = "a un solo %s %s, por turnos, del más cercano al centro al más lejano" % [rec, del_f]
			pct *= forma_escala
		elif forma_nucleo > 0.0:
			a_quien = "a todos los %ss del centro (%s de radio)" % [rec, casillas_txt(forma_nucleo)]
			cada = " y %s a los del resto %s" % [resto.call(pct * area_secundario), del_f]
		elif forma_tramos > 1:
			a_quien = "a todos los %ss %s" % [rec, del_f]
		elif forma_a_aliados:
			a_quien = "a todos los aliados %s" % del_f
			pct *= forma_escala
		else:
			a_quien = "a todos los %ss %s" % [rec, del_f]
			pct *= forma_escala
	if forma_tramos > 1 and huella and t > 0 and not forma_reparte and forma_nucleo <= 0.0 and not forma_solo_primero \
			and not atraviesa:
		# Con tramos no hay UN porcentaje: «Inflige a todos los enemigos del cono un 130 %, un 97,5 % y un 65 % del Ataque
		# de quien la usa como Daño Físico, de cerca a lejos.»
		var fs: Array = []
		for i in forma_tramos:
			fs.append(dano_mult * k * maxf(0.0, forma_escala - forma_tramo_baja * float(i)))
		var frase: String = "%s %s, de cerca a lejos" % [a_quien, lista_cuanto_txt(fs, ref, base, tipo)]
		if g == "1":
			l.append("Inflige %s." % frase)
		else:
			l.append("Da %s golpes; cada uno inflige %s." % [g, frase])
	elif g == "1":
		l.append("Inflige %s %s%s." % [cuanto_txt(pct, ref, base, tipo), a_quien, cada])
	else:
		l.append("Da %s golpes; cada uno inflige %s %s%s." % [g, cuanto_txt(pct, ref, base, tipo), a_quien, cada])
	if not huella:
		var at: String = _area_txt(rec)
		if at != "":
			l.append(at)
		elif redirige_al_morir and num_golpes_max(manos) > 1:
			l.append("Si el %s cae antes, los golpes que quedan saltan a otros %ss." % [rec, rec])
	if escudo_desde_golpe > 0:
		var ref_e: float = _ref_de(quien, true)
		l.append("Del %d.º golpe en adelante golpea con el escudo: esos golpes infligen %s." % [
			escudo_desde_golpe + 1, cuanto_txt(dano_mult * StatsMath.ESCUDO_DEF_A_ATAQUE, ref_e,
			_base_txt(de_enemigo, true), _tipo_txt(de_enemigo, quien))])
	return l


# LA IMBUICION que lleva puesta 'quien' (un Combatant, en la pelea): su linea al final, con SU porcentaje. Es MAGICA:
# sale del Ataque crudo y va contra la Defensa magica (StatsMath.resolve_attack).
static func imbuicion_txt(quien) -> String:
	if quien == null or not (quien is Object) or quien.get("imbue_usos") == null:
		return ""
	if int(quien.imbue_usos) <= 0 or int(quien.imbue_elemento) == Elementos.Elemento.NINGUNO or float(quien.imbue_pct) <= 0.0:
		return ""
	var ref: float = float(quien.atk()) if quien.has_method("atk") else 0.0
	var e: String = "un elemento al azar" if bool(quien.get("imbue_prisma")) else Elementos.nombre(int(quien.imbue_elemento))
	var que: String = "prismática" if bool(quien.get("imbue_prisma")) else "de %s" % e
	return "Por su imbuición %s, cada golpe inflige además %s." % [que,
		cuanto_txt(float(quien.imbue_pct), ref, "del Ataque de quien la usa", "como Daño Mágico de %s" % e)]


# Tope de golpes que da con esas manos (sin contar los extra por multitud). Las frases de la ficha
# lo necesitan: mirando maxi(golpes_max, golpes_dual_max) se decia "en cada golpe" en una habilidad
# que a UNA mano da uno solo.
func num_golpes_max(manos: int) -> int:
	if manos >= 2 and golpes_dual_max > 0:
		return golpes_dual_max
	return golpes_max


# Rango de golpes como texto ("1", "2", "1-2") para el 'manos' dado.
func _golpes_txt(manos: int) -> String:
	var lo: int = golpes_min
	var hi: int = golpes_max
	if manos >= 2 and golpes_dual_max > 0:
		lo = golpes_dual_min
		hi = golpes_dual_max
	return str(lo) if lo == hi else "%d-%d" % [lo, hi]


# RESUMEN mecanico GENERADO desde los campos (nunca hardcodeado en la descripcion):
# daño, golpes, coste, cooldown, carga, foco/mana y estados. Asi cambiar un valor
# (p.ej. cooldown) actualiza el texto solo. La 'descripcion' queda para el SABOR.
# Lo usa el tooltip de habilidad (combat.gd) y cualquier UI futura.
#
# PASE DE TEXTOS (06/11, docs/guia_textos.md): cada % dice de que es ("del daño de un ataque basico"), los estados con
# "probabilidad base de causar", el sujeto es "quien la usa" (lo eligio el jefe), a quien se le echa "un aliado", y nada
# de "tú", "encajar" ni "CD".
#
# REPASO 17/11 (estilo HSR): «un X % del Ataque de quien la usa ... a un enemigo» (personajes) / «un X % de su Ataque ... a
# un objetivo» (enemigos: 'de_enemigo'), la FORMA en su linea, y la IMBUICION de 'quien' (Combatant) al final si la lleva.
func resumen(manos: int = 1, de_enemigo: bool = false, quien = null) -> String:
	# UNA FRASE POR LINEA, como las magias (SpellData.descripcion_mecanica).
	var l: Array = []
	var rec: String = "objetivo" if de_enemigo else "enemigo"
	var ft: String = _forma_txt(de_enemigo)
	if ft != "":
		l.append(ft)

	# --- QUE HACE AL PEGAR ---
	if dano_mult > 0.0:
		l.append_array(_dano_txt(manos, de_enemigo, quien))
		if manos >= 2 and golpes_dual_max > golpes_max:
			l.append("Los golpes de la segunda arma (del %d.º en adelante) infligen un %s del daño de los de la primera." % [
				golpes_max + 1, _pct_txt(dual_golpe_mult)])
		elif not mults_golpe.is_empty():
			var partes := PackedStringArray()
			for i in mults_golpe.size():
				partes.append("el %d.º un %s" % [i + 1, _pct_txt(float(mults_golpe[i]))])
			l.append("No todos los golpes infligen lo mismo: %s de ese daño." % _y(partes))
		var por: float = golpes_extra_por_enemigo
		if manos >= 2 and golpes_extra_por_enemigo_dual > 0.0:
			por = golpes_extra_por_enemigo_dual
		if por > 0.0:
			l.append("%s (hasta %d)." % [_extra_por_enemigo_txt(por), golpes_extra_max])
		if crit_extra > 0.0:
			l.append("Probabilidad de crítico de esta habilidad +%s." % _pct_txt(crit_extra))
		if penetracion_extra > 0.0:
			l.append("Ignora un %s más de la Defensa de cada %s al que golpea." % [_pct_txt(penetracion_extra), rec])
	var antes_de_efectos: int = l.size()

	# --- LO QUE APLICA ---
	var est: String = _texto_estados(manos, de_enemigo)
	if est != "":
		l.append(est)
	l.append_array(_texto_fases_luna(de_enemigo))
	if es_imbuicion():
		var nom_est: String = str(StatusEffects.def(imbue_estado).get("nombre", "?"))
		var doble: String = "" if imbue_prob_doble <= 0.0 \
			else " y un %s de que sean 2 acumulaciones" % _pct_txt(imbue_prob_doble)
		l.append("Impregna de %s el arma durante %d ataques: cada golpe tiene un %s de probabilidad base de causar %s%s." % [
			nom_est, imbue_usos, _pct_txt(imbue_prob), nom_est, doble])
		if not imbue_escalera.is_empty():
			l.append("Al causarlo, las acumulaciones que suma dependen del tier del arma:")
			for t in imbue_escalera.size():
				l.append("   · T%d%s: %s" % [t + 1, " o más" if t == imbue_escalera.size() - 1 else "",
					texto_reparto(imbue_escalera[t])])
		l.append("Se gasta al atacar, no cuando pasan los turnos, y se conserva de un combate al siguiente.")
		if imbue_por_destreza:
			l.append("La probabilidad sube con la Destreza de quien la usa frente a la Resistencia del enemigo.")
	if limpia_debuffs > 0:
		var todos: bool = limpia_debuffs >= 99
		var cuantos: String = "todos los estados negativos" if todos \
			else "%d estado%s negativo%s al azar" % [limpia_debuffs, "" if limpia_debuffs == 1 else "s",
				"" if limpia_debuffs == 1 else "s"]
		l.append("Elimina %s %s." % [cuantos, "de todos los aliados" if objetivo_aliado == Objetivo.GRUPO else "de un aliado"])
	# En las de ENEMIGO el sujeto va callado («Se pone en guardia...»): su nombre ya sale en la ficha (17/11).
	var quien_s: String = "" if de_enemigo else "Quien la usa "
	var de_quien: String = "suyas" if de_enemigo else "de quien la usa"
	if reduce_cooldowns > 0:
		l.append("Las demás habilidades %s se recargan %d turno%s antes." % [de_quien,
			reduce_cooldowns, "" if reduce_cooldowns == 1 else "s"])
	if invoca_cantidad > 0:
		l.append(_invoca_txt())
	# La GUARDIA es la de Defender: bloquea parte del daño (entre StatsMath.DEFEND_TAKEN_MAX y _MIN, segun un pulso de
	# stats: no hay un numero fijo que dar) y deja los criticos en su contra a la mitad.
	var guardia: String = "bloquea parte del daño que recibe y la probabilidad de recibir un golpe crítico se reduce a la mitad"
	if bloqueo_turnos > 0:
		l.append(_mayus("%sse pone en guardia hasta su próximo turno: %s." % [quien_s, guardia]))
	if provoca_turnos > 0:
		l.append("Durante %d turno%s, los %s tienen más probabilidad de atacar a %s." % [
			provoca_turnos, "" if provoca_turnos == 1 else "s", "personajes" if de_enemigo else "enemigos",
			"este enemigo" if de_enemigo else "quien la usa"])
	if postura_contraataque:
		if contra_con_escudo:
			l.append(_mayus("%sse pone en guardia: aumenta su Esquiva y devuelve con un escudazo (que sale de su Defensa) los golpes que esquiva o para, pero se vuelve más lento." % quien_s))
		else:
			l.append(_mayus("%sse pone en guardia: aumenta su Esquiva y devuelve los golpes que esquiva, pero se vuelve más lento." % quien_s))
	if defensa_a_aliados:
		l.append("Pone en guardia a los aliados cercanos hasta su próximo turno: %s." % guardia.replace("recibe", "reciben"))
	if protege_turnos > 0:
		l.append("Durante %d turno%s, protege a un aliado: los ataques dirigidos a ese aliado los recibe %s, con su bloqueo y su Defensa." % [
			protege_turnos, "" if protege_turnos == 1 else "s", "él" if de_enemigo else "quien la usa"])
	if foco_cargas > 0:
		l.append(_mayus("%sobtiene %d cargas de Foco arcano para sus próximos hechizos." % [quien_s, foco_cargas]))
	if mana_gain > 0.0:
		l.append(_mayus("%srecupera %d de maná." % [quien_s, roundi(mana_gain)]))
	if energia_a_mana > 0.0:
		l.append("Convierte toda la energía %s en maná." % ("suya" if de_enemigo else "de quien la usa"))
	# LA IMBUICION que lleva quien la usa en la pelea (al final de lo que hace: es un 'y ademas' de su arma).
	if dano_mult > 0.0 and not de_enemigo:
		var imb: String = imbuicion_txt(quien)
		if imb != "":
			l.append(imb)
	# «No hace daño.» solo si no hace NADA que contar (17/11: en las de apoyo sobraba; HSR no lo dice nunca).
	if dano_mult <= 0.0 and l.size() == antes_de_efectos:
		l.append("No hace daño.")

	# --- LO QUE CUESTA (siempre la ultima linea) ---
	var coste_p: Array = []
	var c: float = coste(manos)
	if c > 0.0:
		coste_p.append("%d de energía" % roundi(c))
	if carga_turnos > 0:
		coste_p.append("se carga durante %d turno%s" % [carga_turnos, "" if carga_turnos == 1 else "s"])
	if cooldown > 0:
		coste_p.append("se recarga en %d turno%s" % [cooldown, "" if cooldown == 1 else "s"])
	if requiere_escudo:
		coste_p.append("requiere " + _escudos_txt())
	if requiere_off_libre:
		coste_p.append("requiere la otra mano libre" + ("" if escudos_tamanos.is_empty() else " o " + _escudos_txt()))
	if not coste_p.is_empty():
		if c > 0.0:
			l.append("Coste: " + " · ".join(coste_p) + ".")
		else:
			# Sin energia (las de los enemigos) no hay "Coste:" que poner.
			var resto: String = " · ".join(coste_p)
			l.append(resto.substr(0, 1).to_upper() + resto.substr(1) + ".")

	# --- QUE CAMBIA CON DOS ARMAS IGUALES (al final: es un 'y ademas', no parte del kit) ---
	# Solo se cuenta mirando la ficha a UNA mano: con dos ya se estan viendo los numeros del dual.
	if manos < 2:
		var d: Array = []
		if golpes_dual_max > golpes_max:
			d.append("da %s golpes en vez de %s" % [_golpes_txt(2), _golpes_txt(1)])
			d.append("los golpes de la segunda arma infligen un %s del daño de los de la primera" % _pct_txt(dual_golpe_mult))
		if golpes_extra_por_enemigo_dual > golpes_extra_por_enemigo:
			d.append(_extra_por_enemigo_txt(golpes_extra_por_enemigo_dual).substr(0, 1).to_lower()
				+ _extra_por_enemigo_txt(golpes_extra_por_enemigo_dual).substr(1))
		if coste_energia_dual > 0.0 and coste_energia_dual != coste_energia:
			d.append("cuesta %d de energía" % roundi(coste_energia_dual))
		if not d.is_empty():
			l.append(_lista_efectos("Con dos armas iguales", d))
	return "\n".join(l)


# Con la primera letra en mayuscula (las frases que empiezan por un sujeto que puede ir callado).
static func _mayus(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t


# «Invoca 1 Apagaluces pequeño.» / «Invoca 2 slimes al azar entre: Slime de fuego, Slime de agua.» (lo que saca de verdad,
# de invoca_pool; antes «Invoca 1 ayudante»).
func _invoca_txt() -> String:
	var nombres: Array = []
	for ed in invoca_pool:
		if ed != null and ed.get("enemy_name") != null and not nombres.has(String(ed.enemy_name)):
			nombres.append(String(ed.enemy_name))
	var n: int = invoca_cantidad
	if nombres.is_empty():
		return "Invoca %d aliado%s." % [n, "" if n == 1 else "s"]
	if nombres.size() == 1:
		return "Invoca %d %s." % [n, nombres[0]] if n == 1 else "Invoca %d: %s." % [n, nombres[0]]
	return "Invoca %d al azar entre: %s." % [n, _y(nombres)]


# "150 %", "37,5 %": coma decimal y espacio antes del % (guia de textos).
static func _pct_txt(f: float) -> String:
	var v: float = f * 100.0
	if is_equal_approx(v, roundf(v)):
		return "%d %%" % roundi(v)
	return "%s %%" % ("%.1f" % v).replace(".", ",")


# Los golpes de mas por enemigo, sin medios golpes: 0,5 por enemigo = "1 golpe más por cada 2 enemigos de más".
func _extra_por_enemigo_txt(por: float) -> String:
	if por < 1.0:
		var cada: int = maxi(2, roundi(1.0 / por))
		return "Da 1 golpe más por cada %d enemigos de más en el combate" % cada
	var n: int = roundi(por)
	return "Da %d golpe%s más por cada enemigo de más en el combate" % [n, "" if n == 1 else "s"]


# Los estados que aplica, agrupados por A QUIEN van. Mismo criterio que SpellData._texto_estados.
func _texto_estados(manos: int = 1, de_enemigo: bool = false) -> String:
	var al_rival: Array = []      # _efecto_partes
	var a_los_mios: Array = []
	var por_crit: Array = []       # los que SOLO salen si el golpe critea (a.solo_crit)
	for a in efectos:
		if a == null or int(a.estado) < 0 or int(a.solo_fase_luna) >= 0:
			continue   # (los de una fase de la luna van aparte: _texto_fases_luna)
		var e: Array = _efecto_partes(a)
		if bool(a.solo_crit):
			por_crit.append(e)
		elif a.en_objetivo:
			al_rival.append(e)
		else:
			a_los_mios.append(e)

	# "CADA GOLPE" cambia por completo lo que significa el porcentaje: un 22 % en una habilidad
	# de 6 tajos no es un 22 %, es casi seguro. Sin esto el numero engaña.
	var multi: bool = num_golpes_max(manos) > 1
	var por_golpe: bool = efectos_por_golpe and multi
	var rec: String = "objetivo" if de_enemigo else "enemigo"
	var en_area: bool = (es_area() or int(_forma_para_texto()[0]) > 0) and not forma_solo_primero
	var quien_r: String = ("cada %s alcanzado" % rec) if en_area else ("ese %s" % rec)

	var out: Array = []
	if not al_rival.is_empty():
		var sujeto: String = "Cada golpe tiene" if por_golpe else "Tiene"
		out.append(_frase_causar(sujeto, al_rival, quien_r))
	if not a_los_mios.is_empty():
		var grupo: bool = _algun_efecto_al_grupo()
		var quien_m: String = "quien la usa"
		if grupo:
			quien_m = "todos los aliados"
			if forma_a_aliados and int(_forma_para_texto()[0]) > 0:
				quien_m += " " + _DEL_FORMA[int(_forma_para_texto()[0])]
		elif de_enemigo:
			quien_m = ""   # «Aumenta su Ataque...»: el nombre ya sale en la ficha
		var nombrados: Array = []
		for e in a_los_mios:
			var p: int = int(e[0])
			var conp: String = "" if p >= 100 else " (con un %d %% de probabilidad)" % p
			# Los que solo cambian stats, como HSR: «Aumenta la Velocidad de quien la usa en un 25 % durante 2 turnos.»
			var st: String = accion_stats(int(e[3]), float(e[4]), quien_m, false)
			if st != "" and int(e[6]) <= 1:
				out.append(_mayus(st) + String(e[5]) + conp + ".")
			else:
				nombrados.append("%s%s%s" % [e[1], e[2], conp])
		if not nombrados.is_empty():
			if grupo:
				out.append("Otorga a %s %s." % [quien_m, _y(nombrados)])
			else:
				out.append(("Obtiene %s." if de_enemigo else "Quien la usa obtiene %s.") % _y(nombrados))
	# Los de critico van en su PROPIA frase, con la condicion delante.
	if not por_crit.is_empty():
		out.append(_frase_causar("Si el golpe es crítico, además tiene", por_crit, quien_r))
	return "\n".join(out)


# «Tiene un 55 % de probabilidad base de causar Sangrado a ese enemigo durante 3 turnos.» Los que solo bajan stats, como
# HSR: «...de reducir el Ataque de cada enemigo alcanzado en un 20 % durante 3 turnos». Varios, en la misma frase: «y un
# 60 % de reducir su Velocidad en un 25 % durante 3 turnos».
func _frase_causar(sujeto: String, lista: Array, quien: String) -> String:
	var trozos: Array = []
	# Si todos son de stats y duran lo mismo, la duracion va una vez al final (no «durante 3 turnos y ... durante 3 turnos»).
	var junta: bool = lista.size() > 1
	for e in lista:
		if int(e[6]) > 1 or StatusEffects._bonus(int(e[3]), float(e[4]), 1.0).is_empty() or String(e[5]) != String(lista[0][5]):
			junta = false
	for k in lista.size():
		var e: Array = lista[k]
		var st: String = accion_stats(int(e[3]), float(e[4]), quien if k == 0 else "", true) if int(e[6]) <= 1 else ""
		var accion: String
		if st != "":
			accion = st + ("" if junta else String(e[5]))
		else:
			accion = "causar %s a %s%s" % [e[1], quien if k == 0 else ("ese mismo" if quien.begins_with("ese") else "cada uno"), e[2]]
		if k == 0:
			trozos.append("un %d %% de probabilidad base de %s" % [int(e[0]), accion])
		else:
			trozos.append("un %d %% de %s" % [int(e[0]), accion])
	if trozos.size() == 1:
		return "%s %s." % [sujeto, trozos[0]]
	return "%s %s y %s%s." % [sujeto, ", ".join(trozos.slice(0, trozos.size() - 1)), trozos[-1],
		("," + String(lista[0][5])) if junta else ""]


# LO QUE HACE UN ESTADO QUE SOLO CAMBIA STATS, como HSR (17/11): «reducir el Ataque de ese enemigo en un 20 %» (infinitivo)
# o «aumenta la Velocidad de quien la usa en un 25 %». 'quien' vacio = «su» («reducir su Velocidad...»). "" si el estado
# hace algo mas que cambiar stats (Sangrado, Aturdido...): ese va por su nombre.
static func accion_stats(id: int, mult: float, quien: String, infinitivo: bool) -> String:
	var bonus: Array = StatusEffects._bonus(id, mult, 1.0)
	if bonus.is_empty():
		return ""
	var trozos: Array = []
	var signo_antes: int = 0
	for i in bonus.size():
		var p: Array = bonus[i]
		var v: float = float(p[1])
		var signo: int = 1 if v >= 0.0 else -1
		var cuanto: String = ("en un %d %%" if bool(p[2]) else "en %d") % absi(roundi(v))
		var verbo: String = ("aumentar" if signo > 0 else "reducir") if infinitivo else ("aumenta" if signo > 0 else "reduce")
		var s: String
		if i == 0 and quien != "":
			s = "%s %s %s de %s %s" % [verbo, String(p[3]), String(p[0]), quien, cuanto]
		elif i == 0 or signo != signo_antes:
			s = "%s su %s %s" % [verbo, String(p[0]), cuanto]
		else:
			s = "su %s %s" % [String(p[0]), cuanto]
		trozos.append(s)
		signo_antes = signo
	var t: String = String(trozos[0]) if trozos.size() == 1 \
		else ", ".join(trozos.slice(0, trozos.size() - 1)) + " y " + String(trozos[-1])
	if int(StatusEffects.def(id).get("max_stacks", 1)) > 1:
		t += " por acumulación"
	return t


# Con UN efecto va todo en una frase; con varios, uno por linea con vineta.
func _lista_efectos(cabecera: String, cosas: Array) -> String:
	if cosas.size() == 1:
		return "%s: %s." % [cabecera, cosas[0]]
	var l: Array = ["%s:" % cabecera]
	for c in cosas:
		l.append("   · %s" % c)
	return "\n".join(l)


func _algun_efecto_al_grupo() -> bool:
	for a in efectos:
		if a != null and not a.en_objetivo and bool(a.get("a_todo_el_grupo")):
			return true
	return false


# "a, b y c" — para que las frases se lean como frases y no como listas separadas por comas.
func _y(cosas) -> String:
	var v: Array = []
	for c in cosas:
		v.append(str(c))
	if v.size() <= 1:
		return "" if v.is_empty() else v[0]
	return "%s y %s" % [", ".join(v.slice(0, v.size() - 1)), v[v.size() - 1]]


# (20/11, el Cazador lunar) LO QUE HACE SEGUN LA FASE DE LA LUNA en que la lanza: una linea por fase, en su orden.
func _texto_fases_luna(de_enemigo: bool) -> Array:
	var out: Array = []
	var en_area: bool = (es_area() or int(_forma_para_texto()[0]) > 0) and not forma_solo_primero
	var rec: String = "objetivo" if de_enemigo else "enemigo"
	var quien_r: String = ("cada %s alcanzado" % rec) if en_area else ("ese %s" % rec)
	for f in FASES_LUNA_TXT.size():
		var lista: Array = []
		for a in efectos:
			if a != null and int(a.estado) >= 0 and int(a.solo_fase_luna) == f and a.en_objetivo:
				lista.append(_efecto_partes(a))
		if not lista.is_empty():
			out.append(_frase_causar("En %s, tiene" % FASES_LUNA_TXT[f], lista, quien_r))
		if robo_vida > 0.0 and robo_vida_fase == f:
			out.append("En %s, %sse cura un %s del daño que hace." % [FASES_LUNA_TXT[f],
				"" if de_enemigo else "quien la usa ", _pct_txt(robo_vida)])
	return out


# UN estado que aplica, en piezas: [probabilidad en %, nombre, " durante 3 turnos (Ataque +25 %)"].
func _efecto_partes(a) -> Array:
	var id_est: int = int(a.estado)
	var nom: String = String(StatusEffects.def(id_est).get("nombre", "?"))
	# Varias de una tirada, en el propio nombre (06/11, el jefe: "suma 2 acumulaciones de una vez" sonaba mal): "causar
	# 2 acumulaciones de Pegajoso al objetivo".
	if int(a.stacks) > 1:
		nom = "%d acumulaciones de %s" % [int(a.stacks), nom]
	var turnos: int = int(a.turns) if int(a.turns) > 0 else int(StatusEffects.def(id_est).get("turns", 0))
	var det: String = ""
	if turnos > 0:
		det += " durante %d turno%s" % [turnos, "" if turnos == 1 else "s"]
	var extras: Array = []
	var que_hace: String = StatusEffects.efecto_legible(id_est, mult_de_efecto(a))
	if que_hace != "":
		extras.append(que_hace)
	if id_est == StatusEffects.Id.ATURDIDO and a.en_objetivo:
		extras.append("se suma al aturdimiento propio del arma")
	var durante: String = det
	if not extras.is_empty():
		det += " (%s)" % "; ".join(extras)
	return [roundi(prob_de_efecto(a) * 100.0), nom, det, id_est, mult_de_efecto(a), durante, int(a.stacks)]


# Texto de UN estado en una linea ("Sangrado (55 % · 3 turnos)"), para quien lo pida suelto.
func _efecto_txt(a) -> String:
	if a == null or int(a.estado) < 0:
		return ""
	var e: Array = _efecto_partes(a)
	return "%s: %d %% de probabilidad base%s" % [e[1], int(e[0]), e[2]]
