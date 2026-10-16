# HERRAMIENTA. No forma parte del juego. CON VENTANA (hornear y capturar necesitan pintar):
#
#   godot --path . res://tools/capturas_retratos.tscn
#
# LOS RETRATOS HORNEADOS (fase 1D, 16/10/2026) contra los VIVOS: la misma fila de retratos (los de la partida de
# referencia) montada con munecos vivos y luego horneada, capturadas las dos en los 8 fotogramas de la respiracion,
# y la diferencia medida pixel a pixel. Deja en el Escritorio (carpeta retratos_horneados): vivo_N.png, horneado_N.png,
# diferencia_N.png (lo que cambia, en rojo, x8 para que se vea) y en el log cuanto cambia cada fotograma.
extends Node

const CARPETA := "C:/Users/dasui/Desktop/retratos_horneados"

var _fila: HBoxContainer


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	var fondo := ColorRect.new()
	fondo.color = Color(0.12, 0.13, 0.16)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_fila = HBoxContainer.new()
	_fila.position = Vector2(40, 60)
	add_child(_fila)
	var gente: Array = Game.party + Game.plantilla
	print("[RETRATOS] %d personas, escala de pantalla %.2f" % [gente.size(), RetratoHorneado.escala_pantalla()])

	# 1) VIVOS (la primera vez no hay nada horneado: salen vivos y piden hornearse)
	var t0: int = Time.get_ticks_usec()
	MenuScaffold.retratos(_fila, gente, 0, Game.party.size(), func(_i): pass)
	print("[RETRATOS] montar la fila VIVA: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var vivos: Array = _munecos()
	var vivas: Array = []
	for m in 8:
		for mu in vivos:
			mu.fijar(RetratoHorneado.ANIM, m)
		vivas.append(await _captura())
	# 1b) EL VIVO CONTRA SI MISMO, movido un tercio de pixel: lo que cambian los bordes solo por donde cae en pantalla.
	for mu in vivos:
		mu.fijar(RetratoHorneado.ANIM, 0)
	_fila.position.x += 0.34
	var movida: Image = await _captura()
	_fila.position.x -= 0.34
	var dv: Array = _diferencia(vivas[0], movida, 99)
	print("[RETRATOS] el VIVO movido 0,34 px contra si mismo: %d pixeles distintos, el peor %d/255" % [dv[0], dv[1]])
	# 2) Esperar a que se horneen
	for i in 300:
		await get_tree().process_frame
		if RetratoHorneado._horneando.is_empty():
			break
	print("[RETRATOS] horneados: %d" % RetratoHorneado._cache.size())
	var n_h: int = 0
	for h in RetratoHorneado._cache:
		var e: Dictionary = RetratoHorneado._cache[h]
		var im: Image = (e["tex"] as Texture2D).get_image()
		im.save_png("%s/atlas_%d.png" % [CARPETA, n_h])
		var usados: Rect2i = im.get_used_rect()
		print("[RETRATOS] atlas %d: %dx%d formato %d, con dibujo en %s" % [n_h, im.get_width(), im.get_height(), im.get_format(), str(usados)])
		n_h += 1
	# 3) HORNEADOS
	var t1: int = Time.get_ticks_usec()
	MenuScaffold.retratos(_fila, gente, 0, Game.party.size(), func(_i): pass)
	print("[RETRATOS] montar la fila HORNEADA: %.1f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
	await get_tree().process_frame
	var horneados: Array = []
	_juntar(_fila, horneados, func(n): return n is RetratoHorneado)
	print("[RETRATOS] en la fila: %d horneados, %d vivos" % [horneados.size(), _munecos().size()])
	var mal: int = 0
	for m in 8:
		for r in horneados:
			r._i = m
			r._t = 0.0
			r.set_process(false)
			r.queue_redraw()
		var img: Image = await _captura()
		img.save_png("%s/horneado_%d.png" % [CARPETA, m])
		(vivas[m] as Image).save_png("%s/vivo_%d.png" % [CARPETA, m])
		var d: Array = _diferencia(vivas[m], img, m)
		print("[RETRATOS] fotograma %d: %d pixeles distintos (mas de 8/255), el peor %d/255" % [m, d[0], d[1]])
		# EL LISTON es lo que cambia el propio vivo movido un tercio de pixel (dv): con una escala de pantalla no entera
		# los bordes bailan segun donde caiga el dibujo, y eso no es un defecto del horneado. A 1280x720 sale 0.
		if d[0] > maxi(dv[0], 50):
			mal += 1
	# 4) LA CARA DE LA BARRA DE TURNOS (RetratoCombate._cara_de_muneco): quieta, sin equipo, en 40 px.
	var RC = preload("res://scripts/ui/retrato_combate.gd")
	_fila.queue_free()
	await get_tree().process_frame
	_fila = HBoxContainer.new()
	_fila.position = Vector2(40, 60)
	add_child(_fila)
	var cuadros: Array = []
	for pj in gente:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(40, 40)
		r.size = Vector2(40, 40)
		r.color = Color(0.2, 0.2, 0.25)
		r.clip_contents = true
		_fila.add_child(r)
		cuadros.append(r)
	await get_tree().process_frame
	for i in gente.size():
		RC._cara_de_muneco(cuadros[i], gente[i])
	var cara_viva: Image = await _captura()
	for i in 300:
		await get_tree().process_frame
		if RetratoHorneado._horneando.is_empty():
			break
	for r in cuadros:
		for h in r.get_children():
			h.free()
	var tc: int = Time.get_ticks_usec()
	for i in gente.size():
		RC._cara_de_muneco(cuadros[i], gente[i])
	print("[RETRATOS] caras de la barra HORNEADAS: %.2f ms las %d" % [(Time.get_ticks_usec() - tc) / 1000.0, gente.size()])
	var hc: Array = []   # un Array y no un int: la lambda captura por valor
	_juntar(_fila, hc, func(n): return n is RetratoHorneado)
	var n_hc: int = hc.size()
	var cara_h: Image = await _captura()
	cara_viva.save_png("%s/cara_viva.png" % CARPETA)
	cara_h.save_png("%s/cara_horneada.png" % CARPETA)
	var dc: Array = _diferencia(cara_viva, cara_h, 50)
	print("[RETRATOS] caras: %d horneadas de %d; %d pixeles distintos, el peor %d/255" % [n_hc, gente.size(), dc[0], dc[1]])
	if dc[0] > maxi(dv[0] / 4, 50):
		mal += 1
	# 5) RECTANGULAR Y RESPIRANDO (la tira de la ficha de detalle de combate, CombateDetalle._colocar_retrato)
	var CD = preload("res://scripts/ui/combate_detalle.gd")
	_fila.queue_free()
	await get_tree().process_frame
	_fila = HBoxContainer.new()
	_fila.position = Vector2(40, 60)
	add_child(_fila)
	var tam := Vector2(60, 84)
	var huecos: Array = []
	var vivos5: Array = []
	for pj in gente:
		var hq := Control.new()
		hq.custom_minimum_size = tam
		hq.size = tam
		hq.clip_contents = true
		_fila.add_child(hq)
		huecos.append(hq)
		var mu := MunecoJugador.new()
		mu.montar(pj)
		mu.tenir(pj.color, 0.0)
		mu.poner_cara(pj.textura())
		hq.add_child(mu)
		mu.z_as_relative = true
		CD._colocar_retrato(mu, tam)
		vivos5.append(mu)
		RetratoHorneado.pedir_modo(pj, "prueba_rect", tam, -1, CD._colocar_retrato)
	await get_tree().process_frame
	for mu in vivos5:
		mu.z_as_relative = true
		mu.z_index = 0
	var vivas5: Array = []
	for m in 8:
		for mu in vivos5:
			mu.fijar(RetratoHorneado.ANIM, m)
		vivas5.append(await _captura())
	for i in 300:
		await get_tree().process_frame
		if RetratoHorneado._horneando.is_empty():
			break
	var rs: Array = []
	for i in gente.size():
		for h in (huecos[i] as Control).get_children():
			h.free()
		var e5: Dictionary = RetratoHorneado.de_modo(gente[i], "prueba_rect")
		if not e5.is_empty():
			var r5 := RetratoHorneado.crear(e5)
			huecos[i].add_child(r5)
			rs.append(r5)
	var peor5: int = 0
	for m in 8:
		for r5 in rs:
			r5._i = m
			r5.set_process(false)
			r5.queue_redraw()
		var im5: Image = await _captura()
		var d5: Array = _diferencia(vivas5[m], im5, 60 + m)
		peor5 = maxi(peor5, d5[0])
		if m == 0:
			im5.save_png("%s/rect_horneado.png" % CARPETA)
			(vivas5[0] as Image).save_png("%s/rect_vivo.png" % CARPETA)
	print("[RETRATOS] rectangulares (60x84, respirando): %d horneados de %d; el peor fotograma %d pixeles distintos" % [rs.size(), gente.size(), peor5])
	if peor5 > maxi(dv[0], 50):
		mal += 1
	print("[RETRATOS] FIN: %s" % ("IGUALES A LA VISTA" if mal == 0 else "%d FOTOGRAMAS CON DIFERENCIAS GRANDES" % mal))
	get_tree().quit()


func _munecos() -> Array:
	var out: Array = []
	_juntar(_fila, out, func(n): return n is MunecoJugador)
	return out


func _juntar(n: Node, out: Array, f: Callable) -> void:
	if f.call(n):
		out.append(n)
	for h in n.get_children():
		_juntar(h, out, f)


func _captura() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var k: float = RetratoHorneado.escala_pantalla()
	var r := Rect2i(Vector2i(_fila.global_position * k), Vector2i(_fila.size * k))
	return img.get_region(r)


func _diferencia(a: Image, b: Image, m: int) -> Array:
	var w: int = mini(a.get_width(), b.get_width())
	var h: int = mini(a.get_height(), b.get_height())
	var d := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n: int = 0
	var peor: int = 0
	for y in h:
		for x in w:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var dif: int = roundi(maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b)) * 255.0)
			peor = maxi(peor, dif)
			if dif > 8:
				n += 1
			d.set_pixel(x, y, Color(minf(1.0, dif * 8 / 255.0), 0, 0, 1))
	d.save_png("%s/diferencia_%d.png" % [CARPETA, m])
	return [n, peor]

