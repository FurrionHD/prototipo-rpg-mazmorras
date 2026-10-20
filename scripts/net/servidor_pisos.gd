# ============================================================
#  servidor_pisos.gd  --  LOS PISOS DEL SERVIDOR (fase 2 del plan de optimizacion, etapa 2)
# ============================================================
# El servidor (la sala) lleva TODOS los pisos con gente, a la vez y en el mismo programa, como un cooperativo de verdad
# (Valheim, Terraria): hasta ahora cada piso era un Godot aparte (un trabajador), que es diseño de MMO y solo traia
# saltos de red, memoria y fallos con carga.
#
# Cada piso va en su SubViewport con SU PROPIO MUNDO de fisica (un World2D suyo): los choques y los rayos de un piso no
# ven los del otro sin tocar nada de la fisica. No se dibuja (el servidor no pinta). La raiz del piso es su PisoVivo,
# con su numero, su lugar ("piso:N") y el servidor como dueño: todo lo que lleva dentro pregunta por EL (etapa 1).
#
# Se monta SIN el jugador de main.tscn: el servidor no juega. Los jugadores son sus cuerpos de red, que entran en el
# piso donde esta cada uno.
#
#   montar(piso_red, numero_juego, foto)  -> el PisoVivo (si ya estaba, el mismo)
#   desmontar(piso_red)                   -> su foto, en el formato de Game.memoria_pisos (para congelarlo)
#   piso(piso_red), pisos()
# Prueba: tools/prueba_servidor_dos_pisos.tscn
extends Node

const _MAIN := preload("res://scenes/levels/main.tscn")

# piso_red -> SubViewport (su hijo es el PisoVivo)
var _vistas: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func piso(piso_red: int) -> PisoVivo:
	var vp: SubViewport = _vistas.get(piso_red)
	if vp == null or not is_instance_valid(vp) or vp.get_child_count() == 0:
		return null
	return vp.get_child(0) as PisoVivo


func pisos() -> Array:
	return _vistas.keys()


# 'numero_juego' es el piso que se juega (en la arena, el que imita); 'foto' lo levanta como se quedo (vacia = nuevo).
func montar(piso_red: int, numero_juego: int, foto: Dictionary = {}) -> PisoVivo:
	var ya: PisoVivo = piso(piso_red)
	if ya != null:
		return ya
	PisoVivo.por_piso = true
	# La foto entra por donde entra siempre: dungeon_floor._restaurar_estado la busca en Game.memoria_pisos por su numero
	# de red. Va por clave, asi que no pisa a los demas pisos.
	if not foto.is_empty():
		Game.memoria_pisos[piso_red] = foto
	var vp := SubViewport.new()
	vp.name = "Piso_%d" % piso_red
	vp.world_2d = World2D.new()   # SU mundo: fisica y rayos aparte de los demas pisos
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.size = Vector2i(2, 2)
	var pv: PisoVivo = _MAIN.instantiate() as PisoVivo
	pv.numero_fijo = numero_juego
	pv.lugar_fijo = "piso:%d" % piso_red
	pv.dueno_fijo = 1
	# Sin jugador: el servidor no juega (ver la cabecera).
	var jugador: Node = pv.get_node_or_null("Player")
	if jugador != null:
		pv.remove_child(jugador)
		jugador.free()
	vp.add_child(pv)
	add_child(vp)
	_vistas[piso_red] = vp
	print("[servidor] monto el piso %d (juega como el %d)%s" % [piso_red, numero_juego,
		" desde su foto" if not foto.is_empty() else ""])
	return pv


# Lo congela: saca su foto (lo mismo que guarda un piso al dejarlo) y lo quita. {} si no estaba.
func desmontar(piso_red: int) -> Dictionary:
	var vp: SubViewport = _vistas.get(piso_red)
	if vp == null or not is_instance_valid(vp):
		_vistas.erase(piso_red)
		return {}
	var foto: Dictionary = foto_de(piso_red)   # ANTES de quitarlo de la lista: foto_de lo busca en ella
	_vistas.erase(piso_red)
	remove_child(vp)
	vp.queue_free()
	print("[servidor] desmonto el piso %d" % piso_red)
	return foto


# La foto de un piso montado, sin quitarlo (la que se manda cada rato para no perder nada si se cae el servidor).
func foto_de(piso_red: int) -> Dictionary:
	var pv: PisoVivo = piso(piso_red)
	if pv == null:
		return {}
	var suelo: Node = pv.primero(&"dungeon_floor")
	if suelo != null and suelo.has_method("volcar_a_memoria"):
		suelo.volcar_a_memoria()
	return Game.memoria_pisos.get(piso_red, {})
