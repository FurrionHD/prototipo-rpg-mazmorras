# ============================================================
#  formas_pixel.gd  (sin class_name: se usa con preload)
#  LAS AREAS DE ATAQUE EN PIXEL (19/11, su decision: «pasan a pixel como los circulos»). Lo mismo que
#  CombatFormas.dibujar (circulo, cono, linea, rectangulo, bolas, tramos y cuñas) con los RELLENOS igual que siempre y
#  los BORDES y las rayas de dentro hechos PIXEL A PIXEL en la rejilla del mundo: continuos, a rayas o a puntos, del
#  grosor que se pida (el estilo de Ajustes > Juego > Ayudas visuales, ver Preferencias.estilo_area).
#  Quien lo pinta tiene que estar en coordenadas de MUNDO con el origen en un pixel entero (la arena: en 0,0).
# ============================================================

extends RefCounted

const AroPixel = preload("res://scripts/fx/aro_pixel.gd")

# est: {"trazo": AroPixel.Trazo, "tam": 1-3, "largo": px de raya, "hueco": px entre rayas o puntos}
static func dibujar(f, ci: CanvasItem, borde: Color, relleno: Color, est: Dictionary) -> void:
	if f == null or ci == null:
		return
	var T = CombatFormas.Tipo
	if f.abanico > 1 and f.tipo == T.LINEA:
		for l in f.lineas():
			dibujar(l, ci, borde, relleno, est)
		return
	var dentro := Color(borde, borde.a * 0.7)   # las rayas de dentro (tramos, cuñas), algo mas suaves
	if f.en_bolas():
		for c in f.centros_bolas():
			var rb: float = maxf(f.ancho * 0.5, 2.0)
			ci.draw_circle(c, rb, relleno)
			arco(ci, c, rb, 0.0, TAU, borde, est)
		return
	match f.tipo:
		T.PUNTO, T.CIRCULO:
			ci.draw_circle(f.centro, maxf(f.radio, 2.0), relleno)
			if f.tipo == T.CIRCULO and f.tramos > 1:
				for k in range(1, f.tramos):
					var rk: float = f.radio * float(k) / float(f.tramos)
					ci.draw_circle(f.centro, rk, relleno)
					arco(ci, f.centro, rk, 0.0, TAU, dentro, est)
			arco(ci, f.centro, maxf(f.radio, 2.0), 0.0, TAU, borde, est)
		T.CONO:
			var a0: float = f.dir.angle() - deg_to_rad(f.apertura * 0.5)
			var a1: float = f.dir.angle() + deg_to_rad(f.apertura * 0.5)
			var n_tr: int = maxi(1, f.tramos)
			for k in n_tr:
				var r0: float = f.radio * float(k) / float(n_tr)
				var r1: float = f.radio * float(k + 1) / float(n_tr)
				var pts := PackedVector2Array()
				for i in 33:
					var a: float = a0 + (a1 - a0) * float(i) / 32.0
					pts.append(f.origen + Vector2(cos(a), sin(a)) * r1)
				if r0 <= 0.0:
					pts.append(f.origen)
				else:
					for i in range(32, -1, -1):
						var a2: float = a0 + (a1 - a0) * float(i) / 32.0
						pts.append(f.origen + Vector2(cos(a2), sin(a2)) * r0)
				var alfa: float = 1.0 - 0.6 * float(k) / float(maxi(1, n_tr - 1)) if n_tr > 1 else 1.0
				Poligono.relleno(ci, pts, Color(relleno, relleno.a * alfa * (1.5 if n_tr > 1 else 1.0)))
				if k > 0:
					arco(ci, f.origen, r0, a0, a1, dentro, est)
			if f.cunas > 1:
				var paso: float = (a1 - a0) / float(f.cunas)
				for j in f.cunas:
					var banda: int = absi(j - (f.cunas - 1) / 2)
					var pc := PackedVector2Array([f.origen])
					for i in 9:
						var ac: float = a0 + paso * (float(j) + float(i) / 8.0)
						pc.append(f.origen + Vector2(cos(ac), sin(ac)) * f.radio)
					Poligono.relleno(ci, pc, Color(relleno, relleno.a * maxf(0.0, 1.2 - 0.5 * float(banda))))
					if j > 0:
						var aj: float = a0 + paso * float(j)
						linea(ci, f.origen, f.origen + Vector2(cos(aj), sin(aj)) * f.radio, Color(borde, borde.a * 0.6), est)
			arco(ci, f.origen, f.radio, a0, a1, borde, est)
			linea(ci, f.origen, f.origen + Vector2(cos(a0), sin(a0)) * f.radio, borde, est)
			linea(ci, f.origen, f.origen + Vector2(cos(a1), sin(a1)) * f.radio, borde, est)
		T.LINEA:
			var nor: Vector2 = Vector2(-f.dir.y, f.dir.x)
			var n_tl: int = maxi(1, f.tramos)
			for k in n_tl:
				var t0: float = f.largo * float(k) / float(n_tl)
				var t1: float = f.largo * float(k + 1) / float(n_tl)
				var q0: Vector2 = f.origen + f.dir * t0
				var q1: Vector2 = f.origen + f.dir * t1
				var h0: Vector2 = nor * f.ancho_en(t0) * 0.5
				var h1: Vector2 = nor * maxf(f.ancho_en(t1), 0.5) * 0.5
				var alfa_l: float = 1.0 - 0.6 * float(k) / float(maxi(1, n_tl - 1)) if n_tl > 1 else 1.0
				Poligono.relleno(ci, PackedVector2Array([q0 - h0, q1 - h1, q1 + h1, q0 + h0]),
					Color(relleno, relleno.a * alfa_l * (1.5 if n_tl > 1 else 1.0)))
				if k > 0:
					linea(ci, q0 - h0, q0 + h0, dentro, est)
			var hs: Vector2 = nor * f.ancho * 0.5
			var p1: Vector2 = f.origen + f.dir * f.largo
			var hf: Vector2 = nor * maxf(f.ancho_en(f.largo), 0.0) * 0.5
			polilinea(ci, PackedVector2Array([f.origen - hs, p1 - hf, p1 + hf, f.origen + hs, f.origen - hs]), borde, est)
		T.RECTANGULO:
			var h: Vector2 = f.tam * 0.5
			var ang: float = f.dir.angle()
			var esq := PackedVector2Array()
			for e in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
				esq.append(f.centro + (e as Vector2).rotated(ang))
			Poligono.relleno(ci, esq, relleno)
			esq.append(esq[0])
			polilinea(ci, esq, borde, est)


# ------------------------------------------------------------
#  LOS TRAZOS EN PIXEL
# ------------------------------------------------------------

# Un ARCO de 'a0' a 'a1' (radianes, a1 > a0): el mismo recorrido pixel a pixel que los aros (AroPixel.recorrido),
# quedandose con los pixeles de ese tramo de angulo.
static func arco(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color, est: Dictionary) -> void:
	var ri: int = maxi(1, roundi(r))
	var todo: bool = a1 - a0 >= TAU - 0.001
	var pix: Array = AroPixel.recorrido(ri)
	var sel: Array = []
	if todo:
		sel = pix
	else:
		# el recorrido empieza arriba (-90º) y da la vuelta: se empieza a contar en un pixel de FUERA del tramo para que
		# el tramo salga seguido y no partido en dos
		var n: int = pix.size()
		var corte: int = 0
		for i in n:
			var p: Vector2i = pix[i]
			if fposmod(atan2(float(p.y), float(p.x)) - a0, TAU) > a1 - a0:
				corte = i
				break
		for j in n:
			var p: Vector2i = pix[(corte + j) % n]
			if fposmod(atan2(float(p.y), float(p.x)) - a0, TAU) <= a1 - a0:
				sel.append(p)
	var base := Vector2i(roundi(c.x), roundi(c.y))
	var abs_pix: Array = []
	for p in sel:
		abs_pix.append(base + (p as Vector2i))
	_pintar(ci, abs_pix, col, est, todo)


# Una LINEA de 'a' a 'b' (Bresenham en la rejilla del mundo).
static func linea(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, est: Dictionary) -> void:
	_pintar(ci, bresenham(Vector2i(roundi(a.x), roundi(a.y)), Vector2i(roundi(b.x), roundi(b.y))), col, est, false)


# Una POLILINEA: los tramos seguidos, con el patron corrido de uno al siguiente (sin que cada esquina empiece raya).
static func polilinea(ci: CanvasItem, pts: PackedVector2Array, col: Color, est: Dictionary) -> void:
	var todo: Array = []
	for i in range(pts.size() - 1):
		var tramo: Array = bresenham(Vector2i(roundi(pts[i].x), roundi(pts[i].y)),
			Vector2i(roundi(pts[i + 1].x), roundi(pts[i + 1].y)))
		if not todo.is_empty() and not tramo.is_empty() and tramo[0] == todo[-1]:
			tramo.pop_front()
		todo.append_array(tramo)
	var cerrada: bool = pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) < 0.5
	if cerrada and todo.size() > 1 and todo[-1] == todo[0]:
		todo.pop_back()
	_pintar(ci, todo, col, est, cerrada)


static func bresenham(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var dx: int = absi(b.x - a.x)
	var dy: int = -absi(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var err: int = dx + dy
	var p: Vector2i = a
	while true:
		out.append(p)
		if p == b:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
	return out


# Pinta los pixeles de un recorrido con el patron (continuo / rayas / puntos) y el grosor. 'cerrado': el patron se
# reparte para cerrar sin costura (como los aros).
static func _pintar(ci: CanvasItem, pix: Array, col: Color, est: Dictionary, cerrado: bool) -> void:
	var n: int = pix.size()
	if n == 0 or col.a <= 0.0:
		return
	var trazo: int = int(est.get("trazo", AroPixel.Trazo.CONTINUO))
	var tam: int = clampi(int(est.get("tam", 1)), 1, 4)
	var largo: int = maxi(1, int(est.get("largo", 6)))
	var hueco: int = maxi(1, int(est.get("hueco", 4)))
	var periodo: int = (tam if trazo == AroPixel.Trazo.PUNTOS else largo) + hueco
	var paso: float = 1.0
	if cerrado:
		var veces: int = maxi(1, roundi(float(n) / float(periodo)))
		paso = float(veces * periodo) / float(n)
	var o: int = (tam - 1) / 2
	var lado := Vector2(tam, tam)
	var ultimo: int = -1
	for i in n:
		var s: float = float(i) * paso
		var en: int = int(s) % periodo
		if trazo == AroPixel.Trazo.PUNTOS:
			var k: int = int(s / float(periodo))
			if k == ultimo:
				continue
			ultimo = k
		elif trazo == AroPixel.Trazo.RAYAS and en >= largo:
			continue
		var p: Vector2i = pix[i]
		ci.draw_rect(Rect2(Vector2(p.x - o, p.y - o), lado), col)
