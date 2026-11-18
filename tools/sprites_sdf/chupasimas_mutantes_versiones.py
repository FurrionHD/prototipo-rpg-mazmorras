# ============================================================
#  chupasimas_mutantes_versiones.py -- LOS MUTANTES DE LA CHUPASIMAS, propuestas en QUIETO (17/11/2026). Arbol de dos ramas
#  y final: Chupasimas -> COAGULO (costra de sangre) / SANGUIJUELA VIDRIADA (bebe mana, rayo) -> MADRE DE LAS SIMAS.
#  Lo que pidio el jefe:
#    COAGULO   "de base casi como la normal pero con algun detalle"; la COSTRA = postillas casi curadas que se agrietan
#              (solo con la costra puesta; sin ella, a lo mucho restos)
#              A sin costra   algo mas llena y oscura, con restos de postilla
#              B costra       postillas GRANDES agrietadas por el lomo (las grietas enseñan la carne)
#              (1a vuelta: eligio A sin costra y B con costra; la C, postillas sueltas, fuera)
#    VIDRIADA  "de cristal DE VERDAD: angulos rectos, formas geometricas, mas gordita" (2a vuelta: el tubo translucido de
#              la primera no le valio). El cuerpo es una CADENA DE PRISMAS TALLADOS y el mana se ve dentro
#              A diamante     tramos de seccion de rombo (cuarzo)
#              B octogono     prisma de ocho caras, la de arriba plana
#              C gemas        bloques sueltos apilados y girados
#    MADRE     "como la de cristal pero mas rojiza, porque se pone costras tambien": las mismas tres tallas en rojo
#              A diamante rosa (sangre y mana dentro), B octogono granate con postillas, C gemas grande
#  Nada en el suelo. Uso: python tools/sprites_sdf/chupasimas_mutantes_versiones.py
#    -> tools/salida/sdf/chupasimas_mutantes_versiones.png (y al escritorio, ataques_mapa/enemigos/prueba_3d/mutantes)
# ============================================================
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import sdf_comun
import chupasimas_sdf as base

V = np.array

MAT = dict(base.MAT)
MAT.update({
    # Coagulo: el granate de siempre, algo mas oscuro y lleno; la costra, la postilla seca casi curada.
    'piel_c':   [(0.26, 0.08, 0.12), (0.44, 0.15, 0.22), (0.58, 0.26, 0.32), (0.90, 0.72, 0.76)],
    'carne':    [(0.50, 0.08, 0.10), (0.72, 0.16, 0.16), (0.88, 0.32, 0.28)],
    'costra':   [(0.16, 0.07, 0.06), (0.30, 0.13, 0.10), (0.44, 0.22, 0.16)],
    # Vidriada: el cristal (translucido) y el mana de dentro (brilla).
    # El cristal casi INCOLORO (un gris verdoso de vidrio) y el mana de un azul FUERTE: si los dos son azul claro, el
    # nucleo no se distingue del cuerpo (lo vi en la primera lamina).
    'vidrio':   [(0.50, 0.58, 0.60), (0.72, 0.80, 0.80), (0.88, 0.94, 0.93), (1.00, 1.00, 1.00)],
    'aro_v':    [(0.44, 0.52, 0.55), (0.60, 0.68, 0.70), (0.76, 0.84, 0.85)],
    'mana':     [(0.08, 0.30, 0.95), (0.16, 0.46, 1.00), (0.42, 0.72, 1.00)],
    # Madre: el cristal rojizo y la sangre de dentro.
    'vidrio_r': [(0.56, 0.22, 0.28), (0.80, 0.42, 0.46), (0.94, 0.68, 0.70), (1.00, 0.96, 0.96)],
    'vidrio_g': [(0.36, 0.08, 0.14), (0.56, 0.16, 0.24), (0.74, 0.32, 0.38), (0.98, 0.86, 0.88)],
    'aro_r':    [(0.48, 0.18, 0.22), (0.64, 0.30, 0.34), (0.80, 0.48, 0.50)],
    'sangre':   [(0.52, 0.04, 0.08), (0.74, 0.10, 0.14), (0.92, 0.26, 0.26)],
})

TRANSLUCIDOS = ('vidrio', 'aro_v', 'vidrio_r', 'vidrio_g', 'aro_r')


def modelo(escala=2.0):
    mo = Modelo(escala, (104, 104), (52, 52), MAT, (0.12, 0.05, 0.07), suaves=('cuerpo',), brillan=('mana',),
                corta_suelo=True, especular=('piel', 'piel_c', 'vidrio', 'vidrio_r', 'vidrio_g'), umbral_especular=0.88,
                translucidos=TRANSLUCIDOS, alfa=0.74)
    # EL CRISTAL TALLADO, bastante opaco: si deja ver demasiado, todas las caras salen del tono de lo de dentro y no se
    # leen las facetas. PERO donde detras esta el MANA (claros_dentro), casi transparente: si no, el nucleo no se ve.
    # (No con 'alfa_mat': ese va DESPUES y pisaba lo del mana -- el nucleo desaparecia por gordo que fuera.)
    mo.alfa_dentro = 0.74
    mo.claros_dentro = ('mana',)
    mo.alfa_claro = 0.25
    return mo


# ------------------------------------------------------------
#  EL CUERPO, con lo que cambia en cada version (el del normal, chupasimas_sdf.escena, con perillas)
# ------------------------------------------------------------
def _radio(u, k_r):
    return base._radio(u) * k_r


def _traza(u, k_l, k_r):
    p = base.POSE()
    q = base._traza(u, p)
    # Mas larga: se estira desde el centro; mas gorda: sube lo que sube el radio.
    return V((q[0], q[1] * k_l, q[2] + (k_r - 1.0) * base._radio(u)))


def _marco(u, k_l, k_r):
    """El marco del cuerpo en 'u': d (a lo largo, hacia la boca), lado y arriba."""
    a = _traza(min(u + 0.01, 1.0), k_l, k_r)
    b = _traza(max(u - 0.01, 0.0), k_l, k_r)
    d = a - b; d /= np.linalg.norm(d)
    lado = np.cross(d, V((0.0, 0.0, 1.0))); lado /= max(np.linalg.norm(lado), 1e-6)
    arriba = np.cross(lado, d)
    return d, lado, arriba


def cuerpo(add, piel, anillo, k_l=1.0, k_r=1.0, anillos=True):
    N = base.N
    us = [i / (N - 1) for i in range(N)]
    pts = [_traza(u, k_l, k_r) for u in us]
    for i in range(N - 1):
        base._cono(add, pts[i], pts[i + 1], _radio(us[i], k_r), _radio(us[i + 1], k_r), piel, 0.8)
    if anillos:
        for k in range(2, 17):
            u = k / 18
            c = _traza(u, k_l, k_r)
            d, _l, _a = _marco(u, k_l, k_r)
            r = _radio(u, k_r) + 0.12
            def aro(P, c=c, d=d, r=r):
                q = P - c
                a = q @ d
                rad = np.linalg.norm(q - np.outer(a, d), axis=1)
                return np.sqrt((rad - r) ** 2 + a ** 2) - 0.32
            add(aro, anillo, 0, 'anillo')
    # La ventosa de delante con su anillo de dientes (como la normal, cerrada).
    boca = pts[-1]; d = pts[-1] - pts[-2]; d /= np.linalg.norm(d)
    cen = boca + d * 0.6
    base._elip(add, cen, (1.9 * k_r,) * 3, piel, 0.5)
    base._elip(add, cen + d * 1.3 * k_r, (1.3 * k_r,) * 3, 'boca', 0, 'boca')
    a1 = np.cross(d, V((0.0, 0.0, 1.0))); a1 /= max(np.linalg.norm(a1), 1e-6); a2 = np.cross(d, a1)
    for k in range(8):
        ang = k / 8 * 2 * math.pi
        rr = a1 * math.cos(ang) + a2 * math.sin(ang)
        base._cono(add, cen + d * 1.4 * k_r + rr * 1.3 * k_r, cen + d * 1.1 * k_r + rr * 0.6 * k_r, 0.3, 0.12, 'diente', 0,
                   'diente')
    cola = pts[0]; dc = pts[0] - pts[1]; dc /= np.linalg.norm(dc)
    base._elip(add, cola + dc * 0.6 + V((0, 0, -0.6)), (2.2 * k_r, 2.2 * k_r, 0.8), piel, 0.6)


def postillas(add, k_l, k_r, desde, hasta, n_largo, n_vuelta, tam, abre, semilla, levanta=0.0, prob=1.0, vuelta=1.6,
              k_sup=1.0):
    """LAS POSTILLAS: placas planas pegadas a la piel por el lomo, con GRIETAS entre ellas ('abre' = lo que se separan:
    por ahi se ve la carne). 'levanta' = lo que despegan los bordes (casi curadas). 'prob' < 1 = sueltas, no todas."""
    rnd = random.Random(semilla)
    for i in range(n_largo):
        u = desde + (hasta - desde) * (i + 0.5) / n_largo
        d, lado, arriba = _marco(u, k_l, k_r)
        r = _radio(u, k_r) * k_sup
        c0 = _traza(u, k_l, k_r)
        for j in range(n_vuelta):
            if rnd.random() > prob:
                continue
            ang = (j + 0.5) / n_vuelta * vuelta - vuelta / 2 + rnd.uniform(-0.12, 0.12)   # repartidas por arriba
            nrm = arriba * math.cos(ang) + lado * math.sin(ang)
            tang = np.cross(nrm, d); tang /= max(np.linalg.norm(tang), 1e-6)
            c = c0 + nrm * (r + 0.05 + levanta * rnd.uniform(0.0, 0.5)) + d * rnd.uniform(-0.3, 0.3)
            M = np.stack([d, tang, nrm], axis=1)
            larg = tam * rnd.uniform(0.8, 1.15) * (1.0 - abre)
            anch = tam * 0.85 * rnd.uniform(0.8, 1.1) * (1.0 - abre)
            add(lambda P, c=c, M=M, rad=V((larg, anch, 0.42)): sd_elipsoide_girado(P, c, M, rad), 'costra', 0, 'costra')
            # LA CARNE de la grieta, debajo: una mancha roja plana que solo asoma entre placas.
            add(lambda P, c=c - nrm * 0.25, M=M, rad=V((tam * 0.95, tam * 0.8, 0.22)): sd_elipsoide_girado(P, c, M, rad),
                'carne', 0, 'carne')


def nucleo(add, mat, k_l, k_r, grosor=0.42, desde=0.12, hasta=0.84):
    """Un tubo por DENTRO del cuerpo (el mana o la sangre), que se ve a traves del cristal."""
    us = [desde + (hasta - desde) * i / 9 for i in range(10)]
    pts = [_traza(u, k_l, k_r) for u in us]
    for i in range(len(pts) - 1):
        base._cono(add, pts[i], pts[i + 1], _radio(us[i], k_r) * grosor, _radio(us[i + 1], k_r) * grosor, mat, 0.6, 'nucleo')


def cuentas(add, mat, k_l, k_r, n, semilla, tam=0.45):
    """BURBUJAS de 'mat' sueltas por dentro del cuerpo."""
    rnd = random.Random(semilla)
    for i in range(n):
        u = 0.12 + 0.72 * (i + rnd.uniform(0.1, 0.9)) / n
        d, lado, arriba = _marco(u, k_l, k_r)
        r = _radio(u, k_r)
        c = _traza(u, k_l, k_r) + lado * rnd.uniform(-0.4, 0.4) * r + arriba * rnd.uniform(-0.2, 0.4) * r
        base._elip(add, c, (r * tam * rnd.uniform(0.75, 1.2),) * 3, mat, 0, 'cuenta%d' % i)


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def coagulo_a():
    e = Escena(base.huesos(None)); add = e.add
    cuerpo(add, 'piel_c', 'anillo', 1.0, 1.12)
    # Restos: tres o cuatro postillas sueltas y planas, sin grietas.
    postillas(add, 1.0, 1.12, 0.25, 0.75, 4, 3, 0.9, 0.0, 7, prob=0.35)
    return e.L


def coagulo_b():
    e = Escena(base.huesos(None)); add = e.add
    cuerpo(add, 'piel_c', 'anillo', 1.0, 1.12, anillos=False)
    postillas(add, 1.0, 1.12, 0.10, 0.86, 7, 5, 1.55, 0.14, 11, levanta=0.25, vuelta=2.4)
    return e.L


# ------------------------------------------------------------
#  EL CUERPO DE CRISTAL TALLADO (2a vuelta de la Vidriada y la Madre): prismas de caras planas y aristas vivas
# ------------------------------------------------------------
def _caja(add, c, ejes, medio, mat, grupo, red=0.06):
    add(lambda P, c=V(c, dtype=float), e=np.array(ejes, dtype=float), m=V(medio, dtype=float), red=red:
        sd_caja(P, c, e, m, red), mat, 0, grupo)


def _ejes(d, lado, arriba, giro):
    """Los ejes de un tramo: a lo largo 'd', y la seccion girada 'giro' radianes alrededor de 'd'."""
    l2 = lado * math.cos(giro) + arriba * math.sin(giro)
    a2 = -lado * math.sin(giro) + arriba * math.cos(giro)
    return [d, l2, a2]


def cuerpo_cristal(add, mat, k_l, k_r, talla, tramos=7, ancho=0.95, nucleo_mat=None, k_nuc=0.36):
    """La cadena de prismas. talla: 'diamante' (rombo), 'octo' (dos cajas, a 0 y a 45 grados) o 'gemas' (bloques sueltos
    girados a turnos). Cada tramo lleva el grosor de su sitio, asi que el perfil va A ESCALONES: tallado, no liso."""
    for i in range(tramos):
        u0 = 0.04 + 0.90 * i / tramos
        u1 = 0.04 + 0.90 * (i + 1) / tramos
        um = 0.5 * (u0 + u1)
        a = _traza(u0, k_l, k_r); b = _traza(u1, k_l, k_r)
        c = 0.5 * (a + b)
        d, lado, arriba = _marco(um, k_l, k_r)
        largo = np.linalg.norm(b - a)
        r = _radio(um, k_r) * ancho
        hueco = 0.12 if talla == 'gemas' else -0.15     # las gemas apenas se separan (sueltas flotaban); las demas se solapan
        medio_l = 0.5 * largo - hueco
        if talla == 'diamante':
            _caja(add, c, _ejes(d, lado, arriba, math.pi / 4), (medio_l, r * 0.82, r * 0.82), mat, 'cristal')
        elif talla == 'octo':
            _caja(add, c, _ejes(d, lado, arriba, 0.0), (medio_l, r * 0.86, r * 0.86), mat, 'cristal')
            _caja(add, c, _ejes(d, lado, arriba, math.pi / 4), (medio_l, r * 0.86, r * 0.86), mat, 'cristal')
        else:
            giro = (math.pi / 4) if i % 2 else 0.0
            _caja(add, c, _ejes(d, lado, arriba, giro), (medio_l, r * 0.84, r * 0.84), mat, 'cristal%d' % i)
        if nucleo_mat:
            _caja(add, c, _ejes(d, lado, arriba, math.pi / 4), (max(0.3, medio_l - 0.2), r * k_nuc, r * k_nuc),
                  nucleo_mat, 'nucleo', 0.1)
    # LA BOCA: un bloque tallado, con la ventosa (ocho dientes) por delante.
    ub = 0.97
    cb = _traza(ub, k_l, k_r)
    d, lado, arriba = _marco(ub, k_l, k_r)
    rb = 1.9 * k_r * 0.85
    _caja(add, cb, _ejes(d, lado, arriba, math.pi / 8), (1.1, rb, rb), mat, 'cristal')
    base._elip(add, cb + d * 1.2, (1.15 * k_r,) * 3, 'boca', 0, 'boca')
    for k in range(8):
        ang = k / 8 * 2 * math.pi
        rr = lado * math.cos(ang) + arriba * math.sin(ang)
        base._cono(add, cb + d * 1.3 + rr * 1.25 * k_r, cb + d * 1.0 + rr * 0.55 * k_r, 0.32, 0.1, 'diente', 0, 'diente')
    # LA COLA: una placa tallada que se agarra al suelo.
    cc = _traza(0.0, k_l, k_r)
    d, lado, arriba = _marco(0.02, k_l, k_r)
    _caja(add, cc - d * 0.8 + V((0, 0, -0.5)), _ejes(d, lado, V((0.0, 0.0, 1.0)), 0.0), (1.4, 2.0 * k_r * 0.8, 0.7), mat,
          'cristal')


def vidriada_a():
    e = Escena(base.huesos(None)); add = e.add
    cuerpo_cristal(add, 'vidrio', 1.0, 1.30, 'diamante', nucleo_mat='mana')
    return e.L


def vidriada_b():
    e = Escena(base.huesos(None)); add = e.add
    cuerpo_cristal(add, 'vidrio', 1.0, 1.25, 'octo', nucleo_mat='mana')
    return e.L


def vidriada_c():
    e = Escena(base.huesos(None)); add = e.add
    cuerpo_cristal(add, 'vidrio', 1.05, 1.30, 'gemas', tramos=6, nucleo_mat='mana', k_nuc=0.40)
    return e.L


def madre_a():
    e = Escena(base.huesos(None)); add = e.add
    cuerpo_cristal(add, 'vidrio_r', 1.05, 1.40, 'diamante', nucleo_mat='sangre', k_nuc=0.36)
    cuentas(add, 'mana', 1.05, 1.40, 4, 9, 0.22)
    return e.L


def madre_b():
    e = Escena(base.huesos(None)); add = e.add
    cuerpo_cristal(add, 'vidrio_g', 1.05, 1.40, 'octo', nucleo_mat='mana', k_nuc=0.34)
    postillas(add, 1.05, 1.40, 0.14, 0.62, 5, 3, 1.3, 0.14, 41, levanta=0.2, vuelta=1.2, k_sup=0.80)
    return e.L


def madre_c():
    e = Escena(base.huesos(None)); add = e.add
    cuerpo_cristal(add, 'vidrio_r', 1.15, 1.55, 'gemas', tramos=6, nucleo_mat='sangre', k_nuc=0.38)
    cuentas(add, 'mana', 1.15, 1.55, 6, 13, 0.2)
    return e.L


if __name__ == '__main__':
    getattr(sdf_comun, '_prioridad_baja', lambda: None)()
    mo = modelo()
    filas = [
        ('NORMAL (hoy)', None),
        ('COAGULO A sin costra', coagulo_a()),
        ('COAGULO B postillas grandes', coagulo_b()),
        ('VIDRIADA A diamante', vidriada_a()),
        ('VIDRIADA B octogono', vidriada_b()),
        ('VIDRIADA C gemas', vidriada_c()),
        ('MADRE A diamante rosa', madre_a()),
        ('MADRE B octogono granate', madre_b()),
        ('MADRE C gemas grande', madre_c()),
    ]
    W = H = 104
    ESC = 4
    MARGEN = 230
    tiras = []
    for nombre, L in filas:
        fotos = []
        for d in range(5):
            if L is None:
                im = render(base.MODELO, base.escena(base.POSE()), d)
            else:
                im = render(mo, L, d)
            fotos.append(im)
        cajas = [f.getbbox() for f in fotos]
        y0 = max(0, min(c[1] for c in cajas) - 3)
        y1 = min(H, max(c[3] for c in cajas) + 3)
        tiras.append((nombre, fotos, y0, y1))
        print(nombre, flush=True)
    x0 = max(0, min(f.getbbox()[0] for t in tiras for f in t[1]) - 3)
    x1 = min(W, max(f.getbbox()[2] for t in tiras for f in t[1]) + 3)
    ancho = x1 - x0
    alto_total = sum((t[3] - t[2]) * ESC for t in tiras)
    hoja = Image.new('RGB', (MARGEN + ancho * 5 * ESC, alto_total), (40, 42, 50))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, fotos, y0, y1 in tiras:
        dib.text((10, y + (y1 - y0) * ESC // 2), nombre, fill=(235, 235, 235))
        for d, im in enumerate(fotos):
            c = im.crop((x0, y0, x1, y1)).resize((ancho * ESC, (y1 - y0) * ESC), Image.NEAREST)
            hoja.paste(c, (MARGEN + d * ancho * ESC, y), c)
        y += (y1 - y0) * ESC
        dib.line((0, y - 1, hoja.size[0], y - 1), fill=(60, 62, 72))
    os.makedirs('tools/salida/sdf', exist_ok=True)
    hoja.save('tools/salida/sdf/chupasimas_mutantes_versiones.png')
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    hoja.save(os.path.join(esc, 'chupasimas_mutantes_versiones.png'))
    print('ok', hoja.size)
