const functions = require("firebase-functions");
const nodemailer = require("nodemailer");
const cors = require("cors")({ origin: true });

const emailUser = "masaken.app@gmail.com";
const emailPass = "cndbfuthhidgruxp";

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: emailUser,
    pass: emailPass,
  },
});

exports.sendPdfEmail = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { pdfBase64, subject } = req.body;

      const mailOptions = {
        from: `"تطبيق مساكن" <${emailUser}>`,
        to: "zizoalzohairy@gmail.com",
        subject: subject || "مستند للطباعة",
        text: "يرجى طباعة الملف المرفق.",
        attachments: [{
          filename: "document.pdf",
          content: pdfBase64,
          encoding: "base64",
        }],
      };

      await transporter.sendMail(mailOptions);
      return res.status(200).send("تم الإرسال");
    } catch (error) {
      console.error("Email Error:", error);
      return res.status(500).send("فشل في الإرسال");
    }
  });
});
