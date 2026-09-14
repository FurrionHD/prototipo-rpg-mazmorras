"""Comprueba que toda referencia a Net.<x> y Net.<tema>.<x> (y dentro de net.gd, <tema>.<x>) apunte a algo
que EXISTE. Godot no lo mira al compilar (Net es un autoload: las llamadas son dinamicas)."""
import os, re, glob

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NETDIR = os.path.join(RAIZ, "scripts", "net")
DEF = re.compile(r"^(?:static\s+)?(?:func|var|const|signal)\s+(\w+)", re.M)
# lo que un Node ya trae de serie (y se usa via Net.)
NODO = {"multiplayer", "get_tree", "get", "set", "has_method", "call", "call_deferred", "rpc", "rpc_id",
        "add_child", "get_node", "get_node_or_null", "name", "process_mode", "is_inside_tree", "connect",
        "emit_signal", "get_children", "queue_free", "set_process", "set_physics_process", "get_parent",
        "create_tween", "has_signal", "is_connected", "disconnect"}


def defs(path):
    return set(DEF.findall(open(path, encoding="utf-8").read()))


net_defs = defs(os.path.join(NETDIR, "net.gd"))
# temas: var <tema>: <Clase> = null  +  const <Clase> = preload("res://scripts/net/<archivo>")
net_txt = open(os.path.join(NETDIR, "net.gd"), encoding="utf-8").read()
clases = dict(re.findall(r'^const (\w+) = preload\("res://scripts/net/(\w+\.gd)"\)', net_txt, re.M))
temas = {}
for nombre, clase in re.findall(r"^var (\w+): (\w+) = null", net_txt, re.M):
    if clase in clases:
        temas[nombre] = defs(os.path.join(NETDIR, clases[clase]))
temas["_trab"] = defs(os.path.join(NETDIR, "trabajadores.gd"))

fallos = 0
archivos = glob.glob(os.path.join(RAIZ, "scripts", "**", "*.gd"), recursive=True) + glob.glob(os.path.join(RAIZ, "tools", "prueba_*.gd"))


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


for f in archivos:
    rel = os.path.relpath(f, RAIZ)
    es_net = os.path.abspath(f) == os.path.abspath(os.path.join(NETDIR, "net.gd"))
    for n, l in enumerate(open(f, encoding="utf-8").read().split("\n"), 1):
        codigo = sin_comentario(l)
        for m in re.finditer(r"\bNet\.(\w+)(?:\.(\w+))?", codigo):
            a, b = m.group(1), m.group(2)
            if a in temas:
                if b and b not in temas[a] and b not in NODO:
                    print("%s:%d  Net.%s.%s NO EXISTE" % (rel, n, a, b)); fallos += 1
            elif a not in net_defs and a not in NODO:
                print("%s:%d  Net.%s NO EXISTE" % (rel, n, a)); fallos += 1
        if es_net:
            for m in re.finditer(r"(?<![\w.])(\w+)\.(\w+)", codigo):
                a, b = m.group(1), m.group(2)
                if a in temas and b not in temas[a] and b not in NODO:
                    print("%s:%d  %s.%s NO EXISTE" % (rel, n, a, b)); fallos += 1

# dentro de cada tema: nombres sueltos que eran de net.gd y se quedaron sin "Net."
for tema, clase in [(t, c) for t, c in re.findall(r"^var (\w+): (\w+) = null", net_txt, re.M) if c in clases]:
    path = os.path.join(NETDIR, clases[clase])
    propios = defs(path)
    txt = open(path, encoding="utf-8").read().split("\n")
    for n, l in enumerate(txt, 1):
        codigo = sin_comentario(l)
        for m in re.finditer(r"(?<![\w.\"'])(_\w+)\b", codigo):
            x = m.group(1)
            if x in net_defs and x not in propios and not re.search(r"\b(var|for)\s+" + x + r"\b", codigo):
                print("%s:%d  '%s' es de Net y no lleva Net." % (os.path.relpath(path, RAIZ), n, x)); fallos += 1

print("VERIFICACION:", "limpia" if fallos == 0 else "%d problemas" % fallos)
