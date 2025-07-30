# Method

This document describes the method used to manage the snapshots.

To get an overview run:
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

The sourced `include` script provides a function `update_ss_vars` to update the variables:

- `ss_default` - number of the active snapshot
- `ss_active` - number of the default snapshot (active for next boot)
- `ss_baseline` - number of the (last) BASELINE snapshot (can be empty)
- `ss_baseline_working` - number of the (last) working BASELINE snapshot (can be empty)

which can be used for decisions.


## `terraform apply`

On `terraform apply` a snapshot of the current system gets created to which will be returned on `terraform destroy` and a rollback to a `BASELINE` snapshot - a copy of it to be precise - is performed. This `BASELINE` snapshot must exist otherwise we have to terminate.

1. Check prerequisites:
   ```
   count_baseline=$(snapper --csvout -c root list --columns description | grep BASELINE | wc -l)
   case ${count_baseline} in
      0) exit_on_error 'No BASELINE snapshot found! Exiting.'
         ;;
      1) log 'BASELINE snapshot found'
         ;;
      *) exit_on_error 'More then one BASELINE snapshots found! Exiting.'
         ;;
   esac
   current_status=$(< "${status_file}")
   [ -n "${current_status}"] && exit_on_error "Invalid status: ${current_status}"
   ```

   A BASELINE snapshot must exist only once and the status must be empty.
   A failure simply terminates the script. The status does not get changed in any case.


2. Remember current snapshot: 
   ```
   # echo "${ss_active}" > "${recovery_snapshot_file}"
   ```

   The snapshot gets remembered in `/var/lib/simple_baremetal/recovery_snapshot`. 
   A failure simply terminates the script. The status does not get changed in any case.
   

3. Rollback to BASELINE:
   ```
   [ -z "${ss_baseline}" ] && exit_on_error "No BASELINE snapshot found!"
   output=$(LANG=C snapper -c root rollback -d 'BASELINE (working)' ${ss_baseline})
   rc=$?
   if [ ${rc} -eq 0 ] ; then
      surplus_snapshot=$(grep 'Creating read-only snapshot of current system.' <<< "${output}" | sed 's/[^0-9]//g')
      working_snapshot=$(grep 'Setting default subvolume to snapshot' <<< "${output}" | sed 's/[^0-9]//g') 
      echo "${working_snapshot}" > "${working_snapshot_file}"
      echo 'baseline_set' > "${status_file}
   else
      echo 'baseline_failed' > "${status_file}
   fi
   ```

   The working baseline snapshot is remembered in `/var/lib/simple_baremetal/working_snapshot`.
   On success the status is set to `baseline_set`, on failure to `baseline_failed`, which is a terminal state and requires manual fixing.   


4. Delete surplus read-only BASELINE snapshot:
   ```
   LANG=C snapper -c root delete ${surplus_snapshot}
   ```

   Deleting the snapshot is optional and a failure is ignored. The status does not get changed in any case.


5. Reboot:
   ```
   # reboot
   ```
   A reboot is only triggered, if the status is set to `baseline_set`.


6. Check if all is ok:
   ```
   # LANG=C snapper --csvout -c root list --columns number,active,default,description | grep '^13,yes,yes,BASELINE (working)$'
   ```

   If the check fails, booting into the snapshot has failed. The status is left alone and the script terminates.
   On success  the status is set to `baseline_active`.


## `terraform destroy`

On `terraform destroy` the system boots in the saved recovery snapshot on `terraform apply` the BASELINE copy snapshot gets removed.

1. Check prerequisites:
   ```
   if test -s /var/lib/simple_baremetal/recovery_snapshot ; then
      exit_on_failure ''

   ```

   Prerequisite for the recovery is a saved recovery snapshot.


2. Set recovery snapshot as default:
   ```
   # cat /var/lib/simple_baremetal/recovery_snapshot
   1

   # btrfs subvolume list -t / | expand | grep ' @/.snapshots/1/snapshot$' | tr -s ' ' | cut -d ' ' -f1
   267

   # btrfs subvolume set-default 267 /
   ```   

   On failure the script terminates without changing the status. On success the status is set to `recovery_set`. 


2. Reboot
   ```
   # reboot
   ```
   A reboot is only triggered, if the status is set to `recovery_set`.


3. Check if all is ok and do the work:
   ```
   # LANG=C snapper --csvout -c root list --columns number,active,default | grep '^1,yes,yes$'
   ```

   If the check fails, booting into the snapshot has failed. The status is left alone and the script terminates.
   With cleanup as next step, the status is left alone.


4. Cleanup. Remove now redundant working BASELINE snapshot and clean all files:
   ```
   # LANG=C snapper -c root delete 13

   # > /var/lib/simple_baremetal/recovery_snapshot
   # > /var/lib/simple_baremetal/working_snapshot
   # > /var/lib/simple_baremetal/status
   ```


-------

rollback2baseline

   status: baseline_set  --> 0
   status: baseline_failed  --> 1
   status: baseline_ss_failure  --> 1
   status: (empty)  --> 1


boot2baseline

# A reboot is only triggered, if the status is set to `baseline_set`.
[ "${status}" != 'baseline_set'  ] && exit_on_error "Invalid status for reboot: ${status}"

# Reboot if necessary (the working BASELINE snapshot is not the active one).
update_ss_vars
if [ "${ss_working_baseline}" == "${ss_active}" ] ; then
    log "The working BASELINE snapshot (${ss_working_baseline}) is already active. No reboot required."
    exit 0
fi
reboot





cleanup:

   if status
      baseline_set            -> set default back to recovery and cleanup
      baseline_failed         -> do nothing  (apply did not change anything) 
      baseline_ss_failure     -> do nothing (apply did not change anything)
      (empty)                 -> do nothing (apply did not change anything)

   status: != recovery_set  -> 1
   recovery snapshot not active -> 1



-----

    ss_default 
    ss_active
    ss_baseline
    ss_baseline_working
    ss_recovery=
}

rollback2baseline:

   A BASELINE rollback should be done only:
      - if a BASELINE snapshot exists
      - if no working BASELINE exists
      - if BASELINE is not the active snapshot

boot2baseline:

   A reboot (intended to boot into the rollbacked baseline) should be done only:
      - a working BASELINE snapshot exists
      - the working BASELINE is the default
      - the working BASELINE is not the active one


verify_baseline

   A successful boot into the working BASELINE happened if:
      - the working BASELINE snapshot is the active one




rollback2recovery:

   A recovery rollback should be done only:
      - a recovery snapshot exists
      - if the recovery snapshot is not the active snapshot


boot2recovery:

   A reboot to recovery should be done only:
      - a a recovery snapshot exists exists
      - the recovery snapshot exists is the default
      - the recovery snapshot exists is not the active one

verify_recovery:

   A successful boot into the recovery snapshot happened if:
      - the recovery snapshot is the active one

cleanup:

   A cleanup should only be done:
      - the recovery snapshot is the active one
