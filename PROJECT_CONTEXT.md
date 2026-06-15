# Family Digital Heritage Vault - Project Context

## Overview
A mobile-first application for securely storing, organizing, and passing down family memories and inheritance content across generations.

## Technology Stack

### Backend
- **Runtime**: Node.js 18+ with Express 4
- **Database**: Supabase PostgreSQL
- **Authentication**: Supabase Auth (migrated from Firebase)
- **Storage**: Supabase Storage for media files
- **APIs**: RESTful endpoints

### Mobile (Flutter)
- **Framework**: Flutter 3 / Dart 3
- **State Management**: Provider
- **Auth**: supabase_flutter
- **Storage**: flutter_secure_storage, local_auth for biometrics
- **Image Picker**: image_picker

## Database Schema

### Tables
1. **users** - id, supabase_uid, email, display_name, created_at
2. **families** - id, name, created_by, created_at
3. **family_members** - id, family_id, user_id, role (ADMIN/ADULT/JUNIOR), invited_email
4. **family_tree_nodes** - id, family_id, user_id, full_name, birth_date, death_date, metadata
5. **family_relationships** - id, family_id, from_node_id, to_node_id, type (PARENT/CHILD/SPOUSE)
6. **memories** - id, family_id, created_by, title, description, media_type, storage_path, event, event_date, tags
7. **memory_people_tags** - id, memory_id, node_id
8. **inheritance_rules** - id, memory_id, family_id, beneficiary_node_id, condition_type, unlock_date, unlock_age

## User Roles
- **ADMIN**: Full control - manage members, tree, inheritance rules
- **ADULT**: Can upload, view memories, manage tree nodes
- **JUNIOR**: Limited access, inheritance rules apply

## Functional Requirements (Use Cases)

### UC-1: Register & Create Family Vault
- User signs up with full name, email, password
- Email verification
- Create initial family vault
- User becomes ADMIN

### UC-2: Login
- Email/password login
- Biometric login support
- Session management

### UC-3: Add Family Member to Tree
- Admin/Adult adds member (name, DOB, gender, relation)
- Define relationship (parent/child/spouse)
- Optional: invite via email

### UC-4: View Family Tree
- Visual tree display
- Filter by generation (All, 1st Gen, 2nd Gen, 3rd Gen)
- Search family members
- Tap node for profile

### UC-5: Upload Memory
- Select media type (photo/video/audio/text)
- Add title, description, date, tags
- Tag family members
- Associate with events
- Upload to Supabase Storage

### UC-6: View Memory with Access Control
- List memories with thumbnails
- Inheritance rules enforced
- Filter by type, date, member

### UC-7: Configure Inheritance Rules
- Set beneficiary from family tree
- Condition types: UNLOCK_AT_DATE, UNLOCK_AT_AGE
- Admin only

### UC-8: Search & Filter Memories
- Keyword search
- Filter by date, member, type, tags

### UC-9: Edit Profile & Biometric Login
- Update display name, avatar
- Enable/disable biometric login

## UI Screens (from Mockups)

### 1. Welcome/Landing Screen
- App title: "Family Digital Heritage Vault"
- Tagline: "Preserve memories. Connect generations. Secure your legacy forever."
- Family image placeholder
- "Get Started" button (purple)
- "Login" button (black)

### 2. Sign Up Screen
- Header: "Create Account" / "Join your family vault"
- Form fields: Full Name, Email, Password, Confirm Password
- "Sign Up" button
- "Already have an account? Login" link

### 3. Login Screen
- Header: "Create Your Heritage Vault"
- Logo with green icon
- Tagline: "Start preserving your family memories"
- Form: Email, Password
- "Sign Up" button
- "Already have an account? Login" link

### 4. Home/Dashboard
- Header: "Welcome Back [Name]" with avatar and notification bell
- Stats cards: Memories count, Members count, Events count
- Quick Actions grid: Tree, Add, Gallery, Profile
- Recent Memories list with thumbnails
- Bottom navigation: Home, Search, Alerts/Profile

### 5. Family Tree Screen
- Header: "Family Tree"
- Subtitle: "Your Family Heritage"
- Search bar: "Search family member..."
- Generation filter chips: All, 1st Gen, 2nd Gen, 3rd Gen
- Member cards in grid:
  - Avatar circle with initial
  - Name below
  - Generation/relationship label
  - Heart icon for favorites
- FAB: Add member
- Bottom navigation: Home, Tree, Profile

### 6. Memories Gallery Screen
- Header: "Memories"
- Subtitle: "Your Family Memories"
- Search bar: "Search memories..."
- Filter chips: All, Photos, Videos, Audio, Text
- Memory cards in grid:
  - Thumbnail image
  - Title overlay at bottom
- FAB: Add memory (purple)
- Bottom navigation: Home, Search, Profile

### 7. Profile Screen
- User info display
- Settings options
- Logout

## Color Scheme (from Mockups)
- **Primary**: Purple (#7C3AED - violet-600)
- **Secondary**: Blue gradient to purple
- **Accent**: Green (#10B981) for logo
- **Background**: White/Light gray
- **Cards**: White with subtle shadows
- **Text**: Dark gray/black

## API Endpoints

### Health
- GET /health

### Families
- POST /api/families - Create family vault
- GET /api/families - List user's families
- POST /api/families/:familyId/invite - Invite member

### Family Tree
- POST /api/family-tree/:familyId/nodes - Create/update node
- DELETE /api/family-tree/:familyId/nodes/:nodeId - Delete node
- POST /api/family-tree/:familyId/relationships - Create relationship
- GET /api/family-tree/:familyId - Get full tree

### Memories
- POST /api/memories - Create memory
- GET /api/memories?familyId=<id> - List memories
- GET /api/memories/:memoryId - Get memory (inheritance enforced)
- POST /api/memories/:memoryId/inheritance-rules - Set rules

## Current Implementation Status

### Backend (Partially Complete)
- [x] Express server setup
- [x] Supabase client configuration
- [x] Database schema (initSchema.js)
- [x] Route files exist (families, memories, familyTree)
- [x] Middleware files (auth, role, inheritance)
- [ ] Auth middleware needs Supabase Auth update (currently Firebase)

### Mobile (Skeleton Only)
- [x] Project structure
- [x] Supabase initialization
- [x] AuthProvider with Supabase Auth
- [x] Basic Login/Register screens (functional but not styled)
- [x] Basic Dashboard (placeholder tiles)
- [x] Family Tree screen (placeholder)
- [x] Memory Upload screen (partial - no API integration)
- [x] Memory Viewer screen (placeholder)
- [ ] UI doesn't match mockups
- [ ] No API service layer
- [ ] No family management UI
- [ ] No bottom navigation
- [ ] No search/filter functionality

## Implementation Priority

### Phase 1: Core Infrastructure
1. Fix backend auth for Supabase
2. Create API service layer in Flutter
3. Implement proper routing with bottom nav

### Phase 2: Authentication & Onboarding
1. Welcome/Landing screen
2. Styled Login screen
3. Styled Register screen with full name

### Phase 3: Home & Navigation
1. Home dashboard with stats
2. Quick actions
3. Recent memories

### Phase 4: Family Tree
1. Tree screen with search/filter
2. Member cards
3. Add/edit member
4. Relationships

### Phase 5: Memories
1. Gallery screen with grid
2. Memory upload with Supabase Storage
3. Memory detail view
4. Search and filters

### Phase 6: Advanced Features
1. Profile screen
2. Inheritance rules UI
3. Notifications

## Supabase Configuration
- URL: https://pybpgzicwwktrwwphmzq.supabase.co
- Storage bucket: "memories" (needs to be created)

## File Structure

### Backend
```
backend/
  src/
    app.js
    server.js
    config/
      env.js
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

### Mobile
```
mobile/
  lib/
    main.dart
    src/
      app.dart
      core/
        config/
          supabase_config.dart
        theme/
          app_theme.dart
        services/           # TO CREATE
          api_service.dart
      features/
        auth/
          state/
            auth_provider.dart
          presentation/
            login_screen.dart
            register_screen.dart
            welcome_screen.dart  # TO CREATE
        dashboard/
          presentation/
            dashboard_screen.dart  # TO REDESIGN
        family_tree/
          state/                   # TO CREATE
            family_tree_provider.dart
          presentation/
            family_tree_screen.dart  # TO REDESIGN
            add_member_screen.dart   # TO CREATE
        memories/
          state/                   # TO CREATE
            memories_provider.dart
          presentation/
            memory_upload_screen.dart  # TO UPDATE
            memory_viewer_screen.dart  # TO REDESIGN
            memory_detail_screen.dart  # TO CREATE
        profile/                  # TO CREATE
          presentation/
            profile_screen.dart
```
