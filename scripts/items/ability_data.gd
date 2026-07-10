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

# Daño por impacto respecto a un ataque normal (1.0 = como un básico; <1 = flurry).
@export var dano_mult: float = 1.0
# Tipo de daño forzado: -1 = el del arma; 0 CORTE, 1 CONTUNDENTE (golpe de escudo).
@export var dano_tipo_override: int = -1

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


# Nº de impactos (aleatorio dentro del rango; dual usa su rango si lo tiene).
func num_golpes(manos: int) -> int:
	if manos >= 2 and golpes_dual_max > 0:
		return randi_range(maxi(1, golpes_dual_min), maxi(golpes_dual_min, golpes_dual_max))
	return randi_range(maxi(1, golpes_min), maxi(golpes_min, golpes_max))

# Coste de energia segun el loadout (dual gasta mas si tiene coste propio).
func coste(manos: int) -> float:
	if manos >= 2 and coste_energia_dual > 0.0:
		return coste_energia_dual
	return coste_energia
