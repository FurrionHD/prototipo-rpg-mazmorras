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
	var fichas: Array = _recoger()
	_resumen(L, fichas)
	_detalle(L, fichas)
	L.append("=".repeat(78))
	return "\n".join(L)


# Todos los personajes que existen en esta maquina, cada uno UNA vez, marcando los DUPLICADOS.
#
# Los duplicados no son un adorno del informe: son un BUG de datos que salio en el primer volcado
# real (16/08). El guardado escribe `d.jugadores[Identidad.id]` con lo tuyo y deja el resto tal cual,
# y al cargar TODA clave que no sea tu identidad actual se aparca como "otro jugador". Si tu
# identidad cambia (otra maquina, identidad.cfg regenerado), tu JugadorData viejo se queda ahi para
# siempre, congelado, y ademas se cuela en el selector de encargos como un fantasma. Cada cambio de
# identidad añade una copia entera del roster.
static func _recoger() -> Array:
	var out: Array = []
	var por_uid: Dictionary = {}   # uid -> la primera ficha que lo trajo
	var lider: PersonajeData = Game.lider()

	for pj in Game.plantilla:
		var etq: Array[String] = []
		if pj == lider:
			etq.append("LIDER")
		etq.append("EQUIPO" if Game.party.has(pj) else "banquillo")
		if Game.esta_de_encargo(pj):
			etq.append("DE ENCARGO")
		if pj.es_original:
			etq.append("original")
		var f := {"pj": pj, "dueno": Identidad.nombre if Net.activo else "yo",
			"etq": etq, "dup_de": null}
		por_uid[String(pj.uid)] = f
		out.append(f)

	for id in Game.jugadores_mundo:
		var jd = Game.jugadores_mundo[id]
		if jd == null:
			continue
		for pj in jd.personajes:
			if not (pj is PersonajeData):
				continue
			var p := pj as PersonajeData
			var etq2: Array[String] = ["de otro jugador"]
			if jd.equipo.has(p):
				etq2.append("en SU equipo")
			var f2 := {"pj": p, "dueno": String(jd.nombre_visible), "etq": etq2,
				"clave": String(id), "dup_de": por_uid.get(String(p.uid))}
			if f2["dup_de"] == null:
				por_uid[String(p.uid)] = f2
			out.append(f2)
	return out


# LA TABLA QUE SE MIRA PRIMERO: una linea por persona con el PODER (que es el divisor del reto) y
# el reto que le sale contra un bicho tipico. Es lo que contesta de un vistazo "¿por que este gana
# menos que aquel?", que es la pregunta que hizo falta el 16/08 y costo una auditoria entera.
static func _resumen(L: Array[String], fichas: Array) -> void:
	L.append("")
	L.append("[RESUMEN]  (reto vs un bicho de poder 128, tipo jabali de piso 4)")
	L.append("  %-22s %-12s %8s %7s %10s  %s" % [
		"personaje", "dueño", "poder", "reto", "PENDIENTE", "estado"])
	for f in fichas:
		var pj: PersonajeData = f["pj"]
		var pend: float = 0.0
		for s in STATS:
			pend += maxf(0.0, float(pj.ability_internal.get(s, 0.0))
				- float(pj.ability_consolidado.get(s, 0.0)))
		var nota: String = ", ".join(f["etq"] as Array)
		if f["dup_de"] != null:
			nota = "DUPLICADO (copia rancia, clave '%s')" % String(f.get("clave", "?"))
		L.append("  %-22s %-12s %8.0f %7.3f %10.2f  %s" % [
			pj.nombre.substr(0, 22), String(f["dueno"]).substr(0, 12),
			Game.poder_jugador_nivel(pj), Game.reto(128.0, 1, pj), pend, nota])
	_avisar_duplicados(L, fichas)


# Si hay copias del mismo uid, decir CUANTO se han separado. Dos copias que ya no coinciden son
# progreso que se esta escribiendo en un sitio y leyendo de otro.
static func _avisar_duplicados(L: Array[String], fichas: Array) -> void:
	var dups: Array = []
	for f in fichas:
		if f["dup_de"] != null:
			dups.append(f)
	if dups.is_empty():
		return
	L.append("")
	L.append("  !! %d PERSONAJE(S) DUPLICADO(S). Tu identidad ha cambiado alguna vez y las copias" % dups.size())
	L.append("     viejas se quedaron aparcadas como si fueran de otro jugador (ver _recoger).")
	for f in dups:
		var pj: PersonajeData = f["pj"]
		var orig: PersonajeData = (f["dup_de"] as Dictionary)["pj"]
		var difs: Array[String] = []
		for s in STATS:
			var d: float = float(orig.ability_internal.get(s, 0.0)) \
				- float(pj.ability_internal.get(s, 0.0))
			if absf(d) >= 0.01:
				difs.append("%s %+.2f" % [s.substr(0, 3), d])
		L.append("     %-20s uid %s  ->  %s" % [pj.nombre, String(pj.uid),
			"IDENTICA a la buena" if difs.is_empty()
				else "la copia va ATRASADA: " + ", ".join(difs)])


static func _detalle(L: Array[String], fichas: Array) -> void:
	for f in fichas:
		# De una copia rancia no se repite la ficha entera: ya se ha dicho en que se diferencia, y
		# volcarla completa es lo que desbordo la salida en el primer volcado real.
		if f["dup_de"] != null:
			continue
		_ficha(L, f["pj"], String(f["dueno"]), f["etq"] as Array[String])


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
	_oficios(L)


# CUANTO SE HA CRAFTEADO, en bruto. Estos contadores son DEL GRUPO (viven en Game, no en cada
# PersonajeData), asi que van una sola vez y aqui arriba: si salieran solo dentro de cada ficha, ver
# el mismo "metalurgia 340" repetido en las cuatro parece un bug de datos y no lo es.
#
# El desarrollo de oficio si es de cada uno (su rango vive en su desarrollos_rango), asi que un
# personaje puede tener Herreria B y otro no tenerla, los dos con este mismo contador detras.
static func _oficios(L: Array[String]) -> void:
	L.append("")
	L.append("[OFICIOS DEL GRUPO]  (contadores compartidos: cuanto se ha crafteado en esta partida)")
	for d in Game.DESARROLLOS:
		if str(d.get("tipo", "")) != "oficio":
			continue
		var cont: String = str(d["contador"])
		L.append("    %-14s %10s   (umbral de %s: %s)" % [d["nombre"],
			String.num(float(Game.get(cont)), 1), Game.letra_rango(1),
			String.num(float(d.get("umbral", 0.0)), 0)])


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
		# Solo lo que se mira: tier, rareza, mejoras y durabilidad. Antes iba el dict crudo entero y
		# entre eso y los duplicados el volcado desbordaba la salida.
		var meta := (pj.equip_meta as Dictionary).get(slot, {}) as Dictionary
		var mejoras := meta.get("mejoras", {}) as Dictionary
		# La DURABILIDAD a 0 es equipo ROTO, y no se ve en ningun sitio del juego con este detalle:
		# en el primer volcado real salieron las cinco piezas del lider a cero.
		var dur = meta.get("durabilidad")
		var dur_txt: String = "?" if dur == null else "%.0f%%" % (float(dur) * 100.0)
		if dur != null and float(dur) <= 0.0:
			dur_txt = "0% ROTA"   # cadena literal, no un format: aqui el %% imprimia DOS %
		# La RAREZA por su nombre y con lo que de verdad hace (el multiplicador de Upgrades), no el
		# indice crudo: "r4" no dice nada, "Legendario x1.35" contesta la pregunta sin ir a la tabla.
		var rar_txt: String = "r?"
		if meta.has("rareza"):
			var r: int = int(meta["rareza"])
			rar_txt = "%s x%.2f" % [Upgrades.rareza_nombre(r), Upgrades.rareza_mult(r)]
		# Y los huecos de mejora GASTADOS sobre los que da esa rareza: es lo que dice si a la pieza le
		# queda recorrido en el herrero o ya esta al tope.
		var slots_txt: String = ""
		if meta.has("rareza"):
			var usados: int = Upgrades.total_mejoras(mejoras)
			var tope: int = Upgrades.rareza_slots(int(meta["rareza"]))
			slots_txt = "  mejoras %d/%d" % [usados, tope]
			if usados >= tope:
				slots_txt += " (AL TOPE)"
			if not mejoras.is_empty():
				# Compacto ("Ataque+3, Critico+1") y no el dict crudo: str() de un Dictionary mete
				# comillas y espacios por todas partes y parte la linea en la consola.
				var det: Array[String] = []
				for k in mejoras:
					det.append("%s+%d" % [str(k), int(mejoras[k])])
				slots_txt += " " + ", ".join(det)
		L.append("    %-11s %-28s T%s  %-22s dur %-8s%s" % [slot, str(it.get("nombre")).substr(0, 28),
			str(meta.get("tier", "?")), rar_txt, dur_txt, slots_txt])


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


# El contador que gatea un desarrollo, LEIDO DE QUIEN TOCA. Los de combate son de la persona (viven
# en su PersonajeData) y los de oficio son del grupo (viven en Game), exactamente el mismo criterio
# que usa Game._subir_rangos_desarrollo. Sin esto, los contadores de combate de todo el mundo salian
# con el numero del LIDER (es lo que hace Game.desarrollo_progreso, que va por la propiedad de Game).
static func _contador_de(pj: PersonajeData, nombre: String) -> float:
	if nombre == "":
		return 0.0
	return float(pj.get(nombre)) if nombre in pj else float(Game.get(nombre))


# Los contadores OCULTOS (los que gatean los desarrollos) y los perks. En el juego no se enseñan a
# proposito —ver la nota de "gating oculto"—, pero un informe de diagnostico sin ellos no sirve.
#
# Se listan TODOS los desarrollos, tenga o no cada uno: el que ya tienes con su rango y lo que le
# falta al siguiente, y el que no, con lo que le falta para desbloquearse. Antes salia el dict crudo
# ({"herreria": 3}), que no dice ni como se llama, ni que letra es, ni cuanto queda.
static func _ocultos(L: Array[String], pj: PersonajeData) -> void:
	L.append("")
	L.append("  DESARROLLOS   (los de oficio llevan el contador DEL GRUPO, ver [OFICIOS DEL GRUPO])")
	L.append("    %-22s %-10s %9s / %-9s  %s  %s" % [
		"", "tipo", "contador", "umbral I", "esc.", "estado"])
	for d in Game.DESARROLLOS:
		var id: String = str(d["id"])
		var rango: int = int(pj.desarrollos_rango.get(id, 0))
		var umbral: float = float(d.get("umbral", 0.0))
		var mult: float = Game._mult_de_rango(d)
		var cont: float = _contador_de(pj, str(d.get("contador", "")))
		var estado: String
		if rango >= Game.RANGO_MAX:
			estado = "rango S — AL TOPE"
		elif rango >= 1:
			var sig: float = Game.req_de_rango(umbral, rango + 1, mult)
			estado = "rango %s  ->  %s falta %s para %s" % [Game.letra_rango(rango),
				_barra(cont, sig), String.num(maxf(0.0, sig - cont), 0),
				Game.letra_rango(rango + 1)]
		else:
			var falta: String = String.num(maxf(0.0, umbral - cont), 0)
			estado = "no lo tiene   %s falta %s para DESBLOQUEAR" % [_barra(cont, umbral), falta]
			if cont >= umbral:
				estado = "no lo tiene   LISTO: sale en el proximo ascenso"
			if bool(d.get("solo_nivel_1", false)) and pj.level != 1:
				estado += "  (solo nivel 1: YA NO PUEDE)"
		L.append("    %-22s %-10s %9s / %-9s  x%.2f  %s" % [d["nombre"], "(%s)" % d["tipo"],
			String.num(cont, 0), String.num(umbral, 0), mult, estado])

	L.append("")
	L.append("  PASIVAS Y CONTADORES SUELTOS")
	var pas: Array[String] = []
	for id in pj.pasivas_rng:
		if bool(pj.pasivas_rng[id]):
			pas.append(str(Game.pasiva_por_id(str(id)).get("nombre", id)))
	L.append("    pasivas RNG .... %s" % ("-" if pas.is_empty() else ", ".join(pas)))
	if not pj.pasivas_pendientes.is_empty():
		var pend: Array[String] = []
		for id in pj.pasivas_pendientes:
			pend.append(str(Game.pasiva_por_id(str(id)).get("nombre", id)))
		L.append("    pendientes ..... %s   <-- le tocaron y aun no lo sabe (falta altar)"
			% ", ".join(pend))
	L.append("    guardianes ..... %s" % ("-" if pj.guardianes_vencidos.is_empty()
		else str(pj.guardianes_vencidos)))
	L.append("    dmg recibido ... %.1f   (ya no gatea nada; el perk va por el BLOQUEADO)"
		% pj.dano_recibido_exp)


# Barra de progreso de texto, para poder ver de un vistazo quien esta cerca y quien no.
static func _barra(v: float, tope: float) -> String:
	var f: float = clampf(v / maxf(0.0001, tope), 0.0, 1.0)
	var n: int = int(round(f * 10.0))
	return "[%s%s]%3.0f%%" % ["#".repeat(n), ".".repeat(10 - n), f * 100.0]


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
