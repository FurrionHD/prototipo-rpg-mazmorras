# ============================================================
#  consumable_data.gd
#  RECURSO con los DATOS de un OBJETO consumible (poción). Se guarda como .tres.
#  Las pociones CURAN POR EL TIEMPO (heal-over-time), no de golpe:
#   - En COMBATE: aplican el estado Regeneración, que cura `cura_total` repartido
#     en `turnos` (cura_total/turnos por turno). Beber GASTA tu turno, asi que
#     premia aguantar/defender mientras la cura tiquea (KAN-57).
#   - FUERA de combate: curan `cura_total` repartido en `segundos` de tiempo real
#     (ver Game.beber_pocion_fuera / Game.tick_heal).
#  Inventario: Game.consumables (ConsumableData -> cantidad). Se consiguen por ahora
#  desde el panel de debug (boton "OBJETOS").
# ============================================================

extends Resource
class_name ConsumableData

@export var nombre: String = "Poción"
@export_multiline var descripcion: String = ""

# Cura PLANA (fija) de la poción. Manda al principio y hace que las pociones viejas se
# queden cortas al escalar la vida (progresion por tiers: necesitas pociones mejores).
@export var cura_total: float = 30.0
# Cura EXTRA como fraccion de tu vida MAXIMA (0.12 = +12% de tu max_hp). Un pelin de % para
# que una poción vieja no caiga a "rasguño" de golpe, sin volverla eterna. 0 = solo plano.
@export var cura_pct: float = 0.0
# MANÁ que restaura (mismo modelo que la vida: plano + % del maná máx). Una poción de
# MANÁ tiene cura_total 0 y mana_total > 0; una de VIDA al reves; podria haber una mixta.
@export var mana_total: float = 0.0
@export var mana_pct: float = 0.0

# COMBATE: la cura/maná se reparte en estos turnos (efectivo/turnos por turno).
@export var turnos: int = 3
# FUERA de combate: se reparte en estos segundos de tiempo real.
@export var segundos: float = 6.0

# ¿Esta poción cura VIDA? ¿da MANÁ? (para el menu y el uso).
func cura_hp() -> bool: return cura_total > 0.0 or cura_pct > 0.0
func da_mana() -> bool: return mana_total > 0.0 or mana_pct > 0.0

# --- VIDA: cura EFECTIVA total segun la vida maxima del que bebe (plano + % de max_hp) ---
func cura_efectiva(max_hp: float) -> float:
	return cura_total + cura_pct * max_hp
func cura_por_turno(max_hp: float) -> float:
	return cura_efectiva(max_hp) / float(maxi(1, turnos))
func cura_por_segundo(max_hp: float) -> float:
	return cura_efectiva(max_hp) / maxf(0.1, segundos)

# --- MANÁ: mismo modelo con el maná maximo ---
func mana_efectivo(max_mp: float) -> float:
	return mana_total + mana_pct * max_mp
func mana_por_turno(max_mp: float) -> float:
	return mana_efectivo(max_mp) / float(maxi(1, turnos))
func mana_por_segundo(max_mp: float) -> float:
	return mana_efectivo(max_mp) / maxf(0.1, segundos)

# Resumen corto del efecto para menus/HUD, p.ej. "cura 27" / "maná 10" / "cura 27 + maná 10".
func resumen(max_hp: float, max_mp: float) -> String:
	var p: Array = []
	if cura_hp():
		p.append("cura %.0f" % cura_efectiva(max_hp))
	if da_mana():
		p.append("maná %.0f" % mana_efectivo(max_mp))
	return " + ".join(p)
