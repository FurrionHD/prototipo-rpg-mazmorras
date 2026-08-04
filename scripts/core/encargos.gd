# ============================================================
#  encargos.gd
#  ENCARGOS: mandar a la gente que tienes parada en el hogar a recolectar por RELOJ REAL.
#  Eliges piso, tipo de nodo y duracion (1 h / 4 h / 8 h), les das herramienta y mochila del cofre
#  y se van. Cuentan aunque cierres el juego.
#
#  DOS EJES INDEPENDIENTES, y es la decision que ordena todo lo demas:
#
#   1. PODER DE COMBATE -> decide SI VUELVEN BIEN. Aunque el encargo sea de mineria, ahi abajo hay
#      bichos: si no tienes poder para matarlos, pierdes y vuelves con menos y peor.
#   2. RECOLECCION -> decide QUE CALIDAD traen. Es EXACTAMENTE el sistema de siempre: la stat del
#      oficio y la afinidad de la herramienta contra la exigencia del material (_reto_recoleccion).
#      Aqui no se reescala nada de eso.
#
#  Asi cada palanca hace una cosa sola y se puede explicar en una frase: la gente y el equipo
#  deciden si vuelven; la herramienta y las stats de oficio deciden que traen.
#
#  Es una clase ESTATICA (sin autoload) para que game.gd no crezca otras 400 lineas y para que el
#  test headless pueda pedirle numeros sin levantar un mundo. Los datos vivos (stats, meta del
#  equipo, capacidad) se los pide a Game, que es un autoload y se ve desde aqui.
# ============================================================

extends RefCounted
class_name Encargos

# --- A QUE los mandas. Los cinco primeros son los mismos nodos del mapa (ResourceNode.Tipo), a
# proposito: un encargo no es contenido nuevo, es "ve al piso N y pica lo que haya alli".
# BICHO es el sexto y no tiene nodo: es salir de caza.
#
# Se elige por MULTISELECCION (el encargo guarda `tipos: Array`, no un `tipo` suelto). Marcar dos
# casillas ES el "mixto", asi que no hace falta un preset aparte. El tiempo se reparte entre lo
# marcado y cada unidad se resuelve con el oficio de SU tipo, o sea que multiseleccionar reparte
# tambien el aprendizaje: tiene un coste real y no es solo comodidad.
enum Tipo { VETA, PLANTA, MADERA, COMIDA, PESCA, BICHO }

const ESTADO_EN_CURSO := 0
const ESTADO_LISTO := 1

# Como les fue. Escala TODO en la misma proporcion 3:2:1 (excelia y cantidad), asi que se puede
# explicar en una frase: "lo que traen y lo que aprenden va por como les fue".
const EXITO := 0
const PARCIAL := 1
const FRACASO := 2
const MULT_DESENLACE := [3.0, 2.0, 1.0]          # excelia
const CANTIDAD_DESENLACE := [1.0, 2.0 / 3.0, 1.0 / 3.0]   # material: el mismo 3:2:1 normalizado
const NOMBRE_DESENLACE := ["Éxito", "A medias", "Fracaso"]

const DURACIONES := [3600, 14400, 28800]   # 1 h / 4 h / 8 h de reloj real
const MIEMBROS_MAX := 4

# Las mismas tablas que usa el piso de verdad. Cero contenido nuevo que mantener en dos sitios.
# Un tipo puede tirar de VARIAS: COMIDA junta la despensa (silvestres) y la sal, que es lo que de
# verdad se sale a buscar cuando vas a por comida — y asi los seis tipos son seis decisiones
# distintas en vez de tener una casilla para un solo material.
# BICHO no esta aqui: sus materiales se derivan de la spawn table (Game.materiales_de_bicho_en).
const TABLAS := {
	Tipo.VETA: ["res://resources/world/vetas.tres"],
	Tipo.PLANTA: ["res://resources/world/plantas.tres"],
	Tipo.MADERA: ["res://resources/world/maderas.tres"],
	Tipo.COMIDA: ["res://resources/world/silvestres.tres", "res://resources/world/sal.tres"],
	Tipo.PESCA: ["res://resources/world/peces.tres"],
}

const NOMBRE_TIPO := {
	Tipo.VETA: "Vetas", Tipo.PLANTA: "Plantas", Tipo.MADERA: "Madera",
	Tipo.COMIDA: "Comida", Tipo.PESCA: "Pesca", Tipo.BICHO: "Enemigos",
}

# A PESCAR NO SE VA SIN CAÑA. Es la regla que ya tiene el juego (Game.cana() es la unica herramienta
# sin respaldo a una basica, y el estanque te lo dice a la cara), asi que un encargo de pesca sin
# caña asignada tampoco sale. Devuelve "" si todo bien, o el motivo.
static func motivo_no_puede(tipos: Array, entradas_cofre: Array) -> String:
	if not tipos.has(int(Tipo.PESCA)):
		return ""
	for e in entradas_cofre:
		if float(mods_util(e as Dictionary, int(Tipo.PESCA))["afinidad"]) > 0.0:
			return ""
		# Una caña sin forjar no da afinidad pero SIRVE para ir: lo que no vale es no llevar ninguna.
		var d: Dictionary = (e as Dictionary).get("dict", {})
		if String(d.get("clase", "")) == "herramienta":
			var pl: ToolData = load(String(d.get("ruta", ""))) as ToolData
			if pl != null and int(pl.tipo) == int(ToolData.Tipo.CANA):
				return ""
	return "A pescar no se va sin caña: métele una del cofre."

static func tipos_validos(tipos: Array) -> Array:
	var out: Array = []
	for t in tipos:
		var i: int = int(t)
		if i >= 0 and i <= int(Tipo.BICHO) and not out.has(i):
			out.append(i)
	return out if not out.is_empty() else [int(Tipo.VETA)]


# ============================================================
#  RELOJ REAL
#  NUNCA Game.tiempo_mazmorra: ese se para con los menus abiertos y no corre con el juego cerrado,
#  que son justo los dos momentos en los que un encargo tiene que seguir avanzando.
#  El desfase de pruebas es el mismo truco que usa el cerrojo de la nube (cloud_store_local._ahora).
# ============================================================
static var desfase_prueba: int = 0

static func ahora() -> int:
	return int(Time.get_unix_time_from_system()) + desfase_prueba

static func restante(e: Dictionary) -> int:
	return maxi(0, int(e.get("t_inicio", 0)) + int(e.get("duracion", 0)) - ahora())

static func vencido(e: Dictionary) -> bool:
	return restante(e) <= 0

# "2 h 14 min" / "45 min" / "listo". Para la UI.
static func texto_restante(e: Dictionary) -> String:
	var s: int = restante(e)
	if s <= 0:
		return "listo"
	var h: int = s / 3600
	var m: int = (s % 3600) / 60
	if h > 0:
		return "%d h %d min" % [h, m]
	return "%d min" % maxi(1, m)


# ============================================================
#  EJE 1 — PODER DE COMBATE
# ============================================================
# La mitad ya existia: Game.poder_jugador_eff() ES la suma de las cinco habilidades, y es el baremo
# que Game.reto() usa contra los enemigos. Lo unico que faltaba era meterle el equipo.

# Lo que aporta UNA pieza. Sale de la meta (tier / rareza / mejoras), que es lo que el jugador ve y
# toca en el herrero, y NO de loadout_mods/armor_mods: esos devuelven numeros de combate (motion
# values, cobertura) y atarian el balance de los encargos al del combate.
const PIEZA_BASE := 4.0
# El tier vale 1.8 AQUI, y no el TIER_GROWTH 2.2 del daño. 2.2 compuesto contra una franja de
# enemigos que crece lineal (+280 por piso) se dispara: al T3 el requisito del piso tendria que
# multiplicarse por cinco para seguirte el paso. 1.8 va acompasado con lo que crecen a la vez los
# bichos y tus stats. Son dos escalas distintas a proposito.
const TIER_PODER := 1.8
const MEJORA := 0.05          # +5% por cada +1

# DESNUDO no es "tu poder entero": es una cuarta parte. El equipo MULTIPLICA, no suma un extra —
# sin nada encima no puedes hacer nada, que es como funciona el juego de verdad.
# Y crece LINEAL, sin saturar: con una curva saturada subir de T1 a T2 movia el numero un 3% y
# mejorar dejaba de notarse, que es lo contrario de lo que tiene que sentir el jugador.
const DESNUDO := 0.25
const EQUIPO_DIV := 55.0
const EQUIPO_TECHO := 12.0

static func puntos_pieza(item: Resource, meta: Dictionary) -> float:
	if item == null:
		return 0.0
	var tier: int = maxi(1, int(meta.get("tier", 1)))
	var rareza: int = int(meta.get("rareza", 0))
	var suma_n: int = 0
	for cat in (meta.get("mejoras", {}) as Dictionary):
		suma_n += int((meta["mejoras"] as Dictionary)[cat])
	return PIEZA_BASE * pow(TIER_PODER, float(tier - 1)) \
		* Upgrades.rareza_mult(rareza) * (1.0 + MEJORA * float(suma_n))

# Los puntos de equipo de una persona. El ARMA cuenta doble: es la pieza que decide si matas.
static func puntos_equipo(pj: PersonajeData) -> float:
	if pj == null:
		return 0.0
	var total: float = 0.0
	for slot in Game.EQUIP_SLOTS:
		var item: Resource = Game._item_equipado_de(slot, pj)
		if item == null:
			continue
		var p: float = puntos_pieza(item, Game._meta(slot, pj))
		total += p * 2.0 if slot == "main" else p
	return total

static func mult_equipo(pj: PersonajeData) -> float:
	return clampf(DESNUDO + puntos_equipo(pj) / EQUIPO_DIV, DESNUDO, EQUIPO_TECHO)

# EL NUMERO. El que sale en la ficha y en cada fila del hogar.
static func poder(pj: PersonajeData) -> float:
	if pj == null:
		return 0.0
	return Game.poder_jugador_eff(pj) * mult_equipo(pj)

# El del GRUPO: el que mas, entero, y los demas a fraccion. Es el hermano de RECO_REPARTO_GRUPO y
# con el mismo motivo: cuatro clones valen x2.2, no x4. Mandar mas gente compensa, pero no convierte
# a cuatro novatos en un veterano.
const REPARTO := 0.4

static func poder_grupo(pjs: Array) -> float:
	var poderes: Array = []
	for pj in pjs:
		poderes.append(poder(pj as PersonajeData))
	return poder_grupo_de(poderes)

# Lo mismo pero desde una lista de PODERES ya calculados. Hace falta para el multijugador: el
# invitado NO tiene los PersonajeData de los personajes de su compañero (viven en la maquina del
# host), asi que su poder le llega ya hecho dentro del roster.
static func poder_grupo_de(poderes: Array) -> float:
	var mejor: float = 0.0
	var suma: float = 0.0
	for p in poderes:
		suma += float(p)
		mejor = maxf(mejor, float(p))
	return mejor + REPARTO * (suma - mejor)


# --- Lo que pide el piso ---
# Sale de los enemigos REALES: Game.enemy_ability_sum_band(piso) da la franja de la suma de
# habilidades de los bichos de ese piso, en LAS MISMAS UNIDADES que poder_jugador_eff. No hay tabla
# nueva que mantener; es la curva de dificultad que ya estaba afinada.
#
# Se usa el TECHO de la franja y no la media: un encargo cruza el piso entero durante horas, o sea
# que se va a topar con lo peor que hay, no con el bicho promedio.
#
# El COEFICIENTE:
#  - Pisos 1..6: rampa suave de 0.60 a 1.25. En los tres primeros todavia no puedes pagar
#    compañeros (PRECIO_FICHAR_BASE 800 y se dobla), asi que exigir grupo ahi bloquearia el sistema
#    justo cuando estrenarlo hace mas ilusion. Uno solo tiene que poder.
#  - Del 6 en adelante: +6% por piso. La franja de enemigos crece LINEAL mientras tu poder crece
#    MULTIPLICATIVO (tier x1.8, y las stats tambien suben). Sin este termino el Minotauro saldria
#    mas facil que el Rey Slime con el equipo de su epoca.
const RETO_PISO_MIN := 0.60
const RETO_PISO_BASE := 1.25
const RETO_PISO_PLENO := 6
const RETO_PISO_PASO := 1.06

static func coef_piso(piso: int) -> float:
	var p: int = maxi(1, piso)
	if p <= RETO_PISO_PLENO:
		return lerpf(RETO_PISO_MIN, RETO_PISO_BASE,
			clampf(float(p - 1) / float(RETO_PISO_PLENO - 1), 0.0, 1.0))
	return RETO_PISO_BASE * pow(RETO_PISO_PASO, float(p - RETO_PISO_PLENO))

static func requisito_combate(piso: int) -> float:
	return maxf(1.0, coef_piso(piso) * Game.enemy_ability_sum_band(piso).y)


# --- Ratio -> % de exito ---
# El techo es 0.99 (siempre cabe la mala suerte) pero NO HAY SUELO, a proposito: un grupo con el 1%
# del poder que pide el piso no tiene "un 5% de conseguirlo", tiene practicamente cero, y redondear
# eso hacia arriba es mentirle al jugador en la unica cifra en la que se va a apoyar para decidir.
#
# El exponente 1.8 es lo que hace que la curva se DERRUMBE abajo sin ablandarse arriba:
#   r 0.01 -> 0.02%     r 0.44 -> 22%     r 0.89 -> 77%     r 1.15 -> 99%
# Con el 1.1 de antes, la mitad del poder necesario daba un 44%: media pantalla del rango util se
# iba en grupos que no tenian nada que hacer.
const EXITO_MAX := 0.99
const EXITO_MIN := 0.0
const EXITO_K := 0.95
const EXITO_POT := 1.8

static func exito(poder_del_grupo: float, piso: int) -> float:
	var r: float = poder_del_grupo / requisito_combate(piso)
	return clampf(EXITO_K * pow(maxf(0.0, r), EXITO_POT), EXITO_MIN, EXITO_MAX)

# TRES desenlaces, no cara o cruz.
#
# "A medias" NO es la mitad de lo que sobra. Repartir el resto por igual daba disparates: con un
# 0.02% de exito salia "a medias 50%", como si un grupo que no puede ni acercarse tuviera media
# posibilidad de volver con algo decente. Salir a medias es "casi lo consiguen", asi que se mide con
# LA MISMA curva contra un liston mas bajo: quien no llega ni a ese liston, fracasa.
#
#   p(exito)   = curva(r)
#   p(al menos a medias) = curva(r / UMBRAL_PARCIAL)     # el liston rebajado
#   p(a medias) = la diferencia          p(fracaso) = lo que quede
#
# Asi "a medias" hace joroba en la zona media (donde de verdad te la juegas) y se desvanece en los
# dos extremos, que es como se comporta de verdad.
const UMBRAL_PARCIAL := 0.6

static func probs_desenlace(poder_del_grupo: float, piso: int) -> Array:
	var e: float = exito(poder_del_grupo, piso)
	var hasta_parcial: float = exito(poder_del_grupo / UMBRAL_PARCIAL, piso)
	var p: float = maxf(0.0, hasta_parcial - e)
	return [e, p, maxf(0.0, 1.0 - e - p)]

# Una probabilidad (0..1) como texto. HASTA dos decimales: los porcentajes grandes se leen mejor
# redondos ("77%"), pero los pequeños hay que verlos enteros ("0.02%") o parecen todos iguales, que
# es justo lo que hacia el suelo de antes.
static func pct(p: float) -> String:
	var v: float = 100.0 * p
	if v >= 10.0:
		return "%d%%" % int(round(v))
	var s: String = "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s + "%"

static func tirar_desenlace(poder_del_grupo: float, piso: int, rng: RandomNumberGenerator) -> int:
	var p: Array = probs_desenlace(poder_del_grupo, piso)
	var x: float = rng.randf()
	if x < float(p[0]):
		return EXITO
	if x < float(p[0]) + float(p[1]):
		return PARCIAL
	return FRACASO


# ============================================================
#  EJE 2 — RECOLECCION (calidad). Aqui NO se toca nada del sistema de siempre.
# ============================================================
# La stat del oficio y el suelo son los mismos que usan los minijuegos, y la afinidad de la
# herramienta entra exactamente donde entra hoy: dentro de _reto_recoleccion.

# tipo de encargo -> [stat, suelo, tipo de herramienta que sirve]
static func oficio_de(tipo: int) -> Dictionary:
	match tipo:
		Tipo.VETA:
			return {"stat": "fuerza", "suelo": Game.MINERIA_FUERZA_FLOOR, "tool": ToolData.Tipo.PICO,
				"gain": Game.GAIN_FUERZA_MINERIA, "pivote": Game.MINERIA_PIVOTE,
				"slope": Game.MINERIA_SLOPE, "tope": Game.RETO_MAX_FISICO}
		Tipo.MADERA:
			return {"stat": "agilidad", "suelo": Game.TALA_AGILIDAD_FLOOR, "tool": ToolData.Tipo.HACHA,
				"gain": Game.GAIN_AGILIDAD_TALA, "pivote": Game.TALA_PIVOTE,
				"slope": Game.TALA_SLOPE, "tope": Game.RETO_MAX_FISICO}
		Tipo.PESCA:
			return {"stat": "resistencia", "suelo": Game.PESCA_RESISTENCIA_FLOOR,
				"tool": ToolData.Tipo.CANA, "gain": Game.GAIN_RESISTENCIA_PESCA,
				"pivote": Game.PESCA_PIVOTE, "slope": Game.PESCA_SLOPE,
				"tope": Game.RETO_MAX_FISICO}
		Tipo.BICHO:
			# CAZA. No hay herramienta que valga (un pico no sirve para despellejar) y la stat es
			# Destreza, que es la que entrena EXTRAER un cristal de un cadaver, que es literalmente lo
			# que estan haciendo. `tool` = -1 significa "aqui no entra ninguna".
			return {"stat": "destreza", "suelo": Game.EXTRACTION_DESTREZA_FLOOR, "tool": -1,
				"gain": Game.GAIN_DESTREZA_MINIJUEGO, "pivote": Game.HERB_PIVOTE,
				"slope": Game.HERB_SLOPE, "tope": Game.RETO_MAX}
		_:
			# PLANTA y COMIDA: hoz y Destreza. La sal se pica con pico, pero va dentro de COMIDA y
			# manda el oficio de la casilla: buscar comida es buscar comida.
			return {"stat": "destreza", "suelo": Game.HERB_DESTREZA_FLOOR, "tool": ToolData.Tipo.HOZ,
				"gain": Game.GAIN_DESTREZA_PLANTA, "pivote": Game.HERB_PIVOTE,
				"slope": Game.HERB_SLOPE, "tope": Game.RETO_MAX}

static func tablas_de(tipo: int) -> Array:
	var out: Array = []
	for ruta in (TABLAS.get(tipo, []) as Array):
		var t: MaterialTable = load(String(ruta)) as MaterialTable
		if t != null:
			out.append(t)
	return out

# Lo que puede salir de un tipo en un piso, como [{"material", "peso"}]. Unifica las dos fuentes:
# las MaterialTable de siempre y, para BICHO, lo que sueltan los bichos del piso.
#
# Cuando un tipo tiene VARIAS tablas (COMIDA), los pesos de cada una se NORMALIZAN antes de juntarse:
# si no, la sal (peso 100 en una tabla de una sola entrada) aplastaria a las cuatro silvestres, que
# se reparten pesos mucho menores. Normalizando, cada tabla aporta la mitad y dentro de ella manda su
# propio reparto, que es lo que se espera al marcar una casilla que junta dos cosas.
static func opciones(tipo: int, piso: int) -> Array:
	if tipo == Tipo.BICHO:
		return Game.materiales_de_bicho_en(piso)
	var tablas: Array = tablas_de(tipo)
	var out: Array = []
	for t in tablas:
		var disp: Array = (t as MaterialTable).disponibles(piso)
		var total: float = 0.0
		for e in disp:
			total += e.peso_en(piso)
		if total <= 0.0:
			continue
		for e in disp:
			out.append({"material": e.material, "peso": e.peso_en(piso) / total})
	return out

static func elegir_material(tipo: int, piso: int, rng: RandomNumberGenerator) -> MaterialData:
	var pool: Array = opciones(tipo, piso)
	if pool.is_empty():
		return null
	var total: float = 0.0
	for o in pool:
		total += float(o["peso"])
	if total <= 0.0:
		return null
	var tirada: float = rng.randf() * total
	for o in pool:
		tirada -= float(o["peso"])
		if tirada <= 0.0:
			return o["material"] as MaterialData
	return (pool.back() as Dictionary)["material"] as MaterialData

# La exigencia MEDIA de lo que sale de ese tipo en ese piso, ponderada por sus pesos. Es lo que usa
# la excelia (una sola cifra por tipo) y el pronostico de la UI.
# Para BICHO da 0: sus materiales no tienen exigencia porque no se recolectan (ver mas abajo).
static func exigencia_media(tipo: int, piso: int) -> float:
	var pool: Array = opciones(tipo, piso)
	var suma: float = 0.0
	var peso: float = 0.0
	for o in pool:
		suma += Game._exigencia_material(o["material"] as MaterialData, piso) * float(o["peso"])
		peso += float(o["peso"])
	return suma / maxf(0.001, peso)

# Lo bien preparados que van para ESE material. >= 1 es ir sobrado. Es el inverso de
# _reto_recoleccion, que devuelve "lo dificil que te resulta".
static func poder_recolector(pjs: Array, tipo: int, afinidad: float) -> float:
	var of: Dictionary = oficio_de(tipo)
	var valores: Array = []
	for pj in pjs:
		valores.append(Game.stat_total_eff(String(of["stat"]), pj as PersonajeData))
	return poder_recolector_de(valores, tipo, afinidad)

# Desde una lista con LA STAT DEL OFICIO de cada uno, por lo mismo que poder_grupo_de: en multi el
# invitado recibe las stats del compañero dentro del roster, no sus PersonajeData.
static func poder_recolector_de(valores: Array, tipo: int, afinidad: float) -> float:
	var of: Dictionary = oficio_de(tipo)
	var suma: float = 0.0
	var mejor: float = 0.0
	for v in valores:
		suma += float(v)
		mejor = maxf(mejor, float(v))
	# Mismo reparto que el combate: el que mas sabe lleva la voz cantante.
	var stat: float = mejor + REPARTO * (suma - mejor)
	return stat * Game.RECOLECCION_STAT_PESO + float(of["suelo"]) + afinidad

static func ratio_material(m: MaterialData, piso: int, poder_reco: float) -> float:
	return poder_reco / maxf(1.0, Game._exigencia_material(m, piso))

# El ratio que decide la CALIDAD de una unidad, segun su tipo.
#
# Los materiales de monstruo tienen exigencia 0.0 en sus .tres, y no es un olvido: no se recolectan,
# se sacan de un cadaver. Asi que para BICHO no hay eje de herramienta que valga y la calidad la
# decide el COMBATE (r_c). Es ademas lo que hace el juego hoy: la calidad del drop sale de
# _calidad_material_de_cristal(), o sea de lo bien que rematas.
static func ratio_calidad(tipo: int, m: MaterialData, piso: int, poder_reco: float,
		r_combate: float) -> float:
	if tipo == Tipo.BICHO:
		return r_combate
	return ratio_material(m, piso, poder_reco)

# Ratio -> reparto de calidades. Calibrado con el ejemplo del jugador: exigencia 150 contra 100 de
# poder recolector (r = 0.667) tiene que dar mas o menos 30 dañado / 50 normal / 20 intacto.
# PURO no sale de un encargo (es el techo de Metalurgia) y ROTO tampoco se genera: fallar se modela
# como cantidad perdida y calidad peor, no como piezas rotas invisibles.
static func reparto_calidades(r: float) -> Dictionary:
	var intacto: float = clampf(0.45 * r - 0.10, 0.0, 0.70)
	var danado: float = 0.75 * pow(clampf(1.0 - r, 0.0, 1.0), 0.8)
	var normal: float = maxf(0.0, 1.0 - intacto - danado)
	return {"intacto": intacto, "normal": normal, "danado": danado}

static func calidad_tirada(r: float, rng: RandomNumberGenerator) -> int:
	var p: Dictionary = reparto_calidades(r)
	var x: float = rng.randf()
	if x < float(p["intacto"]):
		return MaterialItem.Calidad.INTACTO
	if x < float(p["intacto"]) + float(p["normal"]):
		return MaterialItem.Calidad.NORMAL
	return MaterialItem.Calidad.DANADO

# Un escalon MENOS de calidad. Es lo que se lleva la derrota: no solo traen menos, traen peor.
static func bajar_calidad(cal: int) -> int:
	match cal:
		MaterialItem.Calidad.INTACTO: return MaterialItem.Calidad.NORMAL
		MaterialItem.Calidad.NORMAL: return MaterialItem.Calidad.DANADO
		_: return MaterialItem.Calidad.DANADO


# ============================================================
#  CANTIDAD
# ============================================================
# El excedente de poder NO da mas cantidad: va entero a exito y a calidad. Es lo que hace legible el
# sistema ("ir sobrado mejora lo que traen, no cuanto").
#
# UNID_HORA es EL mando de balance de todo esto. Referencia contra jugar: un nodo de mineria son
# unos 15-25 s mas el transito, o sea del orden de 60-100 unidades por hora jugando. Un encargo de
# 8 h con cuatro personas da 64. Nunca puede compensar mas que jugar.
# Cuanto RECOGEN por hora y persona. Es alto a proposito: lo que tiene que limitar un encargo largo
# es LO QUE PUEDEN CARGAR, no el reloj. Con el 2.0 de antes, tres personas ocho horas juntaban 50
# unidades y les cabian 100: la mochila no pintaba absolutamente nada y el tope de peso no llegaba a
# morder nunca. Ahora juntan mas de lo que pueden llevar casi siempre, tiran lo peor, y una mochila
# mejor es directamente mas botin.
#
# Los encargos CORTOS siguen limitados por el tiempo (1 h a solas son 6 unidades y en el zurron
# caben ~14), asi que la curva es: de poco rato manda el reloj, de mucho manda la espalda.
const UNID_HORA := 6.0
const GOLPES_UNID := 0.04
# Techo de carga: pueden volver SOBRECARGADOS (overload_threshold es 0.9), pero no mas alla de esto.
# Es el limite duro que hace que la mochila sea una decision y no un adorno.
const CARGA_MAX := 1.10

# Lo que TRABAJAN: lo que da el tiempo. NO es lo que se traen (eso lo recorta el peso, ver abajo).
static func unidades(duracion: int, n_miembros: int, golpes_menos: int, factor: float) -> int:
	var horas: float = float(duracion) / 3600.0
	return maxi(1, int(round(UNID_HORA * horas * float(maxi(1, n_miembros)) * factor
		* (1.0 + GOLPES_UNID * float(golpes_menos)))))

# Reparte n unidades entre los tipos marcados, a partes lo mas iguales posible y sin perder ninguna
# por el redondeo (las que sobran van a los primeros de la lista).
static func repartir(n: int, tipos: Array) -> Dictionary:
	var out: Dictionary = {}
	var k: int = maxi(1, tipos.size())
	var base: int = n / k
	var resto: int = n % k
	for i in tipos.size():
		out[int(tipos[i])] = base + (1 if i < resto else 0)
	return out


# ============================================================
#  TOPE DE PESO: nunca se traen mas del 110% de lo que pueden cargar
# ============================================================
# Devuelve {"traidas": Array, "perdido": int, "kg": float}. Recorta SIEMPRE por la peor calidad
# primero, asi lo que sobrevive al recorte es lo bueno.
#
# OJO: esto solo recorta el BOTIN. La excelia va por las unidades TRABAJADAS, porque el trabajo lo
# hicieron igual aunque tuvieran que dejar sacos atras; si no, mandar gente sin mochila les cobraria
# dos veces (menos material Y menos aprendizaje).
static func recortar_por_peso(piezas: Array, tope_kg: float) -> Dictionary:
	var total: float = 0.0
	for p in piezas:
		total += _peso_de(p)
	if total <= tope_kg:
		return {"traidas": piezas, "perdido": 0, "kg": total}
	# De peor a mejor calidad. OJO: NO se puede ordenar por el valor del enum, porque
	# MaterialItem.Calidad NO esta en orden de calidad (PURO es el 4, el ultimo, y es el mejor de
	# todos). Ordenar por el int dejaria lo mejor el primero en tirarse. Va por rango explicito.
	var orden: Array = piezas.duplicate()
	orden.sort_custom(func(a, b): return _rango_calidad(int(a["calidad"])) < _rango_calidad(int(b["calidad"])))
	var fuera: int = 0
	while total > tope_kg and not orden.is_empty():
		total -= _peso_de(orden[0])
		orden.remove_at(0)
		fuera += 1
	return {"traidas": orden, "perdido": fuera, "kg": total}

static func _peso_de(pieza: Dictionary) -> float:
	var m: MaterialData = pieza["material"] as MaterialData
	if m == null:
		return 0.1
	return maxf(0.1, m.peso_base * _peso_mult(int(pieza["calidad"])))

# Rango REAL de calidad, de peor (0) a mejor (4). Existe porque el enum no sirve para ordenar.
static func _rango_calidad(cal: int) -> int:
	match cal:
		MaterialItem.Calidad.ROTO: return 0
		MaterialItem.Calidad.DANADO: return 1
		MaterialItem.Calidad.NORMAL: return 2
		MaterialItem.Calidad.INTACTO: return 3
		_: return 4   # PURO

static func _peso_mult(cal: int) -> float:
	match cal:
		MaterialItem.Calidad.NORMAL: return 0.9
		MaterialItem.Calidad.DANADO: return 0.7
		_: return 1.0

# ============================================================
#  LOS UTILES DEL COFRE
#  Se leen del DICT SERIALIZADO de la entrada del cofre, nunca deserializandolo.
#  Deserializar registraria una copia en el baul cada vez que se mira un encargo, que es exactamente
#  el bug de las 6 hachas. Y no hace falta: el dict ya trae tier, rareza, banda y capacidad.
# ============================================================

# Afinidad y golpes_menos de una herramienta del cofre, por TIPO de encargo. 0 si no es del tipo que
# toca (un pico no sirve para plantas) o si es de las basicas (esas no tienen entrada en item_meta).
static func mods_util(entrada: Dictionary, tipo: int) -> Dictionary:
	var nada := {"afinidad": 0.0, "golpes_menos": 0}
	var d: Dictionary = entrada.get("dict", {})
	if String(d.get("clase", "")) != "herramienta":
		return nada
	var quiere: int = int(oficio_de(tipo).get("tool", -1))
	if quiere < 0:
		return nada   # los BICHOS no llevan herramienta
	var plantilla: ToolData = load(String(d.get("ruta", ""))) as ToolData
	if plantilla == null or int(plantilla.tipo) != quiere:
		return nada
	return Upgrades.tool_mods(int(plantilla.tipo), int(d.get("tier", 1)),
		int(d.get("rareza", 0)), int(d.get("banda", 0)))

# Capacidad que aporta una mochila del cofre. Misma cuenta que Game.capacidad_mochila, pero desde el
# dict: capacidad base x factor de tier x multiplicador de rareza.
static func capacidad_util(entrada: Dictionary) -> float:
	var d: Dictionary = entrada.get("dict", {})
	if String(d.get("clase", "")) != "mochila":
		return 0.0
	return float(d.get("capacidad", 0)) * Game.mochila_tier_factor(int(d.get("tier", 1))) \
		* Upgrades.rareza_mult_capacidad(int(d.get("rareza", 0)))

# Lo que puede cargar la cuadrilla, ya con el 110% aplicado. `entradas` son las del cofre asignadas.
static func tope_carga(pjs: Array, entradas: Array) -> float:
	return CARGA_MAX * Game._capacidad_con(Game.base_capacity + _capacidad_utiles(entradas),
		_saturacion_utiles(entradas), pjs)

# La misma cuenta desde una lista de FUERZAS, para el pronostico del invitado (que no tiene los
# PersonajeData del compañero). Se replica lo que hace Game._capacidad_con: media de Fuerza para el
# multiplicador y +15% de contenedor por cada acompañante.
static func tope_carga_de(fuerzas: Array, entradas: Array) -> float:
	var n: int = maxi(1, fuerzas.size())
	var suma: float = 0.0
	for f in fuerzas:
		suma += float(f)
	var media: float = suma / float(n)
	var sat: float = _saturacion_utiles(entradas)
	var mult: float = 1.0 + clampf(media / maxf(1.0, sat), 0.0, 1.0) * Game.fuerza_capacity_bonus_max
	var manos: float = 1.0 + Game.CARGA_POR_ACOMPANANTE * float(n - 1)
	return CARGA_MAX * (Game.base_capacity + _capacidad_utiles(entradas)) * mult * manos

static func _capacidad_utiles(entradas: Array) -> float:
	var extra: float = 0.0
	for e in entradas:
		extra += capacidad_util(e as Dictionary)
	return extra

# La saturacion de Fuerza la marca la MEJOR mochila (mismo criterio que Game).
static func _saturacion_utiles(entradas: Array) -> float:
	var mejor_tier: int = 0
	for e in entradas:
		if capacidad_util(e as Dictionary) <= 0.0:
			continue
		mejor_tier = maxi(mejor_tier, int(((e as Dictionary).get("dict", {}) as Dictionary).get("tier", 1)))
	if mejor_tier <= 0:
		return Game.SATURACION_SIN_MOCHILA
	return float(Game.MOCHILA_FUERZA_SATURACION[
		clampi(mejor_tier, 1, Game.MOCHILA_FUERZA_SATURACION.size()) - 1])


# ============================================================
#  EXCELIA: lo que APRENDEN los que van
# ============================================================
# Dos ganancias, una por eje, porque han hecho dos cosas: recolectar y pelearse con lo que salia.
#
# GAIN_FACTOR esta POR DEBAJO de RECO_REPARTO_GRUPO (0.4) a proposito: ir de encargo tiene que
# enseñar MENOS por unidad que estar delante mirando como otro pica. Un encargo son horas de reloj
# real, no de juego; si rentara igual, jugar seria tonteria.
const GAIN_FACTOR := 0.35
const GAIN_RECO := 0.70          # reparto del presupuesto entre los dos ejes
const GAIN_COMBATE := 0.30
# Cuantos "nodos equivalentes" por hora y persona vale APRENDER en un encargo. Va aparte de
# UNID_HORA (que es cuanto RECOGEN) a proposito, y son numeros distintos porque miden cosas
# distintas: lo que se traen lo corta la espalda, pero lo que aprenden no depende de si tuvieron que
# dejar sacos atras. Si esto colgara de UNID_HORA, subirle el ritmo de recogida para que la mochila
# importara habria triplicado la excelia de rebote.
const RITMO_EXCELIA := 2.0
# Cuanto entrena una hora de pelearse con los bichos del piso. Anclado a lo que da encajar golpes en
# combate (GAIN_RESISTENCIA_GOLPE 0.345): una hora ahi abajo son unos cuantos encontronazos.
const GAIN_COMBATE_HORA := 0.9

# Devuelve la lista de ganancias a aplicar: [{"uid", "abil", "base", "reto", "max_reto"}].
# NO las aplica: quien las aplique tiene que llamar a Game.ganar() con el PersonajeData correcto, que
# en multi puede vivir en otra maquina (ver la nota de las dos vias en net.gd).
# 'trabajadas' = {tipo: unidades} (las TRABAJADAS, no las traidas), 'afinidades' = {tipo: afinidad}.
# 'desenlace' escala todo por MULT_DESENLACE (x3 / x2 / x1).
static func excelia_de(pjs: Array, piso: int, duracion: int, trabajadas: Dictionary,
		afinidades: Dictionary, r_combate: float, desenlace: int) -> Array:
	var horas: float = float(duracion) / 3600.0
	var n: int = maxi(1, pjs.size())
	var req: float = requisito_combate(piso)
	var mult: float = float(MULT_DESENLACE[clampi(desenlace, 0, 2)])
	# El reparto entre tipos se mide en CUOTA (que parte del rato dedicaron a cada cosa), no en
	# unidades sueltas: asi el desenlace entra UNA sola vez, por `mult`. Antes entraba dos veces --
	# tambien venia dentro del recuento de unidades, que ya llevaba CANTIDAD_DESENLACE-- y eso hacia
	# que un fracaso enseñara nueve veces menos que un exito en vez de tres.
	var total_uds: float = 0.0
	for tipo in trabajadas:
		total_uds += float(trabajadas[tipo])
	var salida: Array = []
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj == null:
			continue
		# --- A) por RECOLECTAR, UNA VEZ POR TIPO MARCADO. Cada tipo entrena SU stat: por eso
		# multiseleccionar reparte tambien el aprendizaje, y no es solo comodidad.
		for tipo in trabajadas:
			var uds: int = int(trabajadas[tipo])
			if uds <= 0:
				continue
			var cuota: float = float(uds) / maxf(1.0, total_uds)
			var of: Dictionary = oficio_de(int(tipo))
			var afin: float = float(afinidades.get(tipo, 0.0))
			# El reto es POR PERSONA: al mas flojo del grupo le enseña mas, igual que en los
			# minijuegos. Y con SU stat, no con la del grupo.
			var reto_r: float
			if int(tipo) == Tipo.BICHO:
				# Sin exigencia que medir (vale 0 en sus .tres): el reto es el del combate.
				reto_r = clampf(r_combate_a_reto(r_combate), 0.0, float(of["tope"]))
			else:
				var suyo: float = Game.stat_total_eff(String(of["stat"]), pj) \
					* Game.RECOLECCION_STAT_PESO + float(of["suelo"]) + afin
				reto_r = Game.curva_reto(exigencia_media(int(tipo), piso) / maxf(1.0, suyo),
					float(of["pivote"]), float(of["slope"]), float(of["tope"]))
			salida.append({
				"uid": pj.uid, "abil": String(of["stat"]), "reto": reto_r,
				"max_reto": float(of["tope"]),
				# Por HORAS trabajadas, no por unidades traidas: currar ocho horas enseña lo mismo
				# aunque la mochila les obligara a dejar la mitad tirada.
				"base": float(of["gain"]) * GAIN_FACTOR * GAIN_RECO * mult
					* horas * RITMO_EXCELIA * cuota,
			})
		# --- B) por PELEAR. Game.reto() es la misma funcion que usa el combate, y el requisito del
		# piso ya esta en su escala (suma de habilidades), asi que entra tal cual.
		var reto_c: float = Game.reto(req, 1, pj)
		var base_c: float = GAIN_COMBATE_HORA * GAIN_FACTOR * GAIN_COMBATE * horas * mult
		for abil in ["fuerza", "resistencia"]:
			salida.append({"uid": pj.uid, "abil": abil, "reto": reto_c,
				"max_reto": Game.RETO_MAX_FISICO, "base": base_c * 0.5})
	return salida

# El ratio de combate, leido como "reto": ir justo enseña, ir sobrado no. Es el inverso del ratio,
# con la misma forma que curva_reto le da a los oficios.
static func r_combate_a_reto(r: float) -> float:
	return Game.curva_reto(1.0 / maxf(0.05, r), Game.HERB_PIVOTE, Game.HERB_SLOPE, Game.RETO_MAX)


# ============================================================
#  RESOLVER un encargo: la unica funcion que tira dados
# ============================================================
# Sembrada con encargo.semilla, asi que el resultado es REPRODUCIBLE: se puede volver a calcular
# igual para depurar, y en multi el host lo resuelve una vez y difunde el resultado ya cocido.
#
# Devuelve el informe: {"desenlace", "botin", "excelia", "trabajadas", "traidas", "perdido", "ratio"}.
# NO toca nada de Game: quien lo llame decide cuando y donde aplicar el botin y la excelia.
static func resolver(e: Dictionary, pjs: Array, entradas_cofre: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e.get("semilla", 0))

	var piso: int = int(e.get("piso", 1))
	var duracion: int = int(e.get("duracion", 3600))
	var tipos: Array = tipos_validos(e.get("tipos", []))
	var n: int = maxi(1, pjs.size())

	# --- Eje 1: ¿vuelven bien?
	var pg: float = poder_grupo(pjs)
	var r_c: float = pg / requisito_combate(piso)
	var desenlace: int = tirar_desenlace(pg, piso, rng)

	# --- Lo que aportan los utiles, por tipo.
	var afinidades: Dictionary = {}
	var golpes: int = 0
	for tipo in tipos:
		var mejor: float = 0.0
		for entrada in entradas_cofre:
			var m: Dictionary = mods_util(entrada as Dictionary, int(tipo))
			if float(m["afinidad"]) > mejor:
				mejor = float(m["afinidad"])
				golpes = maxi(golpes, int(m["golpes_menos"]))
		afinidades[int(tipo)] = mejor

	# --- Cuanto TRABAJAN (esto es lo que da la excelia; el botin lo recorta el peso despues).
	var trabajadas: int = unidades(duracion, n, golpes, float(CANTIDAD_DESENLACE[desenlace]))
	var por_tipo: Dictionary = repartir(trabajadas, tipos)

	# --- Eje 2: que sacan y con que calidad.
	var piezas: Array = []
	for tipo in por_tipo:
		var t: int = int(tipo)
		var poder_reco: float = poder_recolector(pjs, t, float(afinidades.get(t, 0.0)))
		for i in int(por_tipo[tipo]):
			var m: MaterialData = elegir_material(t, piso, rng)
			if m == null:
				continue
			var r_m: float = ratio_calidad(t, m, piso, poder_reco, r_c)
			var cal: int = calidad_tirada(r_m, rng)
			# Perder no solo recorta la cantidad: lo que traen viene PEOR. A medias, la mitad.
			if desenlace == FRACASO or (desenlace == PARCIAL and rng.randf() < 0.5):
				cal = bajar_calidad(cal)
			# Un PEZ sin talla no es un pez: el peso, el valor y la corona salen de sus centimetros.
			# Misma tirada que usa el estanque (MaterialData.tirada_talla), con el rng del encargo.
			var cm: float = m.talla_desde(MaterialData.tirada_talla(rng)) if m.cm_max > 0.0 else 0.0
			piezas.append({"material": m, "calidad": cal, "cm": cm})

	# --- El tope de peso. Solo recorta el BOTIN: la excelia va por `trabajadas`.
	var corte: Dictionary = recortar_por_peso(piezas, tope_carga(pjs, entradas_cofre))

	# Agrupar por (ruta, calidad, talla) para que el encargo guarde poco y viaje ligero. La TALLA
	# entra en la clave a proposito: dos peces del mismo tipo no son el mismo pez, y de sus
	# centimetros salen el valor y la corona. Lo que no es pez lleva cm 0 y se agrupa como siempre.
	var cuenta: Dictionary = {}
	for p in corte["traidas"]:
		var clave: String = "%s|%d|%.1f" % [(p["material"] as MaterialData).resource_path,
			int(p["calidad"]), float(p.get("cm", 0.0))]
		cuenta[clave] = int(cuenta.get(clave, 0)) + 1
	var botin: Array = []
	for clave in cuenta:
		var partes: PackedStringArray = clave.split("|")
		botin.append({"ruta": partes[0], "calidad": int(partes[1]), "cm": float(partes[2]),
			"n": int(cuenta[clave])})

	return {
		"desenlace": desenlace,
		"botin": botin,
		"excelia": excelia_de(pjs, piso, duracion, por_tipo, afinidades, r_c, desenlace),
		"trabajadas": trabajadas,
		"traidas": (corte["traidas"] as Array).size(),
		"perdido": int(corte["perdido"]),
		"ratio": r_c,
	}
