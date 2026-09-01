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
const previewLabel = document.querySelector("#preview-label");
const download = document.querySelector("#download");
const status = document.querySelector("#status");
const state = { format: "a4", logo: null, url: null };

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
  const { PDFDocument } = await import("pdf-lib");
  const pdf = await PDFDocument.load(await response.arrayBuffer());
  if (state.logo) {
    const logo = await pdf.embedPng(await logoPng());
    format.logoBoxes.forEach((box) => pdf.getPage(0).drawImage(logo, {
      x: box.x * MM_TO_PT,
      y: box.y * MM_TO_PT,
      width: box.width * MM_TO_PT,
      height: box.height * MM_TO_PT
    }));
  }
  const url = URL.createObjectURL(new Blob([await pdf.save()], { type: "application/pdf" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = format.filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url));
}

formatInputs.forEach((element) => element.addEventListener("change", () => {
  state.format = element.value;
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
download.addEventListener("click", () => {
  download.disabled = true;
  setStatus("Building your PDF...");
  requestAnimationFrame(async () => {
    try {
      await buildPdf();
      setStatus("Your PDF is ready.");
    } catch {
      setStatus("The PDF could not be generated. Try a different logo file.", true);
    }
    download.disabled = false;
  });
});

updatePreview();
