# AI Double Customer

A Flutter app covering the AI Double customer flow: chat list, archived
chats, the AI-guided intake conversation (per category), matched-professional
cards, professional profile with FAQs and reviews, save/bookmark,
chat-with-professional, and the booking flow (slot picker → confirmation →
hand-off to chat).

## Run it

```bash
flutter pub get
flutter run
```

Requires Flutter 3.19+ (Dart 3). Internet access is needed once, for
`flutter pub get` to fetch `provider` and `google_fonts`.

## Architecture — MVVM

```
lib/
  main.dart                        – app entry point: builds the repositories
                                      and hands them down via Provider
  theme/app_theme.dart             – colors & fonts, defined once globally —
                                      change a value here and the whole app
                                      picks it up (see "Theme & fonts" below)
  models/                          – Model: plain data classes
    pro.dart                       – Pro, ProReview, Booking
    convo.dart                     – Convo (owns its own chips/isTyping),
                                      ScriptStep, CategoryScript, CategoryMeta
    chat_message.dart              – ChatMessage (text / proList / dayMark)
  data/                            – static datasources (today's "backend")
    pros_data.dart                 – kPros
    scripts_data.dart              – kScripts, kCategoryMeta, kSlots
  repositories/                    – data-access layer, hides where data
                                      comes from behind an interface
    pro_repository.dart            – ProRepository + StaticProRepository
    script_repository.dart         – ScriptRepository + StaticScriptRepository
    convo_repository.dart          – ConvoRepository: shared, mutable source
                                      of truth for convos/bookings/saved pros
                                      (ChangeNotifier), holds the intake/chat
                                      business logic
  viewmodels/                      – ViewModel: one per screen, exposes only
                                      what that screen's View needs and
                                      forwards commands to the repositories
    chat_list_view_model.dart
    chat_thread_view_model.dart
    archived_view_model.dart
    profile_view_model.dart
  views/                           – View: pure UI, watches its ViewModel
    chat_list_view.dart
    archived_view.dart
    chat_thread_view.dart
    profile_view.dart
  widgets/                         – shared, mostly stateless UI pieces
    chat_row.dart, pro_card.dart, message_bubble.dart,
    booking_sheet.dart, new_request_sheet.dart
```

**Data flow:** View → ViewModel → Repository. Views never read `lib/data`
directly and never hold business logic; ViewModels never know whether a
repository is backed by the static in-memory maps in `lib/data/` or a real
API.

## Swapping static data for a real API

Right now `StaticProRepository` / `StaticScriptRepository` just return the
maps from `lib/data/`, and `ConvoRepository` keeps everything in memory. When
a backend is ready:

1. Add e.g. `ApiProRepository implements ProRepository` that calls your HTTP
   client instead of reading `kPros`.
2. Swap the `Provider<ProRepository>(create: (_) => StaticProRepository())`
   line in `main.dart` for the new implementation.

No ViewModel, View, or widget needs to change — they only depend on the
`ProRepository` / `ScriptRepository` interfaces.

## Theme & fonts (global)

`lib/theme/app_theme.dart` is the single place colors (`AppColors`) and text
styles (`AppFonts`, `buildAppTheme()`) are defined. Every screen and widget
pulls from there, so changing a color or font in that one file re-themes the
entire app.

## Notes / things you may want to change

- **Persistence**: everything lives in memory (`ConvoRepository`) —
  add `shared_preferences`/`hive` behind the same repository interfaces if
  you want chats/bookings to survive an app restart.
- **Fonts**: uses `google_fonts` for Fraunces / Inter Tight / JetBrains Mono.
  Swap for bundled fonts in `app_theme.dart` if you'd rather not fetch them
  at runtime.
- **Toasts**: mapped to `ScaffoldMessenger` SnackBars.
- **Navigation**: `Navigator.push` with the default Material page transition.
