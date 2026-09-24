# SOLO LECTURA: el pity del gacha de cada personaje de cada jugador en un fichero de mundo (o de ranura).
#   PITY_FICHERO=C:/ruta/al/mundo.tres godot --headless --path . res://tools/ver_pity_mundo.tscn
# Sin PITY_FICHERO lee el mundo compartido de este PC (user://mundos/*.tres).
extends Node


func _ready() -> void:
	var rutas: Array = []
	var pedida: String = OS.get_environment("PITY_FICHERO")
	if pedida != "":
		rutas.append(pedida)
	else:
		var dir := DirAccess.open("user://mundos")
		if dir != null:
			for f in dir.get_files():
				if f.ends_with(".tres"):
					rutas.append("user://mundos/" + f)
	for ruta in rutas:
		var d = ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (d is SaveData):
			print("[pity] %s no es una partida" % ruta)
			continue
		var s: SaveData = d
		print("=== %s  (guardado %s) ===" % [ruta, s.fecha])
		# Un mundo compartido: un JugadorData por persona.
		for k in s.jugadores:
			var jd = s.jugadores[k]
			if jd is JugadorData:
				print("  JUGADOR %s  (id %s)" % [(jd as JugadorData).nombre_visible, String(k)])
				for pj in (jd as JugadorData).personajes:
					_pj(pj)
		# Una ranura suelta (o el lider de los campos planos de un mundo viejo).
		print("  LIDER DE LOS CAMPOS PLANOS: %s  pity %s  n50 %d  n200 %d  total %d" % [
			s.nombre, str(s.player_gacha_pity), s.player_gacha_n50, s.player_gacha_n200, s.player_gacha_total])
		for pj in s.plantilla:
			_pj(pj)
		# El historial (lo ultimo primero): cuantas tiradas de cada personaje y cuando.
		var por_quien: Dictionary = {}
		for e in s.gacha_historial:
			var q: String = String((e as Dictionary).get("quien", "?"))
			por_quien[q] = int(por_quien.get(q, 0)) + 1
		print("  HISTORIAL: %d entradas; por personaje: %s" % [s.gacha_historial.size(), str(por_quien)])
		for e in s.gacha_historial.slice(0, 12):
			var ee: Dictionary = e
			print("    %s  %-16s rareza %d  pity %d  %s" % [
				Time.get_datetime_string_from_unix_time(int(ee.get("cuando", 0)) + 7200, true),
				String(ee.get("quien", "")), int(ee.get("rareza", -1)), int(ee.get("pity", 0)),
				String(ee.get("nombre", ""))])
	get_tree().quit()


func _pj(pj) -> void:
	if not (pj is PersonajeData):
		return
	var p: PersonajeData = pj
	print("    %-18s uid %-14s pity %s  n50 %d  n200 %d  total %d" % [p.nombre, String(p.uid),
		str(p.gacha_pity), p.gacha_n50, p.gacha_n200, p.gacha_total])
