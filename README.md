# ⚡ Numination

### A pocket-sized AI IDE for real development work.

<div align="center">

![Numination](https://img.shields.io/badge/Numination-AI%20IDE-7C3AED?style=for-the-badge\&logo=android\&logoColor=white)
![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=for-the-badge\&logo=kotlin\&logoColor=white)
![Jetpack Compose](https://img.shields.io/badge/Jetpack%20Compose-4285F4?style=for-the-badge\&logo=jetpackcompose\&logoColor=white)
![Material 3](https://img.shields.io/badge/Material%203-6750A4?style=for-the-badge\&logo=materialdesign\&logoColor=white)
![Next.js](https://img.shields.io/badge/Next.js-000000?style=for-the-badge\&logo=next.js\&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge\&logo=typescript\&logoColor=white)
![Prisma](https://img.shields.io/badge/Prisma-2D3748?style=for-the-badge\&logo=prisma\&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge\&logo=supabase\&logoColor=white)

**Build. Code. Create. Anywhere.**

</div>

---

## 🧠 What is Numination?

**Numination** is a native Android IDE built for developers who want a powerful development environment directly on their mobile device.

It combines a real project workspace, file explorer, AI-assisted development, authentication, cloud infrastructure and developer-focused tools into one Android experience.

Numination isn't designed to be just another code editor.

It is designed to become a **portable development environment**.

---

## ✨ Core Features

### 📱 Native Android IDE

Built from the ground up for Android using modern native technologies.

* Kotlin
* Jetpack Compose
* Material 3
* Native Android architecture
* Modern UI
* Mobile-first development experience

### 🤖 AI Agent

AI is integrated directly into the development experience.

* AI-assisted development
* Context-aware workflows
* Project interaction
* Development assistance
* Intelligent coding workflows
* AI-powered developer tools

### 📂 Project Workspace

A complete workspace designed around real development projects.

* Project management
* File explorer
* Workspace navigation
* File operations
* Project context
* Development environment

### 🔐 Authentication

Numination includes a complete account and authentication system.

* Email authentication
* Google authentication
* Session management
* Profile synchronization
* Supabase integration
* Secure authentication flows

### 💳 Credits & Pro

Numination includes infrastructure for account-based usage and premium functionality.

* User credits
* Pro functionality
* Billing infrastructure
* Account management
* Owner functionality

---

# 🏗️ Architecture

Numination is organized into independent layers that work together as one ecosystem.

```text
                         ┌────────────────────────┐
                         │        NUMINATION      │
                         │      Android Client    │
                         └────────────┬───────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
             ┌────────────┐    ┌────────────┐    ┌────────────┐
             │ Workspace  │    │ AI Agent   │    │   Auth     │
             │            │    │            │    │            │
             │ Files      │    │ AI Tools   │    │ Sessions   │
             │ Projects   │    │ Context    │    │ Profiles   │
             └──────┬─────┘    └──────┬─────┘    └──────┬─────┘
                    │                 │                 │
                    └─────────────────┼─────────────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │      BACKEND API       │
                         │                        │
                         │       Next.js          │
                         │       TypeScript       │
                         │       Prisma           │
                         └────────────┬───────────┘
                                      │
                         ┌────────────┴────────────┐
                         │                         │
                         ▼                         ▼
                  ┌─────────────┐          ┌──────────────┐
                  │    MySQL    │          │   Supabase   │
                  │             │          │              │
                  │ Application │          │ Auth         │
                  │ Data        │          │ Sessions     │
                  └─────────────┘          │ Profiles     │
                                           └──────────────┘
```

---

# 📁 Repository Structure

```text
Numination/
│
├── android/
│   ├── app/
│   ├── gradle/
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradlew
│
├── backend/
│   ├── app/
│   ├── prisma/
│   ├── public/
│   ├── package.json
│   ├── next.config.*
│   └── .env.example
│
├── supabase/
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

The Android application is the heart of Numination.

Built using **Kotlin, Jetpack Compose and Material 3**, it provides the native interface for the entire development experience.

### Android stack

| Technology      | Role                 |
| --------------- | -------------------- |
| Kotlin          | Application language |
| Jetpack Compose | UI framework         |
| Material 3      | Design system        |
| Android SDK     | Native platform      |
| Gradle          | Build system         |

### Android modules & experiences

* Workspace
* File explorer
* Project navigation
* AI development screens
* Authentication
* Session management
* Credits
* Pro functionality
* Owner screens
* Storage permissions
* Native UI

---

# 🤖 AI Development

Numination places AI directly inside the development workflow.

Rather than forcing developers to constantly switch between an IDE and an external AI assistant, Numination is designed around an integrated AI experience.

```text
              Developer
                  │
                  ▼
             ┌──────────┐
             │ Project  │
             └────┬─────┘
                  │
          ┌───────┼────────┐
          │       │        │
          ▼       ▼        ▼
        Files   Context  Workspace
          │       │        │
          └───────┼────────┘
                  │
                  ▼
             ┌──────────┐
             │ AI Agent │
             └────┬─────┘
                  │
                  ▼
        AI-Assisted Development
```

The objective is simple:

> **Make AI part of the development environment, not a separate destination.**

---

# 🧩 Workspace

The Numination workspace is designed around real development projects.

Developers can work with project structures, navigate files and interact with their development environment from the Android application.

### Workspace capabilities

* Project navigation
* File explorer
* File management
* Workspace context
* Development screens
* Project-aware workflows

---

# 🔐 Authentication

Authentication is an important part of the Numination ecosystem.

The project uses **Supabase** to support account and session functionality while maintaining synchronization with the application backend.

### Authentication capabilities

* Email sign-in
* Google sign-in
* Session handling
* Profile synchronization
* Authentication state
* Account management

```text
User
 │
 ▼
Authentication
 │
 ▼
Supabase
 │
 ├── Session
 ├── Identity
 └── Profile
 │
 ▼
Numination
 │
 ▼
Backend
```

---

# ☁️ Backend

Numination's backend provides the API and server-side infrastructure required by the application.

### Backend stack

```text
Next.js 14
TypeScript
Prisma 5
MySQL
```

The backend handles application services, persistent data, account synchronization and other server-side functionality.

### Backend responsibilities

* API endpoints
* User data
* Authentication integration
* Profile synchronization
* Application data
* Credits
* Pro functionality
* Billing infrastructure
* AI-related services
* Database operations

---

# 🗄️ Database

Numination uses **Prisma** as its ORM and **MySQL** as its primary application database.

```text
┌─────────────────┐
│ Android Client  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Next.js      │
│      API        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Prisma      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│      MySQL      │
└─────────────────┘
```

This structure provides a typed and structured layer between the application services and persistent data.

---

# 💳 Numination Pro

Numination includes infrastructure for premium functionality.

The system is designed around account-level capabilities and usage.

```text
User
 │
 ▼
Account
 │
 ├── Credits
 ├── Plan
 └── Features
       │
       ▼
  Numination Pro
```

The backend validates account and billing-related state before granting protected functionality.

---

# ⚙️ Configuration

Sensitive configuration should never be committed to the repository.

Numination provides example configuration files such as:

```text
.env.example
backend/.env.example
```

Environment variables may contain:

* Database credentials
* Authentication configuration
* API keys
* Service credentials
* Application secrets

**Never commit production secrets.**

---

# 🔄 CI / CD

Numination uses **GitHub Actions** to automatically validate the project.

Workflow:

```text
                    Git Push
                       │
                       ▼
               ┌──────────────┐
               │ GitHub Action│
               └───────┬──────┘
                       │
              ┌────────┴────────┐
              │                 │
              ▼                 ▼
       Android Build      Backend Build
              │                 │
              └────────┬────────┘
                       │
                       ▼
                   CI Result
```

### Automated checks

* Android build
* Backend build
* Dependency validation
* Build verification

---

# 📦 Releases

Numination distributes Android builds through **GitHub Releases**.

Release assets can contain installable Android builds and other project artifacts.

The release workflow allows users to obtain specific versions of Numination without needing to build the application themselves.

---

# 🧪 Development Philosophy

Numination is continuously evolving.

The development process follows an iterative cycle:

```text
IDEA
 │
 ▼
DESIGN
 │
 ▼
BUILD
 │
 ▼
TEST
 │
 ▼
DEBUG
 │
 ▼
IMPROVE
 │
 ▼
RELEASE
 │
 └──────────────► REPEAT
```

Every iteration is an opportunity to improve the developer experience.

---

# 🗺️ Roadmap

## Android

* [x] Native Android application
* [x] Kotlin
* [x] Jetpack Compose
* [x] Material 3
* [x] Workspace
* [x] File explorer
* [x] Authentication
* [x] AI development experience
* [x] Session management
* [x] Credits system
* [x] Owner functionality
* [ ] Expanded development tooling
* [ ] More advanced AI workflows
* [ ] Improved project management

## Backend

* [x] Next.js API
* [x] TypeScript
* [x] Prisma
* [x] MySQL
* [x] Authentication integration
* [x] Profile synchronization
* [x] Credits infrastructure
* [x] Pro billing infrastructure
* [ ] Expanded API services
* [ ] Additional developer functionality

## Infrastructure

* [x] Supabase integration
* [x] GitHub Actions
* [x] Automated Android builds
* [x] Automated backend builds
* [ ] Expanded CI/CD automation

---

# 🧰 Technology Stack

<div align="center">

### Android

![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square\&logo=kotlin\&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=flat-square\&logo=android\&logoColor=white)
![Jetpack Compose](https://img.shields.io/badge/Jetpack%20Compose-4285F4?style=flat-square\&logo=jetpackcompose\&logoColor=white)
![Material 3](https://img.shields.io/badge/Material%203-6750A4?style=flat-square\&logo=materialdesign\&logoColor=white)

### Backend

![Next.js](https://img.shields.io/badge/Next.js-000000?style=flat-square\&logo=next.js\&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat-square\&logo=typescript\&logoColor=white)
![Prisma](https://img.shields.io/badge/Prisma-2D3748?style=flat-square\&logo=prisma\&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat-square\&logo=mysql\&logoColor=white)

### Infrastructure

![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=flat-square\&logo=supabase\&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat-square\&logo=githubactions\&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=flat-square\&logo=git\&logoColor=white)

</div>

---

# 👥 Contributors

Numination is built by contributors working across the Android application, backend and infrastructure.

<div align="center">

<a href="https://github.com/kraqinc">
<img src="https://avatars.githubusercontent.com/u/275528312?v=4" width="80px" alt="kraqinc"/>
</a>

<a href="https://github.com/alvaronegrito230-blip">
<img src="https://avatars.githubusercontent.com/u/301766768?v=4" width="80px" alt="alvaronegrito230-blip"/>
</a>

</div>

---

# 🔒 Security

Security-sensitive information must remain outside the repository.

Never commit:

```text
.env
.env.local
API keys
Database passwords
Private tokens
Service-role keys
Production credentials
Authentication secrets
```

Use environment variables for sensitive configuration.

If you discover a security vulnerability, please report it privately rather than publicly exposing sensitive information.

---

# 📄 License

Numination is released under the **MIT License**.

See [`LICENSE`](LICENSE) for the complete license.

---

# 🌐 Numination

<div align="center">

# ⚡ NUMINATION

### The pocket-sized AI IDE for real development work.

**Kotlin · Jetpack Compose · Material 3 · Next.js · TypeScript · Prisma · MySQL · Supabase**

<br>

[![GitHub](https://img.shields.io/badge/Numination-GitHub-181717?style=for-the-badge\&logo=github\&logoColor=white)](https://github.com/kraqinc/Numination)

[![Website](https://img.shields.io/badge/Numination-Website-7C3AED?style=for-the-badge\&logo=googlechrome\&logoColor=white)](https://numination-swart.vercel.app/)

<br>

**Build. Code. Create. Anywhere.**

</div>
