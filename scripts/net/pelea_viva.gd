# ============================================================
#  PELEA VIVA: todo lo de UNA pelea que se ejecuta en esta maquina
# ============================================================
# FASE 2, ETAPA 3 DEL PLAN DE OPTIMIZACION (22/10): la sala ejecutara VARIAS peleas a la vez, cada una colgada de su
# PisoVivo. Hasta ahora cada Godot llevaba UNA pelea y su estado vivia suelto en Game (_active_enemies, _active_layer,
# los combatientes del grupo, la cola, la arena...) y en Net.peleas (id, participantes, dobles...). Aqui va junto.
#
# MIENTRAS HAYA UNA SOLA (todos los clientes, y por ahora tambien la sala) Game y Net.peleas leen la suya
# (Game.pelea) con los MISMOS nombres de siempre, que ahora son propiedades que miran aqui: el juego hace lo mismo.
#
# Solo lo del que EJECUTA la pelea. Lo del ESPEJO (Net.peleas._pelea_sigo, _mis_en_pelea...) y las zonas ajenas
# que se pintan en el mapa son del cliente: uno por maquina, se quedan donde estaban.
# Pruebas: tools/unitarias/test_pelea_viva.gd
class_name PeleaViva
extends Node

# --- lo que era de Game ---
var enemigos: Array[Node] = []      # enemigos de la pelea (1..4, en orden de setup)          (Game._active_enemies)
var capa: CanvasLayer = null        # capa donde vive la pantalla de combate                  (Game._active_layer)
var montaje_ms: int = 0             # cuando empezo a montarse (ms); 0 = no se esta montando  (Game._montaje_ms)
var aliados_cs: Array = []          # Combatant del grupo, en el orden de la pantalla         (Game._active_player_cs)
var aliados_pjs: Array = []         # la ficha de cada uno, mismo orden                       (Game._active_player_pjs)
var cola: Array = []                # enemigos esperando hueco en la pelea llena              (Game._cola_combate)
var arena_nodo: Node = null         # la arena tactica viva                                   (Game._arena_nodo)
var puntos_arena_fichas: Array = [] # donde estan los que pelean, mientras se abre una pelea de fichas (Game._puntos_arena_fichas)
var zona: Dictionary = {}           # la zona anunciada de esta pelea                         (Game._mi_zona)
var piso: PisoVivo = null           # el piso donde se pelea (el de sus enemigos); null = el de la maquina

# --- lo que era de Net.peleas ---
var id: int = 0                     # id en la red (0 = ninguna)                              (_pelea_id)
var participantes: Array = []       # peers dentro (sin contar a quien la ejecuta)            (_pelea_participantes)
var dobles: Dictionary = {}         # peer -> Array[PersonajeData] de sus personajes          (_dobles)
var humano: int = 0                 # el humano que la abrio (el ruido es suyo)               (_pelea_humano)
var t_cierre: float = 0.0           # cuanto lleva acabada sin que nadie pulse Continuar      (_t_cierre)
var marca: int = 0                  # base de la marca de sus enemigos en el guardado (0 = aun no se ha guardado)


static var _vivas: Array[PeleaViva] = []


func _enter_tree() -> void:
	if not _vivas.has(self):
		_vivas.append(self)


func _exit_tree() -> void:
	_vivas.erase(self)
	if id != 0 and Net.soy_sala:
		Net.peleas.olvidar_pelea(self)   # se va sin cerrarse (su piso desmontado): que no quede apuntada


# ¿Hay una pelea en marcha en esta caja? (lo mismo que Game.combate_activo sin el destrabe)
func en_marcha() -> bool:
	return not enemigos.is_empty()


# EL SUELO de la pelea (el nodo dungeon_floor de su piso): ahi se monta la arena tactica. Sin piso apuntado (el espejo
# de un cliente), el de la maquina.
func suelo() -> Node:
	if is_instance_valid(piso):
		return piso.primero(&"dungeon_floor")
	return get_tree().get_first_node_in_group("dungeon_floor") if is_inside_tree() else null


# LAS PREGUNTAS "¿DE QUIEN ES ESTO?" no necesitan saber la pelea: un combatiente, una ficha o un enemigo estan en
# UNA sola. Se buscan en todas las vivas (en un cliente, la suya). null = en ninguna.
static func de_combatiente(c) -> PeleaViva:
	if c == null:
		return null
	for p in _vivas:
		if p.aliados_cs.has(c):
			return p
	return null


static func de_ficha(pj) -> PeleaViva:
	if pj == null:
		return null
	for p in _vivas:
		if p.aliados_pjs.has(pj):
			return p
	return null


static func de_enemigo(nodo) -> PeleaViva:
	if nodo == null:
		return null
	for p in _vivas:
		if p.enemigos.has(nodo):
			return p
	return null
