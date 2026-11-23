extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/core/basico_arbol.gd
# EL ARBOL DEL BASICO (23/11, memoria rangos-magias-y-habilidades): la linea (pisos 4/8/12 de cada nivel), los puntos de
# facultad, lo que pide cada paso, el primer punto exclusivo, lo que lleva cada mano a la pelea y lo que hacen en el golpe
# las facultades que van por el calculo (Rompearmadura, Firmeza, Cerrojo).

const BasicoArbol = preload("res://scripts/core/basico_arbol.gd")
const T := WeaponData.Tipo


func test_la_linea_de_daño() -> void:
	cerca(BasicoArbol.mult_dano(0), 1.0, 0.0001, "sin pasos, 100 %")
	cerca(BasicoArbol.mult_dano(1), 1.15, 0.0001, "piso 4: 115 %")
	cerca(BasicoArbol.mult_dano(2), 1.20, 0.0001, "piso 8: 120 %")
	cerca(BasicoArbol.mult_dano(3), 1.40, 0.0001, "piso 12: 140 % (el x1,4 del nivel siguiente)")
	cerca(BasicoArbol.mult_dano(4), 1.40 * 1.15, 0.0001, "nivel 2, piso 4: 161 %")
	cerca(BasicoArbol.mult_dano(6), 1.96, 0.0001, "nivel 2 completo: 196 %")


func test_la_linea_de_energia_y_los_puntos() -> void:
	cerca(BasicoArbol.mult_energia(0), 1.0, 0.0001, "sin pasos")
	cerca(BasicoArbol.mult_energia(1), 1.0, 0.0001, "el piso 4 no da energia")
	cerca(BasicoArbol.mult_energia(2), 1.10, 0.0001, "piso 8: +10 %")
	cerca(BasicoArbol.mult_energia(3), 1.15, 0.0001, "piso 12: +5 % mas")
	cerca(BasicoArbol.mult_energia(5), 1.25, 0.0001, "nivel 2, piso 8")
	igual(BasicoArbol.puntos(2), 0, "sin el piso 12, ningun punto")
	igual(BasicoArbol.puntos(3), 1, "el primer punto con el piso 12")
	igual(BasicoArbol.puntos(12), 4, "4 niveles completos, 4 puntos")


func test_lo_que_pide_cada_paso() -> void:
	igual(BasicoArbol.motivo_no_paso(0, 1, 3, 99999), "pide llegar al piso 4", "el primero, en el piso 4")
	igual(BasicoArbol.motivo_no_paso(0, 1, 4, 99999), "", "llegado al 4, se puede")
	igual(BasicoArbol.motivo_no_paso(2, 1, 12, 99999), "pide nivel 2", "el del piso 12 pide subir de nivel")
	igual(BasicoArbol.motivo_no_paso(2, 2, 12, 99999), "", "ya en nivel 2")
	igual(BasicoArbol.motivo_no_paso(3, 2, 12, 99999), "pide llegar al piso 16", "el primero del nivel 2, en el 16")
	cierto(BasicoArbol.motivo_no_paso(0, 1, 4, 0).begins_with("pide "), "sin oro no")


func test_el_primer_punto_es_exclusivo() -> void:
	var d := {"pasos": 6, "fac": {}}
	igual(BasicoArbol.motivo_no_facultad(T.DAGA, d, "ensanamiento"), "el primer punto va a una de las dos primeras", "comun sin exclusiva")
	igual(BasicoArbol.motivo_no_facultad(T.DAGA, d, "sangrado"), "", "una exclusiva, si")
	d["fac"] = {"sangrado": 1}
	cierto(BasicoArbol.motivo_no_facultad(T.DAGA, d, "doble").begins_with("cerrada"), "la otra exclusiva se cierra")
	igual(BasicoArbol.motivo_no_facultad(T.DAGA, d, "ensanamiento"), "", "ya puede ir a una comun")
	d["fac"] = {"sangrado": 1, "ensanamiento": 1}
	igual(BasicoArbol.motivo_no_facultad(T.DAGA, d, "sangrado"), "no te quedan puntos", "2 puntos con 6 pasos")
	d = {"pasos": 30, "fac": {"sangrado": 5}}
	igual(BasicoArbol.motivo_no_facultad(T.DAGA, d, "sangrado"), "ya está al máximo", "tope de rango 5")


func test_todas_las_armas_tienen_dos_y_dos() -> void:
	for tipo in BasicoArbol.FACULTADES:
		var ex: int = 0
		var co: int = 0
		for f in BasicoArbol.facultades(tipo):
			if bool(f.get("excl", false)):
				ex += 1
			else:
				co += 1
			igual((f["v"] as Array).size(), 5, "%s: cinco rangos" % f["id"])
			cierto(not BasicoArbol.frase(tipo, String(f["id"]), 1).contains("{"), "%s: su frase sin huecos" % f["id"])
		igual(ex, 2, "tipo %d: dos exclusivas" % tipo)
		igual(co, 2, "tipo %d: dos comunes" % tipo)


func test_la_frase_sale_del_dato() -> void:
	igual(BasicoArbol.frase(T.ESTOQUE, "filo_certero", 1), "Los críticos del básico hacen un 10 % más de daño.", "rango 1")
	igual(BasicoArbol.frase(T.ESTOQUE, "filo_certero", 5), "Los críticos del básico hacen un 26 % más de daño.", "rango 5")


func test_lo_que_lleva_la_mano() -> void:
	var m: Dictionary = BasicoArbol.de_mano({"pasos": 4, "fac": {"furia": 2}}, T.HACHA_GRANDE)
	cerca(float(m["dano"]), 1.40 * 1.15, 0.0001, "su daño")
	cerca(float(m["fac"]["furia"]), 0.25, 0.0001, "Furia rango 2")
	var b: Dictionary = BasicoArbol.de_mano({"pasos": 4, "fac": {}}, T.BASTON)
	cerca(float(b["dano"]), 1.0, 0.0001, "el baston no sube daño")
	cerca(float(b["mana_extra"]), 0.01, 0.0001, "dos pasos de piso 4: +1 punto de mana")
	cerca(float(b["marca"]), BasicoArbol.MARCA_BASTON, 0.0001, "con un piso 12, la marca")


func test_la_mano_del_combatiente() -> void:
	var p: PersonajeData = Game.lider()
	var antes_main = p.equipped_main
	var antes_off = p.equipped_off
	var antes_arbol: Dictionary = p.basico_arbol.duplicate(true)
	p.equipped_main = load("res://resources/weapons/daga.tres")
	p.equipped_off = load("res://resources/weapons/espada_corta.tres")
	p.basico_arbol = {str(T.DAGA): {"pasos": 3, "fac": {"sangrado": 1}}, str(T.ESPADA_CORTA): {"pasos": 1, "fac": {}}}
	var c: Combatant = Game.crear_player_combatant(p)
	cerca(float(c.arbol_mano().get("dano", 0.0)), 1.40, 0.0001, "la principal, con lo de la daga")
	cerca(c.fac("sangrado"), 0.10, 0.0001, "su facultad")
	c.advance_hand()
	cerca(float(c.arbol_mano().get("dano", 0.0)), 1.15, 0.0001, "la otra mano, con lo de la espada corta")
	cerca(c.fac("sangrado"), 0.0, 0.0001, "y sin la facultad de la daga")
	p.equipped_main = antes_main
	p.equipped_off = antes_off
	p.basico_arbol = antes_arbol


func test_enfriamiento() -> void:
	var c := Combatant.new("x", 1, Abilities.new(), 100, 10, 5, 5)
	c.hands = [{"motion_value": 1.0, "ataque_arma": 1.0, "crit_bonus": 0.0, "dano_tipo": 0, "aturdir_base": 0.0,
		"nombre": "x", "arbol": {"tipo": T.DAGA, "fac": {"abrir_herida": 0.25}, "rangos": {"abrir_herida": 1}}}]
	cierto(c.fac_lista("abrir_herida"), "lista al empezar")
	c.fac_enfriar("abrir_herida", 2)
	cierto(not c.fac_lista("abrir_herida"), "recien usada, no")
	c.fac_turno()
	cierto(not c.fac_lista("abrir_herida"), "un turno despues, tampoco")
	c.fac_turno()
	cierto(not c.fac_lista("abrir_herida"), "dos turnos despues, tampoco")
	c.fac_turno()
	cierto(c.fac_lista("abrir_herida"), "al tercero, otra vez")


func _muneco(defensa: float) -> Combatant:
	var c := Combatant.new("m", 1, Abilities.new(), 1000, 10, defensa, 5)
	c.hands = [{"motion_value": 1.0, "ataque_arma": 30.0, "crit_bonus": 0.0, "dano_tipo": 0, "aturdir_base": 0.0, "nombre": "m"}]
	c._apply_hand(0)
	return c


# La media de muchos golpes sin esquiva ni critico (la variacion se va).
func _media(a: Combatant, d: Combatant, defending := false) -> float:
	var s: float = 0.0
	var n: int = 0
	for i in 400:
		var r: Dictionary = StatsMath.resolve_attack(a, d, defending, -1.0, -1.0, 0.0, false)
		if not bool(r.crit):
			s += float(r.damage)
			n += 1
		d.fac_firmeza = 0.0
	return s / maxf(1.0, float(n))


func test_rompearmadura_firmeza_y_cerrojo() -> void:
	var a := _muneco(5.0)
	var d := _muneco(40.0)
	var normal: float = _media(a, d)
	d.rompe_armadura_n = 3
	d.rompe_armadura_valor = 0.08
	cierto(_media(a, d) > normal * 1.02, "con la armadura rajada le entra mas")
	d.rompe_armadura_n = 0
	d.fac_firmeza = 0.30
	var r: Dictionary = StatsMath.resolve_attack(a, d, false, -1.0, -1.0, 0.0, false)
	cierto(d.fac_firmeza == 0.0, "Firmeza se gasta con el golpe")
	cierto(float(r.damage) < normal, "y ese golpe hace menos")
	d.defend_block = 0.45
	var defendiendo: float = _media(a, d, true)
	d.fac_cubierto = 0.10
	var cubierto: float = _media(a, d)
	cierto(cubierto < normal * 0.8, "cubierto bloquea sin defender")
	cierto(cubierto < defendiendo, "y algo mas que defender a secas")


# LA FICHA DEL BASICO en la pantalla del arbol y el ARBOL como se ve (23/11, el dibujo del jefe): las dos principales,
# luego las dos secundarias por nivel, con los pisos 4 y 8 en linea; coger un nodo del piso 12 es su paso.
func test_la_ficha_y_el_arbol_del_basico() -> void:
	var ArbolUI = load("res://scripts/ui/arbol_mejoras_ui.gd")
	var ui = ArbolUI.new(null)
	var pj := PersonajeData.new()
	pj.level = 2
	pj.piso_hondo = 12
	pj.basico_arbol = {str(T.MAZA_PEQ): {"pasos": 2, "fac": {}, "elec": []}}
	var maza: WeaponData = load("res://resources/weapons/maza_peq.tres")
	var arb: Dictionary = ui._nodos_basico(pj, maza)
	igual((arb["nodos"] as Array).size(), 16, "por nivel: pisos 4 y 8 y las dos del piso 12, cuatro niveles")
	cierto(arb["estados"].has("c3_cerrojo") and arb["estados"].has("c3_martilleo"), "sin principal aun, el nivel 5 enseña las dos")
	igual(String(arb["estados"]["c0_cerrojo"]), "puedes" if Game.money >= BasicoArbol.oro_paso(2) else "falta", "la principal, a por ella")
	igual(String(arb["estados"]["c1_machacar"]), "falta", "la del nivel 3, aun no")
	igual(String(arb["estados"]["l0"]), "tuyo", "el piso 4, comprado")
	igual(String(arb["estados"]["l3"]), "falta", "el piso 16, aun no")
	var content := VBoxContainer.new()
	ui._pintar_ficha_basico(content, pj, maza)
	var todo: String = _textos(content)
	cierto(todo.contains("Clica un nodo"), "todo se compra en el arbol")
	cierto(not todo.contains("{"), "sin huecos sin rellenar")
	content.free()
	ui.nodo_sel = &"c0_martilleo"
	var c1 := VBoxContainer.new()
	ui._pintar_ficha_basico(c1, pj, maza)
	var t1: String = _textos(c1)
	cierto(t1.contains("Martilleo") and t1.contains("Mejorar ("), "elegido un nodo: lo que hace y pagarlo")
	c1.free()
	# Cogida la principal: la otra, cerrada; y lo cogido sube el rango y los pasos.
	var d2: Dictionary = BasicoArbol.con_nodo(Game.basico_de(T.MAZA_PEQ, pj), "cerrojo")
	igual(int(d2["pasos"]), 3, "coger el nodo es el paso del piso 12")
	igual(int(d2["fac"]["cerrojo"]), 1, "rango 1")
	pj.basico_arbol = {str(T.MAZA_PEQ): d2}
	var arb2: Dictionary = ui._nodos_basico(pj, maza)
	igual(String(arb2["estados"]["c0_martilleo"]), "cerrado", "la otra principal se cierra")
	igual(String(arb2["estados"]["c0_cerrojo"]), "tuyo", "la cogida")
	cierto(arb2["estados"].has("c3_cerrojo") and not arb2["estados"].has("c3_martilleo"), "el nivel 5: solo tu principal")
	ui.nodo_sel = &""
	var c2 := VBoxContainer.new()
	pj.basico_arbol = {str(T.BASTON): {"pasos": 1, "fac": {}, "elec": []}}
	ui._pintar_ficha_basico(c2, pj, load("res://resources/weapons/baston.tres"))
	var t2: String = _textos(c2)
	cierto(t2.contains("Maná al acertar") and not t2.contains("Daño del básico"), "el baston enseña su mana, no su daño")
	c2.free()


# Todo el texto de lo que cuelga de 'n' (las filas son cajas con sus etiquetas dentro).
func _textos(n: Node) -> String:
	var t: String = ""
	for h in n.get_children():
		if h is Label:
			t += (h as Label).text + "\n"
		elif h is Button:
			t += "[" + (h as Button).text + "]\n"
		t += _textos(h)
	return t
