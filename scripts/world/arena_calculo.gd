# ============================================================
#  arena_calculo.gd
#  EL RECTANGULO DE LA ARENA: dado el trazado de un piso y donde ha empezado una pelea, decide en
#  que trozo de suelo se pelea. Datos puros, sin un solo nodo -- por eso se puede probar sin montar
#  el juego (ver tools/prueba_arena_tactica.tscn). Quien lo dibuja y le pone muros es
#  scripts/world/arena_combate.gd.
#
#  EL TAMAÑO NO ES FIJO: depende de contra quien peleas. Un jefe pide sitio para moverse a su
#  alrededor; tres ratas en un pasillo, no. Por eso `tam_deseado` mira si hay jefe y cuantos son, y
#  una ficha de enemigo puede pedir el suyo a mano (EnemyData.arena_celdas).
#
#  DOS CAMINOS para encontrar el rectangulo, y el orden importa:
#    1) LA SALA. Si la pelea cae dentro de una sala, la arena es esa sala recortada a lo que se
#       pide. Es el caso de la inmensa mayoria de las peleas y sale de un dato que el generador ya
#       tiene calculado (zonas[i].rect), asi que es exacto y gratis.
#    2) CRECER. En un pasillo, o en una sala que se ha quedado pequeña, se crece desde la semilla
#       lado a lado mientras la fila o columna nueva sea suelo. Cuando un lado topa con roca, ese
#       lado se para. Da el mayor rectangulo de suelo que contiene la semilla.
#
#  Y UNA SALIDA HONESTA: si no llega ni a ARENA_MIN, `cabe()` dice que no y la pelea se abre con la
#  pantalla de siempre. En un pasillo de tres celdas no se pelea en tactico, y es mejor decirlo aqui
#  desde el primer dia que parchearlo el dia que esto salga a la mazmorra.
# ============================================================

extends RefCounted
class_name ArenaCalculo

# El rectangulo de partida, en CELDAS. Impar a proposito en los dos lados: asi hay una celda central
# de verdad y la semilla puede quedar en medio sin desempates raros.
const TAM_BASE := Vector2i(11, 9)

# Por debajo de esto no se pelea en tactico. Con menos, el radio de movimiento no cabe y la pelea se
# convierte en la de siempre pero con pasos: no aporta nada y se ve peor.
const ARENA_MIN := Vector2i(7, 5)

# Un jefe necesita sitio para que puedas rodearlo y para que sus areas grandes signifiquen algo.
const JEFE_MULT := 1.6

# Cada cuerpo de mas, a partir del tercero, pide una celda mas de lado. Sin cupo de enemigos esto es
# lo que hace que una pelea de quince no se juegue en un pañuelo.
const COMBATIENTES_GRATIS := 2

# Al crecer se tolera ESTA cantidad de roca en la fila o columna nueva. Es para las estalagmitas,
# que son de 1x1 (ver dungeon_floor.FORMACION_CAJA): una sola no deberia partir una arena en dos.
# Mas de una ya es una pared de verdad y ahi el lado se para.
const ROCA_TOLERADA := 1

# Cuanto se busca suelo alrededor si la semilla cae sobre roca (pasa: el centroide de un grupo que
# rodea una columna puede caer justo en la columna). En celdas.
const BUSQUEDA_SUELO := 6


# El tamaño que PIDE esta pelea, en celdas. 'forzado' es EnemyData.arena_celdas: (0,0) = automatico.
static func tam_deseado(combatientes: int, hay_jefe: bool,
		forzado: Vector2i = Vector2i.ZERO) -> Vector2i:
	if forzado.x > 0 and forzado.y > 0:
		return forzado
	var t: Vector2i = TAM_BASE
	if hay_jefe:
		t = Vector2i(roundi(float(t.x) * JEFE_MULT), roundi(float(t.y) * JEFE_MULT))
	var extra: int = maxi(0, combatientes - COMBATIENTES_GRATIS)
	return t + Vector2i(extra, extra)


# La celda que contiene un punto en pixeles. Mismo criterio que DungeonFloor.celda_de_px (floor):
# si los dos no coinciden, la arena se dibuja medio desplazada respecto a donde estan los cuerpos.
static func celda_de_px(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / float(DungeonGenerator.CELDA)),
		floori(p.y / float(DungeonGenerator.CELDA)))


# El centro en pixeles de un rectangulo de celdas.
static func centro_px(rect: Rect2i) -> Vector2:
	return Vector2(float(rect.position.x) + float(rect.size.x) * 0.5,
		float(rect.position.y) + float(rect.size.y) * 0.5) * float(DungeonGenerator.CELDA)


# El rectangulo en pixeles de un rectangulo de celdas (para dibujar y para poner los muros).
static func rect_px(rect: Rect2i) -> Rect2:
	var c: float = float(DungeonGenerator.CELDA)
	return Rect2(Vector2(rect.position) * c, Vector2(rect.size) * c)


# LA SEMILLA de una pelea: el centro de gravedad de los que la empiezan. Se pasa una lista de
# posiciones en pixeles (los bichos y los tuyos). Si sale vacia, devuelve la primera que haya.
static func semilla_de(posiciones: Array) -> Vector2:
	if posiciones.is_empty():
		return Vector2.ZERO
	var suma: Vector2 = Vector2.ZERO
	for p in posiciones:
		suma += p as Vector2
	return suma / float(posiciones.size())


# ¿Se puede pelear en tactico aqui? Es la pregunta que hace Game antes de montar nada.
static func cabe(gen: DungeonGenerator, semilla_px: Vector2, deseado: Vector2i) -> bool:
	var r: Rect2i = rect_de_arena(gen, semilla_px, deseado)
	return r.size.x >= ARENA_MIN.x and r.size.y >= ARENA_MIN.y


# EL RECTANGULO. Devuelve un Rect2i en CELDAS; Rect2i() vacio si ni siquiera hay suelo donde plantar
# la semilla.
static func rect_de_arena(gen: DungeonGenerator, semilla_px: Vector2,
		deseado: Vector2i) -> Rect2i:
	if gen == null or gen.ancho <= 0 or gen.alto <= 0:
		return Rect2i()
	var semilla: Vector2i = _suelo_cerca(gen, celda_de_px(semilla_px))
	if semilla.x < 0:
		return Rect2i()

	# 1) LA SALA. Solo si es una sala (un pasillo tiene rect, pero es un rect en L que en su mayor
	#    parte es roca: recortarlo daria una arena con media pared dentro).
	var z: int = gen.zona_en(semilla)
	if z >= 0 and z < gen.zonas.size() and String(gen.zonas[z]["tipo"]) == "sala":
		var sala: Rect2i = gen.zonas[z]["rect"]
		if sala.size.x >= ARENA_MIN.x and sala.size.y >= ARENA_MIN.y:
			return _recortar(sala, semilla, deseado)

	# 2) CRECER desde la semilla.
	return _crecer(gen, semilla, deseado)


# Recorta 'sala' a 'deseado' dejando la semilla lo mas centrada que se pueda sin salirse. Si la sala
# ya es mas pequeña que lo pedido en un eje, en ese eje se queda la sala entera.
static func _recortar(sala: Rect2i, semilla: Vector2i, deseado: Vector2i) -> Rect2i:
	var tam: Vector2i = Vector2i(mini(deseado.x, sala.size.x), mini(deseado.y, sala.size.y))
	var pos: Vector2i = Vector2i(semilla.x - tam.x / 2, semilla.y - tam.y / 2)
	# Y se empuja dentro de la sala: centrar en la semilla puede sacar el rectangulo por un borde
	# cuando la pelea empieza pegada a la pared.
	pos.x = clampi(pos.x, sala.position.x, sala.position.x + sala.size.x - tam.x)
	pos.y = clampi(pos.y, sala.position.y, sala.position.y + sala.size.y - tam.y)
	return Rect2i(pos, tam)


# Crece un rectangulo desde la semilla, un lado cada vez y por turnos, mientras la fila o columna
# nueva sea suelo. Por turnos y no un lado entero primero: si no, la arena sale pegada a un borde y
# la semilla acaba en una esquina.
static func _crecer(gen: DungeonGenerator, semilla: Vector2i, deseado: Vector2i) -> Rect2i:
	var r := Rect2i(semilla, Vector2i.ONE)
	# izquierda, derecha, arriba, abajo
	var lados: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var vivos: Array[bool] = [true, true, true, true]
	while vivos.has(true):
		for i in lados.size():
			if not vivos[i]:
				continue
			var d: Vector2i = lados[i]
			# ¿Ya tengo lo que pedia en este eje? Entonces este lado se da por acabado.
			if (d.x != 0 and r.size.x >= deseado.x) or (d.y != 0 and r.size.y >= deseado.y):
				vivos[i] = false
				continue
			var candidato: Rect2i = _estirar(r, d)
			if _linea_pisable(gen, candidato, d):
				r = candidato
			else:
				vivos[i] = false
	return r


# El rectangulo con un lado estirado una celda hacia 'd'.
static func _estirar(r: Rect2i, d: Vector2i) -> Rect2i:
	var out: Rect2i = r
	if d == Vector2i.LEFT:
		out.position.x -= 1
		out.size.x += 1
	elif d == Vector2i.RIGHT:
		out.size.x += 1
	elif d == Vector2i.UP:
		out.position.y -= 1
		out.size.y += 1
	else:
		out.size.y += 1
	return out


# ¿La fila (o columna) que acaba de aparecer en 'r' al estirar hacia 'd' se puede pisar? Se tolera
# hasta ROCA_TOLERADA celdas de roca: una estalagmita suelta no tiene por que cortar la arena.
static func _linea_pisable(gen: DungeonGenerator, r: Rect2i, d: Vector2i) -> bool:
	var roca: int = 0
	if d.x != 0:
		var x: int = r.position.x if d == Vector2i.LEFT else r.position.x + r.size.x - 1
		for y in range(r.position.y, r.position.y + r.size.y):
			if gen.es_solido(Vector2i(x, y)):
				roca += 1
				if roca > ROCA_TOLERADA:
					return false
	else:
		var y2: int = r.position.y if d == Vector2i.UP else r.position.y + r.size.y - 1
		for x2 in range(r.position.x, r.position.x + r.size.x):
			if gen.es_solido(Vector2i(x2, y2)):
				roca += 1
				if roca > ROCA_TOLERADA:
					return false
	return true


# La celda de suelo mas cercana a 'c' (la propia si ya lo es). Busca en anillos cuadrados. Devuelve
# (-1,-1) si no hay suelo a la vista, que solo puede pasar con un piso roto.
static func _suelo_cerca(gen: DungeonGenerator, c: Vector2i) -> Vector2i:
	if gen.es_suelo(c):
		return c
	for radio in range(1, BUSQUEDA_SUELO + 1):
		for dy in range(-radio, radio + 1):
			for dx in range(-radio, radio + 1):
				# Solo el borde del anillo: el interior ya se miro en la vuelta anterior.
				if absi(dx) != radio and absi(dy) != radio:
					continue
				var p := Vector2i(c.x + dx, c.y + dy)
				if gen.es_suelo(p):
					return p
	return Vector2i(-1, -1)
