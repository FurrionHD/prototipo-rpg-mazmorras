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

# Lo que aporta la SEGUNDA MANO vale la MITAD: los golpes EXTRA que solo existen porque
# llevas dos armas (los que pasan del rango de UNA mano) pegan a este multiplicador. Asi
# el dual vale ~1.5x la version a una mano, no 2x ni 3x (que era lo que la disparaba).
@export var dual_golpe_mult: float = 0.5
# MULTIPLICADOR EXPLICITO POR GOLPE (índice 0-based). Vacío = manda la regla del dual (arriba).
# Lo usan las técnicas de ARMA + ESCUDO (Aplastamiento, Guardia rota): el 1er golpe es con el ARMA
# (más daño) y el 2º con el ESCUDO (menos). Cada golpe se simula distinto sin dos armas de por
# medio. Si el índice pasa del array, se repite el último valor.
@export var mults_golpe: Array = []
# Tipo de daño forzado: -1 = el del arma; 0 CORTE, 1 CONTUNDENTE (golpe de escudo).
@export var dano_tipo_override: int = -1

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
@export var area_secundario: float = 0.5  # SPLASH: fracción de daño a cada secundario
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
			var alcance: String = "toda la fila" if area_max >= 99 else "%d enemigos" % area_max
			return "área: %d%% a %s" % [roundi(area_secundario * 100.0), alcance]
		AreaModo.BARRIDO:
			var alcance2: String = "toda la fila" if area_max >= 99 else "hasta %d" % area_max
			return "barrido: %s, −%d%% por objetivo" % [alcance2, roundi((1.0 - area_falloff) * 100.0)]
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
	var p: Array = []
	if dano_mult > 0.0:
		var g: String = _golpes_txt(manos)
		p.append("%s× · %s golpe%s" % [_num(dano_mult), g, "" if g == "1" else "s"])
		# DUAL: los golpes que pone la segunda arma pegan a la mitad (dual_golpe_mult).
		if manos >= 2 and golpes_dual_max > golpes_max:
			p.append("del %dº en adelante al %d%%" % [golpes_max + 1, roundi(dual_golpe_mult * 100.0)])
		# ARMA+ESCUDO (mults_golpe): cada golpe con su parte (el 1º del arma, el 2º del escudo, menos).
		elif not mults_golpe.is_empty():
			var partes := PackedStringArray()
			for m in mults_golpe:
				partes.append("%d%%" % roundi(float(m) * 100.0))
			p.append("%s: %s" % ["arma/escudo" if requiere_escudo else "por golpe", ", ".join(partes)])
		# ÁREA: cómo reparte a los demás enemigos (derivado de los campos, nunca a mano).
		var at: String = _area_txt()
		if at != "":
			p.append(at)
		# REDIRECCIÓN: solo se anuncia si de verdad puede sobrar algún golpe (multi-golpe).
		elif redirige_al_morir and maxi(golpes_max, golpes_dual_max) > 1:
			p.append("si mata, sigue a otro")
		# ESCALA POR MULTITUD: más golpes cuantos más enemigos (derivado del campo).
		var por: float = golpes_extra_por_enemigo
		if manos >= 2 and golpes_extra_por_enemigo_dual > 0.0:
			por = golpes_extra_por_enemigo_dual
		if por > 0.0:
			p.append("+%s golpe/enemigo" % _num(por))
	var c: float = coste(manos)
	if c > 0.0:
		p.append("%.0f EN" % c)
	if invoca_cantidad > 0:
		p.append("invoca %d" % invoca_cantidad)
	if carga_turnos > 0:
		p.append("carga %dt" % carga_turnos)
	if cooldown > 0:
		p.append("CD %dt" % cooldown)
	if foco_cargas > 0:
		p.append("+%d Foco" % foco_cargas)
	if mana_gain > 0.0:
		p.append("+%.0f MP" % mana_gain)
	if bloqueo_turnos > 0:
		p.append("guardia %dt" % bloqueo_turnos)
	if provoca_turnos > 0:
		p.append("provoca %dt" % provoca_turnos)
	for a in efectos:
		var et: String = _efecto_txt(a)
		if et != "":
			p.append(et)
	return " · ".join(p)


# Texto de UN estado que aplica, a partir de su StatusApplication (nombre del catalogo
# + probabilidad + stacks/nivel/duracion, todo derivado de los campos).
func _efecto_txt(a) -> String:
	if a == null or int(a.estado) < 0:
		return ""
	var s: String = "%s %d%%" % [
		String(StatusEffects.def(int(a.estado)).get("nombre", "?")), roundi(a.prob * 100.0)]
	if int(a.stacks) > 1:
		s += " x%d" % int(a.stacks)
	if a.mult > 0.0:
		# Nivel de un debuff/buff de stat: 0.80 -> -20%, 1.25 -> +25%.
		var delta: int = roundi((a.mult - 1.0) * 100.0)
		s += " %+d%%" % delta
	if int(a.turns) > 0:
		s += " %dt" % int(a.turns)
	return s
