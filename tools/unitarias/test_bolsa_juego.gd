extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/core/game.gd (la BOLSA, la CARBONERA y los CRISTALES)
# Lo que hace el juego con lo que llevas encima: recoger, comprar, el carbon aparte, el peso, la municion, el
# farolillo, vender cristales, perder botin al caer y sacar de la bolsa. Escritas ANTES de pasar la bolsa a contada
# (plan de optimizacion, fase 1A, paso 3) y contra lectores (en_bolsa, cristales_en_bolsa, carbon_restante,
# peso_actual): tienen que salir igual antes y despues. Partida nueva en memoria, sin red ni escena.

const ACERO := "res://resources/materials/acero.tres"
const AJO := "res://resources/materials/ajo.tres"
const CARBON := "res://resources/materials/carbon_vegetal.tres"
const FLECHA := "res://resources/materials/flecha_hierro.tres"
const N := MaterialItem.Calidad.NORMAL
const D := MaterialItem.Calidad.DANADO
const I := MaterialItem.Calidad.INTACTO
const P := MaterialItem.Calidad.PURO


func _limpio() -> void:
	Game.nueva_partida("Prueba")
	Game.money = 1000000


func _mat(ruta: String, cal: int, cm: float = 0.0) -> MaterialItem:
	var m := MaterialItem.crear(load(ruta), cal)
	m.cm = cm
	return m


func _cri(cat: int, cal: int) -> Cristal:
	var c := Cristal.new()
	c.categoria = cat
	c.calidad = cal
	return c


func test_recoger_materiales_y_cristales() -> void:
	_limpio()
	for i in 3:
		Game.embolsar(_mat(ACERO, N))
	Game.embolsar(_cri(2, Cristal.Calidad.NORMAL))
	Game.embolsar(_cri(2, Cristal.Calidad.NORMAL))
	igual(Game.en_bolsa(load(ACERO), N), 3, "3 aceros")
	igual(Game.cristales_en_bolsa(2), 2, "2 cristales de categoria 2")
	igual(Game.cristales_en_bolsa(), 2, "2 cristales en total")


func test_el_carbon_va_a_la_carbonera() -> void:
	_limpio()
	Game.embolsar(_mat(CARBON, N))
	Game.embolsar(_mat(CARBON, N))
	igual(Game.carbon_restante(), 2, "2 trozos en la carbonera")
	igual(Game.en_bolsa(load(CARBON)), 2, "cuenta como llevado")


func test_comprar_mete_en_la_bolsa() -> void:
	_limpio()
	cierto(Game.comprar_material(load(AJO), 4), "compra 4 ajos")
	igual(Game.en_bolsa(load(AJO), N), 4, "4 ajos normales")


func test_peso_suma_materiales_y_cristales_y_no_el_carbon() -> void:
	_limpio()
	var p0: float = Game.peso_actual()
	for i in 5:
		Game.embolsar(_mat(ACERO, N))
	var un_acero: float = _mat(ACERO, N).peso()
	cerca(Game.peso_actual(), p0 + un_acero * 5.0, 0.001, "5 aceros")
	Game.embolsar(_cri(3, Cristal.Calidad.INTACTO))
	cerca(Game.peso_actual(), p0 + un_acero * 5.0 + _cri(3, Cristal.Calidad.INTACTO).peso(), 0.001, "y un cristal")
	var antes: float = Game.peso_actual()
	Game.embolsar(_mat(CARBON, N))
	cerca(Game.peso_actual(), antes, 0.0001, "el carbon no pesa")


func test_sacar_de_la_bolsa_por_modelo() -> void:
	_limpio()
	Game.embolsar(_mat(AJO, N, 31.4))
	Game.embolsar(_mat(AJO, N, 44.0))
	Game.embolsar(_cri(2, Cristal.Calidad.DANADO))
	var pez: Resource = Game._sacar_de_bolsa(_mat(AJO, N, 31.4))
	cierto(pez is MaterialItem and is_equal_approx(pez.cm, 31.4), "saca el de su talla")
	igual(Game.en_bolsa(load(AJO)), 1, "queda el otro")
	cierto(Game._sacar_de_bolsa(_cri(2, Cristal.Calidad.DANADO)) is Cristal, "saca el cristal")
	igual(Game.cristales_en_bolsa(), 0, "sin cristales")
	cierto(Game._sacar_de_bolsa(_cri(9, Cristal.Calidad.NORMAL)) == null, "lo que no hay: null")


func test_sacar_carbon_de_la_carbonera() -> void:
	_limpio()
	Game.embolsar(_mat(CARBON, N))
	cierto(Game._sacar_de_bolsa(_mat(CARBON, N)) != null, "el carbon tambien se saca (para soltarlo)")
	igual(Game.carbon_restante(), 0, "carbonera vacia")


func test_vender_todos_los_cristales() -> void:
	_limpio()
	Game.money = 0
	for i in 4:
		Game.embolsar(_cri(2, Cristal.Calidad.NORMAL))
	var cobrado: int = Game.vender_todos_cristales()
	cierto(cobrado > 0, "cobra (%d)" % cobrado)
	igual(Game.money, cobrado, "al bolsillo")
	igual(Game.cristales_en_bolsa(), 0, "sin cristales")
	igual(Game.vender_todos_cristales(), 0, "sin cristales no cobra")


func test_vender_cristales_de_uno_en_uno() -> void:
	_limpio()
	Game.money = 0
	for i in 3:
		Game.embolsar(_cri(4, Cristal.Calidad.INTACTO))
	cierto(Game.vender_item(_cri(4, Cristal.Calidad.INTACTO), 2) > 0, "vende 2")
	igual(Game.cristales_en_bolsa(4, Cristal.Calidad.INTACTO), 1, "queda 1")


func test_municion_mejor_primero_y_devolver() -> void:
	_limpio()
	var md: MaterialData = load(FLECHA)
	if not cierto(md is MunicionData, "la flecha es municion"):
		return
	Game.embolsar(_mat(FLECHA, D))
	Game.embolsar(_mat(FLECHA, I))
	Game.embolsar(_mat(FLECHA, N))
	var en: Array = Game.municion_en_bolsa((md as MunicionData).arma)
	igual(en.size(), 1, "una clase de municion")
	igual(int(en[0]["n"]), 3, "con 3")
	var cals: Array = Game.sacar_municion_de_bolsa(md, 2)
	igual(cals, [I, N], "saca la mejor primero (intacta, normal)")
	igual(Game.en_bolsa(md), 1, "queda la dañada")
	Game.devolver_municion_a_bolsa([[md, I], [md, I]])
	igual(Game.en_bolsa(md, I), 2, "vuelven 2 intactas")


func test_farolillo_quema_un_trozo_de_la_carbonera() -> void:
	_limpio()
	Game.embolsar(_mat(CARBON, N))
	Game.embolsar(_mat(CARBON, N))
	var luz: float = Game.luz_total_restante()
	cierto(luz > 0.0, "hay luz en la carbonera (%.1f)" % luz)
	cierto(Game._prender_siguiente_carbon(), "prende uno")
	igual(Game.carbon_restante(), 1, "queda un trozo")


func test_perder_botin_al_caer() -> void:
	_limpio()
	for i in 10:
		Game.embolsar(_mat(ACERO, N))
	for i in 10:
		Game.embolsar(_cri(1, Cristal.Calidad.NORMAL))
	Game.embolsar(_mat(CARBON, N))
	var perdido: Array = Game.perder_botin_por_muerte()
	igual(int(perdido[0]), 7, "pierdes 7 de 10 cristales")
	igual(int(perdido[1]), 7, "y 7 de 10 materiales")
	igual(Game.cristales_en_bolsa(), 3, "te quedan 3 cristales")
	igual(Game.en_bolsa(load(ACERO)), 3, "y 3 aceros")
	igual(Game.carbon_restante(), 1, "el carbon no se pierde")


func test_perder_con_bolsa_vacia() -> void:
	_limpio()
	igual(Game.perder_botin_por_muerte(), [0, 0], "nada que perder")


func test_guardar_en_casa_y_volver() -> void:
	_limpio()
	for i in 6:
		Game.embolsar(_mat(ACERO, N))
	Game.embolsar(_mat(CARBON, N))
	Game.guardar_materiales_en_hogar()
	igual(Game.en_bolsa(load(ACERO)), 0, "los aceros a casa")
	igual(Game.carbon_restante(), 1, "el carbon se queda en la carbonera")
	Game.recoger_materiales_del_hogar(true)
	igual(Game.en_bolsa(load(ACERO)), 6, "vuelven los 6")


# --- EL SUELO VA CONTADO (fase 1A, 16/10): soltar varias iguales deja UN monton y recogerlo las devuelve todas ---

func test_embolsar_un_monton_entra_de_golpe() -> void:
	_limpio()
	var m := _mat(ACERO, N)
	m.n = 3   # el n que traiga el item NO cuenta: manda el del monton del suelo
	Game.embolsar(m, 5)
	igual(Game.en_bolsa(load(ACERO), N), 5, "5 aceros, no 3 ni 15")
	Game.embolsar(_cri(2, Cristal.Calidad.NORMAL), 4)
	igual(Game.cristales_en_bolsa(2), 4, "4 cristales")
	var anti: ConsumableData = load("res://resources/consumables/antidoto.tres")
	var antes: int = int(Game.consumables.get(anti, 0))
	Game.embolsar(anti, 3)
	igual(int(Game.consumables.get(anti, 0)), antes + 3, "3 antidotos")


func _jugador_falso() -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	# Colgado de Game y no de la raiz: las unitarias corren mientras la raiz aun monta a sus hijos (add_child falla).
	Game.add_child(p)
	return p


# Sin los que ya se han recogido: recoger() hace queue_free y siguen en el grupo hasta el fotograma siguiente.
func _pickups() -> Array:
	return Game.get_tree().get_nodes_in_group("pickup").filter(func(k): return not k.is_queued_for_deletion())


func test_soltar_varias_deja_un_monton() -> void:
	_limpio()
	for i in 6:
		Game.embolsar(_mat(ACERO, N))
	var p := _jugador_falso()
	igual(Game.soltar_item(_mat(ACERO, N), 5), 5, "suelta 5")
	var suelo: Array = _pickups()
	igual(suelo.size(), 1, "UN monton en el suelo")
	if suelo.size() == 1:
		igual(int(suelo[0].cantidad), 5, "con sus 5")
		igual(Game.en_bolsa(load(ACERO), N), 1, "te queda 1")
		var cuantos: int = int(suelo[0].cantidad)
		Game.embolsar(suelo[0].recoger(), cuantos)
		igual(Game.en_bolsa(load(ACERO), N), 6, "recogerlo devuelve las 5")
	p.free()


func test_soltar_mas_de_las_que_hay() -> void:
	_limpio()
	for i in 2:
		Game.embolsar(_mat(ACERO, N))
	var p := _jugador_falso()
	igual(Game.soltar_item(_mat(ACERO, N), 9), 2, "solo hay 2")
	igual(_pickups().size(), 1, "un monton")
	for k in _pickups():
		k.free()
	p.free()


func test_los_cristales_caen_de_uno_en_uno() -> void:
	_limpio()
	for i in 3:
		Game.embolsar(_cri(1, Cristal.Calidad.NORMAL))
	var p := _jugador_falso()
	igual(Game.soltar_item(_cri(1, Cristal.Calidad.NORMAL), 3), 3, "suelta 3")
	igual(_pickups().size(), 3, "tres cristales sueltos: son cebo y el slime se come uno")
	for k in _pickups():
		k.free()
	p.free()
