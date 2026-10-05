# ============================================================
#  escarabajo3d_sprites.gd  (class_name Escarabajo3DSprites)
#  EL ESCARABAJO DE HIERRO EN 3D (05/10/2026): el domo con su brillo de metal; se hace BOLA y RUEDA, y muere panza arriba.
#  Se modela en tools/sprites_sdf/escarabajo_sdf.py y aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso).
#  Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual. El viejo (EscarabajoSprites, por codigo) queda
#  de referencia.
# ============================================================

extends RefCounted
class_name Escarabajo3DSprites

const CARPETA := "res://assets/sprites/enemigos/escarabajo_sdf/"
# El lienzo del generador viejo a su escala (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(80, 80)
# El color en que estan pintadas las hojas (el de su ficha).
const BASE := Color("5c8055")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 7.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# EL PALAZO: empuja con la pala en la mitad.
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	# Se aplasta del todo en el 0,571 (sale el reflejo del efecto).
	"caparazon": {"hoja": "caparazon", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"hacerse_bola": {"hoja": "hacerse_bola", "dirs": 8, "marcos": 6, "fps": 12.0, "loop": false},
	"bola": {"hoja": "bola", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	# Dos vueltas a 90 grados por marco y se desenrosca (= InsectoAire.T_RODADA).
	"rodar": {"hoja": "rodar", "dirs": 8, "marcos": 12, "fps": 18.0, "loop": false},
	"desenroscarse": {"hoja": "desenroscarse", "dirs": 8, "marcos": 5, "fps": 12.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'escarabajo3d_' y no 'escarabajo_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "escarabajo3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), EscarabajoSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return EscarabajoSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, EscarabajoSprites.COLOR_PASOS))
