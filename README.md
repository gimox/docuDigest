# DocuDigest OCR

DocuDigest è un'applicazione Flutter cross-platform (Web & Desktop) progettata per convertire PDF scansionati o immagini in formato Markdown pulito e strutturato utilizzando il modello locale **GLM-OCR** distribuito tramite server MLX.

## Caratteristiche Principali

*   **Pannello di Lavoro Split Screen**: Visualizzazione a due pannelli affiancati: il documento caricato a sinistra e il risultato Markdown a destra.
*   **Caricamento Istantaneo & Drag & Drop**: Supporta il trascinamento e rilascio globale di file PDF o la selezione classica da file dialog direttamente nella schermata principale.
*   **Visualizzatore PDF Floating**: Visualizzazione della pagina PDF attiva come foglio fluttuante su sfondo scuro con ombreggiatura premium e controlli di navigazione in overlay semitrasparente.
*   **Barra Miniature Espandibile/Collassabile**: Navigazione rapida per pagine tramite barra laterale delle miniature ridimensionata, richiudibile con un clic.
*   **Editor & Anteprima Segmentati**: Un selettore a pillola Material 3 consente di scorrere tra l'**Anteprima Renderizzata** (attiva per impostazione predefinita) e l'**Editor di Modifica** (con barra di formattazione persistente).
*   **Conversione OCR Singola/Completa**: Permette di convertire la singola pagina o di lanciare la trascrizione automatica dell'intero documento in background.
*   **Esportazione Cross-Platform**: Consente di salvare i documenti Markdown finali (`.md`) localmente sia su Web che su Desktop (macOS/Windows/Linux).

## Requisiti

*   **Flutter SDK**: >= 3.0.0
*   **Motore di Backend (Configurabile nelle Impostazioni)**:
    *   **MLX Apple** (Predefinito): Il server locale MLX deve essere in ascolto su `http://localhost:8080` con il modello caricato.
    *   **Ollama**: Il servizio Ollama deve essere in ascolto su `http://localhost:11434` con il modello `glm-ocr` disponibile (`ollama pull glm-ocr`).

## Avvio in Sviluppo

Per eseguire l'applicazione localmente:

```bash
# Esegui i test unitari/widget
flutter test

# Avvia l'applicazione (Desktop macOS come esempio)
flutter run -d macos

# Avvia l'applicazione sul Web
flutter run -d chrome
```
