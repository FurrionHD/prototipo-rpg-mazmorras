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
var traspasados: Array = []         # indices de enemigos que siguen en la pantalla de otro   (Game.enemigos_traspasados)
var cola: Array = []                # enemigos esperando hueco en la pelea llena              (Game._cola_combate)
var arena_nodo: Node = null         # la arena tactica viva                                   (Game._arena_nodo)
var puntos_arena_fichas: Array = [] # donde estan los que pelean, mientras se abre una pelea de fichas (Game._puntos_arena_fichas)
var zona: Dictionary = {}           # la zona anunciada de esta pelea                         (Game._mi_zona)

# --- lo que era de Net.peleas ---
var id: int = 0                     # id en la red (0 = ninguna)                              (_pelea_id)
var participantes: Array = []       # peers dentro (sin contar a quien la ejecuta)            (_pelea_participantes)
var dobles: Dictionary = {}         # peer -> Array[PersonajeData] de sus personajes          (_dobles)
var humano: int = 0                 # el humano que la abrio (el ruido es suyo)               (_pelea_humano)
var t_cierre: float = 0.0           # cuanto lleva acabada sin que nadie pulse Continuar      (_t_cierre)


# ¿Hay una pelea en marcha en esta caja? (lo mismo que Game.combate_activo sin el destrabe)
func en_marcha() -> bool:
	return not enemigos.is_empty()
