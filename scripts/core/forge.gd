# ============================================================
#  forge.gd
#  MATH del HERRERO: FUNDIR mineral -> lingotes, FORJAR lingotes -> equipo, y MEJORAR con
#  nucleos. Estatico, como StatsMath / Upgrades: solo tablas y formulas, sin estado.
#
#  Modelo (cerrado con el usuario):
#   - FUNDIR: N minerales de UNA MISMA CALIDAD -> 1 lingote de esa calidad. No se mezclan
#     calidades a proposito: juntando tres dañados no te sale un normal. La UNICA forma de
#     que el lingote salga MEJOR que el mineral es la habilidad METALURGIA, que tira por
#     subirlo un escalon (dañado -> normal -> intacto).
#   - FORJAR: lingotes + cuero. Aqui SI se mezclan calidades: el metal del lingote fija el
#     TIER y la calidad MEDIA de lo que metes tira la RAREZA. La habilidad HERRERIA empuja
#     esa tirada a tu favor (como si el material fuera algo mejor de lo que es).
#   - MEJORAR: cada +1 cuesta un nucleo mas que el anterior, y el nucleo marca el techo.
#
#  Las dos habilidades suben SOLAS con el oficio (como la Mezcla de la boticaria) y su curva
#  es asintotica: los primeros lingotes enseñan mucho, los mil siguientes ya no.
# ============================================================

extends RefCounted
class_name Forge

# --- REFINAR (fundir mineral, batir chapas, curtir cuero) ---
# Cuantos items del material EN BRUTO hacen falta para uno REFINADO. Son ITEMS, no unidades:
# aqui la calidad no rinde mas, tiene que ser la MISMA (tres dañados NO dan un normal). Lo
# unico que puede subirte un escalon es la habilidad del oficio.
const MINERAL_POR_LINGOTE := 3
const LINGOTE_POR_CHAPA := 1     # un lingote batido da una chapa (mismo metal, misma calidad)
const CUERO_POR_CURTIDO := 2

# DEUDA CONOCIDA (a proposito, no es un olvido): el METAL tiene tres tiers (cobre / hierro /
# adamante) pero la PIEL solo tiene uno, el cuero de rata. O sea que una pieza T2 se acaba
# cosiendo con la misma piel de rata que una T1, que no tiene ningun sentido.
#
# Lo suyo es que cada tier de metal pida piel de SU profundidad, pero hoy NINGUN enemigo
# suelta cuero que no sea el de rata: exigirlo ahora dejaria el T2 y el T3 imposibles de
# forjar. Asi que la regla se queda escrita y APAGADA hasta que haya bichos con pieles
# mejores; entonces basta con comparar el tier del cuero contra el del metal aqui.
static func cuero_vale_para(cuero: MaterialData, metal: MaterialData) -> bool:
	if cuero == null or metal == null:
		return false
	return true   # TODO(pieles por tier): return cuero.tier >= metal.tier

# METALURGIA: probabilidad de que el lingote salga UN ESCALON por encima del mineral que
# fundiste (dañado -> normal, normal -> intacto; un intacto ya no sube). Asintotica: nunca
# llega al tope, pero al principio se nota rapido.
const METALURGIA_MAX := 0.35   # tope de la probabilidad de subir de categoria
const METALURGIA_K := 30.0     # exp para llegar a ~63% del tope

static func prob_subir_calidad(metalurgia_exp: float) -> float:
	return METALURGIA_MAX * _curva(metalurgia_exp, METALURGIA_K)

# HERRERIA: empuja el score de calidad (0..1) con el que se tira la rareza. Con la herreria
# a tope, un material normal tira como si fuera bastante mejor... pero sin llegar a lo que
# da el material perfecto: la habilidad ayuda, no sustituye al buen metal.
const HERRERIA_BONUS_MAX := 0.15
const HERRERIA_K := 30.0

static func bonus_herreria(herreria_exp: float) -> float:
	return HERRERIA_BONUS_MAX * _curva(herreria_exp, HERRERIA_K)

# El METAL tambien empuja la rareza: forjar con adamante no solo sube el tier, ademas hace
# mas probables las rarezas buenas. Un tocho de metal noble ya viene medio hecho.
const BONUS_POR_TIER_METAL := 0.10   # T1 +0, T2 +0.10, T3 +0.20 al score

static func bonus_metal(lingote: MaterialData) -> float:
	if lingote == null:
		return 0.0
	return BONUS_POR_TIER_METAL * float(maxi(1, lingote.tier) - 1)


# --- RESERVADO (aun sin efecto; el enganche esta, los numeros no) ---
# Cuando estas habilidades tengan su curva definitiva (Excel), aqui entran:
#   - AHORRO DE MATERIAL: probabilidad de que fundir/forjar NO consuma parte de lo elegido.
#     Vale para las dos (Metalurgia al fundir, Herreria al forjar).
#   - GOLPE MAESTRO: probabilidad de que la Herreria saque la pieza UN TIER por encima del
#     que da el metal. Es el equivalente al "subir de categoria" que la Metalurgia hace con
#     los lingotes: cada oficio tiene su forma de regalarte un escalon.
static func prob_ahorro(_exp_val: float) -> float:
	return 0.0

static func prob_tier_extra(_herreria_exp: float) -> float:
	return 0.0

# Curva de oficio: 0 al empezar, asintota a 1. Sube deprisa al principio y luego se aplana.
static func _curva(exp_val: float, k: float) -> float:
	return 1.0 - exp(-maxf(0.0, exp_val) / maxf(1.0, k))


# Lo que SUBE cada contador por cada cosa que haces. PROVISIONAL -> Excel.
const OFICIO_POR_REFINADO := 1.0   # metalurgia (fundir/batir) y peleteria (curtir)
const HERRERIA_POR_PIEZA := 1.0


# --- COSTE de forja, derivado del valor_base de la pieza ---
# No hay una receta escrita a mano por cada pieza (serian 33 .tres): el coste se DERIVA de su
# precio de tienda. Lo caro cuesta mas material. Se paga en UNIDADES (un refinado puro rinde
# por 4, uno dañado por 1), asi que refinar bien te ahorra material.
#
# Dos ramas, y en esto se nota que una armadura es mas trabajo que un arma:
#   ARMA     = LINGOTE (se golpea directo) + algo de cuero para la empuñadura.
#   ARMADURA = CHAPA (un paso mas de refinado) + cuero, en la proporcion de su tipo. La de
#              cuero es casi toda piel; la ligera de metal lleva MAS cuero que metal; la
#              pesada, al reves; las placas son casi todo chapa.
const MONEDAS_POR_UNIDAD := 90.0
const METAL_MIN := 2

# Multiplicadores sobre las "unidades base" (precio / MONEDAS_POR_UNIDAD): [metal, cuero].
const MIX_ARMA := [1.0, 0.35]
const MIX_ARMADURA := {
	ArmorData.Tipo.CUERO: [0.25, 2.0],             # hebillas y poco mas; todo piel
	ArmorData.Tipo.HIERRO: [0.7, 1.2],             # ligera: mas cuero que metal
	ArmorData.Tipo.HIERRO_COMPLETO: [1.2, 0.5],    # pesada: mas metal que cuero
	ArmorData.Tipo.PLACAS: [1.5, 0.25],            # casi todo chapa
}

# Coste de forjar `base`, en UNIDADES: {"metal": n, "cuero": n, "usa_chapa": bool}.
# 'usa_chapa' dice de que rama tira el metal: chapa (armadura) o lingote (arma).
static func coste(base: Resource) -> Dictionary:
	if base == null:
		return {"metal": 0, "cuero": 0, "usa_chapa": false}
	var uds: float = float(base.get("valor_base")) / MONEDAS_POR_UNIDAD
	var mix: Array = MIX_ARMA
	var usa_chapa: bool = false
	if base is ArmorData:
		usa_chapa = true
		mix = MIX_ARMADURA.get(int((base as ArmorData).tipo), MIX_ARMA)
	return {
		"metal": maxi(METAL_MIN, int(round(uds * float(mix[0])))),
		"cuero": maxi(1, int(round(uds * float(mix[1])))),
		"usa_chapa": usa_chapa,
	}


# --- TIER: lo fija el metal del lingote (su 'tier' de MaterialData) ---
static func tier_de_metal(lingote: MaterialData) -> int:
	return 1 if lingote == null else maxi(1, lingote.tier)


# --- RAREZA: tabla de pesos que se DEFORMA con la calidad media del material ---
# Tres tablas ancla (pesos, no porcentajes: se normalizan). El score de calidad (0 = todo
# dañado, 0.5 = todo normal, 1 = todo intacto, + el empujon de la Herreria) INTERPOLA.
#   [Comun, Poco comun, Raro, Epico, Legendario, Mitico, Obra maestra]
# Con todo INTACTO: comun y poco comun a CERO, la moda es Epico (45%), por debajo Raro (25%)
# y despues Legendario (20%); mitico 7.5% y obra maestra 2.5%. Que Raro sea MENOS probable
# que Epico teniendo material perfecto es a proposito: el buen metal no te da "algo decente",
# te da algo bueno.
const PESOS_DANADO: Array[float]  = [70.0, 25.0,  5.0,  0.0,  0.0, 0.0, 0.0]
const PESOS_NORMAL: Array[float]  = [25.0, 35.0, 25.0, 12.0,  3.0, 0.0, 0.0]
const PESOS_INTACTO: Array[float] = [ 0.0,  0.0, 25.0, 45.0, 20.0, 7.5, 2.5]
# Cuarta ancla: LINGOTE PURO (score 1.5), que solo sale fundiendo con Metalurgia alta. Es el
# unico sitio del que sale la obra maestra con cierta frecuencia: fuera tambien el Raro, la
# moda se va a Legendario y la OM sube a 8%. El techo del oficio, no del botin.
const PESOS_PURO: Array[float]    = [ 0.0,  0.0,  0.0, 25.0, 42.0, 25.0, 8.0]
const SCORE_PURO := 1.5

static func pesos_rareza(score: float) -> Array:
	var s: float = clampf(score, 0.0, SCORE_PURO)
	var out: Array = []
	for i in PESOS_NORMAL.size():
		var v: float
		if s <= 0.5:
			v = lerpf(PESOS_DANADO[i], PESOS_NORMAL[i], s / 0.5)
		elif s <= 1.0:
			v = lerpf(PESOS_NORMAL[i], PESOS_INTACTO[i], (s - 0.5) / 0.5)
		else:
			v = lerpf(PESOS_INTACTO[i], PESOS_PURO[i], (s - 1.0) / (SCORE_PURO - 1.0))
		out.append(maxf(0.0, v))
	return out


# Probabilidades REALES (0..1) por rareza, derivadas de los pesos. Nunca se escriben a mano:
# la UI las pinta de aqui, asi que lo que ves es lo que va a tirar.
static func probs_rareza(score: float) -> Array:
	var pesos: Array = pesos_rareza(score)
	var total: float = 0.0
	for p in pesos:
		total += float(p)
	var out: Array = []
	for p in pesos:
		out.append(0.0 if total <= 0.0 else float(p) / total)
	return out


static func tirar_rareza(score: float) -> int:
	# (el score que llega aqui ya lleva sumado el empujon de la Herreria)
	var pesos: Array = pesos_rareza(score)
	var total: float = 0.0
	for p in pesos:
		total += float(p)
	if total <= 0.0:
		return Upgrades.Rareza.COMUN
	var t: float = randf() * total
	for i in pesos.size():
		t -= float(pesos[i])
		if t <= 0.0:
			return i
	return Upgrades.Rareza.COMUN


# --- MEJORAR con NUCLEOS ---
# Subir de +k a +(k+1) cuesta (k+1) nucleos: la primera mejora es barata y la septima duele.
# El nucleo manda dos cosas mas (ya en MaterialData): a QUE sirve (uso_mejora ARMA/ARMADURA)
# y hasta donde deja llegar (mejora_max: el de slime se queda en +3, el de fuego llega a +7).
static func nucleos_para_mejora(mejoras_actuales: int) -> int:
	return maxi(1, mejoras_actuales + 1)


static func nucleo_vale(nucleo: MaterialData, item: Resource) -> bool:
	if nucleo == null or item == null or int(nucleo.familia) != MaterialData.Familia.NUCLEO:
		return false
	match int(nucleo.uso_mejora):
		MaterialData.UsoMejora.ARMA:
			return not (item is ArmorData)
		MaterialData.UsoMejora.ARMADURA:
			return item is ArmorData
		_:
			return true   # CUALQUIERA
