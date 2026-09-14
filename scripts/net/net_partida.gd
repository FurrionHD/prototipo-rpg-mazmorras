# ============================================================
#  net_partida.gd  (hijo de Net: /root/Net/Partida)
#  LA PARTIDA POR RED: los personajes de verdad (pj_a_dict/jd_a_dict, no el doble de combate), el
#  guardado (preventivo del LAN y el del mundo compartido, que recoge el estado de todos) y el baile de
#  entrada del que se une a un mundo compartido (su personaje, crearlo o traerlo). Net.partida.<funcion>.
# ============================================================
extends Node

# ============================================================
#  UN PERSONAJE DE VERDAD (no el doble de combate) Y SU JUGADOR
#  ficha_a_dict/ficha_de_dict son el DOBLE: mandan lo justo para pelear, viajan en CADA union a una
#  pelea y traen el equipo SIN registrar a proposito (el bug de las 6 hachas). No se tocan.
#
#  Esto es lo otro: mandar a una PERSONA para que VIVA en un mundo que no esta en su disco. Va una
#  vez al entrar y otra al guardar, asi que puede permitirse ser fiel. Lo que el doble no lleva y
#  aqui es imprescindible:
#    es_original          el personaje de referencia DE ESA PERSONA (a quien se recurre si no queda nadie)
#    dueno                de quien es (ver personaje_data.gd)
#    rol                  su kit y su ficha
#    pasivas_pendientes   una tirada de 1 entre 500.000 sin leer; perderla seria una crueldad
#  Y su equipo se deserializa REGISTRANDO: en un mundo compartido el baul del mundo es la casa de
#  esos objetos, no un prestamo para una pelea.
# ------------------------------------------------------------
# OJO: esta lista es FIJA. Un campo permanente de PersonajeData que no este aqui funciona perfecto en
# solitario y desaparece SOLO en multi, que es de las averias mas caras de encontrar. `uid` esta aqui
# porque los ENCARGOS apuntan a la gente por uid y se cobran horas despues, quiza en otra maquina.
const _PERMANENTES := ["es_original", "rol", "dueno", "pasivas_pendientes", "uid"]


func pj_a_dict(pj: PersonajeData) -> Dictionary:
	var d := ficha_a_dict(pj)
	for campo in _PERMANENTES:
		d[campo] = pj.get(campo)
	return d


# 'registrar' por defecto true porque el caso normal de esta funcion es el ALTA (un personaje que
# pasa a vivir en este mundo). Ver la nota de ficha_de_dict, y sobre todo _mi_estado, que es
# periodico y tiene que pasar false.
func pj_de_dict(d: Dictionary, registrar := true) -> PersonajeData:
	return ficha_de_dict(d, registrar)


# TODO lo de una persona en un mundo: sus personajes y lo que es suyo y de nadie mas (dinero, bolsa,
# oficios, donde se quedo). Es el JugadorData de jugador_data.gd, pero por cable.
func jd_a_dict(jd: JugadorData) -> Dictionary:
	var fichas: Array = []
	for pj in jd.personajes:
		if pj is PersonajeData:
			fichas.append(pj_a_dict(pj as PersonajeData))
	# El equipo va por INDICE dentro de `personajes`, NUNCA como copias: si el mismo personaje viajara
	# dos veces, al otro lado serian DOS objetos distintos y estaria a la vez en el equipo y en la
	# plantilla como dos personas (dos vidas, dos inventarios, y el desgaste de la pelea perdido).
	var huecos: Array = []
	for pj in jd.equipo:
		var i: int = jd.personajes.find(pj)
		if i >= 0:
			huecos.append(i)
	var bolsa: Array = []
	for it in jd.materiales:
		var m: Dictionary = Net.suelo._item_a_dict(it)
		if not m.is_empty():
			bolsa.append(m)
	var cris: Array = []
	for it in jd.crystals:
		var c: Dictionary = Net.suelo._item_a_dict(it)
		if not c.is_empty():
			cris.append(c)
	var carbonera: Array = []
	for it in jd.carbon:
		var cb: Dictionary = Net.suelo._item_a_dict(it)
		if not cb.is_empty():
			carbonera.append(cb)
	return {
		"id": jd.id, "nombre_visible": jd.nombre_visible,
		"personajes": fichas, "equipo": huecos, "lider_pos": jd.lider_pos,
		"dinero": jd.dinero, "materiales": bolsa, "crystals": cris,
		"consumibles": jd.consumibles.duplicate(),
		"mochila": Game.serializar_equipo(jd.equipped_mochila),
		# Las HERRAMIENTAS equipadas. Solo viajan las puestas, como la mochila: el baul de
		# herramientas de cada uno se queda en su save y no tiene por que existir en este mundo.
		"pico": Game.serializar_equipo(jd.equipped_pico),
		"hoz": Game.serializar_equipo(jd.equipped_hoz),
		"hacha": Game.serializar_equipo(jd.equipped_hacha),
		"cana": Game.serializar_equipo(jd.equipped_cana),
		"cuchillo": Game.serializar_equipo(jd.equipped_cuchillo),
		# EL FAROLILLO Y SU CARBON. No viajaban: cada autoguardado del mundo escribia al invitado sin
		# lampara, sin carbonera y sin la llama que llevaba encendida, y al volver a entrar se lo
		# encontraba a oscuras (playtest del 11/09/2026). El cebo tampoco venia.
		"lampara": Game.serializar_equipo(jd.equipped_lampara),
		"carbon": carbonera,
		"lampara_llama": jd.lampara_llama, "lampara_llama_total": jd.lampara_llama_total,
		"cebo": jd.cebo,
		"registro_pesca": jd.registro_pesca.duplicate(true),
		"mezcla": jd.mezcla_exp, "metalurgia": jd.metalurgia_exp,
		"peleteria": jd.peleteria_exp, "herreria": jd.herreria_exp,
		"carpinteria": jd.carpinteria_exp, "cocina": jd.cocina_exp,
		"materiales_vistos": jd.materiales_vistos.duplicate(),
		"pack_inicial": jd.pack_inicial,
		"en_mazmorra": jd.en_mazmorra, "current_floor": jd.current_floor, "pos": jd.pos,
	}


# 'registrar': ¿el equipo que trae este jugador pasa a vivir en MI baul? true en un ALTA (entra al
# mundo por primera vez, o vuelve: sus cosas tienen que existir aqui). FALSE en las
# SINCRONIZACIONES periodicas (_mi_estado), donde ya estan registradas de antes y volver a hacerlo
# mete una COPIA NUEVA cada vez -- ver la nota larga de _mi_estado.
func jd_de_dict(d: Dictionary, registrar := true) -> JugadorData:
	var jd := JugadorData.new()
	jd.id = String(d.get("id", ""))
	jd.nombre_visible = String(d.get("nombre_visible", ""))
	jd.personajes = []
	for f in d.get("personajes", []):
		jd.personajes.append(pj_de_dict(f as Dictionary, registrar))
	jd.equipo = []
	for i in d.get("equipo", []):
		var idx: int = int(i)
		if idx >= 0 and idx < jd.personajes.size() and not jd.equipo.has(jd.personajes[idx]):
			jd.equipo.append(jd.personajes[idx])   # la MISMA instancia, no una copia
	if jd.equipo.is_empty() and not jd.personajes.is_empty():
		jd.equipo.append(jd.personajes[0])   # sin equipo no hay con quien jugar
	jd.lider_pos = clampi(int(d.get("lider_pos", 0)), 0, maxi(0, jd.equipo.size() - 1))
	jd.dinero = int(d.get("dinero", 0))
	jd.materiales = []
	for m in d.get("materiales", []):
		var it: Resource = Net.suelo._item_de_dict(m as Dictionary)
		if it != null:
			jd.materiales.append(it)
	jd.crystals = []
	for c in d.get("crystals", []):
		var it2: Resource = Net.suelo._item_de_dict(c as Dictionary)
		if it2 != null:
			jd.crystals.append(it2)
	jd.carbon = []
	for cb in d.get("carbon", []):
		var it3: Resource = Net.suelo._item_de_dict(cb as Dictionary)
		if it3 != null:
			jd.carbon.append(it3)
	jd.lampara_llama = float(d.get("lampara_llama", 0.0))
	jd.lampara_llama_total = float(d.get("lampara_llama_total", 0.0))
	jd.cebo = String(d.get("cebo", ""))
	jd.consumibles = (d.get("consumibles", {}) as Dictionary).duplicate()
	# La mochila va por el MISMO criterio que el resto del equipo (antes llevaba un `true` a pelo, y
	# por ahi se colaba una mochila nueva en el baul en cada sincronizacion). Es suya y vive en este
	# mundo, pero eso se decide al darla de alta, no cada minuto. Ver Game.serializar_equipo, que le
	# guarda la capacidad porque es el unico campo de instancia que no esta en la meta.
	var mo: Resource = Game.deserializar_equipo(d.get("mochila", {}), registrar)
	if mo is BackpackData:
		jd.equipped_mochila = mo
		jd.owned_mochilas = [mo]
	# HERRAMIENTAS, por el MISMO criterio 'registrar' que la mochila y por la misma razon: con un
	# `true` a pelo cada sincronizacion periodica metería TRES herramientas nuevas en el baul. Es el
	# bug de las 6 hachas multiplicado por tres.
	jd.owned_tools = []
	for par in [["pico", "equipped_pico"], ["hoz", "equipped_hoz"], ["hacha", "equipped_hacha"],
			["cana", "equipped_cana"], ["cuchillo", "equipped_cuchillo"], ["lampara", "equipped_lampara"]]:
		var t: Resource = Game.deserializar_equipo(d.get(String(par[0]), {}), registrar)
		if t is ToolData:
			jd.set(String(par[1]), t)
			jd.owned_tools.append(t)
	jd.registro_pesca = (d.get("registro_pesca", {}) as Dictionary).duplicate(true)
	jd.mezcla_exp = float(d.get("mezcla", 0.0))
	jd.metalurgia_exp = float(d.get("metalurgia", 0.0))
	jd.peleteria_exp = float(d.get("peleteria", 0.0))
	jd.herreria_exp = float(d.get("herreria", 0.0))
	jd.carpinteria_exp = float(d.get("carpinteria", 0.0))
	jd.cocina_exp = float(d.get("cocina", 0.0))
	jd.materiales_vistos = (d.get("materiales_vistos", {}) as Dictionary).duplicate()
	jd.pack_inicial = bool(d.get("pack_inicial", false))
	jd.en_mazmorra = bool(d.get("en_mazmorra", false))
	jd.current_floor = maxi(1, int(d.get("current_floor", 1)))
	jd.pos = d.get("pos", Vector2.ZERO)
	jd.fecha_visto = Time.get_datetime_string_from_system(false, true)
	return jd


func ficha_a_dict(pj: PersonajeData) -> Dictionary:
	var d := {}
	for campo in ["nombre", "color", "metalico", "imagen", "color_alpha", "aspecto", "level",
			"ability_internal", "ability_consolidado", "ability_base_nivel",
			"fuerza", "resistencia", "destreza", "agilidad", "magia",
			"base_hp", "base_attack", "base_defense", "base_magic", "base_speed",
			"base_mp", "base_magia_factor", "base_crit",
			"current_hp", "current_mp", "stamina",
			"desarrollos_rango", "pasivas_rng", "guardianes_vencidos",
			"esquivas_exp", "hechizos_exp", "recitado_exp",
			"dano_recibido_exp", "dano_infligido_exp", "dano_bloqueado_exp"]:
		d[campo] = pj.get(campo)
	# Y su pocion a medias, para que el anfitrion pueda meterla en la pelea (ver _COLAS_POCION), y lo
	# que lleve puesto: estados, cargas de Foco e imbuicion (ver _LO_PUESTO).
	for campo in Net.peleas._COLAS_POCION + Net.peleas._LO_PUESTO:
		d[campo] = pj.get(campo)
	var sin_viajar: Array = []
	for r in Net.peleas._RANURAS:
		var pieza: Resource = pj.get(r)
		d[r] = Game.serializar_equipo(pieza)
		# No basta con que el diccionario no este vacio: tiene que llevar una ruta USABLE. Una
		# version anterior mandaba la ruta del propio guardado ("user://saves/...::Resource_x"), que
		# al otro lado no carga — y como el dict no venia vacio, este aviso no saltaba.
		if pieza != null and not Game._ruta_plantilla_valida(str((d[r] as Dictionary).get("ruta", ""))):
			sin_viajar.append(str(pieza.get("nombre")))
	# Una pieza que no viaja NO es un detalle: el doble entra sin ella y pelea con los puños, que es
	# un bug de balance silencioso. Se dice UNA vez por ficha, con nombres, en vez de callarlo.
	if not sin_viajar.is_empty():
		push_warning("[multi] %s viaja SIN: %s (no se pudo identificar su plantilla)" % [
			pj.nombre, ", ".join(sin_viajar)])
	# CON LOS HUECOS, y el hueco viaja como "". El set de magias guarda la RANURA de cada una (ver
	# Game._set_hechizos), asi que saltarse los null aqui corria las magias del doble una posicion:
	# el clasico campo que se pierde solo en multi y no da ningun error.
	var hechizos: Array = []
	for s in Game.hechizos_con_huecos(pj):
		if s != null and not String(s.resource_path).is_empty():
			hechizos.append(s.resource_path)
		else:
			hechizos.append("")
	d["spells"] = hechizos
	# Y los que SABE, que no son los mismos desde que aprender dejo de tener tope: sin mandarlos, al
	# otro lado el doble llega sin lista de sabidos y su pantalla de magias sale vacia -- no podria
	# volver a ponerse uno que se acaba de quitar. Es justo el fallo que solo se ve en multi.
	var sabidos: Array = []
	for s in Game.hechizos_sabidos(pj):
		if s != null and not String(s.resource_path).is_empty():
			sabidos.append(s.resource_path)
	d["spells_sabidos"] = sabidos
	# HABILIDADES de arma: lo que SABE y el set que lleva puesto POR TIPO DE ARMA. Sin esto el
	# doble entraba a la pelea con el set por DEFECTO de su arma en vez de con el suyo, que es un
	# bug de balance callado (el jugador ve otras cuatro habilidades y nadie avisa).
	# Viajan como rutas .tres, igual que los hechizos; el dict va con la clave en texto porque el
	# JSON no tiene claves enteras (al otro lado se vuelve a int, ver ficha_de_dict).
	var sabidas: Array = []
	for ab in pj.habilidades_aprendidas:
		if ab != null and not String(ab.resource_path).is_empty():
			sabidas.append(ab.resource_path)
	d["habs_sabidas"] = sabidas
	var sets: Dictionary = {}
	for clave in pj.loadout_habilidades:
		var rutas: Array = []
		for ab in pj.loadout_habilidades[clave]:
			# Los HUECOS viajan como "" y NO se saltan. Saltarlos acorta el array, y un set corto
			# es justo lo que Game._set_guardado interpreta como "posiciones que nunca han
			# existido" -> se las autorrellena. Resultado: el doble entraba con cuatro habilidades
			# donde su dueño llevaba una a proposito.
			rutas.append(ab.resource_path if ab != null and not String(ab.resource_path).is_empty() else "")
		sets[str(clave)] = rutas
	d["habs_sets"] = sets
	# SOBREPESO del que se une: viaja para que su doble vaya lento EL solo, no todo el grupo del
	# anfitrion. Es del loadout del HUMANO (su mochila), asi que va una vez por ficha con el mismo valor.
	d["overload"] = Game.overload_speed_factor()
	# AGOTAMIENTO (correr sin fuelle) y COOLDOWNS pendientes de sus habilidades. Los dos duran ENTRE
	# combates y los dos se perdian al unirse a la pelea de otro: el doble entraba descansado y con
	# los CD a cero. Van aqui, no en _LO_PUESTO, porque no son campos de la ficha (uno es una meta y
	# el otro vive en Game.ability_cooldowns_persist). Los CD viajan por RUTA, ver Game.cds_a_rutas.
	d["sin_fuelle"] = bool(pj.get_meta("sin_fuelle", false))
	d["cds"] = Game.cds_a_rutas(Game.ability_cooldowns_persist.get(pj, {}))
	return d


# registrar: ¿el equipo que llega pasa a vivir en MI baul?
#   false (por defecto) = es el DOBLE de otro humano en una pelea: su arma NO es mia. Sin esto se
#     colaba en mi baul una copia por cada vez que se unia a mi pelea (el bug de las 6 hachas).
#   true = el personaje es PERMANENTE y este mundo es su casa (un invitado que se crea o que vuelve
#     en un mundo compartido): entonces su equipo TIENE que registrarse, porque el baul del mundo es
#     el sitio donde viven esos objetos.
func ficha_de_dict(d: Dictionary, registrar := false) -> PersonajeData:
	var pj := PersonajeData.new()
	for campo in d:
		if campo == "spells" or campo == "habs_sabidas" or campo == "habs_sets" or Net.peleas._RANURAS.has(campo):
			continue
		pj.set(campo, d[campo])
	for r in Net.peleas._RANURAS:
		var item: Resource = Game.deserializar_equipo(d.get(r, {}), registrar)
		if item != null:
			pj.set(r, item)
			# Y su meta EQUIPADA apuntando al MISMO dict que la del objeto. Sin esto el doble
			# llevaba el arma pero con tier 1 y rareza comun: la identidad la lee equip_meta[slot]
			# (ver Game._meta), no el objeto. Es la misma invariante que restaura
			# _realinear_equip_meta al cargar una partida.
			pj.equip_meta[r.replace("equipped_", "")] = Game.meta_de(item)
	# El "" es un hueco VACIO y se restaura como tal: las ranuras del doble son las del original.
	# Una ficha vieja llega compacta y sin "": entra tal cual y Game._set_hechizos la rellena de
	# huecos por detras, que es exactamente lo que era.
	var hechizos: Array = []
	for ruta in d.get("spells", []):
		var s = load(String(ruta)) if not String(ruta).is_empty() else null
		hechizos.append(s)
	pj.equipped_spells = hechizos
	# Los SABIDOS. Una ficha de una version anterior no trae la clave: se queda vacia y
	# Game.hechizos_sabidos la reconstruye desde los equipados, que es lo que habia antes.
	var sabidos: Array = []
	for ruta in d.get("spells_sabidos", []):
		var s2 = load(String(ruta))
		if s2 != null:
			sabidos.append(s2)
	pj.hechizos_aprendidos = sabidos
	# Habilidades de arma (ver ficha_a_dict). La clave del set vuelve a int: es el
	# WeaponData.Tipo con el que la guardo Game.clave_loadout.
	var sabidas: Array = []
	for ruta in d.get("habs_sabidas", []):
		var ab = load(String(ruta))
		if ab != null:
			sabidas.append(ab)
	pj.habilidades_aprendidas = sabidas
	var sets: Dictionary = {}
	var sets_in: Dictionary = d.get("habs_sets", {})
	for clave in sets_in:
		var lista: Array = []
		for ruta in sets_in[clave]:
			# "" = hueco que su dueño dejo vacio; entra como null y se respeta tal cual.
			lista.append(load(String(ruta)) if String(ruta) != "" else null)
		sets[int(str(clave))] = lista
	pj.loadout_habilidades = sets
	# Lo que no es campo de la ficha, en metas (ver ficha_a_dict): las lee Game al meterlo en la
	# pelea. Los cooldowns siguen aqui en RUTAS; se traducen al aplicarlos.
	pj.set_meta("sin_fuelle", bool(d.get("sin_fuelle", false)))
	pj.set_meta("cds", d.get("cds", {}))
	return pj


# Lo que el doble ha vivido en la pelea, para devolverselo a su dueño.
func desgaste_a_dict(pj: PersonajeData) -> Dictionary:
	var d := {}
	for campo in Net.peleas._VUELVE:
		var v = pj.get(campo)
		# COPIA, no referencia. Los tres dicts de habilidad y los estados son objetos: metidos a pelo,
		# el lote apunta al MISMO dict de la ficha, asi que cualquier cambio posterior lo reescribe por
		# detras. Por red no se nota (el RPC serializa), pero en local el lote mentia.
		d[campo] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	# DE QUIEN ES ESTE LOTE. Va aparte de _VUELVE a proposito: el uid identifica, no se aplica (si
	# entrara en el bucle de arriba, aplicar_desgaste se lo escribiria encima al de casa).
	#
	# Antes el lote no llevaba identidad ninguna y el dueño lo cruzaba POR POSICION con su formacion
	# (ver _devolver_desgaste). Un solo puesto de desfase no "suma mal": COPIA un personaje entero
	# encima de otro -- excelia, nivel, las cinco stats, vida y contadores.
	d["uid"] = String(pj.uid)
	# Los COOLDOWNS que le queden al doble: van APARTE de _VUELVE porque no son un campo de la ficha
	# (viven en Game.ability_cooldowns_persist, ver Game.cds_a_rutas). Si no vuelven, el que se une a
	# la pelea de otro sale de ella con todas sus habilidades listas. Mientras se pelea los buenos
	# son los del COMBATIENTE (el dict de Game solo tiene los de la entrada): asi tambien salen bien
	# si se marcha a mitad, que es el otro camino que pasa por aqui.
	var vivo: Combatant = Game.combatant_de_pj(pj)
	d["cds"] = Game.cds_a_rutas(vivo.ability_cooldowns if vivo != null \
		else Game.ability_cooldowns_persist.get(pj, {}))
	return d


# LO QUE SOLO SUBE se funde por MAXIMO; lo demas se asigna.
#
# La excelia y los contadores ocultos nunca bajan, asi que si lo que llega es MENOR que lo que ya
# tengo, lo que llega esta rancio y hay que ignorarlo. Asignar a pelo tenia dos formas de perder
# progreso de verdad:
#   - la excelia de un ENCARGO que aterriza mientras espejo una pelea (Net._set_excelia_encargo
#     escribe en el PersonajeData real) se borraba al cerrarse la pelea;
#   - cualquier lote rezagado o repetido revertia lo ganado desde que se mando la ficha.
# Con el maximo, el peor caso de un paquete raro es que no aporte nada, nunca que reste.
const _SOLO_SUBEN := ["esquivas_exp", "hechizos_exp", "recitado_exp",
	"dano_recibido_exp", "dano_infligido_exp", "dano_bloqueado_exp"]
const _DICTS_HABILIDAD := ["ability_internal", "ability_consolidado", "ability_base_nivel"]

func aplicar_desgaste(pj: PersonajeData, d: Dictionary) -> void:
	for campo in Net.peleas._VUELVE:
		if not d.has(campo):
			continue
		if campo in _DICTS_HABILIDAD:
			pj.set(campo, _fundir_maximo(pj.get(campo), d[campo]))
		elif campo in _SOLO_SUBEN:
			pj.set(campo, maxf(float(pj.get(campo)), float(d[campo])))
		else:
			pj.set(campo, d[campo])
	if d.has("cds"):
		Game.ability_cooldowns_persist[pj] = Game.cds_de_rutas(d["cds"] as Dictionary)
	# Los estados vuelven como datos, pero lo que el mapa lee de ellos (cuanto te frenan, sus chips)
	# esta CACHEADO en la ficha: sin recalcularlo, el que se une a una pelea salia con el Pegajoso
	# puesto y andando a velocidad normal, y sin chips que lo dijeran.
	Game.refrescar_cache_estados(pj)


# Dos dicts de habilidad, quedandose con el mayor de cada stat. Las claves que solo esten en uno de
# los dos entran tal cual: un peer de otra version puede no traerlas todas.
func _fundir_maximo(mio_, suyo_) -> Dictionary:
	var mio := (mio_ if mio_ is Dictionary else {}) as Dictionary
	var suyo := (suyo_ if suyo_ is Dictionary else {}) as Dictionary
	var out: Dictionary = mio.duplicate()
	for k in suyo:
		out[k] = maxf(float(mio.get(k, 0.0)), float(suyo[k]))
	return out


# --- GUARDADO PREVENTIVO: el host guarda por los dos -------------------------------------------
#
# El guardado sincronizado de verdad (hito 6: un save autoritativo, la expedicion congelada y la
# posicion de cada invitado por identidad) es mucho mas grande y sigue pendiente. Esto es el
# PREVENTIVO acordado con el usuario: cuando el host da a Guardar, el invitado tambien guarda -- en SU
# ranura, en el PUEBLO de SU mundo, con el personaje tal y como esta en ese momento.
#
# Lo que se le guarda: objetos, nivel, excelia, oficios, pasivas... todo lo del PERSONAJE.
# Lo que NO: el progreso del MUNDO (bosses, tienda T2, mapa, vetas agotadas, baul y cofres comunes),
# porque eso es del mundo del HOST y en el suyo no lo ha hecho. De ahi el congelado de abajo.
#
# CONTRAPARTIDA (avisada): el invitado pierde el SITIO. Si estaba en el piso 8, al cargar sale en su
# pueblo. Su personaje y su bolsa, intactos.

# Lo que era MIO al entrar en la sesion, para devolverlo al save y no volcar el mundo del host.
# Vacio = no estoy de invitado (o ya me fui).
var _mundo_propio: Dictionary = {}


# Solo cliente, al conectar: aparta los campos del mundo PROPIO antes de que el host mande el suyo.
#
# No es cosmetico: mientras tengo el candado del taller, Game.almacen_materiales ES EL BAUL DEL HOST
# (ver _taller_ok). Guardar a pelo me metia en mi save los materiales de mi compañero.
func _congelar_mi_mundo() -> void:
	_mundo_propio = {
		"almacen_materiales": Game.almacen_materiales.duplicate(),
		"bote_dinero": Game.bote_dinero,
		"cofre_equipo": Game.cofre_equipo.duplicate(true),
		"cofre_consumibles": Game.cofre_consumibles.duplicate(true),
		# Los ENCARGOS son del mundo, igual que el cofre: los del host apuntan a gente y herramientas
		# que en mi partida no existen, asi que los mios se apartan y vuelven al desconectar.
		"encargos": Game.encargos.duplicate(true),
		"encargo_next_id": Game._encargo_next_id,
		"mazmorra_persistente": Game.mazmorra_persistente.duplicate(true),
		"mapa_snapshot": Game.mapa_snapshot.duplicate(true),
		"mapa_trabajo": Game.mapa_trabajo.duplicate(true),
		"bosses_derrotados": Game.bosses_derrotados.duplicate(),
		# Que METALES/MADERAS conoce mi oficio. Es progreso del MUNDO tanto como los bosses: lo que
		# se descubre picando aqui sale de las vetas del host, y si se queda pegado, al volver a mi
		# partida el herrero me ofrece sub-tiers que en mi mundo no he sacado nunca. Es la mitad
		# "LAN de siempre" del bug de los sub-tiers regalados; la otra mitad (mundo compartido) la
		# tapa Game.limpiar_mundo_heredado.
		"materiales_vistos": Game.materiales_vistos.duplicate(),
		# LA BIBLIOTECA con la que entre. Mientras dure la sesion es COMUN (lo que lea uno vale para
		# todos, ver _set_biblioteca), pero al salir cada uno recupera la suya: una tarde jugando con
		# tu hermano no te puede completar media coleccion. Es lo mismo que se hace con los bosses y
		# con los materiales conocidos.
		"biblioteca": Game.biblioteca.duplicate(),
		# El cupo del novato de MI mundo. Mientras juegue de invitado gasto el del host, y este vuelve
		# intacto al salir (Game.exportar_partida_invitado).
		"tiradas_novato": Game.tiradas_novato,
	}


# ¿Estoy jugando de invitado en el mundo de otro? Lo consulta Game.exportar_partida_invitado.
func mundo_propio_congelado() -> Dictionary:
	return _mundo_propio


# ============================================================
#  GUARDAR EN UN MUNDO COMPARTIDO: al reves que en el LAN de siempre
#  LAN de siempre: "guardaos todos" = cada uno escribe SU ranura. Aqui no: hay UN save y lo escribe
#  el HOST, asi que lo que se pide no es "guardate" sino "MANDAME LO TUYO".
#
#  Se espera a que contesten, pero con plazo: si alguien no responde (se le fue la red justo ahora),
#  se escribe su ultimo JugadorData conocido. Nunca se pierde su personaje; como mucho, sus ultimos
#  minutos. Bloquear el guardado del mundo por un peer mudo seria peor.
# ------------------------------------------------------------
const _PLAZO_ESTADOS := 1.5

var _estados_pedidos: Array = []   # peers a los que se les ha pedido y aun no han contestado


func recoger_estados(cerrando: bool = false) -> void:
	if not Net.activo or not Net.es_host or not Net.mundo_compartido:
		return
	_estados_pedidos = Net._peers.keys().filter(func(pid): return not Net.es_trabajador(pid))
	if _estados_pedidos.is_empty():
		return
	_dame_tu_estado.rpc(cerrando)
	var esperado := 0.0
	while not _estados_pedidos.is_empty() and esperado < _PLAZO_ESTADOS:
		await get_tree().create_timer(0.1).timeout
		esperado += 0.1
	if not _estados_pedidos.is_empty():
		push_warning("[multi] %d jugador(es) no mandaron su estado: se guarda el ultimo que tengo" % \
			_estados_pedidos.size())
	_estados_pedidos.clear()


# El host pide lo mio. Corre en el INVITADO.
@rpc("any_peer", "call_remote", "reliable")
func _dame_tu_estado(cerrando: bool) -> void:
	if Net.es_host or Net.soy_trabajador:
		return
	_mi_estado.rpc_id(1, jd_a_dict(Game.mi_jugador_data()))
	if not cerrando:
		Net._aviso_esquina("Partida guardada")
		return
	# El mundo se cierra: aqui no me queda nada (mi personaje se queda dentro de el). Un respiro para
	# que el paquete de arriba salga antes de cortar, o se guardaria sin mi ultimo rato.
	await get_tree().create_timer(0.4).timeout
	Net.desconectar()
	Net.estado_cambiado.emit("Se cerró el mundo. Tu personaje queda guardado dentro.")
	Net._sacar_a_escena("res://scenes/ui/multi_menu.tscn")


# Lo que manda el invitado. Corre EN EL HOST: lo mete en el mundo, tal cual, a nombre de su identidad.
#
# SIN REGISTRAR EL EQUIPO, y esto es lo importante. Esto corre en CADA guardado (el autoguardado del
# mundo es cada 60 s), y reconstruir una ficha con registrar=true mete su equipo en MI baul. Como
# crear_item hace base.duplicate(), cada vuelta son objetos NUEVOS y el guardia `not
# owned_weapons.has(item)` -- que compara por REFERENCIA -- no los reconoce: cada guardado añadia
# arma + escudo + 5 piezas + mochila al baul del host, y en media hora lo dejaba inservible.
# Su equipo ya se registro cuando entro al mundo (_alta_jugador / _alta_personaje); esto es una
# ACTUALIZACION, no un alta. Es el mismo fallo que el "bug de las 6 hachas" de ficha_de_dict, que se
# arreglo para el camino del combate y quedo vivo en este.
@rpc("any_peer", "call_remote", "reliable")
func _mi_estado(d: Dictionary) -> void:
	if not Net.es_host or not Net.mundo_compartido:
		return
	var quien := multiplayer.get_remote_sender_id()
	var identidad := String(Net._identidades.get(quien, ""))
	if identidad == "":
		return
	var jd: JugadorData = jd_de_dict(d, false)
	jd.id = identidad          # manda MI registro de quien es, no lo que diga el paquete
	# El estado ANTERIOR se tira: que se lleve consigo la meta de su equipo. Sin esto la fuga seguia
	# por debajo: crear_item apunta en item_meta ANTES de mirar 'registrar', asi que cada
	# sincronizacion dejaba ~8 entradas huerfanas que no purga nadie y que se vuelcan enteras al
	# save (y cada clave es un Resource, o sea un [sub_resource] entero en el .tres).
	_olvidar_meta_de(Game.jugadores_mundo.get(identidad))
	Game.jugadores_mundo[identidad] = jd
	_estados_pedidos.erase(quien)
	print("[multi] estado recibido de ", jd.nombre_visible, ": ", jd.resumen())


# La meta del equipo de un JugadorData que se va a TIRAR. Esas piezas las fabrico la sincronizacion
# anterior y no las referencia ya nadie, pero item_meta las tiene de CLAVE y eso las mantiene vivas
# (y las escribe en el save) para siempre.
func _olvidar_meta_de(jd) -> void:
	if not (jd is JugadorData):
		return
	for pj in (jd as JugadorData).personajes:
		if pj is PersonajeData:
			for r in Net.peleas._RANURAS:
				_olvidar_meta_item((pj as PersonajeData).get(r))
	_olvidar_meta_item((jd as JugadorData).equipped_mochila)
	for t in [(jd as JugadorData).equipped_pico, (jd as JugadorData).equipped_hoz,
			(jd as JugadorData).equipped_hacha, (jd as JugadorData).equipped_cana,
			(jd as JugadorData).equipped_cuchillo, (jd as JugadorData).equipped_lampara]:
		_olvidar_meta_item(t)


func _olvidar_meta_item(item) -> void:
	if not (item is Resource):
		return
	# SALVAGUARDA: si la pieza SI vive en mi baul (viene de un alta con registro, o de lo que dejo
	# acumulado este bug), su meta es la buena y borrarla la degradaria a T1/Comun -- meta_de fabrica
	# un por-defecto cuando no encuentra la entrada. Solo se olvida lo que no es de nadie.
	# Se pregunta por TIPO antes del has(): los arrays estan tipados y preguntarle a owned_armor por
	# un arma revienta (ver la nota de Game.sacar_de_baul).
	if item is ArmorData:
		if Game.owned_armor.has(item):
			return
	elif item is BackpackData:
		if Game.owned_mochilas.has(item):
			return
	elif item is ToolData:
		if Game.owned_tools.has(item):
			return
	elif Game.owned_weapons.has(item):
		return
	Game.item_meta.erase(item)


# Solo host: guardar por los dos. Mi partida la guarda quien me llama (el menu de pausa); aqui se le
# pide a cada invitado que guarde la suya. 'cerrando' = el host ha dado a "Guardar y SALIR": el
# invitado, ademas de guardar, se vuelve A SU MUNDO con la partida ya guardada, en vez de comerse un
# "el host ha cerrado la partida" a secas.
#
# ⚠️ ESTO ES EL CAMINO LEGADO (cada uno con su ranura). En un MUNDO COMPARTIDO no se usa: alli se
# llama a recoger_estados() y el host escribe UN save (ver arriba).
func guardar_todos(cerrando: bool = false) -> void:
	if not Net.activo or not Net.es_host or multiplayer.multiplayer_peer == null:
		return
	# .rpc() sin rpc_id = a TODOS los peers. Con dos o tres invitados guardan todos, cada uno en su
	# ranura: aqui no hay nada que asuma un solo invitado.
	_guardar_ahora.rpc(cerrando)
	if not cerrando:
		return
	# Un respiro antes de que el host corte: los RPC salen en el siguiente poll, y desconectar en el
	# mismo frame tiraria el paquete sin enviarlo (misma trampa que _rechazado). Sin esto el invitado
	# se quedaria sin guardar.
	await get_tree().create_timer(0.3).timeout


# Lo llama el INVITADO desde el menu de pausa: guardar no es privilegio del host. El invitado no
# puede guardar por su cuenta y ya (el host tiene que volcar SU mundo, que es donde estais jugando),
# asi que se lo PIDE y el host hace exactamente lo mismo que si hubiera pulsado el boton el.
func pedir_guardar_todos(cerrando: bool = false) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		return   # el host no se pide nada a si mismo: pause_menu ya llama a guardar_todos
	_pedir_guardar.rpc_id(1, cerrando)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_guardar(cerrando: bool = false) -> void:
	if not Net.es_host:
		return
	var quien: int = multiplayer.get_remote_sender_id()
	# MUNDO COMPARTIDO: no hay "guardar por los dos", hay UN save. Se recogen los estados de todos
	# (incluido el del que lo pide) y se escribe; Mundos.autoguardar ya hace las dos cosas en orden.
	if Net.mundo_compartido:
		var bien: bool = await Mundos.autoguardar()
		_aviso_guardado.rpc_id(quien, bien)
		return
	# El guardado del host lo hace Game (es quien habla con Perfil: ver la nota de _guardar_ahora).
	var ok: bool = Game.guardar_mi_partida()
	_aviso_guardado.rpc_id(quien, ok)
	if ok:
		# Y de aqui salen los guardados de TODOS los invitados, el que lo pidio incluido.
		guardar_todos(cerrando)


# Corre en el INVITADO que pidio guardar: si el host no pudo, que no se quede pensando que si.
@rpc("authority", "call_remote", "reliable")
func _aviso_guardado(ok: bool) -> void:
	Net.guardado_respondido.emit(ok)
	if not ok:
		Net._toast("El anfitrión no ha podido guardar: tu partida tampoco se ha guardado.")


# Corre en el INVITADO: guarda en SU ranura, en el pueblo de SU mundo.
@rpc("authority", "call_remote", "reliable")
func _guardar_ahora(cerrando: bool = false) -> void:
	# El guardado en si lo hace Game (es quien habla con Perfil): si net.gd llamara a Perfil se cerraria
	# un ciclo net -> Perfil -> Game -> net y GDScript deja de inferir los tipos de Game.* aqui dentro.
	var ok: bool = Game.guardar_partida_invitado()
	if not cerrando:
		# El exito es rutina (va a la esquina); el FALLO si es una noticia y sale en grande.
		if ok:
			Net._aviso_esquina("Partida guardada")
		else:
			Net._toast("El anfitrión ha guardado, pero tu partida NO se pudo guardar.")
		return
	# El host cierra la sesion. Me vuelvo A MI MUNDO con lo que se acaba de guardar: se RECARGA de la
	# ranura, que es la unica forma de garantizar que no me llevo nada del mundo del host (baul, mapa,
	# bosses, el piso en el que estaba). Salgo de la sesion PRIMERO, o desconectar pisaria lo cargado
	# restaurando el baul de antes.
	Net.desconectar()
	if ok and Game.recargar_mi_partida():
		Net.estado_cambiado.emit("El anfitrión ha guardado y cerrado. Vuelves a tu mundo.")
	else:
		# No se pudo guardar/recargar: al menos no dejarle dentro de un piso del mundo del host.
		Game.current_floor = 1
		Game.olvidar_mazmorra()
		Net.estado_cambiado.emit("El anfitrión ha cerrado la partida.")
	Net._sacar_a_escena("res://scenes/levels/town.tscn")


# ============================================================
#  EL PERSONAJE DEL QUE SE UNE (mundo compartido)
#  Tres mensajes y una regla: el invitado NO entra hasta que tiene ficha.
#    host -> _tu_jugador        "este eres tu en este mundo" (vuelve alguien conocido)
#    host -> _crea_tu_personaje "no te conozco: hazte uno" (primera vez)
#    cliente -> _alta_personaje  el que acaba de crear; el host lo guarda EN EL MUNDO
#    cliente -> _listo           ya lo he aplicado, y este es mi aspecto de verdad
#  El aspecto viaja en _listo y no en el saludo porque al saludar el invitado todavia no tiene cara.
# ------------------------------------------------------------

# El mundo pide un personaje nuevo. Lo recoge la UI (el menu de multijugador), porque abrir una
# pantalla no es cosa de la capa de red.
signal pedir_personaje(nombre_mundo: String)
# Ya tengo mi personaje del mundo y estoy dentro: quien escuche esto lleva al jugador al pueblo.
signal entrada_lista


# Lo llama la UI cuando el jugador ha terminado de crear su personaje para este mundo.
func mandar_alta_personaje(pj: PersonajeData) -> void:
	if not Net.activo or Net.es_host:
		return
	_alta_personaje.rpc_id(1, pj_a_dict(pj))


# MUDANZA: en vez de un personaje recien creado, se manda uno TRAIDO de una partida de un jugador,
# con sus acompañantes, su equipo puesto y su bolsa (ver Game.jugador_data_desde_ranura).
func mandar_alta_jugador(jd: JugadorData) -> void:
	if not Net.activo or Net.es_host or jd == null:
		return
	_alta_jugador.rpc_id(1, jd_a_dict(jd))


@rpc("any_peer", "call_remote", "reliable")
func _crea_tu_personaje(nombre_mundo: String) -> void:
	Net._respondio = true
	Net.estado_cambiado.emit("Es tu primera vez en este mundo: crea tu personaje.")
	pedir_personaje.emit(nombre_mundo)


# El invitado manda el personaje recien creado. Corre EN EL HOST: es el que lo guarda en el mundo,
# porque el mundo es suyo mientras tenga el cerrojo.
@rpc("any_peer", "call_remote", "reliable")
func _alta_personaje(d: Dictionary) -> void:
	if not Net.es_host or not Net.mundo_compartido:
		return
	var quien := multiplayer.get_remote_sender_id()
	if not Net._en_la_puerta.has(quien):
		return
	var identidad := String(Net._identidades.get(quien, ""))
	if identidad == "":
		return
	var pj: PersonajeData = pj_de_dict(d)
	pj.es_original = true       # EL personaje de esa persona en este mundo (su referencia)
	pj.dueno = identidad
	# Red de seguridad para clientes de versiones anteriores, que mandaban el uid vacio (no pasaban
	# por Game.fichar). Un personaje sin uid no se puede mandar de encargo ni cobrar su excelia. Se le
	# pone AQUI, antes de guardarlo, para que el uid que salga viaje de vuelta en jd_a_dict y las dos
	# maquinas partan del mismo.
	Game.asegurar_uid(pj)
	var jd := JugadorData.new()
	jd.id = identidad
	jd.nombre_visible = String(Net._en_la_puerta[quien].get("nombre", ""))
	jd.personajes = [pj]
	jd.equipo = [pj]
	jd.lider_pos = 0
	Game.jugadores_mundo[identidad] = jd
	print("[multi] alta de ", pj.nombre, " (", jd.nombre_visible, ") en el mundo")
	# Se le devuelve YA empaquetado: asi los dos lados parten de lo mismo y no hay dos verdades.
	_tu_jugador.rpc_id(quien, jd_a_dict(jd), Game.semilla_mundo)


# MUDANZA: el invitado trae un jugador ENTERO de una de sus partidas (personajes + bolsa + oficios).
# Corre EN EL HOST, que es quien manda mientras tenga el cerrojo del mundo, asi que aqui se valida
# todo lo que llega: no se admite un paquete que diga ser de otra persona, ni un equipo mas grande
# del que cabe. El equipo que traen los personajes se registra en el baul de este mundo (lo hace
# jd_de_dict via ficha_de_dict con registrar=true), que es donde tienen que vivir a partir de ahora.
@rpc("any_peer", "call_remote", "reliable")
func _alta_jugador(d: Dictionary) -> void:
	if not Net.es_host or not Net.mundo_compartido:
		return
	var quien := multiplayer.get_remote_sender_id()
	if not Net._en_la_puerta.has(quien):
		return
	var identidad := String(Net._identidades.get(quien, ""))
	if identidad == "":
		return
	# Ya tiene personaje aqui: no se le deja traer otro encima (seria machacar al que vive en el
	# mundo, y con el todo lo que hubiera hecho dentro).
	if Game.jugadores_mundo.get(identidad) is JugadorData:
		print("[multi] %s ya tiene personaje en este mundo: no se importa nada" % identidad)
		_tu_jugador.rpc_id(quien, jd_a_dict(Game.jugadores_mundo[identidad]), Game.semilla_mundo)
		return

	var jd: JugadorData = jd_de_dict(d)
	if jd.equipo.is_empty():
		print("[multi] el paquete de %s no trae equipo: no se da de alta" % identidad)
		return
	# La IDENTIDAD la pone el host con la del que lo manda, pase lo que pase en el diccionario.
	jd.id = identidad
	jd.nombre_visible = String(Net._en_la_puerta[quien].get("nombre", ""))
	# El grupo que baja no puede pasar del tope, y cada personaje queda a nombre de su dueño. Solo el
	# LIDER es "el original" de esa persona en este mundo; los acompañantes son contratados suyos.
	while jd.equipo.size() > Game.PARTY_MAX:
		jd.equipo.pop_back()
	jd.lider_pos = clampi(jd.lider_pos, 0, maxi(0, jd.equipo.size() - 1))
	for pj2 in jd.personajes:
		if pj2 is PersonajeData:
			(pj2 as PersonajeData).dueno = identidad
			(pj2 as PersonajeData).es_original = false
	var lider = jd.equipo[jd.lider_pos]
	if lider is PersonajeData:
		(lider as PersonajeData).es_original = true

	Game.jugadores_mundo[identidad] = jd
	print("[multi] MUDANZA: entra %s con %d personajes y %d materiales" % [
		jd.resumen(), jd.personajes.size(), jd.materiales.size()])
	_tu_jugador.rpc_id(quien, jd_a_dict(jd), Game.semilla_mundo)


# El host le da al invitado SU jugador de este mundo. Corre en el CLIENTE.
@rpc("any_peer", "call_remote", "reliable")
func _tu_jugador(d: Dictionary, semilla: int) -> void:
	Net._respondio = true
	# LO PRIMERO, antes de reconstruir nada: fuera lo que quede de mi partida anterior. Game es un
	# autoload y si venia de "Continuar" en una de mis ranuras, mi baul/almacen/mapa siguen puestos y
	# me los llevaba dentro del mundo de otro (ver Game.limpiar_mundo_heredado). Y va ANTES de
	# jd_de_dict porque ese registra en owned_*/item_meta el equipo que trae puesto mi personaje:
	# limpiar despues seria borrarselo.
	Game.limpiar_mundo_heredado()
	var jd: JugadorData = jd_de_dict(d)
	Game.aplicar_jugador_mundo(jd, semilla)
	# Entro SIEMPRE por el pueblo: la posicion de la mazmorra que traiga mi JugadorData es de una
	# expedicion que no es esta, y sin esto mi primera bajada me dejaba en ese sitio viejo.
	Game.pos_cargada = Vector2.INF
	Net.mundo_compartido = true
	var l: PersonajeData = Game.lider()
	# Y ahora si tengo cara: se manda con el "estoy listo" para que el host me registre con ella.
	_listo.rpc_id(1, Game.player_color, Game.player_metalico, Game.player_nombre,
		Game.player_imagen_png, Game.player_color_alpha,
		Game.lider().aspecto_completo()["piezas"])
	Net.estado_cambiado.emit("Entrando con %s." % (l.nombre if l != null else "tu personaje"))
	entrada_lista.emit()


# El invitado ya tiene ficha: ahora si se le mete dentro. Corre EN EL HOST.
@rpc("any_peer", "call_remote", "reliable")
func _listo(color: Color, metal: float, nombre: String, imagen: PackedByteArray, alpha: float,
		piezas: Dictionary = {}) -> void:
	if not Net.es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if not Net._en_la_puerta.has(quien):
		return
	var lugar := String(Net._en_la_puerta[quien].get("lugar", "pueblo"))
	Net._admitir(quien, color, metal, nombre, lugar, imagen, alpha, piezas)
