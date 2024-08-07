 
|   |  |  |
|-----|-----|----|
| 01.04.2022 | v1.0 | first release (no April joke) |
| 04.04.2022 | v1.1 | Slight rework due to a "design flaw".<br>Now we have a list of size/image tuples to create multiple machines and `images_aws.yaml` supports images per region. |
| 06.04.2022 | v1.2 | Slight rework again. Machines are now declared as an object with identifiers and not as a list anymore.<br>This was necessary to allow the list of machines change safely between applies.<br>The meta_data module has been removed. |
| 12.04.2022 | v1.3 | All three modules can handle stopped machines (in a different way).<br>Consecutive applies on Azure do not lead to re-deployments anymore due to tag changes by some automatism on Azure side. |
| 12.04.2022 | v1.4 | Pinned dmacvicar/libvirt to version 0.6.10 because later version have a bug which can prevent SSH-based libvirt connections: https://github.com/dmacvicar/terraform-provider-libvirt/issues/864 |
| 28.07.2022 | v1.5 | Added security rule to allow ICMP on AWS (Azure is still without ICMP, since I have trouble login in today. :-/ ) |
| 28.07.2022 | v1.6 | Added security rule to allow ICMP on Azure. |
| 29.07.2022 | v1.7 | Changed sources in the examples from local to remote (git::https://...) and removed the doc parts telling that it doesn't work. Suddenly it does. No idea why, so I just accept it as a lucky turn. |
| 11.07.2024 | v1.8 | Added support for the tags `owner`, `managed_by` and `application` on Azure and AWS. |