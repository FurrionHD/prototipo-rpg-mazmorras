# ============================================================
#  consumable_data.gd
#  RECURSO con los DATOS de un OBJETO consumible (poción). Se guarda como .tres.
#  Las pociones CURAN POR EL TIEMPO (heal-over-time), no de golpe:
#   - En COMBATE: `cura_total` repartido en `turnos`. El PRIMER trozo cae en el mismo turno en
#     que la usas (los estados tiquean al inicio del turno, asi que si no, no veias nada subir
#     hasta tu turno siguiente) y el resto va como estado Regeneración en los turnos que queden.
#     Usarla GASTA tu turno, asi que premia aguantar/defender mientras tiquea (KAN-57). Y se le
#     puede dar a OTRO del grupo: eliges a quien en el submenu de Objeto.
#   - FUERA de combate: curan `cura_total` repartido en `segundos` de tiempo real, sobre la
#     persona a la que se la des (ver Game.beber_pocion_fuera / Game.tick_heal). La cola de
#     goteo vive en su ficha (PersonajeData.heal_left), asi que cambiar de lider no se la roba.
#  Inventario: Game.consumables (ConsumableData -> cantidad). Se consiguen por ahora
#  desde el panel de debug (boton "OBJETOS").
# ============================================================

extends Resource
class_name ConsumableData

@export var nombre: String = "Poción"
@export_multiline var descripcion: String = ""

# Cura PLANA (fija) de la poción. Manda al principio y hace que las pociones viejas se
# queden cortas al escalar la vida (progresion por tiers: necesitas pociones mejores).
@export var cura_total: float = 30.0
# Cura EXTRA como fraccion de tu vida MAXIMA (0.12 = +12% de tu max_hp). Un pelin de % para
# que una poción vieja no caiga a "rasguño" de golpe, sin volverla eterna. 0 = solo plano.
@export var cura_pct: float = 0.0
# MANÁ que restaura (mismo modelo que la vida: plano + % del maná máx). Una poción de
# MANÁ tiene cura_total 0 y mana_total > 0; una de VIDA al reves; podria haber una mixta.
@export var mana_total: float = 0.0
@export var mana_pct: float = 0.0

# COMBATE: la cura/maná se reparte en estos turnos (efectivo/turnos por turno).
@export var turnos: int = 3
# FUERA de combate: se reparte en estos segundos de tiempo real.
@export var segundos: float = 6.0

# GRIMORIO: si lleva hechizo, este "consumible" no se bebe, se ESTUDIA. Al usarlo desde el
# inventario aprendes ese hechizo (Game.usar_consumible -> aprender_de_grimorio) y el libro
# se gasta. Un grimorio no cura ni da maná: sus campos de poción se quedan a 0.
@export var spell: SpellData = null

# VUELTA AL PUEBLO: si esta marcado, este "consumible" no se bebe ni se estudia: te teletransporta
# al pueblo desde dentro de la mazmorra (Game.usar_consumible -> volver_al_pueblo_con_objeto), como
# si cruzaras la puerta del piso del boss. Su ALCANCE es por pisos: solo funciona en el piso
# `piso_max_vuelta` o por debajo; mas hondo no te saca (y no se gasta). Es el eje de tier de este
# objeto: la version de la tienda T1 llega al 6, la de la T2 al 12.
@export var vuelve_al_pueblo: bool = false
@export var piso_max_vuelta: int = 6

# CEBO DE PESCA: si trae radio, este consumible no se bebe, ni se estudia, ni se come. Se PONE en el
# anzuelo desde el menu del estanque y hace que los peces que pasen a menos de `cebo_radio` px del
# corcho se giren hacia el y vayan a por el (ver FishingSpot._nadar).
#
# SIN CEBO NO HAY ATRACCION NINGUNA, y es a proposito: la pesca a pelo es la de siempre (los peces
# deambulan y pican los que se cruzan por accidente) y el cebo es lo que compras cuando quieres que
# vengan ellos. El unico eje del cebo es ese radio: no sesga especies ni tallas y no toca el
# minijuego — eso ultimo ya es terreno de la CAÑA (tool_mods.golpes_menos alarga la ventana).
#
# Se gasta al COBRAR la pieza, con un 80% de probabilidad (Game.gastar_cebo_al_cobrar): si el pez se
# te escapa o recoges el sedal no pagas nada, que es lo que impide que fallar el tiron cueste doble.
# Un cebo no cura ni da maná: sus campos de poción se quedan a 0.
@export var cebo_radio: float = 0.0

# PLATO DE COCINA: si trae efectos, este consumible no se bebe ni se estudia, se COME
# (Game.usar_consumible -> comer_plato). Cada efecto es un StatusApplication que le pone un estado
# largo (20 min) al que elijas del grupo. Ver StatusEffects Id.PLATO_*.
#
# Un plato no cura ni da maná: sus campos de poción se quedan a 0. Y solo puedes llevar UNO puesto:
# la exclusion la resuelve el propio estado por su "familia", no este recurso.
# Array SIN tipar, como AbilityData.efectos y por el mismo motivo: los Array tipados escritos a mano
# en un .tres dan problemas al cargar.
@export var efectos: Array = []
# TIER del plato: escala el BONUS del estado, no el valor. 1.0 = T1, 1.2 = T2 (un +10% pasa a +12%
# y un +5% a +6%). Va aqui y no en el estado porque el T1 y el T2 comparten estado y solo cambia
# cuanto aprieta: asi no hacen falta catorce entradas en el catalogo para siete platos.
@export var escala_efecto: float = 1.0

# PRECIO base de la tienda. Las de maná valen ~2.5 veces lo que las de vida equivalentes, y
# los grimorios son el gasto gordo del principio.
@export var valor_base: int = 100

# COLOR del frasco cuando esta TIRADO EN EL SUELO (ver drop_pickup.gd). Se deja en transparente a
# proposito: asi el color lo DERIVA color_suelo() del propio contenido y no hay que rellenarlo a
# mano en cincuenta .tres (ni acordarse de tocarlo al crear el siguiente). Solo se pone aqui para
# forzar un objeto concreto que no encaje en ninguna familia.
@export var color_frasco: Color = Color(0, 0, 0, 0)


# Color con el que se ve este consumible en el SUELO. Por familia, y dentro de la familia por
# POTENCIA: una poción mayor de vida es un rojo mas vivo que una menor, asi que de un vistazo se
# distingue lo que merece la pena agacharse a coger sin leer el nombre.
#
# El eje de potencia es lo que cura/da (`cura_total` / `mana_total`) medido contra un tope suave:
# no hay tabla de tiers escrita a mano, o sea que una poción nueva se colorea sola.
func color_suelo() -> Color:
	if color_frasco.a > 0.0:
		return color_frasco
	if es_grimorio():
		return Color(0.62, 0.42, 0.85)          # morado de libro
	if es_plato():
		return Color(0.92, 0.62, 0.28)          # naranja de guiso
	if es_cebo():
		return Color(0.55, 0.72, 0.32)          # verde de cebo
	if es_vuelta_pueblo():
		return Color(0.95, 0.85, 0.40)          # dorado de piedra
	# Pociones: rojo (vida) o azul (maná), de un tono APAGADO a uno VIVO segun lo que lleven dentro.
	# Una mixta tira al color de lo que mas aporte.
	var vida: float = cura_total
	var mana: float = mana_total
	if vida >= mana:
		return POCION_VIDA_FLOJA.lerp(POCION_VIDA_FUERTE, _t_potencia(vida, VIDA_BASE))
	return POCION_MANA_FLOJA.lerp(POCION_MANA_FUERTE, _t_potencia(mana, MANA_BASE))


# 0 = la poción mas floja de su familia, 1 = el tono mas vivo. La escala va por DUPLICACIONES y no
# por un tope fijo, porque la vida y el maná viven en ordenes de magnitud distintos (la menor de
# vida cura 23 y la de maná da 8): con un tope comun, las de maná se quedaban todas en el mismo
# azul. Asi cada vez que una poción dobla a la anterior sube un escalon, den lo que den, y una de
# un tier futuro se colorea sola sin tocar nada.
func _t_potencia(v: float, base: float) -> float:
	if v <= base:
		return 0.0
	return clampf(log(v / base) / log(2.0) / DOBLES_AL_TOPE, 0.0, 1.0)

# La poción mas floja de cada familia (la "menor" de hoy) es el arranque de la escala.
const VIDA_BASE := 20.0
const MANA_BASE := 7.0
# Cuantas veces tiene que DOBLAR la potencia para llegar al tono mas vivo. Cuatro deja sitio de
# sobra: hoy la media es poco mas de dos dobles de la menor.
const DOBLES_AL_TOPE := 4.0

const POCION_VIDA_FLOJA := Color(0.52, 0.13, 0.16)
const POCION_VIDA_FUERTE := Color(1.00, 0.33, 0.30)
const POCION_MANA_FLOJA := Color(0.15, 0.21, 0.52)
const POCION_MANA_FUERTE := Color(0.42, 0.66, 1.00)

func es_grimorio() -> bool:
	return spell != null

func es_plato() -> bool:
	return not efectos.is_empty()

func es_vuelta_pueblo() -> bool:
	return vuelve_al_pueblo

func es_cebo() -> bool:
	return cebo_radio > 0.0

# ¿Esta poción cura VIDA? ¿da MANÁ? (para el menu y el uso).
func cura_hp() -> bool: return cura_total > 0.0 or cura_pct > 0.0
func da_mana() -> bool: return mana_total > 0.0 or mana_pct > 0.0

# --- VIDA: cura EFECTIVA total segun la vida maxima del que bebe (plano + % de max_hp) ---
func cura_efectiva(max_hp: float) -> float:
	return cura_total + cura_pct * max_hp
func cura_por_turno(max_hp: float) -> float:
	return cura_efectiva(max_hp) / float(maxi(1, turnos))
func cura_por_segundo(max_hp: float) -> float:
	return cura_efectiva(max_hp) / maxf(0.1, segundos)

# --- MANÁ: mismo modelo con el maná maximo ---
func mana_efectivo(max_mp: float) -> float:
	return mana_total + mana_pct * max_mp
func mana_por_turno(max_mp: float) -> float:
	return mana_efectivo(max_mp) / float(maxi(1, turnos))
func mana_por_segundo(max_mp: float) -> float:
	return mana_efectivo(max_mp) / maxf(0.1, segundos)

# Resumen corto del efecto para menus/HUD, p.ej. "cura 27" / "maná 10" / "cura 27 + maná 10".
# El alcance de la vuelta sale del CAMPO, nunca de la descripcion: si cambias piso_max_vuelta en el
# .tres, el texto se entera solo.
func resumen(max_hp: float, max_mp: float) -> String:
	if es_vuelta_pueblo():
		return "vuelve al pueblo (hasta el piso %d)" % piso_max_vuelta
	if es_cebo():
		return "atrae peces a %.0f px del corcho" % cebo_radio
	if es_plato():
		return resumen_plato()
	var p: Array = []
	if cura_hp():
		p.append("cura %.0f" % cura_efectiva(max_hp))
	if da_mana():
		p.append("maná %.0f" % mana_efectivo(max_mp))
	return " + ".join(p)


# FICHA de un plato: QUE te da y CUANTO dura, TODO derivado de los efectos y del catalogo de
# estados. Ni una cifra escrita a mano — la `descripcion` del .tres es sabor puro y no repite un
# solo numero, para que retocar el balance no deje el texto mintiendo.
#
# Se enseña ANTES de cocinar (en el menu del Cocinero) y tambien en el inventario: hay que poder
# decidir si merece la pena gastar los ingredientes sin haber hecho el plato una vez.
func resumen_plato() -> String:
	var lineas: PackedStringArray = []
	for ap in efectos:
		if ap == null:
			continue
		var d: Dictionary = StatusEffects.def(int(ap.estado))
		if d.is_empty():
			continue
		var que: String = StatusEffects.efecto_legible(int(ap.estado), 0.0, escala_efecto)
		lineas.append("%s %s: %s" % [str(d.get("icono", "")), str(d.get("nombre", "?")), que])
	var turnos: int = StatusEffects.PLATO_TURNOS
	for ap in efectos:
		if ap != null and int(ap.turns) > 0:
			turnos = int(ap.turns)
			break
	lineas.append("Dura %d minutos." % int(round(float(turnos) * 5.0 / 60.0)))
	return "\n".join(lineas)
