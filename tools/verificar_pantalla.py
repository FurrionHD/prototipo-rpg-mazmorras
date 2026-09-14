"""Comprueba los TEMAS de una pantalla partida (p. ej. combat.gd + combat_*.gd): toda referencia
_pantalla.x en un tema existe en el host (o es de Control), y toda referencia <tema>.x en el host o en
otro tema existe en ese tema. Godot NO lo comprueba al compilar.
uso: python tools/verificar_pantalla.py scripts/ui/combat.gd"""
import os, re, sys, glob

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOST = os.path.join(RAIZ, sys.argv[1] if len(sys.argv) > 1 else "scripts/ui/combat.gd")
base = os.path.splitext(os.path.basename(HOST))[0]
DEF = re.compile(r"^(?:static\s+)?(?:@onready\s+|@export\s+)?(?:func|var|const|signal|enum)\s+(\w+)", re.M)
CONTROL = set(open(os.path.join(RAIZ, "tools", "miembros_control.txt"), encoding="utf-8").read().split())
EXTRA = {"get", "set", "call", "call_deferred", "has_method", "emit_signal", "connect", "disconnect",
         "is_connected", "has_signal", "get_script", "free", "notification", "set_meta", "get_meta",
         "has_meta", "remove_meta", "is_queued_for_deletion", "Pantalla"}


def sin_comentario(l):
    q = None
    for i, c in enumerate(l):
        if q:
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "#":
            return l[:i]
    return l


host_txt = open(HOST, encoding="utf-8").read()
host_defs = set(DEF.findall(host_txt))
temas = {}
for tema, ruta in re.findall(r'^var (\w+) = \w+\.new\(self\)', host_txt, re.M) and \
        [(t, r) for c, r in re.findall(r'^const (\w+) = preload\("res://([^"]+)"\)', host_txt, re.M)
         for t in re.findall(r'^var (\w+) = ' + c + r'\.new\(self\)', host_txt, re.M)]:
    temas[tema] = os.path.join(RAIZ, ruta)
fallos = 0
tema_defs = {t: set(DEF.findall(open(p, encoding="utf-8").read())) for t, p in temas.items()}
for t, p in temas.items():
    for n, l in enumerate(open(p, encoding="utf-8").read().split("\n"), 1):
        c = sin_comentario(l)
        for m in re.finditer(r"\b_pantalla\.(\w+)(?:\.(\w+))?", c):
            a, b = m.group(1), m.group(2)
            if a in temas:
                if b and b not in tema_defs[a]:
                    print("%s:%d  _pantalla.%s.%s NO EXISTE" % (os.path.basename(p), n, a, b)); fallos += 1
            elif a not in host_defs and a not in CONTROL and a not in EXTRA:
                print("%s:%d  _pantalla.%s NO EXISTE" % (os.path.basename(p), n, a)); fallos += 1
for n, l in enumerate(host_txt.split("\n"), 1):
    c = sin_comentario(l)
    for m in re.finditer(r"(?<![\w.])(\w+)\.(\w+)", c):
        a, b = m.group(1), m.group(2)
        if a in temas and b not in tema_defs[a] and b not in EXTRA:
            print("%s:%d  %s.%s NO EXISTE" % (os.path.basename(HOST), n, a, b)); fallos += 1
print("VERIFICACION %s:" % base, "limpia (%d temas)" % len(temas) if fallos == 0 else "%d problemas" % fallos)
