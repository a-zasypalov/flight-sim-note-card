export const FORMATS = {
  a4: {
    label: "A4 - two cards",
    page: [297, 210],
    cards: [
      { x: 5, y: 5, width: 138.5, height: 200 },
      { x: 153.5, y: 5, width: 138.5, height: 200 }
    ],
    filename: "vatsim-flight-card-a4.pdf"
  },
  a5: {
    label: "A5 - one card",
    page: [148, 210],
    cards: [{ x: 5, y: 5, width: 138, height: 200 }],
    filename: "vatsim-flight-card-a5.pdf"
  }
};

const INK = "#292929";
const MUTED = "#858585";
const BAND = "#ebebeb";
const MM_PER_PT = 25.4 / 72;

export function renderCard(formatKey, logo, dpi = 300) {
  const card = FORMATS[formatKey].cards[0];
  const scale = dpi / 25.4;
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(card.width * scale);
  canvas.height = Math.round(card.height * scale);
  const context = canvas.getContext("2d");
  context.fillStyle = "#fff";
  context.fillRect(0, 0, canvas.width, canvas.height);
  drawCard(context, { ...card, x: 0, y: 0 }, logo, scale);
  return canvas;
}

export function renderPreview(formatKey, logo) {
  const format = FORMATS[formatKey];
  const scale = 2.5;
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(format.page[0] * scale);
  canvas.height = Math.round(format.page[1] * scale);
  const context = canvas.getContext("2d");
  context.fillStyle = "#fff";
  context.fillRect(0, 0, canvas.width, canvas.height);
  format.cards.forEach((card) => drawCard(context, card, logo, scale));
  if (formatKey === "a4") {
    context.save();
    context.strokeStyle = MUTED;
    context.lineWidth = 0.35 * MM_PER_PT * scale;
    context.setLineDash([scale, 1.5 * scale]);
    context.beginPath();
    context.moveTo(148.5 * scale, 0.5 * scale);
    context.lineTo(148.5 * scale, 209.5 * scale);
    context.stroke();
    context.restore();
  }
  return canvas;
}

function drawCard(context, card, logo, scale) {
  const x = (value) => (card.x + value) * scale;
  const y = (value, height = 0) => (card.y + card.height - value - height) * scale;
  const width = (value) => value * scale;
  const stroke = (points) => points * MM_PER_PT * scale;
  const font = (points) => `700 ${points * MM_PER_PT * scale}px Arial, Helvetica, sans-serif`;
  const line = (x1, y1, x2, y2, points = 0.25, color = MUTED) => {
    context.save();
    context.strokeStyle = color;
    context.lineWidth = stroke(points);
    context.beginPath();
    context.moveTo(x(x1), y(y1));
    context.lineTo(x(x2), y(y2));
    context.stroke();
    context.restore();
  };
  const field = (xPos, yPos, fieldWidth, fieldHeight, text) => {
    const top = y(yPos, fieldHeight);
    context.save();
    context.fillStyle = "#fff";
    context.strokeStyle = INK;
    context.lineWidth = stroke(0.55);
    context.fillRect(x(xPos), top, width(fieldWidth), width(fieldHeight));
    context.strokeRect(x(xPos), top, width(fieldWidth), width(fieldHeight));
    context.fillStyle = INK;
    context.font = font(5.35);
    context.textBaseline = "top";
    context.fillText(text, x(xPos + 1.4), top + width(0.8));
    context.restore();
    line(xPos + 1, yPos + 1.8, xPos + fieldWidth - 1, yPos + 1.8);
  };
  const band = (yPos, text) => {
    const top = y(yPos, 5);
    context.save();
    context.fillStyle = BAND;
    context.strokeStyle = INK;
    context.lineWidth = stroke(0.65);
    context.fillRect(x(4), top, width(card.width - 8), width(5));
    context.strokeRect(x(4), top, width(card.width - 8), width(5));
    context.fillStyle = INK;
    context.font = font(7.2);
    context.textBaseline = "middle";
    context.fillText(text, x(6.2), top + width(2.7));
    context.restore();
  };
  const notes = (xPos, yPos, notesWidth, notesHeight, text) => {
    const top = y(yPos, notesHeight);
    context.save();
    context.strokeStyle = INK;
    context.lineWidth = stroke(0.55);
    context.strokeRect(x(xPos), top, width(notesWidth), width(notesHeight));
    if (text) {
      context.fillStyle = MUTED;
      context.font = font(5.35);
      context.textBaseline = "top";
      context.fillText(text, x(xPos + 2.2), top + width(1.3));
    }
    context.restore();
  };
  const marker = (xPos, yPos, text) => {
    context.save();
    context.font = font(9);
    context.textAlign = "center";
    context.textBaseline = "middle";
    const metrics = context.measureText(text);
    const padding = width(0.45);
    const centerX = x(xPos);
    const centerY = y(yPos);
    context.fillStyle = "#fff";
    context.fillRect(centerX - metrics.width / 2 - padding, centerY - width(1.8), metrics.width + padding * 2, width(3.6));
    context.fillStyle = INK;
    context.fillText(text, centerX, centerY);
    context.restore();
  };

  context.save();
  context.strokeStyle = INK;
  context.lineWidth = stroke(0.9);
  const outerInset = 0.9 * MM_PER_PT / 2;
  context.strokeRect(x(outerInset), y(outerInset, card.height - outerInset * 2), width(card.width - outerInset * 2), width(card.height - outerInset * 2));
  context.restore();

  if (logo) {
    const maxWidth = 38;
    const maxHeight = 9;
    const ratio = Math.min(maxWidth / logo.width, maxHeight / logo.height);
    const logoWidth = logo.width * ratio;
    const logoHeight = logo.height * ratio;
    context.drawImage(logo, x(24.5 - logoWidth / 2), y(193) - width(logoHeight / 2), width(logoWidth), width(logoHeight));
  }

  const inner = card.width - 8;
  const header = card.width - 51;
  const call = header * 0.35;
  const aircraft = header * 0.35;
  const stand = 28;
  const altn = 22;
  const altnStart = card.width - 4 - altn;
  const originStart = 4 + stand;
  const originWidth = altnStart - originStart;
  const depAtis = inner * 0.25;
  const depQnh = inner * 0.18;
  const depSqwk = inner * 0.18;
  const delFreq = inner * 0.2;
  const depRwy = inner - depAtis - delFreq - depSqwk - depQnh;
  const arrAtis = inner * 0.21;
  const arrQnh = inner * 0.1;
  const arrTransition = inner * 0.15;
  const arrRwy = inner * 0.13;
  const arrStar = inner - arrAtis - arrQnh - arrTransition - arrRwy;

  field(47, 189, call, 8, "CALLSIGN");
  field(47 + call, 189, aircraft, 8, "AIRCRAFT");
  field(47 + call + aircraft, 189, header - call - aircraft, 8, "DATE");
  field(4, 177, stand, 10, "STAND");
  field(originStart, 177, originWidth, 10, "ORIGIN/DEST");
  field(altnStart, 177, altn, 10, "ALTN");
  marker(originStart + originWidth / 2, 179, "/");

  band(172, "DEPARTURE");
  field(4, 162, depAtis, 10, "ATIS FREQ / INFO");
  marker(4 + depAtis * 0.72, 164, "/");
  marker(4 + depAtis * 0.36, 164, ".");
  field(4 + depAtis, 162, depQnh, 10, "QNH");
  field(4 + depAtis + depQnh, 162, delFreq, 10, "DEL FREQ");
  marker(4 + depAtis + depQnh + delFreq / 2, 164, ".");
  field(4 + depAtis + depQnh + delFreq, 162, depSqwk, 10, "SQWK");
  field(4 + depAtis + depQnh + delFreq + depSqwk, 162, depRwy, 10, "RWY");
  field(4, 152, inner * 0.25, 10, "SID");
  field(4 + inner * 0.25, 152, inner * 0.25, 10, "INIT CLB");
  field(4 + inner * 0.5, 152, inner * 0.25, 10, "TRANS ALT");
  field(4 + inner * 0.75, 152, inner * 0.25, 10, "CRZ ALT");
  field(4, 142, inner / 3, 10, "GND FREQ");
  field(4 + inner / 3, 142, inner / 3, 10, "TWR FREQ");
  field(4 + inner * 2 / 3, 142, inner / 3, 10, "DEP FREQ");
  marker(4 + inner / 6, 144, ".");
  marker(4 + inner / 2, 144, ".");
  marker(4 + inner * 5 / 6, 144, ".");
  notes(4, 123, inner, 19, "PUSHBACK / TAXI");
  [129, 135].forEach((lineY) => line(5, lineY, card.width - 5, lineY));

  band(118, "IN-FLIGHT");
  notes(4, 50, inner, 68, "");
  [56, 62, 68, 74, 80, 86, 92, 98, 104, 110].forEach((lineY) => line(5, lineY, card.width - 5, lineY));

  band(45, "ARRIVAL");
  field(4, 34, arrAtis, 11, "ATIS FREQ / CODE");
  marker(4 + arrAtis * 0.72, 36, "/");
  marker(4 + arrAtis * 0.36, 36, ".");
  field(4 + arrAtis, 34, arrQnh, 11, "QNH");
  field(4 + arrAtis + arrQnh, 34, arrTransition, 11, "TRANS FL");
  field(4 + arrAtis + arrQnh + arrTransition, 34, arrRwy, 11, "RWY");
  field(4 + arrAtis + arrQnh + arrTransition + arrRwy, 34, arrStar, 11, "STAR");
  field(4, 23, inner / 3, 11, "ARR FREQ");
  field(4 + inner / 3, 23, inner / 3, 11, "TWR FREQ");
  field(4 + inner * 2 / 3, 23, inner / 3, 11, "GND FREQ");
  marker(4 + inner / 6, 25, ".");
  marker(4 + inner / 2, 25, ".");
  marker(4 + inner * 5 / 6, 25, ".");
  notes(4, 4, inner, 19, "TAXI");
  line(5, 9, card.width - 4 - stand - 1, 9);
  line(5, 15, card.width - 5, 15);
  field(card.width - 4 - stand, 4, stand, 11, "STAND");
}
