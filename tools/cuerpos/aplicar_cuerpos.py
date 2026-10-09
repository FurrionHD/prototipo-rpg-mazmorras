# ESCRIBE EN CADA FICHA DE ENEMIGO (.tres) el cuerpo, el centro y el alcance que saco sacar_cuerpos.py de la lamina
# marcada por el jefe (EnemyData.cuerpo / centro_golpe / alcance_marcado, en unidades de escala).
#   python tools/cuerpos/aplicar_cuerpos.py
# A MANO sobre el texto y no con Godot: abrir y guardar un .tres desde el editor lo reserializa entero (y se lleva los
# comentarios). Solo se tocan esas tres lineas de la seccion [resource].
import json, os, re

RAIZ = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))

def fmt(v):
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"

def main():
    datos = json.load(open(os.path.join(os.path.dirname(__file__), "cuerpos.json"), encoding="utf-8"))
    for res, d in datos.items():
        ruta = os.path.join(RAIZ, res.replace("res://", ""))
        txt = open(ruta, encoding="utf-8", newline="").read()
        nl = "\r\n" if "\r\n" in txt else "\n"
        e = float(d["escala"])
        c = d["cuerpo_u"]
        lineas = {"cuerpo": "Rect2(%s, %s, %s, %s)" % tuple(fmt(v) for v in c),
                  "centro_golpe": "Vector2(%s, %s)" % (fmt(d["centro"][0] / e), fmt(d["centro"][1] / e))}
        if d.get("alcance_u"):
            lineas["alcance_marcado"] = fmt(d["alcance_u"])
        i = txt.index("[resource]")
        cab, cuerpo = txt[:i], txt[i:]
        for k, v in lineas.items():
            pat = re.compile(r"^%s = .*$" % k, re.M)
            if pat.search(cuerpo):
                cuerpo = pat.sub("%s = %s" % (k, v), cuerpo, count=1)
            else:
                cuerpo = cuerpo.rstrip("\r\n") + nl + "%s = %s" % (k, v) + nl
        open(ruta, "w", encoding="utf-8", newline="").write(cab + cuerpo)
        print("  %-26s %s" % (d["nombre"], lineas))

main()
