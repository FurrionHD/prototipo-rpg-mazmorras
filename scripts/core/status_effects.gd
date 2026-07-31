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
	PLATO_ESTOMAGO, PLATO_FORTUNA }

# Veneno: base de daño (nivel 1) + tope global de stacks. Cada stack DUPLICA el daño
# (base x 2^(stacks-1)); las habilidades/enemigos capan a que stack llegan. PROVISIONAL.
const VENENO_BASE_DMG := 3.0
const VENENO_TURNS := 4
const VENENO_MAX_STACKS := 5

# Sangrado: APILABLE. Cada stack = fraccion BAJA del ATAQUE del aplicador (no 1:1);
# machacar con armas cortantes sube el daño total (dot = magnitud x stacks). PROVISIONAL.
const SANGRADO_FRACCION_ATK := 0.30
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

static func sangrado_magnitude(applier_atk: float, motion_value: float = 1.0) -> float:
	var mv: float = maxf(motion_value, 0.1)
	return applier_atk * SANGRADO_FRACCION_ATK / pow(mv, 1.0 + SANGRADO_MV_EXP)

# Magnitud EFECTIVA de un StatusApplication segun el aplicador. Si trae magnitud fija
# (>=0) se usa esa; si es Sangrado sin magnitud, escala con el ataque del aplicador
# (con el motion_value del arma invertido, ver sangrado_magnitude); si no, -1 (que
# apply_status traduce al dot_default del catalogo).
static func app_magnitude(app, applier_atk: float, motion_value: float = 1.0) -> float:
	var m: float = float(app.magnitud)
	if m >= 0.0:
		return m
	if int(app.estado) == Id.SANGRADO:
		return sangrado_magnitude(applier_atk, motion_value)
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
	"agilidad": "Agilidad", "magia": "Magia",
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
		"descripcion": "Una herida abierta que no espera. Cuanto más fuerte el que corta, más se abre; y cada corte sangra por su cuenta.",
	},
	Id.QUEMADURA: {
		"id": Id.QUEMADURA, "nombre": "Quemadura", "icono": "🔥", "color": Color(1.0, 0.5, 0.1),
		"dot": true, "turns": 2, "dot_default": 6.0,   # lo afinaran los hechizos (Fase 3)
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
		"id": Id.REGEN_MANA, "nombre": "Regen. maná", "icono": "🔷", "color": Color(0.4, 0.6, 1.0),
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
		"inmune": [Id.QUEMADURA],   # empapado NO puedes arder
		"limpia": [Id.QUEMADURA],   # y te APAGA la quemadura que llevaras encima
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
	Id.ESCOLTA: {   # ATAQUE DE SEGUIMIENTO: pegas detras de cada ataque de un aliado
		"id": Id.ESCOLTA, "nombre": "Escolta", "icono": "🗡", "color": Color(0.9, 0.8, 0.55),
		"turns": 3, "seguimiento_pct": 0.5,
		"descripcion": "Dejas de ir por tu cuenta: entras justo detrás del que abre el hueco.",
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
		"descripcion": "Comida de verdad, de la que se queda en el cuerpo. Encajas lo que te echen.",
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
		"descripcion": "Pescado y verdura, comida de convaleciente. El frasco te dura más.",
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

	func _init(def_: Dictionary, turns_: int, stacks_: int = 1) -> void:
		d = def_
		turns = turns_
		stacks = stacks_

	func id() -> int:
		return int(d.get("id", -1))

	# Daño por turno de este estado (0 si no es DoT). Los stacks escalan el daño segun
	# dot_stack_mult: por defecto 1.0 (cada instancia = magnitud; Sangrado suma varias
	# instancias). Veneno usa 2.0 -> base x 2^(stacks-1) (cada stack "sube de tier").
	func dot_damage() -> float:
		if is_heal() or is_mana_heal():
			return 0.0   # Regeneración: la magnitud es CURA/MANÁ, no daño (ver heal/mana_amount)
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
		if es_tiempo_real():
			lineas.append("%s  %s  ·  quedan %s" % [
				str(d.get("icono", "?")), str(d.get("nombre", "?")), tiempo_restante()])
		else:
			lineas.append("%s  %s  ·  %d turno%s" % [
				str(d.get("icono", "?")), str(d.get("nombre", "?")), turns, "" if turns == 1 else "s"])

		# Que te HACE, con la magnitud REAL de esta instancia (stacks ya dentro).
		if dot_damage() > 0.0:
			lineas.append("Te hace %.1f de daño cada turno." % dot_damage())
		if heal_amount() > 0.0:
			lineas.append("Te cura %.1f de vida cada turno." % heal_amount())
		if mana_amount() > 0.0:
			lineas.append("Te devuelve %.1f de maná cada turno." % mana_amount())
		# HABILIDADES BASE (platos): van primero porque es lo gordo que hace el plato.
		for clave in (d.get("hab_mult", {}) as Dictionary):
			var hm: float = hab_mult(str(clave))
			lineas.append("%s %+d%%." % [StatusEffects.NOMBRE_HABILIDAD.get(clave, str(clave)),
				roundi((hm - 1.0) * 100.0)])
		for par in [["atk_mult", "Haces"], ["def_mult", "Aguantas"], ["spd_mult", "Te mueves"],
				["dmg_taken_mult", "Te entra"], ["heal_recv_mult", "Te curan"],
				["def_flat_mult", "Tu armadura protege"], ["aggro_mult", "Te buscan"],
				["dmg_dealt_mult", "Tus golpes hacen"], ["mana_coste_mult", "Los hechizos cuestan"],
				["mp_kill_mult", "Cada bicho te deja"], ["mp_regen_mult", "Recuperas maná"],
				["dot_taken_mult", "El daño por turno te hace"],
				["drop_mult", "Los bichos sueltan botín"]]:
			if not d.has(par[0]):
				continue
			var m: float = mult_de(str(par[0]))
			var pct: int = roundi((m - 1.0) * 100.0)
			lineas.append("%s un %d%% %s." % [
				str(par[1]), absi(pct), "más" if pct > 0 else "menos"])
		# Los ADITIVOS (puntos porcentuales, no multiplicadores).
		for par in [["crit_flat", "Criticas un %d%% más a menudo."],
				["evade_flat", "Esquivas un %d%% más a menudo."],
				["status_resist_flat", "Resistes un %d%% más los estados alterados."],
				["drop_doble_flat", "Un %d%% de los botines sale doble."]]:
			if d.has(par[0]):
				lineas.append(str(par[1]) % roundi(flat_de(str(par[0])) * 100.0))
		if d.has("mochila_extra"):
			lineas.append("Cargas con %d más." % roundi(flat_de("mochila_extra")))
		if is_stun():
			lineas.append("Pierdes el turno.")
		if stun_prob_mult() != 1.0:
			lineas.append("Te aturden más fácil.")
		for id_inm in (d.get("inmune", []) as Array):
			lineas.append("No te puede afectar: %s." % str(StatusEffects.def(id_inm).get("nombre", "?")))

		# Stacks: solo el contador, si de verdad apila. El COMO apila es cocina interna.
		var maxs: int = int(d.get("max_stacks", 1))
		if maxs > 1:
			lineas.append("Acumulado %d de %d." % [stacks, maxs])

		# La frase de SABOR ('descripcion' del catalogo) NO se pinta aqui: en mitad de un turno lo
		# que hace falta es saber que te esta pasando, no leerse un parrafo. Se queda en el catalogo
		# para donde tenga sentido (ficha/bestiario), que es donde se lee con calma.
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
		"magnitude": inst.magnitude, "mult": inst.mult_override, "escala": inst.escala}


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
			float(d.get("escala", 1.0)))


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
	# 'fresh' NO viaja: existe para que un buff recien echado no se coma un turno antes de poder
	# usarlo DENTRO de la pelea. Fuera no hay accion que proteger, y al volver a entrar en combate
	# lo que queda es lo que queda.
	inst.fresh = false
	return inst


# QUE hace un estado, en una frase corta y con el NOMBRE de lo que toca ("−25% defensa"), para las
# fichas. Sin el nombre, un "(30%, -25%)" no dice si el -25% es probabilidad, daño o duracion.
# 'mult' = el nivel concreto de esta aplicacion (StatusApplication.mult), o 0 para el del catalogo.
# 'escala' = el tier del plato (1.2 = el T2, que aprieta un 20% mas). Escala el BONUS, igual que
# Instance.escala, para que la ficha del plato T2 diga +12% y no +10%.
static func efecto_legible(id: int, mult: float = 0.0, escala: float = 1.0) -> String:
	var d: Dictionary = def(id)
	var etiquetas: Dictionary = {
		"atk_mult": "ataque", "def_mult": "defensa", "spd_mult": "velocidad",
		"dmg_taken_mult": "daño recibido", "heal_recv_mult": "curación recibida",
		"def_flat_mult": "armadura", "aggro_mult": "de atención de los enemigos",
		"hp_mult": "vida máxima",
		"dmg_dealt_mult": "daño hecho", "spell_dmg_mult": "daño mágico",
		"mana_coste_mult": "coste de los hechizos", "mp_kill_mult": "maná por enemigo",
		"mp_regen_mult": "regeneración de maná", "dot_taken_mult": "daño por turno recibido",
		"drop_mult": "probabilidad de botín",
	}
	# Los ADITIVOS: puntos porcentuales, no multiplicadores. Un "+5% crítico" no es un x1.05, y
	# pasarlo por la formula de arriba lo pintaria como "-95%".
	var etiquetas_flat: Dictionary = {
		"crit_flat": "crítico", "evade_flat": "esquiva",
		"status_resist_flat": "resistencia a estados",
		"drop_doble_flat": "de que el botín salga doble",
	}
	var partes: Array = []
	# Las HABILIDADES BASE (platos) van primero: es lo mas gordo que hacen.
	for clave in (d.get("hab_mult", {}) as Dictionary):
		partes.append("%+d%% %s" % [roundi((float(d["hab_mult"][clave]) - 1.0) * 100.0 * escala),
			str(NOMBRE_HABILIDAD.get(clave, clave))])
	for clave in etiquetas:
		if not d.has(clave):
			continue
		var m: float = mult if mult > 0.0 else float(d[clave])
		partes.append("%+d%% %s" % [roundi((m - 1.0) * 100.0 * escala), str(etiquetas[clave])])
	for clave in etiquetas_flat:
		if d.has(clave):
			partes.append("%+d%% %s" % [roundi(float(d[clave]) * 100.0 * escala),
				str(etiquetas_flat[clave])])
	if d.has("mochila_extra"):
		partes.append("+%d de carga" % roundi(float(d["mochila_extra"]) * escala))
	if not partes.is_empty():
		return " y ".join(partes)
	if bool(d.get("is_stun", false)):
		return "le hace perder el turno"
	if bool(d.get("dot", false)):
		return "le hace daño cada turno"
	if bool(d.get("heal", false)):
		return "le cura cada turno"
	if bool(d.get("mana_heal", false)):
		return "le devuelve maná cada turno"
	if bool(d.get("silencia", false)):
		return "le corta hechizos y habilidades"
	if float(d.get("seguimiento_pct", 0.0)) > 0.0:
		return "pegas detrás de cada aliado realizando un %d%% de daño" % roundi(
			float(d["seguimiento_pct"]) * 100.0)
	return ""


# UN CHIP por estado, aunque tenga varias instancias. Los estados 'independent' (Pegajoso,
# Sangrado) crean una Instance por aplicacion, asi que la UI pintaba cuatro iconos iguales en fila
# y no habia forma de saber cuanto le quedaba a cada uno.
#
# 'insts' = todas las instancias del MISMO estado. Devuelve [etiqueta, tooltip, icono, color]:
#   - etiqueta: los stacks SUMADOS y los turnos del que MAS le queda (el estado no se te va hasta
#     que caduca el ultimo), y en los DoT el daño total de todas juntas.
#   - tooltip: la ficha de la instancia mas larga + una linea con lo que le queda a cada una, que
#     es justo el dato que se perdia al agrupar.
#   - icono y color: para pintarlo como CHIP con recuadro (ver scripts/ui/status_chip.gd). Van al
#     final para que quien solo queria [etiqueta, tooltip] siga funcionando sin tocar nada.
static func chip_de_grupo(insts: Array) -> Array:
	if insts.is_empty():
		return ["", "", "", Color.WHITE]
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
	var ic: String = str(larga.d.get("icono", "?"))
	var col: Color = larga.d.get("color", Color.WHITE)
	if insts.size() == 1:
		return [larga.etiqueta(), larga.resumen(), ic, col]

	# Mismo formato corto que etiqueta(): icono, stacks y lo que le queda. El daño total de todas
	# las instancias juntas y el desglose por aplicacion van al tooltip, aqui debajo.
	var etq: String = "%sx%d %s" % [ic, stacks_tot, larga.duracion_texto()]
	var tip: String = larga.resumen() + "\n\n%d aplicaciones: %s" % [
		insts.size(), ", ".join(turnos)]
	return [etq, tip, ic, col]
