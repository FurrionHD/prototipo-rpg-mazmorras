# ============================================================
#  boca_sprites.gd
#  LA BOCA, aparte de los ojos (se eligen por separado: lo pidio el usuario, con una hoja de emojis en
#  pixel art de referencia). Misma tecnica que CaraSprites: un SELLO de pixeles estampado donde cae la
#  boca en este fotograma, y la misma paleta (no se tiñe).
#
#  Se carga por preload desde JugadorSprites y no lleva class_name: un class_name nuevo no existe para
#  las herramientas de linea de comandos hasta pasar --import (ver hornear_sprites.bat).
# ============================================================
extends RefCounted

const PIEZA := "boca"

const R := PoseJugador.CABEZA_R

# Los dibujos, de arriba abajo. Letras de CaraSprites.LETRAS: B raya · D por dentro · T lengua.
const BOCAS := {
	"recta": ["BBB"],
	"sonrisa": ["B..B", ".BB."],
	"abierta": ["BBBB", "BDDB", ".BB."],
	"o": ["BB", "BB"],   # con hueco dentro (".B./BDB/.B.") se leia como una cruz
	"lengua": ["BBBB", ".TT."],
	"media": ["...B", "BBB."],
	"triste": [".BB.", "B..B"],
}


static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), CaraSprites.colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), CaraSprites.colores(), esc)


static func clave(modelo: String) -> String:
	return "%s_%s" % [PIEZA, modelo]


# Donde va: CaraSprites.SITIOS, medido sobre la piel que se ve (la proyeccion la ponia en el moflete en
# diagonal y encima del pelo de perfil, ver alli).
static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	var d: int = int(esq.get("dir", 0))
	if d == 3 or d == 4 or d == 5:
		return
	var dibujo: Array = BOCAS.get(modelo, [])
	if dibujo.is_empty():
		return
	var c: Vector2i = CaraSprites.centro_cabeza(esq)
	var espejar: bool = d == 6 or d == 7
	var dm: int = {0: 0, 1: 1, 7: 1, 2: 2, 6: 2}[d]
	var sitio: Dictionary = CaraSprites.SITIOS[dm]
	var ancho: int = String(dibujo[0]).length()
	var alto: int = dibujo.size()
	var y0: int
	var x0: int
	var columnas: Array = []
	if dm == 2:
		# DE PERFIL, SOLO LA MITAD DE DELANTE (una sonrisa entera de lado se lee como un bigote), con su
		# columna de delante en el borde medido.
		x0 = c.x + int(sitio["boca_borde"]) - ancho + 1
		y0 = int(floor(float(c.y) + float(sitio["boca_y"]) - float(alto - 1) * 0.5))
		for i in ancho:
			if i >= ancho / 2:
				columnas.append(i)
	else:
		var cen: Vector2 = sitio["boca"]
		x0 = int(floor(float(c.x) + cen.x - float(ancho - 1) * 0.5))
		y0 = int(floor(float(c.y) + cen.y - float(alto - 1) * 0.5))
	CaraSprites.sello_en(piezas, x0, y0, dibujo, false, false, columnas, c.x, espejar)
