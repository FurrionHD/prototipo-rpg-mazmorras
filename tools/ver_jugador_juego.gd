# ============================================================
#  ver_jugador_juego.gd  --  HERRAMIENTA, no parte del juego.
#
#  Saca una hoja del personaje TAL CUAL SE VE EN LA PARTIDA: montado por MunecoJugador, teñido con
#  su color y pasado por capa_jugador.gdshader. Es el hermano de herramientas/ver_jugador.bat, que enseña el
#  horneado en gris.
#
#  Y NO SOBRA, aunque parezca lo mismo. Los fallos que ha encontrado esta y no la otra:
#    * el tinte multiplicando OSCURECIA el personaje entero (0,48 x 0,45 = 0,21),
#    * el contorno se comia los miembros: en gris pasaba por una linea de dibujo, teñido no,
#    * el antebrazo en tono piel salia como un brochazo claro cruzando el pecho.
#  Todos son de COLOR, y en una hoja gris no existen. La regla que sale de ahi: lo que se juzga en
#  gris es la silueta y el movimiento; lo que se juzga teñido es si se entiende.
#
#  Necesita VENTANA (con --headless no se dibuja nada), asi que va por herramientas/ver_jugador_juego.bat.
#
#    herramientas/ver_jugador_juego.bat [animacion] [direcciones] [arma]
#    herramientas/ver_jugador_juego.bat walk 8               las ocho, un fotograma cada una
#    herramientas/ver_jugador_juego.bat walk 1,2,3           esas tres, con todos sus fotogramas
#    herramientas/ver_jugador_juego.bat guardia 8 espada_larga   con esa arma equipada
#    herramientas/ver_jugador_juego.bat golpe_2m 8 mandoble
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const ZOOM := 3
# El recorte alrededor del personaje, en pixeles de pantalla. Tiene que caber el cuerpo entero con
# margen: el personaje mide 74 px de alto (PoseJugador.ALTO_MUNDO) y la camara del juego va a zoom
# 1.8, asi que en pantalla ocupa ~133. Quedandose corto no da error, simplemente sale decapitado --
# que es lo que pasaba con el 56 de cuando el personaje era la mitad de alto.
const LADO := 176
const FONDO := Color(0.11, 0.12, 0.15)
# El color con el que se tiñe. Uno CUALQUIERA menos el blanco: en blanco el tinte no multiplica nada
# y la hoja seria la gris otra vez, que es justo la que no queremos duplicar.
#
# OJO: DESDE QUE EL CUERPO VA EN COLOR DE PIEL, ESTE ROJO YA NO PINTA NADA. La capa del cuerpo lleva
# "tinte": false (ver JugadorSprites.CAPAS) y el tinte se la salta a proposito. No esta roto: esta
# herramienta seguira siendo la que juzgue el tinte cuando existan las capas de ROPA, que son las que
# se tiñen. Hasta entonces, lo que enseña de util es el shader (que no queme la piel) y la CARA.
const TINTE := Color(0.85, 0.25, 0.22)


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var anim: String = args[0] if args.size() > 0 else "walk"
	# UNA FILA POR MODELO de una pieza que se elige, en cuatro direcciones. Es la hoja con la que se
	# decide un peinado: los seis hay que verlos JUNTOS o cada uno parece bien por su cuenta y luego
	# resulta que tres se leen igual. Es la misma idea que las filas de comparacion de dev_gestos.
	if anim in JugadorSprites.CATALOGO:
		await _hoja_modelos(anim)
		get_tree().quit()
		return
	var dirs: Array = []
	if args.size() > 1 and args[1].contains(","):
		for s in args[1].split(","):
			dirs.append(clampi(int(s), 0, 7))
	else:
		for d in 8:
			dirs.append(d)

	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p == null:
		push_error("[ver jugador juego] no hay Player en la escena")
		get_tree().quit(1)
		return
	Game.player_color = TINTE
	if not Game.tiene_imagen_cuerpo():
		Game.set_imagen_cuerpo(_cara_de_prueba())
	if args.size() > 2:
		_equipar_para_ver(String(args[2]))
	p._pintar_cuerpo()
	# EL JUGADOR REIMPONE SU ANIMACION EN CADA FRAME DE FISICA (ver player._actualizar_animacion), asi
	# que sin pararlo esto captura ocho veces el idle y parece que las direcciones no cambian. Costo
	# una hoja entera de fotos identicas antes de caer.
	p.set_physics_process(false)
	var m = p._muneco
	if m == null or not m.hay_dibujo():
		push_error("[ver jugador juego] el muneco no se ha montado (¿falta hornear?)")
		get_tree().quit(1)
		return

	# Una fila por direccion pedida, una columna por fotograma. Con las ocho direcciones se enseña
	# solo un fotograma de cada (la hoja seria de 64 casillas y no cabe nada).
	var una_sola: bool = dirs.size() >= 8
	var cols: int = 1 if una_sola else 8
	var filas: int = dirs.size() if not una_sola else 1
	var ancho: int = (dirs.size() if una_sola else cols) * LADO
	var out := Image.create(ancho, maxi(1, filas) * LADO, false, Image.FORMAT_RGBA8)
	out.fill(FONDO)
	for i in dirs.size():
		for f in cols:
			var nom: String = "%s_%d" % [anim, int(dirs[i])]
			m.animar(nom)
			m.fijar(nom, f if not una_sola else 2)
			# DOS frames de espera y no uno: el primero aplica el cambio de fotograma y el segundo es
			# el que de verdad lo dibuja. Con uno solo, cada captura salia con la pose ANTERIOR.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			var cx: int = img.get_width() / 2
			var cy: int = img.get_height() / 2
			# El -24 sube el recorte: el nodo del jugador esta a la altura de sus PIES (ver
			# PoseJugador.PIES_BAJO_NODO), asi que centrandolo en el nodo el cuerpo queda en la mitad
			# de arriba y sobra medio recorte de suelo vacio.
			var trozo: Image = img.get_region(Rect2i(cx - LADO / 2, cy - LADO / 2 - 24, LADO, LADO))
			var en := Vector2i(i * LADO, 0) if una_sola else Vector2i(f * LADO, i * LADO)
			out.blit_rect(trozo, Rect2i(0, 0, LADO, LADO), en)
	out.resize(out.get_width() * ZOOM, out.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var ruta: String = "%sjuego_jugador_%s.png" % [SALIDA, anim]
	out.save_png(ruta)
	print("[ver jugador juego] %s · direcciones %s" % [anim, str(dirs)])
	print("[ver jugador juego] ", ProjectSettings.globalize_path(ruta))
	get_tree().quit()


# Una fila por modelo, cuatro direcciones por fila (de frente, en diagonal, de perfil y de espaldas,
# que son las cuatro que de verdad se diferencian).
const DIRS_MODELOS := [0, 1, 2, 4]

func _hoja_modelos(pieza: String) -> void:
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p == null:
		push_error("[ver jugador juego] no hay Player en la escena")
		return
	# LA HOJA DE LA CARA VA SIN FOTO, obligatoriamente: los rasgos dibujados solo se montan cuando NO
	# hay imagen (con foto, tu foto ES tu cara), asi que con la cara de prueba puesta las cuatro filas
	# salian identicas y parecia que los estilos no hacian nada.
	if pieza == "cara":
		Game.set_imagen_cuerpo(PackedByteArray())
	elif not Game.tiene_imagen_cuerpo():
		Game.set_imagen_cuerpo(_cara_de_prueba())
	p.set_physics_process(false)
	var modelos: Array = []
	for m in (JugadorSprites.CATALOGO[pieza]["modelos"] as Dictionary):
		modelos.append(String(m))
	modelos.sort()
	modelos.append("")   # y el "sin nada", que tambien es una opcion del menu
	var out := Image.create(DIRS_MODELOS.size() * LADO, modelos.size() * LADO, false,
		Image.FORMAT_RGBA8)
	out.fill(FONDO)
	var pj: PersonajeData = Game.lider()
	for i in modelos.size():
		var previo: Dictionary = pj.pieza(pieza)
		pj.poner_pieza(pieza, String(modelos[i]), previo["color"], previo["metal"])
		# Remonta la pila de capas: el muñeco solo reconstruye si cambia la lista de claves, y aqui
		# cambia justo eso.
		p._pintar_cuerpo()
		var m2 = p._muneco
		for j in DIRS_MODELOS.size():
			var nom: String = "%s_%d" % ["idle", int(DIRS_MODELOS[j])]
			m2.animar(nom)
			m2.fijar(nom, 2)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			var trozo: Image = img.get_region(Rect2i(img.get_width() / 2 - LADO / 2,
				img.get_height() / 2 - LADO / 2 - 24, LADO, LADO))
			out.blit_rect(trozo, Rect2i(0, 0, LADO, LADO), Vector2i(j * LADO, i * LADO))
	out.resize(out.get_width() * ZOOM, out.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var ruta: String = "%smodelos_%s.png" % [SALIDA, pieza]
	out.save_png(ruta)
	print("[ver jugador juego] %s: %s" % [pieza, str(modelos)])
	print("[ver jugador juego] ", ProjectSettings.globalize_path(ruta))


# UNA CARA DE MENTIRA para cuando la partida no tiene imagen, que es lo normal en esta herramienta:
# arranca sin cargar ninguna, asi que sin esto la capa de la cara no se monta y la hoja no sirve
# para juzgar lo unico nuevo que hay que juzgar.
#
# NO ES UN RETRATO: es un patron a proposito -- fondo de un color, dos ojos y una boca, y una franja
# en la esquina. Lo que hay que poder ver de un vistazo es (a) que la imagen cae DENTRO de la cabeza,
# (b) que se recorta en circulo y no queda cuadrada, y (c) que no sale girada ni del reves. Con una
# foto de verdad, lo tercero no se notaria.
# Equipa un arma (o dos: "daga+daga") por nombre de Tipo, para ver como queda dibujada. Busca el
# .tres cuyo WeaponData.tipo coincide.
func _equipar_para_ver(spec: String) -> void:
	var partes: PackedStringArray = spec.split("+", false)
	var main_tn: String = partes[0] if partes.size() > 0 else ""
	var off_tn: String = partes[1] if partes.size() > 1 else ""
	var pj: PersonajeData = Game.lider()
	var m: WeaponData = _arma_de_tipo(main_tn)
	if m != null:
		pj.equipped_main = m
	var o: WeaponData = _arma_de_tipo(off_tn) if off_tn != "" else null
	if o != null:
		pj.equipped_off = o
	print("[ver jugador juego] arma: %s%s" % [main_tn, (" + " + off_tn) if off_tn != "" else ""])


func _arma_de_tipo(tn: String) -> WeaponData:
	if tn == "" or not ArmaSprites.TIPO_NOMBRE.has(tn):
		return null
	var idx: int = ArmaSprites.TIPO_NOMBRE.find(tn)
	var d := DirAccess.open("res://resources/weapons/")
	if d == null:
		return null
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var w := load("res://resources/weapons/" + f) as WeaponData
		if w != null and int(w.tipo) == idx:
			return w
	return null


func _cara_de_prueba() -> PackedByteArray:
	var n: int = Game.IMAGEN_CUERPO_MAX
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.45, 0.80))
	# La franja de arriba: dice para donde esta el "arriba" de la imagen.
	img.fill_rect(Rect2i(0, 0, n, n / 8), Color(0.95, 0.85, 0.25))
	var ojo: int = n / 10
	img.fill_rect(Rect2i(n / 4 - ojo / 2, n / 2 - ojo, ojo, ojo), Color.BLACK)
	img.fill_rect(Rect2i(3 * n / 4 - ojo / 2, n / 2 - ojo, ojo, ojo), Color.BLACK)
	img.fill_rect(Rect2i(n / 3, 2 * n / 3, n / 3, n / 12), Color(0.85, 0.2, 0.2))
	return img.save_png_to_buffer()
