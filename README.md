# 🚀 **ZeroSense**

### *AI-powered multiplayer semantic word-guessing game*

Built with **Flutter**, **Firebase Realtime DB**, **Groq LLM**, and a **secure Cloudflare Worker proxy**.

---

<div align="center">

![ZeroSense Banner](assets/icon/app_banner_placeholder.png)

</div>

---

## 📌 **What is ZeroSense?**

**ZeroSense** is a fast, AI-driven multiplayer word-guessing game inspired by Semantle.
Players compete to guess a *secret word* by submitting guesses, and the **AI returns a semantic score from 0 → 100**:

* **0 = exact match**
* **100 = completely unrelated**

The lower the score → the closer the guess.

Unlike other clones, ZeroSense uses **pure LLM intelligence** (Groq + Llama-3.1-8B) to score words and generate hints.
Everything is processed through a **secure Cloudflare Worker**, so **no API keys ever touch the client**.

---

## ✨ **Core Features**

### 🧠 **Semantic Scoring (AI)**

Every guess is evaluated using Groq's ultra-fast Llama-3.1 model via a Cloudflare Worker proxy.

### 💬 **AI-generated Hints**

Three-stage hint system:

1. **Startup Hint:** A natural-sentence clue for the hidden word
2. **Hint 1:** A word slightly closer to the secret
3. **Hint 2:** Even closer
4. **Hint 3:** Very close

All hints come from the model with cleaned, validated responses.

### 🌍 **Real-time Multiplayer**

Built on Firebase Realtime Database:

* Host creates a room
* Players join via room ID
* Guessing, hints, scores all sync instantly

### 🔐 **Secure Architecture**

* No API keys stored inside the Flutter app
* All LLM requests pass through Cloudflare Worker
* API key stored as a **Cloudflare Secret**
* Git repository cleaned using `filter-repo` to remove leaked keys

### 📲 **Cross-platform**

Runs on:

* Android (tested)
* iOS (ready)
* Web (future support)

### ✨ **Beautiful UI**

* Elegant glassmorphism
* Smooth animations
* Custom icons
* Seamless UX

---

## 🔧 **Tech Stack**

### **Frontend**

| Tech                 | Purpose             |
| -------------------- | ------------------- |
| Flutter              | Cross-platform UI   |
| Provider             | State management    |
| Firebase Auth        | Anonymous login     |
| Firebase Realtime DB | Multiplayer syncing |

### **Backend / AI**

| Tech               | Purpose                        |
| ------------------ | ------------------------------ |
| Groq Llama-3.1-8B  | Semantic scoring + hints       |
| Cloudflare Workers | Secure zero-exposure API proxy |
| Cloudflare Secrets | Stores GROQ_API_KEY            |

---

## 🏗️ **Architecture Overview**

```
┌────────────┐        Guess/Hints        ┌─────────────┐
│  Flutter   │ ───────────────────────▶  │ Cloudflare  │
│   App      │                           │   Worker    │
└──────┬─────┘        AI Response        └──────┬──────┘
       │                                        │
       │ Real-time Game State via Firebase      │
       ▼                                        ▼
┌────────────┐                          ┌─────────────┐
│ Firebase   │                          │   Groq AI   │
│ RealtimeDB │                          │ (LLaMA 3.1) │
└────────────┘                          └─────────────┘
```

---

## 🛠️ **Local Setup**

### **1. Clone the repository**

```bash
git clone https://github.com/ohnogaurav/ZeroSense.git
cd ZeroSense
```

### **2. Install dependencies**

```bash
flutter pub get
```

### **3. Setup Firebase**

Configure:

* `android/app/google-services.json`
* `ios/Runner/GoogleService-Info.plist`

Anonymous Auth + Realtime Database must be enabled.

### **4. Cloudflare Worker (Secure Proxy)**

Worker code: `groq-proxy/worker.js`

Deploy:

```bash
wrangler secret put GROQ_API_KEY
wrangler deploy
```

You will get a URL like:

```
https://groq-proxy.yoursubdomain.workers.dev
```

### **5. Update Flutter to use proxy**

In `api_service.dart`:

```dart
final String _url = "https://groq-proxy.<your-subdomain>.workers.dev";
```

---

## 🎮 **Game Flow**

### ⭐ Host starts a game

* Secret word auto-generated
* AI generates startup hint
* Firebase syncs room state

### ⭐ Players join

* Enter room ID
* Guesses stored in DB

### ⭐ AI processes every guess

* Worker → Groq → Score
* Score updated in DB

### ⭐ Win condition

Score == 0 → Game Over popup

---

## 📦 Project Structure

```
lib/
 ├── pages/
 │    ├── home_page.dart
 │    ├── host_page.dart
 │    ├── join_page.dart
 │    └── game_page.dart
 ├── services/
 │    ├── api_service.dart
 │    └── firebase_service.dart
 ├── widgets/
 │    ├── glass_button.dart
 │    ├── fade_slide.dart
 │    └── chat_panel.dart
 └── models/
      ├── game_state.dart
      └── words.dart
```

---

## 🚀 Deployment Targets

* [x] Android
* [x] iOS
* [ ] Web (coming soon)
* [ ] Desktop (optional)

---

## 📈 Roadmap

* [ ] Web version
* [ ] Global leaderboard
* [ ] Daily challenge mode
* [ ] Friend system
* [ ] Custom word packs
* [ ] Local offline mode
* [ ] UI theming (light/dark themes)

---

## 🛡 Security Checklist

✔ API key removed using git filter-repo
✔ Cloudflare Worker stores secret safely
✔ No hardcoded secrets in codebase
✔ Firebase rules locked down
✔ GitHub Push Protection active

---

## 🤝 Contributing

Pull requests welcomed.
Open an issue for discussions or feature suggestions.

---

## 📜 License

MIT License.

---

