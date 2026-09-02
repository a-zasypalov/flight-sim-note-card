import assert from "node:assert/strict";
import { parseIcaoFlightPlan } from "./flight-plan.js";
import { FORMATS } from "./templates.js";

assert.deepEqual(FORMATS.a4.page, [297, 210]);
assert.deepEqual(FORMATS.a5.page, [148, 210]);
assert.equal(FORMATS.a4.logoBoxes.length, 2);
assert.equal(FORMATS.a4.logoBoxes[1].x - FORMATS.a4.logoBoxes[0].x, 148.5);
assert.equal(FORMATS.a5.logoBoxes[0].width, 38);
assert.equal(FORMATS.a4.cards.length, 2);
assert.equal(FORMATS.a4.cards[1].valueBoxes.callsign.x - FORMATS.a4.cards[0].valueBoxes.callsign.x, 148.5);
assert.equal(FORMATS.a5.cards[0].valueBoxes.cruise.y, 159.3);
assert.equal(FORMATS.a5.cards[0].valueBoxes.callsign.y, 196.2);
assert.equal(FORMATS.a5.cards[0].valueBoxes.callsign.align, "right");
assert.equal(FORMATS.a5.cards[0].valueBoxes.callsign.size, 8.5);

const imported = parseIcaoFlightPlan(`(FPL-RYR421-IS
-CRJ9/M-SDFGIRWY/S
-EGAC0725
-N0386F170 DCT MAGEE DCT BLACA BLACA1G
-EGPF0033 EIDW
-PBN/D1 DOF/260902 REG/N922SB EET/EGTT0008 EGPX0011 OPR/RYR PER/D RMK/TCAS)`);
assert.deepEqual({ ...imported, source: undefined }, {
  source: undefined,
  callsign: "RYR421",
  aircraft: "CRJ9",
  date: "02 SEP 2026",
  origin: "EGAC",
  destination: "EGPF",
  alternate: "EIDW",
  squawk: "",
  cruise: "FL 170"
});
assert.equal(parseIcaoFlightPlan("(FPL-ABC123-IS-A320/M-S/S-EGLL1200-N0450F350 DCT-EHAM0100-0)").date, "");
assert.equal(parseIcaoFlightPlan("(FPL-ABC123/A7421-IS-A320/M-S/S-EGLL1200-N0450F350 DCT-EHAM0100-0)").squawk, "7421");
assert.throws(() => parseIcaoFlightPlan("FPL-ABC123"), /complete flight plan/);
assert.throws(() => parseIcaoFlightPlan("(FPL-ABC123-IS-A320/M-S/S-EGLL120-N0450F350 DCT-EHAM0100-0)"), /Item 13/);
assert.throws(() => parseIcaoFlightPlan("(FPL-ABC123-IS-A320/M-S/S-EGLL1200-N0450F350 DCT-EHAM0100-DOF/261332)"), /real date/);
console.log("Template geometry is valid.");
