#
# Puppet manifest for Centrify Express
#

class centrifydc(
  $domain = "vagrantup.com",
  $user_ignore = [],
  $users_allow = [],
  $groups_allow = [] ,
) {

	$centrifydc_package_name = $operatingsystem ? {
        redhat  => "CentrifyDC",
        centos  => "CentrifyDC",
        default => "centrifydc"
    }


	# Install the latest Centrify Express client and join domain
	case $operatingsystem {
		centos, redhat: {
		    include site-packages
			package { $centrifydc_package_name:
				ensure => installed,
				provider => rpm, 
				source => "/var/cache/site-packages/centrifydc/centrifydc-5.0.2-rhel3-x86_64.rpm",
				notify => Exec["adjoin"],
				require => File['/var/cache/site-packages/centrifydc/centrifydc-5.0.2-rhel3-x86_64.rpm']
			}  
                        package { "CentrifyDC-openssh":
				ensure => absent,
                        }
                        package { "CentrifyDA":
				ensure => absent,
                        }
		}
		default: {
			package { $centrifydc_package_name:
				ensure => latest ,
				notify => Exec["adjoin"]
			}
		}
	}

	# This is only executed once when the package is installed.
	# It requires "adjoin -w -P -n [new machine name] -u [administrator account] domain" from the
	# puppetmaster to pre-create the machine's account. Do this at the same time you sign
	# the puppet certificate.
	#
    exec { "adjoin" :
        path => "/usr/bin:/usr/sbin:/bin",
        command => "adjoin -w -S ${domain}",
        onlyif => 'adinfo | grep "Not joined to any domain"',
        logoutput => true,
        notify => Exec["addns"]
    }
    
    # Update Active Directory DNS servers with host name
    exec { "addns" :
        path => "/usr/bin:/usr/sbin:/bin",
        command => "addns -U -m",
        onlyif => 'adinfo | grep "Not joined to any domain"',
        logoutput => true,
        require => Exec['adjoin'],
    }
    
    # Give the servers configuration that restricts logins to specific users and groups
    file { "/etc/centrifydc/centrifydc.conf":
      owner  => root,
      group  => root,
      mode   => 644,
      content  => template("centrifydc/centrifydc.conf.erb"),
      replace => false,
      require => Package[$centrifydc_package_name]
    }
  
    # Additional users read from $users_allow array variable
    file { "/etc/centrifydc/users.allow":
      owner  => root,
      group  => root,
      mode   => 644,
      content => template("centrifydc/users.allow.erb"),
      require => Package[$centrifydc_package_name]
    } 
    
    # Additional groups read from $groups_allow array variable
    file { "/etc/centrifydc/groups.allow":
      owner  => root,
      group  => root,
      mode   => 644,
      content => template("centrifydc/groups.allow.erb"),
      require => Package[$centrifydc_package_name]
    } 

    # Additional users to ignore read from $user_ignore array variable
    file { "/etc/centrifydc/user.ignore":
      owner  => root,
      group  => root,
      mode   => 644,
      content => template("centrifydc/user.ignore.erb"),
      require => Package[$centrifydc_package_name]
    } 
        
	# Make sure service is running and is restarted if configuration files are updated
  service { centrifydc:
        ensure  => running,
        hasstatus => false,
        pattern => 'adclient',
        require => [
          Package[$centrifydc_package_name],
          File["/etc/centrifydc/centrifydc.conf"],
          File["/etc/centrifydc/user.ignore"],
          File["/etc/centrifydc/users.allow"],
          File["/etc/centrifydc/groups.allow"],
        ],
        subscribe => [ 
          Package[$centrifydc_package_name],
          File["/etc/centrifydc/centrifydc.conf"], 
          File["/etc/centrifydc/user.ignore"],
          File["/etc/centrifydc/users.allow"],
          File["/etc/centrifydc/groups.allow"],
        ],
	}
}
