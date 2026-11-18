# PRUEBA (sin ventana): los AJUSTES DE JUEGO (Preferencias, pestaña «Juego» de Ajustes).
#
# 1. Las cifras de las fichas: los tres modos llegan a AbilityData.modo_cifras y cambian el texto.
# 2. Los decimales: enteros, 1 decimal (TOPE: lo entero sigue entero) y por defecto, en barras, registro y golpes.
# 3. Se guardan en user://ajustes.cfg sin llevarse los volumenes ni la pantalla, y se vuelven a leer.
# 5. Los CIRCULOS DE ALCANCE (18/11): apagados de serie, cuando se ven, su guardado, y el aro en PIXEL (AroPixel):
#    nitido (cada pixel lleno o vacio), cerrado, a rayas o a puntos con su separacion, y del grosor que se pide.
#
# Se hace copia del fichero de verdad al empezar y se devuelve tal cual al terminar.
extends Node

var _malos: int = 0
var _copia: PackedByteArray = PackedByteArray()
var _habia: bool = false


func _ok(texto: String, cond: bool, visto: String = "") -> void:
	print(("  ok   " if cond else "  MAL  ") + texto + ("" if cond or visto == "" else "  (sale: %s)" % visto))
	if not cond:
		_malos += 1


func _ready() -> void:
	print("=== AJUSTES DE JUEGO (cifras de fichas + decimales) ===")
	_habia = FileAccess.file_exists(Preferencias.RUTA_AJUSTES)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Preferencias.RUTA_AJUSTES)
	var cifras_antes: int = AbilityData.modo_cifras
	var dec_antes: int = Preferencias.decimales

	# 1) CIFRAS DE LAS FICHAS
	var base := "del Ataque de quien la usa"
	var tipo := "como Daño Físico"
	Preferencias.fijar_modo_cifras(AbilityData.ModoCifras.LOS_DOS)
	var t: String = AbilityData.cuanto_txt(2.0, 24.0, base, tipo)
	_ok("los dos: % y numero", t.contains("200") and t.contains("(48)"), t)
	Preferencias.fijar_modo_cifras(AbilityData.ModoCifras.PORCENTAJE)
	t = AbilityData.cuanto_txt(2.0, 24.0, base, tipo)
	_ok("solo %: sin el numero", t.contains("200") and not t.contains("48"), t)
	Preferencias.fijar_modo_cifras(AbilityData.ModoCifras.NUMERO)
	t = AbilityData.cuanto_txt(2.0, 24.0, base, tipo)
	_ok("solo numero: sin el %", t.contains("48") and not t.contains("%"), t)

	# 2) DECIMALES
	Preferencias.fijar_decimales(Preferencias.Decimales.DEFECTO)
	_ok("por defecto: la vida con 2", Preferencias.barra("%.2f / %.2f", 198.844, 199.9) == "198,84 / 199,90",
		Preferencias.barra("%.2f / %.2f", 198.844, 199.9))
	_ok("por defecto: la energia entera", Preferencias.barra("%.0f/%.0f", 12.0, 20.0) == "12/20")
	_ok("por defecto: el registro sin ceros de sobra", Preferencias.num(4.10) == "4,1", Preferencias.num(4.10))
	_ok("por defecto: el golpe con 2", Preferencias.fijo(34.623) == "34,62", Preferencias.fijo(34.623))

	Preferencias.fijar_decimales(Preferencias.Decimales.UNO)
	_ok("1 decimal: la vida con 1", Preferencias.barra("%.2f / %.2f", 198.844, 199.9) == "198,8 / 199,9",
		Preferencias.barra("%.2f / %.2f", 198.844, 199.9))
	_ok("1 decimal: la energia SIGUE entera (es un tope)", Preferencias.barra("%.0f/%.0f", 12.0, 20.0) == "12/20")
	_ok("1 decimal: el maná con prefijo", Preferencias.barra("MP  %.2f / %.2f", 34.62, 40.0) == "MP  34,6 / 40,0",
		Preferencias.barra("MP  %.2f / %.2f", 34.62, 40.0))
	_ok("1 decimal: el registro", Preferencias.num(5.69) == "5,7", Preferencias.num(5.69))
	_ok("1 decimal: el golpe", Preferencias.fijo(34.623) == "34,6", Preferencias.fijo(34.623))

	Preferencias.fijar_decimales(Preferencias.Decimales.ENTEROS)
	_ok("enteros: la vida", Preferencias.barra("%.2f / %.2f", 198.844, 199.9) == "199 / 200",
		Preferencias.barra("%.2f / %.2f", 198.844, 199.9))
	_ok("enteros: el registro", Preferencias.num(5.69) == "6", Preferencias.num(5.69))
	_ok("enteros: un cero no sale «-0»", Preferencias.num(-0.2) == "0", Preferencias.num(-0.2))
	_ok("enteros: un 10 no pierde el cero", Preferencias.num(10.0) == "10", Preferencias.num(10.0))
	_ok("enteros: el golpe", Preferencias.fijo(34.623) == "35", Preferencias.fijo(34.623))

	# 2b) EL REGISTRO viaja escrito (con 2 decimales) y cada uno lo recorta al pintarlo
	var frase := "La rata te inflige 34,62 de Daño Físico (×1,5). Te quedan 198,84, 12 y 3."
	_ok("enteros: el registro se recorta al pintar",
		Preferencias.en_texto(frase) == "La rata te inflige 35 de Daño Físico (×2). Te quedan 199, 12 y 3.",
		Preferencias.en_texto(frase))
	Preferencias.fijar_decimales(Preferencias.Decimales.UNO)
	_ok("1 decimal: el registro se recorta al pintar",
		Preferencias.en_texto(frase) == "La rata te inflige 34,6 de Daño Físico (×1,5). Te quedan 198,8, 12 y 3.",
		Preferencias.en_texto(frase))
	Preferencias.fijar_decimales(Preferencias.Decimales.DEFECTO)
	_ok("por defecto: el registro tal cual", Preferencias.en_texto(frase) == frase, Preferencias.en_texto(frase))
	_ok("lo que se ESCRIBE (y viaja) no depende del ajuste",
		_escrito_con(Preferencias.Decimales.ENTEROS) == "34,62" and _escrito_con(Preferencias.Decimales.UNO) == "34,62")

	# 3) DISCO: se guarda en su seccion sin pisar las demas, y se relee
	Sonido.fijar_volumen("musica", 0.33)
	Sonido.guardar_ajustes()
	Preferencias.fijar_modo_cifras(AbilityData.ModoCifras.NUMERO)
	Preferencias.fijar_decimales(Preferencias.Decimales.UNO)
	var cfg := ConfigFile.new()
	cfg.load(Preferencias.RUTA_AJUSTES)
	_ok("el volumen sigue en el fichero", is_equal_approx(float(cfg.get_value(Sonido.SECCION_VOL, "musica", -1.0)), 0.33))
	_ok("las cifras guardadas", int(cfg.get_value(Preferencias.SECCION, "cifras", -1)) == AbilityData.ModoCifras.NUMERO)
	_ok("los decimales guardados", int(cfg.get_value(Preferencias.SECCION, "decimales", -1)) == Preferencias.Decimales.UNO)
	AbilityData.modo_cifras = AbilityData.ModoCifras.LOS_DOS
	Preferencias.decimales = Preferencias.Decimales.DEFECTO
	Preferencias._cargar()
	_ok("al releer vuelven las cifras", AbilityData.modo_cifras == AbilityData.ModoCifras.NUMERO)
	_ok("al releer vuelven los decimales", Preferencias.decimales == Preferencias.Decimales.UNO)
	Sonido.guardar_ajustes()
	var cfg2 := ConfigFile.new()
	cfg2.load(Preferencias.RUTA_AJUSTES)
	_ok("guardar el volumen no se lleva lo de Juego",
		int(cfg2.get_value(Preferencias.SECCION, "decimales", -1)) == Preferencias.Decimales.UNO)

	# 4) Un valor fuera de rango (fichero a mano) se recorta
	Preferencias.fijar_decimales(99)
	_ok("decimales imposibles se recortan", Preferencias.decimales == 2)

	_circulos()

	AbilityData.modo_cifras = cifras_antes
	Preferencias.decimales = dec_antes
	_restaurar()
	print("FIN, %d fallos" % _malos)
	if _malos == 0:
		print("FIN: TODO BIEN")
	get_tree().quit(_malos)


func _circulos() -> void:
	var antes: Dictionary = Preferencias.alcance.duplicate(true)
	var P = Preferencias
	# De serie, apagados (los dos grupos), y un fichero sin la clave se lee apagado.
	_ok("de serie: los circulos de los tuyos apagados", int(P.ALCANCE_DEFECTO["tuyos"]["modo"]) == P.Alcance.APAGADO)
	_ok("de serie: los de los enemigos apagados", int(P.ALCANCE_DEFECTO["enemigos"]["modo"]) == P.Alcance.APAGADO)
	var cfg := ConfigFile.new()
	cfg.load(P.RUTA_AJUSTES)
	if cfg.has_section_key(P.SECCION, "alcance_tuyos"):
		cfg.erase_section_key(P.SECCION, "alcance_tuyos")
	cfg.save(P.RUTA_AJUSTES)
	P._cargar()
	_ok("sin nada guardado, apagados", int(P.alcance["tuyos"]["modo"]) == P.Alcance.APAGADO)
	_ok("apagado: ni el normal ni el del turno", not P.ve_alcance(false, false) and not P.ve_alcance(false, true))

	# Cuando se ven, cada grupo por su lado.
	P.fijar_alcance("tuyos", "modo", P.Alcance.TURNO)
	P.fijar_alcance("enemigos", "modo", P.Alcance.TODOS)
	_ok("solo del turno: el del turno si, el normal no", P.ve_alcance(false, true) and not P.ve_alcance(false, false))
	_ok("todos: los enemigos se ven todos", P.ve_alcance(true, false) and P.ve_alcance(true, true))
	P.fijar_alcance("tuyos", "opacidad", 40)
	_ok("el del turno, mas marcado", P.color_alcance(false, true).a > P.color_alcance(false, false).a)
	_ok("opacidad 40 %", is_equal_approx(P.color_alcance(false, false).a, 0.4))

	# Guardado y releido, y lo de fuera de rango recortado.
	P.fijar_alcance("enemigos", "color", Color(0.2, 0.9, 0.3))
	P.fijar_alcance("enemigos", "trazo", 0)
	P.fijar_alcance("enemigos", "hueco", 99)
	_ok("una separacion imposible se recorta", int(P.alcance["enemigos"]["hueco"]) == int(P.ALCANCE_TOPES["hueco"][1]))
	P.alcance = {}
	P._cargar()
	_ok("al releer: los tuyos solo del turno", int(P.alcance["tuyos"]["modo"]) == P.Alcance.TURNO)
	_ok("al releer: el color de los enemigos", (P.alcance["enemigos"]["color"] as Color).is_equal_approx(Color(0.2, 0.9, 0.3)))
	_ok("al releer: a puntos", int(P.alcance["enemigos"]["trazo"]) == 0)
	P.restablecer_alcance("enemigos")
	_ok("restablecer: vuelve el rojo", (P.alcance["enemigos"]["color"] as Color).is_equal_approx(P.ALCANCE_DEFECTO["enemigos"]["color"]))
	_ok("restablecer no cambia si se ven", int(P.alcance["enemigos"]["modo"]) == P.Alcance.TODOS)

	# EL ARO EN PIXEL
	var A = preload("res://scripts/fx/aro_pixel.gd")
	var rec: Array = A.recorrido(40)
	var pegado: bool = true
	for i in rec.size():
		var a: Vector2i = rec[i]
		var b: Vector2i = rec[(i + 1) % rec.size()]
		if absi(a.x - b.x) > 1 or absi(a.y - b.y) > 1 or a == b:
			pegado = false
	_ok("el recorrido da la vuelta pixel a pixel, sin saltos ni repetidos", pegado)
	var sin_l: bool = true
	for i in rec.size():
		var a: Vector2i = rec[i]
		var c: Vector2i = rec[(i + 2) % rec.size()]
		if absi(a.x - c.x) <= 1 and absi(a.y - c.y) <= 1:
			sin_l = false
	_ok("sin escalones dobles (pixeles de mas en la curva)", sin_l)
	var entero: int = _llenos(A.textura(40.0, A.Trazo.RAYAS, 1, 1000, 1))
	var rayas: int = _llenos(A.textura(40.0, A.Trazo.RAYAS, 1, 6, 4))
	var puntos: int = _llenos(A.textura(40.0, A.Trazo.PUNTOS, 1, 6, 4))
	var gordo: int = _llenos(A.textura(40.0, A.Trazo.PUNTOS, 2, 6, 4))
	print("     pixeles: recorrido %d, rayas 6/4 %d, puntos /4 %d, puntos de 2 px %d" % [rec.size(), rayas, puntos, gordo])
	_ok("a rayas 6/4: unas 6 de cada 10", absf(float(rayas) / float(rec.size()) - 0.6) < 0.06)
	_ok("a puntos /4: uno de cada 5", absf(float(puntos) / float(rec.size()) - 0.2) < 0.04)
	# (de 2 px el periodo es 2 + 4: caben menos puntos, pero cada uno es de 2 x 2)
	_ok("puntos de 2 px: cada punto de 2 x 2", gordo == roundi(float(rec.size()) / 6.0) * 4)
	_ok("nitido: cada pixel lleno o vacio (nada a medias)", _nitido(A.textura(40.0, A.Trazo.RAYAS, 2, 6, 4)))
	_ok("una textura por estilo: la segunda vez es la misma",
		A.textura(40.0, A.Trazo.RAYAS, 1, 6, 4) == A.textura(40.0, A.Trazo.RAYAS, 1, 6, 4))
	_ok("con todo entero, el aro completo", entero >= rec.size() - 1)

	P.alcance = antes
	A._cache.clear()


func _llenos(tex: Texture2D) -> int:
	var img: Image = tex.get_image()
	var n: int = 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return n


func _nitido(tex: Texture2D) -> bool:
	var img: Image = tex.get_image()
	for y in img.get_height():
		for x in img.get_width():
			var a: float = img.get_pixel(x, y).a
			if a > 0.01 and a < 0.99:
				return false
	return true


func _escrito_con(d: int) -> String:
	var antes: int = Preferencias.decimales
	Preferencias.decimales = d
	var s: String = load("res://scripts/ui/combat.gd")._n(34.62)
	Preferencias.decimales = antes
	return s


func _restaurar() -> void:
	if _habia:
		var f := FileAccess.open(Preferencias.RUTA_AJUSTES, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_copia)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferencias.RUTA_AJUSTES))
