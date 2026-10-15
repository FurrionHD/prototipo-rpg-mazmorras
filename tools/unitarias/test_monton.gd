extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/items/monton.gd
# Monton: el contador de cosas iguales que sustituye a las listas de un objeto por unidad (bolsa, baul, carbonera).

const ACERO := "res://resources/materials/acero.tres"
const AJO := "res://resources/materials/ajo.tres"
const N := MaterialItem.Calidad.NORMAL
const D := MaterialItem.Calidad.DANADO
const I := MaterialItem.Calidad.INTACTO
const P := MaterialItem.Calidad.PURO


func _m(ruta: String, cal: int, cm: float = 0.0) -> MaterialItem:
	var m := MaterialItem.crear(load(ruta), cal)
	m.cm = cm
	return m


func test_contar_sin_un_objeto_por_unidad() -> void:
	var b := Monton.new()
	b.anadir_de(load(ACERO), N, 500)
	b.anadir_de(load(AJO), D, 300)
	b.anadir(_m(ACERO, N))
	igual(b.total(), 801, "total de unidades")
	igual(b.clases(), 2, "dos clases, no 801 objetos")
	igual(b.cantidad(load(ACERO)), 501, "acero de todas las calidades")
	igual(b.cantidad(load(ACERO), N), 501, "acero normal")
	igual(b.cantidad(load(ACERO), I), 0, "acero intacto")
	igual(b.montones().size(), 2, "montones() da una entrada por clase")


func test_calidades_son_clases_distintas() -> void:
	var b := Monton.new()
	b.anadir_de(load(ACERO), N, 2)
	b.anadir_de(load(ACERO), I, 3)
	b.anadir_de(load(ACERO), P, 1)
	igual(b.clases(), 3, "tres calidades, tres montones")
	igual(b.cantidad(load(ACERO)), 6, "seis en total")


func test_unidades_de_taller() -> void:
	var b := Monton.new()
	b.anadir_de(load(ACERO), P, 1)   # 4
	b.anadir_de(load(ACERO), I, 2)   # 3 x 2
	b.anadir_de(load(ACERO), N, 3)   # 2 x 3
	b.anadir_de(load(ACERO), D, 1)   # 1
	igual(b.unidades(load(ACERO)), 4 + 6 + 6 + 1, "puro 4, intacto 3, normal 2, dañado 1")
	igual(b.unidades(load(AJO)), 0, "de lo que no hay, cero")


func test_quitar_devuelve_lo_que_quita() -> void:
	var b := Monton.new()
	b.anadir_de(load(ACERO), N, 5)
	igual(b.quitar_de(load(ACERO), N, 3), 3, "quita 3 de 5")
	igual(b.cantidad(load(ACERO)), 2, "quedan 2")
	igual(b.quitar_de(load(ACERO), N, 10), 2, "pedir 10 con 2 quita 2")
	igual(b.clases(), 0, "el monton vacio desaparece")
	igual(b.quitar_de(load(ACERO), N, 1), 0, "de lo que no hay no quita nada")
	igual(b.total(), 0, "total a cero")


func test_quitar_material_ignora_la_talla() -> void:
	var b := Monton.new()
	b.anadir(_m(AJO, N, 31.4), 2)
	b.anadir(_m(AJO, N, 44.0), 3)
	igual(b.clases(), 2, "dos tallas, dos montones")
	igual(b.quitar_material(load(AJO), N, 4), 4, "el taller quita 4 de cualquier talla")
	igual(b.cantidad(load(AJO)), 1, "queda 1")


func test_tallas_redondeadas_a_decimas() -> void:
	var b := Monton.new()
	b.anadir(_m(AJO, N, 31.42))
	b.anadir(_m(AJO, N, 31.44))
	b.anadir(_m(AJO, N, 31.46))
	igual(b.clases(), 2, "31,42 y 31,44 son 31,4; 31,46 es 31,5")
	var tallas := []
	for e in b.montones():
		tallas.append(e.cm)
	tallas.sort()
	cerca(float(tallas[0]), 31.4, 0.0001, "talla guardada redondeada")


func test_lo_de_dentro_no_es_lo_que_se_paso() -> void:
	var b := Monton.new()
	var m := _m(ACERO, N)
	b.anadir(m)
	m.calidad = I   # quien lo paso sigue usando su objeto
	igual(b.cantidad(load(ACERO), N), 1, "cambiar el objeto de fuera no cambia el monton")


func test_sacar_uno_da_un_objeto_nuevo() -> void:
	var b := Monton.new()
	b.anadir_de(load(ACERO), N, 2)
	var uno: MaterialItem = b.sacar_uno(_m(ACERO, N))
	cierto(uno != null and uno.data == load(ACERO), "sale un acero")
	igual(int(uno.n), 1, "de una unidad")
	igual(b.cantidad(load(ACERO)), 1, "y queda uno dentro")
	cierto(b.sacar_uno(_m(AJO, N)) == null, "de lo que no hay sale null")


func test_lista_contada_ida_y_vuelta() -> void:
	var b := Monton.new()
	b.anadir_de(load(ACERO), N, 7)
	b.anadir_de(load(AJO), D, 2)
	b.anadir_cristal(3, Cristal.Calidad.INTACTO, 4)
	var lista := b.a_lista()
	igual(lista.size(), 3, "tres entradas contadas")
	var b2 := Monton.new()
	b2.anadir_lista(lista)
	igual(b2.total(), 13, "vuelven las 13")
	igual(b2.cantidad(load(ACERO), N), 7, "los 7 aceros")


func test_lista_vieja_por_unidad_se_junta() -> void:
	# Las partidas de antes guardaban un objeto por unidad: al cargarlas se juntan.
	var vieja: Array = []
	for i in 40:
		vieja.append(_m(ACERO, N))
	var b := Monton.new()
	b.anadir_lista(vieja)
	igual(b.clases(), 1, "40 objetos iguales son un monton")
	igual(b.total(), 40, "de 40")
	igual(b.expandir().size(), 40, "y expandir devuelve los 40")


func test_cristales() -> void:
	var b := Monton.new()
	b.anadir_cristal(2, Cristal.Calidad.NORMAL, 10)
	b.anadir_cristal(2, Cristal.Calidad.DANADO, 1)
	b.anadir_cristal(5, Cristal.Calidad.NORMAL, 1)
	igual(b.clases(), 3, "categoria + calidad")
	igual(b.total(), 12, "doce cristales")
	var c := Cristal.new()
	c.categoria = 2
	igual(b.quitar(c, 4), 4, "quitar por modelo")
	igual(b.cantidad_de(c), 6, "quedan 6 de esa clase")


func test_peso_en_cache_y_se_invalida() -> void:
	var b := Monton.new()
	b.anadir_de(load(ACERO), N, 10)
	var uno: float = _m(ACERO, N).peso()
	cerca(b.peso(), uno * 10.0, 0.0001, "peso de 10")
	var v := b.version
	b.quitar_de(load(ACERO), N, 5)
	cierto(b.version > v, "la version sube al cambiar")
	cerca(b.peso(), uno * 5.0, 0.0001, "el peso se recalcula tras quitar")


func test_cosas_raras_no_rompen() -> void:
	var b := Monton.new()
	b.anadir(null)
	b.anadir_de(null, N, 3)
	b.anadir_de(load(ACERO), N, 0)
	b.anadir_de(load(ACERO), N, -2)
	igual(b.total(), 0, "nada de eso mete nada")
	igual(b.cantidad(null), 0, "contar null es cero")
	igual(b.quitar(null), 0, "quitar null es cero")


func test_quitar_al_azar_quita_justo_k() -> void:
	var b := Monton.new()
	b.anadir_de(load(ACERO), N, 9)
	b.anadir_de(load(AJO), N, 1)
	igual(b.quitar_al_azar(7), 7, "quita 7")
	igual(b.total(), 3, "quedan 3")
	igual(b.quitar_al_azar(50), 3, "no quita mas de los que hay")
	igual(b.total(), 0, "vacio")
	# Proporcional: con 9 aceros y 1 ajo, quitar uno al azar 2000 veces se lleva el ajo ~10 % de las veces
	seed(12345)
	var ajos := 0
	for i in 2000:
		var c := Monton.new()
		c.anadir_de(load(ACERO), N, 9)
		c.anadir_de(load(AJO), N, 1)
		c.quitar_al_azar(1)
		if c.cantidad(load(AJO)) == 0:
			ajos += 1
	entre(ajos, 140, 260, "el de 1 sale ~10 %% de las veces (%d de 2000)" % ajos)
