# Orkes / Conductor Deployment Pipeline PoC

Esta Prueba de Concepto muestra cómo registrar y ejecutar dos workflows sencillos en Orkes/Netflix Conductor utilizando únicamente tareas de LOG, WAIT y HTTP contra un worker mock. El objetivo es tener un entorno reproducible en minutos para demostrar:

1. `deploy_simple_v1`: un flujo de deploy con logs, espera y tres llamadas HTTP.
2. `pipeline_simple_v1`: un pipeline que lanza múltiples deploys en paralelo por waves reutilizando el workflow anterior.

La carpeta está pensada para funcionar tanto con Orkes Cloud como con una instalación self-hosted compatible con las APIs REST actuales.

## 1. Prerrequisitos (5 minutos)

* Acceso a un endpoint de Orkes/Conductor (`ORKES_BASE_URL`) y credenciales válidas (`ORKES_KEY`, `ORKES_SECRET`).
* Docker y Docker Compose **o** Python 3.11+ con `pip` (para ejecutar el worker sin contenedores).
* Herramientas de línea de comando: `bash`, `curl`, `jq`, `python3`.
* Opcional pero recomendado: acceso a la UI de Orkes/Conductor para visualizar los workflows.

## 2. Configuración (1 minuto)

1. Copia el archivo de ejemplo y completa tus valores:

   ```bash
   cp .env.sample .env
   # edita .env con tu editor favorito
   ```

   Variables requeridas:

   ```env
   ORKES_BASE_URL=https://tu-instancia.orkes.io
   ORKES_KEY=xxxx
   ORKES_SECRET=yyyy
   WORKER_BASE_URL=http://localhost:3000
   ```

2. (Opcional) Ajusta los payloads de `tasks/samples/deploy_input.json` y `tasks/samples/pipeline_input.json` para personalizar `scope`, `version`, `env` o el comportamiento de `continueOnFailure`.

## 3. Levantar el worker mock (2-4 minutos)

El worker expone los endpoints `/provision`, `/traffic` y `/verify` y simplemente imprime la carga y responde `200`.

### Opción A: Docker Compose (recomendada)

```bash
cd worker
docker compose up -d
```

*Tiempo estimado: 2 minutos (la primera vez puede tardar más por la descarga de imágenes).* 

Verifica que responde:

```bash
curl -sS -X POST http://localhost:3000/provision \
  -H 'Content-Type: application/json' \
  -d '{"ping":true}' | jq
```

Para detenerlo:

```bash
docker compose down
```

### Opción B: Entorno local de Python (3-4 minutos)

```bash
cd worker
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e .
uvicorn src.server:app --reload --host 0.0.0.0 --port 3000
```

La API quedará escuchando en `http://localhost:3000`.

## 4. Registrar definiciones (1 minuto)

El script registra los taskdefs HTTP y ambos workflows. Internamente reemplaza el placeholder `__WORKER_BASE_URL__` con el valor de `WORKER_BASE_URL` de tu `.env`.

```bash
bash scripts/register.sh
```

Salida esperada:

* Mensajes `2xx` en las respuestas impresas.
* Un resumen con `[register] Done.`

## 5. Ejecutar `deploy_simple_v1` (1-2 minutos)

1. Revisa el payload de ejemplo (`tasks/samples/deploy_input.json`).
2. Lanza el workflow:

   ```bash
   bash scripts/run_deploy.sh
   ```

   El script mostrará el `workflowId` generado, por ejemplo `deploy_simple_v1_2024-...`.

3. Consulta el estado (puedes ejecutar este comando varias veces):

   ```bash
   bash scripts/status.sh <workflowId>
   ```

4. Abre la UI de Orkes/Conductor → `Executions` → busca el `workflowId` → revisa el diagrama para ver los pasos `LOG`, `WAIT` y `HTTP`. En la consola del worker deberías ver mensajes `[WORKER] {"step": ... }` para cada llamada.

## 6. Ejecutar `pipeline_simple_v1` (2-3 minutos)

1. Revisa `tasks/samples/pipeline_input.json`:
   * `deployments`: lista de objetos con `scope`, `version`, `env`.
   * `waves`: array de waves; cada wave ejecuta en paralelo los `scope` listados.
   * `continueOnFailure`: controla si el pipeline termina al primer fallo (`false`) o continúa (`true`).

2. Lanza la ejecución:

   ```bash
   bash scripts/run_pipeline.sh
   ```

   Guarda el `workflowId` impreso.

3. Verifica el estado:

   ```bash
   bash scripts/status.sh <workflowId>
   ```

4. En la UI deberías observar dos waves: la primera con `svc-a` y `svc-b` ejecutándose en paralelo (cada una como sub-workflow `deploy_simple_v1`), seguida de la segunda wave con `svc-c`. La consola del worker mostrará las tres secuencias de `/provision`, `/traffic`, `/verify`.

## 7. Errores comunes y soluciones rápidas

| Problema | Síntoma | Solución |
| --- | --- | --- |
| Credenciales inválidas | `401` o `403` al llamar a las APIs | Revisa `ORKES_KEY` y `ORKES_SECRET`. Genera una nueva pareja si es necesario. |
| Worker caído | `curl: (7) Failed to connect` o tareas HTTP en `FAILED` | Asegúrate de que el worker esté corriendo y que `WORKER_BASE_URL` sea correcto. |
| Timeout en tareas HTTP | Workflow se queda en `IN_PROGRESS` en `http_*` | Verifica conectividad local o aumenta los `timeoutSeconds` en `tasks/taskdefs.json`. |
| CORS/UI | La UI del orquestador no carga datos | Accede vía VPN/HTTPS correcto o usa la CLI (`scripts/status.sh`). |

## 8. Limpieza (opcional, <1 minuto)

```bash
bash scripts/cleanup.sh
```

El script intenta eliminar los workflows y taskdefs registrados. Los errores se ignoran para facilitar la limpieza.

## 9. Cómo extender (ideas rápidas)

* **Agregar una nueva tarea HTTP:** duplica una definición en `tasks/taskdefs.json`, actualiza la URI en el workflow, re-registra y ejecútalo.
* **Aprobar waves manualmente:** reemplaza `wait_between` en `deploy_simple_v1` por una tarea `WAIT` más larga o un `USER_TASK` para simular un “manual gate”.
* **Cambiar políticas de reintento:** edita `retryCount`, `retryDelaySeconds` o `timeoutSeconds` en las definiciones de tareas HTTP y vuelve a ejecutar `scripts/register.sh`.
* **Más waves:** edita `workflows/pipeline_simple_v1.json` para añadir bloques `wave_3`, `wave_4`, etc. Siguiendo el patrón existente podrás cubrir más grupos de despliegues.

## 10. Estructura del repositorio

```
.
├─ .env.sample
├─ README.md
├─ scripts/
│  ├─ register.sh
│  ├─ run_deploy.sh
│  ├─ run_pipeline.sh
│  ├─ status.sh
│  └─ cleanup.sh
├─ tasks/
│  ├─ taskdefs.json
│  └─ samples/
│     ├─ deploy_input.json
│     └─ pipeline_input.json
├─ workflows/
│  ├─ deploy_simple_v1.json
│  └─ pipeline_simple_v1.json
└─ worker/
   ├─ Dockerfile
   ├─ docker-compose.yml
   ├─ pyproject.toml
   └─ src/
      └─ server.py
```

> Tiempo total estimado end-to-end: **10-15 minutos** (incluyendo descarga de imágenes y revisión en la UI).
