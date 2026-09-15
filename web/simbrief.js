const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

function value(input) {
  return typeof input === "string" || typeof input === "number" ? String(input).trim() : "";
}

function list(input) {
  return Array.isArray(input) ? input : input && typeof input === "object" ? [input] : [];
}

function formatDate(input) {
  const date = new Date(Number(input) * 1000);
  if (!input || Number.isNaN(date.getTime())) throw new Error("The SimBrief plan has an invalid departure date.");
  return `${String(date.getUTCDate()).padStart(2, "0")} ${MONTHS[date.getUTCMonth()]} ${date.getUTCFullYear()}`;
}

function formatAltitude(input) {
  const altitude = value(input).toUpperCase().replaceAll(" ", "");
  const level = altitude.match(/^FL(\d{2,3})$/)?.[1] || altitude.match(/^F(\d{3})$/)?.[1];
  if (level) return `FL ${Number(level)}`;
  if (/^\d+$/.test(altitude)) return `FL ${Math.round(Number(altitude) / 100)}`;
  throw new Error("The SimBrief plan has an invalid cruise altitude.");
}

function procedure(data, type) {
  const field = `${type}_ident`;
  const direct = [data[field], data.atc?.[field], data.general?.[field], data[type === "sid" ? "origin" : "destination"]?.[field]].map(value).find(Boolean);
  if (direct) return direct;
  const fixes = list(data.navlog?.fix).filter((fix) => value(fix.is_sid_star) === "1" && value(fix.via_airway));
  const descent = fixes.filter((fix) => /^(DES|ARR)/.test(value(fix.stage)));
  if (type === "sid") return value(fixes.find((fix) => !descent.includes(fix))?.via_airway);
  return value(descent.at(-1)?.via_airway || (fixes.length > 1 ? fixes.at(-1)?.via_airway : ""));
}

function routeLine(data, sid, star) {
  const route = value(data.general?.route).replace(/\s+/g, " ");
  const has = (procedure) => route.toUpperCase().split(" ").includes(procedure.toUpperCase());
  const airport = (place) => [value(place?.icao_code), value(place?.plan_rwy)].filter(Boolean).join("/");
  return [airport(data.origin), sid && !has(sid) ? sid : "", route, star && !has(star) ? star : "", airport(data.destination)].filter(Boolean).join(" ");
}

export function parseSimBriefFlightPlan(data) {
  if (data?.fetch?.status !== "Success") throw new Error("SimBrief could not return a current flight plan.");

  const airline = value(data.general?.icao_airline);
  const flightNumber = value(data.general?.flight_number);
  const flightCallsign = airline && flightNumber ? `${airline}${flightNumber}` : "";
  const sid = procedure(data, "sid");
  const star = procedure(data, "star");
  const plan = {
    source: value(data.atc?.flight_plan),
    callsign: value(data.atc?.callsign) || flightCallsign || value(data.aircraft?.reg),
    aircraft: value(data.aircraft?.icaocode),
    date: formatDate(data.times?.sched_out),
    origin: value(data.origin?.icao_code),
    destination: value(data.destination?.icao_code),
    alternate: value(data.alternate?.icao_code),
    squawk: "",
    sid,
    cruise: formatAltitude(data.general?.initial_altitude),
    departureRunway: value(data.origin?.plan_rwy),
    inFlightRoute: routeLine(data, sid, star)
  };
  if (!plan.callsign || !plan.aircraft || !plan.origin || !plan.destination) {
    throw new Error("The latest SimBrief flight plan is incomplete.");
  }
  return plan;
}

export async function fetchSimBriefFlightPlan(username, signal) {
  const user = username.trim();
  if (!user) throw new Error("Enter your SimBrief username.");
  const query = new URLSearchParams({ username: user, json: "1" });
  let response;
  try {
    response = await fetch(`https://www.simbrief.com/api/xml.fetcher.php?${query}`, { signal });
  } catch (error) {
    if (error.name === "AbortError") throw error;
    throw new Error("Could not reach SimBrief. Check your connection and try again.");
  }

  let data;
  try {
    data = await response.json();
  } catch {
    throw new Error("SimBrief returned an unreadable response.");
  }
  if (!response.ok || data?.fetch?.status !== "Success") {
    if (/unknown user/i.test(value(data?.fetch?.status))) throw new Error("SimBrief user not found.");
    throw new Error("SimBrief could not return a current flight plan.");
  }
  return parseSimBriefFlightPlan(data);
}
