/*
 * SH-1142 / TC-69 escenario 4 - re-validacion funcional en org vivo (2026-09-08).
 *
 *     sf apex run -o <SCRATCH_ORG> -f flsrepro-functional-scenario.apex
 *
 * DONDE CORRERLO: SOLO en un org con el CODIGO FUENTE del paquete desplegado (scratch org u org
 * de desarrollo del paquete). NO funciona en UAT ni en produccion: alli InventoryHistoryBatch
 * esta declarada public y no global, asi que el paquete gestionado no la expone y cualquier
 * intento de invocarla falla al compilar con "Type is not visible".
 *
 * POR QUE ESTE SCRIPT EXISTE si ya habia uno: el org de la validacion original (sh1174qa2) expiro.
 * Esta corrida re-valida el mismo escenario en fls-repro y agrega el paso 6, que compara la clave
 * VIEJA contra la NUEVA sobre la MISMA fila huerfana - es decir, demuestra el bug y el fix en la
 * misma corrida, no solo el resultado final.
 *
 * QUE PRUEBA: tras SH-1129 el lookup Item_per_location__c quedo nullable, asi que al borrar un IPL
 * su fila de historial sobrevive huerfana. SH-1142 cambio la dedup key del batch de
 * Item_per_location__c a la clave de negocio (Shop_Item__c + Item_Variant__c + Location__c) para
 * que esa fila huerfana siga contando como "ya existe hoy". Sin ese cambio, un IPL nuevo para la
 * misma combinacion genera un SEGUNDO snapshot del mismo dia y los reportes de valor de inventario
 * cuentan doble.
 *
 * Antes del fix de SH-1142: quedan 2 filas para hoy (FAIL). Despues: queda 1 (PASS).
 *
 * TRAMPA IMPORTANTE PARA QUIEN REUSE ESTO: InventoryHistoryRecorder.hasEnoughInformation() exige un
 * costo, que lee de Shop_Item__r.Item_Cost__c o Item_Variant__r.Cost_per_item__c. Si la query del
 * IPL no trae esos campos de relacion, llegan null, el recorder SALTEA el registro en silencio y el
 * batch inserta 0 filas - se ve como un FAIL y no lo es. La query de abajo calca la de
 * InventoryHistoryBatch.start() a proposito.
 *
 * NO hace rollback: es scratch-only y los registros quedan a proposito para poder tomar capturas.
 * El IPL no se crea a mano: lo genera StockReplenishmentOrder__c en 'Received - Complete'.
 */

String tag = 'SH1142-' + Datetime.now().getTime();
Id locationId = DefaultStoreLocation.getId();

Auctifera__CatalogItem__c mug = new Auctifera__CatalogItem__c(
    Name = 'Ceramic Mug ' + tag,
    Auctifera__Product_ID__c = tag,
    Auctifera__Price__c = 20,
    Auctifera__Item_Cost__c = 5);
insert mug;
System.debug('STEP 1 - shop item "Ceramic Mug" created, cost 5, price 20');

insert new Auctifera__StockReplenishmentOrder__c(
    Name = 'SRO A ' + tag, Auctifera__Order_Amount__c = 10,
    Auctifera__Catalog_Item__c = mug.Id,
    Auctifera__Order_Status__c = 'Received - Complete',
    Auctifera__Item_Cost__c = 5);

String iplQuery =
    'SELECT Id, Auctifera__Item_Variant__c, Auctifera__Shop_Item__c,' +
    ' Auctifera__Display_Storage_Location__c, Auctifera__Total_stock_per_location__c,' +
    ' Auctifera__Shop_Item__r.Name, Auctifera__Shop_Item__r.Auctifera__Item_Cost__c,' +
    ' Auctifera__Shop_Item__r.Auctifera__Current_Item_Cost__c,' +
    ' Auctifera__Item_Variant__r.Auctifera__Item_Variant_Name__c,' +
    ' Auctifera__Item_Variant__r.Auctifera__Cost_per_item__c' +
    ' FROM Auctifera__Item_per_location__c WHERE Auctifera__Shop_Item__c = \'' + mug.Id + '\'';

List<Auctifera__Item_per_location__c> ipls = Database.query(iplQuery);
System.debug('STEP 2 - stock received 10 units -> IPL rows = ' + ipls.size()
    + ' | stock = ' + (ipls.isEmpty() ? null : ipls[0].Auctifera__Total_stock_per_location__c));
Id firstIplId = ipls.isEmpty() ? null : ipls[0].Id;

new InventoryHistoryBatch().execute(null, ipls);
System.debug('STEP 3 - nightly valuation snapshot ran -> rows for TODAY = ' + [
    SELECT COUNT() FROM Auctifera__Inventory_History__c
    WHERE Auctifera__Shop_Item__c = :mug.Id AND Auctifera__Date__c = TODAY]);

delete ipls;
List<Auctifera__Inventory_History__c> survivors = [
    SELECT Id, Auctifera__Item_per_location__c, Auctifera__Total_Stock__c
    FROM Auctifera__Inventory_History__c
    WHERE Auctifera__Shop_Item__c = :mug.Id AND Auctifera__Date__c = TODAY];
Integer orphaned = 0;
for (Auctifera__Inventory_History__c h : survivors) {
    if (h.Auctifera__Item_per_location__c == null) { orphaned++; }
}
System.debug('STEP 4 - stock record replaced (IPL deleted) -> snapshot survives = '
    + survivors.size() + ' | of those ORPHANED = ' + orphaned + ' (this is SH-1129 SetNull)');

insert new Auctifera__StockReplenishmentOrder__c(
    Name = 'SRO B ' + tag, Auctifera__Order_Amount__c = 10,
    Auctifera__Catalog_Item__c = mug.Id,
    Auctifera__Order_Status__c = 'Received - Complete',
    Auctifera__Item_Cost__c = 5);
List<Auctifera__Item_per_location__c> newIpls = Database.query(iplQuery);
System.debug('STEP 5 - NEW stock record created same day -> IPL rows = ' + newIpls.size()
    + ' | new IPL id differs from old = ' + (newIpls.isEmpty() ? null
        : (Object) (newIpls[0].Id != firstIplId)));

Set<Id> newIplIds = new Set<Id>();
for (Auctifera__Item_per_location__c i : newIpls) { newIplIds.add(i.Id); }
Integer oldKeyMatches = [
    SELECT COUNT() FROM Auctifera__Inventory_History__c
    WHERE Auctifera__Date__c = TODAY AND Auctifera__Item_per_location__c IN :newIplIds];
Integer newKeyMatches = [
    SELECT COUNT() FROM Auctifera__Inventory_History__c
    WHERE Auctifera__Date__c = TODAY AND Auctifera__Shop_Item__c = :mug.Id];
System.debug('STEP 6 - dedup lookup, OLD key (by IPL id) finds = ' + oldKeyMatches
    + ' existing rows  -> would insert a SECOND row');
System.debug('STEP 6 - dedup lookup, NEW key (by Shop Item) finds = ' + newKeyMatches
    + ' existing rows  -> recognises the orphan, inserts nothing');

new InventoryHistoryBatch().execute(null, newIpls);
List<Auctifera__Inventory_History__c> finalRows = [
    SELECT Id, Auctifera__Item_per_location__c, Auctifera__Total_Stock__c,
           Auctifera__Inventory_Value__c
    FROM Auctifera__Inventory_History__c
    WHERE Auctifera__Shop_Item__c = :mug.Id AND Auctifera__Date__c = TODAY];
System.debug('STEP 7 - snapshot ran again same day -> rows for TODAY = ' + finalRows.size());
for (Auctifera__Inventory_History__c h : finalRows) {
    System.debug('   ROW ' + h.Id + ' | ipl=' + h.Auctifera__Item_per_location__c
        + ' | stock=' + h.Auctifera__Total_Stock__c
        + ' | inventory value=' + h.Auctifera__Inventory_Value__c);
}

String verdict;
if (finalRows.size() == 1) {
    verdict = 'PASS - one value for today, the valuation report cannot double-count';
} else if (finalRows.size() == 0) {
    verdict = 'INCONCLUSIVE - no snapshot was ever created, setup problem not a product result';
} else {
    verdict = 'FAIL - ' + finalRows.size() + ' rows for today, report WILL double-count';
}
System.debug('RESULT - ' + verdict);
