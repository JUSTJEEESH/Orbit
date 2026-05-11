# Orbit Architecture

## Architecture Pattern

- SwiftUI
- MVVM
- Clean Architecture
- Service-oriented
- Feature modular

---

# App Layers

## Presentation Layer
Views
ViewModels

## Domain Layer
Use Cases
Business Logic

## Data Layer
Repositories
Persistence
API Services

---

# Persistence

## Local
SwiftData

## Cloud
Firebase

---

# AI Layer

Services:
- AIClassificationService
- EmbeddingService
- SearchService
- TranscriptionService

All AI services must:
- be protocol driven
- be mockable
- support future local AI replacement

---

# Dependency Injection

Use protocol-based injection.

Avoid global singletons except:
- Logger
- App configuration

---

# Navigation

Use:
- NavigationStack
- strongly typed routes

Avoid:
- string-based routing

---

# Error Handling

Use:
- typed errors
- Result types
- user-friendly error states

Never:
- silently fail

---

# Performance Rules

- Lazy load heavy content
- Avoid unnecessary re-renders
- Keep ViewModels lightweight
- Optimize startup aggressively

---

# Testing

Must support:
- unit tests
- UI tests
- snapshot tests later