# ============================================================
#  slime_veneno_versiones.py -- el MUTANTE DEL SLIME VENENOSO, propuestas (06/10/2026). Solo QUIETOS, al lado del
#  venenoso de hoy (s115); el elegido pasa a slime_sdf.py como variante para animarlo.
#  Lo que pidio el jefe: ver las TRES opciones dibujadas para decidir ("el pustuloso suena bien"):
#    - PUSTULOSO: ampollas en la piel, sin simetria, una grande a punto de reventar; burbujas de gas dentro.
#    - CORROSIVO: gel mas oscuro, chorreones de acido por los costados, la piel comida a agujeritos y espuma arriba.
#      SIN CHARCO debajo: la baba del suelo la pone el juego (lo dijo el 05/10, ver slime_sdf.escena).
#    - NUBE TOXICA: hirviendo, volutas de gas que le salen de la coronilla y burbujas reventando en la piel.
#  Los tres con su NUCLEO y algun CRISTAL dentro (sutiles), como el brotado.
#  Uso: python tools/sprites_sdf/slime_veneno_versiones.py [salida.png]
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
os.environ['SLIME_VAR'] = 's115'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import slime_sdf as S

V = np.array
COLOR = '47d552'          # el BASE de las hojas del slime venenoso
ESC_NORMAL = 1.15
ESC_MUTANTE = 1.15 * 1.2  # el x1.2 del mutante sobre su tamaño (como mut138)
# El lienzo, el del mutante y con holgura para las volutas de gas: el normal se pinta en el mismo, mas pequeño.
LIENZO, PIES = S._lienzo(ESC_MUTANTE * 1.3)


def _mats(color=COLOR, oscurece=0.0):
    m = S._materiales('normal', COLOR)
    c = S.osc(S.hexc(color), oscurece)
    m['gel'] = [S.osc(c, 0.30), c, S.cla(c, 0.28), S.cla(c, 0.62)]
    m['cuerno'] = m['gel']
    # LA AMPOLLA: el gel hinchado y estirado, mas claro y algo amarillento (pus), con su brillo.
    amp = (0.74, 0.95, 0.36)
    m['ampolla'] = [S.osc(amp, 0.22), amp, S.cla(amp, 0.35), S.cla(amp, 0.75)]
    # La PIEL FINA de la punta de la que va a reventar: amarillo verdoso palido.
    m['punta'] = [(0.80, 0.86, 0.42), (0.90, 0.94, 0.55), (0.97, 1.0, 0.72)]
    # LAS BURBUJAS de gas de dentro: claras, se leen a traves del gel.
    m['burbuja'] = [(0.70, 0.95, 0.62), (0.82, 1.0, 0.74), (0.93, 1.0, 0.88)]
    # EL ACIDO de los chorreones: mas vivo y amarillento que el gel.
    aci = (0.70, 0.92, 0.18)
    m['acido'] = [S.osc(aci, 0.25), aci, S.cla(aci, 0.35), S.cla(aci, 0.75)]
    # LA ESPUMA: burbujitas palidas y opacas.
    m['espuma'] = [(0.70, 0.84, 0.50), (0.84, 0.94, 0.64), (0.95, 1.0, 0.82)]
    # EL GAS: verde palido, translucido.
    gas = (0.80, 0.95, 0.62)
    m['gas'] = [S.osc(gas, 0.18), gas, S.cla(gas, 0.35)]
    return m


def modelo(escala, oscurece=0.0, translucidos=('gel', 'cuerno', 'ampolla'), suaves=('cuerpo', 'gas')):
    c = S.osc(S.hexc(COLOR), oscurece)
    mo = Modelo(escala, LIENZO, PIES, _mats(COLOR, oscurece), S.osc(c, 0.58), suaves=suaves,
                brillan=('ojo', 'gema'), corta_suelo=True,
                especular=('gel', 'cuerno', 'cristal', 'ampolla', 'acido'), umbral_especular=0.955,
                translucidos=translucidos, alfa=0.72)
    mo.alfa_dentro = 0.42
    mo.claros_dentro = ('cristal', 'nucleo', 'burbuja')
    mo.alfa_claro = 0.45
    return mo


def _dir(x, y, z):
    d = V([x, y, z], dtype=float)
    return d / np.linalg.norm(d)


def _cristal(e, c, eje, largo, radio):
    eje = _dir(*eje)
    a = c - eje * largo * 0.5; b = c + eje * largo * 0.5
    e.add(lambda P, a=a, c=c, b=b: np.minimum(sd_cono(P, a, c, 0.25, radio), sd_cono(P, c, b, radio, 0.25)),
          'cristal', 0, 'cristal')


def _nucleo(e, c, r):
    e.add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'nucleo', 0, 'nucleo')


def _cuerno(e, C, R, x, y, z, tam=1.0):
    base, n = S._superficie((x, y, z), C, R)
    lado = 1.0 if x >= 0 else -1.0
    raiz = base - n * 2.0
    medio = base + n * 2.6 * tam + V([0.6 * lado * tam, 0.0, 3.0 * tam])
    punta = medio + V([-0.6 * lado * tam, 0.0, 3.6 * tam])
    e.add(lambda P, a=raiz, b=medio, t=tam: sd_cono(P, a, b, 4.4 * min(t, 1.15), 2.4 * min(t, 1.15)), 'gel', 1.8)
    e.add(lambda P, a=medio, b=punta, t=tam: sd_cono(P, a, b, 2.4 * min(t, 1.15), 0.9), 'gel', 1.0)


def _ojos(e, C, R):
    for x, y, z in [(-0.33, 0.88, 0.34), (0.33, 0.88, 0.34)]:
        base, n = S._superficie((x, y, z), C, R)
        c = base + n * 0.05
        e.add(lambda P, c=c: np.maximum(sd_elipsoide(P, c, V([2.3, 3.0, 5.0])), sd_elipsoide(P, C, R) - 0.3),
              'ojo', 0, 'ojo')


def _base():
    C, R, _sz = S._forma(S.POSE())
    return Escena(S.huesos(S.POSE())), C, R


def _tripas(e, C):
    # Su NUCLEO y un par de cristales comidos, sutiles (como el brotado).
    _nucleo(e, C + V([0.0, -2.5, -1.5]), 3.4)
    _cristal(e, C + V([5.0, -1.0, 2.5]), (0.5, 0.2, 1.0), 4.5, 1.3)
    _cristal(e, C + V([-5.0, -3.5, 0.5]), (-0.4, 0.3, 1.0), 4.0, 1.1)


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def venenoso_hoy():
    return S.escena(S.POSE())


def pustuloso():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'gel', 0)
    # LAS AMPOLLAS (direccion en la cupula, radio): una GRANDE en el costado derecho, a punto de reventar; un racimo de
    # pequeñas en el lomo izquierdo y alguna suelta. Nada delante de los ojos.
    ampollas = [((0.86, 0.30, 0.15), 5.6), ((-0.62, -0.45, 0.55), 3.4), ((-0.82, -0.15, 0.30), 2.6),
                ((-0.40, -0.75, 0.40), 2.4), ((0.30, -0.55, 0.80), 3.0), ((0.60, -0.70, 0.10), 2.2)]
    for d, r in ampollas:
        base, n = S._superficie(d, C, R)
        c = base + n * r * 0.22
        e.add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'ampolla', 1.8)
    # La piel FINA de la grande: una mancha palida en su punta, donde va a romper.
    base, n = S._superficie(ampollas[0][0], C, R)
    tip = base + n * ampollas[0][1] * 1.12
    e.add(lambda P, t=tip: sd_esfera(P, t, 1.5), 'punta', 0.6)
    for s in (-1, 1):
        _cuerno(e, C, R, 0.70 * s, 0.05, 0.72)
    _ojos(e, C, R)
    _tripas(e, C)
    # BURBUJAS DE GAS dentro, en columna, subiendo (mas pequeñas cuanto mas arriba).
    for c, r in [((-3.0, -1.0, -3.0), 1.6), ((-2.0, -0.5, 1.0), 1.3), ((-2.8, 0.2, 4.5), 1.0),
                 ((3.0, 1.5, -2.0), 1.2), ((2.0, 2.0, 2.0), 0.9)]:
        e.add(lambda P, c=C + V(c), r=r: sd_esfera(P, c, r), 'burbuja', 0, 'burbuja')
    return e.L


def corrosivo():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.02])
    # LA PIEL COMIDA: agujeritos (hoyos redondos) mordidos en la cupula, por arriba y el lomo.
    hoyos = []
    for d, r in [((0.30, -0.30, 0.90), 1.8), ((-0.40, -0.10, 0.90), 1.4), ((-0.70, -0.55, 0.45), 1.7),
                 ((0.65, -0.60, 0.45), 1.5), ((0.10, -0.85, 0.50), 1.3), ((-0.85, 0.25, 0.40), 1.2)]:
        base, n = S._superficie(d, C, R)
        hoyos.append((base + n * 0.4, r))
    def gel(P, C=C, R=R, hoyos=hoyos):
        d = sd_elipsoide(P, C, R)
        for c, r in hoyos:
            d = np.maximum(d, -sd_esfera(P, c, r))
        return d
    e.add(gel, 'gel', 0)
    # LOS CHORREONES: el acido que le cae por los costados (azimut en grados, 0 = delante), del lomo a la panza,
    # engordando hacia abajo y acabando en GOTA. Ninguno por delante de los ojos.
    for az, alto, bajo, g in [(70, 0.62, -0.15, 1.0), (115, 0.70, -0.05, 0.85), (-80, 0.55, -0.20, 1.1),
                              (-140, 0.65, 0.0, 0.8), (160, 0.45, -0.10, 0.9), (40, 0.30, -0.18, 0.7)]:
        a = math.radians(az)
        pts = []
        for i in range(7):
            u = i / 6.0
            el = alto + (bajo - alto) * u
            d = (math.sin(a) * math.cos(el), math.cos(a) * math.cos(el), math.sin(el))
            base, n = S._superficie(d, C, R)
            pts.append((base + n * (-0.2 + 0.3 * u), (1.0 + 0.8 * u) * g))
        for (p0, r0), (p1, r1) in zip(pts[:-1], pts[1:]):
            e.add(lambda P, a=p0, b=p1, ra=r0, rb=r1: sd_cono(P, a, b, ra, rb), 'acido', 1.2)
        pf, rf = pts[-1]
        e.add(lambda P, c=pf + V([0, 0, -0.4]), r=rf * 1.3: sd_esfera(P, c, r), 'acido', 1.0)
    # LA ESPUMA: un racimo de burbujitas en la coronilla, entre los cuernos y hacia atras.
    rng = np.random.default_rng(11)
    for _ in range(11):
        d = _dir(rng.uniform(-0.45, 0.45), rng.uniform(-0.65, 0.05), 1.0)
        base, n = S._superficie(d, C, R)
        r = rng.uniform(0.9, 1.8)
        e.add(lambda P, c=base + n * r * 0.4, r=r: sd_esfera(P, c, r), 'espuma', 0, 'espuma')
    for s in (-1, 1):
        _cuerno(e, C, R, 0.70 * s, 0.05, 0.72)
    _ojos(e, C, R)
    _tripas(e, C)
    return e.L


def nube_toxica():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'gel', 0)
    # BURBUJAS REVENTANDO en la piel: medias bolas claras pegadas, alguna abierta (un hoyo en su cima).
    for d, r in [((0.80, -0.30, 0.35), 2.0), ((-0.75, -0.40, 0.30), 1.7), ((0.40, -0.75, 0.45), 1.5),
                 ((-0.30, -0.85, 0.15), 1.9), ((0.88, 0.25, -0.05), 1.4)]:
        base, n = S._superficie(d, C, R)
        c = base + n * r * 0.2
        abierta = r > 1.8
        def bur(P, c=c, r=r, n=n, abierta=abierta):
            dd = sd_esfera(P, c, r)
            return np.maximum(dd, -sd_esfera(P, c + n * r * 0.95, r * 0.55)) if abierta else dd
        e.add(bur, 'ampolla', 0.5)
    # LAS BOCANADAS: nubecitas redondas (racimos de bolas) que le salen de la coronilla, entre los cuernos y hacia
    # atras, y suben haciendose mas pequeñas y apartandose a un lado, como el humo de una olla.
    base, n = S._superficie((0.0, -0.30, 1.0), C, R)
    for (dx, dy, dz), k in [((0.0, 0.0, 2.5), 1.0), ((1.8, -1.0, 8.0), 0.78), ((-0.6, -1.8, 12.5), 0.58),
                            ((1.2, -2.4, 16.0), 0.40)]:
        nube = base + V([dx, dy, dz])
        for (ox, oy, oz), rr in [((0.0, 0.0, 0.0), 2.6), ((2.0, 0.4, -0.4), 2.0), ((-2.0, -0.3, -0.5), 1.9),
                                 ((0.5, 0.3, 1.6), 1.8)]:
            e.add(lambda P, c=nube + V([ox, oy, oz]) * k, r=rr * k: sd_esfera(P, c, r), 'gas', 1.0, 'gas')
    for s in (-1, 1):
        _cuerno(e, C, R, 0.70 * s, 0.05, 0.72)
    _ojos(e, C, R)
    _tripas(e, C)
    return e.L


# ------------------------------------------------------------
#  LO ELEGIDO (06/10): UNA LINEA. 1a = la NUBE TOXICA, pero el humo NO sale todo el rato: A RATOS y por SITIOS AL AZAR
#  de su cuerpo. 2a (la fuerte) = BURBUJAS que le salen al azar por cualquier parte, revientan y sueltan el humillo.
#  En el juego eso lo pondra una capa aparte a su aire (como el parpadeo); aqui se dibuja metido en la escena para verlo.
# ------------------------------------------------------------
def _paso(x, a, b):
    return min(1.0, max(0.0, (x - a) / (b - a)))


def _bocanada(e, base, n, u, k=1.0):
    """Una nubecita de gas que sale de 'base' (normal 'n') y sube; u 0..1 = su vida (nace pequeña, crece, se va)."""
    sube = V([0.0, 0.0, 1.0])
    c0 = base + n * (1.5 + 1.5 * u) + sube * (u * 9.0) + V([math.sin(u * 4.0) * 1.2, 0.0, 0.0])
    tam = k * (0.55 + 0.6 * math.sin(min(u, 1.0) * math.pi * 0.9))
    for (ox, oy, oz), rr in [((0.0, 0.0, 0.0), 2.6), ((2.0, 0.4, -0.4), 2.0), ((-2.0, -0.3, -0.5), 1.9),
                             ((0.5, 0.3, 1.6), 1.8)]:
        e.add(lambda P, c=c0 + V([ox, oy, oz]) * tam, r=rr * tam: sd_esfera(P, c, r), 'gas', 1.0, 'gas')
    if u > 0.35:
        # La cola: una segunda bocanada mas pequeña que la sigue.
        u2 = (u - 0.35) / 0.65
        c1 = base + n * (1.0 + 1.5 * u2) + sube * (u2 * 7.0)
        t1 = k * 0.45 * math.sin(u2 * math.pi)
        if t1 > 0.05:
            e.add(lambda P, c=c1, r=2.2 * t1: sd_esfera(P, c, r), 'gas', 1.0, 'gas')


def _evento(e, C, R, d, t, con_burbuja):
    """Lo que sale al azar en el punto 'd' de su cuerpo, en el momento t (0..1).
    1a: un respiradero que se abre y suelta una bocanada. 2a: una BURBUJA que se hincha, REVIENTA y suelta el humo."""
    base, n = S._superficie(d, C, R)
    if con_burbuja and t < 0.45:
        r = 4.6 * _paso(t, 0.0, 0.42) ** 0.7
        if r > 0.2:
            e.add(lambda P, c=base + n * r * 0.55, r=r: sd_esfera(P, c, r), 'ampolla', 0.6)
        return
    # El agujero por donde sale (la burbuja rota, o el poro de la 1a), que se cierra al final.
    u = _paso(t, 0.45 if con_burbuja else 0.0, 1.0)
    r = (3.0 if con_burbuja else 2.0) * (1.0 - _paso(u, 0.6, 1.0))
    if r > 0.2:
        def borde(P, c=base + n * 0.5, r=r, n=n):
            dd = sd_esfera(P, c, r)
            return np.maximum(dd, -sd_esfera(P, c + n * r * 0.9, r * 0.7))
        e.add(borde, 'ampolla', 0.4)
    _bocanada(e, base, n, u, 1.35 if con_burbuja else 1.1)


def _toxico(grado, eventos=()):
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'gel', 0)
    # Las marcas de la piel: poros abiertos (por donde ha salido gas). La 2a, ademas, burbujitas a medio salir.
    poros = [((0.80, -0.30, 0.35), 2.1), ((-0.75, -0.40, 0.30), 1.9), ((0.40, -0.75, 0.45), 1.8),
             ((-0.30, -0.85, 0.15), 2.0)]
    for d, r in poros:
        base, n = S._superficie(d, C, R)
        c = base + n * r * 0.2
        e.add(lambda P, c=c, r=r, n=n: np.maximum(sd_esfera(P, c, r), -sd_esfera(P, c + n * r * 0.95, r * 0.55)),
              'ampolla', 0.5)
    if grado >= 2:
        for d, r in [((0.88, 0.25, -0.05), 2.4), ((-0.55, -0.15, 0.80), 2.0), ((0.15, -0.95, 0.30), 2.6),
                     ((-0.90, 0.20, 0.05), 1.8), ((0.55, -0.40, 0.72), 1.7)]:
            base, n = S._superficie(d, C, R)
            e.add(lambda P, c=base + n * r * 0.35, r=r: sd_esfera(P, c, r), 'ampolla', 0.5)
    for d, t in eventos:
        _evento(e, C, R, d, t, grado >= 2)
    for s in (-1, 1):
        _cuerno(e, C, R, 0.70 * s, 0.05, 0.72)
    _ojos(e, C, R)
    _tripas(e, C)
    return e.L


# Los sitios "al azar" para enseñarlo (en el juego los tirara el juego cada vez).
EV_1 = [((0.55, -0.45, 0.70), 0.55)]
EV_2 = [((0.80, 0.10, 0.45), 0.25), ((-0.60, -0.55, 0.55), 0.6), ((0.10, -0.70, 0.70), 0.85)]
ESC_2 = ESC_MUTANTE * 1.1
_TR = {'translucidos': ('gel', 'cuerno')}
ELEGIDO = [
    ('venenoso hoy', ESC_NORMAL, venenoso_hoy, {}),
    ('1a quieto', ESC_MUTANTE, lambda: _toxico(1), _TR),
    ('1a echando humo', ESC_MUTANTE, lambda: _toxico(1, EV_1), _TR),
    ('2a quieto', ESC_2, lambda: _toxico(2), _TR),
    ('2a burbujas', ESC_2, lambda: _toxico(2, EV_2), _TR),
]
# La TIRA del efecto (la 2a mirando al sur): una burbuja que se hincha, revienta y suelta el humo.
TIRA_T = [0.0, 0.15, 0.3, 0.42, 0.5, 0.62, 0.75, 0.9]
TIRA_D = (0.62, 0.30, 0.45)


FILAS = [
    ('venenoso hoy', ESC_NORMAL, venenoso_hoy, {}),
    ('A pustuloso', ESC_MUTANTE, pustuloso, {'translucidos': ('gel', 'cuerno')}),
    ('B corrosivo', ESC_MUTANTE, corrosivo, {'oscurece': 0.22}),
    ('C nube toxica', ESC_MUTANTE, nube_toxica, {'translucidos': ('gel', 'cuerno', 'ampolla')}),
]


def _tira(sal):
    mo = modelo(ESC_2, **_TR)
    fotos = [render(mo, _toxico(2, [(TIRA_D, t)]), 0) for t in TIRA_T]
    W, H = fotos[0].size
    lam = Image.new('RGB', (W * len(fotos), H), (40, 42, 50))
    for i, f in enumerate(fotos):
        lam.paste(f, (i * W, 0), f)
    lam.resize((lam.width * 4, lam.height * 4), Image.NEAREST).save(sal)
    print(sal)


if __name__ == '__main__':
    # 'elegido' = la 1a y la 2a de la nube toxica (y la tira del efecto); sin nada, las tres propuestas.
    ELEG = len(sys.argv) > 1 and sys.argv[1] == 'elegido'
    if ELEG:
        sys.argv.pop(1)
        FILAS = ELEGIDO
    sal = sys.argv[1] if len(sys.argv) > 1 else 'tools/salida/sdf/slime_veneno_versiones.png'
    os.makedirs(os.path.dirname(sal), exist_ok=True)
    if ELEG:
        _tira(sal.replace('.png', '_tira.png'))
    filas = []
    for nombre, esc, fn, extra in FILAS:
        L = fn()
        mo = modelo(esc, **extra)
        filas.append((nombre, [render(mo, L, d) for d in range(5)]))
        print(nombre, 'ok')
    W, H = filas[0][1][0].size
    y_ini, y_fin = H, 0
    for _, fotos in filas:
        for f in fotos:
            bb = f.getbbox()
            if bb:
                y_ini = min(y_ini, bb[1]); y_fin = max(y_fin, bb[3])
    y_ini = max(0, y_ini - 3); y_fin = min(H, y_fin + 3); h = y_fin - y_ini
    IZQ = 92
    lam = Image.new('RGB', (W * 5 + IZQ, h * len(filas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    for j, (nombre, fotos) in enumerate(filas):
        dr.text((4, j * h + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            fc = f.crop((0, y_ini, f.size[0], y_fin))
            lam.paste(fc, (IZQ + i * W, j * h), fc)
    lam = lam.resize((lam.width * 4, lam.height * 4), Image.NEAREST)
    lam.save(sal)
    print(sal)
