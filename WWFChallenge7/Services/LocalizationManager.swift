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
    
    var preferredLanguage: String {
        get { UserDefaults.standard.string(forKey: "preferredLanguage") ?? "it" }
        set { 
            UserDefaults.standard.set(newValue, forKey: "preferredLanguage")
            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
    }
    
    private var modelContainer: ModelContainer?
    
    private init() {}
    
    func configure(with container: ModelContainer) {
        self.modelContainer = container
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
        "close": [
            "it": "Chiudi",
            "en": "Close",
            "de": "Schließen",
            "fr": "Fermer"
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
        ]
    ]
    
    /// Dynamic UI String Localization helper.
    func localizedString(for key: String) -> String {
        let lang = preferredLanguage
        return uiTranslations[key]?[lang] ?? uiTranslations[key]?["it"] ?? key
    }
    
    /// Resolves dynamic database model localization (e.g. POI name/description)
    func localizedField(table: String, recordId: UUID, fieldName: String, fallback: String) -> String {
        let lang = preferredLanguage
        if lang == "it" { return fallback } // Default is Italian in core fields
        
        guard let container = modelContainer else { return fallback }
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<LocalTranslation>(
            predicate: #Predicate<LocalTranslation> {
                $0.tableName == table && $0.recordId == recordId && $0.fieldName == fieldName && $0.languageCode == lang
            }
        )
        
        if let match = (try? context.fetch(descriptor))?.first {
            return match.translatedText
        }
        
        return fallback
    }
}
