export const FORMATS = {
  a4: {
    label: "A4",
    page: [297, 210],
    template: "/templates/vatsim-flight-card-a4.pdf",
    preview: "/templates/vatsim-flight-card-a4.png",
    filename: "vatsim-flight-card-a4.pdf",
    logoBoxes: [{ x: 10.5, y: 193.5, width: 38, height: 9 }, { x: 159, y: 193.5, width: 38, height: 9 }]
  },
  a5: {
    label: "A5",
    page: [148, 210],
    template: "/templates/vatsim-flight-card-a5.pdf",
    preview: "/templates/vatsim-flight-card-a5.png",
    filename: "vatsim-flight-card-a5.pdf",
    logoBoxes: [{ x: 10.5, y: 193.5, width: 38, height: 9 }]
  }
};

export const MM_TO_PT = 72 / 25.4;
