# ============================================================
#  munecos_reusables.gd -- LOS MUNECOS GRANDES DE LAS PANTALLAS, REUTILIZADOS (plan de optimizacion, fase 1D, 16/10)
# ============================================================
# El muneco de cuerpo entero del hogar, del altar o de la ficha se tiraba y se montaba de cero en cada clic: crear el
# MunecoJugador y montar sus ~35 capas son ~3 ms cada uno. Hornearlo como los retratos (RetratoHorneado) no sale a
# cuenta: a ese tamaño son ~6 MB por personaje con sus 8 fotogramas. Aqui se GUARDA el que ya esta montado y, al
# rehacer la pantalla, se saca del boton viejo (que se va a borrar) y se pone en el nuevo. Volver a montar(pj) con
# las mismas capas reaprovecha los nodos y solo repinta los colores (MunecoJugador.montar), y animar() con la misma
# animacion no la reinicia: no se nota nada, ni un salto en la respiracion.
#
#   var mu := MunecosReusables.dar("hogar|%d" % puesto, pj)   # montado, teñido y con su cara; sin padre
#   ...colocarlo como siempre...; caja.add_child(mu)
#
# La CLAVE es el sitio (pantalla + hueco), no el personaje: si en ese hueco ahora va otro, el mismo muneco se monta
# con el (montar cambia lo que haga falta). Si el boton viejo ya se borro en un fotograma anterior, el muneco se fue
# con el: se crea uno nuevo.
class_name MunecosReusables
extends RefCounted

static var _guardados: Dictionary = {}   # clave -> MunecoJugador


static func dar(clave: String, pj: PersonajeData) -> MunecoJugador:
	var mu = _guardados.get(clave)
	if mu != null and is_instance_valid(mu) and not (mu as Node).is_queued_for_deletion():
		var padre: Node = (mu as Node).get_parent()
		if padre != null:
			padre.remove_child(mu)
		# MenuScaffold.vaciar marca "muriendo" el boton viejo Y TODO LO DE DENTRO (y hay quien mira esa marca para no
		# tocar lo que se va a borrar): el rescatado no se muere, se le quita.
		_desmarcar(mu)
	else:
		mu = MunecoJugador.new()
		_guardados[clave] = mu
	var m: MunecoJugador = mu
	m.montar(pj)
	m.tenir(pj.color, 0.0)
	m.poner_cara(pj.textura())
	m.modulate = Color.WHITE   # quien lo atenue, que lo vuelva a atenuar: no se hereda del uso anterior
	return m


# Para quien decida no usarlo (no hay dibujo): que no se quede guardado fuera del arbol.
static func soltar(clave: String) -> void:
	var mu = _guardados.get(clave)
	_guardados.erase(clave)
	if mu != null and is_instance_valid(mu) and (mu as Node).get_parent() == null:
		(mu as Node).queue_free()


static func _desmarcar(n: Node) -> void:
	if n.has_meta(MenuScaffold.META_MURIENDO):
		n.remove_meta(MenuScaffold.META_MURIENDO)
	for h in n.get_children():
		_desmarcar(h)
