# SACA LAS MARCAS DEL JEFE de la lamina de cuerpos (tools/lamina_cuerpos_enemigos.gd) y las pasa a medidas del juego.
#   python tools/cuerpos/sacar_cuerpos.py C:/Users/dasui/Desktop/ataques_mapa/cuerpos
# Cada pagina_N.png marcada va con su pagina_N.json y su original_N.png (la misma sin tocar) (donde cae cada enemigo en la foto, lo escribe la herramienta; la
# maquetacion es siempre la misma). En la foto: ROJO = su cuerpo (un rectangulo: el que encierra el trazo), AZUL = un
# puntito dentro del cuerpo (centro desde el que mide su alcance; si no hay, el centro del rojo) y una raya fuera
# (hasta donde llega). Escribe tools/cuerpos/cuerpos.json: por enemigo, el rectangulo RESPECTO A SU NODO y su alcance,
# en px de mundo y tambien divididos por su escala_visual (para que sigan valiendo si se cambia el tamaño).
import json, os, sys
from PIL import Image

def es_rojo(c): return c[0] > 170 and c[1] < 90 and c[2] < 90
def es_azul(c):
    # El VERDE vale igual (en el Rey Slime, que es azul, no se veia el azul).
    return (c[2] > 150 and c[0] < 110 and c[2] - c[0] > 80) or (c[1] > 150 and c[0] < 110 and c[2] < 110)

def componentes(pts):
    pts = set(pts); out = []
    while pts:
        p = pts.pop(); pila = [p]; comp = [p]
        while pila:
            x, y = pila.pop()
            for dx in (-2, -1, 0, 1, 2):
                for dy in (-2, -1, 0, 1, 2):
                    q = (x + dx, y + dy)
                    if q in pts:
                        pts.remove(q); pila.append(q); comp.append(q)
        out.append(comp)
    return out

def caja(comp):
    xs = [p[0] for p in comp]; ys = [p[1] for p in comp]
    return min(xs), min(ys), max(xs), max(ys)

def main(carpeta):
    res = {}
    # Las 5 paginas y las que se rehagan sueltas (el miconido, 09/10, al crecer): 'miconido_nuevo.png' con su
    # pagina_miconido.json y original_miconido.png. Un enemigo sin marcar en una pagina no pisa lo de otra.
    for n in list(range(1, 10)) + ["miconido"]:
        png = os.path.join(carpeta, ("pagina_%d.png" % n) if isinstance(n, int) else ("%s_nuevo.png" % n))
        js = os.path.join(os.path.dirname(__file__), "pagina_%s.json" % n)
        if not os.path.exists(png) or not os.path.exists(js):
            continue
        datos = json.load(open(js, encoding="utf-8"))
        im = Image.open(png).convert("RGB"); px = im.load(); w, h = im.size
        # Solo lo que ha PINTADO el jefe: comparado con la lamina sin tocar (original_N.png), que si no el minotauro, que
        # es rojo, o la gema del Rey Slime contaban como trazo.
        orig = Image.open(os.path.join(os.path.dirname(__file__), "original_%s.png" % n)).convert("RGB").load()
        rojos = []; azules = []
        for y in range(h):
            for x in range(w):
                c = px[x, y]
                o = orig[x, y]
                if abs(c[0] - o[0]) + abs(c[1] - o[1]) + abs(c[2] - o[2]) < 90: continue
                if es_rojo(c): rojos.append((x, y))
                elif es_azul(c): azules.append((x, y))
        # Cada trazo, al enemigo cuyo nodo tenga mas cerca (y a su derecha la raya: la celda es suya).
        def dueno(cx, cy):
            return min(datos, key=lambda d: (d["nodo"][0] - cx) ** 2 + ((d["nodo"][1] - cy) * 1.6) ** 2)
        por = {d["res"]: {"rojo": [], "azul": []} for d in datos}
        for comp in componentes(rojos):
            if len(comp) < 15: continue
            x0, y0, x1, y1 = caja(comp)
            por[dueno((x0 + x1) / 2, (y0 + y1) / 2)["res"]]["rojo"].append((x0, y0, x1, y1))
        for comp in componentes(azules):
            if len(comp) < 3: continue
            x0, y0, x1, y1 = caja(comp)
            por[dueno((x0 + x1) / 2, (y0 + y1) / 2)["res"]]["azul"].append((x0, y0, x1, y1, len(comp)))
        for d in datos:
            m = por[d["res"]]; z = d["zoom"]; nx, ny = d["nodo"]
            if not m["rojo"]:
                if d["res"] not in res:
                    print("  (sin marcar) %s" % d["nombre"])
                continue
            x0 = min(r[0] for r in m["rojo"]); y0 = min(r[1] for r in m["rojo"])
            x1 = max(r[2] for r in m["rojo"]); y1 = max(r[3] for r in m["rojo"])
            centro = ((x0 + x1) / 2, (y0 + y1) / 2)
            dentro = [a for a in m["azul"] if a[0] >= x0 - 2 and a[2] <= x1 + 2 and a[1] >= y0 - 2 and a[3] <= y1 + 2]
            fuera = [a for a in m["azul"] if a not in dentro]
            if dentro:
                a = max(dentro, key=lambda a: a[4]); centro = ((a[0] + a[2]) / 2, (a[1] + a[3]) / 2)
            alcance = None
            if fuera:
                raya = max(fuera, key=lambda a: a[4])
                alcance = round((((raya[0] + raya[2]) / 2) - centro[0]) / z, 1)
            e = d["escala"]
            rect = [round((x0 - nx) / z, 1), round((y0 - ny) / z, 1), round((x1 - x0) / z, 1), round((y1 - y0) / z, 1)]
            res[d["res"]] = {"nombre": d["nombre"], "escala": e, "cuerpo": rect,
                "centro": [round((centro[0] - nx) / z, 1), round((centro[1] - ny) / z, 1)], "alcance": alcance,
                "cuerpo_u": [round(v / e, 2) for v in rect], "alcance_u": round(alcance / e, 2) if alcance else None}
            print("  %-26s cuerpo %s  alcance %s" % (d["nombre"], rect, alcance))
    sal = os.path.join(os.path.dirname(__file__), "cuerpos.json")
    json.dump(res, open(sal, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("->", sal, len(res), "enemigos")

main(sys.argv[1] if len(sys.argv) > 1 else "C:/Users/dasui/Desktop/ataques_mapa/cuerpos")
