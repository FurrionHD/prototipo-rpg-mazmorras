# ============================================================
#  dev_imbuiciones.gd  --  HERRAMIENTA, no parte del juego.
#
#  Comprueba los FILOS y los MANTOS, y sobre todo el MANTO PRISMATICO, que es el primer hechizo del
#  juego que hace dos cosas que no hacia ninguno: sortear su elemento al lanzarlo y tocar la
#  VELOCIDAD mientras dure.
#
#  Lo que se prueba, y por que cada cosa:
#    1. El sorteo del prismatico da los CINCO elementos y nunca NINGUNO. Un sorteo que se dejara uno
#       fuera no da error: solo hace que ese elemento no salga jamas, y eso no se nota jugando.
#    2. LA VELOCIDAD VA PEGADA A LOS USOS, no a los turnos. Es la razon de que no sea el estado
#       Presteza, y es justo lo que se implementaria mal si alguien lo "arregla" con un estado: con
#       turnos se caeria a mitad de los 25 ataques y nadie se enteraria de por que.
#    3. Al agotarse, la imbuicion lo devuelve TODO: velocidad, afinidad y bonus. Lo que se olvide de
#       limpiar queda puesto el resto del combate, gratis.
#    4. LA IMBUICION VIAJA EN LA FICHA entre combates, y la velocidad con ella. Si no viajara, el
#       manto duraria 25 ataques pero solo ligerearia en el combate donde se lanzo.
#    5. LOS NUMEROS DE LAS PIEZAS NUEVAS son los que se acordaron: filos de luz/oscuridad al 50% y
#       15 usos, mantos al 25% con intensidad 0.6, y el mitico al 50% con 25 usos.
#    6. LA MECANICA MOONLIGHT: el manto de luz resiste la luz Y RECIBE MAS de la oscuridad, y al
#       reves. La coraza sube por los dos lados, y esa segunda mitad es la que se olvida.
#    7. Luz y oscuridad dan INMUNIDADES: eran los dos unicos elementos sin entrada en la tabla, y sin
#       ellas un manto legendario protegia de menos que el epico al que sustituye.
#
#  Es logica pura, sin Control ni captura, asi que aqui SI vale --headless.
#
#    godot --headless --path . res://tools/visores/dev_imbuiciones.tscn
#  Escribe el resultado por consola y devuelve codigo de salida != 0 si algo falla.
# ============================================================
extends Node

const DIR := "res://resources/spells/"

var _fallos: int = 0
var _hechas: int = 0


func _ready() -> void:
	print("=== FILOS, MANTOS Y EL PRISMATICO ===")
	_probar_numeros()
	_probar_sorteo()
	_probar_velocidad()
	_probar_moonlight()
	_probar_inmunidades()
	_probar_viaja_en_la_ficha()
	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _s(id: String) -> SpellData:
	return load(DIR + id + ".tres") as SpellData


# Un combatiente de mentira con velocidad conocida: lo que se mide es cuanto la mueve la imbuicion,
# asi que hace falta un punto de partida que no dependa de las stats de nadie.
func _c() -> Combatant:
	return Combatant.new("Prueba", 1, Abilities.new(), 100.0, 10.0, 5.0, 10.0)


# --- 1) LOS NUMEROS ACORDADOS ---
func _probar_numeros() -> void:
	print("\n-- Los números de las piezas nuevas --")
	for id in ["filo_radiante", "filo_umbrio"]:
		var s: SpellData = _s(id)
		_ok("%s es épico, +50%% y 15 ataques" % s.nombre,
			int(s.rareza) == Upgrades.Rareza.EPICO and is_equal_approx(s.imbue_pct, 0.5)
			and s.imbue_usos == 15 and s.imbue_tipo == 1)
	for id2 in ["manto_aureo", "manto_umbrio"]:
		var m: SpellData = _s(id2)
		_ok("%s es legendario, +25%%, 15 ataques y coraza 0.6" % m.nombre,
			int(m.rareza) == Upgrades.Rareza.LEGENDARIO and is_equal_approx(m.imbue_pct, 0.25)
			and m.imbue_usos == 15 and is_equal_approx(m.imbue_intensidad, 0.6)
			and m.imbue_tipo == 2)
	var p: SpellData = _s("manto_prismatico")
	_ok("el prismático es mítico, de cuerpo, +50% y 25 ataques",
		int(p.rareza) == Upgrades.Rareza.MITICO and p.imbue_tipo == 2
		and is_equal_approx(p.imbue_pct, 0.5) and p.imbue_usos == 25)
	_ok("con elemento al azar y +10% de velocidad",
		p.imbue_elemento_aleatorio and is_equal_approx(p.imbue_spd_mult, 1.1))
	# LOS DE ANTES NO SE HAN MOVIDO: las piezas nuevas suben un escalon SOBRE ellas, asi que si
	# alguien tocara los viejos de paso, la diferencia que justifica el tier se esfumaria.
	_ok("y los filos de siempre siguen en +30% y 10 ataques",
		is_equal_approx(_s("filo_ardiente").imbue_pct, 0.3) and _s("filo_ardiente").imbue_usos == 10)
	_ok("y los mantos de siempre en +15% y coraza 0.4",
		is_equal_approx(_s("manto_brasas").imbue_pct, 0.15)
		and is_equal_approx(_s("manto_brasas").imbue_intensidad, 0.4))


# --- 2) EL SORTEO ---
func _probar_sorteo() -> void:
	print("\n-- El elemento del prismático sale al azar --")
	var p: SpellData = _s("manto_prismatico")
	var vistos := {}
	for i in 4000:
		vistos[p.elemento_imbuido()] = true
	_ok("salen los cinco elementos (%d)" % vistos.size(), vistos.size() == Elementos.TODOS.size())
	_ok("y ninguna tirada sale sin elemento",
		not vistos.has(Elementos.Elemento.NINGUNO))
	# Y LOS DEMAS NO SORTEAN: si el campo se colara en un .tres normal, ese hechizo dejaria de ser
	# del elemento que dice su nombre y su ficha mentiria.
	var f: SpellData = _s("filo_ardiente")
	_ok("un filo normal siempre da el suyo",
		f.elemento_imbuido() == Elementos.Elemento.FUEGO
		and f.elemento_imbuido() == Elementos.Elemento.FUEGO)


# --- 3) LA VELOCIDAD, PEGADA A LOS USOS ---
func _probar_velocidad() -> void:
	print("\n-- La velocidad dura lo que dure la imbuición --")
	var p: SpellData = _s("manto_prismatico")
	var c: Combatant = _c()
	var normal: float = c.spd()
	c.aplicar_imbue(Elementos.Elemento.FUEGO, p.imbue_pct, p.imbue_usos, true,
		p.imbue_estado, p.imbue_prob, p.imbue_intensidad, 0.0, false, p.imbue_spd_mult)
	_ok("con el manto puesto va un 10%% más rápido (%.2f -> %.2f)" % [normal, c.spd()],
		is_equal_approx(c.spd(), normal * 1.1))
	_ok("y al castear también", is_equal_approx(c.cast_spd(), c._spd_base() * 1.1))
	# SE GASTA POR ATAQUE. 24 ataques la dejan viva por los pelos; el 25 la apaga.
	for i in 24:
		c.consumir_imbue()
	_ok("tras 24 ataques le queda 1 uso y sigue rápido",
		c.imbue_usos == 1 and is_equal_approx(c.spd(), normal * 1.1))
	var agotada: bool = c.consumir_imbue()
	_ok("el ataque 25 la agota", agotada and c.imbue_usos == 0)
	# --- 4) Y AL AGOTARSE SE DEVUELVE TODO ---
	_ok("y la velocidad vuelve a la de siempre (%.2f)" % c.spd(), is_equal_approx(c.spd(), normal))
	_ok("y la afinidad se suelta", c.elemento == Elementos.Elemento.NINGUNO)
	_ok("y el bonus de daño también", is_equal_approx(c.imbue_pct, 0.0))
	# UN FILO NORMAL NO TOCA LA VELOCIDAD: si la tocara, el mitico dejaria de tener nada propio.
	var c2: Combatant = _c()
	var f: SpellData = _s("filo_ardiente")
	c2.aplicar_imbue(Elementos.Elemento.FUEGO, f.imbue_pct, f.imbue_usos, false,
		f.imbue_estado, f.imbue_prob, f.imbue_intensidad, 0.0, false, f.imbue_spd_mult)
	_ok("un filo normal no cambia la velocidad", is_equal_approx(c2.spd(), _c().spd()))


# --- 6) LA MECANICA MOONLIGHT ---
func _probar_moonlight() -> void:
	print("\n-- Luz y oscuridad se baten la una a la otra --")
	var m: SpellData = _s("manto_aureo")
	var c: Combatant = _c()
	c.aplicar_imbue(Elementos.Elemento.LUZ, m.imbue_pct, m.imbue_usos, true,
		m.imbue_estado, m.imbue_prob, m.imbue_intensidad)
	var de_luz: float = Elementos.mult_recibido(Elementos.Elemento.LUZ, c)
	var de_osc: float = Elementos.mult_recibido(Elementos.Elemento.OSCURIDAD, c)
	print("  con el manto áureo: recibe x%.2f de luz y x%.2f de oscuridad" % [de_luz, de_osc])
	_ok("el manto de luz recorta la luz a x0.70", is_equal_approx(de_luz, 0.7))
	# LA MITAD QUE SE OLVIDA: la coraza sube por los DOS lados. Un manto mas fuerte tambien te deja
	# mas abierto a su contrario, y eso es lo que lo hace una decision y no un si-o-si.
	_ok("y le mete x1.30 de oscuridad, no x1.20", is_equal_approx(de_osc, 1.3))
	# Y CONTRA EL DE ANTES: el epico deja x0.80 / x1.20. Si los dos dieran lo mismo, el legendario
	# solo pegaria mas, y lo que se pidio fue que ademas aguantase mas.
	var v: SpellData = _s("manto_brasas")
	var c2: Combatant = _c()
	c2.aplicar_imbue(Elementos.Elemento.FUEGO, v.imbue_pct, v.imbue_usos, true,
		v.imbue_estado, v.imbue_prob, v.imbue_intensidad)
	_ok("y el manto épico se queda en x0.80, como estaba",
		is_equal_approx(Elementos.mult_recibido(Elementos.Elemento.FUEGO, c2), 0.8))


# --- 7) LAS INMUNIDADES QUE FALTABAN ---
func _probar_inmunidades() -> void:
	print("\n-- Luz y oscuridad ya libran de algo --")
	var c: Combatant = _c()
	c.aplicar_imbue(Elementos.Elemento.LUZ, 0.25, 15, true, -1, 0.0, 0.6)
	_ok("a la luz no la ciegan", c.es_inmune(StatusEffects.Id.CEGUERA))
	var c2: Combatant = _c()
	c2.aplicar_imbue(Elementos.Elemento.OSCURIDAD, 0.25, 15, true, -1, 0.0, 0.6)
	_ok("y la oscuridad ni se ciega ni se asusta",
		c2.es_inmune(StatusEffects.Id.CEGUERA) and c2.es_inmune(StatusEffects.Id.MIEDO))
	# Y NO SE LIBRAN DE TODO: una inmunidad de mas seria peor que una de menos.
	_ok("pero la luz sigue quemándose", not c.es_inmune(StatusEffects.Id.QUEMADURA))


# --- 5) VIAJA EN LA FICHA, CON SU VELOCIDAD ---
func _probar_viaja_en_la_ficha() -> void:
	print("\n-- La imbuición sobrevive al final del combate --")
	var p: SpellData = _s("manto_prismatico")
	var pj := PersonajeData.new()
	pj.nombre = "Prueba"
	var c: Combatant = _c()
	c.aplicar_imbue(Elementos.Elemento.RAYO, p.imbue_pct, p.imbue_usos, true,
		p.imbue_estado, p.imbue_prob, p.imbue_intensidad, 0.0, false, p.imbue_spd_mult)
	for i in 5:
		c.consumir_imbue()
	Game.guardar_imbue_en_ficha(c, pj)
	_ok("la ficha se queda con los 20 usos que quedaban",
		int(pj.imbue.get("usos", 0)) == 20)
	_ok("y con la velocidad", is_equal_approx(float(pj.imbue.get("spd", 1.0)), 1.1))
	# Y AL VOLVER A ENTRAR: lo que no se copie campo a campo se pierde sin dar error.
	var c2: Combatant = _c()
	var normal: float = c2.spd()
	Game.restaurar_imbue_de_ficha(c2, pj)
	_ok("al entrar al siguiente combate vuelve con sus 20 usos", c2.imbue_usos == 20)
	_ok("y sigue yendo un 10% más rápido", is_equal_approx(c2.spd(), normal * 1.1))
	_ok("y con la afinidad del rayo puesta", c2.elemento == Elementos.Elemento.RAYO)
	# UNA FICHA VIEJA, de antes de que el mitico existiera, no trae la clave 'spd'. Sin el valor por
	# defecto entraria a velocidad CERO, que es la clase de fallo que no avisa: el personaje
	# simplemente no volveria a jugar un turno.
	pj.imbue.erase("spd")
	var c3: Combatant = _c()
	Game.restaurar_imbue_de_ficha(c3, pj)
	_ok("y una ficha vieja sin ese dato entra a velocidad normal, no a cero",
		is_equal_approx(c3.spd(), normal))


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
