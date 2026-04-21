### NSP (Perímetros de Seguridad de Red) para cuentas de Azure Storage utilizadas por cómputo serverless:

Estamos agregando una nueva función de red que introduce un NSP (Perímetro de Seguridad de Red) y emplea una etiqueta de servicio que identifica las subredes de tráfico entrante de endpoints de servicio serverless (endpoints estables serverless). Esto permite una mayor conectividad y flexibilidad, permitiendo la expansión sin alcanzar las limitaciones actuales de recursos.

### Motivación:

La creciente demanda de servicios serverless requiere la creación de suscripciones de cómputo adicionales para soportar más Máquinas Virtuales (VMs). Un desafío significativo surge porque las nuevas subredes dentro de estas suscripciones no pueden ser incluidas automáticamente en la lista de permitidos por los clientes existentes (debido a las restricciones actuales del producto). Esto impide el escalamiento horizontal y genera aristas problemáticas en la experiencia del producto.


### Script de Migración

Este script de PowerShell automatiza la creación de un Perímetro de Seguridad de Red (NSP) en Azure y asocia las Cuentas de Storage con ACLs de VNet de Databricks al NSP en modo de aprendizaje. Registra todas las acciones en un archivo de log con marca de tiempo en el directorio del script.

- Si desea utilizar un método con plantilla ARM en su lugar, existe un script de migración alternativo que utiliza una plantilla ARM para su uso en un pipeline de CI/CD por ejemplo, siga este enlace: https://github.com/stjokerli/NPSforDatabricksServerless

### Parámetros:

#### Subscription\_Id:

* El ID de la Suscripción de Azure donde se creará el NSP.

#### Resource\_Group:

* El nombre del Grupo de Recursos donde se creará el NSP.

#### Azure\_Region:

* La región de Azure donde se creará el NSP.

#### Interactive:

* (opcional) Indicador booleano para señalar si se debe ejecutar en modo interactivo (solicitar confirmación para cada asociación) o en modo desatendido.
* El valor predeterminado es $true (modo interactivo).

#### Remove\_Serverless\_ServiceEndpoints:

* (opcional) Indicador booleano para señalar si se deben eliminar los endpoints de servicio de las Cuentas de Storage después de asociarlas con NSP en modo desatendido.
* El valor predeterminado es $false.

#### NSP\_Name:

* (opcional) El nombre del Perímetro de Seguridad de Red a crear. El valor predeterminado es "databricks-nsp".

#### NSP\_Profile:

* (opcional) El nombre del Perfil del Perímetro de Seguridad de Red a crear. El valor predeterminado es "adb-profile".

#### Use\_Global\_Profile:
* (opcional) Indicador booleano para señalar si se debe utilizar un único perfil global para todas las asociaciones en lugar de perfiles regionales. Si se establece en $true, el script utilizará el perfil global predeterminado con la etiqueta de servicio "AzureDatabricksServerless" para todas las asociaciones independientemente de la ubicación. El valor predeterminado es $false (utilizar perfiles regionales basados en la ubicación de la cuenta de storage).
* Esto es útil en escenarios donde desea simplificar la gestión de perfiles y acepta utilizar la etiqueta de servicio global para todas las ubicaciones.
* Actualmente solo es posible el acceso dentro de la misma región utilizando asociaciones NSP, pero en el futuro puede ser posible el acceso a endpoints de servicio globales, lo que haría que esta opción fuera más relevante.


#### Storage\_Account\_Names:

* (opcional) Un arreglo de nombres de Cuentas de Storage para asociar específicamente. Si no se proporciona, se procesarán todas las Cuentas de Storage con ACLs de VNet de Databricks.

#### Dry\_Run\_mode
* (opcional) Indicador booleano para señalar si se debe ejecutar el script en modo de prueba (dry run), que realizará todos los pasos y registrará todas las acciones que se tomarían, pero no realizará realmente ningún cambio en las asociaciones NSP ni eliminará los endpoints de servicio. Esto es útil para pruebas y validación antes de ejecutar el script de forma real.

### Ejecución del script:

Puede ejecutar este script en el Cloud Shell del portal de Azure (PowerShell). Cuando se ejecuta sin parámetros, solicitará el ID de Suscripción, el grupo de recursos y la región para usar/crear el NSP y el perfil para esa suscripción específica.

Puede modificar los nombres predeterminados del NSP y el perfil con los parámetros **NSP\_Name** y **NSP\_Profile**. También puede dirigirse a cuentas de storage específicas pasando una lista separada por comas de cuentas de storage con el parámetro **Storage\_Account\_Names**.

#### Modo Interactivo y Desatendido:

Este script se puede ejecutar de forma interactiva, lo que le permite aprobar cada cambio y paso del proceso, o puede ejecutarse en modo desatendido, que procederá a realizar cambios sin ninguna solicitud de confirmación. Este comportamiento se controla mediante el parámetro **Interactive**, cuyo valor predeterminado es True (ejecución interactiva).

### EJEMPLOS
   #### Ejecución en modo interactivo
   ```
   ./nsp-migrate-script.ps1 -Subscription_Id "<id de suscripción>" -Resource_Group "<nombre del grupo de recursos>" -Azure_Region "<región de azure>"
```
   #### Ejecución en modo desatendido:
```
   ./nsp-migrate-script.ps1 -Subscription_Id "<id de suscripción>" -Resource_Group "<nombre del grupo de recursos>" -Azure_Region "<región de azure>" -Interactive False
```
   #### Eliminar endpoints de servicio en modo desatendido
```
   ./nsp-migrate-script.ps1 -Subscription_Id "<id de suscripción>" -Resource_Group "<nombre del grupo de recursos>" -Azure_Region "<región de azure>" -Interactive False -Remove_Serverless_ServiceEndpoints True
```
   #### Migrar una cuenta de storage específica o varias cuentas de storage
   ```
   ./nsp-migrate-script.ps1 -Subscription_Id "<id de suscripción>" -Resource_Group "<nombre del grupo de recursos>" -Azure_Region "<región de azure>" -Storage_Account_Names <cuenta de storage o lista separada por comas de cuentas de storage>
```

###### creado por: Bruce Nelson Databricks
