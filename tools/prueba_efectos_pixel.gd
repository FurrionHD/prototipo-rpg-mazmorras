# LOS EFECTOS EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art). Que cada hoja apuntada exista y mida lo que dice, que salgan
# con su tinte, que respeten la espera, los dos ritmos y el final, y que SlimeAire use lo horneado cuando le toca (y lo viejo
# cuando no: lo que aun no se ha horneado sigue saliendo).
#   godot --headless --path . res://tools/prueba_efectos_pixel.tscn
extends Node

const _DATOS := preload("res://scripts/fx/efectos_pixel_datos.gd")

var _mal: int = 0


func _ready() -> void:
	call_deferred("_correr")


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	print("1) LAS HOJAS: existen y miden lo que dicen")
	var total: int = 0
	var rotas: Array = []
	for enemigo in _DATOS.HOJAS:
		var hojas: Dictionary = _DATOS.HOJAS[enemigo]
		for nombre in hojas:
			var d: Dictionary = hojas[nombre]
			total += 1
			for suf in ["s", "a"]:
				var medida = d.get(suf)
				if medida == null:
					continue
				var tex: Texture2D = load(EfectoPixel.CARPETA % [enemigo, nombre, suf])
				if tex == null or tex.get_width() != int(medida[0]) * int(d["n"]) or tex.get_height() != int(medida[1]) * int(d["filas"]):
					rotas.append("%s/%s_%s" % [enemigo, nombre, suf])
	_ver(rotas.is_empty(), "las %d hojas, todas bien %s" % [total, str(rotas) if not rotas.is_empty() else ""])

	print("2) EL TINTE Y LOS RITMOS")
	var col := Color(0.29, 0.78, 0.33)
	var pal: PackedColorArray = SlimeAire.paleta_pixel(col)
	_ver(pal.size() == 5, "la paleta son cinco colores")
	var e: EfectoPixel = EfectoPixel.lanzar(self, "slime", "placaje_c", Vector2.ZERO, 6, null, 0.5, -1.0, 1.0, pal)
	_ver(e != null and e.num_capas() == 2, "sale con sus dos capas")
	var s: Sprite2D = e.get_child(0)
	_ver(s.material is ShaderMaterial and (s.material as ShaderMaterial).get_shader_parameter("p1") == pal[1], "lleva el color de quien lo lanza")
	_ver(s.flip_h, "hacia el oeste va en espejo")
	_ver(not s.visible, "con espera, aun no se ve")
	e.set_process(false)
	e._t = 0.1
	_ver(s.visible and e.marco_actual() == 2, "a 25 fps, a 0,1 s va por el marco 2")
	e._t = 0.24 + 1.0 / 11.0
	_ver(e.marco_actual() == 7, "tras el corte va a su otro ritmo (11 fps): un marco por 0,09 s")
	e._t = e.duracion() + 0.01
	_ver(not s.visible, "acabado, no se ve")
	e.queue_free()
	var sin: EfectoPixel = EfectoPixel.lanzar(self, "escarabajo", "coraza", Vector2.ZERO)
	_ver(sin != null and (sin.get_child(0) as Sprite2D).material == null, "sin paleta (el escarabajo), su hoja tal cual")
	if sin != null:
		sin.queue_free()
	_ver(EfectoPixel.lanzar(self, "slime", "no_existe", Vector2.ZERO) == null, "una hoja que no existe no revienta")

	print("3) SLIMEAIRE: lo horneado cuando le toca")
	var semilla: int = SlimeAire.semilla_con_color(9, col)
	var linea := CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 40.0, 16.0)
	_ver(SlimeAire.area(self, linea, SlimeAire.Modo.PLACAJE, semilla, 0.0) is EfectoPixel, "el Placaje, en pixel")
	var ancha := CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 70.0, 70.0)
	_ver(SlimeAire.area(self, ancha, SlimeAire.Modo.PLACAJE, semilla, 0.0) is EfectoPixel, "la Embestida cortante, en pixel")
	_ver(SlimeAire.area(self, CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 70.0, 12.0), SlimeAire.Modo.LLAMARADA, semilla, 0.0) is EfectoPixel, "la Llamarada, en pixel")
	_ver(SlimeAire.area(self, CombatFormas.circulo(Vector2.ZERO, 45.0), SlimeAire.Modo.COMBUSTION, semilla, 0.0) is EfectoPixel, "la Combustion, en pixel")
	_ver(SlimeAire.area(self, CombatFormas.circulo(Vector2.ZERO, 40.0), SlimeAire.Modo.MAREA, semilla, 0.0) is EfectoPixel, "la Marea del Rey, en pixel")
	_ver(SlimeAire.area(self, CombatFormas.circulo(Vector2.ZERO, 35.0), SlimeAire.Modo.SPLAT, semilla, 0.0) is EfectoPixel, "el Reventon, en pixel")
	_ver(SlimeAire.area(self, CombatFormas.circulo(Vector2.ZERO, 50.0), SlimeAire.Modo.SPLAT, semilla, 0.0) is EfectoPixel, "la Nube de ceniza, en pixel")
	_ver(SlimeAire.sobre_cuerpo(self, SlimeAire.Modo.GOLPE, Vector2.ZERO, Rect2(30, 0, 20, 30), col, semilla, 0.05, 1.0) is EfectoPixel, "el basico, en pixel")
	var esc = SlimeAire.sobre_cuerpo(self, SlimeAire.Modo.ESCUPE, Vector2.ZERO, Rect2(90, 0, 20, 30), col, semilla, 0.26, 1.0)
	_ver(esc is EfectoPixel and esc._bola != null, "el Escupitajo, en pixel y con su bola")
	if esc is EfectoPixel:
		esc.set_process(false)
		esc._t = -0.13
		_ver(esc._bola.visible and esc._bola.global_position.x > 40.0 and esc._bola.global_position.x < 60.0, "a mitad de viaje, la bola va por la mitad")
		_ver(esc._bola.global_position.y < 15.0 - 15.0, "y va en arco, por encima de la linea recta")
		esc._t = 0.01
		_ver(not esc._bola.visible, "al llegar, la bola se va y revienta")
	print("3b) EL ABISAL Y SUS MUTANTES")
	_ver(SlimeAire.area(self, CombatFormas.linea(Vector2.ZERO, Vector2.UP, 60.0, 20.0), SlimeAire.Modo.PRESION, semilla, 0.0) is EfectoPixel, "la Presion del abismo, en pixel")
	var tr = SlimeAire.sobre_cuerpo(self, SlimeAire.Modo.TROMBA, Vector2.ZERO, Rect2(0, 0, 20, 30), col, semilla, 0.5, 1.0)
	_ver(tr is EfectoPixel and is_equal_approx(tr._t, -(0.5 - SlimeAire.TOCA_TROMBA)), "la Tromba toca el suelo cuando le toca el golpe")
	var circ := CombatFormas.circulo(Vector2.ZERO, 70.0)
	var antes: int = get_child_count()
	var ll = AbisalAire.area(self, circ, AbisalAire.Modo.LLUVIA, 1, 0.0, 4)
	_ver(ll is EfectoPixel and get_child_count() == antes + 4, "la Lluvia: una estrella por punto")
	var ultima: EfectoPixel = get_child(antes + 3)
	_ver(is_equal_approx(ultima.retardo, AbisalAire.T_ENTRE * 3.0), "una tras otra")
	ultima.set_process(false)
	ultima._t = AbisalAire.T_ENTRE * 2.0
	_ver(not (ultima.get_child(0) as Sprite2D).visible, "la ultima aun no ha salido cuando caen las otras")
	ultima._t = AbisalAire.T_ENTRE * 3.0 + AbisalAire.T_MARCA + AbisalAire.T_CAE + 0.001
	_ver(ultima.marco_actual() == 6, "y toca el suelo (marco 6) cuando dice el combate")
	var rayo = AbisalAire.area(self, CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 150.0, 12.0), AbisalAire.Modo.MIRADA, 1, 0.0)
	_ver(rayo is RayoPixel and is_equal_approx(rayo.duracion(), AbisalAire.T_TRAZA + AbisalAire.T_RAYO + AbisalAire.T_APAGA_RAYO), "el rayo, por celdas y con sus tiempos")
	var f_ag := CombatFormas.circulo(Vector2(100, 0), 85.0)
	f_ag.dir = Vector2.RIGHT
	f_ag.ancho = 100.0
	var ag = AbisalAire.area(self, f_ag, AbisalAire.Modo.AGUJERO, 1, 0.0)
	_ver(ag is EfectoPixel and ag._bola != null and is_equal_approx(ag._t, -AbisalAire.t_vuela(f_ag)), "el Agujero, con su bolita y su espera")
	var es: PiezaPixel = AbisalAire.estrella(self, CombatFormas.circulo(Vector2.ZERO, 6.0), 1)
	_ver(es != null and is_instance_valid(es._actual), "la estrella que se queda")
	if es != null:
		es.secar()
	print("3c) EL PROFUNDO Y SUS MUTANTES")
	for m_p in [ProfundoAire.Modo.MAREA, ProfundoAire.Modo.ESTALLIDO]:
		_ver(ProfundoAire.area(self, CombatFormas.circulo(Vector2.ZERO, 40.0), m_p, 1, 0.0) is EfectoPixel, "por el suelo %d, en pixel" % m_p)
	_ver(ProfundoAire.area(self, CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 110.0, 20.0), ProfundoAire.Modo.CHORRO, 1, 0.0) is EfectoPixel, "el Chorro, en pixel")
	_ver(ProfundoAire.area(self, CombatFormas.cono(Vector2.ZERO, Vector2.RIGHT, 60.0, 80.0), ProfundoAire.Modo.CORAL, 1, 0.0) is EfectoPixel, "el Coral, en pixel")
	_ver(ProfundoAire.area(self, CombatFormas.cono(Vector2.ZERO, Vector2.RIGHT, 70.0, 70.0), ProfundoAire.Modo.ALIENTO, 1, 0.0) is EfectoPixel, "el Aliento, en pixel")
	var ten = ProfundoAire.sobre_cuerpo(self, ProfundoAire.Modo.ANEMONA, Rect2(0, 0, 50, 50), Rect2(100, 0, 20, 30), Vector2(110, 30), 1, 0.12, 1.0)
	_ver(ten is TentaculosPixel, "los tentaculos, por celdas")
	_ver(ProfundoAire.sobre_cuerpo(self, ProfundoAire.Modo.HELADA, Rect2(), Rect2(100, 0, 20, 30), Vector2(110, 30), 1, 0.0, 1.0) is EfectoPixel, "el destello helado, en pixel")
	print("3d) EL REY Y SUS MUTANTES")
	_ver(SlimeAire.area(self, CombatFormas.circulo(Vector2.ZERO, 70.0), SlimeAire.Modo.APLASTA, semilla, 0.0) is EfectoPixel, "el Aplastamiento, en pixel")
	var trz = SlimeAire.sobre_cuerpo(self, SlimeAire.Modo.TROZO, Vector2.ZERO, Rect2(90, 0, 20, 30), col, semilla, 0.22, 1.0)
	_ver(trz is EfectoPixel and trz._bola != null, "el trozo de la Escision vuela")
	antes = get_child_count()
	SlimeAire.sobre_cuerpo(self, SlimeAire.Modo.TROZO, Vector2.ZERO, Rect2(90, 0, 20, 30), col, semilla, 0.22, 1.0, false)
	_ver(get_child_count() == antes + 1, "al destronado no le vuelve")
	_ver(SlimeAire.sobre_cuerpo(self, SlimeAire.Modo.CRIA, Vector2.ZERO, Rect2(90, 0, 20, 30), col, semilla, 0.3, 1.0) is EfectoPixel, "la cria, en pixel")
	_ver(ReyAire.area(self, CombatFormas.cono(Vector2.ZERO, Vector2.RIGHT, 90.0, 60.0), ReyAire.Modo.ESQUIRLAS, 1, 0.0) is EfectoPixel, "las Esquirlas de la corona, en pixel")
	var f_cl := CombatFormas.circulo(Vector2(60, 0), 11.0)
	f_cl.origen = Vector2.ONE
	var cl: PiezaPixel = ReyAire.pieza(self, f_cl, ReyAire.Modo.CLAVADA, col, 1)
	_ver(cl != null and cl.fase() == PiezaPixel.Fase.SALE, "la clavada vuela y se queda")
	cl.secar()
	var ped: PiezaPixel = ReyAire.pieza(self, CombatFormas.circulo(Vector2(60, 0), 12.0), ReyAire.Modo.PEDAZO, col, 1)
	ped.volver_a(Vector2.ZERO)
	_ver(ped.fase() == PiezaPixel.Fase.SE_VA, "el pedazo que le vuelve se va")
	await get_tree().create_timer(0.7).timeout
	_ver(not is_instance_valid(ped), "y desaparece al llegar")
	print("3e) LA RATA Y SUS MUTANTES")
	_ver(BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.MORDISCO, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.14, 1.0, 30.0) is EfectoPixel, "el mordisco, en pixel")
	_ver(BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.FRENESI, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.08, 1.0, 30.0) is EfectoPixel, "el frenesi, en pixel")
	_ver(BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.MORDISCO, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.14, 1.0, 90.0) is BestiaAire, "una boca grande, aun no")
	var f_salto := CombatFormas.circulo(Vector2(100, 0), 25.0)
	f_salto.dir = Vector2.RIGHT
	f_salto.ancho = 60.0
	_ver(RataAire.area(self, f_salto, RataAire.Modo.ESTELA_SOMBRA, 1, 0.0) is EfectoPixel, "el salto en la sombra")
	_ver(RataAire.area(self, f_salto, RataAire.Modo.TRAICION, 1, 0.0) is EfectoPixel, "la Traicion")
	_ver(RataAire.area(self, CombatFormas.circulo(Vector2.ZERO, 40.0), RataAire.Modo.ANILLO_ESQUIRLAS, 1, 0.0) is EfectoPixel, "el anillo de esquirlas")
	_ver(RataAire.area(self, CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 70.0, 18.0), RataAire.Modo.SURCO_CRISTAL, 1, 0.0) is EfectoPixel, "el surco")
	_ver(RataAire.area(self, CombatFormas.cono(Vector2.ZERO, Vector2.RIGHT, 70.0, 70.0), RataAire.Modo.DESTELLO, 1, 0.0) is EfectoPixel, "el Destello")
	for m_r in [RataAire.Modo.JIRONES, RataAire.Modo.ESQUIRLAS, RataAire.Modo.CORTE, RataAire.Modo.VELO]:
		_ver(RataAire.sobre_cuerpo(self, m_r, Vector2.ZERO, Rect2(30, 0, 14, 26), Color.BLACK, 1, 0.0, 1.0) is EfectoPixel, "sobre el cuerpo %d" % m_r)
	print("4) LO QUE SE QUEDA")
	var nube: PiezaPixel = SlimeAire.nube_pixel(self, CombatFormas.circulo(Vector2.ZERO, 50.0), col, 0.0)
	_ver(nube != null and nube.fase() == PiezaPixel.Fase.SALE, "la nube sale")
	await get_tree().create_timer(0.8).timeout
	_ver(nube.fase() == PiezaPixel.Fase.DURA, "y se queda")
	await get_tree().create_timer(1.5).timeout
	_ver(nube.fase() == PiezaPixel.Fase.DURA and is_instance_valid(nube._actual), "mientras no la sequen, sigue")
	nube.secar()
	_ver(nube.fase() == PiezaPixel.Fase.SE_VA, "al secarse, se va")
	await get_tree().create_timer(1.2).timeout
	_ver(not is_instance_valid(nube), "y desaparece")
	var bu: PiezaPixel = SlimeAire.burbuja_pixel(self, CombatFormas.circulo(Vector2(50, 0), 22.0), col)
	_ver(bu != null and bu.tiembla, "la burbuja, que tiembla")
	var ba: PiezaPixel = SlimeAire.baba_pixel(self, CombatFormas.linea(Vector2.ZERO, Vector2.LEFT, 70.0, 41.0), col, true)
	_ver(ba != null and is_instance_valid(ba._actual), "la baba con pinchos, en una linea hacia el oeste")
	# La embestida estira el efecto a lo que tarda el cuerpo en cruzar, como a los demas (SueloRoto lo busca por nombre).
	var n: Node2D = SueloRoto.lanzar(self, linea, SueloRoto.Tipo.SLIME_PLACAJE, semilla)
	_ver(n != null and float(n.get("_ritmo")) != 1.0 or SueloRoto.t_salir_de(SueloRoto.Tipo.SLIME_PLACAJE) == SueloRoto.t_embestida(linea), "la embestida le ajusta el ritmo")
	for h in get_children():
		h.queue_free()
	print("%s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
