# ============================================================
#  dev_maestro.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el menu del MAESTRO DE HABILIDADES de verdad (scripts/ui/maestro_menu.gd) con la partida de
#  prueba (ver PartidaDePrueba) y saca una captura de cada caso que hay que juzgar: el arma que el
#  personaje lleva puesta, una que no, una tecnica ya sabida, y sin dinero para pagar.
#
#  Y comprueba por codigo lo que NO se ve en una foto: que el icono marcado es el del arma que
#  lleva de verdad, que la marca se mueve al cambiar de persona con los retratos, y que aprender
#  cobra una vez y coloca la tecnica si le cabe.
#
#  Va CON VENTANA (nada de --headless): un Control no se coloca ni se dibuja sin superficie de
#  render, y en headless la captura sale en negro. Y con process_mode = ALWAYS, porque el menu
#  PAUSA el arbol al abrirse y sin esto el visor se congela en el primer await.
#
#  Doble clic en herramientas/ver_maestro.bat, o:
#    godot --path . res://tools/visores/dev_maestro.tscn
#  Guarda tools/salida/maestro_*.png y se cierra solo.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
# La partida que se mira. Por preload y no por class_name: ver partida_de_prueba.gd.
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")
# Por preload y NO por class_name, por el mismo motivo que PartidaDePrueba (ver su cabecera).
const Libros = preload("res://scripts/core/libros.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	PartidaDePrueba.llenar()
	# EL PUEBLO DE MENTIRA: aqui no hace falta para el maestro (se aprende donde el maestro esté),
	# pero la ficha de personaje sí lo mira y así las dos herramientas parten de lo mismo.
	if get_tree().current_scene != null:
		get_tree().current_scene.scene_file_path = "res://scenes/town.tscn"

	var men: CanvasLayer = preload("res://scripts/ui/maestro_menu.gd").new()
	add_child(men)
	men.abrir()

	DirAccess.make_dir_recursive_absolute(SALIDA)

	# AL ABRIR, EL ARMA DE SU MANO: el menu no empieza por la primera del catalogo sino por la que
	# lleva puesta, que es lo que uno viene a mirar. Se comprueba aqui y no en la captura porque en
	# la foto no se distingue "abrio por la suya" de "la suya es la primera de la lista".
	_comprobar_arma_inicial(men)
	await _captura("0_arma_puesta")

	# UNA QUE NO LLEVA: las mismas tecnicas, pero la nota de arriba cambia y sigue pudiendo pagar.
	men._arma_idx = _idx_de(men, "hacha")
	men._sel = 0
	men._rebuild()
	await _captura("1_arma_ajena")

	# LA MAGA (retrato 1, con baston): al cambiar de persona la marca tiene que moverse al baston.
	men._pick_persona(1)
	await _captura("2_otra_persona")
	_comprobar_marca(men)

	# APRENDER DE VERDAD, que es lo unico que comprueba que el boton hace algo. Se hace con ELLA y
	# con su BASTON a proposito: el lider se sabe ya todas las tecnicas del baul (ver
	# PartidaDePrueba), y ademas asi se ve el caso bueno -- lleva el arma puesta, asi que la tecnica
	# recien pagada tiene que aparecer SOLA en sus cuatro huecos.
	# "bast" y no "bastón": el trozo se compara contra el NOMBRE del arma, que lleva tilde, y
	# buscando "baston" no casaba nada -- se caia al indice 0 (la daga, que ella no lleva) y la
	# prueba de "se pone sola" fallaba por el motivo correcto sobre el arma equivocada.
	men._arma_idx = _idx_de(men, "bast")
	men._sel = 0
	men._rebuild()
	var pj: PersonajeData = men._pj()
	var antes_dinero: int = Game.money
	var cual: AbilityData = _primera_por_aprender(men)
	if cual == null:
		printerr("[maestro] No hay ninguna tecnica que aprender: la comprobacion no vale.")
	else:
		men._sel = men._tecnicas().find(cual)
		men._rebuild()
		await _captura("3_antes_de_aprender")
		men._aprender(cual)
		await _captura("4_aprendida")
		var pago: int = antes_dinero - Game.money
		if pago != cual.precio:
			printerr("[maestro] MAL: %s cuesta %d y se han cobrado %d." % [cual.nombre, cual.precio, pago])
		elif not Game.habilidad_desbloqueada(cual, pj):
			printerr("[maestro] MAL: se ha cobrado y no la sabe.")
		elif not Game.habilidades_con_huecos(pj).has(cual):
			printerr("[maestro] MAL: lleva el arma y le quedaban huecos, pero %s no se ha puesto sola."
				% cual.nombre)
		else:
			print("[maestro] OK: %s aprende %s por %d y se la pone sola." % [pj.nombre, cual.nombre, pago])

	# LAS DOS SECCIONES NUEVAS. Se miran con la biblioteca A MEDIAS a proposito: con todo leido no
	# se ve el estado "te falta" y con nada leido no se ve el otro, y las dos mitades de esa pantalla
	# hay que juzgarlas juntas.
	# UNO DE CADA TRES, y no los N primeros: la lista empieza por los grimorios, asi que marcando
	# los primeros salian los grimorios completos y las otras dos secciones a cero -- y encima el
	# libro que se abre abajo se buscaba entre los tochos, que no tenian ninguno leido. La foto salia
	# sin la mitad que hay que mirar.
	Game.biblioteca.clear()
	var i_lib: int = 0
	for ruta in Libros.todos():
		var lib: ConsumableData = load(ruta) as ConsumableData
		if lib != null and lib.en_biblioteca():
			if i_lib % 3 == 0:
				Game.biblioteca[lib.tomo_id] = true
			i_lib += 1
	men._tab = 1   # Meditación
	men._rebuild()
	await _captura("6_meditacion")

	# EL GACHA, TIRANDO DE VERDAD. Con dinero de sobra para la x10, que es la tanda que hay que
	# juzgar: el revelado va de una carta en una y el resumen del final enseña las diez.
	Game.money = maxi(Game.money, Game.GACHA_PRECIO_X10 * 3)
	var antes_gacha: int = Game.money
	men._meditar_x10()
	if Game.money != antes_gacha - Game.GACHA_PRECIO_X10:
		printerr("[maestro] MAL: la x10 tenía que cobrar %d y ha cobrado %d." % [
			Game.GACHA_PRECIO_X10, antes_gacha - Game.money])
	elif men._revelado.size() != 10:
		printerr("[maestro] MAL: la x10 ha soltado %d libros." % men._revelado.size())
	else:
		print("[maestro] OK: la x10 cobra %d y reparte 10 libros." % Game.GACHA_PRECIO_X10)

	# EL GUARDADO INSTANTANEO. Es lo que impide rehacer una tirada mala cerrando con alt+F4, asi que
	# se comprueba sobre el DISCO y no sobre la memoria: que el historial ya este en la partida
	# guardada es la unica prueba de que cerrar ahora no borraria nada.
	# Por cabecera() y no cargando la partida: aqui solo hay que LEER lo que hay en el disco, y
	# cargarla de verdad se llevaria por delante la del visor a media prueba.
	#
	# SOLO SI HAY RANURA. La partida de prueba del visor no vive en ninguna (ranura_actual = 0), asi
	# que aqui no se puede comprobar el guardado sin escribir en una ranura de verdad -- y machacar
	# una partida suya para pasar un test seria mucho peor que no probarlo.
	if Perfil.ranura_actual <= 0:
		print("[maestro] (el guardado al tirar no se comprueba: la partida de prueba no tiene ranura)")
	else:
		var guardada: SaveData = Perfil.cabecera(Perfil.ranura_actual)
		if guardada == null:
			printerr("[maestro] MAL: no hay partida guardada; la tirada no se ha escrito.")
		elif guardada.gacha_historial.size() < 10:
			printerr("[maestro] MAL: en el disco hay %d tiradas apuntadas, no las 10."
				% guardada.gacha_historial.size())
		else:
			print("[maestro] OK: la tirada queda guardada al instante (%d en el disco)."
				% guardada.gacha_historial.size())

	# LA PRIMERA CARTA, boca abajo o a medio girar. Si saliera ya destapada, el volteo no estaria
	# corriendo (un tween de un nodo pausado no avanza, y este menu PARA el arbol).
	await _captura("6b_meditacion_carta")

	# SE PASA UNA POR CLIC. Aqui se dan DOS toques por carta a proposito: como el visor no deja correr
	# el tween entre clic y clic, cada carta nace a medio girar, y un toque a media vuelta la TERMINA
	# en vez de saltarsela (si no, un impaciente se salta justo la buena sin verla). El segundo toque
	# es el que pasa a la siguiente. Jugando de verdad el giro ya ha acabado y basta con uno.
	var toques: int = men._revelado.size() * 2 + 1
	for i in toques:
		men._velo_pulsado(_clic())
	if men._res_idx < men._revelado.size():
		printerr("[maestro] MAL: tras %d toques sigue en la carta %d de %d." % [
			toques, men._res_idx, men._revelado.size()])
	elif men._bt_continuar == null or not is_instance_valid(men._bt_continuar):
		printerr("[maestro] MAL: al acabar las cartas no ha salido el resumen.")
	else:
		print("[maestro] OK: se pasa una carta por clic y al final sale el resumen.")
	await _captura("6b1_meditacion_resumen")

	# LA JERARQUIA DE LAS TRES FAMILIAS, con una de cada y a proposito con el GRIMORIO MAS FLOJO que
	# haya. Es la foto que hay que mirar para juzgar que un grimorio comun NO parezca peor premio que
	# un tomo de sabiduria: el color solo no basta (el comun va en gris palido y el sabio en teal),
	# asi que el grimorio lleva ademas el rombo y sus estrellas.
	# Se arma a mano porque una tanda de verdad casi nunca saca las tres juntas.
	var trio: Array = []
	var g_flojo: ConsumableData = null
	for ruta3 in Libros.GRIMORIOS:
		var gg: ConsumableData = load(ruta3) as ConsumableData
		if gg != null and gg.spell != null:
			if g_flojo == null or int(gg.spell.rareza) < int(g_flojo.spell.rareza):
				g_flojo = gg
	var sabio3: ConsumableData = null
	var curio3: ConsumableData = null
	for ruta4 in Libros.TOCHOS:
		var tt: ConsumableData = load(ruta4) as ConsumableData
		if tt == null:
			continue
		if tt.es_tomo_sabio() and sabio3 == null:
			sabio3 = tt
		elif not tt.es_tomo_sabio() and curio3 == null:
			curio3 = tt
	for pieza in [g_flojo, sabio3, curio3]:
		if pieza != null:
			trio.append({"item": pieza, "spell": pieza.spell, "pity": 0})
	if trio.size() == 3:
		print("[maestro] jerarquía: %s (rareza %d) / %s / %s" % [
			g_flojo.nombre, int(g_flojo.spell.rareza), sabio3.nombre, curio3.nombre])
		men._revelado = trio
		men._mostrar_resultados()
		for i in trio.size() * 2 + 1:
			men._velo_pulsado(_clic())
		await _captura("6b3_familias")

	# Y LOS RESULTADOS CERRADOS, que es como se ve el cartel despues de tirar.
	men._cerrar_resultados()
	await _captura("6b2_meditacion_tras_cerrar")

	# EL MODAL DE DETALLES, sus dos pestañas. Es donde vive todo lo que no cabe en la principal, y
	# las dos hay que mirarlas: la de probabilidades por si los porcentajes se salen de la columna,
	# y la del historial porque solo tiene contenido DESPUES de tirar (por eso va aqui abajo).
	men._abrir_detalles()
	await _captura("6c_detalles_probabilidades")
	men._on_modal_tab(1)
	await _captura("6d_detalles_historial")
	men._cerrar_detalles()

	# EL PITY, CON LA CUENTA A PUNTO DE CANTAR. Se fuerza el contador en vez de tirar 49 veces: lo
	# que hay que ver en la foto es el "¡la siguiente!" y las dos filas de garantizado, y llegar ahi
	# tirando cuesta cien mil monedas de mentira.
	var pj_med: PersonajeData = men._pj()
	pj_med.gacha_n50 = Game.GACHA_PITY_EPICO - 1
	pj_med.gacha_n200 = Game.GACHA_PITY_LEGENDARIO - 12
	men._rebuild()
	await _captura("6e_meditacion_pity")

	# Y LA TIRADA GARANTIZADA. Es la unica foto donde se ve la carta BUENA -- nombre del color de su
	# rareza y centelleando -- y hay que forzarla: con el 10% de grimorio, una x10 corriente se queda
	# en diez tochos grises seis de cada diez veces, y esa foto no deja juzgar lo que importa.
	Game.money = maxi(Game.money, Game.GACHA_PRECIO * 3)
	men._meditar_x1()
	if men._revelado.is_empty() or int(men._revelado[0].get("pity", 0)) == 0:
		printerr("[maestro] MAL: con el contador en %d la tirada tenía que ser la garantizada."
			% (Game.GACHA_PITY_EPICO - 1))
	else:
		var s_pity: SpellData = men._revelado[0].get("spell")
		print("[maestro] OK: el garantizado da %s (rareza %d)." % [
			s_pity.nombre if s_pity != null else "?", int(s_pity.rareza) if s_pity != null else -1])
	await _captura("6f_meditacion_garantizado")
	men._tab = 2   # Biblioteca
	men._rebuild()
	await _captura("7_biblioteca")
	# Con un libro ABIERTO, que es donde se lee el texto: la ficha de la derecha es la mitad que
	# justifica la pantalla y sin abrir ninguno no sale en la foto.
	for ruta2 in Libros.TOCHOS:
		var t: ConsumableData = load(ruta2) as ConsumableData
		if t != null and Game.tomo_leido(t.tomo_id):
			men._ver_libro(t)
			break
	# SE COMPRUEBA QUE SE HA ABIERTO. Sin esto, la vez anterior salio una foto identica a la de la
	# lista —no habia ni un tocho leido, asi que no se abrio ninguno— y la ficha de la derecha se
	# quedo sin mirar. Una captura que sale "bien" porque no ha pasado nada es peor que un error.
	if men._libro_abierto == null:
		printerr("[maestro] MAL: no se ha abierto ningún libro; la ficha de la derecha no se ve.")
	else:
		print("[maestro] libro abierto en la ficha: %s" % men._libro_abierto.nombre)
	await _captura("8_biblioteca_abierta")
	men._tab = 0
	men._rebuild()

	# SIN DINERO: los precios en gris y el boton apagado con su motivo.
	Game.money = 0
	men._arma_idx = _idx_de(men, "mandobles")
	men._sel = 0
	men._rebuild()
	await _captura("5_sin_dinero")

	get_tree().quit()


# ¿ABRE POR EL ARMA QUE LLEVA EN LA MANO? Con el lider, que va con espada larga.
func _comprobar_arma_inicial(men: Node) -> void:
	var pj: PersonajeData = men._pj()
	var esperada: String = Game.ruta_base_de(pj.equipped_main) if pj.equipped_main != null else ""
	var abierta: String = String(men._arma().resource_path)
	if esperada == "" or esperada == abierta:
		print("[maestro] OK: abre por %s, que es lo que lleva %s en la mano." % [
			men._arma().nombre, pj.nombre])
	else:
		printerr("[maestro] MAL: %s lleva %s y el menu ha abierto por %s." % [
			pj.nombre, esperada.get_file(), abierta.get_file()])


# ¿LA MARCA ESTA DONDE TIENE QUE ESTAR? En la captura se ve un puntito ambar sobre un icono, pero no
# se puede saber si es el icono correcto: eso se comprueba aqui, contra la RUTA BASE de lo que lleva
# puesto (que es como lo decide el menu, ver maestro_menu._pintar_armas).
func _comprobar_marca(men: Node) -> void:
	var pj: PersonajeData = men._pj()
	var esperadas: Array = []
	for it in [pj.equipped_main, pj.equipped_off]:
		var r: String = Game.ruta_base_de(it) if it != null else ""
		if r != "":
			esperadas.append(r)
	var salen: Array = []
	var todas: Array = men._plantillas()
	for i in todas.size():
		if men._la_lleva(pj, todas[i]):
			salen.append(String(todas[i].resource_path))
	esperadas.sort()
	salen.sort()
	if esperadas == salen:
		print("[maestro] OK: %s lleva %d arma(s) y la fila marca esas mismas." % [
			pj.nombre, salen.size()])
	else:
		printerr("[maestro] MAL: lleva %s y la fila marca %s." % [esperadas, salen])


# El indice de la primera plantilla cuyo nombre contiene 'trozo' (en minusculas). Se busca por
# NOMBRE y no por ruta para que la lista pueda reordenarse sin romper el visor.
func _idx_de(men: Node, trozo: String) -> int:
	var todas: Array = men._plantillas()
	for i in todas.size():
		if String(todas[i].nombre).to_lower().contains(trozo):
			return i
	return 0


# La primera tecnica del arma abierta que este personaje pueda aprender ahora mismo. Si no hay
# ninguna (se las sabe todas), devuelve null y ese trozo de la prueba se salta.
func _primera_por_aprender(men: Node) -> AbilityData:
	var pj: PersonajeData = men._pj()
	for ab in men._tecnicas():
		if not Game.habilidad_desbloqueada(ab, pj) and Game.puede_pagar(ab.precio):
			return ab
	return null


# Un clic de raton, para simular los toques del revelado. Solo el PULSADO: el menu ignora el
# soltado a proposito (un clic manda los dos eventos y si no se comeria dos cartas de golpe).
func _clic() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _captura(nombre: String) -> void:
	# DOS frames: el primero coloca los contenedores (hasta entonces los botones miden 0) y el
	# segundo ya dibuja lo colocado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%smaestro_%s.png" % [SALIDA, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[maestro] ", ProjectSettings.globalize_path(ruta))
