# BD FASE 1: la partida en su fichero SQLite (PartidaBD + MigracionBD).
#   godot --headless --path . res://tools/prueba_bd_partida.tscn
#   HUELLA_FICHERO=<ruta a un .tres>  (por defecto el mundo de referencia de tools/huellas)
# Trabaja en user://bd_prueba/ con una COPIA: nunca toca partidas de verdad.
# Mira:
#   1. que migrar el .tres da una BD que, leida del fichero, tiene la MISMA huella;
#   2. que la copia de seguridad queda hecha y el .tres original intacto;
#   3. que guardar otra vez lo mismo no escribe NADA, y cambiar el dinero escribe 1-2 filas (y sube rev);
#   4. que una partida que no se puede leer NO se migra;
#   5. cuanto tarda cada cosa.
extends Node

const POR_DEFECTO := "res://tools/huellas/mundo_ref.tres"
const DIR := "user://bd_prueba"


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	var fichero: String = OS.get_environment("HUELLA_FICHERO")
	if fichero == "":
		fichero = POR_DEFECTO
	_limpiar()
	DirAccess.make_dir_recursive_absolute(DIR)
	var tres: String = DIR + "/partida.tres"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(fichero), ProjectSettings.globalize_path(tres))
	var bytes_antes: PackedByteArray = FileAccess.get_file_as_bytes(tres)
	var bd_ruta: String = DIR + "/partida.sqlite"
	var fallos: int = 0

	# 1. Migrar.
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = MigracionBD.migrar(tres, bd_ruta)
	print("Migrar: %s en %d ms (%s)" % ["OK" if r["ok"] else "NO", Time.get_ticks_msec() - t0, r["motivo"]])
	if not r["ok"]:
		fallos += 1
		print("MAL: no se ha migrado. Su informe:")
		var inf: String = MigracionBD.RESPALDOS + "/partida_NO_MIGRADA.txt"
		if FileAccess.file_exists(inf):
			for l in FileAccess.get_file_as_string(inf).split("
").slice(0, 30):
				print("   ", l.left(220))
	var tam: int = FileAccess.get_file_as_bytes(bd_ruta).size()
	print("Tamaño de la BD: %.2f MB (el .tres: %.2f MB)" % [tam / 1048576.0, bytes_antes.size() / 1048576.0])

	# 2. Copia y original.
	if not FileAccess.file_exists(MigracionBD.RESPALDOS + "/partida.tres"):
		fallos += 1
		print("MAL: no hay copia de seguridad")
	if FileAccess.get_file_as_bytes(tres) != bytes_antes:
		fallos += 1
		print("MAL: el .tres original ha cambiado")

	# 1b. Leer de la BD y comparar con el .tres.
	var bd := PartidaBD.new()
	bd.abrir(bd_ruta)
	var ids := BDFilas.Ids.new()
	t0 = Time.get_ticks_msec()
	var filas: Dictionary = bd.leer()
	var t_leer: int = Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	var s: SaveData = BDFilas.de_filas(filas, ids)
	print("Leer la BD: %d ms | montar la partida: %d ms" % [t_leer, Time.get_ticks_msec() - t0])
	var original = ResourceLoader.load(tres, "", ResourceLoader.CACHE_MODE_IGNORE)
	var dif: Array = HuellaSave.diferencias(HuellaSave.de(original), HuellaSave.de(s), 20)
	if not dif.is_empty():
		fallos += 1
		print("MAL: la partida leida de la BD no es la del .tres:")
		for l in dif:
			print("   ", l)

	# 3. Guardar lo mismo = nada; cambiar el dinero = poco.
	var rev0: int = bd.rev
	t0 = Time.get_ticks_usec()
	var n: int = bd.escribir(BDFilas.a_filas(s, ids))
	print("Guardar sin cambios: %d filas, %d us (escribir)" % [n, Time.get_ticks_usec() - t0])
	if n != 0 or bd.rev != rev0:
		fallos += 1
		print("MAL: guardar lo mismo ha tocado %d filas (rev %d -> %d)" % [n, rev0, bd.rev])
	s.money += 123
	var f2: Dictionary = BDFilas.a_filas(s, ids)
	t0 = Time.get_ticks_usec()
	n = bd.escribir(f2)
	print("Guardar con +123 de dinero: %d filas en %d us" % [n, Time.get_ticks_usec() - t0])
	if n < 1 or n > 2 or bd.rev != rev0 + 1:
		fallos += 1
		print("MAL: cambiar el dinero ha tocado %d filas (rev %d -> %d)" % [n, rev0, bd.rev])
	bd.cerrar()
	bd.abrir(bd_ruta)
	var s2: SaveData = BDFilas.de_filas(bd.leer(), BDFilas.Ids.new())
	if s2.money != s.money or bd.rev != rev0 + 1:
		fallos += 1
		print("MAL: al reabrir, dinero %d (esperado %d), rev %d" % [s2.money, s.money, bd.rev])
	bd.cerrar()

	# 4. Una partida ilegible no se migra.
	var mala: String = DIR + "/mala.tres"
	var fm := FileAccess.open(mala, FileAccess.WRITE)
	fm.store_string("esto no es una partida")
	fm.close()
	r = MigracionBD.migrar(mala, DIR + "/mala.sqlite")
	if r["ok"] or PartidaBD.existe(DIR + "/mala.sqlite"):
		fallos += 1
		print("MAL: una partida ilegible se ha migrado")

	_limpiar()
	print("FIN: %s" % ("TODO BIEN" if fallos == 0 else "%d MAL" % fallos))
	get_tree().quit(1 if fallos > 0 else 0)


func _limpiar() -> void:
	for d in [DIR, MigracionBD.RESPALDOS]:
		var abs_d: String = ProjectSettings.globalize_path(d)
		if not DirAccess.dir_exists_absolute(abs_d):
			continue
		for f in DirAccess.get_files_at(abs_d):
			if d == MigracionBD.RESPALDOS and not f.begins_with("partida") and not f.begins_with("mala"):
				continue   # en respaldos solo lo de esta prueba
			DirAccess.remove_absolute(abs_d + "/" + f)
