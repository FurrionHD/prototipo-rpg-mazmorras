# ============================================================
#  spell_data.gd
#  RECURSO (Resource) con los DATOS de un HECHIZO. Se guarda como .tres.
#
#  Los hechizos se lanzan RECITANDO un encantamiento: una o varias FRASES en
#  orden. En combate, cada turno el juego muestra un test tipo examen (a/b/c/d)
#  con la frase correcta mezclada con distractores del repositorio (SpellBook).
#  Aciertas -> avanzas a la siguiente frase; fallas -> backfire (te daña).
#
#  La LONGITUD del hechizo = numero de frases:
#    1 frase  = CORTO   (T1 recitas, T2 dispara)
#    2 frases = MEDIO   (T1, T2 recitas, T3 dispara)
#    3 frases = LARGO   (T1, T2, T3 recitas, T4 dispara)
#
#  De momento solo se implementa el tipo ATAQUE (daño). BUFF/DEBUFF quedan
#  definidos en el modelo pero se implementan en una tarea futura (con KAN-58).
# ============================================================

extends Resource
class_name SpellData

enum TipoEfecto { ATAQUE, BUFF, DEBUFF }

# ALCANCE del hechizo: a cuantos enemigos llega el AREA.
#   OBJETIVO   = solo al que tengas seleccionado (lo de siempre).
#   ADYACENTES = al seleccionado y a los de su izquierda y derecha. Con 4 enemigos uno se
#                salva: es la contrapartida de que la magia de area sea la reina del grupo.
#   TODOS      = a todos los vivos.
enum Alcance { OBJETIVO, ADYACENTES, TODOS }

@export var nombre: String = "Hechizo"
@export var tipo: TipoEfecto = TipoEfecto.ATAQUE

# Frases del encantamiento EN ORDEN. Se recitan una por turno. El tamaño define
# corto/medio/largo. Deberian salir del repositorio de SpellBook.REPOSITORIO.
@export var frases: Array[String] = []

# Coste de maná (se descuenta AL EMPEZAR el casteo; si fallas, se pierde).
@export var coste_mana: int = 5

# RAW del hechizo: se escala con la Magia del lanzador (magia_factor) y con el
# magic_amp del arma (bastones/varitas, futuro KAN-95). PROVISIONAL -> Excel.
# OJO: este NO es el numero que hay que enseñar en pantalla; para eso esta dano_mostrado().
@export var dano_base: float = 10.0

# ELEMENTO del hechizo (Elementos.Elemento): decide la resistencia/debilidad del objetivo.
# NINGUNO = daño mágico neutro (no lo modula ningún elemento). Ver elements.gd.
# Con 'elemento_mix' (abajo) sigue siendo el elemento de IDENTIDAD del hechizo: el que usa
# la imbuicion y el que vale de fallback si no hay reparto.
@export var elemento: int = Elementos.Elemento.NINGUNO

# --- MULTI-GOLPE (KAN: Tormenta) ---
# Nº de GOLPES en que se reparte el dano_base. 1 = un solo impacto (lo normal).
# Cada golpe se resuelve por separado: elige su elemento, se mitiga y tira SUS estados.
# La mitigacion es LINEAL en el ataque, asi que partir el daño no cambia el total: lo que
# cambia es que cada golpe pasa por la tabla de tipos con SU elemento y ve el estado del
# objetivo TAL COMO ESTA en ese momento (los golpes de antes ya han podido mojarlo).
@export var hits: int = 1

# REPARTO de elementos entre los golpes: { Elementos.Elemento: peso }. Vacio = todos los
# golpes usan 'elemento'. Tormenta: { AGUA: 0.7, RAYO: 0.3 } -> llueve mucho y cae algun
# rayo, en orden ALEATORIO. Los pesos no hace falta que sumen 1 (se normalizan solos).
@export var elemento_mix: Dictionary = {}

# --- MULTI-OBJETIVO: AREA y REBOTES ---
# Eje DISTINTO al de 'hits': los golpes son POR OBJETIVO. Un hechizo de area con hits=3 le
# mete sus 3 golpes a CADA enemigo que alcanza, y cada golpe sigue tirando su elemento del
# reparto. Los dos ejes se multiplican y no se estorban.
#
# El daño de cada objetivo es dano_base x su MULTIPLICADOR: el principal cobra
# 'dano_objetivo' y el salpicon 'dano_salpicon'. Estan separados para que un mismo alcance
# valga para "150% / 75%" (Brasa) y para "80% a todos" (Rocio).
@export var alcance: Alcance = Alcance.OBJETIVO
@export var dano_objetivo: float = 1.0
@export var dano_salpicon: float = 0.0

# REBOTES: impactos EXTRA, despues del area, cada uno a un enemigo VIVO al AZAR. Pueden
# repetir objetivo y pueden caer en el principal: en 1v1 rebotan todos sobre el unico
# enemigo. No se pueden dirigir, y esa es su gracia y su limite.
@export var rebotes: int = 0
@export var dano_rebote: float = 0.0
# ¿Los rebotes tiran los ESTADOS del hechizo? NO por defecto, y a proposito: un rebote es la
# misma descarga arqueando, no un lanzamiento nuevo. Si tirasen estados, en 1v1 los rebotes
# caerian todos sobre el mismo bicho y multiplicarian las tiradas (3 golpes al 30% = 66%
# pasarian a ser 12 tiradas = 99%), o sea que prob_total() de la ficha MENTIRIA... y solo
# cuando hay pocos enemigos. Asi la ficha dice la verdad con 1 y con 4.
@export var rebote_estados: bool = false

# --- DISPERSION: los GOLPES caen repartidos a enemigos VIVOS al AZAR ---
# Distinto de los rebotes: aqui cada uno de los 'hits' es un lanzamiento de pleno derecho.
# Cada golpe elige un vivo al azar (recalculado por golpe, nunca un cadaver) y aplica ahi el
# ALCANCE del hechizo: si 'alcance' salpica, cada golpe ademas lame a los adyacentes de SU
# punto de impacto. A diferencia de los rebotes, SI tira los estados (una tormenta moja y una
# andanada quema). En 1v1 todo cae sobre el unico enemigo, asi que no pierde daño single.
#   Tormenta: hits=20, alcance=OBJETIVO -> 20 impactos sueltos repartidos.
#   Andanada: hits=4,  alcance=ADYACENTES -> 4 bolas al azar que salpican 150/75 donde caen.
@export var dispersa: bool = false

# --- IMBUICION: el hechizo no pega, TIÑE tus golpes de arma con su 'elemento' ---
# imbue_tipo: 0 = no es imbuicion | 1 = ARMA (solo ofensiva) | 2 = CUERPO (ademas te da la
# AFINIDAD del elemento: resistencias, debilidades e inmunidades; casteo mas largo).
# imbue_pct: fraccion del daño que se añade como daño ELEMENTAL (0.30 = +30%). Porcentual a
# proposito: escala sola con tu Fuerza/arma/mejoras y no hay que retunearla nunca.
@export var imbue_tipo: int = 0
@export var imbue_pct: float = 0.0
# Duracion en ATAQUES, no en turnos: cada ataque que lanzas (basico o habilidad) gasta un uso.
# Si durase turnos, recitar un conjuro largo te la fundiria antes de poder pegar con ella.
@export var imbue_usos: int = 0
# ESTADO que aplican tus golpes imbuidos (StatusEffects.Id; -1 = ninguno) y su probabilidad
# BASE en igualdad de poder. La prob. real la escala un CONTEST de tu Magia vs la Resistencia
# del rival (neutra en igualdad, sube contra debiles, baja contra fuertes). Las de CUERPO
# llevan menos prob. que las de ARMA: a cambio dan la afinidad entera.
@export var imbue_estado: int = -1
@export var imbue_prob: float = 0.0
# FRANJA de la afinidad que da el imbue de CUERPO (solo aplica si imbue_tipo = 2).
# 1.0 = como una criatura PURA del elemento (×0.5 / ×1.5). 0.4 = imbuido (×0.8 / ×1.2):
# no es lo mismo SER de fuego que haberte echado un manto encima. Ver Elementos.
@export var imbue_intensidad: float = 0.4

@export_multiline var descripcion: String = ""

# --- ESTADOS ALTERADOS que aplica el hechizo (KAN-58 Fase 3) ---
# Lista de StatusApplication. Un hechizo puede aplicar VARIOS: p.ej. Tormenta =
# Rayo + Aturdido. En cada uno, 'prob' es la BASE por frase. Ver status_application.gd.
@export var efectos: Array = []

const ESTADO_PROB_MAX := 0.95


# Numero de frases (= turnos de recitado). 1=corto, 2=medio, 3=largo.
func longitud() -> int:
	return frases.size()


# Nº de golpes REAL (minimo 1).
func golpes() -> int:
	return maxi(hits, 1)

func es_multigolpe() -> bool:
	return golpes() > 1


# Nº de REBOTES real (nunca negativo).
func rebotes_n() -> int:
	return maxi(rebotes, 0)


# ¿Salpica a alguien mas que al objetivo? (un alcance de area con multiplicador a 0 no salpica).
func salpica() -> bool:
	return alcance != Alcance.OBJETIVO and dano_salpicon > 0.0


# ¿Toca a mas de un enemigo? Lo que decide si el combate usa la ruta multi-objetivo (y su
# log compacto) o la de siempre.
func es_multiobjetivo() -> bool:
	return salpica() or rebotes_n() > 0 or dispersa


# Peso (0..1) de un elemento en el reparto. Sin reparto: 1.0 para el elemento del hechizo.
func peso_elemento(elem: int) -> float:
	if elemento_mix.is_empty():
		return 1.0 if elem == elemento else 0.0
	var total: float = 0.0
	for e in elemento_mix:
		total += maxf(0.0, float(elemento_mix[e]))
	if total <= 0.0:
		return 0.0
	return maxf(0.0, float(elemento_mix.get(elem, 0.0))) / total


# Nº de golpes que se espera que salgan de 'elem' (media). Con elem < 0 = todos los golpes.
func golpes_esperados(elem: int) -> float:
	if elem < 0:
		return float(golpes())
	return float(golpes()) * peso_elemento(elem)


# ELEMENTO de UN golpe: tirada ponderada sobre 'elemento_mix'. Sin reparto, siempre el
# elemento del hechizo. Es lo que hace que el orden agua/rayo sea ALEATORIO.
func elemento_de_golpe() -> int:
	if elemento_mix.is_empty():
		return elemento
	var total: float = 0.0
	for e in elemento_mix:
		total += maxf(0.0, float(elemento_mix[e]))
	if total <= 0.0:
		return elemento
	var r: float = randf() * total
	for e in elemento_mix:
		r -= maxf(0.0, float(elemento_mix[e]))
		if r <= 0.0:
			return int(e)
	return elemento   # por redondeo


# Probabilidad de aplicar un efecto EN UNA TIRADA.
#  - 1 golpe   -> la longitud del hechizo la multiplica: un conjuro largo es mas fiable.
#  - N golpes  -> es la prob POR GOLPE tal cual: la fiabilidad ya la dan las N tiradas
#                 (multiplicarla ademas por la longitud la dispararia). Ver prob_total().
func efecto_prob(app: StatusApplication) -> float:
	if es_multigolpe():
		return clampf(app.prob, 0.0, ESTADO_PROB_MAX)
	return clampf(app.prob * float(longitud()), 0.0, ESTADO_PROB_MAX)


# Probabilidad ACUMULADA de que un efecto acabe entrando en todo el hechizo: 1 - (1-p)^n,
# con n = los golpes en los que ese efecto llega a tirarse (los de su elemento_req).
# Es la que va a la FICHA: con 20 golpes, un 9% por golpe es un ~74% de verdad.
func prob_total(app: StatusApplication) -> float:
	var p: float = efecto_prob(app)
	var n: float = golpes_esperados(int(app.elemento_req))
	if n <= 0.0:
		return 0.0
	return clampf(1.0 - pow(1.0 - p, n), 0.0, ESTADO_PROB_MAX)


# "Corto" / "Medio" / "Largo" segun el nº de frases del encantamiento.
func longitud_texto() -> String:
	match longitud():
		1: return "Corto"
		2: return "Medio"
		3: return "Largo"
	return "%d frases" % longitud()


# ALCANCE en texto, DERIVADO de los multiplicadores ("150% al objetivo · 75% a los
# adyacentes"). "" si el hechizo no salpica.
func alcance_texto() -> String:
	if not salpica():
		return ""
	var obj: int = roundi(dano_objetivo * 100.0)
	var sal: int = roundi(dano_salpicon * 100.0)
	match alcance:
		Alcance.ADYACENTES:
			return "%d%% al objetivo · %d%% a los adyacentes" % [obj, sal]
		Alcance.TODOS:
			# Reparto plano (Rocio): decirlo de una vez en vez de repetir el mismo numero.
			if is_equal_approx(dano_objetivo, dano_salpicon):
				return "%d%% a todos los enemigos" % obj
			return "%d%% al objetivo · %d%% al resto" % [obj, sal]
	return ""


# REBOTES en texto ("3 rebotes de 50% al azar"). "" si no rebota.
func rebotes_texto() -> String:
	if rebotes_n() <= 0:
		return ""
	return "%d rebote%s de %d%% al azar" % [
		rebotes_n(), "" if rebotes_n() == 1 else "s", roundi(dano_rebote * 100.0)]


# DISPERSION en texto ("4 golpes dispersos al azar"). "" si no dispersa.
func dispersa_texto() -> String:
	if not dispersa:
		return ""
	return "%d golpes dispersos al azar" % golpes()


func es_imbuicion() -> bool:
	return imbue_tipo > 0

func imbue_texto() -> String:
	return "cuerpo" if imbue_tipo == 2 else "arma"


# El daño que se ENSEÑA, que no es el campo crudo: lleva dentro el multiplicador GLOBAL de la
# magia (StatsMath.SPELL_DAMAGE_MULT), que se aplica a todos los hechizos de todo el mundo en
# resolve_spell. Es del HECHIZO, no de quien lo lanza, asi que su sitio es este.
#
# Estuvo un tiempo colandose en el "Poder magico" de la ficha de personaje, y ahi mentia dos veces:
# hacia creer que tenias un +50% arcano de la nada (un tio sin magia leia ×1.50) y ademas dejaba la
# ficha del hechizo diciendo 10 cuando el bicho recibia 15. Aqui cuadra: daño del hechizo × tu poder.
func dano_mostrado() -> float:
	return dano_base * StatsMath.SPELL_DAMAGE_MULT


# RESUMEN mecanico GENERADO desde los campos (nunca hardcodeado en la descripcion, que
# queda para el SABOR). Lo usa el menu de personaje. Ver tambien AbilityData.resumen().
func resumen() -> String:
	var p: Array = []
	p.append("%s (%d frase%s)" % [longitud_texto(), longitud(), "" if longitud() == 1 else "s"])
	p.append("%d maná" % coste_mana)
	if tipo == TipoEfecto.ATAQUE and dano_base > 0.0:
		var d: String = "%.0f de daño" % dano_mostrado()
		if es_multigolpe():
			d += " en %d golpes" % golpes()
		if not elemento_mix.is_empty():
			# Reparto DERIVADO de los pesos: "70% Agua · 30% Rayo".
			var partes: Array = []
			for e in elemento_mix:
				partes.append("%d%% %s" % [roundi(peso_elemento(int(e)) * 100.0), Elementos.nombre(int(e))])
			d += " (%s)" % " · ".join(partes)
		elif elemento != Elementos.Elemento.NINGUNO:
			d += " de %s" % Elementos.nombre(elemento)
		p.append(d)
		# Alcance y rebotes: los textos salen de los multiplicadores, no escritos a mano.
		if salpica():
			# En un disperso con mezcla, solo el elemento de identidad salpica: no mentir diciendo
			# "X% a los adyacentes" como si salpicaran todos los golpes.
			if dispersa and not elemento_mix.is_empty():
				p.append("los golpes de %s salpican %d%% a los adyacentes" % [
					Elementos.nombre(elemento), roundi(dano_salpicon * 100.0)])
			else:
				p.append(alcance_texto())
		if rebotes_n() > 0:
			p.append(rebotes_texto())
		if dispersa:
			p.append(dispersa_texto())
	if es_imbuicion():
		p.append("imbuye el %s de %s" % [imbue_texto(), Elementos.nombre(elemento)])
		p.append("+%d%% de daño" % roundi(imbue_pct * 100.0))
		p.append("%d ataque%s" % [imbue_usos, "" if imbue_usos == 1 else "s"])
		if imbue_estado >= 0 and imbue_prob > 0.0:
			p.append("%s %d%% al golpear" % [
				String(StatusEffects.def(imbue_estado).get("nombre", "?")),
				roundi(imbue_prob * 100.0)])
	for a in efectos:
		if a == null or int(a.estado) < 0:
			continue
		var quien: String = "" if a.en_objetivo else " (a ti)"
		# El % que se enseña es el ACUMULADO de todo el hechizo (no el de una tirada suelta).
		p.append("%s %d%%%s" % [
			String(StatusEffects.def(int(a.estado)).get("nombre", "?")),
			roundi(prob_total(a) * 100.0), quien])
	return " · ".join(p)
