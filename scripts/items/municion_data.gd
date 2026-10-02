# ============================================================
#  municion_data.gd
#  LA MUNICION DE MATERIAL del arco y la ballesta (02/10/2026): flechas y virotes, uno por metal (los
#  nueve, sub-tiers incluidos). Es un MaterialData mas -- vive en la bolsa y en el baul, tiene calidad y
#  se apila --, con tres datos propios. La normal (la infinita) NO es esto: no existe como objeto.
#
#  Se fabrica en el CARPINTERO (lingote + tablon, ver Game.fabricar_municion) y se carga con la habilidad
#  Cargar. Diseño entero en la memoria municion-flechas-diseno.
# ============================================================
extends MaterialData
class_name MunicionData

# Con que arma se dispara (WeaponData.Tipo: ARCO las flechas, BALLESTA los virotes).
@export var arma: int = WeaponData.Tipo.ARCO
# Lo que SUMA al daño del disparo, en fraccion (0.08 = +8%). Va por metal: cobre +8% ... acero espejo +45%.
@export var dano_bonus: float = 0.08
# Lo que AGUANTA sin romperse al clavarse: contra la dureza del enemigo o del suelo (ver la memoria). Va
# por metal, de 1 (cobre) a 6 (acero espejo).
@export var dureza: float = 1.0

# --- SE ROMPE AL CLAVARSE? (diseño 02/10) ---
# 40% de base, +10% por cada punto que lo que recibe sea mas DURO que la flecha (y -10% por cada punto que sea
# mas blando), entre 5% y 95%. La calidad lo multiplica, y lo que destroza flechas (fuego, veneno) suma lo suyo
# aparte: p = 1 - (1 - p)(1 - rompe).
const ROMPER_BASE := 0.4
const ROMPER_POR_PUNTO := 0.1
const ROMPER_MIN := 0.05
const ROMPER_MAX := 0.95
const ROMPER_CALIDAD := {
	MaterialItem.Calidad.PURO: 0.5, MaterialItem.Calidad.INTACTO: 0.7, MaterialItem.Calidad.NORMAL: 1.0,
	MaterialItem.Calidad.DANADO: 1.3, MaterialItem.Calidad.ROTO: 1.3,
}

func prob_romper(cal: int, dureza_blanco: float, rompe: float = 0.0) -> float:
	var p: float = clampf(ROMPER_BASE + ROMPER_POR_PUNTO * (dureza_blanco - dureza), ROMPER_MIN, ROMPER_MAX)
	p = clampf(p * float(ROMPER_CALIDAD.get(cal, 1.0)), 0.0, 1.0)
	return 1.0 - (1.0 - p) * (1.0 - clampf(rompe, 0.0, 1.0))

# LO DURO QUE ES EL SUELO de cada piso para lo que cae en el: el de arriba es tierra, el de las simas piedra.
static func dureza_suelo(piso: int) -> float:
	if piso <= 6:
		return 2.0
	if piso <= 12:
		return 4.0
	return 6.0
