# ============================================================
#  combat_reacciones.gd  (tema de la pantalla de combate: combat.reacciones)
#  LAS REACCIONES ELEMENTALES (12/11; la tabla y las reglas, con el jefe el 10/11, memoria elementos-tabla-y-reacciones).
#  Son LEY DEL ELEMENTO: valen para cualquier golpe que entra, venga de quien venga (tambien contra los tuyos). Lo que
#  pegan de mas (los x1,5) va en Elementos.AMPLIFICA_POR_ESTADO, en la cuenta del daño; aqui va lo que hacen ADEMAS:
#  quitar y poner estados, las esquirlas, el empujon, lo que salta a los de al lado. Y que cada una SE VEA: su rotulo
#  encima (AVISO_REACCION, que viaja a los espejos como un golpe mas), su efecto y su linea en el log.
#
#    CONGELA     Hielo sobre Mojado      -> gasta el Mojado y Congelado (pierde el turno entero)
#    FRACTURA    fisico sobre Congelado  -> ese golpe +50 % (Elementos) y le suelta
#    ESQUIRLAS   Rayo sobre Congelado    -> le suelta y le revientan esquirlas a los pegados (daño de hielo)
#    DERRETIDO   Fuego sobre Frio o Congelado -> quita el hielo y le deja Mojado (y el mojado, al rayo)
#    SOBRECARGA  Rayo sobre Quemado      -> +50 % (Elementos) y empuja a los pegados
#    PROPAGACION Viento sobre un estado de elemento -> Quemado, Electrizado, Frio y Mojado saltan a los pegados
#                (un Congelado no congela a nadie: a los pegados les sopla Frio)
#  Despues de un Congelado, por lo que sea, viene el Deshielo (Combatant._tras_quitar): 2 turnos sin volver a congelarte.
#  Lo resuelve quien lleva la pelea; a los espejos les llegan los estados, los golpes y los rotulos.
# ============================================================
extends RefCounted

const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# El orden NO se toca: viaja en el peso del rotulo (peso = numero / 10). Las nuevas, al final.
enum Reaccion { NINGUNA, CONGELA, ROMPE, ESQUIRLAS, DERRITE, SOBRECARGA, EXTIENDE, ESQUIRLA }

const ROTULO := {
	Reaccion.CONGELA: "¡CONGELADO!",
	Reaccion.ROMPE: "¡FRACTURA!",
	Reaccion.ESQUIRLAS: "¡ESQUIRLAS!",
	Reaccion.DERRITE: "¡DERRETIDO!",
	Reaccion.SOBRECARGA: "¡SOBRECARGA!",
	Reaccion.EXTIENDE: "¡PROPAGACIÓN!",
}
# El color de cada rotulo: el del elemento que la provoca (Elementos.COLOR), para que se lea de donde viene. La
# PROPAGACION no usa el suyo: va del color del elemento de lo que salta (12/11, el jefe), ver color_rotulo.
const ROTULO_C := {
	Reaccion.CONGELA: Color(0.6, 0.85, 1.0),
	Reaccion.ROMPE: Color(0.85, 0.95, 1.0),
	Reaccion.ESQUIRLAS: Color(1.0, 0.95, 0.4),
	Reaccion.DERRITE: Color(1.0, 0.6, 0.25),
	Reaccion.SOBRECARGA: Color(1.0, 0.85, 0.3),
	Reaccion.EXTIENDE: Color(0.72, 0.95, 0.82),
}

# "LOS PEGADOS" de todas las reacciones que saltan: a 45 px (el salpicon de los hechizos, la misma distancia).
const PEGADOS := 45.0
# LAS ESQUIRLAS (12/11, su idea: "que estalle hacia los enemigos cercanos esquirlas y que haga daño"): provisional, la
# MITAD del golpe de rayo que lo rompe, de HIELO (cada uno con su tabla).
const ESQUIRLAS_DANO := 0.5
# LA SOBRECARGA empuja como el Torrente (12/11, su decision): 18 px hacia fuera.
const SOBRECARGA_EMPUJE := -18.0
# Lo que el viento EXTIENDE: los estados de elemento.
# El orden es el del color del rotulo si saltan varios a la vez: manda el primero.
const EXTIENDE_ESTADOS: Array[int] = [StatusEffects.Id.QUEMADURA, StatusEffects.Id.RAYO,
	StatusEffects.Id.CONGELACION, StatusEffects.Id.MOJADO]
const ELEMENTO_DE_ESTADO := {
	StatusEffects.Id.QUEMADURA: Elementos.Elemento.FUEGO, StatusEffects.Id.RAYO: Elementos.Elemento.RAYO,
	StatusEffects.Id.CONGELACION: Elementos.Elemento.HIELO, StatusEffects.Id.MOJADO: Elementos.Elemento.AGUA,
}

# Lo que salta a los de al lado (esquirlas, empujon, el viento) va una vez por resolucion: si un area pilla a tres
# congelados, no revientan tres tandas de esquirlas encima de los mismos.
var _salto_fotograma: int = -1


func _salta_ya() -> bool:
	if _salto_fotograma == Engine.get_process_frames():
		return false
	_salto_fotograma = Engine.get_process_frames()
	return true


# Lo llama CombatEfectos._fx_golpe con cada golpe que ENTRA (no esquivado, con daño), antes de que se gaste lo que lo
# amplificaba y antes de los estados del propio golpe.
func al_entrar(atacante: Combatant, victima: Combatant, dmg: float, elem: int) -> void:
	if _pantalla._espejo or victima == null or _pantalla.efectos._en_rebote:
		return
	match elem:
		Elementos.Elemento.HIELO:
			if victima.has_status(StatusEffects.Id.MOJADO) and victima.is_alive() \
					and not victima.es_inmune(StatusEffects.Id.CONGELADO):
				victima.quitar_estado(StatusEffects.Id.MOJADO)
				victima.apply_status(StatusEffects.Id.CONGELADO)
				if victima.has_status(StatusEffects.Id.CONGELADO):
					_rotulo(atacante, victima, Reaccion.CONGELA)
					_pantalla._log_extra("❄ ¡%s estaba mojado y se queda congelado! Pierde su próximo turno." % _pantalla._etq(victima))
		Elementos.Elemento.NINGUNO:
			if victima.has_status(StatusEffects.Id.CONGELADO):
				victima.quitar_estado(StatusEffects.Id.CONGELADO)
				_rotulo(atacante, victima, Reaccion.ROMPE)
				_pantalla._log_extra("🧊 ¡Fractura! El hielo de %s se parte: ese golpe le inflige un %s más de daño y queda libre." % [
					_pantalla._etq(victima), _extra(StatusEffects.Id.CONGELADO, elem)])
		Elementos.Elemento.RAYO:
			if victima.has_status(StatusEffects.Id.CONGELADO):
				victima.quitar_estado(StatusEffects.Id.CONGELADO)
				_rotulo(atacante, victima, Reaccion.ESQUIRLAS)
				_pantalla._log_extra("⚡ ¡El rayo revienta el hielo de %s, que queda libre!" % _pantalla._etq(victima))
				_esquirlas(atacante, victima, dmg)
			if victima.has_status(StatusEffects.Id.QUEMADURA):
				_rotulo(atacante, victima, Reaccion.SOBRECARGA)
				_pantalla._log_extra("⚡ ¡Sobrecarga! El rayo sobre las llamas de %s le inflige un %s más de daño y aparta a los de al lado." % [
					_pantalla._etq(victima), _extra(StatusEffects.Id.QUEMADURA, elem)])
				_sobrecarga(atacante, victima)
		Elementos.Elemento.FUEGO:
			if victima.has_status(StatusEffects.Id.CONGELADO) or victima.has_status(StatusEffects.Id.CONGELACION):
				victima.quitar_estado(StatusEffects.Id.CONGELADO)
				victima.quitar_estado(StatusEffects.Id.CONGELACION)
				victima.apply_status(StatusEffects.Id.MOJADO)
				_rotulo(atacante, victima, Reaccion.DERRITE)
				_pantalla._log_extra("🔥 ¡El fuego derrite el hielo de %s, que se queda empapado!" % _pantalla._etq(victima))
		Elementos.Elemento.VIENTO:
			_extiende(atacante, victima)


# Lo que pega de mas una reaccion, del daño de ese golpe ("50 %"), sacado de la tabla y no escrito a mano.
static func _extra(estado: int, elem: int) -> String:
	var m: float = float((Elementos.AMPLIFICA_POR_ESTADO.get(estado, {}) as Dictionary).get(elem, 1.0))
	return "%d %%" % int(round((m - 1.0) * 100.0))


# Los de su bando que tiene pegados (solo en el mapa: en la fila no hay "al lado").
func _pegados(victima: Combatant) -> Array:
	var out: Array = []
	if not _pantalla.tactico:
		return out
	var suyos: Array = _pantalla._vivos() if _pantalla._enemies.has(victima) else _pantalla._aliados
	for v in suyos:
		if v != victima and v.is_alive() and not v.no_elegible() \
				and _pantalla.turno_mapa.hueco_entre(victima, v) <= PEGADOS:
			out.append(v)
	return out


func _esquirlas(atacante: Combatant, victima: Combatant, dmg: float) -> void:
	if not _salta_ya():
		return
	var hielo: int = Elementos.Elemento.HIELO
	var es_enemigo: bool = _pantalla._enemies.has(victima)
	for v in _pegados(victima):
		var mult: float = Elementos.mult_recibido(hielo, v)
		var d: float = maxf(0.1, dmg * ESQUIRLAS_DANO * mult)
		v.take_damage(d)
		_pantalla.efectos._en_rebote = true
		_pantalla.efectos._fx_golpe(victima, v, d, false, false, hielo, CombatFX.Estilo.AVISO_REACCION,
			float(Reaccion.ESQUIRLA) / 10.0, false, "", AbilityData.Gesto.AUTO, null, 0, mult)
		_pantalla.efectos._en_rebote = false
		if es_enemigo:
			_pantalla._apuntar_dano(v, d, atacante)
			_pantalla._caidos_de_rebote.append(v)
		elif not v.is_alive():
			_pantalla.altas._caer_aliado(v)
		_pantalla._log_extra("🧊 Las esquirlas de %s le saltan a %s y le infligen %s de daño" % [_pantalla._etq(victima),
			_pantalla._etq(v), _pantalla._n(d)])


func _sobrecarga(_atacante: Combatant, victima: Combatant) -> void:
	if not _salta_ya():
		return
	for v in _pegados(victima):
		_pantalla.turno_mapa.pedir_tiron(v, victima, SOBRECARGA_EMPUJE, victima)   # arranca con el rayo que le entra a el
		var dsp: String = _pantalla.desplazado(v, SOBRECARGA_EMPUJE, victima)
		if dsp != "":
			_pantalla._log_extra(dsp)


# EL VIENTO EXTIENDE (10/11, idea suya, regla unica): cada estado de elemento que lleve salta a los pegados, con lo que
# le quede y su fuerza; con la tirada de siempre (su resistencia cuenta, StatusEffects.prob_final), sin daño.
func _extiende(atacante: Combatant, victima: Combatant) -> void:
	var lleva: Dictionary = {}   # id -> la instancia mas fuerte (de las brasas, la que arde)
	for e in victima.statuses:
		var id: int = e.id()
		# UN CONGELADO SOPLADO (12/11, el jefe): a los de al lado no los congela, les mete FRIO (congelar en grupo seria
		# demasiado). Cuenta como Frio con lo que dure el Frio de siempre.
		if id == StatusEffects.Id.CONGELADO:
			if not lleva.has(StatusEffects.Id.CONGELACION):
				lleva[StatusEffects.Id.CONGELACION] = null
			continue
		if EXTIENDE_ESTADOS.has(id) and (not lleva.has(id) or e.magnitude > lleva[id].magnitude):
			lleva[id] = e
	if lleva.is_empty() or not _pantalla.tactico:
		return
	var pegados: Array = _pegados(victima)
	if pegados.is_empty() or not _salta_ya():
		return
	var saltan: Array = []
	var primero: int = -1   # el estado que salto antes en EXTIENDE_ESTADOS: el color del rotulo
	for v in pegados:
		var puestos: Array = []
		for id in lleva:
			var inst = lleva[id]
			if v.es_inmune(id) or randf() >= StatusEffects.prob_final(1.0, atacante, v, id):
				continue
			if inst == null:
				v.apply_status(id)   # el frio del congelado: el de siempre
			else:
				v.apply_status(id, maxi(1, int(inst.turns)), float(inst.magnitude))
			if v.has_status(id):
				puestos.append(String(StatusEffects.def(id).get("nombre", "?")))
				if primero < 0 or EXTIENDE_ESTADOS.find(id) < EXTIENDE_ESTADOS.find(primero):
					primero = id
		if not puestos.is_empty():
			saltan.append("%s (%s)" % [_pantalla._etq(v), ", ".join(puestos)])
	if saltan.is_empty():
		return
	_rotulo(atacante, victima, Reaccion.EXTIENDE, int(ELEMENTO_DE_ESTADO.get(primero, Elementos.Elemento.VIENTO)))
	_pantalla._log_extra("💨 ¡Propagación! El viento extiende lo que llevaba %s: %s" % [_pantalla._etq(victima), "; ".join(saltan)])


# El rotulo encima: viaja como un golpe sin daño (solo dibujo) y lo pinta CombatTactico (AVISO_REACCION). El PESO lleva
# la reaccion (decimas) y, si su color cambia, el elemento (milesimas): 0,607 = la Propagacion, color del hielo. Va en el
# peso y no en el elemento del golpe para que el aviso no suene ni se tiña como un golpe de ese elemento.
func _rotulo(atacante: Combatant, victima: Combatant, r: int, elem_color: int = 0) -> void:
	_pantalla.efectos._fx_golpe(atacante if atacante != null else victima, victima, 0.0, false, false,
		Elementos.Elemento.NINGUNO, CombatFX.Estilo.AVISO_REACCION, float(r) / 10.0 + float(elem_color) / 1000.0, true)


# Del peso del aviso a su reaccion (lo usa quien lo pinta, en todas las pantallas).
static func de_peso(peso: float) -> int:
	return int(floorf(peso * 10.0 + 0.001))


# Y su color: el del elemento que lleva el peso, si lo lleva; si no, el de la reaccion.
static func color_rotulo(peso: float) -> Color:
	var r: int = de_peso(peso)
	var elem: int = int(round((peso * 10.0 - float(r)) * 100.0))
	if elem > 0 and Elementos.tiene_color(elem):
		return Elementos.color(elem)
	return ROTULO_C.get(r, Color.WHITE)
