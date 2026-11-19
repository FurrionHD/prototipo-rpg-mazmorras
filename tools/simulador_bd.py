#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
simulador_bd.py -- LA BASE DE DATOS DEL SIMULADOR (19/11/2026). Un SQLite local con TODAS las tandas que se lancen
(tools/resultados_simulador/simulador.db, ignorado por git), para comparar a lo grande: reglas de hoy contra las nuevas,
un arma contra otra, un piso contra otro...

  python tools/simulador_bd.py                          # que tandas hay
  python tools/simulador_bd.py meter hoy                # mete tools/resultados_simulador/hoy*.csv (simulador.py ya lo hace solo)
  python tools/simulador_bd.py comparar hoy nuevas      # las dos tandas lado a lado: por piso/grupo/escenario y por rol/arma
  python tools/simulador_bd.py sql "select ..."         # cualquier consulta
  python tools/simulador_bd.py borrar prueba1           # quita una tanda

TABLAS (las columnas son las de las lineas R/P/E de simulador_peleas.gd, en minusculas y con '/' cambiado por '_'):
  tandas      tanda, fecha, commit_git, reglas, argumentos, peleas
  peleas      una por pelea (piso, grupo, escenario, enemigo, gana, turnos_yo, turnos_el, vida_perdida, caidos...)
  personajes  una por personaje tuyo y pelea (rol, arma, armadura, stats, daño hecho/recibido, energia, mana, acciones...)
  enemigos    una por enemigo y pelea (vida, ataque, defensa, daño hecho/recibido, turnos, muere...)
Todas llevan 'tanda' y las de personajes/enemigos 'pelea' (para unirlas con su pelea).
"""
import csv
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "tools" / "resultados_simulador"
BD = SALIDA / "simulador.db"
TABLAS = {"peleas": "", "personajes": "_personajes", "enemigos": "_enemigos"}


def _col(n: str) -> str:
    return n.strip().lower().replace("/", "_").replace("º", "").replace(" ", "_") or "x"


def _num(v: str):
    try:
        return float(v) if any(c in v for c in ".eE") else int(v)
    except ValueError:
        return v


def conectar() -> sqlite3.Connection:
    SALIDA.mkdir(parents=True, exist_ok=True)
    bd = sqlite3.connect(str(BD))
    bd.execute("create table if not exists tandas (tanda text primary key, fecha text, commit_git text, reglas text,"
               " argumentos text, peleas integer)")
    return bd


def meter(tanda: str, argumentos: str = "") -> int:
    bd = conectar()
    borrar(tanda, bd, callado=True)
    n_peleas = 0
    reglas = ""
    for tabla, suf in TABLAS.items():
        ruta = SALIDA / ("%s%s.csv" % (tanda, suf))
        if not ruta.exists():
            continue
        with open(ruta, encoding="utf-8") as f:
            r = csv.reader(f, delimiter=";")
            cab = next(r, None)
            if not cab:
                continue
            cols = [_col(c) for c in cab]
            # columnas nuevas que no tenga aun la tabla (el simulador va ganando datos): se añaden
            bd.execute("create table if not exists %s (%s)" % (tabla, ", ".join('"%s"' % c for c in cols)))
            ya = {row[1] for row in bd.execute("pragma table_info(%s)" % tabla)}
            for c in cols:
                if c not in ya:
                    bd.execute('alter table %s add column "%s"' % (tabla, c))
            filas = [[_num(v) for v in fila] + [None] * (len(cols) - len(fila)) for fila in r]
            bd.executemany("insert into %s (%s) values (%s)" % (tabla, ", ".join('"%s"' % c for c in cols),
                ", ".join("?" * len(cols))), [f[:len(cols)] for f in filas])
            if tabla == "peleas":
                n_peleas = len(filas)
                if filas and "reglas" in cols:
                    reglas = str(filas[0][cols.index("reglas")])
    try:
        commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=str(RAIZ), capture_output=True,
                                text=True).stdout.strip()
    except OSError:
        commit = ""
    bd.execute("insert or replace into tandas values (?, ?, ?, ?, ?, ?)",
               (tanda, time.strftime("%Y-%m-%d %H:%M"), commit, reglas, argumentos, n_peleas))
    bd.commit()
    bd.close()
    print("[bd] tanda '%s': %d peleas -> %s" % (tanda, n_peleas, BD))
    return n_peleas


def borrar(tanda: str, bd=None, callado: bool = False) -> None:
    propia = bd is None
    bd = bd or conectar()
    for tabla in list(TABLAS) + ["tandas"]:
        try:
            bd.execute("delete from %s where tanda = ?" % tabla, (tanda,))
        except sqlite3.OperationalError:
            pass
    if propia:
        bd.commit()
        bd.close()
    if not callado:
        print("[bd] borrada la tanda '%s'" % tanda)


def listar() -> None:
    bd = conectar()
    for fila in bd.execute("select tanda, fecha, commit_git, reglas, peleas, argumentos from tandas order by fecha"):
        print("%-20s %s  %-9s %-8s %6d peleas  %s" % fila)
    bd.close()


def sql(consulta: str) -> None:
    bd = conectar()
    cur = bd.execute(consulta)
    cab = [d[0] for d in cur.description] if cur.description else []
    if cab:
        print(" | ".join(cab))
    for fila in cur:
        print(" | ".join("%.3f" % v if isinstance(v, float) else str(v) for v in fila))
    bd.close()


# LAS DOS TANDAS LADO A LADO: lo mismo medido con una y con otra (y la diferencia).
def comparar(a: str, b: str) -> None:
    bd = conectar()
    print("PELEAS: por piso / grupo / escenario  (%s  ->  %s)" % (a, b))
    print("%-34s %15s %15s %17s %15s" % ("", "gana %", "rondas", "vida perdida %", "caen"))
    q = """select piso, grupo, escenario,
              avg(gana = 'GANA') * 100, avg(case when gana = 'GANA' then turnos_yo * 1.0 /
                (case grupo when 'duo' then 2 when 'trio' then 3 when 'cuatro' then 4 else 1 end) end),
              avg(vida_perdida) * 100, avg(caidos)
           from peleas where tanda = ? group by piso, grupo, escenario"""
    da = {r[:3]: r[3:] for r in bd.execute(q, (a,))}
    db = {r[:3]: r[3:] for r in bd.execute(q, (b,))}
    for k in sorted(set(da) | set(db)):
        x = da.get(k, (None,) * 4)
        y = db.get(k, (None,) * 4)
        def par(i, fmt):
            return "%s -> %s" % (fmt % x[i] if x[i] is not None else "  -", fmt % y[i] if y[i] is not None else "  -")
        print("%-34s %15s %15s %17s %15s" % ("piso %2d %-13s %-8s" % k, par(0, "%3.0f"), par(1, "%4.1f"), par(2, "%3.0f"),
                                              par(3, "%.2f")))
    print()
    print("LOS TUYOS: por piso / rol / arma  (daño por turno, recibido por turno enemigo, mitigacion fisica, %% sin energia)")
    q2 = """select piso, rol, arma, sum(dano_hecho) / max(sum(turnos), 1), avg(recibido_por_turno_enemigo),
               avg(mitig_fisica) * 100, sum(turnos_sin_energia) * 100.0 / max(sum(turnos), 1)
            from personajes where tanda = ? group by piso, rol, arma"""
    pa = {r[:3]: r[3:] for r in bd.execute(q2, (a,))}
    pb = {r[:3]: r[3:] for r in bd.execute(q2, (b,))}
    for k in sorted(set(pa) | set(pb)):
        x = pa.get(k, (None,) * 4)
        y = pb.get(k, (None,) * 4)
        def par2(i, fmt):
            return "%s -> %s" % (fmt % x[i] if x[i] is not None else "  -", fmt % y[i] if y[i] is not None else "  -")
        print("  piso %2d %-8s %-12s daño/t %s   recib/t %s   mitF %s%%   sinEN %s%%" % (k + (par2(0, "%5.1f"),
              par2(1, "%5.2f"), par2(2, "%3.0f"), par2(3, "%3.0f"))))
    bd.close()


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass
    a = sys.argv[1:]
    if not a:
        listar()
    elif a[0] == "meter" and len(a) >= 2:
        meter(a[1], " ".join(a[2:]))
    elif a[0] == "borrar" and len(a) >= 2:
        borrar(a[1])
    elif a[0] == "comparar" and len(a) >= 3:
        comparar(a[1], a[2])
    elif a[0] == "sql" and len(a) >= 2:
        sql(" ".join(a[1:]))
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
