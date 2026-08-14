// SH-1174 / TC-70 escenario idx 5: un Inventory Adjustment posterior NO debe corromper el
// promedio landed. Brecha de cobertura real: CERO referencias a Inventory Adjustment en los
// 17 archivos de la PR #2585 (ni en codigo de produccion ni en tests).
//
// Recepcion: 10 u @ $10.00 + $20.00 de gasto -> efectivo $12.00/u -> promedio $12.00, stock 10.
// Luego un Inventory Adjustment de tipo 'Adjustment' da de baja 3 unidades (merma).
// CONVENCION DE SIGNO (verificada en la formula de CatalogItem.Total_Stock__c:
//   Number_of_Items_Ordered - Number_of_Items_Bought - Number_of_Items_Adjusted + ...):
//   Number_of_Items_Adjusted__c se RESTA, asi que una Quantity__c POSITIVA = unidades dadas de baja.
// Esperado: el stock baja a 7, PERO el promedio landed sigue en $12.00 y el ICH de la recepcion
// conserva su desglose (Unit_Cost 10.00 / Allocated_Expense 20.00 / Effective_Cost 12.00).

String tag = 'QA-1174-S5-' + String.valueOf(Datetime.now().getTime());

List<Auctifera__POS_Settings__c> settings = [SELECT Id, Auctifera__Use_Weighted_Cost_Item_Calculation__c FROM Auctifera__POS_Settings__c LIMIT 1];
if (settings.isEmpty()) {
    insert new Auctifera__POS_Settings__c(Auctifera__Use_Weighted_Cost_Item_Calculation__c = true);
} else if (settings[0].Auctifera__Use_Weighted_Cost_Item_Calculation__c != true) {
    settings[0].Auctifera__Use_Weighted_Cost_Item_Calculation__c = true;
    update settings[0];
}

Auctifera__CatalogItem__c shopItem = new Auctifera__CatalogItem__c(
    Name = tag + ' Mug',
    Auctifera__Product_ID__c = tag,
    Auctifera__Price__c = 25
);
insert shopItem;

Auctifera__Purchase_Order__c po = new Auctifera__Purchase_Order__c(Name = tag + ' PO');
insert po;
insert new Auctifera__Purchase_Order_Expense__c(
    Name = 'Freight',
    Auctifera__Purchase_Order__c = po.Id,
    Auctifera__Calculation_Type__c = 'Amount',
    Auctifera__Amount__c = 20
);
Auctifera__StockReplenishmentOrder__c line = new Auctifera__StockReplenishmentOrder__c(
    Auctifera__Catalog_Item__c = shopItem.Id,
    Auctifera__Purchase_Order__c = po.Id,
    Auctifera__Order_Amount__c = 10,
    Auctifera__Order_Date__c = Date.newInstance(2026, 1, 1),
    Auctifera__Order_Status__c = 'Draft',
    Auctifera__Item_Cost__c = 10
);
insert line;
line.Auctifera__Order_Status__c = 'Received - Complete';
update line;

Auctifera__CatalogItem__c beforeAdj = [SELECT Auctifera__Current_Item_Cost__c, Auctifera__Total_Stock__c FROM Auctifera__CatalogItem__c WHERE Id = :shopItem.Id];
List<Auctifera__Item_Cost_History__c> ichBefore = [
    SELECT Auctifera__Cost__c, Auctifera__Stock__c, Auctifera__Unit_Cost__c,
           Auctifera__Allocated_Expense__c, Auctifera__Effective_Cost__c
    FROM Auctifera__Item_Cost_History__c
    WHERE Auctifera__Shop_Item__c = :shopItem.Id
    ORDER BY Auctifera__Effective_At__c ASC, CreatedDate ASC
];
System.debug('=== SH-1174 S5 :: ANTES DEL AJUSTE ===');
System.debug('Current_Item_Cost__c = ' + beforeAdj.Auctifera__Current_Item_Cost__c + ' (esperado 12.00)');
System.debug('Total_Stock__c       = ' + beforeAdj.Auctifera__Total_Stock__c + ' (esperado 10)');
for (Auctifera__Item_Cost_History__c ich : ichBefore) {
    System.debug('ICH cost=' + ich.Auctifera__Cost__c + ' stock=' + ich.Auctifera__Stock__c +
        ' unitCost=' + ich.Auctifera__Unit_Cost__c + ' allocExpense=' + ich.Auctifera__Allocated_Expense__c +
        ' effectiveCost=' + ich.Auctifera__Effective_Cost__c);
}

// ---------- INVENTORY ADJUSTMENT: merma de 3 unidades ----------
Auctifera__Inventory_Adjustment__c adjustment = new Auctifera__Inventory_Adjustment__c(
    Auctifera__Shop_Item__c = shopItem.Id,
    Auctifera__Quantity__c = 3,
    Auctifera__Type__c = 'Adjustment',
    Auctifera__Adjustment_Reason__c = 'Damaged/Broken',
    Auctifera__Adjustment_Date__c = Date.newInstance(2026, 3, 1)
);
insert adjustment;

Auctifera__CatalogItem__c afterAdj = [SELECT Auctifera__Current_Item_Cost__c, Auctifera__Total_Stock__c FROM Auctifera__CatalogItem__c WHERE Id = :shopItem.Id];
List<Auctifera__Item_Cost_History__c> ichAfter = [
    SELECT Auctifera__Cost__c, Auctifera__Previous_Cost__c, Auctifera__Stock__c, Auctifera__Previous_Stock__c,
           Auctifera__Unit_Cost__c, Auctifera__Allocated_Expense__c, Auctifera__Effective_Cost__c
    FROM Auctifera__Item_Cost_History__c
    WHERE Auctifera__Shop_Item__c = :shopItem.Id
    ORDER BY Auctifera__Effective_At__c ASC, CreatedDate ASC
];
Auctifera__Inventory_Adjustment__c adjAfter = [
    SELECT Auctifera__Quantity__c, Auctifera__Snapshot_Item_Cost__c, Item_Cost_History__c, Auctifera__Merchandise_Cost__c
    FROM Auctifera__Inventory_Adjustment__c WHERE Id = :adjustment.Id
];

System.debug('=== SH-1174 S5 :: DESPUES DEL AJUSTE ===');
System.debug('Current_Item_Cost__c = ' + afterAdj.Auctifera__Current_Item_Cost__c + ' (esperado 12.00, SIN cambio)');
System.debug('Total_Stock__c       = ' + afterAdj.Auctifera__Total_Stock__c + ' (esperado 7)');
System.debug('Ajuste: qty=' + adjAfter.Auctifera__Quantity__c + ' snapshotCost=' + adjAfter.Auctifera__Snapshot_Item_Cost__c +
    ' ICH=' + adjAfter.Item_Cost_History__c + ' merchandiseCost=' + adjAfter.Auctifera__Merchandise_Cost__c);
System.debug('=== CADENA ICH DESPUES (' + ichAfter.size() + ') ===');
for (Auctifera__Item_Cost_History__c ich : ichAfter) {
    System.debug('ICH prevCost=' + ich.Auctifera__Previous_Cost__c + ' cost=' + ich.Auctifera__Cost__c +
        ' prevStock=' + ich.Auctifera__Previous_Stock__c + ' stock=' + ich.Auctifera__Stock__c +
        ' unitCost=' + ich.Auctifera__Unit_Cost__c + ' allocExpense=' + ich.Auctifera__Allocated_Expense__c +
        ' effectiveCost=' + ich.Auctifera__Effective_Cost__c);
}

Boolean costIntact = afterAdj.Auctifera__Current_Item_Cost__c == 12.00;
Boolean breakdownIntact = !ichAfter.isEmpty() && ichAfter[0].Auctifera__Allocated_Expense__c == 20 && ichAfter[0].Auctifera__Effective_Cost__c == 12;
System.debug('=== VEREDICTO S5: promedio intacto=' + costIntact + ' | desglose intacto=' + breakdownIntact + ' ===');
System.debug('Shop Item Id: ' + shopItem.Id);
