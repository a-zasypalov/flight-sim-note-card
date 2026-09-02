const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

function fail(message) {
  throw new Error(message);
}

function formatDate(value) {
  const year = 2000 + Number(value.slice(0, 2));
  const month = Number(value.slice(2, 4));
  const day = Number(value.slice(4, 6));
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    fail("DOF must contain a real date in YYMMDD format.");
  }
  return `${String(day).padStart(2, "0")} ${MONTHS[month - 1]} ${year}`;
}

export function parseIcaoFlightPlan(source) {
  const text = source.trim().replace(/\s+/g, " ").toUpperCase();
  if (!text.startsWith("(") || !text.endsWith(")")) fail("Use a complete flight plan starting with (FPL- and ending with ).");

  const fields = text.slice(1, -1).split("-").map((field) => field.trim());
  if (fields.length !== 9 || fields[0] !== "FPL") fail("Use one standard FPL message with Items 7, 8, 9, 10, 13, 15, 16, and 18.");

  const identification = fields[1].match(/^([A-Z0-9]{2,7})(?:\/A([0-7]{4}))?$/);
  if (!identification) fail("Item 7 must contain a valid callsign, optionally followed by /A and a four-digit squawk.");
  if (!/^[IVYZ][SNGMX]$/.test(fields[2])) fail("Item 8 must contain valid flight rules and flight type.");

  const aircraft = fields[3].match(/^(?:\d{1,2})?([A-Z0-9]{2,4})\/[LMHJ]$/);
  if (!aircraft) fail("Item 9 must contain an aircraft type and wake category, for example CRJ9/M.");
  if (!/^[A-Z0-9]+\/[A-Z0-9]+$/.test(fields[4])) fail("Item 10 must contain equipment and surveillance data.");

  const departure = fields[5].match(/^([A-Z]{4}|ZZZZ|AFIL)(\d{4})$/);
  if (!departure) fail("Item 13 must contain a departure ICAO code and four-digit EOBT.");

  const route = fields[6].match(/^(?:N\d{4}|K\d{4}|M\d{3})(F\d{3}|A\d{3}|S\d{4}|M\d{4}|VFR)(?:\s|$)/);
  if (!route) fail("Item 15 must start with a valid speed and cruise level, for example N0386F170.");

  const arrival = fields[7].match(/^([A-Z]{4}|ZZZZ)(\d{4})(?:\s+(.+))?$/);
  if (!arrival) fail("Item 16 must contain a destination ICAO code and four-digit EET.");
  const alternates = arrival[3] ? arrival[3].split(" ") : [];
  if (!alternates.every((alternate) => /^(?:[A-Z]{4}|ZZZZ)$/.test(alternate))) fail("Item 16 contains an invalid destination alternate.");

  const other = fields[8];
  if (!other) fail("Item 18 must contain 0 or other flight information.");
  const dof = other.match(/(?:^|\s)DOF\/(\d{6})(?=\s|$)/);
  if (/(?:^|\s)DOF\//.test(other) && !dof) fail("DOF must use six digits in YYMMDD format.");

  return {
    source,
    callsign: identification[1],
    aircraft: aircraft[1],
    date: dof ? formatDate(dof[1]) : "",
    origin: departure[1],
    destination: arrival[1],
    alternate: alternates[0] || "",
    squawk: identification[2] || "",
    cruise: route[1].replace(/^F(\d{3})$/, "FL $1")
  };
}
