SH-1169 — QUE MIRAR PARA VALIDAR EL FIX
Guia para revision de PM · UAT (veevartmuseumdemo--uat) · Auctifera 8.337.0.1

================================================================
EL REGISTRO
================================================================
  Sale Item:        S-3447
  Id:               a1ED7000005VOMcMAO
  Client Purchase:  P-2414
  Origen:           pedido REAL de Shopify (External Id 15789035421832)
                    creado por la integracion y re-sincronizado 51 s despues

  URL directa:
  https://veevartmuseumdemo--uat.sandbox.lightning.force.com/lightning/r/Auctifera__Sale_Item__c/a1ED7000005VOMcMAO/view

================================================================
LA TRAMPA — LEER ANTES DE MIRAR NINGUN VALOR
================================================================
En pantalla hay DOS campos con nombres parecidos y solo UNO es el del bug:

  "Total"   <- ESTE es el campo del bug (API: Amount__c)
              Es el que estaba mal y el que el fix corrige.

  "Amount"  <- NO es el campo del bug (API: Subtotal_before_discount__c)
              Es otro campo distinto: Price x Quantity, sin descuento ni impuesto.

Quien busque un campo llamado "Amount" va a mirar el equivocado.
El fix se valida mirando "Total".

================================================================
QUE DEBE VERSE — pedido de 5 unidades a USD 22.00
================================================================
  Price              22.00      precio unitario
  Quantity           5
  Amount            110.00      = 22 x 5   (este NO es el campo del bug)
  Discount Amount     0.00
  Subtotal          110.00      despues de descuento, antes de impuesto
  Tax Amount          8.25
  Total             118.25      <<< EL CAMPO DEL BUG: 110.00 + 8.25

  Source            Shopify

ANTES DEL FIX, "Total" habria mostrado 22.00 — el precio unitario, ignorando
la cantidad. Ese era el bug: el reporte de ventas y de impuestos de la tienda
no cuadraba con la plata realmente cobrada en Shopify.

================================================================
POR QUE ESTE REGISTRO Y NO OTRO
================================================================
El bug solo se manifiesta en una RE-SINCRONIZACION, no en la primera carga:
al insertar, una recalculacion en cadena de la Client Purchase corregia el
valor por accidente. Este registro paso por create + re-sync, que es el
camino donde el bug si aparecia.

================================================================
CAPTURAS
================================================================
Se tomaron el 2026-08-20 y estan pendientes de subir a esta carpeta
(quedaron en el chat de Slack de Angie). Nombres esperados:

  1-sale-item-total-correcto.png
      Seccion Information. Muestra en un solo cuadro:
        Quantity 5 · Amount $110.00 · Discount $0.00
        Subtotal $110.00 · Tax Amount $8.25 · Total $118.25
      Es la captura clave: "Amount" y "Total" quedan uno debajo del otro,
      asi se ve solo que son campos distintos.

  2-price-y-tax-del-shop-item.png
      Secciones Shop Item Information y Discount Information. Muestra:
        Price $22.00 · Tax 7.50% · Discount Value 0.00
      Cierra la aritmetica y confirma que no hay descuento escondido.

Nota: la evidencia de este README es autosuficiente sin las imagenes —
los valores estan escritos arriba y son verificables abriendo el registro.

================================================================
LA ARITMETICA COMPLETA
================================================================
    22.00  x  5          =  110.00   Amount (Price x Quantity)
   110.00  -   0.00      =  110.00   Subtotal (sin descuento)
   110.00  x  7.50%      =    8.25   Tax Amount
   110.00  +   8.25      =  118.25   TOTAL  <<< el campo del bug

