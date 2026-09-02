function card(x, width) {
  const inner = width - 8;
  const header = width - 51;
  const originDest = width - 4 - 22 - (4 + 28);
  const originStart = x + 32;
  const headerAircraft = x + 47 + header * .35;
  const headerDate = x + 47 + header * .7;
  const value = (x, y, width, align = "left", size = 7.4) => ({ x, y, width, align, size });

  return {
    logoBox: { x: x + 5.5, y: 193.5, width: 38, height: 9 },
    valueBoxes: {
      callsign: value(x + 48, 195.3, header * .35 - 2, "right", 8.5),
      aircraft: value(headerAircraft + 1, 195.3, header * .35 - 2, "right", 8.5),
      date: value(headerDate + 1, 195.3, header * .3 - 2, "right", 8.5),
      origin: value(originStart + 1, 184.3, originDest / 2 - 2, "center"),
      destination: value(originStart + originDest / 2 + 1, 184.3, originDest / 2 - 2, "center"),
      alternate: value(x + width - 25, 184.3, 20, "center"),
      squawk: value(x + 4 + inner * .63 + 1, 169.3, inner * .18 - 2, "center"),
      cruise: value(x + 4 + inner * .75 + 1, 159.3, inner * .25 - 2, "center")
    }
  };
}

const a4Cards = [card(5, 138.5), card(153.5, 138.5)];
const a5Cards = [card(5, 138)];

export const FORMATS = {
  a4: {
    label: "A4",
    page: [297, 210],
    template: "/templates/vatsim-flight-card-a4.pdf",
    preview: "/templates/vatsim-flight-card-a4.png",
    filename: "vatsim-flight-card-a4.pdf",
    cards: a4Cards,
    logoBoxes: a4Cards.map(({ logoBox }) => logoBox)
  },
  a5: {
    label: "A5",
    page: [148, 210],
    template: "/templates/vatsim-flight-card-a5.pdf",
    preview: "/templates/vatsim-flight-card-a5.png",
    filename: "vatsim-flight-card-a5.pdf",
    cards: a5Cards,
    logoBoxes: a5Cards.map(({ logoBox }) => logoBox)
  }
};

export const MM_TO_PT = 72 / 25.4;
