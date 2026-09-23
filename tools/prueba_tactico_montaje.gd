# ============================================================
#  PRUEBA: LA PANTALLA DE COMBATE SE MONTA EN MODO TACTICO
#  Monta la pelea de prueba (la de F6: el caso peor, 4 contra 5) con tactico = true y comprueba sin
#  ventana que la puesta en escena del MAPA se arma entera y sin reventar:
#    1) se monta y sobrevive a varios fotogramas de ATB (es donde saltaria un metodo que falta);
#    2) NO hay fondo opaco: debajo tiene que verse la mazmorra;
#    3) las bandas de tarjetas quedan ocultas;
#    4) TODAS las fichas se han mudado a la capa suelta (ninguna se queda en su banda);
#    5) a las fichas mudadas se les ha quitado el hueco del sprite;
#    6) lo que es HUD se conserva: barra de acciones, linea de tiempo y registro;
#    7) los bloques siguen intactos y en el mismo orden que _enemies -- de eso dependen el log,
#       la numeracion y los codigos de la red.
#  Y de paso monta la MISMA pelea en modo fila, para que se vea que la de siempre no cambia.
#
#    godot --headless --path . res://tools/prueba_tactico_montaje.tscn
# ============================================================
extends Node

const ESCENA := "res://scenes/ui/combat.tscn"

var _fallos: int = 0
var _errores: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _probar(true)
	await _probar(false)
	print("[tactico] RESULTADO: %s (%d fallos)"
		% ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)


func _probar(tactico: bool) -> void:
	var quien: String = "TACTICO" if tactico else "FILA"
	var escena: PackedScene = load(ESCENA)
	if escena == null:
		_fallo("no se pudo cargar %s" % ESCENA)
		return
	var pelea: Node = escena.instantiate()
	pelea.process_mode = Node.PROCESS_MODE_ALWAYS
	pelea.tactico = tactico
	# Sin setup(): asi entra por el camino de los combatientes de PRUEBA (4 contra 5), que es el caso
	# peor y el que mas aprieta el montaje.
	add_child(pelea)
	# 1) Varios fotogramas: el montaje es en _ready, pero el ATB y el seguimiento de las fichas
	#    corren en _process y es ahi donde saltaria una llamada a un metodo que no existe.
	for i in 8:
		await get_tree().process_frame

	if tactico:
		_afirmar(_sin_fondo(pelea), "%s: hay un fondo opaco tapando la mazmorra" % quien)
		_afirmar(not pelea._bloques_box.visible,
			"%s: la banda de enemigos tendria que estar oculta" % quien)
		var capa: Control = pelea.figuras_mapa._capa
		_afirmar(is_instance_valid(capa), "%s: no se creo la capa de fichas del mapa" % quien)
		# 4) y 5) Las de los ENEMIGOS, todas mudadas y sin hueco de sprite. Las de los tuyos NO se
		#    mudan: sus barras se leen arriba, en la fila del grupo (ver combat_figuras_mapa.montar).
		var mudadas: int = 0
		for b in pelea._bloques:
			var col: Control = b.get("columna")
			if is_instance_valid(col) and col.get_parent() == capa:
				mudadas += 1
			var hueco: Control = b.get("actor_wrap")
			if is_instance_valid(hueco) and hueco.visible:
				_fallo("%s: una ficha conserva el hueco del sprite" % quien)
		_afirmar(mudadas == pelea._bloques.size(),
			"%s: se mudaron %d fichas de %d" % [quien, mudadas, pelea._bloques.size()])
		for b in pelea._bloques_aliados:
			var col: Control = b.get("columna")
			if is_instance_valid(col) and col.get_parent() == capa:
				_fallo("%s: una ficha de aliado se ha mudado al tablero" % quien)
	else:
		_afirmar(not _sin_fondo(pelea), "%s: falta el fondo opaco de siempre" % quien)
		_afirmar(pelea._bloques_box.visible, "%s: la banda de enemigos tendria que verse" % quien)

	# 6) EL HUD, en los dos modos: es lo que se reutiliza tal cual.
	_afirmar(is_instance_valid(pelea._actions_box) and pelea._action_buttons.size() == 6,
		"%s: falta la barra de acciones" % quien)
	_afirmar(is_instance_valid(pelea._timeline), "%s: falta la linea de tiempo" % quien)
	_afirmar(is_instance_valid(pelea.montaje._log_caja), "%s: falta el registro" % quien)

	# 7) LOS BLOQUES, intactos y en orden: el log numera por el indice de _enemies y la red manda
	#    esos mismos indices.
	_afirmar(pelea._bloques.size() == pelea._enemies.size(),
		"%s: %d bloques para %d enemigos" % [quien, pelea._bloques.size(), pelea._enemies.size()])
	_afirmar(pelea._bloques_aliados.size() == pelea._aliados.size(),
		"%s: %d bloques de aliado para %d aliados"
		% [quien, pelea._bloques_aliados.size(), pelea._aliados.size()])

	pelea.queue_free()
	await get_tree().process_frame


# ¿Hay un ColorRect opaco a pantalla completa colgando de la pelea? Es lo que pinta _anadir_fondo, y
# en tactico no puede estar.
func _sin_fondo(pelea: Node) -> bool:
	for h in pelea.get_children():
		if h is ColorRect and (h as ColorRect).color.a > 0.9:
			return false
	return true


func _afirmar(ok: bool, mensaje: String) -> void:
	if not ok:
		_fallo(mensaje)


func _fallo(mensaje: String) -> void:
	_fallos += 1
	print("[tactico] FALLO  %s" % mensaje)
