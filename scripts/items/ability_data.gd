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
