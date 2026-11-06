"""Vuelca las cadenas que parecen VISIBLES de los .gd (pase de textos de menus y avisos).

Uso: python -I tools/volcar_cadenas_ui.py [archivo_o_carpeta ...] [--salida ruta.txt]
Sin argumentos mira scripts/ui. Saca "archivo:linea  cadena", saltando comentarios, rutas,
identificadores (snake_case), prints y depuracion. Es una criba: puede colar alguna clave interna
y dejarse alguna frase hecha a trozos; sirve para leerlo todo de una vez, no para cambiar a ciegas.
"""
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Llamadas cuyas cadenas no ve el jugador.
NO_VISIBLE = re.compile(
    r"\b(print|prints|printerr|print_debug|push_warning|push_error|assert|get_node|get_node_or_null|"
    r"has_node|find_child|preload|load|has_method|emit_signal|connect|disconnect|call|call_deferred|"
    r"set_meta|get_meta|has_meta|remove_meta|is_in_group|add_to_group|get_nodes_in_group|"
    r"add_theme_[a-z_]+|get_theme_[a-z_]+|has_theme_[a-z_]+|Input\.is_action[a-z_]*|is_action[a-z_]*|"
    r"set_shader_parameter|tween_property|tween_method|Log\.d|_dbg|_log_dbg|DebugLog\.[a-z_]+|"
    r"ResourceLoader\.[a-z_]+|FileAccess\.[a-z_]+|DirAccess\.[a-z_]+|ClassDB\.[a-z_]+|"
    r"rpc[a-z_]*|Steam\.[a-z_]+|OS\.[a-z_]+)\s*\("
)
CADENA = re.compile(r'(?<![&^])"((?:[^"\\]|\\.)*)"')
IDENT = re.compile(r"^[a-z0-9_./:%-]*$")
ACENTO = re.compile(r"[áéíóúñÁÉÍÓÚÑ¿¡]")


def quitar_comentario(linea: str) -> str:
    """Corta el # que no este dentro de una cadena."""
    dentro = False
    i = 0
    while i < len(linea):
        c = linea[i]
        if c == "\\" and dentro:
            i += 2
            continue
        if c == '"':
            dentro = not dentro
        elif c == "#" and not dentro:
            return linea[:i]
        i += 1
    return linea


def parece_visible(s: str) -> bool:
    t = s.strip()
    if len(t) < 2 or not re.search(r"[A-Za-záéíóúñÁÉÍÓÚÑ]", t):
        return False
    if t.startswith(("res://", "user://", "uid://", "http", "%s" * 0 + "/root")):
        return False
    if IDENT.match(t) and not ACENTO.search(t):
        return False  # clave interna: "espada_larga", "ui_accept"
    if re.match(r"^[A-Z0-9_]+$", t):
        return False  # CONSTANTE
    if re.match(r"^[A-Za-z]+(/[A-Za-z0-9_]+)+$", t):
        return False  # ruta de nodo
    if re.match(r"^#?[0-9a-fA-F]{6,8}$", t):
        return False  # color
    return True


def cadenas_del_texto(texto: str):
    """(linea_de_inicio, contenido) de cada cadena "..." del archivo, aunque ocupe varias lineas.
    Salta comentarios (#) y las cadenas &"..." / ^"..." (StringName y NodePath)."""
    i, n, linea = 0, len(texto), 1
    while i < n:
        c = texto[i]
        if c == "\n":
            linea += 1
        elif c == "#":
            while i < n and texto[i] != "\n":
                i += 1
            continue
        elif c == '"':
            triple = texto.startswith('"""', i)
            previo = texto[i - 1] if i > 0 else ""
            fin_tok = '"""' if triple else '"'
            j = i + len(fin_tok)
            ini = linea
            while j < n and not texto.startswith(fin_tok, j):
                if texto[j] == "\\":
                    j += 1
                elif texto[j] == "\n":
                    linea += 1
                j += 1
            contenido = texto[i + len(fin_tok):j]
            if not triple and previo not in "&^":
                yield ini, contenido
            i = j + len(fin_tok)
            continue
        i += 1


def volcar(ruta: str, salida: list) -> None:
    rel = os.path.relpath(ruta, RAIZ).replace("\\", "/")
    with open(ruta, encoding="utf-8") as f:
        texto = f.read()
    lineas = texto.split("\n")
    por_linea: dict = {}
    for n, s in cadenas_del_texto(texto):
        cod = quitar_comentario(lineas[n - 1])
        if NO_VISIBLE.search(cod):
            continue
        if re.match(r"^\s*(signal|class_name|extends|@export|const\s+[A-Z_]+\s*:=\s*preload)", cod):
            continue
        if parece_visible(s):
            por_linea.setdefault(n, []).append(s.replace("\n", "⏎"))
    for n in sorted(por_linea):
        salida.append(f"{rel}:{n}\t" + "  |  ".join(por_linea[n]))


def main() -> None:
    args = sys.argv[1:]
    destino = None
    if "--salida" in args:
        i = args.index("--salida")
        destino = args[i + 1]
        del args[i:i + 2]
    if not args:
        args = [os.path.join(RAIZ, "scripts", "ui")]
    salida: list = []
    for a in args:
        a = a if os.path.isabs(a) else os.path.join(RAIZ, a)
        if os.path.isdir(a):
            for base, _dirs, archivos in os.walk(a):
                for nombre in sorted(archivos):
                    if nombre.endswith(".gd") and nombre != "debug_panel.gd":
                        volcar(os.path.join(base, nombre), salida)
        else:
            volcar(a, salida)
    texto = "\n".join(salida) + "\n"
    if destino:
        with open(destino, "w", encoding="utf-8") as f:
            f.write(texto)
        print(f"{len(salida)} lineas -> {destino}")
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stdout.write(texto)


if __name__ == "__main__":
    main()
