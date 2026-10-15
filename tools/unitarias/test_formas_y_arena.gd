extends "res://tools/unitarias/caso.gd"
# CombatFormas (scripts/ui/combat_formas.gd): que golpea cada forma (circulo, cono, linea, rectangulo).
# ArenaCalculo (scripts/world/arena_calculo.gd): la parte de la arena que no necesita un piso generado
# (tamaño pedido, celdas, mascara, trozos). Lo que mira un piso de verdad sigue en prueba_arena_forma.


func test_circulo_contiene_lo_de_dentro() -> void:
	var f := CombatFormas.circulo(Vector2(100, 100), 50.0)
	cierto(f.contiene(Vector2(100, 100)), "el centro")
	cierto(f.contiene(Vector2(149, 100)), "justo dentro del borde")
	cierto(not f.contiene(Vector2(151, 100)), "justo fuera del borde")
	cierto(not f.contiene(Vector2(300, 300)), "lejos")


func test_cono_respeta_la_apertura() -> void:
	# Cono hacia la derecha de 90 grados: ±45
	var f := CombatFormas.cono(Vector2.ZERO, Vector2.RIGHT, 100.0, 90.0)
	cierto(f.contiene(Vector2(50, 0)), "de frente")
	cierto(f.contiene(Vector2(50, 40)), "dentro del abanico (≈39 grados)")
	cierto(not f.contiene(Vector2(50, 60)), "fuera del abanico (≈50 grados)")
	cierto(not f.contiene(Vector2(-50, 0)), "por detras")
	cierto(not f.contiene(Vector2(120, 0)), "mas lejos que el radio")


func test_cono_con_direccion_cero_no_rompe() -> void:
	var f := CombatFormas.cono(Vector2.ZERO, Vector2.ZERO, 100.0, 90.0)
	cierto(is_finite(f.dir.x) and is_finite(f.dir.y) and f.dir.length() > 0.5,
		"una direccion nula se cambia por una valida (sale %s)" % f.dir)


func test_linea_tiene_largo_y_ancho() -> void:
	var f := CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 200.0)
	cierto(f.contiene(Vector2(100, 0)), "en medio de la raya")
	cierto(not f.contiene(Vector2(250, 0)), "mas alla del largo")
	cierto(not f.contiene(Vector2(-20, 0)), "por detras del origen")
	cierto(not f.contiene(Vector2(100, 200)), "muy de lado")


func test_toca_un_cuerpo_aunque_su_centro_quede_fuera() -> void:
	# Lo que manda en el tactico es el CUERPO (una caja), no su centro: si el borde entra, le da.
	var f := CombatFormas.circulo(Vector2.ZERO, 50.0)
	var caja := Rect2(Vector2(45, -10), Vector2(30, 20))   # centro en x=60, fuera; borde en x=45, dentro
	cierto(not f.contiene(caja.get_center()), "el centro de la caja esta fuera")
	cierto(f.toca(caja), "pero la caja toca el circulo")
	cierto(not f.toca(Rect2(Vector2(200, 200), Vector2(10, 10))), "una caja lejos no toca")


func test_radio_para_crece_con_n() -> void:
	var antes := -1.0
	for n in range(1, 8):
		var r := CombatFormas.radio_para(n)
		cierto(r >= antes, "radio_para(%d) no puede encoger" % n)
		antes = r


func test_tam_deseado_de_la_arena() -> void:
	var base := ArenaCalculo.tam_deseado(0)
	igual(ArenaCalculo.tam_deseado(-3), base, "enemigos negativos = la base")
	var grande := ArenaCalculo.tam_deseado(30)
	cierto(grande.x >= base.x and grande.y >= base.y, "mas enemigos no la hacen mas pequeña")


func test_celda_de_px_redondea_hacia_abajo() -> void:
	var c := float(DungeonGenerator.CELDA)
	igual(ArenaCalculo.celda_de_px(Vector2(0.5, 0.5)), Vector2i(0, 0), "dentro de la primera celda")
	igual(ArenaCalculo.celda_de_px(Vector2(-0.5, -0.5)), Vector2i(-1, -1), "negativos: floor, no truncar")
	igual(ArenaCalculo.celda_de_px(Vector2(c, c * 2.0)), Vector2i(1, 2), "en el borde exacto")


func test_mascara_y_celdas() -> void:
	var rect := Rect2i(10, 10, 3, 2)
	igual(ArenaCalculo.celdas_de(rect, PackedByteArray()), 6, "sin mascara cuenta el rectangulo entero")
	var m := PackedByteArray([1, 0, 1, 1, 1, 0])
	igual(ArenaCalculo.celdas_de(rect, m), 4, "con mascara solo las marcadas")
	cierto(ArenaCalculo.en_forma(rect, m, Vector2i(10, 10)), "primera celda marcada")
	cierto(not ArenaCalculo.en_forma(rect, m, Vector2i(11, 10)), "celda a 0")
	cierto(not ArenaCalculo.en_forma(rect, m, Vector2i(50, 50)), "fuera del rectangulo")


func test_trozos_separa_lo_que_no_se_toca() -> void:
	# Fila 0: 1 1 0 1
	# Fila 1: 1 0 0 1        -> dos trozos: 3 celdas a la izquierda, 2 a la derecha
	var rect := Rect2i(0, 0, 4, 2)
	var m := PackedByteArray([1, 1, 0, 1, 1, 0, 0, 1])
	var t := ArenaCalculo.trozos(rect, m)
	igual(t.size(), 2, "dos trozos")
	if t.size() == 2:
		igual(int(t[0]["celdas"]), 3, "el grande primero")
		igual(int(t[1]["celdas"]), 2, "el pequeño despues")
	igual(ArenaCalculo.trozos(Rect2i(), PackedByteArray()).size(), 0, "rect vacio = sin trozos")
	# en diagonal NO se tocan (solo en cruz)
	igual(ArenaCalculo.trozos(Rect2i(0, 0, 2, 2), PackedByteArray([1, 0, 0, 1])).size(), 2, "diagonal = dos trozos")
