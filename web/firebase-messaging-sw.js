// Required for FCM on Flutter web to deliver a notification while the tab is
// closed/backgrounded — the browser runs this service worker, not the Dart
// app, for that case. Needs the real Web app's Firebase config below before
// it does anything; until then it loads harmlessly and does nothing.
//
// TODO: replace this placeholder config with the real values from the
// Firebase console's Web app registration (Project Settings > General >
// Your apps > Web app > SDK setup and configuration), or from
// `lib/firebase_options.dart` if generated via `flutterfire configure` —
// `DefaultFirebaseOptions.web` there has the same fields.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_ME',
  authDomain: 'REPLACE_ME',
  projectId: 'REPLACE_ME',
  storageBucket: 'REPLACE_ME',
  messagingSenderId: 'REPLACE_ME',
  appId: 'REPLACE_ME',
});

const messaging = firebase.messaging();
