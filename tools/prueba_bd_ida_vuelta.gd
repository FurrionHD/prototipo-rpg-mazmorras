# BD FASE 1: partida -> FILAS -> partida (BDFilas), sin perder NADA.
#   godot --headless --path . res://tools/prueba_bd_ida_vuelta.tscn
#   HUELLA_FICHERO=<ruta a un .tres>  (por defecto el mundo de referencia de tools/huellas)
# Mira:
#   1. que la partida montada desde las filas tiene la MISMA huella que la original (HuellaSave);
#   2. que sacar las filas dos veces del mismo estado da las MISMAS filas (si no, cada guardado
#      reescribiria filas sin motivo);
#   3. que las filas de la partida ya montada salen iguales (los ids sobreviven a la vuelta);
#   4. cuanto tarda y cuantas filas salen.
extends Node

const POR_DEFECTO := "res://tools/huellas/mundo_ref.tres"


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	var fichero: String = OS.get_environment("HUELLA_FICHERO")
	if fichero == "":
		fichero = POR_DEFECTO
	var s = ResourceLoader.load(fichero, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (s is SaveData):
		print("MAL: no es un SaveData: %s" % fichero)
		get_tree().quit(1)
		return
	print("Fichero: %s" % fichero.get_file())
	# Lo que se guarda es lo EXPORTADO (el juego ya cambia cosas al cargar: ver prueba_huella_save).
	Game.importar_partida(s)
	s = Game.exportar_partida()
	var fallos: int = 0

	var ids := BDFilas.Ids.new()
	var t0: int = Time.get_ticks_msec()
	var filas: Dictionary = BDFilas.a_filas(s, ids)
	var t_ida: int = Time.get_ticks_msec() - t0
	var bytes: int = 0
	for tabla in filas:
		for k in filas[tabla]:
			bytes += String(k).length() + str(filas[tabla][k]).length()
	print("Filas: campos %d, objetos %d, contables %d (%.2f MB de texto) | sacarlas: %d ms" % [
		filas["campos"].size(), filas["objetos"].size(), filas["contables"].size(), bytes / 1048576.0, t_ida])

	# 2. Estable.
	t0 = Time.get_ticks_msec()
	var otra: Dictionary = BDFilas.a_filas(s, ids)
	print("Sacarlas otra vez (ya con ids): %d ms" % (Time.get_ticks_msec() - t0))
	var cambian: Array = _cambian(filas, otra)
	if not cambian.is_empty():
		fallos += 1
		print("MAL: el mismo estado da %d filas distintas, p.ej. %s" % [cambian.size(), cambian.slice(0, 5)])

	# 1. Vuelta.
	var ids2 := BDFilas.Ids.new()
	t0 = Time.get_ticks_msec()
	var v: SaveData = BDFilas.de_filas(filas, ids2)
	print("Montar la partida desde las filas: %d ms" % (Time.get_ticks_msec() - t0))
	var h_s: Dictionary = HuellaSave.de(s)
	var h_v: Dictionary = HuellaSave.de(v)
	var dif: Array = HuellaSave.diferencias(h_s, h_v, 40)
	var c_v: Dictionary = {}
	for c in h_v["_compartidos"]:
		c_v[c] = true
	var perdidos: Array = h_s["_compartidos"].filter(func(c): return not c_v.has(c))
	if not perdidos.is_empty():
		print("Compartidos que dejan de serlo: %d, p.ej.:" % perdidos.size())
		for c in perdidos.slice(0, 8):
			print("   ", c)
	if not dif.is_empty():
		fallos += 1
		print("MAL: la partida montada desde las filas NO es la misma:")
		for l in dif:
			print("   ", l)

	# 3. Los ids sobreviven.
	cambian = _cambian(filas, BDFilas.a_filas(v, ids2))
	if not cambian.is_empty():
		fallos += 1
		print("MAL: tras montarla, %d filas salen distintas, p.ej. %s" % [cambian.size(), cambian.slice(0, 5)])

	print("FIN: %s" % ("TODO BIEN" if fallos == 0 else "%d MAL" % fallos))
	get_tree().quit(1 if fallos > 0 else 0)


func _cambian(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for tabla in a:
		for k in a[tabla]:
			if not b[tabla].has(k) or str(b[tabla][k]) != str(a[tabla][k]):
				out.append("%s:%s" % [tabla, k])
		for k in b[tabla]:
			if not a[tabla].has(k):
				out.append("%s:+%s" % [tabla, k])
	return out
