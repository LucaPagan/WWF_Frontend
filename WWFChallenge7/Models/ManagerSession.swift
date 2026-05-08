import Foundation

// Gestione sessione gestore WWF — nessun backend, credenziali locali
// Per produzione: sostituire con Firebase Auth o equivalente
class ManagerSession: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var loginError: String? = nil

    // Credenziali hardcoded per prototipo
    // ⚠️ In produzione: sostituire con sistema di auth reale
    private let validEmail    = "gestore@wwf.it"
    private let validPassword = "Astroni2024!"

    func login(email: String, password: String) {
        if email == validEmail && password == validPassword {
            isLoggedIn = true
            loginError = nil
        } else {
            loginError = "Credenziali non valide."
        }
    }

    func logout() {
        isLoggedIn = false
    }
}