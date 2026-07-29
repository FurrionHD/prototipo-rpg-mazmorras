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

# ¿Este golpe (0-indexado) se da con el escudo?
func golpe_es_de_escudo(i: int) -> bool:
	return escudo_desde_golpe >= 0 and i >= escudo_desde_golpe


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
# true  -> se tiran en CADA golpe que acierta (Ráfaga: cada tajo 40% de sangrado ->
#          mas golpes = mas sangrado, cada hit con su tirada, mas realista).
# false -> UNA sola tirada tras la habilidad si conecto algo (golpe de escudo: 1 stun).
@export var efectos_por_golpe: bool = false

# Activa la GUARDIA (Defender) durante N turnos tras usarla (golpe de escudo).
@export var bloqueo_turnos: int = 0

# MANÁ FIJO que RECUPERA al usarla (0 = ninguno). Una habilidad de PURA UTILIDAD (sin
# daño) se marca con dano_mult = 0: no golpea, solo su efecto.
@export var mana_gain: float = 0.0

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

# Texto del ÁREA para el resumen (derivado de los campos). "" si no golpea en área.
func _area_txt() -> String:
	match area_modo:
		AreaModo.SPLASH:
			var alcance: String = "todos los enemigos" if area_max >= 99 else "hasta %d enemigos" % area_max
			var base: String = "Salpica a %s: los de al lado encajan el %d%%" % [
				alcance, roundi(area_secundario * 100.0)]
			if area_secundario_decay > 0.0:
				return base + ", y un %d%% menos por cada enemigo de más." % roundi(
					area_secundario_decay * 100.0)
			return base + "."
		AreaModo.BARRIDO:
			var alcance2: String = "todos los enemigos" if area_max >= 99 else "hasta %d enemigos" % area_max
			return "Barre a %s a la vez, pero cada objetivo de más le quita un %d%% al golpe." % [
				alcance2, roundi((1.0 - area_falloff) * 100.0)]
	return ""


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
func resumen(manos: int = 1) -> String:
	# UNA FRASE POR LINEA, como las magias (SpellData.descripcion_mecanica). Antes era una tira de
	# abreviaturas unidas por puntos ("1.33× · 2 golpes · arma/escudo: 100%, 50% · ...") que se salia
	# de la pantalla y no habia forma de leer en mitad de un turno.
	var l: Array = []

	# --- QUE HACE AL PEGAR ---
	if dano_mult > 0.0:
		var g: String = _golpes_txt(manos)
		var uno: bool = g == "1"
		l.append("Golpea %s%s al %d%% de un golpe normal." % [
			"una vez" if uno else "%s veces" % g, "", roundi(dano_mult * 100.0)])
		if manos >= 2 and golpes_dual_max > golpes_max:
			l.append("Los golpes que pone la segunda arma (del %dº) pegan al %d%%." % [
				golpes_max + 1, roundi(dual_golpe_mult * 100.0)])
		elif not mults_golpe.is_empty():
			var partes := PackedStringArray()
			for i in mults_golpe.size():
				partes.append("el %dº al %d%%" % [i + 1, roundi(float(mults_golpe[i]) * 100.0)])
			l.append("No todos pegan igual: %s." % _y(partes))
		if escudo_desde_golpe == 0:
			l.append("Pega con el ESCUDO, así que su daño sale de tu Defensa y no de tu arma.")
		elif escudo_desde_golpe > 0:
			l.append("Del %dº golpe en adelante pega con el ESCUDO: ése sale de tu Defensa." % (
				escudo_desde_golpe + 1))
		var at: String = _area_txt()
		if at != "":
			l.append(at)
		elif redirige_al_morir and maxi(golpes_max, golpes_dual_max) > 1:
			l.append("Si mata al objetivo, los golpes que sobren saltan al siguiente.")
		var por: float = golpes_extra_por_enemigo
		if manos >= 2 and golpes_extra_por_enemigo_dual > 0.0:
			por = golpes_extra_por_enemigo_dual
		if por > 0.0:
			l.append("Suma %s golpe%s por cada enemigo de más (hasta %d)." % [
				_num(por), "" if por == 1.0 else "s", golpes_extra_max])
	elif not es_imbuicion() and limpia_debuffs <= 0:
		l.append("No hace daño.")

	# --- LO QUE APLICA ---
	var est: String = _texto_estados()
	if est != "":
		l.append(est)
	if es_imbuicion():
		var nom_est: String = str(StatusEffects.def(imbue_estado).get("nombre", "?"))
		var doble: String = "" if imbue_prob_doble <= 0.0 else 			", y un %d%% de meter dos dosis de golpe" % roundi(imbue_prob_doble * 100.0)
		l.append("Impregna tu arma de %s durante %d ataques: cada golpe tiene un %d%% de aplicarlo%s." % [
			nom_est, imbue_usos, roundi(imbue_prob * 100.0), doble])
		l.append("Se gasta al ATACAR, no con los turnos, y aguanta de un combate al siguiente.")
		if imbue_por_destreza:
			l.append("Prende más a menudo cuanta más Destreza tengas frente a su Resistencia.")
	if limpia_debuffs > 0:
		var a_quien: String = "a todo el grupo" if objetivo_aliado == Objetivo.GRUPO else "al aliado que elijas"
		l.append("Quita %s %s." % [
			"todos los perjuicios" if limpia_debuffs >= 99
			else "%d perjuicio%s al azar" % [limpia_debuffs, "" if limpia_debuffs == 1 else "s"], a_quien])
	if reduce_cooldowns > 0:
		l.append("Le quita %d turno%s de espera a tus OTRAS habilidades." % [
			reduce_cooldowns, "" if reduce_cooldowns == 1 else "s"])
	if invoca_cantidad > 0:
		l.append("Invoca %d ayudante%s." % [invoca_cantidad, "" if invoca_cantidad == 1 else "s"])
	if bloqueo_turnos > 0:
		l.append("Te deja en guardia %d turno%s: encajas mucho menos hasta tu próximo turno." % [
			bloqueo_turnos, "" if bloqueo_turnos == 1 else "s"])
	if provoca_turnos > 0:
		l.append("Durante %d turnos los enemigos tienden a atacarte a ti." % provoca_turnos)
	if postura_contraataque:
		l.append("Te pones en guardia: esquivas más y devuelves los golpes que esquives, pero vas más lento.")
	if foco_cargas > 0:
		l.append("Te da %d cargas de Foco arcano para tus próximos hechizos." % foco_cargas)
	if mana_gain > 0.0:
		l.append("Te devuelve %.0f de maná." % mana_gain)
	if energia_a_mana > 0.0:
		l.append("Convierte TODA tu energía en maná.")

	# --- LO QUE CUESTA (siempre la ultima linea) ---
	var coste_p: Array = []
	var c: float = coste(manos)
	if c > 0.0:
		coste_p.append("%.0f de energía" % c)
	if carga_turnos > 0:
		coste_p.append("tarda %d turno%s en soltarse" % [carga_turnos, "" if carga_turnos == 1 else "s"])
	if cooldown > 0:
		coste_p.append("vuelve a estar lista en %d turnos" % cooldown)
	if requiere_escudo:
		coste_p.append("necesitas ESCUDO")
	if requiere_off_libre:
		coste_p.append("necesitas la otra mano libre")
	if not coste_p.is_empty():
		l.append("Cuesta " + " · ".join(coste_p) + ".")
	return "
".join(l)


# Los estados que aplica, agrupados por A QUIEN van. Mismo criterio que SpellData._texto_estados:
# una frase con nombres y porcentajes, no una lista de siglas.
func _texto_estados() -> String:
	var al_rival: Array = []
	var a_los_mios: Array = []
	for a in efectos:
		if a == null or int(a.estado) < 0:
			continue
		var txt: String = _efecto_txt(a)
		if txt == "":
			continue
		if a.en_objetivo:
			al_rival.append(txt)
		else:
			a_los_mios.append(txt)
	var out: Array = []
	if not al_rival.is_empty():
		out.append("Aplica %s %s." % [_y(al_rival),
			"a cada enemigo alcanzado" if es_area() else "al objetivo"])
	if not a_los_mios.is_empty():
		var quien: String = "a todo el grupo" if _algun_efecto_al_grupo() else "a ti"
		out.append("Te aplica %s." % _y(a_los_mios) if quien == "a ti"
			else "Aplica %s a todo el grupo." % _y(a_los_mios))
	return " ".join(out)


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


# Texto de UN estado que aplica, a partir de su StatusApplication (nombre del catalogo
# + probabilidad + stacks/nivel/duracion, todo derivado de los campos).
func _efecto_txt(a) -> String:
	if a == null or int(a.estado) < 0:
		return ""
	var s: String = String(StatusEffects.def(int(a.estado)).get("nombre", "?"))
	var detalles: Array = ["%d%%" % roundi(a.prob * 100.0)]
	if int(a.stacks) > 1:
		detalles.append("x%d" % int(a.stacks))
	if a.mult > 0.0:
		# Nivel de un debuff/buff de stat: 0.80 -> -20%, 1.25 -> +25%.
		detalles.append("%+d%%" % roundi((a.mult - 1.0) * 100.0))
	if int(a.turns) > 0:
		detalles.append("%d turnos" % int(a.turns))
	return "%s (%s)" % [s, ", ".join(detalles)]
