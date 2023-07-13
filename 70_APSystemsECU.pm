 package main;

use strict;
use warnings;

use IO::Socket::INET;

my @readings = ('LifeTimeEnergy',               # kWh
            	'LastSystemPower',              # W
            	'CurrentDayEnergy',             # kWh
            	);

#my @attributes = (	'Host',
#					'Port',
#					'Timeout',
#					'Interval'
#);

sub
APSystemsECU_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}    = "APSystemsECU_Define";
  $hash->{UndefFn}  = "APSystemsECU_Undef";
  $hash->{GetFn}    = "APSystemsECU_Get";
  #$hash->{SetFn}    = "APSystemsECU_Set";  
  #$hash->{AttrList} = "loglevel:0,1,2,3,4,5 event-on-update-reading event-on-change-reading";
  #$hash->{AttrList} = join (' ', @attributes);
}

sub
APSystemsECU_Define($$)
{
  my ($hash, $def) = @_;
  my $name = $hash->{NAME};

  my @args = split("[ \t]+", $def);

  if (int(@args) < 4)
  {
    return "APSystemsECU_Define: too few arguments. Usage:\n" .
           "define <name> APSystemsECU <host> <port> [<interval> [<timeout>]]";
  }

  $hash->{Host} = $args[2];
  $hash->{Port} = $args[3];

  $hash->{Interval} = int(@args) >= 5 ? int($args[4]) : 60;
  $hash->{Timeout}  = int(@args) >= 6 ? int($args[5]) : 4;

  # config variables
  $hash->{Invalid}    = -1;    # default value for invalid readings

  $hash->{STATE} = 'Initializing';

  #readingsBeginUpdate($hash);

  #readingsEndUpdate($hash, $init_done);

  APSystemsECU_Update($hash);

  Log3 $name, 2, "$hash->{NAME} will read from ECU at $hash->{Host}:$hash->{Port} " . 
         ($hash->{Interval} ? "every $hash->{Interval} seconds" : "for every 'get $hash->{NAME} <key>' request");

  return undef;
}

sub
APSystemsECU_Update($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};

  if ($hash->{Interval} > 0) {
    InternalTimer(gettimeofday() + $hash->{Interval}, "APSystemsECU_Update", $hash, 0);
  }


  Log3 $name, 4, "$hash->{NAME} tries to contact ECU at $hash->{Host}:$hash->{Port}";

  my $success = 0;

  my $socket = new IO::Socket::INET (   
	PeerAddr =>  $hash->{Host},   
	PeerPort =>  $hash->{Port},   
	Timeout =>  $hash->{Timeout},
	Proto => 'tcp',   
  );   
  
  my %systeminfo = ();
  if ($socket and $socket->connected()) {
	  Log3 $name, 4, "$hash->{NAME} Socket open, requesting data...";
	  print $socket "APS1100160001END\n";  
	  
	  #my $response = <$socket>;
	  my $response = "";
	  $socket->recv($response, 2048);
	  
	  Log3 $name, 4, "ECU Repsonse: " . $response;
	  %systeminfo = APSystemsECU_parseEcuBSystemInfo($response);
	  close($socket);
	  
	  my $k = '';
	  Log3 $name, 4, "ECU sent following " . (scalar keys %systeminfo) . " Values:";
      foreach $k (sort keys %systeminfo) {
		 Log3 $name, 4, "\t$k => $systeminfo{$k}";
      }

	  readingsBeginUpdate($hash);
	  
	  readingsBulkUpdateIfChanged($hash, 'LastSystemPower', $systeminfo{'LastSystemPower'});
	  readingsBulkUpdateIfChanged($hash, 'CurrentDayEnergy', $systeminfo{'CurrentDayEnergy'});
	  readingsBulkUpdateIfChanged($hash, 'LifeTimeEnergy', $systeminfo{'LifeTimeEnergy'});

	  readingsEndUpdate($hash, $init_done);

	  $hash->{STATE} = $hash->{READINGS}{LastSystemPower}{VAL}.' W, '.$hash->{READINGS}{CurrentDayEnergy}{VAL}.' kWh';
	  
	  $success = 1;
  }
  
  
  

  if ($success) {
    Log3 $name, 4, "$hash->{NAME} got fresh values from ECU";
  } else {
    $hash->{STATE} = 'Reading from ECU failed';
    Log3 $name, 4, "$hash->{NAME} was unable to get fresh values from ECU";
  }

  return undef;
}

sub
APSystemsECU_Get($@)
{
  my ($hash, @args) = @_;
  my $name = $hash->{NAME};

  return 'APSystemsECU_Get needs two arguments' if (@args != 2);

  APSystemsECU_Update($hash) unless $hash->{Interval};

  my $get = $args[1];
  my $val = $hash->{Invalid};

  if (defined($hash->{READINGS}{$get})) {
    $val = $hash->{READINGS}{$get}{VAL};
  } else {
    return "APSystemsECU_Get: no such reading: $get";
  }

  Log3 $name, 3, "$args[0] $get => $val";

  return $val;
}


#sub APSystemsECU_Attr($$$$) {
#	my ( $cmd, $name, $aName, $aValue ) = @_;
#	my $hash = $defs{$name};
#	
#	if ($cmd eq 'set') {
#		if ($aName eq 'Host') { $hash->{Host} = $aValue; }
#		elsif ($aName eq 'Port') { $hash->{Port} = $aValue; }
#		elsif ($aName eq 'Interval') { $hash->{Interval} = $aValue; }
#		elsif ($aName eq 'Timeout') { $hash->{Timeout} = $aValue; }
#		else {return "Unknown attr $aName";}
#		
#	}
#	
#	return undef;
#}

#sub APSystemsECU_Set {
#	my ($hash, @args) = @_;
#	
#	return '"set Hello" needs at least one argument' if (int(@args) < 2);
#	
#	my $name = shift @args;
#	my $cmd = shift @args;
#	my $value = join("", @args);
#
#	if ($cmd eq 'Host') { $hash->{Host} = $value; }
#	elsif ($cmd eq 'Port') { $hash->{Port} = $value; }
#	elsif ($cmd eq 'Interval') { $hash->{Interval} = $value; }
#	elsif ($cmd eq 'Timeout') { $hash->{Timeout} = $value; }
#	else {return "Unknown argument $cmd, choose one of Host Port Interval Timeout";}
#  
#	return undef;
#}


sub
APSystemsECU_Undef($$)
{
  my ($hash, $args) = @_;

  RemoveInternalTimer($hash) if $hash->{Interval};

  return undef;
}



sub APSystemsECU_parseEcuBSystemInfo {
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
	
	#my $k = '';
	#foreach $k (sort keys %systemInfo) {
	#    print "$k => $systemInfo{$k}\n";
	#}
	#print "\n\n";
	
	return %systemInfo;
}


1;

