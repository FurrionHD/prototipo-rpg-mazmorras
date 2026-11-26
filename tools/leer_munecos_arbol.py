# tools/leer_munecos_arbol.py (25/11): LEE UNA TANDA DE MUÑECOS DE CAMINOS DE ARBOL (tools/caminos_arbol.py).
# Por habilidad y escenario (muneco, munecos, munecos_juntos), el daño por turno de cada camino en % de la misma habilidad
# SIN arbol (el nominal: el simulador le finge el nivel x1,4 por nivel). Media de sus peleas.
#   python tools/leer_munecos_arbol.py munecos_estoque2
import csv
import sys
from collections import defaultdict
from pathlib import Path

tanda = sys.argv[1] if len(sys.argv) > 1 else "munecos_estoque2"
ruta = Path(__file__).resolve().parent / "resultados_simulador" / (tanda + "_personajes.csv")
NOMBRE_A_CLAVE = {"Estocada penetrante": "estocada_penetrante", "Fintas": "fintas", "Danza de acero": "danza_de_acero",
                  "En guardia": "en_guardia", "Paso ligero": "paso_ligero", "Punzada al nervio": "punzada_al_nervio",
                  "Avance cubierto": "avance_cubierto"}
d = defaultdict(list)
for r in csv.DictReader(open(ruta, encoding="utf-8"), delimiter=";"):
    if r.get("rol") != "guerrero":
        continue
    arma = r["arma"].split("@")[0]
    if "#" not in arma:
        # la habilidad SIN arbol sale apuntada como el arma a secas: cual era, por lo que uso (columna acciones)
        usadas = [x.split(":")[0] for x in r.get("acciones", "").split(",") if x and not x.startswith(("atacar", "defender", "Poci"))]
        if not usadas:
            continue
        hab = NOMBRE_A_CLAVE.get(usadas[0], "")
        if not hab:
            continue
    else:
        hab = arma.split("#", 1)[1]
    camino = hab.split(":", 1)[1] if ":" in hab else ""
    hab = hab.split(":", 1)[0]
    try:
        d[(hab, r["escenario"], camino)].append(float(r["dano_por_turno"]))
    except ValueError:
        pass

ESC = ["muneco", "munecos", "munecos_juntos"]
habs = sorted({k[0] for k in d})
for h in habs:
    caminos = sorted({k[2] for k in d if k[0] == h and k[2] != ""})
    print("\n== %s   (%% del nominal: 1 muñeco / corro de 10 / grupo apretado)" % h)
    nom = {e: (sum(d[(h, e, "")]) / len(d[(h, e, "")])) if d[(h, e, "")] else 0.0 for e in ESC}
    print("   nominal: " + "  ".join("%s %.0f" % (e, nom[e]) for e in ESC))
    filas = []
    for c in caminos:
        v = []
        for e in ESC:
            xs = d[(h, e, c)]
            v.append(100.0 * (sum(xs) / len(xs)) / nom[e] if xs and nom[e] > 0 else float("nan"))
        filas.append((c, v))
    for c, v in sorted(filas, key=lambda f: -f[1][0]):
        print("   %5.0f %5.0f %5.0f   %s" % (v[0], v[1], v[2], c))
