# 🔥 L'idea: ServerDeck

[关于已有软件 ServerCat 的相关说明 · Issue #30 · Lakr233/Rayon · GitHub](https://images.openai.com/static-rsc-4/6tp4qk_Kc6vTpz7tUBPtGwDXjxLnT8y4eOdMsMBE643_cisqvJdD1t8XaPJNU75Q9JbVvrnHHq57jfc13dDjOBBCFN5GlTCdkMK9dmgN_8Zs04EnksYZLK4nkpOnN7-M9kfxFQjzn_oB1UDA0aoCUl6j8RB4u2SbHQDyvuGlk3U?purpose=inline)

[github.com](https://github.com/Lakr233/Rayon/issues/30?utm_source=chatgpt.com)

# ServerDeck

Il pannello di controllo tascabile del tuo homelab.

L'obiettivo è riunire tre cose:

- Homepage: accesso rapido a tutti i servizi self-hosted.
- Portainer: gestione di container, stack, log e riavvii.
- Monitoring: stato del server, CPU, RAM, dischi, rete e alert.

Il vantaggio vero è che non devi replicare interamente Portainer. Devi costruire l'interfaccia che vorresti avere quando sei fuori casa e qualcosa smette di funzionare.

## 1. Come la strutturerei

[Komodo Go](https://images.openai.com/static-rsc-4/862WD3e06tLfJ4cUdlDSMH68Vc1KZJ_QGN4f5n9FBIKriJ-AHlE1s1Ign9sqjnF_9ibJ1HKpSl_clAvMCmZWuSvd9jUiiBzXoq0BccOmOUMa2UFXB1qgkrQTNCpTSDyC60WwZDxC_o0E9taIuMKwaft8x5MZbWXDLFvcjJXX2pU?purpose=inline)

01 · Overview

MVP

Stato di `srv-01`, uptime, CPU, RAM, temperatura se disponibile, spazio su `/` e `/mnt/DATA`, traffico di rete e numero di container attivi.

[Unraid Remote - Developer Tools App | MWM](https://images.openai.com/static-rsc-4/V_QeOoaae8eW3nfkUtQLQIH4KX1DkKOjdIYjeZvrUJJd29-Lrx3s6JOox_yCQptzWpX_PSL_I-Khv-M4Nc30WZE420raYdo7GYgJwHwvBxdpwClwTKLwwztn_Z0mCObVdOCaeE5czte8u7VuTFNYkuj4HvCeGJ9KBkOg8XKCJlQ?purpose=inline)

02 · Docker

MVP

Lista dei container con stato, utilizzo risorse, restart, stop/start, log live e filtri per stack. Le operazioni passano da un backend che usa la Docker Engine API ufficiale.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://docs.docker.com\&sz=32)

Docker Docs+1



[Labby - Native iOS Client for Homepage Dashboard](https://images.openai.com/static-rsc-4/kRXg9mQTpNqym5YcfGV0LqNPd0CXi34VMBaoB9gimzqCaEHMGIgjw3jFmCz_QJ1WPcADomzvNQDCQoWjSI-_n4ffXKokbaZbVOIz-QgNgpGGYre8O9sdqX1ZZFvJu4x0y7liiJ4ODkz345gujMKwCr7WgKjxaqBo_FjgkC0P2AA?purpose=inline)

03 · Services

MVP

Una homepage personalizzabile con OpenWebUI, Portainer, qBittorrent, Radarr e gli altri servizi che aggiungerai. Ogni scheda mostra se il servizio risponde.

[Prompt 2 à 8,99 € pour les pros des serveurs - iPhoneSoft](https://images.openai.com/static-rsc-4/M9n75sVHDF-gTw0iBLJ2NHlV50KoCvAkV4yHKa5GVFB3Qbj1ctqeN_h1gdNKZ8RsuPJ4KIfe_VBq1CpJAmI1J6HO84pAzAuMeP4n5bW5Q4uS1HRhRtukHess_FCXnaD6WTF4_CVAWv-w0ALBk2BWKAL5OUhX147XkA_4tRvQ1E4?purpose=inline)

04 · Terminale e log

V2

Terminale SSH integrato, log di sistema, ricerca nei messaggi e comandi rapidi per diagnosticare problemi.

[SwiftServer - Linux Monitoring & SSH](https://images.openai.com/static-rsc-4/LiDHNv0EYvYSPgIwuqxQzfdEm9mOyL4M7rs044coQH5AKBn2jCHx9Gx2HPXUWWWzvZIAIlmuEFjF8TvijFyVfRLcWFfmoDfNToqKPrQ_EWYQaNnI17AcBvYvmaY7B68EX6PyXG-5NwJ1X9VF5P-a2AsBz0YZ878VT1qofGJS1Bw?purpose=inline)

05 · Alert

V2

Avvisi per disco quasi pieno, container fermo, RAM esaurita o servizio irraggiungibile. Le notifiche push richiederanno un meccanismo aggiuntivo, non basta che l'app sia aperta.

## 2. L'architettura che userei

Per il tuo ambiente, sceglierei SwiftUI nativo + un piccolo agent Go su Debian.

ServerDeck · iOS

SwiftUI · URLSession · Keychain

Tailscale

Accesso privato alla rete

ServerDeck Agent · srv-01

Go · REST API · WebSocket · autenticazione

Docker Engine

Container, log, stats

Linux

CPU, RAM, dischi, rete

Perché questa combinazione?

- SwiftUI: interfaccia nativa, animazioni fluide, widget iOS e integrazione con Face ID.
- Go: un singolo binario per il server, facile da distribuire senza aggiungere un altro stack Docker.
- Docker Engine API: gestione diretta dei container, senza dover ricostruire tutta l'interfaccia di Portainer.
- Tailscale: niente porte pubbliche aperte. L'app raggiunge l'agent attraverso la rete privata; Tailscale supporta iOS.&#x20;

  [image](https://www.google.com/s2/favicons?domain=https://tailscale.com\&sz=32)

  Tailscale Docs+1



Sicurezza importante: non esporrei mai direttamente il socket Docker all'iPhone o alla rete. L'agent deve avere autenticazione, autorizzazioni per ogni operazione e accesso limitato. Chi può controllare liberamente Docker può, di fatto, ottenere privilegi molto elevati sul server.

## 3. La funzione che renderebbe l'app davvero utile

Io aggiungerei una sezione chiamata Quick Actions.

Spazio disco

DATA · 72% occupato

OpenWebUI

● Running · Healthy

Restart container

Azione immediata con conferma

Apri Portainer

Accesso diretto alla dashboard esistente

Altre chicche che aggiungerei:

- Dashboard per stack: Films, OpenWebUI e altri gruppi, con stato aggregato.
- Modalità emergenza: mostra gli ultimi errori e i container coinvolti quando qualcosa non funziona.
- Storico risorse: grafici di CPU, RAM e disco per capire se un servizio perde memoria.
- Widget Home Screen: stato del server e conteggio dei servizi attivi.
- Azioni preferite: riavviare un servizio, aprire un URL o consultare i log con due tocchi.

## 4. Come gestirei la rifirma ogni 7 giorni

Dato che vuoi installarla senza pubblicarla necessariamente sull'App Store, puoi svilupparla con Xcode e installarla sul tuo iPhone tramite provisioning gratuito. Con una firma personale gratuita, il limite tipico è di 7 giorni, quindi dovrai rinnovare la firma periodicamente. La rifirma non dovrebbe richiedere di reinstallare il backend o perdere la configurazione sul server.

Per non complicarti la vita:

1. Mantieni agent e configurazione sul mini PC.
2. Salva le credenziali nell'iOS Keychain.
3. Tieni il codice dell'app su Git.
4. Quando scade la firma, ricompili e reinstalli l'app dall'ambiente di sviluppo.

Se vuoi ridurre la seccatura, valuta anche l'installazione tramite strumenti di sideloading compatibili con il tuo setup. Non darei per scontato che ogni soluzione possa rifirmare automaticamente l'app senza configurazione aggiuntiva.

## 5. Da quale versione partirei

| Fase | Funzionalità                                                                 |
| ---- | ---------------------------------------------------------------------------- |
| V1   | Login, stato del server, dischi, CPU/RAM, container, log, restart e homepage |
| V1.1 | Stack Docker, grafici storici, ricerca e filtri                              |
| V2   | SSH integrato, alert e notifiche, widget iOS                                 |
| V3   | Più server, backup, aggiornamenti controllati e automazioni                  |

La prima versione dovrebbe essere abbastanza piccola da poterla davvero finire, invece di diventare l'ennesimo progetto con 47 cartelle `TODO` e una README ambiziosa. 💀

La mia scelta finale: sviluppa ServerDeck come app nativa SwiftUI, con un agent Go installato direttamente su `srv-01`, e usa Portainer come fallback per le operazioni avanzate. In questo modo costruisci qualcosa che userai ogni giorno e che potrai espandere anche quando aggiungerai altri mini PC al tuo homelab.