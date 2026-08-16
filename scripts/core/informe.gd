class_name Informe
extends RefCounted

# INFORME DE PARTIDA (tecla ñ). Vuelca al godot.log —y a un fichero— la foto COMPLETA de todos los
# personajes: sus tres capas de habilidad, lo que llevan puesto y los numeros que gobiernan cuanta
# excelia ganan.
#
# POR QUE EXISTE: el 16/08/2026 un tanque salio de una sesion de 50 minutos con 3 puntos en cada
# stat mientras su compañero de party sacaba 19 de magia. Averiguar por que costo una auditoria
# entera del codigo, y lo unico que hacia falta eran cuatro numeros que el juego ya tenia y no
# enseñaba en ningun sitio: el poder (que es el DENOMINADOR del reto), la excelia PENDIENTE de
# consolidar, y las tres capas por separado. Con esto, la proxima vez son dos minutos.
#
# Es de DIAGNOSTICO, asi que enseña a proposito cosas que el juego oculta (los contadores de los
# desarrollos, las pasivas pendientes). No se le enseña al jugador: se pulsa la tecla y se lee.

const STATS := ["fuerza", "resistencia", "destreza", "agilidad", "magia"]
const SLOTS := ["main", "off", "casco", "pecho", "manos", "pantalones", "botas"]


# El informe entero como texto. Separado de quien lo escribe para poder pedirlo desde un test.
static func generar() -> String:
	var L: Array[String] = []
	L.append("=".repeat(78))
	L.append("INFORME DE PARTIDA  ·  %s" % Time.get_datetime_string_from_system(false, true))
	L.append("=".repeat(78))
	_cabecera(L)
	_gente(L)
	L.append("=".repeat(78))
	return "\n".join(L)


# --- CABECERA: en que partida y en que momento estamos ---------------------------------------
static func _cabecera(L: Array[String]) -> void:
	L.append("")
	L.append("[MUNDO]")
	L.append("  version .......... %s" % str(Game.get("VERSION") if "VERSION" in Game else "?"))
	L.append("  semilla_mundo .... %d" % Game.semilla_mundo)
	# La EPOCA decide que material y que pez sale en cada sitio (ver Game.epoca_mazmorra). Va aqui
	# porque una queja de "me salen siempre los mismos peces" se contesta comparando dos informes.
	L.append("  epoca_mazmorra ... %d" % Game.epoca_actual())
	L.append("  piso actual ...... %d" % Game.current_floor)
	L.append("  tiempo_mazmorra .. %.1f s" % Game.tiempo_mazmorra)
	L.append("  mundo compartido . %s" % str(Game.mundo_compartido))

	L.append("")
	L.append("[RED]")
	if not Net.activo:
		L.append("  sin sesion (partida de un jugador)")
	else:
		var papel: String = "HOST" if Net.es_host else "INVITADO"
		L.append("  papel ............ %s   (mi peer: %d)" % [papel,
			Net.multiplayer.get_unique_id() if Net.multiplayer.multiplayer_peer != null else 0])
		L.append("  identidad ........ %s (%s)" % [Identidad.id, Identidad.nombre])
		L.append("  mi lugar ......... %s" % str(Net.get("_mi_lugar")))
		L.append("  ¿simulo mi piso?.. %s" % str(Net.simulo_mi_piso()))
		L.append("  epoca_sesion ..... %d" % Net.epoca_sesion)
		L.append("  semilla_host ..... %d" % Net.semilla_host)


# --- LA GENTE ---------------------------------------------------------------------------------
static func _gente(L: Array[String]) -> void:
	var lider: PersonajeData = Game.lider()
	for pj in Game.plantilla:
		var etiquetas: Array[String] = []
		if pj == lider:
			etiquetas.append("LIDER")
		etiquetas.append("EQUIPO" if Game.party.has(pj) else "banquillo")
		if Game.esta_de_encargo(pj):
			etiquetas.append("DE ENCARGO")
		if pj.es_original:
			etiquetas.append("original")
		_ficha(L, pj, Identidad.nombre if Net.activo else "yo", etiquetas)

	# En multi, los de los DEMAS: viven aparcados en jugadores_mundo y no estan en ninguna plantilla
	# local. Son justo los que nadie puede consolidar ni mirar desde aqui, asi que si algo se les
	# pierde no hay otra forma de verlo.
	for id in Game.jugadores_mundo:
		var jd = Game.jugadores_mundo[id]
		if jd == null:
			continue
		for pj in jd.personajes:
			if pj is PersonajeData:
				var etq: Array[String] = ["de otro jugador"]
				if jd.equipo.has(pj):
					etq.append("en SU equipo")
				_ficha(L, pj as PersonajeData, String(jd.nombre_visible), etq)


static func _ficha(L: Array[String], pj: PersonajeData, dueno: String,
		etiquetas: Array[String]) -> void:
	L.append("")
	L.append("-".repeat(78))
	L.append("%s   (Nv.%d)   [%s]" % [pj.nombre, pj.level, ", ".join(etiquetas)])
	L.append("  dueño: %s   uid: %s" % [dueno, (pj.uid if not String(pj.uid).is_empty()
		else "<<VACIO — este personaje es un FANTASMA: no se le puede mandar de encargo>>")])

	_habilidades(L, pj)
	_denominadores(L, pj)
	_equipo(L, pj)
	_kit(L, pj)
	_estado_vivo(L, pj)
	_ocultos(L, pj)


# LAS TRES CAPAS + las dos derivadas. Es el corazon del informe.
static func _habilidades(L: Array[String], pj: PersonajeData) -> void:
	L.append("")
	# La cabecera se arma con LOS MISMOS anchos que las filas: escrita a mano se descuadraba, y una
	# tabla de diagnostico que no alinea se lee mal justo cuando hay prisa.
	L.append("  HABILIDADES")
	L.append("    %-14s %8s  %5s  |  %11s  %9s  %9s  %8s" % [
		"", "visible", "rango", "consolidado", "interno", "PENDIENTE", "base_niv"])
	for s in STATS:
		var interno: float = float(pj.ability_internal.get(s, 0.0))
		var consol: float = float(pj.ability_consolidado.get(s, 0.0))
		var base: float = float(pj.ability_base_nivel.get(s, 0.0))
		var visible: int = maxi(0, floori(consol - base))
		# PENDIENTE = lo ganado desde el ultimo altar. Es lo que NO se ve en ningun sitio del juego
		# y lo que contesta "he jugado dos horas y mis stats no se mueven".
		var pend: float = maxf(0.0, interno - consol)
		var aviso: String = "   <-- sin consolidar" if pend >= 1.0 else ""
		L.append("    %-14s %8d  %5s  |  %11.2f  %9.2f  %9.2f  %8.2f%s" % [
			s, visible, Abilities.rank_letter(visible), consol, interno, pend, base, aviso])
	# Y con el PLATO puesto, que es lo que de verdad arma los minijuegos y los oficios.
	var con_plato: Array[String] = []
	for s in STATS:
		con_plato.append("%s %.1f" % [s.substr(0, 3), Game.stat_consolidado_eff(s, pj)])
	L.append("    con plato (stat_consolidado_eff): %s" % "  ".join(con_plato))


# LOS DENOMINADORES DEL RETO. Sin esto no hay forma de explicar por que alguien gana poco.
static func _denominadores(L: Array[String], pj: PersonajeData) -> void:
	var nivel: float = Game.poder_jugador_nivel(pj)
	var vida: float = Game.poder_jugador_eff(pj)
	L.append("")
	L.append("  RETO (cuanto gana este personaje)")
	L.append("    poder de ESTE nivel .. %9.2f   <-- divisor contra bichos de tu nivel o mayor" % nivel)
	L.append("    poder de por vida .... %9.2f   <-- divisor contra bichos de niveles anteriores" % vida)
	# Un ejemplo concreto vale mas que la formula: se pone el reto contra un poder de bicho tipico
	# para poder comparar dos personajes de un vistazo.
	for poder in [60.0, 128.0, 250.0]:
		L.append("    reto vs bicho de poder %6.0f: %.3f   (magia: %.3f)" % [poder,
			Game.reto(poder, 1, pj), Game.reto_stat(poder, "magia", 1, pj)])


static func _equipo(L: Array[String], pj: PersonajeData) -> void:
	L.append("")
	L.append("  EQUIPO")
	for slot in SLOTS:
		var it = pj.get("equipped_" + slot)
		if it == null:
			L.append("    %-11s -" % slot)
			continue
		# La meta (tier, rareza, mejoras, durabilidad) va como dict porque es el MISMO objeto que
		# Game.item_meta[item] y sus claves han ido creciendo: volcarlo crudo no se queda corto.
		var meta = (pj.equip_meta as Dictionary).get(slot, {})
		L.append("    %-11s %-28s %s" % [slot, str(it.get("nombre")), str(meta)])


static func _kit(L: Array[String], pj: PersonajeData) -> void:
	var hechizos: Array[String] = []
	for sp in pj.equipped_spells:
		if sp != null:
			hechizos.append(str(sp.get("nombre")))
	var sabidas: Array[String] = []
	for ab in pj.habilidades_aprendidas:
		if ab != null:
			sabidas.append(str(ab.get("nombre")))
	L.append("")
	L.append("  KIT")
	L.append("    hechizos ....... %s" % ("-" if hechizos.is_empty() else ", ".join(hechizos)))
	L.append("    habs sabidas ... %s" % ("-" if sabidas.is_empty() else ", ".join(sabidas)))
	# El loadout va POR TIPO DE ARMA: un hueco null es un hueco que su dueño dejo vacio a proposito
	# (ver Game.habilidades_equipadas), asi que se marca como tal y no se colapsa.
	for tipo in pj.loadout_habilidades:
		var puestas: Array[String] = []
		for ab in (pj.loadout_habilidades[tipo] as Array):
			puestas.append(str(ab.get("nombre")) if ab != null else "<vacio>")
		L.append("    loadout tipo %s: %s" % [str(tipo), ", ".join(puestas)])


static func _estado_vivo(L: Array[String], pj: PersonajeData) -> void:
	L.append("")
	L.append("  ESTADO VIVO")
	# -1 = "a tope, sin concretar" (ver PersonajeData): decirlo, o parece un dato corrupto.
	L.append("    hp %s   mp %s   aguante %s" % [
		_vivo(pj.current_hp), _vivo(pj.current_mp), _vivo(pj.stamina)])
	var ests: Array[String] = []
	for e in pj.estados:
		ests.append(str((e as Dictionary).get("nombre", (e as Dictionary).get("id", "?"))))
	L.append("    estados ........ %s" % ("-" if ests.is_empty() else ", ".join(ests)))
	L.append("    imbuicion ...... %s" % ("-" if pj.imbue.is_empty() else str(pj.imbue)))
	L.append("    foco_cargas .... %d" % pj.foco_cargas)


static func _vivo(v: float) -> String:
	return "lleno" if v < 0.0 else "%.1f" % v


# Los contadores OCULTOS (los que gatean los desarrollos) y los perks. En el juego no se enseñan a
# proposito —ver la nota de "gating oculto"—, pero un informe de diagnostico sin ellos no sirve.
static func _ocultos(L: Array[String], pj: PersonajeData) -> void:
	L.append("")
	L.append("  PERKS Y CONTADORES OCULTOS")
	L.append("    desarrollos .... %s" % str(pj.desarrollos_rango))
	L.append("    pasivas RNG .... %s" % str(pj.pasivas_rng))
	if not pj.pasivas_pendientes.is_empty():
		L.append("    pendientes ..... %s   <-- le tocaron y aun no lo sabe (falta altar)"
			% str(pj.pasivas_pendientes))
	L.append("    guardianes ..... %s" % str(pj.guardianes_vencidos))
	L.append("    esquivas %.1f | hechizos %.1f | recitado %.1f | dmg recibido %.1f | dmg hecho %.1f" % [
		pj.esquivas_exp, pj.hechizos_exp, pj.recitado_exp,
		pj.dano_recibido_exp, pj.dano_infligido_exp])


# Lo escribe en el log Y en un fichero de la carpeta de la partida, para poder pasarlo tal cual sin
# rebuscar en el godot.log. Devuelve la ruta del fichero ("" si no se pudo escribir).
static func volcar() -> String:
	var texto: String = generar()
	print(texto)
	var ruta: String = "user://informe_%s.txt" % Time.get_datetime_string_from_system(false, false) \
		.replace(":", "-").replace(" ", "_")
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		push_warning("[informe] no se pudo escribir %s: %s" % [ruta,
			error_string(FileAccess.get_open_error())])
		return ""
	f.store_string(texto)
	f.close()
	return ProjectSettings.globalize_path(ruta)
