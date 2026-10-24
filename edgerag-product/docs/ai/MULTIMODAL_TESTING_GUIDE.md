# 🧪 EdgeRAG Multimodal Testing & Quality Verification Guide

This guide gives simple, step-by-step instructions to test all 8 multimodal features on your Android device.

---

## 🧭 Visual Flow Diagram

```
                 [ Home Dashboard Screen ]
                            |
                 (Tap "Explore AI" Banner)
                            v
               [ Explore AI - Model Hub ]
                            |
   +----------+----------+--+-------+----------+----------+
   |          |          |          |          |          |
[AI Chat] [Ask Image] [Scribe]  [Video]   [Scanner]    [Skills]
   |          |          |          |          |          |
   v          v          v          v          v          v
Text+Photo  Camera Photo Voice Note Video File Decal OCR  7 Bounded
+ Citations + Manual RAG -> Text    3 Frames   -> SQLite  Tools
```

---

## 🛠️ Step-by-Step Feature Tests

### Test 1: Explore AI Model Hub Navigation
1. Launch EdgeRAG on your phone.
2. Select an equipment asset (e.g. `Centrifugal Pump 400X`).
3. On the Home Dashboard, observe the new **"Explore AI"** hero card (displays "8 Tools • Gemma 4 E2B IT").
4. Tap the card to open **Explore AI**.
5. **Expected Result**: 8 rounded Apple-inspired cards display in a responsive 2-column grid with live model counts and local/cloud indicators.

---

### Test 2: Multimodal AI Chat Composer
1. From the Model Hub or Dashboard, tap **AI Chat**.
2. Notice the new **attachment paperclip button** in the bottom composer.
3. Tap the paperclip:
   - Select **Choose from Photo Gallery** or **Capture Equipment Photo**.
   - Pick or take a photo of an industrial machine.
4. Notice the **media preview chip** appears above the composer with a remove `(X)` button.
5. Type: `What are the maintenance requirements shown here?` and tap Send.
6. **Expected Result**:
   - The app analyzes the image.
   - It searches `knowledge.sqlite` for matching pump manual chunks.
   - An answer is rendered with clickable `[Source CHUNK_ID]` citations.
   - Tap the **Speaker icon** on the assistant message: Android TTS speaks the answer clearly.

---

### Test 3: Ask Image (Visual Troubleshooting)
1. Tap **Ask Image** from the Model Hub.
2. Tap **Take Photo** to open the device camera.
3. Photograph any machine dial, warning decal, or serial number plate.
4. Enter question: `Is there any visual defect or leak visible?`
5. Tap **Run Visual Diagnostics**.
6. **Expected Result**:
   - Observation bullets list visible items.
   - Grounded recommendation quotes authorized manual procedures.
   - Tap any citation chip to open the **Citation Viewer** showing page numbers.

---

### Test 4: Audio Scribe (Voice Notes & Translation)
1. Tap **Audio Scribe** from the Model Hub.
2. Tap the blue **Microphone Button** (system requests Audio Recording permission if first run).
3. Speak clearly: `Secondary oil seal pressure dropped to fifteen PSI.`
4. Tap the red **Stop Button**.
5. **Expected Result**:
   - Transcript card displays the exact text.
   - Action buttons appear below:
     - Tap **Ask EdgeRAG about this Problem**: opens AI Chat with the transcript pre-filled and searches manuals.
     - Tap **Log as Incident Ticket**: opens Incident creation with the transcript as initial description.

---

### Test 5: Video Insights (Frame Extraction)
1. Tap **Video Insights** from the Model Hub.
2. Tap **Select from Gallery** and pick a short video (under 30 seconds).
3. Observe the frame strip: 3 representative frames appear with timestamps (`0.5s`, `2.5s`, `5.0s`).
4. Tap **Analyze Video Evidence**.
5. **Expected Result**:
   - The model processes the sampled frames without OOM.
   - Diagnostic observations summarize observable machine states across time.

---

### Test 6: Document Scanner (Nameplates & Labels)
1. Tap **Document Scanner** from the Model Hub.
2. Tap **Scan Document / Label** and take a photo of any technical label or printed text.
3. **Expected Result**:
   - OCR extracts model numbers, serials, and codes.
   - Automatically queries `chunks` table in `knowledge_{id}.db` and displays matching manual instructions.

---

### Test 7: Voice Assistant (Push-to-Talk)
1. Tap **Voice Assistant** from the Model Hub.
2. Hold the **Push-to-Talk** button and speak: `How do I check oil pressure?`
3. Release the button.
4. **Expected Result**:
   - Glowing waveform visualizer activates during recording.
   - The assistant searches manuals, generates an answer, and speaks it aloud via TTS.

---

### Test 8: Agent Skills Interactive Workbench
1. Tap **Agent Skills** from the Model Hub.
2. Select **Skill 3: Explain Error / Fault Code**.
3. In `error_code`, type `F07800` or `E-04` and tap **Execute Skill**.
4. **Expected Result**:
   - Skill runs with strict validation.
   - JSON output trace and execution time (in ms) are displayed.
   - Relevant manual citations appear at the bottom.

---

### Test 9: Model Manager & Storage Protection
1. Tap **Model Manager** (or the tuning icon in Model Hub).
2. Inspect the **Device Storage** card: shows real available and used space.
3. Scroll through the model profiles:
   - Notice **Qwen 2.5 0.5B Instruct** shows `Installed` on Pixel 9a.
   - **Google Gemma 4 E2B IT** shows `Download Available` with HuggingFace link and size.
4. Tap **Import Model File** to test manual file selection from Downloads.
