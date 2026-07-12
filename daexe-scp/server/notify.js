'use strict';
// Stub de notificação por e-mail.
// Para ativar envio real: defina SMTP_* nas variáveis de ambiente e instale nodemailer.
// Por padrão apenas registra no console (modo seguro, sem credenciais).
function notifyEmail(to, subject, body) {
  const enabled = process.env.SMTP_HOST && process.env.SMTP_USER;
  if (!enabled) {
    console.log(`[E-MAIL SIMULADO] Para: ${to} | Assunto: ${subject}\n${body}\n`);
    return Promise.resolve({ simulated: true });
  }
  // Integração real (descomente após instalar nodemailer):
  // const nodemailer = require('nodemailer');
  // const t = nodemailer.createTransport({ host: process.env.SMTP_HOST, port: +process.env.SMTP_PORT||587,
  //   auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } });
  // return t.sendMail({ from: process.env.SMTP_USER, to, subject, text: body });
  return Promise.resolve({ simulated: true });
}
module.exports = { notifyEmail };
