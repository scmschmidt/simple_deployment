 
|   |  |  |
|-----|-----|----|
| 01.04.2022 | v1.0 | first release (no April joke) |
| 04.04.2022 | v1.1 | Slight rework due to a "design flaw".<br>Now we have a list of size/image tuples to create multiple machines and `images_aws.yaml` supports images per region. |
| 06.04.2022 | v1.2 | Slight rework again. Machines are now declared as an object with identifiers and not as a list anymore.<br>This was necessary to allow the list of machines change safely between applies.<br>The meta_data module has been removed. |
| 12.04.2022 | v1.3 | All three modules can handle stopped machines (in a different way).<br>Consecutive applies on Azure do not lead to re-deployments anymore due to tag changes by some automatism on Azure side |