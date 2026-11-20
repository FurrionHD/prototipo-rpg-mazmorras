# ============================================================
#  acechador_mutantes_versiones.py -- LOS MUTANTES DEL ACECHADOR, propuestas en QUIETO (19/11/2026, memoria
#  acechador-mutante). Una linea: Acechador -> SOMBRA SIN ROSTRO (sigilo: se funde en las sombras cada turno) ->
#  CAZADOR LUNAR (conserva el sigilo y suma la magia de lunas). Las ideas de cuerpo ya las marco el:
#    SOMBRA SIN ROSTRO  «HUMO EN LOS BORDES»: el contorno se deshace en jirones de sombra en la cola y el lomo, como pelo
#                       hecho humo; los ojos APAGADOS y solo se encienden al atacar.
#                       A humo corto   jirones cortos por el lomo y la cola
#                       B humo largo   jirones largos que suben del lomo y la cola entera hecha humo
#                       B atacando     la misma, con la boca abierta y los ojos ENCENDIDOS
#    CAZADOR LUNAR      «LOBO DE LUNA»: lobo grande, pecho erguido, melena blanco azulada que brilla como la luna y
#                       crecientes en los hombros.
#                       A melena y hombros    la melena alrededor del cuello y un creciente en cada hombro
#                       B con frente y cola   ademas un creciente en la frente y la punta de la cola de luz
#  Los dos, mayores que el normal (tienen mucha mas vida). Arriesgando el cuerpo (memoria mutante-cambia-el-cuerpo-entero).
#  Uso: python tools/sprites_sdf/acechador_mutantes_versiones.py
#    -> tools/salida/sdf/acechador_mutantes_versiones.png (y al escritorio, ataques_mapa/enemigos/prueba_3d/mutantes)
# ============================================================
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import sdf_comun
import acechador_sdf as base

V = np.array

# --- LA SOMBRA: el negro mate del Apagaluces (la referencia "10/10"), con los colmillos de hueso apagado y el humo.
MAT_SOMBRA = dict(base.MAT)
MAT_SOMBRA.update({
    'piel':   [(0.08, 0.08, 0.10), (0.13, 0.13, 0.16), (0.19, 0.19, 0.23)],
    'pata':   [(0.05, 0.05, 0.06), (0.08, 0.08, 0.10), (0.12, 0.12, 0.15)],
    'crin':   [(0.06, 0.06, 0.08), (0.10, 0.10, 0.13), (0.15, 0.15, 0.19)],
    'morro':  [(0.07, 0.07, 0.09), (0.11, 0.11, 0.14), (0.16, 0.16, 0.20)],
    'hueso':  [(0.42, 0.40, 0.38), (0.55, 0.53, 0.50), (0.64, 0.62, 0.58)],
    # los jirones: humo gris violeta, translucido
    'humo':   [(0.22, 0.20, 0.30), (0.33, 0.31, 0.43), (0.46, 0.44, 0.58)],
    # los ojos APAGADOS (en quieto): un rescoldo apenas visible
    'ojo_off': [(0.16, 0.08, 0.08), (0.22, 0.11, 0.10), (0.28, 0.14, 0.12)],
    # y ENCENDIDOS al atacar: ambar que quema
    'ojo':    [(1.0, 0.62, 0.20)] * 3,
})

# --- EL LOBO DE LUNA: pelaje azul noche, melena y crecientes blanco azulado (brillan), ojos de hielo.
MAT_LUNA = dict(base.MAT)
MAT_LUNA.update({
    'piel':   [(0.13, 0.15, 0.24), (0.20, 0.23, 0.34), (0.30, 0.34, 0.47)],
    'pata':   [(0.08, 0.09, 0.15), (0.12, 0.14, 0.21), (0.18, 0.20, 0.29)],
    'crin':   [(0.55, 0.62, 0.80), (0.74, 0.81, 0.95), (0.88, 0.93, 1.00)],
    'morro':  [(0.10, 0.11, 0.18), (0.15, 0.17, 0.25), (0.22, 0.24, 0.33)],
    'luna':   [(0.80, 0.88, 1.00), (0.88, 0.93, 1.00), (0.95, 0.97, 1.00)],
    'ojo':    [(0.70, 0.90, 1.00)] * 3,
    'pupila': [(0.10, 0.14, 0.30)] * 3,
})


def modelo(mat, escala, lado=170, k_pies=0.55, translucidos=(), brillan=('ojo', 'pupila')):
    return Modelo(escala, (lado, lado), (lado // 2, int(lado * k_pies)), mat, (0.02, 0.02, 0.03),
                  suaves=('cuerpo', 'cabeza'), brillan=brillan, corta_suelo=True, translucidos=translucidos, alfa=0.72)


def _unit(v):
    return v / np.linalg.norm(v)


def _con(L, pose, extra):
    """La escena del acechador de base + las piezas de 'extra(add, pose)' (con los mismos huesos)."""
    e2 = Escena(base.huesos(pose))
    extra(e2.add, pose)
    L.extend(e2.L)
    return L


def _sin_ojos(L):
    """Los ojos del de base, cambiados al rescoldo apagado (la Sombra en quieto)."""
    out = Piezas()
    out.sombras = getattr(L, 'sombras', [])
    for fn, m, g, k, Xh, nh in L:
        out.append((fn, 'ojo_off' if m in ('ojo', 'pupila') else m, g, k, Xh, nh))
    return out


# ------------------------------------------------------------
#  MAS RECIOS (19/11: "aun parecen un poco flacuchines, como su primera forma basada en un galgo"): las patas del de base
#  con los radios mas gordos y el tronco relleno (sin la cintura recogida del galgo)
# ------------------------------------------------------------
def escena_recia(p, k_pata, largo=0.0):
    # (20/11) 'largo' = PATAS MAS LARGAS: el cuerpo sube 'largo' (alza en la pose) y las patas se estiran desde el suelo
    # para seguir apoyadas (z -> z * (1 + largo / 13) - largo, que con el +largo de la raiz deja el pie en su sitio).
    viejo_cono, viejo_elip = base._cono, base._elip

    def _z(q, es_pata):
        q = V(q, dtype=float)
        if es_pata and largo != 0.0:
            q = V((q[0], q[1], q[2] * (1.0 + largo / 13.0) - largo))
        return q

    def cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        es = str(grupo).startswith('pata')
        f = k_pata if es else 1.0
        viejo_cono(add, _z(a, es), _z(b, es), ra * f, rb * f, mat, k, grupo, hueso)

    def elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        es = str(grupo).startswith('pata')
        f = k_pata if es else 1.0
        viejo_elip(add, _z(c, es), tuple(x * f for x in r), mat, k, grupo, hueso)

    base._cono, base._elip = cono, elip
    try:
        return base.escena(p)
    finally:
        base._cono, base._elip = viejo_cono, viejo_elip


# (20/11) EL ANCHO DEL LOBO (lo cambia acechador_mut_sdf segun LOBO_CUERPO): el tronco de lado y el pecho/cuello extra.
ANCHO_LOBO = {'tronco_x': 1.0, 'pecho_x': 1.0, 'vientre_z': 1.0}


def tronco(add, p, k=1.0, kx=None):
    """El barril: rellena la cintura y el vientre (el galgo la lleva recogida). kx = el ancho de lado (por defecto k)."""
    kx = k if kx is None else kx
    base._elip(add, (0.0, -1.6, 13.4), (4.8 * kx, 9.4, 4.4 * k), 'piel', 2.0)
    base._elip(add, (0.0, 0.6, 11.4), (4.0 * kx, 7.0, 3.0 * k * ANCHO_LOBO['vientre_z']), 'piel', 2.0)
    base._elip(add, (0.0, -9.0, 15.8), (5.4 * kx, 5.4, 4.8 * k), 'piel', 2.0)


# ------------------------------------------------------------
#  LA SOMBRA SIN ROSTRO: jirones de humo
# ------------------------------------------------------------
def _jiron(add, a, d, largo, r0, rnd, grupo, pasos=4):
    """Un jiron de humo: BOCANADAS redondas que se encogen poco a poco y se ondulan al subir (19/11: "menos pincho"; con
    conos que se afilaban se leian como puas)."""
    pt = V(a, dtype=float); d = _unit(V(d, dtype=float)); r = r0
    for i in range(pasos):
        q = pt + d * (largo / pasos)
        base._elip(add, q, (r, r * 1.25, r * 0.95), 'humo', 0.0, grupo)
        pt = q; r = max(0.35, r * 0.86)
        d = _unit(d + V((rnd.uniform(-0.55, 0.55), rnd.uniform(-0.35, 0.15), 0.25)))


def humo(largo_lomo, largo_cola, cola_entera):
    def extra(add, p):
        tronco(add, p, 1.0)
        rnd = random.Random(11)
        # POR EL LOMO: de la cruz a la grupa, hacia arriba y algo atras
        for i in range(14):
            u = i / 13.0
            y = 9.0 - u * 19.0
            z = 13.6 + u * 3.0 + 0.8
            for x in (-1.6, 1.6):
                x = x + rnd.uniform(-0.6, 0.6)
                _jiron(add, (x, y, z), (x * 0.45, -0.9, 1.0), largo_lomo * (0.7 + 0.5 * rnd.random()),
                       1.15 + 0.35 * rnd.random(), rnd, 'humo_lomo%d' % i, pasos=5)
        # LA COLA: de su recorrido salen jirones hacia atras y abajo; con 'cola_entera', su mitad final es humo
        pt = base.COLA_NACE.astype(float); d = _unit(V((0.0, -0.75, -0.25)))
        for i in range(12):
            q = pt + d * 1.3
            if i >= 4 and i % 2 == 0:
                for sx in (-1, 1):
                    _jiron(add, q, (0.7 * sx + rnd.uniform(-0.3, 0.3), -0.8, 0.5), largo_cola * (0.6 + 0.4 * rnd.random()),
                           1.0, rnd, 'humo_cola%d' % i, pasos=5)
            if cola_entera and i >= 6:
                base._elip(add, q, (1.9, 2.2, 1.7), 'humo', 0.6, 'humo_cola_bulto%d' % i)
            pt = q
            giro = 0.2 if i < 6 else -0.12
            d = _unit(rx(-giro) @ d + V((0.035 * math.sin(i * 0.8), 0.0, 0.0)))
        # EL VIENTRE Y LOS CODOS: hilachas cortas que cuelgan
        for s in (-1, 1):
            for y in (4.0, -3.0, -8.0):
                _jiron(add, (2.8 * s, y, 9.6), (0.6 * s, -0.4, -1.0), largo_lomo * 0.5, 0.9, rnd, 'humo_vientre')
    return extra


def sombra_a():
    p = base.anim_idle(0.0)
    return _con(_sin_ojos(base.escena(p)), p, humo(3.4, 2.6, False))


def sombra_b():
    p = base.anim_idle(0.0)
    return _con(_sin_ojos(escena_recia(p, 1.35)), p, humo(6.0, 4.2, True))


def sombra_b_ataca():
    # el BASICO a medio morder: la boca abierta y los ojos encendidos
    p = base.anim_basico(0.26)
    return _con(escena_recia(p, 1.35), p, humo(6.0, 4.2, True))


# ------------------------------------------------------------
#  EL CAZADOR LUNAR: lobo de luna
# ------------------------------------------------------------
def _creciente(add, c, u, v, R, grueso, grupo, hueso='raiz', abre=0.0):
    """Una media luna: un arco de 220 grados en el plano (u, v), gruesa en el medio y afilada en las puntas."""
    u = _unit(V(u, dtype=float)); v = _unit(V(v, dtype=float)); c = V(c, dtype=float)
    n = 10
    a0 = math.radians(-110 + abre); a1 = math.radians(110 + abre)
    pts = [c + (u * math.cos(a0 + (a1 - a0) * i / n) + v * math.sin(a0 + (a1 - a0) * i / n)) * R for i in range(n + 1)]
    for i in range(n):
        m = 1.0 - abs((i + 0.5) / n - 0.5) * 2.0   # 0 en las puntas, 1 en el medio
        ra = grueso * (0.25 + 0.75 * (1.0 - abs(i / n - 0.5) * 2.0))
        rb = grueso * (0.25 + 0.75 * (1.0 - abs((i + 1) / n - 0.5) * 2.0))
        base._cono(add, pts[i], pts[i + 1], ra, rb, 'luna', 0.0, grupo, hueso)


def lobo(frente, cola_luz):
    def extra(add, p):
        tronco(add, p, 1.12, 1.12 * ANCHO_LOBO['tronco_x'])
        # MAS CUERPO: el pecho hondo y ancho y un cuello GRUESO (el galgo pasa a lobo grande)
        base._elip(add, (0.0, 6.6, 12.4), (5.6 * ANCHO_LOBO['pecho_x'], 5.2, 5.4), 'piel', 1.4)
        base._elip(add, (0.0, -8.6, 16.2), (5.0 * ANCHO_LOBO['pecho_x'], 5.0, 4.6), 'piel', 1.4)
        base._cono(add, (0.0, 8.6, 14.0), V((0.0, 13.0, 12.8)) + base._off_cabeza(p), 3.6, 2.8, 'piel', 1.6)
        # LA MELENA EN VOLUMEN: una gola de pelo luminoso alrededor del cuello
        base._elip(add, (0.0, 9.6, 13.8), (4.6, 3.0, 4.4), 'crin', 0.0, 'melena_bulto')
        rnd = random.Random(5)
        for i in range(16):
            a = -math.pi * 0.95 + (i / 15.0) * math.pi * 1.9
            # anillo alrededor del cuello (eje y), abierto por debajo
            r = 4.2
            c = V((math.sin(a) * r, 10.0 - 1.4 * abs(math.cos(a)), 12.6 + math.cos(a) * r * 0.9))
            fuera = _unit(V((math.sin(a), -0.9, math.cos(a) * 0.9 + 0.2)))
            largo = 3.6 + 1.6 * rnd.random()
            base._cono(add, c, c + fuera * largo, 1.3, 0.2, 'crin', 0.0, 'melena%d' % i)
        # la cruz, mechones que siguen por el lomo
        for i in range(6):
            y = 7.0 - i * 2.2
            base._cono(add, (0.0, y, 15.6 + i * 0.3), (0.0, y - 2.6, 17.4 + i * 0.3), 1.0, 0.2, 'crin', 0.0, 'melena_lomo')
        # LOS CRECIENTES DE LOS HOMBROS: de canto, mirando afuera
        for s in (-1, 1):
            # por FUERA de la melena (antes quedaban medio tapados) y mas grandes
            # (20/11, el jefe: "casi no se ven a este tamaño") aun mas grandes, gruesos y algo mas afuera
            _creciente(add, (7.4 * s, 3.2, 14.8), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), 4.6, 1.45, 'luna_hombro%d' % s)
        if frente:
            ca = base.CABEZA
            _creciente(add, ca + V((0.0, 0.9, 2.7)), (1.0, 0.0, 0.0), (0.0, -0.35, 1.0), 1.5, 0.5, 'luna_frente',
                       'cabeza', abre=180)
        if cola_luz:
            pt = base.COLA_NACE.astype(float); d = _unit(V((0.0, -0.75, -0.25)))
            for i in range(12):
                q = pt + d * 1.3
                if i >= 9:
                    base._elip(add, q, (1.0, 1.3, 1.0), 'luna', 0.3, 'cola_luz')
                pt = q
                giro = 0.2 if i < 6 else -0.12
                d = _unit(rx(-giro) @ d + V((0.035 * math.sin(i * 0.8), 0.0, 0.0)))
    return extra


def _pose_lobo():
    # PECHO ERGUIDO: algo empinado y con la cabeza alta (no la postura de acecho del normal)
    return base.POSE(empina=0.55, cabeza=5.2, hocico=-1.0, estira=1.0)


def lobo_a():
    p = _pose_lobo()
    return _con(base.escena(p), p, lobo(False, False))


def lobo_b():
    p = _pose_lobo()
    return _con(escena_recia(p, 1.45), p, lobo(True, True))


# ------------------------------------------------------------
#  LA CARA DEL LOBO (19/11: "con los ojos asi parece que tiene cara de loco, pierde toda su seriedad")
# ------------------------------------------------------------
def _sin_ojos_base(L):
    """Quita los ojos del de base (los grandes y redondos)."""
    out = Piezas()
    out.sombras = getattr(L, 'sombras', [])
    for x in L:
        if x[1] not in ('ojo', 'pupila'):
            out.append(x)
    return out


def cara(tipo):
    def extra(add, p):
        ca = base.CABEZA
        for s in (-1, 1):
            oj = ca + V((1.85 * s, 2.2, 1.0))
            if tipo in ('A', 'C'):
                # RASGADOS: una almendra estrecha inclinada hacia el hocico, con la pupila en raya
                M = V(((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)))
                ang = 0.35 * s
                M = V(((math.cos(ang), -math.sin(ang), 0.0), (math.sin(ang), math.cos(ang), 0.0), (0.0, 0.0, 1.0)))
                add(lambda P, c=oj, M=M: sd_elipsoide_girado(P, c, M.T, V((0.55, 0.95, 0.30))), 'ojo', 0, 'ojo', 'cabeza')
                add(lambda P, c=oj + V((0.35 * s, 0.1, 0.0)): sd_elipsoide(P, c, V((0.18, 0.35, 0.28))), 'pupila', 0,
                    'ojo', 'cabeza')
            else:
                # PEQUEÑOS Y FRIOS: hundidos, solo un brillo fino
                base._elip(add, oj + V((-0.1 * s, -0.1, -0.1)), (0.45, 0.5, 0.32), 'ojo', 0, 'ojo', 'cabeza')
                base._elip(add, oj + V((0.12 * s, 0.0, -0.1)), (0.2, 0.25, 0.3), 'pupila', 0, 'ojo', 'cabeza')
            # EL CEÑO: una ceja de hueso del pelaje que cae sobre el ojo hacia el hocico (la mirada dura)
            base._cono(add, ca + V((2.1 * s, 0.9, 1.9)), ca + V((1.2 * s, 3.2, 1.25)), 0.75, 0.45, 'piel', 0.4,
                       'cabeza', 'cabeza')
        if tipo == 'C':
            # el hocico mas largo y recto (mas lobo): se alarga por delante el morro y la mandibula
            base._cono(add, ca + V((0.0, 4.0, -0.4)), V((0.0, 22.4, 9.2)), 1.6, 1.05, 'piel', 1.0, 'cabeza', 'cabeza')
            base._elip(add, (0.0, 22.8, 9.2), (1.05, 0.8, 0.9), 'morro', 0, 'nariz', 'cabeza')
    return extra


def lobo_cara(tipo):
    p = _pose_lobo()
    L = _sin_ojos_base(escena_recia(p, 1.45))
    L = _con(L, p, lobo(True, True))
    return _con(L, p, cara(tipo))


def sombra_cara(ataca):
    """La Sombra B con la cara A (19/11: "le pasa lo mismo a la primera evo"): rasgados y ceño; en quieto, rescoldo."""
    p = base.anim_basico(0.26) if ataca else base.anim_idle(0.0)
    L = _sin_ojos_base(escena_recia(p, 1.35))
    L = _con(L, p, humo(6.0, 4.2, True))
    L = _con(L, p, cara('A'))
    return L if ataca else _sin_ojos(L)


if __name__ == '__main__':
    getattr(sdf_comun, '_prioridad_baja', lambda: None)()
    os.environ['SDF_SOMBRA'] = '1'   # en las laminas, la sombra para leer la altura
    W = H = 170
    BR = ('ojo', 'pupila', 'luna', 'crin')
    if sys.argv[1:] == ['final']:
        filas = [
            ('NORMAL (hoy)', None, None),
            ('SOMBRA SIN ROSTRO', sombra_cara(False), modelo(MAT_SOMBRA, 2.05, translucidos=('humo',), brillan=('ojo',))),
            ('SOMBRA atacando', sombra_cara(True), modelo(MAT_SOMBRA, 2.05, translucidos=('humo',), brillan=('ojo',))),
            ('CAZADOR LUNAR', lobo_cara('A'), modelo(MAT_LUNA, 2.5, brillan=BR)),
        ]
    elif sys.argv[1:] == ['cara']:
        filas = [
            ('LOBO B (cara de ahora)', lobo_b(), modelo(MAT_LUNA, 2.5, brillan=BR)),
            ('CARA A rasgados y ceño', lobo_cara('A'), modelo(MAT_LUNA, 2.5, brillan=BR)),
            ('CARA B pequeños y frios', lobo_cara('B'), modelo(MAT_LUNA, 2.5, brillan=BR)),
            ('CARA C rasgados + hocico', lobo_cara('C'), modelo(MAT_LUNA, 2.5, brillan=BR)),
        ]
    else:
      filas = [
        ('NORMAL (hoy)', None, None),
        ('SOMBRA B retocada', sombra_b(), modelo(MAT_SOMBRA, 2.05, translucidos=('humo',), brillan=('ojo',))),
        ('SOMBRA B atacando', sombra_b_ataca(), modelo(MAT_SOMBRA, 2.05, translucidos=('humo',), brillan=('ojo',))),
        ('LOBO DE LUNA B retocado', lobo_b(), modelo(MAT_LUNA, 2.5, brillan=BR)),
      ]
    ESC = 3
    MARGEN = 230
    tiras = []
    for nombre, L, mo in filas:
        fotos = []
        for d in range(5):
            if L is None:
                im = render(base.MODELO, base.escena(base.anim_idle(0.0)), d)
                lien = Image.new('RGBA', (W, H), (0, 0, 0, 0))
                lien.paste(im, ((W - im.size[0]) // 2, int(H * 0.55) - base.MODELO.OY), im)
                im = lien
            else:
                im = render(mo, L, d)
            fotos.append(im)
        cajas = [f.getbbox() for f in fotos if f.getbbox()]
        y0 = max(0, min(c[1] for c in cajas) - 3)
        y1 = min(H, max(c[3] for c in cajas) + 3)
        tiras.append((nombre, fotos, y0, y1))
        print(nombre, flush=True)
    x0 = max(0, min(f.getbbox()[0] for t in tiras for f in t[1] if f.getbbox()) - 3)
    x1 = min(W, max(f.getbbox()[2] for t in tiras for f in t[1] if f.getbbox()) + 3)
    ancho = x1 - x0
    alto_total = sum((t[3] - t[2]) * ESC for t in tiras)
    # FONDO: el suelo de la mazmorra (gris azulado), donde tiene que leerse algo tan negro
    hoja = Image.new('RGB', (MARGEN + ancho * 5 * ESC, alto_total), (52, 58, 70))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, fotos, y0, y1 in tiras:
        dib.text((10, y + (y1 - y0) * ESC // 2), nombre, fill=(235, 235, 235))
        for d, im in enumerate(fotos):
            c = im.crop((x0, y0, x1, y1)).resize((ancho * ESC, (y1 - y0) * ESC), Image.NEAREST)
            hoja.paste(c, (MARGEN + d * ancho * ESC, y), c)
        y += (y1 - y0) * ESC
        dib.line((0, y - 1, hoja.size[0], y - 1), fill=(70, 74, 86))
    os.makedirs('tools/salida/sdf', exist_ok=True)
    nom = {'cara': 'acechador_caras_lobo.png', 'final': 'acechador_mutantes_final.png'}.get(
        (sys.argv[1:] or [''])[0], 'acechador_mutantes_versiones.png')
    hoja.save('tools/salida/sdf/' + nom)
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    hoja.save(os.path.join(esc, nom))
    print('ok', hoja.size)
