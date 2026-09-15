import assert from "node:assert/strict";
import { parseIcaoFlightPlan } from "./flight-plan.js";
import { parseSimBriefFlightPlan } from "./simbrief.js";
import { FORMATS } from "./templates.js";

assert.deepEqual(FORMATS.a4.page, [297, 210]);
assert.deepEqual(FORMATS.a5.page, [148, 210]);
assert.equal(FORMATS.a4.logoBoxes.length, 2);
assert.equal(FORMATS.a4.logoBoxes[1].x - FORMATS.a4.logoBoxes[0].x, 148.5);
assert.equal(FORMATS.a5.logoBoxes[0].width, 38);
assert.equal(FORMATS.a4.cards.length, 2);
assert.equal(FORMATS.a4.cards[1].valueBoxes.callsign.x - FORMATS.a4.cards[0].valueBoxes.callsign.x, 148.5);
assert.equal(FORMATS.a5.cards[0].valueBoxes.cruise.y, 159.3);
assert.equal(FORMATS.a5.cards[0].valueBoxes.callsign.y, 195.3);
assert.equal(FORMATS.a5.cards[0].valueBoxes.callsign.align, "right");
assert.equal(FORMATS.a5.cards[0].valueBoxes.callsign.size, 8.5);
assert.equal(FORMATS.a5.cards[0].valueBoxes.departureRunway.x.toFixed(1), "115.3");
assert.equal(FORMATS.a5.cards[0].valueBoxes.sid.y, 159.3);
assert.equal(FORMATS.a5.cards[0].valueBoxes.inFlightRoute.y, 116.3);
assert.equal(FORMATS.a4.cards[1].valueBoxes.inFlightRoute.x - FORMATS.a4.cards[0].valueBoxes.inFlightRoute.x, 148.5);

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

const simbrief = {
  fetch: { status: "Success" },
  atc: { callsign: "OCN5MA", flight_plan: "(FPL-OCN5MA-IS...)" },
  general: { icao_airline: "OCN", flight_number: "5MA", initial_altitude: "37000", route: "DCT MAGEE DCT BLACA" },
  aircraft: { icaocode: "A20N", reg: "D-AABC" },
  times: { sched_out: Date.UTC(2026, 8, 2, 12) / 1000 },
  origin: { icao_code: "ENBG", plan_rwy: "17" },
  destination: { icao_code: "EDDL", plan_rwy: "23L" },
  alternate: { icao_code: "EDDK" },
  navlog: { fix: [{ is_sid_star: "1", via_airway: "MAGEE1A", stage: "CLB" }, { is_sid_star: "1", via_airway: "BLACA2B", stage: "DES" }] }
};
const simbriefImported = parseSimBriefFlightPlan(simbrief);
assert.deepEqual(simbriefImported, {
  source: "(FPL-OCN5MA-IS...)",
  callsign: "OCN5MA",
  aircraft: "A20N",
  date: "02 SEP 2026",
  origin: "ENBG",
  destination: "EDDL",
  alternate: "EDDK",
  squawk: "",
  sid: "MAGEE1A",
  cruise: "FL 370",
  departureRunway: "17",
  inFlightRoute: "ENBG/17 MAGEE1A DCT MAGEE DCT BLACA BLACA2B EDDL/23L"
});
assert.equal(parseSimBriefFlightPlan({ ...simbrief, atc: {}, general: { ...simbrief.general, initial_altitude: "F370" } }).callsign, "OCN5MA");
assert.deepEqual(
  (({ alternate, departureRunway, inFlightRoute }) => ({ alternate, departureRunway, inFlightRoute }))(
    parseSimBriefFlightPlan({ ...simbrief, alternate: {}, origin: { ...simbrief.origin, plan_rwy: {} }, destination: { ...simbrief.destination, plan_rwy: {} } })
  ),
  { alternate: "", departureRunway: "", inFlightRoute: "ENBG MAGEE1A DCT MAGEE DCT BLACA BLACA2B EDDL" }
);
assert.throws(() => parseSimBriefFlightPlan({ fetch: { status: "Error: Unknown UserID" } }), /current flight plan/);
assert.throws(() => parseSimBriefFlightPlan({ ...simbrief, times: { sched_out: "invalid" } }), /departure date/);
assert.throws(() => parseSimBriefFlightPlan({ ...simbrief, destination: {} }), /incomplete/);
console.log("Template geometry is valid.");
