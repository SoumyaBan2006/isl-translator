# 🧠 ISL Bridge — Real-Time Indian Sign Language Translator

> Turning silence into speech. Instantly. Anywhere.

---

## 🌍 The Problem

Over **5 million deaf individuals in India** rely on Indian Sign Language (ISL) daily.  
Yet:

- ❌ No real-time ISL translator exists
- ❌ Existing tools support only ASL (a completely different language)
- ❌ Communication requires human interpreters — expensive and inaccessible

This creates a **massive communication barrier** in hospitals, schools, banks, and public services.

---

## 💡 The Solution — ISL Bridge

**ISL Bridge** is a real-time mobile application that converts Indian Sign Language into **natural spoken sentences**.

📱 Just open the app → sign in front of the camera → get instant speech output.

---

## ⚙️ How It Works
    Camera Input
    ↓
    ML Kit Pose Detection (landmarks)
    ↓
    Custom ML Model (sign classification)
    ↓
    Sign Sequence Buffer
    ↓
    Google Gemini AI (sentence formation)
    ↓
    Translation API (multi-language)
    ↓
    Text-to-Speech (audio output)

---

## ✨ Features

- 🎥 Real-time sign detection using phone camera
- 🧠 AI-powered sentence formation (Gemini)
- 🔊 Speech output in 5 languages:
  - English
  - Hindi
  - Bengali
  - Tamil
  - Telugu
- 📊 Translation history (Firebase)
- 🔁 Replay audio feature
- 🧹 Reset session instantly
- 📡 Works offline for sign detection
- 📱 Runs on any Android device (Android 8+)

---

## 🚀 Unique Selling Points

- 🇮🇳 Built specifically for **Indian Sign Language**
- ⚡ Real-time — no delay, no interpreter needed
- 🧠 Converts signs → **natural sentences**, not raw words
- 🌐 Breaks both:
  - Sign language barrier
  - Spoken language barrier

---

## 🧪 Tech Stack

| Technology | Purpose |
|----------|--------|
| Flutter | Mobile app development |
| Google ML Kit | Pose & landmark detection |
| Random Forest (scikit-learn) | Sign classification |
| Gemini API | Sentence generation |
| Firebase Firestore | Data storage |
| Firebase Analytics | Usage tracking |
| Flutter TTS | Speech output |
| MyMemory API | Language translation |

---

## 📊 Current Status

- ✅ 53 ISL signs supported
- ✅ Real-time working prototype
- 🔄 Expanding to 263 signs (Phase 2)

---

## 🔮 Future Roadmap

- 📈 Expand dataset → improve accuracy
- ✋ Add hand landmark tracking
- 🧠 ISL-native grammar model
- 🔄 Two-way communication (speech → text)
- 🍎 iOS version
- 🏥 Government & institutional integration

---

## 🗃️ Dataset
Trained on the INCLUDE dataset by AI4Bharat (IIT Madras).

- 984 videos across 53 ISL signs
- 7 different signers for diversity
- Available at: zenodo.org/record/4010759
- GitHub: AI4Bharat/INCLUDE

---

## 💸 Cost Efficiency

- Monthly cost: ₹3,000 – ₹5,000
- Potential users: 5 million+

👉 **Cost per user: < ₹0.001/month**

---

## 🌐 Live Prototype (Link to download apk is present in this prototype)

🔗 https://soumyaban2006.github.io/isl-translator/

---

## 📂 Repository

🔗 https://github.com/SoumyaBan2006/isl-translator

---

## 📂 Demo Video

🔗 https://drive.google.com/file/d/1BjoxxV-Rp1Zh3tIoZ9Fn-q4c-lrMPHko/view?usp=sharing

---

## 👨‍💻 Team

**PseudoPair**  
- Soumya Banerjee (Lead)
- Trisha Karmakar

---

## ❤️ Vision

To make ISL Bridge the **default communication layer** between deaf and hearing individuals across India.

---

> “Communication is a basic human right. ISL Bridge makes it accessible.”
