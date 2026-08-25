SH-1201 / TR-041 - capturas de pantalla

ESTADO: las tres capturas YA SE TOMARON el 2026-08-19 y estan en el chat de Slack
de Angie, pendientes de subir al test manager. Esta carpeta las espera con los
nombres de abajo. Las instrucciones siguen aqui por si hay que repetirlas.

Guarda las imagenes EN ESTA CARPETA con estos nombres exactos (png o jpg):

  1-edit-mode-required-asterisk.png
  2-save-blocked-we-hit-a-snag.png
  3-record-view-item-per-location-empty.png   (opcional)

------------------------------------------------------------------
PRECONDICION - SIN ESTO NO SE REPRODUCE
------------------------------------------------------------------
El layout de UAT debe tener Item_per_location__c con behavior=Required.
Hoy esta en Edit (remediacion de SH-1201 aplicada), asi que el defecto
NO se ve. Hay que revertirlo temporalmente antes de capturar y volver
a dejarlo en Edit al terminar.

Estado actual: Edit          <- no reproduce
Estado necesario: Required   <- reproduce

------------------------------------------------------------------
REGISTRO A USAR
------------------------------------------------------------------
  a4nD7000002QgrTIAS - "SH-1201 Layout Check - BORRAR"
  Es el unico Inventory_History__c del org con Item_per_location__c = null.

  URL vista:   /lightning/r/Auctifera__Inventory_History__c/a4nD7000002QgrTIAS/view
  URL edicion: /lightning/r/Auctifera__Inventory_History__c/a4nD7000002QgrTIAS/edit

  Base: https://veevartmuseumdemo--uat.sandbox.lightning.force.com

------------------------------------------------------------------
QUE TIENE QUE VERSE EN CADA CAPTURA
------------------------------------------------------------------

CAPTURA 1 - modo edicion, asterisco de requerido
  Abrir la URL de edicion. Que se vea:
    - la leyenda "* = Required Information" arriba a la derecha
    - el campo "* Item per location" con asterisco rojo, VACIO
    - IMPORTANTE: que "Item Variant" entre tambien en el encuadre.
      Ese es el control interno: es lookup opcional igual, pero su
      behavior en el layout es Edit, y NO debe mostrar asterisco.
      La captura pierde la mitad de su valor si se recorta ese campo.

CAPTURA 2 - guardado bloqueado
  Con el campo vacio, click en "Save". Que se vea:
    - el campo en rojo con el texto inline "Complete this field."
    - el toast de error "We hit a snag." /
      "Review the following fields" / "Item per location"
  NO guardar despues: dar Cancel. El registro debe quedar intacto.

CAPTURA 3 (opcional) - vista del registro
  La URL de vista, mostrando "Item per location" vacio.

------------------------------------------------------------------
DESPUES DE CAPTURAR
------------------------------------------------------------------
  Devolver el layout a behavior=Edit para restaurar la remediacion.
  Verificar releyendo el layout del org, no asumirlo.

  Al agregar las imagenes, actualizar en el testrun TR-041 la nota del
  escenario 2, que hoy declara: "se tomaron capturas durante la corrida
  pero la herramienta no dejo un archivo recuperable en disco, asi que
  NO se adjuntan imagenes".
