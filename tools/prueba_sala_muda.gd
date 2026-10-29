# PRUEBA (29/10, "Steam colgado"): LOS PLAZOS DE LA ENTRADA y su reintento (Net.fase_entrada). Ninguna espera de la
# entrada se queda para siempre: vence, se dice, se reintenta UNA vez sola y, si tampoco, se dice que no se ha podido.
#   A) nadie escucha en el puerto: se atasca "conectando" (por el plazo o porque ENet se rinde antes), dos veces.
#   B) una SALA MUDA (ENet que acepta la conexion y no contesta nunca, como una sala colgada o de otro build): conecta,
#      se atasca en el "saludo", reintenta (la sala ve llegar DOS conexiones) y se rinde.
# Un solo proceso, sin ventana:
#   <godot> --headless --path . res://tools/prueba_sala_muda.tscn
extends Node

const PUERTO_NADIE := 24620
const PUERTO_MUDA := 24621

var fallos := 0
var _avisos: Array[String] = []
var _muda: ENetConnection = null
var _llegadas_muda := 0


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  FALLO ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.estado_cambiado.connect(func(t: String): _avisos.append(t))
	call_deferred("_correr")


# La sala muda: ENet a pelo, sin MultiplayerAPI. Acepta a quien llegue y no le dice nada.
func _process(_delta: float) -> void:
	if _muda == null:
		return
	var ev: Array = _muda.service()
	while not ev.is_empty() and int(ev[0]) != ENetConnection.EVENT_NONE:
		if int(ev[0]) == ENetConnection.EVENT_CONNECT:
			_llegadas_muda += 1
		ev = _muda.service()


# Espera a que la entrada acabe del todo: dos atascos (el primero y el del reintento) y sin sesion.
func _hasta_rendirse(tope: float) -> float:
	var t0 := Time.get_ticks_msec()
	while (Net.entradas_atascadas < 2 or Net.activo) and Time.get_ticks_msec() - t0 < int(tope * 1000.0):
		await get_tree().process_frame
	return (Time.get_ticks_msec() - t0) / 1000.0


func _caso(nombre: String, puerto: int, fase: String, tope: float) -> void:
	print("--- %s" % nombre)
	_avisos.clear()
	Net.entradas_atascadas = 0
	ok(Net.unirse("127.0.0.1", "codigo", puerto, true) == OK, "empiezo a entrar")
	var t: float = await _hasta_rendirse(tope)
	print("    avisos: %s" % str(_avisos))
	ok(Net.entradas_atascadas == 2, "se atasca dos veces: la entrada y su UNICO reintento (%d)" % Net.entradas_atascadas)
	ok(not Net.activo, "y se rinde: sin sesion (%.1f s)" % t)
	ok(t < tope, "sin quedarse esperando para siempre (%.1f s de %.0f)" % [t, tope])
	var segundo := _avisos.filter(func(a: String): return a.contains("Segundo intento"))
	var final := _avisos.filter(func(a: String): return a.contains("vuelve a intentarlo"))
	ok(segundo.size() == 1, "dice que lo reintenta, una vez")
	ok(final.size() == 1 and _avisos.find(final[0]) > _avisos.find(segundo[0]) if not segundo.is_empty() else false,
		"y al final, que no se ha podido")
	ok(Net._fase_entrada == "", "no queda ninguna fase en marcha")
	# UN PLAZO VIEJO no puede cortar nada: en B el de "conectando" del reintento (15 s desde que empezo) sigue en marcha
	# cuando el saludo ya se ha rendido. Se le deja vencer y no tiene que saltar.
	var antes: int = Net.entradas_atascadas
	await get_tree().create_timer(maxf(1.0, 16.0 - t / 2.0), true).timeout
	ok(Net.entradas_atascadas == antes, "ningun plazo viejo salta despues")
	ok(fase == "conectando" or _avisos.any(func(a: String): return a.contains("no contesta")), "dice que la sala no contesta")


func _correr() -> void:
	# A) nadie escucha.
	await _caso("A) nadie escucha", PUERTO_NADIE, "conectando", 45.0)
	# B) la sala muda.
	_muda = ENetConnection.new()
	ok(_muda.create_host_bound("127.0.0.1", PUERTO_MUDA, 8) == OK, "la sala muda escucha")
	await _caso("B) sala muda", PUERTO_MUDA, "saludo", 30.0)
	ok(_llegadas_muda == 2, "a la sala muda le llegan dos conexiones: la entrada y el reintento (%d)" % _llegadas_muda)
	_muda.destroy()
	_muda = null
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
