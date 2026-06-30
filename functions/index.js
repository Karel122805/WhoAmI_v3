const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { DateTime } = require("luxon");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({
  region: "us-central1",
});

function computeNextAt({ cadence, timeHHmm, timezone, fromJSDate }) {
  const tz = timezone || "America/Mexico_City";
  const now = DateTime.now().setZone(tz);
  const from = DateTime.fromJSDate(fromJSDate).setZone(tz);

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

  if (String(cadence).startsWith("hourly")) {
    let next = from.plus(inc);
    while (next <= now) next = next.plus(inc);
    return next.toJSDate();
  }

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
  const tokens = [];

  const userDoc = await db.collection("users").doc(userId).get();
  const userData = userDoc.exists ? userDoc.data() || {} : {};

  if (typeof userData.fcmToken === "string" && userData.fcmToken.length > 0) {
    tokens.push(userData.fcmToken);
  }

  if (Array.isArray(userData.fcmTokens)) {
    for (const token of userData.fcmTokens) {
      if (typeof token === "string" && token.length > 0) {
        tokens.push(token);
      }
    }
  }

  const snap = await db
    .collection("users")
    .doc(userId)
    .collection("fcm_tokens")
    .get();

  snap.forEach((d) => {
    const data = d.data() || {};
    if (typeof data.token === "string" && data.token.length > 0) {
      tokens.push(data.token);
    }
  });

  return [...new Set(tokens)].filter(Boolean);
}

exports.sendEmergencyNotification = onDocumentCreated(
  "emergencies/{emergencyId}",
  async (event) => {
    const emergency = event.data.data();
    const emergencyId = event.params.emergencyId;

    if (!emergency) return null;

    const caregiverId = emergency.caregiverId;
    const consultantId = emergency.consultantId || "";
    const consultantName = emergency.consultantName || "Tu consultante";

    if (!caregiverId) return null;

    const tokens = await getAllUserTokens(caregiverId);

    if (tokens.length === 0) {
      console.log(`Cuidador ${caregiverId} sin tokens FCM.`);
      return null;
    }

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      data: {
        type: "emergency",
        emergencyId,
        consultantId,
        title: "Emergencia detectada",
        body: `${consultantName} necesita ayuda.`,
        lat: emergency.lat ? String(emergency.lat) : "",
        lng: emergency.lng ? String(emergency.lng) : "",
      },
      android: {
        priority: "high",
      },
    });

    console.log(
      `Emergencia ${emergencyId}: tokens=${tokens.length} ok=${response.successCount} fail=${response.failureCount}`
    );

    return null;
  }
);

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

    for (const doc of dueQuery.docs) {
      const data = doc.data() || {};
      const reminder = data.reminder || {};

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

      const tokens = await getAllUserTokens(userId);

      if (tokens.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {
            title: "WhoAmI?",
            body: displayDate ? `${title} (${displayDate})` : title,
          },
          data: {
            type: "memory_reminder",
            memoryDocId: doc.id,
            userId,
          },
          android: {
            priority: "high",
          },
        });
      }

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