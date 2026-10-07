# BD FASE 5: LA SALA SE QUEDA SIN NUBE. Con el almacen local (user://nube_test) y un almacen "con cortes"
# que hace de red caida:
#   - un latido sin red NO pierde el mundo (sigue a tu nombre) y PAUSA a todos ("reconectando");
#   - al volver la red se reanuda;
#   - si el arrendamiento caduco mientras no habia red y nadie lo ha cogido, se recoge solo;
#   - si lo ha cogido OTRO, entonces si se ha perdido.
#   godot --headless --path . res://tools/prueba_nube_sin_red.tscn -- nube_local
extends Node

var fallos := 0


class AlmacenConCortes:
	extends RefCounted
	var de_verdad
	var cortado := false

	func _init(a) -> void:
		de_verdad = a

	func latido(id: String, token: int) -> Dictionary:
		if cortado:
			return {"ok": false, "error": "sin_red", "mensaje": "No hay conexión con la nube."}
		return de_verdad.latido(id, token)

	func abrir(id, pass_, dirs, sello, build, forzar := false, quien := "", formato := 0) -> Dictionary:
		if cortado:
			return {"ok": false, "error": "sin_red", "mensaje": "No hay conexión con la nube."}
		return de_verdad.abrir(id, pass_, dirs, sello, build, forzar, quien, formato)


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  MAL: ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_correr")


func _correr() -> void:
	if Nube.es_remota():
		print("Esta prueba va con `-- nube_local`.")
		get_tree().quit(1)
		return
	Nube.latido_automatico = false
	var local = Nube.almacen
	var id: String = Nube.nuevo_id()
	ok((await Nube.crear_mundo(id, "pw")).get("ok", false), "mundo creado")
	ok(String((await Nube.abrir(id, "pw", ["1.2.3.4"])).get("resultado", "")) == "host", "abierto: el mundo es mio")
	# Como si fuera la sala de un mundo (es quien pausa a los demas).
	Net.activo = true
	Net.es_host = true
	Net.mundo_compartido = true
	var cortes := AlmacenConCortes.new(local)
	Nube.almacen = cortes

	print("--- se va la red")
	cortes.cortado = true
	await Nube.latir()
	ok(Nube.estado == Nube.HOST, "sin red el mundo sigue siendo mio (estado %d)" % Nube.estado)
	ok(Nube.sin_red and Net.pausa_red and get_tree().paused, "y se pausa a todos: reconectando")

	print("--- vuelve")
	cortes.cortado = false
	await Nube.latir()
	ok(Nube.estado == Nube.HOST and not Nube.sin_red and not Net.pausa_red and not get_tree().paused, "se reanuda")

	print("--- caduca sin red y nadie lo coge")
	var token_antes: int = Nube._token
	local.desfase_prueba = 300   # pasan cinco minutos: el arrendamiento (120 s) ya ha caducado
	var r: Dictionary = await Nube.latir()
	ok(r.get("ok", false) and Nube.estado == Nube.HOST and Nube._token != token_antes,
		"se recoge solo (token %d -> %d)" % [token_antes, Nube._token])

	print("--- caduca y lo coge OTRO")
	local.desfase_prueba = 600
	# El otro tiene que ser de la casa (miembro), o el mundo ni le deja abrir.
	var m: Dictionary = local._leer_json(local._ruta_mundo(id))
	(m["miembros"] as Array).append("ffffffffffffffffffffffff")
	local._escribir_json(local._ruta_mundo(id), m)
	var otro: Dictionary = local.abrir(id, "pw", [], Nube._sello(), Game.VERSION, true, "ffffffffffffffffffffffff", Nube.FORMATO_BD)
	ok(String(otro.get("resultado", "")) == "host", "otro lo abre (el arrendamiento habia caducado)")
	await Nube.latir()
	ok(Nube.estado == Nube.PERDIDO, "ahora si se ha perdido (estado %d)" % Nube.estado)

	Net.activo = false
	Net.es_host = false
	Net.mundo_compartido = false
	Nube.almacen = local
	Nube._olvidar()
	local.desfase_prueba = 0
	for f in ["%s.mundo.json", "%s.cerrojo.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [local.CARPETA, f % id]))
	print("FIN: TODO BIEN" if fallos == 0 else "FIN: %d MAL" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
