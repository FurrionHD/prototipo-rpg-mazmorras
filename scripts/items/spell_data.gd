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

@export var nombre: String = "Hechizo"
@export var tipo: TipoEfecto = TipoEfecto.ATAQUE

# Frases del encantamiento EN ORDEN. Se recitan una por turno. El tamaño define
# corto/medio/largo. Deberian salir del repositorio de SpellBook.REPOSITORIO.
@export var frases: Array[String] = []

# Coste de maná (se descuenta AL EMPEZAR el casteo; si fallas, se pierde).
@export var coste_mana: int = 5

# RAW del hechizo: se escala con la Magia del lanzador (magia_factor) y con el
# magic_amp del arma (bastones/varitas, futuro KAN-95). PROVISIONAL -> Excel.
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


func es_imbuicion() -> bool:
	return imbue_tipo > 0

func imbue_texto() -> String:
	return "cuerpo" if imbue_tipo == 2 else "arma"


# RESUMEN mecanico GENERADO desde los campos (nunca hardcodeado en la descripcion, que
# queda para el SABOR). Lo usa el menu de personaje. Ver tambien AbilityData.resumen().
func resumen() -> String:
	var p: Array = []
	p.append("%s (%d frase%s)" % [longitud_texto(), longitud(), "" if longitud() == 1 else "s"])
	p.append("%d maná" % coste_mana)
	if tipo == TipoEfecto.ATAQUE and dano_base > 0.0:
		var d: String = "%.0f de daño" % dano_base
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
