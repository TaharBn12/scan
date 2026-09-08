// ─────────────────────────────────────────────────────────────────────────
//  إعدادات Firebase — نفس المشروع الذي يزامنه تطبيق POS
//  Firebase config — the same project the POS app syncs to
//
//  1. من وحدة تحكم Firebase: الإعدادات → التطبيقات → أضف "تطبيق ويب"
//     ثم انسخ كائن firebaseConfig (Firebase console → Project settings →
//     Your apps → Add app → Web, copy the firebaseConfig object)
// 2. الصق الكائن مكان القيم أدناه.
//    Paste the object below.
// 3. هذا الكائن نفسه هو الذي تُلصقه في التطبيق (الإعدادات ← المزامنة
//    السحابية) ليرتبط التطبيق واللوحة بنفس مشروع Firestore.
//    The exact same object is pasted in the app (Settings → Cloud Sync)
//    so both point at the same Firestore project.
// ─────────────────────────────────────────────────────────────────────────
window.FIREBASE_CONFIG = {
  apiKey: "PASTE_YOUR_API_KEY",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "000000000000",
  appId: "1:000000000000:web:0000000000000000",
};
