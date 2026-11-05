#!/usr/bin/env python3
# ============================================================
#  slime_fuego_efectos_horno.py -- HORNEA LOS EFECTOS DEL SLIME DE FUEGO, LA CENIZA Y LA OBSIDIANA. Su fuego, su ceniza y su cristal
#  llevan su paleta de la lamina (no se tinen). Se suman a las hojas de 'slime'.
#    python tools/sprites_sdf/slime_fuego_efectos_horno.py
# ============================================================
import math
import random

import slime_efectos_pixel as sl
import slime_veneno_efectos_pixel as vn
import slime_fuego_efectos_pixel as fg
import horno_efectos as ho
from slime_efectos_pixel import UNIDAD, nuevo, estrella

sl.victima = vn.victima = fg.victima = lambda a, x, y: None
sl.escena = vn.escena = fg.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'slime'
CX, CY = 90, 80




def por_dirs(funcion, *args, desde=0):
    filas, origenes = [], []
    for d_ in range(5):
        m, _t = funcion(d_, *args)
        filas.append(m[desde:])
        origenes.append(sl.ORIGEN)
    return filas, origenes


def uno(funcion, *args, desde=0):
    m, _t = funcion(*args)
    return [m[desde:]], [sl.ORIGEN]


d = {}
f, o = por_dirs(fg.llamarada, 'lava160')
d['llamarada'] = ho.guardar_efecto(LA, 'llamarada', f, o, 14.0)
f, o = uno(fg.salpicadura, desde=2)
d['salpica'] = ho.guardar_efecto(LA, 'salpica', f, o, 14.0)
f, o = uno(fg.salpicadura, 'cen192', 40.0, fg.CENIZA, fg.CENIZA[0], False, True, desde=2)
d['salpica_ceniza'] = ho.guardar_efecto(LA, 'salpica_ceniza', f, o, 14.0)
f, o = uno(fg.combustion, desde=6)
d['combustion'] = ho.guardar_efecto(LA, 'combustion', f, o, 14.0)
f, o = uno(fg.ignicion)
d['ignicion'] = ho.guardar_efecto(LA, 'ignicion', f, o, 12.0)
f, o = uno(fg.ignicion, 'cen192', True)
d['ignicion_brasas'] = ho.guardar_efecto(LA, 'ignicion_brasas', f, o, 12.0)
f, o = uno(fg.nube_ceniza, desde=5)
d['nube_ceniza'] = ho.guardar_efecto(LA, 'nube_ceniza', f, o, 12.0)
f, o = por_dirs(fg.embestida_cortante)
d['emb_cortante'] = ho.guardar_efecto(LA, 'emb_cortante', f, o, 16.0)
f, o = por_dirs(fg.esquirlas_obs, desde=3)
d['esquirlas_obs'] = ho.guardar_efecto(LA, 'esquirlas_obs', f, o, 14.0)


# --- LA NUBE DE CENIZA QUE SE QUEDA (estilo 7): la bocanada espesa de la lamina, con sus ascuas; sale, dura y se va ---
def nube_que_queda():
    R = 50.0 / UNIDAD
    rnd = random.Random(12)
    puffs = [(rnd.uniform(0, math.tau), rnd.uniform(0.15, 1.0), rnd.uniform(9.0, 13.0), rnd.uniform(0.0, 0.25)) for _ in range(28)]

    def capa(k, fuerza, giro, f_):
        s, a = nuevo(), nuevo()
        for ang, uu, r, t0 in puffs:
            kk = max(0.0, min(1.0, (k - t0) / (1 - t0)))
            if kk <= 0:
                continue
            an = ang + giro * (0.5 + uu)
            fg.bocanada_ceniza(a if math.sin(an) > -0.2 else s, CX + math.cos(an) * R * uu * kk, CY + math.sin(an) * R * uu * kk * 0.85 - 4, r * (0.5 + 0.5 * kk), fuerza)
        if fuerza > 0.3:
            fg.chispas(a, CX, CY, 8, f_, 17, 20.0, R * 0.8)
        return s, a
    sale = [capa(1.0 - (1.0 - (i + 1) / 6.0) ** 2, 1.0, 0.0, i) for i in range(6)]
    dura = [capa(1.0, 1.0, i / 8.0 * 0.4, i * 10 / 8.0) for i in range(8)]
    vete = [capa(1.0, 1.0 - (i + 1) / 8.0, 0.4, i) for i in range(8)]
    return sale, dura, vete


sa, du, ve = nube_que_queda()
d['nubec_50_sale'] = ho.guardar_efecto(LA, 'nubec_50_sale', [sa], [(CX, CY)], 12.0)
d['nubec_50_dura'] = ho.guardar_efecto(LA, 'nubec_50_dura', [du], [(CX, CY)], 8.0, True)
d['nubec_50_vete'] = ho.guardar_efecto(LA, 'nubec_50_vete', [ve], [(CX, CY)], 10.0)


# --- AFILARSE (obsidiana): el brillo de las aristas lo trae su gesto; aqui los dos destellos de filo sobre el cuerpo ---
def afilar():
    marcos = []
    for f_ in range(11):
        s, a = nuevo(), nuevo()
        if f_ in (3, 4):
            estrella(a, CX + 8, CY - 26 + f_, (9, 12)[f_ - 3], fg.OBSIDIANA)
        if f_ in (8, 9):
            estrella(a, CX - 10, CY - 22 + f_ - 5, (9, 12)[f_ - 8], fg.OBSIDIANA)
        marcos.append((s, a))
    return [marcos]


d['afilar'] = ho.guardar_efecto(LA, 'afilar', afilar(), [(CX, CY)], 12.0)
ho.sumar(LA, d)
