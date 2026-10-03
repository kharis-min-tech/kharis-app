// Firebase Cloud Messaging service worker for the web build.
//
// The Firebase JS SDK registers this file (served from the site root) when the
// app calls FirebaseMessaging.getToken(); without it, getToken() throws on the
// web and push never initialises. It shows notifications that arrive while the
// app tab is closed or in the background.
//
// The SDK version must match firebase_core_web's supportedFirebaseJsSdkVersion
// (firebase_core_web 2.24.1 -> 11.9.1). Update both together when bumping
// firebase_core in pubspec.yaml. Config mirrors DefaultFirebaseOptions.web in
// lib/firebase_options.dart (project kharis-app-47c49).
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDrb8yD1g5rUAZR8fjuh_SXXhhgfyzKyNA',
  appId: '1:656532033168:web:8b84b12c3cd8d888d21215',
  messagingSenderId: '656532033168',
  projectId: 'kharis-app-47c49',
  authDomain: 'kharis-app-47c49.firebaseapp.com',
  storageBucket: 'kharis-app-47c49.firebasestorage.app',
  measurementId: 'G-VYRG23Z14G',
});

// Messages with a `notification` payload are displayed by the SDK itself.
// Initialising messaging here is what enables that background handling.
firebase.messaging();
