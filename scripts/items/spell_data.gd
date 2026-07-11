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
@export var elemento: int = Elementos.Elemento.NINGUNO

# --- IMBUICION: el hechizo no pega, TIÑE tus golpes de arma con su 'elemento' ---
# imbue_tipo: 0 = no es imbuicion | 1 = ARMA (solo ofensiva) | 2 = CUERPO (ademas te da la
# AFINIDAD del elemento: resistencias, debilidades e inmunidades; casteo mas largo).
# imbue_pct: fraccion del daño que se añade como daño ELEMENTAL (0.30 = +30%). Porcentual a
# proposito: escala sola con tu Fuerza/arma/mejoras y no hay que retunearla nunca.
@export var imbue_tipo: int = 0
@export var imbue_pct: float = 0.0
@export var imbue_turnos: int = 0
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


# Probabilidad FINAL de aplicar un efecto (sube con la longitud del hechizo).
func efecto_prob(app: StatusApplication) -> float:
	return clampf(app.prob * float(longitud()), 0.0, ESTADO_PROB_MAX)
