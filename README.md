# Family Digital Heritage Vault

Family Digital Heritage Vault is a mobile-first system for securely storing, organizing, and passing down family memories and inheritance content across generations.

This repository contains:
- `backend`: Node.js + Express REST API with Supabase and Firebase integration
- `mobile`: Flutter app (Android 8.0+) using Provider and clean-ish feature structure

## 1. Backend (Node.js + Express)

### 1.1. Tech stack

- Node.js 18+
- Express 4
- Supabase (PostgreSQL) via `@supabase/supabase-js` and `pg` for initial schema
- Firebase Admin SDK (Auth integration)
- JWT for internal API tokens
- Helmet, CORS, morgan for security and logging

### 1.2. Folder structure

```text
backend/
  package.json
  src/
    app.js
    server.js
    config/
      env.js
      firebaseAdmin.js
      supabaseClient.js
    db/
      initSchema.js
    middlewares/
      authMiddleware.js
      roleMiddleware.js
      inheritanceMiddleware.js
    routes/
      families.js
      memories.js
      familyTree.js
```

### 1.3. Environment variables

Copy `.env.example` to `.env` in the **repository root** (`family-digital-heritage-vault/.env`) and fill in your values. The backend loads this file automatically via `backend/src/config/env.js`.

For local development you can also use `backend/.env` (same keys); root `.env` is preferred so one file serves the whole project.

```bash
# Supabase (required)
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>

# Optional backend settings (defaults shown)
PORT=4000
NODE_ENV=development
CLIENT_BASE_URL=http://localhost:8080
JWT_SECRET=replace-with-strong-secret
SUPABASE_POSTGRES_CONNECTION_STRING=postgres://postgres:<password>@db.<hash>.supabase.co:5432/postgres

FIREBASE_PROJECT_ID=<firebase-project-id>
FIREBASE_CLIENT_EMAIL=<service-account-client-email>
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

> **Note**: On Windows PowerShell, store `FIREBASE_PRIVATE_KEY` in `.env` exactly as a single line; the app replaces `\\n` with real newlines at runtime.

> **Security**: `.env` is gitignored. Never commit real keys. Use the service role key only on the server, never in the Flutter app.

### 1.4. Install & run backend

```bash
cd backend
npm install

# Optional: run schema init standalone
npm run init:schema

# Dev
npm run dev

# Prod-style
npm start
```

On first start, `initSchema` will automatically create/update required tables in your Supabase Postgres using the connection string.

### 1.5. Core REST endpoints (summary)

- **Health**
  - `GET /health`

- **Families**
  - `POST /api/families`
    - Auth: Firebase or internal JWT
    - Body: `{ "name": "Qadeer Family" }`
    - Creates family vault, caller becomes `ADMIN`.
  - `GET /api/families`
    - Lists families the current user belongs to with role.
  - `POST /api/families/:familyId/invite`
    - Role: `ADMIN`
    - Body: `{ "email": "relative@example.com", "role": "ADMIN" | "ADULT" | "JUNIOR" }`
    - Records an invitation and sends an email via the email service.
    - **Roles mapped to UI**: Admin (ADMIN), Editor (ADULT), Viewer (JUNIOR).
  - `POST /api/invitations/accept`
    - Auth: Authenticated user.
    - Body: `{ "token": "<token>" }`
    - Verifies invitation, adds user to family with the selected role, and marks invite as accepted.

- **Family tree**
  - `POST /api/family-tree/:familyId/nodes`
    - Role: `ADMIN` or `ADULT`
    - Body (create): `{ "fullName": "Grandfather", "birthDate": "1950-01-01" }`
    - Body (update): `{ "id": "<node-id>", ... }`
  - `POST /api/family-tree/:familyId/relationships`
    - Role: `ADMIN` or `ADULT`
    - Body: `{ "fromNodeId": "<uuid>", "toNodeId": "<uuid>", "type": "PARENT" | "CHILD" | "SPOUSE" }`
  - `GET /api/family-tree/:familyId`
    - Role: any member
    - Returns `{ nodes, relationships }` for graph-based rendering.
  - `DELETE /api/family-tree/:familyId/nodes/:nodeId`
    - Role: `ADMIN`
    - Prevents deletion if node participates in any relationship (tree integrity).

- **Memories**
  - `POST /api/memories`
    - Role: `ADMIN` or `ADULT`
    - Body:
      ```json
      {
        "familyId": "<family-uuid>",
        "title": "Wedding Day",
        "description": "Photos from our wedding",
        "mediaType": "photo",
        "storagePath": "families/<id>/memories/<file>.jpg",
        "event": "Wedding",
        "eventDate": "2024-06-01",
        "tags": ["wedding", "parents"],
        "peopleNodeIds": ["<node-uuid-1>", "<node-uuid-2>"]
      }
      ```
    - Assumes the mobile app uploads media to Firebase Storage and passes the final `storagePath`.
  - `GET /api/memories?familyId=<id>`
    - Role: any member
    - Lists memories (metadata only).
  - `GET /api/memories/:memoryId`
    - Role: any member
    - Passes through **inheritance middleware** and returns metadata if allowed.

- **Inheritance rules (critical)**
  - `POST /api/memories/:memoryId/inheritance-rules`
    - Role: `ADMIN`
    - Body examples:
      - Unlock at date:
        ```json
        {
          "familyId": "<family-uuid>",
          "beneficiaryNodeId": "<node-uuid>",
          "conditionType": "UNLOCK_AT_DATE",
          "unlockDate": "2040-01-01"
        }
        ```
      - Unlock at age:
        ```json
        {
          "familyId": "<family-uuid>",
          "beneficiaryNodeId": "<node-uuid>",
          "conditionType": "UNLOCK_AT_AGE",
          "unlockAge": 18
        }
        ```

### 1.6. Authentication & security

- Mobile app authenticates via Firebase Authentication (email/password).
- Each API request sends `Authorization: Bearer <token>` where `<token>` is:
  - A Firebase ID token, or
  - An internal JWT issued by `issueInternalJwt` after verifying Firebase.
- `authMiddleware`:
  - Verifies Firebase ID token (or internal JWT).
  - Ensures a corresponding row exists in Supabase `users` (creates on first login).
  - Attaches `req.auth.user` (local user) and `req.auth.firebaseUser`.
- `requireFamilyRole([...])`:
  - Looks up `family_members` for current user + family.
  - Blocks calls if user is not a member or role is insufficient.

### 1.7. Inheritance engine middleware (key logic)

- `enforceInheritanceRules()` is applied to memory access routes (e.g. `GET /api/memories/:memoryId`).
- `enrichMemoriesWithInheritance()` handles list view visibility and locking logic.
- **Privacy & Locked Folder**:
  - If a memory has inheritance rules, it is **hidden** from family members who are not beneficiaries (unless they are `ADMIN` or the creator).
  - For beneficiaries, the memory appears in the "Locked" filter/folder.
  - It remains **locked** (metadata only, no media access) until the condition is met (e.g., a specific date or age).
  - Once the condition is met (e.g., the "selected date"), it becomes fully visible and accessible to the "selected person".
- Algorithm (simplified):
  1. Fetch memory and associated `inheritance_rules`.
  2. Resolve which `family_tree_nodes` belong to current user in that family.
  3. If rules exist:
     - If user is not an `ADMIN`, the creator, or a beneficiary: Hide the memory.
     - If user is a beneficiary:
       - If `UNLOCK_AT_DATE`, deny if `now < unlock_date`.
       - If `UNLOCK_AT_AGE`, compute beneficiary age from `birth_date` and deny if `age < unlock_age`.
  4. If all applicable rules are satisfied, request proceeds to controller.

## 2. Mobile app (Flutter)

### 2.1. Tech stack

- Flutter 3 (Dart 3)
- Provider for state management
- Firebase:
  - `firebase_core`
  - `firebase_auth`
  - `firebase_storage`
  - `firebase_messaging`
- Security:
  - `flutter_secure_storage` for ID token
  - `local_auth` for biometric login (fingerprint/Face ID)

### 2.2. Folder structure

```text
mobile/
  pubspec.yaml
  lib/
    main.dart
    src/
      app.dart
      core/
        theme/app_theme.dart
      features/
        auth/
          state/auth_provider.dart
          presentation/
            login_screen.dart
            register_screen.dart
        dashboard/
          presentation/dashboard_screen.dart
        family_tree/
          presentation/family_tree_screen.dart
        memories/
          presentation/
            memory_upload_screen.dart
            memory_viewer_screen.dart
```

### 2.3. Install & run mobile app

```bash
cd mobile
flutter pub get
flutter run
```

You must configure your Android app with Firebase (using the Firebase console), add `google-services.json`, and make sure the `applicationId` matches your Firebase project.

### 2.4. Key UI flows

- **Login/Register**
  - `LoginScreen` uses `AuthProvider` to sign in with Firebase email/password.
  - Tokens are stored in `flutter_secure_storage` for API calls.
  - Biometric login uses `local_auth` to quickly re-open the app if the user is still authenticated with Firebase.
- **Dashboard**
  - `DashboardScreen` shows nav tiles:
    - Family Tree
    - Upload Memory
    - View Memories
- **Family Tree**
  - `FamilyTreeScreen` is a placeholder showing where an interactive graph-based tree would be rendered.
  - Backend endpoint `GET /api/family-tree/:familyId` returns raw graph data (`nodes`, `relationships`) to feed a canvas renderer.
- **Memories**
  - `MemoryUploadScreen`:
    - Simple form with title/description + image picker.
    - Placeholder stub for Firebase Storage upload and `/api/memories` call.
  - `MemoryViewerScreen`:
    - Placeholder list view that would call `/api/memories?familyId=<id>` and detail views hitting `/api/memories/:id` (inheritance-guarded).

## 3. Example API requests (Postman)

All authenticated requests require:

```http
Authorization: Bearer <firebase-id-token-or-internal-jwt>
Content-Type: application/json
```

### 3.1. Create family vault

```http
POST http://localhost:4000/api/families
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Qadeer Family Vault"
}
```

### 3.2. Create a family member invite

```http
POST http://localhost:4000/api/families/<family-id>/invite
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "email": "uncle@example.com",
  "role": "ADULT"
}
```

### 3.3. Create a tree node

```http
POST http://localhost:4000/api/family-tree/<family-id>/nodes
Authorization: Bearer <token>
Content-Type: application/json

{
  "fullName": "Grandfather",
  "birthDate": "1950-01-01"
}
```

### 3.4. Create a memory metadata entry

```http
POST http://localhost:4000/api/memories
Authorization: Bearer <token>
Content-Type: application/json

{
  "familyId": "<family-id>",
  "title": "Graduation Day",
  "description": "Photos and video from my graduation.",
  "mediaType": "photo",
  "storagePath": "families/<family-id>/memories/graduation-2024.jpg",
  "event": "Graduation",
  "eventDate": "2024-06-01",
  "tags": ["graduation", "college"],
  "peopleNodeIds": ["<node-id-1>"]
}
```

### 3.5. Create an inheritance rule (unlock at age)

```http
POST http://localhost:4000/api/memories/<memory-id>/inheritance-rules
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "familyId": "<family-id>",
  "beneficiaryNodeId": "<beneficiary-node-id>",
  "conditionType": "UNLOCK_AT_AGE",
  "unlockAge": 18
}
```

### 3.6. Read memory with inheritance enforcement

```http
GET http://localhost:4000/api/memories/<memory-id>
Authorization: Bearer <token>
```

If the beneficiary is not old enough or unlock date not reached, response will be `403` with explanatory message and details (`unlockDate` or `requiredAge`/`currentAge`).

## 4. Sample dummy data

You can seed basic data using Postman:

1. Register two Firebase users:
   - Parent (`parent@example.com`)
   - Child (`child@example.com`)
2. Using parent token:
   - Create family vault.
   - Create tree nodes: parent node and child node.
   - Link them with `PARENT`/`CHILD` relationships.
   - Create a memory (e.g. a video message).
   - Create an inheritance rule:
     - `conditionType: "UNLOCK_AT_AGE"`
     - `unlockAge: 18`
     - `beneficiaryNodeId`: child node ID.
3. Using child token:
   - Try to `GET /api/memories/<id>` before age 18 → expect **403**.
4. For testing, temporarily change `unlockAge` down (e.g. 5) and re-test → expect **200**.

This demonstrates the end-to-end inheritance engine working with real tokens, Supabase data, and the middleware logic.

## 5. Notes and next steps

- Hook the Flutter app’s HTTP client to the backend using the stored Firebase ID token for authorization.
- Implement Firebase Storage integration in `MemoryUploadScreen` to upload media and then call `/api/memories` with the resulting `storagePath`.
- Implement device registration with `firebase_messaging` and wire your own push notification backend or Firebase Cloud Functions to notify family members of new memories and inheritance unlocks.
