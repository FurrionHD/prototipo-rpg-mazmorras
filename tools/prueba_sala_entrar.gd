# PRUEBA (fase 3, F3.3): EL BOTON "ENTRAR" de verdad, desde el juego del jugador.
#   1. Crea un mundo (Mundos.alta_propio) y entra (Mundos.entrar): se lanza la sala, la sala lo estrena
#      VACIO y a mi me pide el personaje, como a cualquiera que entra por primera vez.
#   2. Me voy (como "Guardar y salir") y vuelvo a entrar ENSEGUIDA: la sala sigue viva y me reconecto a la
#      MISMA, sin lanzar otra, y soy el mismo personaje.
#   3. Me voy y espero: la sala se cierra sola y el save guarda mi personaje a mi nombre.
# Se lanza con:  <godot> --headless --path . res://tools/prueba_sala_entrar.tscn -- nube_local sala_vacia=4
extends Node

const Sala = preload("res://scripts/net/sala.gd")

var fallos := 0
var _dentro := false


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  FALLO ") + t)
	if not c:
		fallos += 1


func _esperar_a(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	return cond.call()


func _salir() -> void:
	await Ventana.pedir_guardado_al_anfitrion()
	await get_tree().create_timer(0.3).timeout
	Net.desconectar()
	_dentro = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Con el almacen local, o con el `wrangler dev` de servidor/nube (nube_url=http://127.0.0.1:8787).
	if Nube.es_remota() and not String(Nube.almacen.url).contains("127.0.0.1"):
		print("Esta prueba tiene que ir con `-- nube_local` (si no, escribe en la nube de verdad).")
		get_tree().quit(1)
		return
	# Lo que hace el menu: al pedir personaje, se hace uno; al tenerlo, se entra.
	Net.partida.pedir_personaje.connect(func(_n: String):
		var pj := PersonajeData.new()
		pj.nombre = "Estrena"
		Game.asegurar_uid(pj)
		Net.partida.mandar_alta_personaje(pj))
	Net.partida.entrada_lista.connect(func(): _dentro = true)

	# --- 1. Mundo nuevo y entrar ---
	var r: Dictionary = await Mundos.alta_propio("prueba entrar", "clave")
	ok(r.get("ok", false), "mundo dado de alta")
	var clave: String = String(r.get("clave", ""))
	r = await Mundos.entrar(clave, "clave")
	ok(r.get("ok", false) and r.get("direccion") == "127.0.0.1", "entrar lanza la sala y conecta: %s" % str(r))
	var hay_red: bool = not Nube.direcciones_locales().is_empty() or Identidad.direccion_preferida != ""
	ok(not hay_red or not (r.get("direcciones", []) as Array).is_empty(),
		"y me dice las direcciones que ha publicado la sala: %s" % str(r.get("direcciones", [])))
	ok(await _esperar_a(func(): return _dentro, 60.0), "me piden personaje y entro")
	ok(Game.lider().nombre == "Estrena" and Mundos.abierto == "", "soy Estrena y el mundo NO lo tengo abierto yo")
	var pid1: int = int(Sala.leer_estado(clave).get("pid", 0))
	ok(pid1 > 0 and OS.is_process_running(pid1), "la sala es otro proceso (pid %d)" % pid1)

	# --- 2. Salir y volver enseguida: la MISMA sala ---
	await _salir()
	r = await Mundos.entrar(clave, "clave")
	ok(r.get("ok", false), "vuelvo a entrar")
	ok(await _esperar_a(func(): return _dentro, 30.0), "y estoy dentro")
	ok(int(Sala.leer_estado(clave).get("pid", 0)) == pid1, "es la misma sala, no otra")
	ok(Game.lider().nombre == "Estrena", "con el mismo personaje")

	# --- 3. Salir y dejar que se cierre ---
	await _salir()
	ok(await _esperar_a(func(): return not OS.is_process_running(pid1), 40.0), "sin nadie, la sala se cierra sola")
	ok(Mundos.sala_en_este_pc(clave).is_empty(), "y ya no sale como abierta en este PC")
	var d: SaveData = SaveIO.inspeccionar_ruta(Mundos.ruta(clave)).get("datos") as SaveData
	var jd = d.jugadores.get(Identidad.id) if d != null else null
	ok(jd is JugadorData and ((jd as JugadorData).personajes[0] as PersonajeData).nombre == "Estrena"
		and d.jugadores.size() == 1, "el save guarda a Estrena a mi nombre, y a nadie mas")
	var e: Dictionary = await Nube.consultar(clave, "clave")
	ok(e.get("ok", false) and not e.get("abierto", true) and e.get("tiene_save", false), "subido y con el cerrojo suelto")
	Mundos.borrar(clave)
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
