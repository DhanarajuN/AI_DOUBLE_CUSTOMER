// Required for FCM on Flutter web to deliver a notification while the tab is
// closed/backgrounded — the browser runs this service worker, not the Dart
// app, for that case. Values below match DefaultFirebaseOptions.web in
// lib/firebase_options.dart (the "AI double" Firebase project's web app) —
// keep the two in sync if `flutterfire configure` is ever re-run.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB3595kCt74dEpedI4GsU0-FR7fa8CdZ9o',
  authDomain: 'ai-double-3b497.firebaseapp.com',
  projectId: 'ai-double-3b497',
  storageBucket: 'ai-double-3b497.firebasestorage.app',
  messagingSenderId: '453370808950',
  appId: '1:453370808950:web:50a9228f2a90979487ed57',
});

const messaging = firebase.messaging();
