Sí, ahora sí. **Quieres que haga un README para NUMINATION**, usando todo el contexto que me pasaste del repositorio real: Android + Kotlin + Compose + Material 3 + IA + Next.js + Prisma + MySQL + autenticación + Supabase + web login + CI/CD.

# ⚡ Numination

### The pocket-sized AI IDE for real development work.




\







\

---

<div align="center">

# NUMINATION

**Build anywhere. Code anywhere. Think with AI.**

A native Android development environment designed to bring real software development into your pocket.

</div>

---

## ✨ Overview

**Numination** is a native Android IDE with an integrated AI agent, project workspace, file explorer, authentication system, cloud-backed services and a companion web login.

The project is designed around a simple idea:

> **Professional development tools shouldn't have to stay on a desktop.**

Numination combines an Android-native development environment with AI-assisted workflows and a cloud backend, creating a portable workspace for developers who want to build, inspect and manage projects directly from their mobile device.

The architecture separates the Android application, backend services and web authentication layer so each part of the ecosystem can evolve independently.

---

# 🚀 Features

<table>
<tr>
<td width="50%">

### 📱 Native Android IDE

Built specifically for Android using:

* Kotlin
* Jetpack Compose
* Material 3
* Native Android components
* Modern Android architecture

</td>

<td width="50%">

### 🤖 AI-Assisted Development

Numination integrates an AI agent into the development workflow.

* AI development assistance
* Context-aware workflows
* Project interaction
* Development screens
* AI-powered tooling

</td>
</tr>

<tr>
<td width="50%">

### 📂 Project Workspace

Work directly with real project structures.

* File explorer
* Workspace management
* Project navigation
* File operations
* Development environment

</td>

<td width="50%">

### 🔐 Authentication

A complete authentication ecosystem.

* Email authentication
* Google sign-in
* Session management
* Profile synchronization
* Secure redirects
* Cloud-backed accounts

</td>
</tr>

<tr>
<td width="50%">

### ☁️ Cloud Backend

The backend provides the services required by the application.

* Next.js API
* TypeScript
* Prisma
* MySQL
* Authentication
* User data

</td>

<td width="50%">

### 🌐 Companion Web

A lightweight web login experience connected to the Numination backend.

* Static web application
* Vercel deployment
* Authentication flow
* Backend integration
* Browser-based access

</td>
</tr>
</table>

---

# 🏗️ Architecture

Numination is divided into multiple independent layers.

```text
                         ┌──────────────────────┐
                         │       USER           │
                         └──────────┬───────────┘
                                    │
                  ┌─────────────────┴─────────────────┐
                  │                                   │
                  ▼                                   ▼
        ┌────────────────────┐              ┌────────────────────┐
        │   Android App      │              │   Web Login        │
        │                    │              │                    │
        │ Kotlin             │              │ HTML / CSS / JS    │
        │ Jetpack Compose   │              │ Vercel             │
        │ Material 3        │              │                    │
        └─────────┬──────────┘              └─────────┬──────────┘
                  │                                   │
                  └─────────────────┬─────────────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │     Backend API      │
                         │                      │
                         │ Next.js              │
                         │ TypeScript           │
                         │ Prisma               │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │       Database       │
                         │                      │
                         │        MySQL         │
                         └──────────────────────┘

                                    │
                                    ▼

                         ┌──────────────────────┐
                         │      Supabase        │
                         │                      │
                         │ Authentication       │
                         │ Sessions             │
                         │ User synchronization  │
                         └──────────────────────┘
```

---

# 📁 Repository Structure

```text
Numination/
│
├── android/
│   │
│   ├── app/
│   ├── gradle/
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradlew
│
├── backend/
│   │
│   ├── app/
│   ├── prisma/
│   ├── public/
│   ├── package.json
│   ├── next.config.*
│   ├── prisma.schema
│   └── .env.example
│
├── wren-login-web/
│   │
│   ├── index.html
│   ├── style.css
│   ├── script.js
│   ├── config.example.js
│   └── README.md
│
├── supabase/
│   │
│   └── migrations/
│
├── docs/
│
├── scripts/
│
├── .github/
│   └── workflows/
│       └── build.yml
│
├── .env.example
├── .gitignore
├── LICENSE
└── README.md
```

---

# 📱 Android

The Android application is the core of Numination.

Built using modern Android development technologies, the application provides the development workspace, project navigation and AI-assisted experiences.

### Core technologies

| Technology      | Purpose              |
| --------------- | -------------------- |
| Kotlin          | Application language |
| Jetpack Compose | UI framework         |
| Material 3      | Design system        |
| Android SDK     | Native platform      |
| Gradle          | Build system         |

### Android capabilities

* Workspace
* File explorer
* Project management
* AI screens
* Session management
* Credits system
* Owner/admin screens
* Storage permissions
* Native Android UI

---

# 🤖 AI Development

Numination is built around an AI-assisted development experience.

Instead of treating AI as a separate chatbot, the project integrates AI capabilities into the development environment itself.

```text
Developer
    │
    ▼
Project
    │
    ├── Files
    ├── Workspace
    ├── Context
    └── Configuration
           │
           ▼
       AI Agent
           │
           ▼
    Development Workflow
```

The goal is to make AI useful **inside the development process**, rather than outside of it.

---

# 🔐 Authentication

Numination provides a unified authentication flow across its ecosystem.

Current architecture includes:

* Supabase authentication
* Google sign-in
* Email authentication
* Session handling
* Profile synchronization
* Redirect handling
* Backend authentication integration

The Android application and web login communicate with the backend while maintaining the user's account and session ecosystem.

---

# ☁️ Backend

The backend is powered by:

```text
Next.js 14
TypeScript
Prisma 5
MySQL
```

The backend acts as the central API layer connecting the clients, authentication systems and persistent application data.

### Backend responsibilities

* API endpoints
* User management
* Authentication integration
* Profile synchronization
* Application data
* Billing-related services
* AI-related services
* Database operations

---

# 🗄️ Database

Numination uses **Prisma** as its database ORM.

```text
Application
     │
     ▼
  Next.js API
     │
     ▼
   Prisma
     │
     ▼
   MySQL
```

Prisma provides the application with a typed and structured interface for interacting with the database.

---

# 🌐 Web Login

The companion web login is located inside:

```text
wren-login-web/
```

It is intentionally lightweight and can be deployed independently from the Android application.

The web client communicates with the backend through:

```javascript
window.WREN_API_BASE
```

Before deployment, configure the backend endpoint using:

```text
config.example.js
```

and create the required:

```text
config.js
```

---

# ⚙️ Environment Configuration

Environment variables should never be committed directly to the repository.

Use the provided examples:

```text
.env.example
backend/.env.example
wren-login-web/config.example.js
```

Create your local configuration files before running the project.

---

# 🧑‍💻 Getting Started

## 1. Clone the repository

```bash
git clone https://github.com/kraqinc/Numination.git
```

```bash
cd Numination
```

---

## 2. Android

Open:

```text
android/
```

with **Android Studio**.

Then allow Gradle to synchronize the project and run the application on an emulator or physical Android device.

---

## 3. Backend

Navigate to:

```bash
cd backend
```

Install dependencies:

```bash
npm install
```

Configure the environment:

```text
.env
```

based on:

```text
.env.example
```

Then run the development server:

```bash
npm run dev
```

---

## 4. Web Login

Navigate to:

```text
wren-login-web/
```

Create the configuration file from:

```text
config.example.js
```

Set the backend API URL and serve/deploy the static application.

---

# 🔄 CI / CD

Numination uses **GitHub Actions** for automated builds.

The workflow is located at:

```text
.github/workflows/build.yml
```

The CI pipeline validates the main components of the project.

```text
Git Push
   │
   ▼
GitHub Actions
   │
   ├───────────────┐
   │               │
   ▼               ▼
Android Build   Backend Build
   │               │
   └───────┬───────┘
           │
           ▼
        Results
```

### Automated checks

* Android build
* Backend build
* Dependency validation
* Build failures reporting

---

# 📦 Releases

The recommended distribution method for Numination is through **GitHub Releases**.

Users can obtain Android builds from the release assets when releases are published.

```text
GitHub
   │
   ▼
Release
   │
   ▼
Android APK / Build
   │
   ▼
Install
```

---

# 🧪 Development Workflow

Numination follows a development workflow centered around continuous iteration.

```text
PLAN
  ↓
BUILD
  ↓
TEST
  ↓
DEBUG
  ↓
IMPROVE
  ↓
COMMIT
  ↓
CI
  ↓
DEPLOY
```

The project is actively evolving, with Android, backend, authentication and infrastructure components being developed together.

---

# 🗺️ Roadmap

> The roadmap is continuously evolving as Numination develops.

### Android

* [x] Native Android application
* [x] Jetpack Compose UI
* [x] Material 3
* [x] Workspace
* [x] File explorer
* [x] Authentication
* [x] AI development screens
* [ ] Expanded development tooling
* [ ] Improved project management
* [ ] More AI workflows

### Backend

* [x] Next.js API
* [x] Prisma integration
* [x] MySQL integration
* [x] Authentication integration
* [x] Profile synchronization
* [ ] Expanded API capabilities
* [ ] Additional developer services

### Web

* [x] Web login
* [x] Backend integration
* [x] Vercel deployment
* [x] Authentication flow
* [x] Expanded browser functionality

---

# 📊 Project Statistics

<div align="center">

</div>

---

# 🧩 Tech Stack

```text
┌───────────────────────────────────────────────┐
│                    CLIENT                     │
├───────────────────────────────────────────────┤
│ Kotlin                                        │
│ Jetpack Compose                               │
│ Material 3                                    │
│ Android SDK                                   │
└───────────────────────────────────────────────┘

┌───────────────────────────────────────────────┐
│                   BACKEND                     │
├───────────────────────────────────────────────┤
│ Next.js                                       │
│ TypeScript                                    │
│ Prisma                                        │
│ MySQL                                         │
└───────────────────────────────────────────────┘

┌───────────────────────────────────────────────┐
│                AUTH / CLOUD                   │
├───────────────────────────────────────────────┤
│ Supabase                                      │
│ Authentication                                │
│ Session Management                            │
└───────────────────────────────────────────────┘

┌───────────────────────────────────────────────┐
│                  TOOLING                      │
├───────────────────────────────────────────────┤
│ Git                                           │
│ GitHub                                        │
│ GitHub Actions                                │
│ Android Studio                                │
│ Vercel                                        │
└───────────────────────────────────────────────┘
```

---

# 👥 Contributors

Numination is built by contributors working across the Android, backend and web ecosystem.

<a href="[https://github.com/kraqinc](https://github.com/kraqinc)">
  <img src="[https://avatars.githubusercontent.com/u/275528312?v=4](https://avatars.githubusercontent.com/u/275528312?v=4)" width="80px;" alt="kraqinc"/>
</a>
<a href="[https://github.com/alvaronegrito230-blip](https://github.com/alvaronegrito230-blip)">
  <img src="[https://avatars.githubusercontent.com/u/301766768?v=4](https://avatars.githubusercontent.com/u/301766768?v=4)" width="80px;" alt="alvaronegrito230-blip"/>
</a>

---

# 🤝 Contributing

Contributions, ideas and improvements are welcome.

Before submitting a change:

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Test the affected component.
5. Commit your changes.
6. Open a pull request.

Example:

```bash
git checkout -b feature/my-feature
```

```bash
git add .
git commit -m "feat: add my feature"
```

```bash
git push origin feature/my-feature
```

Then open a Pull Request.

---

# 🔒 Security

Do not commit:

```text
.env
.env.local
API keys
Database credentials
Private tokens
Service-role keys
Production secrets
```

Use environment variables and the provided example configuration files.

If you discover a security issue, please report it privately rather than publishing sensitive details in a public issue.

---

# 📄 License

Numination is released under the **MIT License**.

See [`LICENSE`](LICENSE) for the complete license text.

---

# 🌐 Links

**Repository**

[https://github.com/kraqinc/Numination](https://github.com/kraqinc/Numination)

**Website / Waitlist**

[https://numination-swart.vercel.app/#waitlist](https://numination-swart.vercel.app/#waitlist)

**Releases**

[https://github.com/kraqinc/Numination/releases](https://github.com/kraqinc/Numination/releases)

**Issues**

[https://github.com/kraqinc/Numination/issues](https://github.com/kraqinc/Numination/issues)

---

<div align="center">

# ⚡ NUMINATION

### Your development environment. Anywhere.

Built with **Kotlin · Jetpack Compose · Next.js · Prisma · MySQL · Supabase**

<br>

**Code. Create. Build. Ship.**

<br>

</div>
