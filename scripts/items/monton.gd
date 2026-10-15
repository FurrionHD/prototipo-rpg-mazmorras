# ============================================================
#  monton.gd -- UN CONTADOR DE COSAS IGUALES (plan de optimizacion, fase 1A, 15/10/2026)
# ============================================================
# La bolsa, el baul del hogar y la carbonera eran listas con UN objeto por unidad: 19.000 MaterialItem en el baul
# real. Todo lo que las miraba (contar, pesar, agrupar para la rejilla, gastar en un taller, mandar por red) las
# recorria enteras. Aqui van CONTADAS: una entrada por clase de cosa (material + calidad + talla, o cristal
# categoria + calidad), y cada entrada es un MaterialItem / Cristal con su cantidad en `n`.
#
#   var baul := Monton.new()
#   baul.anadir(item)                 # una unidad (o item.n si ya es un monton)
#   baul.anadir_de(acero, NORMAL, 5)  # cinco de golpe, sin crear cinco objetos
#   baul.quitar_de(acero, NORMAL, 3)  # devuelve cuantos ha quitado de verdad
#   baul.cantidad(acero)              # todas las calidades; cantidad(acero, NORMAL) solo esa
#   baul.unidades(acero)              # en UNIDADES DE TALLER (puro 4, intacto 3, normal 2, dañado 1)
#   baul.total()                      # todas las unidades
#   for m in baul.montones(): ...     # una entrada por clase; NO tocar m.n desde fuera
#
# LAS ENTRADAS SON DEL MONTON: montones() devuelve los objetos de dentro para leerlos (rejilla, fichas). Quien
# quiera llevarse una unidad usa sacar_uno()/quitar_*, que devuelven objetos nuevos.
#
# LA TALLA DE LOS PECES va redondeada a 0,1 cm (decimas): dos lubinas de 31,42 y 31,44 cm son el mismo monton. Sin
# eso cada pez seria su propio monton y el contador no contaria nada.
#
# `version` sube con cada cambio: quien guarde algo calculado del monton (la rejilla agrupada, un recuento) mira si
# ha cambiado sin recorrerlo. El PESO va en cache por lo mismo (el HUD lo pregunta varias veces por fotograma).
# Prueba: tools/unitarias/test_monton.gd
class_name Monton
extends RefCounted

var _por_clave: Dictionary = {}   # clave -> MaterialItem | Cristal (con su n)
var _total: int = 0
var version: int = 0
var _peso: float = -1.0           # -1 = hay que recalcularlo


# ------------------------------------------------------------
#  CLAVES
# ------------------------------------------------------------
static func talla(cm: float) -> float:
	return snappedf(cm, 0.1) if cm > 0.0 else 0.0


static func clave_de(cosa: Resource) -> String:
	if cosa is MaterialItem:
		var m := cosa as MaterialItem
		return "m|%s|%d|%d" % [String(m.data.id) if m.data != null else "", int(m.calidad), roundi(talla(m.cm) * 10.0)]
	if cosa is Cristal:
		var c := cosa as Cristal
		return "c|%d|%d" % [c.categoria, int(c.calidad)]
	return ""


static func clave_mat(data: MaterialData, calidad: int, cm: float = 0.0) -> String:
	return "m|%s|%d|%d" % [String(data.id) if data != null else "", calidad, roundi(talla(cm) * 10.0)]


# ------------------------------------------------------------
#  METER
# ------------------------------------------------------------
# Mete `cosa` (una unidad, o cosa.n si ya venia contada). El objeto NO se queda dentro: se copia lo que lo
# identifica, asi que quien lo pasa puede seguir usandolo sin tocar el monton.
func anadir(cosa: Resource, n: int = -1) -> void:
	if cosa == null:
		return
	var cuantos: int = n if n >= 0 else maxi(1, int(cosa.get("n")))
	if cuantos <= 0:
		return
	var k: String = clave_de(cosa)
	if k == "":
		return
	var e: Resource = _por_clave.get(k)
	if e == null:
		e = _copia(cosa)
		e.set("n", 0)
		_por_clave[k] = e
	e.set("n", int(e.get("n")) + cuantos)
	_total += cuantos
	_cambio()


func anadir_de(data: MaterialData, calidad: int, n: int = 1, cm: float = 0.0) -> void:
	if data == null or n <= 0:
		return
	var m := MaterialItem.crear(data, calidad)
	m.cm = cm
	anadir(m, n)


func anadir_cristal(categoria: int, calidad: int, n: int = 1) -> void:
	if n <= 0:
		return
	var c := Cristal.new()
	c.categoria = categoria
	c.calidad = calidad
	anadir(c, n)


# Mete todo lo de una lista (las de antes, por unidad, o ya contada). Para cargar partidas y recibir por red.
func anadir_lista(lista: Array) -> void:
	for cosa in lista:
		if cosa is Resource:
			anadir(cosa)


# ------------------------------------------------------------
#  SACAR
# ------------------------------------------------------------
# Quita hasta `n` de la misma clase que `modelo`. Devuelve cuantos ha quitado.
func quitar(modelo: Resource, n: int = 1) -> int:
	if modelo == null:
		return 0
	return _quitar_clave(clave_de(modelo), n)


func quitar_de(data: MaterialData, calidad: int, n: int = 1, cm: float = 0.0) -> int:
	return _quitar_clave(clave_mat(data, calidad, cm), n)


# Quita hasta `n` de un material de una calidad, SEA CUAL SEA SU TALLA (los talleres no miran la talla).
func quitar_material(data: MaterialData, calidad: int, n: int) -> int:
	if data == null or n <= 0:
		return 0
	var quitados: int = 0
	for k in _claves_de_material(data, calidad):
		if quitados >= n:
			break
		quitados += _quitar_clave(k, n - quitados)
	return quitados


# Saca UNA unidad de la clase de `modelo` como objeto nuevo (para soltarla, venderla...). null si no hay.
func sacar_uno(modelo: Resource) -> Resource:
	var k: String = clave_de(modelo)
	var e: Resource = _por_clave.get(k)
	if e == null:
		return null
	var copia: Resource = _copia(e)
	_quitar_clave(k, 1)
	return copia


func vaciar() -> void:
	if _por_clave.is_empty():
		return
	_por_clave.clear()
	_total = 0
	_cambio()


func _quitar_clave(k: String, n: int) -> int:
	var e: Resource = _por_clave.get(k)
	if e == null or n <= 0:
		return 0
	var hay: int = int(e.get("n"))
	var q: int = mini(hay, n)
	if q >= hay:
		_por_clave.erase(k)
	else:
		e.set("n", hay - q)
	_total -= q
	_cambio()
	return q


# ------------------------------------------------------------
#  PREGUNTAR
# ------------------------------------------------------------
func total() -> int:
	return _total


func esta_vacio() -> bool:
	return _total == 0


func clases() -> int:
	return _por_clave.size()


# Cuantas hay de un material: de una calidad, o de todas si calidad < 0. Todas las tallas.
func cantidad(data: MaterialData, calidad: int = -1) -> int:
	if data == null:
		return 0
	var n: int = 0
	for e in _por_clave.values():
		if e is MaterialItem and e.data != null and e.data.id == data.id and (calidad < 0 or int(e.calidad) == calidad):
			n += int(e.n)
	return n


func cantidad_de(modelo: Resource) -> int:
	var e: Resource = _por_clave.get(clave_de(modelo))
	return int(e.get("n")) if e != null else 0


# En UNIDADES DE TALLER (puro 4, intacto 3, normal 2, dañado 1: MaterialItem.unidades_crafteo).
func unidades(data: MaterialData) -> int:
	if data == null:
		return 0
	var u: int = 0
	for e in _por_clave.values():
		if e is MaterialItem and e.data != null and e.data.id == data.id:
			u += int(e.n) * e.unidades_crafteo()
	return u


# Las entradas, una por clase. Son las de DENTRO: para leer, no para cambiar su n.
func montones() -> Array:
	return _por_clave.values()


# El peso de todo (lo que diga peso() de cada clase, por su cantidad). Va en cache.
# 'sin_combustible': el carbon no pesa en la bolsa (ver Game.peso_actual).
func peso(sin_combustible: bool = false) -> float:
	if _peso >= 0.0 and not sin_combustible:
		return _peso
	var w: float = 0.0
	for e in _por_clave.values():
		if sin_combustible and e is MaterialItem and e.data != null and int(e.data.tipo) == MaterialData.Tipo.COMBUSTIBLE:
			continue
		w += float(e.peso()) * int(e.get("n"))
	if not sin_combustible:
		_peso = w
	return w


# La lista POR UNIDAD de antes (un objeto por unidad). SOLO para lo que todavia no entiende de montones;
# con el baul real son 19.000 objetos, asi que nada que corra a menudo deberia usarla.
func expandir() -> Array:
	var out: Array = []
	for e in _por_clave.values():
		for i in int(e.get("n")):
			var c: Resource = _copia(e)
			out.append(c)
	return out


# La lista CONTADA (una entrada por clase, cada una con su n), como copias: lo que se guarda y lo que viaja.
func a_lista() -> Array:
	var out: Array = []
	for e in _por_clave.values():
		var c: Resource = _copia(e)
		c.set("n", int(e.get("n")))
		out.append(c)
	return out


func _claves_de_material(data: MaterialData, calidad: int) -> Array:
	var out: Array = []
	for k in _por_clave:
		var e = _por_clave[k]
		if e is MaterialItem and e.data != null and e.data.id == data.id and int(e.calidad) == calidad:
			out.append(k)
	return out


static func _copia(cosa: Resource) -> Resource:
	if cosa is MaterialItem:
		var m := MaterialItem.crear(cosa.data, cosa.calidad)
		m.cm = talla(cosa.cm)
		return m
	var c := Cristal.new()
	c.categoria = cosa.categoria
	c.calidad = cosa.calidad
	return c


func _cambio() -> void:
	version += 1
	_peso = -1.0
