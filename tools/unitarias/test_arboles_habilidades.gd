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
