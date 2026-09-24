# PARCHE DE PITY (24/09/2026, pedido por el jefe): a su hermano se le perdieron las tiradas del banner de
# La hora del eclipse (id "ataque") de AGIRATO OCHINAN. Se le dejan los contadores como estaban en su PC:
# mitico 120/200, legendario 20/100, epico 20/50, sin garantizados pendientes, y +110 al total.
#
#   EN SECO (por defecto): lee la copia de este PC, enseña antes y despues y NO guarda ni sube nada.
#   PARCHE_DE_VERDAD=1: abre el mundo por su camino normal (baja la nube y coge el cerrojo; si otro lo
#   tiene abierto NO hace nada), guarda una copia de seguridad, cambia SOLO eso, guarda, sube y suelta.
#     PARCHE_DE_VERDAD=1 godot --headless --path . res://tools/parche_pity.tscn
extends Node

const CLAVE := "1db522c2d6f5a2af06928ebb"
const UID := "8d3fc1465119c53128c69d18-118192909-6"   # Agirato ochinan
const BANNER := &"ataque"                             # La hora del eclipse
const CONTADORES := {3: 20, 4: 20, 5: 120}            # EPICO, LEGENDARIO, MITICO
const SUMA_TOTAL := 110


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	var de_verdad: bool = OS.get_environment("PARCHE_DE_VERDAD") == "1"
	var ruta: String = Mundos.ruta(CLAVE)
	if de_verdad:
		var e: Dictionary = Mundos.entrada(CLAVE)
		var r: Dictionary = await Mundos.abrir(CLAVE, String(e.get("contrasena", "")))
		if not bool(r.get("ok", false)) or String(r.get("resultado", "")) != "host":
			print("[parche] NO se toca nada: el mundo no se ha podido abrir para mi (%s %s)" % [
				String(r.get("resultado", "")), String(r.get("mensaje", ""))])
			get_tree().quit(1)
			return
		print("[parche] mundo abierto con el cerrojo; copia de la nube en %s" % ruta)
		DirAccess.make_dir_recursive_absolute("user://respaldos")
		var respaldo: String = "user://respaldos/%s_antes_del_pity_%s.tres" % [CLAVE,
			Time.get_datetime_string_from_system().replace(":", "-")]
		var err_c: int = DirAccess.copy_absolute(ProjectSettings.globalize_path(ruta),
			ProjectSettings.globalize_path(respaldo))
		print("[parche] copia de seguridad: %s (%s)" % [ProjectSettings.globalize_path(respaldo),
			"ok" if err_c == OK else "ERROR %d" % err_c])
		if err_c != OK:
			await Nube.cerrar(SaveIO.bytes_de_ruta(ruta), Mundos._meta_de(CLAVE))
			print("[parche] sin copia de seguridad no se toca: cerrojo soltado sin cambios")
			get_tree().quit(1)
			return

	var d = ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (d is SaveData):
		print("[parche] el mundo no se puede leer")
		get_tree().quit(1)
		return
	var s: SaveData = d
	var hechos: Array = []   # los PersonajeData ya parcheados (dos jugadores pueden apuntar al MISMO)
	var todos: Array = []
	for k in s.jugadores:
		if s.jugadores[k] is JugadorData:
			todos.append_array((s.jugadores[k] as JugadorData).personajes)
	todos.append_array(s.plantilla)
	for pj in todos:
		if not (pj is PersonajeData) or String((pj as PersonajeData).uid) != UID or hechos.has(pj):
			continue
		var p: PersonajeData = pj
		hechos.append(p)
		print("  ANTES   %s  eclipse %s  total %d" % [p.nombre, str(p.gacha_pity.get(BANNER, {})), p.gacha_total])
		var est: Dictionary = p.gacha_pity.get(BANNER, {})
		est["n"] = CONTADORES.duplicate()
		est["cola"] = []
		p.gacha_pity[BANNER] = est
		p.gacha_total += SUMA_TOTAL
		print("  DESPUES %s  eclipse %s  total %d" % [p.nombre, str(p.gacha_pity.get(BANNER, {})), p.gacha_total])
	if hechos.is_empty():
		print("[parche] no esta Agirato (uid %s) en el mundo: no se toca nada" % UID)
		if de_verdad:
			await Nube.cerrar(SaveIO.bytes_de_ruta(ruta), Mundos._meta_de(CLAVE))
		get_tree().quit(1)
		return
	if not de_verdad:
		print("[parche] EN SECO: no se ha guardado ni subido nada (%d personaje(s) a cambiar)" % hechos.size())
		get_tree().quit(0)
		return

	var err: int = ResourceSaver.save(s, ruta)
	if err != OK:
		print("[parche] no se pudo guardar (error %d): se suelta el cerrojo SIN cambios" % err)
		get_tree().quit(1)
		return
	var sube: Dictionary = await Nube.cerrar(SaveIO.bytes_de_ruta(ruta), Mundos._meta_de(CLAVE))
	if bool(sube.get("ok", false)):
		Mundos._escribir_entrada(CLAVE, {"pendiente": false})
		print("[parche] HECHO: guardado, subido a la nube y cerrojo soltado")
		get_tree().quit(0)
	else:
		Mundos._escribir_entrada(CLAVE, {"pendiente": true})
		print("[parche] guardado en este PC pero NO subido (%s): queda pendiente de subir" % String(sube.get("mensaje", "")))
		get_tree().quit(1)
