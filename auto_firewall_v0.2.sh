#!/bin/sh

#author Tyler K Monroe aka tman904
#date Monday October 23rd of 2017 at 23:28


#this program autoconfigures freebsd to operate as a firewall with dhcp and nat with minimal user input.

###########################################(Init function)#######################################

freebsd_fw_init() {

    echo "please type one of the following"
	echo "install"
	echo "" 
	echo "remove"
    	
    read mode

	if [ "$mode" == "install" ] ; then

		#run install
		freebsd_fw_install
		
	

	elif [ "$mode" == "remove" ] ; then

		#run remove
		freebsd_fw_remove 

	    else
		echo "Please type one of the following"
		echo ""
		echo "install"
		echo ""
		echo "remove"
		
    fi

} 
#############################################################################


#########################(Install function START)###################################
freebsd_fw_install() {

############################################################################
###############################(Make sure we are on FreeBSD)##################

sys=`uname -a |awk '{print $1}'`

	if [ "$sys" == "FreeBSD" ] ; then

		echo "current system is $sys"

	else

		echo "running on unknown system bailing out!!!!!!"
		exit 0

	fi
###################################################################################
###################################################################################

###################################################################################
#################################(Make sure we are root)#############################

us=`env |grep -i user= |cut -d '=' -f2`

	if [ "$us" == "root" ] ; then
		echo ""

	else
	
	echo "please run this program as root user"
	echo "$us does not have permissions to configure this system"
	echo "login as root then run this program"
    exit 0

	fi
####################################################################################
####################################################################################


####################################################################################
#################################(Make sure we haven't already been installed)######

	if [ ! -d "/usr/local/etc/auto_firewall/" ] ; then	
		echo ""
	
	else
		echo "Please remove auto firewall first before using this function. exiting!!!"
		exit 0
	fi	

####################################################################################
####################################################################################


####################################################################################
###################################(Clean up the system a bit)#########################

	killall -9 dhclient
	killall -9 dhcpd
	rm /var/run/dhclient*
	rm /var/db/dhclient*
	pfctl -F all
	pfctl -d
	/etc/rc.d/netif stop
#####################################################################################
#####################################################################################
 
#####################################################################################
################################(Get the lan and wan interfaces from the user)########


	echo "please choose at least two interfaces to use for lan and wan"
	echo "############################################################"
	ifconfig
	echo "############################################################"
	echo "please choose lan interface"
	read lanif
	echo "please choose wan interface"
	read wanif
	echo "############################################################"
	echo "thank you"
	sleep 3
######################################################################################
######################################################################################


######################################################################################
######################(Lease an ip, Bootstrap pkg and backup existing config files)###
	
    #try to get an ip address using dhcp on wan interface 
	dhclient $wanif
	
	export ASSUME_ALWAYS_YES=yes	
	pkg update
	
    #backup current configs
	sleep 2
	mkdir /usr/local/etc/auto_firewall/
	#check if backup directory exists
	if [ -d "/usr/local/etc/auto_firewall/" ] ; then	
	cp /etc/rc.conf /usr/local/etc/auto_firewall/rc.conf.bak
	
	else
		echo "backup directory does not exist bailing out!!!!"
		exit 0
	fi
######################################################################################
######################################################################################

	
######################################################################################
###############################(Create /etc/rc.conf)##################################

    #Create a locally unique hostname to make managing multiple systems easier.
    afwid=`ifconfig |grep -i hwaddr |awk '{ print $2 }'  |md5 |cut -c-13`
	#setup selected interfaces and set ip routing, pf and dhcpd to start on boot.
    #log when we created this file
    rcconfdate=`date +%a_%m_%d_%Y_@%H_%M_%S`

    echo "#Created by tman904's auto_firewall_v0.2.sh program id is $afwid." >/etc/rc.conf
    echo "#Installed on $rcconfdate" >>/etc/rc.conf
    echo "" >>/etc/rc.conf	
    echo "hostname=\"autofirewall$afwid\"" >> /etc/rc.conf
	echo "sshd_enable=\"NO\"" >>/etc/rc.conf	
	echo "ifconfig_$lanif=\"inet 192.168.1.1 netmask 255.255.255.0\"" >>/etc/rc.conf
	echo "ifconfig_$wanif=\"DHCP\"" >>/etc/rc.conf
	echo "gateway_enable=\"YES\"">>/etc/rc.conf
	echo "pf_enable=\"YES\"" >>/etc/rc.conf
	echo "pf_rules=\"/etc/pf.conf\"" >>/etc/rc.conf
	echo "dhcpd_enable=\"YES\"">>/etc/rc.conf
	echo "ntpdate_enable=\"YES\"" >>/etc/rc.conf
	echo "ntpdate_flags=\"north-america.ntp.pool.org\"" >>/etc/rc.conf
	echo "sendmail_enable=\"NO\"" >>/etc/rc.conf
	echo "sendmail_submit_enable=\"NO\"" >>/etc/rc.conf
	echo "sendmail_msp_queue_enable=\"NO\"" >>/etc/rc.conf
	echo "sendmail_outbound_enable=\"NO\"" >>/etc/rc.conf
        echo "syslogd_flags=\"-ss\"" >>/etc/rc.conf
    ###############################################################################
    ###############################################################################
	
	
	###############################################################################
    ################################(Create /etc/pf.conf)############################
    #make pf.conf with sensible defaults
    #log when we created this file
    pfdate=`date +%a_%m_%d_%Y_@%H_%M_%S`

    echo "#Created by tman904's auto_firewall_v0.2.sh. program id is $afwid." >/etc/pf.conf
    echo "#Installed on $pfdate" >>/etc/pf.conf
    echo "" >>/etc/pf.conf
	echo "ext=\"$wanif\"" >>/etc/pf.conf
	echo "int=\"$lanif\"" >>/etc/pf.conf
	echo "" >>/etc/pf.conf
	echo "set skip on lo" >>/etc/pf.conf
    echo "" >>/etc/pf.conf
	echo "set block-policy drop" >>/etc/pf.conf
	echo "" >>/etc/pf.conf
	echo "nat on \$ext from \$int:network to any -> (\$ext)" >>/etc/pf.conf
	echo "" >>/etc/pf.conf
    echo "block drop all" >>/etc/pf.conf    
    echo "" >>/etc/pf.conf    
    echo "pass in on \$int from \$int:network to any keep state"  >>/etc/pf.conf  	
    echo "" >>/etc/pf.conf
    echo "pass out on \$ext from \$int:network to any keep state" >>/etc/pf.conf
    echo "" >>/etc/pf.conf
    echo "pass out on \$ext from \$ext:network to any keep state" >>/etc/pf.conf
	##############################################################################
    ##############################################################################
	

    ##############################################################################
    ##################################(Install dhcpd package)#######################	
	
    ipkg=`pkg search isc-dhcp |grep server |awk '{print $1}'`
	pkg install -y $ipkg
    ##############################################################################
    ##############################################################################

    ##############################################################################
    ##########################(Create /usr/local/etc/dhcpd.conf)####################	
    
    #log when we created this file
    dhcpddate=`date +%a_%m_%d_%Y_@%H_%M_%S`

    echo "#Created by tman904's auto_firewall_v0.2.sh. program id is $afwid." >/usr/local/etc/dhcpd.conf
    echo "#Installed on $dhcpddate" >>/usr/local/etc/dhcpd.conf
    echo "" >>/usr/local/etc/dhcpd.conf
	echo "" >> /usr/local/etc/dhcpd.conf
	echo "option domain-name \"home\";" >>/usr/local/etc/dhcpd.conf
	echo "" >>/usr/local/etc/dhcpd.conf
	echo "option domain-name-servers 4.2.2.1, 4.2.2.2;" >>/usr/local/etc/dhcpd.conf
	echo "" >>/usr/local/etc/dhcpd.conf
	echo "subnet 192.168.1.0 netmask 255.255.255.0 {" >> /usr/local/etc/dhcpd.conf
	echo "" >>/usr/local/etc/dhcpd.conf
	echo "range 192.168.1.2 192.168.1.254;" >>/usr/local/etc/dhcpd.conf
	echo "" >>/usr/local/etc/dhcpd.conf
	echo "option routers 192.168.1.1;" >>/usr/local/etc/dhcpd.conf
	echo "" >>/usr/local/etc/dhcpd.conf
	echo "}" >>/usr/local/etc/dhcpd.conf
	############################################################################
    ############################################################################

	echo "config backups saved to /usr/local/etc/auto_firewall/"
	echo ""
	echo "use auto_firewall_v0.2.sh with the remove option to restore them"
    echo "######################################################################"
    echo ""
    echo "Thank you for using tman904's auto_firewall_v0.2.sh"
    echo ""
    echo "######################################################################"

	echo "setup complete enjoy"
	echo "rebooting"
	
	
    ############################################################################
    ##############################(Leave some footprints)#########################	
    instda=`date +%a_%m_%d_%Y_@%H_%M_%S`
	echo "installed on $instda by tman904's autofirewall_v0.2.sh program id $afwid" >/usr/local/etc/auto_firewall/autofw.conf
	echo "" >>/usr/local/etc/auto_firewall/autofw.conf
	echo "interfaces" >> /usr/local/etc/auto_firewall/autofw.conf
	echo "$lanif LAN" >>/usr/local/etc/auto_firewall/autofw.conf
	echo "$wanif WAN" >>/usr/local/etc/auto_firewall/autofw.conf
    
    #secure auto_firewall directory from being deleted	
    chflags -R schg /usr/local/etc/auto_firewall/
	#############################################################################
    #############################################################################

    #############################################################################    
    ##################################reboot#####################################
	sleep 4
	reboot
	#############################################################################
    #############################################################################

}
####################################(Install function END)#############################################
#################################################################################


#################################################################################
##################################(Remove function START)##############################
freebsd_fw_remove() {

	#check if we are root
	us=`env |grep -i user= |cut -d '=' -f2`

	if [ "$us" == "root" ] ; then
		echo ""

	else
	
	echo "please run this program as root user"
	echo "$us does not have permissions to configure this system"
    echo "login as root then run this program"
	
	exit 0

	fi


	#check if auto firewall is installed if not exit
	if [ -d "/usr/local/etc/auto_firewall/" ] ; then	
		echo ""
	
	else
		echo "Please install auto firewall first before using this function. exiting!!!"
		exit 0
	fi	

	#remove all configurations of this program
	killall -9 dhclient
	killall -9 dhcpd
	rm /var/run/dhclient*
	rm /var/db/dhclient*
	pfctl -F all
	pfctl -d
	kldunload pf	
	sysctl net.inet.ip.forwarding=0	
	/etc/rc.d/netif stop
	rpkg=`pkg info |grep isc-dhcp |awk '{print $1}'`
	pkg remove -y $rpkg
	pw userdel dhcpd
    rm /usr/local/etc/dhcpd.conf
    rm /etc/pf.conf
	
	#restore original configs
	chflags -R noschg /usr/local/etc/auto_firewall/
	cp /usr/local/etc/auto_firewall/rc.conf.bak /etc/rc.conf
	sleep 2

	if [ -f "/etc/rc.conf" ] ; then

	echo "all configs successfully restored."
	echo "######################################################################"
    echo ""
    echo "Thank you for using tman904's auto_firewall_v0.2.sh"
    echo ""
    echo "######################################################################"
    echo "rebooting to factory default state in 10 seconds."
	rm -rf /usr/local/etc/auto_firewall	
	sleep 10
	reboot
	
	else

	echo "something went wrong with the restore."
	exit 0
	
	fi
 
}
######################################################################################################
######################################(Remove function END)###########################################


	#run freebsd setup routine
	freebsd_fw_init
