# Numination

<p align="center">
  <strong>AI · Workspace · Shell</strong>
</p>

<p align="center">
  <em>The AI for people who solve problems.</em>
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="#development">Development</a> •
  <a href="#team">Team</a>
</p>

---

## Overview

**Numination** is an AI-powered development workspace designed to help people build, debug, manage and understand software from one unified environment.

Instead of forcing developers to jump between an editor, terminal, AI assistant, project manager and other tools, Numination brings these workflows together into a single workspace.

> **Numi is the key.**

Numination is being built around one simple idea:

**AI should not just generate code. It should understand the workspace, the project, the problems and the developer's intent.**

---

## Why Numination?

Modern AI coding tools are powerful, but development is still fragmented.

You may need:

* An IDE for your code
* A terminal for commands
* An AI assistant for debugging
* A separate place for project memory
* Another interface for credits and billing
* Different tools for authentication and project management

Numination aims to bring these experiences together.

### One workspace. One AI. One context.

---

## Features

### AI Workspace

A centralized AI workspace for interacting with your projects, files and development environment.

Numination is designed to understand more than an individual prompt. It is intended to work with project context, files, structure and developer intent.

### Intelligent Chat

A dedicated AI chat experience for:

* Code generation
* Debugging
* Explanations
* Refactoring
* Architecture decisions
* Project questions
* Development assistance

### Projects

Projects provide the foundation for organizing development work inside Numination.

The project experience is designed around a simple workflow:

```text
Create Project
      ↓
Open Workspace
      ↓
Work with Numi
      ↓
Build · Debug · Improve
```

### Terminal

A built-in terminal experience designed to keep command-line workflows close to the rest of the workspace.

### Memory

Numination is being designed with persistent project-aware memory so the AI can maintain useful context instead of treating every conversation as completely isolated.

### Credits

A credit system provides the foundation for tracking AI usage and future usage-based features.

### Authentication

Numination is designed around modern authentication with support for:

* Google
* GitHub
* Secure authentication flows
* Persistent user profiles

### Profile

User profiles provide a central place for account information and personalization.

### Settings

A dedicated settings system allows Numination to manage application preferences, account configuration and future customization options.

---

## Product Vision

Numination is more than an AI chatbot inside an editor.

The long-term goal is to create an **AI-native development environment** where the AI understands the entire workflow.

Instead of:

```text
Developer → Tool → AI → Tool → Terminal → Tool
```

Numination aims for:

```text
Developer
    ↓
Numination
    ↓
AI understands the workspace
    ↓
Build · Debug · Run · Manage
```

The AI becomes part of the environment rather than another tab inside it.

---

## Architecture

Numination is evolving toward a modern cross-platform architecture.

### Client

The application is being built with **Flutter**, providing a flexible foundation for a modern desktop and mobile-oriented interface.

Core application areas include:

```text
lib/
├── core/
├── features/
├── screens/
├── services/
├── state/
└── main.dart
```

The application integrates services such as authentication, environment configuration, state management and backend communication.

#### Current UI Areas

```text
Chat
Credits
Home
Memory
Owner
Terminal
Workspace
Settings
Profile
```

### Backend

Numination is moving toward a **Supabase-centered backend architecture**.

The backend is designed to support:

* Authentication
* User profiles
* Credits
* Payments
* Subscriptions
* AI APIs
* Project-related services
* Secure server-side operations

Supabase provides the foundation for authentication, database services and backend infrastructure.

### Data Layer

The project is designed around structured application data such as:

```text
profiles
credits
payments
subscriptions
```

Additional project, memory and workspace data can evolve as the platform grows.

---

## Technology

Numination explores a modern development stack including:

**Client**
* Flutter
* Dart
* Riverpod
* Supabase Flutter
* flutter_dotenv

**Backend**
* Supabase
* PostgreSQL
* Server-side APIs
* Edge/server functions
* Authentication services

**Development**
* Git
* GitHub
* GitHub Actions
* VS Code
* Linux
* Android tooling

The stack may evolve as Numination's architecture matures.

---

## Repository Structure

A simplified view of the project:

```text
Numination/
├── android/
├── ios/
├── lib/
│   ├── core/
│   ├── features/
│   ├── screens/
│   ├── services/
│   └── main.dart
├── assets/
├── test/
├── .github/
│   └── workflows/
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

The backend is maintained separately from the client application as the architecture evolves.

---

## Design Philosophy

Numination follows a modern, focused interface philosophy.

The goal is to make the application feel:

* Fast
* Clean
* Technical
* Minimal
* Professional
* AI-native

The visual language is inspired by modern developer environments and productivity software, while maintaining its own identity.

The interface should stay focused on the work instead of overwhelming the user with unnecessary UI.

---

## Roadmap

Numination is an actively evolving project.

### Phase 1 — Foundation

- [x] Project foundation
- [x] Authentication architecture
- [x] User profiles
- [x] Credits system foundation
- [x] Core navigation
- [x] Initial workspace architecture
- [x] AI chat foundation
- [x] Terminal concept
- [x] Memory concept

### Phase 2 — Workspace

- [ ] Complete project management
- [ ] Improved workspace navigation
- [ ] File/project context
- [ ] Persistent AI context
- [ ] Better terminal integration
- [ ] Workspace state persistence

### Phase 3 — Numi

- [ ] Strong project awareness
- [ ] Context-aware AI responses
- [ ] Codebase understanding
- [ ] Multi-file reasoning
- [ ] Smarter debugging
- [ ] Automated development workflows

### Phase 4 — Platform

- [ ] Production backend
- [ ] Payments
- [ ] Subscriptions
- [ ] Advanced credits
- [ ] Usage analytics
- [ ] More integrations
- [ ] Expanded platform support

### Phase 5 — AI-Native Development

The long-term objective is to make Numination feel less like an IDE with AI and more like a **development environment designed around AI from the beginning**.

---

## Development

### Requirements

Recommended development environment:

```text
Flutter SDK
Dart SDK
Git
VS Code
Android SDK (for Android builds)
```

A recent Flutter version is recommended.

Verify your environment:

```bash
flutter doctor
```

### Clone

```bash
git clone https://github.com/kraqinc/Numination.git
cd Numination
```

### Links

* Website: [numinationinfo.vercel.app](https://numinationinfo.vercel.app/)
* Repository: [github.com/kraqinc/Numination](https://github.com/kraqinc/Numination)

Install dependencies:

```bash
flutter pub get
```

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Run the application:

```bash
flutter run
```

---

## Environment

Numination uses environment-based configuration for services and secrets.

Create a local environment file when required by the current project configuration:

```text
.env
```

Never commit secrets, private keys or production credentials.

A typical configuration may include values such as:

```env
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
API_BASE_URL=
```

Use the project's current environment configuration as the source of truth when adding new variables.

---

## CI/CD

Numination uses GitHub as the primary source-control platform and is designed to make use of automated workflows through **GitHub Actions**.

Typical CI responsibilities include:

```text
Checkout
   ↓
Install dependencies
   ↓
Static analysis
   ↓
Tests
   ↓
Build
```

This keeps builds reproducible and reduces the need for local build environments.

---

## Security

Security is a core part of Numination's architecture.

Sensitive credentials should never be committed to the repository.

Production secrets should be stored through the appropriate secret-management system, such as:

* GitHub Actions Secrets
* Supabase configuration
* Secure server-side environment variables

Authentication and privileged operations should remain server-side whenever possible.

---

## Project Status

> **Numination is under active development.**

The architecture is evolving rapidly as the project moves toward a more complete AI-native workspace.

Some features, APIs and internal structures may change without notice while the platform is being developed.

---

## Contributing

Contributions, ideas and technical discussions are welcome.

Before making large architectural changes, consider the project's current direction and avoid introducing unnecessary complexity.

A good contribution should aim to improve at least one of:

```text
Performance
Reliability
Developer Experience
User Experience
Architecture
AI Capabilities
```

---

## Team

Numination is created and maintained by:

* [**kraqinc**](https://github.com/kraqinc)
* [**alvaronegrito230-blip**](https://github.com/alvaronegrito230-blip)

---

## Philosophy

Numination is built around a simple principle:

> **Tools should adapt to the developer, not the other way around.**

AI should understand what you are building, why you are building it and what needs to happen next.

That is the purpose of Numi.

---

## License

License information will be added as the project reaches its release stage.

---

<p align="center">
  <strong>Numination</strong>
  <br>
  AI · Workspace · Shell
  <br><br>
  <em>The AI for people who solve problems.</em>
</p>
