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
Catálogo Central. Espera quieto hasta que Motocle llega a `intro_distance` (380 px);
entonces lo **recibe carcajeándose** ("¡JA, JA, JA!", animación de risa de 3 cuadros y
`assets/audio/doctor_laugh.wav`). Durante la bienvenida es invulnerable. Después pelea:
patrulla y lanza ráfagas de 3 jeringas apuntadas a Motocle, y cada vez que Motocle
pierde un corazón se vuelve a burlar riéndose.

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

## Jefe del nivel 1: Profesor Zombie

El jefe de nivel ya no es "La Impresora Alfa": ahora es el **Profesor Zombie**
(`ZombieBoss.tscn` + `ZombieBoss.gd`), el titular del laboratorio convertido por
GLITCH.exe. A diferencia de `Boss.gd` (que dispara ráfagas de balas), este jefe:

- Patrulla de un lado a otro frente al jugador (igual que los jefes normales).
- Cada `throw_interval` segundos (2.2s en el nivel 1), antes de lanzar, se voltea
  para encarar la posición actual de Motocle y reproduce la animación `throw` de
  6 cuadros que subiste; justo a la mitad de esa animación — el "cuadro de
  liberación" — invoca `_throw_brain()`, que instancia un `Bullet.tscn` con la
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

## Menú principal

`Main.tscn` ahora usa tu arte de portada (`assets/backgrounds/main_menu.png`,
"MOTOCLE SALVA A SU GÓTICA Y LA UTT" con Avelina, GLITCH.exe y Motocle) como
fondo de pantalla completa en vez del fondo de nivel + texto genérico que
tenía antes. Como el título ya viene dibujado en la imagen, quité las
etiquetas de texto "MOTOCLE" / "Operación Campus"; lo único que queda encima
es un panel semitransparente en la parte de abajo con los controles y el
botón "Iniciar Misión", para que se lean bien sin importar qué tan cargada
esté esa zona de la imagen. Si cambias la imagen de portada, solo reemplaza
`assets/backgrounds/main_menu.png` — no hace falta tocar `Main.gd`.

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
