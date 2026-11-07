# ============================================================
#  status_effects.gd  (KAN-58)
#  Catalogo DATA-DRIVEN de estados alterados + la clase Instance (un estado
#  ACTIVO sobre un combatiente). El MOTOR vive en Combatant (apply/tick/agregadores);
#  aqui estan las DEFINICIONES (que hace cada estado) y sus magnitudes.
#
#  Un estado ACTIVO (Instance) lleva DATOS PROPIOS POR APLICACION:
#   - magnitude: daño por turno BASE (DoT, nivel 1). Lo calcula QUIEN lo aplica:
#       * Veneno  -> base FIJO; cada STACK DUPLICA el daño (dot = base x 2^(stacks-1)),
#                    asi subir de stack = "tier siguiente". Un solo veneno para todo;
#                    las habilidades/enemigos capan hasta que stack pueden subirlo (stack_cap).
#       * Sangrado-> ESCALA con el ATAQUE del aplicador (aplicador fuerte = sangra mas).
#         Lo aplican solo ciertas HABILIDADES con armas cortantes (KAN-57/Fase 3).
#       * Quemadura-> por ahora un valor por defecto (lo afinaran los hechizos).
#     Ambos bandos pueden usar cualquiera; la diferencia es la MECANICA, no quien lo usa.
#   - turns: duracion propia (distintos ataques/bichos pueden traer duraciones distintas).
#   - stack_mode: como apila el estado al re-aplicarse:
#       * "none"        -> una sola instancia; re-aplicar RESETEA duracion y sube al
#                          mas fuerte (magnitud=max). Ej: buffs/debuffs, Quemadura.
#       * "merge"       -> una sola instancia con CUENTA de stacks (MISMA duracion para
#                          todos); el efecto escala con los stacks: dot x2 por stack
#                          (Veneno, via dot_stack_mult) o -X%/stack (Pegajoso/Lento).
#       * "independent" -> cada aplicacion es un STACK con su PROPIA duracion (varias
#                          instancias); las heridas viejas expiran solas. Ej: Sangrado.
#                          Una habilidad puede pasar refresh_all=true para reiniciar la
#                          duracion de TODOS los stacks a la vez.
#
#  Otros efectos del catalogo: mult de atk/def/spd (buffs/debuffs), is_stun (pierde
#  turno) y stun_prob_mult (RAYO: x1.5 a la prob. de aturdir que recibe, estilo MH).
#
#  MAGNITUDES/DURACIONES = PROVISIONALES (afinar con Excel). Ver [[ajuste-curvas-holistico]].
# ============================================================

extends RefCounted
class_name StatusEffects

# OJO: esto se amplia SOLO POR EL FINAL. Los .tres guardan `estado` como el ENTERO del enum, asi
# que meter uno en medio renumera y corrompe todas las habilidades y hechizos que ya existen.
enum Id { VENENO, SANGRADO, QUEMADURA, LENTO, DEBIL, VULNERABLE, FORTALEZA, ATURDIDO, RAYO, PEGAJOSO, REGENERACION, REGEN_MANA, MOJADO,
	PRESTEZA, BALUARTE, MARCA, HERIDA_PROFUNDA, CORROSION, SILENCIO, MIEDO, SIGILO, GUARDIA_CARNE,
	ESCOLTA,
	PLATO_GUARDIA, PLATO_BRIO, PLATO_FURIA, PLATO_ARCANO, PLATO_NUCLEO, PLATO_REMEDIO,
	PLATO_ESTOMAGO, PLATO_FORTUNA,
	ENRAIZADO,
	RESGUARDO,
	CEGUERA,
	OPORTUNISTA,
	ENROSCADO,
	PEGADO,
	RESCOLDO,
	ENCENDIDO, AVIVADO, AFILADO,
	CONGELACION,
	DECRETO,
	EN_SOMBRAS, FURIA_REY, COLMILLOS_ROTOS, MUSGO_QUEMADO,
	RESINADO, SAVIA_NEGRA,
	PICOR, PRINGADO,
	PARALISIS, ENCAPULLADO,
	IMANTADO, ADHERIDO, LIMADURAS, EN_VUELO, ORBITA, CORAZA_IMAN, ELITROS, UNA_CABEZA }

# Veneno: base de daño (nivel 1) + tope global de stacks. Cada stack DUPLICA el daño
# (base x 2^(stacks-1)); las habilidades/enemigos capan a que stack llegan. PROVISIONAL.
const VENENO_BASE_DMG := 3.0
const VENENO_TURNS := 4
const VENENO_MAX_STACKS := 5

# Sangrado: APILABLE. Cada stack = fraccion BAJA del ATAQUE del aplicador (no 1:1);
# machacar con armas cortantes sube el daño total (dot = magnitud x stacks). PROVISIONAL.
const SANGRADO_FRACCION_ATK := 0.30
# (10/10, el jefe tras el playtest del 09/10: "aunque la armadura reduzca el daño que recibo los sangrados hacen daño fijo
# de el ataque de el enemigo; en el minotauro mete un daño que no tiene ningun puto sentido"). Ahora el sangrado, como el
# fuego, sale del GOLPE REAL que lo abre (lo que de verdad te ha quitado, ya con defensa, armadura y bloqueo): un golpe
# flojo, sangrado flojo. Por turno, el 15 % (el fuego, el 30 %): uno solo hace menos que el fuego, pero dura 3 turnos y
# se APILA hasta 5 ("si uno dura mas ya son diferentes a su manera"). SANGRADO_FRACCION_ATK queda para cuando no hay golpe.
const SANGRADO_FRACCION_GOLPE := 0.15
const SANGRADO_TURNS := 3
const SANGRADO_MAX_STACKS := 5

# El sangrado premia las armas RAPIDAS (muchos cortes), no las pesadas: usa el motion_value
# A LA INVERSA. atk() ya HORNEA el motion_value del arma (una GS pega ~1.55x), lo que inflaba
# su sangrado de forma desproporcionada. Dividimos por mv^(1+EXP): el primer mv quita el peso
# ya horneado (queda neutro) y el EXP restante lo INVIERTE, de modo que una daga (mv bajo)
# sangra mas y un mandoble (mv alto) sangra menos. Sigue escalando con Fuerza y ataque base
# (un cortador fuerte abre mas herida): solo se invierte el PESO del arma.
#
# SANGRADO_MV_EXP = cuanto se invierte (la inversion completa era demasiado bestia). La ventaja
# de la ligera sobre la pesada sale de (mv_pesada/mv_ligera)^EXP; con daga 0.65 vs mandoble 1.55
# eso es 2.385^EXP:
#   0.0 -> neutro (el sangrado no depende del arma)
#   0.3 -> la daga sangra ~1.30x el mandoble  <- actual
#   0.5 -> la daga sangra ~1.55x el mandoble
#   1.0 -> inversion COMPLETA: la daga sangra ~2.4x el mandoble
const SANGRADO_MV_EXP := 0.3

# EL FUEGO (06/10, criterio del jefe: "el fuego es un poco random... deberiamos poner un criterio"). Antes la Quemadura
# hacia 6 fijos (o 4-12 fijos en las magias), la pusiera quien la pusiera. Ahora ARDE UN % DEL GOLPE QUE LA PRENDE: desde
# el 10/10 el golpe REAL (lo que de verdad le quita, ver Combatant.golpe_de_ahora; antes, el de sobre el papel); sin golpe
# real a mano, el de sobre el papel; y si no hay golpe (una pasiva, un charco), del ataque de quien la pone. Una daga con fuego quema poco y un martillo mucho.
# NO SE SUMAN (modo "brasas"): cada quemadura va por su cuenta con sus turnos y cada turno arde SOLO LA MAS FUERTE; las
# flojas se van gastando a la vez por debajo. Su ejemplo: turno 1 un fuego de 8, turno 2 uno de 3 -> arde el 8; turno 3
# se va el 8 y arde el 3 (le queda uno); turno 4, nada.
const QUEMADURA_FRACCION := 0.30
# EL RESCOLDO (06/10, la ceniza y brasa, mutante del slime de fuego): brasa y ceniza en la cara. La MITAD por turno que la
# Quemadura pero dura 3, y ademas fallas un 8 % mas (la Ceguera, un 12 %). El agua lo apaga.
const RESCOLDO_FRACCION := 0.15
# LA CONGELACION (07/10): lo que te deja andar en tu turno (la mitad).
const CONGELACION_MOV := 0.5
# EL PICOR (02/11, el mosquito del ambar): la parte de la energia que TE QUEDA que pierdes al empezar cada turno tuyo (de la
# que queda y no de la maxima, decision del jefe: "con poca no te afecta tanto; con la maxima te destroza la energia").
const PICOR_ENERGIA := 0.10
# Cuantas quemaduras sueltas puede llevar uno a la vez (si no, una lluvia de chispas llenaria la lista).
const BRASAS_MAX := 6

static func sangrado_magnitude(applier_atk: float, motion_value: float = 1.0) -> float:
	var mv: float = maxf(motion_value, 0.1)
	return applier_atk * SANGRADO_FRACCION_ATK / pow(mv, 1.0 + SANGRADO_MV_EXP)


# ============================================================
#  ¿PRENDE O NO? — LA UNICA PUERTA
# ============================================================
# TODA probabilidad de meter un estado sale de aqui: golpes al_golpear, imbuiciones, hechizos,
# habilidades del jugador, habilidades del enemigo y el aturdir del arma contundente. Eran SEIS
# copias de la misma cuenta y cada una se habia desviado por su lado — el aturdir, de hecho, corria
# por un carril entero aparte con su propia resistencia y su propio tope.
#
# LA FORMA ES UN COCIENTE, no una resta, y es lo que pediste: que la Resistencia a efectos siga
# notandose por encima del 100% sin llegar nunca a la inmunidad.
#
#     p = prob_base × (1 + eficacia) / (1 + resistencia)
#
#   resistencia 0%    -> p = base          (parte de cero)
#   resistencia 100%  -> p = base / 2
#   resistencia 200%  -> p = base / 3
#   resistencia 300%  -> p = base / 4      <- se sigue notando, y NO eres inmune
#
# Con una resta (lo de antes) el 100% ya era inmunidad y todo lo de mas arriba no valia nada: por eso
# habia que caparlo al 95% y por eso una armadura T2 a tope ya se comia el juego. Asi la escalera
# sigue abierta hasta las armaduras T10 sin romper nada, porque cada punto rinde menos que el
# anterior (1/(1+r) es una hiperbola) pero ninguno rinde cero.
#
# La EFICACIA es su espejo exacto: multiplica por (1+ef), asi que 100% de eficacia contra 100% de
# resistencia devuelve la probabilidad base. Nadie gana la carrera de forma definitiva.
const PROB_TECHO := 0.95     # nunca es SEGURO meter un estado
const PROB_SUELO_FRAC := 0.05  # ...ni imposible: la resistencia nunca quita mas del 95% de la tirada


# 'id' importa: hay resistencias que solo valen para una FAMILIA (los de piedra aguantan el mazazo
# pero no el veneno). 'atacante' puede ser null (efectos sin dueño: una trampa, un entorno).
static func prob_final(prob_base: float, atacante, objetivo, id: int,
		con_afinidad: bool = true) -> float:
	if prob_base <= 0.0 or objetivo == null:
		return 0.0
	# INMUNE es inmune: binario y por delante de todo (afinidad elemental, inmunidad a medida del
	# bicho, o un estado que lleve encima). Aqui no hay cociente que valga.
	if objetivo.es_inmune(id):
		return 0.0
	# DECAIMIENTO DE CONTROL: el segundo aturdimiento seguido cuesta el doble y el cuarto no entra.
	# Va al final, multiplicando: es un descuento sobre la tirada, no una resistencia mas.
	var dr: float = objetivo.decaimiento_control(id)
	if dr <= 0.0:
		return 0.0
	var ef: float = 0.0
	if atacante != null:
		ef = atacante.eficacia_estados()
		# RUNAS (08/10): el set Ignicion prende mas la Quemadura.
		if id == Id.QUEMADURA and atacante is Combatant:
			prob_base += (atacante as Combatant).runa_ignicion_prob
		# y el set Alcantarilla (30/10) abre mas el Sangrado.
		if id == Id.SANGRADO and atacante is Combatant:
			prob_base += (atacante as Combatant).runa_alcantarilla_prob
	# La resistencia puede ser NEGATIVA (Rayo te hace mas facil de aturdir). Con suelo, para que no
	# se pueda dividir por cero ni por un numero minusculo.
	var re: float = maxf(objetivo.resist_estados(id, con_afinidad), -0.9)
	var p: float = prob_base * (1.0 + maxf(ef, 0.0)) / (1.0 + re)
	return clampf(p, prob_base * PROB_SUELO_FRAC, PROB_TECHO) * dr


# ============================================================
#  FAMILIA DE CONTROL: lo que te quita el turno
# ============================================================
# Los que te impiden JUGAR, no los que te hacen daño o te bajan una stat. Son los unicos que llevan
# decaimiento: encadenarlos es lo que convertia una pelea de jefe en "dos aturdimientos y a casa"
# (el Rey Slime no llegaba a castear ni su invocacion ni su ola). Ver Combatant.decaimiento_control.
#
# El Enraizado NO esta: deja pegar y lanzar hechizos, es control PARCIAL. Si algun dia se le sube a
# control total, entra aqui.
# La PARALISIS (03/11) tambien: resiste como un control y gasta su escalon, pero solo te quita el turno si falla la
# tirada; por eso no lleva is_stun, y una carga solo se corta el turno que la falla (ver Combatant.tick_statuses).
const CONTROL := [Id.ATURDIDO, Id.MIEDO, Id.PARALISIS]

static func es_control(id: int) -> bool:
	return CONTROL.has(id)

# Magnitud EFECTIVA de un StatusApplication segun el aplicador. Si trae magnitud fija
# (>=0) se usa esa; si es Sangrado sin magnitud, escala con el ataque del aplicador
# (con el motion_value del arma invertido, ver sangrado_magnitude); si no, -1 (que
# apply_status traduce al dot_default del catalogo).
# 'objetivo' = a quien se le pone: si acaba de encajar un golpe (Combatant.golpe_de_ahora), el sangrado y el fuego salen
# de ESE golpe, el real (magnitud_del_golpe).
static func app_magnitude(app, applier_atk: float, motion_value: float = 1.0, golpe: float = -1.0, objetivo = null) -> float:
	var m: float = float(app.magnitud)
	if m >= 0.0:
		return m
	var frac: float = float(app.get("fraccion_golpe")) if app.get("fraccion_golpe") != null else -1.0
	var real: float = magnitud_del_golpe(int(app.estado), objetivo, frac)
	if real >= 0.0:
		return real
	if int(app.estado) == Id.SANGRADO:
		return sangrado_magnitude(applier_atk, motion_value)
	return magnitud_por_golpe(int(app.estado), applier_atk, golpe)


# EL SANGRADO Y EL FUEGO DEL GOLPE REAL (10/10): el % (el de la ficha, 'frac' >= 0, o el del catalogo) de lo que el golpe
# que los prende le acaba de quitar a 'objetivo'. -1 si no es de esos o si no viene de un golpe (una pasiva, un charco).
static func magnitud_del_golpe(id: int, objetivo, frac: float = -1.0) -> float:
	if objetivo == null or not objetivo.has_method("golpe_de_ahora"):
		return -1.0
	var base: float = float(objetivo.golpe_de_ahora())
	if base < 0.0:
		return -1.0
	match id:
		Id.SANGRADO: return maxf(base * (frac if frac >= 0.0 else SANGRADO_FRACCION_GOLPE), 0.5)
		Id.QUEMADURA: return maxf(base * (frac if frac >= 0.0 else QUEMADURA_FRACCION), 0.5)
		Id.RESCOLDO: return maxf(base * (frac if frac >= 0.0 else RESCOLDO_FRACCION), 0.5)
	return -1.0


# Para los que no traen StatusApplication (la imbuicion, los refuerzos): del golpe real si lo hay; si no, como siempre.
static func magnitud_de(id: int, applier_atk: float, golpe: float, objetivo, motion_value: float = 1.0) -> float:
	var real: float = magnitud_del_golpe(id, objetivo)
	if real >= 0.0:
		return real
	if id == Id.SANGRADO:
		return sangrado_magnitude(applier_atk, motion_value)
	return magnitud_por_golpe(id, applier_atk, golpe)


# De una lista de instancias: para cada estado "brasas" (Quemadura, Rescoldo), la que ARDE (la mas fuerte). Las demas
# no hacen daño mientras esa siga. La usan los ticks de fuera de combate (el de dentro lo hace Combatant.tick_statuses).
static func brasas_que_arden(insts: Array) -> Dictionary:
	var arde: Dictionary = {}
	for e in insts:
		if e != null and String(e.d.get("stack_mode", "")) == "brasas" 				and (not arde.has(e.id()) or e.magnitude > arde[e.id()].magnitude):
			arde[e.id()] = e
	return arde


# LA QUEMADURA Y EL RESCOLDO (06/10): un % del GOLPE que la prende ('golpe' <= 0 = no hay golpe: del ataque de quien la
# pone). Para cualquier otro estado, -1 (el de su catalogo).
static func magnitud_por_golpe(id: int, applier_atk: float, golpe: float = -1.0) -> float:
	var base: float = golpe if golpe > 0.0 else applier_atk
	if id == Id.QUEMADURA:
		return maxf(base * QUEMADURA_FRACCION, 0.5)
	if id == Id.RESCOLDO:
		return maxf(base * RESCOLDO_FRACCION, 0.5)
	return -1.0

# PLATOS: 20 minutos de mapa. No es un numero suelto — son los turnos que caben en 20 min al ritmo
# del reloj de fuera de combate (Game.SEG_POR_TURNO_FUERA = 5 s), y esta escrito asi para que
# cambiar ese reloj no deje los platos durando otra cosa. Dentro de una pelea gastan un turno por
# turno como cualquier estado, que en 20 min de comida no se nota.
# Nombre bonito de cada habilidad base, para los textos de los platos. Las claves son las del
# sub-dict 'hab_mult' y coinciden con las propiedades de Abilities (asi Combatant.hab() lee la
# habilidad por el mismo nombre que aparece en la ficha).
const NOMBRE_HABILIDAD := {
	"fuerza": "Fuerza", "resistencia": "Resistencia", "destreza": "Destreza",
	"agilidad": "Agilidad", "magia": "Magia", "voluntad": "Voluntad",
}

const PLATO_SEGUNDOS := 20.0 * 60.0
const PLATO_TURNOS := int(PLATO_SEGUNDOS / 5.0)   # 5.0 = Game.SEG_POR_TURNO_FUERA (no se puede
                                                  # referenciar: Game es autoload y esto es estatico)

# Catalogo. Cada entrada trae solo los campos que usa (el resto = neutro por defecto,
# ver los get(...) del motor). 'turns' = duracion base por defecto; 'dot' = es DoT;
# 'dot_default' = magnitud por defecto si el aplicador no pasa una (util para dev).
static var _defs: Dictionary = {
	Id.VENENO: {
		"id": Id.VENENO, "nombre": "Veneno", "icono": "☠", "color": Color(0.45, 0.85, 0.2),
		"dot": true, "turns": VENENO_TURNS, "dot_default": VENENO_BASE_DMG,
		"stack_mode": "merge", "max_stacks": VENENO_MAX_STACKS, "dot_stack_mult": 2.0,
		"debuff": true,
		"descripcion": "Corre por dentro y no se cansa. Cada dosis nueva no se suma a la anterior: la multiplica.",
	},
	Id.SANGRADO: {
		"id": Id.SANGRADO, "nombre": "Sangrado", "icono": "🩸", "color": Color(0.85, 0.15, 0.15),
		"dot": true, "turns": SANGRADO_TURNS,   # magnitud/stack = escala con el aplicador
		"stack_mode": "independent", "max_stacks": SANGRADO_MAX_STACKS,
		"debuff": true,
		"descripcion": "Una herida abierta que no espera. Cuanto más hondo entra el corte, más sangra; y cada corte sangra por su cuenta.",
	},
	Id.QUEMADURA: {
		"id": Id.QUEMADURA, "nombre": "Quemadura", "icono": "🔥", "color": Color(1.0, 0.5, 0.1),
		"dot": true, "turns": 2, "dot_default": 6.0,   # (solo si nadie da magnitud: ver QUEMADURA_FRACCION)
		"stack_mode": "brasas", "max_stacks": BRASAS_MAX,
		"debuff": true,
		"descripcion": "Sigue ardiendo cuando la llama ya no está. El agua la apaga.",
	},
	Id.LENTO: {   # Ralentizacion FIJA (hechizo/habilidad): NO apila, un -25% plano.
		"id": Id.LENTO, "nombre": "Lento", "icono": "🐌", "color": Color(0.3, 0.6, 0.9),
		"turns": 3, "spd_mult": 0.75,
		"debuff": true,
		"descripcion": "Los miembros pesan y el turno tarda en llegar.",
	},
	Id.PEGAJOSO: {   # Slimes: hasta 4 stacks INDEPENDIENTES, -5% vel/stack (cada uno su duracion)
		"id": Id.PEGAJOSO, "nombre": "Pegajoso", "icono": "🕸", "color": Color(0.4, 0.8, 0.4),
		"stack_mode": "independent", "max_stacks": 4, "turns": 3,
		"spd_mult": 0.95,   # cada stack (instancia) multiplica x0.95 -> 4 stacks ~ -18.5%
		"debuff": true,
		"descripcion": "Baba que se agarra a todo. Una capa se nota poco; cuatro te dejan luchando dentro de un tarro.",
	},
	Id.DEBIL: {   # debuff de ataque
		"id": Id.DEBIL, "nombre": "Débil", "icono": "💢", "color": Color(0.7, 0.4, 0.9),
		"turns": 3, "atk_mult": 0.80,
		"debuff": true,
		"descripcion": "El golpe sale, pero sale sin nadie detrás.",
	},
	Id.VULNERABLE: {   # debuff de defensa (recibe mas daño)
		"id": Id.VULNERABLE, "nombre": "Vulnerable", "icono": "🔻", "color": Color(0.9, 0.3, 0.5),
		"turns": 3, "def_mult": 0.80,
		"debuff": true,
		"descripcion": "La guardia se ha abierto y todo entra más hondo.",
	},
	Id.FORTALEZA: {   # buff de ataque
		"id": Id.FORTALEZA, "nombre": "Fortaleza", "icono": "💪", "color": Color(0.95, 0.8, 0.2),
		"turns": 3, "atk_mult": 1.25,
		"descripcion": "Los golpes salen con todo el cuerpo detrás.",
	},
	Id.ATURDIDO: {   # pierde el turno; lo aplica el aturdir CRITICO de contundentes (Fase 2)
		"id": Id.ATURDIDO, "nombre": "Aturdido", "icono": "💫", "color": Color(1.0, 0.9, 0.3),
		"turns": 1, "is_stun": true,
		"debuff": true,
		"descripcion": "El mundo se va un momento. Cuando vuelve, ya te han pegado.",
	},
	Id.RAYO: {   # debuff estilo MH: x1.5 a la prob. de aturdir que recibe.
		# Se LLAMA "Electrizado" aunque el Id sea RAYO: el ELEMENTO ya se llama Rayo y tener
		# los dos con el mismo nombre hacia ilegible la ficha ("daño de Rayo · Rayo 32%").
		"id": Id.RAYO, "nombre": "Electrizado", "icono": "⚡", "color": Color(0.6, 0.8, 1.0),
		"turns": 3, "stun_prob_mult": 1.5,
		"debuff": true,
		"descripcion": "Los músculos responden tarde y mal: un buen mazazo ahora te tumba mucho más fácil.",
	},
	Id.REGENERACION: {   # CURA por turno (espejo del DoT): pociones (KAN-57). magnitud = cura/turno.
		"id": Id.REGENERACION, "nombre": "Regeneración", "icono": "✚", "color": Color(0.4, 0.9, 0.55),
		"heal": true, "turns": 3, "heal_default": 8.0,
		"descripcion": "La poción hace su trabajo poco a poco: te cura mientras aguantas, no antes.",
	},
	Id.REGEN_MANA: {   # MANÁ por turno (pociones de maná, KAN-56/57). magnitud = maná/turno.
		"id": Id.REGEN_MANA, "nombre": "Regeneración de maná", "icono": "🔷", "color": Color(0.4, 0.6, 1.0),
		"mana_heal": true, "turns": 3, "mana_default": 4.0,
		"descripcion": "El pozo se va llenando solo, gota a gota.",
	},
	# 'baja_fuera': ver StatusEffects.corre_fuera(). Mojado NO es un debuff (no se lo lleva
	# limpiar_debuffs, y encima te hace inmune al fuego), pero es un ESTORBO —te amplifica el daño de
	# Rayo que recibes— asi que por el mapa te secas solo, como un veneno se pasa. Sin esta clave se
	# quedaria puesto para siempre, que es la regla de los buffs y aqui no pega.
	Id.MOJADO: {
		"baja_fuera": true,   # Lo aplican los golpes imbuidos de AGUA. Empapado no ardes... pero conduces.
		# El "+50% de daño de RAYO recibido" NO vive aqui sino en Elementos.AMPLIFICA_POR_ESTADO:
		# elements.gd ya depende de este archivo, y referenciar Elementos desde aqui haria un
		# CICLO de dependencias (no compilaria).
		"id": Id.MOJADO, "nombre": "Mojado", "icono": "💧", "color": Color(0.4, 0.7, 1.0),
		"turns": 3,
		"inmune": [Id.QUEMADURA, Id.RESCOLDO, Id.ENCENDIDO, Id.AVIVADO],   # empapado NO puedes arder
		# y te APAGA la quemadura (y el rescoldo) que llevaras encima; al slime de fuego, lo que se habia avivado
		"limpia": [Id.QUEMADURA, Id.RESCOLDO, Id.ENCENDIDO, Id.AVIVADO],
		"descripcion": "Empapado no ardes. Pero el agua conduce, y un rayo encuentra el camino.",
	},
	Id.PRESTEZA: {   # buff de VELOCIDAD: no habia ninguno (los unicos spd_mult eran < 1)
		"id": Id.PRESTEZA, "nombre": "Presteza", "icono": "🌀", "color": Color(0.5, 0.9, 0.95),
		"turns": 3, "spd_mult": 1.25,
		"descripcion": "Los pies llegan antes que la idea.",
	},
	Id.BALUARTE: {   # buff de DEFENSA: tampoco habia ninguno, y dos habilidades ya lo prometian
		"id": Id.BALUARTE, "nombre": "Baluarte", "icono": "🛡", "color": Color(0.6, 0.75, 0.95),
		"turns": 3, "def_mult": 1.25,
		"descripcion": "Plantado y entero. Lo que viene, rebota.",
	},
	Id.MARCA: {   # el marcado encaja mas daño DE TODOS: es el efecto que hace valer al grupo
		"id": Id.MARCA, "nombre": "Marca", "icono": "🎯", "color": Color(0.95, 0.45, 0.3),
		"turns": 3, "dmg_taken_mult": 1.25, "debuff": true,
		"descripcion": "Le has enseñado a todos por dónde entra.",
	},
	Id.HERIDA_PROFUNDA: {   # le llega la MITAD de cada cura
		"id": Id.HERIDA_PROFUNDA, "nombre": "Herida profunda", "icono": "🩹", "color": Color(0.8, 0.25, 0.35),
		"turns": 3, "heal_recv_mult": 0.5, "debuff": true,
		"descripcion": "Una herida que no cierra por mucho que la traten.",
	},
	Id.CORROSION: {   # come la DEF PLANA de la armadura. Distinto de Vulnerable, y se COMBINAN
		"id": Id.CORROSION, "nombre": "Corrosión", "icono": "⚗", "color": Color(0.55, 0.7, 0.35),
		"turns": 3, "def_flat_mult": 0.75, "debuff": true,
		"descripcion": "La coraza cede. Ya no protege lo que protegía.",
	},
	Id.SILENCIO: {   # ni hechizos ni habilidades: solo golpe basico, Defender, objeto o huir
		"id": Id.SILENCIO, "nombre": "Silencio", "icono": "🤐", "color": Color(0.65, 0.5, 0.8),
		"turns": 2, "silencia": true, "debuff": true,
		"descripcion": "Las palabras no salen y las manos no encuentran la maña.",
	},
	# EL ESPEJO DEL SILENCIO. Aquel te deja pegar y te corta la magia; este te clava al suelo y te
	# corta lo de pegar, pero los hechizos SALEN IGUAL: para conjurar no hace falta moverse.
	# Por eso NO lleva is_stun -- no pierdes el turno, pierdes media baraja.
	Id.ENRAIZADO: {
		"id": Id.ENRAIZADO, "nombre": "Enraizado", "icono": "🌱", "color": Color(0.45, 0.62, 0.3),
		"turns": 2, "enraiza": true, "debuff": true,
		"descripcion": "Las raíces te agarran hasta los codos. No hay forma de golpear, pero la voz sigue libre para recitar.",
	},
	# EL ANTIDOTO, y es un BUFF, no una curacion. Un antidoto que solo te quitara el veneno no
	# valdria de nada donde hace falta: en los pisos donde TODO lo que hay te envenena, te lo
	# volverian a poner en el mismo turno en que te lo has bebido.
	#
	# Por eso hace las dos cosas a la vez, y las dos salen del mismo sitio que ya usa el Mojado con
	# la quemadura: 'limpia' te quita el que llevas puesto y 'inmune' impide que te pongan otro
	# mientras dura. No hay codigo nuevo detras de esto -- es la misma pareja de claves.
	Id.RESGUARDO: {
		"id": Id.RESGUARDO, "nombre": "Resguardo", "icono": "🧪", "color": Color(0.55, 0.85, 0.45),
		"turns": 3,
		"limpia": [Id.VENENO],
		"inmune": [Id.VENENO],
		"descripcion": "El veneno que llevabas se corta, y durante un rato el que te echen encima no prende.",
	},
	# CEGUERA: no ves, asi que FALLAS. Va por 'precision_flat' en NEGATIVO y no por un "evade_flat"
	# al reves, y la diferencia importa: la precision es del que PEGA y la esquiva es del que
	# ENCAJA. Cegado no esquivas peor -- pegas peor, y le pegas peor a todo el mundo. Ponerlo por
	# el otro lado habria hecho que un ciego fuera mas facil de acertar, que es justo lo contrario.
	#
	# 0.12 sobre una esquiva base de ~0.15 la sube a ~0.27 y el techo normal es 0.35: se nota mucho
	# sin llegar a que falles la mitad de los golpes.
	Id.CEGUERA: {
		"id": Id.CEGUERA, "nombre": "Ceguera", "icono": "🌫", "color": Color(0.72, 0.68, 0.5),
		"turns": 3, "debuff": true,
		"precision_flat": -0.12,
		"descripcion": "Con los ojos llenos de polvo apuntas a bulto. Fallas más, y da igual contra quién.",
	},
	Id.MIEDO: {   # pierde el turno SIEMPRE; al llegarle el turno tira a ver si se DISIPA
		"id": Id.MIEDO, "nombre": "Miedo", "icono": "😱", "color": Color(0.55, 0.35, 0.7),
		"turns": 2, "is_stun": true, "disipa_prob": 0.40, "debuff": true,
		"descripcion": "El cuerpo se planta y no responde. Se pasa... cuando se pasa.",
	},
	Id.SIGILO: {   # espejo de la Provocacion: INCLINA la balanza, no te hace intocable
		"id": Id.SIGILO, "nombre": "Sigilo", "icono": "👤", "color": Color(0.45, 0.5, 0.6),
		"turns": 3, "aggro_mult": 0.35,
		"descripcion": "Te pierden de vista entre el ruido. Buscan a otro.",
	},
	Id.GUARDIA_CARNE: {   # el doble de vida a cambio del doble de daño: la jugada del tanque.
		# NO se marca como debuff: te lo has puesto tu a sabiendas, y limpiarlo a media pelea te
		# bajaria la vida de golpe (ver Combatant._escalar_vida_guardia).
		"id": Id.GUARDIA_CARNE, "nombre": "Guardia de carne", "icono": "🫀", "color": Color(0.85, 0.35, 0.4),
		"turns": 3, "hp_mult": 2.0, "dmg_taken_mult": 2.0,
		"descripcion": "Aguantas el doble y te duele el doble. Quien pega, se acuerda de ti.",
	},
	# VA POR CARGAS, NO POR TURNOS: son CINCO entradas y se acaba, tarden lo que tarden en salir.
	# Con turnos, la habilidad valia lo que valiera el ritmo de la pelea -- tres turnos de un grupo
	# de cuatro daban el triple de golpes que tres turnos peleando solo --, y encima se te iba sin
	# usarla si nadie atacaba. Los turnos siguen puestos como tope de arriba, largos, para que no se
	# quede colgada la pelea entera si no llega a gastarse.
	Id.ESCOLTA: {   # ATAQUE DE SEGUIMIENTO: pegas detras de cada ataque de un aliado
		"id": Id.ESCOLTA, "nombre": "Escolta", "icono": "🗡", "color": Color(0.9, 0.8, 0.55),
		# El 0.75: con el medio golpe de antes, entrar detras no se notaba en la barra de nadie. Con
		# dos armas ademas entra por las dos (la segunda a DUAL_SEGUIMIENTO_MULT), asi que una entrada
		# con dual sale por algo mas de un ataque entero.
		"turns": 30, "usos": 5, "seguimiento_pct": 0.75,
		"descripcion": "Dejas de ir por tu cuenta: entras justo detrás del que abre el hueco.",
	},
	# EL OPORTUNISTA DE LA DAGA (24/09): la Escolta del picaro. Tambien por cargas, pero en el MAPA solo
	# entra si el enemigo golpeado esta a 'alcance_mapa' px de ti, y entonces APARECE A SU ESPALDA (del
	# otro lado del compañero que le ha pegado) y le mete una puñalada con 'crit_extra' de critico. Fuera
	# de alcance no entra y NO gasta carga. En la fila entra siempre, como la Escolta.
	Id.OPORTUNISTA: {
		"id": Id.OPORTUNISTA, "nombre": "Oportunista", "icono": "🗡", "color": Color(0.62, 0.55, 0.85),
		"turns": 30, "usos": 5, "seguimiento_pct": 0.75, "crit_extra": 0.3, "alcance_mapa": 150.0,
		"descripcion": "Cada hueco que abre uno de los tuyos es tuyo: apareces detrás y entras.",
	},
	# EL ENROSQUE DEL CIEMPIES (29/09, solo en el mapa). Lo llevan LOS DOS, la presa y el que la aprieta: los dos
	# clavados en el sitio, y la presa sin poder hacer nada mas que pasar. NO se va por turnos (por eso tantos):
	# lo quita CombatTactico cuando se sueltan (ver empezar_enrosque). Sin is_stun: el turno lo tienes, para pasar.
	Id.ENROSCADO: {
		"id": Id.ENROSCADO, "nombre": "Enroscado", "icono": "🐛", "color": Color(0.62, 0.45, 0.3),
		"turns": 999, "enrosca": true, "debuff": true,
		"descripcion": "Te tiene rodeado y aprieta. Mientras no te suelte, ni te mueves ni levantas el brazo.",
	},
	# LA SANGUIJUELA PEGADA (30/09, el Adherirse del chupasimas, solo en el mapa). Lo llevan LOS DOS: la sanguijuela,
	# que va encima de su presa a donde vaya y no anda por su cuenta, y la presa, que SI se mueve y ataca (es lo que lo
	# separa del Enroscado): solo la lleva encima chupando. NO se va por turnos: la quita CombatTactico (ver
	# empezar_pegada).
	Id.PEGADO: {
		"id": Id.PEGADO, "nombre": "Sanguijuela", "icono": "🩸", "color": Color(0.55, 0.2, 0.28),
		"turns": 999, "pega": true, "debuff": true,
		"descripcion": "Llevas una sanguijuela pegada que te chupa cada turno suyo. Quítasela a golpes o aturdiéndola.",
	},
	# EL RESCOLDO (06/10, ver RESCOLDO_FRACCION): arde como la Quemadura (no se suman: la mas fuerte) pero flojo y mas
	# largo, y con la ceniza en los ojos fallas mas. El agua lo apaga (Mojado).
	# LOS REFUERZOS DE LOS SLIMES DE FUEGO (06/10, su regla: "lo que hacen es avivarse y el agua los apaga"): la Ignicion
	# del de fuego (ENCENDIDO, +25 % de ataque, como la Fortaleza) y el Avivar brasas de la ceniza (AVIVADO: sus golpes
	# queman). El MOJADO los apaga. Y el Afilarse de la obsidiana (AFILADO: sus golpes meten un Sangrado de mas).
	# 'golpe_estado'/'golpe_prob': lo que añade cada golpe suyo que acierta (Combatant.estados_de_refuerzo).
	Id.ENCENDIDO: {
		"id": Id.ENCENDIDO, "nombre": "Encendido", "icono": "🔥", "color": Color(1.0, 0.55, 0.15),
		"turns": 3, "atk_mult": 1.25,
		"descripcion": "Al rojo vivo: pega mucho más fuerte. El agua lo apaga.",
	},
	Id.AVIVADO: {
		"id": Id.AVIVADO, "nombre": "Brasas avivadas", "icono": "♨", "color": Color(1.0, 0.45, 0.2),
		"turns": 3, "golpe_estado": Id.QUEMADURA, "golpe_prob": 0.5,
		"descripcion": "Ha soplado sus brasas: sus golpes pueden causar Quemadura. El agua lo apaga.",
	},
	Id.AFILADO: {
		"id": Id.AFILADO, "nombre": "Afilado", "icono": "🗡", "color": Color(0.55, 0.5, 0.7),
		"turns": 3, "golpe_estado": Id.SANGRADO, "golpe_prob": 1.0,
		"descripcion": "Se ha afilado las aristas: cada golpe suyo abre un corte más.",
	},
	# LA CONGELACION (07/10, idea suya para el slime de escarcha, mutante del profundo): "te reduce la cantidad de
	# movimiento que puedes hacer un 50 %". Solo en el mapa (CombatTactico.radio_de); en la fila no hay pasos que quitar.
	# EL DECRETO (07/10, el Rey tirano): marcado por el rey. No hace nada por si solo: sus subditos solo van a por el y le
	# pegan mas (Combatant.decreto_mult). Lo pone el Decreto directamente, sin tirada (es una orden, no un veneno).
	Id.DECRETO: {
		"id": Id.DECRETO, "nombre": "Decreto", "icono": "👑", "color": Color(0.55, 0.9, 1.0),
		"turns": 2,
		"debuff": true,
		"descripcion": "Señalado por el rey: todos sus súbditos van a por quien lo lleva, y con ganas.",
	},
	# EL SIGILO DE VERDAD DE LOS ENEMIGOS (30/10, la rata sombria; diseño del jefe). No es el Sigilo de los tuyos (que solo
	# INCLINA a quien van): este te lo QUITA DE LA VISTA. Sin cuerpo, sin barra y sin huellas, solo una ondulacion del
	# aire de vez en cuando; no se le puede elegir de objetivo (solo le dan las AREAS). NO se va por turnos: lo quita
	# el primer golpe que le entra (Combatant.take_damage). Entra con MutacionData.sigilo_prob al empezar su turno.
	Id.EN_SOMBRAS: {
		"id": Id.EN_SOMBRAS, "nombre": "En las sombras", "icono": "🌑", "color": Color(0.3, 0.3, 0.42),
		"turns": 999, "en_sombras": true,
		"descripcion": "No está. Bueno, sí está. En algún sitio. Mirándote.",
	},
	# LA FURIA DE REY (31/10, los mutantes del rey rata): cada rata suya que muere le sube el daño (una carga, hasta
	# MutacionData.furia_max, de furia_por_muerte cada una: mult_override) y le renueva los turnos (furia_turnos). Se ve
	# en el mapa: ojos rojos y vaho por el hocico (ReyRataAire.furia, mas cuantas mas cargas).
	Id.FURIA_REY: {
		"id": Id.FURIA_REY, "nombre": "Furia de rey", "icono": "😤", "color": Color(0.9, 0.22, 0.15),
		"turns": 3, "stack_mode": "merge", "max_stacks": 3, "atk_mult": 1.1,
		"descripcion": "Le estás matando a la familia. Se lo está tomando fatal.",
	},
	# LOS COLMILLOS ROTOS (31/10, los mutantes del jabali): tras la Cornada de cristal se le parten; mientras le duren,
	# su Cornada es la de los muñones (AbilityData.rota) y se le ven partidos. Le vuelven a crecer al acabarse.
	Id.COLMILLOS_ROTOS: {
		"id": Id.COLMILLOS_ROTOS, "nombre": "Colmillos rotos", "icono": "🦷", "color": Color(0.45, 0.88, 1.0),
		"turns": 2, "debuff": true,
		"descripcion": "Se los ha dejado clavados en alguien. Le están volviendo a salir. Despacio.",
	},
	# EL MUSGO QUEMADO (31/10, el Jabali ancestral): le han quemado el musgo de la chepa con fuego; ya no le aguanta las
	# areas (MutacionData.chepa_areas) el resto de la pelea, y se le ve pelado.
	Id.MUSGO_QUEMADO: {
		"id": Id.MUSGO_QUEMADO, "nombre": "Musgo quemado", "icono": "🔥", "color": Color(0.6, 0.35, 0.2),
		"turns": 999, "debuff": true,
		"descripcion": "Olía a bosque. Ahora huele a jabalí a la brasa.",
	},
	# LOS MUTANTES DEL TRENT (02/11, trent-mutante). El RESINADO (la Resina del Tocon ambarino): te deja PEGADO al suelo
	# como el Enraizado (no te mueves; los brazos libres), con su pegote de ambar en los pies. Y la SAVIA NEGRA (la del
	# Espantajo): te come la armadura POR CARGAS, cada golpe suyo la renueva (no confundir con la Corrosion de siempre).
	Id.RESINADO: {
		"id": Id.RESINADO, "nombre": "Resinado", "icono": "🍯", "color": Color(0.95, 0.6, 0.15),
		"turns": 1, "enraiza": true, "debuff": true,
		"descripcion": "Tienes los pies dentro de un pegote de ámbar. Dentro de mil años alguien te encontrará así.",
	},
	Id.SAVIA_NEGRA: {
		"id": Id.SAVIA_NEGRA, "nombre": "Savia negra", "icono": "🖤", "color": Color(0.55, 0.4, 0.8),
		"turns": 3, "stack_mode": "merge", "max_stacks": 5, "def_mult": 0.92, "debuff": true,
		"descripcion": "Una savia negra que se come la armadura. Huele a árbol muerto y a herrero llorando.",
	},
	# LOS BICHOS DEL AMBAR (02/11, trent-mutante: los suelta la costra del Tocon ambarino). El PICOR (la Picadura del
	# mosquito): al empezar cada turno tuyo pierdes una parte de tu energia ('picor': fraccion de la que te QUEDA, ver
	# Combatant.tick_statuses). Y el PRINGADO (la Bola de caca del pelotero): no puedes usar objetos mientras te dure.
	# LA PARALISIS (03/11, el Mordisco de la Araña tormentosa): dura sus turnos fijos, y en cada uno tiras: si sale, lo
	# pierdes. Distinta de los otros controles a proposito: no sabes si vas a poder jugar. Volver a morderte la renueva.
	# ENCAPULLADO (03/11, el Capullo de la Tejedora): clavado 2 turnos dentro de su capullo; si lo rompen, se le quita antes.
	Id.ENCAPULLADO: {
		"id": Id.ENCAPULLADO, "nombre": "Encapullado", "icono": "🕸️", "color": Color(1.0, 0.42, 0.08),
		"turns": 2, "enraiza": true, "debuff": true,
		"descripcion": "Seda ardiendo hasta el cuello. No vas a ir a ninguna parte hasta que alguien la rompa.",
	},
	Id.PARALISIS: {
		"id": Id.PARALISIS, "nombre": "Parálisis", "icono": "🫨", "color": Color(0.36, 0.8, 0.92),
		"turns": 3, "paralisis": 0.40, "debuff": true,
		"descripcion": "Los músculos van por libre. A veces te hacen caso. A veces no.",
	},
	Id.PICOR: {
		"id": Id.PICOR, "nombre": "Picor", "icono": "🦟", "color": Color(0.85, 0.5, 0.35),
		"turns": 3, "picor": PICOR_ENERGIA, "debuff": true,
		"descripcion": "Te ha picado algo prehistórico. Rascarte cansa más que pelear.",
	},
	Id.PRINGADO: {
		"id": Id.PRINGADO, "nombre": "Pringado", "icono": "💩", "color": Color(0.5, 0.36, 0.2),
		"turns": 2, "sin_objetos": true, "debuff": true,
		"descripcion": "Llevas las manos llenas de algo que no es barro. No vas a meterlas en la mochila.",
	},
	# LOS MUTANTES DEL ESCARABAJO (04/11; numeros provisionales).
	Id.IMANTADO: {   # lo deja el Pulso: pegado a el, sin poder andar (dos porque se le tira en el turno del bicho: es tu turno entero)
		"id": Id.IMANTADO, "nombre": "Imantado", "icono": "🧲", "color": Color(0.8, 0.19, 0.13),
		"turns": 2, "enraiza": true, "debuff": true,
		"descripcion": "Te has quedado pegado a la herradura. No hay forma de golpear, pero la voz sigue libre para recitar.",
	},
	Id.ADHERIDO: {   # Adherencia: tu turno empieza a su lado: mueves la mitad, como el hielo
		"id": Id.ADHERIDO, "nombre": "Adherido", "icono": "🧲", "color": Color(0.6, 0.62, 0.68),
		"turns": 1, "mov_mult": CONGELACION_MOV, "debuff": true,
		"descripcion": "Tan cerca del imán, cada paso cuesta el doble.",
	},
	Id.LIMADURAS: {   # cada golpe que encaja se le pegan; la Embestida imantada las gasta
		"id": Id.LIMADURAS, "nombre": "Limaduras", "icono": "⚙", "color": Color(0.58, 0.61, 0.67),
		"turns": 999, "stack_mode": "merge", "max_stacks": 5, "def_mult": 1.03,
		"descripcion": "Cada golpe le deja más hierro encima. Las suelta todas de golpe en su Embestida.",
	},
	Id.EN_VUELO: {   # subido para el Picado: no se le puede elegir; un area lo baja
		"id": Id.EN_VUELO, "nombre": "En el aire", "icono": "🪽", "color": Color(0.3, 0.66, 0.52),
		"turns": 999,
		"descripcion": "Demasiado alto para alcanzarlo. Solo un golpe de área lo baja de ahí.",
	},
	# LOS MUTANTES DEL CIEMPIES (05/11; numeros provisionales).
	Id.UNA_CABEZA: {   # Dos mentes: un aturdimiento solo duerme una cabeza; la otra sigue (Combatant._dormir_cabezas)
		"id": Id.UNA_CABEZA, "nombre": "Una cabeza aturdida", "icono": "💤", "color": Color(1.0, 0.9, 0.3),
		"turns": 1,
		"descripcion": "Una de sus cabezas no se entera de nada. La otra, sí. Hace falta aturdir las dos.",
	},
	Id.ORBITA: {   # el Iman errante, con alguien Imantado
		"id": Id.ORBITA, "nombre": "Órbita", "icono": "🌀", "color": Color(0.8, 0.19, 0.13),
		"turns": 999, "spd_mult": 1.25,
		"descripcion": "Tiene a alguien pegado al imán y no piensa dejarlo: va más rápido y sus golpes a ese no se esquivan.",
	},
	Id.CORAZA_IMAN: {   # la Coraza imantada: no le mueven
		"id": Id.CORAZA_IMAN, "nombre": "Coraza imantada", "icono": "🛡", "color": Color(0.34, 0.37, 0.43),
		"turns": 3,
		"descripcion": "Clavado al suelo por su propio imán: no hay empujón que lo mueva.",
	},
	Id.ELITROS: {   # los Elitros cerrados del Saeta
		"id": Id.ELITROS, "nombre": "Élitros cerrados", "icono": "💨", "color": Color(0.3, 0.66, 0.52),
		"turns": 3, "evade_flat": 0.25,
		"descripcion": "Cerrado como una bala: acertarle es cosa de suerte.",
	},
	Id.CONGELACION: {
		"id": Id.CONGELACION, "nombre": "Congelación", "icono": "❄", "color": Color(0.6, 0.85, 1.0),
		"turns": 1, "mov_mult": CONGELACION_MOV,
		"debuff": true,
		"descripcion": "Escarcha en las piernas: este turno solo te da para la mitad del camino.",
	},
	Id.RESCOLDO: {
		"id": Id.RESCOLDO, "nombre": "Rescoldo", "icono": "♨", "color": Color(0.85, 0.45, 0.25),
		"dot": true, "turns": 3, "dot_default": 3.0,
		"stack_mode": "brasas", "max_stacks": BRASAS_MAX,
		"precision_flat": -0.08,
		"debuff": true,
		"descripcion": "Brasas y ceniza en la cara: quema poco pero no se va, y con los ojos llenos de ceniza fallas más.",
	},

	# --- PLATOS DE COCINA (KAN-119) ---------------------------------------------------
	# Buffs LARGOS (PLATO_TURNOS = 20 min de mapa) que se comen en el pueblo o abajo. Tres cosas
	# los separan del resto del catalogo:
	#   - "familia": "plato"  -> EXCLUSION MUTUA: comer uno se lleva por delante al anterior.
	#     Solo un plato activo por persona (lo resuelve Combatant.apply_status).
	#   - "tiempo_real": true -> la UI pinta mm:ss en vez de "240t". Es solo de DISPLAY: los
	#     turnos son los mismos, lo unico que cambia es como se leen.
	#   - "hab_mult"          -> suben la HABILIDAD BASE (Fuerza/Resistencia/Agilidad/Magia), no
	#     la stat derivada. Es a proposito: un +10% de Fuerza mueve ataque Y aturdir Y capacidad,
	#     como si hubieras entrenado, en vez de ser un +10% pegado al daño final.
	# Lo que NO puede llevar un plato: 'hp_mult' ni claves de cura por turno ('heal'/'mana_heal'),
	# porque StatusEffects.estados_que_salen los deja fuera de la pelea y el plato tiene que salir.
	Id.PLATO_GUARDIA: {
		"id": Id.PLATO_GUARDIA, "nombre": "Aguante", "icono": "🛡", "color": Color(0.55, 0.7, 0.95),
		"turns": PLATO_TURNOS, "familia": "plato", "tiempo_real": true,
		"hab_mult": {"resistencia": 1.10}, "dmg_taken_mult": 0.95,
		"descripcion": "Comida de verdad, de la que se queda en el cuerpo. Aguantas lo que te echen.",
	},
	Id.PLATO_BRIO: {
		"id": Id.PLATO_BRIO, "nombre": "Reflejos", "icono": "💨", "color": Color(0.5, 0.9, 0.8),
		"turns": PLATO_TURNOS, "familia": "plato", "tiempo_real": true,
		"hab_mult": {"agilidad": 1.10}, "crit_flat": 0.05, "evade_flat": 0.05,
		"descripcion": "Ligero de estómago y suelto de piernas. Te ves venir los golpes.",
	},
	Id.PLATO_FURIA: {
		"id": Id.PLATO_FURIA, "nombre": "Fuerza", "icono": "🔥", "color": Color(0.95, 0.5, 0.3),
		"turns": PLATO_TURNOS, "familia": "plato", "tiempo_real": true,
		"hab_mult": {"fuerza": 1.10}, "dmg_dealt_mult": 1.05, "mochila_extra": 10.0,
		"descripcion": "Carne y fuego. Pegas con ganas y cargas con más de lo que deberías.",
	},
	Id.PLATO_ARCANO: {
		"id": Id.PLATO_ARCANO, "nombre": "Magia", "icono": "✨", "color": Color(0.7, 0.55, 0.95),
		"turns": PLATO_TURNOS, "familia": "plato", "tiempo_real": true,
		"hab_mult": {"magia": 1.10}, "mana_coste_mult": 0.95,
		"descripcion": "Sabe raro y se te queda la cabeza clara. Las palabras salen solas.",
	},
	Id.PLATO_NUCLEO: {
		"id": Id.PLATO_NUCLEO, "nombre": "Maná", "icono": "🔮", "color": Color(0.45, 0.6, 0.95),
		"turns": PLATO_TURNOS, "familia": "plato", "tiempo_real": true,
		"mp_kill_mult": 1.25, "mp_regen_mult": 1.20,
		"descripcion": "Caldo largo, de los que reposan. Lo que sueltan los bichos te cunde más.",
	},
	Id.PLATO_REMEDIO: {
		"id": Id.PLATO_REMEDIO, "nombre": "Remedios", "icono": "💚", "color": Color(0.5, 0.9, 0.5),
		"turns": PLATO_TURNOS, "familia": "plato", "tiempo_real": true,
		"heal_recv_mult": 1.15,
		"descripcion": "Pescado y verdura, comida de convaleciente. Las curas te entran mejor.",
	},
	Id.PLATO_ESTOMAGO: {
		"id": Id.PLATO_ESTOMAGO, "nombre": "Estómago", "icono": "🧄", "color": Color(0.85, 0.8, 0.5),
		"turns": PLATO_TURNOS, "familia": "plato", "tiempo_real": true,
		"status_resist_flat": 0.10, "dot_taken_mult": 0.85,
		"descripcion": "Salazón y encurtido. Después de esto, un veneno es casi una merienda.",
	},
	# EL PLATO DE LA SUERTE. El unico que no toca ni tus stats ni la pelea: toca lo que SUELTAN los
	# bichos. Dos efectos distintos a proposito, porque hacen cosas distintas:
	#   - drop_mult   -> tiras mas veces (mas bichos sueltan algo).
	#   - drop_doble_flat -> cuando sale, a veces sale DOBLE (el golpe de suerte que se nota).
	# Uno solo de los dos seria un numero aburrido; los dos juntos hacen que una bajada con este plato
	# se recuerde. Lo lee Game._tirar_drop por la cache PersonajeData.estados_drop_*.
	Id.PLATO_FORTUNA: {
		"id": Id.PLATO_FORTUNA, "nombre": "Fortuna", "icono": "🍀", "color": Color(0.45, 0.85, 0.5),
		"turns": PLATO_TURNOS, "familia": "plato", "tiempo_real": true,
		"drop_mult": 1.25, "drop_doble_flat": 0.10,
		"descripcion": "Dicen que la mazmorra se porta mejor con quien baja comido. Nadie lo ha demostrado y todo el mundo lo cumple.",
	},
}


# Definicion (Dictionary) de un estado por su Id.
static func def(id: int) -> Dictionary:
	return _defs.get(id, {})


# Lista de todos los Ids del catalogo.
static func all_ids() -> Array:
	return _defs.keys()


# ¿A este estado le CORRE EL RELOJ fuera del combate?
#
# LA REGLA: fuera de la pelea solo se gastan los ESTORBOS y lo que te esta curando. Los BUFFS se
# quedan ÍNTEGROS para el siguiente combate — te has puesto Fortaleza, sales al pasillo y sigues
# teniendo tus 3 turnos de Fortaleza para el bicho de la vuelta de la esquina. Si se gastaran
# andando, un buff de 3 turnos no llegaria vivo ni a la puerta y las habilidades de apoyo solo
# valdrian a mitad de pelea.
#
# Corre fuera si:
#   - es un DEBUFF (veneno, sangrado, lento...): te lo quitas de encima con el tiempo;
#   - CURA vida o maná: la Regeneración sigue goteando (de hecho sale por heal_left);
#   - es de TIEMPO REAL (los platos de cocina): duran 20 minutos de reloj, ese es su sentido;
#   - o lleva 'baja_fuera' a mano (Mojado: no es debuff pero es un estorbo, ver su entrada).
#
# El DEFAULT es CONGELARSE, y eso es a proposito: un estado nuevo que sea un buff se comporta bien
# sin que nadie se acuerde de tocar esta lista. Si el nuevo es un estorbo, se marca 'debuff' — que
# es lo que hay que marcar de todas formas para que limpiar_debuffs se lo lleve.
static func corre_fuera(def_: Dictionary) -> bool:
	if def_.is_empty():
		return true   # sin definicion: que caduque, mejor perderlo que dejarlo eterno
	return bool(def_.get("debuff", false)) \
		or bool(def_.get("heal", false)) \
		or bool(def_.get("mana_heal", false)) \
		or bool(def_.get("tiempo_real", false)) \
		or bool(def_.get("baja_fuera", false))


# ------------------------------------------------------------
#  Instance: un estado ACTIVO sobre un combatiente (magnitud + turnos + stacks).
# ------------------------------------------------------------
class Instance extends RefCounted:
	var d: Dictionary          # definicion (referencia al catalogo)
	var turns: int = 0
	var stacks: int = 1
	var magnitude: float = 0.0  # daño por turno (DoT); la fija QUIEN lo aplica
	# NIVEL del estado de stat (Vulnerable/Debil/Lento): multiplicador propio que SUSTITUYE
	# al del catalogo. 0.0 = usar el del catalogo. Ej: Vulnerable 0.70 = -30% def (el hacha
	# raja mas que el -20% base). Lo pasa QUIEN lo aplica (StatusApplication.mult).
	var mult_override: float = 0.0
	# Solo BUFFS/DEBUFFS de stat (no DoT ni stun): se saltan el PRIMER decremento del tick,
	# para seguir ACTIVOS durante la accion del turno en que se aplican / expiran (si no, un
	# buff de 3 turnos solo se usa en 2). Los DoT aplican daño y se van normal. Ver Combatant.
	var fresh: bool = true
	# TIER del plato: escala el BONUS, no el valor. 1.2 sube un +10% a +12% y un +5% a +6%.
	# Va aparte de mult_override porque un plato toca VARIAS claves a la vez (+10% Fuerza y +5% daño)
	# y el override las aplastaria todas al mismo numero.
	var escala: float = 1.0
	# CARGAS. Lo que le queda por GASTARSE, para los estados que no se miden en turnos sino en veces
	# que se usan (la Escolta: cinco ataques de seguimiento y se acabo, duren lo que duren). 0 = este
	# estado no va por cargas y vive por sus turnos, como todos los demas.
	#
	# Los turnos siguen contando ademas de las cargas: son el tope de arriba para que un estado con
	# cargas sin gastar no se quede puesto la pelea entera.
	var usos: int = 0

	func _init(def_: Dictionary, turns_: int, stacks_: int = 1) -> void:
		d = def_
		turns = turns_
		stacks = stacks_
		usos = int(def_.get("usos", 0))

	# Gasta una carga. Devuelve true si con esta se ha AGOTADO (quien lo llama tiene que quitarlo).
	# Un estado sin cargas nunca se agota por aqui.
	func gastar_uso() -> bool:
		if usos <= 0:
			return false
		usos -= 1
		return usos <= 0

	func id() -> int:
		return int(d.get("id", -1))

	# Daño por turno de este estado (0 si no es DoT). Los stacks escalan el daño segun
	# dot_stack_mult: por defecto 1.0 (cada instancia = magnitud; Sangrado suma varias
	# instancias). Veneno usa 2.0 -> base x 2^(stacks-1) (cada stack "sube de tier").
	func dot_damage() -> float:
		if is_heal() or is_mana_heal():
			return 0.0   # Regeneración: la magnitud es CURA/MANÁ, no daño (ver heal/mana_amount)
		# Solo los que SON DoT ('dot' en el catalogo). (10/10, logs del 09/10) El Vulnerable del Estallido solar y el Débil de
		# la Vorágine llevan magnitud 0,2 en su ficha y quitaban 0,2 por turno como si sangraran.
		if not bool(d.get("dot", false)):
			return 0.0
		var mult: float = float(d.get("dot_stack_mult", 1.0))
		return magnitude * pow(mult, float(maxi(stacks, 1) - 1))

	# CURA de VIDA por turno de este estado (0 si no es de cura). Espejo de dot_damage.
	func is_heal() -> bool: return bool(d.get("heal", false))
	func heal_amount() -> float:
		if not is_heal():
			return 0.0
		var mult: float = float(d.get("dot_stack_mult", 1.0))
		return magnitude * pow(mult, float(maxi(stacks, 1) - 1))

	# MANÁ restaurado por turno de este estado (0 si no es de maná).
	func is_mana_heal() -> bool: return bool(d.get("mana_heal", false))
	func mana_amount() -> float:
		if not is_mana_heal():
			return 0.0
		var mult: float = float(d.get("dot_stack_mult", 1.0))
		return magnitude * pow(mult, float(maxi(stacks, 1) - 1))

	# Multiplicadores de stat (1.0 = neutro). Apilado LINEAL por stacks.
	func atk_mult() -> float: return _stat_mult("atk_mult")
	func def_mult() -> float: return _stat_mult("def_mult")
	func spd_mult() -> float: return _stat_mult("spd_mult")

	# Multiplicador GENERICO de cualquier clave del catalogo, apilado como los de stat. Los tres de
	# arriba (atk/def/spd) tienen metodo propio porque los usa medio motor; este vale para los que
	# no necesitan uno: dmg_taken_mult, heal_recv_mult, def_flat_mult, aggro_mult...
	func mult_de(clave: String) -> float:
		if not d.has(clave):
			return 1.0
		return _stat_mult(clave)

	func _stat_mult(clave: String) -> float:
		var m: float = float(d.get(clave, 1.0))
		if mult_override > 0.0 and d.has(clave):   # nivel propio (solo al stat que modifica)
			m = mult_override
		return 1.0 + (m - 1.0) * float(stacks) * escala

	# --- PLATOS ---
	# MULTIPLICADOR DE UNA HABILIDAD BASE ("fuerza", "resistencia", "destreza", "agilidad", "magia").
	# 1.0 = neutro. Sale del sub-dict 'hab_mult' del catalogo y pasa por la misma escala/stacks que
	# el resto, para que el T2 de un plato suba el bonus igual que sube los demas.
	func hab_mult(clave: String) -> float:
		var hm: Dictionary = d.get("hab_mult", {})
		if not hm.has(clave):
			return 1.0
		return 1.0 + (float(hm[clave]) - 1.0) * float(stacks) * escala

	# BONUS ADITIVO de una clave del catalogo (crit_flat, evade_flat, status_resist_flat,
	# mochila_extra). Espejo de _stat_mult pero para lo que SUMA en vez de multiplicar: un +5% de
	# critico no es un x1.05, es cinco puntos porcentuales.
	func flat_de(clave: String) -> float:
		if not d.has(clave):
			return 0.0
		return float(d[clave]) * float(stacks) * escala

	# ¿Es un plato de cocina? (para la exclusion mutua y para pintar mm:ss en vez de turnos)
	func familia() -> String: return str(d.get("familia", ""))
	func es_tiempo_real() -> bool: return bool(d.get("tiempo_real", false))

	# Lo que le queda, en mm:ss. Solo para los estados de 'tiempo_real' (platos): un buff de 20
	# minutos en "240t" no lo lee nadie. El 5.0 es Game.SEG_POR_TURNO_FUERA.
	func tiempo_restante() -> String:
		var seg: int = int(round(float(turns) * 5.0))
		@warning_ignore("integer_division")
		var mins: int = seg / 60
		return "%d:%02d" % [mins, seg % 60]

	# Lo que le queda, ya formateado segun el tipo de estado ("4t" o "19:32").
	func duracion_texto() -> String:
		# LO QUE DE VERDAD LE QUEDA. Un estado por cargas se acaba cuando se gastan, no cuando se
		# cumple el plazo, asi que enseñar sus turnos seria mentir: la Escolta pondria "30t" y se te
		# iria a la quinta entrada.
		if usos > 0:
			return "x%d" % usos
		# El Enroscado no se va por turnos: dura hasta que te sueltan (CombatTactico).
		if bool(d.get("enrosca", false)) or bool(d.get("pega", false)):
			return "∞"
		return tiempo_restante() if es_tiempo_real() else "%dt" % turns

	# Multiplicador BASE del estado de stat (override o catalogo), SIN contar stacks.
	# 1.0 si el estado no modifica stats (DoT/stun). Para el label y comparar niveles.
	func base_stat_mult() -> float:
		for k in ["atk_mult", "def_mult", "spd_mult",
				"dmg_taken_mult", "heal_recv_mult", "def_flat_mult", "aggro_mult"]:
			if d.has(k):
				return mult_override if mult_override > 0.0 else float(d.get(k, 1.0))
		return 1.0

	func is_stun() -> bool:
		return bool(d.get("is_stun", false))

	# Multiplicador de la prob. de aturdir que RECIBE el objetivo (RAYO). 1.0 = neutro.
	func stun_prob_mult() -> float:
		return float(d.get("stun_prob_mult", 1.0))

	# True si tener ESTE estado te hace INMUNE al estado 'id' (Mojado -> Quemadura).
	func inmuniza_a(id_estado: int) -> bool:
		return (d.get("inmune", []) as Array).has(id_estado)

	# Estados que este estado APAGA al aplicarse (Mojado apaga la Quemadura).
	func limpia() -> Array:
		return d.get("limpia", [])

	# Texto corto para la UI. DoT: muestra el daño/turno REAL (ya escalado por stacks).
	# Ej "☠12·4t" (veneno x3), "☠x3(12)·4t", "🩸5·3t", "🐌x3·3t", "💫·1t".
	func etiqueta() -> String:
		# CORTO. El chip es un ICONO y un numero, nada mas — como el del Foco arcano, que es el
		# formato que funciona: se lee de un vistazo y no ensancha el bloque. Todo lo demas (el daño
		# por turno, el porcentaje que sube o baja, a que te hace inmune) va al TOOLTIP, que para eso
		# esta: si necesitas el detalle, pasas el raton por encima.
		#
		# Antes ponia cosas como "☠x3(12)·4t" o "🔻x2-25%·3t": tres datos apretados en un chip que
		# nadie lee a media pelea, y el numero que de verdad importa —cuanto le queda— se perdia
		# entre los otros dos.
		var ic: String = str(d.get("icono", "?"))
		var stk: String = "x%d" % stacks if stacks > 1 else ""
		return "%s%s %s" % [ic, stk, duracion_texto()]

	# FICHA COMPLETA del estado (para el tooltip del combate). TODOS los numeros salen de los
	# campos de esta instancia y de su definicion: la 'descripcion' del catalogo es solo
	# SABOR y no repite ni una cifra (si lo hiciera, se quedaria vieja al tocar el balance).
	func resumen() -> String:
		# Cabecera: icono, nombre y lo que le queda, todo en una linea. Debajo, QUE TE HACE en
		# frases cortas. Nada de parentesis explicando la mecanica por dentro: el tooltip se lee
		# de un vistazo en mitad de un turno, no es documentacion.
		var lineas: PackedStringArray = []
		if usos > 0:
			lineas.append("%s  %s  ·  queda%s %d uso%s" % [
				str(d.get("icono", "?")), str(d.get("nombre", "?")), "" if usos == 1 else "n", usos, "" if usos == 1 else "s"])
		elif es_tiempo_real():
			lineas.append("%s  %s  ·  quedan %s" % [
				str(d.get("icono", "?")), str(d.get("nombre", "?")), tiempo_restante()])
		else:
			lineas.append("%s  %s  ·  %d turno%s" % [
				str(d.get("icono", "?")), str(d.get("nombre", "?")), turns, "" if turns == 1 else "s"])

		# QUE LE HACE, con la magnitud REAL de esta instancia (stacks ya dentro). EN TERCERA PERSONA (06/11, pase de
		# textos): el chip lo llevan tambien los enemigos y los compañeros, asi que "Te quita..." mentia en cuanto no
		# eras tu. Como HSR: "reciben un Daño de Rayo con el tiempo... al comienzo de cada turno", "no puede actuar".
		if dot_damage() > 0.0:
			lineas.append("Recibe %s de daño al comienzo de cada turno." % StatusEffects.num(dot_damage()))
		if heal_amount() > 0.0:
			lineas.append("Recupera %s de vida al comienzo de cada turno." % StatusEffects.num(heal_amount()))
		if mana_amount() > 0.0:
			lineas.append("Recupera %s de maná al comienzo de cada turno." % StatusEffects.num(mana_amount()))
		# LOS BONUS, en el formato corto de la guia ("Ataque -20 %"), con la magnitud de ESTA instancia. Salen de la misma
		# tabla que las fichas de habilidades y platos (BONUS_MULT / BONUS_FLAT): asi no se vuelven a separar.
		for clave in (d.get("hab_mult", {}) as Dictionary):
			var pct_h: int = roundi((hab_mult(str(clave)) - 1.0) * 100.0)
			if pct_h != 0:
				lineas.append("%s %+d %%" % [StatusEffects.NOMBRE_HABILIDAD.get(clave, str(clave)), pct_h])
		for e in StatusEffects.BONUS_MULT:
			if d.has(e[0]):
				var pct: int = roundi((mult_de(str(e[0])) - 1.0) * 100.0)
				if pct != 0:
					lineas.append("%s %+d %%" % [e[1], pct])
		for e in StatusEffects.BONUS_FLAT:
			if d.has(e[0]):
				var pct_f: int = roundi(flat_de(str(e[0])) * 100.0)
				if pct_f != 0:
					lineas.append("%s %+d %%" % [e[1], pct_f])
		if d.has("mochila_extra"):
			lineas.append("Carga %+d" % roundi(flat_de("mochila_extra")))
		if is_stun():
			lineas.append("No puede actuar.")
		if bool(d.get("silencia", false)):
			lineas.append("No puede usar habilidades ni hechizos.")
		if bool(d.get("enraiza", false)):
			lineas.append("No puede atacar ni usar habilidades, pero sí lanzar hechizos.")
		if bool(d.get("enrosca", false)):
			lineas.append("No puede moverse ni hacer nada más que pasar el turno.")
		if bool(d.get("pega", false)):
			lineas.append("Pierde vida en cada turno hasta que se la quitan de encima.")
		if float(d.get("paralisis", 0.0)) > 0.0:
			lineas.append("Al comienzo de cada turno, tiene un %d %% de probabilidad de perderlo." % roundi(float(d["paralisis"]) * 100.0))
		if float(d.get("picor", 0.0)) > 0.0:
			lineas.append("Al comienzo de su turno, pierde un %d %% de la energía que le quede." % roundi(float(d["picor"]) * 100.0))
		if bool(d.get("sin_objetos", false)):
			lineas.append("No puede usar objetos.")
		# LO QUE ANDA en su turno (el Congelado: 05/11, el jefe, "no tiene descripcion": salia mudo en la ficha).
		if d.has("mov_mult") and float(d["mov_mult"]) < 1.0:
			lineas.append("En su turno, solo recorre un %d %% de la distancia normal." % roundi(float(d["mov_mult"]) * 100.0))
		# ESCOLTA, igual: era un chip mudo.
		if float(d.get("seguimiento_pct", 0.0)) > 0.0:
			lineas.append("Se suma al ataque de cada aliado con un %d %% del daño de un ataque básico." % roundi(
				float(d["seguimiento_pct"]) * 100.0))
		var stun_m: float = stun_prob_mult()
		if not is_equal_approx(stun_m, 1.0):
			lineas.append("La probabilidad de quedar Aturdido %s en un %d %%." % [
				"aumenta" if stun_m > 1.0 else "se reduce", absi(roundi((stun_m - 1.0) * 100.0))])
		var inm: Array = []
		for id_inm in (d.get("inmune", []) as Array):
			inm.append(str(StatusEffects.def(id_inm).get("nombre", "?")))
		if inm.size() == 1:
			lineas.append("Es inmune %s." % StatusEffects.con_articulo(String(inm[0]), true))
		elif inm.size() > 1:
			lineas.append("Es inmune a estos estados: %s y %s." % [", ".join(inm.slice(0, inm.size() - 1)), String(inm[inm.size() - 1])])

		# Stacks: solo el contador, si de verdad apila. El COMO apila es cocina interna.
		var maxs: int = int(d.get("max_stacks", 1))
		if maxs > 1:
			lineas.append("Acumulaciones: %d de %d." % [stacks, maxs])

		# La frase de SABOR ('descripcion' del catalogo) NO se pinta aqui: en mitad de un turno lo
		# que hace falta es saber que te esta pasando, no leerse un parrafo. Se queda en el catalogo
		# para donde tenga sentido (ficha/bestiario), que es donde se lee con calma.
		# SALVO si no ha salido NADA que diga que hace: un estado mudo es peor que un parrafo (05/11, el Congelado). Un
		# estado nuevo con una mecanica que aqui no se traduce dice al menos su frase del catalogo.
		var dice_algo: bool = lineas.size() > (2 if maxs > 1 else 1)
		if not dice_algo and str(d.get("descripcion", "")) != "":
			lineas.insert(1, str(d["descripcion"]))
		return "\n".join(lineas)


# ------------------------------------------------------------
#  SERIALIZAR una Instance: los estados VIVEN FUERA DEL COMBATE
# ------------------------------------------------------------
# Una Instance es RefCounted y guarda una REFERENCIA al dict del catalogo, asi que no se puede
# meter tal cual en la ficha de un personaje ni mandar por la red. Estos dos la pasan a un dict
# plano (id + lo propio de esta aplicacion) y la reconstruyen atandola otra vez al catalogo.
#
# Se guarda lo que es DE ESTA APLICACION y nada mas: el resto (que hace, cuanto apila, de que color
# es) sale del catalogo al rehidratar, asi que retocar el balance de un estado alcanza tambien a los
# que la gente lleva puestos y no hay dos versiones del mismo veneno.
static func dict_de_instancia(inst) -> Dictionary:
	return {"id": inst.id(), "turns": inst.turns, "stacks": inst.stacks,
		"magnitude": inst.magnitude, "mult": inst.mult_override, "escala": inst.escala,
		"usos": inst.usos}


# LOS ESTADOS QUE SALEN DE UNA PELEA, en dicts. Es la regla de QUE sobrevive a la pantalla de
# combate, y vive aqui porque la preguntan los dos bandos (Game por el grupo, combat.gd por los
# enemigos) y tienen que contestar lo mismo.
#
# Dos exclusiones, cada una por su motivo:
#   - Regeneración / Regen. mana: ya tienen su propio camino de vuelta al mapa (Game.arrastrar_regen
#     -> heal_left -> tick_heal). Sacarlas tambien por aqui seria curar dos veces la misma pocion.
#   - Los que escalan la VIDA MAXIMA (Guardia de carne): el escalado es del combatiente (toca max_hp
#     y current_hp de verdad) y no puede quedarse a medias fuera de una pelea.
static func estados_que_salen(statuses: Array) -> Array:
	var out: Array = []
	for e in statuses:
		if e.is_heal() or e.is_mana_heal():
			continue
		if float(e.d.get("hp_mult", 1.0)) != 1.0:
			continue
		# El Enroscado es de la pelea (lo sujeta el ciempies de ESA pelea): fuera no hay quien te suelte.
		if bool(e.d.get("enrosca", false)) or bool(e.d.get("pega", false)):
			continue
		out.append(dict_de_instancia(e))
	return out


# LA VUELTA: le pone a un combatiente una lista de estados serializados. Va por apply_status y no
# metiendo instancias en el array, porque apply_status es quien vuelve a aplicar los efectos DE
# ENTRADA de cada estado (las limpiezas del Mojado) y quien respeta las inmunidades.
#
# 'c' sin tipar: este archivo es la capa de DATOS de los estados y Combatant es el motor, asi que
# tiparlo aqui haria un ciclo de dependencias.
static func aplicar_a(c, estados: Array) -> void:
	for d in estados:
		c.apply_status(int(d.get("id", -1)), int(d.get("turns", 0)), float(d.get("magnitude", -1.0)),
			# stacks_add = los que traia. En los "merge" (veneno) eso reconstruye el nivel de una
			# sola aplicacion; en los "independent" (Sangrado, Pegajoso) cada dict es SU instancia y
			# entra con un stack, que es exactamente como se guardo.
			maxi(1, int(d.get("stacks", 1))), false, -1, float(d.get("mult", 0.0)),
			# Las CARGAS que le quedaban (la Escolta a medio gastar). Sin esto, el estado volvia de
			# cada pelea con las del catalogo: entrabas con cinco entradas por muchas que hubieras
			# usado. Un dict de antes de que existieran no la trae y se queda en -1 = las del
			# catalogo, que para el resto de estados es lo correcto.
			float(d.get("escala", 1.0)), int(d.get("usos", -1)))


# null si el id ya no existe en el catalogo (un estado retirado entre versiones: mejor perderlo que
# arrastrar una instancia sin definicion, que reventaria en el primer tick).
static func instancia_de_dict(d: Dictionary):
	var def_: Dictionary = def(int(d.get("id", -1)))
	if def_.is_empty():
		return null
	var inst := Instance.new(def_, int(d.get("turns", 0)), maxi(1, int(d.get("stacks", 1))))
	inst.magnitude = float(d.get("magnitude", 0.0))
	inst.mult_override = float(d.get("mult", 0.0))
	# 'escala' con default 1.0: los dicts guardados ANTES de que existieran los platos no la traen
	# y tienen que rehidratar neutros, no a cero (que apagaria el estado entero).
	inst.escala = float(d.get("escala", 1.0))
	# Las CARGAS que le quedaban. Un dict guardado antes de que existieran no la trae, y entonces se
	# queda con las del catalogo (las que puso _init): estrenar cargas es mejor que quedarse a cero,
	# que dejaria el estado puesto pero inutil.
	if d.has("usos"):
		inst.usos = int(d["usos"])
	# 'fresh' NO viaja: existe para que un buff recien echado no se coma un turno antes de poder
	# usarlo DENTRO de la pelea. Fuera no hay accion que proteger, y al volver a entrar en combate
	# lo que queda es lo que queda.
	inst.fresh = false
	return inst


# LA TABLA DE BONUS (06/11, pase de textos): [clave, etiqueta, articulo]. La comparten la ficha del chip
# (Instance.resumen), el formato corto (efecto_legible) y la frase de los platos (efecto_frase).
const BONUS_MULT := [
	["atk_mult", "Ataque", "el"], ["def_mult", "Defensa", "la"], ["spd_mult", "Velocidad", "la"],
	["hp_mult", "Vida máxima", "la"],
	["dmg_taken_mult", "Daño recibido", "el"], ["heal_recv_mult", "Curación recibida", "la"],
	["def_flat_mult", "Armadura", "la"], ["aggro_mult", "Atención de los enemigos", "la"],
	["dmg_dealt_mult", "Daño infligido", "el"], ["spell_dmg_mult", "Daño mágico", "el"],
	["mana_coste_mult", "Coste de los hechizos", "el"], ["mp_kill_mult", "Maná al derrotar a un enemigo", "el"],
	["mp_regen_mult", "Regeneración de maná", "la"], ["dot_taken_mult", "Daño con el tiempo recibido", "el"],
	["drop_mult", "Probabilidad de botín", "la"],
]
# Los ADITIVOS: puntos porcentuales, no multiplicadores. Un "+5% crítico" no es un x1.05, y pasarlo por la formula de
# los multiplicadores lo pintaria como "-95%".
const BONUS_FLAT := [
	["crit_flat", "Probabilidad de crítico", "la"], ["evade_flat", "Esquiva", "la"],
	["precision_flat", "Acierto", "el"],
	["status_resist_flat", "Resistencia a estados", "la"],
	["drop_doble_flat", "Probabilidad de botín doble", "la"],
]


# Un numero para leer: coma decimal, hasta 2 decimales, sin ceros de mas (igual que el registro de la pelea).
static func num(x: float) -> String:
	var s: String = ("%.2f" % x).rstrip("0").rstrip(".")
	return ("0" if s == "-0" else s).replace(".", ",")


# "el Veneno" / "la Quemadura"; con 'a' delante, "al Veneno" / "a la Quemadura". Los nombres de estado que acaban en -a
# son femeninos (Quemadura, Ceguera, Marca); el resto, masculinos (Veneno, Sangrado, Mojado).
static func con_articulo(nombre: String, con_a: bool) -> String:
	var fem: bool = nombre.ends_with("a")
	if con_a:
		return ("a la " if fem else "al ") + nombre
	return ("la " if fem else "el ") + nombre


# LOS BONUS DE UN ESTADO, en piezas: [[etiqueta, valor, es_porcentaje, articulo]], en el orden en que se leen (las
# habilidades base primero: es lo mas gordo que hacen los platos). Lo comparten el formato corto (efecto_legible) y la
# frase al estilo de Genshin (efecto_frase).
# 'mult' = el nivel concreto de esta aplicacion (StatusApplication.mult), o 0 para el del catalogo.
# 'escala' = el tier del plato (1.2 = el T2, que aprieta un 20% mas).
static func _bonus(id: int, mult: float = 0.0, escala: float = 1.0) -> Array:
	var d: Dictionary = def(id)
	var etiquetas: Array = BONUS_MULT
	var etiquetas_flat: Array = BONUS_FLAT
	var out: Array = []
	for clave in (d.get("hab_mult", {}) as Dictionary):
		out.append([str(NOMBRE_HABILIDAD.get(clave, clave)), (float(d["hab_mult"][clave]) - 1.0) * 100.0 * escala, true, "la"])
	for e in etiquetas:
		if d.has(e[0]):
			var m: float = mult if mult > 0.0 else float(d[e[0]])
			out.append([e[1], (m - 1.0) * 100.0 * escala, true, e[2]])
	for e in etiquetas_flat:
		if d.has(e[0]):
			out.append([e[1], float(d[e[0]]) * 100.0 * escala, true, e[2]])
	if d.has("mochila_extra"):
		out.append(["Carga", float(d["mochila_extra"]) * escala, false, "la"])
	return out


# EL MISMO EFECTO EN UNA FRASE, al estilo de la comida de Genshin (06/11, lo eligio el jefe): "aumenta la Agilidad de
# quien se lo come en un 12 %, su Probabilidad de crítico en un 6 % y su Esquiva en un 6 %". 'quien' = "quien se lo
# come", "quien lo bebe"... "" si el estado no mueve ningun numero (entonces lo cuenta su descripcion).
static func efecto_frase(id: int, quien: String, escala: float = 1.0) -> String:
	var bonus: Array = _bonus(id, 0.0, escala)
	if bonus.is_empty():
		return ""
	var trozos: Array = []
	var signo_antes: int = 0
	for i in bonus.size():
		var p: Array = bonus[i]
		var v: float = float(p[1])
		var signo: int = 1 if v >= 0.0 else -1
		var cuanto: String = ("en un %d %%" if bool(p[2]) else "en %d") % absi(roundi(v))
		var art: String = String(p[3])
		var s: String
		if i == 0:
			# "aumenta la Agilidad de quien se lo come en un 12 %"
			s = "%s %s %s de %s %s" % ["aumenta" if signo > 0 else "reduce", art, String(p[0]), quien, cuanto]
		elif signo != signo_antes:
			s = "%s su %s %s" % ["aumenta" if signo > 0 else "reduce", String(p[0]), cuanto]
		else:
			s = "su %s %s" % [String(p[0]), cuanto]
		trozos.append(s)
		signo_antes = signo
	if trozos.size() == 1:
		return String(trozos[0])
	return ", ".join(trozos.slice(0, trozos.size() - 1)) + " y " + String(trozos[trozos.size() - 1])


# QUE hace un estado, en una frase corta y con el NOMBRE de lo que toca ("Defensa -25 %"), para las
# fichas. Sin el nombre, un "(30%, -25%)" no dice si el -25% es probabilidad, daño o duracion.
# 'mult' = el nivel concreto de esta aplicacion (StatusApplication.mult), o 0 para el del catalogo.
# 'escala' = el tier del plato (1.2 = el T2, que aprieta un 20% mas). Escala el BONUS, igual que
# Instance.escala, para que la ficha del plato T2 diga +12% y no +10%.
static func efecto_legible(id: int, mult: float = 0.0, escala: float = 1.0) -> String:
	var d: Dictionary = def(id)
	var partes: Array = []
	for p in _bonus(id, mult, escala):
		partes.append(("%s %+d %%" if bool(p[2]) else "%s %+d") % [String(p[0]), roundi(float(p[1]))])
	# Formato corto de la guia de textos (06/11): "Agilidad +12 % · Esquiva +6 %". Si se acumula, lo de aqui es POR
	# acumulacion (el chip ya enseña el total): sin decirlo, la ficha ponia -5 % y el chip -10 % del mismo Pegajoso.
	if not partes.is_empty():
		return " · ".join(partes) + (" por acumulación" if int(d.get("max_stacks", 1)) > 1 else "")
	if bool(d.get("is_stun", false)):
		return "no puede actuar"
	if bool(d.get("dot", false)):
		return "recibe daño al comienzo de cada turno"
	if bool(d.get("heal", false)):
		return "recupera vida al comienzo de cada turno"
	if bool(d.get("mana_heal", false)):
		return "recupera maná al comienzo de cada turno"
	if bool(d.get("silencia", false)):
		return "no puede usar habilidades ni hechizos"
	if bool(d.get("enraiza", false)):
		return "no puede atacar ni usar habilidades, pero sí lanzar hechizos"
	if bool(d.get("enrosca", false)):
		return "no puede moverse ni hacer nada más que pasar el turno"
	if bool(d.get("pega", false)):
		return "se le pega y le quita vida en cada turno"
	if float(d.get("paralisis", 0.0)) > 0.0:
		return "puede perder cada uno de sus turnos"
	if float(d.get("picor", 0.0)) > 0.0:
		return "pierde energía al comienzo de cada turno"
	if bool(d.get("sin_objetos", false)):
		return "no puede usar objetos"
	if float(d.get("seguimiento_pct", 0.0)) > 0.0:
		return "se suma al ataque de cada aliado con un %d %% del daño de un ataque básico" % roundi(
			float(d["seguimiento_pct"]) * 100.0)
	return ""


# UN CHIP por estado, aunque tenga varias instancias. Los estados 'independent' (Pegajoso,
# Sangrado) crean una Instance por aplicacion, asi que la UI pintaba cuatro iconos iguales en fila
# y no habia forma de saber cuanto le quedaba a cada uno.
#
# 'insts' = todas las instancias del MISMO estado. Devuelve
# [etiqueta, tooltip, icono, color, ultimo_turno]:
#   - etiqueta: los stacks SUMADOS y los turnos del que MAS le queda (el estado no se te va hasta
#     que caduca el ultimo), y en los DoT el daño total de todas juntas.
#   - tooltip: la ficha de la instancia mas larga + una linea con lo que le queda a cada una, que
#     es justo el dato que se perdia al agrupar.
#   - icono y color: para pintarlo como CHIP con recuadro (ver scripts/ui/status_chip.gd).
#   - ultimo_turno: le queda UN turno y se va. La UI lo hace parpadear, que es como se avisa de
#     que se acaba desde que el chip no lleva escrito lo que le queda.
#
# Los tres ultimos van al final para que quien solo queria [etiqueta, tooltip] siga funcionando
# sin tocar nada (los espejos leen estos mismos arrays y comprueban el size()).
# El chip va como [etiqueta, tooltip, icono (emoji), color, ultimo turno, CLAVE del icono pixel]. El emoji se queda: lo
# usan el registro, la red y CombatFX (que busca el estado por el). La clave es el nombre del Id en minusculas, el
# PNG de assets/ui/estados (05/11: los iconos en pixel art; StatusChip.de_par).
static func clave_icono(id: int) -> String:
	var k = Id.find_key(id)
	return String(k).to_lower() if k != null else ""


static func chip_de_grupo(insts: Array) -> Array:
	if insts.is_empty():
		return ["", "", "", Color.WHITE, false, ""]
	var larga: Instance = insts[0]
	var stacks_tot: int = 0
	var dot_tot: float = 0.0
	var turnos: PackedStringArray = []
	for e in insts:
		if e.turns > larga.turns:
			larga = e
		stacks_tot += maxi(1, e.stacks)
		dot_tot += e.dot_damage() + e.heal_amount() + e.mana_amount()
		turnos.append(e.duracion_texto())
	# LAS BRASAS (Quemadura, Rescoldo): arde solo la mas fuerte; el chip enseña esa, no la suma.
	if String(larga.d.get("stack_mode", "")) == "brasas":
		var fuerte: Instance = insts[0]
		for e in insts:
			if e.magnitude > fuerte.magnitude:
				fuerte = e
		return [fuerte.etiqueta(), fuerte.resumen() + "\n\n%d quemaduras a la vez (arde la más fuerte): %s" % [
			insts.size(), ", ".join(turnos)], str(fuerte.d.get("icono", "?")), fuerte.d.get("color", Color.WHITE),
			larga.turns == 1, clave_icono(fuerte.id())]
	var ic: String = str(larga.d.get("icono", "?"))
	var col: Color = larga.d.get("color", Color.WHITE)
	# Se mira el que MAS le queda, igual que la etiqueta: mientras siga vivo uno, el estado sigue
	# puesto. Los permanentes (turns < 0) no parpadean nunca: no se van solos.
	var ultimo: bool = larga.turns == 1
	if insts.size() == 1:
		return [larga.etiqueta(), larga.resumen(), ic, col, ultimo, clave_icono(larga.id())]

	# Mismo formato corto que etiqueta(): icono, stacks y lo que le queda. El daño total de todas
	# las instancias juntas y el desglose por aplicacion van al tooltip, aqui debajo.
	var etq: String = "%sx%d %s" % [ic, stacks_tot, larga.duracion_texto()]
	var tip: String = larga.resumen() + "\n\n%d aplicaciones: %s" % [
		insts.size(), ", ".join(turnos)]
	return [etq, tip, ic, col, ultimo, clave_icono(larga.id())]
