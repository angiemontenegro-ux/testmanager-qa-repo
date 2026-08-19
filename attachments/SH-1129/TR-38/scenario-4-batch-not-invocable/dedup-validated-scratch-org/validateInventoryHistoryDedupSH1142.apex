/*
 * SH-1142 / TC-69 escenario 4 - "InventoryHistoryBatch does not create a duplicate same-day
 * snapshot for a history row orphaned by an earlier IPL delete".
 *
 *     sf apex run -o <SCRATCH_ORG> -f scripts/apex/validateInventoryHistoryDedupSH1142.apex
 *
 * DONDE CORRERLO: SOLO en un org con el CODIGO FUENTE del paquete desplegado (scratch org u org
 * de desarrollo del paquete). NO funciona en UAT ni en produccion: alli InventoryHistoryBatch
 * esta declarada public y no global, asi que el paquete gestionado no la expone y cualquier
 * intento de invocarla falla al compilar con "Type is not visible".
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
 * COMO se ejecuta el batch: se llama execute() directamente con un scope de un solo IPL, en vez de
 * Database.executeBatch. Es sincrono, asi que el resultado se puede asertar en la misma
 * transaccion, y ejercita exactamente onlyNewRecords(), que es donde vive la dedup key.
 *
 * Todo el DML se revierte al final - el org queda como estaba.
 */

final String ns = Schema.getGlobalDescribe().containsKey('Auctifera__CatalogItem__c') ? 'Auctifera__' : '';

System.Savepoint sp = Database.setSavepoint();
try {
    List<SObject> stores = Database.query(
        'SELECT Id FROM ' + ns + 'Display_Storage_Location__c WHERE ' + ns + 'Type__c = \'Store\' LIMIT 1'
    );
    if (stores.isEmpty()) {
        throw new IllegalArgumentException('No hay Display_Storage_Location__c de tipo Store en este org.');
    }
    Id locId = stores[0].Id;

    SObject item = Schema.getGlobalDescribe().get(ns + 'CatalogItem__c').newSObject();
    item.put('Name', 'SH-1142 Dedup Item');
    item.put(ns + 'Price__c', 25);
    item.put(ns + 'Product_ID__c', 'SH1142-' + String.valueOf(Datetime.now().getTime()));
    item.put(ns + 'Bypass_Stock__c', true);
    insert item;

    // IPL original, el que despues se borra.
    SObject iplOld = Schema.getGlobalDescribe().get(ns + 'Item_per_location__c').newSObject();
    iplOld.put(ns + 'Shop_Item__c', item.Id);
    iplOld.put(ns + 'Display_Storage_Location__c', locId);
    insert iplOld;

    // Snapshot de HOY atado a ese IPL.
    SObject history = Schema.getGlobalDescribe().get(ns + 'Inventory_History__c').newSObject();
    history.put(ns + 'Shop_Item__c', item.Id);
    history.put(ns + 'Location__c', locId);
    history.put(ns + 'Item_per_location__c', iplOld.Id);
    history.put(ns + 'Date__c', Date.today());
    history.put(ns + 'Total_Stock__c', 4);
    history.put(ns + 'Item_Cost__c', 25);
    insert history;

    // Se borra el IPL: por SH-1129 la fila de historial sobrevive con el lookup en null (huerfana).
    delete iplOld;

    Integer afterDelete = Database.countQuery(
        'SELECT COUNT() FROM ' + ns + 'Inventory_History__c WHERE ' + ns + 'Shop_Item__c = \'' + item.Id + '\''
    );
    Integer orphans = Database.countQuery(
        'SELECT COUNT() FROM ' + ns + 'Inventory_History__c WHERE ' + ns + 'Shop_Item__c = \'' + item.Id +
        '\' AND ' + ns + 'Item_per_location__c = NULL'
    );

    // IPL NUEVO para la MISMA combinacion Shop Item + Variant + Location.
    SObject iplNew = Schema.getGlobalDescribe().get(ns + 'Item_per_location__c').newSObject();
    iplNew.put(ns + 'Shop_Item__c', item.Id);
    iplNew.put(ns + 'Display_Storage_Location__c', locId);
    insert iplNew;

    // Se re-consulta con los mismos campos que selecciona start(), porque execute() los usa.
    List<Auctifera__Item_per_location__c> scope = Database.query(
        'SELECT Id, ' + ns + 'Item_Variant__c, ' + ns + 'Shop_Item__c, ' + ns + 'Display_Storage_Location__c, ' +
        ns + 'Total_stock_per_location__c, ' + ns + 'Shop_Item__r.Name, ' +
        ns + 'Shop_Item__r.' + ns + 'Item_Cost__c, ' + ns + 'Shop_Item__r.' + ns + 'Current_Item_Cost__c ' +
        'FROM ' + ns + 'Item_per_location__c WHERE Id = \'' + iplNew.Id + '\''
    );

    // Se llama execute() directo: sincrono y es donde vive onlyNewRecords().
    new Auctifera.InventoryHistoryBatch().execute(null, scope);

    Integer afterBatch = Database.countQuery(
        'SELECT COUNT() FROM ' + ns + 'Inventory_History__c WHERE ' + ns + 'Shop_Item__c = \'' + item.Id + '\''
    );
    Integer todayRows = Database.countQuery(
        'SELECT COUNT() FROM ' + ns + 'Inventory_History__c WHERE ' + ns + 'Shop_Item__c = \'' + item.Id +
        '\' AND ' + ns + 'Date__c = TODAY'
    );

    Boolean pass = (todayRows == 1) && (afterBatch == 1);

    System.debug(LoggingLevel.INFO, '======================================================');
    System.debug(LoggingLevel.INFO, '  SH-1142 / TC-69 esc. 4 - dedup del batch tras IPL huerfano');
    System.debug(LoggingLevel.INFO, '  filas tras borrar el IPL      = ' + afterDelete + ' (want 1, sobrevive)');
    System.debug(LoggingLevel.INFO, '  de esas, huerfanas            = ' + orphans + ' (want 1, lookup en null)');
    System.debug(LoggingLevel.INFO, '  filas tras correr el batch    = ' + afterBatch + ' (want 1, NO duplico)');
    System.debug(LoggingLevel.INFO, '  filas con fecha de HOY        = ' + todayRows + ' (want 1)');
    System.debug(LoggingLevel.INFO, '  RESULT: ' + (pass ? 'PASS' : 'FAIL'));
    if (!pass) {
        System.debug(LoggingLevel.INFO, '  -> 2 filas de hoy significa que la dedup key sigue siendo Item_per_location__c');
    }
    System.debug(LoggingLevel.INFO, '======================================================');
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, 'SETUP ERROR: ' + e.getTypeName() + ': ' + e.getMessage() + ' (line ' + e.getLineNumber() + ')');
} finally {
    Database.rollback(sp);
}
