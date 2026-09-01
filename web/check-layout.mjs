import assert from "node:assert/strict";
import { FORMATS } from "./card.js";

assert.deepEqual(FORMATS.a5.page, [148, 210]);
assert.deepEqual(FORMATS.a4.page, [297, 210]);
assert.equal(FORMATS.a5.cards[0].width, 138);
assert.equal(FORMATS.a5.cards[0].height, 200);
assert.equal(FORMATS.a4.cards[0].x, 5);
assert.equal(FORMATS.a4.cards[0].x + FORMATS.a4.cards[0].width, 143.5);
assert.equal(FORMATS.a4.cards[1].x, 153.5);
assert.equal(FORMATS.a4.cards[1].x + FORMATS.a4.cards[1].width, 292);
console.log("Card geometry is valid.");
