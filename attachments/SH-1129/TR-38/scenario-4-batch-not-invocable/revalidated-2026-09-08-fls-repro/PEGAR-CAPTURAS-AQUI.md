# Capturas pendientes

El YAML de TR-038 ya referencia estos DOS archivos. Pegalos en esta carpeta
con EXACTAMENTE estos nombres, y despues borra este archivo:

1. `flsrepro-inventory-history-orphan-single-row.png`
   La ficha del registro Inventory History. Tiene que dejar ver:
   - Date = la fecha de hoy
   - Item per location = VACIO   <-- la prueba de que la fila es huerfana
   - Shop Item, Display/Storage Location, Item Cost y Total Stock = llenos
   - Inventory Value = $50.00    <-- el numero que se duplicaba

2. `flsrepro-navbar-no-inventory-history-tab.png`
   La barra de navegacion de la app, donde NO aparece Inventory History
   entre los tabs. Es la evidencia visual de SH-1244.

Recorta o evita los botones "New Contact" / "New Opportunity" y el Owner
"User User": son ruido de scratch org sin layout configurado y desvian la
lectura.
