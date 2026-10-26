# LA PELEA DE LAS HERRAMIENTAS DE VER (etapa 4, paso 6). En el juego toda pelea la abre la sala (Game.start_combat, el
# camino sin red con el grupo de esta maquina, ya no existe). Las herramientas que solo quieren MIRAR una pantalla de
# pelea (laminas, capturas, ver_*) la abren aqui con el grupo local, por la misma puerta que usa la sala.
#   preload("res://tools/pelea_local.gd").abrir(enemigos)
extends RefCounted


static func abrir(enemigos: Array, embiste: bool = false) -> bool:
	var pjs: Array = [Game.lider()]
	pjs.append_array(Game.companeros())
	return Game._abrir_pelea(enemigos, embiste, pjs)
