# ============================================================
#  tool_data.gd
#  HERRAMIENTA de recoleccion: el PICO (minerales), la HOZ (plantas) y el HACHA (madera).
#  Un .tres por TIPO: son PLANTILLAS, no piezas. La pieza de verdad la hace el herrero
#  (Game.fabricar_herramienta -> crear_item), y su identidad —tier, rareza y BANDA del metal—
#  vive en item_meta, igual que en las armas y la mochila.
#
#  NO son armas: no ocupan mano, no pesan y no entran en el loadout de combate. Viven en
#  sus propios slots (Game.equipped_pico / equipped_hoz / equipped_hacha). Una herramienta
#  mejor NO te entrena mas rapido: solo hace el minijuego MENOS hostil y te deja sacar mas
#  material por rato. Quien pica bien sigue siendo la Fuerza; quien corta fino, la Destreza; quien
#  lleva el compas, la Agilidad. Asi el equipo ayuda pero no sustituye al personaje.
#
#  Como se consigue eso: la afinidad entra en la dificultad, y esa dificultad paga TAMBIEN la
#  excelia (Game.start_*). Suena a que la herramienta te penaliza el entrenamiento, y no: como
#  ademas quita golpes, el nodo paga menos pero cuesta menos, y la excelia POR GOLPE DADO sale
#  plana. Cuando la excelia se medía sin la herramienta, lo que pasaba era lo contrario — un +50%
#  de entrenamiento gratis por llevarla puesta.
#
#  AQUI NO HAY NUMEROS DE DIFICULTAD, y es a proposito. Los tuvo (ventana_bonus, control, filo,
#  compas, golpes_menos, cortes_menos, hachazos_menos) y se borraron el 29/07 por dos razones:
#    1) Estaban TODOS a cero en los tres .tres: no hacian nada, eran un sistema muerto.
#    2) Se sumaban al ancho YA calculado del minijuego, y eso escalaba al reves: como el ancho se
#       estrecha con la exigencia del material, un +0.08 plano valia +31% en madera comun y +95%
#       en anillada. Un hacha T1 ayudaba MAS en el material T3 que en el suyo.
#  Lo que aporta una herramienta sale ahora de Upgrades.tool_mods(tipo, tier, rareza, banda), que
#  baja la DIFICULTAD del minijuego en vez de ensanchar su ventana. Ver el bloque de
#  TOOL_AFINIDAD_TIER en upgrades.gd para el porque completo.
#
#  HACHA va el ULTIMO a proposito: el enum se guarda como numero en los .tres.
# ============================================================

extends Resource
class_name ToolData

enum Tipo { PICO, HOZ, HACHA }

@export var tipo: Tipo = Tipo.PICO
@export var nombre: String = "Herramienta"
@export var descripcion: String = ""
# Informativo de la PLANTILLA (todas son T1: son el punto de partida). El tier REAL de una
# herramienta forjada lo pone el metal con el que se hizo y vive en su item_meta, asi que ningun
# calculo de juego debe leer este campo — lee la meta.
@export var tier: int = 1
@export var valor_base: int = 40


func es_pico() -> bool:
	return tipo == Tipo.PICO

func es_hoz() -> bool:
	return tipo == Tipo.HOZ

func es_hacha() -> bool:
	return tipo == Tipo.HACHA


func tipo_texto() -> String:
	match tipo:
		Tipo.PICO: return "Pico"
		Tipo.HOZ: return "Hoz"
		_: return "Hacha"


# Como se llama lo que ESTA herramienta te ahorra, en el idioma de su minijuego. Lo usa la ficha
# (MenuScaffold.filas_herramienta): "-2 hachazos" se entiende y "-2 golpes" en un hacha, no.
func unidad_golpes(n: int) -> String:
	match tipo:
		Tipo.PICO: return "golpe" if n == 1 else "golpes"
		Tipo.HOZ: return "tallo" if n == 1 else "tallos"
		_: return "hachazo" if n == 1 else "hachazos"
