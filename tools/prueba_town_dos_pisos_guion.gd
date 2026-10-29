# DOS JUGADORES EN DOS PISOS A LA VEZ, POR LA SALA (fase 2, etapa 2, paso 3). La sala lleva los dos pisos montados en el
# mismo programa y cada uno va por su cuenta: sus enemigos, su alboroto (sus brotes) y su congelado. Guion de A (el
# proceso de la prueba); el de B en prueba_town_dos_pisos_b_guion.gd. Lo de la sala, en sus lineas "[S] dato".
#   1) A baja al 1; B baja al 1 y sigue al 2. La sala tiene montados el 1 y el 2.
#   2) Cada uno ve SOLO los enemigos de su piso (ids sin mezclar, y los mismos que lleva la sala en ese piso).
#   3) A arma jaleo: brote en el piso 1 y no en el 2. Luego B: brote en el 2 (con un medidor unico, el respiro tras el
#      primer brote no dejaria salir el segundo).
#   4) B sube al pueblo: el 2 se congela a los 10 s y el 1 sigue montado con A dentro.
#   Y (29/10, Net.peers_en) lo que pasa en el piso de B (su brote, sus enemigos nuevos) NO me llega: a cada uno solo le
#   llegan los sucesos de su sitio.
# Cubre: game.gd (sumar_alboroto con lugar, _sumar_alboroto_piso), piso_vivo.gd (alboroto por piso), net_pisos.gd
# (_alboroto_en_dueno, sala_montar, sala_congelar) y net_enemigos.gd (_pedir_enemigos por lugar).
# Se lanza con:  <godot> --headless --path . res://tools/prueba_town_dos_pisos.tscn -- nube_local
extends "res://tools/prueba_town_sala_comun.gd"


func _ready() -> void:
	slot = 84
	puerto = 24614
	registro_b = "user://logs/prueba_town_dos_pisos_b.log"
	if not await empezar("prueba_town_dos_pisos_b"):
		await _fin()
		return
	await _guion()
	await _fin()


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()


func _mis_ids() -> Array:
	var out: Array = []
	for nid in Net.enemigos._enem_nodos:
		if is_instance_valid(Net.enemigos._enem_nodos[nid]):
			out.append(int(nid))
	return out


# Cuantas lineas de brote ha apuntado la sala en ese lugar.
func _brotes_en(lugar: String) -> int:
	return _texto(registro_sala).count("en %s! Brote disparado" % lugar)


# Ruido de A hasta que salga un brote en su piso (o se acabe el plazo). Poco a poco: el brote solo sale si hay pared a
# la vista, y el medidor lleno espera al siguiente ruido para intentarlo.
func _jaleo_hasta_brote(lugar: String, plazo: float) -> bool:
	var antes := _brotes_en(lugar)
	var t := 0.0
	while _brotes_en(lugar) == antes and t < plazo:
		Game.sumar_alboroto(40.0)
		await _esperar(0.5)
		t += 0.5
	return _brotes_en(lugar) > antes


func _guion() -> void:
	# --- 1) A al 1, B al 1 y luego al 2 ---
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0),
		"bajo al piso 1")
	escribir_fase(1)
	_ok(await hasta_sala("piso_" + IDENT_B, func(v): return v == "2", 60.0), "B llega al piso 2 (%s)" % dato_sala("piso_" + IDENT_B))
	_ok(await hasta_sala("montados", func(v): return v == "1,2", 10.0), "la sala tiene montados el 1 y el 2 (%s)" % dato_sala("montados"))
	_ok(dato_sala("dueno_piso_1") == "1" and dato_sala("dueno_piso_2") == "1", "los dos los lleva la sala")
	await _hasta(func(): return not _mis_ids().is_empty(), 15.0)
	await _esperar(2.0)

	# --- 2) Cada uno ve los de su piso ---
	await _hasta(func(): return _linea(_texto(registro_b), "[B] dato ids", "") != "", 30.0)   # que B lo haya apuntado
	var mios := _mis_ids()
	var de_b: Array = Array(_linea(_texto(registro_b), "[B] dato ids", "").split(",", false)).map(func(x): return int(x))
	var mezclados := 0
	for nid in mios:
		if de_b.has(nid):
			mezclados += 1
	print("[dev] veo %d enemigos (sala: %s en el 1); B ve %d (sala: %s en el 2)" % [mios.size(),
		dato_sala("enem_piso_1"), de_b.size(), dato_sala("enem_piso_2")])
	_ok(not mios.is_empty() and not de_b.is_empty(), "los dos vemos enemigos (%d y %d)" % [mios.size(), de_b.size()])
	_ok(mezclados == 0, "ninguno de los del 1 esta en el 2 (%d mezclados)" % mezclados)
	_ok(absi(mios.size() - int(dato_sala("enem_piso_1"))) <= 1, "veo los que lleva la sala en el 1")
	_ok(absi(de_b.size() - int(dato_sala("enem_piso_2"))) <= 1, "B ve los que lleva la sala en el 2")

	# --- 3) El alboroto, cada piso el suyo ---
	_ok(await _jaleo_hasta_brote("piso:1", 30.0), "mi jaleo revienta una pared EN EL PISO 1")
	_ok(_brotes_en("piso:2") == 0, "y en el piso 2 no ha salido nada")
	var ajenos: int = Net.de_otro_sitio
	escribir_fase(2)   # ahora B
	_ok(await _hasta(func(): return _brotes_en("piso:2") > 0, 40.0), "el jaleo de B revienta una pared en el 2, aunque el 1 acabe de tener el suyo")
	await _esperar(2.0)   # lo que tardaria en llegarme lo de su brote, si me llegara
	_ok(Net.de_otro_sitio == ajenos, "no me llega nada del piso de B (%d mensajes de otro sitio)" % (Net.de_otro_sitio - ajenos))

	# --- 4) B se va: el 2 se congela y el 1 sigue ---
	escribir_fase(3)
	_ok(await hasta_sala("montados", func(v): return v == "1", 25.0), "B sube y la sala desmonta el 2 (montados: %s)" % dato_sala("montados"))
	_ok(int(dato_sala("foto_piso_2")) > 0, "el 2 queda congelado con sus enemigos (%s)" % dato_sala("foto_piso_2"))
	_ok(not _mis_ids().is_empty() and Net._mi_lugar == "piso:1", "yo sigo en el 1 con mis enemigos")
	Net.pisos.viajar_al_pueblo()
	await _hasta(func(): return Net._mi_lugar == "pueblo", 20.0)
