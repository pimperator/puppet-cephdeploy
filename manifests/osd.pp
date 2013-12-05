define cephdeploy::osd(
  $setup_pools            = true,
  $cluster                = 'ceph',
  $user                   = hiera('ceph_deploy_user'),
  $ceph_primary_mon       = hiera('ceph_primary_mon'),
  $cluster_interface      = hiera('ceph_cluster_interface'),
  $cluster_network        = hiera('ceph_cluster_network'),
  $glance_pool            = hiera('glance_ceph_pool'),
  $cinder_pool            = hiera('cinder_rbd_pool'),
  
){

  include cephdeploy
#  include cephdeploy::mon
  $disk = $name

  exec { "get config $disk":
    cwd     => "/home/$user/bootstrap",
    user    => $user,
    command => "/usr/bin/sudo /usr/local/bin/ceph-deploy config push $::hostname",
    require => [ Exec['install ceph'], File["/etc/sudoers.d/$user"] ],
    unless  => "/usr/bin/test -e /etc/ceph/ceph.conf",
  }

  if $::hostname == $ceph_primary_mon {
    $doisudo = "/usr/bin/sudo /usr/local/bin/ceph-deploy gatherkeys $ceph_primary_mon"
  } else {
    $doisudo = "/usr/local/bin/ceph-deploy gatherkeys $ceph_primary_mon"
  }

  exec { "gatherkeys_$disk":
    command => $doisudo,
    user    => $user,
    cwd     => "/home/$user/bootstrap",
    require => [ Exec['install ceph'], File["/etc/sudoers.d/$user"], Exec["get config $disk"] ],
    unless  => '/usr/bin/test -e /home/$user/bootstrap/$cluster.bootstrap-osd.keyring',
  }

  exec {"copy admin key $disk":
    command => "/bin/cp /home/$user/bootstrap/ceph.client.admin.keyring /etc/ceph",
    unless  => '/usr/bin/test -e /etc/ceph/ceph.client.admin.keyring',
    require => Exec["gatherkeys_$disk"],
  }

  exec { "zap $disk":
    cwd     => "/home/$user/bootstrap",
    command => "/usr/local/bin/ceph-deploy disk zap $::hostname:$disk",
    require => [ Exec['install ceph'], Exec["gatherkeys_$disk"] ],
    unless  => "/usr/bin/test -e /home/$user/zapped/$disk",
  }

  exec { "create osd $disk":
    cwd     => "/home/$user/bootstrap",
    command => "/usr/local/bin/ceph-deploy --overwrite-conf osd create $::hostname:$disk",
    unless  => "/usr/bin/test -e /home/$user/zapped/$disk",
    require => Exec["zap $disk"],
  }
  
  file { "/home/$user/zapped/$disk":
    ensure  => present,
    require => [ Exec["zap $disk"], Exec["create osd $disk"], File["/home/$user/zapped"] ],
  }

  exec {"iptables osd $disk":
    command => "/sbin/iptables -A INPUT -i $cluster_interface  -m multiport -p tcp -s $cluster_network --dports 6800:6810 -j ACCEPT",
    unless  => '/sbin/iptables -L | grep "multiport dports 6800:6810"',
  }

  if $setup_pools {

    exec { "create glance images pool $disk":
      command => "/usr/bin/ceph osd pool create $glance_pool 128",
#      unless => "/usr/bin/rados lspools | grep -sq $glance_pool",
      unless => "/usr/bin/rados lspools  | /bin/egrep ^$glance_pool$",
      require => Exec["create osd $disk"],
    }

    exec { "create cinder volumes pool $disk":
      command => "/usr/bin/ceph osd pool create $cinder_pool 128",
#      unless => "/usr/bin/rados lspools | grep -sq $cinder_pool",
      unless => "/usr/bin/rados lspools | /bin/egrep ^$cinder_pool$",
      require => Exec["create osd $disk"],
      notify => [ Service['cinder-volume'], Service['nova-compute'] ],
    }

  }


}
