# ============================================================
#  migracion_bd.gd
#  PASAR UNA PARTIDA VIEJA (.tres) A SU BASE DE DATOS, SIN PERDER NADA.
#
#    1. Copia de seguridad del .tres en user://respaldos/pre_bd/ (si ya habia una, no se pisa).
#       El .tres original NO se toca ni se borra.
#    2. Se lee, se pasa a filas y se escribe en un fichero APARTE (<bd>.migrando).
#    3. Se vuelve a LEER de ese fichero y se compara la huella (HuellaSave) con la del .tres.
#    4. Solo si sale IDENTICA el fichero pasa a ser la BD de esa partida. Si hay UNA diferencia, se
#       borra, se escribe un informe al lado de la copia y la partida sigue con su .tres como hasta
#       ahora (quien llama mira "ok").
# ============================================================
class_name MigracionBD
extends RefCounted

const RESPALDOS := "user://respaldos/pre_bd"


## {"ok": bool, "motivo": String}. `ruta_tres` = la partida vieja; `ruta_bd` = donde va su BD.
static func migrar(ruta_tres: String, ruta_bd: String) -> Dictionary:
	if PartidaBD.existe(ruta_bd):
		return {"ok": true, "motivo": "ya estaba migrada"}
	var info: Dictionary = SaveIO.inspeccionar_ruta(ruta_tres)
	if int(info["estado"]) != SaveIO.OK:
		# Una partida que este build no entiende no se toca (ni para migrarla).
		return {"ok": false, "motivo": "no se puede leer: %s" % SaveIO.motivo_texto(info)}
	var s: SaveData = info["datos"]

	# 1. Copia de seguridad.
	DirAccess.make_dir_recursive_absolute(RESPALDOS)
	var copia: String = "%s/%s" % [RESPALDOS, ruta_tres.get_file()]
	if not FileAccess.file_exists(copia):
		var err: int = DirAccess.copy_absolute(ProjectSettings.globalize_path(ruta_tres), ProjectSettings.globalize_path(copia))
		if err != OK:
			return {"ok": false, "motivo": "no se pudo hacer la copia de seguridad (error %d)" % err}

	# 2. A un fichero aparte.
	var tmp: String = ruta_bd + ".migrando"
	PartidaBD.borrar(tmp)
	var t0: int = Time.get_ticks_msec()
	var bd := PartidaBD.new()
	if not bd.abrir(tmp):
		return {"ok": false, "motivo": "no se pudo crear la base de datos"}
	if bd.escribir(BDFilas.a_filas(s, BDFilas.Ids.new())) < 0:
		bd.cerrar()
		PartidaBD.borrar(tmp)
		return {"ok": false, "motivo": "no se pudo escribir la base de datos"}
	bd.cerrar()

	# 3. Releer DEL FICHERO (no de memoria) y comparar.
	bd = PartidaBD.new()
	bd.abrir(tmp)
	var vuelta: SaveData = BDFilas.de_filas(bd.leer(), BDFilas.Ids.new())
	bd.cerrar()
	var dif: Array = HuellaSave.diferencias(HuellaSave.de(s), HuellaSave.de(vuelta), 200)
	if not dif.is_empty():
		PartidaBD.borrar(tmp)
		var informe: String = "%s/%s_NO_MIGRADA.txt" % [RESPALDOS, ruta_tres.get_file().get_basename()]
		var f := FileAccess.open(informe, FileAccess.WRITE)
		if f != null:
			f.store_string("La partida %s NO se ha pasado a la base de datos: al releerla salian %d diferencias.\n" % [ruta_tres, dif.size()])
			f.store_string("Sigue jugandose con su .tres como siempre. Diferencias:\n")
			for l in dif:
				f.store_line(String(l))
			f.close()
		push_warning("[bd] %s NO migrada: %d diferencias (informe en %s)" % [ruta_tres, dif.size(), informe])
		return {"ok": false, "motivo": "%d diferencias al releerla" % dif.size()}

	# 4. Buena: pasa a ser su BD (renombrar el fichero ya cerrado; WAL ya volcado al cerrar).
	PartidaBD.borrar(ruta_bd)
	var err2: int = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(ruta_bd))
	for extra in ["-wal", "-shm"]:
		if FileAccess.file_exists(tmp + extra):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp + extra))
	if err2 != OK:
		PartidaBD.borrar(tmp)
		return {"ok": false, "motivo": "no se pudo colocar la base de datos (error %d)" % err2}
	print("[bd] %s migrada a %s en %d ms" % [ruta_tres, ruta_bd, Time.get_ticks_msec() - t0])
	return {"ok": true, "motivo": ""}
