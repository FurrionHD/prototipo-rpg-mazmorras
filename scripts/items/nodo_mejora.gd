# ============================================================
#  nodo_mejora.gd
#  UN NODO DEL ARBOL de una habilidad o una magia (22/11, memoria rangos-magias-y-habilidades). Arboles como los de
#  Diablo 4: la habilidad tal como la aprendes arriba y, debajo, 5-7 nodos que la van MODIFICANDO (mas alcance, mas
#  angulo, mas efecto, un efecto por otro...). TODOS dan algo de daño ademas de lo suyo (lo decidio el jefe).
#
#  Va DENTRO de la ficha de la habilidad (AbilityData.arbol / SpellData.arbol), como datos: el arbol se diseña y se
#  ajusta en su .tres, sin tocar codigo (memoria balance-en-la-ficha-no-en-codigo).
#
#  SIN class_name a proposito: uno nuevo no esta en la cache de clases hasta que se abre el editor y las pruebas se
#  lanzan por linea de comandos (memoria class-name-nuevo-pide-import). Quien lo necesite lo carga por preload.
# ============================================================
extends Resource

# El nombre corto del nodo, UNICO dentro de su arbol. Viaja en el nombre de la habilidad montada (ver Mejoras), asi
# que solo letras, numeros y '_' (sin puntos, comas ni '#').
@export var id: StringName = &""
@export var nombre: String = ""
@export_multiline var descripcion: String = ""

# DE QUIEN CUELGA. Vacio = cuelga de la habilidad (la primera fila). Con varios, basta con tener UNO de ellos: asi
# dos ramas se JUNTAN en un nodo (lo pidio asi el jefe: "con pillar una de las dos ya te vale").
@export var padres: Array[StringName] = []
# Los que se excluyen entre si: si tienes uno de estos, este no se puede coger (elegir una rama cierra la otra).
@export var excluye: Array[StringName] = []

# LO QUE PIDE: nivel del personaje, dominio de ESTA habilidad (veces usada) y oro.
@export var nivel_min: int = 1
@export var dominio: int = 0
@export var oro: int = 0

# LO QUE CAMBIA. Cada entrada es campo de la ficha -> [operacion, valor]:
#   "mult" multiplica (dano_mult x1.15), "add" suma (forma_radio +20), "set" pone (imbue_estado = otro estado).
# Los campos son los @export de AbilityData / SpellData; uno que no exista se avisa y se ignora (ver Mejoras).
@export var cambios: Dictionary = {}
