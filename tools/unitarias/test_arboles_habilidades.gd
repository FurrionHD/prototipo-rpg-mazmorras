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
	Mejoras.sumar_dominio(p, base, 1, 0.0)
	Mejoras.sumar_dominio(p, m, 1, 0.0)   # la montada cuenta para su ficha
	igual(int(p.dominio.get(String(base.resource_path), 0)), 2, "dos usos, a la ficha")


# EL DOMINIO POR TRAMOS (24/11, el jefe): tramo del piso p = 25(p-1)..25p; debajo 100 %, dentro 70->40 %, en el del piso
# siguiente 20->10 %, mas arriba 0 %.
func test_dominio_por_tramos() -> void:
	igual(Mejoras.prob_dominio(0, 1), 0.7, "piso 1 al empezar: 70 %")
	cierto(absf(Mejoras.prob_dominio(24, 1) - 0.412) < 0.001, "al final de su tramo, casi 40 %")
	igual(Mejoras.prob_dominio(25, 1), 0.2, "en el tramo del piso 2, estando en el 1: 20 %")
	cierto(absf(Mejoras.prob_dominio(49, 1) - 0.104) < 0.001, "y bajando hasta casi 10 %")
	igual(Mejoras.prob_dominio(50, 1), 0.0, "mas arriba, en el piso 1 ya no sube")
	igual(Mejoras.prob_dominio(137, 13), 1.0, "en un piso mas hondo que tu tramo, siempre")
	igual(Mejoras.ritmo_dominio(137, 13), Mejoras.Ritmo.NARANJA, "naranja")
	igual(Mejoras.ritmo_dominio(10, 1), Mejoras.Ritmo.AMARILLO, "amarillo")
	igual(Mejoras.ritmo_dominio(30, 1), Mejoras.Ritmo.VERDE, "verde")
	igual(Mejoras.ritmo_dominio(60, 1), Mejoras.Ritmo.GRIS, "gris")
	# la tirada: por encima de la prob no sube
	var base := _venablo_con_arbol()
	var p := PersonajeData.new()
	cierto(not Mejoras.sumar_dominio(p, base, 1, 0.75), "en el piso 1 con 0, una tirada de 0,75 no sube (70 %)")
	cierto(Mejoras.sumar_dominio(p, base, 1, 0.65), "una de 0,65 si")
	p.dominio[String(base.resource_path)] = 60
	cierto(not Mejoras.sumar_dominio(p, base, 1, 0.0), "gris: ni con la mejor tirada")
	igual(int(p.dominio[String(base.resource_path)]), 60, "se queda en 60")


# SPAMEAR EN EL PISO 1 NO LLEGA al nivel 2 (300): se para en 50.
func test_dominio_no_se_spamea() -> void:
	var base := _venablo_con_arbol()
	var p := PersonajeData.new()
	for i in 5000:
		Mejoras.sumar_dominio(p, base, 1)
	igual(int(p.dominio[String(base.resource_path)]), 50, "5000 usos en el piso 1: 50 y no mas")


# LO SIGUIENTE QUE PIDE (el "137 / 300" de la ficha): el mas bajo de lo que aun no tienes y pide mas de lo que llevas.
func test_dominio_siguiente() -> void:
	var raf: Resource = load(RAFAGA_RUTA)
	var p := PersonajeData.new()
	igual(Mejoras.dominio_siguiente(p, raf), 300, "con 0: el nivel 2, 300")
	p.dominio[RAFAGA_RUTA] = 300
	igual(Mejoras.dominio_siguiente(p, raf), 600, "con 300: el nivel 3, 600")


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


# EL PRESTAMO (24/11): cada nodo fija la potencia de SU nivel desde el nominal (1,4^(nivel-2) x (1 + 0,4 x parte)); lo que
# un nivel dejo sin subir no arrastra al siguiente, y la forma de la rama (mas tajos) va aparte con "mult".
func test_presupuesto_parte_del_nominal() -> void:
	cerca(Mejoras.presupuesto(2, 1.0), 1.4, 0.0001, "nivel 2, todo a daño: x1,4")
	cerca(Mejoras.presupuesto(2, 0.75), 1.3, 0.0001, "nivel 2, 30 de 40: x1,3")
	cerca(Mejoras.presupuesto(3, 1.0), 1.96, 0.0001, "nivel 3, todo: el nominal x1,96")
	cerca(Mejoras.presupuesto(3, 0.5), 1.68, 0.0001, "nivel 3 se mide desde 1,4, no desde lo que se llevo el 2")
	cerca(Mejoras.presupuesto(5, 1.25), 2.744 * 1.5, 0.0001, "puede pasar del 40 % si lo paga con otra cosa")
	var ab: AbilityData = (load(RAFAGA_RUTA) as AbilityData).duplicate(false)
	ab.resource_path = "res://pruebas_arbol/rafaga_prueba.tres"
	var d0: float = ab.dano_mult
	var c0: float = ab.coste_energia
	ab.arbol = [
		_nodo("forma", [], {"golpes_min": ["add", 1], "golpes_max": ["add", 1], "dano_mult": ["mult", 0.75],
			"potencia": ["presupuesto", 0.75], "potencia_coste": ["presupuesto", 1.0]}, 2),
		_nodo("n3", ["forma"], {"potencia": ["presupuesto", 0.5], "potencia_coste": ["presupuesto", 1.0]}, 3),
	]
	var m2: AbilityData = Mejoras.montar_sin_nombre(ab, [ab.arbol[0]]) as AbilityData
	cerca(m2.dano_mult, d0 * 0.75 * 1.3, 0.0001, "nivel 2: la forma y su potencia")
	cerca(m2.coste_energia, roundf(c0 * 1.4), 0.0001, "el coste, al nominal")
	cerca(m2.potencia, 1.0, 0.0001, "la potencia queda horneada")
	var m3: AbilityData = Mejoras.montar_sin_nombre(ab, ab.arbol) as AbilityData
	cerca(m3.dano_mult, d0 * 0.75 * 1.68, 0.0001, "nivel 3: manda su potencia, no se compone con la del 2")
	cerca(m3.coste_energia, roundf(c0 * 1.96), 0.0001, "y el coste del nivel 3")


# LA RAFAGA DE VERDAD (24/11, cerrada con el jefe): los numeros de cada nodo por su camino, y que las dos ramas del nivel 2
# (mas tajos / hoja fina) van a la par en total a un enemigo porque cada una cambia la BASE del tajo, no solo cuantos hay.
func _raf(ids: Array) -> AbilityData:
	var base: AbilityData = load(RAFAGA_RUTA)
	return Mejoras.montar_sin_nombre(base, (base.arbol as Array).filter(func(n): return ids.has(String(n.id)))) as AbilityData


func test_rafaga_numeros_cerrados() -> void:
	var casos := [
		[["mas_tajos"], 0.8775, 4, 67], [["hoja_fina"], 2.106, 2, 67],
		[["mas_tajos", "remolino"], 1.134, 4, 94], [["mas_tajos", "brazo_largo"], 1.2285, 4, 94],
		[["hoja_fina", "mil_cortes"], 2.835, 2, 94], [["hoja_fina", "entrar_bailando"], 2.9484, 2, 94],
		[["mas_tajos", "brazo_largo", "persiguen"], 1.7199, 4, 132],
		[["hoja_fina", "mil_cortes", "remate"], 3.969, 2, 132],
		[["mas_tajos", "brazo_largo", "persiguen", "frenesi"], 2.4078, 4, 184],
		[["hoja_fina", "mil_cortes", "remate", "ligera"], 5.5566, 2, 151],
	]
	for c in casos:
		var m: AbilityData = _raf(c[0])
		cerca(m.dano_mult, float(c[1]), 0.001, "daño de cada tajo con %s" % str(c[0]))
		igual(m.golpes_max, int(c[2]), "tajos con %s" % str(c[0]))
		igual(roundi(m.coste_energia), int(c[3]), "energia con %s" % str(c[0]))
	var muchos: AbilityData = _raf(["mas_tajos", "brazo_largo", "persiguen", "frenesi"])
	var uno: AbilityData = _raf(["hoja_fina", "mil_cortes", "remate", "frenesi"])
	cerca(uno.dano_mult * uno.golpes_max, muchos.dano_mult * muchos.golpes_max * 1.2, 0.01, "nivel 5: a un enemigo, hoja fina +20 %")
	cerca(_raf(["hoja_fina", "mil_cortes"]).efectos_prob_mult * 0.22, 0.38, 0.0001, "Mil cortes: sangrado 22 -> 38 %")
	var base: AbilityData = load(RAFAGA_RUTA)
	for n in base.arbol:
		igual(int(n.dominio), 300 * (int(n.nivel_min) - 1), "dominio de %s por su nivel" % n.id)
		for pa in n.padres:
			cierto(Mejoras.nodo(base, pa) != null, "el padre %s de %s existe" % [pa, n.id])


# CON MUCHOS ENEMIGOS (24/11, el jefe: "ten cuidado con la cantidad que se suman" y "cada una con su identidad"): a uno
# gana hoja fina (+20 %), con 3 casi iguales, con 5 gana mas tajos.
func test_rafaga_muchos_enemigos() -> void:
	var muchos: AbilityData = _raf(["mas_tajos", "brazo_largo", "persiguen", "frenesi"])
	var uno: AbilityData = _raf(["hoja_fina", "mil_cortes", "remate", "frenesi"])
	var total := func(ab: AbilityData, n: int) -> float: return ab.dano_mult * float(ab.num_golpes(1, n))
	cerca(total.call(uno, 1), total.call(muchos, 1) * 1.2, 0.01, "a un enemigo, hoja fina +20 %")
	igual(muchos.num_golpes(1, 3), 7, "mas tajos con 3 enemigos")
	igual(uno.num_golpes(1, 3), 3, "hoja fina con 3 enemigos")
	igual(muchos.num_golpes(1, 5), 11, "mas tajos con 5 enemigos (tope 8)")
	igual(uno.num_golpes(1, 5), 4, "hoja fina con 5 enemigos")
	cerca(total.call(muchos, 3) / total.call(uno, 3), 1.0, 0.1, "con 3, casi iguales")
	cierto(total.call(muchos, 5) > total.call(uno, 5) * 1.1, "con 5, gana mas tajos")
	var b: AbilityData = load(RAFAGA_RUTA)
	cerca(_raf(["mas_tajos"]).dano_mult * _raf(["mas_tajos"]).golpes_extra_por_enemigo,
		b.dano_mult * b.golpes_extra_por_enemigo * 1.25 * 1.3, 0.001, "mas tajos: +25 % de daño por enemigo de mas (x su potencia)")
	cierto(_raf(["hoja_fina"]).dano_mult * _raf(["hoja_fina"]).golpes_extra_por_enemigo
		< b.dano_mult * b.golpes_extra_por_enemigo * 1.3 * 0.8, "hoja fina: menos daño por enemigo de mas (x su potencia)")


# CON DOS DAGAS (24/11, el jefe: "y en dual como quedan?"): con el reparto de golpes de verdad (plan_golpes: la 2a mano pega
# lo que sobra de la principal, a dual_golpe_mult), la misma relacion que con una: a la par a uno, mas tajos por delante en grupo.
func _total_dual(ab: AbilityData, n: int) -> float:
	var t: float = 0.0
	for g in ab.plan_golpes(ab.num_golpes(2, n), 2):
		t += float(g["mult"])
	return t * ab.dano_mult


func test_rafaga_dos_dagas() -> void:
	var muchos: AbilityData = _raf(["mas_tajos", "brazo_largo", "persiguen", "frenesi"])
	var uno: AbilityData = _raf(["hoja_fina", "mil_cortes", "remate", "frenesi"])
	cerca(_total_dual(uno, 1), _total_dual(muchos, 1) * 1.2, 0.02, "dos dagas, a un enemigo, hoja fina +20 %")
	cerca(_total_dual(muchos, 3) / _total_dual(uno, 3), 1.0, 0.1, "con 3, casi iguales")
	cierto(_total_dual(muchos, 5) > _total_dual(uno, 5) * 1.1, "con 5, gana mas tajos")
	var b: AbilityData = load(RAFAGA_RUTA)
	var m2: AbilityData = _raf(["mas_tajos"])
	var h2: AbilityData = _raf(["hoja_fina"])
	# Las dos, a un enemigo y con dos dagas, lo mismo que la base x su potencia (la forma de la rama no regala nada).
	cerca(_total_dual(m2, 1) / 1.3, _total_dual(b, 1), 0.01, "mas tajos con dos dagas = la base x su potencia")
	cerca(_total_dual(h2, 1) / (1.3 * 1.2), _total_dual(b, 1), 0.01, "hoja fina con dos dagas = la base x su potencia x 1,2")


# LA PUÑALADA DE VERDAD (24/11): los numeros por camino, y las mecanicas nuevas (Desangrar, Asesinato).
const PUNALADA_RUTA := "res://resources/abilities/punalada.tres"


func _pun(ids: Array) -> AbilityData:
	var base: AbilityData = load(PUNALADA_RUTA)
	return Mejoras.montar_sin_nombre(base, (base.arbol as Array).filter(func(n): return ids.has(String(n.id)))) as AbilityData


func test_punalada_numeros_cerrados() -> void:
	var casos := [
		[["punto_debil"], 2.88], [["herida_abierta"], 2.88],
		[["punto_debil", "hasta_el_mango"], 4.20], [["herida_abierta", "mano_segura"], 3.696],
		[["herida_abierta", "arteria", "asesinato"], 6.115], [["herida_abierta", "arteria", "desangrar"], 5.645],
		[["herida_abierta", "arteria", "desangrar", "ejecucion"], 7.903],
		[["punto_debil", "por_la_espalda", "asesinato", "golpe_y_fuera"], 8.891],
	]
	for c in casos:
		cerca(_pun(c[0]).dano_mult, float(c[1]), 0.002, "daño de la puñalada con %s" % str(c[0]))
	var h: AbilityData = _pun(["herida_abierta"])
	cerca(h.efectos[0].prob * h.efectos_prob_mult, 0.908, 0.001, "Herida abierta: sangrado 55 -> 91 %")
	cerca(h.efectos[1].prob * h.efectos_prob_mult, 0.495, 0.001, "y la 2a herida 30 -> 50 %")
	igual(_pun(["herida_abierta", "arteria"]).efectos_cargas_extra, 1, "Arteria: una carga mas, cada una su tirada")
	cierto(_pun(["herida_abierta", "mano_segura"]).infalible, "Mano segura no falla")
	var base: AbilityData = load(PUNALADA_RUTA)
	for n in base.arbol:
		igual(int(n.dominio), 300 * (int(n.nivel_min) - 1), "dominio de %s por su nivel" % n.id)


func _bicho(nombre: String) -> Combatant:
	var c := Combatant.new(nombre, 1, Abilities.new(), 1000.0, 10.0, 10.0, 10.0)
	c.max_hp = 1000.0
	c.current_hp = 1000.0
	return c


func test_desangrar_y_asesinato() -> void:
	const Hab = preload("res://scripts/ui/combat_habilidades.gd")
	var e := _bicho("Rata de prueba")
	e.apply_status(StatusEffects.Id.SANGRADO, 3, 10.0)
	e.apply_status(StatusEffects.Id.SANGRADO, 2, 10.0)
	var vida: float = e.current_hp
	var hecho: float = Hab.detonar(e, StatusEffects.Id.SANGRADO)
	cerca(hecho, 10.0 * 3 + 10.0 * 2, 0.01, "Desangrar: cada carga su daño por turno x sus turnos")
	cerca(e.current_hp, vida - hecho, 0.01, "y se lo quita de la vida")
	cierto(not e.has_status(StatusEffects.Id.SANGRADO), "y le quita el sangrado")
	var a: AbilityData = _pun(["herida_abierta", "arteria", "asesinato"])
	var sano := _bicho("Sano")
	var tocado := _bicho("Tocado")
	tocado.current_hp = tocado.max_hp * 0.2
	cerca(Hab.mult_arbol_golpe(a, sano, 0, 0, 0), 1.0, 0.0001, "Asesinato: nada a uno sano")
	cerca(Hab.mult_arbol_golpe(a, tocado, 0, 0, 0), 1.4, 0.0001, "Asesinato: +40 % a uno por debajo del 30 %")


# DESAPARECER Y OPORTUNISTA (24/11): numeros por camino y lo que trae el Sigilo de Desaparecer.
func _mont(ruta: String, ids: Array) -> AbilityData:
	var base: AbilityData = load(ruta)
	return Mejoras.montar_sin_nombre(base, (base.arbol as Array).filter(func(n): return ids.has(String(n.id)))) as AbilityData


func test_desaparecer_y_oportunista() -> void:
	const DES := "res://resources/abilities/desaparecer.tres"
	const OPO := "res://resources/abilities/oportunista.tres"
	cerca(_mont(DES, ["nube_grande"]).dano_mult, 0.72, 0.001, "nube grande 72 %")
	cerca(_mont(DES, ["a_fondo"]).dano_mult, 0.96, 0.001, "a fondo 96 %")
	cerca(_mont(DES, ["a_fondo", "salir_sombras", "desvio", "recarga"]).dano_mult, 1.976, 0.002, "desaparecer nivel 5: 198 %")
	cerca(_mont(DES, ["nube_grande"]).forma_radio, 85.0, 0.01, "la nube, mas grande")
	cerca(_mont(OPO, ["entrar_fondo", "llegar_matando"]).dano_mult, 0.7 * 2.1, 0.002, "llegar matando: el salto 147 %")
	cerca(_mont(OPO, ["mas_huecos", "ojo_halcon", "sin_rastro", "salto_largo"]).dano_mult, 2.497, 0.002, "salto largo 250 %")
	igual(_mont(OPO, ["entrar_fondo"]).oport_usos, 4, "entrar a fondo: 4 entradas")
	cerca(_mont(OPO, ["entrar_fondo"]).oport_seguimiento, 1.0, 0.0001, "y el seguimiento al 100 % del basico")
	var p := _bicho("Daga")
	p.sigilo_extra = {"esquiva": 0.15, "energia": 0.08, "golpe": 0.3}
	cerca(p.sigilo("golpe"), 0.0, 0.0001, "sin Sigilo no trae nada")
	p.apply_status(StatusEffects.Id.SIGILO, 3)
	cerca(p.sigilo("golpe"), 0.3, 0.0001, "con Sigilo, su golpe al salir")
	cerca(p.status_evade_flat(), 0.15, 0.0001, "y la esquiva de Pies en la niebla")
	const Hab = preload("res://scripts/ui/combat_habilidades.gd")
	Hab.gastar_salir_de_sombras(p)
	cierto(not p.has_status(StatusEffects.Id.SIGILO), "al pegar oculto, se sale del Sigilo")


# EL VENENO POR NIVEL Y EL FILO (24/11): la fuerza la pone quien lo sufre (su bando y el tipo), el tipo del Filo por el tier
# del arma, tope 3 dosis, y lo de su arbol.
func test_veneno_por_nivel_y_filo() -> void:
	igual(StatusEffects.veneno_de_tier(1), 1, "T1: Veneno")
	igual(StatusEffects.veneno_de_tier(2), 1, "T2: Veneno")
	igual(StatusEffects.veneno_de_tier(3), 2, "T3: Ponzoña")
	igual(StatusEffects.veneno_nombre(null, 2), "Ponzoña", "su nombre")
	var enemigo := _bicho("Rata")
	enemigo.es_enemigo = true
	enemigo.nivel_piso = 1
	enemigo.apply_status(StatusEffects.Id.VENENO)
	cerca(enemigo.statuses[0].magnitude, 5.0, 0.001, "a un enemigo del nivel 1: 5 por dosis")
	var tuyo := _bicho("Tuyo")
	tuyo.apply_status(StatusEffects.Id.VENENO)
	cerca(tuyo.statuses[0].magnitude, 3.0, 0.001, "a uno de los tuyos del nivel 1: 3 por dosis")
	var e2 := _bicho("Rata 2")
	e2.es_enemigo = true
	e2.apply_status(StatusEffects.Id.VENENO, -1, StatusEffects.VENENO_BASE_DMG * 1.5, 1, false, -1, 0.0, 1.0, -1, 2)
	cerca(e2.statuses[0].magnitude, 70.0 * 1.5, 0.01, "Ponzoña (forzada por el Filo) con su fuerza de mas")
	igual(String(e2.statuses[0].d.get("nombre", "")), "Ponzoña", "y con su nombre")
	for k in 5:
		e2.apply_status(StatusEffects.Id.VENENO)
	igual(e2.stacks_de(StatusEffects.Id.VENENO), 3, "tope de 3 dosis")
	var f: AbilityData = _mont("res://resources/abilities/filo_emponzonado.tres", ["agarra_mejor", "veneno_fuerte", "ponzona_sangre", "senal"])
	cerca(f.imbue_fuerza, 2.744 * 1.2, 0.002, "Filo nivel 5: la fuerza del veneno")
	cerca(f.imbue_prob, 0.85, 0.0001, "agarra mejor")
	cerca(f.imbue_senal, 0.05, 0.0001, "señal del veneno")
	igual(f.imbue_tope(2), 3, "T2: hasta 3 dosis")
	cerca(float(f.imbue_reparto(2)[0]), 0.0, 0.0001, "T2: nunca 1 sola")


# LA LINEA FIJA DEL 6 AL 16 (24/11): +40 % de daño y de coste por nivel sobre el nominal, sobre la forma de su rama.
func test_linea_del_6_al_16() -> void:
	var base: AbilityData = load(RAFAGA_RUTA)
	var ids: Array = ["mas_tajos", "brazo_largo", "persiguen", "frenesi"]
	for nv in range(6, 17):
		ids.append("linea_%d" % nv)
	var m: AbilityData = _raf(ids)
	cerca(m.dano_mult, 0.9 * 0.75 * pow(1.4, 15), 0.01, "nivel 16: la forma de mas tajos x 1,4^15")
	igual(roundi(m.coste_energia), roundi(48.0 * pow(1.4, 15)), "y su coste")
	var l6: Resource = Mejoras.nodo(base, &"linea_6")
	cierto(l6.padres.has(&"frenesi") and l6.padres.has(&"ligera"), "el 6 cuelga de los dos del nivel 5")


# ------------------------------------------------------------ EL ESTOQUE (25/11)
const ESTOCADA_RUTA := "res://resources/abilities/estocada_penetrante.tres"

func _est(ids: Array) -> AbilityData:
	var base: AbilityData = load(ESTOCADA_RUTA)
	return Mejoras.montar_sin_nombre(base, (base.arbol as Array).filter(func(n): return ids.has(String(n.id)))) as AbilityData


# ESTOCADA PENETRANTE (cerrada con el jefe): 180 % de serie; los numeros de la ficha que aprobo.
func test_estocada_numeros_cerrados() -> void:
	const Hab = preload("res://scripts/ui/combat_habilidades.gd")
	var casos := [
		[["sin_armadura"], 2.16, 64], [["atravesar"], 2.16, 64],
		[["sin_armadura", "corazon"], 3.024, 90], [["sin_armadura", "empunadura"], 3.15, 90],
		[["atravesar", "lanza_larga"], 3.276, 90], [["atravesar", "ensartar"], 3.15, 90],
		[["atravesar", "ensartar", "herida_se_abre"], 4.234, 126],
		[["atravesar", "ensartar", "desequilibrio"], 4.410, 126],
		[["sin_armadura", "corazon", "grieta", "a_fondo"], 6.421, 177],
		[["sin_armadura", "corazon", "grieta", "remate"], 5.927, 177],
	]
	for c in casos:
		var m: AbilityData = _est(c[0])
		cerca(m.dano_mult, float(c[1]), 0.003, "daño de la estocada con %s" % str(c[0]))
		igual(roundi(m.coste_energia), int(c[2]), "energia con %s" % str(c[0]))
	var sa: AbilityData = _est(["sin_armadura"])
	cerca(sa.penetracion_extra, 0.45, 0.0001, "Sin armadura: ignora 20 -> 45 % de defensa")
	igual(_est(["atravesar"]).forma_ancho, 24.0, "Atravesar: la linea 8 -> 24 px")
	igual(_est(["atravesar", "lanza_larga"]).forma_radio, 139.0, "Lanza larga: 99 -> 139 px")
	var h: AbilityData = _est(["atravesar", "ensartar", "herida_se_abre"])
	cerca(h.efectos[0].prob * h.efectos_prob_mult, 0.6, 0.001, "Herida que se abre: Vulnerable 30 -> 60 %")
	igual(h.efectos_turnos_enemigo, 2, "y dura 2 turnos mas")
	# la doble: dos golpes, el segundo a la mitad; entre los dos, lo de su nivel (642 %)
	var d: AbilityData = _est(["sin_armadura", "corazon", "grieta", "estocada_doble"])
	igual(d.golpes_max, 2, "Estocada doble: dos golpes")
	cerca(d.dano_mult * 1.5, 6.421, 0.003, "y entre los dos, lo de su nivel")
	cerca(Hab.mult_arbol_golpe(d, null, 1, 0, 1), 0.5, 0.0001, "el segundo, a la mitad")
	cerca(Hab.mult_arbol_golpe(d, null, 0, 0, 1), 1.0, 0.0001, "el primero, entero")
	var base: AbilityData = load(ESTOCADA_RUTA)
	igual(Mejoras.nodo(base, &"linea_6").padres.size(), 3, "la linea del 6 cuelga de los TRES del nivel 5")
	cierto(not (Mejoras.nodo(base, &"grieta").excluye as Array).is_empty() and Mejoras.nodo(base, &"grieta").excluye.size() == 2,
		"Grieta cierra las otras dos del nivel 4")


func _de(ruta: String, ids: Array) -> AbilityData:
	var base: AbilityData = load(ruta)
	return Mejoras.montar_sin_nombre(base, (base.arbol as Array).filter(func(n): return ids.has(String(n.id)))) as AbilityData


# FINTAS (cerrada con el jefe): 120 % por golpe de serie; los de la rama de Acoso llevan su forma x0,93.
func test_fintas_numeros_cerrados() -> void:
	const R := "res://resources/abilities/fintas.tres"
	var casos := [
		[["acoso"], 1.339, 62], [["abanico"], 1.44, 62],
		[["acoso", "buscar_hueco"], 1.719, 86], [["abanico", "mas_fintas"], 1.848, 86],
		[["abanico", "brazo_largo_f"], 2.184, 86], [["abanico", "ninguno_se_libra"], 2.016, 86],
		[["acoso", "ultima_estocada", "finta_enganosa"], 2.734, 121], [["abanico", "mas_fintas", "leer_guardia"], 2.822, 121],
		[["acoso", "buscar_hueco", "finta_enganosa", "ritmo_f"], 3.981, 169],
		[["abanico", "brazo_largo_f", "leer_guardia", "respiracion"], 4.280, 169],
	]
	for c in casos:
		var m: AbilityData = _de(R, c[0])
		cerca(m.dano_mult, float(c[1]), 0.004, "Fintas, daño por golpe con %s" % str(c[0]))
		igual(roundi(m.coste_energia), int(c[2]), "Fintas, energia con %s" % str(c[0]))
	igual(_de(R, ["acoso"]).golpes_si_uno, 1, "Acoso: un golpe mas con uno solo")
	igual(_de(R, ["abanico"]).forma_apertura, 110.0, "Abanico: 60 -> 110 grados")
	igual(_de(R, ["abanico", "mas_fintas", "leer_guardia", "ritmo_f"]).cooldown, 3, "Ritmo: enfriamiento 4 -> 3")
	var f: AbilityData = _de(R, ["acoso", "buscar_hueco", "finta_enganosa"])
	cierto(f.estado_golpe == StatusEffects.Id.VULNERABLE and f.estado_golpe_solo_principal, "Finta engañosa: Vulnerable solo al primero")
	igual(_de(R, ["abanico", "mas_fintas", "leer_guardia"]).estado_golpe, StatusEffects.Id.GUARDIA_LEIDA, "Leer la guardia: su estado")


# DANZA DE ACERO (cerrada con el jefe): 65 % por estocada; la rama de Cuarto tiempo lleva su forma x1,051.
func test_danza_numeros_cerrados() -> void:
	const R := "res://resources/abilities/danza_de_acero.tres"
	var casos := [
		[["cuarto_tiempo"], 0.820, 64], [["danza_ancha"], 0.78, 64],
		[["cuarto_tiempo", "compas"], 1.148, 90], [["danza_ancha", "danza_larga"], 1.183, 90],
		[["danza_ancha", "baile_alimenta"], 1.092, 90],
		[["cuarto_tiempo", "compas", "herida_cruz"], 1.674, 126], [["danza_ancha", "danza_larga", "sin_guardia"], 1.529, 126],
		[["cuarto_tiempo", "remate_baile", "herida_cruz", "ritmo_d"], 2.437, 177],
		[["danza_ancha", "danza_larga", "sin_guardia", "bailar_esquivando"], 2.319, 177],
	]
	for c in casos:
		var m: AbilityData = _de(R, c[0])
		cerca(m.dano_mult, float(c[1]), 0.004, "Danza, daño por estocada con %s" % str(c[0]))
		igual(roundi(m.coste_energia), int(c[2]), "Danza, energia con %s" % str(c[0]))
	# (25/11, tras la tanda: Cuarto tiempo ganaba tambien en grupo) su estocada de mas, SOLO con uno en la linea; DANZA
	# ANCHA, mas estocadas por enemigo (0,7 -> 1, tope 4 -> 6)
	var cu: AbilityData = _de(R, ["cuarto_tiempo"])
	igual(cu.golpes_max, 3, "Cuarto tiempo: las 3 de siempre")
	igual(cu.golpes_si_uno, 1, "y una mas si solo hay uno")
	var an: AbilityData = _de(R, ["danza_ancha"])
	cerca(an.golpes_extra_por_enemigo, 1.0, 0.0001, "Danza ancha: una estocada mas por enemigo de mas")
	igual(an.golpes_extra_max, 6, "hasta 6 de mas")
	igual(_de(R, ["danza_ancha"]).forma_ancho, 36.0, "Danza ancha: 20 -> 36 px")
	igual(_de(R, ["danza_ancha", "danza_larga"]).forma_radio, 160.0, "Danza larga: 119 -> 160 px")


# LAS PIEZAS COMPARTIDAS del estoque, en el golpe: cada golpe mas que el anterior, y el ultimo x1,5.
func test_estoque_golpe_creciente_y_ultimo() -> void:
	const Hab = preload("res://scripts/ui/combat_habilidades.gd")
	var c: AbilityData = _de("res://resources/abilities/danza_de_acero.tres", ["cuarto_tiempo", "compas"])
	cerca(Hab.mult_arbol_golpe(c, null, 0, 0, 3), 1.0, 0.0001, "Compas: el primero, entero")
	cerca(Hab.mult_arbol_golpe(c, null, 2, 0, 3), 1.2, 0.0001, "Compas: el tercero +20 %")
	var u: AbilityData = _de("res://resources/abilities/fintas.tres", ["acoso", "ultima_estocada"])
	cerca(Hab.mult_arbol_golpe(u, null, 0, 0, 2), 1.0, 0.0001, "Ultima estocada: los de antes, enteros")
	cerca(Hab.mult_arbol_golpe(u, null, 2, 0, 2), 1.5, 0.0001, "Ultima estocada: el ultimo x1,5")


# EN GUARDIA (cerrada con el jefe): no pega; cada nivel sube su CAPA de esquiva (20, 22, 24, 26, 28 y +1 en la linea: 39
# en el 16). De serie la barra al 50 % y la habilidad quita la velocidad de mas.
func test_en_guardia_capa_por_nivel() -> void:
	const R := "res://resources/abilities/en_guardia.tres"
	var base: AbilityData = load(R)
	cerca(base.evasion_bonus, 0.20, 0.0001, "de serie, capa del 20 %")
	cerca(base.guardia_spd_mult, 0.5, 0.0001, "de serie, la barra al 50 %")
	cierto(base.guardia_quita_prisa, "la habilidad quita tu velocidad de mas")
	var casos := [
		[["guardia_alta"], 0.22, 56], [["guardia_paciente", "riposte_perfecto"], 0.24, 78],
		[["guardia_alta", "reto", "respiro"], 0.26, 110], [["guardia_paciente", "salir_al_paso", "paciencia_g", "guardia_no_cae"], 0.28, 154],
	]
	for c in casos:
		var m: AbilityData = _de(R, c[0])
		cerca(m.evasion_bonus, float(c[1]), 0.0001, "En guardia, capa con %s" % str(c[0]))
		igual(roundi(m.coste_energia), int(c[2]), "En guardia, energia con %s" % str(c[0]))
		igual(m.dano_mult, 0.0, "y no pega")
	var hasta16: Array = ["guardia_alta", "reto", "respiro", "guardia_no_cae"]
	for nv in range(6, 17):
		hasta16.append("linea_%d" % nv)
	var m16: AbilityData = _de(R, hasta16)
	cerca(m16.evasion_bonus, 0.39, 0.0001, "en el 16, capa del 39 %")
	cerca(m16.evasion_bonus + m16.guardia_capa_extra, 0.47, 0.0001, "y con Guardia alta, 47 %")
	cerca(_de(R, ["guardia_paciente"]).guardia_spd_mult, 0.35, 0.0001, "Guardia paciente: la barra al 35 %")
	igual(_de(R, ["guardia_paciente", "salir_al_paso"]).guardia_paso, 40.0, "Salir al paso: hasta 40 px")
	igual(Mejoras.nodo(base, &"linea_6").padres.size(), 1, "la linea cuelga del unico del nivel 5")


# PASO LIGERO (cerrado con el jefe): la estocada 70 % sube por nivel (84/118/172 y 250 o 240 en el 5), EN 48/67/93/131.
# Presteza mayor sube la Presteza de +25 a +40 % (el nodo pone su fuerza, no toca la ficha).
func test_paso_ligero_numeros() -> void:
	const R := "res://resources/abilities/paso_ligero.tres"
	var base: AbilityData = load(R)
	var casos := [
		[["paso_largo"], 84, 48], [["al_costado", "encadenar"], 118, 67],
		[["paso_largo", "ida_vuelta", "presteza_mayor"], 172, 93],
		[["al_costado", "pasar_cortando", "paso_despista", "recobrar_aliento"], 250, 131],
		[["paso_largo", "esquiva_paso", "presteza_mayor", "paso_guardia"], 240, 131],
	]
	for c in casos:
		var m: AbilityData = _de(R, c[0])
		cerca(m.dano_mult * 100.0, float(c[1]), 0.51, "Paso ligero, daño con %s" % str(c[0]))
		igual(roundi(m.coste_energia), int(c[2]), "Paso ligero, energia con %s" % str(c[0]))
	igual(_de(R, ["paso_largo"]).forma_rango, 100.0, "Paso largo: 60 -> 100 px")
	cierto(_de(R, ["paso_largo", "ida_vuelta"]).vuelve, "Ida y vuelta: vuelve")
	var pm: AbilityData = _de(R, ["paso_largo", "ida_vuelta", "presteza_mayor"])
	cerca(pm.mult_de_efecto(pm.efectos[0]), 1.4, 0.0001, "Presteza mayor: +40 %")
	cerca(base.mult_de_efecto(base.efectos[0]), 0.0, 0.0001, "la ficha sigue con la del catalogo")
	cierto(base.efectos_mult_de.is_empty(), "y su diccionario no se ha tocado al montar")
	cerca(_de(R, ["al_costado", "pasar_cortando"]).corte_al_pasar, 0.3, 0.0001, "Pasar cortando: 30 %")
	cerca(_de(R, ["al_costado", "encadenar"]).descuento_siguiente, 0.2, 0.0001, "Encadenar: -20 %")
	cerca(_de(R, ["al_costado", "encadenar", "paso_despista"]).amenaza_tras_usar, 0.5, 0.0001, "Paso que despista: x0,5")


# ENCADENAR: el coste con el descuento, y sin el, el de siempre.
func test_encadenar_coste() -> void:
	var ab: AbilityData = load("res://resources/abilities/fintas.tres")
	var c := Combatant.new("x", 1, Abilities.new(), 100, 10, 5, 5)
	igual(c.coste_hab(ab, 1), ab.coste(1), "sin descuento, lo de siempre")
	c.descuento_hab = 0.2
	igual(c.coste_hab(ab, 1), roundf(ab.coste(1) * 0.8), "con Encadenar, un 20 % menos")


# PUNZADA AL NERVIO (cerrada con el jefe): golpe 90 % -> 108 / 151 o 139 / 212 o 229 / 296, 274 o 309; EN 59/82/115/161.
# La fuerza y la probabilidad de Debil y Lento las ponen los nodos (efectos_*_de), sin tocar la ficha.
func test_punzada_numeros() -> void:
	const R := "res://resources/abilities/punzada_al_nervio.tres"
	var base: AbilityData = load(R)
	var casos := [
		[["nervio_brazo"], 108, 59], [["nervio_brazo", "temblor"], 151, 82], [["nervio_pierna", "pulso_firme"], 139, 82],
		[["nervio_pierna", "clavado", "cadena_nerviosa"], 212, 115], [["nervio_brazo", "temblor", "larga_p"], 229, 115],
		[["nervio_brazo", "temblor", "atravesar_p", "sobre_lo_tocado"], 296, 161],
		[["nervio_brazo", "temblor", "atravesar_p", "mano_segura"], 274, 161],
		[["nervio_brazo", "temblor", "atravesar_p", "lena_al_caido"], 309, 161],
	]
	for c in casos:
		var m: AbilityData = _de(R, c[0])
		cerca(m.dano_mult * 100.0, float(c[1]), 0.51, "Punzada, daño con %s" % str(c[0]))
		igual(roundi(m.coste_energia), int(c[2]), "Punzada, energia con %s" % str(c[0]))
	var debil = base.efectos[0]
	var lento = base.efectos[1]
	var brazo: AbilityData = _de(R, ["nervio_brazo", "pulso_firme"])
	cerca(brazo.mult_de_efecto(debil), 0.65, 0.0001, "Nervio del brazo: Debil x0,65")
	cerca(brazo.mult_de_efecto(lento), 0.0, 0.0001, "y el Lento, el del catalogo")
	cerca(brazo.prob_de_efecto(debil), 1.0, 0.0001, "Pulso firme: Debil 100 %")
	cerca(brazo.prob_de_efecto(lento), 0.85, 0.0001, "Pulso firme: Lento 85 %")
	cerca(_de(R, ["nervio_pierna"]).mult_de_efecto(lento), 0.60, 0.0001, "Nervio de la pierna: Lento x0,60")
	cerca(base.prob_de_efecto(debil), 0.8, 0.0001, "la ficha sigue con su 80 %")
	cierto(not _de(R, ["nervio_brazo", "temblor", "atravesar_p"]).forma_solo_primero, "Atravesar: a todos los de la linea")
	cierto(_de(R, ["nervio_brazo", "temblor", "atravesar_p", "mano_segura"]).infalible, "Mano segura: infalible")
	var lena: AbilityData = _de(R, ["nervio_brazo", "temblor", "atravesar_p", "lena_al_caido"])
	igual(lena.estado_golpe, int(StatusEffects.Id.MARCA), "Leña al caido: Marca")
	cerca(lena.estado_golpe_mult, 1.10, 0.0001, "al +10 %")


# SOBRE LO TOCADO (Punzada): +30 % al que ya este Debil o Lento; al que no, nada.
func test_sobre_lo_tocado() -> void:
	const Hab = preload("res://scripts/ui/combat_habilidades.gd")
	var ab: AbilityData = _de("res://resources/abilities/punzada_al_nervio.tres",
		["nervio_brazo", "temblor", "atravesar_p", "sobre_lo_tocado"])
	var e := Combatant.new("e", 1, Abilities.new(), 100, 10, 5, 5)
	cerca(Hab.mult_arbol_golpe(ab, e, 0, 0, 0), 1.0, 0.0001, "sin Debil ni Lento, nada")
	e.apply_status(StatusEffects.Id.LENTO, 3)
	cerca(Hab.mult_arbol_golpe(ab, e, 0, 0, 0), 1.3, 0.0001, "Lento: +30 %")
	e.statuses.clear()
	e.apply_status(StatusEffects.Id.DEBIL, 3)
	cerca(Hab.mult_arbol_golpe(ab, e, 0, 0, 0), 1.3, 0.0001, "Debil: +30 %")


# AVANCE CUBIERTO (26/11, estoque + rodela, cerrado con el jefe): rodelazo 90 % (escudo, golpe 0) + estocada 200 % (arma).
const AVANCE_RUTA := "res://resources/abilities/avance_cubierto.tres"

func test_avance_cubierto_numeros() -> void:
	var base: AbilityData = load(AVANCE_RUTA)
	cierto(base.golpe_es_de_escudo(0) and not base.golpe_es_de_escudo(1), "el rodelazo DELANTE, la estocada detras")
	cierto(base.tiene_golpe_de_escudo() and not base.es_toda_de_escudo(), "lleva escudo, pero no es toda de escudo")
	var cl: AbilityData = _de(AVANCE_RUTA, ["carrera_larga"])
	igual(cl.forma_radio, 150.0, "Carrera larga: 110 -> 150 px")
	cerca(cl.dano_mult, 1.3, 0.0001, "y el +30 % del nivel")
	igual(roundi(cl.coste_energia), 81, "58 -> 81 de energia")
	var ra: AbilityData = _de(AVANCE_RUTA, ["rodelazo_aturde"])
	cerca(ra.prob_de_efecto(ra.efectos[0]), 0.45, 0.0001, "Rodelazo que aturde: 45 %")
	cerca(base.prob_de_efecto(base.efectos[0]), 0.2, 0.0001, "la ficha sigue al 20 %")
	var dob: AbilityData = _de(AVANCE_RUTA, ["carrera_larga", "peso_carrera", "doble_estocada"])
	igual(dob.golpes_max, 3, "Estocada doble: 3 golpes")
	igual((dob.mults_golpe as Array).size(), 3, "con su multiplicador")
	cerca(float(dob.mults_golpe[2]), 1.0, 0.0001, "la segunda estocada al 100 % del Ataque")
	igual((base.mults_golpe as Array).size(), 2, "la ficha no se ha tocado")
	cerca(_de(AVANCE_RUTA, ["carrera_larga", "peso_carrera"]).carga_peso_max, 0.3, 0.0001, "Peso de la carrera: hasta +30 %")
	cierto(_de(AVANCE_RUTA, ["carrera_larga", "abrir_guardia"]).escudo_abre_critico, "Abrirle la guardia")
	var arr: AbilityData = _de(AVANCE_RUTA, ["rodelazo_aturde", "arrollar"])
	cierto(arr.forma_escudo_largo > 0.0 and arr.tiron < 0.0, "Arrollar: el escudo a toda la linea, y empuja")
	igual(_de(AVANCE_RUTA, ["rodelazo_aturde", "retar"]).reto_turnos, 2, "Reto: 2 turnos")
	cerca(_de(AVANCE_RUTA, ["rodelazo_aturde", "retar", "escudo_devuelve"]).escudo_contra_extra, 0.35, 0.0001,
		"Escudo que devuelve: +35 %")
	igual(_de(AVANCE_RUTA, ["rodelazo_aturde", "retar", "escudo_devuelve", "llegar_cubierto"]).guardia_turnos_extra, 1,
		"Llegar cubierto: un turno mas")
	igual(Mejoras.nodo(base, &"linea_6").padres.size(), 1, "la linea del 6 cuelga del unico del nivel 5")


# QUE ESCUDO VALE (26/11, el jefe): el Avance cubierto solo con rodela; En guardia con la mano libre o con rodela, y con
# rodela se come la Postura de rodela. La Guardia rota sigue con cualquiera.
func test_estoque_y_escudos() -> void:
	var p: PersonajeData = Game.lider()
	var main_antes = p.equipped_main
	var off_antes = p.equipped_off
	var avance: AbilityData = load(AVANCE_RUTA)
	var guardia: AbilityData = load("res://resources/abilities/en_guardia.tres")
	var postura: AbilityData = load("res://resources/abilities/postura_rodela.tres")
	p.equipped_main = load("res://resources/weapons/estoque.tres")
	p.equipped_off = null
	var pool: Array = Game.pool_habilidades(p)
	cierto(pool.has(guardia) and not pool.has(avance), "estoque solo: En guardia, sin Avance")
	p.equipped_off = load("res://resources/shields/escudo_pequeno.tres")
	pool = Game.pool_habilidades(p)
	cierto(pool.has(guardia) and pool.has(avance), "estoque y rodela: En guardia y Avance cubierto")
	cierto(not pool.has(postura), "y la Postura de rodela no sale (la tapa En guardia)")
	p.equipped_off = load("res://resources/shields/escudo_normal.tres")
	pool = Game.pool_habilidades(p)
	cierto(not pool.has(guardia) and not pool.has(avance), "estoque y escudo normal: ni En guardia ni Avance")
	p.equipped_main = load("res://resources/weapons/espada_larga.tres")
	p.equipped_off = load("res://resources/shields/escudo_pequeno.tres")
	pool = Game.pool_habilidades(p)
	cierto(pool.has(load("res://resources/abilities/guardia_rota.tres")), "la Guardia rota sigue con cualquier escudo")
	cierto(pool.has(postura), "y sin estoque la Postura de rodela sale")
	p.equipped_main = main_antes
	p.equipped_off = off_antes


# LA ESPADA CORTA (26/11, cerrada con el jefe): los numeros de sus arboles.
const ESPADA := "res://resources/abilities/%s.tres"

func test_espada_corta_numeros() -> void:
	var Q: String = ESPADA % "tajo_quebrantador"
	var af: AbilityData = _de(Q, ["tajo_a_fondo"])
	igual(af.forma_apertura, 60.0, "Tajo a fondo: cono de 60 grados")
	igual(af.forma_radio, 99.0, "y 30 px mas largo")
	cerca(af.dano_mult, 2.0 * 1.1 * 1.2, 0.0001, "x1,1 y el +20 % del nivel")
	igual(roundi(af.coste_energia), 67, "48 -> 67 de energia")
	cerca(_de(Q, ["barrido_ancho", "exponer_mas"]).mult_de_efecto(af.efectos[0]), 0.70, 0.0001, "Exponer mas: Vulnerable al 70 %")
	cerca(_de(Q, ["barrido_ancho", "abrir_a_todos"]).efectos_prob_mult, 2.0, 0.0001, "Abrir a todos: x2")
	igual(_de(Q, ["tajo_a_fondo", "romper_guardia", "mano_rapida_q"]).cooldown, 4, "Mano rapida: recarga 4")
	cierto(_de(Q, ["tajo_a_fondo", "romper_guardia", "mano_rapida_q", "desarmar_guardia"]).quita_guardia, "Desarmar la guardia")
	var D: String = ESPADA % "doble_tajo"
	igual(_de(D, ["tercer_tajo"]).golpes_si_uno, 1, "Tercer tajo: uno mas con uno solo")
	cerca(_de(D, ["mas_tajos"]).golpes_extra_por_enemigo, 1.0, 0.0001, "Mas tajos: 1 por enemigo")
	cerca(_de(D, ["tercer_tajo", "remate_combo"]).ultimo_golpe_mult, 1.5, 0.0001, "Remate del combo: x1,5")
	cerca(_de(D, ["mas_tajos", "abanico_d", "filo_sangra", "respiracion_d"]).energia_por_critico, 0.05, 0.0001, "Respiracion")
	var C: String = ESPADA % "cambio_de_ritmo"
	igual(_de(C, ["acelerar"]).reduce_cooldowns, 2, "Acelerar: -2 esperas")
	var pr: AbilityData = _de(C, ["encadenar_r", "ancho_r", "esquivar_cruzar", "presteza_r"])
	igual(pr.estado_propio, int(StatusEffects.Id.PRESTEZA), "Presteza: el estado propio")
	cerca(pr.descuento_siguiente, 0.2, 0.0001, "Encadenar: -20 %")
	igual(pr.forma_ancho, 28.0, "Ancho: 28 px")
	var S: String = ESPADA % "senalar_el_hueco"
	var sm: AbilityData = _de(S, ["marca_honda"])
	cerca(sm.mult_de_efecto(sm.efectos[0]), 1.40, 0.0001, "Marca honda: x1,40")
	igual(_de(S, ["marca_larga"]).efectos_turnos_enemigo, 2, "Marca larga: +2 turnos")
	cierto(_de(S, ["marca_larga", "orden_ataque"]).marca_orden, "Orden de ataque")
	cerca(_de(S, ["marca_honda", "ojo_duelista"]).marca_ojo_critico, 0.15, 0.0001, "Ojo de duelista: +15")
	cierto(_de(S, ["marca_larga", "a_por_el", "sin_fallo", "caza"]).recarga_si_cae_marcado, "Caza")
	var T: String = ESPADA % "corte_de_tendones"
	igual(_de(T, ["barrido_bajo"]).forma_apertura, 220.0, "Barrido bajo: 220 grados")
	igual(_de(T, ["brazo_largo_t", "al_que_cojea", "arrodillar"]).retrasa_si_estado, int(StatusEffects.Id.LENTO), "Arrodillar")
	cerca(_de(T, ["brazo_largo_t", "al_que_cojea", "presa_facil"]).presa_facil, 0.05, 0.0001, "Presa facil")
	cerca(_de(T, ["barrido_bajo", "sin_curarse"]).herida_cura_duele, 0.5, 0.0001, "Sin poder curarse")
	cerca(_de(T, ["brazo_largo_t", "al_que_cojea", "presa_facil", "clavarlo"]).enraiza_si_lento, 0.5, 0.0001, "Clavarlo")
	cierto(_de(D, ["mas_tajos", "abanico_d", "furia_filo"]).furia_por_enemigo, "Furia de filo")
	cierto(_de(D, ["tercer_tajo", "remate_combo"]).golpe_si_mata_ultimo, "Remate del combo: y si tumba, sigue")


# +X % AL QUE LLEVA EL ESTADO (Romper la guardia, Sobre lo marcado, Al que cojea); al que no, nada.
func test_extra_si_estado() -> void:
	const Hab = preload("res://scripts/ui/combat_habilidades.gd")
	var ab: AbilityData = _de(ESPADA % "tajo_quebrantador", ["tajo_a_fondo", "romper_guardia"])
	var e := Combatant.new("e", 1, Abilities.new(), 100, 10, 5, 5)
	cerca(Hab.mult_arbol_golpe(ab, e, 0, 0, 0), 1.0, 0.0001, "sin Vulnerable, nada")
	e.apply_status(StatusEffects.Id.VULNERABLE, 3)
	cerca(Hab.mult_arbol_golpe(ab, e, 0, 0, 0), 1.4, 0.0001, "Vulnerable: +40 %")
