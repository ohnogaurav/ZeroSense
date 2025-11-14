
# ZeroSense – Multiplayer (Firebase + Flutter)
[DOWNLOAD THE APP FROM RELEASE TAB]

An online multiplayer **semantic word‑guessing game** built with **Flutter**, **Firebase Realtime Database**, and **Gen‑AI scoring**.  
One player hosts a game, others join using a **Room ID**, and all players guess the secret word in real time.


---

## 🚀 Features

### 🔹 Multiplayer (Online Firebase Mode)
- Host creates a room with a secret word (kept hidden).
- Players join using Room ID.
- Realtime syncing using Firebase.

### 🔹 AI‑Powered Semantic Scoring
- Every guess is sent to Gen‑AI API.
- AI returns a semantic distance (0 = exact match, 100 = far).
- Game displays heat indicators (Burning → Cold).

### 🔹 Clean Architecture
- `GameState` for UI state
- `FirebaseService` for realtime multiplayer
- `ApiService` for AI scoring & hints
- `HostPage / JoinPage / GamePage` UI split

### 🔹 Tech Stack
- Flutter
- Firebase Realtime Database
- Firebase Anonymous Auth
- OpenAI / Groq API (any compatible model)
- Provider State Management

---

## 📁 Project Structure

```
lib/
 ├── main.dart
 ├── models/
 │     └── game_state.dart
 ├── pages/
 │     ├── home_page.dart
 │     ├── host_page.dart
 │     ├── join_page.dart
 │     └── game_page.dart
 ├── services/
 │     ├── api_service.dart
 │     └── firebase_service.dart
```

---

## 🛠️ Setup Instructions

### 1️⃣ Install dependencies
```
flutter pub get
```

### 2️⃣ Configure Firebase
Add your `google-services.json` inside:
```
android/app/google-services.json
```

### 3️⃣ Enable Anonymous Auth
Firebase Console → Authentication → Sign‑In Method → Anonymous → Enable

### 4️⃣ Add API key  
Inside `api_service.dart`:
```dart
final String _apiKey = "YOUR_KEY_HERE";
```

### 5️⃣ Run the app
```
flutter run
```

---

## 🎯 How to Play

### Host:
1. Go to **Host Game**
2. Enter a secret word  
3. Get auto‑generated **Room ID**
4. Share it with your friends
5. Tap **Start Game**

### Players:
1. Go to **Join Game**
2. Enter **Room ID**
3. Start guessing

---

## 🧠 Semantic Scoring Logic
Prompt used for AI:
```
"Target word: X. Guess: Y. Return only a number from 0–100."
```

---

## 🧪 Development Notes
- LAN mode removed (Firebase only)
- Clean state management via Provider
- Fully scalable for 20+ players
- Can be deployed to Play Store

---

## 📜 License
MIT License

---

## ✨ Author
**Gaurav Kumar**  
