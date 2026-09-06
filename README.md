# MOTOCLE: Operación Campus

Plataformas 2D hecho en **Godot 4** (probado con Godot 4.3) para tu clase en la UTT.
Motocle recorre 5 edificios del campus para rescatar a Avelina de las garras de **GLITCH.exe**.

## Cómo abrirlo

1. Instala Godot 4.x (recomendado 4.3 o superior) desde godotengine.org — es gratis.
2. Abre Godot, elige "Importar", selecciona la carpeta de este proyecto y el archivo `project.godot`.
3. Dale play (▶) o F5. La escena inicial es `scenes/Main.tscn`.

Este proyecto ya se probó en modo headless con Godot 4.3 (carga de todas las escenas sin errores), pero vale la pena que lo juegues tú mismo antes de mostrarlo en clase.

## Controles

- Mover: flechas ← → o A / D
- Saltar: W, ↑ o Espacio
- Disparar: J o clic izquierdo

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
  HUD.gd, Main.gd, WinScreen.gd, DialogueBox.gd -> interfaz
scenes/
  Main.tscn              -> menú principal
  Player.tscn, Enemy.tscn, Boss.tscn, Bullet.tscn, Fragment.tscn, ExitDoor.tscn, Platform.tscn, HUD.tscn, DialogueBox.tscn -> piezas reutilizables
  ZombieShambler.tscn, ZombieRunner.tscn, ZombieRotten.tscn -> los 3 tipos de zombie de la horda del nivel 1
  Level1_Sistemas.tscn, Level2_Biblioteca.tscn, Level3_Cafeteria.tscn, Level4_Auditorio.tscn, Level5_ElH.tscn -> los 5 niveles
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

Para agregar más zombies a la horda, o cambiar sus posiciones, solo duplica cualquiera
de los nodos `ZombieX` dentro de `Level1_Sistemas.tscn` y ajusta su `position`.

El fondo del nivel (`assets/backgrounds/bg_zombies.png`) es la versión larga del
escenario que compartiste ("Puebla Tecamachalco — Zona de Contención Zombie", con el
letrero de "LEVEL START"), a resolución nativa 1584x672; el nodo `Background` la
reescala a `Vector2(1.9571, 1.1845)` y la desplaza a `position = (-50, -110)` para
cubrir el ancho del nivel (3000px) más un margen de sobra en los cuatro lados, así la
cámara nunca muestra espacio vacío al saltar o moverse.

Antes de llegar al edificio (y al jefe) hay un tramo de obstáculos: 9 plataformas
elevadas (`PlatformA` a `PlatformI`) a distintas alturas que obligan a saltar con más
cuidado mientras la horda persigue a Motocle, mucho más largo que el tramo original.

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
