# ============================================================
#  runa_set_data.gd  (class_name RunaSetData)
#  UN SET DE RUNAS (08/10/2026, fase 5 del plan de mecanicas: las runas de los mutantes). Se activa en una pieza en el
#  Taller de runas con 'coste_material' unidades del material de su enemigo normal y 'coste_nucleo' de su nucleo; las
#  'runa' (lo que sueltan sus mutantes) suben, cambian y re-tiran las sub-stats de la pieza. Ver Runas.
#  Los de ARMADURA cuentan con 2 y 5 piezas; los de ARMA con 2 (principal + secundaria; un arma a dos manos cuenta 2).
#  Los NUMEROS van aqui, en la ficha (balance en la ficha), y la descripcion se genera de ellos.
# ============================================================
extends Resource
class_name RunaSetData

enum Tipo { ARMA, ARMADURA }

@export var id: StringName = &""
@export var nombre: String = ""
@export var tipo: Tipo = Tipo.ARMADURA
# Lo que cuesta ACTIVARLO en una pieza (cantidades fijas; la unidad cuenta la calidad, ver Runas.unidades).
@export var material: MaterialData = null
@export var nucleo: MaterialData = null
@export var coste_material: int = 6
@export var coste_nucleo: int = 3
# La runa de su mutante: 1 = subir de nivel, cambiar una sub-stat o re-tirar un valor.
@export var runa: MaterialData = null
# El bonus de 2 piezas: claves de sub-stat de Runas.SUBS -> valor (0.12 = 12 %).
@export var bonus_2p: Dictionary = {}
# El efecto especial (el de 5 piezas en las armaduras, el de 2 en las armas) y sus numeros. Lo interpreta Runas.aplicar.
@export var efecto: StringName = &""
@export var params: Dictionary = {}


func piezas_efecto() -> int:
	return 2 if tipo == Tipo.ARMA else 5
