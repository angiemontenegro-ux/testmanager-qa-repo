// SH-1174 / TR-038 — lectura del resultado de T2 DESPUES de que corra el recalculo asincrono.
// Correr solo cuando LandedCostExpenseRecalcQueueable este en Completed.
//
// Montaje que dejo T2: PO con $100 de flete, linea A 10u @ $10 -> editada a $20, linea B 10u @ $10.
// Esperado por AC-1/AC-2 tras el fix de SH-1200 (nuevos valores A=$200, B=$100, total $300):
//   linea A: gasto 100 x 200/300 = 66.666667 -> efectivo 20 + 6.666667 = 26.666667
//   linea B: gasto 100 x 100/300 = 33.333333 -> efectivo 10 + 3.333333 = 13.333333
//   promedio final = ((10 x 26.666667) + (10 x 13.333333)) / 20 = 20.00
//   gasto huerfano = 0.00

List<Auctifera__CatalogItem__c> items = [
    SELECT Id, Auctifera__Product_ID__c, Auctifera__Current_Item_Cost__c, Auctifera__Total_Stock__c
    FROM Auctifera__CatalogItem__c
    WHERE Auctifera__Product_ID__c LIKE 'QA-1174-T2-%'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
if (items.isEmpty()) {
    System.debug('=== T2b: no hay item de montaje. Correr primero T2. ===');
    return;
}
Auctifera__CatalogItem__c item = items[0];

List<AsyncApexJob> jobs = [
    SELECT Status, ExtendedStatus, CreatedDate FROM AsyncApexJob
    WHERE JobType = 'Queueable' AND ApexClass.Name = 'LandedCostExpenseRecalcQueueable'
    ORDER BY CreatedDate DESC LIMIT 1
];
System.debug('=== T2b :: ESTADO DEL JOB ASINCRONO ===');
System.debug(jobs.isEmpty() ? 'NO hay job (ojo: la PO puede no tener gasto, o cayo al fallback sincrono)'
    : 'Status=' + jobs[0].Status + ' | ExtendedStatus=' + jobs[0].ExtendedStatus + ' | creado=' + jobs[0].CreatedDate);

Decimal allocated = 0;
System.debug('=== T2b :: CADENA DE ICH DESPUES DEL RECALCULO ===');
for (Auctifera__Item_Cost_History__c ich : [
        SELECT Auctifera__Cost__c, Auctifera__Previous_Cost__c, Auctifera__Stock__c,
               Auctifera__Unit_Cost__c, Auctifera__Allocated_Expense__c, Auctifera__Effective_Cost__c,
               Auctifera__Stock_Replenishment_Order__r.Auctifera__Item_Cost__c
        FROM Auctifera__Item_Cost_History__c
        WHERE Auctifera__Shop_Item__c = :item.Id
        ORDER BY Auctifera__Effective_At__c ASC, CreatedDate ASC]) {
    System.debug('linea con Item_Cost=' + ich.Auctifera__Stock_Replenishment_Order__r.Auctifera__Item_Cost__c +
        ' | prevCost=' + ich.Auctifera__Previous_Cost__c + ' | cost=' + ich.Auctifera__Cost__c +
        ' | stock=' + ich.Auctifera__Stock__c + ' | unitCost=' + ich.Auctifera__Unit_Cost__c +
        ' | allocExpense=' + ich.Auctifera__Allocated_Expense__c + ' | effectiveCost=' + ich.Auctifera__Effective_Cost__c);
    allocated += (ich.Auctifera__Allocated_Expense__c == null ? 0 : ich.Auctifera__Allocated_Expense__c);
}

System.debug('=== T2b :: VEREDICTO ===');
System.debug('Current_Item_Cost__c = ' + item.Auctifera__Current_Item_Cost__c + ' (esperado 20.00)');
System.debug('Total_Stock__c       = ' + item.Auctifera__Total_Stock__c + ' (esperado 20)');
System.debug('Gasto asignado en la cadena = ' + allocated + ' (esperado 100.00)');
System.debug('Gasto HUERFANO = ' + (100 - allocated) + ' (esperado 0.00)');
Boolean pass = item.Auctifera__Current_Item_Cost__c == 20.00 && allocated.setScale(2) == 100.00;
System.debug('VEREDICTO T2b (fix de SH-1200): ' + (pass ? 'PASS' : 'FAIL'));
