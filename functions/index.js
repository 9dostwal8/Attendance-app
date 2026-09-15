const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.onMessageCreated = onDocumentCreated("chat_rooms/{roomId}/messages/{messageId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const data = snapshot.data();
  const senderId = data.senderId;
  const receiverId = data.receiverId;
  const text = data.text;

  if (!senderId || !receiverId || !text) return;

  try {
    // 1. Get sender details for notification title
    const senderDoc = await admin.firestore().collection('employees').doc(senderId).get();
    let senderName = "New Message";
    if (senderDoc.exists) {
      senderName = senderDoc.data().name || "New Message";
    }

    // 2. Get receiver details for FCM token
    const receiverDoc = await admin.firestore().collection('employees').doc(receiverId).get();
    if (!receiverDoc.exists) return;

    const receiverData = receiverDoc.data();
    const fcmToken = receiverData.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${receiverId}`);
      return;
    }

    // 3. Construct and send FCM payload
    const message = {
      notification: {
        title: `Message from ${senderName}`,
        body: text,
      },
      token: fcmToken,
      data: {
        type: 'chat_message',
        senderId: senderId,
        roomId: event.params.roomId
      }
    };

    const response = await admin.messaging().send(message);
    console.log(`Successfully sent message to ${receiverId}:`, response);
  } catch (error) {
    console.error("Error sending push notification:", error);
  }
});
