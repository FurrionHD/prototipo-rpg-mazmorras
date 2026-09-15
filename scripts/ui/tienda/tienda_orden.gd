# ============================================================
#  tienda_orden.gd  --  BUSCADOR, ORDEN Y FILTROS de la tienda (ver shop_menu.gd, que es el armazon).
#
#  Adaptado de la barra del inventario (inventory_menu.gd, "LA BARRA DE ABAJO"), SIN tocar el
#  inventario: alli los criterios estan cosidos a sus pestañas y aqui cada seccion (vender, comprar)
#  trae los suyos. Lo que se comparte es la mecanica:
#    - el estado va POR PANTALLA ("vender_0", "comprar_3"...): el orden que dejaste en Equipo sigue ahi
#      al volver de Consumibles, y lo que buscaste tambien;
#    - dentro de un grupo de filtro es "o" y entre grupos es "y";
#    - volver a elegir el mismo criterio le da la vuelta al sentido.
#
#  Un MONTON es el diccionario que montan las secciones: {modelo, cantidad, origen, ...}. Los numeros
#  que dependen de la seccion (lo que vale, lo que cuesta) se piden a la seccion con precio_unidad(s).
# ============================================================
extends RefCounted

const UMBRAL_ROTA := 0.25   # el mismo escalon del filtro "Rota o casi" del inventario

var _orden: Dictionary = {}     # pantalla -> {campo, desc}
var _filtros: Dictionary = {}   # pantalla -> {grupo: [valores]}
var _texto: Dictionary = {}     # pantalla -> lo escrito en el buscador
# La lista SIN filtrar de la ultima pasada: los recuentos de los chips ("Placas 4") van contra ella,
# o marcar un filtro pondria a cero todos los demas y no habria forma de cambiar de idea.
var sin_filtrar: Array = []


# --- EL BUSCADOR ---------------------------------------------------------

func texto(clave: String) -> String:
	return String(_texto.get(clave, ""))


func poner_texto(clave: String, t: String) -> void:
	_texto[clave] = t


# Sin tildes ni mayusculas: quien busca "pocion" tiene que encontrar la "Poción", y en el movil las
# tildes cuestan un toque largo por letra.
static func normalizar(t: String) -> String:
	var s: String = t.to_lower().strip_edges()
	for par in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"]]:
		s = s.replace(par[0], par[1])
	return s


# --- ORDEN ---------------------------------------------------------------

func orden_de(clave: String, por_defecto: String) -> Dictionary:
	if not _orden.has(clave):
		_orden[clave] = {"campo": por_defecto, "desc": true}
	return _orden[clave]


func pulsar_criterio(clave: String, campo: String, por_defecto: String) -> void:
	var o: Dictionary = orden_de(clave, por_defecto)
	if String(o["campo"]) == campo and campo != "":
		o["desc"] = not bool(o["desc"])
	else:
		o["campo"] = campo
		o["desc"] = true


# El nombre que se enseña en la pastilla de orden, con la flecha del sentido.
func rotulo_orden(clave: String, criterios: Array, por_defecto: String) -> String:
	var o: Dictionary = orden_de(clave, por_defecto)
	var nombre: String = "Predeterminado"
	for c in criterios:
		if String(c["campo"]) == String(o["campo"]):
			nombre = String(c["nombre"])
	if String(o["campo"]) == "":
		return nombre
	return nombre + ("  ↓" if bool(o["desc"]) else "  ↑")


# --- FILTROS -------------------------------------------------------------

func filtros_de(clave: String) -> Dictionary:
	if not _filtros.has(clave):
		_filtros[clave] = {}
	return _filtros[clave]


func hay_filtro(clave: String) -> bool:
	for g in filtros_de(clave).values():
		if not (g as Array).is_empty():
			return true
	return false


func alternar(clave: String, grupo: String, valor: int) -> void:
	var f: Dictionary = filtros_de(clave)
	var lista: Array = f.get(grupo, [])
	if lista.has(valor):
		lista.erase(valor)
	else:
		lista.append(valor)
	f[grupo] = lista


func limpiar(clave: String) -> void:
	_filtros[clave] = {}


func cuantos_con(grupo: String, valor: int) -> int:
	var n: int = 0
	for s in sin_filtrar:
		if valor_filtro(s, grupo) == valor:
			n += 1
	return n


# --- APLICAR -------------------------------------------------------------

# Busca, filtra y ordena, por ese orden (ordenar lo que luego se tira es trabajo tirado). 'seccion' es
# quien sabe el precio y el nombre de cada monton.
func aplicar(clave: String, stacks: Array, seccion, por_defecto: String) -> Array:
	var buscado: String = normalizar(texto(clave))
	var vistos: Array = []
	for s in stacks:
		if buscado == "" or normalizar(seccion.nombre_de(s)).contains(buscado):
			vistos.append(s)
	sin_filtrar = vistos
	var f: Dictionary = filtros_de(clave)
	var out: Array = []
	for s in vistos:
		var pasa: bool = true
		for grupo in f.keys():
			var marcados: Array = f[grupo]
			if not marcados.is_empty() and not marcados.has(valor_filtro(s, String(grupo))):
				pasa = false
				break
		if pasa:
			out.append(s)
	return _ordenar(clave, out, seccion, por_defecto)


func _ordenar(clave: String, stacks: Array, seccion, por_defecto: String) -> Array:
	var o: Dictionary = orden_de(clave, por_defecto)
	var campo: String = String(o["campo"])
	if campo == "":
		return stacks   # predeterminado: el orden en el que la seccion los monta
	var desc: bool = bool(o["desc"])
	# Se calcula UNA vez por monton y no dentro del sort: el precio de una pieza de equipo pasa por su
	# meta y sus mejoras, y sort_custom lo pediria decenas de veces por celda.
	var claves: Array = []
	for i in stacks.size():
		var s: Dictionary = stacks[i]
		claves.append({"i": i, "v": seccion.nombre_de(s) if campo == "nombre" else valor_orden(s, campo, seccion)})
	claves.sort_custom(func(a, b):
		if a["v"] == b["v"]:
			return int(a["i"]) < int(b["i"])   # sort_custom no es estable: a igualdad, el de siempre
		return (a["v"] > b["v"]) if desc else (a["v"] < b["v"]))
	var out: Array = []
	for k in claves:
		out.append(stacks[int(k["i"])])
	return out


# El numero por el que se ordena un monton. Float SIEMPRE (el nombre va aparte): mezclar tipos en un
# sort_custom es la forma mas rapida de que Godot reviente.
func valor_orden(s: Dictionary, campo: String, seccion) -> float:
	var m: Resource = s["modelo"]
	var n: int = maxi(1, int(s.get("cantidad", 1)))
	match campo:
		"cantidad":
			return float(n)
		"precio":
			return float(seccion.precio_unidad(s))
		"valor":
			return float(seccion.precio_unidad(s)) * float(n)
		"peso":
			return _peso(m) * float(n)
		"valor_peso":
			# Lo que renta cada kilo. Peso 0 (el carbon) arriba del todo: renta infinito.
			var p: float = _peso(m)
			return 1e9 if p <= 0.001 else float(seccion.precio_unidad(s)) / p
		"rango":
			return float(IconoItem.escalon(m))
		"tier":
			return float(IconoItem.tier_de(m))
		"rareza":
			return float(Game.meta_de(m)["rareza"]) if _es_equipo(m) else float(IconoItem.escalon(m))
		"mejoras":
			return float(Game.mejoras_actuales(m))
		"durabilidad":
			return Game.durabilidad_item(m) if _es_equipo(m) else 1.0
	return 0.0


func _peso(m: Resource) -> float:
	if m is Cristal:
		return (m as Cristal).peso()
	if m is MaterialItem:
		return (m as MaterialItem).peso()
	return 0.0


static func _es_equipo(m: Resource) -> bool:
	return m is WeaponData or m is ShieldData or m is WandData or m is ArmorData \
		or m is BackpackData or m is ToolData


# El valor de un monton en un eje de filtro. -9999 = no aplica (y ese filtro no lo deja pasar).
func valor_filtro(s: Dictionary, grupo: String) -> int:
	var m: Resource = s["modelo"]
	match grupo:
		"origen":
			# Lo del HOGAR: el baul de materiales (0), el cofre de equipo (1) o el de consumibles (2).
			match String(s.get("origen", "")):
				"hogar": return 0
				"cofre": return 1
				"cofre_c": return 2
			return -9999
		"clase_botin":
			if m is Cristal:
				return 0
			if m is MaterialItem:
				var d: MaterialData = (m as MaterialItem).data
				return 2 if d != null and int(d.tipo) == MaterialData.Tipo.COMBUSTIBLE else 1
			return -9999
		"clase_equipo":
			if m is WeaponData: return 0
			if m is ShieldData: return 1
			if m is WandData: return 2
			if m is ArmorData: return 3
			if m is BackpackData: return 4
			if m is ToolData: return 5
			return -9999
		"clase_consumible":
			var c := m as ConsumableData
			if c == null:
				return -9999
			if c.es_grimorio(): return 2
			if c.es_plato(): return 3
			if c.es_cebo(): return 4
			if c.es_tocho(): return 5
			if c.da_mana() and not c.cura_hp(): return 1
			if c.cura_hp(): return 0
			return 6
		"rango":
			return IconoItem.escalon(m) if (m is MaterialItem or m is MaterialData) else -9999
		"calidad":
			return int((m as MaterialItem).calidad) if m is MaterialItem else -9999
		"rareza":
			return int(Game.meta_de(m)["rareza"]) if _es_equipo(m) else -9999
		"tier":
			return IconoItem.tier_de(m)
		"estado":
			if not _es_equipo(m):
				return -9999
			return 0 if Game.durabilidad_item(m) <= UMBRAL_ROTA else 1
		"material_armadura":
			return int((m as ArmorData).tipo) if m is ArmorData else -9999
		"slot":
			return int((m as ArmorData).slot) if m is ArmorData else -9999
	return -9999


# --- LAS OPCIONES DE CADA GRUPO (las mismas escalas que el inventario) ---

static func ops_rareza() -> Array:
	var out: Array = []
	for r in Upgrades.RAREZA_NOMBRE.size():
		out.append({"nombre": Upgrades.RAREZA_NOMBRE[r], "valor": r})
	return out


static func ops_rango() -> Array:
	var out: Array = []
	for r in 5:
		out.append({"nombre": Upgrades.RAREZA_NOMBRE[r], "valor": r})
	return out


static func ops_tier() -> Array:
	return [{"nombre": "T1", "valor": 1}, {"nombre": "T2", "valor": 2}, {"nombre": "T3", "valor": 3}]


static func ops_calidad() -> Array:
	return [{"nombre": "Puro", "valor": int(MaterialItem.Calidad.PURO)},
		{"nombre": "Intacto", "valor": int(MaterialItem.Calidad.INTACTO)},
		{"nombre": "Normal", "valor": int(MaterialItem.Calidad.NORMAL)},
		{"nombre": "Dañado", "valor": int(MaterialItem.Calidad.DANADO)}]
