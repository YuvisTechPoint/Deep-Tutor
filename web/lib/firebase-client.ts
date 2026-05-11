/**
 * Firebase Web SDK — Auth + optional Analytics.
 * Configure via NEXT_PUBLIC_FIREBASE_* in the project root `.env` (see `.env.example`).
 */

import { type FirebaseApp, getApps, initializeApp, type FirebaseOptions } from "firebase/app";
import {
  type Auth,
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
} from "firebase/auth";

function firebaseOptions(): FirebaseOptions | null {
  const apiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY?.trim();
  const authDomain = process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN?.trim();
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID?.trim();
  const storageBucket = process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET?.trim();
  const messagingSenderId = process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID?.trim();
  const appId = process.env.NEXT_PUBLIC_FIREBASE_APP_ID?.trim();
  const measurementId = process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID?.trim();
  if (!apiKey || !projectId || !appId) return null;
  return {
    apiKey,
    authDomain: authDomain || undefined,
    projectId,
    storageBucket: storageBucket || undefined,
    messagingSenderId: messagingSenderId || undefined,
    appId,
    measurementId: measurementId || undefined,
  };
}

export function isFirebaseConfigured(): boolean {
  return firebaseOptions() !== null;
}

let _app: FirebaseApp | null = null;

export function getFirebaseApp(): FirebaseApp | null {
  if (_app) return _app;
  const opts = firebaseOptions();
  if (!opts) return null;
  _app = getApps().length ? getApps()[0]! : initializeApp(opts);
  return _app;
}

export function getFirebaseAuth(): Auth | null {
  const app = getFirebaseApp();
  if (!app) return null;
  return getAuth(app);
}

export async function signInWithGoogleAndGetIdToken(): Promise<string> {
  const auth = getFirebaseAuth();
  if (!auth) {
    throw new Error("Firebase is not configured (missing NEXT_PUBLIC_FIREBASE_* env).");
  }
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters({ prompt: "select_account" });
  const result = await signInWithPopup(auth, provider);
  const token = await result.user.getIdToken();
  return token;
}
