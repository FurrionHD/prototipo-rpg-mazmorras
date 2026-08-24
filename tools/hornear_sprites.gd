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
		print("  %-24s %d variantes" % [ruta.get_file(), hechas.size()])
	print("")
	print("%d ficheros, %.2f MB, en %.1f s" % [total, bytes / 1048576.0,
		(Time.get_ticks_msec() - t0) / 1000.0])
	print("Estan en %s -- ABRE GODOT UNA VEZ para que los importe antes de jugar." %
		SpriteLienzo.CARPETA_HORNO)

	_hornear_terreno()
	_hornear_recolectables()
	_hornear_props()
	get_tree().quit()


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
