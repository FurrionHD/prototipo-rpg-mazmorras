# ============================================================
#  tinte_podrido.gd  (sin class_name: se usa con preload)
#  EL CADAVER SE VA PONIENDO RANCIO (12/10, lo pidio el jefe: "que se vayan poniendo color rancio segun pasa el
#  tiempo, y asi se ve el tiempo que pasa realmente"). Recien caido se ve igual que siempre; segun se acerca su hora
#  de pudrirse (enemy.CADAVER_SEGUNDOS) va tirando a verde-pardo y apagado, y al final se desvanece (lo hace
#  dungeon_floor._pudrir_cadaveres). Va en self_modulate: el modulate del sprite lo tocan otros (pose, avisos).
#  Lo calcula cada maquina con su reloj desde lo que le queda al cuerpo, asi que se ve igual en todas.
# ============================================================
extends RefCounted

const RANCIO := Color(0.58, 0.60, 0.36)   # verdoso-pardo
const APAGADO := 0.82                      # y algo mas oscuro al final


# 'f' = cuanto se ha podrido: 0 recien caido, 1 a punto de irse.
static func tinte(f: float) -> Color:
	var k: float = smoothstep(0.0, 1.0, clampf(f, 0.0, 1.0))
	var c: Color = Color.WHITE.lerp(RANCIO, k)
	return c.darkened((1.0 - APAGADO) * k)
