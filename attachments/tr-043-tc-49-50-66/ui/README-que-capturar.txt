QUE FALTA CAPTURAR A MANO (escenarios `not-run`)
=================================================
Todo lo de este TR se verifico por codigo fuente + los 1.658 tests del dev.
NO se abrio navegador. Lo que sigue necesita la app corriendo.

DONDE PROBARLO SIN BACKEND
---------------------------
La propia PR #463 dejo una superficie de revision sin backend:
    /sandbox/discount-wizard
(apps/shared/portal/app/sandbox/discount-wizard/, con sandbox-mocks.tsx)
Sirve para todo lo visual de abajo salvo lo que dice "requiere backend".

CAPTURAS PENDIENTES
--------------------
1-tc50-valor-20-percent.png
   Step 1, Discount Type = % Off, Discount Value = 20.
   Que se vea: el campo con el 20 y su rotulo.

2-tc50-valor-20-dollar.png
   Sin borrar el 20, cambiar Discount Type a $ Off.
   Que se vea: si el 20 sigue ahi (deberia) y si algo en el campo indica
   que ahora son dolares (segun el codigo, NO). Estas dos capturas juntas
   son la prueba visual del hallazgo tc-50/hallazgo-sufijo.txt.

3-tc66-online-on-pos-on-dominios-visibles.png
   Step 3 con Available Online = ON y Available at POS = ON.
   Que se vea: la seccion 'Allowed email domains' visible pese a POS activo.
   Es la prueba visual de tc-66/hallazgo-email-domains-pos.txt.

4-tc66-guardar-con-dominios-y-pos.png   [requiere backend]
   Desde el estado anterior, escribir un dominio y darle Save.
   Que se vea: el error del servidor
   "Email domain restrictions cannot be used when POS is enabled."
   Confirma que el error llega tarde, despues del round trip.

5-tc49-review-sin-fila-redemption.png
   Step 4 Review completo.
   Que se vea: que NO hay ninguna fila "Redemption: ...". Sirve para cerrar
   TC-49 S0/S3 y para redactar el TC nuevo contra el Review que si existe.

6-tc49-kebab-sin-duplicate.png
   Listado de descuentos, menu '...' de una fila abierto.
   Que se vea: las acciones reales (report/edit/activate/deactivate/Archive)
   y la ausencia de Duplicate.

7-tc49-archive-dialogo-y-estado.png
   Mismo menu -> Archive -> confirmar.
   Que se vea: el dialogo "Archive discount code?" y despues la fila con el
   chip Archived.

DONDE DEJARLAS
---------------
attachments/tr-043-tc-49-50-66/ui/  con esos nombres exactos.
Despues avisame y actualizo el TR-043: los pasos hoy en `not-run` pasan a
`passed`/`failed` con la captura referenciada, y el run pasa de `in-progress`
a `completed`.

LO QUE NO SE PUEDE CERRAR NI CON CAPTURAS
------------------------------------------
TC-49 S4 (Archive): "excluida de evaluacion futura" y "el historial de
redenciones queda intacto" son comportamiento de backend. Se validan con una
consulta al motor de descuentos despues de archivar, no mirando la UI.

TC-66 S1: "POS staff must enter a reason at redemption" es comportamiento del
POS en runtime, no del wizard. Se prueba en el POS, no aqui.
