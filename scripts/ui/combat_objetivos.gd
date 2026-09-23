# ============================================================
#  combat_objetivos.gd  (tema de la pantalla de combate: combat.objetivos)
#  A QUIEN SE PEGA: como elige victima un enemigo (amenaza, provocacion, Resistencia), la COBERTURA
#  que redirige golpes y los objetivos de un AREA (adyacentes y escalas), de los dos bandos.
#  Los ayudantes basicos (_objetivo, _vivos, _aliados_vivos, _etq) siguen en la pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# PROVOCACION (taunt de escudo): cuanto MAS pesa un aliado que provoca al sortear el objetivo del
# enemigo, frente a los que no (peso 1.0). x4 => con 1 provocador entre 4, ~57% de los golpes van a
# el; el resto se reparte. No es forzado: solo inclina la balanza. PROVISIONAL -> playtest.
const PROVOCA_PESO := 4.0


# A QUIEN pega el enemigo: uno de los tuyos que siga en pie, sorteado por PESO. Dos capas, y ninguna
# FUERZA nada (solo inclinan la balanza; el mago nunca esta a salvo del todo):
#   1) PASIVO: llevar ESCUDO pesa AGGRO_ESCUDO (x2). El que va tapado atrae golpes sin hacer nada.
#   2) PROVOCAR: la habilidad de escudo multiplica por PROVOCA_PESO (x4) durante unos turnos.
# Un tanque con escudo pasa de ~40% de los golpes (en un grupo de 4) a ~73% mientras provoca.
func _elegir_objetivo_enemigo(atenuado: bool = false) -> Combatant:
	var vivos: Array[Combatant] = _pantalla._aliados_vivos()
	if vivos.is_empty():
		return null
	var pesos: Array[float] = []
	var total: float = 0.0
	for c in vivos:
		var w: float = _peso_aggro(c)
		# ATENUADO: para el reparto GOLPE A GOLPE de una habilidad multi-golpe. Ahi el sorteo se
		# repite 5-6 veces seguidas, y con el peso entero el tanque se comia casi la tanda completa
		# (~5 de 6). La raiz cuadrada lo suaviza SIN invertir el orden: sigue siendo el que mas come,
		# pero los demas reciben lo suyo. En la eleccion de UN objetivo (turno normal) no se toca.
		if atenuado:
			w = sqrt(w)
		pesos.append(w)
		total += w
	var r: float = randf() * total
	for i in vivos.size():
		r -= pesos[i]
		if r < 0.0:
			return _redirigir_cobertura(vivos[i])
	return _redirigir_cobertura(vivos[vivos.size() - 1])


# COBERTURA (escudo grande): el golpe que el sorteo le manda al protegido se lo come su protector.
# Es lo unico del juego que MUEVE un golpe de un objetivo a otro; la Provocacion solo inclina la
# balanza del sorteo, y por eso son dos cosas y no una.
#
# VA AQUI, en la eleccion de objetivo, y no al aplicar el daño. Tres motivos:
#   - los ~16 sitios que eligen objetivo lo heredan gratis, en vez de parchear las dos ramas de daño;
#   - el _fx_golpe sale con la direccion buena: la tarjeta que se sacude es la del que se lo come;
#   - la defensa, el defend_defense y el bloqueo del protector entran SOLOS, sin tocar StatsMath.
#     "Te tapa con SU escudo" sale de aqui, no de una formula nueva.
#
# Se evalua EN EL MOMENTO de elegir, no al activarla: un protector que acaba de caer o de huir deja
# de tapar sin que nadie tenga que ir a limpiarlo.
#
# SOLO EL OBJETIVO PRINCIPAL. Los secundarios de un area no pasan por aqui (los saca
# _objetivos_area_aliados de los VECINOS del principal), asi que la regla se cumple sola: un area
# que pilla a tres no puede colapsar en tres golpes al tanque. No hay que escribir nada para eso,
# pero queda dicho para que no se "arregle" mas adelante.
#
# ATURDIDO: ese golpe NO se redirige, pero la cobertura NO cae. Estas grogui y se te cuela uno;
# cuando te recuperas sigues plantado delante. Enraizado si tapa (ver Combatant.aturdido).
func _redirigir_cobertura(obj: Combatant) -> Combatant:
	if obj == null:
		return null
	var p: Combatant = obj.protegido_por
	if p == null or p == obj or p.proteger_turnos <= 0:
		return obj
	if not p.is_alive() or _pantalla._huidos.has(p) or p.aturdido():
		return obj
	return p


# Cierra las coberturas que llegaron por red como INDICE (ver _volatil / _aplicar_volatil). Corre
# una vez, con todos los aliados ya montados.
# Si el indice no cuadra -- el protector era del que se fue, o habia huido, y estado_para_traspaso
# se los salta -- la cobertura se rompe EN SILENCIO. Mejor quedarse sin protector que quedarse con
# el equivocado: lo primero se nota (te pegan) y lo segundo manda golpes a quien no toca.
func _reenlazar_coberturas() -> void:
	for c in _pantalla._cobertura_pendiente:
		var idx: int = int(_pantalla._cobertura_pendiente[c])
		var otro: Combatant = _pantalla._aliados[idx] if idx >= 0 and idx < _pantalla._aliados.size() else null
		if otro == null or otro == c or not otro.is_alive() or _pantalla._huidos.has(otro):
			_romper_cobertura(c)
			continue
		c.protegiendo_a = otro
		otro.protegido_por = c
	_pantalla._cobertura_pendiente.clear()


# Rompe la pareja de cobertura POR LOS DOS LADOS. Vive aparte porque se llama desde cuatro sitios
# (se acaba el tiempo, cae el protector, cae el protegido, se pone una cobertura nueva) y dejar un
# solo lado puesto es un puntero colgado que solo se nota en la pelea siguiente.
func _romper_cobertura(c: Combatant) -> void:
	if c == null:
		return
	if c.protegiendo_a != null:
		if c.protegiendo_a.protegido_por == c:
			c.protegiendo_a.protegido_por = null
		c.protegiendo_a = null
	c.proteger_turnos = 0
	# Y por el otro lado: si a ESTE lo estaban cubriendo, el que lo cubria se queda sin trabajo.
	if c.protegido_por != null:
		if c.protegido_por.protegiendo_a == c:
			c.protegido_por.protegiendo_a = null
			c.protegido_por.proteger_turnos = 0
		c.protegido_por = null


# PESO DE AGGRO de un aliado: el PASIVO (x2 si lleva escudo) x el de PROVOCAR (x4 mientras dure).
# Un tanque quieto ya atrae ~el doble; provocando, se lleva la mayoria de los golpes unos turnos.
# Vive aparte porque lo leen DOS sitios: el sorteo de objetivo y el reparto de la excelia de
# Resistencia (_mult_resistencia_aggro). Si cada uno tuviera su copia, se desincronizarian.
# El SIGILO entra aqui como el espejo exacto de la Provocacion: un multiplicador mas sobre el mismo
# peso. Por eso INCLINA la balanza y no obliga -- al sigiloso le siguen pudiendo pegar, igual que
# provocar no garantiza que te peguen a ti.
func _peso_aggro(c: Combatant) -> float:
	return c.aggro_base * (PROVOCA_PESO if c.provocar_turnos > 0 else 1.0) * c.status_aggro_mult()


func _peso_aggro_total() -> float:
	var total: float = 0.0
	for c in _pantalla._aliados_vivos():
		total += _peso_aggro(c)
	return total


# CUANTA Resistencia entrena 'obj' por encajar un golpe, comparado con lo que entrenaria si el
# aggro no existiera. Ver el bloque de constantes en game.gd (RESIS_COMPENSA_K y compania):
#   - Al que el tanque protege le llegan pocos golpes -> se le compensa fuerte.
#   - Al tanque le llegan muchos pero mermados -> se le compensa poco (ya gana por frecuencia).
# Con un solo aliado vivo, o sin escudo ni Provocar, devuelve 1.0: nada cambia respecto a antes.
func _mult_resistencia_aggro(obj: Combatant) -> float:
	var vivos: Array[Combatant] = _pantalla._aliados_vivos()
	if vivos.size() < 2:
		return 1.0
	var total: float = _peso_aggro_total()
	if total <= 0.0:
		return 1.0
	var cuota: float = _peso_aggro(obj) / total
	var justa: float = 1.0 / float(vivos.size())
	if cuota <= 0.0:
		return 1.0
	if cuota < justa:
		# Le pegan MENOS de lo que le tocaria: el mago detras del escudo.
		var deficit: float = clampf(1.0 - cuota / justa, 0.0, 1.0)
		return 1.0 + Game.RESIS_COMPENSA_K * pow(deficit, Game.RESIS_APORTE_EXP)
	# Le pegan MAS de lo que le tocaria: el que va tapado y plantado delante.
	var exceso: float = clampf(1.0 - justa / cuota, 0.0, 1.0)
	return 1.0 + Game.RESIS_TANQUE_K * pow(exceso, Game.RESIS_APORTE_EXP)


# --- EL ALCANCE, que ahora vive en combat_geometria.gd -----------------------------------------
# Lo de "a quien MAS alcanza" se mudo a su propio tema (`geo`) porque es la unica pieza del combate
# que depende de COMO estan colocados los combatientes: cambiando esa pieza se puede pelear en el
# mapa con posiciones de mundo sin tocar una sola linea de daño. Aqui se quedo lo que decide a quien
# se pega por AMENAZA (aggro, provocacion, cobertura), que no mira el sitio de nadie.
#
# Estos cuatro nombres NO se mueven: son la puerta por la que entran combat_magia, combat_enemigos y
# tools/prueba_formacion_combate.gd. Delegan y ya.
func _adyacentes_vivos(principal: Combatant) -> Array[Combatant]:
	return _pantalla.geo._adyacentes_vivos(principal)


func _objetivos_area(spell: SpellData, principal: Combatant) -> Array:
	return _pantalla.geo._objetivos_area(spell, principal)


func _adyacentes_aliados_vivos(principal: Combatant) -> Array[Combatant]:
	return _pantalla.geo._adyacentes_aliados_vivos(principal)


func _objetivos_area_aliados(ab: AbilityData, principal: Combatant) -> Array:
	return _pantalla.geo._objetivos_area_aliados(ab, principal)
