# Grab out important wsrep metrics from cluster_health.log
#
# Currently tracks when wsrep_local_{send,recv}_queues are nonzero.

# Example:
# $ gawk -f replication-status-cluster-health.gawk ~/Downloads/t/node0/cluster_health.log
#
# Now you set set verbose mode (if you want to debug) this way:
# $ gawk -vVERBOSE=1 -f ..

# Using verbose mode...
# wsrep_local_recv_queue field: 34
# wsrep_local_send_queue field: 39
# timestamp,local_recv_queue,local_send_queue
# 2018-04-16T10:26:47Z,2,0
# 2018-04-16T11:00:17Z,3,0
# 2018-04-16T11:00:47Z,6,0

# TODO
# Might be nice to also graph wsrep_flow_control_{recv,sent}
#   ... note these numbers grow monotonically

BEGIN {
  if ( VERBOSE"X" != "X" && VERBOSE == "1" ) {
    VERBOSE_MODE=1
  } else {
    VERBOSE_MODE=0
  }
  if (VERBOSE_MODE) { print "Using verbose mode..." > "/dev/stderr" }
  FPAT = "([^|]*)|(\"[^\"]+\")"
}

NR == 1 {
  timestamp_field = "N/A" ;
  for ( i = 0 ; i < NF ; i++ ) {
    if ( $i == "timestamp" ) { timestamp_field = i ; }
    if ( $i == "wsrep_local_recv_queue" ) { local_recv_queue_field = i ; }
    if ( $i == "wsrep_local_send_queue" ) { local_send_queue_field = i ; }
  }
  if ( "N/A" == timestamp_field ) {
    print "Unable to find timestamp in headers. Aborting." ;
    exit 1 ;
  }
  if (VERBOSE_MODE) {
    print "wsrep_local_recv_queue field: " local_recv_queue_field > "/dev/stderr"
    print "wsrep_local_send_queue field: " local_send_queue_field > "/dev/stderr"
  }
  print "timestamp,local_recv_queue,local_send_queue" ;
}

NR != 1 {
   if ("0" != $local_recv_queue_field || "0" != $local_send_queue_field) {
       h = $timestamp_field ; 
       g = $local_recv_queue_field ;
       i = $local_send_queue_field ;
       print h "," g "," i ;
   }
}
