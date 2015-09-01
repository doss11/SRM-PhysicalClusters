SRM-PhysicalClusters - Scripts to assist with using VMWare Site Recovery Manager to protect physical Windows Failover Clusters

Companion files for VMWorld US 2015 session STO5053

Set_Perennially-reserved_flags_manually.ps1 - run this before any failover cluster RDM LUN is presented to VMWare hosts.
.\Set_Perennially-reserved_flags_manually.ps1 -vcenter 'prodvcenter.mycompany.com' -targetcluster 'VMWareClusterName' -NAAs 'naa.abcd1234abcd1234','naa.d1e1f10001020304','naa.FFA5D6001234F7DE'

Set_Perennially-reserved_flags.ps1 - run this within each SRM recovery plan, after all VMs with RDM disks have been recovered.
Run on the SRM server (requires a recent version of PowerCLI to be installed on the SRM server):
<path_to_script>\Set_Perennially-reserved_flags.ps1 -vcenter 'DRvcenter.mycompany.com' -targetcluster 'VMWareClusterName'

SRM_Commands.txt - contains the on-liner commands to add to each SRM protected VM to run on the recovered VM, after the "Wait for VMTools" step in  each recovery plan.  These commands force the Failover cluster to start, and change the failover cluster quorum mode to "disk only" 
