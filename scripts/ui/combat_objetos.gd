# ============================================================
#  combat_objetos.gd  (tema de la pantalla de combate: combat.objetos)
#  OBJETOS en combate: el submenu de pociones, a quien se la das y lo que hace al beberla (cura ya y
#  el resto como Regeneracion; platos y antidotos ponen su estado). Lo demas se le pide a _pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# ============================================================
#  OBJETOS / pociones (KAN-57): submenu del inventario + uso
# ------------------------------------------------------------
func _accion_objeto() -> void:
	_pantalla._ocultar_cajas()
	for c in _pantalla._objeto_box.get_children():
		c.queue_free()
	# Una fila por tipo de poción del inventario, con la cantidad. Los grimorios NO salen: en
	# mitad de una pelea no te pones a estudiar (se usan desde el inventario, en el pueblo). Los
	# CEBOS tampoco: no se usan en ningun sitio que no sea la orilla de un estanque.
	var grid := _pantalla._rejilla_submenu(_pantalla._objeto_box)
	for cons in Game.consumables:
		var n: int = int(Game.consumables[cons])
		if n <= 0 or cons.es_grimorio() or cons.es_cebo():
			continue
		var b := TooltipButton.new()
		# El cuanto/en cuantos turnos se va al tooltip: a media anchura solo caben nombre y cantidad.
		b.text = "%s  x%d" % [cons.nombre, n]
		# Un PLATO no se reparte en turnos: su ficha ya dice lo que hace y cuanto dura.
		b.tooltip_text = cons.resumen_plato() if (cons.es_plato() or cons.es_brebaje_de_estado()) \
			else "%s en %d turnos" % [cons.resumen(_pantalla._player.max_hp, _pantalla._player.max_mp), cons.turnos]
		if cons.descripcion != "":
			b.tooltip_text += "\n\n" + cons.descripcion
		b.pressed.connect(_elegir_objetivo_objeto.bind(cons))
		_pantalla._celda_submenu(b)
		grid.add_child(b)
	_pantalla._cerrar_submenu(_pantalla._objeto_box, grid.get_child_count(), _pantalla._mostrar_acciones)
	_pantalla._ocultar_log()   # el submenu ocupa el sitio del historial


# Segundo paso del submenu: A QUIEN se la das. Una poción no tiene por que ser para ti — el que
# la bebe gasta SU turno, pero la cura puede ir al tanque que esta a punto de caer. Con un solo
# aliado en pie no se pregunta nada: va directo a el.
func _elegir_objetivo_objeto(cons: ConsumableData) -> void:
	var vivos: Array[Combatant] = _pantalla._aliados_vivos()
	if vivos.size() <= 1:
		_usar_objeto(cons, _pantalla._player)
		return
	for c in _pantalla._objeto_box.get_children():
		c.queue_free()
	var grid := _pantalla._rejilla_submenu(_pantalla._objeto_box)
	for al in vivos:
		var b := TooltipButton.new()
		var partes: Array = ["%.0f/%.0f ♥" % [al.current_hp, al.max_hp]]
		if cons.da_mana():
			partes.append("%.0f/%.0f 🔷" % [al.current_mp, al.max_mp])
		b.text = "%s  (%s)" % [al.nombre, "  ".join(partes)]
		b.tooltip_text = "%s le da %s a %s." % [_pantalla._player.nombre, cons.nombre, al.nombre]
		b.pressed.connect(_usar_objeto.bind(cons, al))
		_pantalla._celda_submenu(b)
		grid.add_child(b)
	_pantalla._cerrar_submenu(_pantalla._objeto_box, vivos.size(), _accion_objeto)


# Bebe una poción y se la da a 'objetivo': cura vida y/o maná YA, en este mismo turno, y deja el
# resto como Regeneración en los turnos que le queden. El primer tique es inmediato a proposito:
# los estados tiquean al INICIO del turno, asi que antes te bebias una poción y no veias subir
# nada hasta tu turno siguiente — justo cuando ya te habian rematado. El TOTAL no cambia: una
# poción de 3 turnos cura 1/3 ahora y 2/3 en tus 2 turnos siguientes.
# GASTA el turno del que la bebe (_player) y no cuesta energia.
func _usar_objeto(cons: ConsumableData, objetivo: Combatant, cobrar: bool = true) -> void:
	# Igual que las habilidades: el espejo elige y el anfitrion resuelve. El objetivo viaja como
	# INDICE dentro de los aliados, que es lo unico que significa lo mismo en las dos maquinas.
	# La POCION la pone quien la usa, no el anfitrion: las bolsas son por jugador y nunca se
	# sincronizan, asi que se gasta AQUI y el anfitrion resuelve el efecto sin cobrar nada.
	if _pantalla._espejo and cons != null:
		if not Game.gastar_consumible(cons):
			return
		_pantalla._responder_al_anfitrion({"tipo": "objeto", "ruta": cons.resource_path,
			"aliado": _pantalla._aliados.find(objetivo)})
		return
	if _pantalla._state != _pantalla.State.WAITING_PLAYER or objetivo == null or not objetivo.is_alive():
		return
	if cobrar and not Game.gastar_consumible(cons):
		return
	# UN PLATO DE COCINA no cura: pone un buff largo. Sale antes que el reparto de la poción porque
	# no tiene nada que repartir (turnos = 0), y va por apply_status como todo lo demas: es el que
	# sabe de la familia excluyente, o sea que comer aqui tira el plato anterior igual que comer por
	# el mapa. Gasta el turno igual que beber.
	# El ANTIDOTO entra por aqui con el plato: por dentro hacen lo mismo (poner un estado y gastar el
	# turno) y lo unico que cambia es como se cuenta. Si cayera al reparto de la pocion de abajo, sus
	# efectos no se aplicarian nunca -- ese camino solo sabe de vida y mana.
	if cons.es_plato() or cons.es_brebaje_de_estado():
		for ap in cons.efectos:
			if ap == null:
				continue
			objetivo.apply_status(int(ap.estado), int(ap.turns), float(ap.magnitud),
				maxi(1, int(ap.stacks)), false, int(ap.cap), float(ap.mult), cons.escala_efecto)
		var verbo: String = "se come" if cons.es_plato() else "se bebe"
		print("[objeto] %s le da %s a %s (en combate)" % [_pantalla._player.nombre, cons.nombre, objetivo.nombre])
		_pantalla._set_log("%s %s %s." % [objetivo.nombre, verbo, cons.nombre] if objetivo == _pantalla._player
			else "%s le da %s a %s." % [_pantalla._player.nombre, cons.nombre, objetivo.nombre])
		_pantalla._update_hp()
		_pantalla._fin_de_eleccion()
		_pantalla._state = _pantalla.State.ADVANCING
		return

	var restantes: int = maxi(0, cons.turnos - 1)   # el primer turno se cobra AL INSTANTE
	var partes: Array = []
	if cons.cura_hp():
		var por_turno: float = cons.cura_por_turno(objetivo.max_hp)
		var total: float = cons.cura_efectiva(objetivo.max_hp)
		objetivo.heal(por_turno)
		if restantes > 0:
			objetivo.apply_status(StatusEffects.Id.REGENERACION, restantes, por_turno)
		partes.append("✚ %.0f de vida (%.0f ya)" % [total, por_turno])
	if cons.da_mana():
		var mana_turno: float = cons.mana_por_turno(objetivo.max_mp)
		var mana_total: float = cons.mana_efectivo(objetivo.max_mp)
		objetivo.regen_mana(mana_turno)
		if restantes > 0:
			objetivo.apply_status(StatusEffects.Id.REGEN_MANA, restantes, mana_turno)
		partes.append("🔷 %.0f de maná (%.0f ya)" % [mana_total, mana_turno])
	print("[objeto] %s le da %s a %s (x%d turnos)" % [
		_pantalla._player.nombre, cons.nombre, objetivo.nombre, cons.turnos])
	var quien: String = ("%s se bebe %s" % [_pantalla._player.nombre, cons.nombre] if objetivo == _pantalla._player
		else "%s le da %s a %s" % [_pantalla._player.nombre, cons.nombre, objetivo.nombre])
	_pantalla._set_log("%s. %s, repartido en %d turnos." % [quien, " y ".join(partes), cons.turnos])
	_pantalla._update_hp()
	_pantalla._fin_de_eleccion()
	_pantalla._state = _pantalla.State.ADVANCING
