# BD FASE 1: una RANURA de punta a punta con su base de datos (Perfil + PartidaBD + MigracionBD).
#   godot --headless --path . res://tools/prueba_bd_ranura.tscn
#   HUELLA_FICHERO=<ruta a un .tres de ranura>  (por defecto el mundo de referencia de tools/huellas)
# Usa la RANURA 97 (no existe en el juego): las ranuras de verdad no se tocan. La borra al acabar.
# Mira:
#   1. que una ranura vieja se migra al mirarla, queda con su copia de seguridad y su .tres intacto;
#   2. que se carga desde la BD con la misma huella que el .tres;
#   3. que guardar (entero y a trocitos, como el guardado continuo) solo escribe lo que cambia, y lo
#      cambiado se lee al volver a abrirla;
#   4. que borrar la ranura quita su BD y su .tres.
extends Node

const POR_DEFECTO := "res://tools/huellas/mundo_ref.tres"
const SLOT := 97


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	var fichero: String = OS.get_environment("HUELLA_FICHERO")
	if fichero == "":
		fichero = POR_DEFECTO
	_limpiar()
	DirAccess.copy_absolute(ProjectSettings.globalize_path(fichero), ProjectSettings.globalize_path(Perfil.ruta(SLOT)))
	var bytes_antes: PackedByteArray = FileAccess.get_file_as_bytes(Perfil.ruta(SLOT))
	var fallos: int = 0

	# 1. Migrar al mirarla.
	var t0: int = Time.get_ticks_msec()
	var info: Dictionary = Perfil.inspeccionar(SLOT)
	print("Mirar la ranura (con migracion): %d ms" % (Time.get_ticks_msec() - t0))
	if not Perfil.usa_bd(SLOT) or int(info["estado"]) != SaveIO.OK:
		fallos += 1
		print("MAL: la ranura no ha pasado a la BD (estado %d)" % int(info["estado"]))
	if not FileAccess.file_exists(MigracionBD.RESPALDOS + "/slot_%d.tres" % SLOT):
		fallos += 1
		print("MAL: no hay copia de seguridad")
	if FileAccess.get_file_as_bytes(Perfil.ruta(SLOT)) != bytes_antes:
		fallos += 1
		print("MAL: el .tres ha cambiado")
	t0 = Time.get_ticks_msec()
	Perfil.inspeccionar(SLOT)
	print("Mirarla otra vez (ya con BD): %d ms" % (Time.get_ticks_msec() - t0))

	# 2. Cargar.
	var original = ResourceLoader.load(fichero, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not Perfil.cargar(SLOT):
		fallos += 1
		print("MAL: no carga")
	var dif: Array = HuellaSave.diferencias(HuellaSave.de(original), HuellaSave.de(Perfil.inspeccionar(SLOT)["datos"]), 10)
	if not dif.is_empty():
		fallos += 1
		print("MAL: la BD no tiene lo del .tres: ", dif)

	# 3a. Guardar entero.
	var rev0: int = Perfil._bd.rev
	t0 = Time.get_ticks_msec()
	Perfil.guardar(SLOT)
	print("Guardar entero (el primero tras cargar): %d ms, rev %d -> %d" % [Time.get_ticks_msec() - t0, rev0, Perfil._bd.rev])
	Game.money += 777
	var dinero: int = Game.money
	t0 = Time.get_ticks_msec()
	Perfil.guardar(SLOT)
	print("Guardar entero con +777: %d ms" % (Time.get_ticks_msec() - t0))

	# 3b. A trocitos, como el continuo.
	Game.money += 1
	dinero = Game.money
	var v := BDFilas.Volcado.new(Game.exportar_partida(), Perfil._ids)
	var pasos: int = 0
	var peor: int = 0
	while true:
		var tp: int = Time.get_ticks_usec()
		var fin: bool = v.paso(Perfil.PRESUPUESTO_US)
		peor = maxi(peor, Time.get_ticks_usec() - tp)
		pasos += 1
		if fin:
			break
	t0 = Time.get_ticks_usec()
	var n: int = Perfil._bd.escribir(v.out)
	print("A trocitos: %d pasos (el peor %d us) + escribir %d filas en %d us" % [pasos, peor, n, Time.get_ticks_usec() - t0])
	if n < 1 or n > 6:
		fallos += 1
		print("MAL: +1 de dinero ha escrito %d filas" % n)
	if peor > Perfil.PRESUPUESTO_US + 4000:
		fallos += 1
		print("MAL: un paso del guardado ha tardado %d us" % peor)

	# Reabrir: lo cambiado esta.
	Perfil._cerrar_bd()
	var leida: SaveData = Perfil.inspeccionar(SLOT)["datos"]
	if leida == null or leida.money != dinero:
		fallos += 1
		print("MAL: al reabrir el dinero es %s (esperado %d)" % [str(leida.money) if leida else "?", dinero])

	# 4. Borrar.
	Perfil.borrar(SLOT)
	if Perfil.existe(SLOT) or PartidaBD.existe(Perfil.ruta_bd(SLOT)):
		fallos += 1
		print("MAL: la ranura sigue ahi tras borrarla")

	Perfil.ranura_actual = 0
	_limpiar()
	print("FIN: %s" % ("TODO BIEN" if fallos == 0 else "%d MAL" % fallos))
	get_tree().quit(1 if fallos > 0 else 0)


func _limpiar() -> void:
	Perfil.borrar(SLOT)
	var copia: String = MigracionBD.RESPALDOS + "/slot_%d.tres" % SLOT
	if FileAccess.file_exists(copia):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(copia))
