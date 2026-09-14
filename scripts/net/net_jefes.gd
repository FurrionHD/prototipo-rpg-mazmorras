# ============================================================
#  net_jefes.gd  (hijo de Net: /root/Net/Jefes)
#  LOS JEFES en multi: al caer uno se abren atajo y tienda para toda la sesion, se sella su piso con
#  el momento de la muerte y el host lo levanta por reloj de pared (Game.BOSS_RESPAWN). Los sellos
#  viajan como SEGUNDOS QUE FALTAN. Se llama como Net.jefes.<funcion>.
# ============================================================
extends Node

# JEFES caidos de la sesion: piso -> unix time (reloj de pared) en que cayo. Mismo mecanismo que
# _agotados_sesion y por la misma razon: el jefe reaparece por RELOJ (Game.BOSS_RESPAWN) y su cuenta
# atras tiene que sobrevivir a que os subais todos al pueblo.
#
# ESTAR EN LA TABLA = ESTA MUERTO. La resta contra el reloj la hace SOLO el host (_barrer_bosses), y
# cuando cumple borra la entrada y lo difunde. En los clientes el valor no significa nada —su
# tiempo_mazmorra es el de su mundo, no el del host— y solo se mira si la clave esta o no: asi el
# dueño de un piso (que puede ser un cliente) planta el jefe cuando lo dice el host y no cuando se lo
# diga su propio reloj.
var _bosses_sello: Dictionary = {}
# Latido APARTE para los jefes. No comparte el de las vetas porque no comparte el guard: aquel solo
# corre con la expedicion abierta y este corre siempre (ver _process).
var _t_bosses := 0.0


# --- BOSS CAIDO (hito 5.3) --------------------------------------------------------------------
#
# Lo llama enemy.morir() del jefe, en la maquina que simula ese piso. Decision del usuario: el
# ATAJO y la TIENDA se abren para TODOS los de la sesion (lo habeis hecho juntos), pero el CREDITO
# DE NIVEL es POR PERSONAJE y no se toca aqui: guardianes_vencidos solo lo apuntan los personajes
# que estuvieron en ESA pelea (ver Game._on_combat_finished). Si no participaste, se te abre el
# atajo pero no cuentas con haberlo matado.
func avisar_boss_caido(piso: int) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	_boss_caido.rpc(piso)
	# Y que el HOST arranque su cuenta atras, que es el unico que la lleva. Va aparte de _boss_caido
	# porque ese es "call_remote" (quien mata ya hizo su parte en local) y porque el sello no es un
	# hito de mundo: es un cronometro.
	if Net.es_host:
		_sellar_boss_host(piso)
	else:
		_pedir_sellar_boss.rpc_id(1, piso)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_sellar_boss(piso: int) -> void:
	if Net.es_host:
		_sellar_boss_host(piso)


# Solo host: el jefe de ese piso queda MUERTO en la tabla de sesion, y se difunde para que todos
# sepan que no toca plantarlo (el dueño del piso puede ser cualquiera).
func _sellar_boss_host(piso: int) -> void:
	if not Game.BOSSES.has(piso):
		return
	_bosses_sello[piso] = float(Encargos.ahora())
	# Acaba de caer: le queda la espera entera, y eso es lo que se manda (no el instante, ver
	# _conceder_entrada). El _marcar_boss local no toca nada, que la clave ya esta puesta arriba.
	var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
	_marcar_boss(piso, true, espera)
	_marcar_boss.rpc(piso, true, espera)
	print("[multi] jefe del piso %d abatido: vuelve en %d s" % [
		piso, roundi(float(Game.BOSS_RESPAWN.get(piso, 0.0)))])


@rpc("any_peer", "call_remote", "reliable")
func _marcar_boss(piso: int, muerto: bool, restan: float = -1.0) -> void:
	if muerto:
		# Quien MANDA la decision sigue siendo el host (esta clave puesta = el jefe esta muerto). Lo
		# que se guarda aqui es el instante EN MI RELOJ en que le tocara volver, para que el contador
		# de su sala pueda restar en local sin preguntar nada. 'restan' viene del host en segundos por
		# lo mismo que en _conceder_entrada: los relojes de pared de dos maquinas no van a la par.
		# Sin 'restan' (el jefe acaba de caer aqui mismo) la cuenta arranca entera.
		if not _bosses_sello.has(piso):
			var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
			var falta: float = espera if restan < 0.0 else restan
			_bosses_sello[piso] = float(Encargos.ahora()) - (espera - falta)
	else:
		_bosses_sello.erase(piso)


# SOLO HOST: repasa los jefes muertos y levanta a los que han cumplido su tiempo. Va colgado del
# mismo barrido que las vetas (_barrer_respawns), asi que hereda sus dos propiedades: corre cada
# BARRIDO_RESPAWN_CADA con la expedicion abierta, y se pone al dia de golpe cuando alguien vuelve a
# entrar despues de un rato en el pueblo.
#
# Aqui NO se planta el bicho: solo se suelta el sello. Plantarlo es cosa del dueño del piso, que es
# quien simula alli (dungeon_floor._repoblar_boss), o del propio piso al construirse.
func _barrer_bosses() -> void:
	if not Net.es_host:
		return
	for piso in _bosses_sello.keys():
		var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
		# RELOJ DE PARED, el mismo que en solitario (ver Game.bosses_sello). Con tiempo_mazmorra el
		# barrido iba al ritmo de los MENUS DEL HOST: si el anfitrion tenia el hogar abierto, el jefe
		# no se rehacia para nadie. Era la mitad del "el Rey Slime tardo media hora".
		var pasado: float = float(Encargos.ahora()) - float(_bosses_sello[piso])
		if pasado < 0.0:
			_bosses_sello[piso] = float(Encargos.ahora())   # el reloj se fue atras: se reinicia
			continue
		if pasado < espera:
			continue
		_bosses_sello.erase(piso)
		_marcar_boss(piso, false)
		_marcar_boss.rpc(piso, false)
		# El TIEMPO REAL que ha pasado va en el print a proposito: si vuelve a haber una queja de "el
		# jefe no reaparece", este numero dice de un vistazo si el reloj corrio (pasado ~ espera) o si
		# el barrido estuvo parado y se puso al dia de golpe (pasado >> espera).
		print("[multi] el jefe del piso %d vuelve a estar de pie (esperaba %d s, han pasado %d)" % [
			piso, roundi(espera), roundi(pasado)])


# ¿Toca que el jefe de ese piso este de pie? Lo pregunta Game.boss_disponible cuando hay sesion.
# Es una consulta de TABLA, sin relojes: la resta la hace el host en _barrer_bosses.
func boss_disponible(piso: int) -> bool:
	return not _bosses_sello.has(piso)


# SEGUNDOS que le faltan a ese jefe, para el contador de su sala. Aqui SI se resta, tambien en el
# cliente: su entrada de _bosses_sello ya viene re-basada a su reloj (ver _marcar_boss y _entrar_ok).
# Que el numero baje solo es cosmetico; quien decide que se plante sigue siendo boss_disponible, y esa
# sigue siendo consulta de tabla contra el host.
func boss_restante(piso: int) -> float:
	if not _bosses_sello.has(piso):
		return 0.0
	var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
	return maxf(0.0, espera - (float(Encargos.ahora()) - float(_bosses_sello[piso])))


# Corre en TODOS: apunta el hito de mundo y, si estoy en ESE piso, abre sus salidas (la escalera
# de bajada y la puerta al pueblo). Sin esto, el compañero que estaba en la sala del jefe nunca
# veria aparecer la bajada.
@rpc("any_peer", "call_remote", "reliable")
func _boss_caido(piso: int) -> void:
	Game.marcar_boss_derrotado(piso)
	if Net.pisos.mi_piso() != piso:
		return
	var f: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if f != null and f.has_method("abrir_salidas"):
		f.abrir_salidas()


# LOS JEFES VAN POR SU CUENTA: este reloj NO mira si hay expedicion abierta (el de las vetas si). Su reloj
# es de PARED (Encargos.ahora), asi que corre igual con la mazmorra vacia y con todo el mundo en el
# pueblo: no tiene nada que ver con que haya alguien dentro. Colgado del guard, el sello se quedaba
# congelado en cuanto el ultimo subia al pueblo y solo se soltaba en la puesta al dia de volver a
# bajar (_conceder_entrada) -- por eso el Rey Slime "no volvia" hasta que te ibas y regresabas.
#
# Es la OTRA MITAD del bug que dejo el comentario de _barrer_bosses: entonces se arreglo el RELOJ
# (de tiempo_mazmorra a reloj de pared) y se dejo la CADENCIA colgando de un guard que se apaga.
func _process(delta: float) -> void:
	if not Net.activo or not Net.es_host:
		return
	_t_bosses -= delta
	if _t_bosses <= 0.0:
		_t_bosses = Net.recoleccion.BARRIDO_RESPAWN_CADA
		_barrer_bosses()
