use strict;
use IO::Socket; 


my $ecu_port = 8899; 
my $ecu_ip_address = "192.168.178.73";

print("Connecting $ecu_ip_address...\n");

my $response = '';

$response = queryECUSocket("APS1100160001END\n");
my %systeminfo = parseEcuBSystemInfo($response);
print("Count" . scalar keys %systeminfo);


$response = queryECUSocket("APS1100390004216300060865END00\n"); #Week
parseGetEnergyOfWeekMonthYear($response);

$response = queryECUSocket("APS1100390004216300060865END01\n"); #Month
parseGetEnergyOfWeekMonthYear($response);

$response = queryECUSocket("APS1100390004216300060865END02\n"); #Year
parseGetEnergyOfWeekMonthYear($response);

$response = queryECUSocket("APS1100390003216300060865END20230615\n");
parseGetPowerOfDay($response);

$response = queryECUSocket("APS1100280030216300060865END\n");
parseGetInverterSignalLevel($response);



sub queryECUSocket {
	my ($query) = @_;
	my $socket = new IO::Socket::INET (   
		PeerAddr => $ecu_ip_address,   
		PeerPort => $ecu_port,   
		Proto => 'tcp',   
		Timeout => 4,
	);   
	return unless $socket;
	print $socket $query;
	
	#$response = <$socket>;
	my $response = "";
    $socket->recv($response, 2048);
    
    print "Query: " . $query;
    print "Bytes received: " . length($response) . "\n";
    print $response;
	
	close($socket);
	return $response;	
}

sub parseGetInverterSignalLevel {
	my ($response) = @_;	

	if (length($response) < 23) {
		return;	
	}
	
	my %signal = ();
	
	$signal{'SignatureStart'}		= substr($response, 0, 3);
	$signal{'CommandGroup'} 			= substr($response, 3, 2);
	$signal{'FrameLength'} 			= substr($response, 5, 4);
	$signal{'CommandCode'} 			= substr($response, 9, 4);
	$signal{'MatchStatus'} 			= substr($response, 13, 2);
	
	
	$signal{'SignalLevel'} = ();
	my $offset = 15;
	while ($offset < length($response) - 8) {
		my $inverterId = unpack("H12", substr($response, $offset, 6));
		my $value = unpack("n", chr(0) . substr($response, $offset+1, 1)); 
		$signal{'SignalLevel'}{$inverterId} = $value;
		$offset += 7;
	}

	$signal{'SignatureStop'}		= substr($response, $offset, 4);

	if ($signal{'SignatureStop'} ne "END\n") {return;}
	

	
	my $k = '';
	foreach $k (sort keys %signal) {
		if (ref $signal{$k} eq ref {}) {  #If its a hash
			print "$k = \n";
			foreach my $d (sort keys %{$signal{$k}}) {
				print "\t$d = $signal{$k}{$d}\n";
			}
		} else { # or a simple value
			print "$k => $signal{$k}\n";
			
		}
	}
	print "\n\n";
	
	return %signal;
	
}



sub parseGetPowerOfDay {
	my ($response) = @_;
	
	if (length($response) < 23) {
		return;	
	}
	
	my %power = ();
	
	$power{'SignatureStart'}		= substr($response, 0, 3);
	$power{'CommandGroup'} 		= substr($response, 3, 2);
	$power{'FrameLength'} 			= substr($response, 5, 4);
	$power{'CommandCode'} 			= substr($response, 9, 4);
	$power{'MatchStatus'} 			= substr($response, 13, 2);
	
	
	$power{'Time'} = ();
	my $offset = 15;
	while ($offset < length($response) - 4) {
		my $date = unpack("H4", substr($response, $offset, 2));
		my $value = unpack("n", substr($response, $offset+2, 2)); 
		$power{'Time'}{$date} = $value;
		$offset += 4;
	}
	

	$power{'SignatureStop'}		= substr($response, $offset, 4);

	if ($power{'SignatureStop'} ne "END\n") {return;}	
	
	my $k = '';
	foreach $k (sort keys %power) {
		if (ref $power{$k} eq ref {}) {  #If its a hash
			print "$k = \n";
			foreach my $d (sort keys %{$power{$k}}) {
				print "\t$d = $power{$k}{$d}\n";
			}
		} else { # or a simple value
			print "$k => $power{$k}\n";
			
		}
	}
	print "\n\n";
	
	return %power;
	
}

sub parseGetEnergyOfWeekMonthYear {
	my ($response) = @_;
	
	if (length($response) < 23) {
		return;	
	}
	
	my %energy = ();
	
	$energy{'SignatureStart'}		= substr($response, 0, 3);
	$energy{'CommandGroup'} 		= substr($response, 3, 2);
	$energy{'FrameLength'} 			= substr($response, 5, 4);
	$energy{'CommandCode'} 			= substr($response, 9, 4);
	$energy{'MatchStatus'} 			= substr($response, 13, 2);
	$energy{'WeekMonthYear'} 		= substr($response, 15, 2);
	
	
	$energy{'Days'} = ();
	my $offset = 17;
	while ($offset < length($response) - 8) {
		my $date = unpack("H8", substr($response, $offset, 4));
		my $value = unpack("N", substr($response, $offset+4, 4)) / 100.0; 
		$energy{'Days'}{$date} = $value;
		$offset += 8;
	}
	
	$energy{'SignatureStop'}		= substr($response, $offset, 4);

	if ($energy{'SignatureStop'} ne "END\n") {return;}

	my $k = '';
	foreach $k (sort keys %energy) {
		if (ref $energy{$k} eq ref {}) {  #If its a hash
			print "$k = \n";
			foreach my $d (sort keys %{$energy{$k}}) {
				print "\t$d = $energy{$k}{$d}\n";
			}
		} else { # or a simple value
			print "$k => $energy{$k}\n";
			
		}
	}
	print "\n\n";
	
	return %energy;
	
}


sub parseEcuBSystemInfo {
	my ($response) = @_; 

	if (length($response) < 55) {
		return;	
	}
	
	my %systemInfo = ();
	
	$systemInfo{'SignatureStart'}		= substr($response, 0, 3);
	$systemInfo{'CommandGroup'} 		= substr($response, 3, 2);
	$systemInfo{'FrameLength'} 			= substr($response, 5, 4);
	$systemInfo{'CommandCode'} 			= substr($response, 9, 4);

	$systemInfo{'ECUid'} 				= substr($response, 13, 12);
	$systemInfo{'ECUmodel'} 			= substr($response, 25,  2);

	$systemInfo{'LifeTimeEnergy'} 		= unpack("N", substr($response, 27,  4)) / 10.0;
	$systemInfo{'LastSystemPower'} 		= unpack("N", substr($response, 31,  4));
	$systemInfo{'CurrentDayEnergy'}		= unpack("N", substr($response, 35,  4)) / 100.0;

	$systemInfo{'LastTimeConnectedEMA'}	= unpack("H14", substr($response, 39,  7));

	$systemInfo{'Inverters'}			= unpack("n", substr($response, 46,  2));
	$systemInfo{'InvertersOnline'}		= unpack("n", substr($response, 48,  2));

	$systemInfo{'ECUchannel'}			= substr($response, 50,  2);
	
	$systemInfo{'VersionLength'}		= substr($response, 52,  3);
	$systemInfo{'Version'}				= substr($response, 55,  $systemInfo{'VersionLength'});
	
	my $offset = 55 + $systemInfo{'VersionLength'};
	
	$systemInfo{'TimeZoneLength'}		= substr($response, $offset,  3);
	$systemInfo{'TimeZone'}				= substr($response, $offset+=3,  $systemInfo{'TimeZoneLength'});

	$systemInfo{'EthernerMAC'}			= unpack("H12", substr($response, $offset+=$systemInfo{'TimeZoneLength'}, 6));
	$systemInfo{'WirelessMAC'}			= unpack("H12", substr($response, $offset+=6, 6));

	$systemInfo{'SignatureStop'}		= substr($response, $offset+=6, 4);

	if ($systemInfo{'SignatureStop'} ne "END\n") {return;}
	
	my $k = '';
	foreach $k (sort keys %systemInfo) {
	    print "$k => $systemInfo{$k}\n";
	}
	print "\n\n";
	
	return %systemInfo;
}

