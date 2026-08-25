# SH-1169 — Guía manual de punta a punta, desde la compra en Shopify

**Para:** PM / Soporte que quiera validar el fix por su cuenta, sin scripts.
**Caso de origen:** 00176210 — "giftshop tax report", Masonic Temple, Library & Museum.
**Ambiente:** UAT (`veevartmuseumdemo--uat`) u otro org con el fix desplegado.

---

## ⚠️ Lo primero: por qué esta guía existe y no un link a un registro

Los registros de UAT **son efímeros**. Una suite de regresión automatizada corre a diario
y borra los datos de Shop. Cualquier link a un Sale Item concreto deja de servir en
menos de 24 horas.

Por eso esta guía enseña a **generar la evidencia**, no a mirarla. Los valores esperados
están calculados abajo; sirven aunque el org esté vacío.

---

## El bug, en una frase

Los Sale Items que llegan de Shopify guardaban en **Total** el **precio unitario**
en vez de precio × cantidad. Un pedido de 3 unidades de USD 40.00 mostraba
**Total = 40.00** en vez de **120.00**. Por eso el reporte de ventas e impuestos de la
tienda no cuadraba con la plata realmente cobrada en Shopify.

---

## ⚠️ La trampa de los dos campos — leer antes de mirar cualquier valor

En la pantalla del Sale Item hay dos campos con nombres parecidos:

| Etiqueta en pantalla | ¿Es el campo del bug? | Qué es en realidad |
|---|---|---|
| **Total** | ✅ **SÍ** | `Amount__c` — Subtotal + impuesto |
| Amount | ❌ No | `Subtotal_before_discount__c` — precio × cantidad, sin descuento ni impuesto |

**Quien busque un campo llamado "Amount" va a mirar el equivocado.**
El fix se valida leyendo **Total**.

---

## ⚠️ La segunda trampa: el bug NO se ve en la primera sincronización

Al insertarse, una recalculación en cadena del Client Purchase re-guarda la línea sin
el flag de bypass y el valor **se auto-corrige por accidente**. Un pedido que solo
sincronizó una vez se ve bien incluso sin el fix.

**Hay que forzar una segunda sincronización** cambiando algo del pedido en Shopify.
Ese es el paso 5 y sin él la validación es un falso positivo.

---

## Preparación (una sola vez)

### P1 · Verificar que el fix está desplegado

En Salesforce, Setup → Installed Packages → Auctifera. Anotar la versión.
El fix viajó en la PR #2569, mergeada el 2026-08-05.
Si la versión del org es anterior a esa fecha, **se va a reproducir el bug**, no el fix.

### P2 · Que exista un Shop Item publicado al canal online

Si el org fue limpiado por la suite de regresión, puede no haber ninguno.
Crear un Shop Item con:

| Campo | Valor sugerido |
|---|---|
| Name | `SH-1169 Manual Check` |
| Price | **40.00** |
| Tax | dejar en **0%** para el caso base |
| Available Collection Online | ✅ marcado |

### P3 · Que el producto exista en Shopify y esté mapeado

El Shop Item debe tener `Shopify Product Id` poblado. Si está vacío, el pedido va a
sincronizar y **fallar** al crear el POS Purchase — ese es otro bug distinto (SH-799),
no este.

---

## La corrida

### Paso 1 · Comprar en la tienda Shopify

Agregar al carrito **3 unidades** del producto de USD 40.00 y completar la compra.

> Se usan 3 × 40.00 porque son los números exactos del Case 00176210:
> el Sale Item S-3094 en producción mostraba Amount 40.00 donde debía decir 120.00.

📸 **Captura 1** — el carrito o la confirmación de Shopify mostrando 3 unidades y el total cobrado.

### Paso 2 · Esperar la sincronización a Salesforce

Suele tardar segundos. En Salesforce, buscar el **Client Purchase** recién creado.

### Paso 3 · Abrir la línea del pedido

En el Client Purchase → lista relacionada **Sale Items** → abrir el registro.

📸 **Captura 2** — el Client Purchase con su lista de Sale Items.

### Paso 4 · Anotar los valores de la primera sincronización

Se esperan correctos incluso sin el fix (por la auto-corrección del insert).
No concluir nada todavía.

### Paso 5 · ⚠️ Forzar la segunda sincronización

En Shopify, cambiar algo del pedido para que vuelva a sincronizar:
marcarlo como **pagado**, **cumplirlo (fulfill)** o **editarlo**.

**Este es el paso que hace visible el bug.** Sin él, la validación no prueba nada.

### Paso 6 · Volver al Sale Item y leer Total

📸 **Captura 3** — la sección *Information* del Sale Item.
Encuadrar de modo que **"Amount" y "Total" queden ambos visibles**: esa sola imagen
explica la trampa de los dos campos sin necesidad de texto.

---

## Qué debe verse — valores de una corrida real

Ejecutado el 2026-08-20 en UAT: 3 unidades de USD 40.00 con impuesto del 7.5%.
Shopify cobró **USD 129.00**.

| Campo | Valor observado |
|---|---|
| Price | 40.00 |
| Quantity | 3 |
| Amount | 120.00 |
| Discount Amount | 0.00 |
| Subtotal | 120.00 |
| Tax Amount | 9.00 |
| **Total** | **129.00** ← el campo del bug |

```
40.00 × 3        = 120.00   Amount (precio × cantidad)
120.00 − 0.00    = 120.00   Subtotal
120.00 × 7.50%   =   9.00   Tax Amount
120.00 + 9.00    = 129.00   TOTAL
```

**Sin el fix, Total mostraría 40.00** — el precio unitario, ignorando la cantidad.

### De dónde sale la tasa de impuesto — dato confirmado en esta corrida

El Shop Item tenía **Tax = 0%** en Salesforce y aun así el Tax Amount quedó en 9.00.
Es decir: **la tasa que viene en el payload de Shopify gana sobre la del Shop Item.**
`calculateAmount()` solo cae a la tasa del Shop Item cuando el payload no trae ninguna.

Consecuencia práctica: no alarmarse si el Shop Item dice 0% y el Sale Item muestra
impuesto. Lo que hay que comparar es contra lo que cobró Shopify.

Si el pedido fuera sin impuesto, el Total esperado sería 120.00.

---

### Paso 7 · ⭐ El reporte — el paso que cierra el caso

Este es el que más le importa al PM, porque **es el artefacto del que se quejó el cliente**.
El Case 00176210 no reportó "un campo se ve mal": reportó que el reporte de ventas e
impuestos del gift shop **no cuadraba con la plata cobrada**.

Abrir el reporte **`Shop Sales - Today`**
(carpeta *End of Day Reports*, tipo *Client Purchases with Sale Items and Shop Items*).

Valores observados en la corrida del 2026-08-20:

| Métrica del reporte | Valor |
|---|---|
| Total Quantity | 3 |
| Total Price | $40.00 |
| Total Tax Amount | $9.00 |
| **Total Total** | **$129.00** |

Y la cadena que hay que verificar que cierre:

| Fuente | Monto |
|---|---|
| Lo que cobró Shopify | $129.00 |
| El Charge en Salesforce | $129.00 |
| **El reporte** | **$129.00** |

**Por qué es decisivo:** el reporte suma el campo `Total` de los Sale Items.
Antes del fix habría mostrado **$40.00** en vez de $129.00, porque cada línea
aportaba el precio unitario en vez del total. Ese descuadre ES el reclamo del caso.

📸 **Captura 4** — el encabezado del reporte con las cuatro métricas visibles.

> Nota sobre otro reporte: `Sales Tax - Report` (carpeta *Veevart Accounting Reports*)
> NO sirve para esto. Su tipo es *Charges with Charge Items*, un join que exige
> Charge Items; un pedido de Shopify que no los genera sale con "No Results" aunque
> el cargo exista. No confundir ese vacío con un fallo del fix.

---

## Cómo interpretar el resultado

| Lo que muestra **Total** | Qué significa |
|---|---|
| Lo mismo que cobró Shopify | ✅ El fix funciona |
| **El precio unitario** (40.00) | ❌ El bug se reproduce — ese org no tiene el fix |
| Otro valor | Revisar descuento e impuesto antes de concluir |

La regla simple: **el `Total` del Sale Item y el total del reporte tienen que ser
iguales a lo que el cliente pagó en Shopify.** Si los tres no coinciden, hay algo.

---

## Si algo no cuadra — diagnóstico rápido

1. ¿`Source` dice **Shopify**? Si no, este fix no aplica.
2. ¿`Amount` = Price × Quantity? Si no, el problema está antes del cálculo del total.
3. ¿`Subtotal` = Amount menos descuentos?
4. ¿`Total` = Subtotal más `Tax Amount`?
5. Si alguna no cierra, comparar `LastModifiedDate` del registro contra la fecha de
   release del fix: pudo haberse escrito antes.

---

## Capturas de esta corrida

Guardar en `screenshots/` junto a este documento:

```
1-shopify-checkout-129.png                 checkout de Shopify: 3 × $40 + $9 = $129.00
2-client-purchase-P-2425.png               la compra: 3 items, Sold, Total $129.00
3-sale-item-S-3457-amount-y-total.png      Amount $120 y Total $129 juntos ← la clave
4-reporte-shop-sales-today.png             el reporte cuadrando en $129.00 ← la del PM
```

Las capturas de intentos anteriores quedaron en `otras-capturas/`, sin usar.
