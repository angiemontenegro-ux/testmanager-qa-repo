SH-1201 - remediacion manual aplicada a UAT, 2026-08-19

QUE SE HIZO
  Se cambio el behavior de Auctifera__Item_per_location__c de Required a Edit en el layout
  'Inventory History Layout' del org UAT (veevartmuseumdemo--uat).

COMO
  1. sf project retrieve start --metadata "Layout:Auctifera__Inventory_History__c-Auctifera__Inventory History Layout"
     (el namespace va en AMBAS partes del nombre; el fullName que reporta 'sf org list metadata' omite el segundo y no sirve para retrieve)
  2. editar el XML: <behavior>Required</behavior> -> <behavior>Edit</behavior> en ese layoutItem
  3. sf project deploy start --dry-run   (validacion, no aplica)
  4. sf project deploy start             (aplica)

VERIFICACION
  El layout re-descargado de UAT reporta Auctifera__Item_per_location__c = Edit.
  Auditoria: el layout paso de LastModifiedDate 2025-09-23 (intocado desde la instalacion)
  a 2026-08-19T20:30:46Z por Angie Montenegro.

ALCANCE - IMPORTANTE
  Esto arregla UN org. El defecto sigue vivo en todo org suscriptor existente, incluido
  Eiteljorg, y volvera a ocurrir con el proximo cambio de layout del paquete (SH-1143 ya
  trae el mismo patron sobre Shop_Item__c). SH-1201 sigue abierto por esa razon.
  Efecto colateral a tener presente: UAT quedo por DELANTE de produccion en este punto.
