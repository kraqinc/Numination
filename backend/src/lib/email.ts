export async function sendWrenVerificationEmail(params: {
  to: string;
  code: string;
  purpose: "login" | "signup";
}) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    throw new Error("RESEND_API_KEY no configurada");
  }

  const from = process.env.RESEND_FROM || "Numination <no-reply@kraq.ai>";
  const subject =
    params.purpose === "login"
      ? "Tu código de acceso a Numination"
      : "Tu código para crear tu cuenta en Numination";

  const html = `
    <div style="font-family:Inter,Arial,sans-serif;background:#0b0d10;color:#f3f5f7;padding:32px;border-radius:20px;max-width:560px;margin:0 auto">
      <h1 style="margin:0 0 16px 0;font-size:28px;letter-spacing:2px">NUMINATION</h1>
      <p style="margin:0 0 18px 0;color:#9ca3af;font-size:15px;line-height:1.6">
        Tu código de verificación es:
      </p>
      <div style="display:inline-block;background:#11151a;border:1px solid #232833;border-radius:18px;padding:18px 24px;font-size:34px;font-weight:800;letter-spacing:8px;color:#27e7ff">
        ${params.code}
      </div>
      <p style="margin:18px 0 0 0;color:#9ca3af;font-size:13px;line-height:1.6">
        Este código expira en 10 minutos. Si no pediste este acceso, puedes ignorar este correo.
      </p>
    </div>
  `;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: params.to,
      subject,
      html,
      text: `Numination\n\nTu código de verificación es: ${params.code}\n\nEste código expira en 10 minutos.`,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`No se pudo enviar el correo: ${res.status} ${text}`);
  }
}
