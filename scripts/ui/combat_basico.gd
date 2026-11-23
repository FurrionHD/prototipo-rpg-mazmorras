# ============================================================
#  combat_basico.gd  (tema de la pantalla de combate: combat.basico)
#  EL ARBOL DEL BASICO EN LA PELEA (23/11, basico_arbol.gd; memoria rangos-magias-y-habilidades). Lo que hace cada
#  facultad cuando pega el basico de una mano que la lleva. La LINEA (daño y energia) y lo que pasa al recibir el golpe
#  (Firmeza, Cerrojo, Rompearmadura) van en StatsMath.resolve_attack; la marca y el Eco arcano, en combat_magia.
#
#  Cada golpe del basico mira el arbol de SU mano (Combatant.arbol_mano): en dual, cada arma con lo suyo.
#  Los "+X % de daño" MULTIPLICAN el daño final del basico (regla del jefe); la linea es la que suma al %.
#
#  Barrido, Basico doble y Escudazo van en combat._accion_atacar; Atravesar en combat_tactico.blancos_del_disparo;
#  Respuesta en combat_enemigos (al encajar). AUN SIN HACER: Carga mixta (pide dos virotes en Cargar). Ver PENDIENTES.
# ============================================================
extends RefCounted

const Pantalla = preload("res://scripts/ui/combat.gd")
const BasicoArbol = preload("res://scripts/core/basico_arbol.gd")
const SE = StatusEffects.Id

const PENDIENTES := ["carga_mixta"]
const RADIO_CERCANOS := 120.0   # "los compañeros cercanos" de Dar ejemplo y Arenga, en px alrededor de su bulto

var _pantalla: Pantalla = null
# CUANTAS VECES HA SALTADO cada facultad (id -> n) en este proceso: lo imprime el simulador al acabar, para saber que
# de verdad actuan (el registro del combate no sale por consola).
static var saltos: Dictionary = {}

static func _salta(id: String) -> void:
	saltos[id] = int(saltos.get(id, 0)) + 1


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# LO QUE MULTIPLICA EL GOLPE ANTES de saber si es critico: la linea y las facultades que miran al objetivo o a ti.
func mult_antes(yo: Combatant, obj: Combatant) -> float:
	var arb: Dictionary = yo.arbol_mano()
	if arb.is_empty() or obj == null:
		return 1.0
	var m: float = float(arb.get("dano", 1.0))
	var v: float
	v = yo.fac("ensanamiento")
	if v > 0.0 and (obj.has_status(SE.SANGRADO) or obj.has_status(SE.VENENO) or obj.has_status(SE.QUEMADURA)):
		m *= 1.0 + v
		_salta("ensanamiento")
	v = yo.fac("castigar_guardia")
	if v > 0.0 and obj.has_status(SE.VULNERABLE):
		m *= 1.0 + v
		_salta("castigar_guardia")
	v = yo.fac("verdugo")
	if v > 0.0 and obj.max_hp > 0.0 and obj.current_hp / obj.max_hp < BasicoArbol.param(arb["tipo"], yo.fac_rangos(), "verdugo", "vida"):
		m *= 1.0 + v
		_salta("verdugo")
	v = yo.fac("furia")
	if v > 0.0 and yo.max_hp > 0.0 and yo.current_hp / yo.max_hp < BasicoArbol.param(arb["tipo"], yo.fac_rangos(), "furia", "vida"):
		m *= 1.0 + v
		_salta("furia")
	v = yo.fac("machacar")
	if v > 0.0 and (obj.has_status(SE.ATURDIDO) or obj.has_status(SE.LENTO)):
		m *= 1.0 + v
		_salta("machacar")
	v = yo.fac("martilleo")
	if v > 0.0 and yo.fac_martilleo_obj == obj:
		m *= 1.0 + v * yo.fac_martilleo_n
		_salta("martilleo")
	v = yo.fac("tiro_lejano")
	if v > 0.0 and _pantalla.tactico and yo.alcance > 0.0:
		var d: float = _pantalla.turno_mapa.pies_de(yo).distance_to(_pantalla.turno_mapa.pies_de(obj))
		m *= 1.0 + v * clampf(d / yo.alcance, 0.0, 1.0)
		_salta("tiro_lejano")
	v = yo.fac("sangre_fria")
	if v > 0.0 and not yo.fac_golpeado_antes and not yo.fac_golpeado:
		m *= 1.0 + v
		_salta("sangre_fria")
	v = yo.fac("plantado")
	if v > 0.0 and not _se_ha_movido(yo):
		m *= 1.0 + v
		_salta("plantado")
	v = yo.fac("matagigantes")
	if v > 0.0 and (obj.es_jefe or obj.mutante or _es_grande(yo, obj)):
		m *= 1.0 + v
		_salta("matagigantes")
	return m


# LO QUE MULTIPLICA cuando ya se sabe como ha salido: Filo certero (critico) e Impacto (aturde o retrasa).
func mult_despues(yo: Combatant, result: Dictionary) -> float:
	var m: float = 1.0
	if bool(result.get("crit", false)) and yo.fac("filo_certero") > 0.0:
		m *= 1.0 + yo.fac("filo_certero")
		_salta("filo_certero")
	if bool(result.get("aturde", false)) and yo.fac("impacto") > 0.0:
		m *= 1.0 + yo.fac("impacto")
		_salta("impacto")
	return m


# La DEFENSA que ignora el basico (Estocada limpia): va a resolve_attack como penetra_extra.
func penetra(yo: Combatant) -> float:
	return yo.fac("estocada_limpia")


# Cuanto mas atras echa el retraso de ESTE basico (Arrastre). 0 = lo normal.
func arrastre(yo: Combatant) -> float:
	return yo.fac("arrastre")


# LA ENERGIA que repone el basico, con su linea.
func energia(yo: Combatant, base: float) -> float:
	return base * float(yo.arbol_mano().get("energia", 1.0))


# El % de mana maximo EXTRA del bastonazo (+0,5 puntos por paso del piso 4).
func mana_extra(yo: Combatant) -> float:
	return float(yo.arbol_mano().get("mana_extra", 0.0))


# TRAS UN BASICO QUE ACIERTA: todo lo que pasa despues. 'dmg' lo que le ha hecho; 'vida_antes' la que tenia antes del
# golpe (lo que SOBRA al matar = dmg - vida_antes). Devuelve lo que se añade al log (cada cosa con su frase).
func tras_acierto(yo: Combatant, obj: Combatant, dmg: float, result: Dictionary, vida_antes: float) -> String:
	var mato: bool = not obj.is_alive()
	_salta("~basicos_que_aciertan")
	var arb: Dictionary = yo.arbol_mano()
	var txt: String = ""
	# LA MARCA (baston, o la varita con el arma principal): la ponen todos los basicos que aciertan, hasta 3.
	var marca: float = maxf(float(arb.get("marca", 0.0)), yo.marca_varita if yo._hand_idx == 0 else 0.0)
	if marca > 0.0 and obj.is_alive():
		obj.marca_basico_n = mini(obj.marca_basico_n + 1, BasicoArbol.MARCA_TOPE)
		obj.marca_basico_valor = maxf(obj.marca_basico_valor, marca)
		txt += "  Marca a %s (%d)." % [_pantalla._etq(obj), obj.marca_basico_n]
		_salta("marca")
	if arb.is_empty():
		return txt
	var tipo: int = int(arb["tipo"])
	var rangos: Dictionary = yo.fac_rangos()
	# --- estados en el objetivo ---
	if obj.is_alive():
		txt += _estado(yo, obj, "sangrado", SE.SANGRADO, dmg)
		txt += _estado(yo, obj, "exponer", SE.VULNERABLE, dmg)
		txt += _estado(yo, obj, "desarmar", SE.DEBIL, dmg)
		txt += _estado(yo, obj, "herida_no_cierra", SE.HERIDA_PROFUNDA, dmg)
		txt += _estado(yo, obj, "clavar", SE.ENRAIZADO, dmg)
		# ABRIR LA HERIDA (daga): si ya sangra, renueva todas sus cargas.
		if yo.fac_lista("abrir_herida") and obj.has_status(SE.SANGRADO) and randf() < yo.fac("abrir_herida"):
			obj.apply_status(SE.SANGRADO, -1, _mag_sangrado(yo, obj), 0, true)
			yo.fac_enfriar("abrir_herida", _enf(tipo, "abrir_herida"))
			_salta("abrir_herida")
			txt += "  Abre la herida de %s: el sangrado se renueva." % _pantalla._etq(obj)
		# DESCOSER (mandoble): si ya sangra, una carga mas.
		if yo.fac_lista("descoser") and obj.has_status(SE.SANGRADO) and randf() < yo.fac("descoser"):
			obj.apply_status(SE.SANGRADO, -1, _mag_sangrado(yo, obj))
			yo.fac_enfriar("descoser", _enf(tipo, "descoser"))
			_salta("descoser")
			txt += "  Descose a %s: una carga más de sangrado." % _pantalla._etq(obj)
		# ROMPEARMADURA (hacha): una carga de -defensa, hasta su tope, y se renuevan los turnos.
		var ra: float = yo.fac("rompearmadura")
		if ra > 0.0:
			obj.rompe_armadura_n = mini(obj.rompe_armadura_n + 1, int(BasicoArbol.param(tipo, rangos, "rompearmadura", "cargas")))
			obj.rompe_armadura_valor = maxf(obj.rompe_armadura_valor, ra)
			obj.rompe_armadura_turnos = int(BasicoArbol.param(tipo, rangos, "rompearmadura", "turnos"))
			_salta("rompearmadura")
			txt += "  Le raja la armadura a %s (-%d %% de defensa)." % [_pantalla._etq(obj),
				roundi(obj.rompe_armadura_n * obj.rompe_armadura_valor * 100.0)]
		# RETRASAR (ballesta): lo echa atras en la barra, sin aturdir.
		if yo.fac_lista("retrasar") and not bool(result.get("aturde", false)) \
				and randf() < StatusEffects.prob_final(yo.fac("retrasar"), yo, obj, SE.ATURDIDO):
			yo.fac_enfriar("retrasar", _enf(tipo, "retrasar"))
			_salta("retrasar")
			txt += _pantalla._aplicar_aturdir(obj, false, arrastre(yo))
	# SACUDIDA (martillo): si el basico aturde o retrasa, la onda llega a los de alrededor y puede retrasarlos.
	var sac: float = yo.fac("sacudida")
	if sac > 0.0 and bool(result.get("aturde", false)):
		for e in _enemigos_cerca(obj, BasicoArbol.param(tipo, rangos, "sacudida", "radio")):
			if e != obj and randf() < StatusEffects.prob_final(sac, yo, e, SE.ATURDIDO):
				txt += _pantalla._aplicar_aturdir(e, false, arrastre(yo))
				_salta("sacudida")
	# CHISPA (baston): una chispa magica sin elemento del % de tu Magia (por la cuenta del golpe magico, con su defensa).
	var chi: float = yo.fac("chispa")
	if chi > 0.0 and obj.is_alive() and randf() < chi:
		var rc: Dictionary = StatsMath.resolve_magico_enemigo(yo, obj, false)
		var d_ch: float = float(rc.damage) * BasicoArbol.param(tipo, rangos, "chispa", "magia")
		obj.take_damage(d_ch)
		_pantalla._apuntar_dano(obj, d_ch, yo)
		_pantalla._dps_add("Chispa", d_ch)
		_salta("chispa")
		txt += "  Salta una chispa: %s de daño mágico a %s." % [_pantalla._n(d_ch), _pantalla._etq(obj)]
	# MARTILLEO (maza): suma carga si es el mismo; al cambiar, pierde la mitad y empieza con este.
	if yo.fac("martilleo") > 0.0:
		var tope_m: int = int(BasicoArbol.param(tipo, rangos, "martilleo", "cargas"))
		if yo.fac_martilleo_obj == obj:
			yo.fac_martilleo_n = mini(yo.fac_martilleo_n + 1, tope_m)
		else:
			yo.fac_martilleo_obj = obj
			yo.fac_martilleo_n = mini(yo.fac_martilleo_n / 2 + 1, tope_m)
	# --- lo tuyo ---
	if yo.fac("respuesta") > 0.0 and not yo.fac_respuesta and randf() < yo.fac("respuesta"):
		yo.fac_respuesta = true
		_salta("respuesta")
		txt += "  %s queda en respuesta." % yo.nombre
	if yo.fac_lista("pies_ligeros") and randf() < yo.fac("pies_ligeros"):
		yo.apply_status(SE.PRESTEZA, 1)
		yo.fac_enfriar("pies_ligeros", _enf(tipo, "pies_ligeros"))
		_salta("pies_ligeros")
		txt += "  %s queda con Presteza." % yo.nombre
	if yo.fac_lista("firmeza") and randf() < yo.fac("firmeza"):
		yo.fac_firmeza = BasicoArbol.param(tipo, rangos, "firmeza", "menos")
		yo.fac_enfriar("firmeza", _enf(tipo, "firmeza"))
		_salta("firmeza")
		txt += "  %s se afirma: el próximo golpe le hará menos." % yo.nombre
	if yo.fac("cerrojo") > 0.0 and bool(result.get("aturde", false)) and yo.defend_defense > 0.0:
		yo.fac_cubierto = yo.fac("cerrojo")
		_salta("cerrojo")
		txt += "  %s queda cubierto tras el escudo." % yo.nombre
	if yo.fac_lista("buen_ritmo") and randf() < yo.fac("buen_ritmo"):
		var bajada: String = _bajar_recarga(yo)
		if bajada != "":
			yo.fac_enfriar("buen_ritmo", _enf(tipo, "buen_ritmo"))
			_salta("buen_ritmo")
			txt += "  Buen ritmo: %s vuelve un turno antes." % bajada
	if yo.fac_lista("eco_arcano"):
		yo.fac_eco = yo.fac("eco_arcano")
		yo.fac_enfriar("eco_arcano", _enf(tipo, "eco_arcano"))
		_salta("eco_arcano")
	if yo.fac_lista("concentracion") and randf() < yo.fac("concentracion"):
		yo.foco_cargas += 1
		yo.fac_enfriar("concentracion", _enf(tipo, "concentracion"))
		_salta("concentracion")
		txt += "  %s se concentra: una carga de Foco arcano." % yo.nombre
	if yo.fac_lista("escabullirse") and randf() < yo.fac("escabullirse"):
		yo.apply_status(SE.SIGILO, 1)
		yo.fac_enfriar("escabullirse", _enf(tipo, "escabullirse"))
		_salta("escabullirse")
		txt += "  %s se escabulle entre las sombras." % yo.nombre
	# SED (hacha): cura un % del daño, con su tope por turno.
	var sed: float = yo.fac("sed")
	if sed > 0.0 and dmg > 0.0:
		var tope: float = BasicoArbol.param(tipo, rangos, "sed", "tope") * yo.max_hp - yo.fac_sed_turno
		var cura: float = minf(dmg * sed, maxf(tope, 0.0))
		if cura > 0.0:
			var antes: float = yo.current_hp
			yo.heal(cura)
			yo.fac_sed_turno += yo.current_hp - antes
			_salta("sed")
	# ENERGIA: Impulso (si mata) y Romper el ritmo (si aturde o retrasa), en fraccion de lo que repone un basico.
	var basico_en: float = energia(yo, yo.energia_regen if yo.energia_regen > 0.0 else Pantalla.ATTACK_ENERGY_REGEN)
	if mato and yo.fac("impulso") > 0.0:
		yo.regen_energy(basico_en * yo.fac("impulso"))
		_salta("impulso")
	if bool(result.get("aturde", false)) and yo.fac("romper_ritmo") > 0.0:
		yo.regen_energy(basico_en * yo.fac("romper_ritmo"))
		_salta("romper_ritmo")
	# --- los tuyos ---
	if yo.fac_lista("dar_ejemplo") and randf() < yo.fac("dar_ejemplo"):
		var pct: float = BasicoArbol.param(tipo, rangos, "dar_ejemplo", "energia")
		for al in _cercanos(yo):
			al.regen_energy(al.max_energy * pct)
		yo.fac_enfriar("dar_ejemplo", _enf(tipo, "dar_ejemplo"))
		_salta("dar_ejemplo")
		txt += "  %s da ejemplo: los suyos recuperan energía." % yo.nombre
	if yo.fac_lista("arenga") and randf() < yo.fac("arenga"):
		for al in _cercanos(yo):
			al.apply_status(SE.FORTALEZA, 1)
		yo.fac_enfriar("arenga", _enf(tipo, "arenga"))
		_salta("arenga")
		txt += "  %s arenga a los suyos: Fortaleza." % yo.nombre
	# VERDUGO (mandoble): si al matar sobra al menos la mitad del golpe, miedo a los de al lado.
	if mato and yo.fac("verdugo") > 0.0 and dmg - vida_antes >= 0.5 * dmg:
		var p_miedo: float = BasicoArbol.param(tipo, rangos, "verdugo", "miedo")
		var radio: float = BasicoArbol.param(tipo, rangos, "verdugo", "radio")
		for e in _enemigos_cerca(obj, radio):
			if randf() < StatusEffects.prob_final(p_miedo, yo, e, SE.MIEDO):
				e.apply_status(SE.MIEDO, 1)
				_salta("verdugo_miedo")
				txt += "  %s se asusta." % _pantalla._etq(e)
	return txt


# ---------------------------------------------------------------- lo del ataque entero (combat._accion_atacar)

# BARRIDO: los enemigos (menos el objetivo) dentro del cono hacia el objetivo, con el alcance del basico.
func barridos(yo: Combatant, obj: Combatant) -> Array:
	var tm = _pantalla.turno_mapa
	if tm.cuerpo_de(yo) == null or tm.cuerpo_de(obj) == null:
		return []
	var arb: Dictionary = yo.arbol_mano()
	var angulo: float = BasicoArbol.param(int(arb.get("tipo", 0)), yo.fac_rangos(), "barrido", "angulo")
	var origen: Vector2 = tm.pies_de(yo)
	var radio: float = maxf(origen.distance_to(tm.pies_de(obj)), tm.alcance_de(yo) + tm.radio_pisa(yo))
	var f = CombatFormas.cono(origen, tm.pies_de(obj) - origen, radio + 20.0, angulo)
	var out: Array = []
	for e in _pantalla._vivos():
		if e != obj and _pantalla._enemies.has(e) and tm.cuerpo_de(e) != null and f.toca(tm.bulto_de(e)):
			out.append(e)
			_salta("barrido")
	return out


# BASICO DOBLE: con DOS armas del MISMO tipo (dos dagas, dos espadas cortas).
func dos_del_mismo_tipo(yo: Combatant) -> bool:
	if yo.hands.size() < 2:
		return false
	var a: Dictionary = (yo.hands[0] as Dictionary).get("arbol", {})
	var b: Dictionary = (yo.hands[1] as Dictionary).get("arbol", {})
	return not a.is_empty() and not b.is_empty() and int(a.get("tipo", -1)) == int(b.get("tipo", -2))


func param_mano(yo: Combatant, id: String, clave: String, si_no: float) -> float:
	var arb: Dictionary = yo.arbol_mano()
	if arb.is_empty():
		return si_no
	var v: float = BasicoArbol.param(int(arb["tipo"]), yo.fac_rangos(), id, clave)
	return v if v > 0.0 else si_no


# ---------------------------------------------------------------- ayudantes

func _enf(tipo: int, id: String) -> int:
	return int(BasicoArbol.facultad(tipo, id).get("enf", 0))


# UN ESTADO CON PROBABILIDAD (la de la facultad, contra la resistencia del objetivo por la puerta comun).
func _estado(yo: Combatant, obj: Combatant, id: String, estado: int, dmg: float) -> String:
	if not yo.fac_lista(id):
		return ""
	var tipo: int = int(yo.arbol_mano()["tipo"])
	var p: float = StatusEffects.prob_final(yo.fac(id), yo, obj, estado)
	if randf() >= p:
		obj.anotar_intento_estado(yo, estado, false)
		return ""
	obj.anotar_intento_estado(yo, estado, true)
	var mag: float = _mag_sangrado(yo, obj) if estado == SE.SANGRADO else -1.0
	obj.apply_status(estado, -1, mag)
	yo.fac_enfriar(id, _enf(tipo, id))
	_salta(id)
	return "  Causa %s a %s." % [String(StatusEffects.def(estado).get("nombre", "?")), _pantalla._etq(obj)]


func _mag_sangrado(yo: Combatant, obj: Combatant) -> float:
	var real: float = StatusEffects.magnitud_del_golpe(SE.SANGRADO, obj)
	return real if real >= 0.0 else StatusEffects.sangrado_magnitude(yo.atk(), yo.motion_value)


# Quita 1 turno de recarga a UNA habilidad de esta arma que lo tenga (la que mas le falte).
func _bajar_recarga(yo: Combatant) -> String:
	var mejor = null
	var mas: int = 0
	for ab in yo.ability_cooldowns:
		var t: int = int(yo.ability_cooldowns[ab])
		if t > mas and yo.ability_hand_indices(ab).has(yo._hand_idx):
			mas = t
			mejor = ab
	if mejor == null:
		return ""
	yo.ability_cooldowns[mejor] = mas - 1
	return String(mejor.get("nombre")) if mejor is Resource else "una habilidad"


# ¿Es GRANDE? (Matagigantes) En el mapa: su bulto es bastante mayor que el tuyo. PROVISIONAL: GRANDE_FRAC.
const GRANDE_FRAC := 1.6

func _es_grande(yo: Combatant, obj: Combatant) -> bool:
	if not _pantalla.tactico:
		return false
	var tm = _pantalla.turno_mapa
	if tm.cuerpo_de(yo) == null or tm.cuerpo_de(obj) == null:
		return false
	return tm.bulto_de(obj).size.length() >= GRANDE_FRAC * tm.bulto_de(yo).size.length()


# ¿Se ha movido en este turno? (en el mapa: lejos de donde empezo, mas que la holgura de la gargola posada)
func _se_ha_movido(yo: Combatant) -> bool:
	if not _pantalla.tactico:
		return false
	var tm = _pantalla.turno_mapa
	if not tm._inicio_turno.has(yo):
		return false
	return tm.pies_de(yo).distance_to(tm._inicio_turno[yo]) > tm.POSADA_HOLGURA


func _cercanos(yo: Combatant) -> Array:
	if not _pantalla.tactico:
		return _pantalla._aliados_vivos().filter(func(a): return a != yo)
	return _pantalla.turno_mapa.vecinos_de(yo, RADIO_CERCANOS)


func _enemigos_cerca(obj: Combatant, radio: float) -> Array:
	if not _pantalla.tactico:
		return []
	return _pantalla.turno_mapa.vecinos_de(obj, radio).filter(func(e): return e.is_alive())
