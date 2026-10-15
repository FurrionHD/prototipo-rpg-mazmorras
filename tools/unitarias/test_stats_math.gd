extends "res://tools/unitarias/caso.gd"
# StatsMath (scripts/core/stats_math.gd): las cuentas de daño, critico, esquiva, huir y radio de movimiento.
# Se prueban PROPIEDADES (paridad, topes, que crezca con la stat, casos extremos), no numeros copiados del
# codigo: asi un retoque de balance en las constantes no rompe el test, pero un fallo de la formula si.

const STATS := [0.0, 1.0, 14.0, 40.0, 120.0, 500.0, 999.0]


func test_dano_sin_defensa_es_el_ataque() -> void:
	cerca(StatsMath.damage(50.0, 0.0), 50.0, 0.0001, "daño(50, def 0)")


func test_dano_baja_con_la_defensa() -> void:
	var antes := INF
	for d in [0.0, 5.0, 30.0, 100.0, 999.0]:
		var x := StatsMath.damage(80.0, d)
		cierto(x < antes or d == 0.0, "con defensa %s el daño (%s) deberia bajar" % [d, x])
		antes = x
	# K/(K+def): con defensa = K se queda en la mitad
	cerca(StatsMath.damage(80.0, StatsMath.MITIGATION_K), 40.0, 0.0001, "defensa = K deja la mitad")


func test_dano_nunca_baja_del_minimo() -> void:
	cerca(StatsMath.damage(0.0, 999.0), 0.1, 0.0001, "ataque 0")
	cerca(StatsMath.damage(-50.0, 0.0), 0.1, 0.0001, "ataque negativo")


func test_critico_en_igualdad_es_la_paridad() -> void:
	for s in STATS:
		cerca(StatsMath.crit_chance(s, s), StatsMath.CRIT_PARITY, 0.0001, "critico con %s contra %s" % [s, s])
		cerca(StatsMath.evade_chance(s, s), StatsMath.EVADE_PARITY, 0.0001, "esquiva con %s contra %s" % [s, s])
		cerca(StatsMath.flee_chance(s, s), StatsMath.FLEE_PARITY, 0.0001, "huir con %s contra %s" % [s, s])


func test_contests_siempre_dentro_de_sus_topes() -> void:
	for a in STATS + [-50.0, 5000.0]:
		for b in STATS + [-50.0, 5000.0]:
			entre(StatsMath.crit_chance(a, b), StatsMath.CRIT_MIN, StatsMath.CRIT_MAX, "critico %s vs %s" % [a, b])
			entre(StatsMath.evade_chance(a, b), StatsMath.EVADE_MIN, StatsMath.EVADE_MAX, "esquiva %s vs %s" % [a, b])
			entre(StatsMath.flee_chance(a, b), StatsMath.FLEE_MIN, StatsMath.FLEE_MAX, "huir %s vs %s" % [a, b])


func test_contests_crecen_con_la_stat_propia() -> void:
	var rival := 120.0
	var c0 := -1.0
	var e0 := -1.0
	var f0 := -1.0
	for s in STATS:
		var c := StatsMath.crit_chance(s, rival)
		var e := StatsMath.evade_chance(s, rival)
		var f := StatsMath.flee_chance(s, rival)
		cierto(c >= c0, "el critico no puede bajar al subir la Destreza (%s)" % s)
		cierto(e >= e0, "la esquiva no puede bajar al subir la Agilidad (%s)" % s)
		cierto(f >= f0, "huir no puede bajar al subir la Agilidad (%s)" % s)
		c0 = c
		e0 = e
		f0 = f


func test_contest_no_satura_al_arrancar() -> void:
	# El suelo comun (CONTEST_BASE) existe para que 0 contra 14 no se trate igual que 0 contra 999.
	# (con huir: la esquiva y el critico a 0 de stat ya tocan su suelo en los dos casos)
	cierto(StatsMath.flee_chance(0.0, 14.0) > StatsMath.flee_chance(0.0, 999.0),
		"huir con 0 contra 14 tiene que ser mas facil que contra 999")


func test_radio_movimiento_en_el_liston_es_la_base() -> void:
	cerca(StatsMath.radio_movimiento(50.0, 50.0), StatsMath.RADIO_MOV_BASE, 0.0001, "agilidad = liston")


func test_radio_movimiento_topes_y_extremos() -> void:
	for ag in [0.0, -10.0, 1.0, 10000.0]:
		entre(StatsMath.radio_movimiento(ag, 50.0), StatsMath.RADIO_MOV_MIN, StatsMath.RADIO_MOV_MAX,
			"radio con agilidad %s" % ag)
	# liston 0 o negativo no puede dividir por cero
	entre(StatsMath.radio_movimiento(30.0, 0.0), StatsMath.RADIO_MOV_MIN, StatsMath.RADIO_MOV_MAX, "liston 0")


func test_radio_movimiento_sobrepeso_va_encima() -> void:
	var lleno := StatsMath.radio_movimiento(50.0, 50.0, 1.0)
	cerca(StatsMath.radio_movimiento(50.0, 50.0, 0.5), lleno * 0.5, 0.0001, "sobrepeso a la mitad")
	cerca(StatsMath.radio_movimiento(50.0, 50.0, 0.0), 0.0, 0.0001, "sobrepeso 0 = no anda")
	cerca(StatsMath.radio_movimiento(50.0, 50.0, 3.0), lleno, 0.0001, "sobrepeso > 1 no da mas paso")


func test_imbuicion_respeta_su_tope() -> void:
	for st in STATS:
		entre(StatsMath.imbue_proc_chance(0.9, st, 0.0), 0.0, StatsMath.IMBUE_PROC_MAX, "hechizo, stat %s" % st)
		entre(StatsMath.imbue_proc_chance(0.9, st, 0.0, true), 0.0, StatsMath.IMBUE_PROC_MAX_ARMA, "arma, stat %s" % st)
	cerca(StatsMath.imbue_proc_chance(0.3, 100.0, 100.0), 0.3, 0.0001, "en igualdad se queda en la base")


func test_mana_por_kill_baja_con_el_corro_y_tiene_suelo() -> void:
	var antes := INF
	for n in range(1, 10):
		var m := StatsMath.mp_kill_mult(n)
		cierto(m <= antes, "el mult no puede subir con mas enemigos (%d)" % n)
		cierto(m >= StatsMath.MP_KILL_MULT_MIN - 0.0001, "el mult no baja del suelo (%d)" % n)
		antes = m
