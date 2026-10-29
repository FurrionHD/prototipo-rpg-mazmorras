extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/net/net_fotos.gd res://scripts/core/personaje_data.gd res://scripts/net/net_hogar.gd
# LAS FOTOS VIAJAN UNA VEZ (Net.fotos, PROTOCOLO 53): la huella de 64 bits y su recuerdo en PersonajeData, que solo
# entre una foto valida con la huella que se pidio, el tope de subidas por jugador, quien espera una foto que la sala
# aun no tiene, que olvidar la sesion no tira las fotos, y el roster del hogar: va la huella y la foto sale de ella.
# Sin red: las piezas que no mandan nada se llaman a mano.


func _png(col: Color, lado: int = 8) -> PackedByteArray:
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return img.save_png_to_buffer()


func _limpio() -> void:
	Net.fotos.olvidar_sesion()
	Net.fotos._png.clear()


func test_la_huella_es_la_de_la_foto() -> void:
	var a := _png(Color.RED)
	igual(PersonajeData.huella_de(PackedByteArray()), 0, "sin foto, huella 0")
	igual(PersonajeData.huella_de(a), PersonajeData.huella_de(a.duplicate()), "misma foto, misma huella")
	cierto(PersonajeData.huella_de(a) != PersonajeData.huella_de(_png(Color.BLUE)), "otra foto, otra huella")


func test_la_huella_recordada_se_olvida_al_cambiar_la_foto() -> void:
	var pj := PersonajeData.new()
	igual(pj.huella_imagen(), 0, "sin foto, 0")
	var a := _png(Color.RED)
	pj.set_imagen(a)
	igual(pj.huella_imagen(), PersonajeData.huella_de(a), "con set_imagen")
	var b := _png(Color.GREEN)
	pj.imagen = b   # asignada a pelo (la carga de la partida, el creador): tambien
	igual(pj.huella_imagen(), PersonajeData.huella_de(b), "asignada directamente")
	pj.imagen = PackedByteArray()
	igual(pj.huella_imagen(), 0, "quitada")


func test_solo_valen_fotos_png_de_tamano_de_cara() -> void:
	cierto(Net.fotos.valida(_png(Color.RED)), "un PNG pequeño vale")
	cierto(not Net.fotos.valida(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9])), "lo que no es PNG no")
	cierto(not Net.fotos.valida("hola"), "lo que no son bytes no")
	var grande := _png(Color.RED)
	grande.resize(Net.fotos.TOPE_PNG + 1)
	cierto(not Net.fotos.valida(grande), "uno mas grande que el tope no")
	# La foto mas grande que puede salir del juego cabe (ruido: no se comprime nada).
	var img := Image.create(Game.IMAGEN_CUERPO_MAX, Game.IMAGEN_CUERPO_MAX, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	cierto(Net.fotos.valida(img.save_png_to_buffer()), "la mas grande del juego cabe en el tope")


func test_publicar_y_pedir_en_la_misma_maquina() -> void:
	_limpio()
	var a := _png(Color.RED)
	var h: int = Net.fotos.publicar(a)
	igual(h, PersonajeData.huella_de(a), "publicar devuelve su huella")
	igual(Net.fotos.publicar(PackedByteArray()), 0, "sin foto, 0")
	igual(Net.fotos.pedir(h), a, "pedir la devuelve")
	igual(Net.fotos.pedir(0), PackedByteArray(), "huella 0, nada")
	igual(Net.fotos.pedir(h + 1), PackedByteArray(), "una que no tengo, vacia")
	cierto(Net.fotos._pedidas.is_empty(), "sin sesion no se pide nada")


func test_al_cliente_solo_le_entra_lo_que_pidio_y_con_su_huella() -> void:
	_limpio()
	var a := _png(Color.RED)
	var h: int = PersonajeData.huella_de(a)
	var llegadas: Array = []
	var oir := func(x: int) -> void: llegadas.append(x)
	Net.fotos.llegada.connect(oir)
	cierto(not Net.fotos.recibir_foto(h, a), "sin pedirla no entra")
	Net.fotos._pedidas[h] = true
	cierto(not Net.fotos.recibir_foto(h, _png(Color.BLUE)), "con otra foto debajo de esa huella no entra")
	aviso_esperado("ha llegado mal")
	cierto(not Net.fotos.tiene(h), "y no se guarda")
	Net.fotos._pedidas[h] = true
	cierto(Net.fotos.recibir_foto(h, a), "la buena entra")
	cierto(Net.fotos.tiene(h) and Net.fotos._pedidas.is_empty(), "guardada y ya no pendiente")
	igual(Net.fotos.recibidas, 1, "contada")
	igual(llegadas, [h], "avisa de que ha llegado")
	cierto(not Net.fotos.recibir_foto(h, a), "otra vez la misma no entra (no la pedi)")
	Net.fotos.llegada.disconnect(oir)


func test_la_sala_calcula_la_huella_y_pone_tope_a_las_subidas() -> void:
	_limpio()
	var a := _png(Color.RED)
	igual(Net.fotos.recibir_subida(5, a), PersonajeData.huella_de(a), "la sube y la huella la calcula la sala")
	cierto(Net.fotos.tiene(PersonajeData.huella_de(a)), "guardada")
	igual(Net.fotos.recibir_subida(5, PackedByteArray([1, 2, 3])), 0, "lo que no es foto no")
	aviso_esperado("no es una foto valida")
	for i in Net.fotos.SUBIDAS_POR_PEER - 1:
		Net.fotos.recibir_subida(5, _png(Color(float(i) / 100.0, 0, 0)))
	igual(Net.fotos.recibir_subida(5, _png(Color.WHITE)), 0, "pasado el tope no acepta mas de ese jugador")
	aviso_esperado("no se aceptan mas")
	cierto(Net.fotos.recibir_subida(6, _png(Color.WHITE)) != 0, "de otro si")


func test_quien_espera_una_foto_que_la_sala_aun_no_tiene() -> void:
	_limpio()
	var a := _png(Color.RED)
	var h: int = PersonajeData.huella_de(a)
	Net.fotos.atender_peticion(9, PackedInt64Array([h, h]))
	igual(Net.fotos._esperan.get(h, []), [9], "apuntado una vez")
	Net.fotos.atender_peticion(8, PackedInt64Array([h]))
	Net.fotos.olvidar_peer(8)
	igual(Net.fotos._esperan.get(h, []), [9], "el que se va deja de esperar")
	Net.fotos.recibir_subida(5, a)   # 9 no esta conectado de verdad: no se le manda, pero deja de esperar
	cierto(not Net.fotos._esperan.has(h), "al llegar la foto ya no espera nadie")
	Net.fotos.atender_peticion(9, PackedInt64Array([h + 1]))
	Net.fotos.olvidar_peer(9)
	cierto(Net.fotos._esperan.is_empty(), "sin nadie esperando, la huella se borra")


func test_olvidar_la_sesion_no_tira_las_fotos() -> void:
	_limpio()
	var h: int = Net.fotos.publicar(_png(Color.RED))
	Net.fotos._subidas[h] = true
	Net.fotos._pedidas[h + 1] = true
	Net.fotos._esperan[h + 2] = [3]
	Net.fotos.recibir_subida(3, _png(Color.BLUE))
	Net.fotos.olvidar_sesion()
	cierto(Net.fotos.tiene(h), "la foto se queda")
	cierto(Net.fotos._subidas.is_empty() and Net.fotos._pedidas.is_empty(), "lo subido y lo pedido, no")
	cierto(Net.fotos._esperan.is_empty() and Net.fotos._subidas_de.is_empty(), "ni quien espera ni las cuentas")


func test_el_roster_lleva_la_huella_y_la_foto_sale_de_ella() -> void:
	_limpio()
	Game.nueva_partida("Prueba")
	var pj: PersonajeData = Game.lider()
	var a := _png(Color.RED)
	pj.set_imagen(a)
	var fila: Dictionary = Net.hogar._fila_roster(pj, Identidad.id, "yo")
	igual(int(fila["imagen_huella"]), PersonajeData.huella_de(a), "la fila lleva la huella")
	cierto(not (fila["aspecto"] as Dictionary).has("imagen"), "y no la foto")
	var copia: PersonajeData = Net.hogar.pj_de_fila(fila)
	igual(copia.imagen, a, "el personaje de la fila sale con su foto")
	pj.set_imagen(PackedByteArray())
	fila = Net.hogar._fila_roster(pj, Identidad.id, "yo")
	igual(int(fila["imagen_huella"]), 0, "sin foto, huella 0")
	cierto(Net.hogar.pj_de_fila(fila).imagen.is_empty(), "y sale sin foto")


func test_el_cliente_no_sube_ni_pide_hasta_que_la_sala_le_admite() -> void:
	_limpio()
	var activo: bool = Net.activo
	var host: bool = Net.es_host
	Net.activo = true   # cliente de mentira: sin admitir, no llega a mandar nada (no hace falta red)
	Net.es_host = false
	var a := _png(Color.RED)
	var h: int = Net.fotos.publicar(a)
	cierto(Net.fotos._por_subir.has(h), "publicada antes de entrar: se guarda para subirla al entrar")
	cierto(Net.fotos._subidas.has(h), "y cuenta como subida (no sale dos veces)")
	Net.fotos.publicar(a)
	igual(Net.fotos._por_subir.size(), 1, "publicarla otra vez no la duplica")
	Net.fotos.pedir(h + 1)
	Net.fotos.pedir(h + 1)
	igual(Net.fotos._por_pedir, PackedInt64Array([h + 1]), "pedida una vez, esperando a entrar")
	Net.fotos.olvidar_sesion()
	cierto(Net.fotos._por_subir.is_empty() and Net.fotos._por_pedir.is_empty() and not Net.fotos._dentro,
		"al cerrar la sesion no queda nada por mandar")
	Net.activo = activo
	Net.es_host = host


func test_la_ficha_lleva_la_huella_y_vuelve_con_su_foto() -> void:
	_limpio()
	Game.nueva_partida("Prueba")
	var pj: PersonajeData = Game.lider()
	var a := _png(Color.RED)
	pj.set_imagen(a)
	var d: Dictionary = Net.partida.pj_a_dict(pj)
	cierto(not d.has("imagen"), "la ficha no lleva la foto")
	igual(int(d["imagen_huella"]), PersonajeData.huella_de(a), "lleva su huella")
	igual(Net.partida.pj_de_dict(d, false).imagen, a, "y al otro lado sale con su foto")


func test_la_foto_pendiente_viaja_y_se_pone_sola_al_llegar() -> void:
	_limpio()
	var a := _png(Color.RED)
	var h: int = PersonajeData.huella_de(a)
	var pj := PersonajeData.new()
	Net.fotos.poner_en(pj, h)
	cierto(pj.imagen.is_empty(), "aun sin foto")
	igual(Net.fotos.huella_de_pj(pj), h, "pero la que viaja como suya es la que espera (no un 0)")
	Net.fotos.recibir_subida(5, a)
	igual(pj.imagen, a, "al llegar se le pone")
	cierto(not pj.has_meta(PersonajeData.META_FOTO_PENDIENTE), "y ya no espera")
	# Si entre medias le ponen otra, la que esperaba no la pisa.
	var b := _png(Color.BLUE)
	var otro := PersonajeData.new()
	Net.fotos.poner_en(otro, PersonajeData.huella_de(b))
	var c := _png(Color.GREEN)
	otro.set_imagen(c)
	Net.fotos.recibir_subida(5, b)
	igual(otro.imagen, c, "la suya nueva se queda")


func test_la_sala_no_pierde_la_foto_si_la_nueva_aun_no_ha_llegado() -> void:
	_limpio()
	var vieja := _png(Color.RED)
	var nueva := _png(Color.BLUE)
	var antes := JugadorData.new()
	var pj_v := PersonajeData.new()
	pj_v.uid = "u1"
	pj_v.set_imagen(vieja)
	antes.personajes.append(pj_v)
	var ahora := JugadorData.new()
	var pj_n := PersonajeData.new()
	pj_n.uid = "u1"
	Net.fotos.poner_en(pj_n, PersonajeData.huella_de(nueva))
	ahora.personajes.append(pj_n)
	Net.partida._conservar_fotos(ahora, antes)
	aviso_esperado("se queda con la de antes")
	igual(pj_n.imagen, vieja, "mientras, la de antes")
	Net.fotos.recibir_subida(5, nueva)
	igual(pj_n.imagen, nueva, "y al llegar, la nueva")


func test_la_ficha_de_escaparate_lleva_la_huella_y_no_la_foto() -> void:
	_limpio()
	Game.nueva_partida("Prueba")
	var pj: PersonajeData = Game.lider()
	var a := _png(Color.RED)
	pj.set_imagen(a)
	var d: Dictionary = Game.pj_a_dict(pj)
	cierto(not d.has("imagen"), "el roster de una pelea no lleva la foto")
	igual(int(d["imagen_huella"]), PersonajeData.huella_de(a), "lleva su huella")
	igual(Game.pj_de_dict(d).imagen, a, "y el maniqui del espejo sale con su foto")


func test_el_marcador_de_turnos_se_repinta_sin_perder_su_sitio() -> void:
	var tl: Control = load("res://scripts/ui/turn_timeline.gd").new()
	arbol.add_child(tl)
	var c := Combatant.new("x", 1, Abilities.new(), 10.0, 1.0, 1.0, 1.0)
	var pj := PersonajeData.new()
	c.pj_escaparate = pj
	tl.anadir(c, Color.RED, null, "")
	tl._marcadores[c]["ratio"] = 0.4
	tl.marcar_objetivo(c)
	var viejo: Node = tl._marcadores[c]["marco"]
	pj.set_imagen(_png(Color.BLUE))   # le llega la foto
	tl.repintar(c, Color.RED, null, "")
	cierto(tl._marcadores[c]["marco"] != viejo, "marcador nuevo (con su cara)")
	cerca(float(tl._marcadores[c]["ratio"]), 0.4, 0.0001, "en el mismo sitio de la barra")
	cierto(tl._objetivo == c, "y sigue marcado como objetivo")
	tl.free()
