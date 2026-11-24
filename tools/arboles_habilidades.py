# ============================================================
#  arboles_habilidades.py
#  ESCRIBE LOS ARBOLES DE MEJORAS de las habilidades en sus fichas (.tres), a partir de la tabla de abajo (24/11, los
#  arboles que se cierran con el jefe arma a arma; memoria empezar-habilidades-24-11).
#
#      python tools/arboles_habilidades.py            # todas las de la tabla
#      python tools/arboles_habilidades.py rafaga     # solo esa
#
#  Cada nodo: id, nivel, padres, excluye, nombre, sabor y cambios. Los numeros NO van en el sabor: la ficha del nodo los
#  saca de los datos (antes -> despues). El dinero del presupuesto va con ("presupuesto", parte): parte = lo que se lleva
#  ese nodo del +40 % de su nivel (0,75 = 30 de 40). Ver Mejoras.presupuesto.
#
#  Lo que pide cada nodo sale de su NIVEL: dominio 300 por nivel por encima del 1 (tramos de 25 por piso) y el oro de
#  ORO_POR_NIVEL (PROVISIONAL: calibrarlo con el oro que se lleva en cada piso).
#
#  Escribe con saltos de linea LF (memoria python-escribe-crlf) y deja el resto de la ficha como estaba: solo quita los
#  sub-recursos NM_* viejos y la linea 'arbol = [...]' (con su comentario de encima) y pone los nuevos.
# ============================================================
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DOMINIO_POR_NIVEL = 300
ORO_POR_NIVEL = {2: 2000, 3: 8000, 4: 25000, 5: 70000}

P = "presupuesto"
SANGRADO = 1
CEGUERA = 33
VULNERABLE = 5   # el "Expuesto" de los textos
NV3_DESAP = ["humo_espeso", "humo_todos", "salir_sombras", "escabullirse"]

ARBOLES = {
    "rafaga": [
        # Nv2: muchos enemigos o uno solo. Los tajos de mas por enemigo van +-25 % en DAÑO por enemigo de mas (no en
        # tajos: el de hoja fina vale el doble), asi que van x(1,25/0,75) y x(0,75/1,5); mas tajos sube el tope a 12.
        # HOJA FINA DESTACA A UNO (el jefe, "cada una con su identidad"): su tajo vale x1,8 (x1,5 de la forma y +20 % que
        # paga perdiendo area) y su nivel 2 se lleva lo mismo que mas tajos: a un enemigo +20 % en todos los niveles.
        # CON DOS DAGAS (el jefe: "y en dual?"): la 2a mano pega lo que le queda tras los de la principal; para guardar la
        # misma relacion que con una, mas tajos 7 golpes con la 2a al 53 % y hoja fina 4 con la 2a al 40 %.
        ("mas_tajos", 2, [], ["hoja_fina"], "Más tajos",
         "El brazo no para: caen más tajos, aunque ninguno entra hondo.",
         {"golpes_min": ("add", 1), "golpes_max": ("add", 1), "golpes_dual_min": ("add", 2), "golpes_dual_max": ("add", 2),
          "dual_golpe_mult": ("set", 1.6 / 3.0), "golpes_extra_por_enemigo": ("mult", 1.25 / 0.75),
          "golpes_extra_por_enemigo_dual": ("set", 3.0), "golpes_extra_max": ("set", 12),
          "dano_mult": ("mult", 0.75), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        ("hoja_fina", 2, [], ["mas_tajos"], "Hoja fina",
         "Menos tajos, pero cada uno entra hasta el hueso.",
         {"golpes_min": ("add", -1), "golpes_max": ("add", -1), "golpes_dual_min": ("add", -1), "golpes_dual_max": ("add", -1),
          "dual_golpe_mult": ("set", 0.4), "golpes_extra_por_enemigo": ("set", 0.5),
          "golpes_extra_por_enemigo_dual": ("set", 1.0),
          "dano_mult": ("mult", 1.8), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        # Nv3, lado de los muchos tajos
        ("remolino", 3, ["mas_tajos"], ["brazo_largo"], "Remolino",
         "Giras sobre ti mismo y la hoja pasa por todo lo que te rodea.",
         {"forma_apertura": ("set", 360.0), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("brazo_largo", 3, ["mas_tajos"], ["remolino"], "Brazo largo",
         "Estiras el brazo y alcanzas a los que se creían a salvo detrás.",
         {"forma_radio": ("add", 20.0), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        # Nv3, lado de la hoja fina
        ("mil_cortes", 3, ["hoja_fina"], ["entrar_bailando"], "Mil cortes",
         "Cortes que no matan, pero que no dejan de sangrar.",
         {"efectos_prob_mult": ("set", 0.38 / 0.22), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        ("entrar_bailando", 3, ["hoja_fina"], ["mil_cortes"], "Entrar bailando",
         "No esperas a que se acerquen: entras tú.",
         {"acercarse": ("add", 60.0), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        # Nv4, cada uno en su lado
        ("persiguen", 4, ["remolino", "brazo_largo"], [], "Tajos que persiguen",
         "Cuando uno cae, la hoja ya va hacia el siguiente, y con más ganas.",
         {"bonus_por_baja": ("set", 0.15), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        ("remate", 4, ["mil_cortes", "entrar_bailando"], [], "Remate",
         "El último tajo busca la herida que abrieron los primeros.",
         {"remate_estado": ("set", SANGRADO), "remate_mult": ("set", 1.5), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        # Nv5: se llega desde cualquiera de los dos lados. (24/11, muñecos: frenesi iba siempre detras de la ligera -la
        # energia frena, no el enfriamiento-: se lleva 30 de 40 en vez de 15; remate x2 se pasaba con 2 tajos: x1,5)
        ("frenesi", 5, ["persiguen", "remate"], ["ligera"], "Frenesí",
         "Acabas una ráfaga y el brazo ya pide la siguiente.",
         {"cooldown": ("add", -1), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        ("ligera", 5, ["persiguen", "remate"], ["frenesi"], "Ráfaga ligera",
         "Menos fuerza en cada tajo y menos aliento en cada ráfaga.",
         {"potencia": (P, 0.625), "potencia_coste": (P, 0.375)}),
    ],
    # PUÑALADA CERTERA (24/11): base 240 %, un tajo (dos con dos dagas), sangrado 55 % y 2a herida si critea 30 %.
    "punalada": [
        # Nv2: critico o sangre
        ("punto_debil", 2, [], ["herida_abierta"], "Punto débil",
         "Sabes dónde mirar antes de clavar.",
         {"crit_extra": ("add", 0.2), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("herida_abierta", 2, [], ["punto_debil"], "Herida abierta",
         "La hoja no sale limpia: sale arrastrando.",
         {"efectos_prob_mult": ("set", 1.651), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        # Nv3, lado del critico
        ("hasta_el_mango", 3, ["punto_debil"], ["por_la_espalda"], "Hasta el mango",
         "Cuando entra bien, no te paras a medias.",
         {"crit_dano_mult": ("set", 1.3), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        ("por_la_espalda", 3, ["punto_debil"], ["hasta_el_mango"], "Por la espalda",
         "Donde no mira, no se defiende.",
         {"extra_espalda": ("add", 0.3), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        # Nv3, lado de la sangre (Arteria -> Desangrar, el combo del jefe)
        ("arteria", 3, ["herida_abierta"], ["mano_segura"], "Arteria",
         "Buscas la vena gorda, la que no para.",
         {"efectos_cargas_extra": ("set", 1), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        ("mano_segura", 3, ["herida_abierta"], ["arteria"], "Mano segura",
         "Ni rápida ni bonita: segura.",
         {"infalible": ("set", True), "potencia": (P, 0.25), "potencia_coste": (P, 1.0)}),
        # Nv4: desde cualquiera de los cuatro del nivel 3
        ("asesinato", 4, ["hasta_el_mango", "por_la_espalda", "arteria", "mano_segura"], ["desangrar"], "Asesinato",
         "A los que ya se tambalean no les das tiempo a levantarse.",
         {"bonus_vida_baja": ("set", 0.4), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        ("desangrar", 4, ["hasta_el_mango", "por_la_espalda", "arteria", "mano_segura"], ["asesinato"], "Desangrar",
         "Abres lo que ya estaba abierto, y sale todo de una vez.",
         {"detona_estado": ("set", SANGRADO), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        # Nv5: desde cualquiera de los dos del nivel 4
        ("ejecucion", 5, ["asesinato", "desangrar"], ["golpe_y_fuera"], "Ejecución",
         "Uno menos, y la mano ya está lista para el siguiente.",
         {"recarga_al_matar": ("set", True), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("golpe_y_fuera", 5, ["asesinato", "desangrar"], ["ejecucion"], "Golpe y fuera",
         "Clavas, sueltas y ya no estás.",
         {"se_aparta": ("add", 40.0), "potencia": (P, 0.875), "potencia_coste": (P, 1.0)}),
    ],
    # DESAPARECER (24/11): base una puñalada del 60 % a cada enemigo a 64 px, Sigilo 3 turnos, 34 EN, enfriamiento 5.
    "desaparecer": [
        # Nv2: mas nube o puñalada a fondo (su contrario)
        ("nube_grande", 2, [], ["a_fondo"], "Nube más grande",
         "Más humo, más sitio donde perderte.",
         {"forma_radio": ("add", 21.0), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("a_fondo", 2, [], ["nube_grande"], "Puñalada a fondo",
         "Menos gente alrededor, pero a cada uno se la clavas entera.",
         {"forma_radio": ("add", -16.0), "potencia": (P, 1.5), "potencia_coste": (P, 1.0)}),
        # Nv3, lado de la nube
        ("humo_espeso", 3, ["nube_grande"], ["humo_todos"], "Humo espeso",
         "El humo no se va: se queda pegado al suelo y a los ojos.",
         {"nube_turnos": ("set", 2), "nube_estado": ("set", CEGUERA), "nube_prob": ("set", 0.7),
          "potencia": (P, 0.375), "potencia_coste": (P, 1.0)}),
        ("humo_todos", 3, ["nube_grande"], ["humo_espeso"], "Humo para todos",
         "Nadie dijo que la nube fuera solo tuya.",
         {"oculta_aliados_turnos": ("set", 2), "potencia": (P, 0.375), "potencia_coste": (P, 1.0)}),
        # Nv3, lado de la puñalada
        ("salir_sombras", 3, ["a_fondo"], ["escabullirse"], "Salir de las sombras",
         "Lo primero que ven es la hoja.",
         {"sigilo_golpe": ("set", 0.3), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("escabullirse", 3, ["a_fondo"], ["salir_sombras"], "Escabullirse",
         "Cuando el humo se aclara, ya no estás donde te dejaron.",
         {"se_mueve": ("add", 60.0), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        # Nv4: desde cualquiera de los cuatro
        ("desvio", 4, NV3_DESAP, ["pies_niebla"], "Desvío",
         "Te buscaban a ti. Ya no se acuerdan de por qué.",
         {"desvia_amenaza": ("set", True), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        ("pies_niebla", 4, NV3_DESAP, ["desvio"], "Pies en la niebla",
         "Entre el humo, cada paso cae donde no miran.",
         {"sigilo_esquiva": ("set", 0.15), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        # Nv5: desde cualquiera de los dos
        ("sombra_larga", 5, ["desvio", "pies_niebla"], ["recarga"], "Sombra larga",
         "Te cuesta más salir que entrar.",
         {"efectos_turnos_extra": ("set", 1), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("recarga", 5, ["desvio", "pies_niebla"], ["sombra_larga"], "Recarga en las sombras",
         "Mientras nadie te ve, recuperas el aliento.",
         {"sigilo_energia": ("set", 0.08), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
    ],
    # OPORTUNISTA (24/11): el SALTO (70 %, +30 % de critico) es lo que sube su arbol; los SEGUIMIENTOS son un basico al
    # 75 % FIJO (el jefe: escalan con el basico), salvo Entrar a fondo. 5 entradas a 150 px, 44 EN (dual 60), enfr. 6.
    "oportunista": [
        ("mas_huecos", 2, [], ["entrar_fondo"], "Más huecos",
         "Cada vez ves más sitios por donde colarte.",
         {"oport_usos": ("set", 7), "potencia": (P, 0.25), "potencia_coste": (P, 1.0)}),
        ("entrar_fondo", 2, [], ["mas_huecos"], "Entrar a fondo",
         "Entras menos veces, pero cuando entras no vuelves con las manos vacías.",
         {"oport_usos": ("set", 4), "oport_seguimiento": ("set", 1.0), "potencia": (P, 1.0), "potencia_coste": (P, 1.0)}),
        ("ojo_halcon", 3, ["mas_huecos"], ["critico_cadena"], "Ojo de halcón",
         "Ves el hueco desde más lejos.",
         {"oport_alcance": ("set", 200.0), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        ("critico_cadena", 3, ["mas_huecos"], ["ojo_halcon"], "Crítico en cadena",
         "Un buen golpe te abre el siguiente hueco.",
         {"oport_cadena": ("set", 3), "potencia": (P, 0.375), "potencia_coste": (P, 1.0)}),
        ("llegar_matando", 3, ["entrar_fondo"], ["desequilibrar"], "Llegar matando",
         "El primer golpe es el que más duele.",
         {"potencia": (P, 1.25), "potencia_coste": (P, 1.0)}),
        ("desequilibrar", 3, ["entrar_fondo"], ["llegar_matando"], "Desequilibrar",
         "Caes encima y le dejas sin pies.",
         {"estado_golpe": ("set", VULNERABLE), "estado_golpe_prob": ("set", 1.0), "estado_golpe_turnos": ("set", 1),
          "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("sin_rastro", 4, ["ojo_halcon", "critico_cadena", "llegar_matando", "desequilibrar"], ["aprovechado"],
         "Sin dejar rastro", "Entras, cortas y te vuelves sombra.",
         {"oport_oculto": ("set", 1), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("aprovechado", 4, ["ojo_halcon", "critico_cadena", "llegar_matando", "desequilibrar"], ["sin_rastro"],
         "Aprovechado", "Lo que otros abren, tú lo cobras.",
         {"oport_energia": ("set", 0.04), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("salto_largo", 5, ["sin_rastro", "aprovechado"], ["entrar_dos"], "Salto largo",
         "Ninguna espalda queda demasiado lejos.",
         {"forma_rango": ("add", 50.0), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        ("entrar_dos", 5, ["sin_rastro", "aprovechado"], ["salto_largo"], "Entrar los dos",
         "Las dos hojas entran por el mismo hueco.",
         {"oport_dual_entero": ("set", True), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
    ],
    # FILO EMPONZOÑADO (24/11): no pega; su "daño" es la FUERZA DEL VENENO (imbue_fuerza, donde va la potencia). Impregna 5
    # ataques, prob. base 70 % (con Destreza), el tipo y las dosis por el tier del arma, 36 EN, enfriamiento 5.
    "filo_emponzonado": [
        ("agarra_mejor", 2, [], ["mas_usos"], "Agarra mejor",
         "Lo dejas secar un momento más y ya no se va con el primer golpe.",
         {"imbue_prob": ("set", 0.85), "potencia": (P, 0.25), "potencia_coste": (P, 1.0)}),
        ("mas_usos", 2, [], ["agarra_mejor"], "Más usos",
         "Más frasco en el filo, para más golpes.",
         {"imbue_usos": ("set", 7), "potencia": (P, 0.125), "potencia_coste": (P, 1.0)}),
        ("dosis_cargadas", 3, ["agarra_mejor"], ["veneno_fuerte"], "Dosis cargadas",
         "Cada corte deja más veneno dentro.",
         {"imbue_peldano": ("set", 1), "potencia": (P, 0.125), "potencia_coste": (P, 1.0)}),
        ("veneno_fuerte", 3, ["agarra_mejor"], ["dosis_cargadas"], "Veneno fuerte",
         "Un frasco más turbio que el anterior.",
         {"potencia": (P, 1.0), "potencia_coste": (P, 1.0)}),
        ("compartir", 3, ["mas_usos"], ["mano_rapida"], "Compartir el frasco",
         "Sobra veneno: que lo pruebe también el de al lado.",
         {"imbue_comparte_usos": ("set", 3), "potencia": (P, 0.125), "potencia_coste": (P, 1.0)}),
        ("mano_rapida", 3, ["mas_usos"], ["compartir"], "Mano rápida",
         "Destapas, untas y tapas sin mirar.",
         {"cooldown": ("add", -1), "potencia": (P, 0.25), "potencia_coste": (P, 1.0)}),
        ("acido", 4, ["dosis_cargadas", "veneno_fuerte", "compartir", "mano_rapida"], ["ponzona_sangre"], "Ácido",
         "No solo envenena: también se come la armadura.",
         {"imbue_acido": ("set", 0.04), "potencia": (P, 0.25), "potencia_coste": (P, 1.0)}),
        ("ponzona_sangre", 4, ["dosis_cargadas", "veneno_fuerte", "compartir", "mano_rapida"], ["acido"], "Ponzoña y sangre",
         "Por una herida abierta, el veneno corre más deprisa.",
         {"imbue_con_sangre": ("set", 0.15), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("toxina", 5, ["acido", "ponzona_sangre"], ["senal"], "Toxina que revienta",
         "Cuando ya no cabe más veneno, sale todo de golpe.",
         {"imbue_revienta": ("set", True), "potencia": (P, 0.25), "potencia_coste": (P, 1.0)}),
        ("senal", 5, ["acido", "ponzona_sangre"], ["toxina"], "Señal del veneno",
         "Sabes quién va a caer, y eso te da aire.",
         {"imbue_senal": ("set", 0.05), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
    ],
}


def _valor(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(round(v, 6))
    return '"%s"' % v


def _cambios(c: dict) -> str:
    return "{" + ", ".join('"%s": ["%s", %s]' % (k, op, _valor(v)) for k, (op, v) in c.items()) + "}"


def _nombres(xs) -> str:
    return "Array[StringName]([%s])" % ", ".join('&"%s"' % x for x in xs)


def _sub(clave: str, n) -> tuple:
    nid, nivel, padres, excluye, nombre, sabor, cambios = n
    sid = "NM_%s_%s" % (clave[:3], nid)
    txt = "\n".join([
        '[sub_resource type="Resource" id="%s"]' % sid,
        'script = ExtResource("nodo_mejora")',
        'id = &"%s"' % nid,
        'nombre = "%s"' % nombre,
        'descripcion = "%s"' % sabor,
        "padres = " + _nombres(padres),
        "excluye = " + _nombres(excluye),
        "nivel_min = %d" % nivel,
        "dominio = %d" % (DOMINIO_POR_NIVEL * (nivel - 1)),
        "oro = %d" % ORO_POR_NIVEL.get(nivel, 0),
        "cambios = " + _cambios(cambios),
    ])
    return sid, txt


def escribir(clave: str) -> None:
    ruta = RAIZ / "resources" / "abilities" / (clave + ".tres")
    t = ruta.read_text(encoding="utf-8")
    # Fuera los nodos viejos (cada bloque [sub_resource ... id="NM_..."] hasta el siguiente '[').
    t = re.sub(r'\[sub_resource type="Resource" id="NM_[^"]*"\]\n(?:[^\[\n].*\n|\n)*', "", t)
    # Fuera la linea del arbol y los comentarios ';' justo encima.
    t = re.sub(r"(?m)^(?:;[^\n]*\n)*arbol = \[[^\n]*\]\n", "", t)
    if 'id="nodo_mejora"' not in t:
        # detras de la ULTIMA referencia externa (una ficha sin sub-recursos no tiene donde engancharla si no)
        ultima = list(re.finditer(r"\[ext_resource [^\n]*\]\n", t))[-1]
        t = t[:ultima.end()] + '[ext_resource type="Script" path="res://scripts/items/nodo_mejora.gd" id="nodo_mejora"]\n' \
            + t[ultima.end():]
    subs = [_sub(clave, n) for n in ARBOLES[clave]]
    bloque = "".join(s[1] + "\n\n" for s in subs)
    i = t.index("[resource]")
    t = t[:i] + bloque + t[i:]
    linea = ("; EL ARBOL (24/11, cerrado con el jefe): lo escribe tools/arboles_habilidades.py, no tocarlo a mano.\n"
             "arbol = [" + ", ".join('SubResource("%s")' % s[0] for s in subs) + "]\n")
    t = t.rstrip("\n") + "\n" + linea
    t = re.sub(r"\n{3,}", "\n\n", t)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write(t)
    print("%s: %d nodos" % (ruta.relative_to(RAIZ), len(subs)))


if __name__ == "__main__":
    for clave in (sys.argv[1:] or list(ARBOLES)):
        escribir(clave)
