# ============================================================
#  mutacion_data.gd  (class_name MutacionData)
#  UNA MUTACION CON NOMBRE de un enemigo (06/10, el arbol del slime normal que pidio el jefe):
#      Slime --muta--> Slime brotado  (se divide al morir)  --come mas--> Slime brotado punzante (las dos pasivas)
#                 \--> Slime punzante (espinas)             --come mas--/
#  Va en EnemyData.mutaciones. Un enemigo SIN arbol sigue con el mutante de siempre ("X mutante", la tabla
#  EnemyData.MUT_*). Los NUMEROS van aqui, en la ficha, y no en el codigo (ver balance-en-la-ficha).
# ============================================================
extends Resource
class_name MutacionData

@export var id: StringName = &""
# Como se llama en la pelea, en el log y en la ficha (no "X mutante").
@export var nombre: String = ""
# 1 = mutante (sale del normal); 2 = la siguiente (sale de una de 1, comiendo mas cristales).
@export var grado: int = 1
# De que mutaciones de grado 1 se llega a esta (solo las de grado 2).
@export var desde: Array[StringName] = []
# Sus ataques. VACIO = los de su enemigo.
@export var habilidades: Array[AbilityData] = []
# La variante de sprite que le toca (la conoce el generador de su familia; vacio = el normal estirado).
@export var sprite: StringName = &""

# --- PASIVAS ---
# Al morir se encoge y salen dos de su enemigo normal; su cadaver se queda.
@export var se_divide: bool = false
# ESPINAS: al recibir un golpe CUERPO A CUERPO, 'espinas_prob' de lanzar puas que hacen 'espinas_dano' de su ataque
# a todos los que le rodean.
@export var espinas: bool = false
@export var espinas_prob: float = 0.3
@export var espinas_dano: float = 0.5
