# AI Double — Flutter port

A full Flutter port of `customer.html`, covering every flow in the original
mock: chat list, archived chats, the AI-guided intake conversation (per
category), matched-professional cards, professional profile with FAQs and
reviews, save/bookmark, chat-with-professional, and the booking flow
(slot picker → confirmation → hand-off to chat).

## Run it

```bash
flutter pub get
flutter run
```

Requires Flutter 3.19+ (Dart 3). Internet access is needed once, for
`flutter pub get` to fetch `provider` and `google_fonts`.

## Structure

```
lib/
  main.dart                     – app entry point, Provider setup
  theme/app_theme.dart          – colors & fonts ported from the :root CSS vars
  models/
    pro.dart                    – Pro + ProReview + Booking
    convo.dart                  – Convo, ScriptStep, CategoryScript, CategoryMeta
    chat_message.dart           – ChatMessage (text / proList / dayMark)
  data/
    pros_data.dart              – ported PROS map
    scripts_data.dart           – ported SCRIPTS map, CATMETA, SLOTS
  state/
    app_state.dart              – all app logic (ChangeNotifier):
                                   startIntake, advanceIntake, finishIntake,
                                   handleFollowup, sendMsg, chatWithPro,
                                   toggleSave, confirmBooking, seed data
  screens/
    chat_list_screen.dart       – home / chat list + FAB "new request"
    archived_screen.dart        – archived chats list
    chat_thread_screen.dart     – AI intake flow, quick replies, composer
    profile_screen.dart         – pro profile, FAQs, reviews, book/chat CTA
  widgets/
    chat_row.dart                – one row in the chat list
    pro_card.dart                – matched-professional card
    message_bubble.dart          – text bubble, pro-list bubble, day marker,
                                    typing indicator
    booking_sheet.dart           – slot-pick → confirm bottom sheet
    new_request_sheet.dart       – category picker bottom sheet
```

## Notes / things you may want to change

- **Persistence**: the original HTML persisted to `localStorage`. This port
  keeps everything in memory (`AppState`) for simplicity — add
  `shared_preferences` or `hive` in `AppState` if you want chats/bookings to
  survive an app restart.
- **Fonts**: uses `google_fonts` for Fraunces / Inter Tight / JetBrains Mono,
  matching the `<link>` tags in the HTML `<head>`. Swap for bundled fonts if
  you'd rather not fetch them at runtime.
- **Toasts**: mapped to `ScaffoldMessenger` SnackBars.
- **Navigation**: mapped the HTML's sliding `.screen` panels to
  `Navigator.push` with the default Material page transition (slide from
  right), which reproduces the same feel as `.screen.active { transform:
  translateX(0) }`.
