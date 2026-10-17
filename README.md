# Motocle: Operación Campus

Plataformas 2D hecho en **Godot 4** (probado con Godot 4.3+) para tu clase en la UTT.
Motocle recorre 5 edificios del campus (Sistemas, Enfermería, Cafetería, Auditorio y El H) para rescatar a Avelina de las garras de **GLITCH.exe**.

## Cómo abrirlo

1. Instala Godot 4.x (recomendado 4.3 o superior) desde godotengine.org — es gratis.
2. Abre Godot, elige "Importar", selecciona la carpeta de este proyecto y el archivo `project.godot`.
3. Dale play (▶) o F5. La escena inicial es `scenes/Main.tscn`.

Este proyecto ya se probó en modo headless con Godot 4.3 (carga de todas las escenas sin errores), pero vale la pena que lo juegues tú mismo antes de mostrarlo en clase.

## Controles

- **Mover:** Flechas ← → o A / D (o Stick Izquierdo / D-Pad en Gamepad)
- **Saltar:** W, ↑ o Espacio (o Botón A / Cruz en Gamepad)
  - *Soporta salto variable:* mantener presionado para saltar más alto, o pulsar rápido para un salto corto.
  - *Asistencias de juego profesional:* incluye **Coyote Time** (salto al dejar repisas) y **Jump Buffer** (registro anticipado de salto).
- **Agacharse y Gatear:** Mantener S o Flecha ↓ (o D-Pad Abajo en Gamepad) + moverse con A/D o flechas
  - Reduce la hitbox de Motocle a la mitad para esquivar proyectiles que vuelen alto.
  - Permite desplazarse a velocidad táctica (duck-walk / gateo) manteniendo la silueta baja.
  - Permite disparar a ras del suelo mientras estás agachado.

- **Disparar:** J o Clic Izquierdo (o Botón X / Cuadrado en Gamepad)
- **Ataque especial (hadouken):** K (o Botón Y / Triángulo) cuando la barra está llena.
- **Escudo UTT (nivel 2 en adelante):** mantener I (o L1 / LB en Gamepad).
- **Pausa:** Escape o P (o Botón Start en Gamepad, o clic en botón `⏸` del HUD)
  - Despliega el menú de pausa con opciones de Reanudar, Reiniciar Nivel y Menú Principal.

## Sistema de Puntuación
- Ardilla Zombie Shambler: +100 pts
- Ardilla Zombie Runner: +150 pts
- Ardilla Zombie Rotten: +200 pts
- Enemigos regulares: +100 pts
- Fragmento de Avelina: +500 pts
- Jefes de nivel: +1,000 pts


## Estructura del proyecto

```
project.godot        -> configuración del proyecto (autoload GameManager, ventana, física)
scripts/
  GameManager.gd      -> autoload: vida del jugador, progreso de niveles, diálogos, game over / "zombificación"
  Player.gd            -> movimiento y disparo de Motocle
  Bullet.gd             -> proyectil reutilizado por jugador y enemigos
  Enemy.gd              -> enemigo genérico (patrulla + dispara), reutilizado en los niveles 2-5
  ZombieEnemy.gd         -> enemigo zombie (persigue a Motocle, no dispara, tocarlo = derrota instantánea)
  Boss.gd                -> jefe de nivel (más vida, barra de vida, ráfagas)
  Fragment.gd             -> el fragmento holográfico de Avelina que aparece tras vencer al jefe
  ExitDoor.gd              -> puerta de salida, se activa al recoger el fragmento
  Level.gd                  -> conecta jefe -> fragmento -> diálogo -> salida en cada nivel
  LoadingScreen.gd          -> pantalla de carga táctica y briefing de misión por edificio
  HUD.gd, Main.gd, WinScreen.gd, DialogueBox.gd, PauseMenu.gd -> interfaz
scenes/
  Main.tscn              -> menú principal
  LoadingScreen.tscn     -> pantalla de carga y briefing entre niveles
  PauseMenu.tscn         -> menú de pausa con reanudar, reiniciar y menú principal
  Player.tscn, Enemy.tscn, Boss.tscn, Bullet.tscn, Fragment.tscn, ExitDoor.tscn, Platform.tscn, HUD.tscn, DialogueBox.tscn -> piezas reutilizables

  ZombieShambler.tscn, ZombieRunner.tscn, ZombieRotten.tscn -> los 3 tipos de zombie de la horda del nivel 1
  Level1_Sistemas.tscn, Level2_Biblioteca.tscn (Enfermería), Level3_Cafeteria.tscn, Level4_Auditorio.tscn, Level5_ElH.tscn -> los 5 niveles
  (el archivo del nivel 2 conserva el nombre "Biblioteca" para no romper rutas, pero el nivel es la Enfermería)
  WinScreen.tscn          -> pantalla de victoria
assets/
  sprites/    -> Motocle (recortado de tu imagen de referencia), Avelina y todos los enemigos/jefes
  sprites/run/  -> los 10 cuadros de la animación de correr (de tu spritesheet)
  sprites/jump/ -> 5 cuadros de salto + 5 de caída (de tu spritesheet)
  sprites/zombies/ -> los 3 tipos de zombie (shambler, runner, rotten), de tu spritesheet
  backgrounds/ -> un fondo por edificio (incluye el fondo verdoso/nublado del brote zombie)
  tiles/       -> textura de piso/plataforma reutilizada en todos los niveles
```

## Animaciones de Motocle

Motocle usa un `AnimatedSprite2D` con 4 animaciones (definidas en `Player.tscn`,
recurso `SpriteFrames`), y `Player.gd` decide cuál mostrar según su estado físico:

- **idle** — parado, 10 cuadros en bucle (tu hoja de "breathing cycle"), se activa
  cuando Motocle está quieto en el suelo. Antes era un solo cuadro fijo; ahora respira
  sutilmente mientras espera.
- **run** — 10 cuadros en bucle, se activa al moverse mientras está en el suelo.
- **jump** — 5 cuadros, una sola pasada (no hace loop), se activa al saltar mientras sube (`velocity.y < 0`).
- **fall** — 5 cuadros, una sola pasada, se activa al caer (`velocity.y >= 0` y no está en el suelo).

Los cuadros de correr/salto/caída salieron de las hojas de sprites que subiste: los
recorté automáticamente (detectando cada personaje por separado para no mezclar el
rifle de un cuadro con el de al lado), les quité el fondo y la sombra de piso, y los
alineé todos por los pies en un lienzo del mismo tamaño para que no "salten" visualmente
al cambiar de cuadro.

Si quieres ajustar la velocidad de una animación, o cambiar si hace loop o no, edita
el `SpriteFrames` sub_resource dentro de `Player.tscn` desde el editor de Godot
(seleccionas el nodo `AnimatedSprite2D` y ahí abajo aparece el panel de animaciones).

## Nivel 1: brote zombie

El Edificio de Sistemas se reskineó como una escena de horda zombie, con un recorrido
largo (nivel de 3000px de ancho, casi el doble que los demás niveles) antes de llegar
al jefe. Hay 12 ardillas zombie repartidas por el nivel, de tres tipos
(`ZombieShambler.tscn`, `ZombieRunner.tscn`, `ZombieRotten.tscn`), todas usando el
mismo script `ZombieEnemy.gd`:

- **A diferencia de los enemigos normales, no disparan** — solo persiguen a Motocle
  caminando/corriendo hacia su posición horizontal (`get_first_node_in_group("player")`).
- **Tocar a un zombie es derrota instantánea** (`instant_kill = true`), sin importar
  cuánta vida le quede a Motocle — `Player.gd` detecta esta bandera en el contacto y
  llama a `GameManager.zombify_player()` en vez de restarle vida.
- Sí se pueden matar a balazos como cualquier enemigo (tienen vida y `take_damage`),
  así que conviene dispararles antes de que se acerquen.
- Los tres tipos comparten la misma escala (misma altura que Motocle) pero varían en
  velocidad y vida: Shambler es lento pero constante, Runner es el más peligroso
  (corre hacia ti), Rotten es lentísimo pero aguanta más disparos.
- **Los enemigos ya no se encima entre ellos.** Todos los enemigos (zombies, `Enemy.gd`
  y los jefes) ahora chocan físicamente unos con otros (`collision_mask` incluye la
  capa ENEMY además de WORLD), y si un enemigo choca con otro cambia de dirección para
  alejarse en vez de quedarse empujando en el mismo lugar. En los zombies
  (`ZombieEnemy.gd`) esto es temporal: al chocar se alejan del otro zombie por
  `AVOID_TIME` (0.35s) y luego retoman la persecución a Motocle; en los enemigos y
  jefes de patrulla (`Enemy.gd`, `Boss.gd`, `ZombieBoss.gd`) simplemente invierte su
  dirección de patrulla, igual que cuando llegan al límite de `patrol_range`.
- **Al morir, cada zombie reproduce su propia animación de muerte de 6 cuadros**
  (`shambler_death_01..06.png`, `runner_death_01..06.png`, `rotten_death_01..06.png`,
  recortados de la hoja de secuencias de muerte que compartiste) y se queda quieto en
  el último cuadro — sus restos — en vez de desaparecer. En `ZombieEnemy.gd`, cuando la
  vida llega a 0 se llama a `_die()`: se congela el movimiento, se saca al zombie del
  grupo `"enemy"` y se desactiva su colisión (`collision_layer/mask = 0`) para que ya
  no bloquee a Motocle ni a otros zombies ni cuente para el contagio, y se reproduce la
  animación `"death"` (sin loop) del `AnimatedSprite2D` — al terminar, se queda
  congelada sola en el último cuadro, no hace falta borrar el nodo.

**Sonidos de los zombies.** Mientras persiguen a Motocle (a menos de 750 px) se quejan
cada 2.5-6 s con uno de 3 quejidos roncos (`zombie_groan_1/2/3.wav`); como máximo 3
zombies se quejan al mismo tiempo para que no sea un ruidero. Al morir lanzan un grito
de agonía corto (`zombie_scream.wav`). El tono cambia por tipo: Runner más agudo, Rotten
más grave. El Profesor Zombie también se queja y grita al morir, con voz más grave.
Los sonidos están generados por síntesis; se pueden reemplazar por otros `.wav` con el
mismo nombre.

Para agregar más zombies a la horda, o cambiar sus posiciones, solo duplica cualquiera
de los nodos `ZombieX` dentro de `Level1_Sistemas.tscn` y ajusta su `position`.

El arte original del nivel (`assets/backgrounds/bg_zombies.png`, "Puebla Tecamachalco —
Zona de Contención Zombie", 1584x672) ahora es la capa media del parallax con escala
**uniforme** 1.3 (antes estaba estirada 1.96 × 1.18 y se deformaba). Ver la sección
"Perspectiva 2.5D" más abajo.

El nivel mide **3900 px** (30 % más que la versión anterior) y tiene 16 zombies.
Antes de llegar al jefe hay 17 plataformas en varias alturas: una escalera hacia una
torre de vigilancia, una plataforma móvil horizontal, una ruta alta que llega hasta
y = 230 y un elevador vertical.

### Derrumbe en la zona del jefe

Cuando Motocle cruza `collapse_trigger_x` (x = 3330, propiedad de `Level.gd`):

1. Aparece el aviso "¡LA ESTRUCTURA SE ESTÁ DERRUMBANDO!", la cámara se sacude y
   **todas las plataformas flotantes del nivel empiezan a temblar** (sueltan polvo
   por abajo). Mientras el jefe siga vivo hay retumbos periódicos.
2. **Primer aterrizaje** sobre una plataforma: se agrieta, suena un crujido y tiembla más.
3. **Segundo aterrizaje**: tiembla violentamente durante 0.38 s (tiempo para saltar) y
   se rompe. Los trozos salen volando con giro y gravedad, sale una nube de polvo
   (`scripts/PlatformDebris.gd`) y la colisión se desactiva.

**Plataformas frágiles desde el inicio:** en el nivel 1 la propiedad `fragile_platforms`
de `Level.gd` está activa, así que todas las plataformas flotantes cuentan aterrizajes
desde que empieza el nivel: al primer contacto se agrietan y empiezan a temblar, y al
segundo se rompen con la misma animación. El aviso de la zona del jefe hace temblar las
que todavía no se han pisado.

El número de aterrizajes se configura con `landings_to_break` en cada plataforma, y el
sonido es `assets/audio/crumble.wav`. Para usar el derrumbe en otro nivel basta con
poner `collapse_trigger_x` en su nodo raíz. Si Motocle muere, el nivel se recarga y
las plataformas vuelven a estar completas.

## Perspectiva 2.5D, fondos y plataformas

Los 5 niveles usan ahora una presentación **2.5D** (mundo 2D que simula profundidad):

**Fondo en capas (parallax).** Cada nivel tiene un nodo `Fondo` con capas
`Parallax2D` que se mueven a distinta velocidad que la cámara:

| Capa | `scroll_scale` | Qué contiene |
|---|---|---|
| `Cielo` | 0 (fija) | degradado de cielo / pared del fondo |
| `Lejano` | 0.15 | ventanales, telones, siluetas de edificios |
| `Medio` | 0.40 | estantes, racks, butacas, máquinas |
| `Cercano` | 0.75 | mesas, bocinas, barricadas |
| `PrimerPlano` | 1.30 | siluetas que pasan **delante** del jugador |

Las capas lejanas tienen un `modulate` más oscuro/apagado (perspectiva atmosférica)
para que el área de juego destaque. Las imágenes están en
`assets/backgrounds/<edificio>/` (`cielo`, `lejano`, `medio`, `cercano`, `frente`) y se
repiten en horizontal sin costura. Se puede ajustar todo desde el editor: mueve el
`Sprite2D` de una capa o cambia su `scroll_scale`.

**Plataformas con volumen (`scripts/Platform25D.gd`).** `Platform.tscn` ya no es un
sprite plano: dibuja una cara superior que se aleja hacia el fondo, una cara frontal y
una cara lateral que aparece según de qué lado de la cámara esté (el punto de fuga es
el centro de la cámara, así que las caras cambian al caminar, como en 3D). Propiedades:

- `size`: ancho y grosor. El origen es el **centro del borde superior**: una plataforma
  en y = 455 deja a los personajes parados en y = 455.
- `is_ground`: piso largo y sólido. El piso puede tener **huecos** (pits) entre segmentos;
  caer por uno = perder.
- `move_offset` / `move_duration`: plataforma móvil de ida y vuelta (lleva al jugador).
- `supports`: patas/andamios que bajan hasta el piso.
- El estilo (concreto, biblioteca, cafeteria, auditorio, servidor) lo aplica `Level.gd`
  con su propiedad `platform_style`.

Las plataformas flotantes son **de un solo sentido** (`one_way_collision`): se atraviesan
saltando desde abajo, estilo Metal Slug.

**Sombras (`scripts/Shadow25D.gd`).** `Level.gd` agrega una sombra elíptica bajo Motocle
y cada enemigo; se hace más chica y tenue mientras más alto salta.

**Cámara.** `Level.gd` pone límites a la cámara según `level_width`, así ya no se ven
zonas grises fuera del mapa.

**Alturas de salto.** El salto máximo de Motocle es ~110 px de alto y ~210 px de largo.
Los escalones están a 455 / 380 / 305 / 230 (75-77 px entre niveles) y ningún hueco pasa
de 140 px. Las plataformas originales quedaban a 113 px del piso, justo fuera de alcance.

| Nivel | Ancho | Plataformas | Huecos | Móviles |
|---|---|---|---|---|
| 1 Sistemas | 3000 | 14 | 0 (horda zombie) | 1 horizontal |
| 2 Enfermería | 3780 | 20 | 4 | 1 vertical + 1 horizontal |
| 3 Cafetería | 2700 | 11 | 1 | 1 horizontal (charola) |
| 4 Auditorio | 2900 | 14 | 1 (foso de orquesta) | 1 horizontal (rig de luces) |
| 5 El H | 3000 | 14 | 3 | 2 elevadores |

## Nivel 2: la Enfermería — mini ardillas y el Dr. Ardilla

El nivel 2 transcurre en la **enfermería del campus**. Tendrá 4 tipos de enemigos secundarios; el primero ya está listo.
(Los libros voladores provisionales se quitaron.)

**Mini ardilla (`MiniSquirrel.tscn` + `scripts/MiniSquirrel.gd`)** — 10 en el nivel
(el nivel 2 mide 3780 px, 40 % más que antes).
Corre de un lado a otro del pasillo entre `left_limit` y `right_limit` y no se cae
por las orillas (usa un `RayCast2D` que revisa el piso de enfrente). Cuando Motocle
está a menos de `detect_range` (290 px) y a su altura, se lanza desde lejos (410 px/s):

0. **Persigue** (modo agresivo): si Motocle está a menos de `chase_range` (460 px) y a
   su altura, deja de patrullar y corre hacia él a `chase_speed` (195 px/s). Si llega a la
   orilla de su repisa o al límite de su pasillo, se queda ahí acechando.
1. **Prepara** (0.18 s): se agacha con cara de rabia (aviso para el jugador).
2. **Se lanza** hacia Motocle con el hocico abierto y suena `assets/audio/bite.wav`
   (gruñido + mordida). Si lo alcanza en el aire, le quita 1 corazón.
3. **Aterriza** y **se recupera** (0.3 s, momento ideal para dispararle) y en 0.45 s
   puede volver a lanzarse.

Tiene 20 de vida y da 150 puntos. Animaciones: `run` (6 cuadros), `windup`, `lunge`
(3 cuadros), `land`, `recover` y `death` (7 cuadros), en `assets/sprites/mini_squirrel/`.

**Muerte:** al bajarle la vida sale despedida hacia atrás por el golpe y reproduce tu
animación de 7 cuadros (aturdida con estrellitas, sale volando, cae mareada con ojos de
espiral y queda tendida con ojos en X). Se queda en el piso 1.6 s y luego se desvanece.

**Jefe: Dr. Ardilla (`DoctorBoss.tscn` + `scripts/DoctorBoss.gd`)** — reemplaza al
Catálogo Central. Espera quieto hasta que **aparece en pantalla** (en cuanto asoma su cuerpo por la orilla, `ON_SCREEN_MARGIN`) o Motocle llega a `intro_distance` (380 px), lo que pase primero;
entonces lo **recibe carcajeándose** ("¡JA, JA, JA!", animación de risa de 3 cuadros y
`assets/audio/doctor_laugh.wav`). Durante la bienvenida es invulnerable. Después pelea:
patrulla y lanza ráfagas de 3 jeringas apuntadas a Motocle, y cada vez que Motocle
pierde un corazón se vuelve a burlar riéndose.

**Mini ardillas más altas.** Se dibujan 25 % más grandes (escala 0.56) y su hitbox
llega más arriba (cápsula de 72 px), así que los disparos de pie sí les pegan;
agachado también.

**Ataque de ki.** Cada ráfaga usa la animación `ki_attack` (7 cuadros en
`assets/sprites/doctor_boss/attack_01..07.png`): carga ki morado en las manos, echa el
brazo atrás, lanza el golpe y en el cuadro de la explosión de ki (`KI_RELEASE_FRAME`) salen
las jeringas desde su puño (`KI_FIST`), con brillo morado (`KI_TINT`). Mientras ataca se
queda quieto y no se voltea. Los cuadros están alineados por los pies, así que el cuerpo
no "brinca" aunque el brazo se estire.

**Arena de la pelea.** Además del piso (x 3320–3780) y de las repisas que ya había
(3420 a y 440 y la móvil sobre el hueco), la arena tiene 5 repisas nuevas en tres
alturas, separadas de 75 a 90 px para que todas se alcancen de un salto (el salto
de Motocle sube ≈108 px):

| Repisa | Posición (x, y) | Ancho |
|---|---|---|
| Plataforma20 | (3270, 470) — sobre el hueco, sirve de puente | 100 |
| Plataforma21 | (3540, 365) — sobre el doctor | 150 |
| Plataforma22 | (3700, 380) — sobre la puerta de salida | 120 |
| Plataforma23 | (3400, 290) | 120 |
| Plataforma24 | (3680, 290) | 100 |

El doctor también puede teletransportarse a las repisas nuevas, así que ataca desde
más alturas.

**Teletransportación.** Cada 2 golpes que recibe (`hits_per_teleport`), el doctor
desaparece y reaparece en otra parte de la pantalla para atacar desde otro ángulo:

- **Desaparecer:** se estira hacia arriba y se adelgaza dentro de una columna de ki
  morado, con un anillo en el piso y chispas (`scripts/TeleportFx.gd`, sonido
  `assets/audio/teleport.wav`).
- **Elegir el nuevo lugar** (`_pick_teleport_spot`): busca un punto dentro de lo
  que se ve en pantalla que cumpla todo esto:
  - tiene piso firme o una repisa donde quepa completo;
  - no está en un hueco ni en una repisa que se mueve;
  - queda entre `teleport_min_dist` (230 px) y `teleport_max_dist` (560 px) de
    Motocle;
  - de preferencia, del lado contrario a donde estaba.
  
  Sobre una repisa no patrulla, para no caerse.
- **Reaparecer:** sale con otro destello, mira a Motocle y lanza de inmediato una
  ráfaga de jeringas.

Durante la teletransportación (~0.9 s) es invulnerable y no hace daño por contacto.
Si estaba a media ráfaga, la ráfaga se cancela. Para que lo haga más o menos seguido,
cambia `hits_per_teleport` en el inspector del jefe (0 = nunca).

**Derrota.** Al quedarse sin vida reproduce `defeat` (6 cuadros en
`assets/sprites/doctor_boss/defeat_01..06.png`): sorpresa con los ojos en blanco, el golpe,
de rodillas, cae al piso (con sacudida de cámara) y queda tendido con ojos en X y el
estetoscopio tirado. Deja de hacer daño, se oculta su barra de vida y se queda en el piso;
al terminar la animación aparece el fragmento de Avelina. En tu hoja los cuadros 2-6
estaban dibujados más chicos que el primero; se igualaron tomando como referencia el
espejo de la cabeza, para que no "se encoja" al caer. En los cuadros tendidos el cuerpo se ajusta por
cuadro (`DEFEAT_FRAME_OFFSETS`) para quedar apoyado en el piso, y la sombra se ensancha bajo
el cuerpo (`LYING_SHADOW`); lo mismo pasa con la sombra de las mini ardillas al morir.

**Repisas ensangrentadas y resbalosas.** Las plataformas del nivel 2 usan el estilo
`enfermeria` de `Platform25D.gd`: repisas metálicas blancas con franja verde, charcos de
sangre en la cara superior y chorros que escurren por el frente, con gotas que se forman
en la punta y caen (animado). Además `Level.gd` tiene `slippery_platforms = true`, así
que son **resbalosas**: al aterrizar Motocle patina unos 20 px y salpica sangre, y al
soltar la dirección tarda en frenar (~70 px contra ~12 px en piso normal). Los valores
están en `Player.gd` (`SLIP_ACCEL`, `SLIP_FRICTION`, `SLIP_LAND_PUSH`). El piso del
pasillo es linóleo morado y no resbala.

**Fondo del nivel 2 (enfermería).** Usa las 3 capas que compartiste, en
`assets/backgrounds/hospital/`, sin el magenta:
`lejano.png` (campus de noche por la ventana, scroll 0.15), `medio.png` (pasillo con
grietas moradas; los huecos que eran magenta ahora son transparentes y dejan ver el
campus de la capa lejana, scroll 0.40) y `cercano.png` (camas, carrito, sueros, camilla
y los doctorcitos asomándose, scroll 0.75). `frente.png` son siluetas del mismo
mobiliario que pasan por delante. Las capas de biblioteca anteriores siguen en
`assets/backgrounds/biblioteca/` por si las quieres reusar.

Los sprites se recortaron de las hojas con fondo magenta que compartiste (fondo quitado,
cuadros separados y alineados por los pies). Los sonidos se generaron por síntesis; para
cambiarlos, reemplaza los `.wav` con el mismo nombre.

## Perros zombie (nivel 1)

`scenes/ZombieDog.tscn` + `scripts/ZombieDog.gd`. Hay 8 en el nivel 1: 4 en el piso
(x 760, 1450, 2250, 2780) y 4 sobre repisas (1060, 1880, 2370, 2870).

- **Esperando:** sentados con la animación `sit` (tus 6 cuadros sentado gruñendo y
  babeando, en ida y vuelta a 5 fps). No se mueven.
- **Al acercarse Motocle** (`wake_range`, 480 px) **o si le disparan:**
  - Se levantan (`stand`: tus cuadros 2 y 1), gruñen y empiezan a correr con tu
    animación de carrera (`run`, 6 cuadros a 12 fps, que se acelera con su
    velocidad).
  - Corren de un lado a otro sobre su superficie y nunca se caen de una repisa
    corriendo (un rayo revisa el piso de enfrente).
  - Si Motocle está a su altura lo persiguen a toda velocidad (245).
  - Ya cerca (150 px) se le lanzan a morder con un salto; ese salto sí puede
    sacarlos de la repisa.
- **Mordida:** quita 1 corazón (no es derrota instantánea como los zombies) y suena
  `bite.wav`.
- **Hitbox:** además del cuerpo (95×55), tienen una caja para la cabeza (`HeadShape`,
  52×54, adelante y arriba) que se voltea con el perro. Así los disparos de pie le
  pegan en la cabeza, sin importar hacia dónde mire.
- **Muerte:** 14 de vida. Al morir aúllan y reproducen la animación `death`
  (`death_01..06.png`, ≈0.9 s): tambalean, se doblan, caen, intentan levantarse
  aullando y se desploman en un charco. Se quedan tirados un momento y se
  desvanecen. Dan 150 puntos y cuentan para la barra del especial.
- **Tamaño:** se dibujan 25 % más grandes (escala 1.25 en la escena); su hitbox y
  su alcance de mordida crecieron igual.

**Zombies en repisas.** Se agregaron 2 zombies sobre repisas del nivel 1: un
Shambler en la de x 1560 y un Rotten en la de x 2530. Usan la nueva opción
`stay_on_platform` de `ZombieEnemy.gd`: persiguen a Motocle pero se detienen en la
orilla en vez de lanzarse al vacío.

## Jefe del nivel 1: Profesor Zombie

> **Embestidas que destrozan repisas:** al embestir (ataque normal o persecución)
> el Profesor Zombie destroza las repisas que tiene enfrente a la altura de su
> cuerpo: las de y 455, 410 y 380. Las altas, de y 305 o más arriba, quedan por
> encima de él.
> - *Efecto:* la repisa estalla en pedazos que salen disparados hacia donde corre,
>   con polvo, sonido de derrumbe, sacudida de cámara y un letrero "¡CRASH!".
> - *Reconstrucción:* cada repisa destrozada se vuelve a armar a los 7 s
>   (`SMASH_REBUILD`), apareciendo poco a poco, para que la arena no se quede sin
>   repisas. Si Motocle o el jefe están justo donde va, espera un poco más.
> - *Dónde está:* `ZombieBoss._smash_platforms()` → `Platform25D.smash(dir, rebuild_time)`
>   (y `PlatformDebris.push()` para el empujón de los pedazos).

El jefe de nivel ya no es "La Impresora Alfa": ahora es el **Profesor Zombie**
(`ZombieBoss.tscn` + `ZombieBoss.gd`), el titular del laboratorio convertido por
GLITCH.exe.

### Diseño y animaciones (nuevo diseño)

El Profesor Zombie usa el nuevo diseño que compartiste: lentes rotos, cerebro expuesto,
camisa de la UTT ensangrentada, portafolio y aura verde. Los cuadros están en
`assets/sprites/zombie_boss_v2/`; se les quitó el magenta, están escalados a la misma
altura (172 px) y alineados por los pies.

- `intro` + `roar` (**presentación**):
  - *Cuándo:* al acercarse Motocle (`wake_distance`, 360 px).
  - *`intro`:* cuadros 1–5 de tu secuencia (`intro_01..05.png`). Entra caminando
    unos pasos, se acomoda los lentes rotos y abre la boca.
  - *`roar`:* cuadro 6 (`intro_06.png`), con los brazos arriba y el aura verde. Ruge
    con furia y dolor durante 1.9 s (`INTRO_ROAR_TIME`) con el sonido
    `assets/audio/zombie_boss_roar.wav`: un gruñido grave y áspero que crece y se
    quiebra en un grito.
  - *Efectos:* sacudida fuerte de cámara, ondas de aire que salen de su boca y
    texto "¡¡GRRRAAAAAHHH!!".
  - *Invulnerable* durante toda la presentación; al terminar empieza la pelea.
- `idle`: postura de frente (`idle.png`).
- `walk`: tu secuencia de caminado de perfil (`walk_01..06.png`), en bucle a 7 fps.
  Se usa cada vez que camina para reacomodarse entre ataques; en las fases 2 y 3
  la animación va más rápida, igual que su paso. Al llegar a su punto vuelve a `idle`.
- `charge_start`: cuadro 1 de la embestida, agachado tomando impulso. Se usa durante
  el aviso de la embestida y al agacharse para el salto aplastante.
- `charge_run`: cuadros 2–6 en bucle a 12 fps (más rápido en fases altas), mientras
  cruza la pantalla corriendo. En el aire, durante el salto aplastante, se congela en
  la zancada estirada.
- `charge_stop`: cuadro 7, cuando frena y se endereza, y mientras está aturdido tras
  estrellarse.
- Lanzar cerebros: como todavía no hay animación de lanzamiento con el nuevo diseño,
  el cuerpo se echa para atrás y se avienta hacia adelante (`_throw_motion`). El
  cerebro sale a la altura de la mano. Si luego compartes una animación de lanzar,
  se sustituye ahí.

La hitbox creció a 76×140 para el nuevo tamaño. La carpeta vieja
`assets/sprites/zombie_boss/` ya no se usa.

### Pelea dinámica por fases

El jefe ya no se queda patrullando en un punto: se mueve por toda la arena, entre
`arena_left` (3080) y `arena_right` (3860). Alterna ataques que se esquivan de formas
distintas y nunca repite el mismo dos veces seguidas. Tiene 132 de vida. Tocarlo
quita 1 corazón; no es derrota instantánea como con los zombies comunes.

- **Despertar:** cuando Motocle se acerca (`wake_distance`, 360 px), hace su
  presentación con el rugido (ver arriba) y empieza la pelea.
- **Fase 1** (vida > 66 %):
  - Entre ataques camina rápido a otro punto de la arena, a media distancia de
    Motocle.
  - Lanza un cerebro apuntado a Motocle.
  - **Embestida:**
    - *Aviso:* tiembla, parpadea en rojo y aparece un "!".
    - *Ataque:* cruza la pantalla corriendo y levantando polvo. Se esquiva
      saltando por encima.
    - *Choque:* si llega a la orilla de la arena, se estrella y queda aturdido
      (★ ★) un momento. Es el mejor momento para dispararle.
- **Fase 2** (vida ≤ 66 %): ruge y se vuelve 25 % más rápido. Además:
  - **Abanico de 3 cerebros.**
  - **Salto aplastante:**
    - *Impulso:* se agacha para tomar impulso y brinca en arco hasta donde está
      Motocle.
    - *Caída:* cae con una sacudida fuerte y manda dos ondas de choque por el
      piso, una a cada lado (`ShockWave.gd`).
    - *Esquivar:* las ondas solo golpean si Motocle está en el piso; se esquivan
      saltando o parado en una repisa.
- **Fase 3** (vida ≤ 33 %): "¡¡FURIA!!", tinte rojizo y 50 % más rápido. Además:
  - **Lluvia de cerebros:** avienta cerebros al aire y caen desde arriba de la
    pantalla sobre Motocle y a su alrededor.
  - Antes de cada caída, una marca roja parpadeante en el piso
    (`GroundWarning.gd`) avisa dónde va a caer.
- **Derrota:** grita, cae de espaldas, se hunde un poco y se desvanece. Al morir
  aparece el fragmento como antes.

**Persecución si te alejas.**

- *Cuándo:* ya iniciada la pelea, si Motocle se aleja tanto que el jefe queda
  fuera de la pantalla (por ejemplo, regresándose por el nivel).
- *Qué hace:* el jefe lo persigue con embestidas seguidas, una tras otra y sin el
  aviso largo. Usa los cuadros de carrera, va 30 % más rápido
  (`PURSUIT_SPEED_MULT`) y atraviesa a los zombies de la horda.
- *Cuándo para:* en cuanto vuelve a estar bien dentro de la pantalla; ahí sigue
  la pelea normal.
- *Arena móvil:* la arena se mueve con la pelea (`_fit_arena`). Siempre abarca al
  jefe y a Motocle, con el mismo ancho mínimo y dentro de los límites del nivel.
  Así puede reacomodarse, embestir y aplastar donde sea que Motocle lo lleve.

La revisión ocurre entre ataques y al reacomodarse. Si está a media embestida o
aturdido, termina eso primero (1–2 s como máximo).

La vida, la velocidad, los límites de la arena y la distancia para despertarlo se
cambian en el inspector del nodo `Boss` de `Level1_Sistemas.tscn`.

### Lanzamiento de cerebros

- Antes de lanzar, se voltea para encarar la posición actual de Motocle y
  reproduce la animación `throw` de 6 cuadros que subiste; justo a la mitad de
  esa animación — el "cuadro de liberación" — instancia un `Bullet.tscn` con la
  textura del cerebro (`assets/sprites/brain_projectile.png`) en vez de la bala
  genérica.
- **El ataque apunta directo a donde está Motocle en ese instante**, no solo a
  izquierda/derecha: calcula el vector desde el jefe hasta la posición del
  jugador y lanza el cerebro en línea recta por ese vector, así que si Motocle
  está arriba en una plataforma, el cerebro sube en diagonal para alcanzarlo.
  Esto usa una tercera propiedad nueva en `Bullet.gd`, `velocity_vec`: si se
  asigna un vector distinto de cero, el proyectil viaja por ese vector en vez
  del movimiento horizontal por defecto (`direction` + velocidad fija) que usan
  las balas normales de `Enemy.gd`/`Player.gd`.
- Las otras dos propiedades nuevas en `Bullet.gd` siguen aplicando:
  `custom_texture` (para poder mostrar cualquier arte, no solo las balas por
  defecto) y `spin` (lo hace girar sobre sí mismo mientras vuela, como un objeto
  arrojado en vez de un disparo).
- El resto (vida, barra de vida, nombre, `take_damage`, señal `defeated`) es
  igual al patrón de `Boss.gd`, así que se integra con `Level.gd` sin cambios.

Los cuadros de `idle` y `throw` del jefe, y el ícono del cerebro, salieron de las
imágenes que compartiste con el mismo proceso de recorte/limpieza que las
animaciones de Motocle y los zombies de la horda.

## Efecto de sangre al disparar

Cuando una bala amiga (de Motocle) golpea a un enemigo, ahora aparece una salpicadura
de sangre en el punto de impacto. Esto es nuevo en `Bullet.gd`: en `_on_body_entered`,
si la bala es `friendly` y el cuerpo golpeado está en el grupo `"enemy"`, se instancia
`BloodEffect.tscn` en esa posición (además del daño normal). `BloodEffect.tscn` es un
`CPUParticles2D` con textura propia (`assets/effects/blood_particle.png`, una gotita
roja generada con degradado de transparencia) que dispara una ráfaga de partículas una
sola vez (`one_shot = true`), con gravedad para que caigan como gotas y un
`color_ramp` que las hace desvanecerse; `BloodEffect.gd` se autodestruye (`queue_free`)
apenas termina la animación, así no se acumulan nodos de sobra.

El efecto solo ocurre cuando Motocle le pega a un enemigo — las balas enemigas que
golpean a Motocle no lo activan — y aplica a cualquier enemigo del juego (zombies,
enemigos normales y jefes), no solo a los del nivel 1, porque vive en el script
compartido `Bullet.gd`.

## Sonido de disparo

Cada vez que Motocle dispara suena tu efecto de revólver
(`assets/audio/shoot.wav`, convertido del MP3 que compartiste a WAV sin
compresión — mejor para un efecto corto como este, sin retraso de
decodificación). Está en un nodo `AudioStreamPlayer2D` llamado `ShootSound`
dentro de `Player.tscn`; `Player.gd` lo reproduce (`shoot_sound.play()`) en
`_shoot()`, justo cuando se instancia la bala, así que el sonido y el disparo
salen sincronizados. Si quieres cambiar el sonido, solo reemplaza el archivo
`assets/audio/shoot.wav` (o cambia el `stream` del nodo `ShootSound` en el
editor) — no hay que tocar el script.

## Skins de Motocle por nivel (bata de hospital en el nivel 2)

Cada nivel puede vestir a Motocle distinto con `player_skin`, en el nodo raíz del
nivel; el nivel 2 usa `"hospital"`. `Player.gd` (`set_skin`) busca los cuadros en
`assets/sprites/skins/<skin>/` con nombres `<animación>_01.png`, `_02.png`…:

| Animación | Archivos | Estado (hospital) |
|---|---|---|
| run | `run_01..06.png` | ✅ tu secuencia (10 fps) |
| idle | `idle_01..10.png` | ✅ tu secuencia de respiración (6 cuadros en ida y vuelta 1→6→2 para un bucle suave, 6 fps) |
| jump | `jump_01..03.png` | ✅ tu secuencia: impulso agachado → sube con la escopeta en alto → apunta en el aire (12 fps, se queda en el último mientras sube) |
| fall | `fall_01..02.png` | ✅ tu secuencia: bajando, escopeta abajo / apuntando (bucle a 7 fps) |
| land | `land_01.png` | ✅ aterrizaje con polvo: se ve 0.14 s al tocar el piso si está quieto (`LAND_TIME`) |
| crouch | `crouch_XX.png` | ⏳ provisional: cuadro 1 de run aplastado |
| crouch_walk | `crouch_walk_XX.png` | ⏳ provisional: run completo (aplastado) |
| death | `death_01..06.png` | ✅ tu secuencia de derrota |

**Derrota con la skin (nivel 2).** Cuando Motocle pierde su último corazón con una
skin que trae `death_XX.png`, se reproduce tu secuencia (0.3 s por cuadro,
`SKIN_DEATH_FRAME_TIME`) en vez de la caída genérica:

1. Recibe el golpe.
2. Se dobla.
3. Cae de rodillas tocándose el pecho.
4. Estira la mano al cielo.
5. Su brazo se desvanece.
6. Al final, un "alma" azul pálida y translúcida sube y se desvanece.

Detalles:

- La animación corre con el reloj real y se ve completa y a color, porque la
  pantalla de ELIMINADO pone el juego en cámara lenta. `GameManager` espera a
  que termine (`get_death_anim_time()`) y luego muestra ELIMINADO como siempre.
  Los niveles sin esta animación no cambian.
- De tu hoja se descartaron el espíritu borroso del centro y las chispitas.
- El brazo translúcido del último cuadro se "desmezcló" del magenta, para que
  quede semitransparente de verdad sobre el fondo del nivel.

- **Cuando lleguen las demás secuencias:** basta con dejar los PNG con esos
  nombres en la carpeta de la skin. Se usan solos, sin tocar código, y el cuadro
  aplastado provisional de agachado se desactiva.
- **Lienzos:** todos usan los pies a 6 px del borde inferior de un lienzo de
  166 px de alto, igual que la animación original.
- **Disparo:** la punta del arma se detecta sola en cada cuadro, así que los
  perdigones salen del cañón de la escopeta.

## Escopeta (nivel 2)

En la Enfermería Motocle usa una **escopeta** en vez del rifle. Cada nivel elige su
arma con `player_weapon` (en el nodo raíz del nivel: `"rifle"` o `"shotgun"`), y
`Level.gd` se la pone a Motocle al empezar.

- **Disparo en cono:** cada disparo suelta 7 perdigones (`SHOTGUN_PELLETS`) desde la
  punta del arma, abiertos en un cono de ~24° (`SHOTGUN_SPREAD`).
  - *Alcance corto:* cada perdigón vuela ~288 px (`SHOTGUN_RANGE`).
  - *Daño:* 6 de daño cada uno (`SHOTGUN_DAMAGE`). A quemarropa entran casi todos
    (~30–42 de daño), y de lejos, pocos o ninguno.
  - *Varios enemigos:* como cada perdigón es independiente, el cono le pega a
    varios enemigos a la vez.
- **Quemarropa:** si Motocle dispara mientras una mini ardilla está pegada a él
  (a menos de 72 px, adelante o atrás), esa ardilla muere al instante y sale
  volando lejos, girando (`Player._point_blank_launch()` →
  `MiniSquirrel.launch(dir)`). Cuenta para los puntos y para la barra especial.
- **Cadencia y patada:** dispara más lento que el rifle (0.75 s,
  `SHOTGUN_COOLDOWN`). Tiene un fogonazo más grande con dos bocanadas de humo, un
  retroceso visual y una sacudida de cámara más fuertes, y empuja a Motocle hacia
  atrás (más si dispara en el aire, `SHOTGUN_KICK`).
- **Sonido:** `assets/audio/shotgun.wav` es un estallido grave con eco, seguido del
  "chk-chk" de la corredera.
- El dibujo de Motocle sigue siendo el del rifle. Si compartes sprites con
  escopeta, se cambian sin tocar la lógica.

## Bala desde la punta del rifle y fogonazo

- **Salida de la bala:** la bala ya no sale de un punto fijo (`Muzzle`), sino de
  la **punta del cañón del cuadro que se está viendo** (de pie, corriendo,
  saltando, cayendo o agachado). `Player.gd` (`_gun_tip_pixel` / `_gun_tip_local`)
  busca en cada textura la columna opaca más a la derecha del dibujo (el cañón)
  y la altura promedio de esos píxeles. El resultado se guarda en caché por
  textura, así que cada cuadro se calcula una sola vez. Si se cambian o agregan
  animaciones de Motocle, la punta se encuentra sola, siempre que el cañón sea lo
  que está más adelante en el dibujo.
- **Mini explosión:** `scripts/MuzzleFlash.gd` dibuja en la boca del arma un
  fogonazo:
  - un núcleo blanco-amarillo, rayos de fuego naranjas en abanico y brillo
    aditivo;
  - dura 0.1 s y va pegado a Motocle;
  - además suelta una bocanada de humo gris que sube y se desvanece en 0.45 s,
    y se queda en el aire aunque Motocle se mueva.
  
  El tamaño se ajusta en `_shoot()` (`flash.scale`, 1.3 por defecto) y la
  duración en las constantes `FLASH_LIFE` / `SMOKE_LIFE`.

## Ataque especial: barra de carga + bola de energía (tecla K)

**Retroceso.** Al soltar la bola de energía, Motocle sale empujado hacia atrás
(`SPECIAL_RECOIL`, 260 px/s, ≈35 px en total) y su dibujo da un pequeño tirón,
como la patada de un disparo potente. Durante ese instante no responde al stick.

**La barra.** Debajo de los corazones hay una barra de 3 segmentos
(`scripts/SpecialBar.gd`).

- **Cómo se llena:** cada enemigo derrotado (zombies, mini ardillas, enemigos
  comunes) llena un segmento con un destello (`GameManager.register_kill()`).
- **Golpes a jefes:** cada disparo de Motocle que le quita vida a un jefe también
  llena un segmento (`GameManager.register_boss_hit()`).
  - Con 3 golpes al jefe la barra queda lista.
  - Con la escopeta, los perdigones de un mismo disparo cuentan como un solo golpe
    (máximo uno cada 0.25 s, `BOSS_HIT_COOLDOWN`).
  - Los golpes durante la presentación o la teletransportación no cuentan, porque
    no le quitan vida.
  - El propio hadouken no recarga la barra al pegarle al jefe.
- **Llena:** después de 3 enemigos (`SPECIAL_KILLS`) brilla y parpadea
  "¡LISTO! [K]".
- **Reinicio:** empieza vacía en cada nivel y en cada reintento.

**El disparo.** Con la barra llena, la tecla **K** (o el botón **Y** del control)
lanza una bola de energía tipo hadouken (`scripts/EnergyBlast.gd`) y vacía la barra.

- **Salida:** sale de la punta del arma con un destello azul.
- **Letrero "¡HADOUKEN!"** (`scripts/HadoukenText.gd`): aparece al soltar la bola,
  estilo juego de peleas.
  - *Entrada:* una franja de energía azul cruza la pantalla y el texto cae de
    golpe, grande e inclinado, y rebota a su tamaño.
  - *Estilo:* amarillo con contorno rojo oscuro, sombra azul y brillo que palpita;
    tiembla un instante al aterrizar.
  - *Salida:* sale disparado hacia adelante mientras se desvanece (≈1.2 s).
- **Sonido estilo Dragon Ball Z** (`assets/audio/hadouken.wav`, 2.3 s):
  - *Carga:* un zumbido de ki que sube de tono, con trémolo y chispas eléctricas
    que crepitan, y va creciendo de volumen.
  - *Disparo:* justo cuando sale la bola, un golpe subgrave, un chasquido, el
    rugido del rayo (zumbido grave distorsionado con vibrato y flanger) y un
    soplido "zhhhh" que barre de agudo a grave con cola larga.
  - *Explosión azul al chocar* (`scripts/KiExplosion.gd`, ≈0.9 s): un destello
    blanco que se vuelve azul, 14 rayos de energía en estrella, dos ondas
    expansivas, chispas celestes que salen volando y caen, y un resplandor azul
    que se apaga poco a poco. Si la bola no encuentra enemigo, solo se desvanece
    con un destello pequeño.
  - *Impacto* (`assets/audio/ki_explosion.wav`): un estruendo de explosión
    (boom grave, retumbo, chispas y un timbre metálico) y una sacudida de cámara
    más fuerte.
- **Persecución:**
  - Busca al **enemigo más cercano** dentro de 1100 px; los que están enfrente de
    Motocle tienen prioridad.
  - Lo persigue girando suavemente; si el objetivo muere antes, busca otro.
  - Sin enemigos cerca, vuela derecho unos 2.6 s y se desvanece.
- **Impacto:**
  - Hace **80 de daño**, suficiente para cualquier enemigo común y un buen golpe
    a los jefes.
  - Explota con una onda que hace **35 de daño** a los enemigos a menos de 110 px.
  - Sacude la cámara.
- **Animación de lanzamiento** (soldado: nivel 1 y niveles 3 a 5):
  - *Cuadros:* `assets/sprites/cast/cast_01..06.png`, a 15 fps.
  - *Secuencia:* Motocle toma impulso, gira la energía con un remolino, empuja
    con ambas manos y regresa a su guardia.
  - *Disparo:* la bola sale de sus manos en el cuadro 4 (`CAST_RELEASE_FRAME`).
    El sonido arranca con la animación para que el estallido coincida.
  - *Mientras dura (≈0.4 s):* no dispara ni cambia de animación.
  - *Nivel 2 (bata de hospital):* usa su propia secuencia
    (`assets/sprites/skins/hospital/cast_01..06.png`). Junta la energía en la
    cadera durante 3 cuadros, empieza a empujar y estira ambas manos al frente.
    La bola sale en el cuadro 5 (`SKIN_CAST_RELEASE`). El sonido se retrasa un
    poco para que su estallido coincida con ese cuadro.
- **Recarga:** los enemigos que mate la bola también cuentan para volver a llenar
  la barra.

## Escudo UTT (nivel 2 en adelante, tecla I)

Desde la Enfermería, Motocle tiene un **escudo de energía verde con las letras UTT**.
Cada nivel lo habilita con `player_shield = true` en su nodo raíz (niveles 2 a 5;
el nivel 1 no lo tiene). La lógica está en `Player.gd` (`_update_shield`,
`shield_blocks`, `_on_shield_block`) y el dibujo en `scripts/ShieldFx.gd`.

- **Cómo se usa:** se mantiene presionada la **I** (o L1 / LB en el control).
  - Mientras está arriba, Motocle se planta: no camina, no salta y no dispara,
    pero sí puede voltearse.
  - Al soltar la tecla, baja el escudo.
- **Animación (nivel 2):** usa tu secuencia
  (`assets/sprites/skins/hospital/shield_01..05.png`, 18 fps):
  1. Guarda la escopeta en la espalda.
  2. Junta una esfera de energía en la mano.
  3. Forma el escudo y se queda en el último cuadro.

  Al soltar, la secuencia corre al revés. El primer cuadro de tu hoja (apuntando,
  con polvo) no se usa porque es casi igual al de "quieto".
- **Niveles 3 a 5 (soldado):** como no hay cuadros del soldado con escudo, el escudo
  se dibuja con código. Es un blasón verde translúcido con "UTT", contorno brillante
  y chispas, del mismo tamaño y en el mismo lugar que el de tu dibujo.
- **Qué bloquea (solo lo que choca con el escudo):**
  - *Proyectiles enemigos* (balas, jeringas, cerebros): se deshacen si tocan el
    rectángulo del escudo, que está adelante de Motocle (un `Area2D` los intercepta).
  - *Golpes cuerpo a cuerpo* (mordidas de ardillas y perros, embestidas del jefe,
    zombies, ondas de choque por el piso): se bloquean si vienen de enfrente.
  - Lo que llega **por la espalda** o **desde arriba** (por ejemplo la lluvia de
    cerebros) sí hace daño.
  - Con la tecla recién presionada no bloquea al instante: el escudo protege en
    cuanto se forma (cuadro 4 de la animación, ≈0.17 s; con el soldado, 0.12 s).
- **Al bloquear:**
  - Destello verde y un "¡clang!" metálico con chispa eléctrica
    (`assets/audio/shield_block.wav`).
  - Motocle retrocede un poco y el enemigo que estaba pegado sale empujado.
  - Al levantar el escudo suena un zumbido de energía (`shield_up.wav`).
- **Barra de desgaste:** debajo de la barra del especial hay una barra verde,
  `ESCUDO [I]` (`scripts/ShieldBar.gd`), que solo aparece en los niveles con escudo.
  - *Cómo se gasta:* baja 7.2/s mientras el escudo está arriba, 11.2 por cada
    proyectil bloqueado y 17.6 por cada golpe cuerpo a cuerpo bloqueado. Con el
    escudo arriba sin recibir golpes dura ≈14 s; aguanta 25 % más que la primera
    versión (9 / 14 / 22).
  - *Recarga:* se recarga sola, despacio: empieza 1.5 s después de soltar la I y sube
    8/s, así que tarda ≈12 s de vacía a llena.
  - *Colores:* verde → amarillo → rojo, con una estela blanca que muestra lo que se
    acaba de perder.
- **Se ve más roto entre menos energía** (`ShieldFx._draw_damage`):
  - *Grietas:* aparecen poco a poco, crecen y se hacen más gruesas conforme baja
    la energía; siempre son las mismas, para que se vea que el daño avanza.
  - *Pedazos faltantes:* aparecen de la mitad de la energía para abajo.
  - *Brillo:* el escudo pierde brillo, y casi vacío parpadea.
  - Funciona igual sobre tu dibujo del nivel 2 y sobre el escudo dibujado del soldado.
- **Si llega a cero, se rompe:**
  - El escudo estalla en esquirlas verdes con un sonido de cristal roto
    (`assets/audio/shield_break.wav`) y baja solo.
  - La barra se pone roja y dice `ROTO`. Mientras tanto no se puede usar, aunque se
    presione la I, hasta recargar a 40 (≈6 s). Una rayita en la barra marca ese
    punto.
  - Todos los valores están en `Player.gd`: `SHIELD_DRAIN`, `SHIELD_HIT_COST`,
    `SHIELD_MELEE_COST`, `SHIELD_REGEN`, `SHIELD_REGEN_DELAY` y `SHIELD_REARM`.
- **Para extender:** quien dispare o golpee a Motocle debe pasar su posición:
  `player.take_damage(daño, global_position)`. Así el escudo sabe si el golpe
  viene de enfrente.

## Historieta entre niveles (nivel 1 → nivel 2)

En cuanto cae el Profesor Zombie, el nivel 1 ya no muestra el fragmento ni la
puerta:

1. Tras 1 s (`comic_delay`, para ver el golpe final), Motocle queda invencible y
   el juego se pausa.
2. Entra con un destello a pantalla completa la historieta del nivel 2
   (`assets/comics/comic_nivel2.jpg`). Abajo a la derecha parpadea
   "HAZ CLIC PARA CONTINUAR".
3. Con un clic, una tecla o un botón del control (aceptados después de 0.8 s),
   la pantalla funde a negro y arranca el **nivel 2 directamente**, sin pantalla
   de carga (`GameManager.go_to_next_level(true)`).

Cualquier nivel puede usarlo: basta asignar una imagen a `comic_after_boss` en el
nodo raíz del nivel. Si se deja vacío, el nivel sigue con el fragmento y la puerta
como antes. La lógica está en `scripts/ComicScreen.gd`.

**Vida del Profesor Zombie:** bajó al 60 % para que sea más fácil derrotarlo
(220 → 132). Las fases siguen cambiando al 66 % y 33 % de su vida.

## Pantalla de inicio (parallax de 3 capas)

`Main.tscn` + `Main.gd` arman la portada con tus 3 imágenes nuevas, en
`assets/backgrounds/title/`. A las capas 1 y 2 se les quitó el fondo
(blanco y gris) con orillas suaves; los ojos de Motocle se respetaron.

| Capa | Imagen | Contenido | Parallax |
|---|---|---|---|
| 3 – Fondo | `background.png` | Campus en ruinas, Avelina en la jaula de código, GLITCH.exe en el cielo | lento, 15 % (`BG_FACTOR`) |
| 2 – Medio | `bosses.png` | Galería de jefes y horda de ardillas zombi | medio, 55 % (`MID_FACTOR`) |
| 1 – Frente | `hero.png` | Motocle disparando | rápido, 120 % (`FG_FACTOR`) |

- **Movimiento:** las capas se desplazan según el ratón o el stick izquierdo del
  control, como si la cámara se moviera, hasta `SWAY` px. Además se mecen solas
  suavemente para que la pantalla nunca se vea estática. El fondo es un poco más
  grande que la pantalla para que nunca se vean sus orillas. Motocle da un
  pequeño culatazo cada 1–2 s.
- **Título:** "MOTOCLE / OPERACIÓN CAMPUS" con contorno y sombra morada, arriba a
  la izquierda.
- **Botón "PRESIONA CUALQUIER TECLA PARA INICIAR":** parpadea abajo al centro.
  - *Qué inicia el juego:* cualquier tecla, clic o botón del control. También se
    puede hacer clic en el botón.
  - *Al iniciar:* suena la escopeta, la pantalla destella y pasa a negro, y
    arranca la partida.
  - *Retraso:* la entrada se ignora los primeros 0.5 s (`INPUT_DELAY`) para que
    no se salte la pantalla por accidente.
- **Controles:** abajo hay una línea pequeña con los controles.
- La portada vieja `assets/backgrounds/main_menu.png` ya no se usa.

## Vida en corazones

El HUD ya no usa una barra de progreso: la vida de Motocle son **3 corazones**
(`assets/ui/heart_full.png` / `heart_empty.png`, tu ícono pixel-art). Cada golpe
que recibe —bala enemiga o contacto directo con un enemigo o jefe— le cuesta
**1 corazón completo**, sin importar el `contact_damage` o el `damage` de la bala
que lo haya tocado; ese número ya no afecta a Motocle, solo sigue usándose para
la vida de los enemigos que él dispara. Al perder un golpe, el corazón
correspondiente (de derecha a izquierda) cambia de rojo a **negro**
(`heart_empty.png`) en vez de vaciarse gradualmente.

Esto vive en `GameManager.gd` (`MAX_HEARTS := 3`, `damage_player()` ahora resta
1 corazón por golpe en vez del monto recibido) y en el nuevo `HUD.gd`, que
tiene un `HBoxContainer` con 3 `TextureRect` (`Heart1/2/3` dentro de
`HUD.tscn`) y les cambia la textura a lleno/negro según cuántos corazones
queden. Si quieres más o menos corazones, cambia `MAX_HEARTS` en
`GameManager.gd` y agrega/quita nodos `TextureRect` dentro de `HeartsBox` en
`HUD.tscn` (mismo patrón que los tres que ya están).

## Daño de contacto con enemigos (corrección importante)

Había un bug real: tocar a un enemigo normal (`Enemy.gd`) o a un jefe no le quitaba
vida a Motocle, aunque el código de `Player.gd` que revisa las colisiones y llama a
`GameManager.damage_player()` siempre estuvo bien escrito. La causa era que
`Player.tscn` tenía `collision_mask = 1` (solo la capa WORLD/mundo) — le faltaba la
capa ENEMY (4). En Godot, para que un `CharacterBody2D` **detecte** con quién chocó al
moverse (`get_slide_collision()`), su propia `collision_mask` tiene que incluir la capa
del otro cuerpo, no basta con que las capas "se toquen" en general. Como al Player le
faltaba esa capa, físicamente nunca "veía" a los enemigos al chocar, así que ese bloque
de código nunca se ejecutaba.

**Corregido**: `collision_mask` de Motocle ahora es `5` (WORLD + ENEMY). Con esto:
- Tocar un enemigo normal o un jefe le quita `contact_damage` de vida a Motocle
  (10 por defecto, cada uno puede tener su propio valor).
- Tocar un zombie (que tiene `instant_kill = true`) lo sigue zombificando al instante,
  como ya funcionaba.

Verificado con una prueba dedicada (no solo "no truena"): puse a Motocle junto a un
`Enemy.tscn` sin disparar y confirmé que `GameManager.current_health` bajaba de 100 a
90 con el paso de los frames, exactamente el `contact_damage` esperado.

## Música de fondo

Se agregó tu pista de Metal Slug X (`assets/audio/music_gameplay.ogg`, convertida del
MP3 que compartiste a formato OGG Vorbis — mejor que WAV para música larga en bucle,
mucho más liviano) a través de un nuevo autoload: `MusicManager.gd`
(`scripts/MusicManager.gd`, registrado en `project.godot`). Al ser un autoload
(singleton global, igual que `GameManager`), la música arranca una sola vez al abrir
el juego y **no se corta ni reinicia** al cambiar de nivel o cuando Motocle
muere/se zombifica y la escena se recarga — si viviera dentro de cada nivel, se
cortaría feo cada vez.

La pista está en bucle (`loop = true` en el `AudioStreamOggVorbis`) y a un volumen bajo
(`-12 dB`) para no tapar el efecto de disparo. Para cambiar la música, reemplaza
`assets/audio/music_gameplay.ogg` por otro archivo OGG (o edita `MusicManager.gd` si
quieres usar otro formato o ajustar el volumen).

### Música por nivel (nivel 2: hospital tenebroso)

Cada nivel puede tener su propia pista con la propiedad `music` de su nodo raíz
(`Level.gd`). Si se deja vacía, suena la pista general.
- **Cambio de pista:** `MusicManager.play_track()` hace un fundido cruzado de 1.6 s.
- **Reiniciar el mismo nivel** (al morir) no corta ni reinicia la música.
- **Pantalla de inicio:** vuelve a la pista general.

**Enfermería:** `assets/audio/music_hospital.ogg` es un loop de ≈95 s a 66 BPM, en re
menor, generado con código (`gen_hospital_music.py`). Tiene estas capas:
- **Monitor cardiaco:** pitido a cada latido, con arritmias (pitidos que faltan o se
  duplican). A la mitad hace un **flatline**: tono continuo con un chillido agudo
  de cuerdas, y luego vuelve el pulso.
- **Latido grave:** "tum-tum" que marca el ritmo.
- **Respirador mecánico:** inhala y exhala cada compás, con el chasquido de la válvula.
- **Caja musical desafinada:** melodía en re menor con notas "equivocadas" que se va
  atrasando, como si se le acabara la cuerda.
- **Ambiente:** dron grave disonante, cuerdas disonantes que suben y bajan, golpes
  metálicos lejanos y goteo.
- **Eco:** todo pasa por una reverberación larga de pasillo vacío. La cola del eco
  da la vuelta al final, así que el loop no tiene corte.

## Cómo funciona cada nivel (para explicar en clase)

Cada nivel usa el mismo script `Level.gd`, solo cambian los valores exportados
(`level_title`, `dialogue_text`, `is_final_level`) y qué enemigos/jefe se colocan.
Esto es justo el patrón que le puedes enseñar a tus alumnos: **una sola pieza de
lógica reutilizada con datos distintos**, en vez de copiar y pegar código por nivel.

Secuencia de cada nivel:
1. El jugador avanza esquivando/matando enemigos regulares (`Enemy.gd`).
2. Al llegar al jefe (`Boss.gd`) y bajarle toda la vida, se emite la señal `defeated`.
3. `Level.gd` activa el `Fragment` (el holograma de Avelina).
4. Al tocarlo, se dispara un diálogo (`GameManager.show_dialogue`) con la pista hacia el siguiente edificio.
5. Al cerrar el diálogo se activa la `ExitDoor`; tocarla avanza al siguiente nivel (o gana el juego en "El H").

## Arte

Motocle usa tu imagen de referencia (le quité el fondo y la recorté). Avelina, los
enemigos y los jefes son **arte placeholder** que dibujé con formas simples para que
el juego sea jugable de inmediato — no son arte final. Para reemplazarlos:

1. Crea tu sprite (PNG con fondo transparente).
2. Ponlo en `assets/sprites/` con el mismo nombre de archivo que quieres reemplazar (por ejemplo `avelina.png`).
3. Ábrelo en Godot y confirma que se vea bien en el editor — no hace falta tocar ningún script ni escena.

## Ideas para extender (buen material para tus alumnos)

- Agregar más animaciones (por ejemplo, un cuadro específico de disparo).
- Agregar sonido de salto, o música distinta por nivel (ahora mismo la misma pista
  suena en todo el juego vía `MusicManager.gd`).
- Agregar power-ups (vida extra, munición especial) como otra escena reutilizable tipo `Fragment.tscn`.
- Hacer que los enemigos "voladores" (libros, drones) ignoren la gravedad — es un buen ejercicio de herencia/composición en `Enemy.gd`.
- Guardar el progreso (nivel actual) con `FileAccess` para persistencia entre sesiones.

## Documento de narrativa

El documento `motocle_narrativa.md` (entregado por separado en la conversación) tiene
la historia completa, los personajes y la descripción de cada nivel — útil si quieres
mostrarlo en clase antes de jugar, o dárselo a tus alumnos como referencia de diseño.
