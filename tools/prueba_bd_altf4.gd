# UN ALT+F4 NO SE LLEVA LA PARTIDA (BD fase 1; etapa 4, 27/10: con la sala). Tu personaje lo guarda la sala de tu
# ranura: cada SEG_AUTOGUARDADO_RANURA te pide la ficha y la escribe (Mundos._process -> Net.partida.recoger_estados).
# Como jugador con su sala (tools/prueba_con_jugador.gd, ranura 79): cambio el dinero, espero a que pase un autoguardado
# de la sala y corto la conexion A LO BRUTO (Net.desconectar, sin pedir guardado: como un alt+F4 o un cuelgue). La
# sala se cierra sola y lo que queda en la ranura tiene que llevar el dinero cambiado.
#   godot --headless --path . res://tools/prueba_bd_altf4.tscn -- nube_local
extends Node

const SLOT := 79
const DINERO := 424242

var j = null   # el jugador con su sala: tools/prueba_con_jugador.gd

var _mal: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_bd_altf4", SLOT, 0):
		_ver(false, "arranca la sala y entro al pueblo")
		await _fin()
		return
	Game.money = DINERO
	print("Dinero puesto a %d; esperando al autoguardado de la sala (cada %.0f s)..." % [
		DINERO, Mundos.SEG_AUTOGUARDADO_RANURA])
	# Un autoguardado entero, con su recogida de fichas (Net.partida._PLAZO_ESTADOS) y holgura.
	await get_tree().create_timer(Mundos.SEG_AUTOGUARDADO_RANURA + 5.0).timeout
	print("Corte a lo bruto.")
	Net.desconectar()
	var t := 0.0
	while j._p_sala > 0 and OS.is_process_running(j._p_sala) and t < 30.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	_ver(not OS.is_process_running(j._p_sala), "la sala se cierra sola al quedarse vacia")
	var d: SaveData = Perfil._inspeccionar_bd(SLOT, BDFilas.Ids.new()).get("datos")
	var jd = d.jugadores.get(Identidad.id) if d != null else null
	_ver(jd is JugadorData, "la ranura se puede leer y lleva mi ficha")
	if jd is JugadorData:
		_ver(int(jd.dinero) == DINERO, "el dinero cambiado sigue ahi tras el alt+F4 (%d)" % int(jd.dinero))
	await _fin()


func _fin() -> void:
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	await j.cerrar()
	get_tree().quit(1 if _mal > 0 else 0)
