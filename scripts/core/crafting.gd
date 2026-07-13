# ============================================================
#  crafting.gd
#  Las reglas que valen para TODO lo que se fabrica: pociones (boticaria), equipo (herrero),
#  cuero (peletero) y lo que venga. Estatico, como StatsMath / Upgrades.
#
#  Nacieron en la forja, pero no son de la forja: cualquier receta que gaste materiales en
#  UNIDADES se topa con lo mismo, asi que viven aqui y cada oficio las llama.
#
#  1) RECORTE: solo se gasta lo NECESARIO. Si metes de mas, el sobrante se queda en el baul.
#     Lo que se descarta es lo PEOR que hayas metido (mientras el resto siga cubriendo el
#     coste), asi que pasarse nunca te perjudica: te quedas el material bueno Y fabricas con
#     la mejor media de calidad posible. La math del recorte esta en Game (que es quien tiene
#     el baul): Game.recortar_seleccion().
#
#  2) APROVECHAMIENTO: el material no se parte por la mitad. Si la receta pide 4 unidades y un
#     item intacto vale 3, hay que meter DOS: gastas 6 y sobran 2. Cada unidad que sobra da una
#     probabilidad de recuperar UNA pieza (la peor de las gastadas).
# ============================================================

extends RefCounted
class_name Crafting

# La base es DE MANO CORTA a proposito (20% por unidad: con 2 de sobra, un 40%): el margen para
# que esto se vuelva generoso se lo guardan los OFICIOS (Herreria, Peleteria, Mezcla), que
# cuando se desbloqueen sumaran su bonus aqui encima. No desperdiciar nada es cosa del oficio.
const DEVOLVER_POR_UNIDAD := 0.20

# `bonus_oficio` = lo que aporta la habilidad del oficio que esta fabricando (hoy 0 en todas:
# ninguna esta desbloqueada todavia).
static func prob_devolver(unidades_de_sobra: int, bonus_oficio: float = 0.0) -> float:
	var base: float = DEVOLVER_POR_UNIDAD * float(maxi(0, unidades_de_sobra))
	return clampf(base + bonus_oficio, 0.0, 0.99)


# RESERVADO: lo que un oficio sumara al aprovechamiento cuando su habilidad exista. Sin
# numeros todavia (van al Excel con el resto de la curva).
static func bonus_ahorro(_oficio_exp: float) -> float:
	return 0.0
