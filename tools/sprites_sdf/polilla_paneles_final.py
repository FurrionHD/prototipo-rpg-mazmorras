# ============================================================
#  polilla_paneles_final.py -- LA MEZCLA, VUELTA SIGUIENTE (12/11/2026). Eligio la Q3 (negro y rojo, cuerpo negro) de
#  polilla_paneles_color.py, con dos cambios suyos: "en vez de tantos ojos, uno GRANDE en la de alante, uno MEDIANO en la
#  de atras y el PEQUEÑO en la parte de atras del todo", y "que las alas de atras no terminen tan hacia atras, si no mas
#  ABIERTAS" (su dibujo: la trasera como la delantera, picuda y apuntando hacia fuera).
#  Tres grados de apertura de la trasera (y la cola sigue a la trasera):
#    R1 algo abierta   R2 abierta (la de su dibujo)   R3 muy abierta (casi en linea con la de delante)
#  Uso: python tools/sprites_sdf/polilla_paneles_final.py -> tools/salida/sdf/polilla_paneles_final.png
# ============================================================
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import polilla_sdf as pm
import polilla_versiones as pv
import polilla_paneles as pp
import polilla_paneles_color as pc

ast = pp.ast
Q3 = pc.VARIANTES['Q3 ojo rojo']

# La DELANTERA, un solo panel: el ala entera es el ojo grande.
DEL = pp.DEL

# Las TRASERAS: [raiz-delante, punta-delante, PUNTA (en pico, hacia fuera), raiz-detras]. Cuanto mas abierta, mas hacia
# fuera la punta y menos hacia atras. La COLA cuelga del borde de atras de la trasera, por dentro.
TRASERAS = {
    'R1 algo abierta': ([(0.6, 0.4), (9.4, 1.4), (11.2, 7.6), (1.4, 6.8)],
                        [(1.4, 7.0), (4.4, 7.8), (5.2, 13.6), (2.0, 11.4)]),
    'R2 abierta': ([(0.6, 0.4), (10.4, -0.2), (12.6, 4.8), (1.4, 6.2)],
                   [(1.4, 6.4), (5.0, 6.4), (7.0, 11.2), (2.2, 9.8)]),
    'R3 muy abierta': ([(0.6, 0.6), (11.4, -1.6), (13.8, 2.6), (1.4, 5.6)],
                       [(1.4, 5.8), (6.0, 4.8), (9.4, 8.2), (2.6, 8.6)]),
}


def alas(tra, cola):
    a1 = dict(raiz=pv.R1, marco='marco', anillos=pc.ROJO, gira=0, hueco=0.88, silueta=[DEL], paneles=[DEL])
    a2 = dict(raiz=pv.R2, marco='marco', anillos=pc.ROJO, gira=0, hueco=0.86, silueta=[tra, cola], paneles=[tra, cola])
    return a1, a2


VARIANTES = {'Q3 (la de antes)': Q3}
for nombre, (tra, cola) in TRASERAS.items():
    a1, a2 = alas(tra, cola)
    VARIANTES[nombre] = dict(Q3, ala1=a1, ala2=a2)


if __name__ == '__main__':
    pv.ala_generica = pp.ala_paneles
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, vv in VARIANTES.items():
        mo = ast.mz.modelo(vv)
        L = ast.escena(vv, pm.POSE())
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok', flush=True)
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 140, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (140 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    lam.save('tools/salida/sdf/polilla_paneles_final.png')
    print('tools/salida/sdf/polilla_paneles_final.png')
