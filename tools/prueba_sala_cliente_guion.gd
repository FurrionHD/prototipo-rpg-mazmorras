# Guion de un jugador de la prueba de la sala (ver prueba_sala_dos_jugadores.gd).
#   A: la dueña. Tiene personaje en el mundo. Entra, acepta a B cuando la sala se lo pregunta, echa 30 al
#      bote y "cierra el juego" (guarda por el camino del invitado y se va).
#   B: nuevo. Espera a que le acepten, se hace a Berto, espera a quedarse solo, saca 10 del bote y se va.
extends Node

const PASO := 0.25

var rol := ""
var fallos := 0
var _entrado := false


func ok(c: bool, t: String) -> void:
	print("[%s] %s %s" % [rol, "OK   " if c else "FALLO", t])
	if not c:
		fallos += 1


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


# Espera a que se cumpla algo, con tope. Devuelve si se cumplio.
func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(PASO)
		t += PASO
	return cond.call()


func _boton(texto: String) -> Button:
	for n in get_tree().root.find_children("*", "Button", true, false):
		if (n as Button).text == texto and n.is_visible_in_tree():
			return n
	return null


func _acabar() -> void:
	print("[%s] %s" % [rol, "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos])
	get_tree().quit(0 if fallos == 0 else 1)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("cliente_sala")
	var puerto := int(args[i + 1])
	var clave_sala: String = args[i + 2]
	Identidad.id = args[i + 3]   # solo en memoria: cada proceso es otra persona
	rol = args[i + 4]
	Identidad.nombre = "Ana" if rol == "A" else "Berto"
	# Como hace el menu de multijugador: al tener personaje, al pueblo y anunciar el lugar.
	Net.partida.entrada_lista.connect(func():
		var arbol := get_tree()
		arbol.change_scene_to_file("res://scenes/levels/town.tscn")
		await arbol.process_frame
		Net.anunciar_lugar("pueblo")
		_entrado = true)
	# B: el mundo no le conoce y le pide personaje (cuando le hayan dejado pasar).
	Net.partida.pedir_personaje.connect(func(_n: String):
		var pj := PersonajeData.new()
		pj.nombre = "Berto"
		Game.asegurar_uid(pj)
		Net.partida.mandar_alta_personaje(pj))
	await _esperar(0.5)
	ok(Net.unirse("127.0.0.1", clave_sala, puerto, true) == OK, "me conecto a la sala")
	ok(await _hasta(func(): return _entrado, 60.0), "entro en el mundo")
	await _esperar(1.0)
	if rol == "A":
		await _guion_a()
	else:
		await _guion_b()
	_acabar()


func _guion_a() -> void:
	ok(Game.money == 100 and Game.lider().nombre == "Ana", "soy Ana, con mis 100 monedas (%d)" % Game.money)
	ok(Net._num_humanos == 1, "la sala no cuenta como jugador: somos %d" % Net._num_humanos)
	ok(not Net._avatares.has(1), "la sala no tiene cuerpo en el pueblo")
	# Llega B: la sala me pregunta a MI si le dejo entrar.
	ok(await _hasta(func(): return _boton("Aceptar") != null, 60.0), "me preguntan si dejo entrar a alguien")
	var b := _boton("Aceptar")
	if b != null:
		b.pressed.emit()
	ok(await _hasta(func(): return Net._num_humanos == 2, 60.0), "B ya esta dentro: somos %d" % Net._num_humanos)
	await _esperar(1.0)
	ok(Net.formacion.num_jugador(Identidad.id) == 1, "soy el P1 (la sala no ocupa numero)")
	ok(Net.hogar.depositar_bote(30), "echo 30 al bote")
	ok(await _hasta(func(): return Net.hogar.bote_visible() == 30, 10.0), "el bote tiene 30")
	await _esperar(6.0)   # que B tenga tiempo de verme dentro antes de irme
	# "Cierro el juego": guardar por el camino del invitado y fuera. La sala tiene que seguir para B.
	await Ventana.guardar_al_cerrar()
	Net.desconectar()


func _guion_b() -> void:
	ok(Game.lider().nombre == "Berto", "soy Berto, recien hecho")
	ok(await _hasta(func(): return Net._num_humanos == 2, 30.0), "estamos los dos")
	ok(Net.formacion.num_jugador(Identidad.id) == 2, "soy el P2")
	# A se va. Yo sigo dentro y la sala sigue viva.
	ok(await _hasta(func(): return Net._num_humanos == 1, 90.0), "A se ha ido y yo sigo dentro")
	ok(await _hasta(func(): return Net.hogar.bote_visible() == 30, 10.0), "veo los 30 que echo A")
	Net.hogar.retirar_bote(10)
	ok(await _hasta(func(): return Game.money == 10, 10.0), "saco 10 del bote")
	await Ventana.guardar_al_cerrar()
	Net.desconectar()
