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
# Excelia. La escala es la misma 3:2:1, pero NORMALIZADA a que el exito valga 1.0: desde que una
# unidad de encargo paga como un nodo que picas tu, un x3 encima haria que trabajar de encargo
# enseñara el TRIPLE que hacerlo tu mismo, que es absurdo. El exito es el caso normal, asi que es el
# que tiene que valer "lo que vale".
const MULT_DESENLACE := [1.0, 2.0 / 3.0, 1.0 / 3.0]
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
#  CLASE DE COMBATE
#  Aunque los mandes a picar piedra ahi abajo hay bichos, asi que TODOS pelean y todos se llevan
#  excelia de combate. Antes esa excelia era fuerza/resistencia al 50/50 para todo el mundo, con lo
#  que un tio con baston y magias volvia mas fuerte de brazos: absurdo.
#
#  La clase NO se guarda en el personaje ni se elige de por vida (para eso ya estan las habilidades,
#  que son raras y ya diferencian a la gente). Es una ORDEN que das al mandar la expedicion, y las
#  opciones salen de lo que lleve puesto ESE dia. Cambiale el arma y cambian sus clases.
#
#  Solo decide A QUE STATS va su excelia de combate. No toca el % de exito ni el desenlace: eso lo
#  siguen decidiendo el poder y el equipo, que ya estaban calibrados.
# ============================================================
enum Clase { GUERRERO, GUERRERO_PESADO, PICARO, TANQUE, MAGO, GUERRERO_MAGICO }

const NOMBRE_CLASE := {
	Clase.GUERRERO: "Guerrero", Clase.GUERRERO_PESADO: "Guerrero pesado",
	Clase.PICARO: "Pícaro", Clase.TANQUE: "Tanque",
	Clase.MAGO: "Mago", Clase.GUERRERO_MAGICO: "Guerrero mágico",
}

# Para las casillas de la tarjeta, que son estrechas: ahi no caben "Guerrero pesado" ni "Guerrero
# magico" enteros y se recortaban a media palabra. El nombre largo va en el tooltip.
const ABREV_CLASE := {
	Clase.GUERRERO: "Guerrero", Clase.GUERRERO_PESADO: "G. pesado",
	Clase.PICARO: "Pícaro", Clase.TANQUE: "Tanque",
	Clase.MAGO: "Mago", Clase.GUERRERO_MAGICO: "G. mágico",
}

# Por que NO puedes elegirla. Es el tooltip de la casilla deshabilitada.
const REQUISITO_CLASE := {
	Clase.GUERRERO: "Necesita un arma ligera (espada corta, larga o maza).",
	Clase.GUERRERO_PESADO: "Necesita un arma a dos manos (mandoble, hacha o martillo).",
	Clase.PICARO: "Necesita una daga o un estoque.",
	Clase.TANQUE: "Necesita un escudo en la mano secundaria.",
	Clase.MAGO: "Necesita magias equipadas.",
	Clase.GUERRERO_MAGICO: "Necesita magias equipadas Y un arma melee (la varita no cuenta).",
}

# Como reparte su excelia de COMBATE cada clase. Cada fila SUMA 1.0 a proposito: la clase cambia a
# donde va el aprendizaje, no cuanto. Asi se puede tocar esta tabla sin recalibrar nada.
#
# Y son las cinco stats, no dos: a un mago le pegan (resistencia) y esquiva (agilidad) igual que a
# cualquiera, y si se queda sin mana pega un bastonazo (algo de fuerza). Lo que no hace es ponerse
# cachas peleando. El 0.0 se escribe igual para que la tabla se lea de un vistazo.
const PESOS_CLASE := {
	# TODO EL QUE PELEA PEGA, asi que la Fuerza no se hunde por clase: un picaro con dagas da MAS
	# golpes que un mandoble, no menos. Lo que separa a las clases es a donde va el resto (el picaro
	# esquiva y critica, el pesado encaja). En el playtest el picaro sacaba 15 de Fuerza contra los
	# 46 del pesado, y eso no se sostenia.
	Clase.GUERRERO:        {"fuerza": 0.32, "resistencia": 0.24, "destreza": 0.22, "agilidad": 0.22, "magia": 0.00},
	Clase.GUERRERO_PESADO: {"fuerza": 0.40, "resistencia": 0.22, "destreza": 0.18, "agilidad": 0.20, "magia": 0.00},
	Clase.PICARO:          {"fuerza": 0.28, "resistencia": 0.12, "destreza": 0.27, "agilidad": 0.33, "magia": 0.00},
	# El TANQUE tenia 0.50 de Resistencia y en el playtest salio con +74 cuando los demas iban por
	# +46. Se queda en 0.38 porque encajar golpes es ya la ganancia mas generosa del juego
	# (GAIN_RESISTENCIA_GOLPE 0.345, contra 0.15 de atacar): con medio reparto encima se disparaba.
	Clase.TANQUE:          {"fuerza": 0.24, "resistencia": 0.40, "destreza": 0.19, "agilidad": 0.17, "magia": 0.00},
	# Y las dos MAGICAS suben su Magia: pelear es la UNICA forma de subirla —no hay ningun oficio de
	# recoleccion que la entrene—, asi que con el mismo peso que las demas se quedaba corta de por vida.
	Clase.MAGO:            {"fuerza": 0.07, "resistencia": 0.14, "destreza": 0.07, "agilidad": 0.17, "magia": 0.55},
	Clase.GUERRERO_MAGICO: {"fuerza": 0.26, "resistencia": 0.14, "destreza": 0.06, "agilidad": 0.14, "magia": 0.40},
}

# Las tres familias de arma, derivadas de WeaponData.Tipo. Este es EL UNICO sitio del proyecto que
# clasifica armas por familia; si algun dia hace falta en otro lado, se llama aqui y no se copia.
# "Pesada" es dos_manos Y NO magica: el baston tambien es de dos manos, pero es un arma de mago.
const ARMAS_PICARO := [WeaponData.Tipo.DAGA, WeaponData.Tipo.ESTOQUE]
const ARMAS_LIGERAS := [WeaponData.Tipo.ESPADA_CORTA, WeaponData.Tipo.ESPADA_LARGA,
	WeaponData.Tipo.MAZA_PEQ]

# Las clases que ESE personaje puede elegir hoy, por lo que lleva puesto. Nunca devuelve vacio:
# a puno limpio sigues siendo un guerrero.
static func clases_de(pj: PersonajeData) -> Array:
	var out: Array = []
	if pj == null:
		return [int(Clase.GUERRERO)]
	var w: WeaponData = Game.arma_main(pj)
	var tipo_w: int = int(w.tipo) if w != null else int(WeaponData.Tipo.PUNOS)
	var magica: bool = w != null and w.es_magica
	# Melee "de verdad": ni baston ni punos. Es lo que separa al guerrero magico del mago pelado.
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

	# Respaldo: con baston y sin magias no encajas en ninguna de las de arriba, y a punos tampoco.
	if out.is_empty():
		out.append(int(Clase.GUERRERO))
	return out

# La que se usa de verdad: valida lo que pidieron contra lo que pueden, y si no cuadra coge la
# primera disponible. El host llama a ESTO, porque un cliente puede mandar por RPC lo que le de la
# gana y no vamos a fiarnos de su numerito.
static func clase_valida(pj: PersonajeData, pedida: int) -> int:
	var disp: Array = clases_de(pj)
	return pedida if disp.has(int(pedida)) else int(disp[0])


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
		total += puntos_pieza(item, Game._meta(slot, pj)) * _peso_slot(slot, pj)
	return total

# Cuanto pesa cada ranura. El arma principal vale por DOS, y por TRES si es de dos manos.
#
# El x3 no es un premio: es que un arma a dos manos OCUPA la secundaria. Sin esto, un mandoble o un
# baston se comian los puntos de esa ranura por dejarla vacia —una ranura que no pueden llenar— y
# salian por debajo de la misma persona con arma de una mano y escudo, como si les faltara una pieza.
# Con el x3 un dos manos y un una-mano+secundaria cubren lo mismo, que es lo que de verdad pasa.
static func _peso_slot(slot: String, pj: PersonajeData) -> float:
	if slot != "main":
		return 1.0
	var w: WeaponData = pj.equipped_main as WeaponData
	return 3.0 if w != null and w.dos_manos else 2.0

static func mult_equipo(pj: PersonajeData) -> float:
	return clampf(DESNUDO + puntos_equipo(pj) / EQUIPO_DIV, DESNUDO, EQUIPO_TECHO)

# EL NUMERO. El que sale en la ficha y en cada fila del hogar.
#
# Sobre lo CONSOLIDADO (poder_jugador_puesto) y NO sobre el total oculto: la excelia que traen de un
# encargo esta pendiente hasta que descansan en el altar, no se ve en ninguna ficha, y sobre todo NO
# PELEA —las stats que pelean salen de ability_consolidado—. Contandola aqui pasaban dos cosas: dos
# personajes identicos en pantalla daban Poderes distintos sin forma de cuadrarlo, y el grupo se
# llevaba el encargo siguiente con una fuerza que todavia no se habia puesto.
static func poder(pj: PersonajeData) -> float:
	if pj == null:
		return 0.0
	return Game.poder_jugador_puesto(pj) * mult_equipo(pj)

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

# Una probabilidad (0..1) como texto, con HASTA dos decimales.
#
# En el tramo de en medio se lee mejor redondo ("77%"), pero en LOS DOS EXTREMOS hacen falta los
# decimales:
#   - cerca de 0, porque si no todo lo improbable parece igual de improbable ("0%").
#   - cerca de 100, porque redondear un 99.95 a "100%" es decir que algo es SEGURO cuando no lo es,
#     y ademas descuadra la linea: 0.02 + 0.03 + 99.95 suma 100, pero 0.02 + 0.03 + 100 no.
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

# El RETO MEDIO de un tipo: la media, ponderada por lo que sale, del reto de CADA material suyo.
#
# NO es lo mismo que curva_reto(exigencia_media), que es lo que se hacia antes, y la diferencia es
# gorda cuando una bolsa mezcla cosas facilisimas con cosas durisimas. La Comida junta setas
# (exigencia 30) con piedra de sal (150): la MEDIA da 90, que cae justo en el codo de la curva y
# pagaba 2.71 de Destreza por nodo — siete veces lo que una veta de cobre. Material a material, esa
# misma bolsa paga lo que de verdad se saca: casi nada por las setas y mucho por la sal.
#
# Y es ademas lo fiel a "como si lo recogieras tu": tu no recoges el material medio, recoges ESTE.
static func reto_medio(tipo: int, piso: int, suyo: float, of: Dictionary) -> float:
	var pool: Array = opciones(tipo, piso)
	if pool.is_empty():
		return 0.0
	var suma: float = 0.0
	var peso: float = 0.0
	for o in pool:
		var ex: float = Game._exigencia_material(o["material"] as MaterialData, piso)
		var w: float = float(o["peso"])
		suma += Game.curva_reto(ex / maxf(1.0, suyo), float(of["pivote"]), float(of["slope"]),
			float(of["tope"])) * w
		peso += w
	return suma / maxf(0.001, peso)

# ============================================================
#  FAENA: quien trabaja cada tipo
# ============================================================
# Al mandarlos le dices a cada uno a que va ("tu a las vetas, tu a pescar y a por bichos"). Se guarda
# como `faenas` en su entrada de `miembros`: una LISTA, porque a uno le puedes mandar varias cosas.
# Vacia = "lo que haga falta".
#
# LA REGLA, y es una sola: un tipo con gente asignada lo trabajan SOLO esos; un tipo al que no
# asignaste a nadie lo trabajan TODOS. Asi las casillas son una preferencia y no una trampa: si
# marcas tres cosas y solo dices quien va a una, las otras dos siguen saliendo.
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

# Sobre uids sueltos, porque lo llaman los dos lados: la resolucion (que tiene PersonajeData) y el
# pronostico de la UI (que en multi solo tiene fichas del roster).
static func uids_trabajando(miembros: Array, tipo: int, todos: Array) -> Array:
	var out: Array = []
	for u in todos:
		if faenas_de(miembros, String(u)).has(int(tipo)):
			out.append(String(u))
	return out if not out.is_empty() else todos

# Lo mismo, ya filtrado a PersonajeData.
static func trabajadores(pjs: Array, miembros: Array, tipo: int) -> Array:
	var out: Array = []
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj != null and faenas_de(miembros, pj.uid).has(int(tipo)):
			out.append(pj)
	return out if not out.is_empty() else pjs

# Las faenas que pidieron, limpias: fuera lo que no sea un tipo del encargo y fuera los repetidos.
# Si se queda vacia es "lo que haga falta", que es el valor por defecto y el de siempre.
static func faenas_validas(pedidas: Array, tipos_encargo: Array) -> Array:
	var out: Array = []
	for t in pedidas:
		var i: int = int(t)
		if tipos_encargo.has(i) and not out.has(i):
			out.append(i)
	return out


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

# Lo que decide la CALIDAD de una unidad, segun su tipo. Devuelve el MARGEN: cuanta stat de oficio
# les sobra por encima de la exigencia del material.
#
# Los materiales de monstruo tienen exigencia 0.0 en sus .tres, y no es un olvido: no se recolectan,
# se sacan de un cadaver. Asi que para BICHO no hay eje de herramienta que valga y la calidad la
# decide el COMBATE. Es ademas lo que hace el juego hoy: la calidad del drop sale de
# _calidad_material_de_cristal(), o sea de lo bien que rematas. Como el combate SI viene en ratio
# (adimensional, no hay exigencia que restar), se traduce a margen por la misma escala.
static func margen_calidad(tipo: int, m: MaterialData, piso: int, poder_reco: float,
		r_combate: float) -> float:
	if tipo == Tipo.BICHO:
		return (r_combate - 1.0) * MARGEN_PLENO
	return poder_reco - Game._exigencia_material(m, piso)

# MARGEN -> reparto de calidades.
#
# Antes esto iba por RATIO (poder / exigencia) y estaba mal planteado: un cociente le pide a cada
# material un esfuerzo proporcional a lo que ya vale. Llegar a x2 en algo de exigencia 40 sale
# gratis, y en algo de exigencia 500 pediria +500 puntos de stat, que sencillamente no existen. O
# sea que el techo de calidad se volvia inalcanzable justo donde importa.
#
# Ahora va por MARGEN ABSOLUTO: te pide una cantidad PLANA de stat por encima de la exigencia, la
# misma para el cobre en bruto que para lo del piso 13. Ir sobrado es ir sobrado.
#
# Calibrado contra el mismo punto de referencia de siempre (poder 100 contra exigencia 150, o sea
# margen -50 -> unos 30 dañado / 50 normal / 20 intacto), asi que el tramo bajo no se mueve.
# PURO no sale de un encargo (es el techo de Metalurgia) y ROTO tampoco se genera: fallar se modela
# como cantidad perdida y calidad peor, no como piezas rotas invisibles.
const MARGEN_PLENO := 100.0    # stat POR ENCIMA de la exigencia que da el 100% de intacto
const MARGEN_NULO := -90.0     # por debajo de esto no sale nada intacto
const MARGEN_MALO := 155.0     # cuanto por DEBAJO hace falta para el 75% de dañado

static func reparto_calidades(margen: float) -> Dictionary:
	var intacto: float = clampf((margen - MARGEN_NULO) / (MARGEN_PLENO - MARGEN_NULO), 0.0, 1.0)
	var danado: float = 0.75 * pow(clampf(-margen / MARGEN_MALO, 0.0, 1.0), 0.8)
	# Las dos ramas no se pisan: intacto solo empieza a subir a partir de MARGEN_NULO y dañado solo
	# existe con margen negativo, asi que su suma nunca pasa de 1 y `normal` es lo que queda.
	var normal: float = maxf(0.0, 1.0 - intacto - danado)
	return {"intacto": intacto, "normal": normal, "danado": danado}

static func calidad_tirada(margen: float, rng: RandomNumberGenerator) -> int:
	var p: Dictionary = reparto_calidades(margen)
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

# Reparte n unidades entre los tipos marcados A PARTES IGUALES, sin perder ninguna por el redondeo
# (las que sobran van a los primeros de la lista). Seis tipos = un sexto cada uno, marques a quien
# marques.
#
# Se probo pesarlo por CUANTA GENTE trabaja cada tipo, y salio mal por un sitio que no se veia venir:
# como un tipo sin nadie asignado "lo hacen todos", ese contaba con cuatro manos y los demas con una,
# asi que el unico tipo que NO habias pedido se llevaba el 44% de la expedicion. En el playtest eso
# fue media carga de setas y piedra de sal, y ademas subia Destreza a los cuatro (Comida, Plantas y
# Enemigos entrenan las tres Destreza).
#
# Quien trabaja cada tipo lo sigue decidiendo uids_trabajando: eso decide QUIEN, no CUANTO sale.
static func repartir(n: int, tipos: Array) -> Dictionary:
	var out: Dictionary = {}
	var k: int = maxi(1, tipos.size())
	var base: int = n / k
	var resto: int = n % k
	for i in tipos.size():
		# El reparto del RATO es a partes iguales, pero de un sitio del que solo salen cuatro setas
		# no se vuelve con doscientas por mucho que esperes: se recorta por lo que hay en el piso.
		out[int(tipos[i])] = int(round(float(base + (1 if i < resto else 0))
			* abundancia(int(tipos[i]))))
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
# UNA UNIDAD DE ENCARGO PAGA COMO UN NODO QUE PICAS TU. Ni mas ni menos, y no hay constante que la
# escale: el descuento ya lo hace UNID_HORA (recogen 6 por hora y persona, cuando jugando se sacan
# 60-100), asi que volver a descontarlo aqui seria cobrarles el trabajo dos veces.
#
# Y es justo lo que pasaba. Habia un RITMO_EXCELIA = 2.0 ("nodos equivalentes por hora") que les
# pagaba 2 nodos/hora aunque UNID_HORA dijera que trabajaban 6, y encima se multiplicaba por
# GAIN_FACTOR x GAIN_RECO = 0.245. Resultado medido en playtest: 8 horas de reloj real con cuatro
# personas daban +1/+7 por stat, cuando jugando esas mismas horas se sacan +100/+200. Veinte a
# cincuenta veces por debajo, no "algo por debajo".

# CUANTO PAGA UNA FAENA respecto a las demas. Es un ajuste de BALANCE del encargo, no una regla del
# mundo: hay bolsas que mezclan material facilisimo con material durisimo (la piedra de sal, de
# exigencia 150, es la mitad de la Comida; y el banco de peces tiene rarezas exigentisimas detras del
# gobio). Como el sistema paga por lo que te cuesta, esas dos pagaban x5.4 y x3 lo que una veta de
# cobre, y una sola faena decidia la expedicion entera: el tanque volvia con +74 de Resistencia por
# haber ido a pescar, no por ser tanque.
#
# Con esto ninguna se va mas alla del doble de las demas. Lo que NO se toca es la recoleccion de
# verdad: jugando, la sal y los peces raros siguen pagando lo que valen.
const RITMO_FAENA := {
	Tipo.PESCA: 0.47,    # x3.0 -> x1, o sea lo mismo que picar una veta
}

static func ritmo_faena(tipo: int) -> float:
	return float(RITMO_FAENA.get(int(tipo), 1.0))

# CUANTO HAY DE ESO EN EL PISO, comparado con una veta. No es balance: es el mapa.
#
# La mazmorra pone 8 vetas, 8 plantas y 8 maderas, y vuelven en RESPAWN_SEGUNDOS (5 min). Pero de la
# DESPENSA solo hay 1-2 piedras de sal y 2-3 silvestres, y esas tardan el doble en volver
# (RESPAWN_LENTO_SEGUNDOS, 10 min). O sea que hay del orden de cuatro veces menos comida que mineral
# y encima se recupera a la mitad de ritmo. De pesca hay UN estanque por piso.
#
# Sin esto, ocho horas de encargo traian tantas setas como piedras, que no existen en el piso, y
# ademas convertian la Comida en la mejor forma de subir Destreza del juego (57 contra los 35 de las
# Plantas) por un sitio del que se supone que sacas cuatro setas. Recortando las UNIDADES caen las
# dos cosas a la vez: traen menos comida Y aprenden menos de ella.
const ABUNDANCIA := {
	Tipo.VETA: 1.0,
	Tipo.PLANTA: 1.0,
	Tipo.MADERA: 1.0,
	Tipo.COMIDA: 0.22,   # ~4 nodos a mitad de ritmo contra 8 rapidos
	Tipo.PESCA: 0.7,     # un solo estanque, aunque su banco sea generoso
	Tipo.BICHO: 1.0,     # los bichos no se agotan: siguen brotando
}

static func abundancia(tipo: int) -> float:
	return float(ABUNDANCIA.get(int(tipo), 1.0))

# Cuantas peleas se comen por hora ahi abajo. Ocho horas cruzando un piso poblado son muchos
# encontronazos; una cada doce minutos es lo que sale de mirar el aforo y el ritmo de partos.
const PELEAS_HORA := 5.0
# Lo que saca de UNA pelea un miembro de un grupo de cuatro: unos 3 golpes dados
# (GAIN_FUERZA_ATAQUE 0.15) y 2 encajados (GAIN_RESISTENCIA_GOLPE 0.345). No es un numero inventado
# como el GAIN_COMBATE_HORA que habia antes: sale de las mismas constantes que usa combat.gd.
# Subido de 1.35: aplanar los pesos por clase (para que un picaro no saliera con 15 de Fuerza)
# repartia el mismo total entre mas stats y las principales se quedaban cortas. Lo que sube es lo que
# se lleva CADA UNO por pelea, no el numero de peleas.
const VALE_UNA_PELEA := 1.6

# Devuelve la lista de ganancias a aplicar: [{"uid", "abil", "base", "reto", "max_reto"}].
# NO las aplica: quien las aplique tiene que llamar a Game.ganar() con el PersonajeData correcto, que
# en multi puede vivir en otra maquina (ver la nota de las dos vias en net.gd).
# 'trabajadas' = {tipo: unidades} (las TRABAJADAS, no las traidas), 'afinidades' = {tipo: afinidad}.
# 'desenlace' escala todo por MULT_DESENLACE (x3 / x2 / x1).
static func excelia_de(pjs: Array, piso: int, duracion: int, trabajadas: Dictionary,
		afinidades: Dictionary, r_combate: float, desenlace: int, miembros: Array = []) -> Array:
	var req: float = requisito_combate(piso)
	var mult: float = float(MULT_DESENLACE[clampi(desenlace, 0, 2)])
	var todos: Array = _uids(pjs)
	var salida: Array = []
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj == null:
			continue
		# El reparto entre tipos se mide en CUOTA (que parte del rato dedicaron a cada cosa), no en
		# unidades sueltas: asi el desenlace entra UNA sola vez, por `mult`. Antes entraba dos veces
		# --tambien venia dentro del recuento de unidades, que ya llevaba CANTIDAD_DESENLACE-- y eso
		# hacia que un fracaso enseñara nueve veces menos que un exito en vez de tres.
		#
		# Y la cuota es SUYA, no del encargo: solo cuentan los tipos que EL trabaja. Por eso un minero
		# dedicado se lleva su rato entero en fuerza en vez de un tercio, aunque el grupo saliera a
		# tres cosas. Es lo que hace que asignar faenas valga para algo.
		# NODOS SUYOS, no cuotas: las unidades de ese tipo partidas entre los que lo trabajan. Si van
		# dos a las vetas se reparten las vetas, igual que jugando. Un tipo que el no trabaja no le
		# paga nada.
		var mios: Dictionary = {}
		for tipo in trabajadas:
			if int(trabajadas[tipo]) <= 0:
				continue
			var equipo_t: Array = uids_trabajando(miembros, int(tipo), todos)
			if not equipo_t.has(pj.uid):
				continue
			mios[int(tipo)] = float(trabajadas[tipo]) / float(maxi(1, equipo_t.size()))
		# --- A) por RECOLECTAR, UNA VEZ POR TIPO QUE EL TRABAJA. Cada tipo entrena SU stat: por eso
		# multiseleccionar reparte tambien el aprendizaje, y no es solo comodidad.
		for tipo in mios:
			var nodos: float = float(mios[tipo])
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
				reto_r = reto_medio(int(tipo), piso, suyo, of)
			salida.append({
				"uid": pj.uid, "abil": String(of["stat"]), "reto": reto_r,
				"max_reto": float(of["tope"]),
				# Por unidades TRABAJADAS, no traidas: currar ocho horas enseña lo mismo aunque la
				# mochila les obligara a dejar la mitad tirada. Y cada una paga como un nodo entero.
				"base": float(of["gain"]) * nodos * mult * ritmo_faena(int(tipo)),
			})
		# --- B) por PELEAR. Se la llevan TODOS aunque el encargo sea de picar piedra: ahi abajo hay
		# bichos. Game.reto() es la misma funcion que usa el combate, y el requisito del piso ya esta
		# en su escala (suma de habilidades), asi que entra tal cual.
		#
		# A DONDE va esa excelia lo decide la CLASE que le pusiste al mandarlo. Los pesos suman 1.0,
		# asi que el total es el mismo de antes y solo cambia el reparto: un mago sale de ahi con
		# magia y esquiva donde un guerrero pesado sale con brazos.
		var reto_c: float = Game.reto(req, 1, pj)
		var base_c: float = peleas(duracion) * VALE_UNA_PELEA * mult
		var pesos: Dictionary = pesos_clase_de(clase_de(miembros, pj.uid), pj)
		for abil in pesos:
			var peso: float = float(pesos[abil])
			if peso <= 0.0:
				continue
			# La magia se mide con la escala de la magia (RETO_MAX), no con la de los mamporros.
			salida.append({"uid": pj.uid, "abil": String(abil), "reto": reto_c,
				"max_reto": Game.RETO_MAX if abil == "magia" else Game.RETO_MAX_FISICO,
				"base": base_c * peso})
	return salida

# Cuantas peleas se comen en un encargo de esa duracion.
static func peleas(duracion: int) -> float:
	return PELEAS_HORA * float(duracion) / 3600.0

# Los pesos de una clase PARA ESE PERSONAJE. El candado: si no lleva hechizos equipados no puede
# ganar Magia peleando, por mucho que la tabla de su clase diga otra cosa — ese peso se reparte
# proporcionalmente entre las otras cuatro.
#
# Existe porque le puse un 0.05 de Magia al Tanque "por si acaso" y en el playtest salio un tanque
# con +1 de Magia sin llevar una sola magia encima. La tabla ya esta arreglada, pero el candado se
# queda: es la clase de error que vuelve por otra puerta.
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

static func _uids(pjs: Array) -> Array:
	var out: Array = []
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj != null:
			out.append(pj.uid)
	return out

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
	var miembros: Array = e.get("miembros", [])
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
	var por_tipo: Dictionary = repartir(
		unidades(duracion, n, golpes, float(CANTIDAD_DESENLACE[desenlace])), tipos)
	# Lo que TRABAJAN de verdad es la suma de lo que da cada tipo: repartir() recorta los que escasean
	# en el piso (ver ABUNDANCIA), asi que ya no coincide con lo que darian las horas a secas.
	var trabajadas: int = 0
	for t in por_tipo:
		trabajadas += int(por_tipo[t])

	# --- Eje 2: que sacan y con que calidad. La calidad la deciden SOLO los que trabajan ese tipo:
	# si mandaste al fuerte a las vetas y al torpe a las hierbas, el torpe no le estropea el mineral.
	var piezas: Array = []
	for tipo in por_tipo:
		var t: int = int(tipo)
		var poder_reco: float = poder_recolector(trabajadores(pjs, miembros, t), t,
			float(afinidades.get(t, 0.0)))
		for i in int(por_tipo[tipo]):
			var m: MaterialData = elegir_material(t, piso, rng)
			if m == null:
				continue
			var margen: float = margen_calidad(t, m, piso, poder_reco, r_c)
			var cal: int = calidad_tirada(margen, rng)
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
		"excelia": excelia_de(pjs, piso, duracion, por_tipo, afinidades, r_c, desenlace, miembros),
		"partes": partes_de(pjs, duracion, por_tipo, miembros),
		"trabajadas": trabajadas,
		"traidas": (corte["traidas"] as Array).size(),
		"perdido": int(corte["perdido"]),
		"ratio": r_c,
	}


# ============================================================
#  EL PARTE DE TRABAJO: que ha hecho cada uno ahi abajo
# ============================================================
# La excelia no es lo unico que sale de currar ocho horas: tambien se tiran las pasivas RNG y suben
# los contadores ocultos de los desarrollos (Cazador, Autorregeneracion, Reflejos, Erudito...). Pero
# eso vive en Game y en los PersonajeData, y esta clase es ESTATICA y no toca Game a proposito.
#
# Asi que aqui solo se cuenta lo que han hecho, en primitivos, y quien lo aplique tira los dados. Es
# ademas lo que hace falta para multijugador: el parte viaja con el informe y lo aplica la maquina
# del DUEÑO de cada personaje (ver las dos vias de net.gd), que es la unica que tiene su ficha.
#
# Bichos por pelea: los brotes del piso son de dos (ver spawn_zone), asi que dos abatidos por pelea.
const BICHOS_POR_PELEA := 2.0
# Cuanto reparte y cuanto encaja un miembro de un grupo de cuatro en UNA pelea del piso. Son los
# mismos ordenes de magnitud con los que se calibro VALE_UNA_PELEA.
const DANO_DADO_POR_PELEA := 60.0
const DANO_RECIBIDO_POR_PELEA := 25.0
const ESQUIVAS_POR_PELEA := 0.3        # EVADE_MIN es 0.03 y encajan ~6 golpes: se esquiva poco
const HECHIZOS_POR_PELEA := 3.0        # solo cuenta para quien lleve magias

static func partes_de(pjs: Array, duracion: int, trabajadas: Dictionary,
		miembros: Array) -> Array:
	var todos: Array = _uids(pjs)
	var n_peleas: float = peleas(duracion)
	var salida: Array = []
	for pj_ in pjs:
		var pj: PersonajeData = pj_ as PersonajeData
		if pj == null:
			continue
		# Unidades que ha trabajado EL, por tipo: el mismo reparto que paga la excelia.
		var uds: Dictionary = {}
		for tipo in trabajadas:
			if int(trabajadas[tipo]) <= 0:
				continue
			var equipo_t: Array = uids_trabajando(miembros, int(tipo), todos)
			if not equipo_t.has(pj.uid):
				continue
			uds[int(tipo)] = int(round(float(trabajadas[tipo]) / float(maxi(1, equipo_t.size()))))
		salida.append({
			"uid": pj.uid,
			# De quien es: lo necesita el reparto por red, igual que las entradas de excelia.
			"dueno": _dueno_de(miembros, pj.uid),
			"unidades": uds,
			"peleas": n_peleas,
			"bichos": int(round(n_peleas * BICHOS_POR_PELEA)),
			"dano_dado": n_peleas * DANO_DADO_POR_PELEA,
			"dano_recibido": n_peleas * DANO_RECIBIDO_POR_PELEA,
			"esquivas": n_peleas * ESQUIVAS_POR_PELEA,
			"hechizos": n_peleas * HECHIZOS_POR_PELEA,
		})
	return salida
