//
//  LocalizationManager.swift
//  WWFChallenge7
//
//  Created by Antigravity on 17/05/26.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var preferredLanguage: String {
        didSet {
            UserDefaults.standard.set(preferredLanguage, forKey: "preferredLanguage")
        }
    }
    
    private var modelContainer: ModelContainer?
    
    private init() {
        self.preferredLanguage = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "it"
    }
    
    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    func setLanguage(_ languageCode: String) {
        let supported = ["it", "en", "de", "fr"]
        let normalized = supported.contains(languageCode) ? languageCode : "it"
        guard preferredLanguage != normalized else { return }
        preferredLanguage = normalized
    }
    
    /// System translations for UI elements. Super scalable and customizable!
    private let uiTranslations: [String: [String: String]] = [
        "app_title": [
            "it": "Oasi Astroni",
            "en": "Astroni Oasis",
            "de": "Oase Astroni",
            "fr": "Oasis Astroni"
        ],
        "welcome": [
            "it": "Benvenuto in Astroni",
            "en": "Welcome to Astroni",
            "de": "Willkommen in Astroni",
            "fr": "Bienvenue à Astroni"
        ],
        "select_trail": [
            "it": "Seleziona un percorso",
            "en": "Select a path",
            "de": "Wählen Sie einen Weg",
            "fr": "Sélectionnez un sentier"
        ],
        "description": [
            "it": "Descrizione",
            "en": "Description",
            "de": "Beschreibung",
            "fr": "Description"
        ],
        "audio_reading": [
            "it": "Lettura Vivavoce",
            "en": "Text-to-Speech",
            "de": "Sprachausgabe",
            "fr": "Lecture audio"
        ],
        "stop_audio": [
            "it": "Ferma audio",
            "en": "Stop audio",
            "de": "Audio stoppen",
            "fr": "Arrêter l'audio"
        ],
        "start_audio_accessibility_label": [
            "it": "Avvia lettura vivavoce",
            "en": "Start text-to-speech reading",
            "de": "Sprachausgabe starten",
            "fr": "Démarrer la lecture audio"
        ],
        "stop_audio_accessibility_label": [
            "it": "Ferma lettura vivavoce",
            "en": "Stop text-to-speech reading",
            "de": "Sprachausgabe stoppen",
            "fr": "Arrêter la lecture audio"
        ],
        "audio_reading_accessibility_hint": [
            "it": "Tocca due volte per avviare o fermare la lettura della descrizione.",
            "en": "Double tap to start or stop reading the description.",
            "de": "Doppeltippen, um das Vorlesen der Beschreibung zu starten oder zu stoppen.",
            "fr": "Touchez deux fois pour démarrer ou arrêter la lecture de la description."
        ],
        "open_ar": [
            "it": "Apri AR",
            "en": "Open AR",
            "de": "AR öffnen",
            "fr": "Ouvrir l'AR"
        ],
        "open_ar_accessibility_label": [
            "it": "Apri esperienza in realtà aumentata",
            "en": "Open augmented reality experience",
            "de": "Augmented-Reality-Erlebnis öffnen",
            "fr": "Ouvrir l'expérience en réalité augmentée"
        ],
        "open_ar_accessibility_hint": [
            "it": "Apre la fotocamera e permette di posizionare il modello 3D nell'ambiente.",
            "en": "Opens the camera and lets you place the 3D model in the environment.",
            "de": "Öffnet die Kamera und ermöglicht das Platzieren des 3D-Modells in der Umgebung.",
            "fr": "Ouvre la caméra et permet de placer le modèle 3D dans l'environnement."
        ],
        "open_gallery_accessibility_hint": [
            "it": "Tocca due volte per aprire la galleria a schermo intero.",
            "en": "Double tap to open the full-screen gallery.",
            "de": "Doppeltippen, um die Galerie im Vollbild zu öffnen.",
            "fr": "Touchez deux fois pour ouvrir la galerie en plein écran."
        ],
        "media_thumbnail_accessibility_hint": [
            "it": "Tocca due volte per aprire questo contenuto.",
            "en": "Double tap to open this content.",
            "de": "Doppeltippen, um diesen Inhalt zu öffnen.",
            "fr": "Touchez deux fois pour ouvrir ce contenu."
        ],
        "continue_trail_accessibility_hint": [
            "it": "Chiude questa scheda e continua il percorso.",
            "en": "Closes this card and continues the trail.",
            "de": "Schließt diese Karte und setzt den Weg fort.",
            "fr": "Ferme cette fiche et continue le sentier."
        ],
        "close_modal_accessibility_hint": [
            "it": "Chiude la scheda del punto di interesse.",
            "en": "Closes the point of interest card.",
            "de": "Schließt die Karte des interessanten Ortes.",
            "fr": "Ferme la fiche du point d'intérêt."
        ],
        "close_gallery_accessibility_hint": [
            "it": "Chiude la galleria e torna alla scheda.",
            "en": "Closes the gallery and returns to the card.",
            "de": "Schließt die Galerie und kehrt zur Karte zurück.",
            "fr": "Ferme la galerie et revient à la fiche."
        ],
        "content_type_text": [
            "it": "Testo",
            "en": "Text",
            "de": "Text",
            "fr": "Texte"
        ],
        "content_type_image": [
            "it": "Immagine",
            "en": "Image",
            "de": "Bild",
            "fr": "Image"
        ],
        "content_type_video": [
            "it": "Video",
            "en": "Video",
            "de": "Video",
            "fr": "Vidéo"
        ],
        "content_type_model_3d": [
            "it": "Modello 3D",
            "en": "3D Model",
            "de": "3D-Modell",
            "fr": "Modèle 3D"
        ],
        "content_type_audio": [
            "it": "Audio",
            "en": "Audio",
            "de": "Audio",
            "fr": "Audio"
        ],
        "content_type_transcript": [
            "it": "Trascrizione",
            "en": "Transcript",
            "de": "Transkript",
            "fr": "Transcription"
        ],
        "close": [
            "it": "Chiudi",
            "en": "Close",
            "de": "Schließen",
            "fr": "Fermer"
        ],
        "exit_trail": [
            "it": "Esci",
            "en": "Exit",
            "de": "Beenden",
            "fr": "Quitter"
        ],
        "exit_trail_title": [
            "it": "Uscire dal percorso?",
            "en": "Exit the trail?",
            "de": "Weg beenden?",
            "fr": "Quitter le sentier ?"
        ],
        "exit_trail_message": [
            "it": "Se esci adesso, questa esperienza ripartirà da zero la prossima volta. Se chiudi l'app senza uscire, invece, potrai riprendere da dove eri arrivato.",
            "en": "If you exit now, this experience will restart from the beginning next time. If you close the app without exiting, you can resume where you left off.",
            "de": "Wenn du jetzt beendest, startet dieses Erlebnis beim nächsten Mal von vorn. Wenn du die App nur schließt, kannst du dort weitermachen, wo du aufgehört hast.",
            "fr": "Si vous quittez maintenant, cette expérience recommencera depuis le début la prochaine fois. Si vous fermez simplement l'app, vous pourrez reprendre où vous en étiez."
        ],
        "exit_and_reset": [
            "it": "Esci e azzera",
            "en": "Exit and reset",
            "de": "Beenden und zurücksetzen",
            "fr": "Quitter et réinitialiser"
        ],
        "exit_trail_accessibility_hint": [
            "it": "Mostra una conferma prima di uscire e azzerare i progressi locali di questa esperienza.",
            "en": "Shows a confirmation before exiting and resetting local progress for this experience.",
            "de": "Zeigt eine Bestätigung, bevor der lokale Fortschritt dieses Erlebnisses zurückgesetzt wird.",
            "fr": "Affiche une confirmation avant de quitter et de réinitialiser la progression locale de cette expérience."
        ],
        "change_map_type": [
            "it": "Cambia tipo di mappa",
            "en": "Change map type",
            "de": "Kartentyp ändern",
            "fr": "Changer le type de carte"
        ],
        "change_map_type_hint": [
            "it": "Permette di scegliere tra mappa 2D e mappe 3D.",
            "en": "Lets you choose between the 2D map and 3D maps.",
            "de": "Ermöglicht die Auswahl zwischen 2D-Karte und 3D-Karten.",
            "fr": "Permet de choisir entre la carte 2D et les cartes 3D."
        ],
        "restart_trail": [
            "it": "Ricomincia il percorso",
            "en": "Restart trail",
            "de": "Weg neu starten",
            "fr": "Recommencer le sentier"
        ],
        "settings": [
            "it": "Impostazioni",
            "en": "Settings",
            "de": "Einstellungen",
            "fr": "Paramètres"
        ],
        "language": [
            "it": "Lingua",
            "en": "Language",
            "de": "Sprache",
            "fr": "Langue"
        ],
        "download": [
            "it": "Scarica",
            "en": "Download",
            "de": "Herunterladen",
            "fr": "Télécharger"
        ],
        "downloaded": [
            "it": "Scaricato",
            "en": "Downloaded",
            "de": "Heruntergeladen",
            "fr": "Téléchargé"
        ],
        "no_connection": [
            "it": "Nessuna connessione offline",
            "en": "No connection offline",
            "de": "Offline ohne Verbindung",
            "fr": "Pas de connexion hors ligne"
        ],
        "simplified_mode": [
            "it": "Modalità Semplificata",
            "en": "Simplified Mode",
            "de": "Vereinfachter Modus",
            "fr": "Mode Simplifié"
        ],
        "accessibility": [
            "it": "Accessibilità",
            "en": "Accessibility",
            "de": "Barrierefreiheit",
            "fr": "Accessibilité"
        ],
        "map_2d": [
            "it": "Mappa 2D",
            "en": "2D Map",
            "de": "2D-Karte",
            "fr": "Carte 2D"
        ],
        "map_3d": [
            "it": "Mappa 3D",
            "en": "3D Map",
            "de": "3D-Karte",
            "fr": "Carte 3D"
        ],
        "continue_trail": [
            "it": "Continua il sentiero",
            "en": "Continue trail",
            "de": "Weg fortsetzen",
            "fr": "Continuer le sentier"
        ],
        "extra_content": [
            "it": "Contenuti Extra",
            "en": "Extra Content",
            "de": "Zusätzliche Inhalte",
            "fr": "Contenu supplémentaire"
        ],
        "main_photo": [
            "it": "Foto Principale",
            "en": "Main Photo",
            "de": "Hauptfoto",
            "fr": "Photo principale"
        ],
        "not_available_offline": [
            "it": "Contenuto non disponibile offline",
            "en": "Content not available offline",
            "de": "Inhalt offline nicht verfügbar",
            "fr": "Contenu non disponible hors ligne"
        ],
        "active_trails": [
            "it": "Percorsi Attivi",
            "en": "Active Trails",
            "de": "Aktive Wege",
            "fr": "Sentiers Actifs"
        ],
        "explore": [
            "it": "Esplora",
            "en": "Explore",
            "de": "Erkunden",
            "fr": "Explorer"
        ],
        "events": [
            "it": "Eventi",
            "en": "Events",
            "de": "Events",
            "fr": "Événements"
        ],
        "profile": [
            "it": "Profilo",
            "en": "Profile",
            "de": "Profil",
            "fr": "Profil"
        ],
        "notifications": [
            "it": "Notifiche",
            "en": "Notifications",
            "de": "Benachrichtigungen",
            "fr": "Notifications"
        ],
        "no_active_trails": [
            "it": "Nessun percorso attivo",
            "en": "No Active Trails",
            "de": "Keine aktiven Wege",
            "fr": "Aucun sentier actif"
        ],
        "no_active_trails_desc": [
            "it": "I gestori dell'Oasi non hanno ancora pubblicato percorsi.",
            "en": "The Oasis managers have not published any trails yet.",
            "de": "Die Oasen-Manager haben noch keine Wege veröffentlicht.",
            "fr": "Les gestionnaires de l'Oasis n'ont pas encore publié de sentiers."
        ],
        "free_entrance": [
            "it": "Ingresso libero",
            "en": "Free Entrance",
            "de": "Freier Eintritt",
            "fr": "Entrée libre"
        ],
        "offline_ready": [
            "it": "Pronto Offline",
            "en": "Offline Ready",
            "de": "Offline bereit",
            "fr": "Prêt hors ligne"
        ],
        "qr_required": [
            "it": "QR Richiesti",
            "en": "QR Required",
            "de": "QR erforderlich",
            "fr": "QR requis"
        ],
        "difficulty_easy": [
            "it": "Facile",
            "en": "Easy",
            "de": "Einfach",
            "fr": "Facile"
        ],
        "difficulty_medium": [
            "it": "Medio",
            "en": "Medium",
            "de": "Mittel",
            "fr": "Moyen"
        ],
        "difficulty_hard": [
            "it": "Difficile",
            "en": "Hard",
            "de": "Schwer",
            "fr": "Difficile"
        ],
        "steps_label": [
            "it": "tappe",
            "en": "steps",
            "de": "Etappen",
            "fr": "étapes"
        ],
        "minutes_word": [
            "it": "minuti",
            "en": "minutes",
            "de": "Minuten",
            "fr": "minutes"
        ],
        "open_details_hint": [
            "it": "Tocca due volte per aprire i dettagli",
            "en": "Double-tap to open details",
            "de": "Doppeltippen, um Details zu öffnen",
            "fr": "Touchez deux fois pour ouvrir les détails"
        ],
        "open_trail_details_hint": [
            "it": "Tocca due volte per aprire i dettagli del percorso",
            "en": "Double-tap to open the trail details",
            "de": "Doppeltippen, um die Wegdetails zu öffnen",
            "fr": "Touchez deux fois pour ouvrir les détails du sentier"
        ],
        "trail_steps": [
            "it": "Tappe del percorso",
            "en": "Trail Steps",
            "de": "Weg-Etappen",
            "fr": "Étapes du sentier"
        ],
        "offline_mode": [
            "it": "Modalità Offline",
            "en": "Offline Mode",
            "de": "Offline-Modus",
            "fr": "Mode hors ligne"
        ],
        "offline_navigation_desc": [
            "it": "La navigazione funziona senza internet. Scansiona i codici QR lungo il percorso per aggiornare la tua posizione.",
            "en": "Navigation works without internet. Scan the QR codes along the trail to update your position.",
            "de": "Die Navigation funktioniert ohne Internet. Scannen Sie die QR-Codes entlang des Weges, um Ihre Position zu aktualisieren.",
            "fr": "La navigation fonctionne sans internet. Scannez les codes QR le long du sentier pour mettre à jour votre position."
        ],
        "continue_offline": [
            "it": "Continua Offline",
            "en": "Continue Offline",
            "de": "Offline fortfahren",
            "fr": "Continuer hors ligne"
        ],
        "manage_packages": [
            "it": "Gestisci o Aggiorna Pacchetti",
            "en": "Manage or Update Packages",
            "de": "Pakete verwalten oder aktualisieren",
            "fr": "Gérer ou mettre à jour les packages"
        ],
        "download_and_start": [
            "it": "Scarica e Inizia",
            "en": "Download and Start",
            "de": "Herunterladen und starten",
            "fr": "Télécharger et démarrer"
        ],
        "start_point_fallback": [
            "it": "Punto di Partenza",
            "en": "Start Point",
            "de": "Startpunkt",
            "fr": "Point de départ"
        ],
        "start_point_fallback_desc": [
            "it": "Inizia qui il tuo percorso.",
            "en": "Start your trail here.",
            "de": "Beginnen Sie Ihren Weg hier.",
            "fr": "Commencez votre sentier ici."
        ],
        "today_oasis": [
            "it": "Oggi all'Oasi",
            "en": "Today at the Oasis",
            "de": "Heute in der Oase",
            "fr": "Aujourd'hui à l'Oasis"
        ],
        "upcoming_events": [
            "it": "Prossimi Eventi",
            "en": "Upcoming Events",
            "de": "Kommende Veranstaltungen",
            "fr": "Événements à venir"
        ],
        "no_events_scheduled": [
            "it": "Nessun evento in programma",
            "en": "No events scheduled",
            "de": "Keine Termine geplant",
            "fr": "Aucun événement prévu"
        ],
        "no_events_scheduled_desc": [
            "it": "Torna presto a controllare per scoprire nuove attività.",
            "en": "Check back soon to discover new activities.",
            "de": "Schauen Sie bald wieder vorbei, um neue Aktivitäten zu entdecken.",
            "fr": "Revenez bientôt pour découvrir de nouvelles activités."
        ],
        "no_other_events": [
            "it": "Nessun altro evento in programma per ora.",
            "en": "No other events scheduled for now.",
            "de": "Derzeit sind keine weiteren Termine geplant.",
            "fr": "Aucun autre événement prévu pour le moment."
        ],
        "events_activities": [
            "it": "Eventi e Attività",
            "en": "Events & Activities",
            "de": "Veranstaltungen & Aktivitäten",
            "fr": "Événements et activités"
        ],
        "events_oasis_desc": [
            "it": "Esplora le esperienze organizzate nell'Oasi degli Astroni",
            "en": "Explore the experiences organized in the Astroni Oasis",
            "de": "Entdecken Sie die Erlebnisse in der Astroni-Oase",
            "fr": "Explorez les expériences organisées dans l'Oasis des Astroni"
        ],
        "today_upper": [
            "it": "OGGI",
            "en": "TODAY",
            "de": "HEUTE",
            "fr": "AUJOURD'HUI"
        ],
        "free_price": [
            "it": "Gratis",
            "en": "Free",
            "de": "Kostenlos",
            "fr": "Gratuit"
        ],
        "associated_trail": [
            "it": "Percorso",
            "en": "Trail",
            "de": "Weg",
            "fr": "Sentier"
        ],
        "event_cat_educational": [
            "it": "Didattico",
            "en": "Educational",
            "de": "Bildung",
            "fr": "Éducatif"
        ],
        "event_cat_guided_tour": [
            "it": "Visita Guidata",
            "en": "Guided Tour",
            "de": "Geführte Tour",
            "fr": "Visite guidée"
        ],
        "event_cat_workshop": [
            "it": "Laboratorio",
            "en": "Workshop",
            "de": "Workshop",
            "fr": "Atelier"
        ],
        "event_cat_family": [
            "it": "Famiglie",
            "en": "Families",
            "de": "Familien",
            "fr": "Familles"
        ],
        "event_cat_photography": [
            "it": "Fotografia",
            "en": "Photography",
            "de": "Fotografie",
            "fr": "Photographie"
        ],
        "event_cat_scientific": [
            "it": "Scientifico",
            "en": "Scientific",
            "de": "Wissenschaftlich",
            "fr": "Scientifique"
        ],
        "event_cat_other": [
            "it": "Altro",
            "en": "Other",
            "de": "Andere",
            "fr": "Autre"
        ],
        "max_label": [
            "it": "Max",
            "en": "Max",
            "de": "Max.",
            "fr": "Max"
        ],
        "organization": [
            "it": "Organizzazione",
            "en": "Organization",
            "de": "Organisation",
            "fr": "Organisation"
        ],
        "what_to_bring": [
            "it": "Cosa portare",
            "en": "What to bring",
            "de": "Mitzubringen",
            "fr": "Quoi apporter"
        ],
        "how_to_reach_us": [
            "it": "Come raggiungerci",
            "en": "How to reach us",
            "de": "Wie Sie uns erreichen",
            "fr": "Comment nous rejoindre"
        ],
        "offline_trail_desc": [
            "it": "Non c'è connessione internet durante il percorso. Segui la mappa e scansiona i codici QR.",
            "en": "There is no internet during the trail. Follow the trail and scan the QR codes.",
            "de": "Während des Weges gibt es kein Internet. Folgen Sie dem Weg und scannen Sie die QR-Codes.",
            "fr": "Il n'y a pas d'internet pendant le sentier. Suivez le sentier et scannez les codes QR."
        ],
        "start_trail_event": [
            "it": "Inizia il percorso dell'evento",
            "en": "Start Trail of the Event",
            "de": "Weg der Veranstaltung starten",
            "fr": "Démarrer le sentier de l'événement"
        ],
        "place_label": [
            "it": "Luogo",
            "en": "Place",
            "de": "Ort",
            "fr": "Lieu"
        ],
        "reach_marked_point": [
            "it": "Raggiungi il punto contrassegnato sulla mappa.",
            "en": "Reach the marked point on the map.",
            "de": "Erreichen Sie den markierten Punkt auf der Karte.",
            "fr": "Rejoignez le point marqué sur la carte."
        ],
        "audience_all": [
            "it": "Tutti",
            "en": "All",
            "de": "Alle",
            "fr": "Tous"
        ],
        "audience_adults": [
            "it": "Adulti",
            "en": "Adults",
            "de": "Erwachsene",
            "fr": "Adultes"
        ],
        "audience_children": [
            "it": "Bambini",
            "en": "Children",
            "de": "Kinder",
            "fr": "Enfants"
        ],
        "audience_families": [
            "it": "Famiglie",
            "en": "Families",
            "de": "Familien",
            "fr": "Familles"
        ],
        "audience_schools": [
            "it": "Scuole",
            "en": "Schools",
            "de": "Schulen",
            "fr": "Écoles"
        ],
        "audience_researchers": [
            "it": "Ricercatori",
            "en": "Researchers",
            "de": "Forscher",
            "fr": "Chercheurs"
        ],
        "prepare_trail": [
            "it": "Preparati al Percorso",
            "en": "Prepare for the Trail",
            "de": "Bereiten Sie sich auf den Weg vor",
            "fr": "Préparez-vous pour le sentier"
        ],
        "scan_qr_prompt": [
            "it": "Inquadra il codice QR",
            "en": "Scan the QR code",
            "de": "QR-Code scannen",
            "fr": "Scannez le code QR"
        ],
        "position_updated_on_map": [
            "it": "Posizione aggiornata sulla mappa",
            "en": "Position updated on the map",
            "de": "Position auf der Karte aktualisiert",
            "fr": "Position mise à jour sur la carte"
        ],
        "of_word": [
            "it": "di",
            "en": "of",
            "de": "von",
            "fr": "de"
        ],
        "part_of_undownloaded_package": [
            "it": "Questo contenuto fa parte di un pacchetto non ancora scaricato.",
            "en": "This content is part of a package that has not been downloaded yet.",
            "de": "Dieser Inhalt ist Teil eines Pakets, das noch nicht heruntergeladen wurde.",
            "fr": "Ce contenu fait partie d'un package qui n'a pas encore été téléchargé."
        ],
        "unable_to_load_local_file": [
            "it": "Impossibile caricare il file locale",
            "en": "Unable to load local file",
            "de": "Lokale Datei konnte nicht geladen werden",
            "fr": "Impossible de charger le fichier local"
        ],
        "offline_audio_player": [
            "it": "Riproduttore Audio Offline",
            "en": "Offline Audio Player",
            "de": "Offline-Audioplayer",
            "fr": "Lecteur audio hors ligne"
        ],
        "download_offline_desc": [
            "it": "Scarica i contenuti per l'uso offline nell'Oasi.",
            "en": "Download content for offline use in the Oasis.",
            "de": "Laden Sie Inhalte für die Offline-Nutzung in der Oase herunter.",
            "fr": "Téléchargez le contenu pour une utilisation hors ligne dans l'Oasis."
        ],
        "content_language": [
            "it": "Lingua dei contenuti",
            "en": "Content Language",
            "de": "Inhaltssprache",
            "fr": "Langue du contenu"
        ],
        "choose_how_much_download": [
            "it": "Scegli quanto scaricare",
            "en": "Choose what to download",
            "de": "Wählen Sie aus, was Sie herunterladen möchten",
            "fr": "Choisissez quoi télécharger"
        ],
        "downloading_progress": [
            "it": "Download in corso...",
            "en": "Downloading...",
            "de": "Herunterladen...",
            "fr": "Téléchargement..."
        ],
        "use_this_version": [
            "it": "Usa questa versione",
            "en": "Use this version",
            "de": "Diese Version verwenden",
            "fr": "Utiliser cette version"
        ],
        "update_downloaded_bundle": [
            "it": "Aggiorna pacchetto",
            "en": "Update package",
            "de": "Paket aktualisieren",
            "fr": "Mettre à jour le package"
        ],
        "update_available_chip": [
            "it": "Aggiornamento",
            "en": "Update",
            "de": "Update",
            "fr": "Mise à jour"
        ],
        "cancel": [
            "it": "Annulla",
            "en": "Cancel",
            "de": "Abbrechen",
            "fr": "Annuler"
        ],
        "downloaded_chip": [
            "it": "Scaricato",
            "en": "Downloaded",
            "de": "Heruntergeladen",
            "fr": "Téléchargé"
        ],
        "tier_light": [
            "it": "Essenziale",
            "en": "Essential",
            "de": "Essentiell",
            "fr": "Essentiel"
        ],
        "tier_standard": [
            "it": "Standard",
            "en": "Standard",
            "de": "Standard",
            "fr": "Standard"
        ],
        "tier_full": [
            "it": "Completo",
            "en": "Complete",
            "de": "Vollständig",
            "fr": "Complet"
        ],
        "tier_light_desc": [
            "it": "Solo testi, immagini essenziali e audio sintesi vocale.",
            "en": "Texts, essential images, and text-to-speech audio only.",
            "de": "Nur Texte, essentielle Bilder und Text-to-Speech-Audio.",
            "fr": "Textes, images essentielles et synthèse vocale uniquement."
        ],
        "tier_standard_desc": [
            "it": "Tutto l'essenziale più video e immagini in alta qualità.",
            "en": "Everything in essential plus high-quality videos and images.",
            "de": "Alles Wichtige plus hochwertige Videos und Bilder.",
            "fr": "Tout l'essentiel plus vidéos et images de haute qualité."
        ],
        "tier_full_desc": [
            "it": "Esperienza completa con modelli 3D ed esperienze AR.",
            "en": "Complete experience with 3D models and AR experiences.",
            "de": "Komplettes Erlebnis mit 3D-Modellen und AR-Erlebnissen.",
            "fr": "Expérience complète avec modèles 3D et expériences AR."
        ],
        "large_text": [
            "it": "Testo Grande",
            "en": "Large Text",
            "de": "Großer Text",
            "fr": "Grand Texte"
        ],
        "oasis_updates": [
            "it": "Aggiornamenti Oasi",
            "en": "Oasis Updates",
            "de": "Oase-Updates",
            "fr": "Mises à jour de l'Oasis"
        ],
        "info": [
            "it": "Informazioni",
            "en": "Information",
            "de": "Informationen",
            "fr": "Informations"
        ],
        "version": [
            "it": "Versione",
            "en": "Version",
            "de": "Version",
            "fr": "Version"
        ],
        "oasis_val": [
            "it": "Astroni · Napoli",
            "en": "Astroni · Naples",
            "de": "Astroni · Neapel",
            "fr": "Astroni · Naples"
        ],
        "wwf_website": [
            "it": "Sito WWF Italia",
            "en": "WWF Italy Website",
            "de": "WWF Italien Website",
            "fr": "Site Web de WWF Italie"
        ],
        "go_to": [
            "it": "Vai a",
            "en": "Go to",
            "de": "Gehe zu",
            "fr": "Aller à"
        ],
        "reached": [
            "it": "Raggiunto",
            "en": "Reached",
            "de": "Erreicht",
            "fr": "Atteint"
        ],
        "start_trail": [
            "it": "Inizia il percorso",
            "en": "Start the trail",
            "de": "Weg starten",
            "fr": "Démarrer le sentier"
        ],
        "scan_qr": [
            "it": "Inquadra il codice QR",
            "en": "Scan The QR Code",
            "de": "QR-Code scannen",
            "fr": "Scanner le code QR"
        ],
        "scan_qr_desc": [
            "it": "Scansiona il codice QR all'arrivo",
            "en": "Scan the QR code when you arrive",
            "de": "QR-Code bei der Ankunft scannen",
            "fr": "Scannez le code QR à l'arrivée"
        ],
        "view_info": [
            "it": "Visualizza il pannello informativo",
            "en": "View the information panel",
            "de": "Infotafel anzeigen",
            "fr": "Afficher le panneau d'information"
        ],
        "back_to_home": [
            "it": "Torna alla Home",
            "en": "Back to Home",
            "de": "Zurück zur Startseite",
            "fr": "Retour à l'accueil"
        ],
        "qr_error": [
            "it": "Errore QR",
            "en": "QR Error",
            "de": "QR-Fehler",
            "fr": "Erreur QR"
        ],
        "ok_button": [
            "it": "OK",
            "en": "OK",
            "de": "OK",
            "fr": "OK"
        ],
        "flat_2d_map": [
            "it": "Mappa 2D",
            "en": "Flat 2D Map",
            "de": "Flache 2D-Karte",
            "fr": "Carte 2D Plate"
        ],
        "map_type_basic": [
            "it": "Modello 3D Base",
            "en": "Basic 3D Model",
            "de": "Einfaches 3D-Modell",
            "fr": "Modèle 3D de Base"
        ],
        "map_type_realistic": [
            "it": "Mappa 3D Astroni",
            "en": "Astroni 3D Map",
            "de": "Astroni 3D-Karte",
            "fr": "Carte 3D Astroni"
        ],
        "trail_not_active": [
            "it": "Questo percorso non è attivo.",
            "en": "This trail is not active.",
            "de": "Dieser Weg ist nicht aktiv.",
            "fr": "Ce sentier n'est pas actif."
        ],
        "qr_not_related": [
            "it": "Questo codice QR non appartiene al percorso attivo.",
            "en": "This QR code is not related to the active trail.",
            "de": "Dieser QR-Code gehört nicht zum aktiven Weg.",
            "fr": "Ce code QR n'est pas lié au sentier actif."
        ],
        "scanned": [
            "it": "Scansionato",
            "en": "Scanned",
            "de": "Gescannter",
            "fr": "Scanné"
        ],
        "expected_one_of": [
            "it": "Previsto uno dei seguenti",
            "en": "Expected one of",
            "de": "Erwartet eines von",
            "fr": "Attendu l'un des suivants"
        ],
        "no_pois_in_trail": [
            "it": "(Nessun POI nel percorso)",
            "en": "(No POIs in trail)",
            "de": "(Keine POIs im Weg)",
            "fr": "(Aucun POI sur le sentier)"
        ],
        "poi_already_visited": [
            "it": "Hai già visitato questo punto. Procedi al prossimo.",
            "en": "You already visited this point. Proceed to the next POI.",
            "de": "Sie haben diesen Punkt bereits besucht. Fahren Sie mit dem nächsten POI fort.",
            "fr": "Vous avez déjà visité ce point. Passez au POI suivant."
        ],
        "you_are_here": [
            "it": "Tu sei qui",
            "en": "You are here",
            "de": "Sie sind hier",
            "fr": "Vous êtes ici"
        ],
        "trail_completed": [
            "it": "Percorso Completato!",
            "en": "Trail Completed!",
            "de": "Weg beendet!",
            "fr": "Sentier Terminé!"
        ],
        "great_job": [
            "it": "Ottimo lavoro nel completare il percorso.",
            "en": "Great job navigating the trail.",
            "de": "Gute Arbeit beim Navigieren des Weges.",
            "fr": "Excellent travail pour parcourir le sentier."
        ],
        "oasi_hours": [
            "it": "Oasi aperta · 9:00 – 17:00",
            "en": "Oasis open · 9:00 AM – 5:00 PM",
            "de": "Oase geöffnet · 9:00 – 17:00 Uhr",
            "fr": "Oasis ouverte · 9h00 – 17h00"
        ],
        "local_map": [
            "it": "Mappa locale",
            "en": "Local Map",
            "de": "Lokale Karte",
            "fr": "Carte locale"
        ],
        "oasi_subtitle": [
            "it": "Riserva Naturale Vulcanica · Agnano, Napoli",
            "en": "Volcanic Nature Reserve · Agnano, Naples",
            "de": "Vulkanisches Naturschutzgebiet · Agnano, Neapel",
            "fr": "Réserve Naturelle Volcanique · Agnano, Naples"
        ],
        "danger_label": [
            "it": "Pericolo",
            "en": "Danger",
            "de": "Gefahr",
            "fr": "Danger"
        ],
        "warning_label": [
            "it": "Avviso",
            "en": "Warning",
            "de": "Warnung",
            "fr": "Avertissement"
        ],
        "enter_poi_code": [
            "it": "Inserisci il codice del punto di interesse",
            "en": "Enter the point of interest code",
            "de": "Geben Sie den Code für den Ort von Interesse ein",
            "fr": "Saisissez le code du point d'intérêt"
        ],
        "poi_code_hint": [
            "it": "Il codice a 6 cifre è visibile sotto il QR code del POI",
            "en": "The 6-digit code is visible under the POI's QR code",
            "de": "Der 6-stellige Code befindet sich unter dem QR-Code des POI",
            "fr": "Le code à 6 chiffres est visible sous le code QR du POI"
        ],
        "confirm_button": [
            "it": "Conferma",
            "en": "Confirm",
            "de": "Bestätigen",
            "fr": "Confirmer"
        ],
        "manual_code_entry": [
            "it": "Codice manuale",
            "en": "Manual code",
            "de": "Manueller Code",
            "fr": "Code manuel"
        ],
        "manual_code_title": [
            "it": "Codice Manuale",
            "en": "Manual Code",
            "de": "Manueller Code",
            "fr": "Code manuel"
        ],
        "six_digit_code": [
            "it": "Codice a 6 cifre",
            "en": "6-digit code",
            "de": "6-stelliger Code",
            "fr": "Code à 6 chiffres"
        ],
        "poi_numeric_code": [
            "it": "Codice numerico POI",
            "en": "POI numeric code",
            "de": "Numerischer POI-Code",
            "fr": "Code numérique du POI"
        ],
        "poi_code_accessibility_hint": [
            "it": "Inserisci il codice a 6 cifre presente sotto il QR code",
            "en": "Enter the 6-digit code shown below the QR code",
            "de": "Geben Sie den 6-stelligen Code unter dem QR-Code ein",
            "fr": "Saisissez le code à 6 chiffres sous le code QR"
        ],
        "code_confirmation_accessibility": [
            "it": "Conferma codice",
            "en": "Confirm code",
            "de": "Code bestätigen",
            "fr": "Confirmer le code"
        ],
        "code_confirmation_hint": [
            "it": "Cerca il punto di interesse con il codice inserito",
            "en": "Find the point of interest with the entered code",
            "de": "Sucht den Ort von Interesse mit dem eingegebenen Code",
            "fr": "Recherche le point d'intérêt avec le code saisi"
        ],
        "close_code_entry": [
            "it": "Chiudi inserimento codice",
            "en": "Close code entry",
            "de": "Codeeingabe schließen",
            "fr": "Fermer la saisie du code"
        ],
        "error_prefix": [
            "it": "Errore",
            "en": "Error",
            "de": "Fehler",
            "fr": "Erreur"
        ],
        "poi_found_announcement": [
            "it": "POI trovato",
            "en": "POI found",
            "de": "POI gefunden",
            "fr": "POI trouvé"
        ],
        "invalid_code_for_trail": [
            "it": "Codice non valido per questo percorso",
            "en": "Code not valid for this trail",
            "de": "Code für diesen Weg ungültig",
            "fr": "Code non valide pour ce sentier"
        ],
        "lookup_error": [
            "it": "Errore nella ricerca",
            "en": "Lookup error",
            "de": "Fehler bei der Suche",
            "fr": "Erreur de recherche"
        ],
        "xp_label": [
            "it": "XP",
            "en": "XP",
            "de": "XP",
            "fr": "XP"
        ],
        "save_progress_desc": [
            "it": "Salva i tuoi progressi e porta con te la tua collezione",
            "en": "Save your progress and take your collection with you",
            "de": "Speichern Sie Ihren Fortschritt und nehmen Sie Ihre Sammlung mit",
            "fr": "Enregistrez vos progrès et emportez votre collection avec vous"
        ],
        "next_button": [
            "it": "Prossimo",
            "en": "Next",
            "de": "Weiter",
            "fr": "Suivant"
        ],
        "text_and_reading": [
            "it": "Testo e Lettura",
            "en": "Text and Reading",
            "de": "Text und Lesen",
            "fr": "Texte et Lecture"
        ],
        "easy_read_label": [
            "it": "Testo semplificato (Easy-to-Read)",
            "en": "Simplified text (Easy-to-Read)",
            "de": "Vereinfachter Text (Easy-to-Read)",
            "fr": "Texte simplifié (Easy-to-Read)"
        ],
        "easy_read_accessibility_label": [
            "it": "Testo semplificato Easy-to-Read",
            "en": "Easy-to-Read simplified text",
            "de": "Vereinfachter Easy-to-Read-Text",
            "fr": "Texte simplifié Easy-to-Read"
        ],
        "easy_read_accessibility_hint": [
            "it": "Mostra versioni semplificate dei contenuti dei punti di interesse, con frasi brevi e vocabolario semplice",
            "en": "Shows simplified point of interest content with short sentences and simple vocabulary",
            "de": "Zeigt vereinfachte Inhalte der Orte von Interesse mit kurzen Sätzen und einfachem Wortschatz",
            "fr": "Affiche des contenus simplifiés des points d'intérêt avec des phrases courtes et un vocabulaire simple"
        ],
        "kids_mode_label": [
            "it": "Modalità bambini",
            "en": "Kids mode",
            "de": "Kindermodus",
            "fr": "Mode enfants"
        ],
        "kids_mode_accessibility_hint": [
            "it": "Mostra solo percorsi adatti ai bambini con icone grandi e linguaggio semplice",
            "en": "Shows only child-friendly trails with large icons and simple language",
            "de": "Zeigt nur kinderfreundliche Wege mit großen Symbolen und einfacher Sprache",
            "fr": "Affiche uniquement les sentiers adaptés aux enfants avec de grandes icônes et un langage simple"
        ],
        "simplified_text_desc": [
            "it": "Il testo semplificato segue le linee guida Easy-to-Read europee per rendere i contenuti accessibili a tutti.",
            "en": "Simplified text follows European Easy-to-Read guidelines to make content accessible to everyone.",
            "de": "Der vereinfachte Text folgt den europäischen Easy-to-Read-Richtlinien, um Inhalte für alle zugänglich zu machen.",
            "fr": "Le texte simplifié suit les directives européennes Easy-to-Read pour rendre le contenu accessible à tous."
        ],
        "navigation_label": [
            "it": "Navigazione",
            "en": "Navigation",
            "de": "Navigation",
            "fr": "Navigation"
        ],
        "list_view_desc": [
            "it": "La vista lista è consigliata per utenti con lettore di schermo. Si attiva automaticamente quando VoiceOver è attivo.",
            "en": "The list view is recommended for screen reader users. It activates automatically when VoiceOver is on.",
            "de": "Die Listenansicht wird für Screenreader-Benutzer empfohlen. Sie wird automatisch aktiviert, wenn VoiceOver aktiviert ist.",
            "fr": "La vue en liste est recommandée pour les utilisateurs de lecteurs d'écran. Elle s'active automatiquement lorsque VoiceOver est activé."
        ],
        "default_list_view": [
            "it": "Vista lista come predefinita",
            "en": "Use list view by default",
            "de": "Listenansicht als Standard",
            "fr": "Vue en liste par défaut"
        ],
        "default_list_view_hint": [
            "it": "Mostra il percorso come lista di istruzioni testuali invece della mappa visiva",
            "en": "Shows the trail as a list of text instructions instead of the visual map",
            "de": "Zeigt den Weg als Liste von Textanweisungen statt als visuelle Karte",
            "fr": "Affiche le sentier sous forme de liste d'instructions au lieu de la carte visuelle"
        ],
        "audio_feedback": [
            "it": "Audio e Feedback",
            "en": "Audio and Feedback",
            "de": "Audio und Feedback",
            "fr": "Audio et retours"
        ],
        "auto_audio_qr": [
            "it": "Audio automatico al QR",
            "en": "Automatic audio on QR",
            "de": "Automatisches Audio bei QR",
            "fr": "Audio automatique au QR"
        ],
        "auto_audio_qr_hint": [
            "it": "Quando scansioni un QR code, avvia automaticamente la descrizione audio del punto di interesse",
            "en": "Automatically starts the audio description of the point of interest when you scan a QR code",
            "de": "Startet automatisch die Audiobeschreibung des Ortes von Interesse, wenn Sie einen QR-Code scannen",
            "fr": "Lance automatiquement la description audio du point d'intérêt lorsque vous scannez un QR code"
        ],
        "recognition_haptics": [
            "it": "Vibrazione al riconoscimento",
            "en": "Vibration on recognition",
            "de": "Vibration bei Erkennung",
            "fr": "Vibration à la reconnaissance"
        ],
        "recognition_haptics_hint": [
            "it": "Attiva una vibrazione quando il QR code viene riconosciuto con successo",
            "en": "Triggers a vibration when the QR code is recognized successfully",
            "de": "Löst eine Vibration aus, wenn der QR-Code erfolgreich erkannt wurde",
            "fr": "Déclenche une vibration lorsque le QR code est reconnu avec succès"
        ],
        "system_accessibility": [
            "it": "Accessibilità di sistema",
            "en": "System Accessibility",
            "de": "System-Barrierefreiheit",
            "fr": "Accessibilité du système"
        ],
        "system_accessibility_desc": [
            "it": "Per impostazioni avanzate come VoiceOver, Dynamic Type e Aumenta Contrasto, usa Impostazioni > Accessibilità del tuo dispositivo.",
            "en": "For advanced settings like VoiceOver, Dynamic Type, and Increase Contrast, use Settings > Accessibility on your device.",
            "de": "Für erweiterte Einstellungen wie VoiceOver, Dynamic Type und Kontrast erhöhen verwenden Sie die Einstellungen > Barrierefreiheit Ihres Geräts.",
            "fr": "Pour des paramètres avancés comme VoiceOver, Dynamic Type et Augmenter le contraste, utilisez Réglages > Accessibilité sur votre appareil."
        ],
        "event_completion": [
            "it": "Completamento evento",
            "en": "Event Completion",
            "de": "Veranstaltungsabschluss",
            "fr": "Achèvement de l'événement"
        ],
        "scan_qr_short": [
            "it": "Scansiona QR",
            "en": "Scan QR",
            "de": "QR scannen",
            "fr": "Scanner QR"
        ],
        "code_label": [
            "it": "Codice",
            "en": "Code",
            "de": "Code",
            "fr": "Code"
        ],
        "completion_code_title": [
            "it": "Codice completamento",
            "en": "Completion code",
            "de": "Abschlusscode",
            "fr": "Code de validation"
        ],
        "completion_registered": [
            "it": "Completamento registrato.",
            "en": "Completion recorded.",
            "de": "Abschluss gespeichert.",
            "fr": "Validation enregistrée."
        ],
        "event_label": [
            "it": "Evento",
            "en": "Event",
            "de": "Event",
            "fr": "Événement"
        ],
        "back_button_accessibility": [
            "it": "Torna indietro",
            "en": "Go back",
            "de": "Zurück",
            "fr": "Retour"
        ],
        "offline_bundle_unavailable": [
            "it": "Bundle offline non ancora disponibile. Riprova dopo la sincronizzazione.",
            "en": "Offline bundle not yet available. Please try again after synchronization.",
            "de": "Offline-Paket noch nicht verfügbar. Bitte versuchen Sie es nach der Synchronisierung erneut.",
            "fr": "Pack hors ligne pas encore disponible. Veuillez réessayer après la synchronisation."
        ],
        "pois_visited": [
            "it": "POI Visitati",
            "en": "POIs Visited",
            "de": "Besuchte POIs",
            "fr": "POI visités"
        ],
        "species_discovered": [
            "it": "Specie Scoperte",
            "en": "Species Discovered",
            "de": "Entdeckte Arten",
            "fr": "Espèces découvertes"
        ],
        "species_filter_fauna": [
            "it": "Fauna",
            "en": "Fauna",
            "de": "Fauna",
            "fr": "Faune"
        ],
        "species_filter_flora": [
            "it": "Flora",
            "en": "Flora",
            "de": "Flora",
            "fr": "Flore"
        ],
        "species_filter_geology": [
            "it": "Geologia",
            "en": "Geology",
            "de": "Geologie",
            "fr": "Géologie"
        ],
        "species_filter_habitat": [
            "it": "Habitat",
            "en": "Habitat",
            "de": "Lebensraum",
            "fr": "Habitat"
        ],
        "your_badges": [
            "it": "I tuoi Badge",
            "en": "Your Badges",
            "de": "Deine Abzeichen",
            "fr": "Tes badges"
        ],
        "biodiversity_album": [
            "it": "Album Biodiversità",
            "en": "Biodiversity Album",
            "de": "Biodiversitätsalbum",
            "fr": "Album biodiversité"
        ],
        "no_badges_yet": [
            "it": "Nessun badge ancora sbloccato.",
            "en": "No badges unlocked yet.",
            "de": "Noch keine Abzeichen freigeschaltet.",
            "fr": "Aucun badge débloqué pour le moment."
        ],
        "no_species_in_category": [
            "it": "Nessuna specie in questa categoria.",
            "en": "No species in this category.",
            "de": "Keine Arten in dieser Kategorie.",
            "fr": "Aucune espèce dans cette catégorie."
        ],
        "completed_trails": [
            "it": "Percorsi Completati",
            "en": "Completed Trails",
            "de": "Abgeschlossene Wege",
            "fr": "Sentiers terminés"
        ],
        "no_trails_completed": [
            "it": "Non hai ancora completato alcun percorso.",
            "en": "No trails completed yet.",
            "de": "Du hast noch keinen Weg abgeschlossen.",
            "fr": "Tu n'as encore terminé aucun sentier."
        ],
        "your_statistics": [
            "it": "Le tue Statistiche",
            "en": "Your Statistics",
            "de": "Deine Statistiken",
            "fr": "Tes statistiques"
        ],
        "events_completed": [
            "it": "Eventi completati",
            "en": "Events Completed",
            "de": "Abgeschlossene Events",
            "fr": "Événements terminés"
        ],
        "badges_unlocked": [
            "it": "Badge sbloccati",
            "en": "Badges Unlocked",
            "de": "Freigeschaltete Abzeichen",
            "fr": "Badges débloqués"
        ],
        "explorer": [
            "it": "Esploratore ospite",
            "en": "Guest Explorer",
            "de": "Gast-Entdecker",
            "fr": "Explorateur invité"
        ],
        "visitor": [
            "it": "Visitatore",
            "en": "Visitor",
            "de": "Besucher",
            "fr": "Visiteur"
        ],
        "species_locked": [
            "it": "Da scoprire",
            "en": "To Discover",
            "de": "Zu entdecken",
            "fr": "À découvrir"
        ],
        "species_locked_hint": [
            "it": "Continua a esplorare l'Oasi per completare questa scheda dell'album.",
            "en": "Keep exploring the Oasis to complete this album card.",
            "de": "Erkunde die Oase weiter, um diese Albumkarte zu vervollständigen.",
            "fr": "Continue à explorer l'Oasis pour compléter cette fiche d'album."
        ],
        "congratulations": [
            "it": "Congratulazioni",
            "en": "Congratulations",
            "de": "Glückwunsch",
            "fr": "Félicitations"
        ],
        "badge_first_steps": [
            "it": "Primi passi nell'Oasi",
            "en": "First steps in the Oasis",
            "de": "Erste Schritte in der Oase",
            "fr": "Premiers pas dans l'Oasis"
        ],
        "badge_first_poi_hint": [
            "it": "Visita il tuo primo punto di interesse.",
            "en": "Visit your first point of interest.",
            "de": "Besuche deinen ersten Ort von Interesse.",
            "fr": "Visite ton premier point d'intérêt."
        ],
        "badge_complete_trail_hint": [
            "it": "Completa tutte le tappe di un percorso.",
            "en": "Complete every step of a trail.",
            "de": "Schließe alle Etappen eines Weges ab.",
            "fr": "Termine toutes les étapes d'un sentier."
        ],
        "badge_unlock_species_hint": [
            "it": "Sblocca una specie nell'album biodiversità.",
            "en": "Unlock a species in the biodiversity album.",
            "de": "Schalte eine Art im Biodiversitätsalbum frei.",
            "fr": "Débloque une espèce dans l'album biodiversité."
        ],
        "badge_join_event_hint": [
            "it": "Partecipa a un evento.",
            "en": "Join an event.",
            "de": "Nimm an einem Event teil.",
            "fr": "Participe à un événement."
        ]
    ]

    private let knownContentTranslations: [String: [String: String]] = [
        "Primi passi nell'Oasi": [
            "it": "Primi passi nell'Oasi",
            "en": "First steps in the Oasis",
            "de": "Erste Schritte in der Oase",
            "fr": "Premiers pas dans l'Oasis"
        ],
        "Visita il tuo primo punto di interesse.": [
            "it": "Visita il tuo primo punto di interesse.",
            "en": "Visit your first point of interest.",
            "de": "Besuche deinen ersten Ort von Interesse.",
            "fr": "Visite ton premier point d'intérêt."
        ],
        "Completa tutte le tappe di un percorso.": [
            "it": "Completa tutte le tappe di un percorso.",
            "en": "Complete every step of a trail.",
            "de": "Schließe alle Etappen eines Weges ab.",
            "fr": "Termine toutes les étapes d'un sentier."
        ],
        "Sblocca una specie nell'album biodiversità.": [
            "it": "Sblocca una specie nell'album biodiversità.",
            "en": "Unlock a species in the biodiversity album.",
            "de": "Schalte eine Art im Biodiversitätsalbum frei.",
            "fr": "Débloque une espèce dans l'album biodiversité."
        ],
        "Partecipa a un evento.": [
            "it": "Partecipa a un evento.",
            "en": "Join an event.",
            "de": "Nimm an einem Event teil.",
            "fr": "Participe à un événement."
        ],
        "Visitatore": [
            "it": "Visitatore",
            "en": "Visitor",
            "de": "Besucher",
            "fr": "Visiteur"
        ],
        "Esploratore ospite": [
            "it": "Esploratore ospite",
            "en": "Guest Explorer",
            "de": "Gast-Entdecker",
            "fr": "Explorateur invité"
        ]
    ]
    
    /// Dynamic UI String Localization helper.
    func localizedString(for key: String) -> String {
        let lang = preferredLanguage
        return uiTranslations[key]?[lang] ?? uiTranslations[key]?["it"] ?? key
    }

    func localizedKnownContent(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        let lang = preferredLanguage
        return knownContentTranslations[value]?[lang] ?? value
    }
    
    /// Resolves dynamic database model localization (e.g. POI name/description)
    func localizedField(table: String, recordId: UUID, fieldName: String, fallback: String) -> String {
        let lang = preferredLanguage
        if lang == "it" { return fallback } // Default is Italian in core fields
        
        guard let container = modelContainer else { return fallback }
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<LocalTranslation>(
            predicate: #Predicate<LocalTranslation> {
                $0.tableName == table && $0.fieldName == fieldName && $0.languageCode == lang
            }
        )
        
        if let matches = try? context.fetch(descriptor),
           let match = matches.first(where: { $0.recordId == recordId }) {
            return match.translatedText
        }
        
        return fallback
    }
}
