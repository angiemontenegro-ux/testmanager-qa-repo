// SH-1174 / TC-70 escenario idx 2 (AC-3): una recepcion posterior promedia el nuevo costo landed
// contra el promedio existente. Cubre la brecha de los tests del dev: los 10 tests funcionales
// insertan UNA sola Purchase Order, asi que nunca mezclan DOS costos efectivos distintos.
//
// PO-1: 10 u @ $10.00 + $20.00 de gasto -> efectivo $12.00/u -> promedio $12.00
// PO-2: 10 u @ $6.00  + $40.00 de gasto -> efectivo $10.00/u
// Promedio esperado = ((10 x 12.00) + (10 x 10.00)) / 20 = $11.00

String tag = 'QA-1174-S2-' + String.valueOf(Datetime.now().getTime());

// El pipeline de promedio ponderado esta detras de este custom setting.
List<Auctifera__POS_Settings__c> settings = [SELECT Id, Auctifera__Use_Weighted_Cost_Item_Calculation__c FROM Auctifera__POS_Settings__c LIMIT 1];
if (settings.isEmpty()) {
    insert new Auctifera__POS_Settings__c(Auctifera__Use_Weighted_Cost_Item_Calculation__c = true);
} else if (settings[0].Auctifera__Use_Weighted_Cost_Item_Calculation__c != true) {
    settings[0].Auctifera__Use_Weighted_Cost_Item_Calculation__c = true;
    update settings[0];
}

Auctifera__CatalogItem__c shopItem = new Auctifera__CatalogItem__c(
    Name = tag + ' Tote',
    Auctifera__Product_ID__c = tag,
    Auctifera__Price__c = 30
);
insert shopItem;

// ---------- PRIMERA PURCHASE ORDER ----------
Auctifera__Purchase_Order__c po1 = new Auctifera__Purchase_Order__c(Name = tag + ' PO-1');
insert po1;
insert new Auctifera__Purchase_Order_Expense__c(
    Name = 'Freight PO-1',
    Auctifera__Purchase_Order__c = po1.Id,
    Auctifera__Calculation_Type__c = 'Amount',
    Auctifera__Amount__c = 20
);
Auctifera__StockReplenishmentOrder__c line1 = new Auctifera__StockReplenishmentOrder__c(
    Auctifera__Catalog_Item__c = shopItem.Id,
    Auctifera__Purchase_Order__c = po1.Id,
    Auctifera__Order_Amount__c = 10,
    Auctifera__Order_Date__c = Date.newInstance(2026, 1, 1),
    Auctifera__Order_Status__c = 'Draft',
    Auctifera__Item_Cost__c = 10
);
insert line1;
line1.Auctifera__Order_Status__c = 'Received - Complete';
update line1;

Auctifera__CatalogItem__c afterFirst = [SELECT Auctifera__Current_Item_Cost__c, Auctifera__Total_Stock__c FROM Auctifera__CatalogItem__c WHERE Id = :shopItem.Id];
System.debug('=== SH-1174 S2 :: DESPUES DE PO-1 ===');
System.debug('Current_Item_Cost__c = ' + afterFirst.Auctifera__Current_Item_Cost__c + ' (esperado 12.00)');
System.debug('Total_Stock__c       = ' + afterFirst.Auctifera__Total_Stock__c + ' (esperado 10)');

// ---------- SEGUNDA PURCHASE ORDER, INDEPENDIENTE, OTRO COSTO EFECTIVO ----------
Auctifera__Purchase_Order__c po2 = new Auctifera__Purchase_Order__c(Name = tag + ' PO-2');
insert po2;
insert new Auctifera__Purchase_Order_Expense__c(
    Name = 'Freight PO-2',
    Auctifera__Purchase_Order__c = po2.Id,
    Auctifera__Calculation_Type__c = 'Amount',
    Auctifera__Amount__c = 40
);
Auctifera__StockReplenishmentOrder__c line2 = new Auctifera__StockReplenishmentOrder__c(
    Auctifera__Catalog_Item__c = shopItem.Id,
    Auctifera__Purchase_Order__c = po2.Id,
    Auctifera__Order_Amount__c = 10,
    Auctifera__Order_Date__c = Date.newInstance(2026, 2, 1),
    Auctifera__Order_Status__c = 'Draft',
    Auctifera__Item_Cost__c = 6
);
insert line2;
line2.Auctifera__Order_Status__c = 'Received - Complete';
update line2;

Auctifera__CatalogItem__c afterSecond = [SELECT Auctifera__Current_Item_Cost__c, Auctifera__Total_Stock__c FROM Auctifera__CatalogItem__c WHERE Id = :shopItem.Id];

List<Auctifera__Item_Cost_History__c> ichs = [
    SELECT Auctifera__Effective_At__c, Auctifera__Previous_Cost__c, Auctifera__Cost__c,
           Auctifera__Previous_Stock__c, Auctifera__Stock__c,
           Auctifera__Unit_Cost__c, Auctifera__Allocated_Expense__c, Auctifera__Effective_Cost__c,
           Auctifera__Stock_Replenishment_Order__r.Auctifera__Purchase_Order__r.Name
    FROM Auctifera__Item_Cost_History__c
    WHERE Auctifera__Shop_Item__c = :shopItem.Id
    ORDER BY Auctifera__Effective_At__c ASC, CreatedDate ASC
];

System.debug('=== SH-1174 S2 :: DESPUES DE PO-2 ===');
System.debug('Current_Item_Cost__c = ' + afterSecond.Auctifera__Current_Item_Cost__c + ' (esperado 11.00)');
System.debug('Total_Stock__c       = ' + afterSecond.Auctifera__Total_Stock__c + ' (esperado 20)');
System.debug('=== CADENA DE ITEM COST HISTORY (' + ichs.size() + ' registros) ===');
for (Auctifera__Item_Cost_History__c ich : ichs) {
    System.debug(
        'PO=' + ich.Auctifera__Stock_Replenishment_Order__r.Auctifera__Purchase_Order__r.Name +
        ' | prevCost=' + ich.Auctifera__Previous_Cost__c +
        ' | cost=' + ich.Auctifera__Cost__c +
        ' | prevStock=' + ich.Auctifera__Previous_Stock__c +
        ' | stock=' + ich.Auctifera__Stock__c +
        ' | unitCost=' + ich.Auctifera__Unit_Cost__c +
        ' | allocExpense=' + ich.Auctifera__Allocated_Expense__c +
        ' | effectiveCost=' + ich.Auctifera__Effective_Cost__c
    );
}

Boolean pass = afterSecond.Auctifera__Current_Item_Cost__c == 11.00 && afterSecond.Auctifera__Total_Stock__c == 20;
System.debug('=== VEREDICTO S2: ' + (pass ? 'PASS' : 'FAIL') + ' ===');
System.debug('Shop Item Id (para inspeccion en Lightning): ' + shopItem.Id);
