extends "res://tools/unitarias/caso.gd"
# Medidor (scripts/core/medidor.gd): las marcas de tiempo del plan de optimizacion.


func _antes() -> void:
	Medidor.olvidar()
	Medidor.callado = true


func test_tramo_mide_lo_que_pasa_entre_empezar_y_cerrar() -> void:
	_antes()
	Medidor.empezar("x")
	OS.delay_msec(15)
	var a := Medidor.marca("x", "medio")
	OS.delay_msec(15)
	var total := Medidor.cerrar("x")
	cierto(a >= 14.0, "la marca del medio lleva al menos 15 ms (sale %s)" % a)
	cierto(total >= a + 14.0, "el total es mayor que la marca del medio (%s vs %s)" % [total, a])
	cierto(not Medidor.abierto("x"), "cerrar() cierra el tramo")
	igual(int(Medidor.medidas()["x"]["n"]), 1, "y lo apunta como medida")


func test_marca_sin_empezar_no_rompe() -> void:
	_antes()
	cerca(Medidor.marca("nunca", "paso"), -1.0, 0.0001, "sin empezar devuelve -1")
	igual(Medidor.medidas().size(), 0, "y no apunta medida")


func test_medidas_media_y_peor() -> void:
	_antes()
	Medidor.medida("guardado", 10.0)
	Medidor.medida("guardado", 30.0)
	Medidor.medida("guardado", 20.0)
	var m: Dictionary = Medidor.medidas()["guardado"]
	igual(int(m["n"]), 3, "tres medidas")
	cerca(float(m["peor"]), 30.0, 0.0001, "el peor")
	cerca(float(m["suma"]) / 3.0, 20.0, 0.0001, "la media")
	cerca(float(m["ultima"]), 20.0, 0.0001, "la ultima")
	cierto("guardado" in Medidor.resumen(), "sale en el resumen")


func test_solo_guarda_las_ultimas() -> void:
	_antes()
	for i in Medidor.MAX_MARCAS + 50:
		Medidor.marca("y", "p%d" % i)
	igual(Medidor.ultimas(100000).size(), Medidor.MAX_MARCAS, "no crece sin limite")
	igual(String(Medidor.ultimas(1)[0]["paso"]), "p%d" % (Medidor.MAX_MARCAS + 49), "la ultima es la mas nueva")
	Medidor.callado = false


func test_informe_tecla_p_lleva_rendimiento() -> void:
	# El informe de la tecla P (scripts/core/informe.gd) enseña FPS, draw calls y las medidas del medidor
	_antes()
	Medidor.medida("guardado_exportar", 12.0)
	var texto: String = Informe.generar()
	cierto("[RENDIMIENTO]" in texto, "el informe tiene su apartado de rendimiento")
	cierto("draw calls" in texto, "con los draw calls")
	cierto("guardado_exportar" in texto, "y las medidas del medidor")
	Medidor.callado = false
