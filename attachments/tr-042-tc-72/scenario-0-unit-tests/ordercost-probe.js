// Faithful reproduction of the restored helper block (wizard 1 indices [2]/[3]/[4]).
// Source: ReplenishmentOrderWizardHelper.js lines ~121-131 as merged in 0af31068.
function restoredHelperBlock(shopItemCost, orderQuantityValue) {
  const itemRow = [{ cost: null }, {}, { value: null }, { value: orderQuantityValue }, { value: null }];
  if (shopItemCost !== undefined) {          // <-- the guard, verbatim
    const itemCost = itemRow[2];
    const orderQuantity = itemRow[3];
    const orderCost = itemRow[4];
    itemCost.value = shopItemCost;
    itemRow[0].cost = shopItemCost;
    orderCost.value = itemCost.value * orderQuantity.value;   // <-- UNGUARDED multiply
  }
  return { itemCost: itemRow[2].value, orderCost: itemRow[4].value, entered: shopItemCost !== undefined };
}

const cases = [
  ["TC-72 S1/S4: cost 25, qty 3 (normal)",        25,        3],
  ["TC-72 S4: cost 50, qty 3",                    50,        3],
  ["TC-72 S6: cost 0, qty 5 (zero-cost edge)",     0,        5],
  ["TC-72 S7: cost null, qty 3 (SOQL empty field)", null,     3],
  ["FRESH ROW: cost 25, qty null (no qty yet)",   25,     null],
  ["FRESH ROW: cost 25, qty undefined",           25, undefined],
  ["FIELD ABSENT: cost undefined (no selectFields)", undefined, 3],
];
console.log("case".padEnd(48), "| itemCost".padEnd(12), "| orderCost".padEnd(12), "| block ran");
console.log("-".repeat(92));
for (const [label, c, q] of cases) {
  const r = restoredHelperBlock(c, q);
  console.log(label.padEnd(48), "|", String(r.itemCost).padEnd(10), "|", String(r.orderCost).padEnd(10), "|", r.entered);
}
