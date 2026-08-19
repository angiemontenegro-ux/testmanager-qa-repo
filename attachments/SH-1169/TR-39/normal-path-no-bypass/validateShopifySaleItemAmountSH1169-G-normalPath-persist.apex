/*
 * SH-1169 / TC-67 escenario 3 - "Normal Salesforce write (no bypass) still calculates Amount correctly".
 *
 *     sf apex run -o <ORG_ALIAS> -f scripts/apex/validateShopifySaleItemAmountSH1169-G-normalPath-persist.apex
 *
 * Que prueba: una venta que NO viene de Shopify sigue calculando el Total como siempre, o sea que el
 * fix de SH-1169 no rompio el camino normal. Es la regresion que cubre la venta de POS.
 *
 * ALCANCE - leelo antes de usarlo como evidencia:
 * Esto ejercita el MISMO camino de trigger que usa el POS (insert sin Technical_Bypass_Triggers__c,
 * asi que calculateAmount corre normal), pero NO ejercita la app de POS Mobile. Cubre la logica de
 * Salesforce, no la interfaz ni la integracion del dispositivo. Si lo que se necesita es validar la
 * app, esto no la reemplaza.
 *
 * OJO: variante PERSISTENTE, no hace rollback. Los registros QUEDAN en el org.
 * Usala solo en sandbox o scratch org.
 */

final Decimal ITEM_PRICE = 40;
final Integer QUANTITY = 3;
final String SOURCE = 'POS Mobile';

final String ns = Schema.getGlobalDescribe().containsKey('Auctifera__CatalogItem__c') ? 'Auctifera__' : '';
final Schema.SObjectType ciType = Schema.getGlobalDescribe().get(ns + 'CatalogItem__c');
final Schema.SObjectType cpType = Schema.getGlobalDescribe().get(ns + 'ClientPurchase__c');
final Schema.SObjectType siType = Schema.getGlobalDescribe().get(ns + 'Sale_Item__c');

SObject item = ciType.newSObject();
item.put('Name', 'SH-1169 Normal Path Item - BORRAR');
item.put(ns + 'Price__c', ITEM_PRICE);
item.put(ns + 'Tax__c', 0);
item.put(ns + 'Tax_Model__c', 'Tax not included in the price');
item.put(ns + 'Product_ID__c', 'SH1169-NORMAL-' + String.valueOf(Datetime.now().getTime()));
item.put(ns + 'Bypass_Stock__c', true);
insert item;

SObject purchase = cpType.newSObject();
insert purchase;

// Camino normal: SIN Technical_Bypass_Triggers__c. Es lo que hace POSServicePurchase y cualquier
// escritura hecha directamente en Salesforce. calculateAmount() corre como siempre.
SObject line = siType.newSObject();
line.put(ns + 'Catalog_Item__c', item.Id);
line.put(ns + 'Client_Purchase__c', purchase.Id);
line.put(ns + 'Item_Price__c', ITEM_PRICE);
line.put(ns + 'Number_of_Items_bought__c', QUANTITY);
line.put(ns + 'Source__c', SOURCE);
insert line;

SObject stored = Database.query(
    'SELECT Name, ' + ns + 'Amount__c, ' + ns + 'Price_Without_Tax__c, ' + ns + 'Source__c, ' +
    ns + 'Item_Price__c, ' + ns + 'Number_of_Items_bought__c, ' + ns + 'Technical_Bypass_Triggers__c ' +
    'FROM ' + ns + 'Sale_Item__c WHERE Id = \'' + line.Id + '\''
);

Decimal expected = ITEM_PRICE * QUANTITY;
Decimal amount = (Decimal) stored.get(ns + 'Amount__c');
Boolean bypassOff = (stored.get(ns + 'Technical_Bypass_Triggers__c') != true);
Boolean notShopify = (stored.get(ns + 'Source__c') != 'Shopify');
Boolean pass = (amount == expected) && bypassOff && notShopify;
String baseUrl = URL.getOrgDomainUrl().toExternalForm().replace('.my.salesforce.com', '.lightning.force.com');

System.debug(LoggingLevel.INFO, '======================================================');
System.debug(LoggingLevel.INFO, '  SCENARIO G (TC-67 esc. 3) - camino normal, sin bypass');
System.debug(LoggingLevel.INFO, '  Sale Item             = ' + stored.get('Name'));
System.debug(LoggingLevel.INFO, '  Source                = ' + stored.get(ns + 'Source__c') + ' (no Shopify: ' + notShopify + ')');
System.debug(LoggingLevel.INFO, '  Price                 = ' + stored.get(ns + 'Item_Price__c'));
System.debug(LoggingLevel.INFO, '  Quantity              = ' + stored.get(ns + 'Number_of_Items_bought__c'));
System.debug(LoggingLevel.INFO, '  Total (Amount__c)     = ' + amount + ' (want ' + expected + ')');
System.debug(LoggingLevel.INFO, '  Bypass desmarcado     = ' + bypassOff + ' (want true)');
System.debug(LoggingLevel.INFO, '  RESULT: ' + (pass ? 'PASS' : 'FAIL'));
System.debug(LoggingLevel.INFO, '------------------------------------------------------');
System.debug(LoggingLevel.INFO, '  Abrir el Sale Item : ' + baseUrl + '/lightning/r/' + ns + 'Sale_Item__c/' + line.Id + '/view');
System.debug(LoggingLevel.INFO, '======================================================');
