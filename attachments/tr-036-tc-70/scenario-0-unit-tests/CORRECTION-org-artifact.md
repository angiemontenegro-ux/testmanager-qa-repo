# CORRECTION — the original FAIL in this run was a QA org artifact, not a PR defect

Written after the fact. The first execution of TR-036 reported
`LandedCostOnReceiptTest.addingExpenseAfterReceiptReproratesLandedCost` as a deterministic
FAIL (`Expected: 10, Actual: 0.00`) and raised SH-1182 as a High blocker. **That conclusion was
wrong.** The PR code is correct. This file documents the correction so the run's history is
auditable.

## Final evidence

| Org | Baseline | Code under test | Result |
|---|---|---|---|
| `AuctiferaDX__sh890` | created **Jul 9**, only the PR's 12 changed files deployed on top | `f3b892c` exact | **FAIL — `Actual: 0.00`** |
| `AuctiferaDX__sh1169` | created Jul 31 (dev's own org), nothing deployed by QA | functionally identical to `f3b892c` | **PASS 11/11** |
| `AuctiferaDX__sh1169` | same org, after deploying the **byte-exact** `f3b892c` files | `f3b892c` exact | **PASS 11/11** |
| `sh1174qa` | created **clean today** from the PR branch, full `force-app` deploy (12,425/12,425 components, 0 errors) | `f3b892c` exact | **PASS 11/11** |

Two independent orgs pass with the exact committed code. Only the stale `sh890` fails.

Evidence files:
- `sh1169-exact-code-rerun-PASS.json` — 11/11 PASS in sh1169 with byte-exact PR code
- `sh1174qa-clean-org-rerun-PASS.json` — 11/11 PASS in the clean org
- `formatting-only-diff.txt` — the complete diff between the dev's deployed classes and `f3b892c`
- `sh1169-POTH.cls` — the dev's actual deployed `PurchaseOrderTriggerHandler` body, retrieved via Tooling API

## The dev's fix was real and already working

`ApexTestResult` history in sh1169:

- `2026-08-05T01:09:45` — `addingExpenseAfterReceiptReproratesLandedCost` **Fail**, `Expected: 10, Actual: 8.00`
- `2026-08-05T01:26:37` — fix deployed
- `2026-08-05T01:27:17` — same test **Pass**

The genuine bug was "expense not folded in" → `8.00`, and it was fixed before the commit. QA's
`0.00` was a **different symptom**; conflating the two produced the wrong conclusion.

## The "uncommitted changes" theory was also wrong

The size deltas QA observed between the dev's org and `f3b892c` (32 chars in
`PurchaseOrderTriggerHandler`, 216 in `LandedCostOnReceiptTest`) were **pure prettier formatting**
— a SOQL `WHERE` clause re-wrapped across three lines, some assert calls re-wrapped, and a trailing
newline. Zero functional difference. See `formatting-only-diff.txt`.

## Root cause of the false positive — process lesson

QA deployed **only the PR's 12 changed files** onto an org whose metadata baseline was ~1 month old,
and treated the result as conclusive.

This change depends on a trigger chain:

```
insert Purchase_Order_Expense__c
  -> Total_Expenses__c roll-up on the Purchase Order
    -> PurchaseOrderTriggerHandler.getPurchaseOrdersWithChangedTotalExpenses
      -> recalculateLandedCostForReceivedLines
        -> ItemCostHistoryService.recalculateICHsFromOrders
          -> ICHCostCalculationService.calculateWeightedAverageCost
```

For a change like this the org's **whole metadata state is part of the test subject**, not
background scenery. The observed `0.00` traces to this guard in `ICHCostCalculationService`:

```apex
Decimal newStock = previousStock + incomingQuantity;
if (newStock == 0) {
    return CostSnapshot.zero();
}
```

which is consistent with a broken link in that chain in the stale org (an incoming quantity or
previous-stock value not resolving), not with the allocator's arithmetic.

**Rule going forward:** when validating a trigger-chain change, either deploy the full package or
use an org built from the branch. A partial deploy onto an old baseline can produce failures that do
not exist in the code. `AuctiferaDX__sh890` is retired from SH-1174 validation.

## Status of SH-1182

Downgraded High -> Low, retitled `[Likely invalid - QA org artifact] ...`, and documented with two
comments carrying the full evidence. It could not be transitioned to a closed status — the only
workflow transition available from `Not started` is *Ready for development* — so a **manual close as
Cannot Reproduce** was requested from someone with the right workflow permission.

## What remains genuinely open for SH-1174

Unrelated to this correction, and still the real blocker for QA sign-off — two ACs with no test
coverage in the PR, still `not-run` in this test run:

- **ac-3** — a later receipt averages the landed cost again (second receipt into an item that
  already carries an average from a prior, separate PO)
- **ac-5** — short receipt: expense folds into units actually received, shortfall corrected via a
  separate Inventory Adjustment

`sh1174qa` (clean, fully deployed, expires 2026-08-08) is now available and is the right org to
validate both.
