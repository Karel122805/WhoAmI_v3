const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { DateTime } = require("luxon");

admin.initializeApp();
const db = admin.firestore();

/**
 * Cadencias permitidas:
 * hourly1 | hourly2 | hourly6 | daily1 | daily2 | weekly | biweekly
 * monthly | quarterly | semiannual | annual
 */
function computeNextAt({ cadence, timeHHmm, timezone, fromJSDate }) {
  const tz = timezone || "America/Mexico_City";
  const now = DateTime.now().setZone(tz);

  const from = DateTime.fromJSDate(fromJSDate).setZone(tz);

  // Normaliza time "HH:mm"
  let hh = 9;
  let mm = 0;
  if (typeof timeHHmm === "string" && timeHHmm.includes(":")) {
    const parts = timeHHmm.split(":");
    const ph = parseInt(parts[0], 10);
    const pm = parseInt(parts[1], 10);
    if (!Number.isNaN(ph)) hh = ph;
    if (!Number.isNaN(pm)) mm = pm;
  }

  const addMap = {
    hourly1: { hours: 1 },
    hourly2: { hours: 2 },
    hourly6: { hours: 6 },
    daily1: { days: 1 },
    daily2: { days: 2 },
    weekly: { weeks: 1 },
    biweekly: { weeks: 2 },
    monthly: { months: 1 },
    quarterly: { months: 3 },
    semiannual: { months: 6 },
    annual: { years: 1 },
  };

  const inc = addMap[cadence] || { months: 1 };

  // Si es por horas, solo suma horas desde "from"
  if (String(cadence).startsWith("hourly")) {
    let next = from.plus(inc);
    while (next <= now) next = next.plus(inc);
    return next.toJSDate();
  }

  // Para diario/semanal/mensual/anual, fijamos hora HH:mm y avanzamos
  let next = from
    .plus(inc)
    .set({ hour: hh, minute: mm, second: 0, millisecond: 0 });

  while (next <= now) {
    next = next
      .plus(inc)
      .set({ hour: hh, minute: mm, second: 0, millisecond: 0 });
  }

  return next.toJSDate();
}

async function getAllUserTokens(userId) {
  const snap = await db
    .collection("users")
    .doc(userId)
    .collection("fcm_tokens")
    .get();

  const tokens = [];
  snap.forEach((d) => {
    const data = d.data() || {};
    if (typeof data.token === "string" && data.token.length > 0) {
      tokens.push(data.token);
    }
  });
  return tokens;
}

/**
 * Busca recordatorios vencidos y manda push a todos los dispositivos del usuario.
 *
 * Estructura esperada:
 * memories/{uid}/user_memories/{docId}
 *   reminder: {
 *     enabled: true,
 *     cadence: "monthly",
 *     time: "09:00",
 *     timezone: "America/Mexico_City",
 *     nextAt: Timestamp
 *   }
 */
exports.sendDueReminders = onSchedule(
  { schedule: "every 5 minutes", timeZone: "America/Mexico_City" },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const dueQuery = await db
      .collectionGroup("user_memories")
      .where("reminder.enabled", "==", true)
      .where("reminder.nextAt", "<=", now)
      .limit(200)
      .get();

    if (dueQuery.empty) {
      console.log("No hay recordatorios vencidos.");
      return null;
    }

    console.log(`Recordatorios vencidos encontrados: ${dueQuery.size}`);

    for (const doc of dueQuery.docs) {
      const data = doc.data() || {};
      const reminder = data.reminder || {};

      // doc.ref path: memories/{uid}/user_memories/{docId}
      const pathParts = doc.ref.path.split("/");
      const userId = pathParts[1];

      const title =
        data.text && String(data.text).trim().length > 0
          ? String(data.text).trim()
          : "Recordatorio de recuerdo";

      const displayDate = data.displayDate ? String(data.displayDate) : "";

      const cadence = String(reminder.cadence || "monthly");
      const timeHHmm = String(reminder.time || "09:00");
      const timezone = String(reminder.timezone || "America/Mexico_City");

      // Tokens del usuario (multi-dispositivo)
      const tokens = await getAllUserTokens(userId);

      if (tokens.length > 0) {
        try {
          const payload = {
            notification: {
              title: "WhoAmI?",
              body: displayDate ? `${title} (${displayDate})` : title,
            },
            data: {
              type: "memory_reminder",
              memoryDocId: doc.id,
              userId,
            },
          };

          const resp = await admin.messaging().sendEachForMulticast({
            tokens,
            ...payload,
          });

          console.log(
            `Usuario ${userId}: tokens=${tokens.length} ok=${resp.successCount} fail=${resp.failureCount}`
          );

          // Limpia tokens inválidos
          if (resp.failureCount > 0) {
            const batch = db.batch();
            resp.responses.forEach((r, idx) => {
              if (!r.success) {
                const badToken = tokens[idx];
                const tokenRef = db
                  .collection("users")
                  .doc(userId)
                  .collection("fcm_tokens")
                  .doc(badToken);
                batch.delete(tokenRef);
              }
            });
            await batch.commit().catch(() => {});
          }
        } catch (err) {
          console.log("Error enviando FCM:", err);
        }
      } else {
        console.log(`Usuario ${userId} sin tokens. Solo actualizo nextAt.`);
      }

      // Calcula el siguiente nextAt basado en el nextAt actual
      let fromDate = new Date();
      try {
        if (reminder.nextAt && reminder.nextAt.toDate) {
          fromDate = reminder.nextAt.toDate();
        }
      } catch (_) {}

      const nextAtJS = computeNextAt({
        cadence,
        timeHHmm,
        timezone,
        fromJSDate: fromDate,
      });

      await doc.ref.set(
        {
          reminder: {
            enabled: true,
            cadence,
            time: timeHHmm,
            timezone,
            nextAt: admin.firestore.Timestamp.fromDate(nextAtJS),
            lastSentAt: now,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    return null;
  }
);
