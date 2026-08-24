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
#     TIER y la calidad MEDIA de lo que metes tira la RAREZA. La habilidad HERRERIA hace DOS
#     cosas: empuja esa tirada a tu favor (como si el material fuera algo mejor de lo que es)
#     y tira por devolverte parte del material. La rareza PRISTINA, en cambio, no sale de la
#     habilidad: sale del material PURO (ver PESOS_PURO).
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
const MINERAL_POR_LINGOTE := 2
const LINGOTE_POR_CHAPA := 1     # un lingote batido da una chapa (mismo metal, misma calidad)
const MADERA_POR_TABLON := 3     # tres maderas aserradas dan un tablon (mismo tier, misma calidad)
# CARBONERA: dos maderas quemadas dan un carbon. MENOS que el tablon a proposito -- si costara lo
# mismo, quemar lena competiria de tu a tu con el mango de las armas y nadie haria carbon. El
# carbon es el destino BARATO de la madera; lo caro es el tablon.
const MADERA_POR_CARBON := 2
const CUERO_POR_CURTIDO := 2
# Piezas de la MOCHILA. Las hebillas salen caras en metal (3 lingotes por juego): son un puñado
# de herrajes pequeños, pero hay que hacerlos de uno en uno.
const LINGOTE_POR_HEBILLAS := 3
const CUERO_POR_CORREA := 2

# El ACOMPAÑANTE del metal tiene que ser de SU altura: no tiene ningun sentido coser una
# coraza de acero con la misma piel de rata que un chaleco de cobre, ni ponerle a una espada
# de acero un mango de la madera que se cae de las paredes del primer piso.
#
# ARMADURA -> chapa + CUERO. Y aqui esta la gracia: hoy el unico cuero que existe es el de
# rata (T1), asi que exigir esto deja la armadura T2 y T3 SIN FORJAR. Es a proposito, no es
# un bug: esas piezas estaban absurdamente rotas para lo pronto que se conseguian. La
# armadura T2 se desbloqueara sola el dia que un bicho hondo suelte una piel mejor, sin
# tocar una linea de aqui.
#
# ARMA -> lingote + MADERA (el mango). Las armas SI suben de tier, porque la madera si tiene
# tres tiers y sale de la misma profundidad que el metal (madera dura y hierro, los dos en el
# piso 7 y con la misma exigencia). Un arma buena pide bajar; una armadura buena, ademas, pide
# un bicho que aun no existe.
static func cuero_vale_para(cuero: MaterialData, metal: MaterialData) -> bool:
	return _acompana_a(cuero, metal)

static func madera_vale_para(madera: MaterialData, metal: MaterialData) -> bool:
	return _acompana_a(madera, metal)

static func _acompana_a(mat: MaterialData, metal: MaterialData) -> bool:
	if mat == null or metal == null:
		return false
	return mat.tier >= metal.tier

# METALURGIA: probabilidad de que el lingote salga UN ESCALON por encima del mineral que
# fundiste (dañado -> normal, normal -> intacto; un intacto ya no sube). Asintotica: nunca
# llega al tope, pero al principio se nota rapido.
const METALURGIA_MAX := 0.35   # tope de la probabilidad de subir de categoria
const METALURGIA_K := 30.0     # exp para llegar a ~63% del tope

# El input `factor` es el FACTOR DE RANGO del oficio (0..1; ver Game.factor_desarrollo): 0 = no
# tienes el desarrollo, 1 = rango S. El bonus escala LINEAL con el rango (antes era una curva por exp).
static func prob_subir_calidad(factor: float) -> float:
	return METALURGIA_MAX * clampf(factor, 0.0, 1.0)

# METALURGIA / PELETERIA: probabilidad de RECUPERAR una pieza del material que acabas de gastar.
# El oficio no es solo hacerlo mejor, tambien es desperdiciar menos: el que sabe fundir saca el
# lingote con menos mineral. Devuelve como mucho 1 de las `por_uno` piezas que come el refinado,
# asi que ni con el oficio a tope el refinado sale gratis. Misma curva asintotica que el resto.
const DEVOLVER_MAX := 0.30   # tope de la probabilidad de recuperar una pieza
const DEVOLVER_K := 30.0     # exp para llegar a ~63% del tope

static func prob_devolver_material(factor: float) -> float:
	return DEVOLVER_MAX * clampf(factor, 0.0, 1.0)

# MEZCLA (boticaria): probabilidad de que la poción salga del SIGUIENTE escalon de su cadena de
# recetas (vida base -> vida +1 -> vida +2). Es la hermana de prob_subir_calidad: cada oficio
# regala un escalon de lo suyo. Mas baja que la Metalurgia a proposito: una poción de mas nivel
# vale bastante mas que un lingote un pelin mejor, y ademas la Mezcla YA da la doble poción.
# La que ya es la tope de su cadena no sube (ver Game.pocion_siguiente).
const MEZCLA_SUBIR_MAX := 0.15   # tope de la probabilidad de subir de escalon
const MEZCLA_SUBIR_K := 30.0     # exp para llegar a ~63% del tope

static func prob_subir_pocion(factor: float) -> float:
	return MEZCLA_SUBIR_MAX * clampf(factor, 0.0, 1.0)

# HERRERIA: empuja el score de calidad (0..1) con el que se tira la rareza. Con la herreria
# a tope, un material normal tira como si fuera bastante mejor... pero sin llegar a lo que
# da el material perfecto: la habilidad ayuda, no sustituye al buen metal.
const HERRERIA_BONUS_MAX := 0.15
const HERRERIA_K := 30.0

static func bonus_herreria(factor: float) -> float:
	return HERRERIA_BONUS_MAX * clampf(factor, 0.0, 1.0)

# HERRERIA (2ª mitad): ademas de empujar la rareza, el herrero curtido DESPERDICIA menos y te
# devuelve parte de lo que metes. Es lo mismo que hacen la Metalurgia y la Peleteria al refinar
# (prob_devolver_material): el oficio no es solo hacerlo mejor, tambien es aprovechar el material.
# Se tira UNA vez por ingrediente y devuelve UNA pieza, asi que forjar nunca sale gratis.
const HERRERIA_DEV_MAX := 0.30
const HERRERIA_DEV_K := 30.0

static func prob_devolver_forja(factor: float) -> float:
	return HERRERIA_DEV_MAX * clampf(factor, 0.0, 1.0)

# El METAL tambien empuja la rareza: forjar con acero no solo sube el tier, ademas hace
# mas probables las rarezas buenas. Un tocho de metal noble ya viene medio hecho.
const BONUS_POR_TIER_METAL := 0.10   # T1 +0, T2 +0.10, T3 +0.20 al score

# OJO: solo el TIER, no el sub-tier. En la FORJA de armas y armaduras no se puede fabricar con
# sub-tiers (la lista solo ofrece la banda base, ver Game.lingotes_conocidos): son material de
# MEJORA. Donde SI se fabrica con veta es en las herramientas, y esas usan bonus_metal_veta.
static func bonus_metal(lingote: MaterialData) -> float:
	if lingote == null:
		return 0.0
	return BONUS_POR_TIER_METAL * float(maxi(1, lingote.tier) - 1)


# El empujon del metal cuando la VETA tambien cuenta: las HERRAMIENTAS, el unico sitio donde se
# forja con sub-tier. Cada veta vale un TERCIO de tier, asi que el cobre profundo se nota de verdad
# pero no alcanza al hierro en bruto -- subir de tier tiene que seguir siendo el salto gordo.
#
# La veta ya se cobraba en lo que da la herramienta (afinidad y golpes ahorrados, ver
# Upgrades.tool_mods); esto es lo otro que pedia el material bueno: que la tirada de rareza tambien
# lo note. Sigue capado por score_final, o sea que con material intacto no suma nada.
const BONUS_POR_VETA := BONUS_POR_TIER_METAL / 3.0

static func bonus_metal_veta(lingote: MaterialData) -> float:
	if lingote == null:
		return 0.0
	return bonus_metal(lingote) + BONUS_POR_VETA * float(Upgrades.banda_columna(int(lingote.mejora_min)))


# El SCORE final con el que se tira la rareza, juntando las tres fuentes con SU jerarquia:
#   score_material -> 0 (dañado) .. 1 (intacto), y solo el PURO pasa de 1.
#   bonus_oficio   -> Herreria (o Peleteria en la mochila).
#   bonus_metal    -> el tier del lingote/chapa.
#
# La regla: pasar de 1.0 (el techo del material RECOLECTADO) es lo que abre la puerta al
# PRISTINO, y ahi solo llegan el material PURO y el OFICIO. El metal noble ayuda, pero por si
# solo NO fabrica un pristino: su empujon se queda en ese techo. Si no, un acero T3 con material
# intacto sacaba pristinos sin haber tocado la Metalurgia ni la Herreria, y toda la cadena de
# oficio (fundir puro -> forjar) se quedaba sin sentido.
# Efecto lateral asumido: si ya vas por encima de 1.0 (llevas puro), el metal no suma mas; a esas
# alturas el material ya es mejor que el metal.
static func score_final(score_material: float, bonus_oficio: float, bonus_metal_val: float) -> float:
	var sin_metal: float = score_material + bonus_oficio
	return maxf(sin_metal, minf(sin_metal + bonus_metal_val, 1.0))


# --- RESERVADO (aun sin efecto; el enganche esta, los numeros no) ---
# GOLPE MAESTRO: probabilidad de que la Herreria saque la pieza UN TIER por encima del que da
# el metal. Es el equivalente al "subir de categoria" que la Metalurgia hace con los lingotes:
# cada oficio tiene su forma de regalarte un escalon.
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
# Cada pieza lleva METAL + hasta dos fibras (MADERA para el mango, CUERO para el recubrimiento
# o la estructura), en la proporcion de su tipo:
#   ARMA normal = LINGOTE (la hoja) + MADERA (el mango) + un poco de CUERO (recubres el mango
#                 para que sea comodo de empuñar).
#   ARMA MAGICA (baston/varita) = casi toda MADERA + un poco de metal (la contera) + cuero del
#                 mango. Un baston de mas hierro que madera no tenia ningun sentido.
#   ESCUDO      = METAL + CUERO (las correas), sin mango de madera.
#   ARMADURA    = CHAPA + CUERO, en la proporcion de su tipo (la de cuero es casi toda piel; la
#                 ligera de metal lleva mas cuero que metal; las placas, casi todo chapa).
const MONEDAS_POR_UNIDAD := 90.0
const METAL_MIN := 2

# Multiplicadores sobre las "unidades base" (precio / MONEDAS_POR_UNIDAD).
# Armas: [metal, madera, cuero]. El cuero del mango es un pelin en todas.
const MIX_ARMA := [1.0, 0.35, 0.15]           # la hoja manda; mango de madera; agarre de cuero
const MIX_ARMA_MAGICA := [0.25, 1.0, 0.15]    # baston/varita: casi toda madera, algo de contera
const MIX_ESCUDO := [1.0, 0.0, 0.4]           # metal + correas de cuero, sin mango
# Armaduras: [metal, cuero] (sin madera).
const MIX_ARMADURA := {
	ArmorData.Tipo.CUERO: [0.25, 2.0],             # hebillas y poco mas; todo piel
	ArmorData.Tipo.HIERRO: [0.7, 1.2],             # ligera: mas cuero que metal
	ArmorData.Tipo.HIERRO_COMPLETO: [1.2, 0.5],    # pesada: mas metal que cuero
	ArmorData.Tipo.PLACAS: [1.5, 0.25],            # casi todo chapa
}

# Coste de forjar `base`, en UNIDADES: {"metal": n, "madera": n, "cuero": n, "usa_chapa": bool}.
# 'usa_chapa' dice de que rama tira el metal (chapa = armadura, lingote = arma/escudo/varita).
# QUE material concreto es cada fibra (y su tier) lo decide Game.ingredientes_forja.
static func coste(base: Resource) -> Dictionary:
	if base == null:
		return {"metal": 0, "madera": 0, "cuero": 0, "usa_chapa": false}
	var uds: float = float(base.get("valor_base")) / MONEDAS_POR_UNIDAD
	var m_metal: float = 1.0
	var m_madera: float = 0.0
	var m_cuero: float = 0.0
	var usa_chapa: bool = false
	if base is ArmorData:
		usa_chapa = true
		var mix: Array = MIX_ARMADURA.get(int((base as ArmorData).tipo), [1.0, 1.0])
		m_metal = mix[0]; m_cuero = mix[1]
	elif base is ShieldData:
		m_metal = MIX_ESCUDO[0]; m_madera = MIX_ESCUDO[1]; m_cuero = MIX_ESCUDO[2]
	elif base is WandData or (base is WeaponData and (base as WeaponData).es_magica):
		m_metal = MIX_ARMA_MAGICA[0]; m_madera = MIX_ARMA_MAGICA[1]; m_cuero = MIX_ARMA_MAGICA[2]
	else:
		m_metal = MIX_ARMA[0]; m_madera = MIX_ARMA[1]; m_cuero = MIX_ARMA[2]
	return {
		"metal": maxi(METAL_MIN, int(round(uds * m_metal))),
		"madera": (maxi(1, int(round(uds * m_madera))) if m_madera > 0.0 else 0),
		"cuero": (maxi(1, int(round(uds * m_cuero))) if m_cuero > 0.0 else 0),
		"usa_chapa": usa_chapa,
	}


# El APROVECHAMIENTO del recorte ya no es una tirada: lo que sobra vuelve directo como material
# dañado (ver Game._tirar_devolucion). Se acabo la probabilidad, y con ella la clase Crafting.


# --- TIER: lo fija el metal del lingote (su 'tier' de MaterialData) ---
static func tier_de_metal(lingote: MaterialData) -> int:
	return 1 if lingote == null else maxi(1, lingote.tier)


# --- RAREZA: tabla de pesos que se DEFORMA con la calidad media del material ---
# Tres tablas ancla (pesos, no porcentajes: se normalizan). El score de calidad (0 = todo
# dañado, 0.5 = todo normal, 1 = todo intacto, + el empujon de la Herreria) INTERPOLA.
#   [Comun, Poco comun, Raro, Epico, Legendario, Mitico, Obra maestra, Pristino]
# Con todo INTACTO: comun y poco comun a CERO, la moda es Epico (45%), por debajo Raro (25%)
# y despues Legendario (20%); mitico 7.5% y obra maestra 2.5%. Que Raro sea MENOS probable
# que Epico teniendo material perfecto es a proposito: el buen metal no te da "algo decente",
# te da algo bueno.
#
# El PRISTINO esta a 0 en las TRES primeras anclas: solo la cuarta (el PURO) le da peso. Para
# asomarse a el hay que pasar de 1.0, y a eso solo llegan el material PURO y el OFICIO (la
# Herreria); el metal noble por si solo no (ver score_final). O sea: el pristino es del que se
# curra la cadena de oficio, por una via o por la otra.
# Ojo: pesos_rareza itera sobre el tamaño de estas tablas, asi que las cuatro tienen que medir
# lo mismo que RAREZA_NOMBRE.
const PESOS_DANADO: Array[float]  = [70.0, 25.0,  5.0,  0.0,  0.0, 0.0, 0.0, 0.0]
const PESOS_NORMAL: Array[float]  = [25.0, 35.0, 25.0, 12.0,  3.0, 0.0, 0.0, 0.0]
const PESOS_INTACTO: Array[float] = [ 0.0,  0.0, 25.0, 45.0, 20.0, 7.5, 2.5, 0.0]
# Cuarta ancla: LINGOTE PURO (score 1.5), que solo sale fundiendo con Metalurgia alta. Es el
# unico sitio del que salen la obra maestra y el PRISTINO: fuera tambien el Raro, la moda se va
# a Legendario, la OM sube al 12% y el pristino asoma al 6%. El techo del oficio, no del botin.
# Como el score interpola INTACTO -> PURO, la probabilidad de pristino sube SOLA con la
# proporcion de material puro que metas: no hace falta ninguna tirada aparte.
const PESOS_PURO: Array[float]    = [ 0.0,  0.0,  0.0, 20.0, 38.0, 24.0, 12.0, 6.0]
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
# El coste sube DENTRO de la banda de cada nucleo y se REINICIA al saltar al siguiente. Cada
# nucleo cubre un tramo de niveles (mejora_min..mejora_max en MaterialData), y dentro de el la
# cuenta BASE va 1, 2, 3: la primera mejora de ese nucleo es barata y la ultima duele. Pero el coste
# final depende de la PIEZA (`item`):
#   - ARMADURA: PLANO a 1 por mejora. Son CINCO piezas; pedir 6 nucleos por pieza y banda seria
#     infumable (6x5 = 30 por banda). A 1, subir el juego entero cuesta lo razonable.
#   - ARMA a UNA mano / escudo / varita: la base 1, 2, 3 (6 por banda).
#   - ARMA a DOS MANOS (pesada): el DOBLE, 2, 4, 6. Llevas UNA sola arma pesada, asi que iguala el
#     coste de subir DOS armas ligeras (dual).
#
# Antes la cuenta era acumulativa GLOBAL (mejoras+1), asi que el nucleo nuevo entraba cobrando
# 4, 6, 8... de una tacada. Llegar al +7 pedia 13 nucleos de slime de fuego. Ver mejora_min.
static func nucleos_para_mejora(mejoras_actuales: int, nucleo: MaterialData = null, item: Resource = null) -> int:
	var desde: int = 0 if nucleo == null else maxi(0, nucleo.mejora_min)
	var base: int = maxi(1, mejoras_actuales + 1 - desde)
	# EL FAROLILLO NO ESCALA: 1 de cada rama en todos los niveles. Ya paga por otro lado -- pide
	# DOS nucleos en vez de uno --, asi que encarecerlo ademas dentro de la banda lo dejaria
	# fuera de precio. Es la misma decision que en la armadura (plano a 1) y por el mismo
	# motivo: cuando una pieza ya multiplica el coste por otro concepto, el escalon sobra.
	if item is ToolData:
		return 1
	if item is ArmorData:
		return 1
	if item is WeaponData and (item as WeaponData).dos_manos:
		return base * 2
	return base


# Y ademas del nucleo, MATERIAL: el nucleo es el permiso, pero la pieza hay que rehacerla. Se
# paga de lo MISMO con lo que se forjo y del MISMO tier (metal + su fibra: madera si es un arma,
# cuero si es una armadura), asi que reforzar una pieza honda pide bajar a por su material.
#
# La calidad da igual aqui (la rareza ya esta tirada y no se toca): solo cuentan las UNIDADES.
# Por eso el menu no te hace elegir calidades como en la forja: gasta lo peor que tengas.
const MEJORA_METAL_BASE := 2
const MEJORA_FIBRA_BASE := 1
# Cuanto sube el coste DE PRINCIPIO A FIN de una banda: el primer escalon de un sub-tier cuesta la
# base y el ultimo la base + esto. Es EL dial de esta curva; no hay ningun otro numero suelto.
const MEJORA_PASO_BANDA := 2

# La BANDA de mejoras que cubre un material: Vector2i(desde, ancho). Un material sin banda
# (mejora_max <= 0) vale para todo, y ahi no hay reparto que hacer: se devuelve el tramo de 3 de
# siempre. Hermana de _material_de_nivel, que hace la busqueda al reves (del nivel al material).
static func banda_de(mat: MaterialData) -> Vector2i:
	if mat == null or mat.mejora_max <= 0:
		return Vector2i(0, 3)
	return Vector2i(maxi(0, mat.mejora_min), maxi(1, mat.mejora_max - mat.mejora_min))


# Unidades de material que cuesta pasar de +k a +(k+1). PROVISIONAL -> Excel.
#
# El coste se REINICIA en cada sub-tier y se REPARTE a lo ancho de su banda. Las dos cosas:
#
#   - Reinicia porque el material tambien cambia. Antes esto era `BASE + n` continuo sobre toda la
#     escala (la funcion ni siquiera recibia el material, asi que no podia reiniciar), y el primer
#     escalon de cobre veteado entraba cobrando 5 uds como si viniera de seguido. Es el mismo fallo
#     que ya se arreglo en nucleos_para_mejora, que no se replico aqui.
#   - Se reparte porque las bandas NO miden lo mismo: la primera cubre 3 mejoras y las otras dos
#     cubren 6. Subiendo de uno en uno, el +9 acabaria costando 7 uds; repartiendo, el ultimo
#     escalon de una banda cuesta lo mismo dure lo que dure (2->4 el metal, 1->3 la fibra), que es
#     lo que la hace comparable con el +3.
#
# El sobrecoste de lo hondo lo pone el MATERIAL, que es mas raro y hay que bajar a por el, no la
# cantidad. En una banda de 3 sale 2,3,4 y en una de 6 sale 2,2,3,3,4,4.
#
# La banda se saca del METAL (que siempre la trae en los datos) y vale para los dos costes; si no
# la tuviera se mira la fibra. Importa porque el cuero del ESCUDO se pide SIN banda (ver
# Game.cuero_de_tier con nivel 1) y no puede acabar con un reparto distinto al de su metal.
#
# 'base' decide QUIEN manda de los dos. En una pieza normal manda el METAL (es la hoja, la placa),
# y en un BASTON o una VARITA manda la MADERA, igual que al forjarlos (MIX_ARMA_MAGICA es
# [0.25, 1.0, 0.15]: casi toda madera y un poco de contera). Antes esta funcion no miraba la pieza
# y siempre pedia metal = fibra + 1, asi que mejorar un baston pedia mas hierro que madera --
# exactamente lo contrario de con lo que se habia fabricado.
static func material_para_mejora(mejoras_actuales: int, base: Resource = null,
		metal: MaterialData = null, fibra: MaterialData = null) -> Dictionary:
	var n: int = maxi(0, mejoras_actuales)
	var banda: Vector2i = banda_de(metal) if metal != null else banda_de(fibra)
	# Cuantos escalones llevas DENTRO de esta banda, repartidos sobre su ancho.
	var dentro: int = clampi(n - banda.x, 0, maxi(0, banda.y - 1))
	var sube: int = roundi(float(dentro) * float(MEJORA_PASO_BANDA) / float(maxi(1, banda.y - 1)))
	if es_arma_magica(base):
		return {
			"metal": MEJORA_FIBRA_BASE + sube,   # la contera: lo menos
			"fibra": MEJORA_METAL_BASE + sube,   # el asta: lo que de verdad se rehace
		}
	return {
		"metal": MEJORA_METAL_BASE + sube,
		"fibra": MEJORA_FIBRA_BASE + sube,
	}


# El mismo criterio que usan Game._es_arma_magica y coste(): un baston (WeaponData con es_magica)
# o una varita. Vive aqui ademas de en Game porque la math de la forja no debe depender del autoload.
static func es_arma_magica(base: Resource) -> bool:
	return base is WandData or (base is WeaponData and (base as WeaponData).es_magica)


# item_tier = tier de la INSTANCIA del equipo (vive en su meta, no en el .tres base). -1 = no
# comprobar tier (compatibilidad). El gate por tier solo muerde si el nucleo declara tier_equipo > 0.
static func nucleo_vale(nucleo: MaterialData, item: Resource, item_tier: int = -1) -> bool:
	if nucleo == null or item == null or int(nucleo.familia) != MaterialData.Familia.NUCLEO:
		return false
	# Gate por TIER: un nucleo de T1 no mejora equipo T2 (ni al reves). tier_equipo 0 = comodin.
	if item_tier >= 0 and nucleo.tier_equipo > 0 and nucleo.tier_equipo != item_tier:
		return false
	# EL FAROLILLO ADMITE LAS DOS RAMAS, y es la unica pieza del juego que lo hace. No es un
	# descuido de la separacion arma/armadura: es que su mejora PIDE UNA DE CADA (ver
	# Game.puede_mejorar), asi que aqui las dos tienen que pasar el filtro. Es tambien lo que
	# le da por fin un destino comun a las dos escaleras de nucleos y salida a los repetidos.
	if item is ToolData and (item as ToolData).es_lampara():
		return true
	match int(nucleo.uso_mejora):
		MaterialData.UsoMejora.ARMA:
			return not (item is ArmorData)
		MaterialData.UsoMejora.ARMADURA:
			return item is ArmorData
		_:
			return true   # CUALQUIERA


# LA PAREJA de un nucleo: el de la OTRA rama que cubre su misma banda. Lo usa el farolillo, que
# pide uno de cada (slime+rata, venenoso+rey rata, fuego+jabali...).
#
# Se empareja por BANDA y no por una tabla escrita a mano: asi, el dia que entren los nucleos
# T2, se emparejan solos con solo declararles su banda.
static func pareja_nucleo(nucleo: MaterialData, candidatos: Array) -> MaterialData:
	if nucleo == null:
		return null
	# UN COMODIN ES SU PROPIA PAREJA. Los nucleos de jefe (rey slime, minotauro) son CUALQUIERA y
	# son los UNICOS de su banda, asi que buscarle la otra rama no devuelve nada -- y con eso el
	# ultimo tramo de mejoras del farolillo quedaba imposible sin que nada lo dijera: solo se veia
	# el boton en gris. Devolviendose a si mismo hace los dos papeles, y quien lo gasta ya sabe que
	# entonces cuenta como uno solo (ver Game.mejorar_item).
	if int(nucleo.uso_mejora) == MaterialData.UsoMejora.CUALQUIERA:
		return nucleo
	var quiero: int = MaterialData.UsoMejora.ARMADURA \
		if int(nucleo.uso_mejora) == MaterialData.UsoMejora.ARMA \
		else MaterialData.UsoMejora.ARMA
	for c in candidatos:
		var m: MaterialData = c as MaterialData
		if m == null or m == nucleo:
			continue
		if int(m.uso_mejora) != quiero:
			continue
		if int(m.mejora_min) == int(nucleo.mejora_min) and int(m.tier_equipo) == int(nucleo.tier_equipo):
			return m
	return null


# --- FUNDIR EQUIPO: deshacer una pieza y recuperar la mitad ---
# Hasta ahora la unica salida para el equipo que no querias era VENDERLO. Fundirlo le da una
# segunda vida al material: recuperas la MITAD de lo que costaria fabricar esa pieza, y si
# estaba mejorada, tambien la mitad de los nucleos que se comio.
#
# El calculo se DERIVA de la receta (coste + material_para_mejora + nucleos_para_mejora), no de
# lo que metiste de verdad. Es a proposito: asi funciona igual con una pieza comprada en la
# tienda y con una partida guardada de antes de que esto existiera, sin tocar el formato del
# save. Lo que pierdes en fidelidad lo ganas en que no hay ningun caso raro.
const RECUPERACION := 0.5

# Unidades de metal / madera / cuero que devuelve fundir `base` con `mejoras` mejoras encima.
# El material de cada MEJORA (metal + su fibra: madera si es arma, cuero si es armadura o escudo)
# tambien cuenta: una pieza +5 lleva mucho material dentro.
#
# 'escalera' son los metales de SU tier ordenados por banda, y los pone Game (el unico que sabe si
# la pieza es arma o armadura; mismo trato que fundir_nucleos, que recibe la de nucleos). Hace falta
# porque desde que el coste se reinicia por sub-tier, reconstruir lo pagado exige saber en que banda
# caia cada escalon. Sin ella se cae a la banda por defecto, y eso DEVUELVE DE MAS en las bandas
# hondas: es decir, material infinito fundiendo y volviendo a mejorar.
static func fundir_material(base: Resource, mejoras: int, escalera: Array = []) -> Dictionary:
	var c: Dictionary = coste(base)
	var metal: int = int(c["metal"])
	var madera: int = int(c["madera"])
	var cuero: int = int(c["cuero"])
	# La fibra sale de la RECETA de la pieza y no de su clase: si lleva madera, la fibra es el
	# mango; si no, es cuero. Antes esto era `not (base is ArmorData)` = "es un arma", y el ESCUDO
	# se colaba por ahi: fundirlo devolvia MADERA, que no lleva (MIX_ESCUDO es metal + cuero).
	var fibra_es_madera: bool = madera > 0
	for k in range(maxi(0, mejoras)):
		# El metal de la banda que cubria ESE escalon: es de donde sale su reparto.
		var m: Dictionary = material_para_mejora(k, base, _material_de_nivel(escalera, k))
		metal += int(m["metal"])
		if fibra_es_madera:
			madera += int(m["fibra"])
		else:
			cuero += int(m["fibra"])
	return {
		"metal": int(floor(float(metal) * RECUPERACION)),
		"madera": int(floor(float(madera) * RECUPERACION)),
		"cuero": int(floor(float(cuero) * RECUPERACION)),
	}


# Los NUCLEOS que devuelve fundir una pieza que llego a +`mejoras`. Se reconstruye la escalera:
# para cada nivel se mira que nucleo tocaba (el de su banda) y cuanto costaba, y se devuelve la
# mitad. `escalera` son los nucleos ordenados por banda, y los pone Game (que es quien sabe si
# la pieza es un arma o una armadura). Devuelve {MaterialData: cuantos}.
static func fundir_nucleos(escalera: Array, mejoras: int) -> Dictionary:
	var gastados: Dictionary = {}
	for k in range(maxi(0, mejoras)):
		var n: MaterialData = _material_de_nivel(escalera, k)
		if n == null:
			continue
		gastados[n] = int(gastados.get(n, 0)) + nucleos_para_mejora(k, n)
	var out: Dictionary = {}
	for n in gastados:
		var devuelve: int = int(floor(float(gastados[n]) * RECUPERACION))
		if devuelve > 0:
			out[n] = devuelve
	return out


# El nucleo que tocaba para pasar de +k a +(k+1): el de la banda que cubre ese nivel.
static func _material_de_nivel(escalera: Array, k: int) -> MaterialData:
	for n in escalera:
		var m: MaterialData = n as MaterialData
		if m != null and k >= m.mejora_min and k < m.mejora_max:
			return m
	return null
