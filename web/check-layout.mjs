import assert from "node:assert/strict";
import { FORMATS } from "./templates.js";

assert.deepEqual(FORMATS.a4.page, [297, 210]);
assert.deepEqual(FORMATS.a5.page, [148, 210]);
assert.equal(FORMATS.a4.logoBoxes.length, 2);
assert.equal(FORMATS.a4.logoBoxes[1].x - FORMATS.a4.logoBoxes[0].x, 148.5);
assert.equal(FORMATS.a5.logoBoxes[0].width, 38);
console.log("Template geometry is valid.");
