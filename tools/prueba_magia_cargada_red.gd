# PRUEBA (04/11, el jefe): EL CONJURO CARGADO DE PUNTA A PUNTA, con el jugador y su sala en otro Godot:
#   - se recita entero en el mapa SIN enemigo a tiro: se cobra, no sale nada y no se abre pelea;
#   - cargado se puede andar; el clic en un sitio sin nadie no abre pelea y sigue cargado;
#   - el clic sobre el enemigo abre la pelea, y en el turno del lider sale solo, sin boton: al enemigo le baja la vida;
#   - en otra pelea, entrando sin sitio, en su turno apunta y sale al elegirlo.
#   godot --headless --path . res://tools/prueba_magia_cargada_red.tscn -- nube_local
extends Node

const DESCARGA := "res://resources/spells/descarga.tres"
const CASTEO_MAPA = preload("res://scripts/ui/casteo_mapa.gd")

var j
var _mal := 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)   # entrar en el mundo cambia de escena: sin esto la prueba se borraria con ella
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _salir() -> void:
	await j.cerrar()
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


# Espera a que 'cond' se cumpla; mientras, pasa los turnos de los demas de mi grupo.
func _hasta_pasando(p: Node, cond: Callable, tope: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope * 1000.0 or not is_instance_valid(p):
			return false
		j.pasar_turno()   # (solo pulsa si me toca elegir: los que salgan antes que el lider)
		await j._esperar(0.1)
	return true


func _vida_enemigos(p: Node) -> float:
	var v: float = 0.0
	for e in p._enemies:
		v += (e as Combatant).current_hp
	return v


func _correr() -> void:
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_magia_cargada_red", 79):
		print("MAL: no arranca")
		get_tree().quit(1)
		return
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	# La arena me deja lejos de donde me tiene la sala, y alli mi cuerpo llega ANDANDO: hasta que no llegue, para ella
	# estoy a cientos de px y lo que apunto se queda sin alcance (con carga salia fallo a ratos).
	await j._esperar(10.0)
	var pj: PersonajeData = Game.lider()
	var sp: SpellData = load(DESCARGA)
	pj.current_mp = Game.player_max_mp(pj)
	var mp0: float = Game.player_mp(pj)

	# 1) RECITADO ENTERO SIN NADIE A TIRO.
	j.apartar_enemigos()
	var c: Node = CASTEO_MAPA.new()
	c.setup(pj, yo)
	c.lanzado.connect(yo._soltar_conjuro)
	yo.add_child(c)
	await j._esperar(0.2)
	c._elegir(sp)
	for k in sp.longitud():
		c._responder(sp.frases[k], sp.frases[k])
	await j._esperar(0.3)
	_ver(Game.conjuro_cargado() == sp, "recitado sin enemigos: queda cargado")
	_ver(Game.player_mp(pj) < mp0, "y ya esta pagado")
	_ver(not Game.combate_activo(), "y no abre pelea")
	var carga: Node = yo._conjuro_cargado
	_ver(is_instance_valid(carga), "sale su pieza en el mapa")
	if not is_instance_valid(carga):
		await _salir()
		return
	var hay_circulo := false
	for h in yo.get_children():
		if h is CirculoMagico and not (h as CirculoMagico).acabando():
			hay_circulo = true
	_ver(hay_circulo, "con su circulo a los pies")

	# 2) ANDAR CON EL Y CLIC SIN NADIE.
	var slime: Node2D = await j.poner("res://scenes/actors/enemy/slime.tres", Vector2(70, 0))
	_ver(slime != null, "aparece el slime")
	var lejos: Vector2 = yo.global_position + Vector2(0, -60)
	carga.sacar_area(lejos)
	_ver(carga.esta_apuntando(), "el clic saca el area")
	var f = carga.forma_en(sp, carga._ab, yo, lejos)
	var abrio: bool = carga.elegir_sitio(lejos) if not f.toca(Cuerpos.caja_de(slime)) else false
	_ver(not abrio and Game.conjuro_cargado() == sp and not Game.conjuro_con_sitio(), "sin nadie dentro: sigue cargado")

	# 3) CLIC SOBRE EL ENEMIGO: se abre la pelea y sale solo.
	_ver(carga.elegir_sitio(slime.global_position), "el clic sobre el slime pide la pelea")
	if not await j._hasta(func() -> bool: return j.pantalla() != null and Net.peleas.espejando(), 12.0):
		_ver(false, "se abre la pelea")
		await _salir()
		return
	var p: Node = j.pantalla()
	_ver(Game.conjuro_cargado() == null, "el conjuro se va con la ficha")
	var v0: float = _vida_enemigos(p)
	var mp_dentro: float = Game.player_mp(pj)
	var bajo: bool = await _hasta_pasando(p, func() -> bool: return _vida_enemigos(p) < v0 or Net.peleas.espejando() == false, 40.0)
	_ver(bajo, "en su turno sale solo y le baja la vida al enemigo (%.0f -> %.0f)" % [v0, _vida_enemigos(p) if is_instance_valid(p) else 0.0])
	_ver(is_equal_approx(Game.player_mp(pj), mp_dentro), "sin volver a cobrarlo")
	if is_instance_valid(p) and Net.peleas.espejando():
		await j.huir()
		await j._hasta(func() -> bool: return not Net.peleas.espejando(), 30.0)
		j.acabar_pelea_suelta()
	await j._esperar(1.0)

	# 4) ENTRAR EN OTRA PELEA CARGADO Y SIN SITIO: apunta en su turno y sale al elegir.
	Game.cargar_conjuro(sp, pj)
	var s2: Node2D = await j.poner("res://scenes/actors/enemy/slime.tres", Vector2(40, 0))
	var p2: Node = await j.pelear(s2) if s2 != null else null
	_ver(p2 != null, "entra pegando con el arma, con el conjuro cargado")
	if p2 == null:
		await _salir()
		return
	var t = p2.turno_mapa
	var apunta: bool = await _hasta_pasando(p2, func() -> bool: return t.esta_apuntando(), 40.0)
	_ver(apunta, "en su turno le pide el sitio")
	if apunta:
		var v2: float = _vida_enemigos(p2)
		t.confirmar_sitio(t.bulto_de(p2._enemies[0]).get_center())
		var bajo2: bool = await j._hasta(func() -> bool: return _vida_enemigos(p2) < v2 or not Net.peleas.espejando(), 15.0)
		_ver(bajo2, "al elegirlo sale y le da")
	await _salir()
