# ============================================================
#  combat_efectos.gd  (tema de la pantalla de combate: combat.efectos)
#  LO QUE SE VE AL PEGAR: las barras de vida, energia y mana (con su numero), los efectos de cada golpe
#  (estilo, gesto, sonido y color segun arma, habilidad o hechizo) y los CHIPS de estado de cada tarjeta.
#  _update_hp y _bloque_de, que usa todo el combate, siguen en la pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


const ALTO_BARRA_MENOR := 13.0   # energia y maná


# Crea las barras de ENERGIA (amarilla) y MANA (azul) de UN aliado, justo debajo de su barra de
# vida, dentro de su bloque, y las guarda en el propio bloque. Cada aliado tiene las suyas: la
# energia y el maná se gastan por persona, asi que no puede haber "la barra del jugador".
func _crear_barras_aliado(bloque: Dictionary, c: Combatant) -> void:
	var vb: VBoxContainer = bloque["vbox"]
	# OJO: self_modulate y no modulate. modulate tiñe TAMBIEN a los hijos, y estas barras
	# llevan dentro el Label con el numero: se pintaria de amarillo/azul y no se leeria.
	if c.max_energy > 0.0:
		var en := ProgressBar.new()
		en.show_percentage = false
		en.max_value = c.max_energy
		en.custom_minimum_size = Vector2(0, ALTO_BARRA_MENOR)
		en.self_modulate = Color(0.95, 0.85, 0.3)   # energia = amarillo
		en.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(en)
		bloque["en"] = en
		bloque["en_lbl"] = _crear_label_barra(en, 11)
	if c.max_mp > 0.0:
		var mp := ProgressBar.new()
		mp.show_percentage = false
		mp.max_value = c.max_mp
		mp.custom_minimum_size = Vector2(0, ALTO_BARRA_MENOR)
		mp.self_modulate = Color(0.4, 0.6, 1.0)     # mana = azul
		mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(mp)
		bloque["mp"] = mp
		bloque["mp_lbl"] = _crear_label_barra(mp, 11)


# Label centrado que cubre toda la barra, para pintar el numero DENTRO. Con borde oscuro
# para que se lea sobre cualquier color de relleno (mismo patron que las barras del mapa).
func _crear_label_barra(bar: ProgressBar, tam: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(l)
	return l


# Fija el destino de UNA barra. Envoltorio para no repetir en los cuatro sitios el "y si no hay
# capa de efectos, a pelo": la pantalla tiene que funcionar igual sin CombatFX (es decoracion).
func _fijar_barra(bloque: Dictionary, clave: String, valor: float, inmediato := false) -> void:
	if _pantalla._fx != null:
		_pantalla._fx.fijar_barra(bloque, clave, valor, inmediato)
	elif bloque.has(clave):
		bloque[clave].value = valor


# UNA barra y SU numero de una vez: el maximo, el formato, el destino y la cifra.
#
# LA CIFRA SALE DE LA BARRA, NO DEL COMBATIENTE. Es lo que evita el SPOILER: el daño se aplica
# cuando se resuelve la accion, pero el golpe no se ve hasta que la cola lo reproduce, asi que
# escribir aqui `valor` (la vida FINAL) cantaba el resultado antes de tiempo -- lo mas feo era la
# muerte: la cifra ya decia 0.00 mientras la barra seguia bajando tan tranquila.
#
# CombatFX ya repinta el numero cada frame desde bar.value (ver _pintar_numero), pero eso empieza
# en el frame SIGUIENTE; leyendo la barra aqui, la cifra tambien es correcta en este.
# Sin capa de efectos no hay viaje: la barra ya vale el valor final y sale lo mismo de siempre.
func _fijar_barra_num(bloque: Dictionary, clave: String, valor: float, maximo: float,
		fmt: String) -> void:
	if not bloque.has(clave):
		return
	bloque[clave].max_value = maximo
	bloque[clave + "_fmt"] = fmt
	_fijar_barra(bloque, clave, valor)
	if bloque.has(clave + "_lbl"):
		bloque[clave + "_lbl"].text = fmt % [bloque[clave].value, maximo]


# EL UNICO ENGANCHE DE ANIMACION. Lo llaman los seis sitios donde se aplica daño (los basicos de
# los dos bandos, los golpes de habilidad, los de hechizo, los de habilidad enemiga y el
# contraataque) y nadie mas. No pinta nada todavia: apunta el golpe en la cola, y quien la echa a
# andar es el final de la accion (ver _pausa_lectura), que es cuando ya se sabe cuantos golpes
# tiene y por tanto cuanto tiene que durar el turno.
# A QUE GOLPE de la accion pertenece lo siguiente que se encole. Los que comparten numero caen A
# LA VEZ: un molinete pega a los cuatro bichos de una tacada, no de uno en uno. Se llama con el
# indice del golpe justo antes de _fx_golpe, y con eso basta -- NO hace falta reordenar como se
# resuelve el combate, que es lo delicado (sobre todo en la rama enemiga, que va victima a
# victima). Ver CombatFX.tanda.
func _fx_tanda(i: int) -> void:
	if _pantalla._fx != null:
		_pantalla._fx.tanda(i)


# EL SUELO QUE SE ROMPE de la accion en curso (martillo en el mapa, AbilityData.suelo_roto). Mientras
# esta puesto, cada golpe que se encola llega cuando la rotura alcanza el cuerpo de su victima. Lo pone
# quien resuelve (antes de los golpes) y el espejo (al leer el paquete de impactos), y se quita al
# acabar los golpes: un contraataque de despues no tiene que esperar a ninguna grieta.
var _suelo_forma: CombatFormas.Forma = null
var _suelo_tipo: int = 0

func fijar_suelo(tipo: int, forma: CombatFormas.Forma, semilla: int, nucleo: float) -> void:
	if forma == null or _pantalla._fx == null or not _pantalla.tactico:
		return
	_suelo_forma = forma
	_suelo_tipo = tipo
	var arena: Node = _pantalla.turno_mapa._arena()
	if arena != null:
		_pantalla._fx.pedir_suelo(arena, forma, tipo, semilla, nucleo)
	# Y a los espejos, delante de los golpes en el mismo paquete (solo en quien resuelve).
	_pantalla.espejo._apuntar_suelo_red(tipo, forma, semilla, nucleo)


func soltar_suelo() -> void:
	_suelo_forma = null


func _retraso_suelo(victima: Combatant) -> float:
	if _suelo_forma == null or victima == null or not _pantalla._enemies.has(victima):
		return -1.0
	return SueloRoto.retraso_caja(_suelo_forma, _pantalla.turno_mapa.bulto_de(victima), _suelo_tipo)


func _fx_golpe(atacante: Combatant, victima: Combatant, dmg: float, crit: bool,
		evadido: bool, elem: int = Elementos.Elemento.NINGUNO,
		estilo: int = CombatFX.Estilo.MELEE, peso: float = 1.0,
		solo_dibujo: bool = false, sfx: String = "",
		gesto: int = AbilityData.Gesto.AUTO, anim: StringName = &"",
		semilla: int = 0, mult_elem: float = 1.0, guardia_red: bool = false, mano: int = -1) -> void:
	# CON QUE MANO pega (0 la principal/derecha, 1 la secundaria/izquierda). La sabe quien RESUELVE (la mano
	# activa del Combatant: las habilidades pegan con el arma que las trae, el basico alterna); el espejo la
	# recibe en el paquete. Con ella el muñeco pega con la mano de verdad (daga + espada corta: cada golpe
	# con su arma) en vez de alternar a ciegas.
	if mano < 0:
		mano = 1 if atacante != null and atacante.current_hand_slot() == "off" else 0
	# LOS QUE HAN ENCAJADO UN GOLPE DE LOS TUYOS en esta accion: solo detras de esos entran la Escolta y
	# el Oportunista (antes entraban contra el enemigo SELECCIONADO aunque la accion fuera un Filo
	# emponzoñado o una cura, lo vio el jefe el 24/09).
	if not solo_dibujo and not evadido and dmg > 0.0 and victima != null \
			and _pantalla._enemies.has(victima) and _pantalla._aliados.has(atacante) \
			and not _pantalla.golpeados_en_la_accion.has(victima):
		_pantalla.golpeados_en_la_accion.append(victima)
	if _pantalla._fx == null:
		return
	var bv: Dictionary = _pantalla._bloque_de(victima)
	if bv.is_empty():
		return
	# LA SEMILLA DEL SONIDO. La tira quien RESUELVE (o sea, aqui, salvo en el espejo, que la recibe
	# hecha) y no Sonido al reproducir, porque de ella salen la version del fichero y el tono: si
	# cada maquina sorteara lo suyo, el mismo golpe sonaria distinto en cada pantalla.
	#
	# Nunca 0: ese valor significa "no viene de red, sortea tu".
	if semilla == 0:
		semilla = (randi() & 0x3FFFFFFF) | 1
	# EL ESCUDO que lleva el que pega, para que se dibuje EL SUYO. No viaja por red y no hace falta:
	# el espejo resuelve al atacante con _de_codigo y ese Combatant ya trae su fx_escudo, igual que
	# el color y el gesto del arma.
	#
	# EL GESTO va por PARAMETRO y no como estado pegajoso (a diferencia de la tanda). Dos motivos: el
	# espejo llama tambien aqui, asi que se enchufa solo; y sobre todo, los contraataques que
	# _pausa_lectura encola al final heredarian el gesto del que acaba de atacar -- un riposte de
	# estoque haciendo el salto del Rey Slime.
	_pantalla._fx.encolar(_pantalla._bloque_de(atacante), bv, dmg, crit, evadido,
		_color_golpe(atacante, elem, estilo), estilo, peso, solo_dibujo, sfx, elem,
		atacante.fx_escudo if atacante != null else -1, gesto, anim, semilla, mult_elem,
		_retraso_suelo(victima), mano)
	# LA ESQUIVA EN GUARDIA (estoque): el mapa la enseña con su propio gesto (CombatTactico._on_esquiva).
	# En el espejo en_guardia no viaja: le llega marcada en el paquete (guardia_red).
	var en_guardia: bool = evadido and (guardia_red or (not _pantalla._espejo and victima.en_guardia))
	if en_guardia and not _pantalla._fx._cola.is_empty() and is_same(_pantalla._fx._cola.back()["bv"], bv):
		_pantalla._fx._cola.back()["guardia"] = true
	# Y de paso se apunta para los espejos: al pasar TODOS los golpes por aqui, el compañero ve
	# exactamente los mismos que tu, sin tener que acordarse de nada en cada punto de daño.
	# (La esquiva en guardia va en el daño, que en un esquivado es siempre 0: -1 = "en guardia".)
	_pantalla.espejo._apuntar_impacto_red(atacante, victima, -1.0 if en_guardia else dmg, crit, evadido, elem,
		estilo, peso, solo_dibujo, sfx, semilla, mano)


# DE QUE COLOR sale un golpe. Manda el ELEMENTO cuando lo tiene (un rayo es amarillo lo lance quien
# lo lance); si no, lo pinta EL BICHO con su propio color.
#
# El color del bicho es lo que hace que los slimes ataquen de su color -- el venenoso escupe verde y
# el abisal azul oscuro -- sin tener que meterle un elemento falso a cada habilidad solo para
# teñirla. Antes todo lo que no llevaba elemento salia del mismo blanco hueso.
#
# NO VIAJA POR RED, y no hace falta: el espejo resuelve al atacante con _de_codigo y ese Combatant
# ya trae su color_visual, asi que el color se deriva igual en las dos maquinas.
#
# Los golpes a puño limpio (MELEE sin elemento) se quedan con el blanco de siempre: teñir tambien el
# basico de cada bicho llenaba la pantalla de color y le quitaba fuerza justo a las habilidades, que
# es lo que se queria destacar.
# EL ASPECTO de un golpe enemigo. Un solo sitio para que los dos caminos -el basico y el de
# habilidades- no se contesten distinto, que es el error clasico de esta pantalla.
#
# Manda la HABILIDAD si pide algo (AbilityData.fx_estilo). Si no pide nada -o no hay habilidad, que
# es el caso del ataque basico- manda COMO PEGA EL BICHO (EnemyData.fx_basico): una rata muerde
# tanto cuando le sale la tecnica como cuando no. Y si el bicho tampoco dice nada, el empujon de
# tarjeta de siempre.
func _estilo_de_habilidad(ab: AbilityData, atacante: Combatant = null) -> int:
	if ab != null and ab.fx_estilo >= 0:
		return ab.fx_estilo
	if atacante != null and atacante.fx_basico >= 0:
		return atacante.fx_basico
	return CombatFX.Estilo.MELEE


# QUE HACE EL CUERPO al lanzar esta habilidad. Hermano del de arriba, y por el mismo motivo: un solo
# sitio para que el ataque basico y las habilidades no se contesten distinto.
#
# El ataque basico no tiene AbilityData, asi que se queda en AUTO -- que es exactamente el
# comportamiento de siempre. Solo lo cambia quien lo pida en su .tres.
func _gesto_de_habilidad(ab: AbilityData) -> int:
	return ab.gesto if ab != null else AbilityData.Gesto.AUTO


# QUE SONIDO PROPIO pide esta habilidad, o "" si se conforma con el generico de su estilo. La clave
# es el nombre de su .tres (minotauro_bramido -> sfx_minotauro_bramido.wav), que es la misma clave
# estable que ya se usa para cooldowns y para mandar habilidades por red.
#
# Solo valen las que estan en Sonido.CLAVES, y no es por desconfianza: ese indice es lo que viaja en
# el paquete de impactos, asi que una clave de fuera de la lista no podria llegarle al compañero.
func _clave_sfx(ab: AbilityData) -> String:
	if ab == null:
		return ""
	var clave: String = String(ab.resource_path).get_file().get_basename()
	return clave if Sonido.CLAVES.has(clave) else ""


func _color_golpe(atacante: Combatant, elem: int, estilo: int) -> Color:
	if Elementos.tiene_color(elem):
		return Elementos.color(elem)
	# LAS ARMAS SON DE ACERO, y esto no es un detalle: color_visual vale ROJO por defecto (es el color
	# con el que se tiñen los bichos), asi que sin esta rama todos los tajos del jugador saldrian
	# rojizos, como si cada golpe fuera de fuego. El elemento sigue mandando por encima: con fuego el
	# corte sale naranja, que es para lo que existen las imbuiciones del mago.
	if CombatFX.FX_JUGADOR.has(estilo):
		# PERO LA IMBUICION SOLO TIÑE TU METAL. Un grito, un signo arcano, una sombra o las placas de
		# tus compañeros no tienen por que ponerse verdes porque lleves veneno en la daga -- y se
		# ponian, porque aqui entraban los 67 estilos del jugador. Ver CombatFX.FX_SIN_IMBUICION.
		if CombatFX.FX_SIN_IMBUICION.has(estilo):
			return CombatFX.ACERO
		# EL VENENO NO ES UN ELEMENTO, es un ESTADO (ver elements.gd), asi que no llega por 'elem' y
		# el Filo emponzoñado se veria de acero pelado. Se saca del arma imbuida del propio atacante:
		# mientras le queden usos, el filo va tintado de su color. Es la misma via por la que un bicho
		# saca su color_visual, y como el espejo tambien resuelve al atacante, tiñe igual en las dos
		# pantallas... siempre que le haya llegado el imbue; si no, ve acero, que es lo de siempre.
		if atacante != null and atacante.imbue_estado >= 0 and atacante.imbue_usos > 0:
			var d: Dictionary = StatusEffects.def(atacante.imbue_estado)
			if d.has("color"):
				return d["color"]
		return CombatFX.ACERO
	if estilo != CombatFX.Estilo.MELEE and atacante != null:
		return atacante.color_visual
	return Color(1, 0.95, 0.9)


# EL ASPECTO de un golpe de hechizo. Manda el ELEMENTO DEL GOLPE, no el del hechizo: Tormenta
# reparte sus 20 golpes entre agua y rayo, y cada uno tiene que pintarse como lo que es (gotas o
# rayos), no todos como "el hechizo de rayo que es Tormenta".
#
# 'dispersa' cambia de DONDE SALE: una tormenta cae del cielo sobre cada bicho, mientras que una
# brasa la lanzas tu desde la mano.
func _estilo_hechizo(spell: SpellData, elem: int, rebote: bool, salpicon: bool = false) -> int:
	# EL DIBUJO PROPIO MANDA sobre el reparto por elemento, pero NO sobre el rebote: un rebote es un
	# arco que salta de una victima a la siguiente y tiene que verse asi venga del hechizo que venga.
	if rebote:
		return CombatFX.Estilo.ARCO
	# La SALPICADURA tiene su propio dibujo: al vecino no le llega el conjuro, le llega lo que ha
	# reventado en el principal. Si no se mirase antes que fx_estilo, un hechizo con dibujo propio
	# mandaria una copia entera del conjuro a cada enemigo de al lado.
	# UN SOLO DIBUJO PARA TODOS: los golpes por objetivo no pintan nada. MELEE tiene vuelo 0.0, que
	# en esta casa significa exactamente eso -- no se da de alta. El numero y el temblor siguen
	# saliendo por victima, que es lo correcto: el daño SI es de cada uno.
	if spell != null and spell.fx_unico:
		return CombatFX.Estilo.MELEE
	if spell != null and spell.fx_estilo >= 0:
		# EL DIBUJO GORDO es SOLO para los golpes del elemento de identidad del hechizo. Los demas
		# —y las salpicaduras— usan el secundario.
		#
		# No es cosmetico, es de TIEMPO: cada estilo tiene su propio vuelo en CombatFX.T_VUELO, y el
		# efecto se da de alta ese rato ANTES de su impacto. El golpe de agua del Shock termico
		# usaba el estilo de la bola (vuelo 0.42) y por eso nacia casi medio segundo antes de que le
		# tocara: el vapor se abria mientras la bola aun estaba cruzando la pantalla. Con el estilo
		# del vapor (vuelo 0.10) nace cuando toca.
		if salpicon or elem != spell.elemento:
			if spell.fx_estilo_salpicon >= 0:
				return spell.fx_estilo_salpicon
		else:
			return spell.fx_estilo
	if salpicon:
		return _estilo_salpicon(spell, elem)
	match elem:
		Elementos.Elemento.FUEGO:
			return CombatFX.Estilo.PROYECTIL
		Elementos.Elemento.RAYO:
			return CombatFX.Estilo.CAIDA_RAYO if spell.dispersa else CombatFX.Estilo.RAYO
		Elementos.Elemento.AGUA:
			return CombatFX.Estilo.CAIDA_GOTA if spell.dispersa else CombatFX.Estilo.BARRIDO
		_:
			return CombatFX.Estilo.ARCANO


# EL ASPECTO DE LO QUE LE LLEGA A UN VECINO, que NO es lo mismo que le llega al principal. Sin esto,
# el salpicon se pintaba igual que el golpe gordo y lo que de verdad es una cosa que revienta en uno
# y alcanza a los de al lado se leia como "he lanzado tres bolas a la vez".
#
#   FUEGO -> EXPLOSION. La bola vuela hasta el principal, estalla, y a los lados les llega la ONDA.
#            Vale para Brasa (una bola) y para Andanada ignea (varias).
#   RAYO  -> ARCO: una DESCARGA corta que salta del principal a su vecino, colgando de la linea
#            principal. Ojo: solo las de rayo NORMALES (Descarga, Rayo). TORMENTA se queda como
#            esta -- es dispersa, cae del cielo sobre cada bicho y asi es como tiene que verse.
#   AGUA  -> BARRIDO, sin cambios: esas son de alcance TODOS y las cubre la ola unica y ancha.
func _estilo_salpicon(spell: SpellData, elem: int) -> int:
	match elem:
		Elementos.Elemento.FUEGO:
			return CombatFX.Estilo.EXPLOSION
		Elementos.Elemento.RAYO:
			return CombatFX.Estilo.CAIDA_RAYO if spell.dispersa else CombatFX.Estilo.ARCO
		Elementos.Elemento.AGUA:
			return CombatFX.Estilo.CAIDA_GOTA if spell.dispersa else CombatFX.Estilo.BARRIDO
		_:
			return CombatFX.Estilo.ARCANO


# QUE FRACCION del golpe principal se lleva este objetivo. Es lo que decide el tamaño del temblor
# y del efecto: en Brasa el del medio come 1.5 y los de los lados 0.75, o sea que los lados salen
# a 0.5 y tiemblan la mitad. Se saca de los multiplicadores del hechizo y NO del daño ya
# calculado: el daño lleva dentro el critico y las resistencias, asi que un bicho que resiste el
# fuego temblaria menos que uno que no, justo al reves de lo que cuenta el hechizo.
func _peso_hechizo(spell: SpellData, escala: float) -> float:
	return escala / maxf(spell.dano_objetivo, 0.01)


# Reconstruye los chips de un combatiente: uno por estado ACTIVO (mas la imbuicion, que no es
# un estado -vive en sus propios campos- pero se sufre igual y hay que poder consultarla).
# Se rehace entero en cada refresco: son 0-5 botones y asi no hay que llevar la cuenta de
# cuales han expirado.
# 'idx' = indice del enemigo dueño de los chips (-1 = jugador): los chips tambien seleccionan.
func _refrescar_chips(c: Combatant, bloque: Dictionary, idx: int) -> void:
	var box: Container = bloque.get("chips")
	if box == null:
		return
	for hijo in box.get_children():
		hijo.queue_free()
	var pares: Array = _chips_de(c)
	# Los MISMOS pares alimentan las particulas y el tinte del recuadro. Se leen de aqui y no de
	# c.statuses a proposito: en el espejo los combatientes son maniquis sin motor de estados y
	# esto es lo unico que les llega resuelto, asi que asi las dos pantallas pintan igual.
	if _pantalla._fx != null:
		_pantalla._fx.pintar_estados(bloque, pares, true)
	for par in pares:
		# Los chips de ESTADO traen ademas icono y color (chip_de_grupo); los de mecanica de combate
		# (cargando, recitando, provocacion, imbuicion) siguen siendo pares y se pintan en gris claro.
		# Se mira el tamaño y no el tipo para que un espejo con la instantanea vieja (pares de 2) no
		# reviente al llegar: la red manda estos mismos arrays.
		var col: Color = (par[3] as Color) if par.size() > 3 else CHIP_NEUTRO
		# SOLO EL ICONO cuando lo hay (par[2], que lo separa chip_de_grupo). Los chips de mecanica
		# vienen como pares de 2 y se quedan con su texto, que ya es corto y dice algo que no cabe
		# en un icono ("frase 2 de 3"). Lo demas -magnitud, turnos, que hace- esta en el tooltip.
		var visible_txt: String = String(par[2]) if par.size() > 2 and String(par[2]) != "" \
			else String(par[0])
		var ultimo: bool = par.size() > 4 and bool(par[4])
		_chip(box, visible_txt, String(par[1]), idx, col, ultimo)
	box.visible = box.get_child_count() > 0


# QUE chips lleva un combatiente, como [[texto, tooltip], ...]. Separado de la pintura porque estos
# mismos pares VIAJAN a los espejos dentro de la instantanea: alli los combatientes son maniquis sin
# motor de estados, asi que la unica forma de que vean los debuffs de los demas es recibirlos ya
# resueltos. Un solo sitio decide, y las dos pantallas pintan lo mismo.
func _chips_de(c: Combatant) -> Array:
	if c == null:
		return []
	if _pantalla._espejo:
		return _pantalla.espejo._chips_espejo.get(c, [])
	var out: Array = []
	# ATAQUE CARGADO (telegrafiado): el aviso del log se lo lleva el turno siguiente, asi que sin
	# esto no hay forma de saber CUAL de los tres bichos te esta preparando el pepino. Va como chip
	# (y no como texto suelto) para heredar el tooltip y el clic-para-apuntar, y para no ensanchar
	# el bloque: la zona de chips tiene alto fijo.
	if c.charging != null:
		# Corto como el resto: el icono y los turnos que faltan. QUE esta cargando va al tooltip.
		# RELOJ DE ARENA, no rayo: con el ⚡ este chip se leia como un estado mas de los del catalogo
		# y no habia forma de ver de un vistazo cual era el que te estaba preparando el pepino. Lo
		# que dice es "aqui hay una cuenta atras", que es exactamente lo que pasa.
		#
		# Y con la cuenta a 0 el chip cambia: ya no faltan turnos, esta LISTA y solo espera a que su
		# dueño elija objetivo (ver _pedir_soltar_carga). Sin esta rama ponia "⏳0t", que no dice nada.
		if c.charge_left <= 0:
			out.append(["⚡!", "%s: LISTA.\nSolo falta elegir a quién." % c.charging.nombre])
		else:
			out.append(["⏳%dt" % c.charge_left,
				"CARGANDO: %s\nSe dispara en %d turno%s.\nAturdirlo lo interrumpe." % [
					c.charging.nombre, c.charge_left, "" if c.charge_left == 1 else "s"]])
	# RECITANDO un hechizo. Hermano del chip de ataque cargado, y por el mismo motivo: un conjuro dura
	# varios turnos y sin esto no habia forma de saber QUE esta recitando cada uno ni por donde va --
	# ni de ti mismo cuando llevas grupo, ni del personaje del otro humano. Va aqui, en el sitio
	# unico, asi que sale igual en tu pantalla y en la del que espeja la pelea.
	if _pantalla._casteos.has(c):
		var sp: SpellData = _pantalla._casteos[c]["spell"] as SpellData
		if sp != null:
			var i: int = int(_pantalla._casteos[c]["idx"])
			var total: int = sp.longitud()
			if i >= total:
				out.append(["🔮▶",
					"%s: LISTO\nEl conjuro esta recitado entero: el proximo turno se lanza." % sp.nombre])
			else:
				out.append(["🔮%d/%d" % [i + 1, total],
					("%s: recitando\nFrase %d de %d. Fallar una descontrola el conjuro"
					+ " (daño propio) y te cuesta el maná igual.") % [sp.nombre, i + 1, total]])
	# PROVOCANDO (taunt de escudo): sin esto no habia forma de saber si te quedaba taunt ni cuanto.
	# Va en los chips como todo lo demas, asi que sirve igual para ti y para un companero.
	if c.provocar_turnos > 0:
		out.append(["🎯%dt" % c.provocar_turnos,
			"Provocación (%d turno%s)\nLos enemigos centran su atención en ti: te atacan más." % [
				c.provocar_turnos, "" if c.provocar_turnos == 1 else "s"]])
	# COBERTURA (escudo grande). Va en los DOS: quien cubre y a quien cubren. Sin el segundo chip,
	# el que esta tapado no tiene forma de saber por que de pronto no le pega nadie -- y cuando se
	# le acabe, tampoco sabra por que ha vuelto a llover. La flecha dice el sentido.
	if c.proteger_turnos > 0 and c.protegiendo_a != null:
		out.append(["🛡→%dt" % c.proteger_turnos,
			("Cubres a %s (%d turno%s)\nLos golpes que le busquen a él te llegan a ti, con tu"
			+ " bloqueo y tu defensa. Mientras dure, cuentas como si estuvieras defendiendo.") % [
				c.protegiendo_a.nombre, c.proteger_turnos,
				"" if c.proteger_turnos == 1 else "s"]])
	if c.protegido_por != null and c.protegido_por.proteger_turnos > 0:
		out.append(["🛡←",
			"Te cubre %s\nSe ha puesto delante: los golpes que te buscaban van a él." % \
				c.protegido_por.nombre])
	var imb: String = c.imbue_etiqueta()
	if imb != "":
		out.append([imb, c.imbue_resumen()])
	# FOCO ARCANO. Faltaba: por el mapa se pinta (Game.refrescar_cache_estados) y dentro de la pelea
	# no, que es justo donde importa — canalizabas, te quedaban dos cargas y no habia forma de saberlo
	# mas que acordandote. No lleva turnos porque no caduca: es MUNICION, la gasta lanzar.
	# POSTURA DE GUARDIA (estoque). Es un buff con duración —"hasta tu próxima acción"— que te frena
	# mucho y te sube la esquiva, y hasta ahora solo se anunciaba UNA vez en el log y desaparecia de
	# la vista. Igual que Defender y el agotamiento, aqui abajo.
	if c.en_guardia:
		out.append(["🤺", "En guardia (postura de contraataque)\nTe mueves un %d%% más lento, esquivas un %d%% más y devuelves el golpe al esquivar.\nDura hasta tu próxima acción."
			% [roundi((1.0 - c.guardia_spd_mult) * 100.0), roundi(c.evasion_bonus * 100.0)],
			"🤺", Color(0.85, 0.8, 0.5)])
	# DEFENDIENDO: reduce el daño hasta su próximo turno. Vale para ti y para los compañeros.
	if bool(_pantalla._defendiendo.get(c, false)) or (c == _pantalla._player and _pantalla._player_defending):
		out.append(["🛡", "Defendiendo\nEl daño que te entra se recorta hasta tu próximo turno, y los críticos en tu contra se quedan a la mitad.",
			"🛡", Color(0.6, 0.75, 0.95)])
	# AGOTAMIENTO: entraste sin fuelle y tus primeras acciones van a medio ritmo. Solo salia en la
	# linea de intro del log, que a los tres turnos ya nadie recuerda.
	var lentas: int = int(_pantalla._lentas.get(c, 0))
	if lentas > 0:
		out.append(["😮‍💨x%d" % lentas,
			"Sin fuelle\nEntraste agotado: tus próximas %d acción%s van a medio ritmo." % [
				lentas, "" if lentas == 1 else "es"],
			"😮‍💨", Color(0.8, 0.6, 0.45)])
	if c.foco_cargas > 0:
		out.append(["🔮x%d" % c.foco_cargas,
			"Foco arcano: %d carga%s\nCada hechizo OFENSIVO gasta una y pega un %d%% más.\nNo caduca con los turnos." % [
				c.foco_cargas, "" if c.foco_cargas == 1 else "s", roundi(Combatant.FOCO_BONUS * 100.0)],
			"🔮", Color(0.55, 0.7, 1.0)])
	# UN chip por estado, no uno por instancia: los 'independent' (Pegajoso, Sangrado) apilan
	# creando una Instance por aplicacion y salian cuatro iconos iguales en fila. Se agrupan por id
	# conservando el orden en que se aplicaron; el detalle por stack va al tooltip.
	var por_estado: Dictionary = {}
	var orden: Array = []
	for e in c.statuses:
		if not por_estado.has(e.id()):
			por_estado[e.id()] = []
			orden.append(e.id())
		(por_estado[e.id()] as Array).append(e)
	for id_est in orden:
		out.append(StatusEffects.chip_de_grupo(por_estado[id_est]))
	return out


# Un chip: el icono+numeros de siempre (etiqueta()), y al pasar el raton por encima, la ficha
# entera (resumen()). TooltipButton porque el tooltip por defecto de Godot no parte lineas.
# 'idx' = enemigo al que pertenece (-1 = jugador).
#
# El chip SI se come el clic (un tooltip necesita recibir el raton, asi que no puede ir en
# IGNORE como los demas hijos del bloque). En vez de pelearse con eso, se le hace bueno: el
# chip tambien selecciona. Asi el bloque no tiene zonas muertas -> pinches donde pinches
# dentro del borde, apuntas a ese bicho.
# Color de los chips que NO son un estado del catalogo (cargando, recitando, provocacion, imbuicion):
# no tienen color propio porque no salen de StatusEffects.
const CHIP_NEUTRO := Color(0.78, 0.80, 0.86)

# El chip se monta en StatusChip, el mismo sitio que usa el HUD del mapa: asi un veneno se ve igual
# en la pelea y andando por el pasillo. Clicar el de un enemigo lo SELECCIONA, como antes.
func _chip(box: Container, texto: String, tooltip: String, idx: int = -1,
		color: Color = CHIP_NEUTRO, parpadea: bool = false) -> void:
	var clic: Callable = _pantalla.figuras._seleccionar.bind(idx) if idx >= 0 else Callable()
	box.add_child(StatusChip.crear(texto, color, tooltip, clic, parpadea))
