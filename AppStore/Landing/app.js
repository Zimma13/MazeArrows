(() => {
  "use strict";

  const STORAGE_LOCALE = "arrowmaze.site.locale";
  const STORAGE_THEME = "arrowmaze.site.theme";
  const supportedLocales = [
    "en", "en-IN", "de", "es", "es-MX", "fr", "hi", "id", "ja", "ko", "pt-BR", "pt-PT", "ru", "th", "zh-Hant"
  ];

  const translations = {
    en: {
      "meta.title": "Arrow Maze - Find the path that frees them all",
      "meta.description": "A strategic arrow puzzle with 240 levels, daily challenges, Zen mode, Photo Maze and Game Center.",
      "skip": "Skip to content",
      "nav.aria": "Primary navigation",
      "nav.play": "Play",
      "nav.features": "Features",
      "nav.photo": "Photo Maze",
      "controls.language": "Language",
      "controls.theme": "Theme",
      "theme.auto": "System",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "Every arrow has a way out",
      "hero.title": "Find the move that frees them all.",
      "hero.body": "Read the board, choose the right arrow and turn a crowded maze into one satisfying clear.",
      "hero.play": "Try the puzzle",
      "hero.explore": "Explore the game",
      "hero.previewAlt": "Arrow Maze gameplay preview",
      "hero.combo": "Chain clear",
      "facts.aria": "Game highlights",
      "facts.levels": "crafted levels",
      "facts.worlds": "evolving worlds",
      "facts.dailyValue": "Daily",
      "facts.daily": "a fresh maze",
      "facts.photoValue": "Photo",
      "facts.photo": "becomes a maze",
      "play.title": "One free arrow can open the whole board.",
      "play.body": "Tap an arrow only when nothing blocks its path. Find the sequence and keep the combo alive.",
      "play.statusReady": "Find the free arrow.",
      "play.statusClear": "Clear path. Keep going.",
      "play.statusBlocked": "That path is blocked.",
      "play.statusDone": "Board cleared. Beautiful.",
      "play.reset": "Reset puzzle",
      "play.aria": "Interactive Arrow Maze puzzle",
      "play.boardAria": "Puzzle board",
      "play.arrow": "Arrow",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "Your photo becomes the puzzle.",
      "photo.body": "Choose a subject and Arrow Maze builds a playable silhouette from its colours and detail. The image is processed on your device.",
      "photo.hint": "Drag across the image to compare.",
      "photo.compareAria": "Compare photo and maze",
      "features.title": "A puzzle for every pace.",
      "features.body": "Progress, return each day or slow everything down. The rules stay simple while the decisions grow deeper.",
      "features.worldsTitle": "Journey through seven worlds",
      "features.worldsBody": "Master 240 levels that introduce new board shapes, tighter routes and smarter sequences.",
      "features.dailyTitle": "A reason to return every day",
      "features.dailyBody": "Solve the Daily Maze, protect your streak and finish three changing quests for rewards.",
      "features.moreTitle": "Play your way",
      "features.moreBody": "Build combos, use layered hints, relax in Zen and compare achievements through Game Center.",
      "features.combo": "Combos",
      "features.hints": "Hints",
      "features.quests": "Quests",
      "themeStory.title": "Your board, your atmosphere.",
      "themeStory.body": "Aurora keeps the puzzle warm and clear. Midnight Neon turns every path into electric colour. Change the theme above and the whole page follows.",
      "cta.title": "Your next clear is waiting.",
      "cta.body": "Play Arrow Maze on iPhone and iPad.",
      "cta.button": "Download on the App Store",
      "footer.by": "by KinApps",
      "footer.aria": "Legal and support",
      "footer.privacy": "Privacy Policy",
      "footer.terms": "Terms of Use",
      "footer.support": "Support",
      "footer.kinapps": "KinApps",
      "footer.rights": "All rights reserved.",
      "images.gameplay": "Arrow Maze level with glowing arrow paths",
      "images.photoSource": "Colourful parrot photo",
      "images.photoResult": "Parrot transformed into an Arrow Maze",
      "images.worlds": "Arrow Maze world journey screen",
      "images.daily": "Arrow Maze daily challenge screen",
      "images.icon": "Arrow Maze app icon"
    },
    "en-IN": {
      "meta.title": "Arrow Maze - Find the path that frees them all",
      "meta.description": "A strategic arrow puzzle with 240 levels, daily challenges, Zen mode, Photo Maze and Game Center.",
      "skip": "Skip to content",
      "nav.aria": "Primary navigation",
      "nav.play": "Play",
      "nav.features": "Features",
      "nav.photo": "Photo Maze",
      "controls.language": "Language",
      "controls.theme": "Theme",
      "theme.auto": "System",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "Every arrow has a way out",
      "hero.title": "Find the move that frees them all.",
      "hero.body": "Read the board, choose the right arrow and turn a crowded maze into one satisfying clear.",
      "hero.play": "Try the puzzle",
      "hero.explore": "Explore the game",
      "hero.previewAlt": "Arrow Maze gameplay preview",
      "hero.combo": "Chain clear",
      "facts.aria": "Game highlights",
      "facts.levels": "crafted levels",
      "facts.worlds": "evolving worlds",
      "facts.dailyValue": "Daily",
      "facts.daily": "a fresh maze",
      "facts.photoValue": "Photo",
      "facts.photo": "becomes a maze",
      "play.title": "One free arrow can open the whole board.",
      "play.body": "Tap an arrow only when nothing blocks its path. Find the sequence and keep the combo alive.",
      "play.statusReady": "Find the free arrow.",
      "play.statusClear": "Clear path. Keep going.",
      "play.statusBlocked": "That path is blocked.",
      "play.statusDone": "Board cleared. Beautiful.",
      "play.reset": "Reset puzzle",
      "play.aria": "Interactive Arrow Maze puzzle",
      "play.boardAria": "Puzzle board",
      "play.arrow": "Arrow",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "Your photo becomes the puzzle.",
      "photo.body": "Choose a subject and Arrow Maze builds a playable silhouette from its colours and detail. The image is processed on your device.",
      "photo.hint": "Drag across the image to compare.",
      "photo.compareAria": "Compare photo and maze",
      "features.title": "A puzzle for every pace.",
      "features.body": "Progress, return each day or slow everything down. The rules stay simple while the decisions grow deeper.",
      "features.worldsTitle": "Journey through seven worlds",
      "features.worldsBody": "Master 240 levels that introduce new board shapes, tighter routes and smarter sequences.",
      "features.dailyTitle": "A reason to return every day",
      "features.dailyBody": "Solve the Daily Maze, protect your streak and finish three changing quests for rewards.",
      "features.moreTitle": "Play your way",
      "features.moreBody": "Build combos, use layered hints, relax in Zen and compare achievements through Game Center.",
      "features.combo": "Combos",
      "features.hints": "Hints",
      "features.quests": "Quests",
      "themeStory.title": "Your board, your atmosphere.",
      "themeStory.body": "Aurora keeps the puzzle warm and clear. Midnight Neon turns every path into electric colour. Change the theme above and the whole page follows.",
      "cta.title": "Your next clear is waiting.",
      "cta.body": "Play Arrow Maze on iPhone and iPad.",
      "cta.button": "Download on the App Store",
      "footer.by": "by KinApps",
      "footer.aria": "Legal and support",
      "footer.privacy": "Privacy Policy",
      "footer.terms": "Terms of Use",
      "footer.support": "Support",
      "footer.kinapps": "KinApps",
      "footer.rights": "All rights reserved.",
      "images.gameplay": "Arrow Maze level with glowing arrow paths",
      "images.photoSource": "Colourful parrot photo",
      "images.photoResult": "Parrot transformed into an Arrow Maze",
      "images.worlds": "Arrow Maze world journey screen",
      "images.daily": "Arrow Maze daily challenge screen",
      "images.icon": "Arrow Maze app icon"
    },
    de: {
      "meta.title": "Arrow Maze - Finde den Weg, der sie alle befreit",
      "meta.description": "Ein strategisches Pfeilrätsel mit 240 Leveln, täglichen Herausforderungen, Zen-Modus, Photo Maze und Game Center.",
      "skip": "Zum Inhalt springen",
      "nav.aria": "Hauptnavigation",
      "nav.play": "Spielen",
      "nav.features": "Funktionen",
      "nav.photo": "Photo Maze",
      "controls.language": "Sprache",
      "controls.theme": "Design",
      "theme.auto": "System",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "Jeder Pfeil hat einen Ausweg",
      "hero.title": "Finde den Zug, der sie alle befreit.",
      "hero.body": "Lies das Spielfeld, wähle den richtigen Pfeil und verwandle ein dichtes Labyrinth in einen befriedigenden Abschluss.",
      "hero.play": "Rätsel ausprobieren",
      "hero.explore": "Spiel entdecken",
      "hero.previewAlt": "Vorschau des Spielablaufs von Arrow Maze",
      "hero.combo": "Kettenkombo",
      "facts.aria": "Spielhighlights",
      "facts.levels": "gestaltete Level",
      "facts.worlds": "Welten im Wandel",
      "facts.dailyValue": "Täglich",
      "facts.daily": "ein neues Labyrinth",
      "facts.photoValue": "Foto",
      "facts.photo": "wird zum Labyrinth",
      "play.title": "Ein freier Pfeil kann das ganze Spielfeld öffnen.",
      "play.body": "Tippe nur auf einen Pfeil, wenn nichts seinen Weg blockiert. Finde die richtige Reihenfolge und halte die Kombo am Leben.",
      "play.statusReady": "Finde den freien Pfeil.",
      "play.statusClear": "Weg frei. Weiter so.",
      "play.statusBlocked": "Dieser Weg ist blockiert.",
      "play.statusDone": "Spielfeld geräumt. Perfekt.",
      "play.reset": "Rätsel zurücksetzen",
      "play.aria": "Interaktives Arrow Maze Rätsel",
      "play.boardAria": "Rätselspielfeld",
      "play.arrow": "Pfeil",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "Dein Foto wird zum Rätsel.",
      "photo.body": "Wähle ein Motiv und Arrow Maze erstellt aus seinen Farben und Details eine spielbare Silhouette. Das Bild wird auf deinem Gerät verarbeitet.",
      "photo.hint": "Ziehe über das Bild, um zu vergleichen.",
      "photo.compareAria": "Foto und Labyrinth vergleichen",
      "features.title": "Ein Rätsel für jedes Tempo.",
      "features.body": "Komme voran, kehre täglich zurück oder lass es ruhig angehen. Die Regeln bleiben einfach, während die Entscheidungen anspruchsvoller werden.",
      "features.worldsTitle": "Reise durch sieben Welten",
      "features.worldsBody": "Meistere 240 Level mit neuen Spielfeldformen, engeren Routen und raffinierteren Reihenfolgen.",
      "features.dailyTitle": "Ein Grund, jeden Tag zurückzukehren",
      "features.dailyBody": "Löse das tägliche Labyrinth, schütze deine Serie und erfülle drei wechselnde Aufgaben für Belohnungen.",
      "features.moreTitle": "Spiele auf deine Art",
      "features.moreBody": "Bilde Kombos, nutze mehrstufige Hinweise, entspanne im Zen-Modus und vergleiche Erfolge über Game Center.",
      "features.combo": "Kombos",
      "features.hints": "Hinweise",
      "features.quests": "Aufgaben",
      "themeStory.title": "Dein Spielfeld, deine Atmosphäre.",
      "themeStory.body": "Aurora hält das Rätsel warm und klar. Neon taucht jeden Weg in elektrische Farben. Ändere oben das Design und die ganze Seite passt sich an.",
      "cta.title": "Dein nächster Erfolg wartet.",
      "cta.body": "Spiele Arrow Maze auf iPhone und iPad.",
      "cta.button": "Im App Store laden",
      "footer.by": "von KinApps",
      "footer.aria": "Rechtliches und Support",
      "footer.privacy": "Datenschutzrichtlinie",
      "footer.terms": "Nutzungsbedingungen",
      "footer.support": "Support",
      "footer.kinapps": "KinApps",
      "footer.rights": "Alle Rechte vorbehalten.",
      "images.gameplay": "Arrow Maze Level mit leuchtenden Pfeilwegen",
      "images.photoSource": "Foto eines farbenfrohen Papageis",
      "images.photoResult": "Papagei, der in ein Arrow Maze verwandelt wurde",
      "images.worlds": "Weltreise-Bildschirm von Arrow Maze",
      "images.daily": "Bildschirm der täglichen Arrow Maze Herausforderung",
      "images.icon": "App-Symbol von Arrow Maze"
    },
    es: {
      "meta.title": "Arrow Maze - Encuentra el camino que las libera a todas",
      "meta.description": "Un rompecabezas estratégico de flechas con 240 niveles, desafíos diarios, modo Zen, Photo Maze y Game Center.",
      "skip": "Saltar al contenido",
      "nav.aria": "Navegación principal",
      "nav.play": "Jugar",
      "nav.features": "Características",
      "nav.photo": "Photo Maze",
      "controls.language": "Idioma",
      "controls.theme": "Tema",
      "theme.auto": "Sistema",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "Cada flecha tiene una salida",
      "hero.title": "Encuentra el movimiento que las libera a todas.",
      "hero.body": "Observa el tablero, elige la flecha correcta y convierte un laberinto repleto en una resolución realmente satisfactoria.",
      "hero.play": "Probar el rompecabezas",
      "hero.explore": "Explorar el juego",
      "hero.previewAlt": "Vista previa de una partida de Arrow Maze",
      "hero.combo": "Cadena de aciertos",
      "facts.aria": "Aspectos destacados del juego",
      "facts.levels": "niveles diseñados",
      "facts.worlds": "mundos en evolución",
      "facts.dailyValue": "Diario",
      "facts.daily": "un laberinto nuevo",
      "facts.photoValue": "Foto",
      "facts.photo": "se convierte en laberinto",
      "play.title": "Una flecha libre puede abrir todo el tablero.",
      "play.body": "Toca una flecha solo cuando nada bloquee su camino. Encuentra la secuencia y mantén vivo el combo.",
      "play.statusReady": "Encuentra la flecha libre.",
      "play.statusClear": "Camino libre. Sigue así.",
      "play.statusBlocked": "Ese camino está bloqueado.",
      "play.statusDone": "Tablero despejado. Perfecto.",
      "play.reset": "Reiniciar rompecabezas",
      "play.aria": "Rompecabezas interactivo de Arrow Maze",
      "play.boardAria": "Tablero del rompecabezas",
      "play.arrow": "Flecha",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "Tu foto se convierte en el rompecabezas.",
      "photo.body": "Elige un motivo y Arrow Maze creará una silueta jugable a partir de sus colores y detalles. La imagen se procesa en tu dispositivo.",
      "photo.hint": "Desliza sobre la imagen para comparar.",
      "photo.compareAria": "Comparar la foto y el laberinto",
      "features.title": "Un rompecabezas para cada ritmo.",
      "features.body": "Avanza, vuelve cada día o tómatelo con calma. Las reglas siguen siendo sencillas mientras las decisiones ganan profundidad.",
      "features.worldsTitle": "Viaja por siete mundos",
      "features.worldsBody": "Domina 240 niveles que presentan nuevas formas de tablero, rutas más estrechas y secuencias más inteligentes.",
      "features.dailyTitle": "Un motivo para volver cada día",
      "features.dailyBody": "Resuelve el laberinto diario, protege tu racha y completa tres misiones cambiantes para conseguir recompensas.",
      "features.moreTitle": "Juega a tu manera",
      "features.moreBody": "Crea combos, usa pistas por niveles, relájate en el modo Zen y compara logros mediante Game Center.",
      "features.combo": "Combos",
      "features.hints": "Pistas",
      "features.quests": "Misiones",
      "themeStory.title": "Tu tablero, tu ambiente.",
      "themeStory.body": "Aurora mantiene el rompecabezas cálido y claro. Neon llena cada camino de color eléctrico. Cambia el tema arriba y toda la página se adaptará.",
      "cta.title": "Tu próxima resolución te espera.",
      "cta.body": "Juega a Arrow Maze en iPhone y iPad.",
      "cta.button": "Descárgalo en el App Store",
      "footer.by": "de KinApps",
      "footer.aria": "Información legal y soporte",
      "footer.privacy": "Política de privacidad",
      "footer.terms": "Condiciones de uso",
      "footer.support": "Soporte",
      "footer.kinapps": "KinApps",
      "footer.rights": "Todos los derechos reservados.",
      "images.gameplay": "Nivel de Arrow Maze con caminos de flechas luminosos",
      "images.photoSource": "Foto de un loro colorido",
      "images.photoResult": "Loro transformado en un Arrow Maze",
      "images.worlds": "Pantalla del viaje por los mundos de Arrow Maze",
      "images.daily": "Pantalla del desafío diario de Arrow Maze",
      "images.icon": "Icono de la app Arrow Maze"
    },
    "es-MX": {
      "meta.title": "Arrow Maze - Encuentra el camino que las libera a todas",
      "meta.description": "Un rompecabezas estratégico de flechas con 240 niveles, desafíos diarios, modo Zen, Photo Maze y Game Center.",
      "skip": "Saltar al contenido",
      "nav.aria": "Navegación principal",
      "nav.play": "Jugar",
      "nav.features": "Funciones",
      "nav.photo": "Photo Maze",
      "controls.language": "Idioma",
      "controls.theme": "Tema",
      "theme.auto": "Sistema",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "Cada flecha tiene una salida",
      "hero.title": "Encuentra el movimiento que las libera a todas.",
      "hero.body": "Observa el tablero, elige la flecha correcta y convierte un laberinto lleno en una solución muy satisfactoria.",
      "hero.play": "Probar el rompecabezas",
      "hero.explore": "Explorar el juego",
      "hero.previewAlt": "Vista previa de una partida de Arrow Maze",
      "hero.combo": "Cadena de aciertos",
      "facts.aria": "Lo mejor del juego",
      "facts.levels": "niveles diseñados",
      "facts.worlds": "mundos en evolución",
      "facts.dailyValue": "Diario",
      "facts.daily": "un laberinto nuevo",
      "facts.photoValue": "Foto",
      "facts.photo": "se convierte en laberinto",
      "play.title": "Una flecha libre puede abrir todo el tablero.",
      "play.body": "Toca una flecha solo cuando nada bloquee su camino. Encuentra la secuencia y mantén vivo el combo.",
      "play.statusReady": "Encuentra la flecha libre.",
      "play.statusClear": "Camino libre. Sigue así.",
      "play.statusBlocked": "Ese camino está bloqueado.",
      "play.statusDone": "Tablero despejado. Perfecto.",
      "play.reset": "Reiniciar rompecabezas",
      "play.aria": "Rompecabezas interactivo de Arrow Maze",
      "play.boardAria": "Tablero del rompecabezas",
      "play.arrow": "Flecha",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "Tu foto se convierte en el rompecabezas.",
      "photo.body": "Elige un objeto y Arrow Maze creará una silueta jugable a partir de sus colores y detalles. La imagen se procesa en tu dispositivo.",
      "photo.hint": "Desliza sobre la imagen para comparar.",
      "photo.compareAria": "Comparar la foto y el laberinto",
      "features.title": "Un rompecabezas para cada ritmo.",
      "features.body": "Avanza, vuelve cada día o tómate las cosas con calma. Las reglas siguen siendo sencillas mientras las decisiones ganan profundidad.",
      "features.worldsTitle": "Recorre siete mundos",
      "features.worldsBody": "Domina 240 niveles que presentan nuevas formas de tablero, rutas más estrechas y secuencias más inteligentes.",
      "features.dailyTitle": "Una razón para volver cada día",
      "features.dailyBody": "Resuelve el laberinto diario, protege tu racha y completa tres misiones cambiantes para obtener recompensas.",
      "features.moreTitle": "Juega a tu manera",
      "features.moreBody": "Arma combos, usa pistas por niveles, relájate en el modo Zen y compara logros con Game Center.",
      "features.combo": "Combos",
      "features.hints": "Pistas",
      "features.quests": "Misiones",
      "themeStory.title": "Tu tablero, tu ambiente.",
      "themeStory.body": "Aurora mantiene el rompecabezas cálido y claro. Neon llena cada camino de color eléctrico. Cambia el tema arriba y toda la página se adaptará.",
      "cta.title": "Tu próxima solución te espera.",
      "cta.body": "Juega Arrow Maze en iPhone y iPad.",
      "cta.button": "Descárgalo en App Store",
      "footer.by": "de KinApps",
      "footer.aria": "Información legal y soporte",
      "footer.privacy": "Política de privacidad",
      "footer.terms": "Términos de uso",
      "footer.support": "Soporte",
      "footer.kinapps": "KinApps",
      "footer.rights": "Todos los derechos reservados.",
      "images.gameplay": "Nivel de Arrow Maze con caminos de flechas brillantes",
      "images.photoSource": "Foto de un loro colorido",
      "images.photoResult": "Loro transformado en un Arrow Maze",
      "images.worlds": "Pantalla del recorrido por los mundos de Arrow Maze",
      "images.daily": "Pantalla del desafío diario de Arrow Maze",
      "images.icon": "Ícono de la app Arrow Maze"
    },
    fr: {
      "meta.title": "Arrow Maze - Trouvez le chemin qui les libère toutes",
      "meta.description": "Un jeu de réflexion stratégique avec des flèches, 240 niveaux, des défis quotidiens, le mode Zen, Photo Maze et Game Center.",
      "skip": "Aller au contenu",
      "nav.aria": "Navigation principale",
      "nav.play": "Jouer",
      "nav.features": "Fonctionnalités",
      "nav.photo": "Photo Maze",
      "controls.language": "Langue",
      "controls.theme": "Thème",
      "theme.auto": "Système",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "Chaque flèche a une sortie",
      "hero.title": "Trouvez le coup qui les libère toutes.",
      "hero.body": "Observez la grille, choisissez la bonne flèche et transformez un labyrinthe emmêlé en résolution parfaitement satisfaisante.",
      "hero.play": "Essayer le puzzle",
      "hero.explore": "Découvrir le jeu",
      "hero.previewAlt": "Aperçu d'une partie d'Arrow Maze",
      "hero.combo": "Enchaînement",
      "facts.aria": "Points forts du jeu",
      "facts.levels": "niveaux conçus avec soin",
      "facts.worlds": "mondes en évolution",
      "facts.dailyValue": "Quotidien",
      "facts.daily": "un nouveau labyrinthe",
      "facts.photoValue": "Photo",
      "facts.photo": "devient un labyrinthe",
      "play.title": "Une seule flèche libre peut ouvrir toute la grille.",
      "play.body": "Touchez une flèche uniquement si rien ne bloque son chemin. Trouvez la séquence et entretenez le combo.",
      "play.statusReady": "Trouvez la flèche libre.",
      "play.statusClear": "Chemin dégagé. Continuez.",
      "play.statusBlocked": "Ce chemin est bloqué.",
      "play.statusDone": "Grille vidée. Parfait.",
      "play.reset": "Réinitialiser le puzzle",
      "play.aria": "Puzzle Arrow Maze interactif",
      "play.boardAria": "Grille du puzzle",
      "play.arrow": "Flèche",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "Votre photo devient le puzzle.",
      "photo.body": "Choisissez un sujet et Arrow Maze crée une silhouette jouable à partir de ses couleurs et de ses détails. L'image est traitée sur votre appareil.",
      "photo.hint": "Faites glisser sur l'image pour comparer.",
      "photo.compareAria": "Comparer la photo et le labyrinthe",
      "features.title": "Un puzzle pour tous les rythmes.",
      "features.body": "Progressez, revenez chaque jour ou ralentissez. Les règles restent simples tandis que les décisions gagnent en profondeur.",
      "features.worldsTitle": "Parcourez sept mondes",
      "features.worldsBody": "Maîtrisez 240 niveaux qui introduisent de nouvelles formes de grille, des chemins plus étroits et des séquences plus subtiles.",
      "features.dailyTitle": "Une raison de revenir chaque jour",
      "features.dailyBody": "Résolvez le labyrinthe du jour, protégez votre série et terminez trois quêtes changeantes pour obtenir des récompenses.",
      "features.moreTitle": "Jouez à votre façon",
      "features.moreBody": "Créez des combos, utilisez des indices progressifs, détendez-vous en mode Zen et comparez vos succès avec Game Center.",
      "features.combo": "Combos",
      "features.hints": "Indices",
      "features.quests": "Quêtes",
      "themeStory.title": "Votre grille, votre ambiance.",
      "themeStory.body": "Aurora garde le puzzle chaleureux et clair. Neon transforme chaque chemin en couleur électrique. Changez le thème ci-dessus et toute la page s'adapte.",
      "cta.title": "Votre prochaine résolution vous attend.",
      "cta.body": "Jouez à Arrow Maze sur iPhone et iPad.",
      "cta.button": "Télécharger sur l’App Store",
      "footer.by": "par KinApps",
      "footer.aria": "Mentions légales et assistance",
      "footer.privacy": "Politique de confidentialité",
      "footer.terms": "Conditions d'utilisation",
      "footer.support": "Assistance",
      "footer.kinapps": "KinApps",
      "footer.rights": "Tous droits réservés.",
      "images.gameplay": "Niveau d'Arrow Maze avec des trajectoires de flèches lumineuses",
      "images.photoSource": "Photo d'un perroquet coloré",
      "images.photoResult": "Perroquet transformé en Arrow Maze",
      "images.worlds": "Écran du voyage à travers les mondes d'Arrow Maze",
      "images.daily": "Écran du défi quotidien d'Arrow Maze",
      "images.icon": "Icône de l'app Arrow Maze"
    },
    hi: {
      "meta.title": "Arrow Maze - वह रास्ता खोजें जो सभी को मुक्त करे",
      "meta.description": "240 स्तरों, दैनिक चुनौतियों, Zen मोड, Photo Maze और Game Center वाला रणनीतिक तीर पहेली खेल।",
      "skip": "मुख्य सामग्री पर जाएँ",
      "nav.aria": "मुख्य नेविगेशन",
      "nav.play": "खेलें",
      "nav.features": "विशेषताएँ",
      "nav.photo": "Photo Maze",
      "controls.language": "भाषा",
      "controls.theme": "थीम",
      "theme.auto": "सिस्टम",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "हर तीर के लिए बाहर निकलने का एक रास्ता है",
      "hero.title": "वह चाल खोजें जो सभी को मुक्त करे।",
      "hero.body": "बोर्ड को समझें, सही तीर चुनें और भरी हुई भूलभुलैया को संतोषजनक तरीके से साफ़ करें।",
      "hero.play": "पहेली आज़माएँ",
      "hero.explore": "गेम देखें",
      "hero.previewAlt": "Arrow Maze गेमप्ले का पूर्वावलोकन",
      "hero.combo": "लगातार सफ़ाई",
      "facts.aria": "गेम की खास बातें",
      "facts.levels": "सोच समझकर बनाए गए स्तर",
      "facts.worlds": "बदलती हुई दुनियाएँ",
      "facts.dailyValue": "दैनिक",
      "facts.daily": "एक नई भूलभुलैया",
      "facts.photoValue": "फ़ोटो",
      "facts.photo": "भूलभुलैया बनती है",
      "play.title": "एक खुला तीर पूरे बोर्ड को खोल सकता है।",
      "play.body": "तीर को तभी टैप करें जब उसके रास्ते में कुछ न हो। सही क्रम खोजें और कॉम्बो जारी रखें।",
      "play.statusReady": "खुला तीर खोजें।",
      "play.statusClear": "रास्ता साफ़ है। आगे बढ़ते रहें।",
      "play.statusBlocked": "वह रास्ता बंद है।",
      "play.statusDone": "बोर्ड साफ़ हो गया। शानदार।",
      "play.reset": "पहेली रीसेट करें",
      "play.aria": "इंटरैक्टिव Arrow Maze पहेली",
      "play.boardAria": "पहेली बोर्ड",
      "play.arrow": "तीर",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "आपकी फ़ोटो पहेली बन जाती है।",
      "photo.body": "कोई विषय चुनें और Arrow Maze उसके रंगों व बारीकियों से खेलने योग्य सिल्हूट बनाता है। इमेज आपके डिवाइस पर प्रोसेस होती है।",
      "photo.hint": "तुलना करने के लिए इमेज पर खींचें।",
      "photo.compareAria": "फ़ोटो और भूलभुलैया की तुलना करें",
      "features.title": "हर रफ़्तार के लिए एक पहेली।",
      "features.body": "आगे बढ़ें, हर दिन लौटें या आराम से खेलें। नियम सरल रहते हैं, लेकिन फैसले गहरे होते जाते हैं।",
      "features.worldsTitle": "सात दुनियाओं की यात्रा करें",
      "features.worldsBody": "नए बोर्ड आकार, तंग रास्ते और बेहतर क्रम पेश करने वाले 240 स्तरों में महारत हासिल करें।",
      "features.dailyTitle": "हर दिन लौटने की एक वजह",
      "features.dailyBody": "दैनिक भूलभुलैया हल करें, अपनी स्ट्रीक बचाएँ और इनाम के लिए बदलते तीन क्वेस्ट पूरे करें।",
      "features.moreTitle": "अपने तरीके से खेलें",
      "features.moreBody": "कॉम्बो बनाएँ, कई स्तर वाले संकेत उपयोग करें, Zen में आराम करें और Game Center पर उपलब्धियों की तुलना करें।",
      "features.combo": "कॉम्बो",
      "features.hints": "संकेत",
      "features.quests": "क्वेस्ट",
      "themeStory.title": "आपका बोर्ड, आपका माहौल।",
      "themeStory.body": "Aurora पहेली को गर्मजोशी भरा और साफ़ रखता है। Midnight Neon हर रास्ते को इलेक्ट्रिक रंग देता है। ऊपर थीम बदलें और पूरा पेज उसके साथ बदल जाएगा।",
      "cta.title": "आपकी अगली जीत इंतज़ार कर रही है।",
      "cta.body": "iPhone और iPad पर Arrow Maze खेलें।",
      "cta.button": "App Store से डाउनलोड करें",
      "footer.by": "KinApps द्वारा",
      "footer.aria": "कानूनी जानकारी और सहायता",
      "footer.privacy": "गोपनीयता नीति",
      "footer.terms": "उपयोग की शर्तें",
      "footer.support": "सहायता",
      "footer.kinapps": "KinApps",
      "footer.rights": "सर्वाधिकार सुरक्षित।",
      "images.gameplay": "चमकते तीर रास्तों वाला Arrow Maze स्तर",
      "images.photoSource": "रंगीन तोते की फ़ोटो",
      "images.photoResult": "Arrow Maze में बदला गया तोता",
      "images.worlds": "Arrow Maze की दुनिया की यात्रा वाली स्क्रीन",
      "images.daily": "Arrow Maze की दैनिक चुनौती वाली स्क्रीन",
      "images.icon": "Arrow Maze ऐप आइकन"
    },
    id: {
      "meta.title": "Arrow Maze - Temukan langkah yang membebaskan semuanya",
      "meta.description": "Teka-teki panah strategis dengan 240 level, tantangan harian, mode Zen, Photo Maze, dan Game Center.",
      "skip": "Lewati ke konten",
      "nav.aria": "Navigasi utama",
      "nav.play": "Main",
      "nav.features": "Fitur",
      "nav.photo": "Photo Maze",
      "controls.language": "Bahasa",
      "controls.theme": "Tema",
      "theme.auto": "Sistem",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "Setiap panah punya jalan keluar",
      "hero.title": "Temukan langkah yang membebaskan semuanya.",
      "hero.body": "Baca papan, pilih panah yang tepat, dan ubah labirin yang penuh menjadi papan yang tuntas dengan memuaskan.",
      "hero.play": "Coba teka-tekinya",
      "hero.explore": "Jelajahi game",
      "hero.previewAlt": "Pratinjau permainan Arrow Maze",
      "hero.combo": "Bersihkan beruntun",
      "facts.aria": "Sorotan game",
      "facts.levels": "level yang dirancang khusus",
      "facts.worlds": "dunia yang terus berkembang",
      "facts.dailyValue": "Harian",
      "facts.daily": "labirin baru",
      "facts.photoValue": "Foto",
      "facts.photo": "menjadi labirin",
      "play.title": "Satu panah bebas bisa membuka seluruh papan.",
      "play.body": "Ketuk panah hanya saat tidak ada yang menghalangi jalurnya. Temukan urutannya dan pertahankan kombo.",
      "play.statusReady": "Temukan panah yang bebas.",
      "play.statusClear": "Jalur terbuka. Lanjutkan.",
      "play.statusBlocked": "Jalur itu terhalang.",
      "play.statusDone": "Papan bersih. Indah.",
      "play.reset": "Atur ulang teka-teki",
      "play.aria": "Teka-teki interaktif Arrow Maze",
      "play.boardAria": "Papan teka-teki",
      "play.arrow": "Panah",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "Foto Anda menjadi teka-teki.",
      "photo.body": "Pilih subjek, lalu Arrow Maze membuat siluet yang dapat dimainkan dari warna dan detailnya. Gambar diproses di perangkat Anda.",
      "photo.hint": "Geser melintasi gambar untuk membandingkan.",
      "photo.compareAria": "Bandingkan foto dan labirin",
      "features.title": "Teka-teki untuk setiap tempo.",
      "features.body": "Terus maju, kembali setiap hari, atau bermain lebih santai. Aturannya tetap sederhana sementara keputusan makin mendalam.",
      "features.worldsTitle": "Jelajahi tujuh dunia",
      "features.worldsBody": "Kuasai 240 level yang memperkenalkan bentuk papan baru, rute lebih sempit, dan urutan lebih cerdas.",
      "features.dailyTitle": "Alasan untuk kembali setiap hari",
      "features.dailyBody": "Pecahkan Labirin Harian, pertahankan rentetan, dan selesaikan tiga misi yang berubah untuk mendapat hadiah.",
      "features.moreTitle": "Bermain dengan cara Anda",
      "features.moreBody": "Rangkai kombo, gunakan petunjuk berlapis, bersantai di Zen, dan bandingkan pencapaian melalui Game Center.",
      "features.combo": "Kombo",
      "features.hints": "Petunjuk",
      "features.quests": "Misi",
      "themeStory.title": "Papan Anda, suasana Anda.",
      "themeStory.body": "Aurora menjaga teka-teki tetap hangat dan jelas. Midnight Neon mengubah setiap jalur menjadi warna elektrik. Ubah tema di atas dan seluruh halaman ikut berubah.",
      "cta.title": "Penyelesaian berikutnya menanti Anda.",
      "cta.body": "Mainkan Arrow Maze di iPhone dan iPad.",
      "cta.button": "Unduh di App Store",
      "footer.by": "oleh KinApps",
      "footer.aria": "Informasi hukum dan dukungan",
      "footer.privacy": "Kebijakan Privasi",
      "footer.terms": "Ketentuan Penggunaan",
      "footer.support": "Dukungan",
      "footer.kinapps": "KinApps",
      "footer.rights": "Hak cipta dilindungi.",
      "images.gameplay": "Level Arrow Maze dengan jalur panah bercahaya",
      "images.photoSource": "Foto burung nuri berwarna-warni",
      "images.photoResult": "Burung nuri yang diubah menjadi Arrow Maze",
      "images.worlds": "Layar perjalanan dunia Arrow Maze",
      "images.daily": "Layar tantangan harian Arrow Maze",
      "images.icon": "Ikon aplikasi Arrow Maze"
    },
    ja: {
      "meta.title": "Arrow Maze: すべてを解放する道を見つけよう",
      "meta.description": "240ステージ、デイリーチャレンジ、Zenモード、Photo Maze、Game Centerを備えた戦略的な矢印パズル。",
      "skip": "コンテンツへ移動",
      "nav.aria": "メインナビゲーション",
      "nav.play": "プレイ",
      "nav.features": "ゲームの特徴",
      "nav.photo": "Photo Maze",
      "controls.language": "言語",
      "controls.theme": "テーマ",
      "theme.auto": "システム",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "すべての矢印には出口がある",
      "hero.title": "すべてを解放する一手を見つけよう。",
      "hero.body": "盤面を読み、正しい矢印を選び、混み合った迷路を気持ちよくすべて消しましょう。",
      "hero.play": "パズルを試す",
      "hero.explore": "ゲームを詳しく見る",
      "hero.previewAlt": "Arrow Mazeのゲームプレイプレビュー",
      "hero.combo": "連続クリア",
      "facts.aria": "ゲームのハイライト",
      "facts.levels": "こだわって作られたステージ",
      "facts.worlds": "変化していくワールド",
      "facts.dailyValue": "デイリー",
      "facts.daily": "新しい迷路",
      "facts.photoValue": "写真",
      "facts.photo": "迷路になる",
      "play.title": "ひとつの自由な矢印が盤面全体を開く。",
      "play.body": "進路に何もない矢印だけをタップ。正しい順番を見つけ、コンボをつなげよう。",
      "play.statusReady": "動かせる矢印を見つけよう。",
      "play.statusClear": "進路は空いています。その調子。",
      "play.statusBlocked": "その進路はふさがれています。",
      "play.statusDone": "盤面クリア。お見事。",
      "play.reset": "パズルをリセット",
      "play.aria": "インタラクティブなArrow Mazeパズル",
      "play.boardAria": "パズル盤面",
      "play.arrow": "矢印",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "写真がパズルになる。",
      "photo.body": "被写体を選ぶと、Arrow Mazeがその色とディテールから遊べるシルエットを作ります。画像はデバイス上で処理されます。",
      "photo.hint": "画像上をドラッグして比較。",
      "photo.compareAria": "写真と迷路を比較",
      "features.title": "どんなペースでも楽しめるパズル。",
      "features.body": "先へ進む、毎日遊ぶ、ゆっくり考える。ルールはシンプルなまま、判断はより奥深くなります。",
      "features.worldsTitle": "7つのワールドを旅しよう",
      "features.worldsBody": "新しい盤面形状、より狭いルート、より巧妙な順番が登場する240ステージを攻略。",
      "features.dailyTitle": "毎日戻りたくなる理由",
      "features.dailyBody": "デイリー迷路を解き、連続記録を守り、内容が変わる3つのクエストを完了して報酬を獲得。",
      "features.moreTitle": "自分らしくプレイ",
      "features.moreBody": "コンボを重ね、段階的なヒントを使い、Zenでくつろぎ、Game Centerで実績を比較。",
      "features.combo": "コンボ",
      "features.hints": "ヒント",
      "features.quests": "クエスト",
      "themeStory.title": "自分の盤面、自分の空気感。",
      "themeStory.body": "Auroraはパズルを温かく見やすく保ちます。Midnight Neonはすべての道を鮮やかな電光色に変えます。上でテーマを変えると、ページ全体も切り替わります。",
      "cta.title": "次のクリアが待っています。",
      "cta.body": "iPhoneとiPadでArrow Mazeをプレイ。",
      "cta.button": "App Storeからダウンロード",
      "footer.by": "KinAppsによる",
      "footer.aria": "法的情報とサポート",
      "footer.privacy": "プライバシーポリシー",
      "footer.terms": "利用規約",
      "footer.support": "サポート",
      "footer.kinapps": "KinApps",
      "footer.rights": "すべての権利を保有します。",
      "images.gameplay": "光る矢印の道があるArrow Mazeのステージ",
      "images.photoSource": "色鮮やかなオウムの写真",
      "images.photoResult": "Arrow Mazeに変換されたオウム",
      "images.worlds": "Arrow Mazeのワールド旅画面",
      "images.daily": "Arrow Mazeのデイリーチャレンジ画面",
      "images.icon": "Arrow Mazeのアプリアイコン"
    },
    ko: {
      "meta.title": "Arrow Maze: 모두를 해방할 길을 찾아보세요",
      "meta.description": "240개 레벨, 일일 도전, Zen 모드, Photo Maze, Game Center가 있는 전략적인 화살표 퍼즐.",
      "skip": "본문으로 건너뛰기",
      "nav.aria": "주요 탐색 메뉴",
      "nav.play": "플레이",
      "nav.features": "기능",
      "nav.photo": "Photo Maze",
      "controls.language": "언어",
      "controls.theme": "테마",
      "theme.auto": "시스템",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "모든 화살표에는 나가는 길이 있습니다",
      "hero.title": "모두를 해방할 한 수를 찾아보세요.",
      "hero.body": "보드를 읽고 올바른 화살표를 선택해 복잡한 미로를 기분 좋게 모두 비워 보세요.",
      "hero.play": "퍼즐 체험하기",
      "hero.explore": "게임 둘러보기",
      "hero.previewAlt": "Arrow Maze 게임 플레이 미리보기",
      "hero.combo": "연속 클리어",
      "facts.aria": "게임 주요 특징",
      "facts.levels": "정교하게 만든 레벨",
      "facts.worlds": "변화하는 월드",
      "facts.dailyValue": "일일",
      "facts.daily": "새로운 미로",
      "facts.photoValue": "사진",
      "facts.photo": "미로가 됩니다",
      "play.title": "자유로운 화살표 하나가 보드 전체를 열 수 있습니다.",
      "play.body": "경로에 아무것도 없을 때만 화살표를 탭하세요. 올바른 순서를 찾고 콤보를 이어가세요.",
      "play.statusReady": "움직일 수 있는 화살표를 찾으세요.",
      "play.statusClear": "경로가 열렸습니다. 계속하세요.",
      "play.statusBlocked": "그 경로는 막혀 있습니다.",
      "play.statusDone": "보드를 모두 비웠습니다. 멋져요.",
      "play.reset": "퍼즐 초기화",
      "play.aria": "인터랙티브 Arrow Maze 퍼즐",
      "play.boardAria": "퍼즐 보드",
      "play.arrow": "화살표",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "내 사진이 퍼즐이 됩니다.",
      "photo.body": "피사체를 선택하면 Arrow Maze가 색상과 디테일을 바탕으로 플레이 가능한 실루엣을 만듭니다. 이미지는 기기에서 처리됩니다.",
      "photo.hint": "이미지 위를 드래그해 비교하세요.",
      "photo.compareAria": "사진과 미로 비교",
      "features.title": "어떤 속도에도 맞는 퍼즐.",
      "features.body": "계속 진행하거나, 매일 돌아오거나, 천천히 즐겨 보세요. 규칙은 단순하지만 선택은 점점 깊어집니다.",
      "features.worldsTitle": "7개의 월드를 여행하세요",
      "features.worldsBody": "새로운 보드 모양, 더 좁은 경로, 더 영리한 순서를 선보이는 240개 레벨을 마스터하세요.",
      "features.dailyTitle": "매일 돌아올 이유",
      "features.dailyBody": "데일리 미로를 풀고 연속 기록을 지키며, 바뀌는 3개의 퀘스트를 완료해 보상을 받으세요.",
      "features.moreTitle": "나만의 방식으로 플레이",
      "features.moreBody": "콤보를 만들고, 단계별 힌트를 사용하고, Zen에서 편안히 쉬며, Game Center에서 업적을 비교하세요.",
      "features.combo": "콤보",
      "features.hints": "힌트",
      "features.quests": "퀘스트",
      "themeStory.title": "나의 보드, 나의 분위기.",
      "themeStory.body": "Aurora는 퍼즐을 따뜻하고 선명하게 유지합니다. Midnight Neon은 모든 경로를 전기처럼 빛나는 색으로 바꿉니다. 위에서 테마를 바꾸면 페이지 전체가 함께 변합니다.",
      "cta.title": "다음 클리어가 기다리고 있습니다.",
      "cta.body": "iPhone과 iPad에서 Arrow Maze를 플레이하세요.",
      "cta.button": "App Store에서 다운로드",
      "footer.by": "KinApps 제작",
      "footer.aria": "법률 및 지원",
      "footer.privacy": "개인정보 처리방침",
      "footer.terms": "이용 약관",
      "footer.support": "지원",
      "footer.kinapps": "KinApps",
      "footer.rights": "모든 권리 보유.",
      "images.gameplay": "빛나는 화살표 경로가 있는 Arrow Maze 레벨",
      "images.photoSource": "화려한 앵무새 사진",
      "images.photoResult": "Arrow Maze로 변환된 앵무새",
      "images.worlds": "Arrow Maze 월드 여행 화면",
      "images.daily": "Arrow Maze 일일 도전 화면",
      "images.icon": "Arrow Maze 앱 아이콘"
    },
    "pt-BR": {
      "meta.title": "Arrow Maze - Encontre o caminho que libera todas as setas",
      "meta.description": "Um quebra-cabeça estratégico de setas com 240 níveis, desafios diários, modo Zen, Photo Maze e Game Center.",
      "skip": "Pular para o conteúdo",
      "nav.aria": "Navegação principal",
      "nav.play": "Jogar",
      "nav.features": "Recursos",
      "nav.photo": "Photo Maze",
      "controls.language": "Idioma",
      "controls.theme": "Tema",
      "theme.auto": "Sistema",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "Toda seta tem uma saída",
      "hero.title": "Encontre a jogada que libera todas as setas.",
      "hero.body": "Observe o tabuleiro, escolha a seta certa e transforme um labirinto lotado em uma solução super satisfatória.",
      "hero.play": "Testar o quebra-cabeça",
      "hero.explore": "Explorar o jogo",
      "hero.previewAlt": "Prévia de uma partida de Arrow Maze",
      "hero.combo": "Combo em cadeia",
      "facts.aria": "Destaques do jogo",
      "facts.levels": "níveis elaborados",
      "facts.worlds": "mundos em evolução",
      "facts.dailyValue": "Diário",
      "facts.daily": "um novo labirinto",
      "facts.photoValue": "Foto",
      "facts.photo": "vira um labirinto",
      "play.title": "Uma seta livre pode abrir o tabuleiro inteiro.",
      "play.body": "Toque em uma seta apenas quando nada bloquear seu caminho. Encontre a sequência e mantenha o combo ativo.",
      "play.statusReady": "Encontre a seta livre.",
      "play.statusClear": "Caminho livre. Continue.",
      "play.statusBlocked": "Esse caminho está bloqueado.",
      "play.statusDone": "Tabuleiro limpo. Perfeito.",
      "play.reset": "Reiniciar quebra-cabeça",
      "play.aria": "Quebra-cabeça interativo de Arrow Maze",
      "play.boardAria": "Tabuleiro do quebra-cabeça",
      "play.arrow": "Seta",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "Sua foto vira o quebra-cabeça.",
      "photo.body": "Escolha um tema e Arrow Maze criará uma silhueta jogável a partir de suas cores e detalhes. A imagem é processada no seu dispositivo.",
      "photo.hint": "Arraste sobre a imagem para comparar.",
      "photo.compareAria": "Comparar foto e labirinto",
      "features.title": "Um quebra-cabeça para cada ritmo.",
      "features.body": "Avance, volte todos os dias ou diminua o ritmo. As regras continuam simples enquanto as decisões ficam mais profundas.",
      "features.worldsTitle": "Viaje por sete mundos",
      "features.worldsBody": "Domine 240 níveis que apresentam novos formatos de tabuleiro, rotas mais apertadas e sequências mais inteligentes.",
      "features.dailyTitle": "Um motivo para voltar todos os dias",
      "features.dailyBody": "Resolva o labirinto diário, proteja sua sequência e conclua três missões diferentes para ganhar recompensas.",
      "features.moreTitle": "Jogue do seu jeito",
      "features.moreBody": "Monte combos, use dicas progressivas, relaxe no modo Zen e compare conquistas pelo Game Center.",
      "features.combo": "Combos",
      "features.hints": "Dicas",
      "features.quests": "Missões",
      "themeStory.title": "Seu tabuleiro, sua atmosfera.",
      "themeStory.body": "Aurora deixa o quebra-cabeça acolhedor e nítido. Neon transforma cada caminho em cores elétricas. Mude o tema acima e toda a página acompanhará.",
      "cta.title": "Sua próxima vitória está esperando.",
      "cta.body": "Jogue Arrow Maze no iPhone e no iPad.",
      "cta.button": "Baixe na App Store",
      "footer.by": "por KinApps",
      "footer.aria": "Informações legais e suporte",
      "footer.privacy": "Política de Privacidade",
      "footer.terms": "Termos de Uso",
      "footer.support": "Suporte",
      "footer.kinapps": "KinApps",
      "footer.rights": "Todos os direitos reservados.",
      "images.gameplay": "Nível de Arrow Maze com caminhos de setas brilhantes",
      "images.photoSource": "Foto de um papagaio colorido",
      "images.photoResult": "Papagaio transformado em um Arrow Maze",
      "images.worlds": "Tela da jornada pelos mundos de Arrow Maze",
      "images.daily": "Tela do desafio diário de Arrow Maze",
      "images.icon": "Ícone do app Arrow Maze"
    },
    "pt-PT": {
      "meta.title": "Arrow Maze - Encontra o caminho que liberta todas as setas",
      "meta.description": "Um puzzle estratégico de setas com 240 níveis, desafios diários, modo Zen, Photo Maze e Game Center.",
      "skip": "Saltar para o conteúdo",
      "nav.aria": "Navegação principal",
      "nav.play": "Jogar",
      "nav.features": "Funcionalidades",
      "nav.photo": "Photo Maze",
      "controls.language": "Idioma",
      "controls.theme": "Tema",
      "theme.auto": "Sistema",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "Cada seta tem uma saída",
      "hero.title": "Encontra a jogada que liberta todas as setas.",
      "hero.body": "Observa o tabuleiro, escolhe a seta certa e transforma um labirinto cheio numa solução muito gratificante.",
      "hero.play": "Experimentar o puzzle",
      "hero.explore": "Explorar o jogo",
      "hero.previewAlt": "Pré-visualização de uma partida de Arrow Maze",
      "hero.combo": "Combo em cadeia",
      "facts.aria": "Destaques do jogo",
      "facts.levels": "níveis cuidadosamente criados",
      "facts.worlds": "mundos em evolução",
      "facts.dailyValue": "Diário",
      "facts.daily": "um novo labirinto",
      "facts.photoValue": "Fotografia",
      "facts.photo": "torna-se um labirinto",
      "play.title": "Uma seta livre pode abrir todo o tabuleiro.",
      "play.body": "Toca numa seta apenas quando nada bloquear o seu caminho. Encontra a sequência e mantém o combo ativo.",
      "play.statusReady": "Encontra a seta livre.",
      "play.statusClear": "Caminho livre. Continua.",
      "play.statusBlocked": "Esse caminho está bloqueado.",
      "play.statusDone": "Tabuleiro limpo. Perfeito.",
      "play.reset": "Repor puzzle",
      "play.aria": "Puzzle interativo de Arrow Maze",
      "play.boardAria": "Tabuleiro do puzzle",
      "play.arrow": "Seta",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "A tua fotografia torna-se o puzzle.",
      "photo.body": "Escolhe um tema e Arrow Maze cria uma silhueta jogável a partir das suas cores e detalhes. A imagem é processada no teu dispositivo.",
      "photo.hint": "Arrasta sobre a imagem para comparar.",
      "photo.compareAria": "Comparar fotografia e labirinto",
      "features.title": "Um puzzle para todos os ritmos.",
      "features.body": "Avança, regressa todos os dias ou abranda o ritmo. As regras continuam simples enquanto as decisões ganham profundidade.",
      "features.worldsTitle": "Viaja por sete mundos",
      "features.worldsBody": "Domina 240 níveis que apresentam novas formas de tabuleiro, rotas mais apertadas e sequências mais inteligentes.",
      "features.dailyTitle": "Um motivo para regressar todos os dias",
      "features.dailyBody": "Resolve o labirinto diário, protege a tua sequência e conclui três missões diferentes para receber recompensas.",
      "features.moreTitle": "Joga à tua maneira",
      "features.moreBody": "Cria combos, usa pistas progressivas, relaxa no modo Zen e compara conquistas através do Game Center.",
      "features.combo": "Combos",
      "features.hints": "Pistas",
      "features.quests": "Missões",
      "themeStory.title": "O teu tabuleiro, a tua atmosfera.",
      "themeStory.body": "Aurora mantém o puzzle acolhedor e nítido. Neon transforma cada caminho em cores elétricas. Muda o tema acima e toda a página acompanha.",
      "cta.title": "A tua próxima vitória está à espera.",
      "cta.body": "Joga Arrow Maze no iPhone e no iPad.",
      "cta.button": "Descarregar na App Store",
      "footer.by": "por KinApps",
      "footer.aria": "Informações legais e suporte",
      "footer.privacy": "Política de Privacidade",
      "footer.terms": "Termos de Utilização",
      "footer.support": "Suporte",
      "footer.kinapps": "KinApps",
      "footer.rights": "Todos os direitos reservados.",
      "images.gameplay": "Nível de Arrow Maze com caminhos de setas brilhantes",
      "images.photoSource": "Fotografia de um papagaio colorido",
      "images.photoResult": "Papagaio transformado num Arrow Maze",
      "images.worlds": "Ecrã da viagem pelos mundos de Arrow Maze",
      "images.daily": "Ecrã do desafio diário de Arrow Maze",
      "images.icon": "Ícone da app Arrow Maze"
    },
    ru: {
      "meta.title": "Arrow Maze: найди ход, который освободит все стрелки",
      "meta.description": "Стратегическая головоломка со стрелками, 240 уровнями, ежедневными испытаниями, режимом Zen, Photo Maze и Game Center.",
      "skip": "Перейти к содержимому",
      "nav.aria": "Основная навигация",
      "nav.play": "Играть",
      "nav.features": "Возможности",
      "nav.photo": "Photo Maze",
      "controls.language": "Язык",
      "controls.theme": "Тема",
      "theme.auto": "Системная",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "У каждой стрелки есть выход",
      "hero.title": "Найди ход, который освободит все стрелки.",
      "hero.body": "Изучи поле, выбери правильную стрелку и преврати запутанный лабиринт в идеально чистое поле.",
      "hero.play": "Попробовать головоломку",
      "hero.explore": "Узнать больше об игре",
      "hero.previewAlt": "Предпросмотр игрового процесса Arrow Maze",
      "hero.combo": "Цепочка очисток",
      "facts.aria": "Главные особенности игры",
      "facts.levels": "продуманных уровней",
      "facts.worlds": "развивающихся миров",
      "facts.dailyValue": "Каждый день",
      "facts.daily": "новый лабиринт",
      "facts.photoValue": "Фото",
      "facts.photo": "становится лабиринтом",
      "play.title": "Одна свободная стрелка может открыть всё поле.",
      "play.body": "Нажимай на стрелку, только если её путь ничто не перекрывает. Найди верную последовательность и продолжай комбо.",
      "play.statusReady": "Найди свободную стрелку.",
      "play.statusClear": "Путь свободен. Продолжай.",
      "play.statusBlocked": "Этот путь заблокирован.",
      "play.statusDone": "Поле очищено. Красиво.",
      "play.reset": "Сбросить головоломку",
      "play.aria": "Интерактивная головоломка Arrow Maze",
      "play.boardAria": "Игровое поле головоломки",
      "play.arrow": "Стрелка",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "Твоё фото становится головоломкой",
      "photo.body": "Выбери объект, и Arrow Maze создаст по его цветам и деталям игровой силуэт. Изображение обрабатывается на твоём устройстве.",
      "photo.hint": "Проведи по изображению, чтобы сравнить.",
      "photo.compareAria": "Сравнить фото и лабиринт",
      "features.title": "Головоломка для любого ритма.",
      "features.body": "Продвигайся вперёд, возвращайся каждый день или играй не спеша. Правила остаются простыми, а решения становятся всё глубже.",
      "features.worldsTitle": "Путешествуй по семи мирам",
      "features.worldsBody": "Освой 240 уровней с новыми формами поля, более тесными маршрутами и хитрыми последовательностями.",
      "features.dailyTitle": "Причина возвращаться каждый день",
      "features.dailyBody": "Решай ежедневный лабиринт, сохраняй серию и выполняй три меняющихся задания ради наград.",
      "features.moreTitle": "Играй по-своему",
      "features.moreBody": "Собирай комбо, используй многоуровневые подсказки, отдыхай в Zen и сравнивай достижения через Game Center.",
      "features.combo": "Комбо",
      "features.hints": "Подсказки",
      "features.quests": "Задания",
      "themeStory.title": "Твоё поле, твоя атмосфера.",
      "themeStory.body": "Aurora сохраняет оформление тёплым и ясным. Midnight Neon превращает каждый путь в электрический цвет. Смени тему выше, и вся страница изменится вместе с ней.",
      "cta.title": "Следующая победа уже ждёт.",
      "cta.body": "Играйте в Arrow Maze на iPhone и iPad.",
      "cta.button": "Скачать в App Store",
      "footer.by": "от KinApps",
      "footer.aria": "Правовая информация и поддержка",
      "footer.privacy": "Конфиденциальность",
      "footer.terms": "Условия",
      "footer.support": "Поддержка",
      "footer.kinapps": "KinApps",
      "footer.rights": "Все права защищены.",
      "images.gameplay": "Уровень Arrow Maze со светящимися путями стрелок",
      "images.photoSource": "Фото яркого попугая",
      "images.photoResult": "Попугай, превращённый в Arrow Maze",
      "images.worlds": "Экран путешествия по мирам Arrow Maze",
      "images.daily": "Экран ежедневного испытания Arrow Maze",
      "images.icon": "Значок приложения Arrow Maze"
    },
    th: {
      "meta.title": "Arrow Maze: ค้นหาจังหวะที่ปลดปล่อยลูกศรทั้งหมด",
      "meta.description": "เกมปริศนาลูกศรเชิงกลยุทธ์ที่มี 240 ด่าน โจทย์รายวัน โหมด Zen, Photo Maze และ Game Center",
      "skip": "ข้ามไปยังเนื้อหา",
      "nav.aria": "การนำทางหลัก",
      "nav.play": "เล่น",
      "nav.features": "คุณสมบัติ",
      "nav.photo": "Photo Maze",
      "controls.language": "ภาษา",
      "controls.theme": "ธีม",
      "theme.auto": "ระบบ",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "ลูกศรทุกดอกมีทางออก",
      "hero.title": "ค้นหาจังหวะที่ปลดปล่อยลูกศรทั้งหมด",
      "hero.body": "อ่านกระดาน เลือกลูกศรที่ถูกต้อง แล้วเปลี่ยนเขาวงกตที่แน่นขนัดให้กลายเป็นกระดานโล่งอย่างน่าพอใจ",
      "hero.play": "ลองเล่นปริศนา",
      "hero.explore": "สำรวจเกม",
      "hero.previewAlt": "ตัวอย่างการเล่น Arrow Maze",
      "hero.combo": "เคลียร์ต่อเนื่อง",
      "facts.aria": "จุดเด่นของเกม",
      "facts.levels": "ด่านที่ออกแบบอย่างพิถีพิถัน",
      "facts.worlds": "โลกที่พัฒนาอย่างต่อเนื่อง",
      "facts.dailyValue": "รายวัน",
      "facts.daily": "เขาวงกตใหม่",
      "facts.photoValue": "รูปภาพ",
      "facts.photo": "กลายเป็นเขาวงกต",
      "play.title": "ลูกศรอิสระเพียงดอกเดียวเปิดทั้งกระดานได้",
      "play.body": "แตะลูกศรเฉพาะเมื่อไม่มีอะไรขวางเส้นทาง ค้นหาลำดับที่ถูกต้องและรักษาคอมโบไว้",
      "play.statusReady": "ค้นหาลูกศรที่ไปได้",
      "play.statusClear": "เส้นทางว่าง ไปต่อเลย",
      "play.statusBlocked": "เส้นทางนั้นถูกขวาง",
      "play.statusDone": "เคลียร์กระดานแล้ว สวยงาม",
      "play.reset": "รีเซ็ตปริศนา",
      "play.aria": "ปริศนา Arrow Maze แบบโต้ตอบ",
      "play.boardAria": "กระดานปริศนา",
      "play.arrow": "ลูกศร",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "รูปของคุณกลายเป็นปริศนา",
      "photo.body": "เลือกวัตถุ แล้ว Arrow Maze จะสร้างเงารูปที่เล่นได้จากสีและรายละเอียดของภาพ รูปภาพจะถูกประมวลผลบนอุปกรณ์ของคุณ",
      "photo.hint": "ลากผ่านภาพเพื่อเปรียบเทียบ",
      "photo.compareAria": "เปรียบเทียบรูปภาพกับเขาวงกต",
      "features.title": "ปริศนาสำหรับทุกจังหวะการเล่น",
      "features.body": "เดินหน้า กลับมาทุกวัน หรือค่อย ๆ เล่น กติกายังคงเรียบง่าย ขณะที่การตัดสินใจลึกซึ้งขึ้น",
      "features.worldsTitle": "เดินทางผ่านเจ็ดโลก",
      "features.worldsBody": "ฝึกฝน 240 ด่านที่นำเสนอรูปทรงกระดานใหม่ เส้นทางที่แคบขึ้น และลำดับที่ชาญฉลาดขึ้น",
      "features.dailyTitle": "เหตุผลให้กลับมาทุกวัน",
      "features.dailyBody": "แก้เขาวงกตรายวัน รักษาสถิติต่อเนื่อง และทำภารกิจที่เปลี่ยนไปสามรายการเพื่อรับรางวัล",
      "features.moreTitle": "เล่นในแบบของคุณ",
      "features.moreBody": "สร้างคอมโบ ใช้คำใบ้หลายระดับ ผ่อนคลายใน Zen และเปรียบเทียบความสำเร็จผ่าน Game Center",
      "features.combo": "คอมโบ",
      "features.hints": "คำใบ้",
      "features.quests": "ภารกิจ",
      "themeStory.title": "กระดานของคุณ บรรยากาศของคุณ",
      "themeStory.body": "Aurora ทำให้ปริศนาดูอบอุ่นและชัดเจน Midnight Neon เปลี่ยนทุกเส้นทางให้เป็นสีไฟฟ้า เปลี่ยนธีมด้านบน แล้วทั้งหน้าจะเปลี่ยนตาม",
      "cta.title": "การเคลียร์ครั้งต่อไปรอคุณอยู่",
      "cta.body": "เล่น Arrow Maze บน iPhone และ iPad",
      "cta.button": "ดาวน์โหลดบน App Store",
      "footer.by": "โดย KinApps",
      "footer.aria": "ข้อมูลทางกฎหมายและการช่วยเหลือ",
      "footer.privacy": "นโยบายความเป็นส่วนตัว",
      "footer.terms": "ข้อกำหนดการใช้งาน",
      "footer.support": "การช่วยเหลือ",
      "footer.kinapps": "KinApps",
      "footer.rights": "สงวนลิขสิทธิ์",
      "images.gameplay": "ด่าน Arrow Maze ที่มีเส้นทางลูกศรเรืองแสง",
      "images.photoSource": "รูปนกแก้วสีสันสดใส",
      "images.photoResult": "นกแก้วที่แปลงเป็น Arrow Maze",
      "images.worlds": "หน้าจอการเดินทางรอบโลกของ Arrow Maze",
      "images.daily": "หน้าจอโจทย์รายวันของ Arrow Maze",
      "images.icon": "ไอคอนแอป Arrow Maze"
    },
    "zh-Hant": {
      "meta.title": "Arrow Maze: 找出能解放所有箭頭的關鍵一步",
      "meta.description": "一款策略箭頭益智遊戲，包含240個關卡、每日挑戰、Zen模式、Photo Maze和Game Center。",
      "skip": "跳至內容",
      "nav.aria": "主要導覽",
      "nav.play": "遊玩",
      "nav.features": "特色",
      "nav.photo": "Photo Maze",
      "controls.language": "語言",
      "controls.theme": "主題",
      "theme.auto": "系統",
      "theme.light": "Aurora",
      "theme.dark": "Neon",
      "hero.eyebrow": "每支箭頭都有出口",
      "hero.title": "找出能解放所有箭頭的關鍵一步。",
      "hero.body": "觀察盤面，選對箭頭，將擁擠糾結的迷宮暢快地完全清空。",
      "hero.play": "試玩謎題",
      "hero.explore": "探索遊戲",
      "hero.previewAlt": "Arrow Maze遊戲玩法預覽",
      "hero.combo": "連續清除",
      "facts.aria": "遊戲亮點",
      "facts.levels": "精心設計的關卡",
      "facts.worlds": "持續演變的世界",
      "facts.dailyValue": "每日",
      "facts.daily": "全新迷宮",
      "facts.photoValue": "相片",
      "facts.photo": "變成迷宮",
      "play.title": "一支暢通的箭頭就能開啟整個盤面。",
      "play.body": "只有在前方沒有阻擋時才能點擊箭頭。找出正確順序，持續累積連擊。",
      "play.statusReady": "找出前方暢通的箭頭。",
      "play.statusClear": "路徑暢通。繼續前進。",
      "play.statusBlocked": "這條路徑受阻。",
      "play.statusDone": "盤面已清空。漂亮。",
      "play.reset": "重設謎題",
      "play.aria": "互動式Arrow Maze謎題",
      "play.boardAria": "謎題盤面",
      "play.arrow": "箭頭",
      "photo.eyebrow": "Photo Maze",
      "photo.title": "你的相片變成謎題。",
      "photo.body": "選擇主體，Arrow Maze會依據色彩和細節建立可遊玩的剪影。圖像會在你的裝置上處理。",
      "photo.hint": "在圖像上拖曳即可比較。",
      "photo.compareAria": "比較相片與迷宮",
      "features.title": "適合每種步調的謎題。",
      "features.body": "推進進度、每天回來，或放慢腳步。規則保持簡單，抉擇卻愈來愈有深度。",
      "features.worldsTitle": "遊歷七個世界",
      "features.worldsBody": "精通240個關卡，迎接全新盤面形狀、更狹窄的路線和更巧妙的順序。",
      "features.dailyTitle": "每天回來的理由",
      "features.dailyBody": "解開每日迷宮、守住連續紀錄，並完成三項不斷變化的任務以獲得獎勵。",
      "features.moreTitle": "用你的方式遊玩",
      "features.moreBody": "累積連擊、使用分層提示、在Zen中放鬆，並透過Game Center比較成就。",
      "features.combo": "連擊",
      "features.hints": "提示",
      "features.quests": "任務",
      "themeStory.title": "你的盤面，你的氛圍。",
      "themeStory.body": "Aurora讓謎題溫暖而清晰。Midnight Neon讓每條路徑化為電光色彩。切換上方主題，整個頁面也會隨之改變。",
      "cta.title": "下一次暢快清空正等著你。",
      "cta.body": "在iPhone和iPad上暢玩Arrow Maze。",
      "cta.button": "在App Store下載",
      "footer.by": "由KinApps打造",
      "footer.aria": "法律資訊與支援",
      "footer.privacy": "隱私權政策",
      "footer.terms": "使用條款",
      "footer.support": "支援",
      "footer.kinapps": "KinApps",
      "footer.rights": "保留所有權利。",
      "images.gameplay": "具有發光箭頭路徑的Arrow Maze關卡",
      "images.photoSource": "色彩繽紛的鸚鵡相片",
      "images.photoResult": "變成Arrow Maze的鸚鵡",
      "images.worlds": "Arrow Maze世界旅程畫面",
      "images.daily": "Arrow Maze每日挑戰畫面",
      "images.icon": "Arrow Maze App圖示"
    }
  };

  const localeSelect = document.querySelector("#languageSelect");
  const themeSelect = document.querySelector("#themeSelect");
  const colourScheme = window.matchMedia("(prefers-color-scheme: dark)");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  let activeLocale = "en";
  let activeThemeMode = "auto";

  function normaliseLocale(locale) {
    if (!locale) return null;
    const normalised = locale.replace("_", "-");
    const exact = supportedLocales.find((item) => item.toLowerCase() === normalised.toLowerCase());
    if (exact) return exact;

    const lower = normalised.toLowerCase();
    if (lower.startsWith("zh")) {
      if (lower.includes("hant") || lower.startsWith("zh-tw") || lower.startsWith("zh-hk") || lower.startsWith("zh-mo")) return "zh-Hant";
      return null;
    }
    if (lower.startsWith("pt-br")) return "pt-BR";
    if (lower.startsWith("pt")) return "pt-PT";
    if (lower.startsWith("es-mx")) return "es-MX";
    if (lower.startsWith("es")) return "es";
    if (lower.startsWith("en-in")) return "en-IN";
    if (lower.startsWith("en")) return "en";

    const base = lower.split("-")[0];
    return supportedLocales.find((item) => item.toLowerCase() === base) || null;
  }

  function detectLocale() {
    try {
      const stored = localStorage.getItem(STORAGE_LOCALE);
      if (stored && supportedLocales.includes(stored)) return stored;
    } catch (_) {
      // Storage can be unavailable in private browsing. System detection still works.
    }

    const candidates = navigator.languages?.length ? navigator.languages : [navigator.language];
    for (const candidate of candidates) {
      const locale = normaliseLocale(candidate);
      if (locale) return locale;
    }
    return "en";
  }

  function text(key) {
    return translations[activeLocale]?.[key] || translations.en[key] || key;
  }

  function applyLocale(locale, persist = false) {
    activeLocale = supportedLocales.includes(locale) ? locale : "en";
    document.documentElement.lang = activeLocale;
    localeSelect.value = activeLocale;

    document.querySelectorAll("[data-i18n]").forEach((element) => {
      element.textContent = text(element.dataset.i18n);
    });
    document.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
      element.setAttribute("aria-label", text(element.dataset.i18nAriaLabel));
    });
    document.querySelectorAll("[data-i18n-alt]").forEach((element) => {
      element.setAttribute("alt", text(element.dataset.i18nAlt));
    });

    document.title = text("meta.title");
    const description = document.querySelector('meta[name="description"]');
    const ogTitle = document.querySelector('meta[property="og:title"]');
    const ogDescription = document.querySelector('meta[property="og:description"]');
    if (description) description.content = text("meta.description");
    if (ogTitle) ogTitle.content = text("meta.title");
    if (ogDescription) ogDescription.content = text("meta.description");

    updateMazeAccessibility();
    if (persist) {
      try { localStorage.setItem(STORAGE_LOCALE, activeLocale); } catch (_) { /* No-op. */ }
    }
  }

  function resolveTheme(mode) {
    if (mode === "light" || mode === "dark") return mode;
    return colourScheme.matches ? "dark" : "light";
  }

  function applyTheme(mode, persist = false) {
    activeThemeMode = ["auto", "light", "dark"].includes(mode) ? mode : "auto";
    document.documentElement.dataset.themeMode = activeThemeMode;
    document.documentElement.dataset.theme = resolveTheme(activeThemeMode);
    themeSelect.value = activeThemeMode;
    if (persist) {
      try { localStorage.setItem(STORAGE_THEME, activeThemeMode); } catch (_) { /* No-op. */ }
    }
    window.dispatchEvent(new CustomEvent("arrowmaze:themechange"));
  }

  function detectTheme() {
    try {
      const stored = localStorage.getItem(STORAGE_THEME);
      if (["auto", "light", "dark"].includes(stored)) return stored;
    } catch (_) {
      // Use system theme when storage is unavailable.
    }
    return "auto";
  }

  localeSelect.addEventListener("change", () => applyLocale(localeSelect.value, true));
  themeSelect.addEventListener("change", () => applyTheme(themeSelect.value, true));
  colourScheme.addEventListener("change", () => {
    if (activeThemeMode === "auto") applyTheme("auto");
  });

  document.querySelectorAll("[data-theme-choice]").forEach((button) => {
    button.addEventListener("click", () => applyTheme(button.dataset.themeChoice, true));
  });

  const revealElements = [...document.querySelectorAll(".reveal")];
  if (reduceMotion.matches || !("IntersectionObserver" in window)) {
    revealElements.forEach((element) => element.classList.add("is-visible"));
  } else {
    const revealObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -8%", threshold: 0.12 });
    revealElements.forEach((element) => revealObserver.observe(element));
  }

  // Exact campaign level 1 from MazeArrows/Data/levels.json (story_1).
  // Every ordered cell list is one independent snake arrow; the final cell is
  // its head. Keeping this literal data here makes the web demo render the
  // same 12 × 16 board as the app instead of an approximation.
  const puzzleDefinition = {
    width: 12,
    height: 16,
    pieces: [
      ["s1_1", "up", [[7,6],[7,5],[7,4],[7,3],[8,3],[9,3],[10,3],[10,2],[10,1],[11,1],[11,0]]],
      ["s1_2", "right", [[6,5],[6,4],[6,3],[6,2],[7,2],[8,2],[9,2],[9,1],[9,0],[10,0]]],
      ["s1_3", "up", [[8,4],[9,4],[10,4],[10,5],[11,5],[11,4],[11,3],[11,2]]],
      ["s1_4", "up", [[10,6],[11,6],[11,7],[10,7],[9,7],[9,6],[9,5]]],
      ["s1_5", "left", [[1,0],[0,0],[0,1],[1,1],[2,1],[2,0],[3,0],[3,1],[3,2],[2,2],[1,2],[0,2]]],
      ["s1_6", "down", [[9,14],[9,15],[10,15],[10,14],[10,13],[10,12],[11,12],[11,13],[11,14],[11,15]]],
      ["s1_7", "down", [[9,8],[10,8],[11,8],[11,9],[11,10],[11,11],[10,11],[9,11],[9,12],[9,13]]],
      ["s1_8", "up", [[4,15],[5,15],[5,14],[5,13],[6,13],[7,13],[8,13],[8,12],[8,11],[8,10],[9,10],[10,10],[10,9]]],
      ["s1_9", "right", [[6,9],[6,10],[6,11],[6,12],[7,12],[7,11],[7,10],[7,9],[8,9],[9,9]]],
      ["s1_10", "down", [[0,15],[1,15],[2,15],[3,15],[3,14],[3,13],[3,12],[4,12],[4,13],[4,14]]],
      ["s1_11", "down", [[2,6],[2,7],[2,8],[2,9],[3,9],[4,9],[5,9],[5,10],[5,11],[5,12]]],
      ["s1_12", "right", [[8,5],[8,6],[8,7],[7,7],[6,7],[5,7],[5,8],[6,8],[7,8],[8,8]]],
      ["s1_13", "right", [[3,6],[3,7],[3,8],[4,8],[4,7],[4,6],[4,5],[5,5],[5,6],[6,6]]],
      ["s1_14", "right", [[3,5],[3,4],[3,3],[2,3],[1,3],[0,3],[0,4],[0,5],[0,6],[1,6]]],
      ["s1_15", "up", [[1,4],[1,5],[2,5],[2,4]]],
      ["s1_16", "left", [[7,0],[8,0],[8,1],[7,1],[6,1],[5,1],[5,2],[5,3],[5,4],[4,4]]],
      ["s1_17", "right", [[4,3],[4,2],[4,1],[4,0],[5,0],[6,0]]],
      ["s1_18", "down", [[7,15],[6,15],[6,14],[7,14],[8,14],[8,15]]],
      ["s1_19", "up", [[3,10],[2,10],[1,10],[1,11],[2,11],[3,11],[4,11],[4,10]]],
      ["s1_20", "down", [[0,11],[0,12],[0,13],[0,14],[1,14],[1,13],[1,12],[2,12],[2,13],[2,14]]],
      ["s1_21", "down", [[0,10],[0,9],[0,8],[0,7],[1,7],[1,8],[1,9]]]
    ].map(([id, direction, cells]) => ({ id, direction, cells }))
  };

  const board = document.querySelector("#miniGameBoard");
  const playStatus = document.querySelector("#playStatus");
  const comboValue = document.querySelector("#comboValue");
  const resetButton = document.querySelector("#resetMaze");
  const svgNamespace = "http://www.w3.org/2000/svg";
  let puzzlePieces = [];
  let combo = 0;
  let puzzleLocked = false;
  let hoveredPiece = null;
  let mazeSvg = null;
  let gridDots = [];
  let mazeGeneration = 0;
  let currentChevronUnits = 0.23;

  function directionDelta(direction) {
    return {
      up: [0, -1],
      right: [1, 0],
      down: [0, 1],
      left: [-1, 0]
    }[direction];
  }

  function pieceIsFree(piece) {
    const [xDelta, yDelta] = directionDelta(piece.direction);
    const head = piece.cells[piece.cells.length - 1];
    let x = head[0];
    let y = head[1];

    while (true) {
      x += xDelta;
      y += yDelta;
      if (x < 0 || x >= puzzleDefinition.width || y < 0 || y >= puzzleDefinition.height) {
        return true;
      }
      const key = x + ":" + y;
      const isBlocked = puzzlePieces.some((other) => (
        other.alive && other.id !== piece.id && other.cellSet.has(key)
      ));
      if (isBlocked) return false;
    }
  }

  function svgElement(name, attributes = {}) {
    const element = document.createElementNS(svgNamespace, name);
    Object.entries(attributes).forEach(([key, value]) => element.setAttribute(key, value));
    return element;
  }

  function simplifiedCells(cells) {
    if (cells.length <= 2) return cells;
    const result = [cells[0]];
    for (let index = 1; index < cells.length - 1; index += 1) {
      const previous = cells[index - 1];
      const current = cells[index];
      const next = cells[index + 1];
      const firstDelta = [current[0] - previous[0], current[1] - previous[1]];
      const secondDelta = [next[0] - current[0], next[1] - current[1]];
      if (firstDelta[0] === secondDelta[0] && firstDelta[1] === secondDelta[1]) continue;
      result.push(current);
    }
    result.push(cells[cells.length - 1]);
    return result;
  }

  function buildRenderPath(points, direction, chevronHalf = 0.23) {
    if (!points.length) return "";
    const body = points.map(([x, y], index) => (index === 0 ? "M" : "L") + x + " " + y).join(" ");
    const [headX, headY] = points[points.length - 1];
    const arms = {
      up: [[headX - chevronHalf, headY + chevronHalf], [headX + chevronHalf, headY + chevronHalf]],
      right: [[headX - chevronHalf, headY - chevronHalf], [headX - chevronHalf, headY + chevronHalf]],
      down: [[headX - chevronHalf, headY - chevronHalf], [headX + chevronHalf, headY - chevronHalf]],
      left: [[headX + chevronHalf, headY - chevronHalf], [headX + chevronHalf, headY + chevronHalf]]
    }[direction];
    return body + " M" + arms[0][0] + " " + arms[0][1]
      + " L" + headX + " " + headY
      + " L" + arms[1][0] + " " + arms[1][1];
  }

  function buildPiecePath(piece, chevronHalf = 0.23) {
    const points = simplifiedCells(piece.cells).map(([x, y]) => [x + 0.5, y + 0.5]);
    return buildRenderPath(points, piece.direction, chevronHalf);
  }

  function renderPathSampler(points) {
    const segments = [];
    let totalLength = 0;
    for (let index = 1; index < points.length; index += 1) {
      const start = points[index - 1];
      const end = points[index];
      const length = Math.hypot(end[0] - start[0], end[1] - start[1]);
      if (length <= 0) continue;
      segments.push({ start, end, length, cumulative: totalLength });
      totalLength += length;
    }

    function pointAt(distance) {
      if (!segments.length) return points[0] ?? [0, 0];
      if (distance <= 0) return segments[0].start;
      if (distance >= totalLength) return segments[segments.length - 1].end;
      const segment = segments.find((candidate) => (
        distance <= candidate.cumulative + candidate.length
      )) ?? segments[segments.length - 1];
      const progress = (distance - segment.cumulative) / segment.length;
      return [
        segment.start[0] + (segment.end[0] - segment.start[0]) * progress,
        segment.start[1] + (segment.end[1] - segment.start[1]) * progress
      ];
    }

    function pointsBetween(start, end) {
      if (start >= end) return [pointAt(start)];
      const result = [pointAt(start)];
      segments.forEach((segment) => {
        const vertexDistance = segment.cumulative + segment.length;
        if (vertexDistance > start + 0.0001 && vertexDistance < end - 0.0001) {
          result.push(segment.end);
        }
      });
      result.push(pointAt(end));
      return result;
    }

    return { pointsBetween };
  }

  function cleanedBody(points) {
    if (points.length <= 2) return points;
    const epsilon = 0.000001;
    const result = [points[0]];
    points.slice(1).forEach((point) => {
      const last = result[result.length - 1];
      if (Math.hypot(point[0] - last[0], point[1] - last[1]) < epsilon) {
        result[result.length - 1] = point;
        return;
      }
      while (result.length >= 2) {
        const a = result[result.length - 2];
        const b = result[result.length - 1];
        const cross = (b[0] - a[0]) * (point[1] - b[1])
          - (b[1] - a[1]) * (point[0] - b[0]);
        const dot = (b[0] - a[0]) * (point[0] - b[0])
          + (b[1] - a[1]) * (point[1] - b[1]);
        if (Math.abs(cross) < epsilon && dot > 0) {
          result.pop();
        } else {
          break;
        }
      }
      result.push(point);
    });
    return result;
  }

  function exitDistanceInCells(piece) {
    const xs = piece.cells.map(([x]) => x);
    const ys = piece.cells.map(([, y]) => y);
    const padding = 2;
    const scenePadding = 1;
    switch (piece.direction) {
      case "right":
        return Math.max(0, puzzleDefinition.width - Math.max(...xs)) + padding + scenePadding;
      case "left":
        return Math.min(...xs) + padding + scenePadding;
      case "down":
        return Math.max(0, puzzleDefinition.height - Math.max(...ys)) + padding + scenePadding;
      case "up":
      default:
        return Math.min(...ys) + padding + scenePadding;
    }
  }

  function cancelPieceAnimation(piece) {
    piece.animationToken = (piece.animationToken ?? 0) + 1;
    if (piece.animationFrame) window.cancelAnimationFrame(piece.animationFrame);
    piece.animationFrame = 0;
    const resolveAnimation = piece.animationResolve;
    piece.animationResolve = null;
    resolveAnimation?.(false);
    piece.tremorAnimation?.cancel();
    piece.tremorAnimation = null;
  }

  async function animatePieceFlyOut(piece) {
    const token = (piece.animationToken ?? 0) + 1;
    piece.animationToken = token;
    piece.isAnimating = true;
    piece.element.classList.add("is-flying");
    piece.buttonElement.disabled = true;

    if (reduceMotion.matches) {
      const fade = piece.element.animate(
        [{ opacity: 1 }, { opacity: 0 }],
        { duration: 120, easing: "ease-in", fill: "forwards" }
      );
      piece.tremorAnimation = fade;
      await fade.finished.catch(() => {});
      piece.tremorAnimation = null;
      return piece.animationToken === token;
    }

    const [xDelta, yDelta] = directionDelta(piece.direction);
    const tremorAmplitude = 1.2;
    const perpendicularX = yDelta * tremorAmplitude;
    const perpendicularY = -xDelta * tremorAmplitude;
    const tremor = piece.element.animate([
      { transform: "translate(0, 0)" },
      { transform: `translate(${perpendicularX}px, ${perpendicularY}px)` },
      { transform: `translate(${-perpendicularX}px, ${-perpendicularY}px)` },
      { transform: `translate(${perpendicularX}px, ${perpendicularY}px)` },
      { transform: "translate(0, 0)" }
    ], {
      duration: 140,
      easing: "linear"
    });
    piece.tremorAnimation = tremor;
    await tremor.finished.catch(() => {});
    piece.tremorAnimation = null;
    if (piece.animationToken !== token) return false;

    const bodyPoints = simplifiedCells(piece.cells).map(([x, y]) => [x + 0.5, y + 0.5]);
    const head = bodyPoints[bodyPoints.length - 1];
    const pieceLength = Math.max(1, piece.cells.length - 1);
    const exitLength = exitDistanceInCells(piece) + pieceLength + 1;
    const extendedEnd = [
      head[0] + xDelta * exitLength,
      head[1] + yDelta * exitLength
    ];
    const sampler = renderPathSampler([...bodyPoints, extendedEnd]);
    const duration = Math.min(580, Math.max(280, 180 + 18 * piece.cells.length));

    return new Promise((resolve) => {
      piece.animationResolve = resolve;
      let startedAt = 0;
      const finish = (completed) => {
        if (piece.animationResolve !== resolve) return;
        piece.animationResolve = null;
        resolve(completed);
      };
      const frame = (timestamp) => {
        if (piece.animationToken !== token) {
          finish(false);
          return;
        }
        if (!startedAt) startedAt = timestamp;
        const raw = Math.min(1, Math.max(0, (timestamp - startedAt) / duration));
        const advance = raw * raw * exitLength;
        const visibleBody = cleanedBody(
          sampler.pointsBetween(advance, advance + pieceLength)
        );
        const path = buildRenderPath(visibleBody, piece.direction, currentChevronUnits);
        piece.lineElement.setAttribute("d", path);
        piece.focusElement.setAttribute("d", path);

        if (raw > 0.76) {
          const fadeProgress = (raw - 0.76) / 0.24;
          piece.element.style.opacity = String(1 - fadeProgress * fadeProgress);
        }

        if (raw < 1) {
          piece.animationFrame = window.requestAnimationFrame(frame);
        } else {
          piece.animationFrame = 0;
          finish(true);
        }
      };
      piece.animationFrame = window.requestAnimationFrame(frame);
    });
  }

  function updateMazeMetrics() {
    if (!mazeSvg || !board.clientWidth) return;
    const cellPixels = board.clientWidth / puzzleDefinition.width;
    const strokePixels = Math.min(
      cellPixels * 0.46,
      Math.min(8, Math.max(2, cellPixels * 0.22))
    );
    const chevronPixels = Math.min(
      cellPixels * 0.30,
      Math.max(3, cellPixels * 0.23)
    );
    const dotPixels = Math.max(0.55, Math.min(1.15, cellPixels * 0.045));
    const chevronUnits = chevronPixels / cellPixels;
    const dotUnits = dotPixels / cellPixels;
    currentChevronUnits = chevronUnits;

    board.style.setProperty("--maze-stroke", strokePixels + "px");
    board.style.setProperty("--maze-focus-stroke", strokePixels + 7 + "px");
    board.style.setProperty("--maze-glow", strokePixels * 0.45 + "px");
    board.style.borderRadius = Math.min(24, Math.max(8, cellPixels * 0.7)) + "px";
    gridDots.forEach((dot) => dot.setAttribute("r", String(dotUnits)));
    puzzlePieces.forEach((piece) => {
      if (piece.isAnimating || !piece.alive) return;
      const path = buildPiecePath(piece, chevronUnits);
      piece.lineElement?.setAttribute("d", path);
      piece.focusElement?.setAttribute("d", path);
    });
  }

  function pieceAtPointer(event) {
    const bounds = board.getBoundingClientRect();
    const x = Math.floor(((event.clientX - bounds.left) / bounds.width) * puzzleDefinition.width);
    const y = Math.floor(((event.clientY - bounds.top) / bounds.height) * puzzleDefinition.height);
    const key = x + ":" + y;
    return puzzlePieces.find((piece) => (
      piece.alive && !piece.isAnimating && piece.cellSet.has(key)
    )) ?? null;
  }

  function updateFreePieces() {
    puzzlePieces.forEach((piece) => {
      piece.element?.classList.toggle("is-free", piece.alive && pieceIsFree(piece));
      piece.element?.setAttribute("data-state", piece.alive && pieceIsFree(piece) ? "free" : "blocked");
    });
  }

  function updateMazeAccessibility() {
    if (!puzzlePieces.length) return;
    puzzlePieces.forEach((piece, index) => {
      piece.buttonElement?.setAttribute("aria-label", `${text("play.arrow")} ${index + 1}`);
    });
    if (combo === 0 && puzzlePieces.some((piece) => piece.alive)) {
      playStatus.textContent = text("play.statusReady");
    }
  }

  function resetPuzzle() {
    mazeGeneration += 1;
    puzzlePieces.forEach(cancelPieceAnimation);
    combo = 0;
    puzzleLocked = false;
    hoveredPiece = null;
    board.replaceChildren();
    board.classList.remove("is-complete");
    playStatus.textContent = text("play.statusReady");
    comboValue.textContent = "×0";

    mazeSvg = svgElement("svg", {
      class: "maze-board-svg",
      viewBox: "0 0 12 16",
      preserveAspectRatio: "xMidYMid meet",
      "aria-hidden": "true",
      focusable: "false"
    });
    const gridLayer = svgElement("g", { class: "maze-grid", "aria-hidden": "true" });
    gridDots = [];
    for (let y = 0; y < puzzleDefinition.height; y += 1) {
      for (let x = 0; x < puzzleDefinition.width; x += 1) {
        const dot = svgElement("circle", {
          class: "maze-grid-dot",
          cx: String(x + 0.5),
          cy: String(y + 0.5),
          r: "0.045"
        });
        gridLayer.append(dot);
        gridDots.push(dot);
      }
    }
    mazeSvg.append(gridLayer);
    const pieceLayer = svgElement("g", { class: "maze-piece-layer" });
    const keyboardLayer = document.createElement("div");
    keyboardLayer.className = "maze-keyboard-controls";

    puzzlePieces = puzzleDefinition.pieces.map((template, index) => {
      const piece = {
        ...template,
        alive: true,
        element: null,
        lineElement: null,
        focusElement: null,
        buttonElement: null,
        isAnimating: false,
        animationFrame: 0,
        animationToken: 0,
        animationResolve: null,
        tremorAnimation: null,
        cellSet: new Set(template.cells.map(([x, y]) => x + ":" + y))
      };
      const group = svgElement("g", {
        class: "maze-piece"
      });
      const focus = svgElement("path", {
        class: "maze-piece-focus",
        d: buildPiecePath(piece),
        "vector-effect": "non-scaling-stroke"
      });
      const line = svgElement("path", {
        class: "maze-piece-line",
        d: buildPiecePath(piece),
        "vector-effect": "non-scaling-stroke"
      });
      group.append(focus, line);
      pieceLayer.append(group);
      const button = document.createElement("button");
      const head = template.cells[template.cells.length - 1];
      button.type = "button";
      button.className = "maze-piece-keyboard";
      button.style.left = ((head[0] + 0.5) / puzzleDefinition.width) * 100 + "%";
      button.style.top = ((head[1] + 0.5) / puzzleDefinition.height) * 100 + "%";
      button.setAttribute("aria-label", text("play.arrow") + " " + (index + 1));
      button.addEventListener("click", () => handlePieceTap(piece));
      button.addEventListener("keydown", (event) => {
        if (event.key !== "Enter" && event.key !== " ") return;
        event.preventDefault();
        handlePieceTap(piece);
      });
      button.addEventListener("focus", () => group.classList.add("is-keyboard-focus"));
      button.addEventListener("blur", () => group.classList.remove("is-keyboard-focus"));
      keyboardLayer.append(button);
      piece.element = group;
      piece.lineElement = line;
      piece.focusElement = focus;
      piece.buttonElement = button;
      return piece;
    });
    mazeSvg.append(pieceLayer);
    board.append(mazeSvg, keyboardLayer);

    updateFreePieces();
    window.requestAnimationFrame(updateMazeMetrics);
  }

  async function handlePieceTap(piece) {
    if (puzzleLocked || !piece.alive) return;
    if (!pieceIsFree(piece)) {
      playStatus.textContent = text("play.statusBlocked");
      piece.element.classList.remove("is-blocked");
      void piece.element.offsetWidth;
      piece.element.classList.add("is-blocked");
      window.setTimeout(() => piece.element?.classList.remove("is-blocked"), 380);
      return;
    }

    puzzleLocked = true;
    combo += 1;
    comboValue.textContent = `×${combo}`;
    playStatus.textContent = text("play.statusClear");
    if (hoveredPiece === piece) {
      hoveredPiece.element?.classList.remove("is-hovered");
      hoveredPiece = null;
    }
    const generation = mazeGeneration;
    let completed = false;
    try {
      completed = await animatePieceFlyOut(piece);
    } catch {
      completed = false;
    }
    if (generation !== mazeGeneration) return;
    if (!completed) {
      piece.isAnimating = false;
      piece.element.classList.remove("is-flying");
      piece.element.style.removeProperty("opacity");
      piece.buttonElement.disabled = false;
      const path = buildPiecePath(piece, currentChevronUnits);
      piece.lineElement.setAttribute("d", path);
      piece.focusElement.setAttribute("d", path);
      combo = Math.max(0, combo - 1);
      comboValue.textContent = `×${combo}`;
      playStatus.textContent = text("play.statusReady");
      puzzleLocked = false;
      return;
    }

    piece.alive = false;
    piece.isAnimating = false;
    piece.element.classList.add("is-cleared");
    piece.buttonElement.tabIndex = -1;
    piece.buttonElement.setAttribute("aria-hidden", "true");
    puzzleLocked = false;
    updateFreePieces();
    if (puzzlePieces.every((candidate) => !candidate.alive)) {
      playStatus.textContent = text("play.statusDone");
      board.classList.add("is-complete");
    }
  }

  board.addEventListener("click", (event) => {
    const piece = pieceAtPointer(event);
    if (piece) handlePieceTap(piece);
  });

  board.addEventListener("pointermove", (event) => {
    if (event.pointerType === "touch") return;
    const piece = pieceAtPointer(event);
    if (piece === hoveredPiece) return;
    hoveredPiece?.element?.classList.remove("is-hovered");
    hoveredPiece = piece;
    hoveredPiece?.element?.classList.add("is-hovered");
  });

  board.addEventListener("pointerleave", () => {
    hoveredPiece?.element?.classList.remove("is-hovered");
    hoveredPiece = null;
  });

  resetButton.addEventListener("click", resetPuzzle);
  if ("ResizeObserver" in window) {
    new ResizeObserver(updateMazeMetrics).observe(board);
  }

  const comparisonRange = document.querySelector("#comparisonRange");
  const photoResult = document.querySelector("#photoResult");
  const comparisonHandle = document.querySelector("#comparisonHandle");

  function updateComparison(value) {
    const position = Math.min(92, Math.max(8, Number(value)));
    photoResult.style.clipPath = `inset(0 ${100 - position}% 0 0)`;
    comparisonHandle.style.left = `${position}%`;
  }

  comparisonRange.addEventListener("input", () => updateComparison(comparisonRange.value));
  updateComparison(comparisonRange.value);

  const canvas = document.querySelector("#ambientMaze");
  const context = canvas.getContext("2d", { alpha: true });
  let mazePaths = [];
  let animationFrame = 0;
  let lastFrameTime = 0;
  let resizeTimer = 0;

  function makeMazePaths(width, height) {
    const spacing = width < 700 ? 58 : 76;
    const columns = Math.ceil(width / spacing) + 2;
    const rows = Math.ceil(height / spacing) + 2;
    const paths = [];
    let seed = 0x5a17;
    const random = () => {
      seed = (seed * 1664525 + 1013904223) >>> 0;
      return seed / 4294967296;
    };

    for (let index = 0; index < Math.min(28, Math.ceil((width * height) / 62000)); index += 1) {
      let column = Math.floor(random() * columns);
      let row = Math.floor(random() * rows);
      const points = [[column * spacing, row * spacing]];
      const length = 5 + Math.floor(random() * 8);
      let horizontal = random() > 0.5;
      for (let step = 0; step < length; step += 1) {
        const direction = random() > 0.5 ? 1 : -1;
        if (horizontal) column = Math.max(-1, Math.min(columns, column + direction));
        else row = Math.max(-1, Math.min(rows, row + direction));
        points.push([column * spacing, row * spacing]);
        horizontal = !horizontal;
      }
      paths.push({ points, speed: 0.25 + random() * 0.55, offset: random() * 360 });
    }
    return paths;
  }

  function resizeAmbientCanvas() {
    const pixelRatio = Math.min(window.devicePixelRatio || 1, 1.5);
    const width = window.innerWidth;
    const height = window.innerHeight;
    canvas.width = Math.round(width * pixelRatio);
    canvas.height = Math.round(height * pixelRatio);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
    mazePaths = makeMazePaths(width, height);
    drawAmbientMaze(performance.now(), true);
  }

  function drawAmbientMaze(time, staticOnly = false) {
    const width = window.innerWidth;
    const height = window.innerHeight;
    const styles = getComputedStyle(document.documentElement);
    const pathColour = styles.getPropertyValue("--path").trim();
    const accentColour = styles.getPropertyValue("--accent").trim();
    context.clearRect(0, 0, width, height);
    context.lineCap = "round";
    context.lineJoin = "round";

    mazePaths.forEach((path, index) => {
      context.beginPath();
      path.points.forEach(([x, y], pointIndex) => {
        if (pointIndex === 0) context.moveTo(x, y);
        else context.lineTo(x, y);
      });
      context.setLineDash([]);
      context.globalAlpha = 0.07;
      context.strokeStyle = pathColour;
      context.lineWidth = 2;
      context.stroke();

      if (!staticOnly) {
        context.beginPath();
        path.points.forEach(([x, y], pointIndex) => {
          if (pointIndex === 0) context.moveTo(x, y);
          else context.lineTo(x, y);
        });
        context.setLineDash([10, 310]);
        context.lineDashOffset = -((time * path.speed * 0.04) + path.offset + index * 23);
        context.globalAlpha = 0.18;
        context.strokeStyle = index % 3 === 0 ? accentColour : pathColour;
        context.lineWidth = 3;
        context.stroke();
      }
    });

    context.setLineDash([]);
    context.globalAlpha = 1;
  }

  function animateAmbientMaze(time) {
    if (time - lastFrameTime >= 42) {
      drawAmbientMaze(time, false);
      lastFrameTime = time;
    }
    animationFrame = window.requestAnimationFrame(animateAmbientMaze);
  }

  function updateAmbientAnimation() {
    window.cancelAnimationFrame(animationFrame);
    if (reduceMotion.matches || document.hidden) {
      drawAmbientMaze(performance.now(), true);
      return;
    }
    animationFrame = window.requestAnimationFrame(animateAmbientMaze);
  }

  window.addEventListener("resize", () => {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(() => {
      resizeAmbientCanvas();
      updateAmbientAnimation();
    }, 120);
  }, { passive: true });
  document.addEventListener("visibilitychange", updateAmbientAnimation);
  reduceMotion.addEventListener("change", updateAmbientAnimation);
  window.addEventListener("arrowmaze:themechange", () => drawAmbientMaze(performance.now(), reduceMotion.matches));

  applyTheme(detectTheme());
  resetPuzzle();
  applyLocale(detectLocale());
  resizeAmbientCanvas();
  updateAmbientAnimation();
})();
