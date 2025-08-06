# 🚀 Typeracer

**Typeracer** is a modern, full-stack **Elixir + Phoenix LiveView** application for mastering typing speed and accuracy — whether you're practicing solo or competing in real-time multiplayer races.  

With a sleek, responsive UI powered by **Tailwind CSS**, it offers rich statistics tracking, user profiles, and detailed mistake analysis to help you improve every keystroke.  

---

## ✨ Features

- 🎯 **Practice Mode** – Sharpen your skills with adjustable difficulty levels and **real-time WPM, accuracy, and mistake tracking**.  
- ⚡ **Multiplayer Races** – Challenge friends or random players in **live typing battles** with instant progress updates.  
- 👤 **User Profiles** – Track your personal bests, improvement history, and streaks.  
- 📊 **Advanced Stats** – Daily stats, session history, and interactive progress charts.  
- 🛠 **Mistake Analysis** – Identify your most common errors and work on them.  
- 📱 **Responsive UI** – Optimized for both desktop and mobile, thanks to Tailwind CSS + LiveView.

---

## 🛠 Getting Started

### 📋 Prerequisites

Make sure you have:

- **Elixir** `>= 1.14`
- **Erlang/OTP** `>= 25`
- **PostgreSQL**
- **Node.js** (for frontend assets)
- *(Optional)* `esbuild` & `tailwindcss` binaries (auto-installed)

---

### ⚙️ Setup Instructions

```sh
# 1️⃣ Clone the repository
git clone https://github.com/jyoti-131/typeracer.git
cd typeracer

# 2️⃣ Install dependencies
mix deps.get
cd assets && npm install && cd ..

# 3️⃣ Setup the database
mix ecto.setup

# 4️⃣ Start the Phoenix server
mix phx.server
```

Then visit **[http://localhost:4000](http://localhost:4000)** 🚀  

---

## 🧪 Running Tests

```sh
mix test
```

---

## 📂 Project Structure

| Path | Description |
|------|-------------|
| `lib/typeracer/accounts/` | Ecto schemas for users, sessions, daily stats, and mistakes |
| `lib/typeracer_web/live/` | LiveView modules for gameplay, profiles, and multiplayer |
| `lib/typeracer_web/components/` | Core UI components |
| `priv/repo/migrations/` | Database migration files |
| `assets/` | Frontend assets (JS, CSS, Tailwind config) |

---

## 🔑 Key Modules

- [`Typeracer.Stats`](lib/typeracer/stats.ex) – Stats, sessions, and profile logic  
- [`UserProfile`](lib/typeracer/accounts/user_profile.ex) – User profile schema  
- [`TypingSession`](lib/typeracer/accounts/typing_session.ex) – Typing session schema  
- [`DailyStat`](lib/typeracer/accounts/daily_stat.ex) – Daily statistics schema  
- [`CharacterMistake`](lib/typeracer/accounts/character_mistake.ex) – Mistake tracking schema  

---

## 🎨 Customization

- **Difficulty Levels** – Edit in [`RaceLive.Index`](lib/typeracer_web/live/game_live/index.ex)  
- **UI Components** – Modify in [`CoreComponents`](lib/typeracer_web/components/core_components.ex)  
- **Multiplayer Logic** – Update in [`RaceRoomLive`](lib/typeracer_web/live/game_live/race_room_live.ex)  

---

## 🤝 Contributing

1. **Fork** the repository  
2. **Create** your feature branch  
3. **Commit** your changes  
4. **Push** to your branch  
5. Open a **Pull Request**

---

## 📄 License

This project is licensed under the **MIT License** – see [LICENSE](LICENSE) for details.

---

💡 **Pro Tip:** Consistency is the key. Race daily, track your stats, and watch your WPM soar! 🚀  
