# PRUEBA DE DOS JUGADORES, guion de A. POR LA SALA (fase 2, paso 6): A (este proceso) y B entran como clientes en la
# sala de la RANURA 86 (ver prueba_town_sala_comun.gd); lo de dentro de la sala se lee de su registro ([S] dato).
# Comprueba lo que se ve desde A y lo que B apunta en su registro (lineas "[B] ...").
#   0) las fotos de los personajes de casa y el equipo de B
#   1) los dos bajan al piso 1
#   2) DOS PELEAS A LA VEZ, las dos en la sala (etapa 3: cada una con su id)
#   3) B se UNE a la pelea de A y HUYE: la pelea sigue para A
#   4) la arena de pruebas, compartida
extends "res://tools/prueba_town_sala_comun.gd"


func _ready() -> void:
	prefijo = ""
	slot = 86
	puerto = 24601
	registro_b = "user://logs/prueba_jugador_b.log"
	escribir_fase(0)
	if not preparar_mundo(GRUPO_A, CASA_A, GRUPO_B, CASA_B) or not await abrir_sala_y_entrar():
		await _fin()
		return
	# Uno de CASA (no va en el equipo) con foto: B tiene que verle la cara y la foto en Encargos.
	for pj in Game.plantilla:
		if String((pj as PersonajeData).uid) == String(uid_casa["a"]):
			(pj as PersonajeData).set_imagen(foto_de_prueba(Color(0.9, 0.2, 0.2)))
	Net.hogar.marcar_hogar_sucio()
	if not await lanzar_b("prueba_town_dos_cliente"):
		await _fin()
		return

	# 0) LAS FOTOS DEL ROSTER. Los dos subimos la de nuestro personaje de casa a la sala, y cada uno ve la del otro.
	_ok(await hasta_sala("fotos", func(v): return int(v) >= 2, 20.0), "la sala tiene las fotos de los dos (%s)" % dato_sala("fotos"))
	_ok(await _veo_foto_de(String(uid_casa["b"]), 20.0), "veo la cara Y la foto del personaje de casa de B")
	_ok(await _dato_de_b("foto_del_host", 20.0) == 1, "B ve la cara Y la foto de mi personaje de casa")
	_ok(await hasta_sala("reenvio_fotos_igual", func(v): return v != "", 20.0) and dato_sala("reenvio_fotos_igual") == "1",
		"una segunda difusion no reenvia las fotos")

	# 0b) EL EQUIPO DE B (10/10, playtest 09/10): su hogar me llega al entrar SIN que toque nada, con sus dos del equipo
	# marcados. (Sus barras, abajo: salen al bajar al piso.)
	var t := 0.0
	var van_b := 0
	while van_b != 2 and t < 10.0:
		van_b = Net.hogar.roster_hogar().filter(func(f): return String(f.get("dueno", "")) == IDENT_B 			and bool(f.get("en_equipo", false))).size()
		await _esperar(0.5)
		t += 0.5
	_ok(van_b == 2, "me llega el hogar de B al entrar, con sus 2 del equipo (%d, %.1f s)" % [van_b, t])

	# 1) Los dos al piso 1.
	Net.pisos.solicitar_entrar(1)
	escribir_fase(1)
	await _esperar(10.0)
	t = 0.0
	while piso_de_b() != 1 and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	_ok(piso_de_b() == 1, "B esta en el piso 1")
	# Y SU GRUPO EN MI BARRA DE ARRIBA (BarrasOtros, 10/10), con sus numeros.
	t = 0.0
	while Net.jugadores.barras_de_otros().is_empty() and t < 10.0:
		await _esperar(0.5)
		t += 0.5
	var grupos_b: Array = Net.jugadores.barras_de_otros()
	_ok(grupos_b.size() == 1 and (grupos_b[0][1] as Array).size() == 2 and float(grupos_b[0][1][0][4]) > 0.0,
		"me llegan las barras del grupo de B (%s)" % str(grupos_b).left(160))
	var yo: Node = get_tree().get_first_node_in_group("player")
	var bo = yo.get("_barras_otros") if yo != null else null
	await _esperar(0.5)
	_ok(bo != null and bo.ancho() > 0.0, "y salen en mi barra de arriba, detras de las mias")
	await _esperar(3.0)

	# 2) DOS PELEAS A LA VEZ. Abro la mia y B abre la suya: las dos las lleva la sala (etapa 3), cada una con su id.
	var excelia_antes := excelia_grupo()
	await pelear_con(enemigo_libre(Net.posicion_de_peer(_b())))
	var f_mia: int = Net.peleas._pelea_sigo
	_ok(Net.peleas.espejando() and Net.peleas.ejecutor_de(f_mia) == 1, "mi pelea la ejecuta la sala (%d)" % f_mia)
	escribir_fase(2)
	_ok(await hasta_sala("peleas", func(v): return int(v) >= 2, 20.0),
		"DOS peleas a la vez en la sala (%s)" % dato_sala("peleas"))
	var f_b: int = await _dato_de_b("anfitrion_fase2", 20.0)
	_ok(f_b != 0 and f_b != f_mia and Net.peleas.ejecutor_de(f_b) == 1,
		"la de B es OTRA pelea de la sala (%d, la mia %d)" % [f_b, f_mia])
	_ok(await pelear_hasta_el_final(60.0), "mi pelea termina")
	_ok(excelia_grupo() > excelia_antes, "me llega la excelia de mi pelea")
	await _dato_de_b("fase2_fin", 60.0)
	await _esperar(4.0)

	# 3) B se UNE a mi pelea y HUYE. Yo solo DEFIENDO (una rata muere de un golpe y la pelea se acabaria antes).
	await pelear_con(enemigo_libre(Net.posicion_de_peer(_b())))
	var f3: int = Net.peleas._pelea_sigo   # el ID de mi pelea (etapa 3): es lo que lleva cada enemigo en pelea_de
	_ok(Net.peleas.espejando(), "abro la pelea a la que se va a unir B")
	var id_suyo := 0
	t = 0.0
	while id_suyo == 0 and t < 8.0:
		for nid in Net.enemigos._enem_nodos:
			var n = Net.enemigos._enem_nodos[nid]
			if is_instance_valid(n) and int(n.get("pelea_de")) == f3:
				id_suyo = int(nid)
				break
		await _esperar(0.25)
		t += 0.25
	_ok(id_suyo != 0, "veo que enemigo esta en mi pelea (%d)" % id_suyo)
	escribir_fase(3, [id_suyo, f3])
	var p: Node = pantalla()
	var entro_b := false
	var se_fue_b := false
	t = 0.0
	while t < 60.0 and not se_fue_b:
		var dentro: bool = p != null and is_instance_valid(p) and (p.get("_aliados") as Array).size() > 2
		entro_b = entro_b or dentro
		# No actuo hasta que B este dentro: el ATB espera a quien tiene el turno, asi que la pelea se queda
		# quieta y no se acaba antes de que llegue. Luego Defender para alargarla (sin energia, Atacar: si
		# no hago nada la pelea se para en mi turno y a B no le llega nunca el suyo). Y si la rata esta lejos, Atacar
		# tambien esta apagado: Pasar (el sexto boton lejos del muro), o la pelea se queda esperandome (A8, 12/10).
		if entro_b and not pulsar(3) and not pulsar(0):
			pulsar(5)
		se_fue_b = _hay_linea_b("fase3_fin")
		await _esperar(0.25)
		t += 0.25
	_ok(entro_b, "B aparece en mi pelea")
	_ok(se_fue_b and Net.peleas.espejando(), "B huye y la pelea SIGUE para mi")
	_ok(await pelear_hasta_el_final(60.0), "termino la pelea yo solo")

	# 4) LA ARENA DE PRUEBAS, compartida: la lleva la sala y B (que no es el dueño) pone, pelea,
	# limpia y sale sin llevarse nada. Yo entro para ver lo que coloca.
	await _esperar(2.0)
	# Si me ha pillado otra pelea (zona ajena: a B le alcanza un bicho mientras espera), la acabo antes: en pelea no
	# se va a la arena (23/10).
	if Game.hay_pelea_en_pantalla():
		await pelear_hasta_el_final(60.0)
	Game.entrar_arena_de_pruebas()
	escribir_fase(4)
	t = 0.0
	while (Net._mi_lugar != "piso:%d" % Game.PISO_ARENA or piso_de_b() != Game.PISO_ARENA) and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA and piso_de_b() == Game.PISO_ARENA,
		"los dos estamos en la arena (%.1f s)" % t)
	var dueno_arena: int = int(dato_sala("dueno_piso_%d" % Game.PISO_ARENA))
	# Desde la etapa 2 los pisos (tambien la arena) los lleva LA SALA: su dueño es el peer 1.
	_ok(dueno_arena == 1, "la arena la lleva la sala (%d)" % dueno_arena)
	var visto := false
	t = 0.0
	while not visto and t < 30.0:
		for nid in Net.enemigos._enem_nodos:
			var n = Net.enemigos._enem_nodos[nid]
			if is_instance_valid(n) and int(Game.muneco_de(n).get("modo", 0)) == 1:
				visto = true
		await _esperar(0.25)
		t += 0.25
	_ok(visto, "veo el enemigo que ha puesto B, con su muñeco")
	# Mientras B pelea, YO TAMBIEN JUEGO MIS TURNOS (12/10): entro por el mismo sitio que el, y a veces es mi cuerpo
	# el que toca su slime primero. La pelea es entonces mia, B se une, y si yo no pulso nada el trabajador se
	# queda esperandome y la de B no acaba nunca.
	t = 0.0
	while not _hay_linea_b("arena_fin") and t < 120.0:
		var pa: Node = pantalla()
		if pa != null and is_instance_valid(pa):
			if pa.acabada():
				pa._on_continue_pressed()
			elif not pulsar(0):
				pulsar(5)
		await _esperar(0.25)
		t += 0.25
	_ok(await _dato_de_b("arena_fin", 1.0) == 1, "B termina la arena")

	await _fin()


# ¿Ese peer es un trabajador puesto en su piso para peleas? (lo dice la sala)
# Veo la cara y la foto del personaje de casa 'uid' de otro, como las pinta Encargos.
func _veo_foto_de(uid: String, plazo: float) -> bool:
	var t := 0.0
	while t <= plazo:
		for f in Net.hogar.roster_hogar():
			var fila := f as Dictionary
			if String(fila.get("uid", "")) != uid or int(fila.get("imagen_huella", 0)) == 0:
				continue
			var pj: PersonajeData = Net.hogar.pj_de_fila(fila)
			if pj != null and not pj.aspecto.is_empty() and not pj.imagen.is_empty():
				return true
		await _esperar(0.5)
		t += 0.5
	return false
