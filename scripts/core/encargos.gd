# ============================================================
#  encargos.gd
#  ENCARGOS: mandar a la gente que tienes parada en el hogar a por material por RELOJ REAL.
#  Eliges el OBJETIVO (grupos de material con su porcentaje), el piso y la duracion (1 h / 4 h / 8 h),
#  les das utiles del cofre y se van. Cuentan aunque cierres el juego.
#
#  REWORK DEL 15/09/2026 (lo dicto el jefe, pieza a pieza). Lo que ordena todo:
#
#   1. RECOGER tiene TOPE POR PERSONA: 4 unidades por hora cada uno (mineral, madera, plantas,
#      comida y pescado). Antes una cuadrilla de cuatro ocho horas te resolvia la vida entera.
#   2. CAZAR va por ENEMIGOS DE VERDAD: 5 peleas por hora contra (personas + 1) bichos sacados de la
#      tabla de spawn del piso, y cada uno suelta lo SUYO con SU probabilidad. Si pides cuero y te
#      tocan slimes, no hay cuero. De cada baja sale ademas su cristal, que se vende al recoger.
#   3. LA CALIDAD VA POR PERSONA, con la stat de quien lo recoge: el de 450 de Fuerza trae el hierro
#      intacto y el de 100 lo trae dañado, o lo rompe.
#   4. EL DESENLACE es una curva por anclas y CASTIGA POCO Y SIN AZAR: parcial -20% de cada grupo,
#      fracaso -40%.
#
#  Es una clase ESTATICA (sin autoload) para que game.gd no crezca y para que el simulador headless
#  pueda pedirle numeros sin levantar un mundo. Los datos vivos se los pide a Game.
# ============================================================

extends RefCounted
class_name Encargos

# --- EL OBJETIVO: a por que van. Grupos de material, NO los nodos del mapa: al jugador le importa
# traer cuero o nucleos, no "ir a por bichos".
enum Grupo { MINERAL, MADERA, PLANTA, COMIDA, PESCADO, CUERO, NUCLEO, POCION, CRISTAL }

# Los que se RECOGEN (gastan las 4 por hora de cada persona) y los que salen de lo que CAZAN (van por
# bajas, sin tope). La COMIDA esta en los dos lados: se recoge (setas, tuberculos, sal) y ademas los
# bichos sueltan carne.
const RECOGIBLES := [Grupo.MINERAL, Grupo.MADERA, Grupo.PLANTA, Grupo.COMIDA, Grupo.PESCADO]
const DE_CAZA := [Grupo.CUERO, Grupo.NUCLEO, Grupo.POCION, Grupo.CRISTAL]

const NOMBRE_GRUPO := {
	Grupo.MINERAL: "Mineral", Grupo.MADERA: "Madera", Grupo.PLANTA: "Plantas",
	Grupo.COMIDA: "Comida", Grupo.PESCADO: "Pescado", Grupo.CUERO: "Cuero",
	Grupo.NUCLEO: "Núcleos", Grupo.POCION: "Materiales de poción", Grupo.CRISTAL: "Cristales",
}

const ESTADO_EN_CURSO := 0
const ESTADO_LISTO := 1

const EXITO := 0
const PARCIAL := 1
const FRACASO := 2
const NOMBRE_DESENLACE := ["Éxito", "Éxito parcial", "Fracaso"]

# LO QUE CUESTA CADA DESENLACE, fijo y sin azar: la parte de cada grupo que se pierde. Y lo que
# aprenden baja en la misma proporcion (una sola regla para todo, decidido asi).
# Antes un fracaso bajaba la calidad a suertes y pagaba segun las probabilidades: "era el terrorismo".
const PERDIDA := [0.0, 0.20, 0.40]

static func mult_desenlace(desenlace: int) -> float:
	return 1.0 - float(PERDIDA[clampi(desenlace, 0, PERDIDA.size() - 1)])

const DURACIONES := [3600, 14400, 28800]   # 1 h / 4 h / 8 h de reloj real
const MIEMBROS_MAX := 4

# Las mismas tablas que usa el piso de verdad. Solo los RECOGIBLES: lo de caza sale de la spawn table.
const TABLAS := {
	Grupo.MINERAL: ["res://resources/world/vetas.tres"],
	Grupo.PLANTA: ["res://resources/world/plantas.tres"],
	Grupo.MADERA: ["res://resources/world/maderas.tres"],
	Grupo.COMIDA: ["res://resources/world/silvestres.tres", "res://resources/world/sal.tres"],
	Grupo.PESCADO: ["res://resources/world/peces.tres"],
}

static func es_recogible(g: int) -> bool:
	return RECOGIBLES.has(g)

static func es_de_caza(g: int) -> bool:
	return DE_CAZA.has(g)


# ============================================================
#  EL OBJETIVO: {grupo: porcentaje}, y los porcentajes SUMAN 100
# ============================================================

# Limpia lo que pidan (de la UI o por RPC): fuera grupos que no existen y porcentajes a cero, y lo que
# quede se reescala a enteros que suman exactamente 100. Vacio = todo a mineral, que es lo de siempre.
static func grupos_validos(pedidos) -> Dictionary:
	var pesos: Dictionary = {}
	if pedidos is Dictionary:
		for k in pedidos:
			var g: int = int(k)
			if g < 0 or g > int(Grupo.CRISTAL):
				continue
			var v: float = float(pedidos[k])
			if v > 0.0:
				pesos[g] = float(pesos.get(g, 0.0)) + v
	if pesos.is_empty():
		return {int(Grupo.MINERAL): 100}
	return a_cien(pesos)

# Reparte 100 entre unos pesos con el metodo del MAYOR RESTO: redondear cada uno por su cuenta da
# 99 o 101 y el deslizador bailaria.
static func a_cien(pesos: Dictionary, total: int = 100) -> Dictionary:
	var suma: float = 0.0
	for g in pesos:
		suma += maxf(0.0, float(pesos[g]))
	var out: Dictionary = {}
	if pesos.is_empty():
		return out
	var restos: Array = []
	var usado: int = 0
	for g in pesos:
		var exacto: float = float(total) * maxf(0.0, float(pesos[g])) / suma if suma > 0.0 \
			else float(total) / float(pesos.size())
		var entero: int = int(floor(exacto))
		out[int(g)] = entero
		usado += entero
		restos.append([exacto - float(entero), int(g)])
	restos.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var i: int = 0
	while usado < total and not restos.is_empty():
		var g: int = int(restos[i % restos.size()][1])
		out[g] = int(out[g]) + 1
		usado += 1
		i += 1
	return out

# EL DESLIZADOR: pone el grupo `g` a `v` y los demas se reparten lo que sobra EN PROPORCION a lo que
# tenian. Con un solo grupo marcado no hay nada que repartir: se queda a 100.
static func ajustar_porcentaje(grupos: Dictionary, g: int, v: int) -> Dictionary:
	if not grupos.has(g):
		return grupos
	if grupos.size() == 1:
		return {g: 100}
	var fijo: int = clampi(v, 0, 100)
	var otros: Dictionary = {}
	for k in grupos:
		if int(k) != g:
			otros[int(k)] = float(grupos[k])
	var suma_otros: float = 0.0
	for k in otros:
		suma_otros += float(otros[k])
	if suma_otros <= 0.0:
		for k in otros:
			otros[k] = 1.0
	var repartido: Dictionary = a_cien(otros, 100 - fijo)
	# EN EL MISMO ORDEN QUE LLEGARON: si el que mueves se fuera al final, la lista de deslizadores se
	# reordenaria con cada toque y no habria forma de ajustarlos.
	var out: Dictionary = {}
	for k in grupos:
		out[int(k)] = fijo if int(k) == g else int(repartido.get(int(k), 0))
	return out

# Marcar o desmarcar un grupo. Al marcar entra con su parte a partes iguales; al desmarcar, lo suyo se
# reparte entre los demas. Nunca se queda vacio.
static func alternar_grupo(grupos: Dictionary, g: int) -> Dictionary:
	var pesos: Dictionary = {}
	for k in grupos:
		pesos[int(k)] = float(grupos[k])
	if pesos.has(g):
		if pesos.size() <= 1:
			return grupos
		pesos.erase(g)
	else:
		pesos[g] = 100.0 / float(pesos.size() + 1) if not pesos.is_empty() else 100.0
		# Los que ya estaban ceden lo suyo en proporcion.
		var resto: float = 100.0 - float(pesos[g])
		var suma: float = 0.0
		for k in pesos:
			if int(k) != g:
				suma += float(pesos[k])
		for k in pesos:
			if int(k) != g and suma > 0.0:
				pesos[k] = float(pesos[k]) * resto / suma
	return a_cien(pesos)


# ============================================================
#  MIGRACION: los encargos de antes del rework
# ============================================================
# Guardaban `tipos` (Array de un enum viejo: VETA, PLANTA, MADERA, COMIDA, PESCA, BICHO) y las faenas
# en ese mismo enum. Los numeros NO coinciden con Grupo, asi que leerlos tal cual mandaria a pescar
# al que iba a por plantas. Se convierte en su sitio, una vez.
const _TIPO_VIEJO_A_GRUPOS := {
	0: [Grupo.MINERAL], 1: [Grupo.PLANTA], 2: [Grupo.MADERA], 3: [Grupo.COMIDA],
	4: [Grupo.PESCADO], 5: [Grupo.CUERO, Grupo.NUCLEO, Grupo.POCION],
}

static func migrar(e: Dictionary) -> bool:
	if e.has("grupos") or not e.has("tipos"):
		return false
	var pesos: Dictionary = {}
	for t in (e.get("tipos", []) as Array):
		for g in (_TIPO_VIEJO_A_GRUPOS.get(int(t), []) as Array):
			pesos[int(g)] = 1.0
	e["grupos"] = grupos_validos(pesos)
	for m_ in (e.get("miembros", []) as Array):
		var m := m_ as Dictionary
		var nuevas: Array = []
		for t in (m.get("faenas", []) as Array):
			for g in (_TIPO_VIEJO_A_GRUPOS.get(int(t), []) as Array):
				if not nuevas.has(int(g)):
					nuevas.append(int(g))
		m["faenas"] = nuevas
	e.erase("tipos")
	return true


# ============================================================
#  UTILES DEL COFRE: una mochila por persona, una herramienta por tipo
# ============================================================
# Devuelve "" si se puede mandar, o el motivo.
static func motivo_no_puede(grupos: Dictionary, entradas_cofre: Array, n_personas: int) -> String:
	var mochilas: int = 0
	var por_tipo: Dictionary = {}
	var hay_cana: bool = false
	for e_ in entradas_cofre:
		var e := e_ as Dictionary
		var d: Dictionary = e.get("dict", {})
		match String(d.get("clase", "")):
			"mochila":
				mochilas += 1
			"herramienta":
				var t: int = tipo_herramienta(e)
				por_tipo[t] = int(por_tipo.get(t, 0)) + 1
				if t == int(ToolData.Tipo.CANA):
					hay_cana = true
	if mochilas > maxi(1, n_personas):
		return "Solo una mochila por persona."
	for t in por_tipo:
		if int(por_tipo[t]) > 1:
			return "Solo una herramienta de cada tipo."
	# A PESCAR NO SE VA SIN CAÑA, la misma regla del estanque.
	if grupos.has(int(Grupo.PESCADO)) and not hay_cana:
		return "A pescar no se va sin caña: métele una del cofre."
	return ""

# El ToolData.Tipo de una entrada del cofre, o -1 si no es herramienta.
static func tipo_herramienta(entrada: Dictionary) -> int:
	var d: Dictionary = entrada.get("dict", {})
	if String(d.get("clase", "")) != "herramienta":
		return -1
	var pl: ToolData = load(String(d.get("ruta", ""))) as ToolData
	return int(pl.tipo) if pl != null else -1


# ============================================================
#  CLASE DE COMBATE
#  Aunque los mandes a picar piedra ahi abajo hay bichos, asi que TODOS pelean y todos se llevan
#  excelia de combate. La clase es una ORDEN del envio (no del personaje) y solo decide A QUE STATS
#  va esa excelia; las opciones salen de lo que lleve puesto ese dia.
# ============================================================
enum Clase { GUERRERO, GUERRERO_PESADO, PICARO, TANQUE, MAGO, GUERRERO_MAGICO }

const NOMBRE_CLASE := {
	Clase.GUERRERO: "Guerrero", Clase.GUERRERO_PESADO: "Guerrero pesado",
	Clase.PICARO: "Pícaro", Clase.TANQUE: "Tanque",
	Clase.MAGO: "Mago", Clase.GUERRERO_MAGICO: "Guerrero mágico",
}

# Para las casillas estrechas; el nombre largo va en el tooltip.
const ABREV_CLASE := {
	Clase.GUERRERO: "Guerrero", Clase.GUERRERO_PESADO: "G. pesado",
	Clase.PICARO: "Pícaro", Clase.TANQUE: "Tanque",
	Clase.MAGO: "Mago", Clase.GUERRERO_MAGICO: "G. mágico",
}

const REQUISITO_CLASE := {
	Clase.GUERRERO: "Necesita un arma ligera (espada corta, larga o maza).",
	Clase.GUERRERO_PESADO: "Necesita un arma a dos manos (mandoble, hacha o martillo).",
	Clase.PICARO: "Necesita una daga o un estoque.",
	Clase.TANQUE: "Necesita un escudo en la mano secundaria.",
	Clase.MAGO: "Necesita magias equipadas.",
	Clase.GUERRERO_MAGICO: "Necesita magias equipadas Y un arma melee (la varita no cuenta).",
}

# Como reparte su excelia de COMBATE cada clase. Cada fila SUMA 1.0: la clase cambia a donde va el
# aprendizaje, no cuanto.
const PESOS_CLASE := {
	# Todo el que pelea pega, asi que la Fuerza no se hunde por clase (en el playtest el picaro sacaba
	# 15 de Fuerza contra los 46 del pesado y no se sostenia).
	Clase.GUERRERO:        {"fuerza": 0.32, "resistencia": 0.24, "destreza": 0.22, "agilidad": 0.22, "magia": 0.00},
	Clase.GUERRERO_PESADO: {"fuerza": 0.40, "resistencia": 0.22, "destreza": 0.18, "agilidad": 0.20, "magia": 0.00},
	Clase.PICARO:          {"fuerza": 0.28, "resistencia": 0.12, "destreza": 0.27, "agilidad": 0.33, "magia": 0.00},
	# 0.38 y no 0.50: encajar golpes ya es la ganancia mas generosa del juego y el tanque salia con +74.
	Clase.TANQUE:          {"fuerza": 0.24, "resistencia": 0.40, "destreza": 0.19, "agilidad": 0.17, "magia": 0.00},
	# Pelear es la UNICA forma de subir Magia, asi que las magicas la suben de verdad.
	Clase.MAGO:            {"fuerza": 0.07, "resistencia": 0.14, "destreza": 0.07, "agilidad": 0.17, "magia": 0.55},
	Clase.GUERRERO_MAGICO: {"fuerza": 0.26, "resistencia": 0.14, "destreza": 0.06, "agilidad": 0.14, "magia": 0.40},
}

# El UNICO sitio del proyecto que clasifica armas por familia.
const ARMAS_PICARO := [WeaponData.Tipo.DAGA, WeaponData.Tipo.ESTOQUE]
const ARMAS_LIGERAS := [WeaponData.Tipo.ESPADA_CORTA, WeaponData.Tipo.ESPADA_LARGA,
	WeaponData.Tipo.MAZA_PEQ]

# Las clases que ESE personaje puede elegir hoy. Nunca devuelve vacio.
static func clases_de(pj: PersonajeData) -> Array:
	var out: Array = []
	if pj == null:
		return [int(Clase.GUERRERO)]
	var w: WeaponData = Game.arma_main(pj)
	var tipo_w: int = int(w.tipo) if w != null else int(WeaponData.Tipo.PUNOS)
	var magica: bool = w != null and w.es_magica
	var melee: bool = w != null and not magica and tipo_w != int(WeaponData.Tipo.PUNOS)
	var hechizos: bool = Game.tiene_hechizos(pj)

	if hechizos:
		out.append(int(Clase.MAGO))
		if melee:
			out.append(int(Clase.GUERRERO_MAGICO))
	if pj.equipped_off is ShieldData:
		out.append(int(Clase.TANQUE))
	if ARMAS_PICARO.has(tipo_w):
		out.append(int(Clase.PICARO))
	elif w != null and w.dos_manos and not magica:
		out.append(int(Clase.GUERRERO_PESADO))
	elif ARMAS_LIGERAS.has(tipo_w):
		out.append(int(Clase.GUERRERO))

	if out.is_empty():
		out.append(int(Clase.GUERRERO))
	return out

# El host llama a ESTO: lo que mande un cliente por RPC es una peticion.
static func clase_valida(pj: PersonajeData, pedida: int) -> int:
	var disp: Array = clases_de(pj)
	return pedida if disp.has(int(pedida)) else int(disp[0])


# ============================================================
#  RELOJ REAL
#  NUNCA Game.tiempo_mazmorra: ese se para con los menus y no corre con el juego cerrado.
# ============================================================
static var desfase_prueba: int = 0

static func ahora() -> int:
	return int(Time.get_unix_time_from_system()) + desfase_prueba

static func restante(e: Dictionary) -> int:
	return maxi(0, int(e.get("t_inicio", 0)) + int(e.get("duracion", 0)) - ahora())

static func vencido(e: Dictionary) -> bool:
	return restante(e) <= 0

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
#  PODER DE COMBATE: decide si vuelven bien
# ============================================================
# Sale de la meta (tier / rareza / mejoras) y NO de loadout_mods: esos son numeros de combate y
# atarian el balance de los encargos al del combate.
const PIEZA_BASE := 4.0
# 1.8 y no el TIER_GROWTH 2.2 del daño: compuesto contra una franja de enemigos lineal se dispara.
const TIER_PODER := 1.8
const MEJORA := 0.05          # +5% por cada +1

# El equipo MULTIPLICA: desnudo es una cuarta parte.
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

static func puntos_equipo(pj: PersonajeData) -> float:
	if pj == null:
		return 0.0
	var total: float = 0.0
	for slot in Game.EQUIP_SLOTS:
		var item: Resource = Game._item_equipado_de(slot, pj)
		if item == null:
			continue
		total += puntos_pieza(item, Game._meta(slot, pj)) * _peso_slot(slot, pj)
	return total

# El arma vale por DOS, y por TRES a dos manos: ocupa la secundaria y no puede llenarla.
static func _peso_slot(slot: String, pj: PersonajeData) -> float:
	if slot != "main":
		return 1.0
	var w: WeaponData = pj.equipped_main as WeaponData
	return 3.0 if w != null and w.dos_manos else 2.0

static func mult_equipo(pj: PersonajeData) -> float:
	return clampf(DESNUDO + puntos_equipo(pj) / EQUIPO_DIV, DESNUDO, EQUIPO_TECHO)

# Sobre lo CONSOLIDADO: la excelia pendiente no pelea y no se ve en ninguna ficha.
static func poder(pj: PersonajeData) -> float:
	if pj == null:
		return 0.0
	return Game.poder_jugador_puesto(pj) * mult_equipo(pj)

# El del GRUPO: el que mas, entero, y los demas a fraccion. Cuatro clones valen x2.2, no x4.
const REPARTO := 0.4

static func poder_grupo(pjs: Array) -> float:
	var poderes: Array = []
	for pj in pjs:
		poderes.append(poder(pj as PersonajeData))
	return poder_grupo_de(poderes)

# Desde poderes ya calculados: el invitado no tiene los PersonajeData de su compañero.
static func poder_grupo_de(poderes: Array) -> float:
	var mejor: float = 0.0
	var suma: float = 0.0
	for p in poderes:
		suma += float(p)
		mejor = maxf(mejor, float(p))
	return mejor + REPARTO * (suma - mejor)


# --- Lo que pide el piso ---
# Sale del TECHO de la franja de los enemigos reales del piso (un encargo cruza el piso entero durante
# horas y se topa con lo peor), por un coeficiente que en los seis primeros pisos es suave para que
# uno solo pueda.
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

# R: el numero de SIEMPRE. Es donde el grupo va "justo" (70% de exito).
static func requisito_combate(piso: int) -> float:
	return maxf(1.0, coef_piso(piso) * Game.enemy_ability_sum_band(piso).y)


# ============================================================
#  EL DESENLACE: una curva por ANCLAS
# ============================================================
# Las anclas se miden en PASOS (w) y no en porcentaje del requisito. En los primeros pisos un 20% son
# veintitantos puntos, pero en un piso que pide 3000 serian 600 y la zona de "vas justo" se haria
# enorme. El paso crece mas despacio que el requisito: un 20% de lo que pide el piso 1 (134) y un
# ~12% con 6000.
const PASO_BASE := 0.20
const PASO_REF := 134.0
const PASO_EXP := 0.866

static func paso(req: float) -> float:
	return PASO_BASE * PASO_REF * pow(maxf(1.0, req) / PASO_REF, PASO_EXP)

# EL NUMERO QUE SE ENSEÑA: llegar a el es el 100% de exito.
static func requisito_mostrado(piso: int) -> float:
	var r: float = requisito_combate(piso)
	return r + paso(r)

# [pasos respecto a R, [exito, parcial, fracaso]], de menos a mas. Entre dos anclas, linea recta.
#   R + w         -> 100% exito
#   R             -> 70 / 25 / 5
#   R - 0.8 w     -> 10 / 30 / 60     (un 30% por debajo del numero enseñado, en el piso 1)
#   R - 2 w       -> 100% fracaso     (la mitad del numero enseñado, en el piso 1)
const ANCLAS := [
	[-2.0, [0.0, 0.0, 1.0]],
	[-0.8, [0.10, 0.30, 0.60]],
	[0.0, [0.70, 0.25, 0.05]],
	[1.0, [1.0, 0.0, 0.0]],
]

static func probs_desenlace(poder_del_grupo: float, piso: int) -> Array:
	var r: float = requisito_combate(piso)
	return probs_por_pasos((poder_del_grupo - r) / paso(r))

static func probs_por_pasos(d: float) -> Array:
	if d <= float(ANCLAS[0][0]):
		return (ANCLAS[0][1] as Array).duplicate()
	for i in range(1, ANCLAS.size()):
		var d1: float = float(ANCLAS[i][0])
		if d <= d1:
			var d0: float = float(ANCLAS[i - 1][0])
			var t: float = (d - d0) / (d1 - d0)
			var a: Array = ANCLAS[i - 1][1]
			var b: Array = ANCLAS[i][1]
			return [lerpf(a[0], b[0], t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t)]
	return (ANCLAS[ANCLAS.size() - 1][1] as Array).duplicate()

static func exito(poder_del_grupo: float, piso: int) -> float:
	return float(probs_desenlace(poder_del_grupo, piso)[EXITO])

# Una probabilidad como texto, con decimales solo en los extremos (un 99.95 no es un 100).
static func pct(p: float) -> String:
	var v: float = 100.0 * p
	if v >= 100.0:
		return "100%"
	if v >= 10.0 and v < 99.0:
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
#  OFICIOS: que stat y que util cuenta en cada grupo
# ============================================================
static func oficio_de(grupo: int) -> Dictionary:
	match grupo:
		Grupo.MINERAL:
			return {"stat": "fuerza", "suelo": Game.MINERIA_FUERZA_FLOOR, "tool": ToolData.Tipo.PICO,
				"gain": Game.GAIN_FUERZA_MINERIA, "pivote": Game.MINERIA_PIVOTE,
				"slope": Game.MINERIA_SLOPE, "tope": Game.RETO_MAX_FISICO}
		Grupo.MADERA:
			return {"stat": "agilidad", "suelo": Game.TALA_AGILIDAD_FLOOR, "tool": ToolData.Tipo.HACHA,
				"gain": Game.GAIN_AGILIDAD_TALA, "pivote": Game.TALA_PIVOTE,
				"slope": Game.TALA_SLOPE, "tope": Game.RETO_MAX_FISICO}
		Grupo.PESCADO:
			return {"stat": "resistencia", "suelo": Game.PESCA_RESISTENCIA_FLOOR,
				"tool": ToolData.Tipo.CANA, "gain": Game.GAIN_RESISTENCIA_PESCA,
				"pivote": Game.PESCA_PIVOTE, "slope": Game.PESCA_SLOPE,
				"tope": Game.RETO_MAX_FISICO}
		Grupo.PLANTA, Grupo.COMIDA:
			# La sal se pica con pico, pero va dentro de COMIDA y manda el oficio del grupo.
			return {"stat": "destreza", "suelo": Game.HERB_DESTREZA_FLOOR, "tool": ToolData.Tipo.HOZ,
				"gain": Game.GAIN_DESTREZA_PLANTA, "pivote": Game.HERB_PIVOTE,
				"slope": Game.HERB_SLOPE, "tope": Game.RETO_MAX}
		_:
			# CAZA: extraer el cristal del cadaver, con Destreza y cuchillo, igual que jugando.
			return {"stat": "destreza", "suelo": Game.EXTRACTION_DESTREZA_FLOOR,
				"tool": ToolData.Tipo.CUCHILLO, "gain": Game.GAIN_DESTREZA_MINIJUEGO,
				"pivote": Game.EXTRACTION_DESTREZA_PIVOTE, "slope": Game.EXTRACTION_DESTREZA_SLOPE,
				"tope": Game.EXTRACTION_DESTREZA_RETO_MAX}

static func tablas_de(grupo: int) -> Array:
	var out: Array = []
	for ruta in (TABLAS.get(grupo, []) as Array):
		var t: MaterialTable = load(String(ruta)) as MaterialTable
		if t != null:
			out.append(t)
	return out

# A que grupo va un material que suelta un bicho. La carne es comida; lo que no es piel ni nucleo
# (babas, polvo de alas, esporas...) va a las pociones; y si un constructo suelta mineral o un trent
# madera, cuenta en su grupo pero POR BAJA, sin gastar las 4 por hora de nadie.
static func grupo_de_drop(m: MaterialData) -> int:
	if m == null:
		return -1
	if int(m.familia) == int(MaterialData.Familia.NUCLEO) or int(m.tipo) == int(MaterialData.Tipo.NUCLEO):
		return Grupo.NUCLEO
	match int(m.tipo):
		MaterialData.Tipo.CUERO: return Grupo.CUERO
		MaterialData.Tipo.CARNE, MaterialData.Tipo.DESPENSA, MaterialData.Tipo.PESCADO: return Grupo.COMIDA
		MaterialData.Tipo.MINERAL: return Grupo.MINERAL
		MaterialData.Tipo.MADERA: return Grupo.MADERA
	return Grupo.POCION

# Lo que puede salir de un grupo en un piso, como [{"material", "peso"}]. Para la pantalla (el icono
# del grupo es su material mas comun) y para tirar lo que se recoge. Los CRISTALES no tienen material.
# Con varias tablas (COMIDA) los pesos se normalizan por tabla: la sal, sola en la suya, no aplasta
# a las silvestres.
static func opciones(grupo: int, piso: int) -> Array:
	var out: Array = []
	if es_recogible(grupo):
		for t in tablas_de(grupo):
			var disp: Array = (t as MaterialTable).disponibles(piso)
			var total: float = 0.0
			for e in disp:
				total += e.peso_en(piso)
			if total <= 0.0:
				continue
			for e in disp:
				out.append({"material": e.material, "peso": e.peso_en(piso) / total})
	# De los bichos: lo de caza y la carne de la comida. En MINERAL o MADERA no se lista lo que suelta
	# algun constructo: sale poco y confundiria el icono del grupo.
	if grupo != Grupo.CRISTAL and (es_de_caza(grupo) or grupo == Grupo.COMIDA):
		for o in Game.materiales_de_bicho_en(piso):
			if grupo_de_drop(o["material"] as MaterialData) == grupo:
				out.append(o)
	return out

# Lo que se RECOGE de un grupo en un piso: [{"material", "peso", "exigencia"}]. Se calcula UNA vez por
# encargo (ver resolver): hacerlo en cada tirada cargaba y filtraba las tablas cientos de veces.
static func pool_recogible(grupo: int, piso: int) -> Array:
	var pool: Array = []
	for t in tablas_de(grupo):
		var disp: Array = (t as MaterialTable).disponibles(piso)
		var total: float = 0.0
		for e in disp:
			total += e.peso_en(piso)
		if total <= 0.0:
			continue
		for e in disp:
			pool.append({"material": e.material, "peso": e.peso_en(piso) / total,
				"exigencia": Game._exigencia_material(e.material, piso)})
	return pool

static func elegir_material(grupo: int, piso: int, rng: RandomNumberGenerator) -> MaterialData:
	return _tirar_de(pool_recogible(grupo, piso), rng)

static func _tirar_de(pool: Array, rng: RandomNumberGenerator) -> MaterialData:
	var o: Dictionary = _tirar_fila(pool, rng)
	return o.get("material") as MaterialData if not o.is_empty() else null

static func _tirar_fila(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: float = 0.0
	for o in pool:
		total += float(o["peso"])
	if total <= 0.0:
		return {}
	var tirada: float = rng.randf() * total
	for o in pool:
		tirada -= float(o["peso"])
		if tirada <= 0.0:
			return o
	return pool.back()

# El RETO MEDIO de un grupo para una persona: la media, por lo que sale, del reto de CADA material.
# La media de las exigencias mentia: la Comida junta setas (30) con sal (150) y la media cae en el codo.
static func reto_medio(grupo: int, piso: int, suyo: float, of: Dictionary) -> float:
	var suma: float = 0.0
	var peso: float = 0.0
	for t in tablas_de(grupo):
		var disp: Array = (t as MaterialTable).disponibles(piso)
		var total: float = 0.0
		for e in disp:
			total += e.peso_en(piso)
		if total <= 0.0:
			continue
		for e in disp:
			var w: float = e.peso_en(piso) / total
			var ex: float = Game._exigencia_material(e.material, piso)
			suma += Game.curva_reto(ex / maxf(1.0, suyo), float(of["pivote"]), float(of["slope"]),
				float(of["tope"])) * w
			peso += w
	return suma / maxf(0.001, peso)


# ============================================================
#  FAENA: a por que va cada uno
# ============================================================
# `miembros[i].faenas` es una LISTA de grupos; vacia = "a lo que haga falta".
static func faenas_de(miembros: Array, uid: String) -> Array:
	for m in miembros:
		if String((m as Dictionary).get("uid", "")) == uid:
			return (m as Dictionary).get("faenas", [])
	return []

static func _dueno_de(miembros: Array, uid: String) -> String:
	for m in miembros:
		if String((m as Dictionary).get("uid", "")) == uid:
			return String((m as Dictionary).get("dueno", ""))
	return ""

static func clase_de(miembros: Array, uid: String) -> int:
	for m in miembros:
		if String((m as Dictionary).get("uid", "")) == uid:
			return int((m as Dictionary).get("clase", Clase.GUERRERO))
	return int(Clase.GUERRERO)

# LOS GRUPOS QUE TRABAJA UNA PERSONA: los que tiene marcados, o todos los del encargo si no marco
# ninguno. Es la regla de las casillas: una preferencia, no una trampa.
static func grupos_de_persona(miembros: Array, uid: String, grupos: Dictionary) -> Array:
	var out: Array = []
	for g in faenas_de(miembros, uid):
		if grupos.has(int(g)) and not out.has(int(g)):
			out.append(int(g))
	if out.is_empty():
		for g in grupos:
			out.append(int(g))
	return out

static func faenas_validas(pedidas: Array, grupos: Dictionary) -> Array:
	var out: Array = []
	for t in pedidas:
		var i: int = int(t)
		if grupos.has(i) and not out.has(i):
			out.append(i)
	return out


# ============================================================
#  CALIDAD: por persona, con SU stat
# ============================================================
# MARGEN = stat*0.8 + suelo + afinidad - exigencia. Una RESTA (cuanto te sobra), no un cociente: un
# cociente pediria +500 de stat para ir sobrado en algo de exigencia 500. El 0.8 y no el 0.5 de los
# minijuegos: en una resta, dividir la stat quita puntos de golpe en vez de aplanar la pendiente.
const STAT_PESO_CALIDAD := 0.8

const MARGEN_PLENO := 100.0    # stat POR ENCIMA de la exigencia que da el 100% de intacto
const MARGEN_NULO := -90.0     # por debajo de esto no sale nada intacto
const MARGEN_MALO := 155.0     # cuanto por DEBAJO hace falta para el 75% de dañado
# LO QUE SE ROMPE. Nuevo en el rework: antes un encargo nunca rompia nada y el flojo traia lo mismo que
# el bueno pero peor. Empieza a romperse con 60 por debajo y llega al tope con 260 por debajo.
const ROTO_DESDE := -60.0
const ROTO_HASTA := -260.0
const ROTO_MAX := 0.45

static func reparto_calidades(margen: float) -> Dictionary:
	var intacto: float = clampf((margen - MARGEN_NULO) / (MARGEN_PLENO - MARGEN_NULO), 0.0, 1.0)
	var roto: float = ROTO_MAX * clampf((margen - ROTO_DESDE) / (ROTO_HASTA - ROTO_DESDE), 0.0, 1.0)
	var danado: float = minf(0.75 * pow(clampf(-margen / MARGEN_MALO, 0.0, 1.0), 0.8), 1.0 - roto)
	var normal: float = maxf(0.0, 1.0 - intacto - danado - roto)
	return {"intacto": intacto, "normal": normal, "danado": danado, "roto": roto}

static func calidad_tirada(margen: float, rng: RandomNumberGenerator) -> int:
	var p: Dictionary = reparto_calidades(margen)
	var x: float = rng.randf()
	if x < float(p["intacto"]):
		return MaterialItem.Calidad.INTACTO
	x -= float(p["intacto"])
	if x < float(p["normal"]):
		return MaterialItem.Calidad.NORMAL
	x -= float(p["normal"])
	if x < float(p["danado"]):
		return MaterialItem.Calidad.DANADO
	return MaterialItem.Calidad.ROTO

# El margen de UNA persona contra un material. `stat` es su stat de efecto (consolidada con plato).
static func margen_de(stat: float, grupo: int, afinidad: float, exigencia: float) -> float:
	return stat * STAT_PESO_CALIDAD + float(oficio_de(grupo)["suelo"]) + afinidad - exigencia


# ============================================================
#  CUANTO: el tope de recoger y la caza
# ============================================================
# 4 por hora POR PERSONA, y cada una se va a un grupo segun los porcentajes. Un encargo de 8 h a solas
# son 32 tiradas: da para mucho, pero no te resuelve la vida.
const UNIDADES_HORA_PERSONA := 4.0

# CUANTO HAY DE ESO EN EL PISO: la probabilidad de que una tirada encuentre algo. No es balance, es el
# mapa: de la despensa hay pocos nodos y tardan en volver, y de pesca hay un estanque.
const ABUNDANCIA := {
	Grupo.COMIDA: 0.35,
	Grupo.PESCADO: 0.7,
}

static func abundancia(grupo: int) -> float:
	return float(ABUNDANCIA.get(int(grupo), 1.0))

# Peleas por hora ahi abajo, y cuantos bichos en cada una: uno mas que la gente que va.
const PELEAS_HORA := 5.0

static func bichos_por_pelea(n_personas: int) -> int:
	return maxi(1, n_personas) + 1

# Un numero con decimales a entero, tirando la parte fraccionaria: 2.3 son 2, y un 30% de veces 3.
static func _entero_con_resto(x: float, rng: RandomNumberGenerator) -> int:
	var base: int = int(floor(maxf(0.0, x)))
	return base + (1 if rng.randf() < maxf(0.0, x) - float(base) else 0)

static func _elegir_grupo(candidatos: Array, grupos: Dictionary, rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for g in candidatos:
		total += float(grupos.get(int(g), 0))
	if total <= 0.0:
		return int(candidatos[rng.randi() % candidatos.size()])
	var x: float = rng.randf() * total
	for g in candidatos:
		x -= float(grupos.get(int(g), 0))
		if x <= 0.0:
			return int(g)
	return int(candidatos.back())

static func _elegir_enemigo(filas: Array, rng: RandomNumberGenerator) -> EnemyData:
	var total: float = 0.0
	for f in filas:
		total += float(f["prob"])
	if total <= 0.0:
		return null
	var x: float = rng.randf() * total
	for f in filas:
		x -= float(f["prob"])
		if x <= 0.0:
			return f["data"] as EnemyData
	return (filas.back() as Dictionary)["data"] as EnemyData

# La categoria del cristal, como EnemyData.roll_crystal_category pero con el rng del encargo (aquella
# usa randf() global y el resultado dejaria de ser reproducible). t = 0.5: un bicho medio.
static func _categoria_cristal(data: EnemyData, rng: RandomNumberGenerator) -> int:
	if not data.crystal_category_weights.is_empty():
		var total: float = 0.0
		for w in data.crystal_category_weights:
			total += maxf(0.0, w)
		if total > 0.0:
			var r: float = rng.randf() * total
			for i in range(data.crystal_category_weights.size()):
				r -= maxf(0.0, data.crystal_category_weights[i])
				if r < 0.0:
					return data.crystal_category_min + i
		return data.crystal_category_min + data.crystal_category_weights.size() - 1
	var cat: int = data.crystal_category_min
	for _i in range(data.crystal_category_max - data.crystal_category_min):
		if rng.randf() < 0.5:
			cat += 1
	return cat


# ============================================================
#  TOPE DE PESO
# ============================================================
const CARGA_MAX := 1.10

static func capacidad_util(entrada: Dictionary) -> float:
	var d: Dictionary = entrada.get("dict", {})
	if String(d.get("clase", "")) != "mochila":
		return 0.0
	return float(d.get("capacidad", 0)) * Game.mochila_tier_factor(int(d.get("tier", 1))) \
		* Upgrades.rareza_mult_capacidad(int(d.get("rareza", 0)))

static func tope_carga(pjs: Array, entradas: Array) -> float:
	return CARGA_MAX * Game._capacidad_con(Game.base_capacity + _capacidad_utiles(entradas),
		_saturacion_utiles(entradas), pjs)

# Lo mismo desde las FUERZAS, para el pronostico del invitado.
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

static func _peso_de(pieza: Dictionary) -> float:
	if pieza.has("cristal"):
		var c := Cristal.new()
		c.categoria = int(pieza["cristal"])
		c.calidad = int(pieza["calidad"])
		return c.peso()
	var m: MaterialData = pieza.get("material") as MaterialData
	if m == null:
		return 0.1
	return maxf(0.1, m.peso_base * _peso_mult(int(pieza["calidad"])))

# De peor (0) a mejor (4). El enum no sirve para ordenar: PURO es el ultimo y es el mejor.
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

static func _peor_primero(a: Dictionary, b: Dictionary) -> bool:
	return _rango_calidad(int(a["calidad"])) < _rango_calidad(int(b["calidad"]))

# LA MOCHILA LLENA SE RECORTA SEGUN EL OBJETIVO. Antes se tiraba lo peor de todo junto, y si el
# hierro pesaba mas que las hierbas volvias sin una sola piedra habiendo pedido "un poco de todo".
#
#   1. Cada grupo llena SU PARTE: su porcentaje de la mochila, en kilos.
#   2. Si sobra hueco (algun grupo no llego a llenar la suya), se reparte entre los que se dejaron
#      cosas fuera, en proporcion a su porcentaje, y cada uno puede pasarse como mucho EXTRA_RECORTE
#      de la mochila: el que pidio un 10% vuelve con un 20% como mucho, el de 60 con un 70. Lo que
#      no quepa ni asi se queda ahi abajo. El porcentaje es lo que pediste, no una sugerencia.
#
# Dentro de cada grupo se queda lo MEJOR (ver _mejor_primero).
# Devuelve {"traidas": Array, "perdido": int, "kg": float}.
const EXTRA_RECORTE := 0.10

static func recortar_por_peso(piezas: Array, tope_kg: float, grupos: Dictionary) -> Dictionary:
	var total: float = 0.0
	for p in piezas:
		total += _peso_de(p)
	if total <= tope_kg:
		return {"traidas": piezas, "perdido": 0, "kg": total}

	var fuera: Dictionary = {}     # grupo -> lo que aun no ha entrado, de mejor a peor
	for p in piezas:
		var g: int = int(p["grupo"])
		if not fuera.has(g):
			fuera[g] = []
		(fuera[g] as Array).append(p)
	for g in fuera:
		(fuera[g] as Array).sort_custom(_mejor_primero)

	var traidas: Array = []
	var kg: float = 0.0
	# 1. Su parte.
	for g in fuera:
		kg += _llenar(fuera[g], tope_kg * float(grupos.get(int(g), 0)) / 100.0, traidas)
	# 2. El hueco que sobre, a los que se dejaron cosas, con su tope de extra. Varias vueltas: lo que uno
	# no puede coger por su tope vuelve al bote para los demas.
	var extra: Dictionary = {}
	for _vuelta in 6:
		var libre: float = tope_kg - kg
		if libre <= 0.01:
			break
		var quieren: Array = []
		var suma_pct: float = 0.0
		for g in fuera:
			if not (fuera[g] as Array).is_empty() \
					and float(extra.get(g, 0.0)) < tope_kg * EXTRA_RECORTE - 0.01:
				quieren.append(g)
				suma_pct += maxf(1.0, float(grupos.get(int(g), 0)))
		if quieren.is_empty():
			break
		var cogido: float = 0.0
		for g in quieren:
			var hueco: float = minf(libre * maxf(1.0, float(grupos.get(int(g), 0))) / suma_pct,
				tope_kg * EXTRA_RECORTE - float(extra.get(g, 0.0)))
			var w: float = _llenar(fuera[g], hueco, traidas)
			extra[g] = float(extra.get(g, 0.0)) + w
			cogido += w
		kg += cogido
		if cogido <= 0.0:
			break
	return {"traidas": traidas, "perdido": piezas.size() - traidas.size(), "kg": kg}

# Mete en `traidas` lo que quepa en `hueco` kilos, en orden, y lo saca de `restantes`. Si una pieza no
# cabe se salta y se prueba la siguiente (una piedra pesada no deja fuera a tres hierbas que si caben).
# Devuelve los kilos metidos.
static func _llenar(restantes: Array, hueco: float, traidas: Array) -> float:
	var llevo: float = 0.0
	var i: int = 0
	while i < restantes.size():
		var w: float = _peso_de(restantes[i])
		if llevo + w <= hueco:
			llevo += w
			traidas.append(restantes[i])
			restantes.remove_at(i)
		else:
			i += 1
	return llevo

# QUE ES "LO MEJOR" dentro de un grupo:
#   - CRISTALES: lo que mas DINERO da por kilo. Van a la tienda y nada mas, asi que en el hueco que les
#     toca se mete el maximo de monedas; un intacto pequeño puede valer menos por kilo que un normal
#     de categoria alta.
#   - MATERIALES: la mejor CALIDAD, que es lo que cuenta al craftear.
static func _mejor_primero(a: Dictionary, b: Dictionary) -> bool:
	if a.has("cristal") and b.has("cristal"):
		return _valor_kg_cristal(a) > _valor_kg_cristal(b)
	return _rango_calidad(int(a["calidad"])) > _rango_calidad(int(b["calidad"]))

static func _valor_kg_cristal(p: Dictionary) -> float:
	var c := Cristal.new()
	c.categoria = int(p["cristal"])
	c.calidad = int(p["calidad"])
	return float(c.valor_estimado()) / maxf(0.1, c.peso())

# EL CASTIGO DEL DESENLACE: la misma parte de CADA grupo, sin azar. Se va lo peor primero.
static func aplicar_perdida(piezas: Array, desenlace: int) -> Dictionary:
	var perdida: float = float(PERDIDA[clampi(desenlace, 0, PERDIDA.size() - 1)])
	if perdida <= 0.0:
		return {"quedan": piezas, "perdido": 0}
	var por_grupo: Dictionary = {}
	for p in piezas:
		var g: int = int(p["grupo"])
		if not por_grupo.has(g):
			por_grupo[g] = []
		(por_grupo[g] as Array).append(p)
	var quedan: Array = []
	var fuera: int = 0
	for g in por_grupo:
		var lista: Array = (por_grupo[g] as Array).duplicate()
		lista.sort_custom(_peor_primero)
		var quitar: int = int(round(float(lista.size()) * perdida))
		fuera += quitar
		quedan.append_array(lista.slice(quitar))
	return {"quedan": quedan, "perdido": fuera}


# ============================================================
#  LOS UTILES DEL COFRE
#  Se leen del DICT SERIALIZADO, nunca deserializando: registraria una copia en el baul cada vez que
#  se mira un encargo (el bug de las 6 hachas).
# ============================================================
static func mods_util(entrada: Dictionary, grupo: int) -> Dictionary:
	var nada := {"afinidad": 0.0, "golpes_menos": 0}
	var d: Dictionary = entrada.get("dict", {})
	if String(d.get("clase", "")) != "herramienta":
		return nada
	var quiere: int = int(oficio_de(grupo).get("tool", -1))
	var plantilla: ToolData = load(String(d.get("ruta", ""))) as ToolData
	if plantilla == null or int(plantilla.tipo) != quiere:
		return nada
	return Upgrades.tool_mods(int(plantilla.tipo), int(d.get("tier", 1)),
		int(d.get("rareza", 0)), int(d.get("banda", 0)))

# Lo que aporta un util a un encargo con esos grupos, para ORDENAR la rejilla (el mejor arriba).
static func aporte_util(entrada: Dictionary) -> float:
	var cap: float = capacidad_util(entrada)
	if cap > 0.0:
		return cap
	var mejor: float = 0.0
	for g in Grupo.values():
		mejor = maxf(mejor, float(mods_util(entrada, int(g))["afinidad"]))
	return mejor

static func _afinidades(grupos: Dictionary, entradas_cofre: Array) -> Dictionary:
	var out: Dictionary = {}
	for g in Grupo.values():
		var mejor: float = 0.0
		for entrada in entradas_cofre:
			mejor = maxf(mejor, float(mods_util(entrada as Dictionary, int(g))["afinidad"]))
		out[int(g)] = mejor
	return out


# ============================================================
#  EXCELIA: lo que APRENDEN
# ============================================================
# UNA UNIDAD DE ENCARGO PAGA COMO UN NODO QUE PICAS TU; el descuento ya lo pone el tope de 4 por hora.
# PESCA paga menos por unidad: su banco tiene rarezas exigentisimas y una sola faena decidia la
# expedicion entera (el tanque volvia con +74 de Resistencia por haber ido a pescar).
const RITMO_FAENA := {
	Grupo.PESCADO: 0.47,
}

static func ritmo_faena(grupo: int) -> float:
	return float(RITMO_FAENA.get(int(grupo), 1.0))

# La unica palanca global: lo que rinde un encargo respecto a hacerlo tu.
const RENDIMIENTO := 0.65

# Lo que saca de UNA pelea un miembro: ~3 golpes dados y 2 encajados, con las constantes de combat.gd.
const VALE_UNA_PELEA := 1.6

# Devuelve [{"uid", "abil", "base", "reto", "max_reto"}]. NO las aplica: en multi el PersonajeData
# puede vivir en otra maquina.
#   trabajo      = {uid: {grupo: unidades recogidas}}
#   extracciones = {uid: {"n": int, "reto": float suma}}
static func excelia_de(pjs: Array, piso: int, peleas_n: int, trabajo: Dictionary,
		extracciones: Dictionary, afinidades: Dictionary, desenlace: int, miembros: Array = []) -> Array:
	var req: float = requisito_combate(piso)
	var mult: float = mult_desenlace(desenlace)
	var salida: Array = []
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj == null:
			continue
		# DE QUIEN ES ESTE PERSONAJE, en cada entrada, igual que en partes_de. NO es un adorno: quien
		# resuelve el encargo es el host —y en la fase 3 el host es LA SALA, que no tiene a nadie en su
		# plantilla—, asi que sin dueño Game.recoger_encargo no sabe a que maquina mandarsela
		# (Net.peer_de_identidad("") = 0) y acababa escribiendola sobre la copia aparcada del jugador en
		# jugadores_mundo... que el siguiente autoguardado del dueño pisa entera. Resultado del playtest
		# del 23/09: ocho horas de encargo y CERO en todas las stats, sin un solo aviso.
		var dueno: String = _dueno_de(miembros, pj.uid)
		# --- A) por RECOGER: cada grupo entrena SU stat, con SU reto (al flojo le enseña mas).
		var suyo_t: Dictionary = trabajo.get(pj.uid, {})
		for g in suyo_t:
			var n: int = int(suyo_t[g])
			if n <= 0:
				continue
			var of: Dictionary = oficio_de(int(g))
			# RETO, no efecto: con la INTERNA y SIN plato, como los minijuegos.
			var suyo: float = float(Game.stat_total(String(of["stat"]), pj)) \
				* Game.RECOLECCION_STAT_PESO + float(of["suelo"]) + float(afinidades.get(int(g), 0.0))
			salida.append({
				"uid": pj.uid, "dueno": dueno, "abil": String(of["stat"]),
				"reto": reto_medio(int(g), piso, suyo, of), "max_reto": float(of["tope"]),
				"base": float(of["gain"]) * float(n) * mult * ritmo_faena(int(g)) * RENDIMIENTO,
			})
		# --- B) por EXTRAER cristales: Destreza, con el reto medio de lo que saco.
		var ex: Dictionary = extracciones.get(pj.uid, {})
		if int(ex.get("n", 0)) > 0:
			var n_ex: int = int(ex["n"])
			salida.append({
				"uid": pj.uid, "dueno": dueno, "abil": "destreza",
				"reto": float(ex.get("reto", 0.0)) / float(n_ex),
				"max_reto": Game.EXTRACTION_DESTREZA_RETO_MAX,
				"base": Game.GAIN_DESTREZA_MINIJUEGO * float(n_ex) * mult * RENDIMIENTO,
			})
		# --- C) por PELEAR, todos, repartido por la CLASE que le pusiste.
		# EL 1 ES EL NIVEL DEL ENEMIGO: hoy todos los bichos son de nivel 1. El dia que no, esta linea
		# medira contra el denominador equivocado sin dar error.
		var reto_c: float = Game.reto(req, 1, pj)
		var base_c: float = float(peleas_n) * VALE_UNA_PELEA * mult * RENDIMIENTO
		var pesos: Dictionary = pesos_clase_de(clase_de(miembros, pj.uid), pj)
		for abil in pesos:
			var peso: float = float(pesos[abil])
			if peso <= 0.0:
				continue
			salida.append({"uid": pj.uid, "dueno": dueno, "abil": String(abil), "reto": reto_c,
				"max_reto": Game.RETO_MAX if abil == "magia" else Game.RETO_MAX_FISICO,
				"base": base_c * peso})
	return salida

# El candado: sin hechizos equipados no se gana Magia peleando; ese peso se reparte entre las demas.
static func pesos_clase_de(clase: int, pj: PersonajeData) -> Dictionary:
	var base: Dictionary = PESOS_CLASE.get(clase, PESOS_CLASE[Clase.GUERRERO])
	var magia: float = float(base.get("magia", 0.0))
	if magia <= 0.0 or (pj != null and Game.tiene_hechizos(pj)):
		return base
	var resto: float = 1.0 - magia
	if resto <= 0.0:
		return {"fuerza": 1.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}
	var out: Dictionary = {}
	for abil in base:
		out[abil] = 0.0 if abil == "magia" else float(base[abil]) / resto
	return out


# ============================================================
#  RESOLVER: la unica funcion que tira dados
# ============================================================
# Sembrada con encargo.semilla: el mismo encargo da siempre lo mismo, y en multi el host lo resuelve
# una vez y difunde el resultado ya cocido. NO toca Game.
#
# Informe: {"desenlace", "botin", "cristales", "dinero", "rotos", "perdido_desenlace", "perdido",
#           "excelia", "partes", "trabajadas", "bichos", "peleas", "ratio"}
static func resolver(e: Dictionary, pjs: Array, entradas_cofre: Array) -> Dictionary:
	migrar(e)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e.get("semilla", 0))

	var piso: int = int(e.get("piso", 1))
	var horas: float = float(int(e.get("duracion", 3600))) / 3600.0
	var grupos: Dictionary = grupos_validos(e.get("grupos", {}))
	var miembros: Array = e.get("miembros", [])
	var n: int = maxi(1, pjs.size())

	# --- ¿Vuelven bien?
	var pg: float = poder_grupo(pjs)
	var desenlace: int = tirar_desenlace(pg, piso, rng)
	var afinidades: Dictionary = _afinidades(grupos, entradas_cofre)

	var piezas: Array = []
	var rotos: int = 0
	var trabajo: Dictionary = {}        # uid -> {grupo: n}
	var trabajadas: int = 0
	var pools: Dictionary = {}
	for g in grupos:
		if es_recogible(int(g)):
			pools[int(g)] = pool_recogible(int(g), piso)

	# --- RECOGER: 4 por hora cada uno, repartidas por los porcentajes entre SUS grupos.
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj == null:
			continue
		var mios: Array = []
		for g in grupos_de_persona(miembros, pj.uid, grupos):
			if es_recogible(int(g)):
				mios.append(int(g))
		if mios.is_empty():
			continue
		var suyo: Dictionary = {}
		for i in _entero_con_resto(UNIDADES_HORA_PERSONA * horas, rng):
			var g: int = _elegir_grupo(mios, grupos, rng)
			if rng.randf() >= abundancia(g):
				continue   # no encontro nada: esa tirada se fue en buscar
			var o: Dictionary = _tirar_fila(pools.get(g, []), rng)
			if o.is_empty():
				continue
			var m: MaterialData = o["material"] as MaterialData
			suyo[g] = int(suyo.get(g, 0)) + 1
			trabajadas += 1
			var stat: float = Game.stat_consolidado_eff(String(oficio_de(g)["stat"]), pj)
			var cal: int = calidad_tirada(margen_de(stat, g, float(afinidades.get(g, 0.0)),
				float(o["exigencia"])), rng)
			if cal == MaterialItem.Calidad.ROTO:
				rotos += 1
				continue
			# Un PEZ sin talla no es un pez: la misma tirada que usa el estanque.
			var cm: float = m.talla_desde(MaterialData.tirada_talla(rng)) if m.cm_max > 0.0 else 0.0
			piezas.append({"grupo": g, "material": m, "calidad": cal, "cm": cm})
		trabajo[pj.uid] = suyo

	# --- CAZAR: enemigos reales de la tabla del piso.
	var peleas_n: int = _entero_con_resto(PELEAS_HORA * horas, rng)
	var tabla: SpawnTable = load(Game.TABLA_SPAWNS) as SpawnTable
	var filas: Array = tabla.aplanar(piso) if tabla != null else []
	# Quien extrae: los que van a por algo de caza (o a por comida, por la carne). Si nadie marco nada
	# de eso, nadie se para a destripar: pelean y siguen.
	var quiere_caza: bool = grupos.has(int(Grupo.COMIDA))
	for g in DE_CAZA:
		if grupos.has(int(g)):
			quiere_caza = true
	var cazadores: Array = []
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj == null:
			continue
		for g in grupos_de_persona(miembros, pj.uid, grupos):
			if es_de_caza(int(g)) or int(g) == Grupo.COMIDA:
				cazadores.append(pj)
				break
	var extracciones: Dictionary = {}
	var bichos: int = 0
	var familias: Dictionary = {}
	for _c in peleas_n:
		for _k in bichos_por_pelea(n):
			var data: EnemyData = _elegir_enemigo(filas, rng)
			if data == null:
				continue
			bichos += 1
			if int(data.familia) > 0:
				familias[int(data.familia)] = int(familias.get(int(data.familia), 0)) + 1
			if not quiere_caza or cazadores.is_empty():
				continue
			var quien: PersonajeData = cazadores[rng.randi() % cazadores.size()]
			var cat: int = _categoria_cristal(data, rng)
			var req: float = maxf(1.0, Game._extraction_req(cat))
			var afin_c: float = float(afinidades.get(int(Grupo.CRISTAL), 0.0))
			var destreza: float = Game.stat_consolidado_eff("destreza", quien)
			var cal_c: int = calidad_tirada(margen_de(destreza, Grupo.CRISTAL, afin_c, req), rng)
			var ex: Dictionary = extracciones.get(quien.uid, {"n": 0, "reto": 0.0})
			ex["n"] = int(ex["n"]) + 1
			ex["reto"] = float(ex["reto"]) + Game.curva_reto(
				req / (float(Game.stat_total("destreza", quien)) * Game.RECOLECCION_STAT_PESO
					+ Game.EXTRACTION_DESTREZA_FLOOR),
				Game.EXTRACTION_DESTREZA_PIVOTE, Game.EXTRACTION_DESTREZA_SLOPE,
				Game.EXTRACTION_DESTREZA_RETO_MAX)
			extracciones[quien.uid] = ex
			if grupos.has(int(Grupo.CRISTAL)):
				if cal_c == MaterialItem.Calidad.ROTO:
					rotos += 1
				else:
					piezas.append({"grupo": int(Grupo.CRISTAL), "cristal": cat, "calidad": cal_c})
			# Lo que suelta, con SU probabilidad y la calidad del cristal (un cristal roto deja el
			# material dañado, como jugando). El cuchillo sube material y nucleo, no la carne.
			var cal_m: int = mini(cal_c, MaterialItem.Calidad.DANADO)
			var cuchillo: float = Upgrades.cuchillo_drop_mult(afin_c, req) if afin_c > 0.0 else 1.0
			var f_piso: float = data.drop_factor_piso(piso)
			_soltar(piezas, grupos, data.drop_material, data.drop_chance * f_piso * cuchillo,
				data.drop_cantidad_min, data.drop_cantidad_max, cal_m, rng)
			_soltar(piezas, grupos, data.nucleo, data.nucleo_chance * f_piso * cuchillo, 1, 1, cal_m, rng)
			_soltar(piezas, grupos, data.drop_extra, data.drop_extra_chance,
				data.drop_extra_min, data.drop_extra_max, cal_m, rng)

	# --- El desenlace: la misma parte de cada grupo.
	var castigo: Dictionary = aplicar_perdida(piezas, desenlace)
	# --- La mochila: en proporcion al objetivo.
	var corte: Dictionary = recortar_por_peso(castigo["quedan"], tope_carga(pjs, entradas_cofre), grupos)

	# Agrupar para que el encargo guarde poco y viaje ligero.
	var cuenta: Dictionary = {}
	var cuenta_c: Dictionary = {}
	var dinero: int = 0
	for p in corte["traidas"]:
		if p.has("cristal"):
			var clave_c: String = "%d|%d" % [int(p["cristal"]), int(p["calidad"])]
			cuenta_c[clave_c] = int(cuenta_c.get(clave_c, 0)) + 1
			var c := Cristal.new()
			c.categoria = int(p["cristal"])
			c.calidad = int(p["calidad"])
			dinero += c.valor_estimado()
			continue
		var clave: String = "%s|%d|%.1f|%d" % [(p["material"] as MaterialData).resource_path,
			int(p["calidad"]), float(p.get("cm", 0.0)), int(p["grupo"])]
		cuenta[clave] = int(cuenta.get(clave, 0)) + 1
	var botin: Array = []
	for clave in cuenta:
		var partes: PackedStringArray = clave.split("|")
		botin.append({"ruta": partes[0], "calidad": int(partes[1]), "cm": float(partes[2]),
			"grupo": int(partes[3]), "n": int(cuenta[clave])})
	var cristales: Array = []
	for clave in cuenta_c:
		var pc: PackedStringArray = clave.split("|")
		cristales.append({"categoria": int(pc[0]), "calidad": int(pc[1]), "n": int(cuenta_c[clave])})

	return {
		"desenlace": desenlace,
		"botin": botin,
		"cristales": cristales,
		"dinero": dinero,
		"rotos": rotos,
		"perdido_desenlace": int(castigo["perdido"]),
		"perdido": int(corte["perdido"]),
		"kg": float(corte["kg"]),
		"excelia": excelia_de(pjs, piso, peleas_n, trabajo, extracciones, afinidades, desenlace, miembros),
		"partes": partes_de(pjs, peleas_n, trabajo, extracciones, familias, miembros),
		"trabajadas": trabajadas,
		"bichos": bichos,
		"peleas": peleas_n,
		"ratio": pg / requisito_mostrado(piso),
	}

# Un bicho suelta (o no) una cosa. Solo entra si su grupo esta en el objetivo: lo demas se queda en
# el suelo.
static func _soltar(piezas: Array, grupos: Dictionary, m: MaterialData, chance: float, n_min: int,
		n_max: int, cal: int, rng: RandomNumberGenerator) -> void:
	if m == null or rng.randf() >= clampf(chance, 0.0, 1.0):
		return
	var g: int = grupo_de_drop(m)
	if not grupos.has(g):
		return
	var cuantos: int = rng.randi_range(maxi(1, n_min), maxi(1, maxi(n_min, n_max)))
	for _i in cuantos:
		piezas.append({"grupo": g, "material": m, "calidad": cal, "cm": 0.0})


# ============================================================
#  EL PARTE DE TRABAJO: lo que ha hecho cada uno ahi abajo
# ============================================================
# Las pasivas RNG, los contadores de desarrollo y el DESGASTE del equipo viven en Game y en los
# PersonajeData, asi que aqui solo se cuenta lo que han hecho, en primitivos, y lo aplica la maquina
# del DUEÑO de cada personaje (Game.aplicar_parte_encargo).
const DANO_DADO_POR_PELEA := 60.0
const DANO_RECIBIDO_POR_PELEA := 25.0
# Lo que PARA levantando la guardia (contador de la Autorregeneracion). PROVISIONAL.
const DANO_BLOQUEADO_POR_PELEA := 10.0
const ESQUIVAS_POR_PELEA := 0.3
const HECHIZOS_POR_PELEA := 3.0
# DESGASTE: golpes que da y que encaja cada uno por pelea. Son los mismos que calibran VALE_UNA_PELEA,
# y cada uno gasta con el DESGASTE_ARMA / DESGASTE_ARMOR de siempre.
const GOLPES_DADOS_POR_PELEA := 3.0
const GOLPES_RECIBIDOS_POR_PELEA := 2.0

static func partes_de(pjs: Array, peleas_n: int, trabajo: Dictionary, extracciones: Dictionary,
		familias: Dictionary, miembros: Array) -> Array:
	var n: int = maxi(1, pjs.size())
	var salida: Array = []
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj == null:
			continue
		# Las bajas se reparten entre todos: el slayer se gana matando, y matan entre todos.
		var suyas: Dictionary = {}
		var bichos_suyos: int = 0
		for f in familias:
			var k: int = int(round(float(familias[f]) / float(n)))
			if k > 0:
				suyas[int(f)] = k
				bichos_suyos += k
		salida.append({
			"uid": pj.uid,
			"dueno": _dueno_de(miembros, pj.uid),
			"unidades": (trabajo.get(pj.uid, {}) as Dictionary).duplicate(),
			"extracciones": int((extracciones.get(pj.uid, {}) as Dictionary).get("n", 0)),
			"peleas": peleas_n,
			"bichos": bichos_suyos,
			"familias": suyas,
			"dano_dado": peleas_n * DANO_DADO_POR_PELEA,
			"dano_recibido": peleas_n * DANO_RECIBIDO_POR_PELEA,
			"dano_bloqueado": peleas_n * DANO_BLOQUEADO_POR_PELEA,
			"esquivas": peleas_n * ESQUIVAS_POR_PELEA,
			"hechizos": peleas_n * HECHIZOS_POR_PELEA,
			"golpes_dados": peleas_n * GOLPES_DADOS_POR_PELEA,
			"golpes_recibidos": peleas_n * GOLPES_RECIBIDOS_POR_PELEA,
		})
	return salida
