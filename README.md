# 🚀 ServerDeck

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Go Version](https://img.shields.io/badge/Go-1.24-00ADD8.svg)](https://go.dev/)
[![Rust Version](https://img.shields.io/badge/Rust-1.80%2B-DEA584.svg)](https://www.rust-lang.org/)
[![Swift Version](https://img.shields.io/badge/Swift-6.0-F05138.svg)](https://swift.org/)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B%20%7C%20Linux-black.svg)]()

> **Il pannello di controllo tascabile del tuo homelab.**  
> Unisce il monitoraggio hardware, la gestione Docker, il terminale shell host interattivo e la dashboard dei servizi self-hosted in un'unica app nativa iOS (SwiftUI) alimentata da un leggero agent Go su Debian/Linux e un micro-bridge nativo in Rust.

---

## 🏛️ Architettura (Modello Beszel)

```
┌────────────────────────────────────────────────────────┐
│  iPhone (iOS 17+ / SwiftUI Nativo)                     │
│  Keychain · URLSession · WebSockets · Dual-IP Failover │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTPS / Tailscale VPN (privato & sicuro)
                           ▼
┌────────────────────────────────────────────────────────┐
│  srv-01 / Docker: serverdeck-backend (Go)              │
│  • Container 100% NON PRIVILEGIATO                     │
│  • REST API + WebSocket Stream in tempo reale          │
│  • Token Constant-Time SHA-256 Authentication          │
│  • Auto-Discovery porte web dei container Docker       │
└──────────────────────────┬─────────────────────────────┘
                           │ UNIX Domain Socket (/run/serverdeck/bridge.sock)
                           ▼
┌────────────────────────────────────────────────────────┐
│  srv-01 Host Linux: serverdeck-bridge (Rust Nativo)    │
│  • Daemon ultra-leggero systemd (~590 KB, 120 KB RAM)  │
│  • Esegue comandi shell del Terminale sull'host        │
│  • Gestione PC: systemctl reboot, shutdown, telemetry  │
└────────────────────────────────────────────────────────┘
```

---

## ✨ Funzionalità

### 📱 1. Client iOS (SwiftUI)
- **Overview in Tempo Reale:** Gauge animati per carico CPU, memoria RAM, temperature, throughput di rete e stato dei dischi (`/` e volumi dati).
- **Dual-IP Failover Intelligente:** Prova automaticamente la rete locale LAN (es. `10.0.0.99`) per latenza zero quando sei a casa, con fallback automatico e trasparente su Tailscale (es. `100.x.y.z`) quando sei fuori.
- **Terminale Shell Interattivo:** Esegui comandi shell direttamente sul server host con cronologia, output monospazio, exit code e tempo di esecuzione in millisecondi. Include chip di scorciatoie rapide per i comandi più frequenti (`uptime`, `free -h`, `df -h`, `sensors`, ecc.).
- **Gestione PC & Host:** Riavvio e spegnimento del server protetti da dialoghi di doppia conferma e feedback aptico.
- **Docker Management:** Lista container con raggruppamento per stack Docker Compose, statistiche live (CPU/RAM cgroup, I/O disco/rete), log viewer stile terminale e azioni di avvio, arresto e riavvio.
- **Docker System Prune:** Recupero spazio su disco con un tocco eliminando container terminati e immagini orfane.
- **Homepage Servizi Self-Hosted:** Griglia con probe di ping/latenza in tempo reale (Portainer, Beszel, Jellyfin, ecc.) e rilevamento automatico (*auto-discovery*) dei nuovi container con porte web esposte.
- **Sicurezza & Privacy:** Credenziali memorizzate nel Secure Enclave via iOS Keychain e supporto per sblocco con Face ID / Touch ID.

### ⚙️ 2. Backend Agent (Go) & Host Bridge (Rust)
- **Agent Go (`backend/`):** Server compatto Go 1.24 che dialoga con la Docker Engine API e gestisce lo streaming WebSocket bidirezionale.
- **Bridge Rust (`bridge/`):** Demone nativo systemd minimale in Rust che ascolta su socket UNIX locale (`/run/serverdeck/bridge.sock`). Permette al container Go di operare in modo completamente **non privilegiato**, eliminando qualsiasi rischio di container escape.
- **Hardening di Sicurezza:**
  - Confronto token in tempo costante con SHA-256 (prevenzione timing e length attacks).
  - Parametro query `?token=` ristretto solo all'upgrade WebSocket per evitare token leak nei log HTTP.
  - Protezione SSRF contro endpoint cloud metadata (`169.254.169.254`).
  - Cap su log tailing (max 2000 righe) contro attacchi DoS da esaurimento memoria.

---

## 📁 Struttura del Progetto

```
ServerDeck/
├── backend/              # Agent Go REST + WebSocket server & Docker Compose
│   ├── cmd/server/main.go
│   ├── internal/api/     # Routing, handlers, WebSocket hub
│   ├── internal/auth/    # Middleware di autenticazione e CORS
│   ├── internal/docker/  # Client Docker Engine API
│   ├── internal/hostctrl/# Client verso il bridge Rust
│   ├── internal/metrics/ # Collettore telemetria host
│   ├── internal/services/# Health check prober e auto-discovery
│   ├── Dockerfile
│   └── compose.yml
├── bridge/               # Daemon nativo Rust (modello Beszel)
│   ├── Cargo.toml
│   └── src/main.rs       # Gestore UNIX socket per esecuzione comandi host
├── ios/                  # Applicazione nativa iOS (SwiftUI)
│   ├── ServerDeck.xcodeproj
│   ├── project.yml       # Configurazione XcodeGen
│   ├── Sources/ServerDeck/
│   │   ├── Models/       # Modelli dati conformi a SHARED_SPEC.md
│   │   ├── Services/     # APIClient, WebSocketManager, KeychainService
│   │   ├── ViewModels/   # Logica di stato e polling
│   │   └── Views/        # Viste SwiftUI e Terminale Host
│   └── Tests/            # Test unitari
├── scripts/              # Script di installazione systemd e asset
│   ├── install-bridge.sh # Script di installazione automatica del bridge Rust
│   └── serverdeck-bridge.service
├── AppIcon.svg           # Icona master vettoriale SVG
├── SHARED_SPEC.md        # Specifica API condivisa
└── LICENSE               # Licenza MIT
```

---

## ⚡ Quick Start

### 1. Installazione Host in 1 Click (Script automatico)

Su qualsiasi macchina Linux (Debian, Ubuntu, Arch, ecc.) puoi installare sia il **daemon nativo Rust** sia il **container Docker non privilegiato** con un unico comando:

```bash
curl -sSL https://raw.githubusercontent.com/GhostAndry/ServerDeck/main/scripts/install.sh | sudo bash
```

Lo script rileverà automaticamente l'architettura (`x86_64` o `arm64`), installerà Docker se assente, compilerà il bridge Rust come servizio di sistema `serverdeck-bridge.service`, avvierà il container backend e genererà il token sicuro stampando a schermo l'IP locale e Tailscale.

Oppure puoi passare un token o una porta personalizzata al volo:
```bash
curl -sSL https://raw.githubusercontent.com/GhostAndry/ServerDeck/main/scripts/install.sh | sudo SERVERDECK_TOKEN=mio-token-segreto SERVERDECK_PORT=8080 bash
```

---

### 2. Configurare l'App iOS (Multi-Server)

1. Apri la cartella `ios/` in **Xcode** (oppure apri `ios/ServerDeck.xcodeproj`).
2. Collega il tuo iPhone o seleziona un simulatore iOS 17+.
3. Seleziona il tuo **Team di sviluppo personale** in *Signing & Capabilities*.
4. Compila ed esegui sull'iPhone (`Cmd + R`).
5. **Aggiunta e Gestione Server:**
   - Tocca il nome del server in alto nella barra principale per aprire il **selettore rapido**, oppure vai in **Impostazioni** > **I Miei Server**.
   - Tocca **"Aggiungi Nuovo Server"** per configurare tutti i tuoi server o VPS (es. `srv-01`, `homelab-vps`, `pi-cluster`).
   - Inserisci il nome, l'IP locale (LAN), l'IP Tailscale/remoto e il token API.
   - Puoi verificare istantaneamente la rotta con il pulsante **"Test Connessione"** e passare da un server all'altro con un tocco!
   - **API Token:** Il token configurato nel file `.env`
   - Premi **Test Connection** per verificare la rotta attiva e la latenza in millisecondi.

---

## 📄 Licenza

Distribuito sotto licenza **MIT**. Consulta il file [`LICENSE`](LICENSE) per ulteriori informazioni.
