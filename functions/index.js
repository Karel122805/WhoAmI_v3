// ===============================================================
// CLOUD FUNCTION - ENVÍO AUTOMÁTICO DE NOTIFICACIONES DE EMERGENCIA
// ===============================================================
// Esta función se activa cuando se crea un nuevo documento en la colección
// "emergencies". Envía una notificación push al cuidador usando su token FCM.
// Compatible con Firebase Functions v4+ (modular SDK).
// ===============================================================

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

// Inicializa Admin SDK (una sola vez)
initializeApp();
const db = getFirestore();

// ===============================================================
// 🔔 FUNCIÓN: se ejecuta al crear una emergencia
// ===============================================================
export const notifyCaregiverOnEmergency = onDocumentCreated(
  "emergencies/{emergencyId}",
  async (event) => {
    try {
      const data = event.data?.data();
      if (!data) {
        console.log("⚠️ Documento vacío, se omite.");
        return;
      }

      const { caregiverId, consultantId, lat, lng } = data;
      if (!caregiverId) {
        console.log("⚠️ No hay caregiverId en la emergencia.");
        return;
      }

      // 🔹 Obtener token del cuidador
      const caregiverDoc = await db.collection("users").doc(caregiverId).get();
      const caregiverToken = caregiverDoc.data()?.fcmToken;

      if (!caregiverToken) {
        console.log("⚠️ Cuidador sin token FCM.");
        return;
      }

      // 🔹 Construir notificación
      const message = {
        token: caregiverToken,
        notification: {
          title: "🚨 Emergencia detectada",
          body: "Tu consultante necesita ayuda. Toca para ver la ubicación.",
        },
        data: {
          type: "emergency",
          consultantId: consultantId ?? "",
          lat: lat?.toString() ?? "",
          lng: lng?.toString() ?? "",
        },
      };

      // 🔹 Enviar notificación
      await getMessaging().send(message);
      console.log("✅ Notificación enviada a cuidador:", caregiverId);
    } catch (err) {
      console.error("❌ Error enviando notificación:", err);
    }
  }
);
