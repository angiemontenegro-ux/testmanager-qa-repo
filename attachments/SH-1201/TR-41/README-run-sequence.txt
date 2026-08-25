SH-1201 / TR-041 - secuencia completa de la corrida, incluidos los cambios de ambiente
Org: veevartmuseumdemo--uat | 2026-08-19

POR QUE HAY CAMBIOS DE AMBIENTE EN UNA CORRIDA DE QA
  El defecto SH-1201 solo se manifiesta cuando el layout del org marca
  Item_per_location__c como Required. La remediacion manual documentada en
  attachments/SH-1129/TR-38/scenario-6-layout/remediation-uat-2026-08-19/
  ya habia puesto ese campo en Edit en UAT, lo que ELIMINO la reproduccion.
  Para ejecutar el escenario hubo que revertir temporalmente esa remediacion.

SECUENCIA (todo sobre el layout 'Inventory History Layout', unico componente tocado)

  1. Estado inicial          Item_per_location__c = Edit
                             (remediacion de SH-1201 aplicada el 2026-08-19)

  2. Revert temporal         Edit -> Required
     deploy 0AfD700003TOxRpKAL
     Motivo: recuperar la reproduccion del defecto.

  3. EJECUCION DEL ESCENARIO en Lightning -> FAIL reproducido
     Ver ui-observation-transcript.txt
     Layout durante la corrida: uat-layout-DURING-run-required.xml

  4. Re-aplicacion            Required -> Edit
     deploy 0AfD700003TOxRuKAL
     Motivo: devolver el org al estado de su remediacion documentada.

  5. Estado final            Item_per_location__c = Edit   (verificado releyendo del org)
                             Layout final: uat-layout-AFTER-remediation-restored.xml

ESTADO FINAL DEL ORG
  UAT queda EXACTAMENTE como estaba antes de esta corrida, coincidiendo con el
  README de remediacion de SH-1129/TR-38. No queda deriva.

  Nota: Shop_Item__c sigue en Required en UAT y NO fue tocado en ningun momento.
  Ese campo es el que cambia SH-1143, por lo que su escenario de layout sigue
  siendo validable en este org sin contaminacion de esta corrida.

DATOS
  Ningun registro fue creado, modificado ni eliminado. El unico registro usado
  (a4nD7000002QgrTIAS) quedo intacto, con su LastModifiedDate original del
  2026-08-18. Ver record-state-unchanged.log
