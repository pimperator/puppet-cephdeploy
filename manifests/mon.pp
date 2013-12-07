class cephdeploy::mon(
  $cluster = 'ceph',
  $ceph_primary_mon = hiera('ceph_primary_mon'),
  $user             = hiera('ceph_deploy_user'),
  $public_interface = hiera('ceph_public_interface'),
  $public_network   = hiera('ceph_public_network'),
){

#  include cephdeploy

  exec { 'create mon':
    cwd      => "/home/$user/bootstrap",
    command  => "/usr/bin/sudo /usr/local/bin/ceph-deploy mon create $::hostname",
    unless   => "/usr/bin/sudo /usr/bin/ceph --cluster=ceph --admin-daemon /var/run/ceph/`hostname -s`-mon.ceph.asok mon_status",
    require  => Exec['install ceph'],
    user     => $user,
  }

  if $ceph_primary_mon == $::hostname {
    exec { 'copy keys':
      path    => '/bin:/usr/bin',
      command => "cp /var/lib/ceph/bootstrap-mds/$cluster.keyring /home/$user/bootstrap/$cluster.bootstrap-mds.keyring &&
                  cp /var/lib/ceph/bootstrap-osd/$cluster.keyring /home/$user/bootstrap/$cluster.bootstrap-osd.keyring &&
                  cp /etc/ceph/ceph.client.admin.keyring /home/$user/bootstrap/ceph.client.admin.keyring &&
                  cp /var/lib/ceph/mon/ceph-$ceph_primary_mon/keyring /home/$user/bootstrap/ceph.mon.keyring &&
                  chown $user:$user /home/$user/bootstrap/* &&
                  chmod 644 /home/$user/bootstrap/*
                  ",
      require => Exec['create mon'],
      unless  => "/usr/bin/test -e /home/$user/bootstrap/$cluster.bootstrap-osd.keyring",
    }
  }

  exec {'iptables mon':
    command => "/usr/bin/sudo /sbin/iptables -A INPUT -i $public_interface -p tcp -s $public_network --dport 6789 -j ACCEPT",
    unless  => '/usr/bin/sudo /sbin/iptables -L | grep "tcp dpt:6789"',
  }


}
