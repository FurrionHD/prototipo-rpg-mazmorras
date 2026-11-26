# tools/caminos_arbol.py (25/11): los caminos hasta el nivel 5 del arbol de cada habilidad, para el simulador.
#   python tools/caminos_arbol.py [hab1,hab2] [arma]  -> arma#hab,arma#hab:n2.n3.n4.n5,...  (arma: estoque por defecto;
#   con escudo, 'estoque+escudo_pequeno' para el Avance cubierto)
# Los caminos hasta el nivel 5 de cada habilidad del estoque (uno por nodo de cada nivel, respetando padres y exclusiones),
# como lista de 'estoque#hab:n2.n3.n4.n5' para el simulador. Mas cada habilidad sin arbol (el nominal).
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arboles_habilidades as A

HABS = sys.argv[1].split(",") if len(sys.argv) > 1 else ["estocada_penetrante", "fintas", "danza_de_acero", "paso_ligero",
                                                          "punzada_al_nervio"]


def caminos(clave):
    nodos = {n[0]: n for n in A.ARBOLES[clave]}
    out = []

    def seguir(camino, nivel):
        if nivel > 5:
            out.append(camino)
            return
        hay = False
        for nid, n in nodos.items():
            if n[1] != nivel:
                continue
            padres = n[2]
            if padres and not any(p in camino for p in padres):
                continue
            if any(x in camino for x in n[3]):
                continue
            hay = True
            seguir(camino + [nid], nivel + 1)
        if not hay:
            out.append(camino)

    seguir([], 2)
    return out


ARMA = sys.argv[2] if len(sys.argv) > 2 else "estoque"
lista = []
for h in HABS:
    lista.append("%s#%s" % (ARMA, h))
    for c in caminos(h):
        lista.append("%s#%s:%s" % (ARMA, h, ".".join(c)))
print(",".join(lista))
print(len(lista), file=sys.stderr)
