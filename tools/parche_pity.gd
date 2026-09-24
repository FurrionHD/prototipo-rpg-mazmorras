# PARCHE DE PITY (24/09/2026, pedido por el jefe): a Agirato ochinan se le perdieron tiradas del banner de
# La hora del eclipse (id "ataque"). Se le dejan los contadores como estaban en su PC: mitico 120/200,
# legendario 20/100, epico 20/50, sin garantizados pendientes, y +110 al total.
#
# El mundo se abre DIRECTAMENTE contra la nube (Nube.abrir: baja el save y coge el cerrojo; si otro lo tiene
# abierto, NO hace nada), sin apuntarlo en la lista de mundos de este PC. Antes de cambiar nada comprueba que
# dentro estan los personajes que tienen que estar (PARCHE_DEBEN_ESTAR) y guarda una copia de seguridad.
#   EN SECO (por defecto): abre, enseña antes y despues, y suelta el mundo SUBIENDO LOS MISMOS BYTES que bajo.
#   PARCHE_DE_VERDAD=1: cambia SOLO eso, sube y suelta.
#     PARCHE_MUNDO=<codigo> PARCHE_CONTRASENA=<contraseña> [PARCHE_DE_VERDAD=1]
#       godot --headless --path . res://tools/parche_pity.tscn
extends Node

const NOMBRE := "Agirato ochinan"
const DEBEN_ESTAR := ["Daniel", "Agirato ochinan", "Eufrasio S. Loza"]
const BANNER := &"ataque"                             # La hora del eclipse
const CONTADORES := {3: 20, 4: 20, 5: 120}            # EPICO, LEGENDARIO, MITICO
const SUMA_TOTAL := 110


func _ready() -> void:
	call_deferred("_correr")


func _salir(codigo: int) -> void:
	get_tree().quit(codigo)


func _correr() -> void:
	var de_verdad: bool = OS.get_environment("PARCHE_DE_VERDAD") == "1"
	var id: String = OS.get_environment("PARCHE_MUNDO")
	var pw: String = OS.get_environment("PARCHE_CONTRASENA")
	if id == "":
		print("[parche] falta PARCHE_MUNDO")
		_salir(1)
		return
	# PARCHE_COMO: presentarse ante la nube con OTRA identidad tuya (la del PC que juega ese mundo), solo en
	# memoria (Identidad.id_cerrojo, lo que usa la sala): el fichero de identidad de este PC no se toca.
	var como: String = OS.get_environment("PARCHE_COMO")
	if como != "":
		Identidad.id_cerrojo = como
		print("[parche] me presento ante la nube como %s (solo en memoria)" % como)
	var r: Dictionary = await Nube.abrir(id, pw, [])
	if not bool(r.get("ok", false)) or String(r.get("resultado", "")) != "host":
		print("[parche] NO se toca nada: la nube no me da el mundo (%s %s %s)" % [String(r.get("resultado", "")),
			String(r.get("error", "")), String(r.get("mensaje", ""))])
		_salir(1)
		return
	var bytes: PackedByteArray = r.get("save", PackedByteArray())
	print("[parche] mundo %s abierto con el cerrojo (%d bytes)" % [id, bytes.size()])
	DirAccess.make_dir_recursive_absolute("user://respaldos")
	var sello: String = Time.get_datetime_string_from_system().replace(":", "-")
	var respaldo: String = "user://respaldos/%s_antes_del_pity_%s.tres" % [id, sello]
	var trabajo: String = "user://respaldos/%s_trabajo.tres" % id
	if bytes.is_empty() or not SaveIO.escribir_bytes(respaldo, bytes) or not SaveIO.escribir_bytes(trabajo, bytes):
		print("[parche] no se pudo guardar la copia de seguridad: se suelta SIN cambios")
		await Nube.cerrar(bytes, {})
		_salir(1)
		return
	print("[parche] copia de seguridad: %s" % ProjectSettings.globalize_path(respaldo))

	var d = ResourceLoader.load(trabajo, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (d is SaveData):
		print("[parche] el mundo no se puede leer: se suelta SIN cambios")
		await Nube.cerrar(bytes, {})
		_salir(1)
		return
	var s: SaveData = d
	# La cabecera de verdad (nombre, nivel, miembros...): soltar con {} borraria el resumen de "Mis mundos".
	var todos: Array = []
	for k in s.jugadores:
		if s.jugadores[k] is JugadorData:
			var j: JugadorData = s.jugadores[k]
			var noms: Array = []
			for pj in j.personajes:
				if pj is PersonajeData:
					noms.append((pj as PersonajeData).nombre)
			print("  JUGADOR %s (id %s): %s" % [j.nombre_visible, String(k), ", ".join(noms)])
			todos.append_array(j.personajes)
	todos.append_array(s.plantilla)
	var nombres: Array = []
	for pj in todos:
		if pj is PersonajeData and not nombres.has((pj as PersonajeData).nombre):
			nombres.append((pj as PersonajeData).nombre)
	for n in DEBEN_ESTAR:
		if not nombres.has(n):
			print("[parche] NO esta '%s' en este mundo: no es el que buscamos. Se suelta SIN cambios" % n)
			await Nube.cerrar(bytes, Mundos._cab_de(s))
			_salir(1)
			return

	var hechos: Array = []
	for pj in todos:
		if not (pj is PersonajeData) or (pj as PersonajeData).nombre != NOMBRE or hechos.has(pj):
			continue
		var p: PersonajeData = pj
		hechos.append(p)
		print("  ANTES   %s (uid %s)  eclipse %s  total %d" % [p.nombre, String(p.uid),
			str(p.gacha_pity.get(BANNER, {})), p.gacha_total])
		var est: Dictionary = p.gacha_pity.get(BANNER, {})
		est["n"] = CONTADORES.duplicate()
		est["cola"] = []
		p.gacha_pity[BANNER] = est
		p.gacha_total += SUMA_TOTAL
		print("  DESPUES %s (uid %s)  eclipse %s  total %d" % [p.nombre, String(p.uid),
			str(p.gacha_pity.get(BANNER, {})), p.gacha_total])

	if not de_verdad:
		await Nube.cerrar(bytes, Mundos._cab_de(s))
		print("[parche] EN SECO: soltado con los MISMOS bytes que baje (%d personaje(s) a cambiar)" % hechos.size())
		_salir(0)
		return
	var err: int = ResourceSaver.save(s, trabajo)
	if err != OK:
		await Nube.cerrar(bytes, Mundos._cab_de(s))
		print("[parche] no se pudo guardar (error %d): soltado SIN cambios" % err)
		_salir(1)
		return
	var nuevos: PackedByteArray = SaveIO.bytes_de_ruta(trabajo)
	var sube: Dictionary = await Nube.cerrar(nuevos, Mundos._cab_de(s))
	if bool(sube.get("ok", false)):
		print("[parche] HECHO: subido a la nube y cerrojo soltado (%d bytes)" % nuevos.size())
		_salir(0)
	else:
		print("[parche] NO se subio (%s): el mundo queda como estaba en la nube" % String(sube.get("mensaje", "")))
		_salir(1)
