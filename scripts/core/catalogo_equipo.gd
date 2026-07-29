# ============================================================
#  catalogo_equipo.gd
#  Las PLANTILLAS base del equipo que existe en el juego: un .tres por arma y por secundaria.
#
#  Vivian dentro de shop_menu.gd, que es donde nacieron. Estan aqui porque ya no son "lo que
#  vende el tendero": el MAESTRO DE HABILIDADES recorre estas mismas plantillas para saber que
#  habilidades trae cada tipo de arma (WeaponData.habilidades). Con la lista duplicada en los dos
#  menus, añadir un arma nueva la dejaba a la venta pero sin habilidades que aprender, o al reves.
#
#  Son las plantillas BASE (T1/comun): el tier y la rareza no viven en el .tres, los pone la
#  compra o la forja (ver Game.crear_item). Las habilidades SI son del .tres base, asi que valen
#  igual para un arma T1 comun que para una T3 legendaria.
# ============================================================

extends RefCounted
class_name CatalogoEquipo

const ARMAS: Array[String] = [
	"res://resources/weapons/daga.tres",
	"res://resources/weapons/estoque.tres",
	"res://resources/weapons/espada_corta.tres",
	"res://resources/weapons/espada_larga.tres",
	"res://resources/weapons/maza_peq.tres",
	"res://resources/weapons/mandobles.tres",
	"res://resources/weapons/hacha_grande.tres",
	"res://resources/weapons/martillo_grande.tres",
	"res://resources/weapons/baston.tres",
]

const SECUNDARIAS: Array[String] = [
	"res://resources/shields/escudo_pequeno.tres",
	"res://resources/shields/escudo_normal.tres",
	"res://resources/shields/escudo_grande.tres",
	"res://resources/wands/varita.tres",
]
