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
	_ver(BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.MORDISCO, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.14, 1.0, 90.0) is EfectoPixel, "la del Rey Rata, igual")
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
	print("3f) EL REY RATA Y SUS MUTANTES")
	_ver(BestiaAire.area(self, CombatFormas.cono(Vector2.ZERO, Vector2.RIGHT, 100.0, 120.0), BestiaAire.Modo.CHILLIDO, 1, 0.0) is EfectoPixel, "el Chillido")
	_ver(BestiaAire.area(self, CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 55.0, 12.0), BestiaAire.Modo.ESTELA, 1, 0.0) is EfectoPixel, "el polvo de la Yugular")
	_ver(ReyRataAire.agujero(self, Vector2.ZERO, ReyRataAire.Version.GRIETA, 1).has_meta("grieta"), "la grieta de la Llamada")
	_ver(ReyRataAire.golpe(self, ReyRataAire.Modo.CAMPANAZO, Vector2.ZERO, Vector2.RIGHT, 12.0, 1) is EfectoPixel, "el campanazo")
	var pega := Node2D.new()
	add_child(pega)
	var fu: ReyRataAire = ReyRataAire.furia(self, pega, 2, Vector2.DOWN, 1)
	_ver(fu != null and is_instance_valid(fu._hoja), "la Furia de Rey")
	fu.poner_nivel(3, Vector2.RIGHT)
	_ver(fu.nivel == 3, "que sube de nivel")
	fu.parar()
	pega.queue_free()
	print("3g) EL JABALI Y SUS MUTANTES")
	_ver(BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.COLMILLO, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.14, 1.0, 40.0) is EfectoPixel, "el colmillazo")
	_ver(BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.CHOQUE, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.0, 1.0, 40.0) is EfectoPixel, "el choque")
	_ver(BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.CORNADA, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.14, 1.0, 40.0) is BestiaAire, "la Cornada sigue levantando (y su hoja sale al llegar)")
	var ya: Array = get_children()
	BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.CORNADA, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.14, 1.0, 40.0)
	await get_tree().create_timer(0.25).timeout
	var hoja_c: EfectoPixel = null
	for h in get_children():
		if h is EfectoPixel and not ya.has(h):
			hoja_c = h
	_ver(hoja_c != null, "y al llegar sale su hoja")
	await get_tree().create_timer(1.3).timeout
	_ver(not is_instance_valid(hoja_c), "que se va sola")
	_ver(BestiaAire.area(self, CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 90.0, 22.0), BestiaAire.Modo.SURCO, 1, 0.0) is EfectoPixel, "el surco de la Embestida")
	_ver(BestiaAire.area(self, CombatFormas.circulo(Vector2.ZERO, 30.0), BestiaAire.Modo.PISOTON, 1, 0.0) is EfectoPixel, "el Pisoton")
	var surco50 = RataAire.area(self, CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 50.0, 14.0), RataAire.Modo.SURCO_CRISTAL, 1, 0.0)
	_ver(surco50 is EfectoPixel, "el surco de la Cornada de cristal, a su largo")
	_ver(JabaliAire.estallido(self, Vector2.ZERO, Vector2.RIGHT, 10.0, 1) != null, "el estallido")
	_ver(JabaliAire.esporas(self, Vector2.ZERO, 40.0, 1) != null, "las esporas")
	var refl: EfectoPixel = JabaliAire.reflejo(self, Vector2.ZERO, Vector2(100, 0), 1)
	_ver(refl != null and refl._bola != null, "el reflejo, con su bola")
	_ver(JabaliAire.quema(self, Vector2.ZERO, Vector2.RIGHT, 1) != null, "el humo de la quema")
	print("3h) EL TRENT Y SUS MUTANTES")
	_ver(BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.RAMALAZO, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.14, 1.0, 40.0) is EfectoPixel, "el ramalazo")
	_ver(BestiaAire.area(self, CombatFormas.cono(Vector2.ZERO, Vector2.RIGHT, 55.0, 140.0), BestiaAire.Modo.RAMAZO, 1, 0.0) is EfectoPixel, "el Ramazo")
	var rz = BestiaAire.area(self, CombatFormas.circulo(Vector2(60, 0), 30.0), BestiaAire.Modo.RAICES, 1, 0.0)
	_ver(rz is EfectoPixel, "las Raices")
	var at: PiezaPixel = BestiaAire.atado(self, Rect2(50, -26, 14, 26), Vector2(60, 0), 1)
	_ver(at != null and at._actual != null and at._actual._t < -0.5, "el atado espera a que salgan las raices")
	at.secar()
	var f_sv := CombatFormas.circulo(Vector2(60, 0), 20.0)
	f_sv.dir = Vector2.RIGHT
	var sv = BestiaAire.area(self, f_sv, BestiaAire.Modo.SAVIA, 1, 0.0)
	_ver(sv is EfectoPixel and sv._bola != null, "el goteron de savia vuela")
	var ch: PiezaPixel = BestiaAire.charco(self, CombatFormas.circulo(Vector2.ZERO, 20.0), 1, 0.0)
	BestiaAire.vestir_savia_negra(ch)
	_ver(ch != null and ch._paleta == BestiaAire.PAL_NEGRA, "el charco de savia negra")
	ch.secar()
	var f_g := CombatFormas.circulo(Vector2(100, 0), 45.0)
	f_g.dir = Vector2.RIGHT
	f_g.ancho = 80.0
	_ver(TrentAire.area(self, f_g, TrentAire.Modo.GEISER, 1, 0.35) != null, "el Geiser")
	_ver(TrentAire.area(self, f_g, TrentAire.Modo.RESINA, 1, 0.2) is EfectoPixel, "el goteron de Resina")
	_ver(TrentAire.chupar(self, Vector2(100, 0), Vector2.ZERO, 0, 1) is CintaPixel, "Chupar")
	var hu: PiezaPixel = TrentAire.pegado(self, TrentAire.Modo.HUMO, Rect2(0, -30, 14, 30), 2, 1)
	hu.poner_nivel(4)
	await get_tree().process_frame
	_ver(hu._dura == "humo_4", "el humo, mas espeso con mas cargas")
	hu.secar()
	var spr_g := AnimatedSprite2D.new()
	add_child(spr_g)
	_ver(TrentAire.pegado(self, TrentAire.Modo.SECO, Rect2(), 2, 1, spr_g) is GrietaPixel, "las grietas que laten, sobre su sprite")
	spr_g.queue_free()
	_ver(AmbarAire.pegado(self, AmbarAire.Modo.PICOR, Rect2(0, -30, 14, 30), 1) != null, "el picor")
	_ver(AmbarAire.revienta(self, Vector2.ZERO, 30.0, 1) != null, "el reventon de la garrapata")
	print("3i) LA ARANA Y SUS MUTANTES")
	_ver(InsectoAire.sobre_cuerpo(self, InsectoAire.Modo.QUELICEROS, Vector2.ZERO, Rect2(30, 0, 14, 26), 1, 0.14, 1.0) is EfectoPixel, "los queliceros")
	var f_tela := CombatFormas.circulo(Vector2(100, 0), 25.0)
	f_tela.dir = Vector2.RIGHT
	var tela = InsectoAire.area(self, f_tela, InsectoAire.Suelo.TELARANA, 1, 0.0)
	_ver(tela is EfectoPixel and tela._bola != null, "el ovillo vuela")
	_ver(InsectoAire.red(self, f_tela, 1, 0.0) is PiezaPixel, "y la red se queda")
	var ray: RayoPixel = AranaAire.arco(self, Vector2.ZERO, Vector2(100, 0), false, 0.14, 1.0)
	_ver(ray != null and ray.quiebros >= 3, "el rebote, en zigzag")
	_ver(AranaAire.rayos(self, Vector2.ZERO, 80.0, 1) is EfectoPixel and AranaAire.fogonazo(self, Vector2.ZERO, 60.0, 1) is EfectoPixel, "la Descarga y la Explosion")
	_ver(BestiaAire.area(self, CombatFormas.circulo(Vector2.ZERO, 45.0), BestiaAire.Modo.PISOTON, 1, 0.0) is EfectoPixel, "el Pisoton de trueno")
	var cg: AranaAire = AranaAire.pegado(self, Rect2(0, -30, 20, 30), false, 1)
	cg.poner_nivel(2, 4)
	_ver(is_instance_valid(cg._cont) and is_instance_valid(cg._aura), "las cargas, con su contador")
	cg.secar()
	var pt: AranaAire = AranaAire.puntos(self, Rect2(0, -30, 20, 30), 1)
	pt.poner_nivel(1, 3)
	_ver(is_instance_valid(pt._cont) and pt._aura == null, "los puntos de la costra, solo el contador")
	pt.secar()
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
