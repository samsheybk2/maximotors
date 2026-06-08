import type { APIRoute } from 'astro';
import { createClient } from '@supabase/supabase-js';
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';

const AZUL = '#1D3557';
const ROJO = '#E63946';
const VERDE = '#2A9D8F';
const GRIS = '#6B7280';

function hexToRgb(hex: string) {
  const c = parseInt(hex.replace('#', ''), 16);
  return rgb(((c >> 16) & 0xff) / 255, ((c >> 8) & 0xff) / 255, (c & 0xff) / 255);
}

export const GET: APIRoute = async ({ params, request }) => {
  const { id } = params;

  const supabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY
  );

  const { data: inspection, error } = await supabase
    .from('inspections')
    .select('*')
    .eq('id', id)
    .single();

  if (error || !inspection) {
    return new Response('Inspection not found', { status: 404 });
  }

  const [agentRes, vehicleRes, categoriesRes, itemsRes, resultsRes] = await Promise.all([
    supabase.from('agents').select('*').eq('id', inspection.agent_id).single(),
    supabase.from('vehicles').select('*').eq('id', inspection.vehicle_id).single(),
    supabase.from('inspection_categories').select('*').order('display_order'),
    supabase.from('inspection_items').select('*').order('display_order'),
    supabase.from('inspection_results').select('*').eq('inspection_id', id),
  ]);

  const agent = agentRes.data;
  const vehicle = vehicleRes.data;
  const categories = categoriesRes.data ?? [];
  const items = itemsRes.data ?? [];
  const results = resultsRes.data ?? [];

  const resultMap = Object.fromEntries(results.map(r => [r.item_id, r]));

  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const boldFont = await doc.embedFont(StandardFonts.HelveticaBold);

  const page = doc.addPage([595.28, 841.89]); // A4
  const { width, height } = page.getSize();
  let y = height - 50;

  function drawText(text: string, x: number, size: number, color: any, opts?: { bold?: boolean; maxWidth?: number }) {
    const f = opts?.bold ? boldFont : font;
    const tw = f.widthOfTextAtSize(text, size);
    if (opts?.maxWidth && tw > opts.maxWidth) {
      const scale = opts.maxWidth / tw;
      size = size * scale;
    }
    page.drawText(text, { x, y: y - size, size, font: f, color });
    return size;
  }

  function drawWrappedText(text: string, x: number, size: number, color: any, maxWidth: number, bold?: boolean) {
    const f = bold ? boldFont : font;
    const words = text.split(' ');
    let line = '';
    let lineHeight = size * 1.3;
    for (const w of words) {
      const test = line ? line + ' ' + w : w;
      if (f.widthOfTextAtSize(test, size) > maxWidth) {
        page.drawText(line, { x, y: y - size, size, font: f, color });
        y -= lineHeight;
        line = w;
      } else {
        line = test;
      }
    }
    if (line) {
      page.drawText(line, { x, y: y - size, size, font: f, color });
      y -= lineHeight;
    }
    return size;
  }

  function drawLine(yPos: number, color: any, thickness?: number) {
    page.drawLine({
      start: { x: 50, y: yPos },
      end: { x: width - 50, y: yPos },
      thickness: thickness ?? 1,
      color,
    });
  }

  // === HEADER ===
  page.drawText('MAXI MOTORS', { x: 50, y: y - 24, size: 22, font: boldFont, color: hexToRgb(AZUL) });
  page.drawText('Certificación de 140 Puntos', { x: 50, y: y - 44, size: 14, font: boldFont, color: hexToRgb(ROJO) });
  if (inspection.completed_at) {
    const dateStr = new Date(inspection.completed_at).toLocaleDateString('es-PA', { year: 'numeric', month: 'long', day: 'numeric' });
    page.drawText(`Fecha: ${dateStr}`, { x: width - 200, y: y - 24, size: 9, font, color: hexToRgb(GRIS) });
  }
  page.drawText(`ID: ${id?.slice(0, 8)}...`, { x: width - 200, y: y - 36, size: 9, font, color: hexToRgb(GRIS) });
  y -= 60;
  drawLine(y, hexToRgb(AZUL), 2);
  y -= 25;

  // === VEHICLE INFO ===
  if (vehicle) {
    page.drawText('DATOS DEL VEHÍCULO', { x: 50, y: y - 12, size: 11, font: boldFont, color: hexToRgb(AZUL) });
    y -= 28;
    const info = [
      `Marca: ${vehicle.brand ?? '—'}`,
      `Modelo: ${vehicle.model ?? '—'}`,
      `Año: ${vehicle.year ?? '—'}`,
      `VIN: ${vehicle.vin ?? '—'}`,
      `Placa: ${vehicle.license_plate ?? '—'}`,
      `Kilometraje: ${vehicle.mileage ? `${vehicle.mileage.toLocaleString()} km` : '—'}`,
    ];
    for (let i = 0; i < info.length; i += 2) {
      page.drawText(info[i], { x: 50, y: y - 10, size: 9, font, color: hexToRgb('#374151') });
      if (info[i + 1]) page.drawText(info[i + 1], { x: 300, y: y - 10, size: 9, font, color: hexToRgb('#374151') });
      y -= 16;
    }
    y -= 10;
  }

  // === AGENT INFO ===
  if (agent) {
    page.drawText(`Realizado por: ${agent.full_name ?? agent.email}`, { x: 50, y: y - 10, size: 9, font, color: hexToRgb(GRIS) });
    y -= 20;
  }

  drawLine(y, hexToRgb(AZUL), 0.5);
  y -= 20;

  // === RESULTS BY CATEGORY ===
  let aprobados = 0, observaciones = 0, rechazados = 0, sinRevisar = 0;

  for (const cat of categories) {
    const catItems = items.filter(i => i.category_id === cat.id);

    // Check if we need a new page
    if (y < 120) {
      page.drawText('Continúa...', { x: 50, y: y - 10, size: 9, font, color: hexToRgb(GRIS) });
      const newPage = doc.addPage([595.28, 841.89]);
      y = newPage.getSize().height - 50;
    }

    page.drawText(`${cat.display_order}. ${cat.name}`, { x: 50, y: y - 11, size: 10, font: boldFont, color: hexToRgb(AZUL) });
    y -= 22;

    for (const item of catItems) {
      const r = resultMap[item.id];
      const resultVal = r?.result;
      const resultColor = resultVal === 'aprobado' ? hexToRgb(VERDE)
        : resultVal === 'observacion' ? hexToRgb('#D97706')
        : resultVal === 'rechazado' ? hexToRgb(ROJO)
        : hexToRgb(GRIS);
      const resultText = resultVal === 'aprobado' ? 'APROBADO'
        : resultVal === 'observacion' ? 'OBSERVACIÓN'
        : resultVal === 'rechazado' ? 'RECHAZADO'
        : 'SIN REVISAR';
      const noteText = r?.notes ? ` — ${r.notes}` : '';

      if (resultVal === 'aprobado') aprobados++;
      else if (resultVal === 'observacion') observaciones++;
      else if (resultVal === 'rechazado') rechazados++;
      else sinRevisar++;

      if (y < 50) {
        const newPage = doc.addPage([595.28, 841.89]);
        y = newPage.getSize().height - 50;
      }

      page.drawText('•', { x: 50, y: y - 8, size: 8, font, color: hexToRgb(GRIS) });
      const nameWidth = boldFont.widthOfTextAtSize(item.name, 8);
      page.drawText(item.name, { x: 60, y: y - 8, size: 8, font: boldFont, color: hexToRgb('#374151') });
      page.drawText(resultText, { x: 60 + nameWidth + 8, y: y - 8, size: 7, font, color: resultColor });
      if (noteText) {
        page.drawText(noteText, { x: 60 + nameWidth + 8 + 70, y: y - 8, size: 7, font, color: hexToRgb(GRIS) });
      }
      y -= 14;
    }
    y -= 6;
    drawLine(y, hexToRgb('#E5E7EB'), 0.3);
    y -= 12;
  }

  // === SUMMARY ===
  y = Math.min(y, height - 250);
  if (y < 150) {
    const newPage = doc.addPage([595.28, 841.89]);
    y = newPage.getSize().height - 50;
  }

  drawLine(y, hexToRgb(AZUL), 2);
  y -= 25;

  page.drawText('RESUMEN DE LA CERTIFICACIÓN', { x: 50, y: y - 11, size: 11, font: boldFont, color: hexToRgb(AZUL) });
  y -= 25;

  const total = aprobados + observaciones + rechazados + sinRevisar;
  const summaryData = [
    ['Total puntos', total.toString()],
    ['Aprobados', aprobados.toString()],
    ['Observaciones', observaciones.toString()],
    ['Rechazados', rechazados.toString()],
    ['Sin revisar', sinRevisar.toString()],
  ];
  for (const [label, val] of summaryData) {
    page.drawText(label, { x: 70, y: y - 9, size: 9, font, color: hexToRgb('#374151') });
    page.drawText(val, { x: 300, y: y - 9, size: 9, font: boldFont, color: label === 'Aprobados' ? hexToRgb(VERDE) : label === 'Rechazados' ? hexToRgb(ROJO) : label === 'Observaciones' ? hexToRgb('#D97706') : hexToRgb('#374151') });
    y -= 16;
  }

  y -= 10;

  // === FOOTER ===
  page.drawText('www.maximotors.pa | Maxi Motors © Todos los derechos reservados', {
    x: 50, y: 40, size: 8, font, color: hexToRgb(GRIS),
  });

  const pdfBytes = await doc.save();

  return new Response(pdfBytes, {
    status: 200,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="certificacion-${vehicle?.brand ?? ''}-${vehicle?.model ?? ''}-${vehicle?.year ?? ''}.pdf"`,
    },
  });
};
