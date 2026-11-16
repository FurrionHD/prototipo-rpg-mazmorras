# ============================================================
#  aberracion_mutantes_versiones.py -- OPCIONES DE CUERPO PARA LOS MUTANTES DE LA ABERRACION (13/11/2026). Los mutantes
#  son los del SET DE ARMADURA MAGICO (memoria siguiente-mutante-set-magico): la bestia que se vuelve maga-tanque. El jefe
#  decide el arbol y el elemento MIRANDO ESTOS DIBUJOS. Regla: CAMBIAR EL CUERPO ENTERO (silueta, postura), no pegar
#  adornos a la masa de siempre, y sin charcos en el sprite.
#    A columna   erguida: una VELA de carne alta, el ojo arriba del todo, los tentaculos como un faldon
#    B racimo    la masa REVENTADA DE OJOS: uno grande y un racimo de pequeños que brillan
#    C membrana  envuelta en una MEMBRANA translucida con venas que brillan (el escudo del set hecho carne)
#    D corona    los tentaculos SUBEN en corona alrededor del ojo, con las puntas encendidas (lanzando)
#    E medusa    FLOTA: campana de carne en el aire y los tentaculos colgando hasta el suelo
#    F cerebro   la masa es un CEREBRO al aire con los pliegues que brillan; el ojo abajo, delante
#    G fauces    la masa entera es una BOCA vertical abierta y el ojo mira desde DENTRO
#    H concha    lleva encima una CONCHA en espiral de hueso; el ojo sale en un pedunculo
#  Solo QUIETAS, las cinco direcciones. Uso: python tools/sprites_sdf/aberracion_mutantes_versiones.py
#    -> tools/salida/sdf/aberracion_mutantes_versiones.png
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import aberracion_sdf as ab

V = np.array
_elip, _cono, _unit = ab._elip, ab._cono, ab._unit


def tonos(c, k=(0.62, 0.82, 1.0, 1.25)):
    return [tuple(min(1.0, v * f) for v in c) for f in k]


# Los de la base, y los nuevos: RUNA = lo que brilla (la magia que lleva dentro).
BASE = dict(ab.MAT)
PALETAS = {
    'morada': {},
    'noche': {'carne': tonos((0.20, 0.10, 0.26)), 'tent': tonos((0.15, 0.07, 0.20)),
              'vena': tonos((0.85, 0.35, 0.95))[:3], 'iris': tonos((0.85, 0.35, 0.95))[:3]},
    'palida': {'carne': tonos((0.62, 0.52, 0.66)), 'tent': tonos((0.50, 0.38, 0.55)),
               'vena': tonos((0.55, 0.85, 1.0))[:3], 'iris': tonos((0.55, 0.85, 1.0))[:3]},
}
EXTRA = {
    'runa': tonos((0.95, 0.45, 1.0))[:3],
    'runa_c': tonos((0.55, 0.90, 1.0))[:3],
    'membrana': tonos((0.80, 0.62, 0.92)),
    'hueso': tonos((0.82, 0.76, 0.66)),
    'hueso_o': tonos((0.55, 0.48, 0.42))[:3],
    'pliegue': tonos((0.86, 0.48, 0.70)),
}


def modelo(paleta, brillan=('pupila', 'runa', 'runa_c'), translucidos=(), esc=1.8, lado=150, pies=(75, 92)):
    mat = dict(BASE); mat.update(EXTRA); mat.update(PALETAS[paleta])
    return Modelo(esc, (lado, lado), pies, mat, (0.12, 0.04, 0.12), suaves=('cuerpo',), brillan=brillan,
                  corta_suelo=True, especular=('carne', 'tent', 'globo', 'membrana'), umbral_especular=0.90,
                  translucidos=translucidos, alfa=0.55)


# ------------------------------------------------------------
#  PIEZAS COMUNES
# ------------------------------------------------------------
def ojo(add, c, r=1.0, mira=(0.0, 1.0, 0.0), iris='iris', cuenca=True):
    """Globo, iris y pupila rasgada que sobresalen hacia 'mira' (de perfil tiene que mirar a donde mira)."""
    c = V(c, dtype=float); m = _unit(V(mira, dtype=float))
    _elip(add, c, (3.3 * r, 2.7 * r, 3.2 * r), 'globo', 0, 'ojo')
    _elip(add, c + m * 1.65 * r, (1.9 * r, 1.3 * r, 1.85 * r), iris, 0, 'ojo')
    _elip(add, c + m * 2.5 * r, (0.55 * r, 0.6 * r, 1.35 * r), 'pupila', 0, 'ojo')
    if cuenca:
        _elip(add, c - m * 1.8 * r + V((0, 0, 1.2 * r)), (3.7 * r, 2.4 * r, 2.3 * r), 'carne', 1.2)


def ojito(add, c, r, mira):
    c = V(c, dtype=float); m = _unit(V(mira, dtype=float))
    _elip(add, c, (r, r, r), 'globo', 0, 'ojo')
    _elip(add, c + m * r * 0.62, (r * 0.62, r * 0.62, r * 0.62), 'runa', 0, 'ojo')
    _elip(add, c + m * r * 0.95, (r * 0.22, r * 0.22, r * 0.45), 'pupila', 0, 'ojo')
    _elip(add, c - m * r * 0.4, (r * 1.25, r * 1.25, r * 1.1), 'carne', 0.6)


def fauces(add, bo, ancho=2.5, abre=0.6, alto=1.0, mat='fauces'):
    bo = V(bo, dtype=float)
    ab_ = 0.6 + 2.0 * abre
    _elip(add, bo + V((0.0, 0.4, 0.0)), (ancho, 1.4, (0.7 + ab_ * 0.8) * alto), mat, 0, 'boca')
    for j in range(5):
        x = (-1.9 + 0.95 * j) * ancho / 2.5
        for sz in (1, -1):
            c = bo + V((x, 1.5 - 0.25 * abs(x), sz * (0.55 + ab_ * 0.75) * alto))
            _cono(add, c, c - V((0.0, 0.0, sz * 0.95)), 0.45, 0.1, 'diente', 0, 'boca')


def tentaculo(add, nace, fuera, modo='cae', n=11, paso=1.15, r0=2.3, r1=1.0, i=0, punta=None, mat='tent'):
    """El de la base, con MODOS: 'cae' (al suelo y se tiende), 'sube' (se alza y se abre arriba, en corona) y 'cuelga'
    (de algo que flota: cae recto hasta el suelo y se arrastra el final). 'punta' = material que brilla en el extremo."""
    fuera = _unit(V((fuera[0], fuera[1], 0.0)))
    lado = V((fuera[1], -fuera[0], 0.0))
    pt = V(nace, dtype=float); rr = r0
    enrosca = (0.9, -0.7, 0.8, -0.9, 0.7, -0.8, 0.6, -0.6)[i % 8]
    caida = {'cae': 0.95, 'sube': -1.25, 'cuelga': 1.45}[modo]
    for k in range(n):
        u = k / (n - 1)
        if modo == 'cae':
            caida = max(0.0, caida - 0.19) if k < n - 2 else min(caida, -0.22)
        elif modo == 'sube':
            caida = min(0.6, caida + 0.16)          # se va abriendo hacia fuera y la punta se dobla
        else:
            caida = 1.45 if pt[2] > 2.5 else max(0.1, caida - 0.5)
        onda = enrosca * u * u + 0.45 * math.sin(i * 1.9 + k * 0.7) * u
        d = _unit(fuera * math.cos(caida) + V((0.0, 0.0, -math.sin(caida))) + lado * onda * (0.5 if modo == 'cuelga' else 1))
        q = pt + d * paso
        q[2] = max(q[2], r1 * 0.9 + (rr - r1) * 0.55)
        rb = r0 + (r1 - r0) * min(1.0, (k + 1) / (n - 1))
        _cono(add, pt, q, rr, rb, mat, 1.2 if k < 2 else 0.5)
        if 3 <= k <= 9 and k % 2 == 1 and modo != 'sube':
            _elip(add, q - V((0.0, 0.0, rb * 0.62)), (rb * 0.55, rb * 0.55, rb * 0.42), 'ventosa', 0, 'ventosa')
        pt = q; rr = rb
    if punta:
        _elip(add, pt, (r1 * 1.3, r1 * 1.3, r1 * 1.3), punta, 0, 'runa')


def corro(add, nn, r, z, modo='cae', desfase=30.0, salta_frente=True, **kw):
    for i in range(nn):
        ang = math.radians(desfase + 360.0 / nn * i + (7.0, -5.0, 9.0, -8.0, 4.0, -6.0, 5.0, -7.0)[i % 8])
        f = (math.sin(ang), math.cos(ang))
        if salta_frente and f[1] > 0.93:
            continue
        tentaculo(add, (f[0] * r, f[1] * r, z), f, modo, i=i, **kw)


def escena_de(fn):
    e = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))})
    fn(e)
    return e.L


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def v_base(e):
    return None


def v_columna(e):
    add = e.add
    # Una vela de carne: tres masas apiladas que adelgazan, ligeramente torcida (no es un totem).
    _elip(add, (0.0, 0.0, 3.0), (6.4, 6.0, 3.6), 'carne', 0)
    _elip(add, (0.6, -0.4, 8.0), (4.8, 4.4, 4.2), 'carne', 2.6)
    _elip(add, (1.0, -0.2, 13.0), (3.8, 3.6, 3.6), 'carne', 2.6)
    _elip(add, (0.4, 0.2, 17.0), (3.4, 3.2, 3.0), 'carne', 2.4)
    for a, b in (((0.0, -3.0, 16.0), (1.8, -4.4, 6.0)), ((-2.6, 0.0, 15.0), (-4.2, -1.0, 4.0))):
        _cono(add, a, b, 0.4, 0.3, 'vena', 0, 'vena')
    ojo(add, (0.4, 3.0, 18.4), 0.9)
    fauces(add, (0.8, 4.0, 9.0), 1.9, 0.3)
    corro(add, 7, 5.2, 2.8, 'cae', n=9, r0=2.0, desfase=0.0, salta_frente=False)


def v_racimo(e):
    add = e.add
    _elip(add, (0.0, 0.0, 5.0), (7.6, 7.0, 5.0), 'carne', 0)
    _elip(add, (0.0, -0.4, 1.8), (8.4, 7.8, 2.2), 'carne', 2.5)
    _elip(add, (-1.0, -3.0, 9.4), (5.0, 4.6, 3.8), 'carne', 3.0)
    ojo(add, (0.0, 5.2, 8.0), 0.9)
    pequenos = [((4.6, 3.2, 9.0), 1.3), ((-4.4, 3.4, 9.6), 1.2), ((2.6, -1.0, 12.4), 1.4), ((-3.2, -3.6, 11.8), 1.1),
                ((5.8, -2.2, 7.2), 1.0), ((-6.2, 0.2, 6.6), 1.2), ((0.0, -6.4, 7.6), 1.1), ((-1.0, 1.0, 13.2), 1.0),
                ((3.4, 5.4, 4.0), 0.8), ((-3.6, 5.6, 4.6), 0.8)]
    for c, r in pequenos:
        ojito(add, c, r, (c[0] * 0.5, c[1] + 2.0, c[2] - 5.0))
    corro(add, 6, 4.8, 3.6, 'cae', n=8, r0=2.0)


def v_membrana(e):
    add = e.add
    # La masa de siempre, mas baja, dentro de una membrana (casquete translucido) que la cubre como un capullo.
    _elip(add, (0.0, 0.0, 4.4), (6.2, 5.8, 4.4), 'carne', 0)
    _elip(add, (0.0, -0.4, 1.6), (7.0, 6.6, 2.0), 'carne', 2.5)
    ojo(add, (0.0, 4.4, 7.2), 0.85)
    fauces(add, (0.0, 5.2, 3.4), 2.0, 0.2)
    corro(add, 6, 5.0, 3.0, 'cae', n=10)
    add(lambda P: np.maximum(sd_elipsoide(P, V((0.0, -0.6, 6.0)), V((9.6, 9.4, 9.0))),
                             -sd_elipsoide(P, V((0.0, -0.6, 6.0)), V((9.0, 8.8, 8.4)))), 'membrana', 0, 'membrana')
    # Las VENAS que brillan por la membrana (meridianos).
    for k in range(6):
        a = math.radians(15 + 60 * k)
        pts = [V((9.4 * math.sin(a) * math.cos(t), -0.6 + 9.2 * math.cos(a) * math.cos(t), 6.0 + 8.8 * math.sin(t)))
               for t in np.linspace(-0.25, 1.35, 6)]
        for p0, p1 in zip(pts, pts[1:]):
            _cono(add, p0, p1, 0.32, 0.32, 'runa', 0, 'runa')


def v_corona(e):
    add = e.add
    _elip(add, (0.0, 0.0, 4.6), (6.0, 5.6, 4.8), 'carne', 0)
    _elip(add, (0.0, -0.4, 1.8), (7.2, 6.8, 2.2), 'carne', 2.5)
    _elip(add, (0.0, 0.0, 9.0), (4.6, 4.4, 3.4), 'carne', 2.6)
    ojo(add, (0.0, 3.6, 10.4), 1.0)
    fauces(add, (0.0, 5.0, 4.0), 2.0, 0.4)
    corro(add, 6, 3.4, 10.0, 'sube', n=9, r0=1.9, r1=0.8, paso=1.2, punta='runa', desfase=0.0)
    corro(add, 5, 5.6, 2.4, 'cae', n=6, r0=1.8, desfase=36.0)


def v_medusa(e):
    add = e.add
    z = 12.0
    e.sombra(0.0, 0.0, 8.0, 7.0, 0.30)
    add(lambda P: sd_casquete(P, V((0.0, 0.0, z)), np.eye(3), V((0.0, 0.0, 0.0)), V((8.0, 7.6, 6.4)), -1.2, 0.03),
        'carne', 0, 'cuerpo')
    _elip(add, (0.0, -1.0, z + 4.6), (4.6, 4.2, 2.8), 'carne', 2.0)
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        _elip(add, (6.6 * math.sin(a), 6.2 * math.cos(a), z - 0.6), (1.4, 1.4, 0.7), 'runa', 0, 'runa')
    ojo(add, (0.0, 6.4, z + 1.6), 0.85)
    corro(add, 8, 5.0, z - 1.0, 'cuelga', n=12, paso=1.25, r0=1.6, r1=0.7, desfase=22.5, salta_frente=False)


def v_cerebro(e):
    add = e.add
    _elip(add, (0.0, 0.0, 3.4), (7.4, 7.0, 3.8), 'carne', 0)
    _elip(add, (0.0, -1.0, 8.8), (6.4, 6.6, 5.2), 'pliegue', 1.2)
    # Los PLIEGUES: toros y cordones encima del cerebro, y la cisura del medio.
    for j, (x, r) in enumerate(((-3.6, 2.0), (-1.8, 2.6), (1.8, 2.6), (3.6, 2.0))):
        for k, y in enumerate((-5.0, -2.4, 0.4, 2.8)):
            zz = 8.8 + 5.0 * math.sqrt(max(0.0, 1 - (x / 6.6) ** 2 - ((y + 1.0) / 6.8) ** 2))
            _elip(add, (x, y, zz - 0.4), (1.2, 1.5, 0.9), 'pliegue', 0.4)
    _cono(add, (0.0, -6.0, 12.0), (0.0, 3.6, 13.0), 0.5, 0.5, 'runa', 0, 'runa')
    for a, b in (((-4.0, -4.0, 11.6), (-2.0, 2.8, 12.6)), ((4.0, -4.0, 11.6), (2.0, 2.8, 12.6))):
        _cono(add, a, b, 0.32, 0.32, 'runa', 0, 'runa')
    ojo(add, (0.0, 6.2, 4.6), 0.75)
    corro(add, 6, 5.6, 2.4, 'cae', n=10, r0=2.0)


def v_fauces(e):
    add = e.add
    # La masa ES la boca: dos labios gruesos verticales abiertos, con dientes por dentro, y el ojo dentro mirando.
    _elip(add, (0.0, -1.6, 5.4), (7.0, 6.0, 5.6), 'carne', 0)
    _elip(add, (0.0, -0.6, 1.8), (8.0, 7.6, 2.2), 'carne', 2.5)
    for sx in (1, -1):
        _elip(add, (sx * 3.6, 2.6, 6.4), (2.4, 3.6, 6.6), 'carne', 2.2)
    _elip(add, (0.0, 3.2, 6.4), (2.6, 2.2, 6.0), 'fauces', 0, 'boca')
    for k in range(6):
        zz = 2.0 + 1.8 * k
        for sx in (1, -1):
            c = V((sx * 2.2, 4.6, zz))
            _cono(add, c, c - V((sx * 1.2, 0.0, 0.0)), 0.5, 0.1, 'diente', 0, 'boca')
    ojo(add, (0.0, 2.2, 7.0), 0.75, cuenca=False)
    corro(add, 6, 5.0, 3.2, 'cae', n=11)


def v_concha(e):
    add = e.add
    _elip(add, (0.0, 1.0, 3.0), (6.4, 7.8, 3.2), 'carne', 0)
    _elip(add, (0.0, 1.4, 1.2), (7.2, 8.6, 1.6), 'carne', 2.0)
    # LA CONCHA: espiral de hueso, toros que encogen y suben (vista de lado, como un nautilo), con un filo oscuro.
    cx, cz = 0.0, 9.0
    for k in range(7):
        t = k / 6.0
        r = 6.4 * (1.0 - 0.72 * t)
        c = V((cx, -2.2 + 3.0 * t, cz + 3.4 * t))
        add(lambda P, c=c, r=r, g=1.9 * (1 - 0.55 * t): sd_toro_y(P, c, r, g, 1.0), 'hueso', 0.0, 'concha')
    _elip(add, (0.0, -2.2, 9.0), (6.0, 1.6, 6.0), 'hueso_o', 0, 'concha')
    for k in range(5):
        a = math.radians(-40 + 40 * k)
        _elip(add, (4.8 * math.cos(a), -0.4, 9.0 + 4.8 * math.sin(a)), (0.7, 0.9, 0.7), 'runa', 0, 'runa')
    # El PEDUNCULO del ojo, delante.
    _cono(add, (0.0, 6.0, 3.0), (0.0, 8.0, 8.2), 1.8, 1.2, 'carne', 1.0)
    ojo(add, (0.0, 8.6, 9.6), 0.75)
    fauces(add, (0.0, 8.8, 2.4), 1.8, 0.3, 0.8)
    corro(add, 6, 5.2, 2.6, 'cae', n=9, r0=1.9, desfase=30.0)


VERSIONES = [
    ('base', None, 'morada', {}),
    ('A columna', v_columna, 'noche', {}),
    ('B racimo', v_racimo, 'morada', {}),
    ('C membrana', v_membrana, 'morada', dict(translucidos=('membrana',))),
    ('D corona', v_corona, 'noche', {}),
    ('E medusa', v_medusa, 'palida', {}),
    ('F cerebro', v_cerebro, 'morada', {}),
    ('G fauces', v_fauces, 'noche', {}),
    ('H concha', v_concha, 'palida', {}),
]


if __name__ == '__main__':
    solo = sys.argv[1:]
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, fn, pal, kw in VERSIONES:
        if solo and nombre.split()[0] not in solo:
            continue
        mo = modelo(pal, **kw)
        L = ab.escena(ab.POSE()) if fn is None else escena_de(fn)
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok', flush=True)
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 90, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (90 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    lam.save('tools/salida/sdf/aberracion_mutantes_versiones.png')
    print('tools/salida/sdf/aberracion_mutantes_versiones.png')
