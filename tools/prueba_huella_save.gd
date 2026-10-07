# BD FASE 0: la HUELLA de una partida (HuellaSave) y lo que cuesta HOY guardarla.
#   godot --headless --path . res://tools/prueba_huella_save.tscn
#   HUELLA_FICHERO=<ruta a un .tres>  (por defecto el mundo de referencia de tools/huellas)
# Mira:
#   1. que la huella sale IGUAL al cargar dos veces el mismo fichero (si no, no sirve para comparar);
#   2. que escribirlo y releerlo con Godot da la MISMA huella (la ida y vuelta de hoy no pierde nada);
#   3. cuanto tarda hoy cargar, escribir y sacar la huella, y cuantas filas de materiales saldrian;
#   4. LINEA BASE: lo que cambia con solo pasar la partida por el juego (importar -> exportar). No es
#      un fallo: es lo que el juego ya cambia al cargar (migraciones, fecha...), y la BD se compara
#      contra lo exportado, no contra el fichero.
extends Node

const POR_DEFECTO := "res://tools/huellas/mundo_ref.tres"
const TMP := "user://prueba_huella_tmp.tres"


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	var fichero: String = OS.get_environment("HUELLA_FICHERO")
	if fichero == "":
		fichero = POR_DEFECTO
	print("Fichero: %s (%.2f MB)" % [fichero, _mb(fichero)])
	var fallos: int = 0

	var t0: int = Time.get_ticks_msec()
	var a = ResourceLoader.load(fichero, "", ResourceLoader.CACHE_MODE_IGNORE)
	var t_cargar: int = Time.get_ticks_msec() - t0
	if not (a is SaveData):
		print("MAL: no es un SaveData")
		get_tree().quit(1)
		return
	var b = ResourceLoader.load(fichero, "", ResourceLoader.CACHE_MODE_IGNORE)
	t0 = Time.get_ticks_msec()
	var ha: Dictionary = HuellaSave.de(a)
	var t_huella: int = Time.get_ticks_msec() - t0
	var hb: Dictionary = HuellaSave.de(b)
	print("Cargar: %d ms | huella: %d ms | objetos compartidos: %d" % [t_cargar, t_huella, ha["_compartidos"].size()])

	# 1. Determinista.
	var dif: Array = HuellaSave.diferencias(ha, hb)
	if not dif.is_empty():
		fallos += 1
		print("MAL: la huella cambia cargando dos veces el mismo fichero:")
		for l in dif.slice(0, 20):
			print("   ", l)

	# 2. La ida y vuelta de hoy (ResourceSaver).
	t0 = Time.get_ticks_msec()
	ResourceSaver.save(a, TMP)
	var t_escribir: int = Time.get_ticks_msec() - t0
	print("Escribirlo entero: %d ms (%.2f MB)" % [t_escribir, _mb(TMP)])
	var c = ResourceLoader.load(TMP, "", ResourceLoader.CACHE_MODE_IGNORE)
	dif = HuellaSave.diferencias(ha, HuellaSave.de(c))
	if not dif.is_empty():
		fallos += 1
		print("MAL: escribir y releer con Godot cambia la huella:")
		for l in dif.slice(0, 20):
			print("   ", l)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))

	# 3. Cuantas filas de materiales saldrian (una por material+calidad+talla, por sitio).
	_contar(a)

	# 4. Linea base: importar -> exportar.
	Game.importar_partida(a)
	t0 = Time.get_ticks_msec()
	var e: SaveData = Game.exportar_partida()
	print("Exportar (Game -> SaveData): %d ms" % (Time.get_ticks_msec() - t0))
	dif = HuellaSave.diferencias(HuellaSave.de(b), HuellaSave.de(e), 100000)
	var por_campo: Dictionary = {}
	for l in dif:
		var campo: String = String(l).get_slice(":", 0).trim_prefix(".").get_slice(".", 0).get_slice("[", 0).get_slice("{", 0)
		por_campo[campo] = int(por_campo.get(campo, 0)) + 1
	print("LINEA BASE (lo que ya cambia al pasar por el juego): %d diferencias" % dif.size())
	for campo in por_campo:
		print("   %s: %d" % [campo, por_campo[campo]])
	for l in dif.slice(0, 30):
		print("   . ", l)

	print("FIN: %s" % ("TODO BIEN" if fallos == 0 else "%d MAL" % fallos))
	get_tree().quit(1 if fallos > 0 else 0)


func _contar(s: SaveData) -> void:
	var sitios: Dictionary = {"bolsa": s.materiales, "almacen": s.almacen_materiales, "carbon": s.carbon}
	for id in s.jugadores:
		var jd = s.jugadores[id]
		sitios["jugador %s bolsa" % String(id).left(6)] = jd.materiales
		sitios["jugador %s carbon" % String(id).left(6)] = jd.carbon
	var unidades: int = 0
	var filas: int = 0
	for nombre in sitios:
		var claves: Dictionary = {}
		for m in sitios[nombre]:
			if m is MaterialItem:
				claves["%s|%d|%s" % [m.data.resource_path if m.data else "?", int(m.calidad), str(m.cm)]] = true
		unidades += sitios[nombre].size()
		filas += claves.size()
		if not sitios[nombre].is_empty():
			print("   %s: %d unidades -> %d filas" % [nombre, sitios[nombre].size(), claves.size()])
	print("Materiales: %d unidades -> %d filas en la BD" % [unidades, filas])


func _mb(ruta: String) -> float:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return 0.0
	return f.get_length() / 1048576.0
