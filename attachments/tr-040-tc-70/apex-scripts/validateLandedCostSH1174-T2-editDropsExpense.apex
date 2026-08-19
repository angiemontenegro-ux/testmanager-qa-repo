// SH-1174 / TR-037 regresion tecnica T2 (HALLAZGO-1): al editar el costo de una linea YA RECIBIDA,
// el ICH pierde el gasto asignado y vuelve a base de costo CRUDO. El gasto de la PO queda sin
// asignar en esa linea hasta que Total_Expenses__c cambie otra vez.
//
// Montaje: PO con $100 de flete, dos lineas de 10 u @ $10 = $100 c/u (valor total $200).
//   Prorrateo -> $50 por linea -> $5/u -> costo efectivo $15/u. Promedio tras ambas recepciones: $15.00.
// Accion: se edita Item_Cost__c de la linea A de $10 a $20 (correccion post-recepcion).
// Esperado por AC-1/AC-2 (prorrateo por valor + promedio sobre costo landed):
//   nuevos valores A=$200, B=$100 -> $100 de flete reparte A $66.67 ($6.667/u -> efectivo $26.667)
//   y B $33.33 ($3.333/u -> efectivo $13.333) -> promedio final $20.00.
// Observado con la PR: ver salida.

// OJO (2026-08-19, head f1b460100d): desde el fix de SH-1200 la edicion de una linea recibida cuya PO
// tiene gasto se re-prorratea de forma ASINCRONA (LandedCostExpenseRecalcQueueable). Este script hace
// el montaje y la edicion; la LECTURA va en el script hermano T2b, que hay que correr DESPUES de que
// el job termine. Leer en la misma ejecucion devuelve el estado PRE-recalculo y parece un falso FAIL.
String tag = 'QA-1174-T2-' + String.valueOf(Datetime.now().getTime());

List<Auctifera__POS_Settings__c> settings = [SELECT Id, Auctifera__Use_Weighted_Cost_Item_Calculation__c FROM Auctifera__POS_Settings__c LIMIT 1];
if (settings.isEmpty()) {
    insert new Auctifera__POS_Settings__c(Auctifera__Use_Weighted_Cost_Item_Calculation__c = true);
}

Auctifera__CatalogItem__c shopItem = new Auctifera__CatalogItem__c(
    Name = tag + ' Item', Auctifera__Product_ID__c = tag, Auctifera__Price__c = 40);
insert shopItem;

Auctifera__Purchase_Order__c po = new Auctifera__Purchase_Order__c(Name = tag + ' PO');
insert po;
insert new Auctifera__Purchase_Order_Expense__c(
    Name = 'Freight', Auctifera__Purchase_Order__c = po.Id,
    Auctifera__Calculation_Type__c = 'Amount', Auctifera__Amount__c = 100);

Auctifera__StockReplenishmentOrder__c lineA = new Auctifera__StockReplenishmentOrder__c(
    Auctifera__Catalog_Item__c = shopItem.Id, Auctifera__Purchase_Order__c = po.Id,
    Auctifera__Order_Amount__c = 10, Auctifera__Order_Date__c = Date.newInstance(2026, 1, 1),
    Auctifera__Order_Status__c = 'Draft', Auctifera__Item_Cost__c = 10);
Auctifera__StockReplenishmentOrder__c lineB = new Auctifera__StockReplenishmentOrder__c(
    Auctifera__Catalog_Item__c = shopItem.Id, Auctifera__Purchase_Order__c = po.Id,
    Auctifera__Order_Amount__c = 10, Auctifera__Order_Date__c = Date.newInstance(2026, 1, 2),
    Auctifera__Order_Status__c = 'Draft', Auctifera__Item_Cost__c = 10);
insert new List<Auctifera__StockReplenishmentOrder__c>{ lineA, lineB };

lineA.Auctifera__Order_Status__c = 'Received - Complete'; update lineA;
lineB.Auctifera__Order_Status__c = 'Received - Complete'; update lineB;

Auctifera__CatalogItem__c before = [SELECT Auctifera__Current_Item_Cost__c FROM Auctifera__CatalogItem__c WHERE Id = :shopItem.Id];
System.debug('=== T2 :: ANTES DE LA EDICION ===');
System.debug('Current_Item_Cost__c = ' + before.Auctifera__Current_Item_Cost__c + ' (esperado 15.00)');
for (Auctifera__Item_Cost_History__c ich : [
        SELECT Auctifera__Cost__c, Auctifera__Unit_Cost__c, Auctifera__Allocated_Expense__c, Auctifera__Effective_Cost__c,
               Auctifera__Stock_Replenishment_Order__c
        FROM Auctifera__Item_Cost_History__c WHERE Auctifera__Shop_Item__c = :shopItem.Id
        ORDER BY Auctifera__Effective_At__c ASC, CreatedDate ASC]) {
    System.debug((ich.Auctifera__Stock_Replenishment_Order__c == lineA.Id ? 'LINEA A' : 'LINEA B') +
        ' cost=' + ich.Auctifera__Cost__c + ' unitCost=' + ich.Auctifera__Unit_Cost__c +
        ' allocExpense=' + ich.Auctifera__Allocated_Expense__c + ' effectiveCost=' + ich.Auctifera__Effective_Cost__c);
}

// ACCION: correccion del costo de la linea A despues de recibida
lineA.Auctifera__Item_Cost__c = 20;
update lineA;

System.debug('=== T2 :: EDICION APLICADA — el recalculo corre ASINCRONO ===');
System.debug('Correr scripts/apex/validateLandedCostSH1174-T2b-readback.apex cuando el job termine.');
System.debug('Verificar el job: SELECT Status FROM AsyncApexJob WHERE ApexClass.Name = \'LandedCostExpenseRecalcQueueable\' ORDER BY CreatedDate DESC LIMIT 1');
System.debug('Shop Item Id: ' + shopItem.Id);
System.debug('Product_ID__c: ' + tag);
