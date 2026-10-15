extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/core/game.gd (la BOLSA y el BAUL del hogar)
# Lo que hace el juego con los materiales de la bolsa y del baul: guardar en casa, recoger, mover montones, vender
# desde casa, contar para los talleres, gastar lo peor primero, refinar y devolver unidades. Escritas ANTES de pasar
# las listas a contadas (plan de optimizacion, fase 1A) y contra los lectores en_bolsa/en_hogar: tienen que salir
# igual antes y despues. Partida nueva en memoria (Game.nueva_partida), sin red ni escena.

const ACERO := "res://resources/materials/acero.tres"
const AJO := "res://resources/materials/ajo.tres"
const N := MaterialItem.Calidad.NORMAL
const D := MaterialItem.Calidad.DANADO
const I := MaterialItem.Calidad.INTACTO
const P := MaterialItem.Calidad.PURO


func _limpio() -> void:
	Game.nueva_partida("Prueba")
	Game.money = 0


func _a_bolsa(ruta: String, cal: int, n: int, cm: float = 0.0) -> void:
	for i in n:
		var m := MaterialItem.crear(load(ruta), cal)
		m.cm = cm
		Game.guardar_material(m)


func _a_casa(ruta: String, cal: int, n: int) -> void:
	_a_bolsa(ruta, cal, n)
	Game.guardar_materiales_en_hogar()


func test_partida_nueva_empieza_vacia() -> void:
	_limpio()
	igual(Game.total_en_bolsa(), 0, "bolsa vacia")
	igual(Game.total_en_hogar(), 0, "baul vacio")


func test_guardar_en_casa_lo_pasa_todo() -> void:
	_limpio()
	_a_bolsa(ACERO, N, 5)
	_a_bolsa(AJO, D, 3)
	igual(Game.guardar_materiales_en_hogar(), 8, "guarda las 8")
	igual(Game.total_en_bolsa(), 0, "la bolsa se vacia")
	igual(Game.en_hogar(load(ACERO), N), 5, "5 aceros en casa")
	igual(Game.en_hogar(load(AJO)), 3, "3 ajos en casa")


func test_recoger_todo_lo_devuelve_a_la_bolsa() -> void:
	_limpio()
	_a_casa(ACERO, N, 4)
	igual(Game.recoger_materiales_del_hogar(true), 4, "recoge 4")
	igual(Game.total_en_hogar(), 0, "casa vacia")
	igual(Game.en_bolsa(load(ACERO), N), 4, "4 en la bolsa")


func test_mover_monton_respeta_cuantos() -> void:
	_limpio()
	_a_bolsa(ACERO, N, 6)
	_a_bolsa(ACERO, D, 2)
	var modelo := MaterialItem.crear(load(ACERO), N)
	igual(Game.mover_monton_material(modelo, true, 4), 4, "mueve 4 a casa")
	igual(Game.en_bolsa(load(ACERO), N), 2, "quedan 2 normales en la bolsa")
	igual(Game.en_bolsa(load(ACERO), D), 2, "los dañados no se tocan (otra calidad)")
	igual(Game.en_hogar(load(ACERO), N), 4, "4 en casa")
	igual(Game.mover_monton_material(modelo, false), 4, "sin 'cuantos' se trae el monton entero")
	igual(Game.en_bolsa(load(ACERO), N), 6, "vuelven los 6")


func test_mover_monton_de_peces_por_talla() -> void:
	_limpio()
	_a_bolsa(AJO, N, 2, 31.4)
	_a_bolsa(AJO, N, 1, 44.0)
	var modelo := MaterialItem.crear(load(AJO), N)
	modelo.cm = 31.4
	igual(Game.mover_monton_material(modelo, true), 2, "mueve solo los de su talla")
	igual(Game.en_bolsa(load(AJO)), 1, "el grande se queda")


func test_vender_desde_casa() -> void:
	_limpio()
	_a_casa(ACERO, N, 5)
	var modelo := MaterialItem.crear(load(ACERO), N)
	var cobrado: int = Game.vender_item(modelo, 3, true)
	cierto(cobrado > 0, "cobra algo (%d)" % cobrado)
	igual(Game.money, cobrado, "el dinero sube lo cobrado")
	igual(Game.en_hogar(load(ACERO), N), 2, "quedan 2 en casa")
	igual(Game.vender_item(modelo, 10, true) > 0, true, "vender mas de los que hay vende los que quedan")
	igual(Game.en_hogar(load(ACERO)), 0, "y casa vacia")


func test_vender_desde_la_bolsa() -> void:
	_limpio()
	_a_bolsa(AJO, D, 4)
	var modelo := MaterialItem.crear(load(AJO), D)
	cierto(Game.vender_item(modelo, 1) > 0, "vende uno de la bolsa")
	igual(Game.en_bolsa(load(AJO), D), 3, "quedan 3")


func test_recuento_de_talleres_con_y_sin_cache() -> void:
	_limpio()
	_a_casa(ACERO, N, 3)
	_a_casa(ACERO, I, 2)
	igual(Game.items_calidad_en_hogar(load(ACERO), N), 3, "3 normales sin recuento abierto")
	igual(Game.unidades_material_en_hogar(load(ACERO)), 3 * 2 + 2 * 3, "unidades: normal 2, intacto 3")
	Game.abrir_recuento_hogar()
	igual(Game.items_calidad_en_hogar(load(ACERO), I), 2, "2 intactos con el recuento abierto")
	_a_casa(ACERO, I, 1)   # algo toca el baul con el recuento abierto: tiene que enterarse
	igual(Game.items_calidad_en_hogar(load(ACERO), I), 3, "el recuento se rehace si el baul cambia")
	Game.cerrar_recuento_hogar()


func test_gastar_unidades_quema_lo_peor_primero() -> void:
	_limpio()
	_a_casa(ACERO, I, 1)
	_a_casa(ACERO, N, 1)
	_a_casa(ACERO, D, 2)
	Game._consumir_unidades(load(ACERO), 2)   # 2 unidades = los dos dañados
	igual(Game.en_hogar(load(ACERO), D), 0, "se van los dañados")
	igual(Game.en_hogar(load(ACERO), N), 1, "el normal se queda")
	igual(Game.en_hogar(load(ACERO), I), 1, "el intacto se queda")


func test_gastar_nucleos_peor_primero() -> void:
	_limpio()
	_a_casa(ACERO, I, 1)
	_a_casa(ACERO, D, 1)
	Game._consumir_nucleos(load(ACERO), 1)
	igual(Game.en_hogar(load(ACERO), D), 0, "se gasta el dañado")
	igual(Game.en_hogar(load(ACERO), I), 1, "el intacto se queda")


func test_devolver_unidades_en_piezas() -> void:
	_limpio()
	Game._devolver_unidades(load(ACERO), 5)
	igual(Game.en_hogar(load(ACERO), N), 2, "5 unidades = 2 normales (2 uds cada una)...")
	igual(Game.en_hogar(load(ACERO), D), 1, "...y un dañado con la que sobra")


func test_consumir_items_de_una_calidad() -> void:
	_limpio()
	_a_casa(ACERO, N, 5)
	_a_casa(ACERO, D, 5)
	Game._consumir_items_calidad(load(ACERO), N, 3)
	igual(Game.en_hogar(load(ACERO), N), 2, "quita 3 normales")
	igual(Game.en_hogar(load(ACERO), D), 5, "y no toca los dañados")


func test_refinar_cuadra_las_cuentas() -> void:
	_limpio()
	var mineral: MaterialData = load("res://resources/materials/acero.tres")
	var lingote: MaterialData = Game.lingote_de(mineral) if Game.lingote_de(mineral) != null else load(AJO)
	_a_casa(ACERO, N, 9)
	var hechos: int = Game.refinar(mineral, lingote, N, 3, 3, "herreria")
	igual(hechos, 3, "3 refinados con 9 de a 3")
	igual(Game.en_hogar(lingote) if lingote != mineral else 3, 3, "salen 3 piezas (de la calidad que toque)")
	var quedan: int = Game.en_hogar(mineral) - (Game.en_hogar(lingote) if lingote == mineral else 0)
	entre(quedan, 0, 3, "de 9 se gastan 9 y vuelven entre 0 y 3 (una por refinado como mucho)")


func test_refinar_sin_bastantes_no_hace_nada() -> void:
	_limpio()
	_a_casa(ACERO, N, 2)
	igual(Game.refinar(load(ACERO), load(AJO), N, 1, 3, "herreria"), 0, "con 2 no llega a 3")
	igual(Game.en_hogar(load(ACERO), N), 2, "y no gasta nada")


func test_el_carbon_va_a_la_carbonera_y_no_pesa() -> void:
	_limpio()
	var carbon: MaterialData = null
	for r in Game.rutas_materiales():
		var md: MaterialData = load(r)
		if md != null and int(md.tipo) == MaterialData.Tipo.COMBUSTIBLE:
			carbon = md
			break
	if not cierto(carbon != null, "hay algun combustible en el juego"):
		return
	var antes: float = Game.peso_actual()
	var m := MaterialItem.crear(carbon, N)
	Game.guardar_material(m)
	igual(Game.en_bolsa(carbon), 1, "el carbon cuenta como llevado")
	cerca(Game.peso_actual(), antes, 0.0001, "pero no pesa")
	igual(Game.guardar_materiales_en_hogar(), 0, "y no se guarda en casa con lo demas")
