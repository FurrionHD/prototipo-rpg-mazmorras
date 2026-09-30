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
# LA AMENAZA (30/09, como en el WoW; plan stateless-sniffing-bentley): cada enemigo con su tabla (Combatant.amenaza).
# Tu cuota de SU tabla multiplica tu peso: 1 + AMENAZA_PESO x cuota x vivos (con la cuota justa, x3 todos; con
# toda la amenaza, x(1 + 2n)). El sigilo genera la mitad; las curas, la mitad de lo curado repartida entre todos.
const AMENAZA_PESO := 2.0
const AMENAZA_CURA := 0.5
const AMENAZA_SIGILO := 0.5
const AMENAZA_PROVOCA := 1.1     # la Provocacion te pone un 10% por encima del primero de su tabla
# A QUIEN SE ACERCA (CombatTactico._presa_de): el de mas peso ENTRE LOS QUE LE LLEGAN ESTE TURNO. Solo persigue a
# uno que no le llega si le provoca o si pesa esto veces el mejor de los que si (lo pidio el: "si va a tardar dos
# turnos en llegar al que mas aggro le genera, no debe ir a por el si en este turno puede pegar a uno").
const PERSEGUIR_X := 2.5
# LAS PASIVAS EN EL REPARTO (30/09): el chillon va a por el que va en sigilo (y sin la rebaja del sigilo), la araña
# a por el que esta en su red, y la segadora evita al primero de su tabla (va a por los blandos).
const ECO_SIGILO := 3.0
const EMBOSCADA_PESO := 2.0
const EVITA_TANQUE := 0.35


# A QUIEN pega el enemigo: uno de los tuyos que siga en pie, sorteado por PESO. Dos capas, y ninguna
# FUERZA nada (solo inclinan la balanza; el mago nunca esta a salvo del todo):
#   1) PASIVO: llevar ESCUDO pesa AGGRO_ESCUDO (x2). El que va tapado atrae golpes sin hacer nada.
#   2) PROVOCAR: la habilidad de escudo multiplica por PROVOCA_PESO (x4) durante unos turnos.
# Un tanque con escudo pasa de ~40% de los golpes (en un grupo de 4) a ~73% mientras provoca.
func _elegir_objetivo_enemigo(atenuado: bool = false) -> Combatant:
	var vivos: Array[Combatant] = _pantalla._aliados_vivos()
	# EN EL MAPA, solo los que alcanza desde donde esta. Si no llega a nadie sale null, y quien llama
	# ya sabe que hacer con eso (el enemigo pierde el ataque, ver _enemy_turn).
	var quien: Combatant = _pantalla.turno_mapa.atacante if _pantalla.tactico else null
	if quien != null:
		vivos = _pantalla.turno_mapa.alcanzables(quien, vivos)
	if vivos.is_empty():
		return null
	# OLOR A SANGRE (el acechador): ni aggro ni sorteo, va a por quien sangra. Provocado si hace caso a la Provocacion.
	var olor: Combatant = presa_por_olor(quien, vivos)
	if olor != null and not atenuado:
		return _redirigir_cobertura(olor)
	var pesos: Array[float] = []
	var total: float = 0.0
	for c in vivos:
		var w: float = _peso_aggro(c, quien)
		# SORTEO INCLINADO (30/09): en la eleccion de UN objetivo el peso va AL CUADRADO -- casi siempre el primero
		# de su tabla, alguna vez otro. ATENUADO (el reparto GOLPE A GOLPE de una multi-golpe, que sortea 5-6
		# veces seguidas): el peso a secas, para que los demas reciban lo suyo sin invertir el orden.
		if not atenuado:
			w = w * w
		pesos.append(w)
		total += w
	var r: float = randf() * total
	for i in vivos.size():
		r -= pesos[i]
		if r < 0.0:
			return _redirigir_cobertura(vivos[i])
	return _redirigir_cobertura(vivos[vivos.size() - 1])


# OLOR A SANGRE (30/09, EnemyData.olor_sangre_mult): entre 'vivos', el que sangra (el que menos vida le quede si son
# varios) y, si nadie sangra, el de menos vida (por fraccion). null si 'quien' no tiene la pasiva o esta PROVOCADO
# (la Provocacion del escudo le puede: es la herramienta del tanque para quitarselo al herido).
func presa_por_olor(quien: Combatant, vivos: Array) -> Combatant:
	if quien == null or quien.olor_sangre_mult == 1.0 or vivos.is_empty():
		return null
	for c in vivos:
		if c.provocar_turnos > 0 and quien in c.provocados:
			return null
	var mejor: Combatant = null
	var clave_mejor: float = INF
	for c in vivos:
		# Los que sangran van antes que cualquiera que no sangre (el +1 los separa: la fraccion va de 0 a 1).
		var clave: float = c.current_hp / maxf(1.0, c.max_hp) + (0.0 if c.has_status(StatusEffects.Id.SANGRADO) else 1.0)
		if clave < clave_mejor:
			clave_mejor = clave
			mejor = c
	return mejor


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
#
# 'atacante': EN EL MAPA la Provocacion solo pesa para los enemigos que pillo su huella (Combatant.provocados).
# Sin atacante (el reparto de la excelia) o sin lista (la fila), pesa para todos.
func _peso_aggro(c: Combatant, atacante: Combatant = null) -> float:
	var provoca: bool = c.provocar_turnos > 0 and (atacante == null or c.provocados.is_empty()
		or atacante in c.provocados)
	var w: float = c.aggro_base * (PROVOCA_PESO if provoca else 1.0) * c.status_aggro_mult()
	# SIN UN ENEMIGO CONCRETO (el reparto de la excelia de Resistencia) se queda como siempre.
	if atacante == null or not _pantalla._enemies.has(atacante):
		return w
	# SU TABLA DE AMENAZA: tu cuota de lo que le han hecho entre todos los que siguen en pie.
	var total: float = 0.0
	for k in atacante.amenaza.keys():
		if is_instance_valid(k) and (k as Combatant).is_alive():
			total += float(atacante.amenaza[k])
	if total > 0.0:
		var cuota: float = float(atacante.amenaza.get(c, 0.0)) / total
		w *= 1.0 + AMENAZA_PESO * cuota * float(_pantalla._aliados_vivos().size())
	if atacante.ecolocaliza and c.has_status(StatusEffects.Id.SIGILO):
		w = w / maxf(c.status_aggro_mult(), 0.01) * ECO_SIGILO
	if atacante.emboscada_mult != 1.0 and c.has_status(StatusEffects.Id.PEGAJOSO):
		w *= EMBOSCADA_PESO
	if atacante.evita_tanque and _pantalla._aliados_vivos().size() > 1 and atacante.primero_en_amenaza() == c:
		w *= EVITA_TANQUE
	return w


# CUANTA AMENAZA GENERA 'quien' por cada punto: el doble con escudo (aggro_base: el tanque tiene que PEGAR para
# sujetarlos) y la mitad en sigilo.
func generacion_amenaza(quien: Combatant) -> float:
	if quien == null:
		return 1.0
	return quien.aggro_base * (AMENAZA_SIGILO if quien.has_status(StatusEffects.Id.SIGILO) else 1.0)


# CURAR TAMBIEN SE NOTA: la mitad de lo curado, repartida entre todos los enemigos vivos. El curandero no pasa
# desapercibido, pero pega menos que pegar.
func amenaza_por_cura(sanador: Combatant, cura: float) -> void:
	if sanador == null or cura <= 0.0 or not _pantalla._aliados.has(sanador):
		return
	var vivos: Array = _pantalla._vivos()
	if vivos.is_empty():
		return
	var parte: float = cura * AMENAZA_CURA * generacion_amenaza(sanador) / float(vivos.size())
	for e in vivos:
		(e as Combatant).sumar_amenaza(sanador, parte)


# LA PROVOCACION: a los que pillo (o a todos, en la fila) les pone a 'quien' un poco por encima del primero de su
# tabla. Ademas sigue pesando PROVOCA_PESO mientras dure.
func provocar_amenaza(quien: Combatant, enemigos: Array) -> void:
	if quien == null:
		return
	for e in (enemigos if not enemigos.is_empty() else _pantalla._vivos()):
		var c: Combatant = e
		var top: float = 0.0
		for k in c.amenaza.keys():
			top = maxf(top, float(c.amenaza[k]))
		c.amenaza[quien] = maxf(float(c.amenaza.get(quien, 0.0)), top * AMENAZA_PROVOCA + 1.0)


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
