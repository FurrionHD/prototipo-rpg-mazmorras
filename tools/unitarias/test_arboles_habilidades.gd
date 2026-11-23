extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/core/mejoras.gd
# LOS ARBOLES DE HABILIDADES Y MAGIAS (22/11, memoria rangos-magias-y-habilidades): la habilidad montada con los
# nodos de un personaje, su nombre (lo que viaja por la red), lo que pide cada nodo y el dominio.

const Mejoras = preload("res://scripts/core/mejoras.gd")
const Nodo = preload("res://scripts/items/nodo_mejora.gd")
const VENABLO := "res://resources/spells/venablo_de_tormenta.tres"
const RAFAGA_RUTA := "res://resources/abilities/rafaga.tres"


func _nodo(id: String, padres: Array, cambios: Dictionary, nivel := 1, dominio := 0, oro := 0, excluye: Array = []) -> Resource:
	var n: Resource = Nodo.new()
	n.id = StringName(id)
	var ps: Array[StringName] = []
	for p in padres:
		ps.append(StringName(p))
	n.padres = ps
	var ex: Array[StringName] = []
	for x in excluye:
		ex.append(StringName(x))
	n.excluye = ex
	n.cambios = cambios
	n.nivel_min = nivel
	n.dominio = dominio
	n.oro = oro
	return n


# Una copia del Venablo con un arbol de prueba:   a -> b \
#                                                 c ---- d (se junta: basta con b o con c)
func _venablo_con_arbol() -> SpellData:
	var base: SpellData = (load(VENABLO) as SpellData).duplicate(false)
	base.resource_path = "res://pruebas_arbol/venablo_prueba.tres"   # que no pise el de verdad
	base.arbol = [
		_nodo("a", [], {"dano_base": ["mult", 1.10]}),
		_nodo("b", ["a"], {"dano_base": ["mult", 1.10], "coste_mana": ["add", 2]}, 2, 500, 3000),
		_nodo("c", [], {"dano_base": ["mult", 1.05], "forma_radio": ["add", 20.0]}, 1, 0, 0, ["a"]),
		_nodo("d", ["b", "c"], {"dano_base": ["mult", 1.20], "elemento": ["set", 3]}),
	]
	return base


func test_sin_nodos_es_la_ficha() -> void:
	var base := _venablo_con_arbol()
	cierto(Mejoras.montar(base, []) == base, "sin nodos se lleva la ficha tal cual")
	cierto(Mejoras.montar(base, ["no_existe"]) == base, "un nodo que no esta en su arbol no la cambia")


func test_montada_cambia_lo_suyo_y_no_la_ficha() -> void:
	var base := _venablo_con_arbol()
	var d0: float = base.dano_base
	var m: SpellData = Mejoras.montar(base, ["b", "a"]) as SpellData
	cerca(m.dano_base, d0 * 1.10 * 1.10, 0.0001, "a y b multiplican el daño")
	igual(m.coste_mana, base.coste_mana + 2, "b suma maná")
	cerca(base.dano_base, d0, 0.0001, "la ficha no se toca")
	# El NOMBRE: la ficha + los nodos EN EL ORDEN DEL ARBOL (no en el que lleguen), para que dos maquinas den el mismo.
	igual(String(m.resource_path), "res://pruebas_arbol/venablo_prueba.tres#a+b", "su nombre")
	igual(Mejoras.ruta_base(m), "res://pruebas_arbol/venablo_prueba.tres", "la ruta de su ficha")
	igual(String(m.resource_path).get_file().get_basename(), "venablo_prueba", "lo que buscan sellos y sonidos sigue igual")
	cierto(Mejoras.montar(base, ["a", "b"]) == m, "la misma copia mientras viva (se compara por referencia)")
	cierto(Mejoras.cargar(String(m.resource_path)) == m, "por su nombre (lo que llega por la red) sale la misma")


func test_set_y_add_de_lista() -> void:
	var base := _venablo_con_arbol()
	var m: SpellData = Mejoras.montar(base, ["c", "d"]) as SpellData
	igual(m.elemento, 3, "set pone el valor")
	cerca(m.forma_radio, base.forma_radio + 20.0, 0.0001, "add suma")


func test_lo_que_pide_cada_nodo() -> void:
	var base := _venablo_con_arbol()
	var p := PersonajeData.new()
	igual(Mejoras.motivo_no(p, base, &"a", 1, 0), "", "el primero se puede coger")
	igual(Mejoras.motivo_no(p, base, &"b", 5, 99999), "te falta el anterior", "b cuelga de a")
	p.nodos_elegidos[String(base.resource_path)] = ["a"]
	igual(Mejoras.motivo_no(p, base, &"a", 1, 0), "ya lo tienes", "no se coge dos veces")
	igual(Mejoras.motivo_no(p, base, &"b", 1, 99999), "pide nivel 2", "b pide nivel")
	igual(Mejoras.motivo_no(p, base, &"b", 2, 99999), "pide dominio 500", "b pide dominio")
	p.dominio[String(base.resource_path)] = 500
	igual(Mejoras.motivo_no(p, base, &"b", 2, 100), "pide 3000 de oro", "b pide oro")
	igual(Mejoras.motivo_no(p, base, &"b", 2, 3000), "", "con todo, se puede")
	igual(Mejoras.motivo_no(p, base, &"c", 9, 99999), "cierra otra rama", "c no se coge si tienes a")
	# SE JUNTAN: d pide b O c; con b basta.
	igual(Mejoras.motivo_no(p, base, &"d", 1, 0), "te falta el anterior", "d sin b ni c")
	p.nodos_elegidos[String(base.resource_path)] = ["a", "b"]
	igual(Mejoras.motivo_no(p, base, &"d", 1, 0), "", "d con b (basta una de las dos ramas)")


func test_para_combate_y_el_interruptor() -> void:
	var base := _venablo_con_arbol()
	var p := PersonajeData.new()
	p.nodos_elegidos[String(base.resource_path)] = ["a"]
	var m: Resource = Mejoras.para_combate(p, base)
	cierto(m != base and String(m.resource_path).ends_with("#a"), "a la pelea, con sus nodos")
	p.sin_mejoras[String(base.resource_path)] = true
	cierto(Mejoras.para_combate(p, base) == base, "con el interruptor, sin mejoras")


func test_dominio_cuenta_para_la_ficha() -> void:
	var base := _venablo_con_arbol()
	var p := PersonajeData.new()
	var m: Resource = Mejoras.montar(base, ["a"])
	Mejoras.sumar_dominio(p, base)
	Mejoras.sumar_dominio(p, m)   # la montada cuenta para su ficha
	igual(int(p.dominio.get(String(base.resource_path), 0)), 2, "dos usos, a la ficha")


func test_la_red_manda_la_montada_en_texto() -> void:
	var base := _venablo_con_arbol()
	var m: Resource = Mejoras.montar(base, ["a"])
	igual(IdsRed.de_o_texto(m), String(m.resource_path), "lo que lleva estado: el nombre entero")
	var real: Resource = load(RAFAGA_RUTA)
	cierto(IdsRed.de_o_texto(real) is int, "una ficha normal sigue yendo por numero")


func test_el_combatiente_lleva_las_montadas() -> void:
	# Por la fabrica de verdad (Game.crear_player_combatant): un personaje con un nodo en una de sus habilidades.
	var p: PersonajeData = Game.lider()
	var arma_antes = p.equipped_main
	var sabidas_antes: Array = p.habilidades_aprendidas.duplicate()
	p.equipped_main = load("res://resources/weapons/daga.tres")
	p.habilidades_aprendidas = Game.pool_habilidades(p).duplicate()
	var habs: Array = Game.habilidades_con_huecos(p)
	var ab: AbilityData = null
	for h in habs:
		if h != null:
			ab = h
			break
	if not cierto(ab != null, "el lider lleva alguna habilidad"):
		return
	var ruta: String = String(ab.resource_path)
	var arbol_antes: Array = ab.arbol
	var nodos_antes = p.nodos_elegidos.get(ruta)
	ab.arbol = [_nodo("x", [], {"dano_mult": ["mult", 1.5]})]
	p.nodos_elegidos[ruta] = ["x"]
	var c: Combatant = Game.crear_player_combatant(p)
	var montada: AbilityData = null
	for h in c.abilities_combate:
		if h != null and Mejoras.ruta_base(h) == ruta:
			montada = h
	ab.arbol = arbol_antes
	p.equipped_main = arma_antes
	p.habilidades_aprendidas = sabidas_antes
	if nodos_antes == null:
		p.nodos_elegidos.erase(ruta)
	else:
		p.nodos_elegidos[ruta] = nodos_antes
	if cierto(montada != null, "la lleva a la pelea"):
		cerca(montada.dano_mult, ab.dano_mult * 1.5, 0.0001, "con su nodo")
		igual(String(montada.resource_path), ruta + "#x", "y con su nombre")
