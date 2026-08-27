# ============================================================
#  dev_hornear.gd  --  HERRAMIENTA, no parte del juego.
#
#  Dibuja todos los sprites generados y los deja en disco como PNG normales, en
#  assets/sprites/enemigos/. A partir de ahi el juego los CARGA en vez de dibujarlos, que es la
#  diferencia entre milisegundos y ~3 segundos por partida.
#
#  SE EJECUTA A MANO, con hornear_sprites.bat, y hay que volver a pasarlo CADA VEZ que se toque un
#  generador de sprites o SpriteLienzo.UNIDADES_POR_CELDA. Si se olvida no se rompe nada: el juego
#  detecta que falta esa variante y la dibuja al vuelo como siempre (ver SpritesEnemigo.frames_de),
#  solo que pagando el rato de generarla.
#
#  Recorre TODOS los EnemyData del proyecto, asi que un bicho nuevo entra solo en cuanto tenga
#  generador: no hay una lista que mantener aparte.
# ============================================================
extends Node

const FICHAS := "res://scenes/actors/enemy/"
# Cuantas 't' se prueban por enemigo. 't' solo entra por color_visual, que es monotona, y tras
# cuantizar deja 3-4 escalones: con 24 muestras se cubren todos de sobra.
const MUESTRAS := 24


func _ready() -> void:
	print("=== HORNEANDO SPRITES ===")
	var d := DirAccess.open(FICHAS)
	if d == null:
		push_error("[horno] no encuentro %s" % FICHAS)
		get_tree().quit(1)
		return
	var rutas: PackedStringArray = []
	for f in d.get_files():
		if f.ends_with(".tres"):
			rutas.append(FICHAS + f)
	rutas.sort()

	var total: int = 0
	var bytes: int = 0
	var t0: int = Time.get_ticks_msec()
	var recortados: int = 0
	var sueltas: int = 0
	for ruta in rutas:
		var ed: EnemyData = load(ruta) as EnemyData
		if ed == null or SpritesEnemigo.clave_de(ed, 0.5) == "":
			continue      # sin generador: sigue siendo un ColorRect, no hay nada que hornear
		var hechas := {}
		for i in MUESTRAS:
			var t: float = float(i) / float(MUESTRAS - 1)
			var clave: String = SpritesEnemigo.clave_de(ed, t)
			if hechas.has(clave):
				continue
			hechas[clave] = true
			# generar_de y no frames_de: aqui hay que DIBUJARLO siempre, aunque ya haya un horneado
			# viejo en disco -- si no, rehornear despues de tocar un generador no serviria de nada.
			var g = SpritesEnemigo.GENERADORES_POR_NOMBRE.get(ed.sprite_gen, null)
			if g == null:
				g = SpritesEnemigo.GENERADORES.get(ed.familia, null)
			var sf: SpriteFrames = g.generar_de(ed, t)
			var n: int = SpriteLienzo.hornear(sf, clave)
			if n <= 0:
				push_error("[horno] no pude escribir %s" % clave)
				continue
			bytes += n
			total += 1
			recortados += _avisar_recortes(sf, clave)
			sueltas += _avisar_islas(sf, clave)
		print("  %-24s %d variantes" % [ruta.get_file(), hechas.size()])
	print("")
	print("%d ficheros, %.2f MB, en %.1f s" % [total, bytes / 1048576.0,
		(Time.get_ticks_msec() - t0) / 1000.0])
	if recortados > 0:
		print("")
		print("  !! %d fotogramas TOCAN EL BORDE de su lienzo (ver arriba cuales): a esos el dibujo"
			% recortados)
		print("     se les corta en seco. O la pose se pasa, o ese bicho necesita un lienzo mayor.")
	if sueltas > 0:
		print("")
		print("  !! %d fotogramas tienen TROZOS SUELTOS separados del cuerpo." % sueltas)
		print("     Alguna pieza se ha quedado atras: se ve como un cacho de bicho tirado al lado.")
	print("Estan en %s -- ABRE GODOT UNA VEZ para que los importe antes de jugar." %
		SpriteLienzo.CARPETA_HORNO)

	_hornear_terreno()
	_hornear_recolectables()
	_hornear_props()
	_hornear_jugador()
	get_tree().quit()


# EL PERSONAJE. Va en el mismo horno que todo lo demas y no en un .bat aparte: se toca por lo mismo
# (mirar como queda y volver a dibujar) y dos herramientas que hay que acordarse de pasar acaban
# siendo una que se pasa y otra que no.
#
# Sus capas se hornean CADA UNA POR SU LADO, que es la idea entera: no hay una imagen del personaje
# con placas y mandoble, hay una del cuerpo, una del peto de placas y una del mandoble. Por eso esto
# no depende de cuantas combinaciones existan sino de cuantas piezas hay.
func _hornear_jugador() -> void:
	print("")
	print("=== JUGADOR ===")
	var bytes: int = 0
	var recortados: int = 0
	var sueltas: int = 0
	var t0: int = Time.get_ticks_msec()
	# TODAS LAS CAPAS QUE EXISTEN, no las del personaje de turno. 'JugadorSprites.CAPAS' son solo las
	# fijas (el cuerpo); lo que se elige -- pelo y ropa -- vive en los CATALOGOS, y hornear solo lo
	# que lleva puesto alguien significaria que el resto de peinados se dibujan al vuelo en el juego.
	# 'todas_las_capas' ya las genera (generar y no frames: aqui hay que DIBUJARLAS siempre, aunque
	# haya un horneado viejo en disco, o rehornear tras tocar un generador no serviria de nada).
	for c in JugadorSprites.todas_las_capas():
		var sf: SpriteFrames = JugadorSprites.generar_capa(c, 1.0)
		var clave: String = String(c["clave"])
		var n: int = CapaJugador.hornear(sf, clave, 1.0)
		if n <= 0:
			push_error("[horno] no pude escribir la capa %s" % clave)
			continue
		bytes += n
		recortados += _avisar_recortes(sf, clave)
		sueltas += _avisar_islas_capa(sf, clave, int(c["piezas"]))
		print("  %-20s %.1f KB · %d animaciones" % [clave, n / 1024.0, sf.get_animation_names().size()])
	print("%.2f MB en %s (%.1f s)" % [bytes / 1048576.0, CapaJugador.CARPETA,
		(Time.get_ticks_msec() - t0) / 1000.0])
	if recortados > 0:
		print("  !! %d fotogramas TOCAN EL BORDE del lienzo: sube PoseJugador.LIENZO_FACTOR."
			% recortados)
	if sueltas > 0:
		print("  !! %d fotogramas tienen MAS TROZOS de los declarados en JugadorSprites.CAPAS."
			% sueltas)
		print("     O se ha despegado algo, o esa capa tiene mas piezas de las que dice.")


# EL VALIDADOR DE ISLAS DEL JUGADOR. Es el mismo que el de los bichos con dos diferencias, y las dos
# importan:
#
#  1. MIRA TODAS LAS ANIMACIONES, no solo morir. En un bicho las poses brutas son las de la muerte;
#     en el personaje el fallo tipico esta en ANDAR -- la mano se va por delante del cuerpo, el
#     antebrazo queda tapado por el pecho y lo que se ve es un puntito flotando al lado. Limitarlo a
#     'muerte' aqui seria no mirar donde pasa.
#  2. CADA CAPA DICE DE CUANTOS TROZOS CONSTA. Unas botas son dos piezas y no hay nada que arreglar;
#     el cuerpo es una y dos significa que se ha soltado algo. Sin esto, la mitad de los avisos
#     serian correctos-por-diseño y el aviso entero dejaria de leerse, que es como muere un
#     validador.
func _avisar_islas_capa(sf: SpriteFrames, clave: String, esperadas: int) -> int:
	var malos: int = 0
	for anim in sf.get_animation_names():
		for i in sf.get_frame_count(anim):
			var tex: Texture2D = sf.get_frame_texture(anim, i)
			var img: Image = tex.get_image() if tex != null else null
			if img == null:
				continue
			var trozos: Array = _manchas(img)
			if trozos.size() <= esperadas:
				continue
			trozos.sort()
			trozos.reverse()
			# Media mano suelta es un fallo; un pixel asomando es pixel-art.
			var sueltos: Array = trozos.slice(esperadas).filter(func(px: int) -> bool: return px >= 4)
			if sueltos.is_empty():
				continue
			malos += 1
			if malos <= 4:
				print("     !! %s %s f%d: %d trozo(s) de mas, de %s px (mayor: %d)"
					% [clave, anim, i, sueltos.size(), str(sueltos), int(trozos[0])])
	return malos


func _hornear_props() -> void:
	print("")
	print("=== PROPS ===")
	for clave in PropSprites.PROPS:
		var n: int = PropSprites.hornear(String(clave))
		if n <= 0:
			push_error("[horno] no pude escribir el prop %s" % clave)
			continue
		print("  %-20s %.1f KB" % [clave, n / 1024.0])


# El TERRENO va en el mismo horno y no en uno aparte: se toca por lo mismo (mirar como queda y
# volver a dibujar) y asi no hay dos .bat que acordarse de pasar.
func _hornear_terreno() -> void:
	print("")
	print("=== TERRENO ===")
	var bytes: int = 0
	for t in TerrenoSprites.TRAMOS:
		var clave: String = String(t["clave"])
		var n: int = TerrenoSprites.hornear(clave)
		if n <= 0:
			push_error("[horno] no pude escribir el terreno %s" % clave)
			continue
		bytes += n
		print("  terreno_%-16s %.1f KB" % [clave, n / 1024.0])
	print("%.2f MB en %s" % [bytes / 1048576.0, TerrenoSprites.CARPETA])


func _hornear_recolectables() -> void:
	print("")
	print("=== RECOLECTABLES ===")
	var bytes: int = 0
	for fam in RecolectableSprites.FAMILIAS:
		var n: int = RecolectableSprites.hornear(String(fam))
		if n <= 0:
			push_error("[horno] no pude escribir el recolectable %s" % fam)
			continue
		bytes += n
		print("  %-20s %.1f KB" % [fam, n / 1024.0])
	print("%.2f MB en %s" % [bytes / 1048576.0, RecolectableSprites.CARPETA])


# ¿SE LE SALE EL DIBUJO DEL LIENZO? Devuelve cuantos fotogramas tocan el borde, y dice cuales.
#
# Esta aqui porque es el fallo de arte que MAS caro sale de encontrar: no da error, no rompe nada,
# y lo unico que pasa es que a la figura le falta un trozo -- una sombra cortada en seco por una
# linea recta. Se ve mirando, si a uno le da por mirar ese bicho, en esa animacion, en esa
# direccion. Con 34 variantes por 40 animaciones cada una, eso es no verlo.
#
# El AtlasTexture recortado es justo lo que hace falta para detectarlo: 'margin' dice donde cae el
# recorte dentro del lienzo entero, asi que si el recorte llega al borde es que el dibujo llegaba
# mas alla y se quedo fuera. (Ojo: puede haber falsos positivos si una pose ROZA el borde sin
# pasarse, pero es lo bastante raro como para que merezca la pena mirarlo igualmente.)
func _avisar_recortes(sf: SpriteFrames, clave: String) -> int:
	var malos: int = 0
	for anim in sf.get_animation_names():
		for i in sf.get_frame_count(anim):
			var at: AtlasTexture = sf.get_frame_texture(anim, i) as AtlasTexture
			if at == null:
				continue
			# UN FOTOGRAMA VACIO NO SE SALE DE NADA. Los que no dibujan nada (la cara mirando al
			# norte: una nuca no tiene ojos) apuntan al pixel transparente que SpriteLienzo reserva al
			# final de la hoja, y ese pixel esta pegado al borde por construccion -- con lo que el
			# chequeo de abajo los daba TODOS por recortados. Fueron 370 avisos de golpe, que es la
			# forma mas rapida de que un validador deje de leerse.
			if at.region.size.x <= 1 and at.region.size.y <= 1:
				continue
			var w: int = int(at.region.size.x + at.margin.size.x)
			var h: int = int(at.region.size.y + at.margin.size.y)
			var x0: int = int(at.margin.position.x)
			var y0: int = int(at.margin.position.y)
			if x0 > 0 and y0 > 0 and x0 + int(at.region.size.x) < w 					and y0 + int(at.region.size.y) < h:
				continue
			malos += 1
			if malos <= 3:   # con avisar de los primeros basta: siempre van en racha
				print("     !! %s %s f%d se sale del lienzo (%dx%d)" % [clave, anim, i, w, h])
	return malos


# ¿SE LE HA QUEDADO ALGUN TROZO SUELTO? Cuenta las manchas separadas del dibujo y avisa de las que
# tengan mas de una.
#
# Es el hermano de _avisar_recortes y existe por lo mismo: no da error y no rompe nada, simplemente
# el bicho aparece con un cacho de si mismo tirado al lado. Paso con el trent al caerse -- sus
# raices se quedaron donde estaban mientras el tronco se iba de lado -- y se vio de casualidad, en
# una captura, en UNA de las ocho direcciones.
#
# SOLO en 'muerte' y 'cadaver', y no en todas las animaciones, por dos motivos: es donde las poses
# mueven el cuerpo de forma mas bruta (y por tanto donde se despegan las cosas), y porque hay
# animaciones en las que separarse es CORRECTO -- un slime en el aire deja su sombra en el suelo.
#
# La sombra de contacto no cuenta como cuerpo: va translucida (alpha 0.22), asi que basta con mirar
# solo los pixeles opacos.
const ANIMS_DE_UNA_PIEZA := ["muerte", "cadaver"]

func _avisar_islas(sf: SpriteFrames, clave: String) -> int:
	var malos: int = 0
	for anim in sf.get_animation_names():
		if not ANIMS_DE_UNA_PIEZA.has(String(anim).rsplit("_", true, 1)[0]):
			continue
		for i in sf.get_frame_count(anim):
			var tex: Texture2D = sf.get_frame_texture(anim, i)
			var img: Image = tex.get_image() if tex != null else null
			if img == null:
				continue
			# EL TAMAÑO DE CADA TROZO, no solo cuantos hay: no es lo mismo que se le haya quedado
			# atras media pata que la punta de una rama asomando por un pixel. El primero es un fallo
			# y el segundo es pixel-art.
			var trozos: Array = _manchas(img)
			if trozos.size() <= 1:
				continue
			trozos.sort()
			trozos.reverse()
			# Todo lo que no sea el cuerpo principal, y solo cuenta si tiene entidad.
			var sueltos: Array = trozos.slice(1).filter(func(px: int) -> bool: return px >= 4)
			if sueltos.is_empty():
				continue
			malos += 1
			if malos <= 3:
				print("     !! %s %s f%d: %d trozo(s) suelto(s) de %s px (cuerpo: %d)"
					% [clave, anim, i, sueltos.size(), str(sueltos), int(trozos[0])])
	return malos


# El tamaño en pixeles de cada mancha OPACA separada (vecindad de 4). Inundacion iterativa con una
# pila propia: recursiva se sale de la pila de GDScript en cuanto la figura es grande.
func _manchas(img: Image) -> Array:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var visto := PackedByteArray()
	visto.resize(w * h)
	var tam: Array = []
	for y in h:
		for x in w:
			var i0: int = y * w + x
			if visto[i0] == 1 or img.get_pixel(x, y).a <= 0.5:
				continue
			var px: int = 1
			var pila: Array[int] = [i0]
			visto[i0] = 1
			while not pila.is_empty():
				var i: int = pila.pop_back()
				var cx: int = i % w
				var cy: int = i / w
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = cx + d.x
					var ny: int = cy + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var j: int = ny * w + nx
					if visto[j] == 1 or img.get_pixel(nx, ny).a <= 0.5:
						continue
					visto[j] = 1
					px += 1
					pila.append(j)
			tam.append(px)
	return tam
