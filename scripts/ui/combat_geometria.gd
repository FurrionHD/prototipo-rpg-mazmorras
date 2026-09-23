# ============================================================
#  combat_geometria.gd  (tema de la pantalla de combate: combat.geo)
#  LA GEOMETRIA DE LOS OBJETIVOS: dado un objetivo principal, A QUIEN MAS alcanza lo que le lanzas
#  y con cuanta fuerza le llega a cada uno.
#
#  Esta es la implementacion de FILA, la de siempre: los combatientes estan en dos filas de tarjetas
#  y "al lado" significa la columna de al lado EN PANTALLA. Todo lo de aqui mide en INDICES de fila.
#
#  POR QUE VIVE APARTE. Es la unica pieza del combate que depende de COMO estan colocados los
#  combatientes. El resto del motor (el ATB, el daño, los estados, la red) habla de combatientes y
#  de indices, no de sitios. Sacandola a su propio archivo, un combate colocado de otra forma -- en
#  el mapa, con posiciones de mundo y areas dibujadas en el suelo -- solo tiene que traer OTRA
#  implementacion de estas seis funciones: combat_geometria_mapa.gd. Ni una linea de daño cambia.
#
#  LA REGLA, para que la costura siga sirviendo de algo:
#    Si te encuentras escribiendo un `if` sobre el modo de combate DENTRO de una funcion que
#    resuelve daño (_accion_atacar, _resolver_hechizo, StatsMath), la costura esta en el sitio
#    equivocado. Las ramas solo existen aqui (geometria) y en el montaje (puesta en escena).
#
#  QUE NO ESTA AQUI, a proposito:
#    - `_objetivo()` (combat.gd) -- es la SELECCION (a quien apuntas), no el alcance.
#    - `_etq()` (combat.gd) -- es la numeracion para el log.
#    - la cobertura y el aggro (combat_objetivos) -- deciden a quien, pero por amenaza, no por sitio.
#
#  Quien llama a esto lo hace por `objetivos.*` y `habilidades.*`, que delegan aqui: esos nombres son
#  la puerta publica y no se mueven (los usa hasta tools/prueba_formacion_combate.gd).
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos; los NOMBRES no los comprueba al compilar: de eso se
# encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# Los VECINOS de 'principal' a los que salpica un hechizo de area: el de su izquierda y el de su
# derecha EN PANTALLA (maximo 2).
#
# VA POR EL ORDEN DE PANTALLA (_fila_visual_enemigos), no por el del array, y esa es la clave: los
# cadaveres ya no estan en la fila (se retiran, ver _retirando) y el jefe se recoloca al centro
# (_ordenar_fila_enemigos), asi que el array y lo que ves pueden decir cosas distintas. Lo que
# salpica tiene que ser lo que el jugador ve al lado; si no, el hechizo alcanza a alguien que en la
# pantalla esta a dos huecos y parece un bug aunque el numero sea correcto.
#
# Los muertos no cuentan y no absorben nada: nada se lanza al vacio (misma regla que _objetivo()).
func _adyacentes_vivos(principal: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var fila: Array[Combatant] = _pantalla.altas._fila_visual_enemigos()
	var centro: int = fila.find(principal)
	if centro < 0:
		return out
	for paso in [-1, 1]:
		var i: int = centro + paso
		if i >= 0 and i < fila.size():
			out.append(fila[i])
	return out


# A quien alcanza la fase de AREA, con el multiplicador de daño de cada uno ya puesto:
# [{c: Combatant, escala: float}]. El principal va SIEMPRE el primero (el log lo cuenta asi).
func _objetivos_area(spell: SpellData, principal: Combatant) -> Array:
	var out: Array = [{"c": principal, "escala": spell.dano_objetivo}]
	if not spell.salpica():
		return out
	var vecinos: Array[Combatant] = []
	match spell.alcance:
		SpellData.Alcance.ADYACENTES:
			vecinos = _adyacentes_vivos(principal)
		SpellData.Alcance.TODOS:
			vecinos = _pantalla._vivos()
	for c in vecinos:
		if c != principal:
			out.append({"c": c, "escala": spell.dano_salpicon})
	return out


# Los aliados PEGADOS a 'principal': el de su izquierda y el de su derecha, y ya. Lo usa el AREA de
# las habilidades ENEMIGAS (un slime que aplasta salpica a los de al lado).
#
# SOLO centro-1 y centro+1, y si estan KO no entran. Antes esto era un `while` que se SALTABA a los
# muertos y seguia buscando al siguiente vivo, asi que con un compañero caido el salpicon aterrizaba
# en alguien que estaba a dos o tres huecos, con un cuerpo en medio -- y eso ya no es "de al lado".
#
# El gemelo de la fila de ENFRENTE (_adyacentes_vivos) no necesita este arreglo: alli los cadaveres
# se retiran de la fila (ver _retirando), asi que el vecino de al lado siempre esta vivo. Aqui no,
# porque las tarjetas de los tuyos se quedan puestas a proposito.
#
# POR LA FILA QUE SE VE (la de la formacion, ver combat_altas._fila_visual_aliados) y no por el orden del
# array: el que entro el 4o y se ve en el puesto 2 tiene por vecinos al 1 y al 3.
func _adyacentes_aliados_vivos(principal: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var fila: Array[Combatant] = _pantalla.altas._fila_visual_aliados()
	var centro: int = fila.find(principal)
	if centro < 0:
		return out
	for paso in [-1, 1]:
		var i: int = centro + paso
		if i >= 0 and i < fila.size() and fila[i].is_alive():
			out.append(fila[i])
	return out


# A quien alcanza el AREA de una habilidad ENEMIGA sobre tu grupo, con su escala de daño ya puesta:
# [{c, escala}]. El principal SIEMPRE el primero.
#
# EL ALCANCE lo decide area_max: >= 99 = TODA la fila (Pisotón, Chillido, Bramido, Marea); si no,
# solo los ADYACENTES (Combustión, Carga, Reventón). Por eso esas fijan area_max = 3.
# Y area_centrada se salta todo eso: la huella cae en MEDIO del grupo y los tapa a todos (ver
# AbilityData.area_centrada; es el Aplastamiento del Rey).
#
# EL REPARTO sale de area_escalas si la habilidad la trae (por cercania al centro de la huella), y
# si no, de area_secundario como siempre.
func _objetivos_area_aliados(ab: AbilityData, principal: Combatant) -> Array:
	var alcanzados: Array[Combatant] = []
	if ab.area_centrada or ab.area_max >= 99:
		alcanzados = _pantalla._aliados_vivos()
	else:
		alcanzados.append(principal)
		for c in _adyacentes_aliados_vivos(principal):
			if c != principal:
				alcanzados.append(c)
	if alcanzados.is_empty():
		alcanzados.append(principal)

	# EL CENTRO DE LA HUELLA, en indices de la fila. Centrada = el medio del grupo vivo; si no, el
	# objetivo. Es lo que decide quien se lleva la peor parte, y es EL MISMO dato con el que se
	# dibuja: lo que ves tapado es exactamente lo que cobra.
	# Las posiciones son las de la FILA QUE SE VE, no las del array (ver _adyacentes_aliados_vivos).
	var fila_v: Array[Combatant] = _pantalla.altas._fila_visual_aliados()
	var centro: float = 0.0
	if ab.area_centrada:
		var suma: float = 0.0
		for c in alcanzados:
			suma += float(fila_v.find(c))
		centro = suma / float(alcanzados.size())
	else:
		centro = float(fila_v.find(principal))

	# Sin tabla, el de siempre: el principal entero y los demas a area_secundario.
	if ab.area_escalas.is_empty():
		var out: Array = [{"c": principal, "escala": 1.0}]
		for c in alcanzados:
			if c != principal:
					out.append({"c": c, "escala": ab.area_secundario})
		return out

	# CON tabla: se ordenan por cercania al centro (desempatando por indice, para que dos peleas
	# iguales repartan igual) y se les va dando la escala que toca.
	var orden: Array = alcanzados.duplicate()
	orden.sort_custom(func(x, y):
		var ix: float = absf(float(fila_v.find(x)) - centro)
		var iy: float = absf(float(fila_v.find(y)) - centro)
		if is_equal_approx(ix, iy):
			return fila_v.find(x) < fila_v.find(y)
		return ix < iy)
	# La fila de la tabla que toca por numero de alcanzados; si se pasa, la ultima que haya.
	var fila: Array = ab.area_escalas[mini(orden.size(), ab.area_escalas.size()) - 1]
	var out2: Array = []
	for i in orden.size():
		var esc: float = float(fila[i]) if i < fila.size() else ab.area_secundario
		out2.append({"c": orden[i], "escala": esc})
	# El PRINCIPAL tiene que ir el primero: el log y los efectos lo dan por hecho (el de la posicion
	# 0 es "el objetivo"). Con la tabla el orden es por cercania, asi que puede no coincidir.
	for i in out2.size():
		if out2[i]["c"] == principal:
			if i > 0:
				out2.insert(0, out2.pop_at(i))
			break
	return out2


# Los OBJETIVOS de una habilidad de ÁREA: el principal SIEMPRE el primero, y detrás sus
# vecinos VIVOS más cercanos (alternando izquierda/derecha) hasta llenar area_max. Reusa la
# misma geometría que el salpicón de los hechizos: los cadáveres no cuentan ni desplazan la
# numeración (ver _adyacentes_vivos). area_max >= nº de vivos -> toca a todos.
func _objetivos_hab(ab: AbilityData, principal: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = [principal]
	if not ab.es_area() or ab.area_max <= 1:
		return out
	# POR LA FILA QUE SE VE y no por el array: con el Rey Slime recolocado al centro, el array y la
	# pantalla no coinciden, y "el de al lado" tiene que ser el que el jugador ve al lado.
	var fila: Array[Combatant] = _pantalla.altas._orden_visual_enemigos_todos()
	var centro: int = fila.find(principal)
	if centro < 0:
		return out
	# Punteros que se alejan del centro a cada lado; cogemos el primer vivo de cada tanda.
	var izq: int = centro - 1
	var der: int = centro + 1
	while out.size() < ab.area_max:
		var anadido := false
		# Izquierda: primer vivo hacia el borde.
		while izq >= 0:
			if fila[izq].is_alive():
				out.append(fila[izq]); izq -= 1; anadido = true
				break
			izq -= 1
		if out.size() >= ab.area_max:
			break
		# Derecha: primer vivo hacia el borde.
		while der < fila.size():
			if fila[der].is_alive():
				out.append(fila[der]); der += 1; anadido = true
				break
			der += 1
		if not anadido:
			break   # no quedan vivos a ningún lado
	return out


# El enemigo VIVO más cercano a 'muerto' (para redirigir los golpes que sobran de una flurry
# cuando el objetivo cae). Primero mira a los lados; si no, el primero vivo que haya. null si no
# queda nadie.
func _siguiente_vivo(muerto: Combatant) -> Combatant:
	var fila: Array[Combatant] = _pantalla.altas._orden_visual_enemigos_todos()   # la que se ve
	var centro: int = fila.find(muerto)
	if centro >= 0:
		for paso in [-1, 1]:
			var i: int = centro + paso
			while i >= 0 and i < fila.size():
				if fila[i].is_alive():
					return fila[i]
				i += paso
	var vivos: Array[Combatant] = _pantalla._vivos()
	return vivos[0] if not vivos.is_empty() else null
