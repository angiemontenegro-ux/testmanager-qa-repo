/**
 * @description       : Trigger Handler for Auctifera__Purchase_Order__c
 * @author            : David Lopez
 * @group             : Shop
 * @last modified on  : 01-15-2025
 * @last modified by  : Ethan Montalvo
 **/
public with sharing class PurchaseOrderTriggerHandler extends TriggerHandler {
    final static String CLASS_NAME = PurchaseOrderTriggerHandler.class.getName();

    List<Auctifera__Purchase_Order__c> purchaseOrders;
    Map<Id, Auctifera__Purchase_Order__c> oldPurchaseOrders;

    /**
     * @description class constructor
     */
    public PurchaseOrderTriggerHandler() {
        purchaseOrders = Trigger.new;
        if (Trigger.isUpdate) {
            oldPurchaseOrders = (Map<Id, Auctifera__Purchase_Order__c>) Trigger.oldMap;
        }
    }

    public override void afterUpdate() {
        Set<Id> totalExpensesChangedPurchaseOrders = getPurchaseOrdersWithChangedTotalExpenses();
        if (totalExpensesChangedPurchaseOrders.size() > 0) {
            updateShopItemCosts(totalExpensesChangedPurchaseOrders);
            // SH-1174: expenses can be added/edited after goods are received. Re-prorate the
            // landed cost into the moving-average (ICH) pipeline for the already-received lines.
            recalculateLandedCostForReceivedLines(totalExpensesChangedPurchaseOrders);
        }

        Set<Id> totalChangedPurchaseOrder = getPurchaseOrdersWithChangedTotal();
        if (totalChangedPurchaseOrder.size() > 0) {
            calculatePercentageExpensesAmount(totalChangedPurchaseOrder);
        }
    }

    private Set<Id> getPurchaseOrdersWithChangedTotalExpenses() {
        Set<Id> totalExpensesChangedPurchaseOrders = new Set<Id>();
        for (Auctifera__Purchase_Order__c purchaseOrder : purchaseOrders) {
            Boolean totalExpensesChanged =
                purchaseOrder.Auctifera__Total_Expenses__c !=
                oldPurchaseOrders.get(purchaseOrder.Id).Auctifera__Total_Expenses__c;
            if (totalExpensesChanged) {
                totalExpensesChangedPurchaseOrders.add(purchaseOrder.Id);
            }
        }
        return totalExpensesChangedPurchaseOrders;
    }

    private void updateShopItemCosts(Set<Id> purchaseOrderIds) {
        List<Auctifera__StockReplenishmentOrder__c> relatedStockOrders = [
            SELECT Auctifera__Catalog_Item__c, Auctifera__Item_Variant__c
            FROM Auctifera__StockReplenishmentOrder__c
            WHERE Auctifera__Purchase_Order__c IN :purchaseOrderIds
        ];

        Set<Id> orderedShopItems = new Set<Id>();
        Set<Id> orderedVariants = new Set<Id>();
        for (Auctifera__StockReplenishmentOrder__c stockOrder : relatedStockOrders) {
            orderedShopItems.add(stockOrder.Auctifera__Catalog_Item__c);
            orderedVariants.add(stockOrder.Auctifera__Item_Variant__c);
        }
        orderedShopItems.remove(null);
        orderedVariants.remove(null);

        List<SObject> recordsToUpdate = new List<SObject>();

        if (!orderedShopItems.isEmpty()) {
            recordsToUpdate.addAll(
                StockReplenishmentOrderTriggerHandler.propagateAverageItemCostToItemCost(orderedShopItems)
            );
        }

        if (!orderedVariants.isEmpty()) {
            ItemCostCalculator.VariantCost variantCalculator = new ItemCostCalculator.VariantCost();
            recordsToUpdate.addAll(variantCalculator.calculate(orderedVariants));
        }

        if (!recordsToUpdate.isEmpty()) {
            try {
                DML.vupdate(recordsToUpdate, CLASS_NAME, 66);
            } catch (DmlException e) {
                System.debug(e.getMessage()); //NOPMD due to error debug
                System.debug(e.getStackTraceString()); //NOPMD due to error debug
            }
        }
    }

    /**
     * @description SH-1174: recalculates the landed cost (Item Cost History) of a purchase order's
     * already-received lines when its total expenses change, so adding or editing an expense after
     * receipt re-prorates the moving-average cost without re-touching the lines.
     *
     * @param purchaseOrderIds Purchase orders whose total expenses changed.
     */
    private void recalculateLandedCostForReceivedLines(Set<Id> purchaseOrderIds) {
        List<Auctifera__StockReplenishmentOrder__c> receivedLines = [
            SELECT
                Id,
                Auctifera__Catalog_Item__c,
                Auctifera__Item_Variant__c,
                Auctifera__Order_Amount__c,
                Auctifera__Item_Cost__c,
                Auctifera__Order_Status__c,
                Auctifera__Order_Date__c,
                Auctifera__Purchase_Order__c
            FROM Auctifera__StockReplenishmentOrder__c
            WHERE Auctifera__Purchase_Order__c IN :purchaseOrderIds AND Auctifera__Order_Status__c = 'Received - Complete'
        ];
        if (receivedLines.isEmpty()) {
            return;
        }

        // The purchase order's Total_Expenses__c just changed; drop any cached value so the
        // allocator re-prorates against the new total instead of a stale one.
        LandedCostAllocator.clearCache();

        ItemCostHistoryService itemCostHistoryService = new ItemCostHistoryService();
        List<Auctifera__Item_Cost_History__c> recalculated = itemCostHistoryService.recalculateICHsFromOrders(
            receivedLines
        ); //NOPMD ICH is an acronym for Item Cost History.
        if (recalculated.isEmpty()) {
            return;
        }
        Database.update(recalculated, true, AccessLevel.SYSTEM_MODE);
        itemCostHistoryService.updateICHPointers(recalculated);
    }

    private Set<Id> getPurchaseOrdersWithChangedTotal() {
        Set<Id> purchaseOrderIds = new Set<Id>();
        for (Auctifera__Purchase_Order__c purchaseOrder : purchaseOrders) {
            Boolean totalChanged =
                purchaseOrder.Auctifera__Total_Amount__c !=
                oldPurchaseOrders.get(purchaseOrder.Id).Auctifera__Total_Amount__c;
            if (totalChanged) {
                purchaseOrderIds.add(purchaseOrder.Id);
            }
        }
        return purchaseOrderIds;
    }

    private void calculatePercentageExpensesAmount(Set<Id> purchaseOrderIds) {
        List<Auctifera__Purchase_Order_Expense__c> percentageOrderExpenses = getRelatedPercentageExpenses(
            purchaseOrderIds
        );

        PurchaseOrderExpenseTriggerHandler.AmountCalculator amountCalculator = new PurchaseOrderExpenseTriggerHandler.AmountCalculator();
        amountCalculator.assignAmountFromPercentage(percentageOrderExpenses);

        try {
            DML.vupdate(percentageOrderExpenses, CLASS_NAME, 95);
        } catch (Exception e) {
            System.debug(e.getMessage()); //NOPMD
            System.debug(e.getStackTraceString()); //NOPMD
        }
    }

    private List<Auctifera__Purchase_Order_Expense__c> getRelatedPercentageExpenses(Set<Id> purchaseOrderIds) {
        return [
            SELECT Id, Auctifera__Purchase_Order__c, Auctifera__Percentage__c
            FROM Auctifera__Purchase_Order_Expense__c
            WHERE Auctifera__Purchase_Order__c IN :purchaseOrderIds AND Auctifera__Calculation_Type__c = 'Percentage'
        ];
    }
}