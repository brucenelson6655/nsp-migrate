## nsp-check.ps1 — Script de Verificación Previa para Migración de NSP

Este script identifica las Cuentas de Azure Storage con ACLs de VNet de Databricks que son candidatas para migración a un Perímetro de Seguridad de Red (NSP). Produce un reporte de las cuentas elegibles sin realizar ningún cambio, por lo que es seguro ejecutarlo como un paso de descubrimiento/planeación antes de ejecutar la migración completa.

Todas las acciones se registran en un archivo de log con marca de tiempo (`nsp-migrate-log_<timestamp>.log`) en el directorio del script.

---

### Cómo Funciona

1. Se conecta a la suscripción de Azure especificada.
2. Consulta Azure Resource Graph para obtener las Cuentas de Storage con reglas de ACL de VNet que apunten a IDs de subredes serverless conocidas de Databricks.
3. Filtra las cuentas que son DBFS (almacenamiento predeterminado del workspace) o que ya están asociadas con un NSP.
4. Genera un reporte que lista las Cuentas de Storage que requieren migración a NSP.


---

### Prerrequisitos

- [Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell) (módulo `Az`)
- Módulo `Az.ResourceGraph` (`Install-Module -Name Az.ResourceGraph`)
- Acceso de Contributor o Owner en la suscripción objetivo

---

### Parámetros

| Parámetro | Requerido | Descripción |
|---|---|---|
| `Subscription_Id` | Sí | El ID de la Suscripción de Azure a evaluar. |
| `Storage_Account_Names` | No | Arreglo de nombres específicos de Cuentas de Storage a evaluar. Si se omite, se evalúan todas las Cuentas de Storage elegibles en la suscripción. |

---

### Ejemplos

**Escanear todas las Cuentas de Storage en una suscripción:**
```powershell
./nsp-check.ps1 -Subscription_Id "12345678-1234-1234-1234-123456789012"
```

**Escanear Cuentas de Storage específicas:**
```powershell
./nsp-check.ps1 -Subscription_Id "12345678-1234-1234-1234-123456789012" -Storage_Account_Names "storageaccount1","storageaccount2"
```

---

### Salida

El script imprime un resumen de las Cuentas de Storage que:
- Tienen reglas de ACL de VNet que apuntan a subredes serverless de Databricks
- **No** son DBFS (almacenamiento predeterminado del workspace)
- **No** están ya asociadas con un NSP

Ejemplo de salida:
```
Found 3 Storage Accounts with Databricks VNet ACLs and not yet associated with NSP.
The following Storage Accounts were identified for migration:

- mystorageaccount1 Resource Group: my-rg Location: eastus
- mystorageaccount2 Resource Group: my-rg Location: westus2
- mystorageaccount3 Resource Group: another-rg Location: eastus
```

Si no hay cuentas que requieran migración:
```
No Storage Accounts matched, no NSP work required.
```

---

### Próximos Pasos

Una vez que haya identificado las Cuentas de Storage que requieren migración, utilice [`nsp-migrate-script.ps1`](./README-mx.md) para asociarlas con un Perímetro de Seguridad de Red.

---

###### creado por: Bruce Nelson, Databricks
