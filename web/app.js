import { parseIcaoFlightPlan } from "./flight-plan.js";
import { FORMATS, MM_TO_PT } from "./templates.js";

const formatInputs = document.querySelectorAll('input[name="format"]');
const input = document.querySelector("#logo-input");
const dropZone = document.querySelector("#drop-zone");
const picker = document.querySelector("#pick-logo");
const deleteLogo = document.querySelector("#delete-logo");
const fileName = document.querySelector("#file-name");
const previewPaper = document.querySelector("#preview-paper");
const previewImage = document.querySelector("#preview-image");
const previewLogos = document.querySelector("#preview-logos");
const previewValues = document.querySelector("#preview-values");
const previewLabel = document.querySelector("#preview-label");
const download = document.querySelector("#download");
const status = document.querySelector("#status");
const fplSlots = document.querySelector("#fpl-slots");
const fplDialog = document.querySelector("#fpl-dialog");
const fplTitle = document.querySelector("#fpl-title");
const fplForm = document.querySelector("#fpl-form");
const fplInput = document.querySelector("#fpl-input");
const fplError = document.querySelector("#fpl-error");
const fplCancel = document.querySelector("#fpl-cancel");
const state = { format: "a4", logo: null, url: null, plans: [null, null] };
let activePlan = 0;

function updatePreview() {
  const format = FORMATS[state.format];
  previewPaper.className = `preview-paper ${state.format}`;
  previewImage.src = format.preview;
  previewLogos.replaceChildren(...format.logoBoxes.map((box) => {
    const logo = new Image();
    logo.className = "preview-logo";
    logo.src = state.url || "";
    logo.style.left = `${box.x / format.page[0] * 100}%`;
    logo.style.bottom = `${box.y / format.page[1] * 100}%`;
    logo.style.width = `${box.width / format.page[0] * 100}%`;
    logo.style.height = `${box.height / format.page[1] * 100}%`;
    return logo;
  }));
  previewValues.replaceChildren(...format.cards.flatMap((card, index) => Object.entries(card.valueBoxes).flatMap(([key, box]) => {
    const text = state.plans[index]?.[key];
    if (!text) return [];
    const value = document.createElement("span");
    value.className = ["origin", "destination", "alternate", "cruise"].includes(key) ? "preview-value-large" : "preview-value";
    value.textContent = text;
    value.style.left = `${box.x / format.page[0] * 100}%`;
    value.style.bottom = `${box.y / format.page[1] * 100}%`;
    value.style.width = `${box.width / format.page[0] * 100}%`;
    value.style.textAlign = box.align;
    return value;
  })));
  previewLabel.textContent = format.label;
}

function setStatus(message = "", error = false) {
  status.textContent = message;
  status.classList.toggle("error", error);
}

function setFile(file) {
  if (!file || !file.type.startsWith("image/")) {
    setStatus("Choose a PNG, JPEG, WebP, or SVG logo.", true);
    return;
  }
  const url = URL.createObjectURL(file);
  const image = new Image();
  image.onload = () => {
    if (state.url) URL.revokeObjectURL(state.url);
    state.logo = image;
    state.url = url;
    fileName.textContent = file.name;
    picker.textContent = "Replace logo";
    deleteLogo.hidden = false;
    download.disabled = false;
    setStatus("");
    updatePreview();
  };
  image.onerror = () => {
    URL.revokeObjectURL(url);
    setStatus("This image could not be read in your browser.", true);
  };
  image.src = url;
}

function removeLogo() {
  if (state.url) URL.revokeObjectURL(state.url);
  state.logo = null;
  state.url = null;
  input.value = "";
  fileName.textContent = "No image selected";
  picker.textContent = "Choose logo";
  deleteLogo.hidden = true;
  setStatus("");
  updatePreview();
}

function action(label, type, index) {
  const button = document.createElement("button");
  button.className = "secondary";
  button.type = "button";
  button.textContent = label;
  button.dataset.fplAction = type;
  button.dataset.fplIndex = index;
  return button;
}

function renderFlightSlots() {
  const indexes = state.format === "a4" ? [0, 1] : [0];
  fplSlots.replaceChildren(...indexes.map((index) => {
    const plan = state.plans[index];
    const slot = document.createElement("section");
    slot.className = `fpl-slot${plan ? "" : " fpl-slot-empty"}`;
    const heading = document.createElement("h4");
    heading.textContent = state.format === "a4" ? `${index ? "Right" : "Left"} card` : "";
    const slotHeading = document.createElement("div");
    slotHeading.className = "fpl-slot-heading";
    slotHeading.append(heading);
    if (!plan) {
      slotHeading.append(action("Import ICAO FPL", "import", index));
      slot.append(slotHeading);
      return slot;
    }
    if (plan) {
    const summary = document.createElement("p");
    summary.textContent = [plan.callsign, `${plan.origin} - ${plan.destination}`, plan.date].filter(Boolean).join(" · ");
    const actions = document.createElement("div");
    actions.className = "fpl-actions";
    actions.append(action("Edit", "edit", index), action("Remove", "remove", index));
    slot.append(slotHeading, summary, actions);
    } else {
      slot.append(slotHeading)
    }
    return slot;
  }));
}

function openFplDialog(index) {
  activePlan = index;
  fplTitle.textContent = `Import ICAO FPL`;
  fplInput.value = state.plans[index]?.source || "";
  fplError.textContent = "";
  fplDialog.showModal();
  fplInput.focus();
}

async function logoPng() {
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(38 / 25.4 * 300);
  canvas.height = Math.round(9 / 25.4 * 300);
  const ratio = Math.min(canvas.width / state.logo.width, canvas.height / state.logo.height);
  const width = state.logo.width * ratio;
  const height = state.logo.height * ratio;
  canvas.getContext("2d").drawImage(state.logo, (canvas.width - width) / 2, (canvas.height - height) / 2, width, height);
  const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
  if (!blob) throw new Error("Logo conversion failed");
  return blob.arrayBuffer();
}

async function buildPdf() {
  const format = FORMATS[state.format];
  const response = await fetch(format.template);
  if (!response.ok) throw new Error("Template could not be loaded");
  const { PDFDocument, StandardFonts, rgb } = await import("pdf-lib");
  const pdf = await PDFDocument.load(await response.arrayBuffer());
  const page = pdf.getPage(0);
  if (state.logo) {
    const logo = await pdf.embedPng(await logoPng());
    format.logoBoxes.forEach((box) => page.drawImage(logo, {
      x: box.x * MM_TO_PT,
      y: box.y * MM_TO_PT,
      width: box.width * MM_TO_PT,
      height: box.height * MM_TO_PT
    }));
  }
  const font = await pdf.embedFont(StandardFonts.Courier);
  format.cards.forEach((card, index) => Object.entries(card.valueBoxes).forEach(([key, box]) => {
    const text = state.plans[index]?.[key];
    if (!text) return;
    const size = 7.4;
    const width = font.widthOfTextAtSize(text, size);
    const boxWidth = box.width * MM_TO_PT;
    const x = box.x * MM_TO_PT + (box.align === "center" ? (boxWidth - width) / 2 : 0);
    page.drawText(text, { x, y: box.y * MM_TO_PT, size, font, color: rgb(.16, .16, .16) });
  }));
  const url = URL.createObjectURL(new Blob([await pdf.save()], { type: "application/pdf" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = format.filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url));
}

formatInputs.forEach((element) => element.addEventListener("change", () => {
  state.format = element.value;
  renderFlightSlots();
  updatePreview();
}));

picker.addEventListener("click", () => input.click());
deleteLogo.addEventListener("click", removeLogo);
dropZone.addEventListener("click", () => input.click());
dropZone.addEventListener("keydown", (event) => {
  if (event.key === "Enter" || event.key === " ") {
    event.preventDefault();
    input.click();
  }
});
input.addEventListener("change", () => setFile(input.files[0]));
["dragenter", "dragover"].forEach((eventName) => dropZone.addEventListener(eventName, (event) => {
  event.preventDefault();
  dropZone.classList.add("dragging");
}));
["dragleave", "drop"].forEach((eventName) => dropZone.addEventListener(eventName, (event) => {
  event.preventDefault();
  dropZone.classList.remove("dragging");
}));
dropZone.addEventListener("drop", (event) => setFile(event.dataTransfer.files[0]));
fplSlots.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-fpl-action]");
  if (!button) return;
  const index = Number(button.dataset.fplIndex);
  if (button.dataset.fplAction === "remove") {
    state.plans[index] = null;
    renderFlightSlots();
    updatePreview();
    return;
  }
  openFplDialog(index);
});
fplCancel.addEventListener("click", () => fplDialog.close());
fplForm.addEventListener("submit", (event) => {
  event.preventDefault();
  try {
    state.plans[activePlan] = parseIcaoFlightPlan(fplInput.value);
    fplDialog.close();
    renderFlightSlots();
    updatePreview();
  } catch (error) {
    fplError.textContent = error.message;
  }
});
download.addEventListener("click", () => {
  download.disabled = true;
  setStatus("Building your PDF...");
  requestAnimationFrame(async () => {
    try {
      await buildPdf();
      setStatus("PDF is ready, have a great flight! 🛫");
    } catch {
      setStatus("The PDF could not be generated. Try a different logo file.", true);
    }
    download.disabled = false;
  });
});

renderFlightSlots();
updatePreview();
