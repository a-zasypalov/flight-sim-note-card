import { parseIcaoFlightPlan } from "./flight-plan.js";
import { FORMATS, MM_TO_PT } from "./templates.js";

const formatInputs = document.querySelectorAll('input[name="format"]');
const input = document.querySelector("#logo-input");
const dropZone = document.querySelector("#drop-zone");
const picker = document.querySelector("#pick-logo");
const deleteLogo = document.querySelector("#delete-logo");
const fileName = document.querySelector("#file-name");
const controls = document.querySelector(".controls");
const previewPapers = Object.fromEntries([...document.querySelectorAll(".preview-paper")].map((paper) => [paper.dataset.format, paper]));
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
let controlsTimeout;
let controlLayoutTimeout;
let transitionPaper;
let previewTimeouts = [];

function updatePreview(format) {
  const paper = previewPapers[format];
  const spec = FORMATS[format];
  const image = paper.querySelector(".preview-image");
  const logos = paper.querySelector(".preview-logos");
  const values = paper.querySelector(".preview-values");
  if (image.getAttribute("src") !== spec.preview) image.src = spec.preview;
  logos.replaceChildren(...spec.logoBoxes.map((box) => {
    const logo = new Image();
    logo.className = "preview-logo";
    logo.src = state.url || "";
    logo.style.left = `${box.x / spec.page[0] * 100}%`;
    logo.style.bottom = `${box.y / spec.page[1] * 100}%`;
    logo.style.width = `${box.width / spec.page[0] * 100}%`;
    logo.style.height = `${box.height / spec.page[1] * 100}%`;
    return logo;
  }));
  values.replaceChildren(...spec.cards.flatMap((card, index) => Object.entries(card.valueBoxes).flatMap(([key, box]) => {
    const text = state.plans[index]?.[key];
    if (!text) return [];
    const value = document.createElement("span");
    value.className = ["callsign", "aircraft", "origin", "destination", "alternate", "cruise"].includes(key) ? "preview-value-large" : "preview-value";
    value.textContent = text;
    value.style.left = `${box.x / spec.page[0] * 100}%`;
    value.style.bottom = `${box.y / spec.page[1] * 100}%`;
    value.style.width = `${box.width / spec.page[0] * 100}%`;
    value.style.textAlign = box.align;
    return value;
  })));
}

function updatePreviews() {
  updatePreview("a4");
  updatePreview("a5");
  previewLabel.textContent = FORMATS[state.format].label;
}

function reducedMotion() {
  return matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function showPreview(format) {
  Object.entries(previewPapers).forEach(([key, paper]) => paper.classList.toggle("is-hidden", key !== format));
}

function clearPreviewTransition(format = state.format) {
  previewTimeouts.forEach(clearTimeout);
  previewTimeouts = [];
  transitionPaper = null;
  Object.values(previewPapers).forEach((paper) => paper.classList.remove("sequence-a4", "sequence-a5", "sequence-visible", "to-center", "to-left", "fade-out"));
  showPreview(format);
}

function clearControlsTransition() {
  clearTimeout(controlsTimeout);
  controls.style.height = "";
  controls.classList.remove("resizing");
}

function clearControlLayoutMotion() {
  clearTimeout(controlLayoutTimeout);
  controls.querySelectorAll(".control-moving").forEach((element) => {
    element.style.transition = "";
    element.style.transform = "";
    element.classList.remove("control-moving");
  });
}

function animateControlLayout(before) {
  if (reducedMotion()) return;
  const moving = [];
  for (const [element, top] of before) {
    const distance = top - element.getBoundingClientRect().top;
    if (!distance) continue;
    element.style.transition = "none";
    element.style.transform = `translateY(${distance}px)`;
    moving.push(element);
  }
  if (!moving.length) return;
  void controls.offsetHeight;
  moving.forEach((element) => {
    element.style.transition = "";
    element.classList.add("control-moving");
    element.style.transform = "";
  });
  controlLayoutTimeout = setTimeout(clearControlLayoutMotion, 260);
}

function animateControls(fromHeight) {
  if (reducedMotion()) return;
  const toHeight = controls.offsetHeight;
  if (fromHeight === toHeight) return;
  controls.classList.add("resizing");
  controls.style.height = `${fromHeight}px`;
  void controls.offsetHeight;
  controls.style.height = `${toHeight}px`;
  controlsTimeout = setTimeout(clearControlsTransition, 260);
}

function animatePreview(previousFormat) {
  if (reducedMotion()) return showPreview(state.format);
  const previous = previewPapers[previousFormat];
  const next = previewPapers[state.format];
  transitionPaper = next;
  showPreview(previousFormat);
  next.classList.remove("is-hidden");
  const later = (action, delay) => previewTimeouts.push(setTimeout(() => transitionPaper === next && action(), delay));
  const start = (action) => requestAnimationFrame(() => requestAnimationFrame(() => transitionPaper === next && action()));
  if (previousFormat === "a4") next.classList.add("sequence-a5");
  else next.classList.add("sequence-a4");
  start(() => {
    if (previousFormat === "a4") {
      next.classList.add("sequence-visible");
      later(() => previous.classList.add("fade-out"), 130);
      later(() => next.classList.add("to-center"), 260);
    } else {
      previous.classList.add("to-left");
      later(() => next.classList.add("sequence-visible"), 210);
      later(() => previous.classList.add("fade-out"), 300);
    }
    later(() => clearPreviewTransition(state.format), 440);
  });
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
    dropZone.style.setProperty("--logo-preview", `url("${url}")`);
    dropZone.classList.add("has-logo");
    fileName.textContent = file.name;
    picker.textContent = "Replace logo";
    deleteLogo.hidden = false;
    download.disabled = false;
    setStatus("");
    updatePreviews();
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
  dropZone.style.removeProperty("--logo-preview");
  dropZone.classList.remove("has-logo");
  input.value = "";
  fileName.textContent = "No image selected";
  picker.textContent = "Choose logo";
  deleteLogo.hidden = true;
  setStatus("");
  updatePreviews();
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

function flightSlot(index) {
  const plan = state.plans[index];
  const slot = document.createElement("section");
  slot.className = `fpl-slot${plan ? "" : " fpl-slot-empty"}`;
  const heading = document.createElement("h4");
  heading.textContent = state.format === "a4" ? `card ${index ? "2" : "1"}` : "card 1";
  const slotHeading = document.createElement("div");
  slotHeading.className = "fpl-slot-heading";
  slotHeading.append(heading);
  if (!plan) {
    slotHeading.append(action("Import ICAO FPL", "import", index));
    slot.append(slotHeading);
    return slot;
  }
  const summary = document.createElement("p");
  summary.textContent = [plan.callsign, `${plan.origin} - ${plan.destination}`, plan.date].filter(Boolean).join(" · ");
  const actions = document.createElement("div");
  actions.className = "fpl-actions";
  actions.append(action("Edit", "edit", index), action("Remove", "remove", index));
  slot.append(slotHeading, summary, actions);
  return slot;
}

function renderFlightSlots() {
  const indexes = state.format === "a4" ? [0, 1] : [0];
  fplSlots.replaceChildren(...indexes.map(flightSlot));
}

function syncFlightSlots() {
  if (state.format === "a4" && fplSlots.children.length === 1) fplSlots.append(flightSlot(1));
  if (state.format === "a5" && fplSlots.children.length > 1) fplSlots.lastElementChild.remove();
}

function replaceFlightSlot(index) {
  fplSlots.children[index]?.replaceWith(flightSlot(index));
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
    const size = box.size;
    const width = font.widthOfTextAtSize(text, size);
    const boxWidth = box.width * MM_TO_PT;
    const x = box.x * MM_TO_PT + (box.align === "center" ? (boxWidth - width) / 2 : box.align === "right" ? boxWidth - width : 0);
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
  clearControlsTransition();
  clearControlLayoutMotion();
  const previousFormat = state.format;
  const previousHeight = controls.getBoundingClientRect().height;
  const previousLayout = new Map([...controls.children].map((child) => [child, child.getBoundingClientRect().top]));
  clearPreviewTransition(previousFormat);
  state.format = element.value;
  syncFlightSlots();
  previewLabel.textContent = FORMATS[state.format].label;
  animateControls(previousHeight);
  animateControlLayout(previousLayout);
  animatePreview(previousFormat);
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
    replaceFlightSlot(index);
    updatePreviews();
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
    replaceFlightSlot(activePlan);
    updatePreviews();
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
updatePreviews();
