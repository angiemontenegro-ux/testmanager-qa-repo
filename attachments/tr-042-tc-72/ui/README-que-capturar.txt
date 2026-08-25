EVIDENCIA UI — TR-042 / TC-72 escenario 10 (AC4)
================================================
Escenario: "A manual override of the auto-populated cost survives Save"
Estado actual en el TR: not-run (pendiente de estas capturas)

Es el UNICO escenario que no se puede cerrar por codigo fuente: su afirmacion
central es de PERSISTENCIA en Salesforce, no de logica de cliente.

PRECONDICION OBLIGATORIA
  Hard reload antes de probar (Cmd+Shift+R), o incognito con login nuevo, o
  desactivar Setup > Session Settings > Enable secure and persistent browser caching.
  Sin esto el navegador sigue ejecutando el componente Aura viejo desde IndexedDB
  y el resultado es un falso FAIL.

CAPTURAS ESPERADAS (nombres sugeridos)
  1-item-cost-autopoblado-25.png     Item Cost se auto-completa en 25.00 al elegir el Shop Item
  2-override-manual-40-qty-2.png     Item Cost sobrescrito a 40.00 y Order Quantity en 2
  3-order-cost-80-antes-de-guardar.png   Order Cost recalculado a 80.00 ANTES de guardar
  4-registro-salesforce-40.png       El REGISTRO guardado en Salesforce con Item Cost 40.00 (no 25.00)

OPCIONAL PERO UTIL
  5-wizard-2-supplier.png            Lo mismo en el segundo wizard (el que tiene columna Supplier)
  6-order-cost-fila-sin-cantidad.png Order Cost en una fila con Item Cost puesto y cantidad vacia
                                     (confirma o descarta OBS-1: muestra $0.00 en vez de blanco)

LIMITE DEL REPO: 10 MB por adjunto (attachmentsMaxSizeMb en .testmanager.yml).

Una vez esten aca, se actualiza el escenario 10 con su veredicto real, la corrida
pasa de in-progress a completed, y se commitea a la PR #28.
