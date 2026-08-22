# ============================================================
#  combat_fx.gd  (class_name CombatFX)
#  TODO lo que se MUEVE y BRILLA en la pantalla de combate. Vive aparte de combat.gd por dos
#  razones: ese archivo ya pasa de 5800 lineas, y porque esto es una capa PASIVA -- no decide
#  nada de la pelea, solo pinta lo que le cuentan.
#
#  Hace cuatro cosas, y las cuatro cuelgan de las TARJETAS que crea _crear_bloque:
#
#   1. ESTADOS       particulas y tinte del recuadro segun lo que sufre cada uno (arde si esta
#                    quemado, centellea si esta pegajoso, borde dorado si esta potenciado).
#   2. BARRAS        la vida no salta: se desliza hasta su destino.
#   3. IMPACTOS      la tarjeta del atacante EMBISTE a la del objetivo, pum, y la otra tiembla.
#   4. NUMEROS       el daño flotando encima de quien lo ha comido.
#
#  DOS DECISIONES DE FONDO, las dos con motivo:
#
#  * NADA de Tween ni de await, todo se evalua en _process restando delta. Es el mismo motor que
#    ya lleva el combate (_pause_left) y, sobre todo, hace IMPOSIBLE el bug feo: con un await vivo,
#    la tecla P (_desatascar) puede forzar el estado del turno por debajo de la corrutina y dejarte
#    un turno duplicado o perdido. Una cola pasiva que solo pinta no puede romper el orden de turnos
#    ni queriendo.
#
#  * Los estados se leen del ARRAY DE CHIPS YA RESUELTO, nunca de c.has_status(). En multijugador
#    el que ESPEJA la pelea tiene maniquis con statuses vacio: lo unico que le llega son los chips
#    que resolvio el anfitrion (ver _chips_de en combat.gd). Leyendo de ahi, esto funciona igual en
#    las dos pantallas y sin mandar un solo byte de mas.
#
#  Todo nodo que cuelgue de aqui va en PROCESS_MODE_ALWAYS. En SOLITARIO el arbol del juego esta
#  PAUSADO durante el combate y en multijugador NO (ver game.gd, _modal_stack): sin eso, los
#  efectos funcionan con un compañero y se quedan congelados jugando solo.
# ============================================================

extends Node
class_name CombatFX

# El tinte de un recuadro ha cambiado. Se avisa por señal en vez de repintar el estilo aqui:
# quien sabe si esa tarjeta esta SELECCIONADA (borde blanco) o APAGADA (cadaver gris) es
# combat.gd, y el stylebox tiene que salir de un solo sitio o el borde de seleccion se perderia
# en cuanto te entrara un veneno.
signal tinte_cambiado(bloque: Dictionary)

# A esta tarjeta ya le ha caido el ULTIMO golpe que tenia pendiente, asi que ya se puede apagar
# (el gris del cadaver). Existe porque los muertos se rematan al final de la accion, o sea antes
# de que la animacion haya reproducido un solo golpe: sin esto el bicho se ponia gris y despues
# le llegaba volando el hechizo que lo mataba.
signal apagar_ahora(bloque: Dictionary)

# COMO se presenta un impacto. MELEE es lo de siempre: la tarjeta del que pega EMBISTE a la del
# que lo recibe. Todos los demas son de hechizo y NINGUNO embiste -- el que lanza se queda en su
# sitio y lo que viaja es el efecto, que es lo que diferencia lanzar un conjuro de dar un tajo.
#
# Caben DOSCIENTOS CINCUENTA Y SEIS: en la red viajan en 8 bits (ver _apuntar_impacto_red en
# combat.gd). Eran ocho y tres bits, luego dieciseis y cuatro al añadir la EXPLOSION, seis al entrar
# los mordiscos y ocho al darle dibujo propio a cada arma y cada habilidad del jugador. Hay que
# tocar las dos puntas a la vez o el compañero ve un efecto distinto al tuyo (y sin dar ningun
# error).
# Del 9 en adelante son los de los ENEMIGOS (los pide cada habilidad por su fx_estilo):
#   SPLAT   cuerpo que cae gordo y redondo y se APLASTA al tocar (Reventon, Aplastamiento)
#   ESCUPITAJO  bola pequeña con PARABOLA (Escupitajo toxico, Rociada, Escision)
#   AURA    resplandor sobre el PROPIO lanzador, no viaja (Ignicion y los buffs)
#   VORTICE espiral oscura que se cierra encima (las del abismo)
#   ARRASTRE  melee que se lleva una llama consigo mientras embiste (Llamarada, Combustion)
#   MORDISCO  dos hileras que se cierran, con los PALETOS anchos de un roedor (las ratas)
#   COLMILLAZO  lo mismo pero con fauces de fiera: dientes irregulares y colmillos largos
#   YUGULAR   un colmillazo seco con un DESTELLO de cuatro puntas encima (la del Rey rata)
#   CHILLIDO  anillos que se abren desde el lanzador y barren la fila; no muerde a nadie
#   ZARPAZO   cuatro surcos diagonales de borde dentado, en punta por los dos extremos
#   PLACAJE   un cuerpo blando que se estampa y se ESCURRE a los lados (los slimes)
#   CORNADA   un cuerno que engancha de abajo arriba y levanta
#   CARGA     la embestida: lineas de velocidad y polvareda en el choque
#   PISOTON   grieta que se abre por el suelo y onda baja de polvo
#   GOLPETAZO porrazo romo: estrella de impacto corta y gorda (puños de piedra, mazas, ramas)
#   RAICES    brotan del suelo y suben ramificandose; te dejan ATADO (el estado Enraizado pinta
#             esta misma forma en la tarjeta, ver CapaEstado._dibujar_raices)
# Del 25 en adelante, los tres de PONERSE A CUBIERTO. Son la misma mecanica (Fortaleza sobre uno
# mismo, 0 de daño) con tres formas distintas, porque lo que se cubre no es lo mismo: un bicho con
# coraza, un coloso de piedra y un muñeco de arcilla.
#   CAPARAZON elitro negro abombado, con costura central y brillo (el escarabajo)
#   MURALLA   muro de ladrillo que se levanta delante (el coloso)
#   ESCUDO    placas que se cierran sobre el (el golem)
# Y los BICHOS (28-32):
#   PONZONA   la dentellada de fauces con un destello VERDE (los queliceros de la araña)
#   TELARANA  una red que cae encima y se queda tirante
#   ENROSQUE  anillos que rodean la tarjeta y APRIETAN (el ciempies)
#   PATAS     muchas patas finas barriendo de arriba abajo
#   RODADA    la carga, pero GIRANDO: una bola con estelas de rotacion
#   MIRADA    un OJO que se abre en el lanzador y suelta una onda hacia el objetivo
#   LATIGAZO  verdugones de azote que aparecen SOBRE EL GOLPEADO
#
# Y DEL 35 EN ADELANTE, LO DEL JUGADOR. Hasta ahora TODO lo suyo iba con MELEE, o sea sin dibujo:
# daba lo mismo el arma que llevaras y la habilidad que gastaras, era el mismo empujon de tarjeta.
# Cada arma tiene su gesto (lo pide su tipo, ver FX_ARMA) y cada habilidad puede pedir el suyo por
# fx_estilo, igual que hacen los bichos.
#
# EL COLOR LO PONE LA IMBUICION. Estos se pintan en ACERO cuando no hay elemento (ver _color_golpe
# en combat.gd), y cuando lo hay se tiñen: el mismo corte sale verde con veneno y naranja con fuego.
# Por eso los painters dibujan la hoja en gris metal y usan el color SOLO en el filo y la estela --
# si tiñeran el arma entera, un tajo envenenado parecia una espada de plastico verde.
#   DAGA_CORTE   corte corto y rapido, de dos filos cruzados (el basico de la daga)
#   DAGA_RAFAGA  dos cortes seguidos y nerviosos, el segundo cruzando al primero
#   PUNALADA     APUÑALAMIENTO: la hoja entra recta y se hunde. No corta, atraviesa
#   IMBUIR_FILO  adorno sobre uno mismo: la hoja se moja y gotea (Filo emponzoñado)
#   DESVANECER   LA SOMBRA en la que te metes, sobre TI (Desaparecer). El corte de esa habilidad es
#                un DAGA_CORTE normal contra el enemigo: el que desaparece eres TU, asi que el humo
#                sale en tu tarjeta y no en la suya. Va por fx_sobre_mi.
# EL ESTOQUE es todo de PUNTA, al reves que la daga: no corta, PINCHA. Su hoja es larga y fina y
# entra en linea recta, asi que sus gestos se leen por la profundidad y por lo seco de la entrada.
#   ESTOQUE_PUNZADA  la estocada de siempre: entra, pincha y sale (el basico)
#   ESTOCADA_PENETRANTE  la que ATRAVIESA: entra hasta el fondo y sale por el otro lado
#   FINTAS       dos pinchazos nerviosos con el amago dibujado antes de cada uno
#   EN_GUARDIA   adorno sobre uno mismo: la punta en alto y el arco de la guardia
#   PASO_LIGERO  la estocada se da MIENTRAS te apartas: deja el rastro del que ya no esta ahi
#   PUNZADA_NERVIO  no busca el organo, busca el cable: pinchazo fino y un latigazo que recorre
#   DANZA_ACERO  tres tiempos encadenados sin bajar la punta, en abanico
# LA ESPADA CORTA corta como la daga pero con CUERPO: hoja mas larga y ancha, trazos mas amplios y
# menos nerviosos. Donde la daga da un arañazo rapido, esta abre.
#   ESPADA_TAJO       el tajo de siempre (el basico)
#   TAJO_QUEBRANTADOR el que ABRE LA GUARDIA: el tajo revienta un arco que salta en pedazos
#   DOBLE_TAJO        los dos cortes se quedan puestos formando una CRUZ y, cuando se cierra,
#                     destella entera
#   CAMBIO_RITMO      un tajo corto y las marcas del compas que se rompe
#   SENALAR_HUECO     dos cortes EN EL MISMO SITIO y una diana que se queda puesta
#   CORTE_TENDONES    corte BAJO, a lo que lo sostiene: la herida va abajo y el bicho cede
# LA ESPADA LARGA pesa de verdad: sus tajos CAEN, no barren. Y viene con escudo, asi que aqui entra
# tambien el gesto que faltaba para TODAS las armas: el escudazo.
#   ESPADA_LARGA_TAJO el tajo con peso (el basico)
#   TAJO_PESADO       el mandoble descendente: cae a plomo de arriba abajo y levanta polvo
#   TAJO_DESARMANTE   tajo al BRAZO ARMADO: el corte alto y el arma del bicho saltando
#   GUARDIA_ROTA      el tajo que abre la guardia (su segundo golpe es de escudo: ver ESCUDAZO)
#   VOTO_GUARDIA      postura sobre uno mismo: los pies clavados y la guardia cerrada
#   ESTOCADA_MARCIAL  una punta limpia por encima del escudo
#   VOZ_MANDO         adorno sobre LOS TUYOS: la orden que los mueve antes de pensarla
#   ESCUDAZO          el golpe con el ESCUDO. No es de un arma concreta: lo usa CUALQUIER golpe que
#                     AbilityData marque como de escudo (escudo_desde_golpe), en la espada larga, en
#                     la maza o donde sea. Ver _resolver_golpe_hab en combat.gd.
# LOS MANDOBLES son el arma grande: todo lo suyo es ANCHO y LENTO, y tres de sus cinco tecnicas
# alcanzan a VARIOS -- van en _ESTILOS_DE_GRUPO, o sea que de una tanda se dibuja UNO solo, tan
# ancho como haga falta para cubrir a todos los que alcanza (ver _marcar_efectos_de_grupo).
#   MANDOBLE_TAJO    el tajo enorme (el basico)
#   TAJO_DEVASTADOR  el descendente con toda la masa del espadon, y la onda que levanta
#   MOLINETE         DOS barridos que cruzan la fila entera de lado a lado
#   GRITO_GUERRA     la onda del grito barriendo la fila (el acero en alto va en fx_sobre_mi: se
#                    levanta sobre TI, no sobre el que lo recibe)
#   ACERO_EN_ALTO    el arma levantada por encima de la cabeza, sobre uno mismo. SIN DUEÑO ahora
#                    mismo: se hizo para el Grito de guerra y ahi sobraba (un grito no pega con el
#                    arma). Se queda porque el martillo lo va a querer; el hueco del enum no se
#                    puede reciclar de todas formas, que los numeros viajan por red.
#   TAJO_VERDUGO     el que se anuncia un turno: cae desde MUY arriba y parte el suelo
#   SEGAR            dos barridos BAJOS, a la altura de las piernas, de lado a lado
# LA MAZA PEQUEÑA es la primera arma ROMA del jugador, y eso lo cambia todo: no hay filo, no hay
# trazo y no hay estela. Un mazazo no deja "por donde ha pasado" nada -- deja UN PUNTO donde ha
# reventado. Por eso ninguno de estos usa _tajo: usan _porrazo, que es la estrella corta y gorda del
# GOLPETAZO de los bichos pasada a colores de jugador (acero o imbuicion).
#
# Y NO PINTAN NI UNA ESTRELLITA DE ATURDIMIENTO, aunque sea el arma que aturde. Eso YA lo cuenta el
# juego: el estado Aturdido va en la familia "control" de las particulas (ver _FAMILIAS aqui abajo) y
# saca el corro de estrellitas girando sobre la cabeza. Dibujarlas tambien en el golpe seria decir
# dos veces lo mismo, y ademas mentir cuando el aturdir NO prende (es probabilidad, no seguro). Lo
# que cuenta el gesto es el PESO: la onda que se abre y el impacto resonando.
#
# El ARMA NO SE DIBUJA (decidido con el usuario): solo la marca del porrazo, como en los tajos.
#   MAZA_GOLPE       el porrazo de siempre (el basico). Corto y seco: sale mucho por pelea
#   GOLPE_DEMOLEDOR  el mazazo concusivo: el porrazo GORDO y la resonancia -- anillos escalonados
#                    saliendo del punto y el impacto vibrando, que es lo que dice "esto ha sonado"
#   ROMPEPIERNAS     el mazazo BAJO, a lo que lo sostiene: el porrazo va abajo del todo y de el
#                    salen las rayas del desplome (la pierna cede)
#   APLASTAMIENTO    el que ROMPE LA GUARDIA: porrazo y el arco de la guardia partiendose. Su
#                    SEGUNDO golpe no es esto -- es un ESCUDAZO, que lo pide escudo_desde_golpe
#   GRITO_ALIENTO    adorno sobre LOS TUYOS: no es una orden (eso es VOZ_MANDO), es que se yerguen
#   MURO_ALIADOS     adorno sobre LOS TUYOS: las placas cerrando la formacion hombro con hombro
#   CULATAZO         con el MANGO y ALTO, a la cabeza: el porrazo mas pequeño y mas seco del arma
# EL HACHA GRANDE es a dos manos y la mas lenta del arsenal (velocidad 0.72), pero NO es un mandoble
# mas pequeño: un mandoble ATRAVIESA y un hacha MUERDE. Ese contraste es todo lo que hay que dibujar,
# y se dice con el trazo -- el del mandoble cruza la tarjeta de lado a lado y el del hacha entra, se
# hunde y SE PARA a media tarjeta, gordo en la cabeza y cortado en seco.
#
# Y SANGRA: tres de sus cinco tecnicas dejan Sangrado o Herida profunda. Por eso es la primera arma
# con SALPICADURA (_salpicadura): gotas que salen despedidas siguiendo la marcha del filo. No es una
# marca de herida -- eso ya se probo y sobra (ver la nota de _tajo) -- es lo que SALE VOLANDO, y es
# lo que la separa de las cuatro armas de corte que ya habia.
#   HACHA_TAJO      el hachazo de siempre (el basico): entra en diagonal y se para dentro
#   HENDEDURA       el que RAJA: cae en vertical y parte, y dos labios se separan por donde ha entrado
#   HACHAZO_BRUTAL  el mas gordo del arma (x2.45): un arco enorme con todo el cuerpo detras
#   CARNICERIA      TRES hachazos sucios, uno por golpe, cada uno por su lado y ninguno limpio
#   DESGARRO        entra y TIRA HACIA FUERA: engancha, arrastra y se lleva algo consigo
#   SED_SANGRE      sobre TI (va por fx_sobre_mi): el hachazo es un HACHA_TAJO normal contra el bicho
#                   y lo que se te suelta por dentro se pinta en TU tarjeta
# EL MARTILLO GRANDE es el arma mas lenta y la que mas aturde, y comparte con la maza que es ROMA:
# reusa su _porrazo. Lo que las separa NO es el tamaño (eso solo daria "una maza mas grande"), es
# CONTRA QUE PEGAN:
#
#   la maza    golpea AL BICHO -- el porrazo pasa en su tarjeta y ahi se acaba
#   el martillo golpea EL SUELO -- revienta abajo y lo que hace daño es lo que SE PROPAGA
#
# Tres de sus cinco (Sismico, Onda expansiva, Temblor) son de area y ninguna de las tres toca a
# nadie: sacuden el suelo. Por eso van en _ESTILOS_DE_GRUPO -- un terremoto es UNO, no uno por bicho.
# El lenguaje de lo que pasa abajo esta en _reventon_de_suelo (crater, esquirlas, cascotes), sacado
# del Tajo del verdugo justo para esto.
#   MARTILLO_GOLPE   el mazazo de siempre (el basico): revienta y el suelo se resiente
#   GOLPE_SISMICO    el que parte el suelo y sacude a todo lo que hay alrededor
#   ONDA_EXPANSIVA   martillazo al suelo y la onda BARRIENDO la fila entera
#   ROMPECORAZAS     no busca la carne, busca la chapa: el unico que pega ARRIBA y al cuerpo
#   MARTILLO_GUERRA  se anuncia un turno y cae desde muy arriba (el verdugo del martillo)
#   MARTILLO_EN_ALTO lo que se echa encima el que carga: el martillo aguantado sobre la cabeza
#   TEMBLOR_SUELO    no es un golpe: el suelo NO PARA de temblar y se va abriendo. Se llama asi y no
#                    TEMBLOR porque el enum ya se lee suelto en muchos sitios y "Temblor" a secas no
#                    dice de que va
# EL BASTON es el arma del MAGO y no se parece a ninguna de las ocho anteriores, porque lo suyo casi
# no es pegar: motion_value 0.4, el mas flojo del juego. Eso es lo que hay que dibujar -- sus dos
# golpes tienen que verse POCA COSA al lado de un hachazo, que es exactamente lo que son.
#
# Barre ROMO (_barrido_romo): una cinta mate sin canto brillante. Un palo no tiene filo, asi que
# usar el trazo de las armas de corte lo convertiria en una espada; y no tiene masa, asi que el
# porrazo seco de la maza lo convertiria en un mazazo. Es lo de en medio: barre, pero no corta.
#
# Y lo demas es ARCANO, que en esta arma es la mitad del kit.
#   BASTON_GOLPE   el bastonazo de siempre (el basico): flojo y corto
#   BASTONAZO      el mismo golpe con ganas, y el enemigo frenandose detras
#   FOCO_ARCANO    sobre TI: los signos que se juntan y se meten en el baston
#   SELLO_ARCANO   un signo trazado en el aire sobre el enemigo que se CIERRA de golpe (Silencio)
#   VELO_UMBRIO    sobre TI: el manto de sombra que CAE y te tapa (Sigilo)
#   VIENTO_LIMPIO  sobre LOS TUYOS: la corriente que los recorre y se lleva porqueria
# LOS PUÑOS Y EL RESTO DEL ESCUDO, que es lo que quedaba suelto.
#
# Los puños NO TIENEN NI UNA HABILIDAD: son el arma de cuando no llevas arma, asi que su unico gesto
# es el basico. Y tiene que verse pequeño y rapido -- lo unico que dice "vas a mano limpia" es que el
# golpe ocupe mucho menos que cualquiera de los otros nueve.
#
# Del escudo ya estaba el ESCUDAZO (60), que es el Golpe de escudo tal cual. Lo que faltaba son sus
# otras cuatro tecnicas, y tres de ellas ni siquiera pegan.
#   PUNOS_GOLPE     el puñetazo (el basico de ir desarmado)
#   EMBESTIDA_ESCUDO  el hombro detras del hierro: una CARGA, no un empujon de plancha
#   PROVOCACION     sobre TI: golpeas el escudo, ruges y te cubres detras
#   GUARDIA_CARNE   sobre TI: bajas la guardia A PROPOSITO y te plantas
#   COBERTURA       sobre LOS TUYOS: adelantas el escudo para que quepan otros detras
enum Estilo { MELEE = 0, PROYECTIL = 1, ARCANO = 2, RAYO = 3, CAIDA_RAYO = 4,
		CAIDA_GOTA = 5, BARRIDO = 6, ARCO = 7, EXPLOSION = 8,
		SPLAT = 9, ESCUPITAJO = 10, AURA = 11, VORTICE = 12, ARRASTRE = 13,
		MORDISCO = 14, COLMILLAZO = 15, YUGULAR = 16, CHILLIDO = 17,
		ZARPAZO = 18, PLACAJE = 19, CORNADA = 20, CARGA = 21, PISOTON = 22,
		GOLPETAZO = 23, RAICES = 24,
		CAPARAZON = 25, MURALLA = 26, ESCUDO = 27,
		PONZONA = 28, TELARANA = 29, ENROSQUE = 30, PATAS = 31, RODADA = 32,
		MIRADA = 33, LATIGAZO = 34,
		DAGA_CORTE = 35, DAGA_RAFAGA = 36, PUNALADA = 37, IMBUIR_FILO = 38,
		DESVANECER = 39,
		ESTOQUE_PUNZADA = 40, ESTOCADA_PENETRANTE = 41, FINTAS = 42, EN_GUARDIA = 43,
		PASO_LIGERO = 44, PUNZADA_NERVIO = 45, DANZA_ACERO = 46,
		ESPADA_TAJO = 47, TAJO_QUEBRANTADOR = 48, DOBLE_TAJO = 49, CAMBIO_RITMO = 50,
		SENALAR_HUECO = 51, CORTE_TENDONES = 52,
		ESPADA_LARGA_TAJO = 53, TAJO_PESADO = 54, TAJO_DESARMANTE = 55, GUARDIA_ROTA = 56,
		VOTO_GUARDIA = 57, ESTOCADA_MARCIAL = 58, VOZ_MANDO = 59, ESCUDAZO = 60,
		MANDOBLE_TAJO = 61, TAJO_DEVASTADOR = 62, MOLINETE = 63, GRITO_GUERRA = 64,
		TAJO_VERDUGO = 65, SEGAR = 66, ACERO_EN_ALTO = 67,
		MAZA_GOLPE = 68, GOLPE_DEMOLEDOR = 69, ROMPEPIERNAS = 70, APLASTAMIENTO = 71,
		GRITO_ALIENTO = 72, MURO_ALIADOS = 73, CULATAZO = 74,
		HACHA_TAJO = 75, HENDEDURA = 76, HACHAZO_BRUTAL = 77, CARNICERIA = 78,
		DESGARRO = 79, SED_SANGRE = 80,
		MARTILLO_GOLPE = 81, GOLPE_SISMICO = 82, ONDA_EXPANSIVA = 83, ROMPECORAZAS = 84,
		MARTILLO_GUERRA = 85, MARTILLO_EN_ALTO = 86, TEMBLOR_SUELO = 87,
		BASTON_GOLPE = 88, BASTONAZO = 89, FOCO_ARCANO = 90, SELLO_ARCANO = 91,
		VELO_UMBRIO = 92, VIENTO_LIMPIO = 93,
		PUNOS_GOLPE = 94, EMBESTIDA_ESCUDO = 95, PROVOCACION_FX = 96, GUARDIA_CARNE_FX = 97,
		COBERTURA = 98 }


# QUE GESTO hace cada arma con su golpe basico. La clave es WeaponData.Tipo.
#
# Vive aqui y no en weapon_data.gd porque es una tabla de PRESENTACION, y aqui estan los estilos:
# el .tres de un arma habla de daño, alcance y durabilidad, no de como se ve el mandoble.
#
# El que no este en la tabla se queda en MELEE (el empujon de tarjeta de siempre), asi que un arma
# nueva no revienta -- simplemente no dibuja hasta que se le ponga aqui.
const FX_ARMA := {
	1: Estilo.DAGA_CORTE,        # DAGA
	5: Estilo.ESTOQUE_PUNZADA,   # ESTOQUE
	2: Estilo.ESPADA_TAJO,       # ESPADA_CORTA
	3: Estilo.ESPADA_LARGA_TAJO, # ESPADA_LARGA
	4: Estilo.MANDOBLE_TAJO,     # MANDOBLE
	7: Estilo.MAZA_GOLPE,        # MAZA_PEQ
	6: Estilo.HACHA_TAJO,        # HACHA_GRANDE
	8: Estilo.MARTILLO_GOLPE,    # MARTILLO_GRANDE
	9: Estilo.BASTON_GOLPE,      # BASTON
	0: Estilo.PUNOS_GOLPE,       # PUNOS (ir a mano limpia tambien tiene su dibujo)
}


# LOS GESTOS DEL JUGADOR, para lo que hay que tratar distinto por ser suyo. Hoy es una cosa: el
# COLOR. Un bicho tiñe su golpe con su color_visual, pero un arma es de ACERO mientras no la imbuyan
# (ver _color_golpe en combat.gd), y sin esta lista los tajos salian del rojo de bicho.
const FX_JUGADOR := [Estilo.DAGA_CORTE, Estilo.DAGA_RAFAGA, Estilo.PUNALADA,
	Estilo.IMBUIR_FILO, Estilo.DESVANECER,
	Estilo.ESTOQUE_PUNZADA, Estilo.ESTOCADA_PENETRANTE, Estilo.FINTAS, Estilo.EN_GUARDIA,
	Estilo.PASO_LIGERO, Estilo.PUNZADA_NERVIO, Estilo.DANZA_ACERO,
	Estilo.ESPADA_TAJO, Estilo.TAJO_QUEBRANTADOR, Estilo.DOBLE_TAJO, Estilo.CAMBIO_RITMO,
	Estilo.SENALAR_HUECO, Estilo.CORTE_TENDONES,
	Estilo.ESPADA_LARGA_TAJO, Estilo.TAJO_PESADO, Estilo.TAJO_DESARMANTE, Estilo.GUARDIA_ROTA,
	Estilo.VOTO_GUARDIA, Estilo.ESTOCADA_MARCIAL, Estilo.VOZ_MANDO, Estilo.ESCUDAZO,
	Estilo.MANDOBLE_TAJO, Estilo.TAJO_DEVASTADOR, Estilo.MOLINETE, Estilo.GRITO_GUERRA,
	Estilo.TAJO_VERDUGO, Estilo.SEGAR, Estilo.ACERO_EN_ALTO,
	Estilo.MAZA_GOLPE, Estilo.GOLPE_DEMOLEDOR, Estilo.ROMPEPIERNAS, Estilo.APLASTAMIENTO,
	Estilo.GRITO_ALIENTO, Estilo.MURO_ALIADOS, Estilo.CULATAZO,
	Estilo.HACHA_TAJO, Estilo.HENDEDURA, Estilo.HACHAZO_BRUTAL, Estilo.CARNICERIA,
	Estilo.DESGARRO, Estilo.SED_SANGRE,
	Estilo.MARTILLO_GOLPE, Estilo.GOLPE_SISMICO, Estilo.ONDA_EXPANSIVA, Estilo.ROMPECORAZAS,
	Estilo.MARTILLO_GUERRA, Estilo.MARTILLO_EN_ALTO, Estilo.TEMBLOR_SUELO,
	Estilo.BASTON_GOLPE, Estilo.BASTONAZO, Estilo.FOCO_ARCANO, Estilo.SELLO_ARCANO,
	Estilo.VELO_UMBRIO, Estilo.VIENTO_LIMPIO,
	Estilo.PUNOS_GOLPE, Estilo.EMBESTIDA_ESCUDO, Estilo.PROVOCACION_FX, Estilo.GUARDIA_CARNE_FX,
	Estilo.COBERTURA]

# EL GRIS DE UN ARMA SIN IMBUIR. Vive aqui porque lo necesitan los dos lados: combat.gd lo manda
# como color del golpe y CapaHechizos lo compara para saber si el arma lleva algo encima o no.
#
# Y SE COMPARA POR IGUALDAD, no "a ojo" por la saturacion del color. Se intento adivinar con un
# `|g - b| > 0.06` y este mismo gris lo colaba como imbuido: 0.82 - 0.76 da 0.06000000000000005 en
# coma flotante, o sea MAYOR que 0.06 por un pelo, y el fogonazo de la Puñalada salia gris en vez de
# rojo. Comparar con el color exacto que manda combat.gd no tiene ese problema.
const ACERO := Color(0.72, 0.76, 0.82)

# Cuanto tarda cada efecto en llegar desde que nace. Se usa para dar de alta el dibujo ANTES del
# instante del golpe, de forma que el impacto aterrice EXACTAMENTE cuando salen el numero y la
# sacudida: si el rayo llegara despues del temblor, se leeria al reves.
const T_VUELO := {
	Estilo.MELEE: 0.0, Estilo.PROYECTIL: 0.20, Estilo.ARCANO: 0.18, Estilo.RAYO: 0.10,
	Estilo.CAIDA_RAYO: 0.16, Estilo.CAIDA_GOTA: 0.22, Estilo.BARRIDO: 0.26, Estilo.ARCO: 0.14,
	# La EXPLOSION no viaja: nace donde revienta. Un pelin de vuelo para que la onda haya empezado
	# a abrirse cuando entran el numero y el temblor, y no salga toda de golpe con ellos.
	Estilo.EXPLOSION: 0.08,
	# El SPLAT cae de MAS ARRIBA que un rayo y pesa mas: se ve venir, que es media gracia.
	Estilo.SPLAT: 0.34, Estilo.ESCUPITAJO: 0.26, Estilo.AURA: 0.10,
	Estilo.VORTICE: 0.24, Estilo.ARRASTRE: 0.18,
	# CERO SIGNIFICA "NO SE DIBUJA NADA". No es solo que el efecto salga sin adelanto: el `vuelo > 0`
	# de mas abajo (donde se llama a CapaHechizos.alta) es justo lo que hace que el MELEE no pinte
	# nada, asi que un estilo a 0.0 no llega a darse de alta en su vida. Ya mordio una vez: los
	# mordiscos estaban a 0.0 "porque no viajan, van con la embestida" y las tres habilidades de
	# rata no sacaban ningun efecto.
	#
	# Los mordiscos no viajan de verdad (la tarjeta es la que se lanza y las fauces se cierran donde
	# aterriza), asi que su vuelo es solo el adelanto con el que se abre la boca antes del golpe.
	Estilo.MORDISCO: 0.05, Estilo.COLMILLAZO: 0.06, Estilo.YUGULAR: 0.07,
	Estilo.CHILLIDO: 0.14, Estilo.ZARPAZO: 0.06,
	# Los cinco de cuerpo a cuerpo tampoco viajan: su vuelo es el adelanto con el que empieza el
	# dibujo. La CARGA lleva el mas largo porque tiene que verse VENIR (las lineas de velocidad
	# entran antes que el choque) y el PISOTON un pelin, para que la grieta abra con el temblor.
	Estilo.PLACAJE: 0.05, Estilo.CORNADA: 0.06, Estilo.CARGA: 0.08,
	Estilo.PISOTON: 0.07, Estilo.GOLPETAZO: 0.05,
	# Las RAICES no las lanza nadie: brotan del suelo. El vuelo es lo que tardan en salir, y va largo
	# a proposito -- tienen que verse SUBIR, que es lo que dice "te estan atrapando".
	Estilo.RAICES: 0.16,
	# Los de ponerse a cubierto no viajan (nacen sobre el propio bicho), pero llevan vuelo LARGO a
	# proposito: es lo que tardan en cerrarse encima, y eso es justo lo que hay que ver. El muro va
	# el que mas porque se levanta hilada a hilada.
	Estilo.CAPARAZON: 0.18, Estilo.MURALLA: 0.24, Estilo.ESCUDO: 0.16,
	# La TELARAÑA es lo unico de los bichos que VIAJA de verdad (se la lanza), de ahi el vuelo largo.
	# Los demas van con la embestida, asi que su vuelo es solo el adelanto del dibujo.
	Estilo.PONZONA: 0.06, Estilo.TELARANA: 0.24, Estilo.ENROSQUE: 0.10,
	Estilo.PATAS: 0.05, Estilo.RODADA: 0.10,
	# La MIRADA es de las pocas que de verdad VIAJA: el ojo se abre en el lanzador y la onda cruza,
	# asi que necesita vuelo para que se vea salir. El LATIGAZO va con el golpe.
	Estilo.MIRADA: 0.26, Estilo.LATIGAZO: 0.06,
	# LO DEL JUGADOR. Ninguno viaja: la tarjeta embiste y el arma llega con ella, asi que el vuelo es
	# solo el ADELANTO con el que empieza el gesto. La daga los tiene CORTOS a proposito -- es un arma
	# rapida, y con adelantos largos el corte parecia un mandoble a camara lenta.
	#
	# La PUÑALADA lleva algo mas: la hoja se arma antes de entrar, y ese instante de espera es lo que
	# la hace leerse como un golpe apuntado y no como un corte mas.
	Estilo.DAGA_CORTE: 0.04, Estilo.DAGA_RAFAGA: 0.05, Estilo.PUNALADA: 0.09,
	# IMBUIR_FILO no viaja (te la echas encima) y va largo: hay que ver la hoja mojarse.
	Estilo.IMBUIR_FILO: 0.30, Estilo.DESVANECER: 0.10,
	# EL ESTOQUE. Su vuelo es el ARMADO: la punta se echa atras antes de salir disparada, y eso es
	# justo lo que hace que una estocada se lea como apuntada y no como un manotazo. Las rapidas
	# (basico, fintas, danza) apenas se arman; las gordas se toman su tiempo.
	Estilo.ESTOQUE_PUNZADA: 0.07, Estilo.ESTOCADA_PENETRANTE: 0.13, Estilo.FINTAS: 0.06,
	Estilo.PASO_LIGERO: 0.08, Estilo.PUNZADA_NERVIO: 0.10, Estilo.DANZA_ACERO: 0.06,
	# La postura no viaja: se abre sobre uno mismo y hay que verla montarse.
	Estilo.EN_GUARDIA: 0.22,
	# LA ESPADA CORTA. Un pelin mas de adelanto que la daga: la hoja pesa mas y el brazo tarda mas en
	# arrancar. El QUEBRANTADOR es el que mas, porque hay que ver venir el golpe que abre la guardia.
	Estilo.ESPADA_TAJO: 0.06, Estilo.TAJO_QUEBRANTADOR: 0.11, Estilo.DOBLE_TAJO: 0.05,
	Estilo.CAMBIO_RITMO: 0.06, Estilo.SENALAR_HUECO: 0.07, Estilo.CORTE_TENDONES: 0.07,
	# LA ESPADA LARGA. Los adelantos mas largos de todas las armas hasta ahora: la hoja pesa y hay que
	# verla CAER. El TAJO_PESADO es el que mas, que es literalmente su gracia.
	Estilo.ESPADA_LARGA_TAJO: 0.09, Estilo.TAJO_PESADO: 0.16, Estilo.TAJO_DESARMANTE: 0.10,
	Estilo.GUARDIA_ROTA: 0.09, Estilo.ESTOCADA_MARCIAL: 0.11, Estilo.ESCUDAZO: 0.07,
	# Los dos que no son golpes: la postura se monta y la orden sale de ti.
	Estilo.VOTO_GUARDIA: 0.24, Estilo.VOZ_MANDO: 0.18,
	# LOS MANDOBLES: los adelantos mas largos del juego. Este arma es LENTA y esa es su identidad --
	# lo que la hace temible es que la ves venir. El VERDUGO se lleva el record: se anuncia un turno
	# entero (carga_turnos) y encima tarda en bajar.
	Estilo.MANDOBLE_TAJO: 0.13, Estilo.TAJO_DEVASTADOR: 0.20, Estilo.MOLINETE: 0.14,
	Estilo.GRITO_GUERRA: 0.16, Estilo.TAJO_VERDUGO: 0.30, Estilo.SEGAR: 0.12,
	Estilo.ACERO_EN_ALTO: 0.20,
	# LA MAZA PEQUEÑA. Su adelanto es lo que tarda la cabeza en LLEGAR, y en un arma roma eso pesa
	# mas que en una espada corta (0.06) aunque las dos sean de una mano: lo que hace daño aqui es la
	# masa, y la masa se ve venir. El CULATAZO es la excepcion y va el mas corto del arma -- es un
	# mangazo seco a la cabeza, y con adelanto largo parecia otro mazazo mas.
	Estilo.MAZA_GOLPE: 0.08, Estilo.GOLPE_DEMOLEDOR: 0.15, Estilo.ROMPEPIERNAS: 0.10,
	Estilo.APLASTAMIENTO: 0.13, Estilo.CULATAZO: 0.05,
	# Los dos que no son golpes: se los echas a LOS TUYOS y hay que verlos montarse.
	Estilo.GRITO_ALIENTO: 0.18, Estilo.MURO_ALIADOS: 0.20,
	# EL HACHA GRANDE. Adelantos largos: es la mas lenta del arsenal (velocidad 0.72) y su gracia,
	# como la del mandoble, es que la ves venir. El BRUTAL se lleva el mas largo del arma -- es su
	# golpe gordo y hay que verlo cargar.
	#
	# LA CARNICERIA ES LA EXCEPCION y va la mas corta de TODO el juego (0.04): son tres hachazos
	# atropellados, y con el adelanto largo del resto del arma se veian venir uno a uno, o sea
	# ordenados. Lo que cuenta esa habilidad es justo que ha dejado de apuntar.
	Estilo.HACHA_TAJO: 0.12, Estilo.HENDEDURA: 0.17, Estilo.HACHAZO_BRUTAL: 0.22,
	Estilo.CARNICERIA: 0.04, Estilo.DESGARRO: 0.13,
	# Lo que se te suelta por dentro no viaja: nace sobre ti y hay que verlo subir.
	Estilo.SED_SANGRE: 0.20,
	# EL MARTILLO GRANDE: los adelantos mas largos del juego junto con el mandoble, porque es el arma
	# mas lenta que hay (velocidad 0.68). Las tres de suelo llevan ademas el tiempo de que la cabeza
	# LLEGUE abajo, que es de donde sale todo lo demas.
	Estilo.MARTILLO_GOLPE: 0.15, Estilo.GOLPE_SISMICO: 0.20, Estilo.ONDA_EXPANSIVA: 0.18,
	# El Rompecorazas es el rapido del arma: es un golpe seco y apuntado a la chapa, no una demolicion.
	Estilo.ROMPECORAZAS: 0.12,
	# El Martillo de guerra empata con el Tajo del verdugo: los dos se anuncian un turno entero
	# (carga_turnos) y encima tardan en bajar.
	Estilo.MARTILLO_GUERRA: 0.30, Estilo.MARTILLO_EN_ALTO: 0.24,
	# El Temblor va largo porque lo suyo es que NO PARA: el adelanto es el primer martillazo y el
	# resto pasa en la coleta, que es la mas larga del arma.
	Estilo.TEMBLOR_SUELO: 0.16,
	# EL BASTON. Sus dos golpes van CORTOS: es un palo, no pesa, y con los adelantos largos de las
	# armas grandes parecian solemnes -- justo lo contrario de lo que son.
	Estilo.BASTON_GOLPE: 0.06, Estilo.BASTONAZO: 0.09,
	# Lo arcano va LARGO, que es lo contrario: un signo hay que verlo trazarse. Y el velo tiene que
	# verse CAER, o no se entiende que te tapa.
	Estilo.SELLO_ARCANO: 0.24, Estilo.FOCO_ARCANO: 0.26, Estilo.VELO_UMBRIO: 0.28,
	Estilo.VIENTO_LIMPIO: 0.22,
	# LOS PUÑOS: el adelanto MAS CORTO del juego. No hay arma que llevar hasta alli, solo el brazo, y
	# eso es medio gesto -- un puñetazo que se ve venir no es un puñetazo.
	Estilo.PUNOS_GOLPE: 0.03,
	# LA EMBESTIDA se ve VENIR (es una carga: lo que la hace temible es el trecho que recorre), y las
	# tres que no pegan van largas porque hay que verlas montarse.
	Estilo.EMBESTIDA_ESCUDO: 0.16, Estilo.PROVOCACION_FX: 0.20,
	Estilo.GUARDIA_CARNE_FX: 0.24, Estilo.COBERTURA: 0.22,
}

# --- ritmo de un impacto -------------------------------------------------------------------
# Manda la ANIMACION: el turno dura lo que dura esto, no hay espera muerta detras. Un golpe
# suelto (0.55) sale mas rapido que el segundo fijo que habia antes; una racha se nota.
const T_IDA := 0.22          # la tarjeta se lanza hacia el objetivo
const T_PUM := 0.12          # el instante del impacto (flash + sacudida)
const T_VUELTA := 0.21       # y se vuelve a su sitio
const T_ENCADENADO := 0.20   # separacion entre impactos de una misma racha
const TOPE_RACHA := 0.75     # techo de lo que suman TODOS los extras de una racha
const TOPE_TOTAL := 1.40     # techo duro: ninguna accion puede comerse mas turno que esto

# LOS HECHIZOS VAN A SU AIRE. Una racha de magia no es una racha de espada: los impactos se
# encadenan MUCHO mas apretados (una tormenta es un chaparron, no veinte tajos) pero el conjunto
# puede durar mas, porque es el momentazo del mago. Tormenta son ~32 impactos -> ~1.9s.
# El melee no se entera de nada de esto: sigue con las constantes de arriba.
const TOPE_TOTAL_MAGIA := 2.00
const TOPE_RACHA_MAGIA := 1.30
const T_ENCADENADO_MAGIA := 0.075
const T_ARRANQUE_MAGIA := 0.22   # lo que tarda en llegar el efecto mas lento (el barrido)
const T_COLA_MAGIA := 0.25       # margen para que la ultima sacudida y salpicadura terminen

# Del 7º impacto en adelante ya no hay embestida (seria un temblor ilegible): solo numero y
# sacudida. Solo afecta al melee -- la magia no embiste nunca.
const MAX_IMPACTOS_ANIMADOS := 6
# A partir de aqui se descartan: son cosmeticos. 40 y no 24 porque Tormenta encola ~32 impactos
# (20 golpes, y los de RAYO ademas salpican a los adyacentes) y con el tope viejo los ultimos
# desaparecian EN SILENCIO: el daño se aplicaba igual, solo faltaba el dibujo.
const MAX_EVENTOS := 40

const DIST_EMBESTIDA := 26.0   # cuanto se desplaza la tarjeta que pega
const AMP_SACUDIDA := 7.0      # y cuanto tiembla la que la recibe
const T_SACUDIDA := 0.22
const T_FLASH := 0.06

# --- numeros flotantes ---------------------------------------------------------------------
const MAX_NUMEROS := 32
const T_NUMERO := 0.65
const SUBIDA_NUMERO := 26.0
const RETRASO_CRIT := 0.05   # el critico entra un pelin tarde para que se lea antes el impacto

# --- barras --------------------------------------------------------------------------------
# Velocidad de acercamiento, en fracciones del maximo por segundo. 3.0 = un golpe que se lleva
# un tercio de la vida tarda ~0.11s; uno que se la lleva entera, ~0.33s. Va con el ritmo de la
# embestida a proposito: la barra acaba de bajar justo cuando la tarjeta vuelve a su sitio.
const VEL_BARRA := 3.0

# --- RITMO ------------------------------------------------------------------------------------
# EL RITMO BASE. Por debajo de 1.0 = todo mas despacio de lo que dicen las constantes de arriba.
# Las animaciones iban demasiado rapidas para verlas: un golpe se resolvia antes de que te diera
# tiempo a leer lo que habia pasado. No se toca cada constante (son quince y se descuadran entre
# ellas): se escala el DELTA en _process y ya.
const RITMO_BASE := 0.70

# Lo que multiplica al ritmo base. Lo pone combat.gd desde la velocidad elegida (x1 o x2), y en
# multijugador desde la del DUEÑO de la pelea. 1.0 = RITMO_BASE pelado.
#
# OJO: 'arrancar_cola' devuelve la duracion en segundos DE VERDAD (dividida por esto), porque ese
# numero es el que se convierte en la pausa del turno. Si devolviera la duracion sin escalar, a x2
# el turno esperaria el doble de lo que dura la animacion y a x1 se cortaria por la mitad.
# Se la pasa a la capa de dibujos en el mismo momento: los dos relojes tienen que ir igualados o el
# impacto deja de coincidir con el golpe.
var escala_tiempo: float = RITMO_BASE:
	set(v):
		escala_tiempo = maxf(v, 0.05)
		if _capa_fx != null and is_instance_valid(_capa_fx):
			_capa_fx.escala_tiempo = escala_tiempo

# QUE ESTADO SE VE COMO QUE.
#
# Van por TRES FAMILIAS, y cada una tiene su forma. La forma es lo que hace la lectura: antes
# todos eran el mismo cuadradito brillante con distinto color, asi que el Pegajoso (verde) se leia
# igual que una curacion. Un cuadradito que centellea significa "algo bueno" en TODO el juego (es
# el destello de las vetas y del equipo raro), asi que no puede ser tambien un debuff.
#
#   DAÑO   algo te esta consumiendo    -> motas que SUBEN y se deshacen
#   CAPA   algo te cubre               -> pelicula que se acumula + goterones que escurren
#   AYUDA  algo te esta ayudando       -> CRUCES que suben (curar) o destellos (los demas buffs)
#
# CABE UNA DE CADA FAMILIA A LA VEZ, no dos de la misma: si estas ardiendo Y envenenado se ve el
# fuego (el primero de la lista manda), pero si estas ardiendo Y pringado Y regenerando se ven las
# tres cosas, porque son tres familias distintas y no compiten entre si. Con eso, lo que ves
# siempre responde a tres preguntas separadas: ¿me estan haciendo daño?, ¿llevo algo encima?,
# ¿tengo algo a favor?
#
# Lo que no sale en ninguna lista se sigue viendo, pero solo por el TINTE del recuadro, que es
# informacion suficiente para un "lento" o un "marcado". Con los 31 a la vez esto seria una sopa.
#
# Se guardan los Id (enteros), NUNCA los emojis: el catalogo es la fuente de iconos y colores, y
# asi un estado nuevo entra solo (como "solo tinte", que es el fallback correcto).
# CADA FAMILIA tiene su hueco y su forma. Ojo a las dos curaciones: van en familias SEPARADAS a
# proposito, porque son dos recursos distintos y tienes que poder ver a la vez que te sube la vida
# y que te sube el maná. Juntas, la de vida ganaba siempre y la azul no salia nunca.
const FAMILIAS: Array = [
	# [nombre, forma, ids...] -- el orden dentro de la lista es quien gana el hueco de su familia.
	# ARDE POR ABAJO: una hoguera en el borde inferior de la tarjeta (dibujada, como el agua) mas
	# las llamitas que suben de ella. Un cuadradito naranja subiendo no es una quemadura.
	["fuego", "llama", [StatusEffects.Id.QUEMADURA]],
	# CALAVERITAS subiendo, y mas cuantas mas dosis lleves: el veneno APILA y se tiene que notar.
	["veneno", "veneno", [StatusEffects.Id.VENENO]],
	# SANGRA, y tambien apila: gotas que caen por toda la tarjeta.
	["sangra", "sangre", [StatusEffects.Id.SANGRADO]],
	# UN CORTE ABIERTO dibujado en un sitio fijo, del que gotea sangre. Las motas genericas no
	# dicen "herida"; un tajo que no cierra, si.
	["herida", "raja", [StatusEffects.Id.HERIDA_PROFUNDA]],
	["dano", "ascendente", [StatusEffects.Id.CORROSION]],
	# Te CHORREA encima: pelicula que se acumula + goterones. Es lo unico que pinta CapaEstado.
	["capa", "capa", [
		StatusEffects.Id.PEGAJOSO, StatusEffects.Id.MOJADO,
	]],
	# Algo tuyo ha BAJADO: flechas cayendo despacio.
	["merma", "flecha", [
		StatusEffects.Id.LENTO, StatusEffects.Id.DEBIL, StatusEffects.Id.VULNERABLE,
	]],
	# TE HAN SEÑALADO: una diana en el centro de la tarjeta que late. Va dibujada y no con
	# particulas porque es un MARCADOR -- tiene que estar siempre en el mismo sitio y con la misma
	# pinta, o deja de servir para encontrar de un vistazo a quien has marcado.
	["marca", "diana", [StatusEffects.Id.MARCA]],
	# TE TIENEN AGARRADO POR LOS PIES: raices que suben del borde de abajo y no se sueltan. Va en su
	# propia familia y no en "control" porque el Enraizado NO te quita el turno -- te quita media
	# baraja -, y las estrellitas sobre la cabeza dirian justo lo que no es.
	["raices", "raices", [StatusEffects.Id.ENRAIZADO]],
	# Te quitan el turno o te lo capan: el corro de estrellitas girando SOBRE LA CABEZA, tal cual el
	# gag de dibujos animados de toda la vida.
	["control", "estrella", [
		StatusEffects.Id.ATURDIDO, StatusEffects.Id.MIEDO, StatusEffects.Id.SILENCIO,
	]],
	# No te hace nada por si mismo, esta ahi crepitando y sube lo siguiente que te caiga. Van
	# RAYITOS (zigzags) y no chispas genericas: una X se lee como "algo brilla", un zigzag como
	# "esto esta electrificado".
	["ampli", "rayito", [
		StatusEffects.Id.RAYO,
	]],
	# Las dos curaciones: cruces verdes la vida, azules el maná.
	["vida", "cruz", [StatusEffects.Id.REGENERACION]],
	["mana", "cruz", [StatusEffects.Id.REGEN_MANA]],
	# Algo tuyo ha SUBIDO: las mismas flechas de la merma pero hacia arriba. Al ser el espejo
	# exacto se leen de un vistazo sin tener que aprenderse nada nuevo.
	["buff", "flecha_arriba", [
		StatusEffects.Id.FORTALEZA, StatusEffects.Id.BALUARTE,
	]],
	# VELOCIDAD: lineas de velocidad cruzando la tarjeta. Unos puntitos brillantes no dicen "vas
	# mas rapido"; estas si, y sin tener que explicarlas.
	["veloz", "estela", [StatusEffects.Id.PRESTEZA]],
	# TE TAPA: un velo de niebla sobre la tarjeta entera, sin una sola particula. El Sigilo se dice
	# haciendo que cueste verte, no echandote puntitos grises encima.
	["velo", "niebla", [StatusEffects.Id.SIGILO]],
	# El resto de cosas a tu favor, que no son ni "un numero que sube" ni nada con forma propia:
	# el destello de siempre, que en todo el juego significa "esto es bueno".
	["favor", "destello", [
		StatusEffects.Id.GUARDIA_CARNE, StatusEffects.Id.ESCOLTA,
	]],
]
# Los 8 PLATOS se quedan SOLO con el tinte a proposito, y no es un olvido: duran 20 minutos de
# reloj, asi que un emisor suyo estaria encendido toda la partida y no diria nada -- lo que
# informa de un estado es que aparezca y desaparezca.

# CUANTOS se pintan a la vez. NO es uno por familia: eso hacia que dos estados de la misma familia
# se taparan entre si (te ponias Sigilo y Guardia de carne y solo salia uno), que es el mismo tipo
# de mentira que enseñar un estado que no tienes. Se pintan los CUATRO primeros, salgan de donde
# salgan, y el orden es el de FAMILIAS: lo que te esta matando antes que lo que te viene bien.
#
# Cuatro y no mas porque la tarjeta mide 216x120: con cinco o seis emisores encima deja de leerse
# nada. Los que se caen del corte se siguen viendo en su chip y en el tinte del recuadro.
const MAX_EMISORES := 4

# Lo TRANSPARENTES que van todos los efectos de estado. Se pintan encima del nombre, de la barra
# de vida y de los numeros, asi que ninguno puede taparlos: informan de algo, pero lo que hay
# debajo importa mas.
const OPACIDAD := 0.7

const DORADO_BUFF := Color(1.0, 0.85, 0.35)

# icono (String) -> {"tipo": "ascendente"/"destello"/"", "color": Color, "debuff": bool}
# Se construye UNA vez recorriendo el catalogo. Al ir por Id y no por emoji escrito a mano, un
# estado nuevo del catalogo entra solo (como "solo tinte", que es el fallback correcto).
static var _tabla_cache: Dictionary = {}

# La capa donde vuelan los numeros. La monta combat.gd por encima de todo (si colgaran de la
# tarjeta, el clip_contents de la zona de chips se los comeria).
#
# Al asignarla se crea DENTRO la capa de hechizos, por debajo de los numeros. Se hace aqui y no
# en _ready porque el orden de arranque manda: este nodo nace al principio de combat._ready (las
# tarjetas necesitan registrarse en el) y la capa de numeros no existe hasta _montar_columna.
var capa_numeros: Control = null:
	set(v):
		capa_numeros = v
		if v == null or _capa_fx != null:
			return
		_capa_fx = CapaHechizos.new()
		# Nace con el ritmo que ya este puesto: la capa se crea DESPUES de que combat.gd fije la
		# velocidad, asi que sin esto la primera pelea corria los dibujos a otro ritmo que las
		# tarjetas hasta el siguiente cambio.
		_capa_fx.escala_tiempo = escala_tiempo
		v.add_child(_capa_fx)
		# El PRIMERO de la capa: los rayos y las bolas van por DEBAJO de los numeros de daño, que
		# son lo que hay que poder leer pase lo que pase.
		v.move_child(_capa_fx, 0)

var _capa_fx: CapaHechizos = null

var _tarjetas: Array[Dictionary] = []   # las mismas Dictionary que maneja combat.gd
var _cola: Array[Dictionary] = []       # impactos de la accion en curso
var _t := 0.0                           # reloj de la racha
var _dur := 0.0                         # lo que dura la racha entera
var _activa := false
# LA TANDA de un impacto: los que comparten numero caen A LA VEZ (ver arrancar_cola). Un molinete
# a cuatro bichos son DOS tandas de cuatro golpes, no ocho golpes seguidos.
var _tanda_pedida := -1                 # la que ha fijado quien resuelve, o -1 si no ha dicho nada
var _tanda_auto := -1                   # la ultima estampada: sin peticion, cada golpe va a la suya
var _numeros: Array[Dictionary] = []    # los que estan volando ahora
var _pool: Array[Label] = []            # Labels reciclados: nada de crear nodos por frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ============================================================
#  TARJETAS
# ============================================================

# Da de alta una tarjeta recien creada y le cuelga su capa de efectos. Se llama desde los TRES
# sitios que crean bloques (_setup_ui, _anadir_bloque_aliado y _meter_enemigo).
#
# La capa es el ULTIMO hijo del panel a proposito: los hermanos se dibujan en orden, asi que
# las particulas caen POR ENCIMA del nombre y de las barras. Y va en IGNORE para no robarle a
# la tarjeta el clic de seleccion, que es del panel.
func registrar(bloque: Dictionary) -> void:
	if bloque.is_empty() or bloque.has("fx_capa"):
		return
	var panel: Control = bloque.get("panel")
	if panel == null or not is_instance_valid(panel):
		return
	# La PELICULA va primero (debajo): es una capa sobre la tarjeta, y las particulas caen encima.
	var pelicula := CapaEstado.new()
	panel.add_child(pelicula)
	bloque["fx_pelicula"] = pelicula

	var capa := Control.new()
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(capa)
	bloque["fx_capa"] = capa
	bloque["fx_emisores"] = {}
	bloque["fx_firma"] = ""
	bloque["tinte"] = Color.WHITE
	if not _tarjetas.has(bloque):
		_tarjetas.append(bloque)


# Al cerrarse la pelea. No libera los nodos (se van con la escena), solo suelta las referencias
# para que no queden Dictionary vivos apuntando a paneles muertos.
func olvidar_todas() -> void:
	cancelar()
	_tarjetas.clear()


# ============================================================
#  ESTADOS: tinte + particulas
# ============================================================

# 'chips' = lo que devuelve _chips_de(c): [[etiqueta, tooltip, icono, color], ...]. Los chips de
# MECANICA (cargando, recitando, provocacion, imbuicion) vienen como pares de 2 y se ignoran
# aqui: no son estados y no tienen color de catalogo. Se mira el TAMAÑO y no el tipo por lo
# mismo que _refrescar_chips: un espejo con una instantanea vieja manda pares de 2 y no puede
# reventar por eso.
#
# 'vivo' = false apaga todo. Hace falta explicito porque _update_hp SE SALTA los chips de los
# caidos, asi que sin esta llamada un cadaver se quedaba ardiendo para siempre.
func pintar_estados(bloque: Dictionary, chips: Array, vivo: bool) -> void:
	if bloque.is_empty() or not bloque.has("fx_capa"):
		return
	var quiere: Array[Dictionary] = []      # lo que se pinta al final (como mucho MAX_EMISORES)
	var n_buff := 0
	var n_debuff := 0
	var col_debuff := Color.WHITE
	var col_buff := Color.WHITE
	if vivo:
		var tabla: Dictionary = _tabla()
		for par in chips:
			if par.size() < 4:
				continue
			var col: Color = par[3]
			var info: Dictionary = tabla.get(_clave(String(par[2]), col), {})
			if info.is_empty():
				continue
			# El recuento de buffs/debuffs es para el TINTE del recuadro, y va aparte de las
			# particulas: un estado sin forma (los platos) tiñe igual.
			if bool(info.get("debuff", false)):
				n_debuff += 1
				if col_debuff == Color.WHITE:
					col_debuff = col
			else:
				n_buff += 1
				if col_buff == Color.WHITE:
					col_buff = col
			var fam: String = String(info.get("familia", ""))
			if fam == "":
				continue   # sin forma: se queda solo con el tinte
			quiere.append({"icono": String(par[2]), "color": col,
				"tipo": String(info["tipo"]), "familia": fam,
				"fam_orden": int(info.get("fam_orden", 99)),
				"orden": int(info.get("orden", 99)),
				"stacks": _stacks_de(String(par[0]))})
	# Por FAMILIA primero y por gravedad despues: lo que te esta matando se ve antes que lo que te
	# viene bien. El orden tiene que ser estable ademas de justo, porque de el sale la firma que
	# decide si hay que recrear emisores o no.
	quiere.sort_custom(func(a, b) -> bool:
		if int(a["fam_orden"]) != int(b["fam_orden"]):
			return int(a["fam_orden"]) < int(b["fam_orden"])
		return int(a["orden"]) < int(b["orden"]))
	if quiere.size() > MAX_EMISORES:
		quiere.resize(MAX_EMISORES)

	# FIRMA: la huella de lo que deberia verse. _update_hp llama aqui constantemente (cada golpe,
	# cada tick, cada refresco de red) y casi siempre no ha cambiado nada; sin este corte se
	# estarian recreando 18 emisores por golpe.
	var tinte: Color = _tinte_de(n_buff, n_debuff, col_buff, col_debuff)
	var firma: String = "%d" % tinte.to_rgba32()
	for q in quiere:
		# Los STACKS entran en la firma: si te cae otra dosis de baba, el efecto tiene que crecer,
		# y sin esto el corte por firma decidia que "no ha cambiado nada" y se quedaba igual.
		firma += ";%s,%d,%d" % [q["icono"], (q["color"] as Color).to_rgba32(), int(q["stacks"])]
	if String(bloque.get("fx_firma", "")) == firma:
		return
	bloque["fx_firma"] = firma

	_reconciliar_emisores(bloque, quiere)

	# LA PELICULA de lo que te cubre. Va aparte de los emisores porque no es una particula: es una
	# capa pintada sobre la tarjeta, y es lo que hace que el Pegajoso se lea como "estas cubierto
	# de baba" y no como "algo verde te esta pasando".
	var pelicula: CapaEstado = bloque.get("fx_pelicula")
	if pelicula != null and is_instance_valid(pelicula):
		# Las cuatro capas son INDEPENDIENTES entre si: puedes estar pringado, escondido, marcado
		# y con un tajo abierto a la vez, y cada cosa se pinta en su sitio.
		var pintado: Dictionary = {}   # tipo -> color
		var chorreos: Array = []       # TODAS las que te chorrean (baba y agua pueden ir juntas)
		var stk: Dictionary = {}       # tipo -> dosis, para lo que escala
		for q in quiere:
			var t: String = String(q["tipo"])
			if t == "capa":
				chorreos.append({"col": q["color"], "stacks": int(q.get("stacks", 1))})
			elif not pintado.has(t):
				pintado[t] = q["color"]
				stk[t] = int(q.get("stacks", 1))
		pelicula.pintar_capas(chorreos)
		pelicula.pintar_fuego(pintado.get("llama", Color.TRANSPARENT),
			1.0 if pintado.has("llama") else 0.0)
		pelicula.pintar_niebla(pintado.get("niebla", Color.TRANSPARENT),
			1.0 if pintado.has("niebla") else 0.0)
		pelicula.pintar_diana(pintado.get("diana", Color.TRANSPARENT),
			1.0 if pintado.has("diana") else 0.0)
		pelicula.pintar_raja(pintado.get("raja", Color.TRANSPARENT),
			1.0 if pintado.has("raja") else 0.0)
		pelicula.pintar_raices(pintado.get("raices", Color.TRANSPARENT),
			1.0 if pintado.has("raices") else 0.0)

	if bloque.get("tinte", Color.WHITE) != tinte:
		bloque["tinte"] = tinte
		tinte_cambiado.emit(bloque)


# Crea los que faltan, deja en paz los que siguen y apaga los que se han ido. Reutilizar importa:
# recrear un CPUParticles2D reinicia su ciclo y el efecto daria un "tirón" en cada refresco.
func _reconciliar_emisores(bloque: Dictionary, quiere: Array[Dictionary]) -> void:
	var capa: Control = bloque["fx_capa"]
	var vivos: Dictionary = bloque.get("fx_emisores", {})
	var quedan: Dictionary = {}
	for q in quiere:
		# La clave lleva los STACKS: si te cae otra dosis, el emisor se rehace con mas cantidad en
		# vez de quedarse con la de antes. Sin ellos en la clave, "el mismo icono" se daba por
		# bueno y el efecto no crecia nunca.
		var ico: String = "%s#%d" % [q["icono"], int(q.get("stacks", 1))]
		var p: CPUParticles2D = vivos.get(ico)
		if p != null and is_instance_valid(p):
			quedan[ico] = p
			vivos.erase(ico)
			continue
		p = _crear_emisor(capa, q["tipo"], q["color"], int(q.get("stacks", 1)))
		if p != null:
			quedan[ico] = p
	# Lo que sobra: se apaga (deja de emitir sin borrar lo ya emitido) y se libera.
	for ico in vivos:
		var viejo: CPUParticles2D = vivos[ico]
		if viejo != null and is_instance_valid(viejo):
			Particulas.apagar(viejo)
			viejo.queue_free()
	bloque["fx_emisores"] = quedan


# 'stacks' = cuantas dosis lleva. Sube la CANTIDAD del efecto (mas gotas, mas calaveras), que es
# la forma honesta de enseñar que te han echado tres capas de baba y no una. Se capa por arriba:
# a partir de la tercera ya no se distingue y solo seria ruido.
func _crear_emisor(capa: Control, tipo: String, color: Color, stacks: int = 1) -> CPUParticles2D:
	var tam: Vector2 = capa.size
	if tam.x <= 0.0 or tam.y <= 0.0:
		tam = Vector2(180, 90)   # todavia sin layout: se recoloca solo en el resized de abajo
	var mult: float = 1.0 + 0.5 * float(clampi(stacks, 1, 4) - 1)
	var p: CPUParticles2D = null
	match tipo:
		"veneno":
			# Calaveritas subiendo, y mas cuantas mas dosis lleve encima.
			p = Particulas.ascendentes(capa, color, 0.85 * mult, tam.y * 0.5,
				Particulas.textura_calavera())
		"sangre":
			p = Particulas.sangre(capa, color, tam, mult)
		"ascendente":
			# 'alto' es el lado del cuerpo para Particulas: aqui el cuerpo es la tarjeta, y con la
			# mitad del alto las llamas suben ~1.5 tarjetas sin taparlo todo.
			p = Particulas.ascendentes(capa, color, 0.85, tam.y * 0.5)
		"cruz":
			p = Particulas.cruces(capa, color, 1.0, tam.y * 0.5)
		"capa":
			p = Particulas.chorretones(capa, color, tam, mult)
		"flecha":
			p = Particulas.flechas(capa, color, tam, 1.0)
		"flecha_arriba":
			p = Particulas.flechas(capa, color, tam, 1.0, true)
		"estrella":
			p = Particulas.orbitan(capa, color, tam, 1.0)
		"llama":
			p = Particulas.ascendentes(capa, color, 0.85, tam.y * 0.5, Particulas.textura_llama())
		"chispa":
			p = Particulas.chispas(capa, color, tam, 1.0)
		"rayito":
			p = Particulas.chispas(capa, color, tam, 1.0, Particulas.textura_rayito())
		"estela":
			p = Particulas.estelas(capa, color, tam, 1.0)
		"raja":
			# El corte lo dibuja CapaEstado; esto son SOLO las gotas que salen de el, asi que la
			# boquilla es diminuta (el tamaño se lo da el ajustar de abajo, en el punto del corte).
			p = Particulas.chorretones(capa, color, Vector2(8.0, 8.0), 0.6)
		"niebla", "diana", "raices":
			return null   # no llevan particulas: los pinta CapaEstado
		_:
			p = Particulas.destellos(capa, color, tam, 0.6, 0.7)
	if p == null:
		return null
	# OBLIGATORIO (ver cabecera): en solitario el arbol esta pausado durante el combate.
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	# NADA opaco encima de la tarjeta. Estos efectos van sobre el nombre, la vida y los numeros, y
	# lo que hay debajo importa mas que ellos: son un aviso, no el contenido. Se baja aqui, en el
	# emisor, y no en las rampas de Particulas -- esas las comparten las vetas y los proyectiles
	# del mundo, donde si tienen que verse a tope.
	p.modulate.a = OPACIDAD
	# El tamaño real no se sabe hasta que el contenedor coloca la tarjeta, asi que la zona de
	# emision sigue al layout en vez de clavarse a un numero. Mismo patron que MenuScaffold.brillo_en.
	var ajustar := func() -> void:
		if not is_instance_valid(p) or not is_instance_valid(capa):
			return
		p.position = capa.size * 0.5
		match tipo:
			"ascendente", "cruz", "llama":
				# Nacen en una franja ancha y baja: la cosa te sube por todo el cuerpo, no te
				# brota de un punto.
				p.emission_rect_extents = Vector2(capa.size.x * 0.45, capa.size.y * 0.12)
			"capa":
				# Los goterones nacen ARRIBA del todo y bajan por la tarjeta.
				p.position.y = capa.size.y * 0.16
				p.emission_rect_extents = Vector2(capa.size.x * 0.44, capa.size.y * 0.08)
			"flecha", "flecha_arriba":
				# Las de bajar nacen arriba y las de subir abajo, para que se vea el recorrido.
				var signo: float = 1.0 if tipo == "flecha" else -1.0
				p.position.y = capa.size.y * (0.5 - 0.28 * signo)
				p.emission_rect_extents = Vector2(capa.size.x * 0.42, capa.size.y * 0.1)
			"estrella":
				# SOBRE LA CABEZA, no en medio de la tarjeta: el corro va arriba, donde estaria la
				# cabeza del personaje, que es donde lo pone todo dibujo animado desde siempre.
				p.position.y = capa.size.y * 0.2
				p.emission_sphere_radius = minf(capa.size.x * 0.5, capa.size.y) * 0.42
			"raja":
				# Las gotas nacen EN EL CORTE, en el mismo punto donde CapaEstado lo dibuja.
				p.position = capa.size * CapaEstado.POS_RAJA
				p.emission_rect_extents = Vector2(3.0, 2.0)
			"estela":
				# Nacen pegadas al borde izquierdo y cruzan la tarjeta entera.
				p.position.x = 0.0
				p.emission_rect_extents = Vector2(2.0, capa.size.y * 0.38)
				p.initial_velocity_min = capa.size.x * 1.4
				p.initial_velocity_max = capa.size.x * 2.2
			_:
				p.emission_rect_extents = capa.size * 0.5
	capa.resized.connect(ajustar)
	ajustar.call()
	return p


# Buffs = dorado, debuffs = el color del estado pero apagado, empate o nada = blanco (sin tinte).
# Manda EL BANDO QUE MAS PESA y no la suma: un envenenado con Fortaleza tiene que leerse como
# una cosa o la otra, no como un marron a medias.
func _tinte_de(n_buff: int, n_debuff: int, col_buff: Color, col_debuff: Color) -> Color:
	if n_buff == n_debuff:
		return Color.WHITE
	if n_buff > n_debuff:
		var dorado: Color = col_buff.lerp(DORADO_BUFF, 0.5)
		return Color.WHITE.lerp(dorado, clampf(0.35 + 0.15 * float(n_buff), 0.0, 0.8))
	var apagado: Color = col_debuff.darkened(0.35)
	apagado.s = minf(apagado.s, 0.65)
	return Color.WHITE.lerp(apagado, clampf(0.4 + 0.1 * float(n_debuff), 0.0, 0.8))


# El catalogo entero traducido a "que efecto lleva cada icono". 'orden' = prioridad cuando hay
# mas estados que emisores: los DoT primero (arder es lo mas urgente de leer), luego el resto.
static func _tabla() -> Dictionary:
	if not _tabla_cache.is_empty():
		return _tabla_cache
	for id in StatusEffects.all_ids():
		var d: Dictionary = StatusEffects.def(id)
		var ico: String = str(d.get("icono", ""))
		if ico == "":
			continue
		# 'familia' = de que hueco compite (uno por familia); 'orden' = quien gana dentro de ella;
		# 'tipo' = con que forma se pinta.
		var familia := ""
		var tipo := ""
		var orden := 99
		var fam_orden := 99
		for fi in FAMILIAS.size():
			var f: Array = FAMILIAS[fi]
			var i: int = (f[2] as Array).find(id)
			if i >= 0:
				familia = String(f[0])
				tipo = String(f[1])
				orden = i
				fam_orden = fi
				break
		_tabla_cache[_clave(ico, d.get("color", Color.WHITE))] = {
			"tipo": tipo, "familia": familia, "orden": orden, "fam_orden": fam_orden,
			"debuff": bool(d.get("debuff", false))}
	return _tabla_cache


# La clave de la tabla: icono Y COLOR, no solo el icono. HAY EMOJIS REPETIDOS en el catalogo --
# 🔥 lo llevan Quemadura y el plato "Fuerza", 🛡 lo llevan Baluarte y el plato "Aguante"-- asi que
# con la clave solo por icono el que se define despues (el plato, que va al final) pisaba al otro
# y Quemadura y Baluarte se quedaban SIN efecto, mudos, sin un solo error por ningun lado.
#
# El color los separa porque cada entrada del catalogo tiene el suyo, y es el mismo que viaja en
# el chip resuelto: la clave se puede reconstruir igual en el espejo, que es donde no hay Ids.
static func _clave(ico: String, col: Color) -> String:
	return "%s|%d" % [ico, col.to_rgba32()]


# CUANTAS DOSIS lleva encima, sacadas de la etiqueta del chip ("🕸x3 2t" -> 3). Se lee del texto y
# no de c.statuses a proposito, por lo mismo que todo lo demas de aqui: en el espejo de
# multijugador no hay motor de estados y la etiqueta ya resuelta es lo unico que llega.
# Los que no apilan no traen la "xN" y valen 1.
static func _stacks_de(etiqueta: String) -> int:
	var i: int = etiqueta.find("x")
	if i < 0:
		return 1
	var n := ""
	var j: int = i + 1
	while j < etiqueta.length() and etiqueta[j] >= "0" and etiqueta[j] <= "9":
		n += etiqueta[j]
		j += 1
	return maxi(1, int(n)) if n != "" else 1


# ============================================================
#  BARRAS
# ============================================================

# _update_hp sigue siendo el unico que decide el valor, pero ahora fija el DESTINO y la barra
# viaja sola. El NUMERO de al lado VIAJA CON ELLA: lo repinta _mover_barras desde bar.value, asi
# que la cifra y el dibujo cuentan siempre lo mismo. (Antes la cifra iba instantanea al valor
# final: la barra bajaba despacio mientras el numero ya estaba abajo, y eso se leia como un fallo.)
func fijar_barra(bloque: Dictionary, clave: String, valor: float, inmediato := false) -> void:
	if not bloque.has(clave):
		return
	var bar: ProgressBar = bloque[clave]
	if bar == null or not is_instance_valid(bar):
		return
	# La PRIMERA vez que se toca una barra siempre es un salto seco, nunca un viaje. Se detecta
	# por que todavia no tiene meta, y con eso quedan cubiertos de golpe TODOS los caminos que
	# crean tarjetas (el arranque, un refuerzo, un compañero que se une, el roster del espejo):
	# sin esto, cada tarjeta recien nacida hacia subir su vida desde cero como si se curara.
	var primera: bool = not bloque.has(clave + "_meta")
	# 'valor' es la vida FINAL de la accion entera, que es lo unico que sabe combat.gd. Pero la
	# barra no puede irse ya a ese numero: los golpes van cayendo uno a uno y cada uno tiene que
	# descontar LO SUYO cuando toca, o la vida baja antes de que se vea el golpe que la baja.
	# Lo que queda por descontar se guarda en '<clave>_pend' (ver arrancar_cola).
	bloque[clave + "_fin"] = valor
	_recalcular_meta(bloque, clave)
	if inmediato or primera:
		bar.value = bloque[clave + "_meta"]


# EL DESTINO de una barra = la vida final MAS lo que aun no se ha visto caer. Un solo sitio para
# los tres que lo tocan (fijar_barra, encolar y _descontar), porque los tres tienen que respetar
# las mismas dos vallas:
#
#   1. NUNCA por encima del maximo. 'pend' guarda el daño BRUTO del golpe, pero la vida final sale
#      de current_hp, que esta clampeado a 0 (ver Combatant.take_damage). En un remate con exceso
#      (bicho a 10/30 que come 50) daba fin=0 + pend=50 = 50, y la ProgressBar lo recortaba a 30:
#      la barra SUBIA hasta llenarse de rojo justo antes de morir. Mismo desajuste con el escudo
#      del sequito del Rey Slime, que recorta el daño aplicado despues de haberse encolado el bruto.
#   2. MIENTRAS QUEDEN GOLPES POR CAER, LA BARRA SOLO BAJA. Es lo que remata el caso de arriba: un
#      golpe pendiente jamas puede empujar la barra hacia arriba, venga el numero que venga. Solo
#      se aplica con pend > 0, para que una CURACION siga subiendola con toda normalidad.
func _recalcular_meta(bloque: Dictionary, clave: String) -> void:
	if not bloque.has(clave) or not bloque.has(clave + "_fin"):
		return
	var bar: ProgressBar = bloque[clave]
	if bar == null or not is_instance_valid(bar):
		return
	var pend: float = float(bloque.get(clave + "_pend", 0.0))
	var meta: float = clampf(float(bloque[clave + "_fin"]) + pend, 0.0, bar.max_value)
	if pend > 0.0:
		meta = minf(meta, bar.value)
	bloque[clave + "_meta"] = meta


# Olvida los destinos de las barras de UNA tarjeta, para que el siguiente fijar_barra vuelva a
# ser un salto seco. Lo usa el hueco de cadaver que se reestrena: la barra del que entra no puede
# venir viajando desde la vida del que estaba antes.
#
# Se borra TAMBIEN lo pendiente y la vida final: si solo se quitaba la meta, el que entra en el
# hueco heredaba los golpes sin aterrizar del muerto y su barra nacia midiendo con la vida ajena.
func olvidar_barras(bloque: Dictionary) -> void:
	for clave in ["hp", "en", "mp"]:
		bloque.erase(clave + "_meta")
		bloque.erase(clave + "_pend")
		bloque.erase(clave + "_fin")


# Le quita a la barra de UNA tarjeta lo que acaba de comerse en este golpe. Cuando ya no queda
# nada pendiente, la meta es la vida final y todo cuadra solo.
func _descontar(bloque: Dictionary, dmg: float) -> void:
	if bloque.is_empty() or not bloque.has("hp_fin"):
		return
	var pend: float = maxf(0.0, float(bloque.get("hp_pend", 0.0)) - maxf(dmg, 0.0))
	bloque["hp_pend"] = pend
	_recalcular_meta(bloque, "hp")
	if pend <= 0.0:
		_soltar_apagado(bloque)


# Si esta tarjeta estaba esperando a morirse en pantalla, ya puede: le ha caido todo lo que le
# tenia que caer.
func _soltar_apagado(bloque: Dictionary) -> void:
	if not bool(bloque.get("fx_apagar", false)):
		return
	bloque.erase("fx_apagar")
	apagar_ahora.emit(bloque)


# ¿Le queda a esta tarjeta algun golpe por aterrizar? Lo pregunta combat.gd antes de poner un
# cadaver en gris.
func golpes_pendientes(bloque: Dictionary) -> bool:
	return float(bloque.get("hp_pend", 0.0)) > 0.0


# Suelta lo que quedara a medias: la barra se va ya a la vida real. Se llama al acabar la racha y
# al cancelarla (tecla P), para que un golpe que no se llego a ver no deje la barra mintiendo.
func _saldar_barras() -> void:
	for b in _tarjetas:
		if float(b.get("hp_pend", 0.0)) != 0.0:
			b["hp_pend"] = 0.0
			_recalcular_meta(b, "hp")
		# Y si alguien se quedo esperando a morirse en pantalla, que se muera ya: la racha se ha
		# acabado (o la han cortado con la P) y no va a caerle nada mas.
		_soltar_apagado(b)


func _mover_barras(delta: float) -> void:
	for b in _tarjetas:
		for clave in ["hp", "en", "mp"]:
			if not b.has(clave) or not b.has(clave + "_meta"):
				continue
			var bar: ProgressBar = b[clave]
			if bar == null or not is_instance_valid(bar):
				continue
			var meta: float = b[clave + "_meta"]
			if not is_equal_approx(bar.value, meta):
				var paso: float = maxf(bar.max_value, 1.0) * VEL_BARRA * delta
				bar.value = move_toward(bar.value, meta, paso)
			# El numero se repinta SIEMPRE, tambien con la barra quieta. Es lo que cubre la RETENCION:
			# entre que el golpe se resuelve y el impacto aterriza, la barra se queda a proposito
			# donde estaba... pero _update_hp ya ha escrito el numero de despues. Sin repintar aqui,
			# la cifra seguia adelantandose al golpe justo en el hueco que importa.
			_pintar_numero(b, clave)


# EL NUMERO de una barra, sacado de la BARRA y no del combatiente: es lo que hace que la cifra y
# el dibujo cuenten lo mismo mientras la vida viaja. Al llegar a la meta, move_toward aterriza
# exacto, asi que en reposo la cifra sigue siendo la de verdad.
#
# El formato lo deja _update_hp en '<clave>_fmt' (cada barra tiene el suyo: "EN 1/1", "MP 1.00/1.00").
# Sin formato no se toca nada: manda lo que haya escrito _update_hp, que es el camino que funciona
# tambien cuando no hay capa de efectos.
func _pintar_numero(bloque: Dictionary, clave: String) -> void:
	if not bloque.has(clave + "_lbl") or not bloque.has(clave + "_fmt"):
		return
	var lbl: Label = bloque[clave + "_lbl"]
	if lbl == null or not is_instance_valid(lbl):
		return
	var bar: ProgressBar = bloque[clave]
	lbl.text = String(bloque[clave + "_fmt"]) % [bar.value, bar.max_value]


func _snap_barras() -> void:
	for b in _tarjetas:
		for clave in ["hp", "en", "mp"]:
			if b.has(clave) and b.has(clave + "_meta") and is_instance_valid(b[clave]):
				b[clave].value = b[clave + "_meta"]
				_pintar_numero(b, clave)


# ============================================================
#  IMPACTOS
# ============================================================

# A QUE TANDA pertenece el proximo golpe que se encole. Lo dice quien resuelve la accion, con el
# indice del golpe que ya tiene a mano: un molinete de dos golpes a cuatro bichos llama con 0 para
# los cuatro primeros y con 1 para los cuatro siguientes, y esos cuatro caen A LA VEZ.
#
# Solo vale para UN encolar: en cuanto se estampa, se olvida. Asi lo que NO pase por aqui (un
# basico, los rebotes encadenados de un rayo) sigue yendo golpe a golpe como siempre, que es como
# tiene que verse: un rebote es justamente una cosa DESPUES de otra.
func tanda(n: int) -> void:
	_tanda_pedida = maxi(0, n)


# Apunta UN golpe. No lo reproduce todavia: la accion puede tener 8 y hasta que no estan todos
# no se sabe cuanto tiene que durar la racha (ver arrancar_cola).
#
# 'peso' = QUE FRACCION del golpe principal se lleva este objetivo (1.0 el principal, 0.5 un
# adyacente de Brasa, 0.55 un rebote de Rayo). Manda el tamaño del temblor y del efecto: si el
# del medio come 100 y los de los lados 50, los de los lados tiemblan la mitad. Se pasa la
# FRACCION y no el daño a proposito -- el daño ya lleva dentro el critico y las resistencias, y
# entonces un objetivo que RESISTE el fuego temblaria menos que uno que no, justo al reves.
#
# 'solo_dibujo' = esto NO es un golpe, es UN ADORNO. Sale el efecto y nada mas: ni numero, ni
# temblor, ni barra. Es como se pintan las cosas que no pegan -- el aura de un buff, las gotas del
# Brote del Rey al desprenderse-- sin tener que inventarles un daño de cero, que sacaba un "0"
# flotando y una sacudida por un golpe que no existe.
#
# 'sfx' = la clave del sonido PROPIO de la habilidad ("" = ninguna, y entonces suena el generico de
# su estilo). Ver Sonido.golpe y el disparo en _process.
func encolar(b_atacante: Dictionary, b_victima: Dictionary, dmg: float, crit: bool,
		evadido: bool, color_elem: Color, estilo: int = Estilo.MELEE, peso: float = 1.0,
		solo_dibujo: bool = false, sfx: String = "", elem: int = 0) -> void:
	if b_victima.is_empty() or _cola.size() >= MAX_EVENTOS:
		_tanda_pedida = -1
		return
	# La tanda que hayan pedido, o una nueva para este golpe solo. Nunca hacia atras: si alguien
	# mezcla golpes con tanda y sin ella, los de despues no pueden caer ANTES.
	var t_ev: int = _tanda_auto + 1 if _tanda_pedida < 0 else maxi(_tanda_pedida, 0)
	_tanda_auto = maxi(_tanda_auto, t_ev)
	_tanda_pedida = -1
	_cola.append({
		"ba": b_atacante, "bv": b_victima, "dmg": dmg, "crit": crit,
		"evadido": evadido, "color": color_elem, "t": 0.0, "lanzado": false,
		"estilo": estilo, "peso": clampf(peso, 0.2, 1.5), "fx_lanzado": false,
		"tanda": t_ev, "solo_dibujo": solo_dibujo,
		"sfx": sfx, "sfx_lanzado": false,
		# EL ELEMENTO, aparte del color. El color solo dice de que tono va; el elemento dice COMO SE
		# COMPORTA: el rayo centellea y se quiebra, el fuego ondea y suelta chispas, el agua gotea.
		# Pintar los tres del mismo modo y cambiarles el tinte no cuela -- no parecian ni fuego ni
		# agua ni rayo, parecian el mismo tajo de tres colores.
		"elem": elem,
	})
	# LA VIDA NO PUEDE BAJAR ANTES QUE EL GOLPE. Se apunta AQUI, en el mismo instante en que el
	# golpe se resuelve, y no al arrancar la cola: entre una cosa y otra combat.gd llama a
	# _update_hp varias veces y desde sitios distintos segun la accion, asi que hacerlo al final
	# dependia de en que orden cayeran las llamadas. Aqui no hay orden que valga.
	#
	# Lo apuntado se le DEVUELVE a la barra: mientras quede pendiente, su destino es "la vida
	# final MAS lo que aun no se ha visto caer", o sea justo donde estaba antes de la accion.
	# Cada impacto le descuenta lo suyo al aterrizar (ver _descontar).
	if not evadido and dmg > 0.0:
		b_victima["hp_pend"] = float(b_victima.get("hp_pend", 0.0)) + dmg
		_recalcular_meta(b_victima, "hp")


# Cierra la racha y la echa a andar. Devuelve LO QUE VA A DURAR: ese numero es el que se convierte
# en la duracion del turno (ver _pausa_lectura en combat.gd). 0.0 = no habia nada que animar, y
# entonces manda quien llama (un turno aturdido se queda su pausa corta de lectura).
func arrancar_cola() -> float:
	if _cola.is_empty():
		return 0.0
	var n: int = _cola.size()
	# ¿Es una racha de MAGIA? Se deduce de la propia cola en vez de recibirlo por parametro, y eso
	# importa: a esta funcion la llama TAMBIEN el espejo de multijugador (aplicar_impactos), asi
	# que dedurciendolo aqui las dos pantallas sacan la misma duracion sin sincronizar nada.
	var magia: bool = false
	for ev in _cola:
		if int(ev.get("estilo", Estilo.MELEE)) != Estilo.MELEE:
			magia = true
			break
	# (Lo que le queda por bajar a cada barra ya se apunto al ENCOLAR cada golpe, no aqui: ver
	# encolar. Hacerlo en este punto dependia de si combat.gd llamaba a _update_hp antes o
	# despues, y eso cambia segun la accion.)
	var t_enc: float = T_ENCADENADO_MAGIA if magia else T_ENCADENADO
	var arranque: float = T_ARRANQUE_MAGIA if magia else T_IDA
	# EL TIEMPO SE REPARTE ENTRE TANDAS, NO ENTRE IMPACTOS. Un golpe de area es UN golpe aunque
	# alcance a cuatro: los cuatro tienen que caer en el mismo instante. Escalonando por indice de
	# evento, un molinete de 2 golpes a 4 bichos salian 8 instantes distintos y se leia como ocho
	# golpecitos en fila en vez de dos barridos. De paso el turno dura lo que dura DE VERDAD (dos
	# tandas), que es bastante menos.
	var orden: Dictionary = {}   # numero de tanda -> su posicion (0, 1, 2...)
	for ev in _cola:
		var tv: int = int(ev.get("tanda", 0))
		if not orden.has(tv):
			orden[tv] = orden.size()
	var n_tandas: int = maxi(1, orden.size())
	# Los extras TOPAN: 32 impactos de una tormenta no pueden durar cinco segundos. Lo que hacen
	# es encadenarse mas apretados dentro de la misma ventana.
	var extra: float = minf(t_enc * float(n_tandas - 1), TOPE_RACHA_MAGIA if magia else TOPE_RACHA)
	var paso: float = extra / maxf(1.0, float(n_tandas - 1))
	for i in n:
		var pos: int = int(orden[int(_cola[i].get("tanda", 0))])
		_cola[i]["t"] = arranque + paso * float(pos)
		_cola[i]["pos_tanda"] = pos
		_cola[i]["lanzado"] = false
		_cola[i]["fx_lanzado"] = false
		_cola[i]["sfx_lanzado"] = false
	_marcar_efectos_de_grupo()
	_t = 0.0
	if magia:
		_dur = minf(arranque + T_PUM + extra + T_COLA_MAGIA, TOPE_TOTAL_MAGIA)
	else:
		_dur = minf(arranque + T_PUM + extra + T_VUELTA, TOPE_TOTAL)
	# La accion se ha cerrado: la numeracion de tandas empieza de cero en la siguiente.
	_tanda_auto = -1
	_tanda_pedida = -1
	_activa = true
	# En SEGUNDOS DE VERDAD: _dur esta en tiempo de animacion y _process avanza a escala_tiempo.
	return _dur / maxf(escala_tiempo, 0.01)


# UN SOLO EFECTO POR TANDA para los estilos que son UNA COSA GRANDE, no un proyectil por cabeza.
#
# LA REGLA, que vale para todos: si un ataque es de area, el efecto no se REPITE, se hace MAS
# GRANDE hasta cubrir a los que alcanza. Repetirlo convierte una cosa enorme en varias pequeñas.
#   BARRIDO    una ola es UN frente que pasa por delante de varios; repetida salian olitas en fila.
#   SPLAT      un bicho que salta encima es UN cuerpo; repetido caian bolas sueltas sobre cada uno.
#   VORTICE    un remolino que se traga a tres es UNO ancho, no tres remolinos pequeños.
#   EXPLOSION  la bola revienta UNA vez y la onda alcanza a los lados; repetida son tres petardos.
#   ARRASTRE   el bicho embiste UNA vez llevandose la llama por delante. Repetido salia una llama
#              por cabeza, o sea "un proyectil a cada uno", que es justo lo contrario de la
#              Combustion: el slime se pone al rojo y ARRASA de lado a lado, en grande.
#
# De cada tanda se queda UNA como portadora del dibujo y a las demas se les apaga (siguen dando su
# numero, su temblor y su parte de barra: lo unico que pierden es repetir el efecto). La portadora
# recibe el ANCHO de todo lo alcanzado -del borde izquierdo del primero al derecho del ultimo- y el
# CENTRO, asi que el efecto se adapta solo a 2, 3 o 4 objetivos sin que nadie le pase el numero.
#   CHILLIDO   un grito es UNA onda que se abre y coge a todo el que pilla. Repetido serian tres
#              gritos a la vez, que ademas es justo lo que NO es: el Rey chilla una sola vez.
#
# Los MORDISCOS no entran aqui A PROPOSITO. El Frenesi y la Dentellada real reparten golpe a golpe
# (cada impacto es una dentellada entera sobre quien le toque, no la salpicadura de una comun), asi
# que fundirlos en uno se cargaria justo lo que hay que leer: cuantas veces te han mordido y a quien.
#   PISOTON    una onda por el suelo alcanza a varios y es UNA. Repetida serian tres pisotones
#              simultaneos, que ademas es imposible: el bicho tiene dos patas.
#   RODADA     una bola que rueda y arrolla a tres es UNA bola que pasa por encima de los tres, no
#              tres bolas. Igual que el ARRASTRE, y por el mismo motivo.
#   CARGA      lo mismo: el bicho embiste UNA vez y arrolla lo que pilla por el camino. Repetida
#              salian tres embestidas simultaneas, cada una con sus lineas de velocidad apuntando a
#              una victima distinta, y se leia como tres bichos cargando a la vez.
# La OLEADA DE PATAS no entra: reparte golpe a golpe, asi que cada impacto es su propia tanda de
# patas sobre quien le toque -- lo mismo que los mordiscos.


# LOS QUE SON CUERPO A CUERPO. Manda dos cosas a la vez, y por eso esta en UNA lista y no repartido
# en dos condiciones: estos EMBISTEN (la tarjeta del que pega se lanza contra la del que lo recibe)
# y estos NO encienden la tarjeta al canalizar (no sale nada de tu mano: vas tu).
#
# El MELEE de siempre y el ARRASTRE (un melee que se lleva una llama por delante) entran aqui igual
# que los de los bichos. Era una cadena de diez `estilo == ...` encadenados con `or`, duplicada al
# derecho en la embestida y al reves en la canalizacion: cada familia nueva habia que acordarse de
# tocar las dos, y olvidar la segunda dejaba al bicho embistiendo Y encendido como un mago.
const _CUERPO_A_CUERPO := [Estilo.MELEE, Estilo.ARRASTRE, Estilo.MORDISCO, Estilo.COLMILLAZO,
	Estilo.YUGULAR, Estilo.ZARPAZO, Estilo.PLACAJE, Estilo.CORNADA, Estilo.CARGA,
	Estilo.PISOTON, Estilo.GOLPETAZO, Estilo.PONZONA, Estilo.ENROSQUE, Estilo.PATAS,
	Estilo.RODADA, Estilo.LATIGAZO,
	# Los del jugador van aqui por lo mismo que los mordiscos: para dar un tajo hay que LLEGAR, y es
	# la embestida la que lleva el arma al sitio. El IMBUIR_FILO no, que es sobre uno mismo.
	Estilo.DAGA_CORTE, Estilo.DAGA_RAFAGA, Estilo.PUNALADA,
	# El estoque tiene MAS alcance, pero sigue habiendo que llegar: embiste igual. El EN_GUARDIA no,
	# que es una postura y va sobre uno mismo.
	Estilo.ESTOQUE_PUNZADA, Estilo.ESTOCADA_PENETRANTE, Estilo.FINTAS, Estilo.PASO_LIGERO,
	Estilo.PUNZADA_NERVIO, Estilo.DANZA_ACERO,
	Estilo.ESPADA_TAJO, Estilo.TAJO_QUEBRANTADOR, Estilo.DOBLE_TAJO, Estilo.CAMBIO_RITMO,
	Estilo.SENALAR_HUECO, Estilo.CORTE_TENDONES,
	Estilo.ESPADA_LARGA_TAJO, Estilo.TAJO_PESADO, Estilo.TAJO_DESARMANTE, Estilo.GUARDIA_ROTA,
	Estilo.ESTOCADA_MARCIAL, Estilo.ESCUDAZO,
	Estilo.MANDOBLE_TAJO, Estilo.TAJO_DEVASTADOR, Estilo.MOLINETE, Estilo.TAJO_VERDUGO,
	Estilo.SEGAR,
	# La maza es de una mano y de alcance corto: para dar un mazazo hay que llegar mas que con
	# ninguna. Los dos gritos NO -- esos se los echas a los tuyos desde donde estas.
	Estilo.MAZA_GOLPE, Estilo.GOLPE_DEMOLEDOR, Estilo.ROMPEPIERNAS, Estilo.APLASTAMIENTO,
	Estilo.CULATAZO,
	# El hacha es a dos manos y de alcance corto: hay que echarse encima. La Sed de sangre NO -- eso
	# es lo que te pasa a TI, y va sobre tu tarjeta.
	Estilo.HACHA_TAJO, Estilo.HENDEDURA, Estilo.HACHAZO_BRUTAL, Estilo.CARNICERIA,
	Estilo.DESGARRO,
	# El martillo tambien hay que llevarlo hasta alli, incluidas las que pegan al suelo: el suelo que
	# revientas es el de DEBAJO del bicho.
	Estilo.MARTILLO_GOLPE, Estilo.GOLPE_SISMICO, Estilo.ONDA_EXPANSIVA, Estilo.ROMPECORAZAS,
	Estilo.MARTILLO_GUERRA, Estilo.TEMBLOR_SUELO,
	# Los dos golpes del baston: para dar un palo tambien hay que llegar. Lo arcano NO embiste -- un
	# mago no se lanza contra nadie, y ese contraste es medio kit del arma.
	Estilo.BASTON_GOLPE, Estilo.BASTONAZO,
	# Los puños son lo mas corto de alcance que hay, y la Embestida es literalmente ir hacia el.
	Estilo.PUNOS_GOLPE, Estilo.EMBESTIDA_ESCUDO]
# NOTA: la CARGA esta en _ESTILOS_DE_GRUPO y aun asi embiste. No es contradictorio: embestir es del
# ATACANTE (su tarjeta se lanza) y agruparse es del DIBUJO (uno solo para todo lo alcanzado).


# LOS QUE SE PINTAN SOBRE UNO MISMO. El bicho se echa la cosa ENCIMA (un aura, una coraza, un muro):
# atacante y victima son el mismo y el dibujo va en SU tarjeta, no en la de enfrente. Los demas
# estilos de una habilidad SIN DAÑO se pintan sobre los objetivos (ver combat.gd._fx_adorno).
const SOBRE_SI_MISMO := [Estilo.AURA, Estilo.CAPARAZON, Estilo.MURALLA, Estilo.ESCUDO,
	Estilo.IMBUIR_FILO, Estilo.EN_GUARDIA, Estilo.VOTO_GUARDIA, Estilo.ACERO_EN_ALTO,
	Estilo.DESVANECER, Estilo.SED_SANGRE, Estilo.MARTILLO_EN_ALTO,
	Estilo.FOCO_ARCANO, Estilo.VELO_UMBRIO,
	Estilo.PROVOCACION_FX, Estilo.GUARDIA_CARNE_FX]
const _ESTILOS_DE_GRUPO := [Estilo.BARRIDO, Estilo.SPLAT, Estilo.VORTICE, Estilo.EXPLOSION,
	Estilo.ARRASTRE, Estilo.CHILLIDO, Estilo.PISOTON, Estilo.RAICES, Estilo.RODADA,
	Estilo.CARGA,
	# Los del mandoble que alcanzan a varios: un molinete es UN giro que coge a tres, no tres
	# molinetes pequeños; y lo mismo el barrido bajo de Segar y la onda del Grito.
	Estilo.MOLINETE, Estilo.SEGAR, Estilo.GRITO_GUERRA,
	# Las tres del martillo que sacuden el SUELO. Un terremoto es UNO y coge a los que coge: pintar
	# uno por bicho serian tres temblores pequeños al lado, que es justo lo contrario.
	Estilo.GOLPE_SISMICO, Estilo.ONDA_EXPANSIVA, Estilo.TEMBLOR_SUELO]

func _marcar_efectos_de_grupo() -> void:
	var por_tanda: Dictionary = {}   # "tanda:estilo" -> [indices de la cola]
	for i in _cola.size():
		var es: int = int(_cola[i].get("estilo", Estilo.MELEE))
		if not _ESTILOS_DE_GRUPO.has(es):
			continue
		# La clave lleva el ESTILO: si en una misma tanda cayeran una ola y un splat, cada uno tiene
		# que quedarse con su propia portadora.
		var k: String = "%d:%d" % [int(_cola[i].get("tanda", 0)), es]
		if not por_tanda.has(k):
			por_tanda[k] = []
		(por_tanda[k] as Array).append(i)
	for k in por_tanda:
		var idx: Array = por_tanda[k]
		var izq: float = INF
		var der: float = -INF
		var portadora: int = -1
		for i in idx:
			var b: Dictionary = _cola[i]["bv"]
			var p: Control = b.get("panel")
			if p == null or not is_instance_valid(p):
				continue
			var c: Vector2 = _punto(b)
			var w: float = _ancho_tarjeta(b)
			izq = minf(izq, c.x - w * 0.5)
			der = maxf(der, c.x + w * 0.5)
			# La portadora es la de MAS A LA IZQUIERDA: da igual cual sea mientras sea estable, pero
			# asi el centro cae donde tiene que caer aunque solo haya una.
			if portadora < 0 or c.x < _punto(_cola[portadora]["bv"]).x:
				portadora = i
		if portadora < 0:
			continue
		for i in idx:
			if i != portadora:
				_cola[i]["sin_dibujo"] = true
		_cola[portadora]["ancho_grupo"] = maxf(der - izq, 1.0)
		_cola[portadora]["centro_grupo"] = (izq + der) * 0.5


# La tanda del ULTIMO golpe encolado, o -1 si no hay ninguno. La pregunta combat.gd justo despues
# de encolar, para contarle al espejo cuando empieza una tanda nueva sin tener que llevar la
# cuenta por su lado (y arriesgarse a que las dos cuentas se separen).
func ultima_tanda() -> int:
	return int(_cola[-1].get("tanda", 0)) if not _cola.is_empty() else -1


func ocupado() -> bool:
	return _activa


# Deja todo como estaba, YA. La llama _desatascar (tecla P) y el final de la pelea. Como la cola
# no decide turnos, cortarla no puede perder ni duplicar ninguno: se descarta lo que quedaba de
# animacion y punto.
func cancelar() -> void:
	_cola.clear()
	_activa = false
	_t = 0.0
	_dur = 0.0
	_tanda_auto = -1
	_tanda_pedida = -1
	for b in _tarjetas:
		_reposo(b)
	for n in _numeros:
		_soltar_numero(n)
	_numeros.clear()
	# Y los rayos y bolas que estuvieran en el aire, o se quedan pintados para siempre.
	if _capa_fx != null and is_instance_valid(_capa_fx):
		_capa_fx.limpiar()
	_saldar_barras()   # los golpes que no se llegaron a ver ya han pasado: la vida, a la real
	_snap_barras()


func diagnostico() -> String:
	return "fx: %d impactos en cola (%.2fs de %.2fs), %d numeros, %d tarjetas" % [
		_cola.size(), _t, _dur, _numeros.size(), _tarjetas.size()]


func _reposo(bloque: Dictionary) -> void:
	var panel: Control = bloque.get("panel")
	if panel == null or not is_instance_valid(panel):
		return
	panel.position = Vector2.ZERO
	panel.scale = Vector2.ONE
	panel.rotation = 0.0
	panel.self_modulate = Color.WHITE


func _process(delta: float) -> void:
	# TODO el combate corre a esta escala: las embestidas, los dibujos, las barras y los numeros.
	# Escalando el DELTA en un solo sitio no hay que tocar ni una de las constantes de tiempo, y no
	# se puede quedar una parte a otro ritmo (que es lo que pasaria ajustandolas una a una).
	var dt: float = delta * escala_tiempo
	_mover_barras(dt)
	_mover_numeros(dt)
	if not _activa:
		return
	_t += dt

	# Lo que le toca a cada panel ESTE frame. Se acumula en un diccionario y se aplica al final:
	# un mismo atacante puede tener varios impactos solapados y hay que quedarse con uno, no
	# sumarlos (se iria a tomar viento).
	var mov: Dictionary = {}      # panel -> Vector2
	var flash: Dictionary = {}    # panel -> float 0..1
	var punch: Dictionary = {}    # panel -> float 0..1
	var aura: Dictionary = {}     # panel -> [Color, float 0..1]: el brillo del que CANALIZA

	for i in _cola.size():
		var ev: Dictionary = _cola[i]
		var t_imp: float = ev["t"]
		var estilo: int = int(ev.get("estilo", Estilo.MELEE))
		var peso: float = float(ev.get("peso", 1.0))
		var pa: Control = ev["ba"].get("panel") if not ev["ba"].is_empty() else null
		var pv: Control = ev["bv"].get("panel")
		if pv == null or not is_instance_valid(pv):
			continue

		# EL DIBUJO sale ANTES que el golpe, lo que tarde en volar, para que llegue justo a tiempo.
		# OJO con el `vuelo > 0.0`: es lo que hace que el MELEE no pinte nada, o sea que un estilo
		# SIN entrada en T_VUELO (o con un 0.0) queda mudo para siempre y sin dar ningun error. Si
		# añades un estilo, dale vuelo aunque su efecto no viaje. Ver la nota en T_VUELO.
		var vuelo: float = float(T_VUELO.get(estilo, 0.0))
		if not ev["fx_lanzado"] and vuelo > 0.0 and _t >= t_imp - vuelo:
			ev["fx_lanzado"] = true
			# 'sin_dibujo' lo pone _marcar_efectos_de_grupo: de una tanda de ola o de splat solo se
			# dibuja UNO (son una cosa grande, no un proyectil por cabeza). Los demas siguen con su
			# numero y su temblor.
			if _capa_fx != null and not bool(ev.get("sin_dibujo", false)):
				# El portador cubre TODO lo alcanzado: va al centro del grupo y con el ancho de
				# todos. Lo demas apunta a su tarjeta y lleva el ancho de una.
				var destino: Vector2 = _punto(ev["bv"])
				var ancho: float = _ancho_tarjeta(ev["bv"])
				if ev.has("ancho_grupo"):
					destino.x = float(ev["centro_grupo"])
					ancho = float(ev["ancho_grupo"])
				_capa_fx.alta(estilo, _punto(ev["ba"]), destino, ev["color"], peso, vuelo, ancho)

		# EL SONIDO, en el mismo frame que el dibujo. Tiene su propio guardian y NO copia el `if` de
		# arriba, por tres motivos:
		#
		#   - SIN el `vuelo > 0.0`. Esa condicion es justo la que deja al MELEE sin dibujo, y un
		#     puñetazo si tiene que sonar. Con vuelo 0 se queda en `_t >= t_imp`, o sea el instante
		#     del impacto, que es cuando suena un golpe que no viaja.
		#   - SI respeta 'sin_dibujo': de una marea que coge a cuatro suena UNA, igual que se dibuja
		#     una sola (ver _marcar_efectos_de_grupo).
		#   - Va ANTES del 'continue' de aqui abajo, porque los adornos -el Bramido, el Alarido, la
		#     Ignicion, los caparazones- son precisamente los que mas piden sonido.
		if not ev["sfx_lanzado"] and _t >= t_imp - vuelo:
			ev["sfx_lanzado"] = true
			if not bool(ev.get("sin_dibujo", false)):
				Sonido.golpe(String(ev.get("sfx", "")), estilo, peso, bool(ev["crit"]))

		# UN ADORNO no impacta: se ha pintado y ya. Ni numero, ni barra, ni sacudida (el 'continue'
		# se salta tambien la embestida y el temblor de mas abajo). Ver 'solo_dibujo' en encolar.
		if bool(ev.get("solo_dibujo", false)):
			continue

		# EL IMPACTO: se dispara una vez, justo al cruzar su instante.
		if not ev["lanzado"] and _t >= t_imp:
			ev["lanzado"] = true
			_soltar_numero_de(ev)
			# Y ESTE golpe le quita SU parte a la barra, justo ahora: lo que baja la vida es
			# exactamente el numero que acaba de salir volando.
			_descontar(ev["bv"], float(ev["dmg"]) if not bool(ev["evadido"]) else 0.0)

		# EMBESTIDA del atacante. SOLO EN MELEE: un mago no se lanza contra el bicho para tirarle
		# una bola de fuego, se queda donde esta y lo que viaja es el conjuro. De la 7ª TANDA en
		# adelante tampoco se mueve nadie: con esa densidad el movimiento se lee como ruido.
		#
		# Cuenta la TANDA y no el indice del evento: si no, un molinete a cuatro bichos gastaba el
		# cupo con el primer barrido y el atacante se quedaba plantado en el segundo.
		# Quien EMBISTE sale de _CUERPO_A_CUERPO: son los estilos en los que el bicho tiene que
		# llegar hasta ti (morder, cornear, placar, pisar), y de hecho es la embestida la que lleva
		# el efecto al sitio -- por eso su T_VUELO es casi cero.
		if pa != null and is_instance_valid(pa) and pa != pv \
				and _CUERPO_A_CUERPO.has(estilo) \
				and int(ev.get("pos_tanda", i)) < MAX_IMPACTOS_ANIMADOS:
			var dir: Vector2 = _direccion(pa, pv)
			var d: float = 0.0
			if _t < t_imp and _t >= t_imp - T_IDA:
				# Acelerando (u*u): un lanzamiento arranca despacio y llega lanzado.
				var u: float = (_t - (t_imp - T_IDA)) / T_IDA
				d = DIST_EMBESTIDA * u * u
			elif _t >= t_imp and _t < t_imp + T_VUELTA:
				var u2: float = (_t - t_imp) / T_VUELTA
				d = DIST_EMBESTIDA * (1.0 - u2 * u2)
			if d > 0.0:
				var v: Vector2 = dir * d
				if not mov.has(pa) or v.length() > (mov[pa] as Vector2).length():
					mov[pa] = v

		# CANALIZACION: lo que hace el lanzador en vez de embestir. Su tarjeta se enciende del
		# color del elemento mientras el conjuro esta en el aire. Los de CAIDA no la encienden: de
		# un rayo que cae del cielo no sale nada de tu mano.
		# Los de CAIDA y el SPLAT no la encienden (no sale de tu mano, viene de arriba); el ARCO
		# tampoco (salta de una victima a otra); ni el AURA, que es fuego SOBRE el propio bicho y ya
		# se ve de sobra sin encenderle ademas la tarjeta. Y NINGUNO de los de cuerpo a cuerpo: esos
		# ya embisten, y encenderlos encima los convertiria en un conjuro.
		# El CHILLIDO si se queda dentro -- el grito SALE del Rey, y que se le encienda la tarjeta
		# mientras la onda viaja es exactamente lo que se quiere leer.
		if pa != null and is_instance_valid(pa) and not _CUERPO_A_CUERPO.has(estilo) \
				and estilo != Estilo.CAIDA_RAYO and estilo != Estilo.CAIDA_GOTA \
				and estilo != Estilo.ARCO and estilo != Estilo.SPLAT \
				and estilo != Estilo.AURA \
				and _t >= t_imp - vuelo and _t < t_imp:
			var k: float = 1.0 - (t_imp - _t) / maxf(vuelo, 0.001)
			if not aura.has(pa) or k > float(aura[pa][1]):
				aura[pa] = [ev["color"], k]

		# SACUDIDA + FLASH + PUNCH de la victima, desde el instante del golpe.
		# Los de CAIDA pegan mas fuerte y mas rato: un rayo del cielo es un pisoton, no un empujon.
		# El SPLAT entra aqui de cabeza: que te caiga un slime entero encima es el pisoton por
		# excelencia, mas que un rayo.
		var cae: bool = estilo == Estilo.CAIDA_RAYO or estilo == Estilo.CAIDA_GOTA \
			or estilo == Estilo.SPLAT
		var t_sac: float = T_SACUDIDA * (1.2 if cae else 1.0)
		if _t >= t_imp and _t < t_imp + t_sac and not bool(ev["evadido"]):
			var u3: float = (_t - t_imp) / t_sac
			# El PESO es lo que hace que el adyacente que come la mitad tiemble la mitad.
			var amp: float = AMP_SACUDIDA * peso * (1.15 if cae else 1.0) \
				* (1.0 - u3) * (1.5 if bool(ev["crit"]) else 1.0)
			# Deterministico y de frecuencias distintas en X e Y: parece un golpe, no una vibracion.
			var s: Vector2 = Vector2(sin(u3 * 71.0), cos(u3 * 53.0)) * amp
			if not mov.has(pv) or s.length() > (mov[pv] as Vector2).length():
				mov[pv] = s
			if _t < t_imp + T_FLASH:
				flash[pv] = 1.0 - (_t - t_imp) / T_FLASH
			var t_punch: float = T_PUM
			if _t < t_imp + t_punch:
				punch[pv] = (1.0 - (_t - t_imp) / t_punch) * peso

	_aplicar(mov, flash, punch, aura)

	if _t >= _dur:
		_activa = false
		_cola.clear()
		_saldar_barras()
		for b in _tarjetas:
			_reposo(b)


# Un frame de animacion sobre los paneles. Los que no participan vuelven a reposo: es lo que
# garantiza que nadie se quede torcido si una racha se corta a medias.
func _aplicar(mov: Dictionary, flash: Dictionary, punch: Dictionary, aura: Dictionary) -> void:
	for b in _tarjetas:
		var panel: Control = b.get("panel")
		if panel == null or not is_instance_valid(panel):
			continue
		panel.position = mov.get(panel, Vector2.ZERO)
		var f: float = flash.get(panel, 0.0)
		# self_modulate y NO modulate: modulate es de _apagar_bloque (el gris del cadaver) y
		# pisarlo resucitaria visualmente a los muertos cada vez que les pegan.
		#
		# El aura del que canaliza se pliega AQUI, en la misma expresion, y no se escribe aparte:
		# esta linea corre cada frame para todas las tarjetas, asi que cualquier otro que tocara
		# self_modulate por su cuenta se lo comeria al frame siguiente.
		var col: Color = Color(1.0 + 0.6 * f, 1.0 + 0.6 * f, 1.0 + 0.6 * f)
		if aura.has(panel):
			col = col.lerp((aura[panel][0] as Color) * 1.35, 0.35 * float(aura[panel][1]))
		panel.self_modulate = col
		var p: float = punch.get(panel, 0.0)
		if p > 0.0:
			panel.pivot_offset = panel.size * 0.5
			panel.scale = Vector2.ONE * (1.0 + 0.06 * p)
			panel.rotation = deg_to_rad(1.5 * p)
		else:
			panel.scale = Vector2.ONE
			panel.rotation = 0.0


# El centro de una tarjeta en coordenadas de la capa de efectos. Si el bloque esta vacio (un
# hechizo que "cae del cielo" no tiene tarjeta de origen) devuelve un punto por encima del techo,
# que es justo de donde tiene que venir.
func _punto(bloque: Dictionary) -> Vector2:
	if bloque.is_empty() or capa_numeros == null or not is_instance_valid(capa_numeros):
		return Vector2.ZERO
	var p: Control = bloque.get("panel")
	if p == null or not is_instance_valid(p):
		return Vector2.ZERO
	return p.get_global_rect().get_center() - capa_numeros.global_position


func _ancho_tarjeta(bloque: Dictionary) -> float:
	var p: Control = bloque.get("panel")
	if p == null or not is_instance_valid(p):
		return 120.0
	return p.size.x


# Hacia donde se lanza el que pega. La horizontal sale de los centros reales de las dos tarjetas;
# la vertical es fija por bando (los enemigos van arriba y tu abajo), porque dos tarjetas de la
# MISMA fila estan a la misma altura y sin esto un golpe entre vecinos no se veria ir a ningun sitio.
func _direccion(pa: Control, pv: Control) -> Vector2:
	var ca: Vector2 = pa.get_global_rect().get_center()
	var cv: Vector2 = pv.get_global_rect().get_center()
	var d: Vector2 = cv - ca
	if d.length() < 1.0:
		return Vector2.DOWN
	return d.normalized()


# ============================================================
#  NUMEROS FLOTANTES
# ============================================================

func _soltar_numero_de(ev: Dictionary) -> void:
	if capa_numeros == null or not is_instance_valid(capa_numeros):
		return
	var pv: Control = ev["bv"].get("panel")
	if pv == null or not is_instance_valid(pv):
		return
	var crit: bool = bool(ev["crit"])
	var evadido: bool = bool(ev["evadido"])
	var lbl: Label = _coger_numero()
	if evadido:
		lbl.text = "FALLA"
		lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		lbl.add_theme_font_size_override("font_size", 18)
	else:
		# Con DOS DECIMALES, igual que el log y que los numeros de dentro de las barras: si el
		# numero que vuela dice 134 y la barra dice 134.42, parecen dos cuentas distintas.
		lbl.text = "%.2f" % maxf(float(ev["dmg"]), 0.0)
		if crit:
			lbl.text += "!"
		lbl.add_theme_color_override("font_color", ev["color"])
		lbl.add_theme_font_size_override("font_size", 28 if crit else 19)

	# El sitio: DENTRO de la tarjeta que lo come, en su tercio alto, no pegado a su borde de
	# arriba. La fila de enemigos esta casi tocando el techo de la pantalla, asi que naciendo en
	# el borde y subiendo 26 px, sus numeros se salian por arriba y no se leian.
	var r: Rect2 = pv.get_global_rect()
	var base: Vector2 = r.get_center() - capa_numeros.global_position
	base.y = (r.position.y + r.size.y * 0.34) - capa_numeros.global_position.y

	# Que una racha no se lea como un borron: cada numero sobre la MISMA tarjeta baja un poco y
	# se aparta en zigzag, asi ocho golpes seguidos quedan en escalerilla y se pueden contar.
	var seq: int = int(ev["bv"].get("fx_num_seq", 0))
	ev["bv"]["fx_num_seq"] = seq + 1
	base.y += 12.0 * float(seq % 5)
	base.x += 14.0 * (1.0 if seq % 2 == 0 else -1.0) * float((seq % 4) / 2 + 1)
	# Y por si acaso: ninguno puede nacer tan arriba que al subir se salga de la pantalla. Es el
	# cinturon para las tarjetas cortas y para las resoluciones bajas.
	base.y = maxf(base.y, SUBIDA_NUMERO + 8.0)

	lbl.position = base - Vector2(60, 24)
	lbl.modulate.a = 1.0
	lbl.scale = Vector2.ONE
	lbl.visible = true
	_numeros.append({"lbl": lbl, "t": -(RETRASO_CRIT if crit else 0.0),
		"x": lbl.position.x, "y": lbl.position.y, "crit": crit})
	# Techo: si se pasa, el mas viejo se recicla en vez de dejar la pantalla llena.
	while _numeros.size() > MAX_NUMEROS:
		_soltar_numero(_numeros.pop_front())


func _mover_numeros(delta: float) -> void:
	var i: int = _numeros.size() - 1
	while i >= 0:
		var n: Dictionary = _numeros[i]
		n["t"] = float(n["t"]) + delta
		var t: float = n["t"]
		var lbl: Label = n["lbl"]
		if not is_instance_valid(lbl):
			_numeros.remove_at(i)
			i -= 1
			continue
		if t < 0.0:
			lbl.visible = false   # el critico espera un pelin a que se lea el impacto
			i -= 1
			continue
		lbl.visible = true
		var u: float = t / T_NUMERO
		if u >= 1.0:
			_soltar_numero(n)
			_numeros.remove_at(i)
			i -= 1
			continue
		# Sube frenando (1-(1-u)^2) y se apaga en el ultimo tercio.
		lbl.position = Vector2(n["x"], float(n["y"]) - SUBIDA_NUMERO * (1.0 - pow(1.0 - u, 2.0)))
		lbl.modulate.a = 1.0 if u < 0.65 else (1.0 - (u - 0.65) / 0.35)
		if bool(n["crit"]) and u < 0.18:
			var k: float = 1.0 - u / 0.18
			lbl.scale = Vector2.ONE * (1.0 + 0.3 * k)
		else:
			lbl.scale = Vector2.ONE
		i -= 1


# Los Labels se RECICLAN, nunca se liberan en caliente: en una racha de area se crearian y
# destruirian 25 nodos en medio segundo.
func _coger_numero() -> Label:
	if not _pool.is_empty():
		var l: Label = _pool.pop_back()
		if is_instance_valid(l):
			return l
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.size = Vector2(120, 48)
	lbl.pivot_offset = Vector2(60, 24)
	# Contorno negro: sin el, un numero claro sobre la tarjeta clara no se lee. Mismo apaño que
	# los numeros de dentro de las barras (_crear_label_barra).
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	capa_numeros.add_child(lbl)
	return lbl


func _soltar_numero(n: Dictionary) -> void:
	var lbl: Label = n.get("lbl")
	if lbl != null and is_instance_valid(lbl):
		lbl.visible = false
		_pool.append(lbl)
