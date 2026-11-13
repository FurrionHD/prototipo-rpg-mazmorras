#!/usr/bin/env python3
# ============================================================
#  polilla_efectos_horno.py -- HORNEA LOS EFECTOS DE LA POLILLA Y SUS MUTANTES, los de su lamina aprobada (12/11/2026:
#  "se ven god", tools/sprites_sdf/polilla_efectos_pixel.py), SIN REJILLA (transparencia de verdad: 4 pasadas, alfa en 4
#  escalones). Cada uno en el color de quien lo lanza: _polvo (la normal y la de luto), _oro (Vigilia dorada), _ceniza
#  (Mortaja alada), _rojo (Polilla insomne).
#  SOBRE QUIEN RECIBE, (CX, CY) = sus pies:
#    roce_<c>        5 dirs: el basico, la media luna blanda que barre la cara y motas que caen brillando
#    polvo_<c>       el polvo en la cara (cada uno que pilla la nube o el cono, y la pasiva de tocarla)
#    velo            el velo de Ciego;  miedo  los jirones morados del Miedo
#  DEL GESTO DE QUIEN LO LANZA (TacticoPixel.al_gesto), origen = el CENTRO DE SU SPRITE, 5 direcciones (+ espejo):
#    aleteo_polvo    el Aleteo cegador: tres bocanadas, una por batido, que salen de su frente
#    cono_oro|ceniza|negro   el Destello de escamas, el Aleteo sombrio y el Parpado negro (este con brasas rojas)
#    ojo_carga       (en bucle) las motas rojas que vuelven a sus ojos;  ojo  el fogonazo al abrirse
#  EN EL SUELO, origen = el centro del circulo:
#    anillo60_<c>    el anillo gordo de las nubes (Nube de esporas, Polvo dorado, Nube de ceniza);  anillo70_rojo  el del Ojo
#    lluvia          la Lluvia de escamas (r40, donde apunta)
#  SOBRE ELLA (origen = el centro de su sprite):
#    amortajarse     el humo que la envuelve de abajo arriba;  insomnio  las motas rojas que tiran de los de cerca;
#    mirada          el destello rojo en sus ojos cuando devuelve un hechizo
#    python tools/sprites_sdf/polilla_efectos_horno.py
# ============================================================
import math
import random

import polilla_efectos_pixel as pe      # (trae su lienzo: va antes que los demas)
import miconido_efectos_pixel as mi
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import ciempies_efectos_pixel as ce
import horno_efectos as ho
import transparencia as tr
from slime_efectos_pixel import nuevo, estrella

LA = 'polilla'
W, H = pe.W, pe.H
CX, CY = W // 2, H // 2 + 20
MODS = [ce, ep, sl, rt, mi, pe]
PALETAS = {'polvo': pe.POLVO, 'oro': pe.ORO, 'ceniza': pe.CENIZA, 'rojo': pe.ROJO}
VAR_DE = {'polvo': pe.NORMAL, 'oro': pe.VIGILIA, 'ceniza': pe.MORTAJA, 'rojo': pe.INSOMNE}
# El sprite se pone por su CENTRO (como hace escena): el juego lanza lo que sale del cuerpo desde el centro de su sprite
# (EfectoPixel.centro_sprite), asi casa sin depender de donde pone los pies la ficha.
A = (CX, CY - 10)


def V():
    return (CX, CY)


def guardar(nombre, gen, fps, n_filas=1, bucle=False, origen=None):
    filas = tr.filas_con_alfa(gen, MODS)
    return ho.guardar_efecto(LA, nombre, filas, [origen or (CX, CY)] * n_filas, fps, bucle)


# ------------------------------------------------------------
#  SOBRE QUIEN RECIBE
# ------------------------------------------------------------
def g_roce(pal):
    def gen():
        filas = []
        for fila in range(5):
            dx, _dy = mi._dir(fila)
            hx, hy = mi.cabeza(V())
            out = []
            for e in range(10):
                s, a = nuevo(), nuevo()
                pe.media_luna(a, hx, hy, e, 1 if dx >= 0 else -1, pal)
                mi.motas(a, hx, hy, e, fila + 3, pal, 5, -0.6, 8, True)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_polvo(pal):
    def gen():
        out = []
        for e in range(10):
            s, a = nuevo(), nuevo()
            mi.tos(a, V(), e, 1, pal, True)
            out.append((s, a))
        return [out]
    return gen


def g_velo():
    out = []
    for e in range(10):
        s, a = nuevo(), nuevo()
        mi.velo(a, V(), e)
        out.append((s, a))
    return [out]


def g_miedo():
    out = []
    for e in range(9):
        s, a = nuevo(), nuevo()
        pe.miedo(a, V(), e)
        out.append((s, a))
    return [out]


# ------------------------------------------------------------
#  DEL GESTO
# ------------------------------------------------------------
def g_aleteo():
    var = pe.NORMAL

    def gen():
        filas = []
        for fila in range(5):
            dx, dy = mi._dir(fila)
            boca = pe.frente(pe.marco(var, 'aletear', 0, fila), A, dx, dy)
            hasta = (boca[0] + dx * 40, boca[1] + dy * 32 - 6)
            out = []
            for f in range(16):
                s, a = nuevo(), nuevo()
                for sale in (1, 3, 5):
                    pe.bocanada(a, boca, hasta, f - sale, pe.POLVO)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_cono(var, pal):
    R = 60.0 / pe.UNIDAD

    def gen():
        filas = []
        for fila in range(5):
            dx, dy = mi._dir(fila)
            eje = math.atan2(dy, dx)
            o = pe.frente(pe.marco(var, 'aletear', 0, fila), A, dx, dy, 0.3)
            out = []
            for e in range(15):
                s, a = nuevo(), nuevo()
                mi.abanico(a if dy > -0.2 else s, o[0], o[1], eje, R, 40.0, e, pal)   # la huella del juego: 40 grados
                mi.motas(a, o[0] + dx * R * 0.5, o[1] + dy * R * 0.5, e, fila + 9, pe.ROJO if pal is pe.NEGRO else pal,
                         8 if pal is pe.NEGRO else 6, 0.5, R * 0.35, True)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_ojo_carga():
    rnd = random.Random(5)
    llegan = [(rnd.uniform(0, math.tau), rnd.uniform(20, 34)) for _ in range(10)]

    def gen():
        out = []
        for f in range(8):
            s, a = nuevo(), nuevo()
            c = pe.centro(pe.marco(pe.INSOMNE, 'ojo_carga', f, 1), A)
            for j, (ang, d0) in enumerate(llegan):
                k = ((f + j * 0.6) % 4) / 4.0
                d = d0 * (1.0 - k)
                pe.punto(a, c[0] + math.cos(ang) * d, c[1] + math.sin(ang) * d * 0.7, pe.ROJO[2] if k > 0.5 else pe.ROJO[1], 2)
            out.append((s, a))
        return [out]
    return gen


def g_ojo():
    out = []
    for e in range(4):
        s, a = nuevo(), nuevo()
        c = pe.centro(pe.marco(pe.INSOMNE, 'ojo', e, 1), A)
        if e < 2:
            estrella(a, c[0], c[1], (18, 12)[e], pe.ROJO)
        elif e == 2:
            estrella(a, c[0], c[1], 6, pe.ROJO)
        out.append((s, a))
    return [out]


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
def g_anillo(radio, pal, dura):
    R = radio / pe.UNIDAD

    def gen():
        out = []
        for e in range(dura + 1):
            s, a = nuevo(), nuevo()
            pe.anillo(s, CX, CY, R, e, pal, dura)
            out.append((s, a))
        return [out]
    return gen


def g_lluvia():
    R = 40.0 / pe.UNIDAD
    out = []
    for e in range(14):
        s, a = nuevo(), nuevo()
        d = pe.np.hypot(pe.XX - CX, (pe.YY - CY) * 2.0)
        fuerza = 1.0 if e < 8 else max(0.0, 1.0 - (e - 8) / 6.0)
        pe.poner(s, (pe.np.abs(d - R) < 2.2) & (pe.TRAMA < 0.6 * fuerza), pe.ORO[1])
        pe.escamas_caen(a, CX, CY, R, e, pe.ORO, 7)
        out.append((s, a))
    return [out]


# ------------------------------------------------------------
#  SOBRE ELLA
# ------------------------------------------------------------
def g_amortajarse():
    out = []
    for f in range(16):
        s, a = nuevo(), nuevo()
        cx, cy = pe.centro(pe.marco(pe.MORTAJA, 'nube', min(f, 7), 1), A)
        pe.humo_sube(a, cx, cy + 6, 46, f, pe.SUDARIO, 3)
        out.append((s, a))
    return [out]


def g_insomnio():
    c = pe.centro(pe.marco(pe.INSOMNE, 'idle', 0, 1), A)
    desde = [(c[0] - 48, c[1] + 22), (c[0] + 46, c[1] + 26), (c[0] + 4, c[1] + 50), (c[0] - 20, c[1] - 30)]
    out = []
    for f in range(10):
        s, a = nuevo(), nuevo()
        if 1 <= f < 9:
            for j, p in enumerate(desde):
                pe.motas_hacia(a, p, c, f, pe.ROJO, 3, j)
        out.append((s, a))
    return [out]


def g_mirada():
    out = []
    for f in range(4):
        s, a = nuevo(), nuevo()
        c = pe.centro(pe.marco(pe.INSOMNE, 'idle', 0, 1), A)
        estrella(a, c[0], c[1], (14, 9, 5, 3)[f], pe.ROJO)
        out.append((s, a))
    return [out]


def g_mirada_bola():
    """La bola roja que vuelve a quien lanzo el hechizo (la mueve el codigo: EfectoPixel.poner_vuelo), una fila por
    direccion, con su cola detras."""
    filas = []
    for fila in range(5):
        dx, dy = mi._dir(fila)
        s, a = nuevo(), nuevo()
        for k in (2, 1):
            pe.bolita(a, CX - dx * 5 * k, CY - dy * 4 * k, 3.8 - k * 0.8, pe.ROJO)
        pe.bolita(a, CX, CY, 3.8, pe.ROJO)
        filas.append([(s, a)])
    return filas


def g_mirada_llega():
    out = []
    for e in range(6):
        s, a = nuevo(), nuevo()
        if e < 2:
            estrella(a, CX, CY - 12, (14, 8)[e], pe.ROJO)
        for q in range(6):
            ang = q / 6 * math.tau
            pe.punto(a, CX + math.cos(ang) * (3 + e * 2.2), CY - 12 + math.sin(ang) * (2 + e * 1.5) + e, pe.ROJO[2], 2)
        out.append((s, a))
    return [out]


def principal():
    d = {}
    for nom, pal in PALETAS.items():
        d['roce_' + nom] = guardar('roce_' + nom, g_roce(pal), 12.0, 5)
        d['polvo_' + nom] = guardar('polvo_' + nom, g_polvo(pal), 12.0)
    d['velo'] = guardar('velo', g_velo, 12.0)
    d['miedo'] = guardar('miedo', g_miedo, 12.0)
    d['aleteo_polvo'] = guardar('aleteo_polvo', g_aleteo(), 14.0, 5, origen=A)
    d['cono_oro'] = guardar('cono_oro', g_cono(pe.VIGILIA, pe.ORO), 13.0, 5, origen=A)
    d['cono_ceniza'] = guardar('cono_ceniza', g_cono(pe.MORTAJA, pe.CENIZA), 13.0, 5, origen=A)
    d['cono_negro'] = guardar('cono_negro', g_cono(pe.INSOMNE, pe.NEGRO), 13.0, 5, origen=A)
    d['ojo_carga'] = guardar('ojo_carga', g_ojo_carga(), 12.0, 1, True, origen=A)
    d['ojo'] = guardar('ojo', g_ojo, 12.0, origen=A)
    for nom in ('polvo', 'oro', 'ceniza'):
        d['anillo60_' + nom] = guardar('anillo60_' + nom, g_anillo(60.0, PALETAS[nom], 10), 10.0)
    d['anillo70_rojo'] = guardar('anillo70_rojo', g_anillo(70.0, pe.ROJO, 11), 12.0)
    d['lluvia'] = guardar('lluvia', g_lluvia, 12.0)
    d['amortajarse'] = guardar('amortajarse', g_amortajarse, 10.0, origen=A)
    d['insomnio'] = guardar('insomnio', g_insomnio, 10.0, origen=A)
    d['mirada'] = guardar('mirada', g_mirada, 12.0, origen=A)
    d['mirada_bola'] = guardar('mirada_bola', g_mirada_bola, 10.0, 5)
    d['mirada_llega'] = guardar('mirada_llega', g_mirada_llega, 12.0)
    ho.apuntar(LA, d)


if __name__ == '__main__':
    principal()
