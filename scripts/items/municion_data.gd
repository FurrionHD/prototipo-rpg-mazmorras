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
