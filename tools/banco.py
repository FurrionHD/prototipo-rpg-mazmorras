#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
banco.py -- pasa la BATERIA ENTERA en un worktree aparte (../prm-banco) sobre un commit, para poder seguir trabajando
mientras tanto (lo pidio el jefe el 29/10/2026: "si no perdemos un monton de tiempo").

  python tools/banco.py                 # la bateria entera sobre HEAD de este worktree
  python tools/banco.py 24cc899d        # sobre ese commit
  python tools/banco.py HEAD sala town  # solo las que contengan esas palabras (como pasar_pruebas.py)
  python tools/banco.py --hilos 2       # menos a la vez, si hay poca RAM libre (por defecto 3)

COMO VA:
  - El banco es un worktree fijo, ../prm-banco, que no se toca a mano: cada vez se pone en el commit que toca (detached).
    La primera vez se crea y se le copian la cache .godot y tools/huellas/mundo_ref.tres (git no los trae).
  - Lleva un override.cfg con su PROPIA carpeta de usuario (DungeonOratoria_banco): las partidas, logs e identidades de
    sus pruebas no se cruzan con las de aqui.
  - Mientras corre deja un cerrojo (../prm-banco.en_marcha, con su pid). pasar_pruebas.py lo mira: con el banco en
    marcha, aqui NO se lanzan las de red (usan puertos fijos y se pisarian).
  - El resultado entero se queda en tools/resultados_pruebas/banco_<commit>.txt de ESTE worktree, y sale con 0 solo si
    todas salen bien.

LA REGLA (29/10): rapidas antes del commit local; la bateria en el banco sobre ese commit; nada sube ni se junta a main
sin su bateria en verde. Si falla, se arregla con un commit encima y se vuelve a pasar.
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BANCO = RAIZ.parent / "prm-banco"
CERROJO = RAIZ.parent / "prm-banco.en_marcha"
OVERRIDE = """; Solo en el banco de pruebas (tools/banco.py): su propia carpeta de usuario, para no cruzarse con el worktree de
; trabajo. Ignorado por git.
[application]
config/custom_user_dir_name="DungeonOratoria_banco"
"""


def git(*a, cwd: Path = RAIZ, check: bool = True) -> str:
    p = subprocess.run(["git", *a], cwd=str(cwd), capture_output=True, text=True)
    if check and p.returncode != 0:
        raise SystemExit("git %s: %s" % (" ".join(a), p.stderr.strip()))
    return p.stdout.strip()


def pid_vivo(pid: int) -> bool:
    if pid <= 0:
        return False
    if os.name == "nt":
        out = subprocess.run(["tasklist", "/FI", "PID eq %d" % pid], capture_output=True, text=True).stdout
        return str(pid) in out
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def banco_ocupado() -> bool:
    """¿Hay una bateria corriendo en el banco? (lo usa tambien pasar_pruebas.py)"""
    try:
        return pid_vivo(int(CERROJO.read_text().strip()))
    except (OSError, ValueError):
        return False


def preparar(sha: str) -> None:
    if not BANCO.exists():
        print("Creando el banco en %s..." % BANCO)
        git("worktree", "add", "--detach", str(BANCO), sha)
        print("Copiando la cache .godot (la primera vez tarda)...")
        shutil.copytree(RAIZ / ".godot", BANCO / ".godot", dirs_exist_ok=True)
    else:
        git("checkout", "--detach", "--force", sha, cwd=BANCO)
    ref = RAIZ / "tools" / "huellas" / "mundo_ref.tres"
    ref_banco = BANCO / "tools" / "huellas" / "mundo_ref.tres"
    if ref.exists() and (not ref_banco.exists() or ref.stat().st_mtime > ref_banco.stat().st_mtime):
        shutil.copy2(ref, ref_banco)
    (BANCO / "override.cfg").write_text(OVERRIDE, encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Pasa la bateria entera en ../prm-banco sobre un commit.")
    ap.add_argument("commit", nargs="?", default="HEAD")
    ap.add_argument("filtros", nargs="*")
    ap.add_argument("--hilos", type=int, default=3)
    a = ap.parse_args()
    if RAIZ.name == BANCO.name:
        raise SystemExit("banco.py se lanza desde el worktree de trabajo, no desde el banco.")
    if banco_ocupado():
        raise SystemExit("El banco ya esta pasando una bateria (cerrojo %s)." % CERROJO)
    sha = git("rev-parse", a.commit)
    corto = sha[:8]
    print("BANCO: bateria sobre %s (%s)" % (corto, git("log", "-1", "--format=%s", sha)))
    preparar(sha)
    salida = RAIZ / "tools" / "resultados_pruebas" / ("banco_%s.txt" % corto)
    salida.parent.mkdir(parents=True, exist_ok=True)
    CERROJO.write_text(str(os.getpid()))
    try:
        orden = [sys.executable, "-u", str(BANCO / "tools" / "pasar_pruebas.py"), "--hilos", str(a.hilos), *a.filtros]
        with open(salida, "w", encoding="utf-8") as f:
            f.write("BANCO: bateria sobre %s\n" % sha)
            p = subprocess.Popen(orden, cwd=str(BANCO), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, encoding="utf-8", errors="replace")
            for linea in p.stdout:
                f.write(linea)
                f.flush()
                print(linea, end="", flush=True)
            codigo = p.wait()
    finally:
        CERROJO.unlink(missing_ok=True)
    print("\nBANCO %s: %s  (todo en %s)" % (corto, "TODO BIEN" if codigo == 0 else "HAY FALLOS", salida))
    return codigo


if __name__ == "__main__":
    sys.exit(main())
