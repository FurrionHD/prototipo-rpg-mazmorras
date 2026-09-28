# ============================================================
#  combat_tactico.gd  (tema de la pantalla de combate: combat.turno_mapa)
#  EL TURNO CUANDO SE PELEA EN EL MAPA: quien anda, cuanto, y hasta donde.
#
#  Lo que añade al combate de siempre es SOLO el movimiento. El turno sigue siendo el mismo -- lo
#  reparte el ATB, lo resuelven _accion_atacar / habilidades / magia -- y esto se mete en dos huecos:
#
#    TU TURNO        mientras la barra de acciones esta a la vista, el personaje que tiene el turno
#                    anda libre dentro de su circulo. Elegir accion cierra el turno (el tacto de
#                    Trails): moverte + 1 accion, y el ATB no corre mientras piensas, porque
#                    WAITING_PLAYER ya lo congela.
#    SU TURNO        antes de decidir que hace, el enemigo se ACERCA a su presa con la misma regla de
#                    radio que tu. Con TOPE DURO DE TIEMPO: no hay NavigationAgent en el proyecto y la
#                    IA es de rayos, asi que un bicho atascado contra una pared colgaria la pelea -- y
#                    en multi, a todos. Llegue o no, al acabar el tope actua desde donde este.
#
#  EL BORDE CAMBIA "PASAR" POR "HUIR". El sexto boton de la barra (abajo a la derecha) cede el turno;
#  pegado al muro de la arena se convierte en Huir, que va por _accion_huir de siempre, con su tirada
#  de Agilidad y su excelia. Antes el muro sacaba una pregunta arriba del tablero: lejos de los botones
#  y poco intuitiva (lo pidio cambiar el usuario el 24/09).
#
#  LA REGLA DE SIEMPRE: aqui no se resuelve daño. Si alguna vez hace falta un if de "tactico" dentro
#  de una funcion que pega, la costura esta mal puesta.
#
#  EN MULTI, DESDE EL PRINCIPIO. Quien mueve cada cuerpo:
#    TUS PERSONAJES   los mueve TU maquina, siempre -- tambien si la pelea la lleva otro y tu la ves
#                     en espejo. Es la que tiene sus cuerpos de verdad, y su posicion ya viaja por el
#                     canal del jugador (Net.jugadores.enviar_estado, con el sequito). El radio te lo
#                     manda quien lleva la pelea con la peticion de turno, y tu posicion le vuelve
#                     sellada con tu accion (pos_para_red / anotar_pos_remota).
#    LOS BICHOS       los mueve quien lleva la pelea, y se lo cuenta a su DUEÑO (el del piso) para
#                     que los ponga en su sitio y los reparta por su tick de siempre
#                     (Net.peleas.mover_bichos_en_pelea).
#    EL CIRCULO       de quien tiene el turno viaja con la barra de turnos (estado_red), para que todos
#                     vean quien anda y hasta donde.
#  Y CADA MAQUINA ENCUENTRA LOS CUERPOS EN SU MUNDO por una direccion que viaja en el roster: un
#  aliado es "el personaje k del jugador tal" y un bicho es su id de red (direccion_red / cuerpo_de).
#
#  EL ALCANCE Y LA HUELLA (fase 5): para pegar hay que llegar (llega / alcanzables), y las habilidades
#  ya hechas para el mapa se APUNTAN con el raton (apuntar / reparto_habilidad): pegan a todo lo que la
#  huella roce, sin tope. Mientras se recita NO se anda (decision del usuario: no hay reposicion entre
#  frases). Las huellas las ven TODOS (estado_huellas / aplicar_huellas). PENDIENTE: la magia con su rango.
# ============================================================
extends RefCounted

const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# A que paso anda tu personaje en su turno, en px de mundo por segundo. Es el andar del mapa: el
# turno no se juega a la carrera, y a este ritmo se ve bien hasta donde llegas.
const VEL_PASEO := 110.0
# A que paso se acerca el enemigo. Algo mas vivo que tu, porque este lo miras sin tocar nada.
const VEL_ACERCARSE := 150.0
# EL TOPE del acercamiento, en segundos DE PELEA (a x2 dura la mitad). Llegue o no, actua.
const TOPE_ACERCARSE := 1.6
# Se da por atascado al que no avanza ni esto en ATASCO_T segundos: no tiene sentido agotar el tope
# empujando una pared.
const ATASCO_PX := 0.5
const ATASCO_T := 0.25
# EL ALCANCE, en px de HUECO entre cuerpos (Cuerpos.hueco, la cuenta del golpe por el mapa). Lo de
# cada uno viene en Combatant.alcance (su arma, o su ficha de enemigo); esto es el suelo para quien
# no lo diga.
const ALCANCE_MINIMO := 6.0
# El enemigo se arrima hasta esta fraccion de su alcance, no hasta el limite justo: parado en el
# borde exacto, el redondeo de la red podia dejarle a medio pixel de no llegar.
const ARRIMARSE := 0.75
# Lo que se le perdona a la posicion de OTRO humano al mirar si llega: su cuerpo llega interpolado y
# su posicion sellada puede no cuadrar al pixel con la de su pantalla. Nunca se rechaza por eso.
const HOLGURA_ALCANCE := 6.0
# Un cuerpo no se monta encima de uno del OTRO bando: no puede meterse a menos de esto. Solo frena al
# que se ACERCA, asi que dos que empiezan solapados se pueden separar.
const SEPARACION := 22.0
# Cuanto se deja el paso por dentro del borde de la arena. Por DEBAJO del margen con el que el borde
# avisa (ArenaCombate.MARGEN): si no, nunca llegarias a tocarlo y no se te podria preguntar si huyes.
const DENTRO_DEL_BORDE := 4.0
# La huella de pies de quien no declara ninguna forma de colision.
const HUELLA_POR_DEFECTO := Vector2(16.0, 12.0)

# MOVIENDO  anda uno de los mios, en esta maquina.
# ACERCANDO se acerca un bicho (solo en la maquina que lleva la pelea).
# AJENO     tiene el turno uno que se mueve en OTRA maquina: aqui solo se pinta su circulo; su cuerpo
#           lo trae la red.
enum Fase { NADA, MOVIENDO, ACERCANDO, AJENO }
var _fase: int = Fase.NADA

# EN EL ESPEJO: el roster que mando quien lleva la pelea. De ahi sale la direccion de cada cuerpo.
var roster_red: Dictionary = {}

# LOS BICHOS MOVIDOS que aun no se le han contado a su dueño: id -> [pos, angulo, andando].
var _bichos_movidos: Dictionary = {}
var _t_envio: float = 0.0
const ENVIO_BICHOS := 1.0 / 20.0   # el mismo ritmo que el tick de enemigos de su dueño

# EL QUE TIENE EL TURNO y su cuerpo del mapa.
var _quien: Combatant = null
var _cuerpo: Node2D = null
var _inicio: Vector2 = Vector2.ZERO   # donde estaba al empezar el turno: el centro del circulo
var _radio: float = 0.0
var _andando: bool = false

# A QUIEN SIGUE LA CAMARA: el cuerpo del ultimo que ha tenido el turno (tuyo, de un compañero o de un
# enemigo). Se queda en el mientras se resuelve la accion. Ver Game.camara_tactica_sigue.
var _foco: Node2D = null

# EL ACERCAMIENTO del enemigo.
var _presa: Combatant = null
var _t_acercar: float = 0.0
var _t_atasco: float = 0.0

# LAS POSICIONES, por combatiente. La verdad es el cuerpo del mapa; esto es lo que se apunta cada vez
# que alguien se mueve, para que la geometria (fase 5) y la red (fase 7) lo lean de un sitio sin
# tener que ir buscando nodos. Mismo patron que _defendiendo o _casteos: en el tema, no en Combatant.
var _pos: Dictionary = {}

# Lo que se le cambio a cada nodo visual para que se animara con el arbol en pausa, para devolverlo.
var _modos_guardados: Array = []



# ------------------------------------------------------------
#  MONTAR / DESMONTAR
# ------------------------------------------------------------

# Se llama al acabar de montar la pantalla. Deja los cuerpos listos para andar.
func montar() -> void:
	# EL BOTON DE HUIR ES "PASAR" y se vuelve "Huir" pegado al borde (ver en_el_borde y
	# combat._huir_es_pasar). Lo decide _refresh_actions, que ya se repinta al andar.
	# LOS DIBUJOS SE ANIMAN AUNQUE EL ARBOL ESTE EN PAUSA. En solitario, abrir la pelea pausa el
	# piso entero, y con el los sprites: un bicho que se acerca se deslizaria como una estatua. Se le
	# da PROCESS_MODE_ALWAYS solo a lo que PINTA (el sprite, el muñeco), no al cuerpo: el cuerpo
	# llevaria dentro su IA y su lectura del teclado, y eso tiene que seguir parado.
	for c in _pantalla._aliados + _pantalla._enemies:
		_preparar(c)
	# LAS BARRAS DE ARRIBA pasan a leer la pelea (vida, energia de combate y mana en vivo).
	var pl: Node = _jugador_local()
	if pl != null:
		pl.usar_barras_de_pelea(combatiente_de_mi_pj)


func _jugador_local() -> Node:
	var pl: Node = _pantalla.get_tree().get_first_node_in_group("player") if _pantalla.is_inside_tree() else null
	return pl if pl != null and pl.has_method("usar_barras_de_pelea") else null


# Lo llama combat._update_hp tras cada cambio de verdad: en solitario el arbol esta en pausa y el
# jugador no repinta solo.
func refrescar_barras_grupo() -> void:
	var pl: Node = _jugador_local()
	if pl != null:
		pl.refrescar_barras()
	pintar_imbuiciones()


# LA IMBUICION DE CADA UNO DE LOS TUYOS, EN SU CUERPO (aura del Manto, efecto del Filo en el arma). En
# pelea sale del COMBATIENTE: el Filo emponzoñado se pone a media pelea y las cargas se gastan golpe a
# golpe, y la ficha no se entera hasta el cierre. Vale en el espejo (el maniqui trae sus campos).
# 'soltar' devuelve cada muñeco a lo que diga su ficha (al acabar la pelea).
func pintar_imbuiciones(soltar: bool = false) -> void:
	for c in _pantalla._aliados:
		var cu: Node2D = cuerpo_de(c)
		if cu == null:
			continue
		var m = cu.get("_muneco")
		if m is MunecoJugador:
			(m as MunecoJugador).poner_imbue_pelea(-1 if soltar else ImbueVisual.de_combatiente(c))


# El combatiente de uno de MIS personajes, para sus barras de arriba. En quien lleva la pelea sale de
# Game; en el ESPEJO, del roster: la fila que es mia y lleva su mismo cuerpo (Game.indice_de_cuerpo).
func combatiente_de_mi_pj(pj: PersonajeData) -> Combatant:
	if not _pantalla._espejo:
		return Game.combatant_de_pj(pj)
	var k: int = Game.indice_de_cuerpo(pj)
	var filas: Array = roster_red.get("aliados", [])
	for i in mini(filas.size(), _pantalla._aliados.size()):
		var d: Dictionary = filas[i]
		if int(d.get("peer", -1)) == _mi_id() and int(d.get("cuerpo", -2)) == k:
			return _pantalla._aliados[i]
	return null


# Deja listo el cuerpo de UN combatiente (su sitio y sus dibujos animandose en pausa). Vale tambien
# para los que entran A MEDIA PELEA (refuerzos, aliados que se unen): los busca _preparar_altas en
# cada tick, porque montar() solo ve a los que estaban al empezar. false = aun no tiene cuerpo aqui.
var _preparados: Dictionary = {}

func _preparar(c: Combatant) -> bool:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return false
	_pos[c] = cuerpo.global_position
	for hijo in cuerpo.get_children():
		if hijo is AnimatedSprite2D or hijo is MunecoJugador:
			if (hijo as Node).process_mode != Node.PROCESS_MODE_ALWAYS:
				_modos_guardados.append([hijo, (hijo as Node).process_mode])
				(hijo as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	_preparados[c] = true
	return true


func _preparar_altas() -> void:
	for c in _pantalla._aliados + _pantalla._enemies:
		if not _preparados.has(c):
			_preparar(c)


# ------------------------------------------------------------
#  LO QUE ESTA DENTRO DE LA ARENA, PELEA
# ------------------------------------------------------------
# Un enemigo DENTRO del rectangulo que no esta en ninguna pelea entra en esta como refuerzo (lo vio el
# usuario el 23/09: uno se quedaba congelado dentro, sin barra, porque el grupo del arranque lo elige
# el que dispara la pelea -- el y sus vecinos cercanos -- y la arena, que se calcula despues, es mas
# grande). Cubre tambien al que aparece dentro y al que entra andando: es la regla del borde "un
# enemigo de fuera se mete en la pelea", que estaba escrita en la arena y nunca se enchufo.
#
# Lo mira SOLO quien lleva la pelea, cada RECOGER_CADA segundos, y entra por los caminos de siempre:
#   - un cuerpo DE VERDAD (solitario, o soy el dueño del piso): Game.unir_enemigo_al_combate, igual
#     que cuando un enemigo te alcanza andando (enemy._start_combat);
#   - un ESPEJO (el dueño es otro): se le pide a su dueño con Net.peleas.solicitar_pelea, la misma
#     peticion que al atacarle; como ya estoy peleando, al llegar se une a esta (_llega_pelea). No se
#     repite la peticion mientras se espera la respuesta (PEDIDO_OTRA_VEZ).
const RECOGER_CADA := 0.5
const PEDIDO_OTRA_VEZ := 3000   # ms
var _t_recoger: float = 0.0
var _pedidos: Dictionary = {}   # net_id -> ms en que se pidio

func _recoger_de_la_arena(delta: float) -> void:
	if _pantalla._espejo:
		return
	_t_recoger += delta
	if _t_recoger < RECOGER_CADA:
		return
	_t_recoger = 0.0
	var arena: ArenaCombate = _arena()
	if arena == null or _pantalla._state == _pantalla.State.FINISHED:
		return
	var ahora: int = Time.get_ticks_msec()
	for n in _pantalla.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n) or not (n is Node2D) or not arena.contiene((n as Node2D).global_position):
			continue
		if Game.esta_en_combate(n) or (n.has_method("esta_muerto") and n.esta_muerto()):
			continue
		if n.has_meta("es_espejo"):
			if not Net.activo or not n.has_meta("net_id") or Net.peleas.pelea_de_enemigo(n) != 0:
				continue
			var id: int = int(n.get_meta("net_id"))
			if ahora - int(_pedidos.get(id, -PEDIDO_OTRA_VEZ)) < PEDIDO_OTRA_VEZ:
				continue
			_pedidos[id] = ahora
			print("[arena] %s esta dentro de la arena: lo pido a su dueño" % n.name)
			Net.peleas.solicitar_pelea(id)
			continue
		if bool(n.get("_combat_triggered")):
			continue
		# Como en enemy._start_combat: quieto y sin su aviso de embestida, y si la pelea no le admite (se
		# esta cerrando), suelto para que no se quede de estatua.
		n.set("_combat_triggered", true)
		n.set("velocity", Vector2.ZERO)
		if n.has_method("_cancelar_aviso"):
			n.call("_cancelar_aviso")
		if Game.unir_enemigo_al_combate(n):
			print("[arena] %s estaba dentro de la arena: entra a la pelea" % n.name)
		else:
			n.set("_combat_triggered", false)


func desmontar() -> void:
	for par in _modos_guardados:
		if is_instance_valid(par[0]):
			(par[0] as Node).process_mode = par[1]
	_modos_guardados.clear()
	_tirones.clear()
	_quitar_circulo()
	_apagar_circulos()
	_sigilo_visible(true)
	pintar_imbuiciones(true)
	var pl: Node = _jugador_local()
	if pl != null:
		pl.usar_barras_de_pelea(Callable())


# EL SIGILO SE VE (24/09, Desaparecer: "te quedas mas transparente para que se note"): los tuyos que lo
# llevan, medio transparentes. 'quitar' los deja a todos enteros (al acabar la pelea).
const ALFA_SIGILO := 0.45
const ESCALA_CARNE := 1.12

func _sigilo_visible(quitar: bool) -> void:
	for al in _pantalla._aliados:
		var cu: Node2D = cuerpo_de(al)
		if cu == null:
			continue
		var m = cu.get("_muneco")
		if not (m is CanvasItem):
			continue
		var a: float = 1.0 if quitar or not al.has_status(StatusEffects.Id.SIGILO) else ALFA_SIGILO
		# LA GUARDIA DE CARNE SE VE (25/09, lo pidio el): "te tiene que hacer mas grande y ponerte rojito un poco".
		var carne: bool = not quitar and al.has_status(StatusEffects.Id.GUARDIA_CARNE)
		var col := Color(1.0, 0.72, 0.7, a) if carne else Color(1.0, 1.0, 1.0, a)
		if not (m as CanvasItem).modulate.is_equal_approx(col):
			(m as CanvasItem).modulate = col
		var esc: Vector2 = Vector2.ONE * (ESCALA_CARNE if carne else 1.0)
		if m is Node2D and not (m as Node2D).scale.is_equal_approx(esc):
			(m as Node2D).scale = esc


# ------------------------------------------------------------
#  LOS CIRCULOS MAGICOS de quien recita (26/09): a sus pies, una capa por frase (CirculoMagico).
# ------------------------------------------------------------
# Se CONCILIAN cada fotograma con los conjuros en curso: asi los cubre todos (huir, morir, cambiar, acabar la
# pelea) sin tocar cada salida. El disparo y el fallo los avisa combat_magia (circulo_acaba) antes de limpiar
# el conjuro, para que el circulo se cierre en un fogonazo o se rompa en vez de apagarse sin mas.
var _circulos: Dictionary = {}   # Combatant -> CirculoMagico


# Los conjuros en curso que se ven: {Combatant: [SpellData, frases dichas]}. En el espejo, los de la red.
func _casteos_vistos() -> Dictionary:
	if _pantalla._espejo:
		return _casteos_red
	var out: Dictionary = {}
	for c in _pantalla._casteos:
		var d: Dictionary = _pantalla._casteos[c]
		if d.get("spell") is SpellData:
			out[c] = [d["spell"], int(d.get("idx", 0)), d.get("punto")]
	return out


# LA HUELLA DEL HECHIZO mientras se recita: donde va a caer (el aviso, como las cargas). Se pinta con la
# forma de AHORA desde la posicion de quien recita, que no se mueve mientras canta.
var _huellas_canto: Dictionary = {}   # Combatant -> clave de la huella en la arena

func _pintar_huellas_canto(vistos: Dictionary) -> void:
	var arena: ArenaCombate = _arena()
	for c in _huellas_canto.keys():
		if not vistos.has(c) or not (vistos[c][2] is Vector2):
			if arena != null:
				arena.quitar_huella(_huellas_canto[c])
			_huellas_canto.erase(c)
	if arena == null:
		return
	for c in vistos:
		var spell: SpellData = vistos[c][0]
		if not (vistos[c][2] is Vector2) or not usa_huella_hechizo(spell):
			continue
		var clave: StringName = StringName("canto_%d" % _pantalla._aliados.find(c))
		_huellas_canto[c] = clave
		arena.poner_huella(clave, forma_hechizo(spell, c, vistos[c][2]), 0.0, COLOR_CARGA)


func _tick_circulos() -> void:
	var vistos: Dictionary = _casteos_vistos()
	_pintar_huellas_canto(vistos)
	for c in vistos:
		var spell: SpellData = vistos[c][0]
		var dichas: int = vistos[c][1]
		var circ = _circulos.get(c)
		if circ != null and (not is_instance_valid(circ) or (circ as CirculoMagico).acabando()):
			circ = null
		if circ != null and str((circ as CirculoMagico).receta.get("clave", "")) != SellosMagicos.clave_de(spell):
			(circ as CirculoMagico).apagar()
			circ = null
		if dichas <= 0:
			continue
		if circ == null:
			var cu: Node2D = cuerpo_de(c)
			if cu == null:
				continue
			circ = CirculoMagico.crear(cu, spell, Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
			_circulos[c] = circ
		if (circ as CirculoMagico).frases_dichas() < dichas:
			(circ as CirculoMagico).a_la_frase(dichas)
	for c in _circulos.keys():
		if vistos.has(c) and int(vistos[c][1]) > 0:
			continue
		var circ2 = _circulos[c]
		if is_instance_valid(circ2) and not (circ2 as CirculoMagico).acabando():
			(circ2 as CirculoMagico).apagar()
		_circulos.erase(c)


# El conjuro de 'c' se acaba: 'disparo' = se suelta (fogonazo); si no, se ha recitado mal (se rompe). Si aun no
# habia circulo (falla la primera frase), sale uno para romperse.
func circulo_acaba(c: Combatant, disparo: bool, spell: SpellData = null) -> void:
	if spell == null:
		spell = (_pantalla._casteos.get(c, {}) as Dictionary).get("spell") as SpellData
	# Para los espejos: viaja en la instantanea (circulos_para_red).
	if not _pantalla._espejo and spell != null:
		_fin_seq += 1
		_fines.append([_pantalla._aliados.find(c), disparo, spell.resource_path, _fin_seq])
		if _fines.size() > 4:
			_fines.pop_front()
	var circ = _circulos.get(c)
	if circ == null or not is_instance_valid(circ) or (circ as CirculoMagico).acabando():
		circ = null
		if disparo:
			return
		var cu: Node2D = cuerpo_de(c)
		if cu == null or spell == null:
			return
		circ = CirculoMagico.crear(cu, spell, Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	if disparo:
		(circ as CirculoMagico).disparar()
	else:
		(circ as CirculoMagico).fallar()
	_circulos.erase(c)


# --- EN RED: quien lleva la pelea manda los conjuros en curso y los finales; el espejo los pinta igual. ---
var _fines: Array = []            # [aliado, disparo, ruta, seq]: los ultimos, por si se pierde una instantanea
var _fin_seq: int = 0
var _casteos_red: Dictionary = {} # ESPEJO: {Combatant: [SpellData, frases dichas]}
var _fin_visto: int = -1          # ESPEJO: el ultimo final ya pintado (-1 = aun no ha llegado ninguna)

func circulos_para_red() -> Dictionary:
	var cs: Array = []
	for c in _pantalla._casteos:
		var d: Dictionary = _pantalla._casteos[c]
		var i: int = _pantalla._aliados.find(c)
		if i >= 0 and d.get("spell") is SpellData:
			var pt = d.get("punto")
			cs.append([i, (d["spell"] as SpellData).resource_path, int(d.get("idx", 0))]
				+ ([(pt as Vector2).x, (pt as Vector2).y] if pt is Vector2 else []))
	return {"c": cs, "f": _fines}


func aplicar_circulos_red(d: Dictionary) -> void:
	# Los finales primero: el circulo se cierra (o se rompe) antes de que la conciliacion lo apague.
	var fines: Array = d.get("f", [])
	var tope: int = _fin_visto
	for f in fines:
		var seq: int = int(f[3])
		tope = maxi(tope, seq)
		if _fin_visto < 0 or seq <= _fin_visto:
			continue   # al llegar a mitad no se repiten los de antes
		var i: int = int(f[0])
		var sp = load(str(f[2])) if str(f[2]) != "" else null
		if i >= 0 and i < _pantalla._aliados.size() and sp is SpellData:
			circulo_acaba(_pantalla._aliados[i], bool(f[1]), sp)
	_fin_visto = maxi(tope, 0)
	_casteos_red.clear()
	for c in d.get("c", []):
		var i2: int = int(c[0])
		var sp2 = load(str(c[1])) if str(c[1]) != "" else null
		if i2 >= 0 and i2 < _pantalla._aliados.size() and sp2 is SpellData:
			_casteos_red[_pantalla._aliados[i2]] = [sp2, int(c[2]),
				Vector2(float(c[3]), float(c[4])) if (c as Array).size() >= 5 else null]


func _apagar_circulos() -> void:
	_pintar_huellas_canto({})
	for c in _circulos:
		var circ = _circulos[c]
		if is_instance_valid(circ) and not (circ as CirculoMagico).acabando():
			(circ as CirculoMagico).apagar()
	_circulos.clear()


# ------------------------------------------------------------
#  DE COMBATIENTE A CUERPO
# ------------------------------------------------------------

# EL UNICO SITIO que responde "donde esta el cuerpo de este combatiente", en cualquier maquina. Lo
# usan tambien las fichas del mapa (combat_figuras_mapa): si cada uno lo buscara por su cuenta, el
# dia que se arregla uno el otro sigue buscando en el sitio viejo.
func cuerpo_de(c: Combatant) -> Node2D:
	if c == null:
		return null
	if _pantalla._espejo:
		return _cuerpo_en_espejo(c)
	var i: int = _pantalla._enemies.find(c)
	if i >= 0:
		# El orden es el mismo por construccion: Game._abrir_pelea crea un Combatant por nodo, en el
		# orden de _active_enemies. Los invocados no tienen nodo y se quedan en null.
		var nodos: Array = Game._active_enemies
		var n = nodos[i] if i < nodos.size() else null
		return n as Node2D if n != null and is_instance_valid(n) else null
	if not _pantalla._aliados.has(c):
		return null
	var pj: PersonajeData = Game.pj_de_combatant(c)
	if pj == null:
		return null
	var dueno: int = int(_pantalla._dueno_aliado.get(c, 0))
	if dueno == 0:
		return Game.cuerpo_de(pj)
	# El DOBLE de otro humano: su cuerpo es el que me pinta la red, el personaje k de ese jugador.
	return Game.cuerpo_de_red(dueno, int(pj.get_meta("cuerpo_red", -1)))


func _cuerpo_en_espejo(c: Combatant) -> Node2D:
	var i: int = _pantalla._enemies.find(c)
	if i >= 0:
		var filas: Array = roster_red.get("enemigos", [])
		return _nodo_de_bicho(int((filas[i] as Dictionary).get("nid", 0))) if i < filas.size() else null
	i = _pantalla._aliados.find(c)
	if i >= 0:
		var filas: Array = roster_red.get("aliados", [])
		if i >= filas.size():
			return null
		var d: Dictionary = filas[i]
		return Game.cuerpo_de_red(int(d.get("peer", 0)), int(d.get("cuerpo", -1)))
	return null


# El cuerpo de un bicho por su id de red: el de verdad si es mio, o el espejo que me pinta su dueño.
func _nodo_de_bicho(id: int) -> Node2D:
	if id == 0:
		return null
	var n = Net.enemigos._enem_nodos.get(id)   # SIN tipar: puede estar liberado
	if n == null or not is_instance_valid(n):
		n = Net.enemigos._enemigos.get(id, {}).get("nodo")
	return n as Node2D if n != null and is_instance_valid(n) else null


# LA DIRECCION DE RED de un combatiente, para el roster: con ella el espejo encuentra su cuerpo en
# SU mundo. Aliado = {peer, cuerpo}; bicho = {nid}. Solo la pide quien lleva la pelea.
func direccion_red(c: Combatant) -> Dictionary:
	var i: int = _pantalla._enemies.find(c)
	if i >= 0:
		var cuerpo: Node2D = cuerpo_de(c)
		return {"nid": int(cuerpo.get_meta("net_id", 0)) if cuerpo != null else 0}
	var pj: PersonajeData = Game.pj_de_combatant(c)
	var dueno: int = int(_pantalla._dueno_aliado.get(c, 0))
	if dueno == 0:
		return {"peer": _mi_id(), "cuerpo": Game.indice_de_cuerpo(pj)}
	return {"peer": dueno, "cuerpo": int(pj.get_meta("cuerpo_red", -1)) if pj != null else -1}


static func _mi_id() -> int:
	if Net.activo and Net.multiplayer.multiplayer_peer != null:
		return Net.multiplayer.get_unique_id()
	return 0


# ¿Este personaje lo muevo YO, en esta maquina? En la que lleva la pelea, los que no son de otro
# humano; en el espejo, los que el roster dice que son mios.
func _es_mio(c: Combatant) -> bool:
	if not _pantalla._espejo:
		return int(_pantalla._dueno_aliado.get(c, 0)) == 0
	var i: int = _pantalla._aliados.find(c)
	var filas: Array = roster_red.get("aliados", [])
	return i >= 0 and i < filas.size() and int((filas[i] as Dictionary).get("peer", -1)) == _mi_id()


# Donde esta. Lo que diga su cuerpo, y si no tiene (un invocado), lo ultimo apuntado.
# El personaje de OTRO humano, en quien lleva la pelea, esta donde dijo al elegir su accion (la
# posicion sellada, ver anotar_pos_remota), no donde lo tenga ahora mismo su cuerpo interpolado.
func pos_de(c: Combatant) -> Vector2:
	if not _pantalla._espejo and _pos.has(c) and _pantalla._aliados.has(c) and not _es_mio(c):
		return _pos[c]
	var cuerpo: Node2D = cuerpo_de(c)
	if is_instance_valid(cuerpo):
		return cuerpo.global_position
	return _pos.get(c, Vector2.ZERO)


# Cuanto anda en SU turno. Sale de su Agilidad contra el liston del piso, y cero si algo le clava.
func radio_de(c: Combatant) -> float:
	if c == null or c.abilities == null:
		return 0.0
	# CLAVADO: enraizado no anda (el mismo estado que le quita el basico), y quien esta cargando un
	# golpe tampoco -- es lo que hace que la carga se pague (decision del usuario).
	if c.enraizado() or c.charging != null:
		return 0.0
	return StatsMath.radio_movimiento(float(c.abilities.agilidad),
		Game.agilidad_esperada_piso(), c.overload_factor)


# ------------------------------------------------------------
#  EL ALCANCE: ¿llega el golpe de 'a' a 'b'?
# ------------------------------------------------------------

# ------------------------------------------------------------
#  LOS PIES: cada cuerpo es un CIRCULO en el suelo
# ------------------------------------------------------------
# QUIEN GOLPEA mide desde SUS PIES (el centro de su cuerpo en el suelo), igual en todas las
# direcciones; QUIEN RECIBE, por su cuerpo tal como se ve (bulto_de). Lo usan a la vez el basico
# (hueco_entre), la punta del arma de las habilidades (forma_de) y a quien pilla cada huella
# (reparto_habilidad): una sola cuenta.
#
# POR QUE ASI Y NO CON CAJAS (23/09, mirando la pelea con el usuario): con cajas salian dos cosas
# que no cuadraban con lo que se ve.
#   - Hacia ARRIBA llegaba mas: el cuerpo del personaje era una caja alta (22x42), y la punta del arma
#     se contaba desde su borde, que por arriba queda 10 px mas lejos. Parecia que pegaba "desde la
#     cabeza". Un circulo mide lo mismo en todas las direcciones.
#   - A la Aberracion le daba cualquier cosa: se media con un cuadrado del ANCHO de su dibujo (53 px,
#     tentaculos incluidos) puesto en el suelo, y el dibujo es el bicho DE PIE visto a 45 grados, no
#     lo que pisa. Tres pegadas se solapaban entre ellas y contigo, y un cono que tapaba a una
#     "pillaba a 3".
# El radio es una fraccion del ancho que se VE (el dibujo en los enemigos, la caja de siempre en los
# tuyos): lo que pisa un cuerpo es bastante menos que lo que abulta.
const PISA := 0.33


# Donde tiene los pies, con el cuerpo donde la PELEA dice que esta (pos_de: la posicion sellada si es
# de otro humano). Los tuyos: bajo el nodo (PoseJugador.PIES_BAJO_NODO). Los enemigos: a la altura de su
# dibujo que diga su ficha (centro_suelo_de); sin ficha, un pelo por encima del borde de abajo.
const PIES_SOBRE_EL_BORDE := 0.1

func pies_de(c: Combatant) -> Vector2:
	var p: Vector2 = pos_de(c)
	if not _pantalla._enemies.has(c):
		return p + Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
	var r: Rect2 = bulto_de(c)
	return Vector2(r.get_center().x, r.position.y + r.size.y * centro_suelo_de(cuerpo_de(c)))


# A que altura de su dibujo tiene cada enemigo su centro en el suelo: lo dice SU FICHA
# (EnemyData.centro_suelo), porque un bipedo lo tiene en los pies y uno a cuatro patas en medio del
# cuerpo. Vale el bicho de esta maquina y la copia de red: los dos llevan su 'data'.
static func centro_suelo_de(cuerpo: Node2D) -> float:
	var d = cuerpo.get("data") if cuerpo != null else null
	if d is EnemyData:
		return (d as EnemyData).centro_suelo_real()
	return 1.0 - PIES_SOBRE_EL_BORDE


# El radio de lo que PISA quien golpea: la punta de su arma se cuenta desde el borde de esto.
func radio_pisa(c: Combatant) -> float:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return 32.0 * PISA
	var ancho: float = 0.0
	if _pantalla._enemies.has(c):
		ancho = rect_dibujo(cuerpo).size.x
	if ancho <= 0.0:
		ancho = Cuerpos.caja_de(cuerpo).size.x
	return ancho * PISA


# LA HITBOX de quien RECIBE: su cuerpo tal como se ve (lo marco el usuario sobre una captura, una caja
# alrededor del dibujo de la Aberracion: "eso es lo que hay que tener en cuenta para golpearlo").
#   Los enemigos: la caja de lo que tienen PINTADO, donde se pinta (ver rect_dibujo).
#   Los tuyos: la caja de su cuerpo (PoseJugador.CAJA_CUERPO), la misma contra la que te pegan por el mapa.
# Con el cuerpo donde la PELEA dice que esta (pos_de).
func bulto_de(c: Combatant) -> Rect2:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return Rect2(pos_de(c) - Vector2(16, 16), Vector2(32, 32))
	var r: Rect2 = Rect2()
	if _pantalla._enemies.has(c):
		r = rect_dibujo(cuerpo)
	if not r.has_area():
		r = Cuerpos.caja_de(cuerpo)
	r.position += pos_de(c) - cuerpo.global_position
	return r


# EL CUERPO DE UN BLOQUE EN PANTALLA: lo que CombatFX usa para colocar los numeros y los dibujos de los
# golpes en el mapa (CombatFX.rect_en_mapa). El bulto de su combatiente, pasado por la camara. Rect2()
# = ese bloque no tiene cuerpo ahora mismo, y entonces manda la tarjeta de siempre.
func rect_pantalla_de_bloque(bloque: Dictionary) -> Rect2:
	var c: Combatant = null
	for lista in [_pantalla._enemies, _pantalla._aliados]:
		for x in lista:
			if is_same(_pantalla._bloque_de(x), bloque):
				c = x
				break
		if c != null:
			break
	if c == null or cuerpo_de(c) == null:
		return Rect2()
	var r: Rect2 = bulto_de(c)
	var xf: Transform2D = _pantalla.get_viewport().get_canvas_transform()
	return Rect2(xf * r.position, r.size * xf.get_scale().abs())


# QUIEN ESTA BAJO UN PUNTO DE LA PANTALLA, para el mantener pulsado que abre la ficha de detalle: su
# cuerpo en el mapa (el bulto, el mismo que recibe los golpes) o, de los tuyos, su columna de ARRIBA
# (las barras del grupo del HUD, que en el mapa son sus tarjetas). Solo los vivos, como en la fila.
func combatiente_en_pantalla(pos: Vector2) -> Combatant:
	var xf: Transform2D = _pantalla.get_viewport().get_canvas_transform()
	for lista in [_pantalla._enemies, _pantalla._aliados]:
		for c in lista:
			if not (c as Combatant).is_alive() or cuerpo_de(c) == null:
				continue
			var r: Rect2 = bulto_de(c)
			if Rect2(xf * r.position, r.size * xf.get_scale().abs()).has_point(pos):
				return c
	var pl: Node = _jugador_local()
	if pl != null:
		var pj: PersonajeData = pl.pj_en_pantalla(pos)
		var c2: Combatant = combatiente_de_mi_pj(pj) if pj != null else null
		if c2 != null and c2.is_alive():
			return c2
	return null


# El hueco para GOLPEAR: de los pies de quien golpea (menos lo que pisa) al cuerpo de quien recibe.
# No es simetrico, y es a proposito: "a llega a b" y "b llega a a" miden desde pies distintos.
func hueco_entre(a: Combatant, b: Combatant) -> float:
	if cuerpo_de(a) == null or cuerpo_de(b) == null:
		return INF
	var p: Vector2 = pies_de(a)
	var r: Rect2 = bulto_de(b)
	var cerca := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(cerca) - radio_pisa(a)


func alcance_de(c: Combatant) -> float:
	return maxf(c.alcance, ALCANCE_MINIMO) if c != null else ALCANCE_MINIMO


# ¿Llega? En quien lleva la pelea, al personaje de OTRO humano se le perdona HOLGURA_ALCANCE: su
# pantalla le dijo que llegaba con las posiciones que el veia, y un rechazo por dos pixeles de red
# le dejaria sin el turno que eligio.
func llega(a: Combatant, b: Combatant) -> bool:
	if a == null or b == null:
		return false
	var tope: float = alcance_de(a)
	if not _pantalla._espejo and _pantalla._aliados.has(a) and not _es_mio(a):
		tope += HOLGURA_ALCANCE
	return hueco_entre(a, b) <= tope


# De 'candidatos', los que 'a' alcanza desde donde esta.
func alcanzables(a: Combatant, candidatos: Array) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in candidatos:
		if llega(a, c):
			out.append(c)
	return out


# ¿Tiene a alguien a tiro? Es lo que decide si el boton de Atacar pega o te deja ESPERAR.
func llega_a_alguno(a: Combatant) -> bool:
	for e in _pantalla._vivos():
		if llega(a, e):
			return true
	return false


# EL ENEMIGO QUE ESTA ACTUANDO, mientras resuelve su turno. Lo mira el sorteo de a quien pega
# (objetivos._elegir_objetivo_enemigo), que se llama desde ocho sitios y no sabe de quien es el
# turno. Solo vive durante la llamada a _enemy_turn (ver _turno_enemigo_de_siempre).
var atacante: Combatant = null


# El turno de siempre del enemigo, pero sabiendo quien pega para que su sorteo se quede con los que
# alcanza. Si no alcanza a nadie, el sorteo sale vacio y _enemy_turn lo cuenta como que no llega.
func _turno_enemigo_de_siempre(e: Combatant) -> void:
	atacante = e
	_pantalla.enemigos._enemy_turn(e)
	atacante = null


# ------------------------------------------------------------
#  TU TURNO
# ------------------------------------------------------------

# Empieza el turno de uno de los tuyos. Dos sitios lo llaman:
#   - quien lleva la pelea, desde _begin_player_turn (ya se sabe que el turno se juega: ni aturdido ni
#     cargando). Calcula el radio el, que tiene la Agilidad de verdad.
#   - el ESPEJO, desde turno_mio, cuando le piden la accion de uno de los suyos. El radio le llega con
#     la peticion ('radio'): su maniqui no tiene stats de las que sacarlo.
# Si el personaje lo mueve OTRA maquina, aqui solo se pinta su circulo (fase AJENO).
func empezar_turno(c: Combatant, radio: float = -1.0) -> void:
	_terminar()
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		print("[tactico] %s no tiene cuerpo en el mapa de esta maquina (dir %s): turno sin andar" % [
			c.nombre, str(direccion_red(c)) if not _pantalla._espejo else "espejo"])
		return
	_quien = c
	_cuerpo = cuerpo
	_foco = cuerpo
	_inicio = cuerpo.global_position
	# CON DOS ARMAS cada accion empieza por la DERECHA: con golpes impares (el Doble tajo con dos espadas son 3,
	# la Rafaga con dos dagas 5) la siguiente accion empezaba por la izquierda.
	_mano_izq_toca.erase(cuerpo)
	# Su turno: se le acaba En guardia (vuelve a su guardia de ataque) y el frente de su Defender.
	_frente_defensa.erase(c)
	if cuerpo.get("_muneco") is MunecoJugador:
		(cuerpo.get("_muneco") as MunecoJugador).guardia_defensiva = false
		(cuerpo.get("_muneco") as MunecoJugador).postura_defensa = false
	if radio >= 0.0:
		_radio = radio
	else:
		# Recitando (entre frases) no se anda todavia: la reposicion entre frases es la fase 6.
		_radio = 0.0 if _pantalla._cast_spell != null else radio_de(c)
	_fase = Fase.MOVIENDO if _es_mio(c) else Fase.AJENO
	_andando = false
	if _fase == Fase.MOVIENDO:
		_animar(cuerpo, _mirada_de(cuerpo), false)
	var arena: ArenaCombate = _arena()
	if arena != null and _radio > 0.0:
		arena.poner_circulo(_inicio, _radio)


# El radio del turno que se esta jugando, para mandarselo al dueño con la peticion de accion.
func radio_del_turno() -> float:
	return _radio if _fase != Fase.NADA else 0.0


# Cada fotograma, desde _process (tambien en el espejo). Devuelve true si el turno lo tiene ESTE tema
# (un enemigo acercandose) y la pantalla no debe hacer nada mas este fotograma.
func tick(delta: float) -> bool:
	if is_instance_valid(_foco):
		Game.camara_tactica_sigue(_foco.global_position)
	_sigilo_visible(false)
	_tick_circulos()
	_tick_huellas(delta)
	_tick_gestos(delta)
	_tick_tirones(delta)
	_tick_saltos(delta)
	_tick_deslices(delta)
	_preparar_altas()
	_recoger_de_la_arena(delta)
	match _fase:
		Fase.MOVIENDO:
			_tick_moviendo(delta)
			return false
		Fase.AJENO:
			if _turno_acabado():
				_terminar()
			return false
		Fase.ACERCANDO:
			_tick_acercando(delta)
			return true
	return false


# ------------------------------------------------------------
#  APUNTAR una habilidad en el mapa
# ------------------------------------------------------------
# Las habilidades YA HECHAS para el mapa (forma_apunte >= 0 en su ficha) no salen al pulsarlas: se
# apuntan. La huella sigue al raton, el personaje mira hacia ella, y el clic izquierdo confirma (el
# derecho, o Esc, vuelve al menu). Lo que se elige es un PUNTO, y ese punto es lo que viaja por red
# sellado con la accion: quien lleva la pelea rehace la huella desde la posicion sellada del que la
# lanza y su alcance, y pega a quien le toque. Las que aun no se han hecho siguen como en la fila.

var _apuntando: AbilityData = null
# El punto elegido (mundo) de la accion que se va a resolver. Lo pone el clic en esta maquina, o
# llega sellado por red (anotar_apunte). Lo lee reparto_habilidad.
var apunte: Vector2 = Vector2.ZERO
var _hay_apunte: bool = false
var _pillados_vistos: int = -1
const CLAVE_APUNTE := &"apuntando"
const CLAVE_APUNTE_ESCUDO := &"apuntando_escudazo"


# ¿Esta habilidad se resuelve con su huella del mapa?
func usa_huella(ab: AbilityData) -> bool:
	return _pantalla.tactico and ab != null and int(ab.forma_apunte) >= 0 and int(ab.forma) >= 0


# La forma de 'ab' lanzada por 'c' hacia 'hacia', desde SUS PIES y con 'c' donde la PELEA dice.
func forma_de(ab: AbilityData, c: Combatant, hacia: Vector2) -> RefCounted:
	var f = CombatFormas.de_habilidad_mapa(ab, pies_de(c), radio_pisa(c), alcance_de(c), hacia)
	# EL PASO y EL AVANCE enseñan lo que va a pasar de verdad: el circulo donde acabas y la linea hasta
	# donde llegas (recortados por pared, borde o un cuerpo en el sitio).
	if ab.paso:
		f.centro = _sitio_libre_hacia(c, f.centro) + Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
	elif ab.avance and f.tipo == CombatFormas.Tipo.LINEA:
		var fin: Vector2 = _sitio_libre_hacia(c, f.origen + f.dir * f.largo) \
			+ Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
		f.largo = maxf(0.0, (fin - f.origen).dot(f.dir))
		f.radio = f.largo   # lo que leen la red y el compas (SueloRoto)
		f.centro = f.origen + f.dir * f.largo * 0.5
	return f


# A QUIEN PEGA y con cuanto: [{c, escala}], sin tope (en el mapa le da a todo lo que la huella toque:
# el cuerpo de cada uno tal como se ve, ver bulto_de). Con NUCLEO, los que el nucleo toca van al daño entero y
# el resto a area_secundario; un cono con TRAMOS baja forma_tramo_baja por tramo; si no, todos a
# forma_escala (1.0 = entero). Ordenados por cercania
# al centro y, a igualdad, por indice en _enemies: el mismo orden en todas las maquinas. Vacio =
# golpea el suelo.
func reparto_habilidad(ab: AbilityData, c: Combatant) -> Array:
	var out: Array = []
	if not _hay_apunte:
		return out
	if ab.paso:
		var plan: Dictionary = plan_paso(ab, c)
		if plan["v"] != null:
			out.append({"c": plan["v"], "escala": 1.0})
		return out
	if ab.forma_a_aliados:
		return out   # lo que pilla son de los tuyos: ver aliados_de_huella
	return _reparto_en(ab, c, forma_de(ab, c, apunte))


# ------------------------------------------------------------
#  LOS HECHIZOS EN EL MAPA (26/09): se apuntan AL ELEGIRLOS y caen en ese sitio al soltarlos
# ------------------------------------------------------------
# La huella de un hechizo es la de una habilidad hecha con los campos de su ficha: asi el apuntado, la huella
# que ven los demas y el reparto son los mismos que ya funcionan con las armas.
var _huellas_hechizo: Dictionary = {}   # SpellData -> AbilityData
var _hechizo_apuntado: Array = []       # [SpellData, aliado] mientras se apunta un hechizo

func usa_huella_hechizo(spell: SpellData) -> bool:
	return spell != null and spell.forma_apunte >= 0 and spell.forma >= 0


func huella_hechizo(spell: SpellData) -> AbilityData:
	if _huellas_hechizo.has(spell):
		return _huellas_hechizo[spell]
	var ab := AbilityData.new()
	ab.nombre = spell.nombre
	ab.forma = spell.forma
	ab.forma_apunte = spell.forma_apunte
	ab.forma_radio = spell.forma_radio
	ab.forma_apertura = spell.forma_apertura
	ab.forma_rango = spell.forma_rango
	ab.forma_ancho = spell.forma_ancho
	ab.forma_solo_primero = spell.forma_solo_primero
	ab.forma_a_aliados = spell.forma_a_aliados
	# A UNO de los tuyos (Vendaje, Filos) salvo que caiga ALREDEDOR de ti: entonces es a todos los que pille (Fortaleza).
	if spell.forma_a_aliados and spell.forma_apunte != CombatFormas.Apunte.ALREDEDOR:
		ab.objetivo_aliado = AbilityData.Objetivo.ALIADO
	_huellas_hechizo[spell] = ab
	return ab


# Elegiste un hechizo con huella: a apuntar. Al confirmar se empieza a recitar (combat_magia._elegir_hechizo).
func apuntar_hechizo(spell: SpellData, aliado: Combatant) -> void:
	_hechizo_apuntado = [spell, aliado]
	apuntar(huella_hechizo(spell))
	if _apuntando == null:
		_hechizo_apuntado = []


# La forma del hechizo lanzado por 'c' hacia 'punto', desde sus pies (con las cuñas puestas).
func forma_hechizo(spell: SpellData, c: Combatant, punto: Vector2) -> RefCounted:
	var f = forma_de(huella_hechizo(spell), c, punto)
	f.cunas = spell.forma_cunas
	# El centro, en la rejilla de 1/16 de px en la que viaja por red: la Andanada saca de el donde caen sus bolas
	# (MagiaAire.puntos_andanada) y tiene que salir IGUAL aqui y en el espejo.
	f.centro = (f.centro * 16.0).round() / 16.0
	# DE DONDE SALE lo que se lanza a un CIRCULO (la chispa del Estallido): el circulo no guarda su origen y por red
	# solo viaja el centro, asi que en su 'ancho' (que el circulo no usa) va lo lejos que esta de ti, hacia atras por
	# su 'dir'. Ver MagiaMayor.origen.
	if f.tipo == CombatFormas.Tipo.CIRCULO:
		f.ancho = roundf(pies_de(c).distance_to(f.centro) * 16.0) / 16.0
	return f


# A QUIEN LE CAE y con cuanto: [{c, escala}], ordenados como las habilidades (el primero es el principal).
# La escala es el multiplicador de daño: el de su cuña si el cono va por cuñas, si no dano_objetivo. Vacio =
# no hay nadie donde cae: se pierde contra el suelo.
func reparto_hechizo(spell: SpellData, c: Combatant, punto: Vector2) -> Array:
	if spell.forma_a_aliados:
		return []   # va a uno de los tuyos (el elegido al apuntar), no pilla enemigos
	var f = forma_hechizo(spell, c, punto)
	var out: Array = _reparto_en(huella_hechizo(spell), c, f)
	for d in out:
		var esc: float = spell.dano_objetivo
		if spell.forma_cunas > 1 and not spell.forma_escalas.is_empty():
			var k: int = f.cuna_de(bulto_de(d["c"]))
			esc = spell.forma_escalas[clampi(k, 0, spell.forma_escalas.size() - 1)]
		elif spell.forma_caida.size() >= 2:
			esc = lerpf(spell.forma_caida[0], spell.forma_caida[1], lejania_al_centro(f, d["c"]))
		d["escala"] = esc
	return out


# Lo lejos del centro de un circulo que queda un cuerpo: 0 en medio, 1 en el borde (por su punto mas cercano).
func lejania_al_centro(f, c: Combatant) -> float:
	var r: Rect2 = bulto_de(c)
	var cerca := Vector2(clampf(f.centro.x, r.position.x, r.end.x), clampf(f.centro.y, r.position.y, r.end.y))
	return clampf(cerca.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)


# LOS DE DENTRO de un hechizo disperso (la Tormenta), para repartir sus golpes al azar entre ellos.
func dentro_del_hechizo(spell: SpellData, c: Combatant, punto: Vector2) -> Array:
	var out: Array = []
	for d in _reparto_en(huella_hechizo(spell), c, forma_hechizo(spell, c, punto)):
		out.append(d["c"])
	return out


# LOS QUE SALPICA un golpe sobre 'c' (el rayo de la Tormenta): los vivos a 'radio' px de su cuerpo, sin el.
func vecinos_de(c: Combatant, radio: float) -> Array:
	var out: Array = []
	var r: Rect2 = bulto_de(c).grow(radio)
	for e in _pantalla._vivos():
		if e != c and r.intersects(bulto_de(e)):
			out.append(e)
	return out


# LOS TUYOS QUE PILLA LA HUELLA de un hechizo de apoyo en area (Fortaleza alrededor de ti), en el orden de siempre.
func aliados_hechizo(spell: SpellData, c: Combatant) -> Array:
	var ab: AbilityData = huella_hechizo(spell)
	var lista: Array = []
	var f = forma_hechizo(spell, c, pies_de(c))
	for al in _pantalla._aliados_vivos():
		var r: Rect2 = bulto_de(al)
		if f.toca(r):
			lista.append(al)
	return lista


# LOS QUE SE CRUZA UN PROYECTIL (una linea de solo_primero), en orden desde quien lo lanza: a donde siguen los
# golpes que sobran si el primero cae (el Pulso arcano).
func fila_del_proyectil(spell: SpellData, c: Combatant, punto: Vector2) -> Array:
	var ab: AbilityData = huella_hechizo(spell).duplicate()
	ab.forma_solo_primero = false
	var out: Array = []
	for d in _reparto_en(ab, c, forma_hechizo(spell, c, punto)):
		out.append(d["c"])
	# De cerca a lejos desde quien lo lanza (el reparto ordena por el centro de la huella).
	var pies: Vector2 = pies_de(c)
	out.sort_custom(func(x, y): return bulto_de(x).get_center().distance_squared_to(pies) < bulto_de(y).get_center().distance_squared_to(pies))
	return out


# EL SIGUIENTE ESLABON de una cadena (la Descarga): el vivo mas cercano a 'desde' que no este en 'ya', a no
# mas de 'maximo' px entre cuerpos. null = no hay a quien saltar. A igualdad, el de menor indice.
func siguiente_en_cadena(desde: Combatant, ya: Array, maximo: float) -> Combatant:
	var mejor: Combatant = null
	var d_mejor: float = INF
	for e in _pantalla._vivos():
		if ya.has(e):
			continue
		var d: float = hueco_entre(desde, e)
		if d <= maximo and d < d_mejor - 0.001:
			mejor = e
			d_mejor = d
	return mejor


# EL ESCUDAZO de la Guardia rota (AbilityData.forma_escudo_largo): a quien le cae, con la misma regla.
func reparto_escudazo(ab: AbilityData, c: Combatant) -> Array:
	if not _hay_apunte or ab.forma_escudo_largo <= 0.0:
		return []
	return _reparto_en(ab, c, forma_escudazo(ab, c, apunte))


# La LINEA del escudazo: sale de tus pies hacia donde apuntas, y su ancho lo pone tu escudo.
func forma_escudazo(ab: AbilityData, c: Combatant, hacia: Vector2) -> RefCounted:
	var f = forma_de(ab, c, hacia)
	var tam: int = clampi(c.fx_escudo, 0, ShieldData.ANCHO_ESCUDAZO.size() - 1)
	return CombatFormas.linea(pies_de(c), f.dir, ab.forma_escudo_largo, float(ShieldData.ANCHO_ESCUDAZO[tam]))


# LOS TUYOS QUE PILLA LA HUELLA (AbilityData.forma_a_aliados), del mas cercano al centro al mas lejano, y a
# igualdad por su sitio en _aliados (el mismo orden en todas las maquinas). Con el lanzador si queda dentro,
# salvo que la habilidad no valga sobre uno mismo (el Muro).
func aliados_de_huella(ab: AbilityData, c: Combatant) -> Array:
	if not _hay_apunte:
		return []
	var f = forma_de(ab, c, apunte)
	var lista: Array = []
	for al in _pantalla._aliados_vivos():
		if ab.excluye_al_lanzador() and al == c:
			continue
		var r: Rect2 = bulto_de(al)
		if not f.toca(r):
			continue
		lista.append({"c": al, "d": r.get_center().distance_squared_to(f.centro_util()),
			"i": _pantalla._aliados.find(al)})
	lista.sort_custom(func(x, y):
		if is_equal_approx(float(x["d"]), float(y["d"])):
			return int(x["i"]) < int(y["i"])
		return float(x["d"]) < float(y["d"]))
	return lista.map(func(x): return x["c"])


# A quien pilla la forma 'f' que lanza 'c': los del OTRO bando. Si la lanza un enemigo, los tuyos (ver
# LAS HABILIDADES DEL ENEMIGO); el orden de desempate, su sitio en su lista, igual en todas las maquinas.
func _reparto_en(ab: AbilityData, c: Combatant, f) -> Array:
	var out: Array = []
	var nucleo = CombatFormas.circulo(f.centro, ab.forma_nucleo) if ab.forma_nucleo > 0.0 else null
	var lista: Array = []
	var de_enemigo: bool = _pantalla._enemies.has(c)
	var bando: Array = _pantalla._enemies if not de_enemigo else _pantalla._aliados
	for e in (_pantalla._vivos() if not de_enemigo else _pantalla._aliados_vivos()):
		var r: Rect2 = bulto_de(e)
		if not f.toca(r):
			continue
		var esc: float = ab.forma_escala
		if nucleo != null:
			esc = 1.0 if nucleo.toca(r) else ab.area_secundario
		elif f.tramos > 1:
			# El cono a TROZOS (la Onda): cada tramo mas lejos, forma_tramo_baja menos.
			esc = maxf(0.0, ab.forma_escala - ab.forma_tramo_baja * float(f.tramo_de(r)))
		# SOLO AL PRIMERO: manda lo cerca que este de quien pega, no del centro de la huella. Y en el
		# AVANCE tambien: los golpes caen en el orden en que te los cruzas.
		var ref: Vector2 = pies_de(c) if ab.forma_solo_primero or ab.avance else f.centro_util()
		lista.append({"c": e, "escala": esc, "d": r.get_center().distance_squared_to(ref),
			"i": bando.find(e)})
	lista.sort_custom(func(x, y):
		if is_equal_approx(float(x["d"]), float(y["d"])):
			return int(x["i"]) < int(y["i"])
		return float(x["d"]) < float(y["d"]))
	if ab.forma_solo_primero and lista.size() > 1:
		lista = lista.slice(0, 1)
	for d in lista:
		out.append({"c": d["c"], "escala": d["escala"]})
	return out


# LO QUE TIENE PINTADO un enemigo, en MUNDO: la caja que abraza su dibujo EN EL FOTOGRAMA QUE SE VE.
# Rect2() = no tiene dibujo que medir.
#
# EL FOTOGRAMA DE AHORA, no la pose entera: uniendo todos los de la animacion, un slime que bota o un
# golem que sube y baja al andar se quedaban con una caja bastante mas grande que lo que se ve (lo vio
# el usuario el 23/09). Para golpear manda lo que ves en el momento del golpe.
#
# DOS COSAS que hay que sumar y que la primera version no sumaba (la caja salia caida hacia abajo en
# el Rey Slime, el Coloso y el Miconido):
#   - el SPRITE no esta en el punto del enemigo: va subido (su propia position), asi que se mide desde
#     el sprite, no desde el nodo;
#   - cada fotograma es un AtlasTexture RECORTADO: lo pintado (su region) va dentro de un lienzo mas
#     grande, y su sitio dentro de el lo dice su MARGIN.
static var _cache_dibujo := {}

static func rect_dibujo(cuerpo: Node2D) -> Rect2:
	if cuerpo == null:
		return Rect2()
	for hijo in cuerpo.get_children():
		if hijo is AnimatedSprite2D and (hijo as CanvasItem).visible \
				and (hijo as AnimatedSprite2D).sprite_frames != null:
			var spr: AnimatedSprite2D = hijo
			var local: Rect2 = _pintado_local(spr)
			if not local.has_area():
				return Rect2()
			var t: Transform2D = spr.get_global_transform()
			var esc: Vector2 = t.get_scale().abs()
			return Rect2(t.origin + local.position * esc, local.size * esc)
		if hijo is ColorRect and (hijo as CanvasItem).visible:
			var cr: ColorRect = hijo
			var tc: Transform2D = cr.get_global_transform()
			return Rect2(tc.origin, cr.size * tc.get_scale().abs())
	return Rect2()


# Lo pintado del fotograma que se ve, en px de la textura y relativo al ORIGEN del sprite (su punto de
# dibujo, con 'centered' y 'offset' ya dentro). Cacheado por textura: las de una especie se generan una
# vez y son las mismas para todos los suyos, asi que get_image solo se paga la primera vez.
static func _pintado_local(spr: AnimatedSprite2D) -> Rect2:
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return Rect2()
	var clave: int = tex.get_instance_id()
	var r: Rect2
	if _cache_dibujo.has(clave):
		r = _cache_dibujo[clave]
	else:
		r = Rect2(Vector2.ZERO, tex.get_size())   # sin recorte: el lienzo entero
		if tex is AtlasTexture:
			var at: AtlasTexture = tex
			r = Rect2(at.margin.position, at.region.size)
		var img: Image = tex.get_image()
		if img != null:
			var usado: Rect2i = img.get_used_rect()
			if usado.size.x > 0 and usado.size.y > 0:
				r = Rect2(r.position + Vector2(usado.position), Vector2(usado.size))
		r.position -= tex.get_size() * 0.5   # relativo al centro del lienzo
		_cache_dibujo[clave] = r
	if not spr.centered:
		r.position += tex.get_size() * 0.5
	r.position += spr.offset
	return r


# Pulsaste una habilidad con huella: a apuntar.
func apuntar(ab: AbilityData) -> void:
	if _pantalla._state != _pantalla.State.WAITING_PLAYER or not is_instance_valid(_cuerpo):
		return
	_apuntando = ab
	_pillados_vistos = -1
	_andando = false
	_pantalla._ocultar_cajas()
	_mostrar_volver()
	_refrescar_apunte(_raton_en_mundo())


func esta_apuntando() -> bool:
	return _apuntando != null


func _refrescar_apunte(raton: Vector2) -> void:
	if _apuntando == null or not is_instance_valid(_cuerpo):
		return
	var f = forma_de(_apuntando, _quien, raton)
	var arena: ArenaCombate = _arena()
	# EL ESCUDAZO (Guardia rota): su linea, dentro de la huella del tajo.
	var f_esc = forma_escudazo(_apuntando, _quien, raton) if _apuntando.forma_escudo_largo > 0.0 else null
	if arena != null:
		arena.poner_huella(CLAVE_APUNTE, f, _apuntando.forma_nucleo)
		if f_esc != null:
			arena.poner_huella(CLAVE_APUNTE_ESCUDO, f_esc, 0.0, COLOR_ESCUDAZO)
	# Y a los demas: si llevo la pelea la apunto en la lista que reparto; si soy espejo, se la mando.
	_anotar_huella_red(_quien, CLASE_APUNTANDO, f, _apuntando.forma_nucleo)
	_anotar_huella_red(_quien, CLASE_ESCUDAZO, f_esc, 0.0)
	_enviar_mi_huella(f, _apuntando.forma_nucleo, f_esc)
	# MIRA HACIA DONDE APUNTA (lo pidio el usuario), pero solo QUIETO: andando manda la pose de andar
	# (ver _tick_moviendo). Su cuerpo es el de esta maquina, y su cara viaja con el, por el canal del
	# jugador.
	if not _andando:
		_animar(_cuerpo, raton - _cuerpo.global_position, false)
	# Cuantos pilla, en un letrero junto al boton de volver y NO en el registro: el registro viaja a
	# los demas jugadores, y cada movimiento del raton seria una linea en su pantalla.
	apunte = raton
	_hay_apunte = true
	var aliados: Array = aliados_de_huella(_apuntando, _quien) if _apuntando.forma_a_aliados else []
	var n: int = aliados.size() if _apuntando.forma_a_aliados else reparto_habilidad(_apuntando, _quien).size()
	# EL PASO dice en que orden: no es lo mismo pegar e irte que llegar y pegar.
	var modo_paso: int = int(plan_paso(_apuntando, _quien)["modo"]) if _apuntando.paso else -1
	# Andando no se puede soltar (ver _confirmar_apunte): el letrero lo dice. -2 = "estoy andando".
	var visto: int = -2 if _andando else n + (modo_paso + 1) * 1000
	if _apuntando.forma_a_aliados and not aliados.is_empty():
		visto += 100000 * (_pantalla._aliados.find(aliados[0]) + 1)
	if visto != _pillados_vistos and is_instance_valid(_letrero):
		_pillados_vistos = visto
		var pilla: String = "no pilla a nadie" if n == 0 else ("pilla a 1" if n == 1 else "pilla a %d" % n)
		if _apuntando.forma_a_aliados:
			if _apuntando.objetivo_aliado == AbilityData.Objetivo.ALIADO:
				pilla = "elige a uno de los tuyos" if n == 0 else "a %s" % (aliados[0] as Combatant).nombre
			else:
				pilla = "no llega a ninguno de los tuyos" if n == 0 \
					else ("llega a 1 de los tuyos" if n == 1 else "llega a %d de los tuyos" % n)
		match modo_paso:
			Desliz.TRAS: pilla = "estocada y te apartas"
			Desliz.ANTES: pilla = "te acercas y estocada"
			Desliz.YA: pilla = "solo el paso"
		_letrero.text = ("%s: párate para lanzarla" % _apuntando.nombre) if _andando \
			else "%s: %s.  Clic para lanzarla · clic derecho para volver" % [_apuntando.nombre, pilla]


func _confirmar_apunte() -> void:
	# HAY QUE ESTAR QUIETO para lanzarla (lo pidio el usuario): asi el personaje ya se ha girado hacia
	# donde golpea. Andando, el clic no hace nada (el letrero lo avisa).
	if _andando:
		return
	var ab: AbilityData = _apuntando
	# LAS DE UNO DE LOS TUYOS (Escolta, Muro) no se lanzan al aire: sin nadie debajo, el clic no hace nada.
	if ab.forma_a_aliados and ab.objetivo_aliado == AbilityData.Objetivo.ALIADO \
			and aliados_de_huella(ab, _quien).is_empty():
		return
	# UN HECHIZO: el sitio se queda sellado con el conjuro y se empieza a recitar.
	if not _hechizo_apuntado.is_empty():
		var hz: Array = _hechizo_apuntado
		var aliado_hz = hz[1]
		# A UNO DE LOS TUYOS (el Vendaje): sin nadie debajo el clic no hace nada; con alguien, va a ese.
		if ab.forma_a_aliados and ab.objetivo_aliado == AbilityData.Objetivo.ALIADO:
			var bajo: Array = aliados_de_huella(ab, _quien)
			if bajo.is_empty():
				return
			aliado_hz = bajo[0]
		_hechizo_apuntado = []
		_dejar_de_apuntar()
		_pantalla.magia._elegir_hechizo(hz[0], aliado_hz, _raton_en_mundo())
		return
	_dejar_de_apuntar()
	apunte = _raton_en_mundo()
	_hay_apunte = true
	_pantalla.habilidades._usar_habilidad(ab)


func _cancelar_apunte() -> void:
	var era_hechizo: bool = not _hechizo_apuntado.is_empty()
	_hechizo_apuntado = []
	_dejar_de_apuntar()
	if era_hechizo:
		_pantalla.magia._accion_magia()   # de vuelta al menu de magia
	else:
		_pantalla.habilidades._accion_habilidad()   # de vuelta al menu de habilidades


func _dejar_de_apuntar() -> void:
	if _apuntando != null and _quien != null:
		_anotar_huella_red(_quien, CLASE_APUNTANDO, null, 0.0)
		_anotar_huella_red(_quien, CLASE_ESCUDAZO, null, 0.0)
		_enviar_mi_huella(null, 0.0)
	_apuntando = null
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.quitar_huella(CLAVE_APUNTE)
		arena.quitar_huella(CLAVE_APUNTE_ESCUDO)
	if is_instance_valid(_boton_volver):
		_boton_volver.queue_free()
	_boton_volver = null
	if is_instance_valid(_letrero):
		_letrero.queue_free()
	_letrero = null


# Lo llama la pantalla desde su _input, ANTES que nada. true = el evento era del apuntado.
func input_apuntando(event: InputEvent) -> bool:
	if _apuntando == null:
		return false
	if event is InputEventMouseMotion:
		_refrescar_apunte(_raton_en_mundo())
		return false   # el movimiento no se come: la ficha del que tienes debajo sigue funcionando
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		# Un clic sobre un BOTON (el de volver) es del boton, no del suelo.
		var bajo: Control = _pantalla.get_viewport().gui_get_hovered_control()
		if bajo is BaseButton:
			return false
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_confirmar_apunte()
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancelar_apunte()
			return true
	if event.is_action_pressed(&"cancelar"):
		_cancelar_apunte()
		return true
	return false


# El boton de volver: en tactil no hay clic derecho. UI provisional, como la pregunta de huir.
var _boton_volver: Button = null
var _letrero: Label = null

func _mostrar_volver() -> void:
	if is_instance_valid(_boton_volver):
		return
	_boton_volver = Button.new()
	_boton_volver.text = "↩ Volver"
	_boton_volver.focus_mode = Control.FOCUS_NONE
	_boton_volver.pressed.connect(_cancelar_apunte)
	_pantalla.add_child(_boton_volver)
	var util: Rect2 = Game._rect_util_tactico()
	_boton_volver.position = Vector2(util.get_center().x - 60.0, util.end.y - 56.0)
	_boton_volver.custom_minimum_size = Vector2(120, 44)
	_letrero = Label.new()
	_letrero.add_theme_font_size_override("font_size", 18)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	_letrero.add_theme_constant_override("outline_size", 6)
	_letrero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letrero.size = Vector2(util.size.x, 28)
	_letrero.position = Vector2(util.position.x, util.end.y - 88.0)
	_pantalla.add_child(_letrero)


# Donde esta el raton EN EL MUNDO: la pantalla va en una capa aparte, pero el suelo lo pinta la
# camara, asi que se deshace su transformacion.
func _raton_en_mundo() -> Vector2:
	var vp: Viewport = _pantalla.get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


# EN EL ESPEJO, al contestar una habilidad: el punto al que apunte. [] si no hay.
func apunte_para_red() -> Array:
	return [apunte.x, apunte.y] if _hay_apunte else []


# EN QUIEN LLEVA LA PELEA: el punto sellado con la habilidad de otro humano. No se valida contra
# nada: la huella se rehace aqui con SU posicion sellada y SU alcance, asi que un punto lejisimos
# solo pone el centro en la punta de su arma, que es lo mas lejos que puede caer.
func anotar_apunte(p: Array) -> void:
	_hay_apunte = p.size() >= 2
	apunte = Vector2(float(p[0]), float(p[1])) if _hay_apunte else Vector2.ZERO


# LAS CARGAS: el sitio se elige al EMPEZAR a cargar y se queda (combatiente -> [ab, punto]). Mientras
# carga, su huella se queda pintada en el suelo: es el aviso, y lo que deja salir de ella andando.
# Vive en quien lleva la pelea, que es quien suelta la carga (ver _begin_player_turn).
var _cargas: Dictionary = {}

func guardar_carga(c: Combatant, ab: AbilityData) -> void:
	if c == null or not _hay_apunte:
		return
	_cargas[c] = [ab, apunte]
	var f = forma_de(ab, c, apunte)
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.poner_huella(c, f, ab.forma_nucleo, COLOR_CARGA)
	_anotar_huella_red(c, CLASE_CARGA, f, ab.forma_nucleo)
	# Y se queda con el arma en alto mientras carga (ver _animar).
	var cu: Node2D = cuerpo_de(c)
	if cu != null:
		_animar(cu, _mirada_de(cu), false)


func tiene_carga(c: Combatant) -> bool:
	return _cargas.has(c)


# Pone el sitio guardado como el apunte de la accion y borra la huella: lo que queda es soltarla.
func recuperar_carga(c: Combatant) -> void:
	var d: Array = _cargas.get(c, [])
	_cargas.erase(c)
	_anotar_huella_red(c, CLASE_CARGA, null, 0.0)
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.quitar_huella(c)
	if d.size() >= 2:
		apunte = d[1]
		_hay_apunte = true


# Si le interrumpen la carga (aturdido) o cae, la huella se va con ella.
func olvidar_carga(c: Combatant) -> void:
	if not _cargas.has(c):
		return
	_cargas.erase(c)
	_anotar_huella_red(c, CLASE_CARGA, null, 0.0)
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.quitar_huella(c)


# ------------------------------------------------------------
#  LAS HABILIDADES DEL ENEMIGO EN EL MAPA (28/09, empezando por los slimes)
# ------------------------------------------------------------
# Con su forma en la ficha (forma/forma_apunte, como las tuyas) el enemigo APUNTA: busca el sitio o la
# direccion que pilla a MAS de los tuyos a la vez (lo pidio el usuario: "el reventon es el slime
# hinchandose y saltando sobre los personajes: intentara caer sobre varios"). Las CARGADAS eligen el sitio
# al empezar y su huella se queda ROJA en el suelo toda la carga: al soltar cae ahi, y el que se haya
# salido se ha librado. Todo esto corre solo en quien lleva la pelea (la IA es suya); a los espejos les
# llegan la huella de la carga (por el paquete de huellas) y los golpes (por los impactos).

# EL MEJOR SITIO: {punto, n, valor}. Prueba a apuntar a cada uno de los tuyos, al punto medio de cada pareja
# y al centro de todos (lo que importa en un circulo es donde cae), y se queda con el que mas pilla, pesando
# cada uno por lo que le entra (el nucleo cuenta entero, el anillo menos). A igualdad, el que pilla a su
# PRESA ('preferido', el que eligio el sorteo por aggro), y si no el primero: el mismo en todas las maquinas.
# n = 0: desde aqui no pilla a nadie.
func mejor_apunte(e: Combatant, ab: AbilityData, preferido: Combatant = null) -> Dictionary:
	var vivos: Array = _pantalla._aliados_vivos()
	var pies: Vector2 = pies_de(e)
	var puntos: Array = []
	for a in vivos:
		puntos.append(bulto_de(a).get_center())
	var cae_en_un_sitio: bool = int(ab.forma) in [CombatFormas.Tipo.CIRCULO, CombatFormas.Tipo.PUNTO] \
		and int(ab.forma_apunte) != CombatFormas.Apunte.ALREDEDOR
	if cae_en_un_sitio and vivos.size() > 1:
		var suma := Vector2.ZERO
		for i in puntos.size():
			suma += puntos[i]
			for j in range(i + 1, puntos.size()):
				puntos.append(((puntos[i] as Vector2) + (puntos[j] as Vector2)) * 0.5)
		if vivos.size() > 2:
			puntos.append(suma / float(vivos.size()))
	var mejor: Dictionary = {"punto": pies + Vector2.RIGHT, "n": 0, "valor": 0.0}
	for p in puntos:
		var rep: Array = _reparto_en(ab, e, forma_de(ab, e, p))
		if rep.is_empty():
			continue
		var valor: float = 0.0
		for d in rep:
			valor += float(d["escala"])
			if d["c"] == preferido:
				valor += 0.001
		if valor > float(mejor["valor"]) + 0.0001:
			mejor = {"punto": p, "n": rep.size(), "valor": valor}
	return mejor


# ¿Puede usar 'ab' en el mapa este turno? Con huella, si desde aqui pilla a alguien; sin huella, si tiene a
# quien pegar ('obj', ya filtrado por alcance) o si es de las que solo se echa encima (la Ignicion).
func sirve_en_mapa(e: Combatant, ab: AbilityData, obj: Combatant) -> bool:
	if usa_huella(ab):
		return int(mejor_apunte(e, ab, obj)["n"]) > 0
	return obj != null or solo_a_si_mismo(ab)


static func solo_a_si_mismo(ab: AbilityData) -> bool:
	if ab == null or ab.dano_mult > 0.0 or ab.invoca_cantidad > 0:
		return false
	for a in ab.efectos:
		if a.en_objetivo:
			return false
	return true


# LA HUELLA CON LA QUE SUELTA 'ab': la de su carga si la estaba cargando (fija, se borra del suelo al soltar)
# y si no la mejor desde donde esta. Se gira hacia ella.
var ultima_forma_enemigo = null

func forma_para_soltar(e: Combatant, ab: AbilityData, preferido: Combatant = null) -> RefCounted:
	var f = null
	var d: Array = _cargas.get(e, [])
	if d.size() >= 3 and d[0] == ab:
		f = d[2]
		olvidar_carga(e)
	else:
		f = forma_de(ab, e, mejor_apunte(e, ab, preferido)["punto"])
	ultima_forma_enemigo = f
	_encarar(e, f.centro_util())
	return f


# A quien le cae y con cuanto: [{c, escala}], el primero el principal (el mas cercano al centro).
func reparto_enemigo(e: Combatant, ab: AbilityData, preferido: Combatant = null) -> Array:
	return _reparto_en(ab, e, forma_para_soltar(e, ab, preferido))


# LO QUE MUEVE AL ENEMIGO su habilidad, con la huella que acaba de soltar (forma_para_soltar):
#   salta   el Reventon, el Aplastamiento: por el aire hasta el centro del circulo (sin caer encima de nadie)
#   carga   el Placaje, la Presion: embiste por su linea hasta pegarse al primero que pilla (sin nadie, al final)
# Lo decide quien lleva la pelea y sale con el gesto, como el paso del estoque (pedir_desliz).
const T_SALTO_BICHO := 0.4
const ALTO_SALTO_BICHO := 26.0
const T_EMBESTIDA_BICHO := 0.2

func mover_enemigo(e: Combatant, ab: AbilityData, lista: Array, golpes: int) -> void:
	var f = ultima_forma_enemigo
	if f == null or cuerpo_de(e) == null or _pantalla._espejo:
		return
	var hasta: Vector2 = pos_de(e)
	var dur: float = T_EMBESTIDA_BICHO
	var arco: float = 0.0
	if ab.salta:
		hasta = _sitio_libre_hacia(e, f.centro)
		dur = T_SALTO_BICHO
		arco = ALTO_SALTO_BICHO * clampf(radio_pisa(e) / 10.0, 1.0, 2.5)   # el Rey salta mas alto
	elif ab.carga and f.tipo == CombatFormas.Tipo.LINEA:
		var fin: Vector2 = f.origen + f.dir * f.largo
		# El primero que se cruza (el mas cercano a sus pies).
		var v: Combatant = null
		for d in lista:
			if v == null or pies_de(d["c"]).distance_squared_to(f.origen) < pies_de(v).distance_squared_to(f.origen):
				v = d["c"]
		if v != null:
			fin = pies_de(v) - f.dir * (maxf(radio_pisa(v), 8.0) + radio_pisa(e))
		hasta = _sitio_libre_hacia(e, fin)
	else:
		return
	# El salto se ve aunque caiga casi en el sitio (los tuyos le tapan el hueco): bota en el aire.
	if hasta.distance_to(pos_de(e)) < 2.0 and not ab.salta:
		return
	pedir_desliz(e, hasta, Desliz.ANTES, maxi(1, golpes), dur, arco)


# EMPIEZA A CARGAR: elige el sitio YA y lo deja pintado en ROJO hasta que suelte.
func guardar_carga_enemigo(e: Combatant, ab: AbilityData, preferido: Combatant = null) -> void:
	var f = forma_de(ab, e, mejor_apunte(e, ab, preferido)["punto"])
	_cargas[e] = [ab, f.centro, f]
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.poner_huella(e, f, ab.forma_nucleo, COLOR_ENEMIGO)
	_anotar_huella_red(e, CLASE_CARGA, f, ab.forma_nucleo)
	_encarar(e, f.centro_util())


# Se gira hacia donde va a soltar, y se lo cuenta al dueño del bicho si es de otra maquina.
func _encarar(e: Combatant, p: Vector2) -> void:
	var cu: Node2D = cuerpo_de(e)
	if cu == null or p.distance_squared_to(cu.global_position) < 1.0:
		return
	_animar(cu, p - cu.global_position, false)
	_apuntar_bicho(cu, false)
	_enviar_bichos()


# DESDE LEJOS: antes de echar a andar, si tiene lista una habilidad que YA pilla a alguien desde donde esta
# (el escupitajo, la tromba), la tirada de habilidad se hace aqui; si sale, la suelta sin moverse. La tirada
# se guarda para que _enemy_turn no tire otra vez: una por turno, ande o no.
var _tiradas: Dictionary = {}     # Combatant -> bool
var _decididas: Dictionary = {}   # Combatant -> AbilityData

func _decidir_de_lejos(e: Combatant) -> bool:
	if _pantalla._dps_on or e.silenciado() or e.charging != null \
			or _pantalla.enemigos._invocacion_lista(e) != null:
		return false
	var buenas: Array = []
	for ab in e.habilidades:
		if e.ability_ready(ab) and ab.invoca_cantidad <= 0 and usa_huella(ab) \
				and int(mejor_apunte(e, ab)["n"]) > 0:
			buenas.append(ab)
	if buenas.is_empty():
		return false
	var sale: bool = randf() < e.prob_habilidad
	_tiradas[e] = sale
	if not sale:
		return false
	_decididas[e] = buenas[randi() % buenas.size()]
	return true


# La tirada de habilidad de este turno: la de _decidir_de_lejos si la hubo, o una nueva.
func sacar_tirada(e: Combatant) -> bool:
	if _tiradas.has(e):
		var t: bool = _tiradas[e]
		_tiradas.erase(e)
		return t
	return randf() < e.prob_habilidad


func sacar_decidida(e: Combatant) -> AbilityData:
	var ab: AbilityData = _decididas.get(e)
	_decididas.erase(e)
	return ab


# ------------------------------------------------------------
#  QUE LOS DEMAS VEAN LAS HUELLAS
# ------------------------------------------------------------
# Quien lleva la pelea guarda TODAS las huellas vivas (la que se apunta, sea de aqui o de un espejo, y
# las de las cargas) y las reparte juntas unas veces por segundo. Cada maquina pinta las de los demas;
# la suya, mientras apunta, la pinta ella misma sin esperar a la red.
#
# UNA HUELLA = 15 floats: [cod, clase, tipo, cx, cy, ox, oy, dx, dy, radio, apertura, nucleo, tramos,
# ancho, ancho_fin]. cod = el codigo de siempre del combatiente (espejo._cod_combatiente). clase 0 =
# apuntando, 1 = carga. En la LINEA el radio es su largo; ancho y ancho_fin solo los mira ella.
const FLOATS_HUELLA := 15
const CLASE_APUNTANDO := 0
const CLASE_CARGA := 1
const CLASE_ESCUDAZO := 2   # la linea del escudazo de la Guardia rota, que va con la de apuntar
const CLASES_HUELLA := 3
const ENVIO_HUELLAS := 1.0 / 12.0
const REPETIR_HUELLAS := 0.5   # aunque no cambie nada: un paquete perdido no deja una huella fantasma
var _huellas_red: Dictionary = {}          # cod -> PackedFloat32Array (en quien lleva la pelea)
var _huellas_cambiadas: bool = false
var _t_huellas: float = 0.0
var _t_repetir: float = 0.0
var _mi_huella_enviada: PackedFloat32Array = PackedFloat32Array()
var _claves_red: Array = []                # las que pinte llegadas por red, para quitarlas luego


static func _empaquetar(cod: int, clase: int, f, nucleo: float) -> PackedFloat32Array:
	return PackedFloat32Array([float(cod), float(clase), float(f.tipo), f.centro.x, f.centro.y,
		f.origen.x, f.origen.y, f.dir.x, f.dir.y, f.radio, f.apertura, nucleo, float(f.tramos),
		f.ancho, f.ancho_fin])


static func _desempaquetar(d: PackedFloat32Array, i: int) -> Array:
	var f := CombatFormas.Forma.new()
	f.tipo = int(d[i + 2])
	f.centro = Vector2(d[i + 3], d[i + 4])
	f.origen = Vector2(d[i + 5], d[i + 6])
	f.dir = Vector2(d[i + 7], d[i + 8])
	f.radio = d[i + 9]
	f.apertura = d[i + 10]
	f.tramos = int(d[i + 12])
	f.ancho = d[i + 13]
	f.ancho_fin = d[i + 14]
	if f.tipo == CombatFormas.Tipo.LINEA:
		f.largo = f.radio
	return [int(d[i]), int(d[i + 1]), f, d[i + 11]]


func _cod(c: Combatant) -> int:
	return _pantalla.espejo._cod_combatiente(c)


# Apunta (o borra, con f = null) una huella en la lista que se reparte. Solo en quien lleva la pelea.
func _anotar_huella_red(c: Combatant, clase: int, f, nucleo: float) -> void:
	if _pantalla._espejo:
		return
	var cod: int = _cod(c) * CLASES_HUELLA + clase   # las de apuntar, cargar y escudazo del mismo no se pisan
	if f == null:
		if _huellas_red.erase(cod):
			_huellas_cambiadas = true
		return
	_huellas_red[cod] = _empaquetar(_cod(c), clase, f, nucleo)
	_huellas_cambiadas = true


# EN EL ESPEJO que apunta: su huella, a quien lleva la pelea (solo si ha cambiado). Vacia = ya no apunto.
func _enviar_mi_huella(f, nucleo: float, f_escudo = null) -> void:
	if not _pantalla._espejo:
		return
	var d: PackedFloat32Array = PackedFloat32Array() if f == null \
		else _empaquetar(_cod(_quien), CLASE_APUNTANDO, f, nucleo)
	# El escudazo, pegado detras (la de apuntar va siempre la primera).
	if f != null and f_escudo != null:
		d.append_array(_empaquetar(_cod(_quien), CLASE_ESCUDAZO, f_escudo, 0.0))
	if d == _mi_huella_enviada:
		return
	_mi_huella_enviada = d
	if d.is_empty():
		d = PackedFloat32Array([float(_cod(_quien)), -1.0])   # "la mia, fuera"
	Net.peleas.enviar_mi_huella(d)


# EN QUIEN LLEVA LA PELEA: llega la huella del espejo que apunta. Solo se acepta la de un personaje
# de ESE humano, y solo mientras le toca: una rezagada de un turno ya jugado no se pinta.
func huella_de_espejo(d: PackedFloat32Array, emisor: int) -> void:
	if _pantalla._espejo or d.size() < 2:
		return
	var c: Combatant = _pantalla.espejo._de_codigo(int(d[0]))
	if c == null or c != _pantalla._player or int(_pantalla._dueno_aliado.get(c, 0)) != emisor:
		return
	if int(d[1]) < 0 or d.size() < FLOATS_HUELLA:
		_anotar_huella_red(c, CLASE_APUNTANDO, null, 0.0)
		_anotar_huella_red(c, CLASE_ESCUDAZO, null, 0.0)
		return
	var x: Array = _desempaquetar(d, 0)
	_anotar_huella_red(c, CLASE_APUNTANDO, x[2], x[3])
	var esc = _desempaquetar(d, FLOATS_HUELLA)[2] if d.size() >= FLOATS_HUELLA * 2 else null
	_anotar_huella_red(c, CLASE_ESCUDAZO, esc, 0.0)


# Cada fotograma en quien lleva la pelea: reparte si algo cambio (o cada medio segundo, por si se
# perdio un paquete). La de un turno que ya se fue, fuera.
func _tick_huellas(delta: float) -> void:
	if _pantalla._espejo or not Net.activo:
		return
	# La de apuntar solo vive mientras es el turno de ese: si se fue sin avisar, se borra aqui.
	for cod in _huellas_red.keys():
		var d: PackedFloat32Array = _huellas_red[cod]
		if int(d[1]) != CLASE_CARGA and (_pantalla._state != _pantalla.State.WAITING_PLAYER
				or _pantalla.espejo._de_codigo(int(d[0])) != _pantalla._player):
			_huellas_red.erase(cod)
			_huellas_cambiadas = true
	_t_huellas += delta
	_t_repetir += delta
	if _t_huellas < ENVIO_HUELLAS or (not _huellas_cambiadas and _t_repetir < REPETIR_HUELLAS):
		return
	_t_huellas = 0.0
	_t_repetir = 0.0
	_huellas_cambiadas = false
	Net.peleas.difundir_huellas(estado_huellas())


func estado_huellas() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for cod in _huellas_red:
		out.append_array(_huellas_red[cod])
	return out


# EN EL ESPEJO: llegan todas las huellas vivas. Se quitan las que pinte antes y se ponen estas, menos
# la MIA mientras apunto (esa la pinto yo, al momento).
func aplicar_huellas(d: PackedFloat32Array) -> void:
	if not _pantalla._espejo:
		return
	var arena: ArenaCombate = _arena()
	if arena == null:
		return
	for k in _claves_red:
		arena.quitar_huella(k)
	_claves_red.clear()
	var i: int = 0
	while i + FLOATS_HUELLA <= d.size():
		var x: Array = _desempaquetar(d, i)
		i += FLOATS_HUELLA
		var c: Combatant = _pantalla.espejo._de_codigo(int(x[0]))
		if int(x[1]) != CLASE_CARGA and _apuntando != null and c == _quien:
			continue
		var clave: String = "red_%d_%d" % [int(x[0]), int(x[1])]
		var col: Color = COLOR_CARGA if int(x[1]) == CLASE_CARGA \
			else (COLOR_ESCUDAZO if int(x[1]) == CLASE_ESCUDAZO else COLOR_APUNTE)
		if _pantalla._enemies.has(c):
			col = COLOR_ENEMIGO
		arena.poner_huella(clave, x[2], x[3], col)
		_claves_red.append(clave)


# ROJO = ENEMIGO (decidido con el usuario el 28/09): las nuestras van en frios, del color de nuestro
# circulo de movimiento, para que una huella roja en el suelo se lea siempre como "apartate".
const COLOR_APUNTE := Color(0.45, 0.85, 1.0)
const COLOR_CARGA := Color(0.35, 0.5, 1.0)
const COLOR_ESCUDAZO := Color(0.95, 0.95, 1.0)   # la linea del escudazo, dentro de la del tajo
const COLOR_ENEMIGO := Color(1.0, 0.3, 0.25)


# EL TURNO SE HA IDO: se eligio accion, o se lo ha llevado otra cosa (huyo, cayo).
func _turno_acabado() -> bool:
	return _pantalla._state != _pantalla.State.WAITING_PLAYER or _pantalla._player != _quien \
		or not is_instance_valid(_cuerpo)


func _tick_moviendo(delta: float) -> void:
	if _turno_acabado():
		_terminar()
		return
	var arena: ArenaCombate = _arena()
	_vigilar_alcance()
	# SE ANDA con la barra de acciones delante, en el menu de habilidades y APUNTANDO una: recolocarse
	# mientras eliges como golpear es justo lo que hace falta (lo pidio el usuario: tener que volver
	# atras del todo para dar dos pasos y volver a elegir la habilidad era un engorro). No en los
	# demas submenus (hechizos, objetos).
	var en_menu: bool = (_pantalla._actions_box != null and _pantalla._actions_box.visible) \
		or (_pantalla._ability_box != null and _pantalla._ability_box.visible) or _apuntando != null
	var puede: bool = _radio > 0.0 and en_menu
	var dir: Vector2 = Vector2.ZERO
	if puede:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# El joystick de la pantalla manda cuando hay un dedo puesto (igual que en player.gd).
		if Tactil.activo and Tactil.eje != Vector2.ZERO:
			dir = Tactil.eje
	if dir == Vector2.ZERO:
		if _andando:
			_andando = false
			# Apuntando, al pararte te GIRAS hacia el raton (lo pidio el usuario): es lo que vas a golpear.
			if _apuntando != null:
				_animar(_cuerpo, _raton_en_mundo() - _cuerpo.global_position, false)
				_pillados_vistos = -1   # que el letrero vuelva a decir a cuantos pilla
				_refrescar_apunte(_raton_en_mundo())
			else:
				_animar(_cuerpo, _mirada_de(_cuerpo), false)
		return
	var antes: Vector2 = _cuerpo.global_position
	var nueva: Vector2 = paso(antes, dir.limit_length(1.0) * VEL_PASEO * delta, _inicio, _radio,
		_dentro(arena), _puede_estar.bind(_cuerpo))
	_colocar(_quien, _cuerpo, nueva)
	_andando = true
	# Apuntando, la huella viene contigo, pero el personaje ANDA de verdad, mirando hacia donde va (lo pidio
	# el usuario: antes miraba al raton y se le pedian dos poses por fotograma, quieto y andando, y la de
	# andar volvia a empezar cada vez: se quedaba tieso). Al pararse se gira hacia el raton.
	if _apuntando != null:
		_refrescar_apunte(_raton_en_mundo())
	_animar(_cuerpo, dir, true)


# LOS BOTONES CAMBIAN SEGUN ANDAS: al entrar en el alcance de alguien, Atacar se enciende; al salir
# de todos, se apaga. Pegado al muro, Pasar se vuelve Huir. Solo se repintan cuando algo cambia
# (tambien si pulsas a otro enemigo), no cada fotograma: _refresh_actions reescribe los tooltips de
# toda la barra.
var _alcance_visto: Array = []

func _vigilar_alcance() -> void:
	var ahora: Array = [_pantalla._target_idx, llega(_quien, _pantalla._objetivo()), llega_a_alguno(_quien),
		en_el_borde()]
	if ahora != _alcance_visto:
		_alcance_visto = ahora
		if _pantalla._actions_box != null and _pantalla._actions_box.visible:
			_pantalla._refresh_actions()


# EL PASO, puro y sin nodos, para poder probarlo solo (tools/prueba_tactico_turno).
#
#   desde    donde esta           mov      lo que quiere andar este fotograma
#   inicio   el centro del circulo radio   hasta donde puede alejarse de el
#   dentro   el rectangulo por el que se puede andar (la arena menos su borde)
#   puede    Callable(p) -> bool: si ese punto se pisa (suelo, y nadie encima)
#
# LAS DOS PAREDES SON BLANDAS: ni el circulo ni la arena te frenan en seco, te DEVUELVEN a su borde,
# asi que empujar contra ellos te hace resbalar a lo largo en vez de pararte. La roca si es dura: si
# el punto no se pisa se prueba cada eje por separado (deslizar por la pared), y si ninguno vale, no
# se mueve.
static func paso(desde: Vector2, mov: Vector2, inicio: Vector2, radio: float, dentro: Rect2,
		puede: Callable) -> Vector2:
	for intento in [mov, Vector2(mov.x, 0.0), Vector2(0.0, mov.y)]:
		if (intento as Vector2).is_zero_approx():
			continue
		var p: Vector2 = _acotar(desde + intento, inicio, radio, dentro)
		if p.distance_squared_to(desde) < 0.0001:
			continue
		if puede.call(p):
			return p
	return desde


static func _acotar(p: Vector2, inicio: Vector2, radio: float, dentro: Rect2) -> Vector2:
	if p.distance_to(inicio) > radio:
		p = inicio + (p - inicio).limit_length(radio)
	if dentro.has_area():
		p = Vector2(clampf(p.x, dentro.position.x, dentro.end.x),
			clampf(p.y, dentro.position.y, dentro.end.y))
	return p


# ------------------------------------------------------------
#  SU TURNO: el enemigo se acerca y luego actua
# ------------------------------------------------------------

# Lo llama _process en lugar de enemigos._enemy_turn. Si el bicho no tiene por que andar, actua ya.
func turno_enemigo(e: Combatant) -> void:
	_terminar()
	var cuerpo: Node2D = cuerpo_de(e)
	var radio: float = radio_de(e)
	var presa: Combatant = _presa_de(e)
	_tiradas.erase(e)
	_decididas.erase(e)
	# Aturdido pierde el turno de todas formas: andar y luego no hacer nada seria contarlo mal. Y el
	# que ya tiene a alguien a tiro no se mueve: pega desde donde esta.
	if cuerpo == null or presa == null or radio <= 0.0 or e.aturdido() \
			or hueco_entre(e, presa) <= alcance_de(e) * ARRIMARSE:
		_turno_enemigo_de_siempre(e)
		return
	# Lo que ya llega desde aqui (un escupitajo) se suelta sin andar, si le sale la tirada.
	if _decidir_de_lejos(e):
		_turno_enemigo_de_siempre(e)
		return
	_quien = e
	_cuerpo = cuerpo
	_foco = cuerpo
	_presa = presa
	_inicio = cuerpo.global_position
	_radio = radio
	_t_acercar = 0.0
	_t_atasco = 0.0
	_fase = Fase.ACERCANDO
	# El ATB se para mientras anda: es su turno, aunque todavia no haya decidido nada. PAUSED con la
	# cuenta en infinito, y la cuenta no se toca porque este tema se queda el fotograma (ver tick).
	_pantalla._state = _pantalla.State.PAUSED
	_pantalla._pause_left = INF
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.poner_circulo(_inicio, _radio, true)


func _tick_acercando(delta: float) -> void:
	var dt: float = delta * _pantalla._vel_pelea
	_t_acercar += dt
	if not is_instance_valid(_cuerpo) or _presa == null or not _presa.is_alive():
		_actuar()
		return
	var falta: float = hueco_entre(_quien, _presa) - alcance_de(_quien) * ARRIMARSE
	if falta <= 0.0 or _t_acercar >= TOPE_ACERCARSE:
		_actuar()
		return
	var hacia: Vector2 = pos_de(_presa) - _cuerpo.global_position
	var antes: Vector2 = _cuerpo.global_position
	var quiere: float = minf(VEL_ACERCARSE * dt, falta)
	var nueva: Vector2 = paso(antes, hacia.normalized() * quiere, _inicio, _radio,
		_dentro(_arena()), _puede_estar.bind(_cuerpo))
	_colocar(_quien, _cuerpo, nueva)
	_animar(_cuerpo, hacia, true, (nueva - antes) / maxf(delta, 0.0001))
	_apuntar_bicho(_cuerpo, true)
	_t_envio += delta
	if _t_envio >= ENVIO_BICHOS:
		_t_envio = 0.0
		_enviar_bichos()
	# ATASCADO (contra roca, o en el borde de su circulo): no se agota el tope empujando.
	if nueva.distance_to(antes) < ATASCO_PX:
		_t_atasco += dt
		if _t_atasco >= ATASCO_T:
			_actuar()
	else:
		_t_atasco = 0.0


func _actuar() -> void:
	var e: Combatant = _quien
	if is_instance_valid(_cuerpo):
		var mira: Vector2 = pos_de(_presa) - _cuerpo.global_position \
			if _presa != null else _mirada_de(_cuerpo)
		_animar(_cuerpo, mira, false)
		# EL ULTIMO AVISO AL DUEÑO: "se ha parado aqui, mirando alli". Sin el, en las demas pantallas
		# el bicho se quedaba con la pose de andar o unos pixeles antes de donde se paro de verdad.
		_apuntar_bicho(_cuerpo, false)
		_enviar_bichos()
	_terminar()
	# La cuenta a cero: si su turno no la vuelve a poner (casi todos acaban en _pausa_lectura, que
	# si), el siguiente fotograma la pelea sigue sola en vez de quedarse en pausa para siempre.
	_pantalla._pause_left = 0.0
	if e != null and e.is_alive() and _pantalla._state != _pantalla.State.FINISHED:
		_turno_enemigo_de_siempre(e)


# Apunta donde esta un bicho para contarselo a su dueño. Solo si su dueño es OTRA maquina (lo que
# tengo es su espejo, remote_enemy): si el bicho de verdad es mio, mi propio tick de red ya lo lee
# de su nodo y no hay nada que contar.
func _apuntar_bicho(cuerpo: Node2D, andando: bool) -> void:
	if not Net.activo or not is_instance_valid(cuerpo) or not cuerpo.has_meta("net_id") \
			or not cuerpo.get("_objetivo") is Vector2:
		return
	_bichos_movidos[int(cuerpo.get_meta("net_id"))] = [cuerpo.global_position,
		_mirada_de(cuerpo).angle(), andando]


func _enviar_bichos() -> void:
	if _bichos_movidos.is_empty():
		return
	var lote: Array = []
	for id in _bichos_movidos:
		var d: Array = _bichos_movidos[id]
		lote.append([id, d[0], d[1], d[2]])
	_bichos_movidos.clear()
	Net.peleas.mover_bichos_en_pelea(lote)


# A QUIEN SE ACERCA: al de los tuyos que tenga mas cerca (por el hueco, como se mide el alcance). No
# es necesariamente a quien pega: eso lo sortea _enemy_turn por amenaza ENTRE LOS QUE ALCANZA al
# acabar de andar (ver objetivos._elegir_objetivo_enemigo). Si no alcanza a nadie, pierde el ataque.
func _presa_de(e: Combatant) -> Combatant:
	var mejor: Combatant = null
	var d_mejor: float = INF
	# PROVOCADO (la Provocacion del escudo, 25/09): va a por quien le provoca, el mas cercano si son varios.
	# Luego, al pegar, el sorteo sigue inclinado hacia el (combat_objetivos._peso_aggro).
	for c in _pantalla._aliados_vivos():
		if c.provocar_turnos > 0 and e in c.provocados:
			var dp: float = hueco_entre(e, c)
			if dp < d_mejor:
				d_mejor = dp
				mejor = c
	if mejor != null:
		return mejor
	for c in _pantalla._aliados_vivos():
		var d: float = hueco_entre(e, c)
		if d < d_mejor:
			d_mejor = d
			mejor = c
	return mejor


# ------------------------------------------------------------
#  EL BORDE: Pasar se vuelve Huir
# ------------------------------------------------------------

# ¿El que tiene el turno esta pegado al muro de la arena? Con el mismo margen con el que la arena da
# por tocado su borde (ArenaCombate.MARGEN): el paso te deja a DENTRO_DEL_BORDE, por debajo.
func en_el_borde() -> bool:
	var arena: ArenaCombate = _arena()
	if arena == null or not is_instance_valid(_cuerpo):
		return false
	return arena.distancia_al_borde(_cuerpo.global_position) <= ArenaCombate.MARGEN


# ------------------------------------------------------------
#  AYUDANTES
# ------------------------------------------------------------

func _terminar() -> void:
	if _fase == Fase.MOVIENDO and is_instance_valid(_cuerpo) and _andando:
		_animar(_cuerpo, _mirada_de(_cuerpo), false)
	_fase = Fase.NADA
	_quien = null
	_cuerpo = null
	_presa = null
	_alcance_visto = []
	_dejar_de_apuntar()
	_hay_apunte = false
	_andando = false
	_quitar_circulo()


# ------------------------------------------------------------
#  LA RED
# ------------------------------------------------------------

# EL CIRCULO QUE SE ESTA VIENDO, para que los espejos pinten el mismo: [quien, x, y, radio]. 'quien'
# es el codigo de siempre del combatiente (aliados tal cual, enemigos desde 100; ver
# espejo._cod_combatiente), -1 si no anda nadie. Viaja al final del paquete de la barra de turnos.
func estado_red() -> PackedFloat32Array:
	if _fase == Fase.NADA or _quien == null or _radio <= 0.0:
		return PackedFloat32Array([-1.0, 0.0, 0.0, 0.0])
	return PackedFloat32Array([float(_pantalla.espejo._cod_combatiente(_quien)),
		_inicio.x, _inicio.y, _radio])


# EN EL ESPEJO: llega el circulo de quien lleva la pelea. Si el turno es mio y ya estoy andando, el
# que manda es el mio (lo pinte yo al empezar), no el que viene con retraso por la red.
func aplicar_red(d: PackedFloat32Array) -> void:
	if not _pantalla._espejo or d.size() < 4 or _fase == Fase.MOVIENDO:
		return
	var arena: ArenaCombate = _arena()
	if arena == null:
		return
	var cod: int = int(d[0])
	if cod < 0 or d[3] <= 0.0:
		arena.quitar_circulo()
	else:
		arena.poner_circulo(Vector2(d[1], d[2]), d[3], cod >= 100)
		# La camara, con quien anda aunque lo mueva otra maquina.
		var c_red: Combatant = _pantalla.espejo._de_codigo(cod)
		if c_red != null and cuerpo_de(c_red) != null:
			_foco = cuerpo_de(c_red)


# EN EL ESPEJO, al contestar mi accion: donde he dejado a mi personaje. Viaja SELLADA con la accion
# (el mismo seq), asi quien lleva la pelea resuelve el golpe con la posicion con la que lo elegi y no
# con la que le haya llegado a medias por el canal del jugador.
func pos_para_red() -> Array:
	if _fase != Fase.MOVIENDO or not is_instance_valid(_cuerpo):
		return []
	return [_cuerpo.global_position.x, _cuerpo.global_position.y]


# EN QUIEN LLEVA LA PELEA: llega la posicion sellada con la accion de otro humano. NO SE RECHAZA
# NUNCA -- un rechazo seco congela la pelea entera --: si se sale de su circulo o de la arena se
# recorta al punto valido mas cercano y se apunta en la traza. Con un poco de holgura, porque su
# cuerpo aqui llega interpolado y el centro del circulo puede ir unos pixeles por detras.
const HOLGURA_RED := 8.0

func anotar_pos_remota(c: Combatant, pos: Array) -> void:
	if c == null or pos.size() < 2:
		return
	var p := Vector2(float(pos[0]), float(pos[1]))
	var valida: Vector2 = p
	if _quien == c and _radio > 0.0 and p.distance_to(_inicio) > _radio + HOLGURA_RED:
		valida = _inicio + (p - _inicio).limit_length(_radio)
	var arena: ArenaCombate = _arena()
	if arena != null:
		valida = arena.recortar_dentro(valida, 0.0)
	if not valida.is_equal_approx(p):
		_pantalla._traza_add("POS de %s recortada: %s -> %s" % [c.nombre, str(p.round()), str(valida.round())])
	_pos[c] = valida


func _quitar_circulo() -> void:
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.quitar_circulo()


func _arena() -> ArenaCombate:
	var a = Game.get("_arena_nodo")
	return a as ArenaCombate if is_instance_valid(a) else null


# Por donde se puede andar: la arena menos un pelo de borde (por debajo de lo que dispara la
# pregunta de huir, ver DENTRO_DEL_BORDE). Sin arena, sin limite.
func _dentro(arena: ArenaCombate) -> Rect2:
	if arena == null:
		return Rect2()
	return arena.rect.grow(-DENTRO_DEL_BORDE)


func _colocar(c: Combatant, cuerpo: Node2D, p: Vector2) -> void:
	cuerpo.global_position = p
	_pos[c] = p
	# LA COPIA DE RED de un bicho (remote_enemy) se arrastra cada fotograma hacia el ultimo sitio que
	# le mando su dueño: sin moverle tambien el destino, volvia andando a donde estaba. (Lo que le
	# siga llegando de su dueño durante la pelea ya no se le aplica, ver net_enemigos._tick_enemigos, y
	# el dueño se entera de donde lo dejo por _enviar_bichos.)
	if cuerpo.get("_objetivo") is Vector2:
		cuerpo.set("_objetivo", p)
		# Y el reloj con el que deduce si anda (remote_enemy._physics_process): sin ponerlo a cero, se
		# daba por quieto y le quitaba la pose de andar en cada fotograma.
		if cuerpo.get("_t_sin_avanzar") != null:
			cuerpo.set("_t_sin_avanzar", 0.0)
	# El orden de dibujo de los bichos lo recalcula su _physics_process, que con el arbol en pausa no
	# corre: sin esto, uno que pasa por delante de otro se quedaria pintado detras.
	# (Solo los bichos: son los que llevan _sprite y se lo recalculan asi, ver enemy._physics_process.)
	if cuerpo.get("_sprite") != null:
		cuerpo.z_index = Game.z_frente_a_personajes(cuerpo)


# ¿Puede estar ESTE cuerpo en 'p'? Toda su huella sobre suelo, y sin meterse encima de otro.
func _puede_estar(p: Vector2, cuerpo: Node2D) -> bool:
	if not _sobre_suelo(p, cuerpo):
		return false
	var antes: Vector2 = cuerpo.global_position
	var soy_enemigo: bool = _quien != null and _pantalla._enemies.has(_quien)
	var rivales: Array = _pantalla._aliados if soy_enemigo else _pantalla._enemies
	for c in rivales:
		if not c.is_alive():
			continue
		var otro: Node2D = cuerpo_de(c)
		if not is_instance_valid(otro) or otro == cuerpo:
			continue
		var o: Vector2 = otro.global_position
		if p.distance_to(o) < SEPARACION and p.distance_to(o) < antes.distance_to(o):
			return false
	# LOS TUYOS TAMBIEN CHOCAN ENTRE SI (lo pidio el usuario: se le montaban uno encima de otro), pero
	# con una excepcion: el que ya ESTA encima de un compañero lo atraviesa hasta despegarse. El grupo
	# entra a la pelea en fila, y sin esto el que va el ultimo no podia ni salir de detras de los suyos.
	# Los enemigos entre ellos siguen sin chocar: su acercamiento no sabe rodear a los suyos.
	if not soy_enemigo:
		for c in _pantalla._aliados:
			if not c.is_alive():
				continue
			var comp: Node2D = cuerpo_de(c)
			if not is_instance_valid(comp) or comp == cuerpo:
				continue
			var oc: Vector2 = comp.global_position
			if antes.distance_to(oc) >= SEPARACION and p.distance_to(oc) < SEPARACION:
				return false
	return true


# ¿Toda la huella de ESTE cuerpo en 'p' cae sobre suelo que se pisa?
func _sobre_suelo(p: Vector2, cuerpo: Node2D) -> bool:
	var piso: Node = Game.get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("_pisable_px"):
		var h: Rect2 = _huella(cuerpo)
		for esquina in [h.position, Vector2(h.end.x, h.position.y),
				Vector2(h.position.x, h.end.y), h.end]:
			if not piso._pisable_px(p + esquina):
				return false
	return true


# La huella del cuerpo en el suelo, relativa a su origen: su forma de colision, que es con lo que
# choca por el mapa. Asi un cuerpo pasa por la arena por los mismos sitios que por la mazmorra.
func _huella(cuerpo: Node2D) -> Rect2:
	for hijo in cuerpo.get_children():
		if hijo is CollisionShape2D and (hijo as CollisionShape2D).shape != null:
			var cs: CollisionShape2D = hijo
			var r: Rect2 = cs.shape.get_rect()
			return Rect2(cs.position + r.position * cs.scale, r.size * cs.scale)
	return Rect2(-HUELLA_POR_DEFECTO * 0.5, HUELLA_POR_DEFECTO)


# ------------------------------------------------------------
#  EL TIRON (Desgarro, 24/09)
# ------------------------------------------------------------
# Lo pide quien RESUELVE la habilidad (AbilityData.tiron) y se hace cuando la cola ENSEÑA el golpe
# (CombatFX.golpe_encajado): el hacha entra y se lo trae. Solo en quien lleva la pelea; las demas
# pantallas lo ven por el mismo canal que el paso de un bicho (_apuntar_bicho / _enviar_bichos). Si el
# golpe no llega a verse (sin capa de efectos), se hace igual al cabo de T_TIRON_ESPERA.
# Nunca hasta meterselo encima: se para a ALCANCE_MINIMO de quien tira, en una pared o en el borde.
const T_TIRON := 0.18
const T_TIRON_ESPERA := 3.0
var _tirones: Array = []   # {c, de, px, espera, t, desde, hasta}

func pedir_tiron(c: Combatant, de: Combatant, px: float) -> void:
	if _pantalla._espejo or c == null or de == null or is_zero_approx(px):
		return
	var tr := {"c": c, "de": de, "px": px, "espera": 0.0, "t": -1.0}
	if not _tiron_a_otro_humano(tr):
		_tirones.append(tr)


# ATRAER A UN PUNTO (la Vorágine): como el tiron, pero hacia 'hacia' (el centro de la huella) y sin pasarse de el.
func pedir_atraccion(c: Combatant, de: Combatant, hacia: Vector2, px: float) -> void:
	if _pantalla._espejo or c == null or de == null or px <= 0.0:
		return
	var tr := {"c": c, "de": de, "px": px, "hacia": hacia, "espera": 0.0, "t": -1.0}
	if not _tiron_a_otro_humano(tr):
		_tirones.append(tr)


# APARTAR A UN LADO de la linea del que embiste (la Embestida del jabali, 28/09): cada uno sale hacia SU lado
# de la linea (el de la ultima huella que solto el enemigo); el que va justo por el medio, a uno por su codigo.
func pedir_apartar(c: Combatant, de: Combatant, px: float) -> void:
	if _pantalla._espejo or c == null or de == null or px <= 0.0:
		return
	var f = ultima_forma_enemigo
	var eje: Vector2 = f.dir if f != null and f.dir != Vector2.ZERO else (pos_de(c) - pos_de(de)).normalized()
	var perp := Vector2(-eje.y, eje.x)
	var origen: Vector2 = f.origen if f != null else pies_de(de)
	var lado: float = signf(perp.dot(pies_de(c) - origen))
	if is_zero_approx(lado):
		lado = 1.0 if _cod(c) % 2 == 0 else -1.0
	var tr := {"c": c, "de": de, "px": px, "desplaza": perp * lado * px, "espera": 0.0, "t": -1.0}
	if not _tiron_a_otro_humano(tr):
		_tirones.append(tr)


# EL PERSONAJE DE OTRO HUMANO no se puede arrastrar desde aqui: su cuerpo lo mueve SU maquina (y con un
# trabajador de pelea, TODOS son de otro). Asi que el sitio donde acaba se decide YA, con la pared que lo
# para, y viaja como un desliz EMPUJON, que su maquina hace al encajar el golpe; aqui se apunta en _pos.
# Antes se movia solo la copia de esta maquina: en las pantallas de los jugadores no se movia nadie, y la
# pelea contaba con un sitio donde el personaje no estaba.
func _tiron_a_otro_humano(tr: Dictionary) -> bool:
	var c: Combatant = tr["c"]
	if not Net.activo or not _pantalla._aliados.has(c) or _es_mio(c):
		return false
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null or cuerpo_de(tr["de"]) == null:
		return true   # sin cuerpo no hay nada que mover (y tampoco aqui)
	var desde: Vector2 = pos_de(c)
	var hasta: Vector2 = _hasta_de_tiron(tr, desde)
	# La pared (o el borde de la arena) lo para, igual que en _tick_tirones.
	var dentro: Rect2 = _dentro(_arena())
	var pasos: int = maxi(1, ceili(desde.distance_to(hasta) / 4.0))
	var fin: Vector2 = desde
	for k in range(1, pasos + 1):
		var p: Vector2 = desde.lerp(hasta, float(k) / float(pasos))
		if not _sobre_suelo(p, cuerpo) or (dentro.has_area() and not dentro.has_point(p)):
			break
		fin = p
	if fin.distance_to(desde) > 1.0:
		pedir_desliz(c, fin, Desliz.EMPUJON, 1, T_TIRON)
	return true


func _on_golpe_encajado(b: Dictionary, _dur: float) -> void:
	for tr in _tirones:
		if float(tr["t"]) < 0.0 and is_same(_pantalla._bloque_de(tr["c"]), b):
			_arrancar_tiron(tr)
	# El empujon a un personaje de otro humano: sale con SU golpe, en todas las maquinas (lo mueve la suya).
	for d in _deslices:
		if int(d["modo"]) == Desliz.EMPUJON and not bool(d["armado"]) and is_same(_pantalla._bloque_de(d["c"]), b):
			d["armado"] = true
			d["espera"] = 0.0
			d["tope"] = 0.0


# LA SANGRE DEL HACHA (24/09): cada golpe de hacha que ENTRA salpica desde el cuerpo que lo encaja, hacia
# donde va el tajo: los barridos de lado (el Brutal hacia su giro, la Carniceria alternando), la Hendedura
# hacia fuera y el Desgarro hacia quien tira, dejando ademas el surco del arrastre. En todas las maquinas.
const _SANGRA := [CombatFX.Estilo.HACHA_TAJO, CombatFX.Estilo.HENDEDURA, CombatFX.Estilo.HACHAZO_BRUTAL,
	CombatFX.Estilo.CARNICERIA, CombatFX.Estilo.DESGARRO,
	# La DAGA (24/09): poca, de los tajos; la Puñalada, un chorro por detras (por donde asoma la punta).
	CombatFX.Estilo.DAGA_CORTE, CombatFX.Estilo.DAGA_RAFAGA, CombatFX.Estilo.PUNALADA,
	# La ESPADA CORTA (25/09): entre la daga y el hacha.
	CombatFX.Estilo.ESPADA_TAJO, CombatFX.Estilo.TAJO_QUEBRANTADOR, CombatFX.Estilo.DOBLE_TAJO,
	CombatFX.Estilo.CAMBIO_RITMO, CombatFX.Estilo.SENALAR_HUECO, CombatFX.Estilo.CORTE_TENDONES,
	# La ESPADA LARGA (25/09): como la corta, algo mas en el Tajo pesado. El escudazo no corta.
	CombatFX.Estilo.ESPADA_LARGA_TAJO, CombatFX.Estilo.TAJO_PESADO, CombatFX.Estilo.TAJO_DESARMANTE,
	CombatFX.Estilo.GUARDIA_ROTA, CombatFX.Estilo.ESTOCADA_MARCIAL,
	# La RATA (28/09): el Mordisco sangrante y el Frenesi (el basico, no: muerde, pero no es el que sangra).
	CombatFX.Estilo.BESTIA_MORDISCO_SANGRA, CombatFX.Estilo.BESTIA_FRENESI]

func _on_impacto(ev: Dictionary) -> void:
	# LA GOTA DEL BROTE cae sobre su cria: se levanta. De enemigo a enemigo no pega nadie mas.
	if _pantalla.tactico:
		var va: Combatant = _de_bloque(ev["bv"])
		var aa: Combatant = _de_bloque(ev["ba"])
		if va != null and aa != null and va != aa and _pantalla._enemies.has(va) and _pantalla._enemies.has(aa):
			if _por_nacer.has(va) or _pantalla._espejo:
				_nacer_cria(va)
				return
	var estilo: int = int(ev.get("estilo", 0))
	if not _pantalla.tactico or estilo not in _SANGRA:
		return
	var v: Combatant = _de_bloque(ev["bv"])
	var cuerpo: Node2D = cuerpo_de(v)
	var arena: ArenaCombate = _arena()
	if cuerpo == null or arena == null:
		return
	var a: Combatant = _de_bloque(ev["ba"])
	var r: Rect2 = bulto_de(v)
	var pies_v: Vector2 = pies_de(v)
	var desde: Vector2 = r.get_center() if r.has_area() else pies_v + Vector2(0.0, -12.0)
	var radial: Vector2 = (pies_v - pies_de(a)).normalized() if a != null and cuerpo_de(a) != null else Vector2.RIGHT
	var dir: Vector2 = radial.rotated(PI * 0.5) * 0.85 + radial * 0.45
	var fuerza: float = clampf(float(ev.get("peso", 1.0)), 0.3, 1.5) * (1.35 if bool(ev.get("crit", false)) else 1.0)
	match estilo:
		CombatFX.Estilo.HACHAZO_BRUTAL:
			fuerza *= 1.4
		CombatFX.Estilo.CARNICERIA:
			var lado: float = 1.0 if int(ev.get("pos_tanda", 0)) % 2 == 0 else -1.0
			dir = radial.rotated(PI * 0.5 * lado) * 0.85 + radial * 0.45
			fuerza *= 0.8
		CombatFX.Estilo.HENDEDURA:
			dir = radial
		CombatFX.Estilo.DESGARRO:
			dir = -radial
			SangreMapa.surco(arena, cuerpo, pies_v - cuerpo.global_position)
		CombatFX.Estilo.HACHA_TAJO:
			fuerza *= 0.6
		CombatFX.Estilo.BESTIA_MORDISCO_SANGRA:
			fuerza *= 0.7
		CombatFX.Estilo.BESTIA_FRENESI:
			fuerza *= 0.4
		CombatFX.Estilo.DAGA_CORTE, CombatFX.Estilo.DAGA_RAFAGA:
			fuerza *= 0.35
		CombatFX.Estilo.PUNALADA:
			dir = radial
			fuerza *= 0.8
		CombatFX.Estilo.CORTE_TENDONES:
			desde = Vector2(desde.x, lerpf(desde.y, pies_v.y, 0.6))   # sale de las piernas
			fuerza *= 0.7
		CombatFX.Estilo.ESPADA_TAJO, CombatFX.Estilo.DOBLE_TAJO, CombatFX.Estilo.CAMBIO_RITMO, \
				CombatFX.Estilo.SENALAR_HUECO, CombatFX.Estilo.TAJO_QUEBRANTADOR, \
				CombatFX.Estilo.ESPADA_LARGA_TAJO, CombatFX.Estilo.TAJO_DESARMANTE, CombatFX.Estilo.GUARDIA_ROTA:
			fuerza *= 0.55
		CombatFX.Estilo.TAJO_PESADO:
			dir = radial   # de arriba abajo: sale hacia delante, como la Hendedura
			fuerza *= 0.9
		CombatFX.Estilo.ESTOCADA_MARCIAL:
			dir = radial
			fuerza *= 0.6
	SangreMapa.salpicar(arena, desde, pies_v, dir, fuerza, int(ev.get("semilla", 1)))


# LA ESQUIVA SE VE (24/09, para TODOS, lo pidio el): quien esquiva un golpe se aparta de lado y vuelve,
# dejando su eco (EstoqueAire.Modo.ESQUIVA). Se mueve solo el DIBUJO (el muñeco de los tuyos, el sprite de
# un enemigo), no su sitio en la pelea. Si esquivaba En guardia, ademas la parada en la hoja. En todas las
# maquinas: el espejo recibe los mismos golpes (y la marca de guardia, ver efectos._fx_golpe).
func _on_esquiva(ev: Dictionary) -> void:
	var arena: ArenaCombate = _arena()
	if arena == null or not _pantalla.tactico:
		return
	var v: Combatant = _de_bloque(ev["bv"])
	var a: Combatant = _de_bloque(ev["ba"])
	var cuerpo: Node2D = cuerpo_de(v)
	if v == null or cuerpo == null or v == a:
		return
	var dibujo: Node2D = cuerpo.get("_muneco") if cuerpo.get("_muneco") is Node2D else cuerpo.get("_sprite")
	var hacia: Vector2 = pies_de(a) - pies_de(v) if a != null and cuerpo_de(a) != null else Vector2.RIGHT
	var ritmo: float = _pantalla._fx.escala_tiempo if _pantalla._fx != null else 1.0
	EstoqueAire.postura(arena, EstoqueAire.Modo.ESQUIVA, dibujo, pies_de(v), hacia,
		int(ev.get("semilla", 1)) | 1, 0.0, ritmo, Vector2.INF, bool(ev.get("guardia", false)), bulto_de(v))


# LA DEFENSA SOLO CUBRE POR DELANTE (24/09, decision suya: media vuelta, 180º). Vale para el Defender (y
# con el el bloqueo del escudo y la parada de la rodela) y para lo que reduce En guardia; la esquiva extra
# de En guardia sigue valiendo por todos lados. El Defender se FIJA hacia donde miras al pulsarlo; lo
# demas mira hacia donde mira el cuerpo en el golpe. Lo pregunta quien resuelve (combat_enemigos).
var _frente_defensa: Dictionary = {}   # Combatant -> hacia donde miraba al Defender

func fijar_frente_defensa(c: Combatant) -> void:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo != null:
		_frente_defensa[c] = _mirada_de(cuerpo)


func cubre_de_frente(c: Combatant, atacante: Combatant) -> bool:
	if not _pantalla.tactico or c == null or atacante == null:
		return true
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null or cuerpo_de(atacante) == null:
		return true
	var mira: Vector2 = _frente_defensa.get(c, _mirada_de(cuerpo))
	var hacia: Vector2 = pies_de(atacante) - pies_de(c)
	if hacia.length_squared() < 0.01 or mira.length_squared() < 0.01:
		return true
	return mira.normalized().dot(hacia.normalized()) >= 0.0


const _MODO_ESTOQUE := {
	CombatFX.Estilo.ESTOQUE_PUNZADA: EstoqueAire.Modo.PUNZADA,
	CombatFX.Estilo.PASO_LIGERO: EstoqueAire.Modo.PUNZADA,
	CombatFX.Estilo.ESTOCADA_PENETRANTE: EstoqueAire.Modo.PENETRANTE,
	CombatFX.Estilo.FINTAS: EstoqueAire.Modo.FINTA,
	CombatFX.Estilo.PUNZADA_NERVIO: EstoqueAire.Modo.NERVIO,
	CombatFX.Estilo.DANZA_ACERO: EstoqueAire.Modo.DANZA,
	# La Estocada marcial de la espada larga: la punta limpia que atraviesa, como la penetrante.
	CombatFX.Estilo.ESTOCADA_MARCIAL: EstoqueAire.Modo.PENETRANTE,
}

# LAS DE APOYO de la espada larga y el escudo (ApoyoAire), lo de cada cuerpo. -1 = nada en el cuerpo.
const _MODO_APOYO := {
	CombatFX.Estilo.VOTO_GUARDIA: -1, CombatFX.Estilo.PROVOCACION_FX: -1,
	CombatFX.Estilo.VOZ_MANDO: ApoyoAire.Modo.PRESTEZA, CombatFX.Estilo.COBERTURA: ApoyoAire.Modo.AMPARO_C,
	CombatFX.Estilo.ESCOLTA_FX: ApoyoAire.Modo.ESCOLTA, CombatFX.Estilo.MURO_GUARDIAN: ApoyoAire.Modo.MURO,
	CombatFX.Estilo.GUARDIA_CARNE_FX: ApoyoAire.Modo.CARNE, CombatFX.Estilo.POSTURA_RODELA: ApoyoAire.Modo.RODELA,
}

const _MODO_ESPADA := {
	CombatFX.Estilo.ESPADA_TAJO: EspadaAire.Modo.TAJO,
	CombatFX.Estilo.TAJO_QUEBRANTADOR: EspadaAire.Modo.QUEBRANTADOR,
	CombatFX.Estilo.DOBLE_TAJO: EspadaAire.Modo.DOBLE,
	CombatFX.Estilo.CAMBIO_RITMO: EspadaAire.Modo.RITMO,
	CombatFX.Estilo.SENALAR_HUECO: EspadaAire.Modo.SENALAR,
	CombatFX.Estilo.CORTE_TENDONES: EspadaAire.Modo.TENDONES,
	# LA ESPADA LARGA (25/09): la pincelada de siempre en el basico, casi vertical en el Tajo pesado, al brazo con
	# choque de acero en el Desarmante y la guardia en pedazos en el tajo de la Guardia rota.
	CombatFX.Estilo.ESPADA_LARGA_TAJO: EspadaAire.Modo.TAJO,
	CombatFX.Estilo.TAJO_PESADO: EspadaAire.Modo.PESADO_C,
	CombatFX.Estilo.TAJO_DESARMANTE: EspadaAire.Modo.DESARME,
	CombatFX.Estilo.GUARDIA_ROTA: EspadaAire.Modo.QUEBRANTADOR,
}

# LA MAZA PEQUEÑA (MazaAire, 25/09), lo de cada cuerpo. El Demoledor y el mazazo del Aplastamiento no pintan nada
# en los cuerpos (un solo golpe al suelo, como el Golpe sismico). Las de apoyo, en cada uno de los tuyos.
const _MODO_MAZA := {
	CombatFX.Estilo.MAZA_GOLPE: MazaAire.Modo.PORRAZO,
	CombatFX.Estilo.CULATAZO: MazaAire.Modo.CULATAZO,
	CombatFX.Estilo.ROMPEPIERNAS: MazaAire.Modo.ROMPE_C,
	CombatFX.Estilo.GRITO_ALIENTO: MazaAire.Modo.ALIENTO_C,
	CombatFX.Estilo.MURO_ALIADOS: MazaAire.Modo.MURO_C,
}

# EL BASTON Y LA VARITA (BastonAire, 26/09), lo de cada cuerpo.
const _MODO_BASTON := {
	CombatFX.Estilo.BASTON_GOLPE: BastonAire.Modo.GOLPE,
	CombatFX.Estilo.BASTONAZO: BastonAire.Modo.BASTONAZO_C,
	CombatFX.Estilo.VIENTO_LIMPIO: BastonAire.Modo.VIENTO_C,
	CombatFX.Estilo.FOCO_ARCANO: BastonAire.Modo.FOCO,
	CombatFX.Estilo.VELO_UMBRIO: BastonAire.Modo.VELO,
	CombatFX.Estilo.PURIFICAR: BastonAire.Modo.PURIFICAR,
	CombatFX.Estilo.CHISPA_VINCULADA: BastonAire.Modo.CHISPA,
	CombatFX.Estilo.EGIDA_MENOR: BastonAire.Modo.EGIDA,
}

# EL DIBUJO DE UN GOLPE DE DAGA (o de estoque), sobre el cuerpo de verdad (CombatFX.dibujo_en_mapa). En todas las
# maquinas, esquivado o no. 'vuelo' = lo que falta para el golpe, en tiempo de la pelea.
const _MODO_SLIME := {CombatFX.Estilo.SLIME_GOLPE: SlimeAire.Modo.GOLPE, CombatFX.Estilo.SLIME_ESCUPE: SlimeAire.Modo.ESCUPE,
	CombatFX.Estilo.SLIME_TROMBA: SlimeAire.Modo.TROMBA, CombatFX.Estilo.SLIME_TROZO: SlimeAire.Modo.TROZO,
	CombatFX.Estilo.SLIME_IGNICION: SlimeAire.Modo.IGNICION}
const _MODO_BESTIA := {CombatFX.Estilo.BESTIA_MORDISCO: BestiaAire.Modo.MORDISCO,
	CombatFX.Estilo.BESTIA_MORDISCO_SANGRA: BestiaAire.Modo.MORDISCO_SANGRA, CombatFX.Estilo.BESTIA_FRENESI: BestiaAire.Modo.FRENESI}

func _on_dibujo_mapa(ev: Dictionary, vuelo: float) -> void:
	var arena: ArenaCombate = _arena()
	if arena == null or not _pantalla.tactico:
		return
	var v: Combatant = _de_bloque(ev["bv"])
	var a: Combatant = _de_bloque(ev["ba"])
	if v == null or cuerpo_de(v) == null:
		return
	var estilo: int = int(ev.get("estilo", 0))
	var ritmo: float = _pantalla._fx.escala_tiempo if _pantalla._fx != null else 1.0
	var semilla: int = (int(ev.get("semilla", 1)) ^ (int(ev.get("pos_tanda", 0)) * 7919)) | 1
	if estilo == CombatFX.Estilo.IMBUIR_FILO:
		DagaAire.ponzona(arena, cuerpo_de(v).get("_muneco"), semilla, vuelo, ritmo)
		return
	# LOS SLIMES (SlimeAire, 28/09): del cuerpo del slime (un poco por encima de su centro: la boca) al que recibe.
	if estilo in _MODO_SLIME:
		var desde_s: Vector2 = bulto_de(a).get_center() - Vector2(0.0, bulto_de(a).size.y * 0.15) 			if a != null and cuerpo_de(a) != null else bulto_de(v).get_center() - Vector2(30.0, 0.0)
		SlimeAire.sobre_cuerpo(arena, int(_MODO_SLIME[estilo]), desde_s, bulto_de(v), ev.get("color", Color.WHITE),
			semilla, vuelo, ritmo)
		return
	# LAS BESTIAS (BestiaAire, 28/09): las mandibulas de la rata, de quien muerde al que recibe.
	if estilo in _MODO_BESTIA:
		var desde_b: Vector2 = bulto_de(a).get_center() if a != null and cuerpo_de(a) != null else bulto_de(v).get_center() - Vector2(30.0, 0.0)
		BestiaAire.sobre_cuerpo(arena, int(_MODO_BESTIA[estilo]), desde_b, bulto_de(v), semilla, vuelo, ritmo,
			bulto_de(a).size.x if a != null and cuerpo_de(a) != null else -1.0)
		return
	# EL ARCO de una cadena (MagiaAire): del pecho del ultimo tocado (o de quien lo lanza) al pecho de este.
	if estilo == CombatFX.Estilo.ARCO:
		var caja_v: Rect2 = bulto_de(v)
		var desde_a: Vector2 = bulto_de(a).get_center() if a != null and cuerpo_de(a) != null 			else caja_v.get_center() - Vector2(30.0, 0.0)
		var elem_a: int = int(ev.get("elem", Elementos.Elemento.RAYO))
		var col_a: Color = Elementos.color(elem_a) if Elementos.tiene_color(elem_a) else MagiaAire.RAYO
		MagiaAire.arco(arena, desde_a, caja_v.get_center(), col_a, semilla, vuelo, ritmo)
		return
	# LAS MAGIAS SIN GOLPE (MagiaAire): la maldicion sobre el enemigo, la fortaleza sobre el tuyo y el filo que
	# viaja del pecho de quien lo lanza al de quien lo recibe (con el color de su elemento).
	if estilo == CombatFX.Estilo.MALDICION or estilo == CombatFX.Estilo.FORTALECER:
		MagiaAire.sobre_cuerpo(arena, MagiaAire.Modo.MALDICION if estilo == CombatFX.Estilo.MALDICION
			else MagiaAire.Modo.FORTALECER, bulto_de(v), Color.WHITE, semilla, vuelo, ritmo)
		return
	if estilo == CombatFX.Estilo.IMBUIR_ELEM or estilo == CombatFX.Estilo.IMBUIR_CUERPO:
		var el_i: int = int(ev.get("elem", 0))
		var col_i: Color = Elementos.color(el_i) if Elementos.tiene_color(el_i) else MagiaAire.ARCANO
		var desde_i: Vector2 = bulto_de(a).get_center() if a != null and cuerpo_de(a) != null else bulto_de(v).get_center()
		MagiaAire.filo(arena, desde_i, bulto_de(v), col_i, semilla, vuelo, ritmo, el_i,
			estilo == CombatFX.Estilo.IMBUIR_CUERPO)
		return
	# EL CHORRO DE PETALOS del Manto prismatico (MagiaMayor): del pecho de quien lo lanza al que lo recibe.
	if estilo == CombatFX.Estilo.IMBUIR_PRISMA:
		var desde_p: Vector2 = bulto_de(a).get_center() if a != null and cuerpo_de(a) != null else bulto_de(v).get_center()
		MagiaMayor.petalos_prisma(arena, desde_p, bulto_de(v), semilla, vuelo, ritmo)
		return
	# EL RAYO DE LA TORMENTA (MagiaMayor): del borde del ojo a sus pies.
	if estilo == CombatFX.Estilo.TORMENTA_RAYO:
		MagiaMayor.rayo_tormenta(arena, bulto_de(v), semilla, vuelo, ritmo)
		return
	# LA COLUMNA DE LUZ de la cura de grupo (MagiaMayor) sobre cada uno de los tuyos.
	if estilo == CombatFX.Estilo.CURA_GRUPO:
		MagiaMayor.columna_luz(arena, bulto_de(v), semilla, vuelo, ritmo)
		return
	# EL VENDAJE DE LUZ sobre el aliado (MagiaAire.cura).
	if estilo == CombatFX.Estilo.CURACION_LUZ:
		MagiaAire.cura(arena, bulto_de(v), semilla, vuelo, ritmo)
		return
	# EL DEFENDER no pinta nada: lo que se ve es su postura (el gesto, ver gesto_en_mapa).
	if estilo == CombatFX.Estilo.DEFENSA:
		return
	# EN GUARDIA (sobre ti): el destello por la hoja y la postura en el suelo, mirando al enemigo mas cercano.
	if estilo == CombatFX.Estilo.EN_GUARDIA:
		var mas_cerca: Combatant = null
		var d_min: float = INF
		for e in _pantalla._vivos():
			var d_e: float = pies_de(e).distance_squared_to(pies_de(v))
			if d_e < d_min:
				d_min = d_e
				mas_cerca = e
		var hacia_g: Vector2 = (pies_de(mas_cerca) - pies_de(v)) if mas_cerca != null else Vector2.RIGHT
		EstoqueAire.postura(arena, EstoqueAire.Modo.GUARDIA, cuerpo_de(v).get("_muneco"), pies_de(v), hacia_g,
			semilla, vuelo, ritmo)
		return
	# EL ESTOQUE: todo de punta (EstoqueAire), desde la altura del pecho del que pega.
	if estilo in _MODO_ESTOQUE:
		var caja_e: Rect2 = bulto_de(v)
		var desde_e: Vector2 = pies_de(a) + Vector2(0.0, -EstoqueAire.ALTO_TORSO) \
			if a != null and cuerpo_de(a) != null else caja_e.get_center() - Vector2(20.0, 0.0)
		var modo_e: int = int(_MODO_ESTOQUE[estilo])
		# LAS FINTAS: el amago solo en la primera; las demas son estocadas a secas.
		if modo_e == EstoqueAire.Modo.FINTA and int(ev.get("pos_tanda", 0)) > 0:
			modo_e = EstoqueAire.Modo.PUNZADA
		EstoqueAire.golpe(arena, modo_e, desde_e, caja_e, bool(ev.get("evadido", false)),
			bool(ev.get("crit", false)), int(ev.get("pos_tanda", 0)), semilla, vuelo, ritmo)
		return
	# LAS DE APOYO (ApoyoAire): lo de la huella ya ha salido por el suelo; aqui lo de cada cuerpo.
	if estilo in _MODO_APOYO:
		var m_ap: int = int(_MODO_APOYO[estilo])
		if m_ap < 0:
			return   # el Voto y la Provocacion: todo lo suyo esta en el suelo
		var desde_ap: Vector2 = pies_de(a) + Vector2(0.0, -ApoyoAire.ALTO_TORSO) \
			if a != null and cuerpo_de(a) != null else bulto_de(v).get_center()
		var hacia_ap := Vector2.ZERO
		if m_ap == ApoyoAire.Modo.MURO or m_ap == ApoyoAire.Modo.RODELA:
			var mas_cerca_ap: Combatant = null
			var d_ap: float = INF
			for e in _pantalla._vivos():
				var de: float = pies_de(e).distance_squared_to(pies_de(v))
				if de < d_ap:
					d_ap = de
					mas_cerca_ap = e
			hacia_ap = (pies_de(mas_cerca_ap) - pies_de(v)) if mas_cerca_ap != null else Vector2.RIGHT
		ApoyoAire.cuerpo(arena, m_ap, desde_ap, bulto_de(v), semilla, vuelo, ritmo, hacia_ap)
		return
	# EL ESCUDAZO (EscudoAire): el impacto en el cuerpo. La CHAPA sale una vez: en el Golpe de escudo la pinta su
	# onda (el golpe 0 con suelo); en el escudazo suelto (Guardia rota, que va detras del tajo, y el contraataque
	# de la rodela, sin suelo) la pinta este, delante de quien pega.
	if estilo == CombatFX.Estilo.ESCUDAZO or estilo == CombatFX.Estilo.EMBESTIDA_ESCUDO:
		var caja_z: Rect2 = bulto_de(v)
		var desde_z: Vector2 = pies_de(a) + Vector2(0.0, -EscudoAire.ALTO_TORSO) \
			if a != null and cuerpo_de(a) != null else caja_z.get_center() - Vector2(20.0, 0.0)
		var suelta: bool = float(ev.get("retraso_suelo", -1.0)) < 0.0 or int(ev.get("pos_tanda", 0)) > 0
		var modo_z: int = EscudoAire.Modo.EMBESTIDA if estilo == CombatFX.Estilo.EMBESTIDA_ESCUDO \
			else EscudoAire.Modo.ESCUDAZO
		EscudoAire.golpe(arena, modo_z, desde_z, caja_z, bool(ev.get("evadido", false)),
			bool(ev.get("crit", false)), int(ev.get("pos_tanda", 0)), semilla, vuelo, ritmo, suelta)
		return
	# EL BASTON Y LA VARITA (BastonAire): desde el pecho del que la lanza. La Egida mira a su enemigo mas cercano;
	# el Foco de la varita, mas pequeño que el del baston.
	if estilo in _MODO_BASTON:
		var m_b: int = int(_MODO_BASTON[estilo])
		var caja_b: Rect2 = bulto_de(v)
		var desde_b: Vector2 = pies_de(a) + Vector2(0.0, -BastonAire.ALTO_TORSO) 			if a != null and cuerpo_de(a) != null else caja_b.get_center() - Vector2(20.0, 0.0)
		var hacia_b := Vector2.ZERO
		if m_b == BastonAire.Modo.EGIDA:
			var mas_cerca_b: Combatant = null
			var d_b: float = INF
			for e in _pantalla._vivos():
				var de_b: float = pies_de(e).distance_squared_to(pies_de(v))
				if de_b < d_b:
					d_b = de_b
					mas_cerca_b = e
			hacia_b = (pies_de(mas_cerca_b) - pies_de(v)) if mas_cerca_b != null else Vector2.RIGHT
		var esc_b: float = 1.0
		if m_b == BastonAire.Modo.FOCO:
			var pj_b: PersonajeData = Game.pj_de_combatant(v)
			if pj_b != null and not (pj_b.equipped_main is WeaponData and int(pj_b.equipped_main.tipo) == WeaponData.Tipo.BASTON):
				esc_b = 0.7
		BastonAire.golpe(arena, m_b, desde_b, caja_b, bool(ev.get("evadido", false)), bool(ev.get("crit", false)),
			int(ev.get("pos_tanda", 0)), semilla, vuelo, ritmo, hacia_b, esc_b)
		return
	# LA MAZA: porrazos (MazaAire), desde la altura del pecho del que pega (o del que la lanza, en las de apoyo).
	if estilo in _MODO_MAZA:
		var caja_m: Rect2 = bulto_de(v)
		var desde_m: Vector2 = pies_de(a) + Vector2(0.0, -MazaAire.ALTO_TORSO) 			if a != null and cuerpo_de(a) != null else caja_m.get_center() - Vector2(20.0, 0.0)
		MazaAire.golpe(arena, int(_MODO_MAZA[estilo]), desde_m, caja_m, bool(ev.get("evadido", false)),
			bool(ev.get("crit", false)), int(ev.get("pos_tanda", 0)), semilla, vuelo, ritmo)
		return
	# LA ESPADA CORTA: tajos con cuerpo (EspadaAire), desde la altura del pecho del que pega.
	if estilo in _MODO_ESPADA:
		var caja_s: Rect2 = bulto_de(v)
		var desde_s: Vector2 = pies_de(a) + Vector2(0.0, -EspadaAire.ALTO_TORSO) \
			if a != null and cuerpo_de(a) != null else caja_s.get_center() - Vector2(20.0, 0.0)
		EspadaAire.golpe(arena, int(_MODO_ESPADA[estilo]), desde_s, caja_s, bool(ev.get("evadido", false)),
			bool(ev.get("crit", false)), int(ev.get("pos_tanda", 0)), semilla, vuelo, ritmo)
		return
	var modo: int = DagaAire.Modo.TAJO
	if estilo == CombatFX.Estilo.DAGA_RAFAGA:
		modo = DagaAire.Modo.RAFAGA
	elif estilo == CombatFX.Estilo.PUNALADA:
		modo = DagaAire.Modo.PUNALADA
	var caja: Rect2 = bulto_de(v)
	# De donde viene: la altura del pecho del que pega (sin el, desde su lado del cuerpo).
	var desde: Vector2 = pies_de(a) + Vector2(0.0, -DagaAire.ALTO_TORSO) if a != null and cuerpo_de(a) != null \
		else caja.get_center() - Vector2(20.0, 0.0)
	DagaAire.golpe(arena, modo, desde, caja, bool(ev.get("evadido", false)), bool(ev.get("crit", false)),
		int(ev.get("pos_tanda", 0)), semilla, vuelo, ritmo)


# El combatiente de un bloque de la pelea (aliado o enemigo). null si no es de nadie.
func _de_bloque(b) -> Combatant:
	if not b is Dictionary:
		return null
	for c in _pantalla._enemies:
		if is_same(_pantalla._bloque_de(c), b):
			return c
	for c in _pantalla._aliados:
		if is_same(_pantalla._bloque_de(c), b):
			return c
	return null


# Hasta donde se acercan al centro los que atrae un pozo: no se amontonan todos en el mismo pixel.
const HUECO_ATRAE := 12.0

func _arrancar_tiron(tr: Dictionary) -> void:
	var c: Combatant = tr["c"]
	var cuerpo: Node2D = cuerpo_de(c)
	tr["t"] = 0.0
	tr["desde"] = Vector2.ZERO
	tr["hasta"] = Vector2.ZERO
	if cuerpo == null or not c.is_alive() or cuerpo_de(tr["de"]) == null:
		return
	var desde: Vector2 = cuerpo.global_position
	tr["desde"] = desde
	tr["hasta"] = _hasta_de_tiron(tr, desde)


# Adonde lleva un tiron a 'c', saliendo de 'desde' (su nodo). La pared no se mira aqui.
func _hasta_de_tiron(tr: Dictionary, desde: Vector2) -> Vector2:
	var c: Combatant = tr["c"]
	# UN DESPLAZAMIENTO YA DECIDIDO (apartar a un lado, pedir_apartar).
	if tr.has("desplaza"):
		return desde + Vector2(tr["desplaza"])
	# HACIA UN PUNTO (la Vorágine): sus pies van hacia el, sin pasarse (se quedan a HUECO_ATRAE del centro).
	if tr.has("hacia"):
		var pies: Vector2 = pies_de(c)
		var hacia: Vector2 = tr["hacia"]
		var largo_a: float = minf(float(tr["px"]), maxf(0.0, pies.distance_to(hacia) - HUECO_ATRAE))
		return desde + (hacia - pies).normalized() * largo_a
	# NEGATIVO = EMPUJON (la Embestida, la Marea): se aleja de quien golpea. La pared lo para (_tick_tirones).
	if float(tr["px"]) < 0.0:
		return desde + (desde - pos_de(tr["de"])).normalized() * -float(tr["px"])
	var largo: float = minf(float(tr["px"]), maxf(0.0, hueco_entre(tr["de"], c) - ALCANCE_MINIMO))
	return desde + (pos_de(tr["de"]) - desde).normalized() * largo


func _tick_tirones(delta: float) -> void:
	if _tirones.is_empty():
		return
	var dentro: Rect2 = _dentro(_arena())
	for tr in _tirones.duplicate():
		if float(tr["t"]) < 0.0:
			tr["espera"] = float(tr["espera"]) + delta
			if float(tr["espera"]) >= T_TIRON_ESPERA:
				_arrancar_tiron(tr)
			continue
		var c: Combatant = tr["c"]
		var cuerpo: Node2D = cuerpo_de(c)
		var desde: Vector2 = tr["desde"]
		var hasta: Vector2 = tr["hasta"]
		if cuerpo == null or not c.is_alive() or desde.is_equal_approx(hasta):
			_tirones.erase(tr)
			continue
		tr["t"] = float(tr["t"]) + delta * _pantalla._vel_pelea
		var u: float = clampf(float(tr["t"]) / T_TIRON, 0.0, 1.0)
		# Arranca de golpe y frena al llegar: es un tiron, no un paseo.
		var p: Vector2 = desde.lerp(hasta, 1.0 - (1.0 - u) * (1.0 - u))
		if not _sobre_suelo(p, cuerpo) or (dentro.has_area() and not dentro.has_point(p)):
			_tirones.erase(tr)
			continue
		_colocar(c, cuerpo, p)
		_apuntar_bicho(cuerpo, false)
		if u >= 1.0:
			_tirones.erase(tr)
	_enviar_bichos()


# ------------------------------------------------------------
#  EL SALTO A LA ESPALDA (Oportunista de la daga, 24/09)
# ------------------------------------------------------------
# El que lo hace APARECE detras del enemigo, del otro lado de 'desde' (el mismo, con la habilidad; el
# compañero que acaba de pegarle, al entrar detras). El SITIO lo decide quien lleva la pelea con sus
# posiciones y viaja al espejo en el paquete de impactos, delante de los golpes (espejo._apuntar_salto_red).
# Cada maquina lo hace cuando ARRANCA su gesto de golpear (CombatFX.gesto_iniciado): primero aparece,
# despues apuñala. Solo mueve el cuerpo quien lo mueve siempre (_es_mio); quien lleva la pelea apunta
# ademas el sitio en _pos, que es donde la pelea cuenta que esta el personaje de otro humano.
const T_SALTO_ESPERA := 3.0   # si el gesto no llega a verse (sin capa de efectos), se hace igual
const HUECO_ESPALDA := 2.0
const SEPARA_ESPALDAS := 16.0   # lo minimo entre dos que aparecen a la espalda (un cuerpo de ancho)
var _saltos: Array = []   # {c, hasta (el nodo), hacia (los pies del enemigo), espera}

func pedir_salto(c: Combatant, victima: Combatant, desde: Combatant) -> void:
	if _pantalla._espejo or not _pantalla.tactico or c == null or victima == null:
		return
	var p = sitio_a_la_espalda(c, victima, desde)
	if p == null:
		return
	var hacia: Vector2 = pies_de(victima)
	if not _es_mio(c):
		_pos[c] = p
	_pantalla.espejo._apuntar_salto_red(c, p, victima)
	anotar_salto(c, p, hacia)


# Tambien en el espejo, al leer el paquete de impactos.
func anotar_salto(c: Combatant, hasta: Vector2, hacia: Vector2) -> void:
	if c == null:
		return
	_saltos.append({"c": c, "hasta": hasta, "hacia": hacia, "espera": 0.0})


# DONDE SE PONE (el nodo, no los pies), o null si no hay sitio. Pegado al enemigo por detras: sus pies, mas
# lo que pisa el enemigo y medio de lo que pisa el que salta. Si detras hay pared o se sale de la arena,
# prueba a los lados, cada vez mas abiertos hacia el frente.
func sitio_a_la_espalda(c: Combatant, victima: Combatant, desde: Combatant):
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null or cuerpo_de(victima) == null:
		return null
	var pv: Vector2 = pies_de(victima)
	var dir: Vector2 = pv - pies_de(desde if desde != null else c)
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var largo: float = maxf(radio_pisa(victima), 8.0) + radio_pisa(c) * 0.5 + HUECO_ESPALDA
	return _sitio_en_abanico(c, pv, dir, largo, false)


# EL SITIO junto a 'pv' (unos pies) en la direccion 'dir' a 'largo' px, o null. Si no cabe, abre en abanico
# (cada vez mas a los lados) y, si se llena, un palmo mas lejos. 'sin_pisar' = ademas no puede quedar encima
# de NADIE (enemigos incluidos): el Muro se pone entre los suyos y el enemigo, no dentro de el.
func _sitio_en_abanico(c: Combatant, pv: Vector2, dir: Vector2, largo: float, sin_pisar: bool):
	var cuerpo: Node2D = cuerpo_de(c)
	var dentro: Rect2 = _dentro(_arena())
	# VARIOS A LA ESPALDA DEL MISMO (lo vio el jefe: dos con Oportunista caian uno encima del otro). Los
	# sitios ya cogidos -- los cuerpos de los tuyos y los saltos que aun no se han hecho -- no valen: se
	# abre en ABANICO detras del enemigo (cada vez mas a los lados) y, si se llena, un palmo mas atras.
	var ocupados: Array = []
	for al in _pantalla._aliados:
		if al != c and al.is_alive() and cuerpo_de(al) != null:
			ocupados.append(pos_de(al))
	for sp in _saltos:
		if sp["c"] != c:
			ocupados.append(sp["hasta"])
	for anillo in 3:
		var r: float = largo + float(anillo) * SEPARA_ESPALDAS
		for giro in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.0, -2.0]:
			var nodo: Vector2 = pv + dir.rotated(float(giro) * PI * 0.25) * r \
				- Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
			if not _sobre_suelo(nodo, cuerpo) or (dentro.has_area() and not dentro.has_point(nodo)):
				continue
			if sin_pisar and _hay_otro_en(c, nodo):
				continue
			var libre: bool = true
			for o in ocupados:
				if nodo.distance_to(o) < SEPARA_ESPALDAS:
					libre = false
					break
			if libre:
				return nodo
	return null


func _on_gesto_salto(b: Dictionary, _dir: int, _dur: float, _anim: StringName, _mano: int = -1) -> void:
	if _saltos.is_empty():
		return
	var c: Combatant = _de_bloque(b)
	for s in _saltos:
		if s["c"] == c:
			_hacer_salto(s)
			return


func _hacer_salto(s: Dictionary) -> void:
	_saltos.erase(s)
	var c: Combatant = s["c"]
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null or not c.is_alive():
		return
	# LA SOMBRA se ve en todas las pantallas; el cuerpo solo lo mueve quien lo mueve siempre.
	var arena: ArenaCombate = _arena()
	if arena != null:
		var bajo := Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
		DagaAire.sombra(arena, cuerpo.global_position + bajo, Vector2(s["hasta"]) + bajo,
			int(Vector2(s["hasta"]).x * 31.0) | 1, _pantalla._fx.escala_tiempo if _pantalla._fx != null else 1.0)
	if not _es_mio(c):
		return
	_colocar(c, cuerpo, s["hasta"])
	# Mirando al enemigo: el gesto que arranca ahora mismo lee esta mirada (ver gesto_en_mapa).
	_animar(cuerpo, Vector2(s["hacia"]) - Vector2(s["hasta"]) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO), false)
	# El circulo de andar de su turno ya no vale: se quedaria pintado donde estaba.
	if _quien == c and _fase == Fase.MOVIENDO:
		_inicio = cuerpo.global_position


func _tick_saltos(delta: float) -> void:
	for s in _saltos.duplicate():
		s["espera"] = float(s["espera"]) + delta
		if float(s["espera"]) >= T_SALTO_ESPERA:
			_hacer_salto(s)


# ------------------------------------------------------------
#  EL PASO Y EL AVANCE (estoque, 24/09)
# ------------------------------------------------------------
# Los dos MUEVEN al que la lanza deslizandose (no aparece de golpe como el salto). Lo decide quien lleva
# la pelea y viaja al espejo como el salto (espejo._apuntar_desliz_red). Cuando arranca:
#   ANTES   al empezar su gesto: das el paso y luego la estocada (Paso ligero sin nadie al alcance)
#   TRAS    al acabar sus golpes: la estocada y luego el paso (Paso ligero con alguien pegado)
#   YA      en el acto: no hay golpe que esperar (Paso ligero sin nadie)
#   AVANCE  al empezar su gesto, y dura lo que sus golpes: cruzas la linea (Danza de acero)
#   EMPUJON al encajar ESE el golpe: el tiron/empujon a un personaje de OTRO humano (la Marea, 28/09), que
#           solo puede mover su maquina (ver pedir_tiron)
enum Desliz { ANTES, TRAS, YA, AVANCE, EMPUJON }
const T_PASO := 0.16           # lo que tarda el paso de lado, en tiempo de la pelea
# (el avance va a EstoqueAire.V_DANZA, el compas de sus golpes)
var _deslices: Array = []   # {c, hasta (el nodo), modo, golpes, espera, tope, armado, t (-1 sin arrancar), desde}

# EL PLAN DEL PASO LIGERO con las posiciones de ahora: {v: a quien pega (o null), hasta: el nodo, modo}.
func plan_paso(ab: AbilityData, c: Combatant) -> Dictionary:
	var f = forma_de(ab, c, apunte)
	var hasta: Vector2 = Vector2(f.centro) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
	var v: Combatant = _mas_cercano_al_alcance(c, pies_de(c))
	if v != null:
		return {"v": v, "hasta": hasta, "modo": Desliz.TRAS}
	v = _mas_cercano_al_alcance(c, f.centro)
	return {"v": v, "hasta": hasta, "modo": Desliz.ANTES if v != null else Desliz.YA}


# El enemigo vivo mas cercano al que 'c' llegaria con su arma estando con los pies en 'pies'.
func _mas_cercano_al_alcance(c: Combatant, pies: Vector2) -> Combatant:
	var mejor: Combatant = null
	var d_mejor: float = INF
	for e in _pantalla._vivos():
		var r: Rect2 = bulto_de(e)
		var cerca := Vector2(clampf(pies.x, r.position.x, r.end.x), clampf(pies.y, r.position.y, r.end.y))
		var hueco: float = pies.distance_to(cerca) - radio_pisa(c)
		if hueco <= alcance_de(c) and hueco < d_mejor:
			d_mejor = hueco
			mejor = e
	return mejor


# HASTA DONDE LLEGA 'c' yendo en recto hacia 'pies_fin' (los pies): el ultimo sitio del camino que pisa
# suelo y no se sale de la arena, y de ahi hacia atras hasta uno donde no quede encima de nadie. Devuelve
# el NODO. Sin sitio, donde esta.
func _sitio_libre_hacia(c: Combatant, pies_fin: Vector2) -> Vector2:
	var cuerpo: Node2D = cuerpo_de(c)
	var bajo: Vector2 = _bajo_de(c)
	var ini: Vector2 = pos_de(c)
	if cuerpo == null:
		return ini
	var fin: Vector2 = pies_fin - bajo
	var dentro: Rect2 = _dentro(_arena())
	var largo: float = ini.distance_to(fin)
	var pasos: int = maxi(1, ceili(largo / 4.0))
	# Por el camino: donde se acabe el suelo, se para.
	var tope: int = 0
	for k in range(1, pasos + 1):
		var p: Vector2 = ini.lerp(fin, float(k) / float(pasos))
		if not _sobre_suelo(p, cuerpo) or (dentro.has_area() and not dentro.has_point(p)):
			break
		tope = k
	# Y de ahi hacia atras, hasta no pisar a nadie (se ATRAVIESA, pero no se acaba encima).
	for k in range(tope, 0, -1):
		var p2: Vector2 = ini.lerp(fin, float(k) / float(pasos))
		if not _hay_otro_en(c, p2):
			return p2
	return ini


# DE SU NODO A SUS PIES: los tuyos, PoseJugador.PIES_BAJO_NODO; un enemigo, lo que diga su dibujo (ver pies_de).
func _bajo_de(c: Combatant) -> Vector2:
	if _pantalla._enemies.has(c):
		return pies_de(c) - pos_de(c)
	return Vector2(0.0, PoseJugador.PIES_BAJO_NODO)


# ¿Queda el nodo 'p' encima de alguien vivo que no sea 'c' (enemigo o de los tuyos)?
func _hay_otro_en(c: Combatant, p: Vector2) -> bool:
	for grupo in [_pantalla._enemies, _pantalla._aliados]:
		for o in grupo:
			if o == c or not (o as Combatant).is_alive() or cuerpo_de(o) == null:
				continue
			if p.distance_to(pos_de(o)) < SEPARACION:
				return true
	return false


# Lo que mueve una habilidad con PASO o AVANCE, con el apunte de la accion. 'golpes' = los que va a dar
# (0 = no pega a nadie).
func pedir_movimiento(ab: AbilityData, c: Combatant, golpes: int) -> void:
	if ab.paso:
		var plan: Dictionary = plan_paso(ab, c)
		pedir_desliz(c, plan["hasta"], int(plan["modo"]), golpes)
	elif ab.avance:
		var f = forma_de(ab, c, apunte)
		pedir_desliz(c, f.origen + f.dir * f.largo - Vector2(0.0, PoseJugador.PIES_BAJO_NODO),
			Desliz.AVANCE, golpes)


# LA CARGA (Embestida, 25/09): corres por la linea hasta pegarte al primero que pilla ('victima') y le das
# al llegar; sin nadie, hasta el final de la linea y ya. 'golpes' = los que va a dar.
func pedir_carga(ab: AbilityData, c: Combatant, victima: Combatant, golpes: int) -> void:
	var f = forma_de(ab, c, apunte)
	var fin: Vector2 = f.origen + f.dir * f.largo
	if victima != null:
		fin = pies_de(victima) - f.dir * (maxf(radio_pisa(victima), 8.0) + radio_pisa(c))
	pedir_desliz(c, _sitio_libre_hacia(c, fin), Desliz.ANTES if victima != null else Desliz.YA,
		golpes if victima != null else 0)


# EL MURO (25/09): te pones junto a quien cubres, DEL LADO DEL ENEMIGO MAS CERCANO A EL (no "delante" suyo:
# de donde le viene el golpe). Sin enemigos, no te mueves. Sale ya: no hay golpe que esperar.
func pedir_ponerse_delante(c: Combatant, aliado: Combatant) -> void:
	if _pantalla._espejo or not _pantalla.tactico or c == null or aliado == null or cuerpo_de(aliado) == null:
		return
	var enemigo: Combatant = null
	var d_mejor: float = INF
	for e in _pantalla._vivos():
		var d: float = hueco_entre(aliado, e)
		if d < d_mejor:
			d_mejor = d
			enemigo = e
	if enemigo == null:
		return
	var pa: Vector2 = pies_de(aliado)
	var dir: Vector2 = pies_de(enemigo) - pa
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	var largo: float = maxf(maxf(radio_pisa(aliado), 8.0) + radio_pisa(c) + HUECO_ESPALDA, SEPARACION + 2.0)
	var p = _sitio_en_abanico(c, pa, dir.normalized(), largo, true)
	if p != null:
		pedir_desliz(c, p, Desliz.YA, 0)


# CERRAR FILAS (Muro de aliados de la maza, 25/09): 'c' da un paso de 'px' hacia 'hacia', sin acabar
# encima de el ni de nadie. Sale ya: no hay golpe que esperar.
func pedir_juntar(c: Combatant, hacia: Combatant, px: float) -> void:
	if _pantalla._espejo or not _pantalla.tactico or c == null or hacia == null or c == hacia \
			or cuerpo_de(c) == null or cuerpo_de(hacia) == null:
		return
	var pc: Vector2 = pies_de(c)
	var ph: Vector2 = pies_de(hacia)
	var largo: float = minf(px, pc.distance_to(ph) - SEPARACION - 2.0)
	if largo < 2.0:
		return
	var hasta: Vector2 = _sitio_libre_hacia(c, pc + (ph - pc).normalized() * largo)
	if not hasta.is_equal_approx(pos_de(c)):
		pedir_desliz(c, hasta, Desliz.YA, 0)


# 'dur' (> 0) = lo que tarda, en tiempo de la pelea (si no, el paso de siempre); 'arco' = lo alto que va por el aire
# (el salto de un enemigo: su dibujo sube y baja, sus pies van por el suelo).
func pedir_desliz(c: Combatant, hasta: Vector2, modo: int, golpes: int, dur: float = -1.0, arco: float = 0.0) -> void:
	if _pantalla._espejo or not _pantalla.tactico or c == null:
		return
	if not _es_mio(c):
		_pos[c] = hasta
	_pantalla.espejo._apuntar_desliz_red(c, hasta, modo, golpes)
	anotar_desliz(c, hasta, modo, golpes)
	(_deslices.back() as Dictionary)["dur"] = dur
	(_deslices.back() as Dictionary)["arco"] = arco


# Tambien en el espejo, al leer el paquete de impactos.
func anotar_desliz(c: Combatant, hasta: Vector2, modo: int, golpes: int) -> void:
	if c == null:
		return
	# Sin golpes no hay gesto que esperar: sale ya.
	var ya: bool = modo == Desliz.YA or golpes <= 0
	_deslices.append({"c": c, "hasta": hasta, "modo": modo, "golpes": maxi(1, golpes), "espera": 0.0,
		"tope": 0.0 if ya else T_SALTO_ESPERA, "armado": ya, "t": -1.0, "desde": Vector2.ZERO})
	# El empujon va al ritmo del tiron (el paquete de red no lleva la duracion).
	if modo == Desliz.EMPUJON:
		(_deslices.back() as Dictionary)["dur"] = T_TIRON


# Su gesto ha arrancado: el paso de ANTES y el avance salen ya; el de TRAS espera a que acaben los golpes.
func _on_gesto_desliz(b: Dictionary, _dir: int, dur: float, _anim: StringName, _mano: int = -1) -> void:
	if _deslices.is_empty():
		return
	var c: Combatant = _de_bloque(b)
	for d in _deslices:
		# El avance no va con el gesto: va al compas de sus golpes (_on_suelo_lanzado).
		if d["c"] == c and not bool(d["armado"]) and int(d["modo"]) not in [Desliz.AVANCE, Desliz.EMPUJON]:
			d["armado"] = true
			d["espera"] = 0.0
			d["tope"] = dur * float(d["golpes"]) if int(d["modo"]) == Desliz.TRAS else 0.0
			# EL SALTO de un enemigo: se infla durante su gesto y CAE al acabarlo, que es cuando pega.
			if float(d.get("arco", 0.0)) > 0.0:
				d["tope"] = maxf(0.0, dur - _dur_desliz(d))
			return


# EL COMPAS DE LA DANZA ha salido (SueloRoto.Tipo.DANZA): el avance arranca con su frente, a su velocidad.
func _on_suelo_lanzado(tipo: int, espera: float) -> void:
	if tipo != SueloRoto.Tipo.DANZA:
		return
	for d in _deslices:
		if int(d["modo"]) == Desliz.AVANCE and not bool(d["armado"]):
			d["armado"] = true
			d["espera"] = 0.0
			d["tope"] = espera
			return


# Lo que dura un desliz, en segundos de verdad. El avance, lo que tarda el compas de la Danza en
# recorrerlo; el paso, al ritmo de los efectos (que ya lleva dentro la velocidad de la pelea).
func _dur_desliz(d: Dictionary) -> float:
	if int(d["modo"]) == Desliz.AVANCE:
		return maxf(Vector2(d["desde"]).distance_to(Vector2(d["hasta"])) / EstoqueAire.V_DANZA, 0.05)
	var ritmo: float = _pantalla._fx.escala_tiempo if _pantalla._fx != null else 1.0
	return float(d.get("dur", -1.0) if float(d.get("dur", -1.0)) > 0.0 else T_PASO) / maxf(ritmo, 0.05)


func _tick_deslices(delta: float) -> void:
	for d in _deslices.duplicate():
		var c: Combatant = d["c"]
		var cuerpo: Node2D = cuerpo_de(c)
		if cuerpo == null or not c.is_alive():
			_deslices.erase(d)
			# Si cae en pleno salto, el dibujo vuelve al suelo.
			if cuerpo != null and d.has("sp0") and cuerpo.get("_sprite") is Node2D:
				(cuerpo.get("_sprite") as Node2D).position = Vector2(d["sp0"])
			continue
		if float(d["t"]) < 0.0:
			d["espera"] = float(d["espera"]) + delta
			if float(d["espera"]) < float(d["tope"]):
				continue
			d["t"] = 0.0
			d["desde"] = cuerpo.global_position
			var sp0 = cuerpo.get("_sprite")
			if sp0 is Node2D:
				d["sp0"] = (sp0 as Node2D).position
			# EL RASTRO (polvo y aire) se ve en todas las pantallas, lo mueva quien lo mueva. Por el aire no deja.
			var arena: ArenaCombate = _arena()
			if arena != null and float(d.get("arco", 0.0)) <= 0.0:
				var bajo: Vector2 = _bajo_de(c)
				EstoqueAire.rastro(arena, Vector2(d["desde"]) + bajo, Vector2(d["hasta"]) + bajo, _dur_desliz(d),
					int(Vector2(d["hasta"]).x * 31.0) | 1)
		var dur: float = _dur_desliz(d)
		d["t"] = float(d["t"]) + delta
		var u: float = clampf(float(d["t"]) / dur, 0.0, 1.0)
		# El paso arranca rapido y frena; el avance va parejo, que es donde caen los golpes.
		var k: float = u if int(d["modo"]) == Desliz.AVANCE else 1.0 - (1.0 - u) * (1.0 - u)
		# El cuerpo solo lo mueve quien lo mueve siempre (como el salto); quien lleva la pelea ya lo
		# apunto en _pos al pedirlo.
		if _es_mio(c):
			_colocar(c, cuerpo, Vector2(d["desde"]).lerp(Vector2(d["hasta"]), k))
			if _pantalla._enemies.has(c):
				_apuntar_bicho(cuerpo, u < 1.0)
		# POR EL AIRE: el dibujo sube y baja (en todas las pantallas); los pies siguen por el suelo.
		var arco: float = float(d.get("arco", 0.0))
		var sp = cuerpo.get("_sprite")
		if arco > 0.0 and sp is Node2D and d.has("sp0"):
			(sp as Node2D).position = Vector2(d["sp0"]) - Vector2(0.0, sin(PI * u) * arco)
		if u >= 1.0:
			_deslices.erase(d)
			_enviar_bichos()
			if _es_mio(c) and _quien == c and _fase == Fase.MOVIENDO:
				_inicio = cuerpo.global_position


# ------------------------------------------------------------
#  EL GESTO DEL CUERPO en el mapa (24/09)
# ------------------------------------------------------------
# Cuando la pelea avisa de que uno de los tuyos hace su gesto (CombatFX.gesto_iniciado), lo hace SU
# CUERPO DEL MAPA, mirando hacia donde golpea (su _facing: apuntando ya se giro hacia el raton). La
# animacion la dice el estilo de la habilidad (CombatFX.ANIM_CUERPO_MAPA); sin ella, el golpe de su
# arma. Al acabar vuelve a la guardia (o a la pose de carga, si esta cargando).
# El MOLINETE no es una animacion sino un GIRO: la pose de espada extendida pasando por las ocho
# direcciones, dos vueltas en el sentido de las agujas como su estela (BarridoAire.GIRO).
const T_VUELTA_MOLINETE := 0.2    # = BarridoAire.T_ENTRE: una vuelta por golpe
# Los gestos que se REPITEN en cada golpe, y su version con la mano izquierda (dos dagas).
const _GESTOS_QUE_DEFIENDEN := ["defensa", "voto_larga", "golpe_escudo", "embestida_escudo", "provoca_escudo",
	"amparo_escudo", "rodela_escudo"]
const _REPITE_POR_GOLPE := {"tajo_daga": "tajo_daga_izq", "punalada_daga": "punalada_daga_izq",
	# El estoque (una mano siempre): la finta y el pinchazo de la Danza, uno por golpe.
	"finta_estoque": "finta_estoque", "pinchazo_estoque": "pinchazo_estoque",
	# Las puñaladas de tras la bomba (CombatFX las avisa ya con su nombre: ANIM_SIGUIENTE_MAPA).
	"tajo_daga_solo": "tajo_daga_solo",
	# La espada corta (25/09): con una, siempre la derecha; con dos, alternando (MunecoJugador los cambia
	# por los de las dos espadas).
	"tajo_espada": "tajo_espada_izq", "reves_espada": "reves_espada_izq", "barrido_espada": "barrido_espada_izq", "tajo_bajo_espada": "tajo_bajo_espada_izq", "tajo_paso_espada": "tajo_paso_espada_izq",
	# La maza (26/09): igual que la espada corta. El Demoledor con dos NO: es un gesto de las dos manos a la vez.
	"mazazo_maza": "mazazo_maza_izq", "rompe_maza": "rompe_maza_izq", "culatazo_maza": "culatazo_maza_izq"}
var _mano_izq_toca: Dictionary = {}   # cuerpo -> el siguiente tajo lo da la izquierda
var _gestos_mapa: Dictionary = {}   # cuerpo -> {t, dur, anim, d0, m}

# 'mano': la del golpe (0 derecha, 1 izquierda; -1 = no se sabe y se alterna como antes).
func gesto_en_mapa(c: Combatant, anim: String, dur: float, mano: int = -1) -> bool:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return false
	var m = cuerpo.get("_muneco")
	if not (m is MunecoJugador) or not (m as MunecoJugador).hay_dibujo():
		return false
	if anim == "":
		anim = _pantalla.figuras._anim_golpe_de(c)
	var en_curso: String = String(_gestos_mapa[cuerpo]["anim"]) if _gestos_mapa.has(cuerpo) else ""
	# LA DAGA REPITE SU GESTO EN CADA GOLPE (24/09, lo pidio el jefe: "no ataca una vez por puñalada").
	# Con dos dagas, alternando de mano. Y la bomba de Desaparecer: tras tirarla, cada aviso es una
	# puñalada a una mano (su otra daga sigue envainada).
	if anim == "lanzar_humo" and en_curso in ["lanzar_humo", "tajo_daga_solo"]:
		anim = "tajo_daga_solo"
	elif _REPITE_POR_GOLPE.has(anim):
		if (m as MunecoJugador).lleva_arma_izq():
			# LA MANO DE VERDAD (la del golpe que resolvio la pelea): con daga + espada corta cada golpe sale
			# con el arma que pega. Solo si no se sabe, alternando.
			var izq: bool = mano == 1 if mano >= 0 else bool(_mano_izq_toca.get(cuerpo, false))
			_mano_izq_toca[cuerpo] = not izq
			if izq:
				anim = String(_REPITE_POR_GOLPE[anim])
	# UN GESTO POR ACCION para el resto: la pelea vuelve a avisar en cada impacto (uno por golpe y
	# victima), y con su animacion entera ya cubriendo todos los golpes, reiniciarla la cortaba a medias.
	elif en_curso == anim:
		return true
	var d: int = SpriteLienzo.dir8(_mirada_de(cuerpo))
	var escala: float = _pantalla._fx.escala_tiempo if _pantalla._fx != null else 1.0
	(m as MunecoJugador).velocidad = escala
	# EN GUARDIA: ponerse en guardia la enciende (su quieta pasa a ser la defensiva) y dura hasta su
	# siguiente turno (la apaga empezar_turno; sus contraataques no). Sale del gesto, que ven todas las maquinas.
	if anim == "ponerse_en_guardia":
		(m as MunecoJugador).guardia_defensiva = true
	# Y el DEFENDER, igual: se queda en su postura de defensa hasta su turno. Tambien las que te dejan EN GUARDIA
	# (bloqueo_turnos: el Voto, los golpes de escudo, la Embestida, la Provocacion, el Muro, la rodela).
	if anim in _GESTOS_QUE_DEFIENDEN:
		(m as MunecoJugador).postura_defensa = true
	(m as MunecoJugador).animar("%s_%d" % [anim, d])
	_gestos_mapa[cuerpo] = {"t": 0.0, "dur": maxf(dur, 0.3), "anim": anim, "d0": d, "m": m,
		"escala": escala}
	return true


# ------------------------------------------------------------
#  EL GESTO DE UN ENEMIGO en el mapa (28/09, los slimes)
# ------------------------------------------------------------
# Lo mismo para los bichos: la animacion que pide la habilidad (AbilityData.fx_anim: 'inflar', 'escupir'...)
# o su embestida, EN SU CUERPO DEL MAPA y hacia donde mira (antes solo se animaba la tarjeta, que en el mapa
# esta escondida). 'encaje' = le acaban de pegar: sacudida, que nunca pisa un gesto suyo. Mientras dura, el
# cuerpo lleva la marca 'gesto_pelea' y su _actualizar_animacion no le cambia la animacion (en red, la copia
# del bicho la recalcula al verse mover).
# EN CADENA ('pide' = "hinchado>aplaston>deshincharse", ver AbilityData.fx_anim): la primera dura 'dur' y las
# demas salen detras a su ritmo. 'sostener' = la ultima se queda en bucle hasta que otro gesto la pise (la
# pose de CARGA: ver _tick_cargas_bicho). 'dur' <= 0 = a su ritmo.
var _gestos_bicho: Dictionary = {}   # cuerpo -> {t, dur, encaje, cola, sostener}

func gesto_bicho_en_mapa(c: Combatant, pide: StringName, dur: float, encaje: bool = false,
		sostener: bool = false) -> void:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null or not c.is_alive():
		return
	if encaje and _gestos_bicho.has(cuerpo) and not bool(_gestos_bicho[cuerpo]["encaje"]):
		return
	var partes: PackedStringArray = String(pide).split(">", false)
	var base: String = "encaje" if encaje else (partes[0] if not partes.is_empty() else "embestida")
	var natural: float = _poner_anim_bicho(cuerpo, base, dur, not encaje)
	if natural < 0.0:
		return
	cuerpo.set_meta("gesto_pelea", true)
	_gestos_bicho[cuerpo] = {"t": 0.0, "dur": maxf(dur if dur > 0.0 else natural, 0.2), "encaje": encaje,
		"cola": partes.slice(1) if not encaje else PackedStringArray(), "sostener": sostener}


# Pone la animacion 'base' hacia donde mira, ajustada a 'dur' (<= 0: a su ritmo). Devuelve lo que dura a su
# ritmo, o -1 si no la tiene. 'o_embestida' = si no la tiene, su embestida.
func _poner_anim_bicho(cuerpo: Node2D, base: String, dur: float, o_embestida: bool) -> float:
	var sp = cuerpo.get("_sprite")
	if not (sp is AnimatedSprite2D) or (sp as AnimatedSprite2D).sprite_frames == null:
		return -1.0
	var frames: SpriteFrames = (sp as AnimatedSprite2D).sprite_frames
	var d: int = SpriteLienzo.dir8(_mirada_de(cuerpo))
	var anim := StringName("%s_%d" % [base, d])
	# Las que solo tienen la direccion 0 valen igual: un slime es una bola.
	if not frames.has_animation(anim):
		anim = StringName("%s_0" % base)
	if not frames.has_animation(anim) and o_embestida:
		anim = StringName("embestida_%d" % d)
	if not frames.has_animation(anim):
		return -1.0
	var fps: float = maxf(frames.get_animation_speed(anim), 0.1)
	var natural: float = float(frames.get_frame_count(anim)) / fps
	(sp as AnimatedSprite2D).speed_scale = clampf(natural / dur, 0.25, 6.0) if dur > 0.0 else 1.0
	(sp as AnimatedSprite2D).play(anim)
	(sp as AnimatedSprite2D).frame = 0
	if cuerpo.get("_anim_actual") != null:
		cuerpo.set("_anim_actual", String(anim))
	return natural


func _tick_gestos_bicho(delta: float) -> void:
	_tick_cargas_bicho(delta)
	_tick_crias(delta)
	for cuerpo in _gestos_bicho.keys():
		if not is_instance_valid(cuerpo):
			_gestos_bicho.erase(cuerpo)
			continue
		var g: Dictionary = _gestos_bicho[cuerpo]
		g["t"] = float(g["t"]) + delta
		if float(g["t"]) < float(g["dur"]):
			continue
		# La siguiente de la cadena, a su ritmo.
		var cola: PackedStringArray = g["cola"]
		if not cola.is_empty():
			var natural: float = _poner_anim_bicho(cuerpo, cola[0], -1.0, false)
			g["cola"] = cola.slice(1)
			g["t"] = 0.0
			g["dur"] = maxf(natural, 0.05)   # si no la tiene, pasa a la siguiente
			continue
		# LA POSE DE CARGA se queda: si la animacion no es de bucle (la ignicion), vuelve a empezar.
		if bool(g["sostener"]):
			var sp = cuerpo.get("_sprite")
			if sp is AnimatedSprite2D and not (sp as AnimatedSprite2D).is_playing():
				(sp as AnimatedSprite2D).play()
				(sp as AnimatedSprite2D).frame = 0
			continue
		_gestos_bicho.erase(cuerpo)
		_soltar_gesto_bicho(cuerpo)


# ------------------------------------------------------------
#  LAS CRIAS DEL BROTE (28/09): nacen con cuerpo, ENTRE EL REY Y LOS TUYOS (decision del usuario: son su
#  escudo). Quien lleva la pelea elige el sitio y se lo pide a Game (que lo crea, o se lo pide al dueño del
#  piso). Hasta que le cae encima la gota del Rey es un CHARCO quieto (el primer marco de 'nacer'); con la
#  gota se levanta y se hace slime. En las demas pantallas se levanta igual: un golpe de enemigo a enemigo
#  solo puede ser esto.
# ------------------------------------------------------------
const SEPARA_CRIA := 30.0
const T_NACER_MAX := 1.5              # si la gota no llega (o llego antes que su cuerpo), nace igual
var _por_nacer: Dictionary = {}       # Combatant -> segundos esperando la gota
var _sitios_cria: Array = []          # [[pos, t_msec]]: los ya pedidos, cuyo cuerpo aun puede no estar

func dar_cuerpo_a_cria(rey: Combatant, cria: Combatant, data: EnemyData) -> void:
	if _pantalla._espejo or cuerpo_de(rey) == null:
		return
	var slot: int = _pantalla._enemies.find(cria)
	if slot < 0:
		return
	var p: Vector2 = sitio_para_cria(rey)
	_sitios_cria.append([p, Time.get_ticks_msec()])
	Game.dar_cuerpo_a_cria(slot, data, p, 0.2)   # la 't' con la que nace en la pelea (altas._invocar_slime)


func sitio_para_cria(rey: Combatant) -> Vector2:
	var pr: Vector2 = pos_de(rey)
	var suma := Vector2.ZERO
	var n: int = 0
	for al in _pantalla._aliados:
		if al.is_alive() and cuerpo_de(al) != null:
			suma += pos_de(al)
			n += 1
	var dir: Vector2 = (suma / float(n) - pr).normalized() if n > 0 else Vector2.DOWN
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var ocupados: Array = []
	var ahora: int = Time.get_ticks_msec()
	for s in _sitios_cria.duplicate():
		if ahora - int(s[1]) > 4000:
			_sitios_cria.erase(s)
		else:
			ocupados.append(s[0])
	for grupo in [_pantalla._enemies, _pantalla._aliados]:
		for c in grupo:
			if c != rey and (c as Combatant).is_alive() and cuerpo_de(c) != null:
				ocupados.append(pos_de(c))
	var cuerpo_rey: Node2D = cuerpo_de(rey)
	var dentro: Rect2 = _dentro(_arena())
	var base: float = radio_pisa(rey) + 18.0
	for anillo in 3:
		var r: float = base + float(anillo) * 18.0
		for giro in [0.0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35, 1.8, -1.8]:
			var p: Vector2 = pr + dir.rotated(float(giro)) * r
			if dentro.has_area() and not dentro.has_point(p):
				continue
			if not _sobre_suelo(p, cuerpo_rey):
				continue
			var libre: bool = true
			for o in ocupados:
				if p.distance_to(o) < SEPARA_CRIA:
					libre = false
					break
			if libre:
				return p
	return pr + dir * base


# Game le acaba de poner cuerpo (el suyo, o el espejo que llego por red): charco quieto hasta la gota.
func cria_con_cuerpo(slot: int) -> void:
	if slot < 0 or slot >= _pantalla._enemies.size():
		return
	var c: Combatant = _pantalla._enemies[slot]
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return
	var rey_hacia := Vector2.DOWN
	for al in _pantalla._aliados:
		if al.is_alive() and cuerpo_de(al) != null:
			rey_hacia = pos_de(al) - cuerpo.global_position
			break
	_animar(cuerpo, rey_hacia, false)
	if _poner_anim_bicho(cuerpo, "nacer", -1.0, false) < 0.0:
		return
	(cuerpo.get("_sprite") as AnimatedSprite2D).pause()
	(cuerpo.get("_sprite") as AnimatedSprite2D).frame = 0
	cuerpo.set_meta("gesto_pelea", true)
	_gestos_bicho[cuerpo] = {"t": 0.0, "dur": INF, "encaje": false, "cola": PackedStringArray(),
		"sostener": false}
	_por_nacer[c] = 0.0


func _nacer_cria(c: Combatant) -> void:
	_por_nacer.erase(c)
	gesto_bicho_en_mapa(c, &"nacer", -1.0)


func _tick_crias(delta: float) -> void:
	for c in _por_nacer.keys():
		_por_nacer[c] = float(_por_nacer[c]) + delta
		if float(_por_nacer[c]) >= T_NACER_MAX or not c.is_alive():
			_nacer_cria(c)


# LOS QUE CAEN A MEDIA PELEA (28/09, decision del usuario): se mueren en su sitio (su 'muerte', hacia donde
# miraban) y se DESVANECEN, para no estorbar. Al acabar la pelea vuelven al suelo como CADAVER para recogerlos:
# Game los mata (morir / marcar_cadaver) y ahi se les devuelve el alfa (quitar_muerto_en_pelea). Lo llama el
# apagado de su tarjeta (combat_altas._apagar_visual), que ya espera al golpe que lo mata y corre en TODAS las
# pantallas, tambien en los espejos.
const T_DESVANECE_MUERTO := 0.6

func morir_en_mapa(c: Combatant) -> void:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null or cuerpo.has_meta("muerto_en_pelea"):
		return
	_gestos_bicho.erase(cuerpo)
	_por_nacer.erase(c)
	_poses_carga.erase(c)
	var natural: float = _poner_anim_bicho(cuerpo, "muerte", -1.0, false)
	cuerpo.set_meta("gesto_pelea", true)
	var t: Tween = cuerpo.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_interval(maxf(natural, 0.0) + 0.3)
	t.tween_property(cuerpo, "modulate:a", 0.0, T_DESVANECE_MUERTO)
	cuerpo.set_meta("muerto_en_pelea", t)


# LA POSE DE CARGA (Reventon hinchado, Presion encogida, Combustion al rojo). Se mira 'charging' cada
# fotograma, y no se engancha a _enemy_begin_charge, porque 'charging' ya viaja al espejo con el estado:
# asi la ven igual todas las pantallas sin mandar nada. Al soltar la pisa el gesto de la habilidad. Si se
# le va la carga y NO llega ese gesto (aturdido, o no llega en T_CARGA_SUELTA), hace su 'interrumpe'.
const T_CARGA_SUELTA := 1.5
var _poses_carga: Dictionary = {}   # Combatant -> {ab, t}

func _tick_cargas_bicho(delta: float) -> void:
	for e in _pantalla._enemies:
		var ab: AbilityData = e.charging if e.is_alive() else null
		if ab != null and ab.fx_anim_carga != &"" and not _poses_carga.has(e) and cuerpo_de(e) != null:
			_poses_carga[e] = {"ab": ab, "t": 0.0}
			gesto_bicho_en_mapa(e, ab.fx_anim_carga, -1.0, false, true)
	for e in _poses_carga.keys():
		var p: Dictionary = _poses_carga[e]
		if e.is_alive() and e.charging == p["ab"]:
			continue
		var cuerpo: Node2D = cuerpo_de(e)
		var g = _gestos_bicho.get(cuerpo) if cuerpo != null else null
		# Muerto, o ya salio el gesto de soltarla: nada que hacer.
		if not e.is_alive() or g == null or not bool(g["sostener"]):
			_poses_carga.erase(e)
			continue
		p["t"] = float(p["t"]) + delta
		if not e.aturdido() and float(p["t"]) < T_CARGA_SUELTA:
			continue
		_poses_carga.erase(e)
		var ab_ido: AbilityData = p["ab"]
		if ab_ido.fx_anim_interrumpe != &"":
			gesto_bicho_en_mapa(e, ab_ido.fx_anim_interrumpe, -1.0)
		else:
			_gestos_bicho.erase(cuerpo)
			_soltar_gesto_bicho(cuerpo)


func _soltar_gesto_bicho(cuerpo: Node2D) -> void:
	cuerpo.remove_meta("gesto_pelea")
	var sp = cuerpo.get("_sprite")
	if sp is AnimatedSprite2D:
		(sp as AnimatedSprite2D).speed_scale = 1.0
	if cuerpo.get("_anim_actual") != null:
		cuerpo.set("_anim_actual", "")
	_animar(cuerpo, _mirada_de(cuerpo), false)


func _tick_gestos(delta: float) -> void:
	_tick_gestos_bicho(delta)
	for cuerpo in _gestos_mapa.keys():
		var g: Dictionary = _gestos_mapa[cuerpo]
		# El reloj del gesto va en tiempo REAL (su 'dur' viene asi); el giro del Molinete, en el de la pelea.
		g["t"] = float(g["t"]) + delta
		if not is_instance_valid(cuerpo) or not is_instance_valid(g["m"]):
			_gestos_mapa.erase(cuerpo)
			continue
		var t: float = float(g["t"])
		if String(g["anim"]) == "molinete":
			# Las direcciones van 0 = S, 1 = SE, 2 = E...: al reves de las agujas en pantalla. Restar es girar
			# como la estela. 8 pasos por vuelta, dos vueltas, y se queda mirando a donde empezo.
			var paso: int = mini(int(t * float(g["escala"]) / (T_VUELTA_MOLINETE / 8.0)), 16)
			(g["m"] as MunecoJugador).animar("molinete_%d" % posmod(int(g["d0"]) - paso, 8))
		if t >= float(g["dur"]) and (String(g["anim"]) != "molinete"
				or t * float(g["escala"]) >= 2.0 * T_VUELTA_MOLINETE):
			_gestos_mapa.erase(cuerpo)
			(g["m"] as MunecoJugador).velocidad = 1.0
			_animar(cuerpo, _mirada_de(cuerpo), false)


# EL CORTE DEL BASICO DEL MANDOBLE sobre 'obj' (BarridoAire.TAJO): centrado en su cuerpo tal como se ve,
# de su tamaño (sin pasarse: "no tan grande") y en diagonal hacia abajo, hacia el lado al que golpeas.
# 'fallo' (esquivado): el corte pasa AL LADO, tenue. Viaja en la apertura (1 = fallo), que la red ya lleva.
func forma_corte(a: Combatant, obj: Combatant, fallo: bool = false) -> CombatFormas.Forma:
	var r: Rect2 = bulto_de(obj)
	var centro: Vector2 = r.get_center() if r.has_area() else pos_de(obj)
	var largo: float = clampf(r.size.y * 0.95, 18.0, 32.0) if r.has_area() else 26.0
	var cu: Node2D = cuerpo_de(a)
	var lado: float = -1.0 if cu != null and _mirada_de(cu).x < 0.0 else 1.0
	if fallo:
		centro += Vector2(-lado * r.size.x * 0.75, 0.0) if r.has_area() else Vector2(-lado * 14.0, 0.0)
	return CombatFormas.cono(centro, Vector2(0.45 * lado, 1.0), largo, 1.0 if fallo else 0.0)


# El combatiente de uno de los cuerpos de los tuyos (null si no es de ninguno).
func _aliado_de_cuerpo(cuerpo: Node2D) -> Combatant:
	for c in _pantalla._aliados:
		if cuerpo_de(c) == cuerpo:
			return c
	return null


func _mirada_de(cuerpo: Node2D) -> Vector2:
	var f = cuerpo.get("_facing")
	if f is Vector2 and f != Vector2.ZERO:
		return f
	# La copia de red de un bicho no lleva _facing: mira por un angulo (remote_enemy._mira).
	var ang = cuerpo.get("_mira")
	if ang is float:
		return Vector2.RIGHT.rotated(ang)
	return Vector2.DOWN


# Pone la pose de andar o de quieto. Con el arbol en pausa el cuerpo no se anima solo (su
# _physics_process no corre), asi que hay que decirselo aqui.
#   Los tuyos: el muñeco, en GUARDIA (andar con el arma en alto: es una pelea).
#   Los bichos: su propio _actualizar_animacion, que ya sabe elegir walk/idle por velocidad.
func _animar(cuerpo: Node2D, dir: Vector2, moviendose: bool, vel: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(cuerpo) or dir == Vector2.ZERO:
		return
	if cuerpo.get("_facing") != null:
		cuerpo.set("_facing", dir.normalized())
	var muneco = cuerpo.get("_muneco")
	if muneco is MunecoJugador and (muneco as MunecoJugador).hay_dibujo():
		# En pleno gesto (el Molinete girando, un tajo bajando) no se le pisa con la guardia.
		if _gestos_mapa.has(cuerpo):
			return
		# CARGANDO, quieto: el arma en alto hasta soltarla (lo pidio el jefe: "que mantenga el martillo en
		# alto hasta que golpea el suelo").
		var c: Combatant = _aliado_de_cuerpo(cuerpo)
		if not moviendose and c != null and (_cargas.has(c) or c.charging != null):
			(muneco as MunecoJugador).animar("en_alto_%d" % SpriteLienzo.dir8(dir))
			return
		(muneco as MunecoJugador).animar(PoseJugador.animacion(dir, 1, moviendose, false, true, 0))
		return
	# LA COPIA DE RED de un bicho no lleva _facing ni velocidad: su pose sale de un ANGULO y de un "se
	# mueve", que normalmente le llegan por la red, y su _actualizar_animacion no tiene argumentos.
	if cuerpo.get("_mira") != null and cuerpo.get("_mov") != null:
		cuerpo.set("_mira", dir.angle())
		cuerpo.set("_mov", moviendose)
		cuerpo.call("_actualizar_animacion")
		return
	if cuerpo.has_method("_actualizar_animacion") and cuerpo.get("_sprite") != null:
		cuerpo.call("_actualizar_animacion", vel if moviendose else Vector2.ZERO)
