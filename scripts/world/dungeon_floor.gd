# ============================================================
#  dungeon_floor.gd
#  Nodo raiz del PISO de la mazmorra. Hace dos trabajos:
#
#  1) LEVANTA EL PISO: lo traza con DungeonGenerator (semilla derivada de la profundidad:
#     el mismo piso da siempre el mismo mapa, y al bajar sale otro), construye la
#     geometria fusionando celdas en tramos, y coloca jugador, puerta y escalera.
#
#  2) HACE DE SPAWNER DEL PISO: crea una SpawnZone por sala y por pasillo (las paredes de
#     cada zona paren monstruos) y lleva la contabilidad GLOBAL: cuantos bichos vivos
#     aguanta el piso, a quien se recicla cuando esta lleno, y a quien se le congela la IA
#     por estar lejisimos.
#
#  El piso NO toca la dificultad: el escalado por profundidad ya lo llevan
#  Game.enemy_floor_stat_factor y Game.enemy_ability_sum_band. Aqui solo se decide la
#  FORMA del piso y QUE bicho nace y DONDE.
# ============================================================

extends Node2D
class_name DungeonFloor

# --- Tamaño del piso (en CELDAS de 32 px) ---
# 100x60 = 3200x1920 px. La sala unica de antes eran 440x260: esto es ~54 veces mas.
@export var ancho_celdas: int = 100
@export var alto_celdas: int = 60
@export var max_salas: int = 14
@export var sala_min: Vector2i = Vector2i(8, 6)
@export var sala_max: Vector2i = Vector2i(18, 12)
# Pasillo de 3 celdas (96 px) = cabeis tu y un bicho, y puedes esquivarlo. A 1 celda el
# pasillo mide justo lo que tu, y solo se avanza rozando la pared.
@export var ancho_pasillo: int = 3

# Semilla del piso 1. Los siguientes la derivan de esta (ver _semilla_del_piso).
@export var semilla_base: int = 20260712

# --- QUE pare la mazmorra: la tabla del piso (familias -> variantes) ---
@export var spawn_table: SpawnTable

# --- RITMO de los partos (segundos). Franja ANCHA y LENTA a proposito: ver spawn_zone.gd ---
@export var intervalo_min: float = 25.0
@export var intervalo_max: float = 70.0

# --- Topes de poblacion ---
# Vivos que aguanta el piso ENTERO. Toda la mazmorra pare a la vez, asi que sin este tope
# el mapa se llenaria hasta reventar el rendimiento.
@export var max_vivos_piso: int = 28
# Vivos por zona: se derivan del AREA (celdas / esto), acotados por los maximos de abajo.
# OJO al contar: los pasillos que desembocan en una sala tienen SUS bichos, y desde dentro
# de la sala parecen suyos. Una sala a tope (3) con dos bocas de pasillo (1 cada una) ya se
# ve como 5 bichos encima. Por eso los topes son bajos: lo que cuenta es lo que VES junto.
@export var celdas_por_bicho: int = 40
@export var max_vivos_sala: int = 3
@export var max_vivos_pasillo: int = 1

# Que fraccion del aforo de cada zona ya esta poblada AL ENTRAR al piso. Una mazmorra
# tiene bichos deambulando cuando llegas; los partos son el goteo que viene despues. A 0
# entrarias a un piso vacio y en silencio durante el primer intervalo entero. Ni vacia ni
# a reventar: la mazmorra se nota habitada, y aun queda hueco para que las paredes paran.
@export_range(0.0, 1.0) var poblacion_inicial: float = 0.6

# La SALA DE ENTRADA (donde apareces) nace LIMPIA: nada de abrir la puerta y encontrarte
# tres esperandote. Sus paredes siguen pariendo con el tiempo, asi que no es un refugio
# eterno: es un respiro para orientarte y decidir por donde sales.
@export var entrada_despejada: bool = true

# --- Distancias (px) ---
# Mas lejos de esto, a un enemigo se le apaga la IA (no lo ves: no hace falta simularlo).
@export var dist_congelar: float = 1400.0
# Al tope global, se RECICLA (despawnea) al vivo mas lejano para que la sala donde estas
# pueda seguir pariendo. Solo si esta MAS lejos que esto: nunca se borra algo que puedas ver.
@export var dist_reciclar: float = 2000.0

# --- Colores placeholder (el pase visual va al final) ---
@export var color_suelo: Color = Color(0.16, 0.15, 0.19)
@export var color_roca: Color = Color(0.06, 0.06, 0.08)
@export var color_muro: Color = Color(0.34, 0.32, 0.40)

# La puerta de vuelta al pueblo (ya montada en la escena). Va por NodePath y no por grupo:
# el grupo lo añade door.gd en su _ready, que puede correr DESPUES que el nuestro.
@export var puerta_pueblo: NodePath

var gen: DungeonGenerator = null

var _enemy_scene: PackedScene = preload("res://scenes/actors/enemy/enemy.tscn")
var _zone_script: GDScript = preload("res://scripts/world/spawn_zone.gd")
var _stairs_script: GDScript = preload("res://scripts/world/stairs.gd")
var _pickup_script: GDScript = preload("res://scripts/items/drop_pickup.gd")

var _geo: Node2D = null      # toda la geometria del piso (se tira entera al regenerar)
var _zonas: Node2D = null    # todas las SpawnZone
var _t_barrido: float = 0.0  # acumulador del barrido de congelado

# QUE profundidad esta construida ahora mismo. NO se puede usar Game.current_floor para
# guardar el estado al salir: cuando el piso se regenera, current_floor YA vale el piso
# NUEVO (lo sube Game._cambiar_piso antes de llamarnos), y guardariamos los bichos del piso
# viejo bajo el numero del nuevo -> te los encontrarias esperandote abajo.
var _piso_construido: int = 0

const BARRIDO_CADA := 0.5


func _ready() -> void:
	add_to_group("dungeon_floor")  # asi Game.bajar_piso nos encuentra
	z_index = -1                   # el piso se dibuja por detras del jugador y de los bichos
	_construir()


# Vuelve a trazar el piso ENTERO (lo llama Game.bajar_piso). Sin recargar la escena: el
# jugador, su HUD y sus menus siguen vivos. Lo del piso viejo (bichos, cadaveres y lo que
# hubiera por el suelo) se queda atras: bajas con lo que llevas encima.
func regenerar(por_la_bajada: bool = false) -> void:
	_limpiar()
	_construir(por_la_bajada)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("bloquear_interaccion"):
		player.bloquear_interaccion()  # bajar es pulsar F: que no dispare nada al aterrizar


func _limpiar() -> void:
	_guardar_estado()   # ANTES de tirar nada: el piso que dejas se queda como lo dejas
	for grupo in ["enemy", "corpse", "pickup"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(n):
				continue
			# SACARLOS DEL GRUPO YA, no solo liberarlos: queue_free() no borra al instante
			# (lo hace al final del frame), asi que los bichos del piso viejo seguian
			# contando como vivos cuando el piso nuevo se poblaba -> el tope global se daba
			# por lleno y el piso 2 nacia VACIO.
			n.remove_from_group(grupo)
			n.queue_free()
	if _geo != null:
		_geo.queue_free()
		_geo = null
	if _zonas != null:
		_zonas.queue_free()
		_zonas = null


func _construir(por_la_bajada: bool = false) -> void:
	_piso_construido = Game.current_floor
	gen = DungeonGenerator.new()
	gen.generar(ancho_celdas, alto_celdas, _semilla_del_piso(),
		max_salas, sala_min, sala_max, ancho_pasillo)

	_construir_geometria()
	_colocar_actores(por_la_bajada)
	_crear_zonas()

	print("[mazmorra] piso ", Game.current_floor, " | semilla ", gen.semilla,
		" | ", gen.salas.size(), " salas, ", gen.zonas.size(), " zonas",
		" | ", gen.ancho, "x", gen.alto, " celdas")
	if spawn_table != null:
		print("[mazmorra] paren las paredes: ", spawn_table.resumen(Game.current_floor))
	else:
		push_warning("[mazmorra] el piso no tiene tabla de spawns: no va a parir nada")


# Cada piso, su mapa. La base es la SEMILLA DEL MUNDO de ESTA PARTIDA: cada jugador (y cada
# ranura de guardado) tiene SU mazmorra, y le dura. El numero primo evita que pisos
# consecutivos salgan parecidos. Si no hubiera partida cargada, el @export hace de reserva.
func _semilla_del_piso() -> int:
	var base: int = Game.semilla_mundo if Game.semilla_mundo != 0 else semilla_base
	return base + Game.current_floor * 7919


# ------------------------------------------------------------
#  GEOMETRIA
#  Ni un nodo por celda: las celdas contiguas se fusionan en tramos horizontales (Rect2i)
#  y cada tramo es UN ColorRect. La colision entera vive en un solo StaticBody2D con una
#  forma por tramo de muro.
# ------------------------------------------------------------
func _construir_geometria() -> void:
	var celda: float = float(DungeonGenerator.CELDA)

	_geo = Node2D.new()
	_geo.name = "Geo"
	add_child(_geo)

	# Fondo: la roca maciza (lo que hay detras de las paredes).
	var fondo := ColorRect.new()
	fondo.color = color_roca
	fondo.size = gen.tam_px()
	_geo.add_child(fondo)

	# Suelo pisable.
	for r in gen.suelos_fusionados():
		var cr := ColorRect.new()
		cr.color = color_suelo
		cr.position = Vector2(r.position) * celda
		cr.size = Vector2(r.size) * celda
		_geo.add_child(cr)

	# Muros: color + colision. Solo la roca que TOCA suelo (al resto no llegas nunca).
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Muros"
	_geo.add_child(cuerpo)
	for r in gen.muros_fusionados():
		var cr := ColorRect.new()
		cr.color = color_muro
		cr.position = Vector2(r.position) * celda
		cr.size = Vector2(r.size) * celda
		cuerpo.add_child(cr)

		var forma := RectangleShape2D.new()
		forma.size = Vector2(r.size) * celda
		var col := CollisionShape2D.new()
		col.shape = forma
		col.position = (Vector2(r.position) + Vector2(r.size) * 0.5) * celda
		cuerpo.add_child(col)


# ------------------------------------------------------------
#  ACTORES: jugador, puerta al pueblo y escalera de bajada.
#  El jugador y la puerta ya existen en la escena: aqui solo se los MUEVE a la sala de
#  entrada, que cambia con cada piso.
# ------------------------------------------------------------
func _colocar_actores(por_la_bajada: bool = false) -> void:
	if gen.salas.is_empty():
		push_warning("[mazmorra] el generador no saco ninguna sala")
		return

	var entrada: Rect2i = gen.salas[0]
	var centro: Vector2 = gen.centro_px(entrada.get_center())
	var lejana: Rect2i = _sala_mas_lejana(entrada)
	var fondo: Vector2 = gen.centro_px(lejana.get_center()) if lejana.size != Vector2i.ZERO else centro

	# DONDE APARECES:
	#  - Si CARGAS una partida hecha dentro de la mazmorra: en el sitio EXACTO donde guardaste.
	#  - Si vienes de abajo (has SUBIDO): por la escalera del fondo, no en la boca del piso.
	#    Subir no puede ser un atajo a la salida: hay que rehacer el camino.
	#  - Si no: en la boca del piso.
	var destino: Vector2 = fondo if por_la_bajada else centro
	if Game.pos_cargada != Vector2.INF:
		destino = Game.pos_cargada
		Game.pos_cargada = Vector2.INF   # de un solo uso: solo al cargar la partida

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("recolocar"):
		player.recolocar(destino)  # recolocar, no mover a pelo: no regala excelia de distancia

	# Que hay en la BOCA del piso, 2 celdas por encima de ti:
	#  - piso 1: la PUERTA al pueblo (el pueblo esta en la entrada de la mazmorra, no en
	#    cada piso: si te sigue hacia abajo, del piso 5 sales al pueblo de un paso).
	#  - piso 2+: una escalera de SUBIR al piso anterior. La puerta se aparta y se esconde.
	var boca: Vector2 = centro + Vector2(0.0, -2.0 * float(DungeonGenerator.CELDA))
	var puerta := get_node_or_null(puerta_pueblo)
	if puerta is Node2D:
		var en_superficie: bool = Game.current_floor <= 1
		(puerta as Node2D).visible = en_superficie
		# Fuera del alcance del jugador (la interaccion va por distancia): si solo la
		# ocultamos, seguiria siendo pulsable con F desde la sala de entrada.
		(puerta as Node2D).global_position = boca if en_superficie else Vector2(-1e6, -1e6)

	if Game.current_floor > 1:
		var subir = _stairs_script.new()
		subir.sube = true
		subir.position = boca
		_geo.add_child(subir)

	# La escalera de BAJAR, en la sala mas LEJANA a la entrada: descender obliga a cruzar la
	# mazmorra, que es justo donde el sistema de spawns se tiene que sostener. Va 2 celdas
	# por encima del centro (igual que la boca) para no aterrizar ENCIMA de ella al subir.
	if lejana.size != Vector2i.ZERO:
		var bajar = _stairs_script.new()
		bajar.position = fondo + Vector2(0.0, -2.0 * float(DungeonGenerator.CELDA))
		_geo.add_child(bajar)


func _sala_mas_lejana(desde: Rect2i) -> Rect2i:
	var mejor := Rect2i()
	var best_d: float = -1.0
	var origen: Vector2 = Vector2(desde.get_center())
	for s in gen.salas:
		if s == desde:
			continue
		var d: float = origen.distance_to(Vector2(s.get_center()))
		if d > best_d:
			best_d = d
			mejor = s
	return mejor


# ------------------------------------------------------------
#  ZONAS: una por sala y una por pasillo. Cada una conoce SUS paredes y pare por ellas.
# ------------------------------------------------------------
func _crear_zonas() -> void:
	_zonas = Node2D.new()
	_zonas.name = "Zonas"
	add_child(_zonas)

	# ¿Este piso ya lo habias pisado en esta expedicion? Entonces NO se puebla: se RESTAURA
	# tal y como lo dejaste (mismos bichos, mismos sitios, mismos cadaveres).
	var recordado: bool = Game.memoria_pisos.has(_piso_construido)

	# Zona de la sala donde apareces: se crea igual (sus paredes paren), pero no se puebla.
	var zona_entrada: int = -1
	if entrada_despejada and not gen.salas.is_empty():
		zona_entrada = gen.zona_en(gen.salas[0].get_center())

	for i in range(gen.zonas.size()):
		var z: Dictionary = gen.zonas[i]
		var celdas: Array = z["celdas"]
		var partos: Array = gen.celdas_de_parto(i)
		if celdas.is_empty() or partos.is_empty():
			continue  # una zona sin paredes propias no puede parir nada

		var es_sala: bool = z["tipo"] == "sala"
		var zona = _zone_script.new()
		zona.piso = self
		zona.zona_idx = i
		zona.tipo = z["tipo"]
		zona.partos = partos
		zona.intervalo_min = intervalo_min
		zona.intervalo_max = intervalo_max
		# Aforo por AREA: una sala grande sostiene mas bichos que un pasillo.
		var tope: int = maxi(1, celdas.size() / celdas_por_bicho)
		zona.max_vivos = mini(tope, max_vivos_sala if es_sala else max_vivos_pasillo)
		# Que deambulen por SU zona y no se vayan a la de al lado.
		var rect: Rect2i = z["rect"]
		var lado: float = float(mini(rect.size.x, rect.size.y)) * float(DungeonGenerator.CELDA)
		zona.wander_radius = clampf(lado * 0.5, 48.0, 160.0)
		# Por donde MERODEAN sus bichos: las celdas pisables de la zona. Antes deambulaban
		# en un circulo alrededor del sitio donde nacian y, como nacen PEGADOS A LA PARED,
		# medio circulo era roca: chocaban y se quedaban clavados contra el muro.
		var pts: Array = []
		for c in celdas:
			pts.append(gen.centro_px(c))
		zona.puntos = pts
		zona.hogar = _centro_pisable(pts)
		_zonas.add_child(zona)
		# DIFERIDO: al construir el piso desde _ready, el nodo padre (Main) aun esta montando
		# sus hijos y Godot rechaza cualquier add_child -> los bichos no llegaban a entrar en
		# la escena. Poblar un frame despues, con el arbol ya montado, los mete sin drama.
		if not recordado:
			var n: int = 0 if i == zona_entrada else int(round(float(zona.max_vivos) * poblacion_inicial))
			zona.call_deferred("poblar", n)

	# DIFERIDO igual que poblar: durante _ready el nodo padre aun se esta montando y Godot
	# rechaza los add_child (los bichos no llegarian a entrar en la escena).
	if recordado:
		call_deferred("_restaurar_estado")
	call_deferred("_log_poblacion", recordado)


func _log_poblacion(recordado: bool) -> void:
	print("[mazmorra] ", "RESTAURADO (ya lo habias pisado): " if recordado else "poblacion inicial: ",
		_vivos_en_el_piso(), " bichos vivos (tope ", max_vivos_piso, ")",
		", ", get_tree().get_nodes_in_group("corpse").size(), " cadaveres")


# El "hogar" de una zona: el punto PISABLE mas cercano a su centro. Se usa el mas cercano
# y no el centro a secas porque un pasillo en L tiene el centro geometrico dentro de la
# roca, y ahi mandariamos a los bichos a empotrarse.
func _centro_pisable(pts: Array) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var media := Vector2.ZERO
	for p in pts:
		media += p
	media /= float(pts.size())

	var mejor: Vector2 = pts[0]
	var best: float = INF
	for p in pts:
		var d: float = p.distance_squared_to(media)
		if d < best:
			best = d
			mejor = p
	return mejor


# ------------------------------------------------------------
#  MEMORIA DEL PISO: lo dejas como lo dejas, y al volver sigue igual.
#  Solo se guardan las COSAS (bichos, cadaveres, loot del suelo). La FORMA del piso no hace
#  falta: se rehace identica desde la semilla, asi que esto no crece con el tamaño del mapa.
# ------------------------------------------------------------
# Vuelca el piso ACTUAL a la memoria sin abandonarlo. Lo llama el guardado de partida: un
# piso solo se volcaba al salir de el, asi que guardar estando dentro dejaba el piso que
# estas pisando VACIO en el fichero.
func volcar_a_memoria() -> void:
	_guardar_estado()


func _guardar_estado() -> void:
	if _piso_construido <= 0 or gen == null:
		return

	var enemigos: Array = []
	# Vivos y CADAVERES. Los cadaveres tambien: llevan tu cristal dentro y perderlos por subir
	# un piso es justo lo que escuece. (Los ya extraidos no estan: se desvanecen al extraerlos.)
	for grupo in ["enemy", "corpse"]:
		for e in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(e) or e.data == null:
				continue
			enemigos.append({
				"data": e.data,
				"pos": e.global_position,
				# La 't' es lo que fija sus stats dentro de la franja del piso: sin guardarla,
				# el mismo slime reaparece con otras stats (mas flojo o mas bestia).
				"t": e.current_t,
				"zona": e.zona_idx,
				"muerto": grupo == "corpse",
			})

	var suelo: Array = []
	for p in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(p) and p.item != null:
			suelo.append({"item": p.item, "pos": p.global_position})

	Game.memoria_pisos[_piso_construido] = {"enemigos": enemigos, "suelo": suelo}
	print("[mazmorra] guardado el piso ", _piso_construido, ": ", enemigos.size(),
		" bichos (vivos+cadaveres), ", suelo.size(), " cosas por el suelo")


func _restaurar_estado() -> void:
	var mem: Dictionary = Game.memoria_pisos.get(_piso_construido, {})
	if mem.is_empty():
		return

	for d in (mem.get("enemigos", []) as Array):
		var zona = _zona(int(d["zona"]))
		var radio: float = zona.wander_radius if zona != null else 90.0
		var e = crear_enemigo(d["data"], d["pos"], radio, float(d["t"]))
		if e == null:
			continue
		e.zona_idx = int(d["zona"])
		if bool(d["muerto"]):
			e.morir()   # vuelve a ser un cadaver: gris, sin IA y con su cristal dentro
		elif zona != null:
			zona.adoptar(e)   # la zona lo cuenta como suyo, o parira por encima de su aforo

	for d in (mem.get("suelo", []) as Array):
		var pickup: Node2D = _pickup_script.new()
		pickup.setup(d["item"])
		var mundo: Node = get_parent()
		if mundo == null:
			mundo = self
		mundo.add_child(pickup)
		pickup.global_position = d["pos"]


func _zona(idx: int):
	if _zonas == null or idx < 0:
		return null
	for hijo in _zonas.get_children():
		var z = hijo
		if z.zona_idx == idx:
			return z
	return null


# ------------------------------------------------------------
#  SPAWNER DEL PISO (lo llaman las zonas)
# ------------------------------------------------------------

# Que bicho toca parir, segun la tabla del piso y la profundidad.
func elegir_enemigo() -> EnemyData:
	if spawn_table == null:
		return null
	return spawn_table.elegir(Game.current_floor)


# ¿Cabe un bicho mas en el piso? Si estamos al tope, se intenta hacer sitio reciclando al
# vivo mas LEJANO. Sin esto, "toda la mazmorra pare siempre" acaba con el piso lleno de
# bichos dormidos en la otra punta y la sala donde estas TU esteril.
# Al POBLAR el piso al entrar se llama con reciclar=false: si no, las ultimas zonas en
# poblarse se pondrian a borrar los bichos de las primeras para hacerse sitio.
func hay_sitio(reciclar: bool = true) -> bool:
	if _vivos_en_el_piso() < max_vivos_piso:
		return true
	return reciclar and _reciclar_lejano()


func _vivos_en_el_piso() -> int:
	return get_tree().get_nodes_in_group("enemy").size()


# Despawnea al enemigo vivo mas lejano al jugador, y SOLO si esta lejisimos (nunca se
# borra algo que puedas estar viendo). Los CADAVERES no se tocan jamas: llevan tu loot
# dentro y morir() ya los saca del grupo "enemy", asi que ni aparecen por aqui.
func _reciclar_lejano() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if not (player is Node2D):
		return false
	var pj: Vector2 = (player as Node2D).global_position

	var lejano: Node = null
	var best: float = dist_reciclar
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		var d: float = pj.distance_to((e as Node2D).global_position)
		if d > best:
			best = d
			lejano = e
	if lejano == null:
		return false
	lejano.queue_free()
	return true


# Instancia un enemigo. Mismo patron que el spawner de dev (scripts/ui/spawner.gd): el
# 'data' se asigna ANTES de add_child (su _ready lo usa) y se le recoloca DESPUES para
# re-fijar su "hogar" (si no, deambula hacia el (0,0) y cruza las paredes).
func crear_enemigo(data: EnemyData, pos: Vector2, radio: float, t: float = -1.0):
	if data == null:
		return null
	var e = _enemy_scene.instantiate()
	e.data = data
	e.wander_radius = radio
	# 't' impuesta (restaurando el piso): el bicho vuelve con las MISMAS stats que tenia.
	# Va antes de add_child porque su _ready es quien la lee.
	e.t_forzada = t
	# Cuelgan del PADRE del piso (junto al jugador) y no del piso: asi no heredan su
	# z_index de -1 y no se dibujan por debajo del suelo.
	var mundo: Node = get_parent()
	if mundo == null:
		mundo = self
	mundo.add_child(e)
	e.recolocar(pos)
	return e


# Barrido: a los bichos que estan lejisimos se les apaga la IA (no los ves, no hace falta
# simularlos) y se les vuelve a encender al acercarte. Los cadaveres ya vienen con la IA
# apagada de fabrica (morir()), asi que ni los tocamos.
func _process(delta: float) -> void:
	_t_barrido -= delta
	if _t_barrido > 0.0:
		return
	_t_barrido = BARRIDO_CADA

	var player := get_tree().get_first_node_in_group("player")
	if not (player is Node2D):
		return
	var pj: Vector2 = (player as Node2D).global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		var lejos: bool = pj.distance_to((e as Node2D).global_position) > dist_congelar
		e.set_physics_process(not lejos)


# ------------------------------------------------------------
#  DEV: comprobar las proporciones de la tabla sin jugar una hora.
# ------------------------------------------------------------
func test_proporciones(tiradas: int = 200) -> void:
	if spawn_table == null:
		return
	var cuenta: Dictionary = {}
	for _i in range(tiradas):
		var d: EnemyData = spawn_table.elegir(Game.current_floor)
		var nombre: String = d.enemy_name if d != null else "(nada)"
		cuenta[nombre] = int(cuenta.get(nombre, 0)) + 1
	print("[dev] ", tiradas, " tiradas de la tabla en el piso ", Game.current_floor, ":")
	for nombre in cuenta:
		var n: int = cuenta[nombre]
		print("   ", nombre, ": ", n, "  (", snappedf(100.0 * float(n) / float(tiradas), 0.1), "%)")
	print("[dev] esperado -> ", spawn_table.resumen(Game.current_floor))


# Fuerza un brote en la zona que tengas mas cerca. Los brotes estan APAGADOS en juego
# (aun no tienen proposito y sin balancear son una masacre): esto es para poder verlos.
func dev_brote_cercano() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not (player is Node2D) or _zonas == null:
		return
	var pj: Vector2 = (player as Node2D).global_position

	var mejor = null
	var best: float = INF
	for hijo in _zonas.get_children():
		var zona = hijo   # sin tipar: asi GDScript deja llamar a lo suyo (partos, brote_min...)
		if zona.partos.is_empty():
			continue
		# Distancia a la celda de parto mas cercana de esa zona.
		for p in zona.partos:
			var d: float = pj.distance_to(gen.centro_px(p["suelo"]))
			if d < best:
				best = d
				mejor = zona
	if mejor == null:
		return
	var n: int = randi_range(mejor.brote_min, mejor.brote_max)
	print("[dev] BROTE forzado en la zona ", mejor.zona_idx, " -> ", n, " bichos")
	mejor.forzar_parto(n)
