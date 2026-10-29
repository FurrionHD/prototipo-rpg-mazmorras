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
