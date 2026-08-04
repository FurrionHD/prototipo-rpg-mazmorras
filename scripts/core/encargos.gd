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

# --- Tipos de encargo. Son los mismos que los nodos del mapa (ResourceNode.Tipo), a proposito: un
# encargo no es contenido nuevo, es "ve al piso N y pica lo que haya alli".
enum Tipo { VETA, PLANTA, MADERA, SAL, HUERTO }

const ESTADO_EN_CURSO := 0
const ESTADO_LISTO := 1

const DURACIONES := [3600, 14400, 28800]   # 1 h / 4 h / 8 h de reloj real
const MIEMBROS_MAX := 4

# Las mismas tablas que usa el piso de verdad. Cero contenido nuevo que mantener en dos sitios.
const TABLAS := {
	Tipo.VETA: "res://resources/world/vetas.tres",
	Tipo.PLANTA: "res://resources/world/plantas.tres",
	Tipo.MADERA: "res://resources/world/maderas.tres",
	Tipo.SAL: "res://resources/world/sal.tres",
	Tipo.HUERTO: "res://resources/world/silvestres.tres",
}

const NOMBRE_TIPO := {
	Tipo.VETA: "Vetas", Tipo.PLANTA: "Plantas", Tipo.MADERA: "Madera",
	Tipo.SAL: "Sal", Tipo.HUERTO: "Silvestres",
}


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
	var mejor: float = 0.0
	var suma: float = 0.0
	for pj in pjs:
		var p: float = poder(pj as PersonajeData)
		suma += p
		mejor = maxf(mejor, p)
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
# Nunca 0% ni 100%: siempre cabe la suerte, buena o mala.
const EXITO_MAX := 0.99
const EXITO_MIN := 0.05
const EXITO_K := 0.95
const EXITO_POT := 1.1

static func exito(poder_del_grupo: float, piso: int) -> float:
	var r: float = poder_del_grupo / requisito_combate(piso)
	return clampf(EXITO_K * pow(maxf(0.0, r), EXITO_POT), EXITO_MIN, EXITO_MAX)


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
		Tipo.SAL:
			return {"stat": "fuerza", "suelo": Game.MINERIA_FUERZA_FLOOR, "tool": ToolData.Tipo.PICO,
				"gain": Game.GAIN_FUERZA_MINERIA, "pivote": Game.MINERIA_PIVOTE,
				"slope": Game.MINERIA_SLOPE, "tope": Game.RETO_MAX_FISICO}
		Tipo.MADERA:
			return {"stat": "agilidad", "suelo": Game.TALA_AGILIDAD_FLOOR, "tool": ToolData.Tipo.HACHA,
				"gain": Game.GAIN_AGILIDAD_TALA, "pivote": Game.TALA_PIVOTE,
				"slope": Game.TALA_SLOPE, "tope": Game.RETO_MAX_FISICO}
		_:
			# PLANTA y HUERTO: hoz y Destreza.
			return {"stat": "destreza", "suelo": Game.HERB_DESTREZA_FLOOR, "tool": ToolData.Tipo.HOZ,
				"gain": Game.GAIN_DESTREZA_PLANTA, "pivote": Game.HERB_PIVOTE,
				"slope": Game.HERB_SLOPE, "tope": Game.RETO_MAX}

static func tabla_de(tipo: int) -> MaterialTable:
	var ruta: String = String(TABLAS.get(tipo, TABLAS[Tipo.VETA]))
	return load(ruta) as MaterialTable

# Lo bien preparados que van para ESE material. >= 1 es ir sobrado. Es el inverso de
# _reto_recoleccion, que devuelve "lo dificil que te resulta".
static func poder_recolector(pjs: Array, tipo: int, afinidad: float) -> float:
	var of: Dictionary = oficio_de(tipo)
	var suma: float = 0.0
	var mejor: float = 0.0
	for pj in pjs:
		var s: float = Game.stat_total_eff(String(of["stat"]), pj as PersonajeData)
		suma += s
		mejor = maxf(mejor, s)
	# Mismo reparto que el combate: el que mas sabe lleva la voz cantante.
	var stat: float = mejor + REPARTO * (suma - mejor)
	return stat * Game.RECOLECCION_STAT_PESO + float(of["suelo"]) + afinidad

static func ratio_material(m: MaterialData, piso: int, poder_reco: float) -> float:
	return poder_reco / maxf(1.0, Game._exigencia_material(m, piso))

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
const UNID_HORA := 2.0
const GOLPES_UNID := 0.04
const DERROTA_MIN := 0.35
const DERROTA_MAX := 0.70

static func unidades(duracion: int, n_miembros: int, golpes_menos: int, factor: float) -> int:
	var horas: float = float(duracion) / 3600.0
	return maxi(1, int(round(UNID_HORA * horas * float(maxi(1, n_miembros)) * factor
		* (1.0 + GOLPES_UNID * float(golpes_menos)))))


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
# Cuanto entrena una hora de pelearse con los bichos del piso. Anclado a lo que da encajar golpes en
# combate (GAIN_RESISTENCIA_GOLPE 0.345): una hora ahi abajo son unos cuantos encontronazos.
const GAIN_COMBATE_HORA := 0.9

# Devuelve la lista de ganancias a aplicar: [{"uid", "abil", "base", "reto", "max_reto"}].
# NO las aplica: quien las aplique tiene que llamar a Game.ganar() con el PersonajeData correcto, que
# en multi puede vivir en otra maquina (ver la nota de las dos vias en net.gd).
static func excelia_de(pjs: Array, tipo: int, piso: int, duracion: int,
		unids: int, exigencia_media: float, afinidad: float) -> Array:
	var of: Dictionary = oficio_de(tipo)
	var horas: float = float(duracion) / 3600.0
	var n: int = maxi(1, pjs.size())
	var req: float = requisito_combate(piso)
	var salida: Array = []
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj == null:
			continue
		# --- A) por RECOLECTAR. El reto es POR PERSONA: al mas flojo del grupo le enseña mas, igual
		# que en los minijuegos. Y con SU stat, no con la del grupo.
		var suyo: float = Game.stat_total_eff(String(of["stat"]), pj) * Game.RECOLECCION_STAT_PESO \
			+ float(of["suelo"]) + afinidad
		var reto_r: float = Game.curva_reto(exigencia_media / maxf(1.0, suyo),
			float(of["pivote"]), float(of["slope"]), float(of["tope"]))
		salida.append({
			"uid": pj.uid, "abil": String(of["stat"]), "reto": reto_r,
			"max_reto": float(of["tope"]),
			"base": float(of["gain"]) * GAIN_FACTOR * GAIN_RECO * (float(unids) / float(n)),
		})
		# --- B) por PELEAR. Game.reto() es la misma funcion que usa el combate, y el requisito del
		# piso ya esta en su escala (suma de habilidades), asi que entra tal cual.
		var reto_c: float = Game.reto(req, 1, pj)
		var base_c: float = GAIN_COMBATE_HORA * GAIN_FACTOR * GAIN_COMBATE * horas
		for abil in ["fuerza", "resistencia"]:
			salida.append({"uid": pj.uid, "abil": abil, "reto": reto_c,
				"max_reto": Game.RETO_MAX_FISICO, "base": base_c * 0.5})
	return salida
