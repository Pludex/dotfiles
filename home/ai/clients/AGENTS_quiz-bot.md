AGENTS.md — quiz-bot

Technical documentation and guidelines for AI coding agents and developers working on the quiz-bot Nix Home Manager module and Python solver codebase.

────────────────────────────────────

1. System Overview

quiz-bot is an automated Android quiz solver for time-sensitive multiple-choice quizzes (primarily Vietnamese youth policy, politics, and history). It operates over Android Debug Bridge (ADB), parses screen content using Tesseract OCR, dispatches queries tovision/text LLM models via an OmniRoute endpoint, and executes touch inputs in real time.

┌─────────────────┐       exec-out screencap      ┌────────────────────────┐
│                 ├──────────────────────────────►│ Framebuffer / PNG Crop │
│  Android Device │                               └───────────┬────────────┘
│  (Quiz Target)  │◄──────────────────────────────┐           │
└─────────────────┘        adb input tap          │           ▼
                                                  │ ┌──────────────────────┐
                                                  │ │ Tesseract OCR        │
                                                  │ │ (PSM 4 & PSM 6)      │
                                                  │ └───────────┬──────────┘
┌─────────────────┐      /v1/chat/completions     │           │
│    OmniRoute    │◄──────────────────────────────┼───────────┘
│   (LLM Router)  ├───────────────────────────────┘
└─────────────────┘      Answer Choice (1, 2, 3, 4)

---
## 2. File & Component Structure
- **Nix Module (`programs.quiz-bot`)**: Home Manager module written in Nix. Handles system dependencies (`adb`, `tesseract`), sops-nix secret integration, option declarations, and builds the runner package via `pkgs.writeShellApplication`.
- **Python Application (`script`)**: Embedded Python 3 script inside the Nix file executing the OCR, API dispatch, screen parsing, timer logic, and ADB input actions.
---
## 3. Nix Configuration & Environment Mapping
The Nix module `programs.quiz-bot` exports option values into environment variables consumed by the Python runtime:
| Nix Option | Environment Variable | Type / Default | Description |
|---|---|---|---|
| `omnirouteUrl` | `OMNIROUTE_URL` | `string` | Base URL of OmniRoute server instance. |
| `secretName` | `OMNIROUTE_API_KEY_FILE` | `string` (`"api-keys/omniroute/quiz-bot"`) | Path to sops secret file containing the API key. |
| `model` | `QUIZ_MODEL` | `string` (`"gemini/gemini-3.6-flash"`) | Primary LLM model or combo string. Must accept vision. |
| `fallbackModel` | `QUIZ_FALLBACK_MODEL` | `nullOr string` (`null`) | Secondary model used for alternate/hedged requests. |
| `reasoningEffort` | `QUIZ_EFFORT` | `nullOr string` (`null`) | Optional `reasoning_effort` API parameter. |
| `maxTokens` | `QUIZ_MAX_TOKENS` | `int` (`512`) | Max completion token limit (includes internal reasoning tokens). |
| `questionSeconds` | `QUIZ_QUESTION_SECONDS` | `int` (`20`) | Target app question countdown budget (seconds). |
| `marginSeconds` | `QUIZ_MARGIN_SECONDS` | `int` (`2`) | Buffer subtracted from total time for network/input delay. |
| `graceSeconds` | `QUIZ_GRACE_SECONDS` | `int` (`6`) | Time extension added if bot timer expires but screen hasn't changed. |
| `detectLagSeconds` | `QUIZ_DETECT_LAG_SECONDS` | `float` (`1.0`) | Estimated lag before bot notices a new question appears. |
| `llmCutoffSeconds` | `QUIZ_LLM_CUTOFF_SECONDS` | `float` (`1.0`) | Abort LLMs this many seconds before question deadline to force a tap/guess. |
| `nextSafeSeconds` | `QUIZ_NEXT_SAFE_SECONDS` | `float` (`1.5`) | Min seconds required before app timeout to safely tap "Next". |
| `hedgeSeconds` | `QUIZ_HEDGE_SECONDS` | `float` (`3.0`) | Time to wait for primary response before sending another request. |
| `maxAttempts` | `QUIZ_MAX_ATTEMPTS` | `int` (`4`) | Total maximum LLM requests dispatched per question. |
| `parallel` | `QUIZ_PARALLEL` | `int` (`2`) | Number of initial concurrent LLM requests sent at start. |
| `textHedge` | `QUIZ_TEXT_HEDGE` | `bool` (`true` -> `"1"`) | Use lightweight OCR text payloads for hedged requests. |
      | `jpegQuality` | `QUIZ_JPEG_QUALITY` | `int` (`75`) | Compression quality of JPEG images sent to API. |
      | `jpegQuality` | `QUIZ_JPEG_QUALITY` | `int` (`75`) | Compression quality of JPEG images sent to API. |
      | `jpegQuality` | `QUIZ_JPEG_QUALITY` | `int` (`75`) | Compression quality of JPEG images sent to API. |
      ## 4. Screen Layout & Normalized Geometry Constants
      ## 4. Screen Layout & Normalized Geometry Constants
      ## 4. Screen Layout & Normalized Geometry Constants
         0.235 ├─────────────────────────────────────────┤ ◄── TITLE_REGION Bottom
               │                                         │
               │         Question + 4 Options            │
         0.235 ├─────────────────────────────────────────┤ ◄── TITLE_REGION Bottom
               │                                         │
               │         Question + 4 Options            │
               │                                         │
               │         Question + 4 Options            │
         0.30  ├─────────────────────────────────────────┤ ◄── DIALOG_REGION Top
               │       (Submit Confirmation Modal)       │
         0.30  ├─────────────────────────────────────────┤ ◄── DIALOG_REGION Top
               │       (Submit Confirmation Modal)       │
               │       (Submit Confirmation Modal)       │
         0.806 │                             ┌─────────┐ │ ◄── NEXT_BOX Top (0.806)
         0.806 │                             ┌─────────┐ │ ◄── NEXT_BOX Top (0.806)
         0.806 │                             ┌─────────┐ │ ◄── NEXT_BOX Top (0.806)
               └─────────────────────────────────────────┘ (1.0, 1.0)
               └─────────────────────────────────────────┘ (1.0, 1.0)
               └─────────────────────────────────────────┘ (1.0, 1.0)
      - **`NEXT_CENTER = (0.886, 0.938)`**: Tap target ratio for the "Next" button.
      - **`SUBMIT_CENTER = (0.799, 0.146)`**: Tap target ratio for the top header "Submit" button.
      - **`NEXT_ACTIVE_MAX = 120`**: Maximum red channel extrema value (`getextrema()[0]`); values $< 120$ indicate the "Next" button is enabled/active.
      - **`NEXT_CENTER = (0.886, 0.938)`**: Tap target ratio for the "Next" button.
      - **`SUBMIT_CENTER = (0.799, 0.146)`**: Tap target ratio for the top header "Submit" button.
      - **`NEXT_ACTIVE_MAX = 120`**: Maximum red channel extrema value (`getextrema()[0]`); values $< 120$ indicate the "Next" button is enabled/active.
      - **`SUBMIT_CENTER = (0.799, 0.146)`**: Tap target ratio for the top header "Submit" button.
      - **`NEXT_ACTIVE_MAX = 120`**: Maximum red channel extrema value (`getextrema()[0]`); values $< 120$ indicate the "Next" button is enabled/active.
         - Takes screen crop defined by `CONTENT_REGION`.
         - Executes `pytesseract.image_to_data` concurrently across two threads using Page Segmentation Modes (PSM):
         - Takes screen crop defined by `CONTENT_REGION`.
         - Executes `pytesseract.image_to_data` concurrently across two threads using Page Segmentation Modes (PSM):
         - Executes `pytesseract.image_to_data` concurrently across two threads using Page Segmentation Modes (PSM):
         - Filters words with confidence `conf <= MIN_CONF` (`10`).
         - Filters words with confidence `conf <= MIN_CONF` (`10`).
         - Filters words with confidence `conf <= MIN_CONF` (`10`).
      2. **Block Allocation**:
      2. **Block Allocation**:
      2. **Block Allocation**:
      3. **Question Fingerprinting**:
      3. **Question Fingerprinting**:
      3. **Question Fingerprinting**:
         - Assigns incremental sequential labels (`Q1`, `Q2`, etc.) keyed by fingerprint to detect recurring or duplicate screens.
         - Assigns incremental sequential labels (`Q1`, `Q2`, etc.) keyed by fingerprint to detect recurring or duplicate screens.
         - Assigns incremental sequential labels (`Q1`, `Q2`, etc.) keyed by fingerprint to detect recurring or duplicate screens.
      - **Connection Cancellation**: When any thread receives a valid choice (`1`-`4`), `Job.cancel()` aborts all active HTTP socket connections immediately.
      ---
      ## 7. Timing & State Control
      ### Deadlines & Timers
      - **Fresh Clock**: `time.time() + QUESTION_SECONDS - MARGIN_SECONDS - DETECT_LAG_SECONDS`
      - **Connection Cancellation**: When any thread receives a valid choice (`1`-`4`), `Job.cancel()` aborts all active HTTP socket connections immediately.
      ---
      ## 7. Timing & State Control
      ### Deadlines & Timers
      - **Fresh Clock**: `time.time() + QUESTION_SECONDS - MARGIN_SECONDS - DETECT_LAG_SECONDS`
      - **Connection Cancellation**: When any thread receives a valid choice (`1`-`4`), `Job.cancel()` aborts all active HTTP socket connections immediately.
      ---
      ## 7. Timing & State Control
      ### Deadlines & Timers
      - **Fresh Clock**: `time.time() + QUESTION_SECONDS - MARGIN_SECONDS - DETECT_LAG_SECONDS`
      ---
      ## 8. Heuristic Fallback (`smart_guess`)
      If LLM calls fail or exceed cutoff deadline, `smart_guess` selects an option using heuristics:
      1. Normalizes text (removes diacritics, converts `đ` $\rightarrow$ `d`, strips non-alphanumeric characters).
      ---
      ## 8. Heuristic Fallback (`smart_guess`)
      If LLM calls fail or exceed cutoff deadline, `smart_guess` selects an option using heuristics:
      1. Normalizes text (removes diacritics, converts `đ` $\rightarrow$ `d`, strips non-alphanumeric characters).
      ---
      ## 8. Heuristic Fallback (`smart_guess`)
      If LLM calls fail or exceed cutoff deadline, `smart_guess` selects an option using heuristics:
      1. Normalizes text (removes diacritics, converts `đ` $\rightarrow$ `d`, strips non-alphanumeric characters).
      # Probe device screen: output next button redness, SHA1 fingerprint, and OCR block extraction
      quiz-bot --probe
      # Dry run: process OCR and query LLMs without executing ADB input taps
      # Probe device screen: output next button redness, SHA1 fingerprint, and OCR block extraction
      quiz-bot --probe
      # Dry run: process OCR and query LLMs without executing ADB input taps
      # Probe device screen: output next button redness, SHA1 fingerprint, and OCR block extraction
      quiz-bot --probe
      # Dry run: process OCR and query LLMs without executing ADB input taps


    10. Rules for Modifying Code

    10. Rules for Modifying Code

    10. Rules for Modifying Code
    • Coordinate Recalibration: Target screen regions are normalized ratios (0.0 to 1.0). Recalibrate ratios if target app updates its UI layout or aspect ratio.
    • Secrets Protocol: API key is loaded via OMNIROUTE_API_KEY_FILE path point to sops secrets. Never hardcode keys or log secret path contents.
    • Secrets Protocol: API key is loaded via OMNIROUTE_API_KEY_FILE path point to sops secrets. Never hardcode keys or log secret path contents.
    • Secrets Protocol: API key is loaded via OMNIROUTE_API_KEY_FILE path point to sops secrets. Never hardcode keys or log secret path contents.
