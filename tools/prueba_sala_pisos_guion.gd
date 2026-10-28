# Guion del jugador de prueba_sala_pisos (fase 2, etapa 2, paso 2). Apunta lo que ve con "[P] ..." y lee lo de la sala
# de su registro (lineas "[S] dato", ver tools/sonda_sala.gd).
extends "res://tools/prueba_town_dos_comun.gd"

var _entrado := false
var _registro_sala := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prefijo = "[P] "
	var args := OS.get_cmdline_user_args()
	var i := args.find("cliente_pisos")
	var puerto := int(args[i + 1])
	var codigo: String = args[i + 2]
	Identidad.id = args[i + 3]
	_registro_sala = OS.get_user_data_dir().path_join("logs/" + args[i + 4])
	Net.partida.entrada_lista.connect(func():
		var arbol := get_tree()
		arbol.change_scene_to_file("res://scenes/levels/town.tscn")
		await arbol.process_frame
		Net.anunciar_lugar("pueblo")
		_entrado = true)
	await _esperar(0.5)
	_ok(Net.unirse("127.0.0.1", codigo, puerto, true) == OK, "me conecto a la sala de mi ranura")
	_ok(await _hasta(func(): return _entrado, 60.0), "entro en el pueblo")
	await _esperar(1.0)
	await _guion()
	print("[P] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	Net.desconectar()
	await _esperar(1.0)
	get_tree().quit(0 if fallos.is_empty() else 1)


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()


# Lo que la sala dice AHORA de 'clave' ("" si nunca lo ha dicho).
func _sala(clave: String) -> String:
	if not FileAccess.file_exists(_registro_sala):
		return ""
	var f := FileAccess.open(_registro_sala, FileAccess.READ)
	var texto := f.get_as_text()
	f.close()
	var v := ""
	var pre := "[S] dato " + clave + "="
	for linea in texto.split("\n"):
		if linea.begins_with(pre):
			v = linea.substr(pre.length()).strip_edges()
	return v


# Los enemigos que veo (espejos vivos): id -> posicion.
func _espejos() -> Dictionary:
	var out := {}
	for nid in Net.enemigos._enem_nodos:
		var n = Net.enemigos._enem_nodos[nid]
		if is_instance_valid(n):
			out[nid] = (n as Node2D).global_position
	return out


func _bajar() -> bool:
	Net.pisos.solicitar_entrar(1)
	if not await _hasta(func(): return Net._mi_lugar == "piso:1" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0):
		return false
	# Los espejos llegan uno a uno (un aviso por enemigo): se espera a que esten y se asienten.
	await _hasta(func(): return not _espejos().is_empty(), 15.0)
	await _esperar(1.5)
	return true


func _subir() -> void:
	Net.pisos.viajar_al_pueblo()
	_ok(await _hasta(func(): return Net._mi_lugar == "pueblo", 20.0), "subo al pueblo (lugar %s, pelea en pantalla %s, espejando %s)" % [
		Net._mi_lugar, Game.hay_pelea_en_pantalla(), Net.peleas.espejando()])
	await _esperar(0.5)


func _guion() -> void:
	# --- 1) Bajo: la sala monta el piso y es su dueña ---
	_ok(await _bajar(), "bajo al piso 1")
	_ok(not PisoVivo.dueno_de(Net._mi_lugar), "entro de ESPEJO: el piso no es mio")
	_ok(await _hasta(func(): return _sala("dueno_piso_1") == "1", 10.0), "el dueño del piso 1 es la sala (%s)" % _sala("dueno_piso_1"))
	_ok(_sala("montados") == "1", "la sala tiene montado el piso 1 (%s)" % _sala("montados"))
	var vistos: Dictionary = _espejos()
	var en_sala := int(_sala("enem_piso_1"))
	print("[P] dato espejos=%d sala=%d" % [vistos.size(), en_sala])
	_ok(vistos.size() > 0 and vistos.size() == en_sala, "veo los mismos enemigos que lleva la sala (%d y %d)" % [vistos.size(), en_sala])
	var ids_propios := 0
	for nid in vistos:
		if int(nid) / 1000000 == multiplayer.get_unique_id():
			ids_propios += 1
	_ok(ids_propios == 0, "ninguno lo he creado yo (ids de la sala)")
	# Se mueven: los lleva la sala (no hay dueño humano).
	var antes := _espejos()
	await _esperar(4.0)
	var movido := 0.0
	var ahora := _espejos()
	for nid in antes:
		if ahora.has(nid):
			movido = maxf(movido, (ahora[nid] as Vector2).distance_to(antes[nid]))
	_ok(movido > 2.0, "los enemigos se mueven (%.1f px)" % movido)

	# --- 2) Subo y vuelvo antes de 10 s: el piso sigue vivo, con los mismos ---
	var ids_antes: Array = _espejos().keys()
	await _subir()
	_ok(await _hasta(func(): return _sala("piso_" + Identidad.id) == "-1", 10.0), "estoy en el pueblo para la sala")
	await _esperar(3.0)
	_ok(_sala("montados") == "1", "a los 3 s de irme, el piso 1 sigue montado (%s)" % _sala("montados"))
	_ok(await _bajar(), "vuelvo a bajar antes de los 10 s")
	var ids_vuelta: Array = _espejos().keys()
	var comunes := 0
	for nid in ids_vuelta:
		if ids_antes.has(nid):
			comunes += 1
	print("[P] dato ids_antes=%d ids_vuelta=%d comunes=%d" % [ids_antes.size(), ids_vuelta.size(), comunes])
	_ok(comunes > 0 and comunes >= ids_antes.size() - 2, "son los MISMOS enemigos, no un piso nuevo (%d de %d)" % [comunes, ids_antes.size()])

	# --- 3) Subo y espero: la sala lo congela en su foto ---
	await _esperar(1.0)
	var foto_mia: Dictionary = _espejos()   # cuantos veia justo antes de irme
	await _subir()
	_ok(await _hasta(func(): return _sala("montados") == "", 20.0), "a los 10 s de irme, la sala lo desmonta (%s)" % _sala("montados"))
	var en_foto := int(_sala("foto_piso_1"))
	print("[P] dato foto_piso_1=%d (veia %d)" % [en_foto, foto_mia.size()])
	_ok(en_foto > 0 and absi(en_foto - foto_mia.size()) <= 2, "y lo congela con sus enemigos (%d, veia %d)" % [en_foto, foto_mia.size()])

	# --- 4) Vuelvo: se monta desde la foto ---
	_ok(await _bajar(), "vuelvo a bajar")
	_ok(await _hasta(func(): return _sala("montados") == "1", 10.0), "la sala lo monta otra vez")
	var nuevos: Dictionary = _espejos()
	print("[P] dato espejos_al_volver=%d foto=%d" % [nuevos.size(), en_foto])
	_ok(absi(nuevos.size() - en_foto) <= 2, "vuelven los de la foto (%d, la foto traia %d)" % [nuevos.size(), en_foto])
	# Cada uno sale donde lo dejo la foto (con la misma semilla saldrian otros en otros sitios). Lo cuenta la sala al
	# montarlo, antes de que anden: a mi me llegan cuando ya he cargado el piso.
	_ok(await _hasta(func(): return _sala("vuelta_piso_1") != "", 5.0), "la sala ha mirado la vuelta")
	var v: PackedStringArray = _sala("vuelta_piso_1").split("/")
	var en_sitio := int(v[0]) if v.size() == 2 else 0
	var total := int(v[1]) if v.size() == 2 else 0
	_ok(total > 0 and en_sitio == total, "y cada uno sale en su sitio de la foto (%d de %d)" % [en_sitio, total])
	await _subir()
