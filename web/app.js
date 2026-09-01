import { jsPDF } from "jspdf";
import { FORMATS, renderCard, renderPreview } from "./card.js";

const formatInputs = document.querySelectorAll('input[name="format"]');
const input = document.querySelector("#logo-input");
const dropZone = document.querySelector("#drop-zone");
const picker = document.querySelector("#pick-logo");
const fileName = document.querySelector("#file-name");
const preview = document.querySelector("#preview");
const previewLabel = document.querySelector("#preview-label");
const download = document.querySelector("#download");
const status = document.querySelector("#status");
const state = { format: "a4", logo: null, url: null };

function updatePreview() {
  const image = renderPreview(state.format, state.logo);
  preview.width = image.width;
  preview.height = image.height;
  preview.getContext("2d").drawImage(image, 0, 0);
  previewLabel.textContent = FORMATS[state.format].label;
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

function buildPdf() {
  const format = FORMATS[state.format];
  const pdf = new jsPDF({ orientation: state.format === "a4" ? "landscape" : "portrait", unit: "mm", format: state.format, compress: true });
  const card = renderCard(state.format, state.logo);
  format.cards.forEach(({ x, y, width, height }) => pdf.addImage(card, "PNG", x, y, width, height, "flight-card", "FAST"));
  if (state.format === "a4") {
    pdf.setDrawColor(133);
    pdf.setLineWidth(0.12);
    pdf.setLineDashPattern([1, 1.5], 0);
    pdf.line(148.5, 0.5, 148.5, 209.5);
  }
  pdf.save(format.filename);
}

formatInputs.forEach((element) => element.addEventListener("change", () => {
  state.format = element.value;
  updatePreview();
}));

picker.addEventListener("click", () => input.click());
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
  requestAnimationFrame(() => {
    try {
      buildPdf();
      setStatus("Your PDF is ready.");
    } catch {
      setStatus("The PDF could not be generated. Try a different logo file.", true);
    }
    download.disabled = false;
  });
});

updatePreview();
