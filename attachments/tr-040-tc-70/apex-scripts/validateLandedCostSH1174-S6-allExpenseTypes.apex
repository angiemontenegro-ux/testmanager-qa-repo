// SH-1174 / TC-70 escenario idx 6 (AC-6): TODO tipo de gasto del modulo de gastos (flete, impuesto,
// manejo, aduana, seguro) entra al costo landed sin excepcion. Ningun test del dev combina 3+ tipos
// de gasto concurrentes, asi que QA lo cubre aqui.
//
// PO con CINCO lineas de gasto: 10 + 20 + 30 + 15 + 25 = $100 total.
// Una linea de 10 u @ $10.00 -> efectivo = 10 + 100/10 = $20.00/u. Promedio esperado $20.00.
// Si algun tipo quedara excluido, el efectivo saldria por debajo de $20.00.

String tag = 'QA-1174-S6-' + String.valueOf(Datetime.now().getTime());

List<Auctifera__POS_Settings__c> settings = [SELECT Id FROM Auctifera__POS_Settings__c LIMIT 1];
if (settings.isEmpty()) {
    insert new Auctifera__POS_Settings__c(Auctifera__Use_Weighted_Cost_Item_Calculation__c = true);
}

Auctifera__CatalogItem__c shopItem = new Auctifera__CatalogItem__c(
    Name = tag + ' Item', Auctifera__Product_ID__c = tag, Auctifera__Price__c = 50);
insert shopItem;

Auctifera__Purchase_Order__c po = new Auctifera__Purchase_Order__c(Name = tag + ' PO');
insert po;

// Los 5 tipos de gasto del ticket, como lineas SEPARADAS del modulo de gastos.
List<Auctifera__Purchase_Order_Expense__c> expenses = new List<Auctifera__Purchase_Order_Expense__c>{
    new Auctifera__Purchase_Order_Expense__c(Name = 'Freight',   Auctifera__Purchase_Order__c = po.Id, Auctifera__Calculation_Type__c = 'Amount', Auctifera__Amount__c = 10),
    new Auctifera__Purchase_Order_Expense__c(Name = 'Tax',       Auctifera__Purchase_Order__c = po.Id, Auctifera__Calculation_Type__c = 'Amount', Auctifera__Amount__c = 20),
    new Auctifera__Purchase_Order_Expense__c(Name = 'Handling',  Auctifera__Purchase_Order__c = po.Id, Auctifera__Calculation_Type__c = 'Amount', Auctifera__Amount__c = 30),
    new Auctifera__Purchase_Order_Expense__c(Name = 'Duties',    Auctifera__Purchase_Order__c = po.Id, Auctifera__Calculation_Type__c = 'Amount', Auctifera__Amount__c = 15),
    new Auctifera__Purchase_Order_Expense__c(Name = 'Insurance', Auctifera__Purchase_Order__c = po.Id, Auctifera__Calculation_Type__c = 'Amount', Auctifera__Amount__c = 25)
};
insert expenses;

Auctifera__Purchase_Order__c poCheck = [SELECT Auctifera__Total_Expenses__c FROM Auctifera__Purchase_Order__c WHERE Id = :po.Id];
System.debug('=== SH-1174 S6 :: GASTOS EN LA PO ===');
System.debug('5 lineas de gasto (Freight 10, Tax 20, Handling 30, Duties 15, Insurance 25)');
System.debug('Total_Expenses__c = ' + poCheck.Auctifera__Total_Expenses__c + ' (esperado 100.00 — ningun tipo excluido del rollup)');

Auctifera__StockReplenishmentOrder__c line = new Auctifera__StockReplenishmentOrder__c(
    Auctifera__Catalog_Item__c = shopItem.Id, Auctifera__Purchase_Order__c = po.Id,
    Auctifera__Order_Amount__c = 10, Auctifera__Order_Date__c = Date.newInstance(2026, 1, 1),
    Auctifera__Order_Status__c = 'Draft', Auctifera__Item_Cost__c = 10);
insert line;
line.Auctifera__Order_Status__c = 'Received - Complete';
update line;

Auctifera__CatalogItem__c after = [SELECT Auctifera__Current_Item_Cost__c, Auctifera__Total_Stock__c FROM Auctifera__CatalogItem__c WHERE Id = :shopItem.Id];
List<Auctifera__Item_Cost_History__c> ichs = [
    SELECT Auctifera__Cost__c, Auctifera__Unit_Cost__c, Auctifera__Allocated_Expense__c, Auctifera__Effective_Cost__c
    FROM Auctifera__Item_Cost_History__c WHERE Auctifera__Shop_Item__c = :shopItem.Id];

System.debug('=== SH-1174 S6 :: DESPUES DE RECIBIR ===');
System.debug('Current_Item_Cost__c = ' + after.Auctifera__Current_Item_Cost__c + ' (esperado 20.00 = 10 + 100/10)');
System.debug('Total_Stock__c       = ' + after.Auctifera__Total_Stock__c + ' (esperado 10)');
for (Auctifera__Item_Cost_History__c ich : ichs) {
    System.debug('ICH cost=' + ich.Auctifera__Cost__c + ' unitCost=' + ich.Auctifera__Unit_Cost__c +
        ' allocExpense=' + ich.Auctifera__Allocated_Expense__c + ' (esperado 100.00) effectiveCost=' + ich.Auctifera__Effective_Cost__c);
}
Boolean pass = after.Auctifera__Current_Item_Cost__c == 20.00 && !ichs.isEmpty() && ichs[0].Auctifera__Allocated_Expense__c == 100;
System.debug('=== VEREDICTO S6: ' + (pass ? 'PASS' : 'FAIL') + ' — los 5 tipos de gasto entran al costo landed ===');
System.debug('Shop Item Id: ' + shopItem.Id);
