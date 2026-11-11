# Lop-Client Architecture & Rules

## Background
Migrate Lop-Bot (Termux/Baileys Node.js) to secure, user-friendly Mobile/Desktop app.

## Goals
1. Code security (server-side protection, zero bot code on client).
2. User-friendly (no CLI/Termux, simple UI).
3. GitHub distribution (Lop-Client).

## User Flow
1. Auth: Google Login required.
2. Token: Input exclusive token (1 token = 1 Google account, managed by admin).
3. Pairing: Input WhatsApp number -> get pairing code from backend -> link device.
4. Main Menu: Built-in features, Custom features, Custom prefix settings.
5. Admin Panel: Protected by Admin Google Account. Generate, reset, delete, list tokens.

## Tech Stack & Architecture
- Frontend: Flutter (Cross-platform Mobile/Desktop UI).
- Backend & Baileys Runner: Node.js + Express + Baileys multi-session runner hosted on VPS/Cloud. Bot runs 24/7 on server.
- Database: Supabase / PostgreSQL (Google Auth mapping, Token validation, Session storage).
- Connection Flow: Client requests pairing -> Backend generates Baileys pairing code -> Client displays code -> User links WhatsApp -> Session persisted on server.
