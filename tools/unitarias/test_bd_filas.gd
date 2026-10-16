extends "res://tools/unitarias/caso.gd"
# BDFilas (scripts/core/bd_filas.gd): una partida <-> filas de la base de datos.
# Lo importante para el plan de optimizacion: los materiales y cristales van CONTADOS (una fila por
# material+calidad+talla, no una por unidad) y vuelven identicos. La prueba con una partida real entera
# sigue siendo tools/prueba_bd_ida_vuelta (integracion); aqui va lo que se puede mirar en milisegundos.

const ACERO := "res://resources/materials/acero.tres"
const AJO := "res://resources/materials/ajo.tres"


func _mat(ruta: String, calidad: int, cm: float = 0.0) -> MaterialItem:
	var m := MaterialItem.crear(load(ruta), calidad)
	m.cm = cm
	return m


func _cri(cat: int, calidad: int) -> Cristal:
	var c := Cristal.new()
	c.categoria = cat
	c.calidad = calidad
	return c


func _ida_vuelta(s: SaveData) -> Array:
	var filas := BDFilas.a_filas(s, BDFilas.Ids.new())
	return [filas, BDFilas.de_filas(filas, BDFilas.Ids.new())]


# Cuenta una lista de materiales como {ruta|calidad|cm: n}, para comparar sin depender del orden.
func _cuenta(lista: Array) -> Dictionary:
	var out := {}
	for m in lista:
		var k: String
		if m is MaterialItem:
			k = "%s|%d|%s" % [m.data.resource_path, int(m.calidad), str(m.cm)]
		elif m is Cristal:
			k = "cri|%d|%d" % [m.categoria, int(m.calidad)]
		else:
			k = "otro|" + str(m)
		out[k] = int(out.get(k, 0)) + maxi(1, int(m.n))   # un monton cuenta lo que lleva
	return out


func _unidades(lista: Array) -> int:
	var n := 0
	for m in lista:
		n += maxi(1, int(m.n))
	return n


func test_baul_grande_va_contado() -> void:
	var s := SaveData.new()
	for i in 500:
		s.almacen_materiales.append(_mat(ACERO, MaterialItem.Calidad.NORMAL))
	for i in 300:
		s.almacen_materiales.append(_mat(AJO, MaterialItem.Calidad.DANADO))
	for i in 7:
		s.almacen_materiales.append(_mat(ACERO, MaterialItem.Calidad.PURO))
	var r := _ida_vuelta(s)
	var filas: Dictionary = r[0]
	var n_filas := 0
	for k in filas["contables"]:
		if String(k).begins_with("almacen_materiales|"):
			n_filas += 1
	igual(n_filas, 3, "807 materiales de 3 clases son 3 filas contadas")
	var s2: SaveData = r[1]
	igual(_unidades(s2.almacen_materiales), 807, "vuelven las 807 unidades")
	igual(s2.almacen_materiales.size(), 3, "en 3 montones, no 807 objetos")
	igual(_cuenta(s2.almacen_materiales), _cuenta(s.almacen_materiales), "mismas cantidades por clase")


func test_talla_de_los_peces_se_conserva() -> void:
	var s := SaveData.new()
	s.materiales.append(_mat(AJO, MaterialItem.Calidad.NORMAL, 31.5))
	s.materiales.append(_mat(AJO, MaterialItem.Calidad.NORMAL, 31.5))
	s.materiales.append(_mat(AJO, MaterialItem.Calidad.NORMAL, 44.25))
	var s2: SaveData = _ida_vuelta(s)[1]
	igual(_cuenta(s2.materiales), _cuenta(s.materiales), "la talla (cm) viaja con cada uno")


func test_cristales_van_contados() -> void:
	var s := SaveData.new()
	for i in 40:
		s.crystals.append(_cri(2, Cristal.Calidad.NORMAL))
	s.crystals.append(_cri(5, Cristal.Calidad.INTACTO))
	var r := _ida_vuelta(s)
	var n_filas := 0
	for k in r[0]["contables"]:
		if String(k).begins_with("crystals|"):
			n_filas += 1
	igual(n_filas, 2, "41 cristales de 2 clases son 2 filas")
	igual(_cuenta(r[1].crystals), _cuenta(s.crystals), "mismos cristales")


func test_listas_vacias() -> void:
	var s := SaveData.new()
	var s2: SaveData = _ida_vuelta(s)[1]
	igual(s2.materiales.size(), 0, "bolsa vacia")
	igual(s2.almacen_materiales.size(), 0, "baul vacio")
	igual(s2.crystals.size(), 0, "sin cristales")


func test_diccionario_partido_va_por_piso() -> void:
	var s := SaveData.new()
	s.memoria_pisos = {1: {"suelo": [Vector2i(1, 2)]}, 6: {"suelo": [], "vivos": 3}}
	var r := _ida_vuelta(s)
	cierto(r[0]["campos"].has("memoria_pisos/1") and r[0]["campos"].has("memoria_pisos/6"),
		"memoria_pisos va una fila por piso")
	igual(r[1].memoria_pisos, s.memoria_pisos, "y vuelve igual")


func test_volcado_a_trozos_da_lo_mismo_que_de_golpe() -> void:
	var s := SaveData.new()
	for i in 1000:
		s.almacen_materiales.append(_mat(ACERO if i % 3 else AJO, i % 4))
	var de_golpe := BDFilas.a_filas(s, BDFilas.Ids.new())
	var v := BDFilas.Volcado.new(s, BDFilas.Ids.new())
	var pasos := 0
	while not v.paso(1):   # el presupuesto mas pequeño posible: un trozo por paso
		pasos += 1
	cierto(pasos > 1, "con 1 µs de presupuesto tiene que ir a trozos")
	igual(v.out["contables"], de_golpe["contables"], "las filas contadas salen iguales")


func test_montones_cuentan_su_n_y_la_fila_no_cambia() -> void:
	# Un monton de 300 y 300 objetos sueltos tienen que dar EXACTAMENTE la misma fila (misma clave y cuenta)
	var s1 := SaveData.new()
	var monton := _mat(ACERO, MaterialItem.Calidad.NORMAL)
	monton.n = 300
	s1.almacen_materiales.append(monton)
	var s2 := SaveData.new()
	for i in 300:
		s2.almacen_materiales.append(_mat(ACERO, MaterialItem.Calidad.NORMAL))
	var f1: Dictionary = BDFilas.a_filas(s1, BDFilas.Ids.new())["contables"]
	var f2: Dictionary = BDFilas.a_filas(s2, BDFilas.Ids.new())["contables"]
	igual(f1, f2, "un monton de 300 = 300 sueltos, misma fila")


func test_monton_en_tres_conserva_su_n() -> void:
	# El mundo compartido y los respaldos van como .tres: el n tiene que guardarse alli
	var m := _mat(ACERO, MaterialItem.Calidad.NORMAL)
	m.n = 42
	var ruta := "user://prueba_monton_n.tres"
	var s := SaveData.new()
	s.almacen_materiales.append(m)
	ResourceSaver.save(s, ruta)
	var de_vuelta: SaveData = ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_IGNORE)
	igual(int(de_vuelta.almacen_materiales[0].n), 42, "el n vuelve del .tres")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


# EL ATAJO DEL TEXTO CONTADO (1C, 16/10): el texto de cada material se reaprovecha por lo que ES (ruta, calidad, talla),
# porque Monton.a_lista hace copias nuevas en cada exportar. Con un Ids que ya ha guardado antes tienen que salir
# EXACTAMENTE las mismas filas que con uno nuevo; y un material con metadatos sueltos no toma el atajo.
func test_atajo_del_texto_contado_da_lo_mismo() -> void:
	var s := SaveData.new()
	s.almacen_materiales = [_mat(ACERO, MaterialItem.Calidad.NORMAL), _mat(ACERO, MaterialItem.Calidad.PURO),
		_mat(ACERO, MaterialItem.Calidad.NORMAL, 31.4), _cri(2, Cristal.Calidad.INTACTO)]
	var raro := _mat(ACERO, MaterialItem.Calidad.NORMAL)
	raro.set_meta("marca", 7)
	s.almacen_materiales.append(raro)
	var caliente := BDFilas.Ids.new()
	# Calentarlo con COPIAS iguales (otras instancias, como hace a_lista en cada exportar)
	var antes := SaveData.new()
	antes.almacen_materiales = [_mat(ACERO, MaterialItem.Calidad.NORMAL), _mat(ACERO, MaterialItem.Calidad.PURO),
		_mat(ACERO, MaterialItem.Calidad.NORMAL, 31.4), _cri(2, Cristal.Calidad.INTACTO)]
	BDFilas.a_filas(antes, caliente)
	cierto(caliente.contable_txt.size() >= 4, "el atajo aprende los 4 textos")
	var fa: Dictionary = BDFilas.a_filas(s, caliente)
	var fb: Dictionary = BDFilas.a_filas(s, BDFilas.Ids.new())
	igual(fa["contables"], fb["contables"], "mismas filas contadas con atajo y sin el")
	igual(BDFilas._clave_texto(raro), "", "con metadatos no hay atajo")


# LAS FOTOS (1C, 16/10): una fila con una foto grande se pasa a texto con la foto recordada y tiene que salir LETRA POR
# LETRA igual que var_to_str de todo; la segunda vez (foto recordada) tambien, y si la foto cambia, el texto nuevo.
func test_fila_con_foto_da_el_mismo_texto() -> void:
	var foto := PackedByteArray()
	for i in 3000:
		foto.append(i % 251)
	var ids := BDFilas.Ids.new()
	var d := {"_clase": "PersonajeData", "nombre": "Dawnsin", "imagen": foto, "color": Color(1, 0.5, 0.2)}
	var esperado: String = var_to_str(d)
	igual(BDFilas._texto_objeto(d.duplicate(), ids), esperado, "primera vez")
	igual(BDFilas._texto_objeto(d.duplicate(), ids), esperado, "con la foto recordada")
	var otra: PackedByteArray = foto.duplicate()
	otra[10] = 7
	var d2 := {"_clase": "PersonajeData", "nombre": "Dawnsin", "imagen": otra, "color": Color(1, 0.5, 0.2)}
	igual(BDFilas._texto_objeto(d2.duplicate(), ids), var_to_str(d2), "foto cambiada: texto nuevo")
	var chica := {"imagen": PackedByteArray([1, 2, 3])}
	igual(BDFilas._texto_objeto(chica.duplicate(), ids), var_to_str(chica), "foto pequeña, tal cual")
