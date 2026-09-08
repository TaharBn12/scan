// ─────────────────────────────────────────────────────────────────────────
//  لوحة المتجر — قراءة مباشرة (read-only) من Cloud Firestore
//  The POS app pushes products / sales / customers / expenses / purchases
//  into the same project; this page renders what it finds, live.
// ─────────────────────────────────────────────────────────────────────────
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import {
  collection,
  doc,
  getDoc,
  getFirestore,
  onSnapshot,
  query,
  where,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";

const $ = (id) => document.getElementById(id);

const setupBanner = $("setupBanner");
const errorBanner = $("errorBanner");
const liveDot = $("liveDot");
const liveText = $("liveText");

let currency = "DA";
let sawAnySnapshot = false;

// ── helpers ──────────────────────────────────────────────────────────────

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[c]));
}

const moneyFmt = new Intl.NumberFormat("ar-DZ", { maximumFractionDigits: 2 });

function money(n) {
  if (n == null || isNaN(n)) return "—";
  return `${moneyFmt.format(Number(n) || 0)} ${currency}`;
}

/** Local ISO-8601 like the app writes (same TZ as the shop phone). */
function localIso(d) {
  const p = (n) => String(n).padStart(2, "0");
  return (
    `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}` +
    `T${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}.000`
  );
}

function timeOf(iso) {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "";
  return d.toLocaleTimeString("ar-DZ", { hour: "2-digit", minute: "2-digit" });
}

function markUpdated() {
  $("updatedAt").textContent = "آخر تحديث: " + new Date().toLocaleTimeString("ar-DZ");
}

function markLive(state) {
  liveDot.classList.remove("live", "off");
  if (state === "live") {
    liveDot.classList.add("live");
    liveText.textContent = "مباشر";
  } else {
    liveDot.classList.add("off");
    liveText.textContent = "انقطع الاتصال";
    errorBanner.textContent = "تعذّر الاتصال بـ Cloud Firestore — تأكد من الإعدادات وقواعد الأمان.";
    errorBanner.classList.remove("hidden");
  }
}

// ── labels ───────────────────────────────────────────────────────────────

const PAY_LABELS = { cash: "نقدي", credit: "آجل" };

const EXPENSE_CATS = {
  rent: "إيجار",
  utilities: "مصاريف تشغيلية",
  salaries: "رواتب",
  supplies: "مستلزمات",
  transport: "نقل",
  purchase: "شراء مخزون",
  other: "أخرى",
};

function saleStatus(s) {
  if (s.isRefunded) return { text: "ملغاة", cls: "refunded" };
  if (s.isPaid) return { text: "مدفوعة", cls: "paid" };
  const paid = (s.payments || []).reduce((a, p) => a + (Number(p.amount) || 0), 0);
  return paid > 0
    ? { text: "جزئية", cls: "partial" }
    : { text: "غير مدفوعة", cls: "unpaid" };
}

function saleProfit(s) {
  return (s.items || []).reduce(
    (sum, it) => sum + ((Number(it.unitPrice) || 0) - (Number(it.unitCost) || 0)) * (Number(it.quantity) || 0),
    0
  );
}

// ── config guard ─────────────────────────────────────────────────────────

const config = window.FIREBASE_CONFIG;
if (!config || !config.apiKey || config.apiKey === "PASTE_YOUR_API_KEY") {
  setupBanner.classList.remove("hidden");
  liveText.textContent = "غير مهيّأ";
  // Stop here: no project to talk to.
} else {
  boot();
}

// ── live subscriptions ───────────────────────────────────────────────────

async function boot() {
  initializeApp(config);
  const db = getFirestore();

  const todayStart = localIso(new Date());

  // Shop header (written by the app on every sync).
  try {
    const shop = await getDoc(doc(db, "meta", "shop"));
    if (shop.exists()) {
      const d = shop.data();
      if (d.name) $("shopName").textContent = d.name;
      if (d.currencySymbol) currency = d.currencySymbol;
    }
  } catch (_) {
    /* header stays generic */
  }

  // Sales of the day.
  onSnapshot(
    query(collection(db, "sales"), where("dateTime", ">=", todayStart)),
    (snap) => {
      sawAnySnapshot = true;
      markLive("live");
      markUpdated();
      const sales = snap.docs
        .map((d) => d.data())
        .sort((a, b) => String(b.dateTime).localeCompare(String(a.dateTime)));

      const active = sales.filter((s) => !s.isRefunded);
      const revenue = active.reduce((sum, s) => sum + (Number(s.total) || 0), 0);
      const profit = active.reduce((sum, s) => sum + saleProfit(s), 0);

      $("kpiRevenue").textContent = money(revenue);
      $("kpiOrders").textContent = String(active.length);
      $("kpiProfit").textContent = money(profit);
      $("kpiRevenueSub").textContent =
        active.length === 0 ? "لا مبيعات اليوم" : `صافي بعد استبعاد الملغاة (${sales.length - active.length})`;

      const rows = sales.slice(0, 100).map((s) => {
        const names = (s.items || []).map((it) => esc(it.productName));
        const summary =
          names.length > 1
            ? `${names[0]} +${names.length - 1}`
            : names[0] || "—";
        const st = saleStatus(s);
        return `<tr>
          <td class="num">${esc(timeOf(s.dateTime))}</td>
          <td class="num">${esc(s.number ?? "—")}</td>
          <td>${summary}</td>
          <td class="num">${money(s.total)}</td>
          <td>${esc(PAY_LABELS[s.paymentMethod] || s.paymentMethod || "—")}</td>
          <td><span class="badge ${st.cls}">${st.text}</span></td>
          <td>${esc(s.cashierName || "—")}</td>
        </tr>`;
      });
      $("salesBody").innerHTML = rows.length
        ? rows.join("")
        : `<tr><td colspan="7" class="muted">لا مبيعات اليوم</td></tr>`;
    },
    (err) => {
      console.error(err);
      markLive("off");
    }
  );

  // Products → low stock list.
  onSnapshot(collection(db, "products"), (snap) => {
    markUpdated();
    const all = snap.docs.map((d) => d.data());
    const low = all
      .filter(
        (p) =>
          p.trackStock !== false &&
          Number(p.stock) <= (Number(p.lowStockThreshold) || 0)
      )
      .sort((a, b) => (Number(a.stock) || 0) - (Number(b.stock) || 0));

    $("kpiLowStock").textContent = String(low.length);
    const rows = low.slice(0, 100).map((p) => `<tr>
      <td>${esc(p.name)}</td>
      <td class="num">${esc(p.barcode || "—")}</td>
      <td class="num">${Number(p.stock) || 0}</td>
      <td class="num">${Number(p.lowStockThreshold) || 0}</td>
    </tr>`);
    $("stockBody").innerHTML = rows.length
      ? rows.join("")
      : `<tr><td colspan="4" class="muted">كل المنتجات فوق حد التنبيه ✓</td></tr>`;
  }, (err) => console.error(err));

  // Expenses of the day.
  onSnapshot(
    query(collection(db, "expenses"), where("dateTime", ">=", todayStart)),
    (snap) => {
      markUpdated();
      const exps = snap.docs
        .map((d) => d.data())
        .sort((a, b) => String(b.dateTime).localeCompare(String(a.dateTime)));
      const total = exps.reduce((sum, e) => sum + (Number(e.amount) || 0), 0);
      $("kpiExpenses").textContent = money(total);

      const rows = exps.slice(0, 100).map((e) => `<tr>
        <td class="num">${esc(timeOf(e.dateTime))}</td>
        <td>${esc(e.title || "—")}</td>
        <td>${esc(EXPENSE_CATS[e.category] || e.category || "—")}</td>
        <td class="num">${money(e.amount)}</td>
      </tr>`);
      $("expensesBody").innerHTML = rows.length
        ? rows.join("")
        : `<tr><td colspan="4" class="muted">لا مصاريف اليوم</td></tr>`;
    },
    (err) => console.error(err)
  );
}
