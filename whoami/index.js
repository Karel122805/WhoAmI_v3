const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendEmergencyNotification = onDocumentCreated(
  "emergencies/{emergencyId}",
  async (event) => {
    const emergency = event.data.data();
    const emergencyId = event.params.emergencyId;

    if (!emergency) return;

    const caregiverId = emergency.caregiverId;
    const consultantName = emergency.consultantName || "Tu consultante";

    if (!caregiverId) return;

    const caregiverDoc = await admin
      .firestore()
      .collection("users")
      .doc(caregiverId)
      .get();

    if (!caregiverDoc.exists) return;

    const caregiverData = caregiverDoc.data() || {};

    const tokens = Array.isArray(caregiverData.fcmTokens)
      ? caregiverData.fcmTokens
      : [];

    const singleToken = caregiverData.fcmToken;

    const finalTokens = [...new Set([
      ...tokens,
      ...(singleToken ? [singleToken] : []),
    ])].filter(Boolean);

    if (finalTokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens: finalTokens,
      data: {
        type: "emergency",
        emergencyId: emergencyId,
        consultantId: emergency.consultantId || "",
        title: "Emergencia detectada",
        body: `${consultantName} necesita ayuda.`,
        lat: emergency.lat ? String(emergency.lat) : "",
        lng: emergency.lng ? String(emergency.lng) : "",
      },
      android: {
        priority: "high",
      },
    });
  }
);