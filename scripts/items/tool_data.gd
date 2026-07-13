# ============================================================
#  tool_data.gd
#  HERRAMIENTA de recoleccion: el PICO (minerales) y la HOZ (plantas). Un .tres por
#  herramienta; la tienda vendra a vender las buenas.
#
#  NO son armas: no ocupan mano, no pesan y no entran en el loadout de combate. Viven en
#  sus propios slots (Game.equipped_pico / equipped_hoz). Una herramienta mejor NO sube la
#  stat: solo hace el minijuego MENOS hostil. Quien pica bien sigue siendo la Fuerza; quien
#  corta fino sigue siendo la Destreza. Asi el equipo ayuda pero no sustituye al personaje.
#
#  Cada tipo usa SUS campos (los del otro se ignoran): son dos minijuegos distintos.
# ============================================================

extends Resource
class_name ToolData

enum Tipo { PICO, HOZ }

@export var tipo: Tipo = Tipo.PICO
@export var nombre: String = "Herramienta"
@export var descripcion: String = ""
@export var tier: int = 1
@export var valor_base: int = 40

# --- PICO (minijuego de mineria) ---
# Ensancha la franja de golpe optimo (mas margen para soltar en el punto justo).
@export var ventana_bonus: float = 0.0
# Frena la barra de carga: un pico bien equilibrado se controla mejor.
@export var control: float = 0.0
# Golpes que te ahorras para romper la veta.
@export var golpes_menos: int = 0

# --- HOZ (minijuego de herboristeria) ---
# Ensancha el NUCLEO del corte (la franja del corte limpio).
@export var filo: float = 0.0
# Tallos que te ahorras cortar.
@export var cortes_menos: int = 0


func es_pico() -> bool:
	return tipo == Tipo.PICO


# Los numeros van aqui, nunca en la descripcion.
func resumen() -> String:
	var partes: PackedStringArray = ["%s T%d" % ["Pico" if es_pico() else "Hoz", tier]]
	if es_pico():
		if ventana_bonus > 0.0:
			partes.append("+%d%% de margen al golpear" % roundi(ventana_bonus * 100.0))
		if control > 0.0:
			partes.append("carga %.2f más lenta (más control)" % control)
		if golpes_menos > 0:
			partes.append("-%d golpes" % golpes_menos)
	else:
		if filo > 0.0:
			partes.append("+%d%% de corte limpio" % roundi(filo * 100.0))
		if cortes_menos > 0:
			partes.append("-%d tallos" % cortes_menos)
	if partes.size() == 1:
		partes.append("sin mejoras: la herramienta de siempre")
	return "  ·  ".join(partes)
