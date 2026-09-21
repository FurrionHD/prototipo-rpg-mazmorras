# ============================================================
#  net_jugadores.gd  (hijo de Net: /root/Net/Jugadores)
#  LO QUE LOS DEMAS VEN DE TI: posicion y pose (arma, espadazo, faena), si estas peleando, la piedra de
#  retorno compartida, el aspecto de tu grupo, imbuiciones, apoyo a otro jugador, entrar en su pelea,
#  el farolillo y los hechizos cantados en el mapa. Todo viaja por el host (topologia estrella).
#  Se llama como Net.jugadores.<funcion>.
# ============================================================
extends Node

const _PROYECTIL_HECHIZO := preload("res://scripts/actors/player/proyectil_hechizo.gd")


# --- POSICION (lo que hace que os veais moveros) --------------------------------------------
# ESTRANGULADA a ~20 Hz: el player la llama cada tick de fisica (60 Hz), pero mas no hace falta
# —remote_player interpola con SUAVIZADO entre paquetes, igual que los bichos—, y al pasar por el
# host se multiplicaria por el numero de destinos. Baja el trafico tambien con 2 jugadores.
const _POS_TICK_MS := 50   # ~20 Hz, hermano de _ENEM_TICK (que va en segundos)
var _pos_last_ms := 0

# --- LA POSE, DENTRO DEL PAQUETE DE POSICION -------------------------------------------------
# Lo que hace falta para dibujar a otro jugador HACIENDO cosas, y no solo andando: si va agachado o
# corriendo, si lleva el arma en la mano, y si esta soltando un espadazo. Antes no viajaba NADA de
# esto -- remote_player pintaba "modo andar" a pelo -- y por eso el compañero cruzaba la mazmorra sin
# sacar el arma y sin dar un solo golpe visible.
#
# VA EMPAQUETADO EN UN INT y pegado a la posicion, no en un RPC aparte. Motivo: un golpe dura ~0,67 s
# y el paquete sale a 20 Hz, asi que un espadazo cae dentro de ~13 paquetes seguidos. Aunque el canal
# sea unreliable y se pierdan varios, el golpe se ve igual -- mientras que un aviso suelto que se
# pierda no se ve NUNCA. El contador de golpes (que sube en cada espadazo) es lo que distingue "sigue
# el mismo golpe" de "ha empezado otro".
const POSE_MODO := 0b11          # bits 0-1: movement_mode (0 sigilo, 1 andar, 2 correr)
const POSE_DESENV := 1 << 2      # bit 2: lleva el arma fuera
const POSE_VARIANTE := 0b11 << 3 # bits 3-4: la mano del golpe (0 der, 1 izq, 2 dos manos)
const POSE_SEQ := 0xFF << 5      # bits 5-12: contador de espadazos, da la vuelta solo


static func empaquetar_pose(modo: int, desenvainado: bool, variante: int, seq: int,
		faena: int = 0, volteo: bool = false, tier: int = 1, golpe: int = 0) -> int:
	return (clampi(modo, 0, 3)) | (POSE_DESENV if desenvainado else 0) \
		| (clampi(variante, 0, 3) << 3) | ((seq & 0xFF) << 5) \
		| (clampi(faena, 0, 7) << POSE_FAENA_BIT) | ((1 << POSE_VOLTEO_BIT) if volteo else 0) \
		| (clampi(tier, 0, 7) << POSE_TIER_BIT) | (clampi(golpe, 0, 3) << POSE_GOLPE_BIT)


# LA FAENA (picar, talar...) viaja en la misma pose, en los bits de arriba: cual es (0 = ninguna,
# indice en PoseJugador.FAENAS + 1), si va volteada (a la izquierda del recurso) y el tier de la
# herramienta, para que el pico del otro salga de su metal. Cada golpe sube el mismo 'seq' que los
# espadazos, asi que no hace falta ningun mensaje nuevo.
const POSE_FAENA_BIT := 13
const POSE_VOLTEO_BIT := 16
const POSE_TIER_BIT := 17
# COMO HA SALIDO el ultimo golpe de la faena (el enum Golpe de su minijuego: flojo/limpio/bruto...).
# Con el, los demas oyen el golpe que toca y la maquina que mueve a los bichos sabe cuanto ruido ha
# hecho (ver RemotePlayer._faena_golpe_remoto).
const POSE_GOLPE_BIT := 20

static func golpe_de_pose(pose: int) -> int:
	return (pose >> POSE_GOLPE_BIT) & 0b11

static func faena_de_pose(pose: int) -> int:
	return (pose >> POSE_FAENA_BIT) & 0b111

static func volteo_de_pose(pose: int) -> bool:
	return ((pose >> POSE_VOLTEO_BIT) & 1) != 0

static func tier_de_pose(pose: int) -> int:
	return maxi(1, (pose >> POSE_TIER_BIT) & 0b111)


# La llama el Player LOCAL cada tick de fisica si Net.activo. Difunde su posicion a los de MI lugar.
func enviar_estado(pos: Vector2, facing: Vector2, comps: Array = [], pose: int = 0) -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not Net.activo or Net.soy_trabajador or multiplayer.multiplayer_peer == null:
		return
	var ahora := Time.get_ticks_msec()
	if ahora - _pos_last_ms < _POS_TICK_MS:
		return
	_pos_last_ms = ahora
	if Net.es_host:
		for pid in Net._peers:
			if Net._peers[pid].get("lugar", "") == Net._mi_lugar:
				Net.pisos._recibir_estado.rpc_id(pid, Net._mi_id(), pos, facing, comps, pose)
	else:
		_rel_estado.rpc_id(1, pos, facing, comps, pose)


# Cliente -> host: reparte mi posicion a los de MI lugar (el host sabe donde esta cada cual).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rel_estado(pos: Vector2, facing: Vector2, comps: Array = [], pose: int = 0) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	var lugar: String = Net._peers.get(de, {}).get("lugar", "")
	if Net._mi_lugar == lugar:
		Net.pisos._recibir_estado(de, pos, facing, comps, pose)
	for pid in Net._peers:
		if pid != de and Net._peers[pid].get("lugar", "") == lugar:
			Net.pisos._recibir_estado.rpc_id(pid, de, pos, facing, comps, pose)


# --- ¿QUIEN ESTA PELEANDO? (hito 5.3) --------------------------------------------------------
# Lo difunde Game al abrir/cerrar un combate. Sirve para que las paredes NO te paran bichos en las
# narices mientras estas en una pelea (no puedes ni verlo venir): ver spawn_zone._dist_min_de.
func avisar_combate(peleando: bool) -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not Net.activo or Net.soy_trabajador or multiplayer.multiplayer_peer == null:
		return
	Net._peleando = peleando
	if Net.es_host:
		for pid in Net._peers:
			_set_peleando.rpc_id(pid, Net._mi_id(), peleando)
	else:
		_rel_peleando.rpc_id(1, peleando)


@rpc("any_peer", "call_remote", "reliable")
func _set_peleando(emisor: int, peleando: bool) -> void:
	if Net._peers.has(emisor):
		Net._peers[emisor]["peleando"] = peleando


@rpc("any_peer", "call_remote", "reliable")
func _rel_peleando(peleando: bool) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_peleando(de, peleando)
	for pid in Net._peers:
		if pid != de:
			_set_peleando.rpc_id(pid, de, peleando)


# --- PIEDRA DE RETORNO: el viaje es COMPARTIDO ----------------------------------------------
# El que la gasta se va al instante (Game.volver_al_pueblo_con_objeto) y a los demas se les OFRECE
# subirse, gratis. Aqui solo se reparte el aviso; lo de enseñarlo y esperar a que el jugador este
# libre es cosa de la UI (retorno_menu.gd).
#
# El reparto va FILTRADO POR PISO, y ese filtro es lo que mantiene el sentido del tier de la piedra
# (T1 hasta el 6, T2 hasta el 12): al que esta en el pueblo no le llega nada, y al que esta mas
# hondo de lo que alcanza, tampoco. Regalarle el viaje seria convertir una piedra T1 en una T2 para
# todo el que no la paga.
#
# Molde: avisar_combate (arriba). El emisor puede ser cualquiera, asi que el cliente pasa por el
# host y el host reparte -- en estrella los clientes no se ven entre si.
func anunciar_retorno(piso_max: int, quien: String) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_repartir_retorno(piso_max, quien, Net._mi_id())
	else:
		_rel_retorno.rpc_id(1, piso_max, quien)


@rpc("any_peer", "call_remote", "reliable")
func _rel_retorno(piso_max: int, quien: String) -> void:
	if not Net.es_host:
		return
	_repartir_retorno(piso_max, quien, multiplayer.get_remote_sender_id())


# Solo host: a cada peer que este DENTRO y a tiro de la piedra. El host se auto-sirve si le cuadra
# (no puede mandarse un rpc a si mismo), y al que la uso no se le ofrece: ya esta subiendo.
func _repartir_retorno(piso_max: int, quien: String, de: int) -> void:
	if not Net.es_host:
		return
	if de != 1 and _alcanza_la_piedra(Net._mi_lugar, piso_max):
		Game.recibir_oferta_retorno(quien, piso_max)
	for pid in Net._peers:
		if pid == de or Net.es_trabajador(pid):
			continue
		if _alcanza_la_piedra(str(Net._peers[pid].get("lugar", "")), piso_max):
			_ofrecer_retorno.rpc_id(pid, piso_max, quien)


# ¿A ese LUGAR llega una piedra de ese alcance? "pueblo" no (ya estas arriba) y un piso por debajo
# de su tope tampoco.
func _alcanza_la_piedra(lugar: String, piso_max: int) -> bool:
	if not lugar.begins_with("piso:"):
		return false
	return int(lugar.substr(5)) <= piso_max


@rpc("any_peer", "call_remote", "reliable")
func _ofrecer_retorno(piso_max: int, quien: String) -> void:
	Game.recibir_oferta_retorno(quien, piso_max)


# Donde esta cada OTRO jugador de mi mismo lugar y si esta peleando. Lo consultan las zonas de
# parto para no hacer nacer bichos encima de nadie (y menos aun encima de quien pelea).
func jugadores_remotos_aqui() -> Array:
	var out: Array = []
	if not Net.activo:
		return out
	for id in Net._peers:
		var p: Dictionary = Net._peers[id]
		if p.get("lugar", "") == Net._mi_lugar and p.get("pos", Vector2.INF) != Vector2.INF:
			out.append({"pos": p["pos"], "peleando": bool(p.get("peleando", false))})
	return out


# --- ASPECTO DE MI GRUPO (hito 5.4) ----------------------------------------------------------
# El color/brillo/nombre de MIS acompañantes. Va aparte de la posicion (que viaja 60 veces por
# segundo) porque solo cambia cuando cambia el equipo. Se difunde al conectar y al tocar el grupo.
func anunciar_grupo() -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not Net.activo or Net.soy_trabajador or multiplayer.multiplayer_peer == null:
		return
	var datos: Array = []
	for pj in Game.companeros():
		# "piezas" = su pelo y su ropa (ver PersonajeData.aspecto_completo). La clave que no metas
		# aqui es la que hace que el compañero se vea distinto en la pantalla del otro, y solo ahi.
		datos.append({"color": pj.color, "metal": pj.metalico, "nombre": pj.nombre,
			"imagen": pj.imagen, "alpha": pj.color_alpha,
			"piezas": pj.aspecto_completo()["piezas"],
			# Lo que lleva puesto, igual que el lider (ver anunciar_aspecto). Aqui sale gratis porque
			# esto ya viajaba como diccionario.
			"equipo": Game.pj_a_dict(pj).get("equipo", {})})
	if Net.es_host:
		for pid in Net._peers:
			_set_grupo.rpc_id(pid, Net._mi_id(), datos)
	else:
		_rel_grupo.rpc_id(1, datos)


@rpc("any_peer", "call_remote", "reliable")
func _set_grupo(emisor: int, datos: Array) -> void:
	if not Net._peers.has(emisor):
		return
	Net._peers[emisor]["comps"] = datos
	# Si tenia cuerpos de mas (se dejo gente en casa), fuera; y a los que quedan, su cara nueva.
	var lista: Array = Net._avatares_comp.get(emisor, [])
	while lista.size() > datos.size():
		var sobra = lista.pop_back()
		if is_instance_valid(sobra):
			sobra.queue_free()
	for i in mini(lista.size(), datos.size()):
		if is_instance_valid(lista[i]):
			var d: Dictionary = datos[i]
			lista[i].aplicar_aspecto(d.get("color", Color.WHITE), float(d.get("metal", 0.0)),
				String(d.get("nombre", "")), d.get("imagen", PackedByteArray()),
				float(d.get("alpha", 1.0)), d.get("piezas", {}), d.get("equipo", {}))
	Net._avatares_comp[emisor] = lista


@rpc("any_peer", "call_remote", "reliable")
func _rel_grupo(datos: Array) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_grupo(de, datos)
	for pid in Net._peers:
		if pid != de:
			_set_grupo.rpc_id(pid, de, datos)


# --- IMBUICIONES DE MI GRUPO -----------------------------------------------------------------
# Canal PROPIO, y no un campo mas en anunciar_aspecto/anunciar_grupo, por una razon de peso: esos
# dos llevan el PNG del personaje (128x128) y solo cambian cuando te tocas la cara, mientras que la
# imbuicion se aplica y se gasta en CADA combate. Metida ahi, se habria reenviado la imagen entera
# de todo el grupo cada vez que a alguien se le acababan las cargas.
#
# El paquete es un int por persona, en el orden [lider] + companeros() -- el MISMO que usa
# anunciar_grupo, asi que el indice i+1 de aqui es el companero i de alli. Solo viaja el ID del
# elemento: el color lo saca cada maquina de Elementos.COLOR y no puede desincronizarse.
func anunciar_imbue() -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not Net.activo or Net.soy_trabajador or multiplayer.multiplayer_peer == null:
		return
	var elems := _mis_imbues()
	if Net.es_host:
		for pid in Net._peers:
			_set_imbue.rpc_id(pid, Net._mi_id(), elems)
	else:
		_rel_imbue.rpc_id(1, elems)


func _mis_imbues() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.append(Game.lider().imbue_elemento())
	for pj in Game.companeros():
		out.append(pj.imbue_elemento())
	return out


@rpc("any_peer", "call_remote", "reliable")
func _set_imbue(emisor: int, elems: PackedInt32Array) -> void:
	if not Net._peers.has(emisor):
		return
	# Se guarda en _peers ADEMAS de repintar: quien entre despues (o vuelva a montar la vista al
	# viajar) recrea los avatares desde aqui, y sin esto nacerian sin rastro.
	Net._peers[emisor]["imbue"] = elems
	_aplicar_imbue_a_avatares(emisor, elems)


# Reparte el paquete entre el avatar del lider y los de sus companeros. Lo llaman el RPC y las dos
# rutas de creacion de avatares (ver _crear_avatar_comp y _montar_avatar).
func _aplicar_imbue_a_avatares(emisor: int, elems: PackedInt32Array) -> void:
	var a = Net._avatares.get(emisor)   # SIN tipar: puede estar liberado
	if a != null and is_instance_valid(a) and a.has_method("aplicar_imbue"):
		a.aplicar_imbue(_imbue_en(elems, 0))
	var lista: Array = Net._avatares_comp.get(emisor, [])
	for i in lista.size():
		if is_instance_valid(lista[i]) and lista[i].has_method("aplicar_imbue"):
			lista[i].aplicar_imbue(_imbue_en(elems, i + 1))


# Elemento en la posicion i, o NINGUNO si el paquete es mas corto (peer de una version anterior, o
# grupo que ha crecido entre dos anuncios).
func _imbue_en(elems: PackedInt32Array, i: int) -> int:
	return int(elems[i]) if i >= 0 and i < elems.size() else Elementos.Elemento.NINGUNO


# --- APOYO AL PERSONAJE DE OTRO JUGADOR (Mantos, curas y buffs desde el mapa) -----------------
# La ficha de ese personaje vive en la maquina de su dueño, asi que se aplica ALLI. Viaja la ruta del
# hechizo y a quien: 'idx' en el orden [lider] + companeros() (el de _mis_imbues) y el nombre como
# comprobacion, por si su grupo ha cambiado entre medias; 'grupo' = a todos los suyos. La cura que pone
# el que lanza ya va calculada (Game.cura_magica_de). El mana ya lo cobro quien lo recito.
# 'entre' = a cuantos se reparte la cura (la de area divide entre todos los que alcanza).
func apoyo_a_otro(spell: SpellData, peer: int, idx: int, nombre: String, grupo: bool, entre: int = 1) -> void:
	if not Net.activo or spell == null or peer == 0:
		return
	var lanzador: String = Game.lider().nombre
	var cura: float = Game.cura_magica_de(spell, Game.lider())
	if Net.es_host:
		_apoyarte.rpc_id(peer, spell.resource_path, idx, nombre, lanzador, cura, grupo, entre)
	else:
		_rel_apoyo.rpc_id(1, peer, spell.resource_path, idx, nombre, lanzador, cura, grupo, entre)


@rpc("any_peer", "call_remote", "reliable")
func _rel_apoyo(peer: int, ruta: String, idx: int, nombre: String, lanzador: String, cura: float,
		grupo: bool, entre: int) -> void:
	if not Net.es_host:
		return
	if peer == Net._mi_id():
		_apoyarte(ruta, idx, nombre, lanzador, cura, grupo, entre)
	elif Net._peers.has(peer):
		_apoyarte.rpc_id(peer, ruta, idx, nombre, lanzador, cura, grupo, entre)


# Corre en el DUEÑO del personaje.
@rpc("authority", "call_remote", "reliable")
func _apoyarte(ruta: String, idx: int, nombre: String, lanzador: String, cura: float, grupo: bool,
		entre: int) -> void:
	var spell = load(ruta) if ruta.begins_with("res://") else null
	if not (spell is SpellData) or not (spell as SpellData).es_apoyo():
		return
	var sp: SpellData = spell
	# Metido en una pelea, la ficha la lleva el combate y la pisaria al cerrarse. No deberia llegar aqui
	# (quien lanza te ve peleando y entra en tu pelea en vez de mandar esto), pero la carrera existe.
	if Game.hay_pelea_en_pantalla():
		Net._toast("✨ %s intentó echarte %s, pero estabas peleando." % [lanzador, sp.nombre])
		return
	var mios: Array = [Game.lider()]
	mios.append_array(Game.companeros())
	var destinos: Array = []
	if grupo:
		destinos = mios
	elif idx >= 0 and idx < mios.size() and (mios[idx] as PersonajeData).nombre == nombre:
		destinos = [mios[idx]]
	else:
		for g in mios:
			if (g as PersonajeData).nombre == nombre:
				destinos = [g]
				break
	var partes: PackedStringArray = []
	for pj in destinos:
		var hecho: String = Game.apoyo_desde_mapa(sp, pj, lanzador, cura, entre)
		if hecho != "":
			partes.append("%s: %s" % ["tú" if pj == Game.lider() else (pj as PersonajeData).nombre, hecho])
	if not partes.is_empty():
		Net._toast("✨ %s te echa %s.  %s" % [lanzador, sp.nombre, "  ·  ".join(partes)])


# --- LOS EFECTOS DE UNA CURA DE AREA, para que los vean los demas -----------------------------
# El circulo verde mientras recitas y la onda al soltarla (AreaCuracion) cuelgan del cuerpo del que la
# lanza. Aqui viaja solo QUE hay que pintar: el dibujo lo hace cada pantalla sobre el avatar del emisor.
# Mismo camino que el bocadillo del canto (anunciar_canto): por el host, a los del mismo lugar.
const FX_CURA_APAGAR := 0
const FX_CURA_CIRCULO := 1
const FX_CURA_ONDA := 2
var _circulos_cura: Dictionary = {}   # emisor -> AreaCuracion que se esta pintando sobre su avatar


func anunciar_fx_cura(que: int) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		for pid in Net._peers:
			if Net._peers[pid].get("lugar", "") == Net._mi_lugar:
				_set_fx_cura.rpc_id(pid, Net._mi_id(), que)
	else:
		_rel_fx_cura.rpc_id(1, que, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _set_fx_cura(emisor: int, que: int) -> void:
	var viejo = _circulos_cura.get(emisor)   # SIN tipar: puede estar liberado
	if viejo != null and is_instance_valid(viejo):
		viejo.apagar()
	_circulos_cura.erase(emisor)
	var a = Net._avatares.get(emisor)
	if a == null or not is_instance_valid(a) or que == FX_CURA_APAGAR:
		return
	if que == FX_CURA_CIRCULO:
		_circulos_cura[emisor] = AreaCuracion.circulo(a)
	elif que == FX_CURA_ONDA:
		AreaCuracion.onda(a)


@rpc("any_peer", "call_remote", "reliable")
func _rel_fx_cura(que: int, lugar: String) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar:
		_set_fx_cura(de, que)
	for pid in Net._peers:
		if pid != de and Net._peers[pid].get("lugar", "") == lugar:
			_set_fx_cura.rpc_id(pid, de, que)


# --- ENTRAR EN LA PELEA DE UN JUGADOR (el que la ejecuta puede no ser el) ---------------------
# Para echarle una magia de apoyo a alguien que esta peleando hay que entrar en SU pelea, pero esa
# pelea la puede estar ejecutando otro (el esta espejando). Asi que se le pregunta a EL quien la lleva,
# que es el unico que lo sabe seguro, y con la respuesta se pide sitio por la via de siempre.
func unirme_a_la_pelea_del_jugador(peer: int) -> void:
	if not Net.activo or peer == 0 or peer == Net._mi_id():
		return
	_dime_tu_pelea.rpc_id(peer)


@rpc("any_peer", "call_remote", "reliable")
func _dime_tu_pelea() -> void:
	var anfitrion: int = Net._mi_id() if Net.peleas._pelea_id != 0 else Net.peleas._pelea_anfitrion
	_esta_es_mi_pelea.rpc_id(multiplayer.get_remote_sender_id(), anfitrion)


@rpc("any_peer", "call_remote", "reliable")
func _esta_es_mi_pelea(anfitrion: int) -> void:
	if anfitrion == 0:
		Net._toast("Esa pelea ya ha terminado.")
		return   # la nota del conjuro caduca sola y devuelve el mana (Game.tick_hechizo_de_entrada)
	Net.peleas.solicitar_unirse(anfitrion)


@rpc("any_peer", "call_remote", "reliable")
func _rel_imbue(elems: PackedInt32Array) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_imbue(de, elems)
	for pid in Net._peers:
		if pid != de:
			_set_imbue.rpc_id(pid, de, elems)


# --- EL FAROLILLO DE CADA UNO ------------------------------------------------------------------
# Cuanto alumbra su lampara, en celdas. Canal propio y calcado del de las imbuiciones, por lo mismo:
# es un numero minusculo que cambia a su ritmo (enciendes, se gasta el carbon, cambias de farolillo)
# y no puede ir colgado de anunciar_aspecto, que arrastra el PNG del personaje.
#
# Antes NO viajaba nada de esto, y niebla._focos() le ponia a todos los aliados MI radio: en la
# pantalla de cada uno, el compañero alumbraba exactamente lo que alumbrabas tu. Se veia raro
# justamente cuando importa -- yo sin carbon y el otro con el farolillo bueno, y aun asi veia igual.
#
# Es SOLO del lider: los acompañantes van pegados a el y su luz es la misma (en local pasa igual,
# ver _focos). Un solo float, y el que no lo anuncie se queda con el suelo duro de vision.
#
# SE LLAMA CADA FRAME (desde niebla._focos) y manda solo cuando el numero CAMBIA de verdad. Es a
# proposito: el radio se mueve por media docena de motivos -enciendes, se acaba el trozo de carbon,
# prende el siguiente, te cambias el farolillo, bajas un piso- y engancharse a los seis call sites
# es la clase de lista a la que siempre se le olvida uno. Comparar un float por frame no cuesta nada
# y no se puede olvidar ninguno.
var _luz_anunciada: float = -1.0

func anunciar_luz() -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not Net.activo or Net.soy_trabajador or multiplayer.multiplayer_peer == null:
		return
	var r: float = Game.radio_lampara()
	if is_equal_approx(r, _luz_anunciada):
		return
	_luz_anunciada = r
	if Net.es_host:
		for pid in Net._peers:
			_set_luz.rpc_id(pid, Net._mi_id(), r)
	else:
		_rel_luz.rpc_id(1, r)


@rpc("any_peer", "call_remote", "reliable")
func _set_luz(emisor: int, radio: float) -> void:
	if not Net._peers.has(emisor):
		return
	# En _peers ADEMAS de en el avatar: quien entre despues -o vuelva a montar la vista al viajar-
	# recrea los cuerpos desde aqui, y sin esto nacerian con el radio por defecto.
	Net._peers[emisor]["luz"] = radio
	_aplicar_luz_a_avatares(emisor, radio)


func _aplicar_luz_a_avatares(emisor: int, radio: float) -> void:
	var a = Net._avatares.get(emisor)   # SIN tipar: puede estar liberado
	if a != null and is_instance_valid(a) and a.has_method("aplicar_luz"):
		a.aplicar_luz(radio)
	for c in Net._avatares_comp.get(emisor, []):
		if is_instance_valid(c) and c.has_method("aplicar_luz"):
			c.aplicar_luz(radio)


@rpc("any_peer", "call_remote", "reliable")
func _rel_luz(radio: float) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_luz(de, radio)
	for pid in Net._peers:
		if pid != de:
			_set_luz.rpc_id(pid, de, radio)


# --- CANTAR HECHIZOS EN EL MAPA: lo que ven los demas ------------------------------------------
# Puro ADORNO, y por eso va por su propio canal y no con la pelea: el bocadillo sobre la cabeza del
# que esta recitando y el conjuro que sale disparado. Nada de esto decide nada — quien resuelve el
# hechizo es la maquina que acaba montando el combate (ver Game._soltar_hechizo_de_entrada).
#
# 'texto' vacio = ha dejado de cantar (lo ha soltado, ha fallado o lo ha cancelado).
func anunciar_canto(texto: String, color: Color) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		for pid in Net._peers:
			if Net._peers[pid].get("lugar", "") == Net._mi_lugar:
				_set_canto.rpc_id(pid, Net._mi_id(), texto, color)
	else:
		_rel_canto.rpc_id(1, texto, color, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _set_canto(emisor: int, texto: String, color: Color) -> void:
	var a = Net._avatares.get(emisor)   # SIN tipar: puede estar liberado
	if a == null or not is_instance_valid(a) or not a.has_method("cantar"):
		return
	a.cantar(texto, color)


@rpc("any_peer", "call_remote", "reliable")
func _rel_canto(texto: String, color: Color, lugar: String) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar:
		_set_canto(de, texto, color)
	for pid in Net._peers:
		if pid != de and Net._peers[pid].get("lugar", "") == lugar:
			_set_canto.rpc_id(pid, de, texto, color)


# El conjuro que sale volando hacia un bicho. Viaja el net_id del objetivo (que es lo unico que
# significa lo mismo en las dos maquinas), el color y la RUTA del hechizo: de ella salen la forma y
# el tamaño del proyectil (ver proyectil_hechizo), asi que sin ella el compañero veria un conjuro
# generico donde tu ves una Tormenta.
func anunciar_conjuro(objetivo: Node, color: Color, spell: SpellData = null) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null or objetivo == null:
		return
	var id: int = int(objetivo.get_meta("net_id", 0)) if objetivo.has_meta("net_id") else 0
	if id == 0:
		return
	var ruta: String = String(spell.resource_path) if spell != null else ""
	if Net.es_host:
		for pid in Net._peers:
			if Net._peers[pid].get("lugar", "") == Net._mi_lugar:
				_set_conjuro.rpc_id(pid, Net._mi_id(), id, color, ruta)
	else:
		_rel_conjuro.rpc_id(1, id, color, ruta, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _set_conjuro(emisor: int, id: int, color: Color, ruta: String = "") -> void:
	var a = Net._avatares.get(emisor)
	var obj = Net.enemigos._enem_nodos.get(id)
	if a == null or not is_instance_valid(a) or obj == null or not is_instance_valid(obj):
		return
	var p: Node2D = _PROYECTIL_HECHIZO.new()
	p.setup(obj, color, load(ruta) as SpellData if ruta != "" else null)
	p.global_position = (a as Node2D).global_position
	var mundo: Node = get_tree().current_scene
	if mundo != null:
		mundo.add_child(p)


@rpc("any_peer", "call_remote", "reliable")
func _rel_conjuro(id: int, color: Color, ruta: String, lugar: String) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar:
		_set_conjuro(de, id, color, ruta)
	for pid in Net._peers:
		if pid != de and Net._peers[pid].get("lugar", "") == lugar:
			_set_conjuro.rpc_id(pid, de, id, color, ruta)


# Tira los cuerpos de los acompañantes de un peer (cambio de lugar, se fue, fin de sesion).
func _quitar_companeros(peer_id: int) -> void:
	for c in Net._avatares_comp.get(peer_id, []):
		if is_instance_valid(c):
			c.queue_free()
	Net._avatares_comp.erase(peer_id)
