# ============================================================
#  slime_rey_versiones.py -- el REY SLIME retocado y su MUTANTE, propuestas (07/10/2026). Solo QUIETOS, al lado del Rey
#  de hoy (rey280); el elegido pasa a slime_sdf.py como variante para animarlo.
#  Lo que pidio el jefe:
#    - RETOCAR EL REY: "no parece un rey de verdad", la corona se ve rara (cinco palitos sueltos con una bola), y es
#      "demasiado redondo", no tan bonito como los slimes normales. Dos maneras:
#        R1 CORONA DE GEL: cuerpo de PUDIN (la base mas ancha y blanda, la cupula algo mas baja) y una corona de verdad:
#           un ARO de su gel claro abrazando la coronilla con cinco puntas anchas, gemas en el aro.
#        R2 CORONA DE ORO: el mismo cuerpo con una corona de ORO, mas pequeña y LADEADA, gema roja delante.
#    - UNA SOLA LINEA de mutantes: TIRANO (1a) -> DESTRONADO (2a). NO mas alto ("no me termina de convencer").
#        TIRANO: corona de CRISTAL (los que se ha comido, irregulares) y un MANTO real por detras (con su ribete de
#           armiño); cejas fruncidas; dentro, el nucleo y los cristales.
#        DESTRONADO: igual de cristal, pero la corona ROTA (puntas partidas, un hueco, ladeada a punto de caerse) y el
#           manto ROTO, con rajas, agujeros y el bajo deshilachado; los ojos caidos.
#  Uso: python tools/sprites_sdf/slime_rey_versiones.py [salida.png]
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
os.environ['SLIME_VAR'] = 'rey280'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import slime_sdf as S

V = np.array
COLOR = '55b8ff'
ESC_REY = 2.80
ESC_TIRANO = ESC_REY * 1.1
ESC_DESTRONADO = ESC_TIRANO
LIENZO, PIES = S._lienzo(ESC_TIRANO * 1.25)


def _mats():
    m = S._materiales('rey', COLOR)
    c = S.hexc(COLOR)
    m['oro'] = [(0.50, 0.32, 0.06), (0.86, 0.64, 0.16), (1.0, 0.86, 0.42), (1.0, 0.97, 0.80)]
    m['gema_r'] = [(1.0, 0.25, 0.32)] * 3
    m['gema_v'] = [(0.40, 1.0, 0.55)] * 3
    # LA CORONA DE CRISTAL: el cian de los cristales del juego, opaco (va por fuera).
    m['cristal_f'] = [(0.22, 0.55, 0.72), (0.45, 0.88, 1.0), (0.80, 1.0, 1.0), (1.0, 1.0, 1.0)]
    # EL MANTO: terciopelo morado oscuro; EL ARMIÑO, blanco con sus motitas negras.
    m['manto'] = [(0.16, 0.05, 0.22), (0.32, 0.10, 0.42), (0.50, 0.22, 0.62)]
    m['manto_d'] = [(0.20, 0.10, 0.24), (0.34, 0.18, 0.40), (0.46, 0.30, 0.52)]
    m['armino'] = [(0.72, 0.74, 0.80), (0.92, 0.93, 0.96), (1.0, 1.0, 1.0)]
    m['mota'] = [(0.05, 0.05, 0.08)] * 3
    m['ceja'] = [S.osc(c, 0.70)] * 3
    return m


def modelo(escala):
    c = S.hexc(COLOR)
    mo = Modelo(escala, LIENZO, PIES, _mats(), S.osc(c, 0.58), suaves=('cuerpo',),
                brillan=('ojo', 'gema', 'gema_r', 'gema_v'), corta_suelo=True,
                especular=('gel', 'cuerno', 'cristal', 'oro', 'cristal_f'), umbral_especular=0.955,
                translucidos=('gel',), alfa=0.72)
    mo.alfa_dentro = 0.42
    mo.claros_dentro = ('cristal', 'nucleo')
    mo.alfa_claro = 0.45
    return mo


# ------------------------------------------------------------
#  EL CUERPO DE PUDIN: la bola de siempre algo mas baja, fundida con una base ancha y aplastada (asi asienta como un
#  flan en vez de rodar como una pelota). C/R = la cupula (donde van la corona y los ojos).
# ------------------------------------------------------------
CUP_C = V([0.0, 0.0, 8.0])
CUP_R = V([16.5, 16.5, 13.2])
BASE_C = V([0.0, 0.0, 2.4])
BASE_R = V([17.6, 17.6, 4.0])


def _cuerpo(e):
    e.add(lambda P: sd_elipsoide(P, CUP_C, CUP_R), 'gel', 0)
    e.add(lambda P: sd_elipsoide(P, BASE_C, BASE_R), 'gel', 3.0)
    return CUP_C, CUP_R


def _ojos(e, C, R, ceja=False, caidos=False):
    for s in (-1, 1):
        base, n = S._superficie((0.31 * s, 0.88, 0.30), C, R)
        c = base + n * 0.05
        rad = V([2.4, 3.0, 5.2])
        e.add(lambda P, c=c, rad=rad: np.maximum(sd_elipsoide(P, c, rad), sd_elipsoide(P, C, R) - 0.3), 'ojo', 0, 'ojo')
        if caidos:
            # EL PARPADO A MEDIAS: la mitad de arriba del ojo tapada de gel (cansado, hundido).
            zc = c[2] + 0.4
            e.add(lambda P, c=c, rad=rad * 1.06, zc=zc: np.maximum(np.maximum(sd_elipsoide(P, c, rad),
                  sd_elipsoide(P, C, R) - 0.45), zc - P[:, 2]), 'parpado', 0, 'parpado')
            raya = V([rad[0] * 1.1, rad[1] * 1.1, 0.55])
            e.add(lambda P, c=V([c[0], c[1], zc]), raya=raya: np.maximum(sd_elipsoide(P, c, raya),
                  sd_elipsoide(P, C, R) - 0.55), 'pestana', 0, 'pestana')
        if ceja:
            # LA CEJA FRUNCIDA: una raya de gel oscuro sobre el ojo, baja por dentro y alta por fuera.
            a, _ = S._superficie((0.12 * s, 0.86, 0.58), C, R)
            b, _ = S._superficie((0.50 * s, 0.80, 0.70), C, R)
            e.add(lambda P, a=a, b=b: sd_cono(P, a, b, 0.9, 0.7), 'ceja', 0, 'ceja')


def _nucleo(e, C, cristales=1):
    e.add(lambda P: sd_esfera(P, C + V([0.0, -3.0, -2.5]), 4.6), 'nucleo', 0, 'nucleo')
    rng = np.random.default_rng(11)
    for k in range(cristales):
        p = C + V([rng.uniform(-7, 7), rng.uniform(-6, 3), rng.uniform(-5, 4)])
        d = rng.normal(size=3); d /= np.linalg.norm(d)
        e.add(lambda P, a=p - d * 1.6, b=p + d * 1.6: sd_cono(P, a, b, 0.9, 0.3), 'cristal', 0, 'cristal')


def _altura_aro(C, R, z):
    """Radio horizontal de la cupula a la altura z."""
    return R[0] * math.sqrt(max(0.0, 1.0 - ((z - C[2]) / R[2]) ** 2))


def _aro(e, C, R, z0, z1, mat, grosor=0.9, giro=None):
    def f(P, giro=giro):
        Q = P if giro is None else giro(P)
        concha = np.abs(sd_elipsoide(Q, C, R + 0.6)) - grosor
        return np.maximum(concha, np.maximum(z0 - Q[:, 2], Q[:, 2] - z1))
    e.add(f, mat, 0, 'corona')


def _ladeo(ang, eje_y=0.0, centro=None):
    """Gira la corona alrededor del eje Y (de lado), con centro en la coronilla."""
    ca, sa = math.cos(ang), math.sin(ang)
    def g(P, centro=centro):
        Q = P - centro
        x = Q[:, 0] * ca + Q[:, 2] * sa
        z = -Q[:, 0] * sa + Q[:, 2] * ca
        return np.stack([x, Q[:, 1], z], axis=1) + centro
    return g


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def rey_hoy():
    return S.escena(S.POSE())


def _corona(e, mat, rr, z0, z1, puntas, g=None, gema=None, gema_aro=None, grosor=0.8):
    """Una corona de verdad: un ARO VERTICAL (cilindro hueco) sobre la coronilla y sus puntas. 'puntas' = lista de
    (angulo, ancho, alto, abre, forma) con forma 'tri' (lamina triangular) o 'cristal' (esquirla); g = giro (ladeada)."""
    G = (lambda P: P) if g is None else g
    def aro(P):
        Q = G(P)
        d = np.abs(np.linalg.norm(Q[:, :2], axis=1) - rr) - grosor
        return np.maximum(d, np.maximum(z0 - Q[:, 2], Q[:, 2] - z1))
    e.add(aro, mat, 0, 'corona')
    for a, ancho, alto, abre, forma in puntas:
        u = V([math.cos(a), math.sin(a), 0.0]); t = V([-math.sin(a), math.cos(a), 0.0])
        bc = V([0, 0, z1 - 0.4]) + u * rr
        if forma == 'tri':
            bl, br, tip = bc - t * ancho, bc + t * ancho, bc + u * abre + V([0, 0, alto])
            e.add(lambda P, a=bl, b=br, c=tip: sd_triangulo(G(P), a, b, c, 0.6), mat, 0, 'corona')
            if gema:
                e.add(lambda P, c=tip + V([0, 0, 0.6]): sd_esfera(G(P), c, 1.0), gema, 0, 'gema')
        else:
            # LA ESQUIRLA: un prisma que se afila (dos tramos); partida = alto pequeño y SIN afilar.
            partida = forma == 'partida'
            base = bc - V([0, 0, z1 - z0]) * 0.55
            dirc = u * abre + V([0, 0, 1.0]); dirc /= np.linalg.norm(dirc)
            m = base + dirc * alto * 0.65; b = base + dirc * alto
            rb = ancho * 0.8 if partida else 0.15
            e.add(lambda P, a=base, m=m, b=b, ra=ancho, rb=rb: np.minimum(sd_cono(G(P), a, m, ra, ra * 0.9),
                  sd_cono(G(P), m, b, ra * 0.9, rb)), mat, 0, 'corona')
    if gema_aro:
        mat_g, ang = gema_aro
        pf = V([math.cos(ang) * (rr + 0.9), math.sin(ang) * (rr + 0.9), (z0 + z1) / 2])
        e.add(lambda P, c=pf: sd_esfera(G(P), c, 1.3), mat_g, 0, 'gema')


def r1_gel():
    e = Escena(S.huesos(S.POSE()))
    C, R = _cuerpo(e)
    puntas = [(k / 5.0 * 2 * math.pi + math.pi * 0.5, 2.6, 5.5, 0.6, 'tri') for k in range(5)]
    _corona(e, 'cuerno', 8.6, 18.0, 22.0, puntas, gema='gema', gema_aro=('gema_r', math.pi * 0.5), grosor=1.0)
    _ojos(e, C, R)
    _nucleo(e, C)
    return e.L


def r2_oro():
    e = Escena(S.huesos(S.POSE()))
    C, R = _cuerpo(e)
    g = _ladeo(0.25, centro=V([0.0, 0.0, 20.0]))
    puntas = [(k / 5.0 * 2 * math.pi + math.pi * 0.5, 2.0, 4.6, 0.3, 'tri') for k in range(5)]
    _corona(e, 'oro', 7.2, 18.8, 21.8, puntas, g=g, gema='oro', gema_aro=('gema_r', math.pi * 0.5))
    _ojos(e, C, R)
    _nucleo(e, C)
    return e.L


def _corona_cristal(e, rota=False):
    """La corona de CRISTAL: aro de cristal y SIETE esquirlas irregulares (las que se ha comido), la de delante la mayor.
    Rota: ladeada a punto de caerse, puntas partidas y un hueco en el aro (donde faltan dos)."""
    rng = np.random.default_rng(4)
    g = _ladeo(0.42, centro=V([0.0, 0.0, 19.0])) if rota else None
    puntas = []
    for k in range(7):
        a = k / 7.0 * 2 * math.pi + math.pi * 0.5 + rng.uniform(-0.12, 0.12)
        alto = rng.uniform(5.0, 8.0) * (1.4 if k == 0 else 1.0)
        forma = 'cristal'
        if rota:
            if k in (2, 3):
                continue
            if k != 0:
                forma = 'partida'; alto *= rng.uniform(0.35, 0.55)
        puntas.append((a, rng.uniform(1.2, 1.7), alto, rng.uniform(0.15, 0.4), forma))
    _corona(e, 'cristal_f', 8.0, 18.0, 21.4, puntas, g=g, grosor=1.0)
    return g


def _manto(e, C, R, roto=False):
    """El manto, SOLO POR DETRAS: una capa pegada al cuerpo que cae del cuello al suelo, con el bajo y el cuello de
    armiño. Roto: el bajo deshilachado, agujeros, rajas y el armiño arrancado a trozos."""
    MC = V([0.0, -0.6, 8.0]); MR = V([17.6, 17.6, 14.4])
    rng = np.random.default_rng(9)
    agujeros = [(V([rng.uniform(-11, 11), -17.0, rng.uniform(5, 13)]), rng.uniform(1.5, 2.3)) for _ in range(4)]
    rajas = [rng.uniform(-2.6, -0.5) for _ in range(5)]
    def concha(P, extra=0.0):
        d = np.abs(sd_elipsoide(P, MC, MR + extra)) - 0.7
        d = np.maximum(d, P[:, 1] + 1.5 - P[:, 2] * 0.12)     # por detras (algo mas hacia delante abajo: cae)
        return np.maximum(d, P[:, 2] - 13.8)
    def tela(P):
        d = concha(P)
        if roto:
            ang = np.arctan2(P[:, 1], P[:, 0])
            bajo = 1.0 + 2.6 * np.abs(np.sin(ang * 7.0)) + 1.6 * np.abs(np.sin(ang * 17.0 + 1.0))
            d = np.maximum(d, bajo - P[:, 2])
            for c, r in agujeros:
                d = np.maximum(d, r - np.linalg.norm(P - c, axis=1))
            for a0 in rajas:
                cuña = np.abs(ang - a0) * 16.0 - (10.0 - P[:, 2]) * 0.16
                d = np.maximum(d, -np.maximum(cuña, P[:, 2] - 10.0))
        return d
    e.add(tela, 'manto_d' if roto else 'manto', 0, 'manto')
    def armino(P):
        d = np.abs(sd_elipsoide(P, MC, MR + 0.4)) - 1.1
        d = np.maximum(d, P[:, 1] + 1.5 - P[:, 2] * 0.12)
        bajo = np.maximum(-P[:, 2], P[:, 2] - 2.4)
        cuello = np.maximum(12.4 - P[:, 2], P[:, 2] - 14.4)
        if roto:
            ang = np.arctan2(P[:, 1], P[:, 0])
            bajo = np.maximum(bajo, -np.sin(ang * 4.0 + 0.7) * 3.0)     # a trozos
            return np.maximum(d, bajo)
        return np.maximum(d, np.minimum(bajo, cuello))
    e.add(armino, 'armino', 0, 'armino')
    for k in range(9):
        ang = -math.pi * (0.1 + 0.8 * k / 8.0)
        for z in ((1.2, 13.4) if not roto else (1.2,)):
            if roto and math.sin(ang * 4.0 + 0.7) < 0:
                continue
            rz = math.sqrt(max(0.0, 1.0 - ((z - MC[2]) / (MR[2] + 0.4)) ** 2))
            p = MC + V([math.cos(ang) * (MR[0] + 1.9) * rz, math.sin(ang) * (MR[1] + 1.9) * rz, z - MC[2]])
            e.add(lambda P, c=p: sd_esfera(P, c, 0.6), 'mota', 0, 'armino')


def tirano():
    e = Escena(S.huesos(S.POSE()))
    C, R = _cuerpo(e)
    _manto(e, C, R)
    _corona_cristal(e)
    _ojos(e, C, R, ceja=True)
    _nucleo(e, C, cristales=5)
    return e.L


def destronado():
    e = Escena(S.huesos(S.POSE()))
    C, R = _cuerpo(e)
    _manto(e, C, R, roto=True)
    _corona_cristal(e, rota=True)
    _ojos(e, C, R, caidos=True)
    _nucleo(e, C, cristales=5)
    return e.L


FILAS = [
    ('Rey hoy', ESC_REY, rey_hoy),
    ('R1 corona gel', ESC_REY, r1_gel),
    ('R2 corona oro', ESC_REY, r2_oro),
    ('1a TIRANO', ESC_TIRANO, tirano),
    ('2a DESTRONADO', ESC_DESTRONADO, destronado),
]


def _lamina(filas, sal, esc=3):
    W, H = filas[0][1][0].size
    y_ini, y_fin = H, 0
    for _, fotos in filas:
        for f in fotos:
            bb = f.getbbox()
            if bb:
                y_ini = min(y_ini, bb[1]); y_fin = max(y_fin, bb[3])
    y_ini = max(0, y_ini - 3); y_fin = min(H, y_fin + 3); h = y_fin - y_ini
    IZQ = 110
    n = max(len(f) for _, f in filas)
    lam = Image.new('RGB', (W * n + IZQ, h * len(filas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    for j, (nombre, fotos) in enumerate(filas):
        dr.text((4, j * h + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            fc = f.crop((0, y_ini, f.size[0], y_fin))
            lam.paste(fc, (IZQ + i * W, j * h), fc)
    lam.resize((lam.width * esc, lam.height * esc), Image.NEAREST).save(sal)
    print(sal)


if __name__ == '__main__':
    sal = sys.argv[1] if len(sys.argv) > 1 else 'tools/salida/sdf/slime_rey_versiones.png'
    os.makedirs(os.path.dirname(sal), exist_ok=True)
    solo = sys.argv[2:] if len(sys.argv) > 2 else None
    filas = []
    for nombre, esc, fn in FILAS:
        if solo and not any(s in nombre for s in solo):
            continue
        if fn is rey_hoy:
            mo = S.MODELO
            mo.W, mo.H = LIENZO; mo.OX, mo.OY = PIES
        else:
            mo = modelo(esc)
        filas.append((nombre, [render(mo, fn(), d) for d in range(5)]))
        print(nombre, 'ok')
    _lamina(filas, sal)
