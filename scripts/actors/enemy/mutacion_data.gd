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
# (06/10, los mutantes del slime venenoso: miasma y pestilente)
# REVIENTA AL MORIR: deja en su sitio el charco/nube de esta habilidad (su forma de circulo, sus turnos, sus estados).
@export var revienta_al_morir: AbilityData = null
# ACIDO EN LA PIEL: al recibir un golpe CUERPO A CUERPO, 'acido_prob' de meterle 'acido_efectos' al que le pega (el
# acido le come el arma: Debil).
@export var acido_piel: bool = false
@export var acido_prob: float = 0.3
@export var acido_efectos: Array = []
# LO QUE LE SALE AL AZAR POR EL CUERPO (HumoToxico): 0 = nada, 1 = bocanadas de humo a ratos (el miasma), 2 = burbujas
# que se hinchan, revientan y sueltan el humo (el pestilente).
@export var humo: int = 0
# (06/10, los mutantes del slime de fuego)
# SU PASIVA AL SER GOLPEADO, si cambia la de su enemigo: la ceniza suelta ceniza (Rescoldo) en vez de quemar; la
# obsidiana no lleva ninguna (lista vacia con 'al_ser_golpeado_propio').
@export var al_ser_golpeado_propio: bool = false
@export var al_ser_golpeado: Array = []
@export var al_ser_golpeado_prob: float = 0.0
@export var al_ser_golpeado_texto: String = ""
@export var al_ser_golpeado_fx: int = -1
# SU ELEMENTO, si cambia (-1 = el de su enemigo): la obsidiana pierde el fuego (0 = ninguno).
@export var elemento: int = -1
# Sus RESISTENCIAS elementales a medida (vacio = las de su enemigo): la obsidiana, {Rayo: 0,8, Agua: 0,8}.
@export var resist_elemental: Dictionary = {}
# FRAGIL A CONTUNDENTES (1 = no) y DEVOLVER CORTES (la obsidiana: 1,3; 20 % de devolver la mitad).
@export var fragil_contundente: float = 1.0
@export var devuelve_corte_prob: float = 0.0
@export var devuelve_corte_frac: float = 0.5
# EL COLOR DE SUS EFECTOS (el charco, las salpicaduras...), si no es el de su enemigo (alfa 0 = el suyo): la ceniza en
# gris ceniza, la obsidiana en negro.
@export var color_fx: Color = Color(0, 0, 0, 0)
# (06/10, los mutantes del slime ABISAL)
# DEJA ESTRELLAS: al moverse en la pelea deja una ESTRELLA donde estaba. No explotan ni hacen nada solas: son las piezas
# de sus ataques (la Constelacion las une con rayos; la Mirada estelar dispara desde cada una). Como mucho
# 'estrellas_max' (la mas vieja se apaga); duran la pelea.
@export var deja_estrellas: bool = false
@export var estrellas_max: int = 6
# TODO LO VE (el de mil ojos): no se le embosca (sin iniciativa contra el), el sigilo no le engaña (ni en el mapa ni en la
# pelea), ve en redondo y apunta mejor (+precision_extra).
@export var todo_lo_ve: bool = false
@export var precision_extra: float = 0.15
