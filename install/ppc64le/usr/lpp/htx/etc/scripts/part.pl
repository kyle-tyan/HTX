#!/usr/bin/perl

# @(#)47        1.10.4.34     src/htx/usr/lpp/htx/etc/scripts/part.pl, htxconf, htxubuntu 1/4/16 02:46:33

use Fcntl;
use File::Basename;
require "/usr/lpp/htx/etc/scripts/ioctl.ph"; 

# Definition of constants as subroutines 

# sub MEDIA_DVD_LASTLBA   { 0x3fa0df; }
# sub MAX_BLKNO  		{ 269250; }

sub CD_LASTLBA  	{ 269250; }
sub DVD_ROM_LASTLBA  	{ 4169951; }

# Set debug flag to 1 for debug info
# Initialise 'rawcnt' variable from 1 as we do not bind any device to raw node 0,
# being it a special node, containing some control information.

$debug=0;
$cnt=0;
$rawcnt=1;
$cd_dvd_cnt=0;
$fdcnt=0;

# Used when GNU parted command is used to collect disk information
%disk_info=""; 
$num_disk=-1;
# Making 'KERNEL_26' variable 'true' always for 2.6 and higher kernels as 2.4 is no more being used now.
# $KERNEL_26="";
# $KERNEL_26=`uname -r | grep "2\.6\."`;

$KERNEL_26="true";

#Check for BML 
$is_bml=0; 
$is_ubuntu=0;
$version_file='/usr/lpp/htx/etc/version'; 
if(-e $version_file) { 
	$htx_release=`cat /usr/lpp/htx/etc/version 2>/dev/null` ;  
	chomp($htx_release); 
	if($htx_release =~ /htxltsbml/) { 
		$Is_bml=1; 
		print (" BML detected release =$htx_release \n") if($debug); 
	} elsif($htx_release =~ /htxubuntu/){  
		$is_ubuntu=1; 
		print (" Debain Ubuntu release = $htx_release \n") if($debug);
	} else { 
		$is_ubuntu=0; 
		$is_bml=0; 
	} 
} 


# /proc/partition acts an input for all the block devices
# configured on this system, open it once and read in..
# mpath logic for detecting is different..
@proc_partition="";
$file_name="/proc/partitions";
unless (open (IN_FILE,"$file_name")) {
    die ("Can't open $file_name file!\n");
}
@block_device_info= <IN_FILE>;
foreach $line (@block_device_info) {
    chomp($line);
    if($line =~ /name/i || $line =~ /^/s*$/) {
        # Skip Header and blank line
        next;
    }
    ($junk, $major, $minor, $num_blocks, $block_dev) = split(/\s+/,$line);
    chomp($block_dev);
    push(@proc_partition, $block_dev);
}
close(IN_FILE);
printf("Block device configured on system- @proc_partition\n") if($debug);

$found_cd_dvd=0;

if($is_bml){
	print "\nRunning BML Version of \'part\' script\n\n" if($debug);
} elsif($is_ubuntu) { 
	print "\nRunning Debian Ubuntu Version of \'part\' script\n\n" if($debug);
} else { 
	print "\nRunning Distro Version of \'part\' script\n\n" if($debug);
}

unless (open (RAW_PART,">/tmp/rawpart")) {
	die "Open failed for file /tmp/rawpart";
}

unless (open (RAW_LINKS,">/tmp/rawlinks")) {
	die "Open failed for file /tmp/rawlinks";
}

# The links to the raw nodes will be put in /tmp/rawpart    
# The corresponding rm -f commands for each of these links  
# will be kept in a script in /tmp/rawlinks. This script    
# will be called from htx.cleanup.                          

print RAW_LINKS "#!/bin/sh\n";

if( !$KERNEL_26 ){
	&create_raw_nodes();
}

&get_CD_DVD_info();
&get_FD_info();
&get_parts_to_exclude();

if($debug) {
	print "Collecting Hard Disk info\n";
}

print("proc_partition=@proc_partition\n") if($debug);

foreach $part (@proc_partition){
	
	chomp($part);
	if(!$part) {
	    next;
	}
	if($debug) {
	    print "checking $part\n";
	}
	$partition=0;
	$used=0;
	$file_system=0;
	
# Exclude already used partitions

	for($i=0;$i<$cnt;$i++) 
	{
		if($part eq $parts_to_exclude[$i])
		{
			if($debug) {
				print "$part - Found in exclude list\n";
			}
			$used=1;
			last;
		}
	}
	if($used==1){
		next;
	}
	
# Now check if the partition contain partitions , if it contains then leave it 
# and process it's partitions, else process itself for checking it to be usable 
# for hxestorage.

	@match_parts="";
        @match_parts=&get_parts($part) ;
        $partition=@match_parts;
        
        if($partition > 1) {
            print("$part has partitions=$partition, skipping disk .. \n") if($debug);
            next;
        }
        
#        if($part !~ /\d\b/){
#		@match_parts=`cat /proc/partitions | awk '{print \$4}' | grep $part `;
#		foreach $name (@match_parts)
#		{
#			chomp($name);
#			if($name eq $part) {
#				next;
#			}
#			$diff=$name;
#			$diff =~ s/$part//;
#			if($diff !~ /\D/ && $diff =~ /\d/) {
#				$partition=1;
#				if($debug) {
#					print "$part - Contain Partitions\n";
#				}
#				last;
#			}
#		}
#	}
#	
#	if($partition==1){
#		next;
#	}

# Now check wheteher partition contains filesystem upon it or not . 
# If it contais file system then we will not use it for hxestorage. 

	$file_system=&check_filesystem($part);
	if($file_system == 1) {
		next; 
	}
	if($debug) {
		print "**** Disk = $part --> USABLE for hxestorage ****\n";
	}
	&make_entry(*RAW_PART,$part, "raw");
}
if($debug) {
	print "Done\n\n";
}
close(RAW_PART);
# To enable multipath testing this file should be created 
`rm -f /tmp/mpath_parts 2 >/dev/null`; 
&get_multipath_info(); 

if($is_ubuntu) { 
	# sdXX detected could be CAPI Flash, give preference to hxesurelock. 
	`rm f /tmp/cflash_parts 2>/dev/null`;
	&get_cflash_info();
}
&get_TD_info();

close(RAW_LINKS);

exit(0);

######################################################################
# All the sub routines start here
######################################################################

#######################################################################
# Collects CD & DVD info 
#######################################################################

sub get_CD_DVD_info 
{
	if($debug) {
		print "Collecting SCSI CD, DVD info\n";
	}

	unless(open(CD_PART,">/tmp/cdpart")) {
		die("Open failed for file /tmp/cdpart\n");
	}
	
	unless(open(DVDR_PART,">/tmp/dvdrpart")) {
		die("Open failed for file /tmp/dvdrpart\n");
	}

	unless(open(DVDW_PART,">/tmp/dvdwpart")){
		die("Open failed for file /tmp/dvdwpart\n");
	}

	# Look for SCSI CD-ROM's in /proc/sys/dev/cdrom
	# /proc/sys/dev/cdrom/info contains info about both SCCI and IDE CD/DVD drives
	# but we will gather info for SCSI CD/DVD's only from there 
	
	@cd_dvd_drives=`cat /proc/sys/dev/cdrom/info 2>/dev/null | awk '/drive name:/ { for(i=3;i<=NF;i++) print \$i}'`;
	foreach $drive (@cd_dvd_drives) 
	{
		chomp($drive);
		if($debug){
			print "checking $drive\n";
		}
		if($drive =~ /^sr/) 
		{
		
			$ret=`file -s /dev/$drive | grep filesystem | wc -l`;
			if($ret == 1) {
				if ($debug) {
					print "$drive contain a filesystem. So, excluding it\n";
				}
				$cd_dvd[$cd_dvd_cnt++]=$drive;
				$found_cd_dvd=1;
				next;
			}
			
			$ret=system("/usr/lpp/htx/bin/getDVD /dev/$drive 2>&1");
			
			$ret=$ret>>8;

			if($debug) {
				print "getDVD returned $ret for $drive\n";
			}
		
			# CDROM Media	
			
			if($ret==8) { 
				if($debug) {
					print "$drive is SCSI CDROM\n";
				}
				$cd_dvd[$cd_dvd_cnt++]=$drive;	
 				&make_entry(*CD_PART,$drive, "raw"); 
				$found_cd_dvd=1;
			}
	
			# DVDROM Media
			
			if($ret==10) { 
				if($debug) {
					print "$drive is SCSI DVDROM\n";
				}
				$cd_dvd[$cd_dvd_cnt++]=$drive;	
				&make_entry(*DVDR_PART,$drive, "raw");
				$found_cd_dvd=1;
			}

			# DVDRAM Media
			
			if($ret==12) { 
				if($debug) {
					print "$drive is SCSI DVDRAM\n";
				}
				$cd_dvd[$cd_dvd_cnt++]=$drive;	
				&make_entry(*DVDW_PART,$drive, "raw");
				$found_cd_dvd=1;
			}
		} 
	}        
	
	if($found_cd_dvd==0) {
	@cd_dvd_drives=`ls /dev/scd* 2>/dev/null | awk '{print $1}' | cut -c '6-9'`;
	foreach $drive (@cd_dvd_drives)
	{
		chomp($drive);
		if($debug){
                        print "checking $drive\n";
                }

		$ret=system("/usr/lpp/htx/bin/getDVD /dev/$drive 2>&1");

		$ret=$ret>>8;
		
		if($debug) {
                                print "getDVD returned $ret for $drive\n";
                        }

                        # CDROM Media

                        if($ret==8) {
                                if($debug) {
                                        print "$drive is SCSI CDROM\n";
                                }
                                $cd_dvd[$cd_dvd_cnt++]=$drive;
                                &make_entry(*CD_PART,$drive, "raw");
                        }

                        # DVDROM Media

                        if($ret==10) {
                                if($debug) {
                                        print "$drive is SCSI DVDROM\n";
                                }
                                $cd_dvd[$cd_dvd_cnt++]=$drive;
                                &make_entry(*DVDR_PART,$drive, "raw");
                        }

                        # DVDRAM Media

                        if($ret==12) {
                                if($debug) {
                                        print "$drive is SCSI DVDRAM\n";
                                }
                                $cd_dvd[$cd_dvd_cnt++]=$drive;
                                &make_entry(*DVDW_PART,$drive, "raw");
                        }
           }
	  }
		


	if($debug) {
		print "Done\n\n";
	}

	# Look for IDE CD-ROM's into /proc/ide .

	# Earlier part used to look first into /proc/sys/dev/cdrom/info for ide cd/dvd's also
	# and after that it used to look into /proc/ide. Then it used to exclude those already
	# found into /proc/sys/dev/cdrom/info . But it seems better to look only into /proc/ide,
	# which is a superset, and all info should be here for ide cd/dvd's. 


	if($debug) {
		print "Collecting IDE CD, DVD info\n";
	}
	@ide_devices=`ls -l /proc/ide 2> /dev/null | grep hd | awk '{print \$9}'`;
	foreach $device (@ide_devices)
	{
		chomp($device);
		if($debug) { 
			print "checking $device\n";
		}
	# Now check media
		
		$media=`cat /proc/ide/$device/media 2>/dev/null`;
		chomp($media);
		if($debug) {
			print "media type shown is $media for $device\n";
		}
		if($media eq "cdrom")
		{
	
	# We will use the capacity of the media to differentiate between DVD-ROM 
        # and CD-ROM. For DVD-RAM, the device names will always be like
        # srn or scdn, becoz of scsi layer emulation. We are not responsible for not
        # enabling the scsi layer emulation. Hence, if the scsi layer emulation has not
        # been enabled, and the media present in the drive is DVD-RAM media, we will still
        # create the stanza as DVD-ROM only and this will generate miscompares for hxecd.
		
	# But before determining device type first check driver type , because if driver is 
	# ide-scsi then this device will already will be shown in SCSI devices
	# This is a bad design in Linux, as to add writing support tp IDE CD/DVD Linux 
	# uses SCSI emulation layer, as IDE subsystem does not have capability to burn CD/DVD.
	# The bad thing is that in this case Linux shows the drive as SCSI and IDE both, but 
	# physically there is only one drive. So we have to eliminate IDE drive.

			
			$IDE_SCSI_DRIVER=`cat /proc/ide/$device/driver | grep ide-scsi`;
			
			if($IDE_SCSI_DRIVER) {
				if($debug) {
					print "$device is being used by ide-scsi driver as SCSI drive\n";
				}
				$cd_dvd[$cd_dvd_cnt++]=$device;
				next;
			}
			
			unless(sysopen (DEV_FILE, "/dev/$device",O_RDONLY | O_NONBLOCK))
			{
				print ("sysopen call failed for /dev/$device\n");
				next;
			}
                   
		     #	$no_blks=chr(0)x4;
			$no_blks=chr(0) x length(pack("L!"));
			unless(ioctl (DEV_FILE,&BLKGETSIZE,$no_blks))
			{
				print ("ioctl BLKGETSIZE failed for /dev/$device\n");
				next;
			}
	             #  $no_blks=unpack("L",$no_blks);
			$no_blks=unpack("L!",$no_blks);
			
	             #	$sect_size=chr(0)x4;
	             	$sect_size=chr(0) x length(pack("L!"));
			unless(ioctl(DEV_FILE,&BLKSSZGET,$sect_size))
			{
				print ("ioctl BLKSSZGET failed for /dev/$device\n");
				next;
			}
		     #  $sect_size=unpack("L",$sect_size);
			$sect_size=unpack("L!",$sect_size);
			
			if($debug){
				print "no_blks = $no_blks\n";
				print "sect_size = $sect_size\n";
			}

			if($sect_size == 2048){
                    		$no_blks = $no_blks / 4;
			}
		
		     #  $lastlba = $no_blks - 1;
			$lastlba=$no_blks;
                
                	if( $lastlba >= &DVD_ROM_LASTLBA )
                	{
				if($debug) {
					print "$device is IDE DVDROM\n";
				}
				$cd_dvd[$cd_dvd_cnt++]=$device;	
                    		&make_entry(*DVDR_PART,$device, "raw");
		
			} elsif ( $lastlba <= &CD_LASTLBA  )
               		{
				if($debug) {
					print "$device is IDE CDROM\n";
				}
				$cd_dvd[$cd_dvd_cnt++]=$device;	
		   		&make_entry(*CD_PART,$device, "raw");
			} else 
			{
				if($debug) {
					print "$device is IDE DVDRAM\n";
				}
				$cd_dvd[$cd_dvd_cnt++]=$device;	
		   		&make_entry(*DVDW_PART,$device, "raw");
			} 
		}

	}
	if($debug) {
		print "Done\n\n";
	}
	
	close(CD_PART);
	close(DVDR_PART);
	close(DVDW_PART);
}

#######################################################################
# Collects Floppy information
#######################################################################

sub get_FD_info  
{
	if($debug) {
		print "Collecting Floppy info\n";
	}
	unless (open (FD_PART,">/tmp/fdpart")) {
		die ("Open failed for file /tmp/fdpart\n");
	}
	
	@floppies=`cat /proc/devices | awk '{print \$2}' | grep ^fd` ;
	foreach $device (@floppies)
	{
		chomp($device);	
		if ($device eq "fd")
		{
			if($debug) {
				print "Found Floppy $device in /proc/devices\n"; 
			}
			$device= "$device" . "0";
			&make_entry(*FD_PART,$device, "raw");
			$floppy[$fdcnt++]=$device;
			last;
		}
	}
 
 # Came out of loop as soon as found one floppy as not sure how multiple floppies
 # will look like in /proc/devices and before that whether it is possible or not
 # from hardware point of view to put more than 1 floppy in system.
 
 # Now Look for any FD which might be present in /proc/partitions

	@proc_parts=`cat /proc/partitions | awk '(NR >2){print \$4}'`;
	foreach $part (@proc_parts)
	{
		chomp($part);
		if($debug) {
			print "checking $part \n";
		}
		$found=0;
		$found=&check_floppy($part);
		if($found==1){
			if($debug){
				print "Found Floppy $part in /proc/partitions $part\n"; 
			}
			&make_entry(*FD_PART,$part, "raw");
			$floppy[$fdcnt++]=$part;
			@floppy_parts=&get_parts($part); 
			foreach $var (@floppy_parts)
			{
				chomp($var);
				if($debug) {
					print "$var is partition of floppy $part\n";
				}
				$floppy[$fdcnt++]=$var;
			}
		} else { 
			next;
		}
	}
	if($debug) {
		print "Collecting Floppy info .. Done... \n\n"; 
	}
	close(FD_PART);
} 

##################################################################################
# checks whether given partition/device is floppy or not by calculating it's size 
##################################################################################

sub check_floppy
{
	($name) = @_;
	if($name !~ /^[hsm]d/) {
		if($debug) {
			print "$name is a logical volume\n";
		}
		return 0;
	}
	if ($name =~ /\d\b/)
	{
	# Partition present hence it may be a Hard Disk
		if($debug) {
			print "$name is a partition\n";
		}
		return 0;
	}
	unless(open (DEV_FILE, "/dev/$name")) {
		print ("Open failed for /dev/$name\n");
		return 0;	
	}
     #	$no_blks=chr(0)x4;
	$no_blks=chr(0) x length(pack("L!"));
	unless(ioctl DEV_FILE,&BLKGETSIZE,$no_blks) {
		print "ioctl BLKGETSIZE failed for /dev/$name\n";
		return 0;
	}
     #  $no_blks=unpack("L",$no_blks);	
	$no_blks=unpack("L!",$no_blks);	
	close(DEV_FILE);
	if($debug) {
		print "no of blocks for $name is $no_blks\n";
	}
	if($no_blks < 0xFA0)
	{
		return 1;
	} else {
		return 0;
	}
}

#################################################################################
# gets the partitions which are used for swap, system, floppy, cd-dvd etc..
#################################################################################

sub get_parts_to_exclude 
{

# Exclude swap partitions
		
	if($debug) {
		print "Collecting partitions_to_exclude info\n";
		print "\nSwap partitions:\n"
	}
	
	@swap_parts=`cat /proc/swaps | awk '{print \$1}' | grep /dev`;
	foreach $part (@swap_parts)
	{
		chomp($part);
		$part =~ s/\/dev\///;
		if($debug){
			print "$part\n";
		}
		$parts_to_exclude[$cnt++]=$part;
	}

# Exclude system partitions

	if($debug) {
		print "\nSystem partitions:\n";
	}
	@sys_parts=`cat /etc/mtab | awk '{print \$1}' | grep /dev`;
	foreach $part (@sys_parts)
	{
		chomp($part);
		$part =~ s/\/dev\///;
		if($debug){
			print "$part\n";
		}
		$parts_to_exclude[$cnt++]=$part;
	}

# Exclude PPC PReP Boot partitions
# Also, excludes Extended partitions. used_as field will be "lba" for extended partitions.

	if($is_bml == 0) { 
		print ("\nPPC PReP Boot Partitions:\n") if($debug);
	# Fdisk is absolete now, it doesn't reads GPT,so better use parted utility. 	
	#		@PPC_PReP_boot_parts=`fdisk -l 2>&1 | awk '/PPC/ { print \$1}'`; 	
	#		foreach $name (@PPC_PReP_boot_parts)
	#		{
	#			chomp($name);
	#			$part=`echo $name | awk -F / '{ print \$3 }'`;
	#			chomp($part);
	#			if($debug) {
	#				print "$part\n";
	#			}
	#			$parts_to_exclude[$cnt++]=$part;
	#		}
		&get_disk_info_parted(); 	
		$num_disks=$num_disk+1; 
		print("num_disks=$num_disks \n") if($debug); 
		for($i=0;$i<$num_disks ;$i++) {
        		#Murali Iyer : In this case nvme0n1 is a base device and "root" is on "nvme0n1p1" and entire "nvme0n1" needs to be avoided to protect load source.
        		# So if exclude any partition of nvme disk, we put whole disk in exclude list.
        		$is_nvme_device = 0;
        		$disable_this_nvme_device = 0;
        		if($disk_info[$i]{name}=~/nvme/) {
        		    $is_nvme_device = 1;
        		}
        		print("Disk $disk_info[$i]{name}, has $disk_info[$i]{num_partitions} partitions\n") if($debug);
        		if($disk_info[$i]{num_partitions} >= 1) {
        		    $dev_name=basename($disk_info[$i]{name});
        		    print("Excluding disk=$dev_name as it has partitions\n") if($debug);
        		    $parts_to_exclude[$cnt++]=$dev_name;
        		}
        		for($j=0;$j<$disk_info[$i]{num_partitions};$j++) {
               		 	print("partition $disk_info[$i]{$j}{partition_name}, fs_type=$disk_info[$i]{$j}{fs_type}, used_as=$disk_info[$i]{$j}{used_as} \n") if($debug);
				# If partition is already used by system we exclude it .. 
					if($disk_info[$i]{$j}{used_as} !~ /RAW/i) { 
						print("Excluding part=$disk_info[$i]{$j}{partition_name} because its used as $disk_info[$i]{$j}{used_as} \n") if($debug); 
						$parts_to_exclude[$cnt++]=$disk_info[$i]{$j}{partition_name}; 
						if($is_nvme_device) {
						    $disable_this_nvme_device = 1;
						}
					} elsif($disk_info[$i]{$j}{fs_type} !~ /NA/i) { 
						#if partition has file system on it we exclude it .. 	
						print("Excluding part=$disk_info[$i]{$j}{partition_name} because it has filesystem, fs_type=$disk_info[$i]{$j}{fs_type} \n") if($debug);
						$parts_to_exclude[$cnt++]=$disk_info[$i]{$j}{partition_name}; 
						if($is_nvme_device) {
						    $disable_this_nvme_device = 1;
						}
					} else { 
						print("#### Detected !!!! Test Candidate Storage Media=$disk_info[$i]{$j}{partition_name} 
										because used_as=$disk_info[$i]{$j}{used_as} and fs_type=$disk_info[$i]{$j}{fs_type} \n") if($debug); 
					}
        		}
        		if($disable_this_nvme_device) {
        		     print("disabling Disk $disk_info[$i]{name} completely \n") if($debug);
        		     for($j=0;$j<$disk_info[$i]{num_partitions};$j++) {
        		         print("Excluding part=$disk_info[$i]{$j}{partition_name} because disable_this_nvme_device=$disable_this_nvme_device \n") if($debug);
        		         $parts_to_exclude[$cnt++]=$disk_info[$i]{$j}{partition_name};
        		     }
        		 }
		}
	}

# Exclude Extended partition with block size 1 
# Linux uses the  partitions of block size 1 to maintain partition table 
# so they should not be exercised.
	
	if($debug){
		print "\nExtended Partitions of block size 1:\n";
	}
	@proc_part_lines=`cat /proc/partitions | awk '(NR>2)'`;
	foreach $line (@proc_part_lines)
	{

		chomp($line);
		$no_blks=`echo $line | awk '{ print \$3 }'`;
		if ( $no_blks != 1 )
		{
			next;
		} else {
			$part=`echo $line | awk '{ print \$4}'`;
			chomp($part);
			if($debug) {
				print "$part\n";
			}
			$parts_to_exclude[$cnt++]=$part;
		}
	}

# Exclude partitions used by Volume Groups

	if($debug){
		print "\nPartitions used by Volume Groups:\n";
	}

	@lv_parts=`pvdisplay 2>/dev/null | awk '/PV Name/ { print \$3 }'`;
	foreach $part (@lv_parts) 
	{
	 	chomp($part);
		$part =~ s/\/dev\///;
		if($part =~ /mapper/) { 
			#boot is on mapper, need to find the physical devices
			#behind this mapper_device. 
			@p_dev=&check_mpath($part); 
			foreach $dev (@p_dev) { 
				chomp($dev); 
				if($debug) {
                	print "$dev\n";
                }
				$parts_to_exclude[$cnt++]=$dev; 
			}
		} else { 
			if($debug) {
				print "$part\n";
			}
			$parts_to_exclude[$cnt++]=$part;
		}
	}

	if($debug){
		print "\nPartitions showing Volume Group, CD-DVD, Floppy, AIX or MAC Disk:\n";
	}

	@proc_parts=`cat /proc/partitions | awk '(NR>2) { print \$4}'`;
	foreach $part (@proc_parts)
	{
		chomp($part);
	
	# Exclude Volume Groups 
	# if you have a new device type which doesn't shows up as search done below, add a condition ... 
		if(($part !~ /^[hsm]d/) && ($part !~ /^rsxx.$/) &&($part !~ /^nvme/)) {
			if($debug) {
				print "$part is a Volume Group\n";
			}
			$parts_to_exclude[$cnt++]=$part;
			next;
		}
		
	
	# Exclude CD DVD drives
		for($i=0;$i<$cd_dvd_cnt;$i++)
		{
			if($cd_dvd[$i] eq $part)
			{
				$parts_to_exclude[$cnt++]=$part;
				if($debug) {
					print "$part is a CD/DVD partition\n";
				}
				last;	
			}
		}
	
	# Exclude Floppy drives
		for($i=0;$i<$fdcnt;$i++)
		{
			if($floppy[$i] eq $part)
			{
				$parts_to_exclude[$cnt++]=$part;
				if($debug) {
					print "$part is a floppy partition\n";
				}
				last;
			}
		}
	
	# Exclude the AIX logical volumes and MAC disks. The logic is
	# that the AIX disk start with 0xC9C2D4C1 or IBMA in ebcdic and
	# the MAC disks have 0x4552 at 0x0. We exclude any disk with the
	# respective string at the respective location

		unless(open(DEV_FILE,"/dev/$part"))
		{
			print "Open failed for file /dev/$part\n";
			next;
		}

		unless(read (DEV_FILE,$disk_id,4))
		{
			print "Read failed for file /dev/$part\n";
			next;
		}
	  	$disk_id=unpack("I",$disk_id);
		if($debug) { 
			print "disk - $part disk_id - $disk_id\n";
		}
		if(($disk_id == 0xc9c2d4c1) || (($disk_id & 0xFFFF0000) == 0x45520000))
		{
			$parts_to_exclude[$cnt++]=$part;
			if($debug){ 
				if($disk_id == 0xc9c2d4c1){
					print "$part is AIX Disk\n";
				}
				if(($disk_id & 0xFFFF0000) == 0x45520000){
					print "$part is MAC Disk\n";
				}
			}
			@parts_of_AIX_MAC_disk=&get_parts($part);
			foreach $var (@parts_of_AIX_MAC_disk)
			{
				chomp($var);	
				$parts_to_exclude[$cnt++]=$var;
				if($debug) {
					print "$var is partition of AIX/MAC disk $part\n";
				}
			}
		}
	}

	# Exclude partitions used by RAID drives 

	if($debug){
		print "\nPartitions used by RAID drives:\n";
        }

    	@raid_drive_parts=`cat /etc/raidtab 2>/dev/null | awk '(\$1=="device") { print \$2 }'`;
    	foreach $part (@raid_drive_parts)
    	{
        	chomp($part);
        	$part =~ s/\/dev\///;
        	$parts_to_exclude[$cnt++]=$part;
        	if($debug){
            		print "$part\n";
        	}
    	}

		@raid_drive_parts=`cat /proc/mdstat 2>/dev/null | awk '(\$3=="active") { print \$5 }'`;
        foreach $part (@raid_drive_parts)
        {
                chomp($part);
                $part =~ s/\[[0-9]*\]//;
                $parts_to_exclude[$cnt++]=$part;
                if($debug){
                        print "$part\n";
                }
        }

        @raid_drive_parts=`cat /proc/mdstat 2>/dev/null | awk '(\$3=="active") { print \$6 }'`;
        foreach $part (@raid_drive_parts)
        {
                chomp($part);
                $part =~ s/\[[0-9]*\]//;
                $parts_to_exclude[$cnt++]=$part;
                if($debug){
                        print "$part\n";
                }
        }

        # Simple sanity Check if we havn't left any disk
        # blkid generally recognizes all disks, so we shouldnot touch those which
        # blkid recognizes
        @recognized=`blkid -s TYPE`;
        foreach $line (@recognized) {
            chomp($line);
            ($device, $type) = split(/:/, $line);
			($waste,$fs_type) = split(/=/,$type);
            print("device=$device of type=$fs_type Detected !! \n") if($debug);
			unless($fs_type) { 
				next; 	
			}	
			if($fs_type) { 
				$dev_name=basename($device); 
				chomp($dev_name); 
				print ("dev_name = $dev_name \n"); 
				$found = 0; 
				for($counter=0; $counter < $cnt; $counter++) {
					if($dev_name =~ /$parts_to_exclude[$counter]/) { 
						print (" We are good, $dev_name already excluded \n") if($debug); 
						$found = 1; 
						last; 
					}	
				}
				if($found == 0) { 
					print (" Err !! $dev_name not in exclude list. Adding it to excludes \n") if($debug);
					$parts_to_exclude[$cnt++]=$dev_name;  
				}

			} 

        }

		#Exclude Mpaths here .. 
	   	#Check if multipath daemon is running.
    	$res=`ps -ef | grep multipathd | grep -v grep | awk ' {print \$2}'`;
    	chomp($res);
    	unless($res) {
       		print("multipathd not running \n");
       		return;
    	}
		#Get the MPaths configured
		printf("## Excluding mpaths Here ##\n") if($debug); 
    	@mpaths=`dmsetup ls | awk -F '(' '{ print \$1 }'`;
    	foreach $path (@mpaths) {
       		chomp($path);        
       		$path =~ s/\s+$//;
       		# Check for validity of this mpath first ....
			print(" Checking exclude for mpath = $path \n") if($debug); 
       		        $abs_path="/dev/mapper/" . $path ;
			# first of all check if mpath has partitions. exclude mpath itself.
			# Then check any system partition on it
			$mpath_partition=`kpartx -l $abs_path 2>/dev/null | wc -l`;
			if ($mpath_partition >= 1) {
			    print("mpath $abs_path has partitions. SO, excluding it...\n" ) if ($debug);
			    $parts_to_exclude[$cnt++]=$path;
			}
			#Now check if mpath or any of its partitions has boot disk
			$res=`parted "$abs_path" print 2>/dev/null | awk  '/PPC/ || /Linux/ || /linux/ || /boot/ || /prep/' | grep -v \"device-mapper\"`;
#			$res=`fdisk -l "$abs_path"  2>/dev/null | awk  '/PPC/ || /Linux/ '` ; 
			chomp($res); 
			if($res) { 
				print(" Mpath=$path, has valid Volume group \nres=$res \n. Excluding ..... \n") if($debug) ; 
				$parts_to_exclude[$cnt++]=$path; 			
				#if it has partition then add them as well. 
				@mpath_partitions=`kpartx -l $abs_path 2>/dev/null| awk ' { print \$1 }'`;
				print("path = $abs_path has partitions \n @mpath_partitions \n") if($debug);
       			foreach $mpath_partition (@mpath_partitions) {
					chomp($mpath_partition); 
					if($mpath_partition =~ /failed/) {
               			last;
           			}
					print(" Mpath=$path, partition=$mpath_partition.  Excluding ..... \n") if($debug) ; 
					$parts_to_exclude[$cnt++]=$mpath_partition; 
				} 
				print("Exclude disks behind this partition \n"); 
				@sd_devices=get_sd_device($path); 
				$num_devices=@sd_devices; 
				for($i=0;$i<$num_devices; $i++) { 
					printf("Excluding $sd_devices[$i] coz its part of $path \n"); 
					$parts_to_exclude[$cnt++]=$sd_devices[$i]; 
				} 
				next; 
			}
		}

		# This check should always be at the end. 
        # Now if we need to do exclude partitions also present in disks
        # excluded as part of parts_to_exclude.
        @partitions="";
        $num_parts=0;
        foreach $part (@parts_to_exclude) {
            printf(" Finding partition in $device ") if($debug);
            $device="/dev/". $part;
            @partn=`kpartx -l $device 2>/dev/null| awk ' { print \$1 }'`;
            foreach $dev (@partn) {
                chomp($dev);
                printf(" $dev \t") if($debug);
                $partitions[$num_parts++]=$dev;
            }
#           printf("\n");
        }
        foreach $partn (@partitions) {
            $parts_to_exclude[$cnt++]=$partn;
        }

		if($debug) {
			print "Done\n\n";
		}

}

#########################################################################
# checks whether filesystem is present upon the given partition or not 
#########################################################################

sub check_filesystem
{
	($test_part)=@_;
	`mkdir /tmp/mnt_check 2>/dev/null `;
	if($debug) {
		print "checking filesystem on $test_part\n";
		print "mount /dev/$test_part /tmp/mnt_check\n";
	}

# We use mount command, if it fails it means that either there is no filesystem
# on the partition or linux kernel does not understand it. So it implies 
# that the partition is not being used and we can use it for hxestorage
	
	$ret=system("mount /dev/$test_part /tmp/mnt_check 2>&1 ");
	$ret=$ret >> 8;
	if($debug) {
		print "mount returned $ret for $test_part\n"
	}
	if($ret==32){
		`rm -rf /tmp/mnt_check 2>/dev/null`;
		return 0;
	} else {
		`umount /dev/$test_part 2>&1`;
		`rm -rf /tmp/mnt_check 2>&1`;
		return 1;
	}

}

######################################################################################
# makes entry in file given filehandle and device name for 2.6 . For 2.4 it first 
# binds the device to a rawnode and then creates entry for links to rawnodes in
# file using passed filehandle and device. 
# The explaination for puting a link for 2.4 is given below. 
# For ex: If /dev/hda1 is bound to /dev/raw/raw1, then we will create a link 
# /dev/raw/rhda1---> /dev/raw/raw1. So that in place of seeing raw/raw1 in the
# supervisor screen, we will be able to see the actual device name appended with 'r' 
# The links will be deleted from the htx.cleanup script.           
#######################################################################################
 
sub make_entry
{
	local($FILE,$dev, $type)=@_ ;

	if($type =~ m/mpath/i) {
		print("binding /dev/mapper/$dev to /dev/$dev \n") if($debug);
        `ln -s /dev/mapper/$dev /dev/$dev 2>/dev/null`;
        $rmlink="rm -f /dev/$dev";
        print RAW_LINKS "$rmlink\n";
	}
	
	if($KERNEL_26) {
		print $FILE "$dev\n";
	} else { 
		if($type != m/mpath/i) {
			if($debug) {
				print "binding /dev/$dev to /dev/raw/raw$rawcnt\n";
			}
			`raw /dev/raw/raw$rawcnt /dev/$dev >/dev/null`;
			`ln -s /dev/raw/raw$rawcnt /dev/raw/r$dev >/dev/null`;
			$rawcnt++;

			# Put the corresponding remove in /tmp/rawlinks	
			$rmlink="rm -f /dev/raw/r" . "$dev";
			print RAW_LINKS "$rmlink\n";
			print $FILE "raw/r$dev\n";
		}
	}
}

#################################################################################
# creates raw nodes in /dev/raw directory to be bind later
#################################################################################

sub create_raw_nodes 
{
	$major_no = `ls -l /dev/raw |  awk '{print \$5}' | grep , | awk '(NR==1)'`;
	chomp($major_no);
	$major_no =~ s/,//;
	if($debug) {
		print "creating raw nodes in /dev/raw directory with major no $major_no\n";
	}
	for($i=0; $i<=255; $i++)
	{
		$ret=`mknod /dev/raw/raw$i c $major_no $i 2>&1`;
		if($debug) {
			print $ret;
		}
	}
}

##########################################################################################
# returns the partitions of a given partition
##########################################################################################

sub get_parts
{
	($name, $field) = @_;
	@array="";
	$name=basename($name);
	chomp($name);
	$devname="/dev/$name";
	@partition_info="";
	$file_name="/tmp/$name"."_partitions";
	`rm $file_name 2>/dev/null`;
	$rc=`lsblk -inr -o name,type $devname 1>$file_name`;
	unless (open (IN_FILE,"$file_name")) {
	    die ("Can't open $file_name file!\n");
	}
	
	@partition_info= <IN_FILE>;
	close(IN_FILE);
	`rm $file_name 2>/dev/null`;
	
	foreach $part (@partition_info) {
	    chomp($part);
	    ($block_dev, $type) = split(/\s+/, $part);
	    chomp($block_dev);
	    if($name eq $block_dev) {
	        next;
	    }
	    if($type =~ /disk/ ) {
	        next;
	    } elsif($type =~ /part/) {
	        if($field) {
	            if($block_dev =~ /^$name/ && $block_dev =~ /$field$/) {
	                push(@array, $block_dev);
	                return(@array);
	            }
	        } else {
	            push(@array, $block_dev);
	        }
	    } else {
	        # ignore the rest ..
	    }
	}
	    
	
#	local($count);
#	@match_parts=`cat /proc/partitions | awk '/$name/ { print \$4}'`;
#	foreach $part (@match_parts)
#	{
#		
#		chomp($part);
#		if($name eq $part) {
#			next;
#		}
#		$diff=$part;	
#		$diff =~ s/$name//;
#		if($diff =~ /\D/){
#			next;
#		}
#		if($diff =~ /\d/) {
#			$array[$count++]=$part;
#		}
#	}
	return @array;
}
	
##################################################################################
# Collects Tape information
##################################################################################

sub get_TD_info
{
	if($debug) {
		print "Collecting Tape info\n";
	}
	unless(open(TD_PART,">/tmp/tdpart")) {
		die("Open failed for file /tmp/tdpart\n");
	}
      # $no_tape_drives=`lsscsi | awk '(\$2 ~/tape/)' | wc -l`;
	$no_tape_drives=`cat /proc/scsi/scsi 2>/dev/null | grep Sequential-Access | wc -l`; 
	for($i=0; $i<$no_tape_drives;$i++)	
	{
		$ret=`mt -f /dev/st$i status 2>/dev/null`;
		if($debug){
			print "mt -f /dev/st$i status\n";
			print "$ret";
		}
		if($ret)
		{
 	# Tape is a character device. So don't bind
        # it to a raw node. Simply create a entry 
        # for it without appending 'r'.
	# See defect 433319
	
			if($debug){
				print "Found Tape drive st$i\n";
			}
			print TD_PART "st$i\n";
		} 
		#else {
		#	last;
		#}
	}
	if($debug){
		print "Done\n\n";
	}
	close(TD_PART);
}


####################################################################################
# Change for mpaths
####################################################################################
sub check_mpath 
{
	($mpath)=@_;
	if($debug) { 
		print(" Finding devices for mpath = $mpath \n"); 
	} 
	($mapper, $alias) = split(/\//, $mpath); 
	$wwid=`dmsetup info -c | awk ' /$alias/ { print \$8}' | sed 's/.*mpath-//g'`; 	      
	chomp($wwid);
	#get the parent device from multipath cmd. 
	$parent=`multipath -ll  | awk ' /$wwid/ { print \$1}'` ; 
	print(" Alias = $alias, wwid= $wwid, parent = $parent \n") if($debug);
	@phy_dev=&get_sd_device($parent); 
	foreach $dev (@phy_dev) { 
		chomp($dev); 
		print("Found Physical devices = $dev \n") if($debug); 
	}
	return(@phy_dev);

}	

sub get_sd_device 
{ 
 	($mpath)=@_; 
	chomp($mpath);
	@phy_dev=""; 
	$cnt_1=0;  
	$line=`multipath -ll "$mpath" | grep sd[a-z]` ; 
	chomp($line); 
	@line_elm=split(/\s/,$line); 
    foreach $elm (@line_elm) { 
		chomp($elm); 
		if($elm =~ /sd[a-z]/) { 
			chomp($elm); 
			$phy_dev[$cnt_1++]=$elm; 
		} 
	}		
	return(@phy_dev); 
}
sub get_multipath_info
{

	if($debug) { 
		print(" \n Collecting Multipath Info "); 
	} 
	#Check if multipath daemon is running. 	
	$res=`ps -ef | grep multipathd | grep -v grep | awk ' {print \$2}'`; 
	chomp($res); 
	unless($res) { 
		print("multipathd not running \n");	
		return; 
	}
	# All the commands below works only if multipath-tools is installed. 
	unless(open(MPATH_PART, ">/tmp/mpath_parts")) {
		die("Open failed for file $/tmp/mpath_parts \n"); 
	}
	unless(open(RAWPART, "</tmp/rawpart")) { 
		die("Open failed for file $/tmp/rawpart \n"); 
	} 
	@raw_parts = <RAWPART>;
	close(RAWPART); 
	@mpath_dev=NULL; 
	$num_devs = 0; 
	@tot_paths=NULL; 
	$num_paths=0;
	$duplicate = 0; 
	$duplicate_path = 0; 
	$dont_add = 0 ; 
	#Get the MPaths configured  
	@mpaths=`dmsetup ls | awk -F '(' '{ print \$1 }'`; 	
	foreach $path (@mpaths) { 
		chomp($path); 
		$path =~ s/\s+$//;
		print("$path found ..\n") if($debug);
		foreach $dev (@parts_to_exclude) {
        	chomp($dev);
            	unless($dev){
            	next;
            }

            if($path eq $dev) {
		print("$path, $dev not added coz found in exlcude list !!!! \n") if($debug); 
		$dont_add =  1; 
                last;
            }
        }
#	if($dont_add) {  
#		$dont_add =  0; 
#		next; 
#	}	
	#These multipaths will lead to multipath disks. 
	#I need to verify whether whether we can run hxestorage on it or not.
	# Compare each with raw_parts :-). 
	print("Searching for path = $path \n") if($debug); 
	@res=`multipath -ll "$path" | grep sd[a-z]`; 
	foreach $line (@res) { 
		chomp($line); 
		@spltd_line = split(/\s+/, $line);
		foreach $elmnt (@spltd_line) { 
			chomp($elmnt);
			$dont_add_dev = 0;
			if($elmnt =~/sd/) { 
				print(" path = $path, $elmnt, ") if($debug); 
				foreach $dev (@parts_to_exclude) { 
					chomp($dev);
					unless($dev){
						next; 
					} 
					if($dev eq $elmnt) { 
						$dont_add_dev =  1; 
						print("found: $elmnt, $dev\n") if debug;
						last; 
					}
				}
				print(" dont_add_dev = $dont_add_dev ") if($debug); 
				if($dont_add_dev) { 
					next; 
				}
				#Check If this device has previosly been added to array. 
				for($i = 0; $i < $num_devs; $i++) { 
					if($mpath_dev[$i] eq $elmnt) { 
						#Duplicate path to same disk found Dont add this path. 
						$duplicate = 1; 
						last; 
					}  
				} 
				print(" ,duplicate=$duplicate \n") if($debug); 
				if($duplicate) { 
					$duplicate = 0; 
					next;
				}
				if($i == $num_devs) { 
					$mpath_dev[$num_devs] = $elmnt; 
					$num_devs ++; 
				}	
				for($i = 0; $i < $num_paths; $i++) { 
					if($tot_paths[$i] eq $path) { 
						$duplicate_path = 1; 
						last; 
					} 
				} 
				if($duplicate_path) { 
					$duplicate_path = 0; 
					next; 
				}				
				print(" Found Device $elmnt in path=$path \n") if($debug); 
				if($i ==  $num_paths) { 
					$tot_paths[$num_paths] = $path; 
					$num_paths++; 
				}
			}
		}
		# HTX doesnot supports device length of more than 40 characters. 
		# if device length more than 40 chars, then find its corresponding actual device. 
		# use that instead. 

		if ($dont_add == 0) {
			print("Length of mpath name length($path) \n") if($debug);
			if(length($path) >= 15) {
				$alternate_dev=`ls -l /dev/mapper | grep "$path" | awk '{print \$NF}'`;
                	        chomp($alternate_dev);
                	        $alternate_dev=basename($alternate_dev);
                	        if((length($alternate_dev)<= 0) || (length($alternate_dev) >= 15)) {
                	            # Check in /dev/disk/by-id path for alternate dev
                	            @match=split(/\s+/, $path);
                	            $match_dev=@match[$#match];
                	            $alternate_dev=`ls -l /dev/disk/by-id | grep mpath | grep "$match_dev" | awk '{print \$NF}'`;
                	            chomp($alternate_dev);
                	            $alternate_dev=basename($alternate_dev);
                	            if((length($alternate_dev)<= 0) || (length($alternate_dev) >= 15)) {
                	                #Fallback ..
                	                $alternate_dev=$path;
                	            }
                	        }
                        	print("Mpath name too big !!! using $alternate_dev instead of $path \n") if($debug);
                        	print MPATH_PART "$alternate_dev  \n";
                        	print("**** Multipath = $alternate_dev --> USABLE by hxestorage ***** \n");

			} else { 
				print("**** Multipath = $path --> USABLE by hxestorage ***** \n"); 
				print MPATH_PART "$path \n";
				&make_entry("XYZ", $path, "mpath");
			}
			$dont_add = 1;
		}
			
	} 
	if($dont_add) { 
		$dont_add = 0; 
	}
} 
close(MPATH_PART);
#Sanity Check to verify we dont have multpath to same disk. 
    for($i = 0; $i < $num_devs; $i++) { 
		for($j = $i + 1; $j < $num_devs; $j++) { 
			if($mpath_dev[$i] eq $mpath_dev[$j]) { 
				$res = `rm -f /tmp/mpath_parts`;
				return; 
			} 
		} 
	}			
	# I need to remove the device been already exercised from mpaths 
	# in rawparts. 
	foreach $dev (@mpath_dev) { 
		$num=@raw_parts ; 
		@partitions=&get_parts($dev); 
		$num_part=@partitions;
		$i = 0; 
		chomp($dev); 
		if($dev eq "NULL") { 
			next;
		} 
		foreach $raw (@raw_parts) { 
			chomp($raw);
			print("raw_parts = $raw, dev = $dev \n") if($debug); 
			if($dev eq $raw ) {  
				print("removing $dev from rawparts as already exercised thru multipath's \n") if($debug); 
				splice(@raw_parts, $i, 1);	
			}
			#Check for partitions on $dev as well, 
			print("Device $dev has partitions @partitions \n") if($debug); 
		    for($j=0;$j<$num_part;$j++) {
                chomp($partitions[$j]);
                if($raw eq $partitions[$j]) {
					print("removing $dev from raw parts \n") if($debug); 
					splice(@raw_parts, $i, 1);	
                    last;
                }
            }
			$i++; 
		} 			
	}
    unless(open(RAWPART, ">/tmp/rawpart")) {
        die("Open failed for file $/tmp/rawpart \n");
    }
	foreach $dev (@raw_parts) { 
		print RAWPART ("$dev \n");
	}
	close(RAWPART); 	 
	if($debug) { 
		print (" done \n"); 	
	}
}
sub
get_cflash_info () { 

	print("\nCollecting CAPI Flash Information \n") if($debug); 

	%surelock_dev=""; 

	# if these files exits then read hxestorage candidate devices
	unless(open(RAWPART, "</tmp/rawpart")) {
        die("Open failed for file $/tmp/rawpart \n");
    }
    @raw_parts = <RAWPART>;
    close(RAWPART);
	$num_rawparts = @raw_parts;

    $mpath_fname="/tmp/mpath_parts";
	$mpaths_exists=0;
    if(-e $mpath_fname) {

        unless(open(MPATH_PART, "<$mpath_fname")) {
            die("Open failed for file $mpath_fname \n");
        }
        @mpath_parts=<MPATH_PART>;
        close(MPATH_PART);

        unless(open(MPATH_PART, ">$mpath_fname")) {
            die("Open failed for file >$mpath_fname \n");
        }
		$mpaths_exists = 1;
	}
		
	# Open files for writing .... 
	unless(open(RAWPART, ">/tmp/rawpart")) {
		die("Open failed for file >/tmp/rawpart \n"); 
	}
    unless(open(CFLASH_PART, ">/tmp/cflash_parts")) {
         die("Open failed for file /tmp/cflash_parts \n");
    }
	if($mpaths_exists) { 
        unless(open(MPATH_PART, ">$mpath_fname")) {
            die("Open failed for file >$mpath_fname \n");
        }
	}

	$num_cxldevs=0;
	$cxlflash_path="/sys/module/cxlflash/drivers/pci:cxlflash/*:*:*.*/host*/target*:*:*/*:*:*:*/";
	@num_paths=`ls -d $cxlflash_path 2>/dev/null`; 
	$num_cxldevs=0;
	foreach $path (@num_paths)  { 
		chomp($path);
		#Get Surelock device mapping info
		print("Searching for CXL devices in $path \n") if(debug); 
        $block_dev=`ls $path/block`;
        $surelock_dev=`ls $path/scsi_generic`;
		$block_dev=&trim($block_dev);	
		$surelock_dev=&trim($surelock_dev);
		$mode=`cat $path/scsi_generic/$surelock_dev/device/mode`; 
		$mode=&trim($mode);
		$lun_identifier = `/lib/udev/scsi_id -d /dev/$surelock_dev --page=0x83 --whitelisted`;
		$lun_identifier = &trim($lun_identifier); 
		#cut off the first digit ONLY, since we want the LUN ID
		$lunid = substr($lun_identifier, 1);
		$lunid = &trim($lunid); 	
		if(length($lunid) == 0) { 
			printf("Surelock : Ignored surelock=$surelock_dev because no block_dev=$block_dev, num_cxldevs=$num_cxldevs, lunid=$lunid \n") if($debug); 
			next;
		}
		$is_duplicate = 0; 
		for($count=0; $count < $num_cxldevs; $count++) { 
			# If we are running VLUN, then include all devices 
			#$test_phylun="/tmp/test_phylun"; 
			#if(!(-e $test_phylun)) { 
			#	last; 
			#}
			if($surelock_dev[$count]{lunid} eq $lunid) { 
				$is_duplicate = 1; 
				last; 
			}
		}	
        $surelock_dev[$num_cxldevs]{block}      = $block_dev;
        $surelock_dev[$num_cxldevs]{surelock}   = $surelock_dev;
        $surelock_dev[$num_cxldevs]{mode}       = $mode;
        $surelock_dev[$num_cxldevs]{added}      = 0;
        $surelock_dev[$num_cxldevs]{lunid}      = $lunid;
		if($is_duplicate == 1) { 
			print("Surelock : Found duplicate block=$block_dev, surelock=$surelock_dev, 
					mode=$mode, num_cxldevs=$num_cxldevs, with block dev=$surelock_dev[$count]{block}, and surelock_dev=$surelock_dev[$count]{surelock} \n") if($debug);
			$surelock_dev[$num_cxldevs]{duplicate} = 1; 	
		} else { 
			$surelock_dev[$num_cxldevs]{duplicate} = 0; 
			print("Surelock : Found Unique block=$surelock_dev[$num_cxldevs]{block}, surelock=$surelock_dev[$num_cxldevs]{surelock}, 
					mode=$mode, num_cxldevs=$num_cxldevs, lunid=$surelock_dev[$num_cxldevs]{lunid} \n") if($debug); 
		} 
		$num_cxldevs++; 
	}	
	if($num_cxldevs == 0) { 
		print("No Surelock device found, num_cxldevs=$num_cxldevs \n") if($debug); 
		# Write back the what ever was existing and return.  
		foreach $rawpart (@raw_parts) { 
			chomp($rawpart); 
			print RAWPART ("$rawpart \n"); 
		}
		close(RAWPART);
		if($mpaths_exists) { 
			foreach $mpath (@mpath_parts) { 
				chomp($mpath); 
				print MPATH_PART ("$mpath \n"); 
			}
			close(MPATH_PART); 
		}
		return;
	} else { 
		print("Num Surelock devs = $num_cxldevs\n\n\n") if($debug); 
	}
	# Check in rawpart if entry exists .. 
	$rawpart_match = 0; 
	for($i=0; $i < $num_rawparts; $i++) { 
		$raw_parts[$i]=&trim($raw_parts[$i]);
		$rawpart_match = 0;
		for($j=0; $j < $num_cxldevs; $j++) { 
			if(($raw_parts[$i] eq $surelock_dev[$j]{block}) && ($surelock_dev[$j]{mode} =~ /superpipe/)) { 
				$rawpart_match = 1; 	
				last; 
			}
		}
		if($rawpart_match == 0 ) {  
			print RAWPART ("$raw_parts[$i]\n"); 		
			printf ("Adding $raw_parts[$i] to RAWPART \n") if($debug); 
		} elsif(($surelock_dev[$j]{added} == 0) && ($surelock_dev[$j]{duplicate} == 0) )  { 
			print CFLASH_PART ("$surelock_dev[$j]{surelock}\n");  
			print ("Adding $surelock_dev[$j]{surelock} to CFLASH_PART \n") if($debug); 
			$surelock_dev[$j]{added} = 1; 	
		} else { 
			print("block=$surelock_dev[$j]{block}, surelock=$surelock_dev[$j]{surelock} not added, coz added=$surelock_dev[$j]{added} and duplicate=$surelock_dev[$j]{duplicate} \n") if($debug); 
		}
	}	
	# Check in mpath if this device is slave .. 
	if($mpaths_exists) { 
		foreach $mpath (@mpath_parts) { 
			$mpath = &trim($mpath); 
			$mpath_match = 0; 
			@mpath_blockdev=`ls /sys/block/'$mpath'/slaves/`;
			foreach $slave (@mpath_blockdev) { 
				$slave = &trim($slave); 
				for($j = 0; $j < $num_cxldevs; $j++) {
					if(($surelock_dev[$j]{block} eq $slave) && ($surelock_dev[$j]{mode} =~ /superpipe/)) { 
						$mpath_match = 1; 
						last;
					} 
				}
				if($mpath_match == 1) { 
					last; 
				}
			}
			print("mpath=$mpath, mpath_match=$mpath_match, slaves=@mpath_blockdev, surelock_block=$surelock_dev[$j]{block}, j = $j\n") if($debug);
			if($mpath_match == 0) {
				printf("Adding $mpath back to MPATH_PARTs \n"); 
				print MPATH_PART ("$mpath\n");  
			} else { 
            	if(($surelock_dev[$j]{added} == 0) && ($surelock_dev[$j]{duplicate} == 0)) {
					printf("Adding surelock=$surelock_dev[$j]{surelock} is part of mpath=$mpath, block=$surelock_dev[$j]{block} hence adding to CFLASH_PART \n") if($debug);
                    print CFLASH_PART ("$surelock_dev[$j]{surelock} \n");
                    $surelock_dev[$j]{added} = 1;
				} else { 
                	print("surelock=$surelock_dev[$j]{surelock},block=$surelock_dev[$j]{block}  not added, coz added=$surelock_dev[$j]{added} and duplicate=$surelock_dev[$j]{duplicate}  \n") if($debug);
                }
			}
		}
	}  
	
	close(MPATH_PART) if($mpaths_exists); 	
	close(RAWPART); 
    # if mpath_part and rawpart remained empty, then sgXX devices would get ignored.
    for($j = 0; $j < $num_cxldevs; $j++) {
    	if(($surelock_dev[$j]{added} == 0) && ($surelock_dev[$j]{mode} =~ /superpipe/) && ($surelock_dev[$j]{duplicate} == 0)) {
        	printf("Adding surelock=$surelock_dev[$j]{surelock} to CFLASH_PART as it was not found anywhere \n");
            print CFLASH_PART ("$surelock_dev[$j]{surelock} \n");
            $surelock_dev[$j]{added} = 1;
        }
    }

	close(CFLASH_PART); 
	printf("Collecting CAPI Flash Information ... Completed!!! \n\n\n") if($debug); 
} 


sub
get_disk_info_parted() { 

	$new_dev="no";
	$dev_name="";
	$partition_name="";
	$num_partitions=0;

	print("Collecting Disk Information from GNU parted command \n") if($debug);  
	@input=`parted -msl`;
	foreach $line (@input) {

        chomp($line);
        if($line =~ /BYT/) {
                $new_dev="yes";
                next;
        }
        if($new_dev=~ /yes/) {
                $fs_type="NA";
                $used_as="RAW";
                if($line =~ /^$/) {
                        $new_dev="no";
                        next;
                }
                @parted_fields = split(/:/, $line);
                if($line =~ /dev/) {
                        # Actual Disk Information
                        $num_disk++;
                        printf(" Disk name=%s \n", $parted_fields[0]) if($debug);
                        $num_partitions=0;
                        $dev_name=$parted_fields[0];
                        $disk_info[$num_disk]{name}=$parted_fields[0];
                        $disk_info[$num_disk]{num_partitions}=0;
                } else {
                        # It's partition Information
                        @partition_name="";
                        @partition_name=&get_parts($dev_name, $parted_fields[0]);
                        # $partition_name=$dev_name.$parted_fields[0];
                        chomp($fs_type);
                        if(length($parted_fields[4])) {
                                $fs_type=$parted_fields[4];
                        }
                        chop($parted_fields[6]);
                        if(length($parted_fields[6])) {
                                $used_as=$parted_fields[6];
                        }
			$basename=basename(pop @partition_name); 
			chomp($basename); 
                        $disk_info[$num_disk]{$disk_info[$num_disk]{num_partitions}}{partition_name} = $basename; 
                        chomp($fs_type);
                        $disk_info[$num_disk]{$disk_info[$num_disk]{num_partitions}}{fs_type} = $fs_type;
                        chomp($used_as);
                        $disk_info[$num_disk]{$disk_info[$num_disk]{num_partitions}}{used_as} = $used_as;
                        $disk_info[$num_disk]{num_partitions}++;
                        $num_partitions++;

                        print("partition_name=$partition_name, fs_type= $fs_type, used_as=$used_as \n") if($debug);
                }
        }

	}
	return(); 
}


sub trim {

    local($string) = @_;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

