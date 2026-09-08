# ️ لوحة الويب — Web Dashboard

لوحة قراءة مباشرة (read-only) لبيانات تطبيق POS، تبني فوق نفس مشروع
Cloud Firestore الذي يزامنه التطبيق. تعرض: مبيعات اليوم (الإيراد، عدد
الفواتير، الربح التقديري)، نواقص المخزون، ومصاريف اليوم — وتتحدث لحظياً
عند كل تغيير.

A live, read-only dashboard for the POS app. It reads the same Cloud
Firestore project the app syncs to and shows today's sales (revenue,
invoice count, estimated profit), low stock and today's expenses,
updating in real time.

## الملفات / Files

| File | Description |
| --- | --- |
| `index.html` | الصفحة الوحيدة (HTML) |
| `styles.css` | التصميم |
| `app.js` | الاشتراكات اللحظية من Firestore |
| `firebase-config.js` | **تضع إعدادات مشروعك هنا** (you paste your config here) |

## التهيئة / Setup

1. **أنشئ مشروع Firebase** وفعّل **Cloud Firestore** (وضع الإنتاج)
   Create a Firebase project and enable **Cloud Firestore** (production mode).

2. **أضف تطبيق ويب** للمشروع وانسخ كائن `firebaseConfig`
   Add a **Web App** to the project and copy the `firebaseConfig` object.

3. الصق الكائن في الملفين:
   Paste the same object in **both** places:
   - هنا في `firebase-config.js` — here
   - في التطبيق: **الإعدادات ← المزامنة السحابية ← حفظ الإعدادات**
     — in the app: Settings → Cloud Sync → Save config

4. **انشر المجلد** على أي استضافة ثابتة / host this folder anywhere static:
   - Firebase Hosting (الأسهل):
     ```bash
     firebase login
     cd web-dashboard && firebase init hosting   # public dir: "."
     firebase deploy --only hosting
     ```
   - أو Netlify / GitHub Pages / أي web server — or any static host.

5. ضع رابط النشر في التطبيق (حقل "رابط لوحة الويب") لفتحه بنقرة، ثم اضغط
   **"مزامنة سحابية الآن"** مرة واحدة ليُرسل التطبيق كل البيانات.
   Put the hosted URL in the app ("Dashboard URL") to open it with one
   tap, then press **"Cloud sync now"** once to upload the full dataset.

## قواعد الأمان / Security rules

التطبيق واللوحة يقرأان/يكتبان عبر SDKs عادية بدون مصادقة، لذا ابدأ بقواعد
متسامحة ثم اقفلها:

The app and the dashboard use plain client SDKs (no sign-in), so start
permissive, then lock down:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Starting point — anyone with the API key can read/write.
    // Tighten before going to production.
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

> ⚠️ مفتاح API الخاص بالتطبيقات ليس سراً فعلياً، لكن القواعد هي خط الدفاع.
> The web API key is not a real secret, but rules are your line of defense.

## مجموعات البيانات / Collections

| Collection | Docs |
| --- | --- |
| `products/{id}` | خريطة المنتج الكاملة + `updatedAt` |
| `sales/{id}` | الفاتورة الكاملة (بنداتها، المدفوعات، البائع) |
| `customers/{id}` | العملاء |
| `expenses/{id}` | المصاريف اليومية |
| `purchases/{id}` | عمليات شراء المخزون |
| `stock_movements/{id}` | سجل حركات المخزون |
| `meta/shop` | اسم المتجر + رمز العملة (ترويسة اللوحة) |
