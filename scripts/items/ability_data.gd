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

# Energia que gasta al usarla (KAN-57).
@export var coste_energia: float = 20.0

# Golpes: nº de impactos. Si por_mano=true se IGNORA y da 1 impacto POR MANO de arma
# (dual-wield = 2 golpes, 1 mano = 1) -> asi la Ráfaga de daga escala con el dual.
@export var golpes: int = 1
@export var por_mano: bool = false

# Daño por impacto respecto a un ataque normal (1.0 = como un básico; <1 = flurry).
@export var dano_mult: float = 1.0
# Tipo de daño forzado: -1 = el del arma; 0 CORTE, 1 CONTUNDENTE (golpe de escudo).
@export var dano_tipo_override: int = -1

# Estados que aplica CADA impacto al enemigo (Array[StatusApplication], con su prob).
@export var efectos: Array = []

# Activa la GUARDIA (Defender) durante N turnos tras usarla (golpe de escudo).
@export var bloqueo_turnos: int = 0


# Nº de impactos reales según el loadout (por_mano -> nº de manos de arma).
func num_golpes(manos: int) -> int:
	if por_mano:
		return maxi(1, manos)
	return maxi(1, golpes)
