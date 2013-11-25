class cephdeploy::mon(
  $user             = hiera('ceph_deploy_user'),
  $public_interface = hiera('ceph_public_interface'),
  $public_network   = hiera('ceph_public_network'),
){

  include cephdeploy

  exec { 'create mon':
    cwd      => "/home/$user/bootstrap",
    command  => "/usr/bin/sudo /usr/local/bin/ceph-deploy mon create $::hostname",
    unless   => "/usr/bin/ceph --cluster=ceph --admin-daemon /var/run/ceph/`hostname -s`-mon.ceph.asok mon_status",
    require  => Exec['install ceph'],
    provider => posix,
    user     => $user,
  }

  exec {'iptables mon':
    command => "/usr/bin/sudo /sbin/iptables -A INPUT -i $public_interface -p tcp -s $public_network --dport 6789 -j ACCEPT",
    unless  => '/usr/bin/sudo /sbin/iptables -L | grep "tcp dpt:6789"',
  }


}
