# Method

This document describes the method used to manage the snapshots.

## `terraform apply`

On `terraform apply` a snapshot of the current system gets created to which will be returned on `terraform destroy` and a rollback to a `BASELINE` snapshots is performed. This `BASELINE` snapshot must exist otherwise we have to terminate.

```  
$ LANG=C snapper -c root list --disable-used-space --columns number,type,pre-number,post-number,default,active,description,userdata
    # | Type   | Pre # | Post # | Default | Active | Description           | Userdata     
-----+--------+-------+--------+---------+--------+-----------------------+--------------
    0  | single |       |        | no      | no     | current               |              
105  | pre    |       |   106  | no      | no     | zypp(zypper)          | important=yes
106  | post   |   105 |        | no      | no     |                       | important=yes
135  | pre    |       |   136  | no      | no     | zypp(zypper)          | important=yes
136  | post   |   135 |        | no      | no     |                       | important=yes
140  | pre    |       |   141  | no      | no     | zypp(zypper)          | important=yes
141  | post   |   140 |        | no      | no     |                       | important=yes
179  | single |       |        | no      | no     | BASELINE              |              
206* | single |       |        | yes     | yes    | writable copy of #140 | 
```

The BASELINE has been created in the past and currently we are on #206.


1. Check if the BASELINE snapshot exists and terminate if not. Without it we cannot continue.
   
   ```
   $ LANG=C snapper --csvout  -c root list --disable-used-space --columns description | grep '^BASELINE$'
   ```
   Should return one line.

1. Check if we are already have the snapshots to be idempotent.
   ```
   $ LANG=C snapper --csvout  -c root list --disable-used-space --columns description | grep '^simple_baremetal$'
   ```
   If the rollback command has been executed, two lines should be found and nothing if not.
   Any other amount of lines suggests problems on apply or destroy.

1. Rollback to the BASELINE snapshot from the running system .
   A snapshot of the current system gets created. It is the snapshot we are returning to with `terraform destroy`.

   ``` 
   $ LANG=C snapper --csvout  -c root list --disable-used-space --columns number,description | grep ',BASELINE$' | cut -d',' -f1
   179
    
   $ LANG=C snapper -c root rollback -d 'simple_baremetal' 179
   Ambit is classic.
   Creating read-only snapshot of current system. (Snapshot 207.)
   Creating read-write snapshot of snapshot 179. (Snapshot 208.)
   Setting default subvolume to snapshot 208.

   $ LANG=C snapper -c root list --disable-used-space --columns number,type,pre-number,post-number,default,active,description,userdata
      # | Type   | Pre # | Post # | Default | Active | Description           | Userdata     
   -----+--------+-------+--------+---------+--------+-----------------------+--------------
     0  | single |       |        | no      | no     | current               |              
   105  | pre    |       |   106  | no      | no     | zypp(zypper)          | important=yes
   106  | post   |   105 |        | no      | no     |                       | important=yes
   135  | pre    |       |   136  | no      | no     | zypp(zypper)          | important=yes
   136  | post   |   135 |        | no      | no     |                       | important=yes
   140  | pre    |       |   141  | no      | no     | zypp(zypper)          | important=yes
   141  | post   |   140 |        | no      | no     |                       | important=yes
   179  | single |       |        | no      | no     | BASELINE              |              
   206- | single |       |        | no      | yes    | writable copy of #140 |              
   207  | single |       |        | no      | no     | simple_baremetal      | important=yes
   208+ | single |       |        | yes     | no     | simple_baremetal      |  
   ```
   
   Snapshot 207 is the one we need to recover on destroy.
   Snapshot 208 ist the rw snapshot of BASELINE we need to boot into.

1. Check if we have booted already in the BASELINE rollback (idempotency)

   ```
   $ LANG=C snapper --csvout  -c root list --disable-used-space --columns default,active,description | grep 'yes,yes,simple_baremetal$'
   yes,yes,simple_baremetal
   ```
   If one of the `simple_baremetal` snapshots is active and default, the reboot has been done.

1. Reboot the system
   ```
   $ reboot

   $ LANG=C snapper -c root list --disable-used-space --columns number,type,pre-number,post-number,default,active,description,userdata
     # | Type   | Pre # | Post # | Default | Active | Description           | Userdata     
   -----+--------+-------+--------+---------+--------+-----------------------+--------------
     0  | single |       |        | no      | no     | current               |              
   105  | pre    |       |   106  | no      | no     | zypp(zypper)          | important=yes
   106  | post   |   105 |        | no      | no     |                       | important=yes
   135  | pre    |       |   136  | no      | no     | zypp(zypper)          | important=yes
   136  | post   |   135 |        | no      | no     |                       | important=yes
   140  | pre    |       |   141  | no      | no     | zypp(zypper)          | important=yes
   141  | post   |   140 |        | no      | no     |                       | important=yes
   179  | single |       |        | no      | no     | BASELINE              |              
   206  | single |       |        | no      | no     | writable copy of #140 |              
   207  | single |       |        | no      | no     | simple_baremetal      | important=yes
   208* | single |       |        | yes     | yes    | simple_baremetal      | 
   ```
   
   The system has no reached the end of `terraform apply`. The system has been booted into #208 (the rw copy of #179). 

## `terraform destroy`

On `terraform destroy` we rollback to the first `simple_baremetal` snapshot created by `terraform destroy`.

```  
$ LANG=C snapper -c root list --disable-used-space --columns number,type,pre-number,post-number,default,active,description,userdata
   # | Type   | Pre # | Post # | Default | Active | Description           | Userdata     
-----+--------+-------+--------+---------+--------+-----------------------+--------------
  0  | single |       |        | no      | no     | current               |              
105  | pre    |       |   106  | no      | no     | zypp(zypper)          | important=yes
106  | post   |   105 |        | no      | no     |                       | important=yes
135  | pre    |       |   136  | no      | no     | zypp(zypper)          | important=yes
136  | post   |   135 |        | no      | no     |                       | important=yes
140  | pre    |       |   141  | no      | no     | zypp(zypper)          | important=yes
141  | post   |   140 |        | no      | no     |                       | important=yes
179  | single |       |        | no      | no     | BASELINE              |              
206  | single |       |        | no      | no     | writable copy of #140 |              
207  | single |       |        | no      | no     | simple_baremetal      | important=yes
208* | single |       |        | yes     | yes    | simple_baremetal      | 
```

Currently we are in #206 and want to return to #207.

1. Check if we are already have the snapshots to be idempotent.
   ```
   $ LANG=C snapper --csvout  -c root list --disable-used-space --columns number,default,active,description | grep -e ',no,no,simple_baremetal$' -e ',yes,yes,simple_baremetal$'
   207,no,no,simple_baremetal
   208,yes,yes,simple_baremetal
   ```
   Exactly two lines should be found.

1. Rollback to the first `simple_baremetal` snapshot.
   ```
   $ LANG=C snapper --csvout  -c root list --disable-used-space --columns number,default,active,description | grep ',simple_baremetal$' | head -n 1 | cut -d, -f 1
   207

   $ LANG=C snapper -c root rollback -d 'simple_baremetal recovery' 207
   Ambit is classic.
   Creating read-only snapshot of current system. (Snapshot 209.)
   Creating read-write snapshot of snapshot 207. (Snapshot 210.)
   Setting default subvolume to snapshot 210.

   $ LANG=C snapper -c root list --disable-used-space --columns number,type,pre-number,post-number,default,active,description,userdata
      # | Type   | Pre # | Post # | Default | Active | Description               | Userdata     
   -----+--------+-------+--------+---------+--------+---------------------------+--------------
     0  | single |       |        | no      | no     | current                   |              
   105  | pre    |       |   106  | no      | no     | zypp(zypper)              | important=yes
   106  | post   |   105 |        | no      | no     |                           | important=yes
   135  | pre    |       |   136  | no      | no     | zypp(zypper)              | important=yes
   136  | post   |   135 |        | no      | no     |                           | important=yes
   140  | pre    |       |   141  | no      | no     | zypp(zypper)              | important=yes
   141  | post   |   140 |        | no      | no     |                           | important=yes
   179  | single |       |        | no      | no     | BASELINE                  |              
   206  | single |       |        | no      | no     | writable copy of #140     |              
   207  | single |       |        | no      | no     | simple_baremetal          | important=yes
   208- | single |       |        | no      | yes    | simple_baremetal          |              
   209  | single |       |        | no      | no     | simple_baremetal recovery | important=yes
   210+ | single |       |        | yes     | no     | simple_baremetal recovery |              
   ```
   Snapshot 209 is a snapshot we can delete later.
   Snapshot 208 ist the rw snapshot of 207 - the system as it was before the `terraform apply`.

1. Check if we have booted already in the recovery rollback (idempotency)
   ```
   $ LANG=C snapper --csvout  -c root list --disable-used-space --columns default,active,description | grep 'yes,yes,simple_baremetal recovery$'
   yes,yes,simple_baremetal recovery
   ```
   If one of the `simple_baremetal recovery` snapshots is active and default, the reboot has been done.


1. Reboot the system
   ```
   $ reboot

   $ LANG=C snapper -c root list --disable-used-space --columns number,type,pre-number,post-number,default,active,description,userdata
      # | Type   | Pre # | Post # | Default | Active | Description           | Userdata     
   -----+--------+-------+--------+---------+--------+-----------------------+--------------
     0  | single |       |        | no      | no     | current                   |              
   105  | pre    |       |   106  | no      | no     | zypp(zypper)              | important=yes
   106  | post   |   105 |        | no      | no     |                           | important=yes
   135  | pre    |       |   136  | no      | no     | zypp(zypper)              | important=yes
   136  | post   |   135 |        | no      | no     |                           | important=yes
   140  | pre    |       |   141  | no      | no     | zypp(zypper)              | important=yes
   141  | post   |   140 |        | no      | no     |                           | important=yes
   179  | single |       |        | no      | no     | BASELINE                  |              
   206  | single |       |        | no      | no     | writable copy of #140     |              
   207  | single |       |        | no      | no     | simple_baremetal          | important=yes
   208  | single |       |        | no      | no     | simple_baremetal          |              
   209  | single |       |        | no      | no     | simple_baremetal recovery | important=yes
   210* | single |       |        | yes     | yes    | simple_baremetal recovery |  
   ```
   
1. Finally all snapshots not used anymore can be removed.
   ```
   $ LANG=C snapper --csvout  -c root list --disable-used-space --columns number,default,active,description | grep ',no,no,simple_baremetal' | cut -d ',' -f 1
   207
   208
   209

   $ snapper delete 207
   $ snapper delete 208
   $ snapper delete 209

   $ LANG=C snapper -c root list --disable-used-space --columns number,type,pre-number,post-number,default,active,description,userdata
      # | Type   | Pre # | Post # | Default | Active | Description               | Userdata     
   -----+--------+-------+--------+---------+--------+---------------------------+--------------
     0  | single |       |        | no      | no     | current                   |              
   105  | pre    |       |   106  | no      | no     | zypp(zypper)              | important=yes
   106  | post   |   105 |        | no      | no     |                           | important=yes
   135  | pre    |       |   136  | no      | no     | zypp(zypper)              | important=yes
   136  | post   |   135 |        | no      | no     |                           | important=yes
   140  | pre    |       |   141  | no      | no     | zypp(zypper)              | important=yes
   141  | post   |   140 |        | no      | no     |                           | important=yes
   179  | single |       |        | no      | no     | BASELINE                  |              
   206  | single |       |        | no      | no     | writable copy of #140     |              
   210* | single |       |        | yes     | yes    | simple_baremetal recovery |    
   ```

   The system has no reached the end of `terraform destroy`. The system has been booted into #208 (the rw copy of #179). 
