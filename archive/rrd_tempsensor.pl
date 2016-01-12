#!/usr/bin/perl
#
# copyright Martin Pot 2006
# http://martybugs.net/electronics/tempsensor/
#
# thanks to Petr for suggestions relating to better handling of failed data reads
#
# rrd_tempsensor.pl

use lib qw(/usr/local/rrdtool-1.2.12/lib/perl);
use RRDs;
use Net::Pachube;
my $feed_id="v1/feeds/79292";
my $key="nMSuKqIIJMvuL5QYKSQTQOEt58KSAKxTbjVReWYwbWs3OD0g";
my $pachube = Net::Pachube->new( key=> $key, url=>"http://api.cosm.com");
my $feed = $pachube->feed($feed_id);


# define location of rrdtool databases
my $rrd = '/var/lib/rrd';
# define location of images
my $img = '/var/www/temperature';

# process data for each interface (add/delete as required)
my @values;
push(@values, ProcessSensor(0, "PC"));
push(@values, ProcessSensor(1, "roof"));
push(@values, ProcessSensor(2, "freezer"));
push(@values, ProcessSensor(3, "compressor"));
$feed->update(data=>\@values);

sub ProcessSensor
{
# process sensor
# inputs: $_[0]: sensor number (ie, 0/1/2/etc)
#	  $_[1]: sensor description 

	# get temperature from sensor
	my $temp = `sudo /usr/local/bin/digitemp -t $_[0] -q -c /etc/digitemp.conf -o%C | tail -1`;

	# remove eol chars
	chomp($temp);

#	print "sensor $_[0]: $temp degrees C\n";

	# if rrdtool database doesn't exist, create it
	if (! -e "$rrd/temp$_[0].rrd")
	{
		print "creating rrd database for temp sensor $_[0]...\n";
		RRDs::create "$rrd/temp$_[0].rrd",
			"-s 10",
			"DS:temp:GAUGE:600:U:U",
			"RRA:AVERAGE:0.5:1:2016",
			"RRA:MIN:0.5:1:2016",
			"RRA:MAX:0.5:1:2016",
			"RRA:AVERAGE:0.5:6:1344",
			"RRA:MIN:0.5:6:1344",
			"RRA:MAX:0.5:6:1344",
			"RRA:AVERAGE:0.5:24:2190",
			"RRA:MIN:0.5:24:2190",
			"RRA:MAX:0.5:24:2190",
			"RRA:AVERAGE:0.5:144:3650",
			"RRA:MIN:0.5:144:3650",
			"RRA:MAX:0.5:144:3650";
	}
	if ($ERROR = RRDs::error) { print "$0: failed to create $_[0] database file: $ERROR\n"; }

	# check for error code from temp sensor
	if (int $temp eq 85)
	{
		print "failed to read value from sensor $_[0]\n";
		$temp = "U";
	}
		
	# insert values into rrd
	RRDs::update "$rrd/temp$_[0].rrd",
		"-t", "temp",
		"N:$temp";
	if ($ERROR = RRDs::error) { print "$0: failed to insert $_[0] data into rrd: $ERROR\n"; }


	# create graphs for current sensor
	&CreateGraph($_[0], "day", $_[1]);
	&CreateGraph($_[0], "week", $_[1]);
	&CreateGraph($_[0], "month", $_[1]); 
	&CreateGraph($_[0], "year", $_[1]);
	return $temp;
}

sub CreateGraph
{
# creates graph
# inputs: $_[0]: sensor number (ie, 0/1/2/etc)
#	  $_[1]: interval (ie, day, week, month, year)
#	  $_[2]: sensor description 

	RRDs::graph "$img/temp$_[0]-$_[1].png",
		"-s -1$_[1]",
		"-t $_[2] (sensor $_[0]) :: last $_[1]",
		"--lazy",
		"-h", "80", "-w", "600",
		"-a", "PNG",
		"-v degrees C",
		"--slope-mode",
		"DEF:temp=$rrd/temp$_[0].rrd:temp:AVERAGE",
		"DEF:min=$rrd/temp$_[0].rrd:temp:MIN",
		"DEF:max=$rrd/temp$_[0].rrd:temp:MAX",
		"LINE1:min#FF3333",
		"LINE1:max#66FF33",
		"LINE2:temp#0000FF:temp sensor $_[0]\\:",
		"GPRINT:temp:MAX:    Max\\: %6.1lf",
		"GPRINT:temp:AVERAGE: Avg\\: %6.1lf",
		"GPRINT:temp:LAST: Current\\: %6.1lf degrees C\\n";
	if ($ERROR = RRDs::error) { print "$0: unable to generate sensor $_[0] $_[1] graph: $ERROR\n"; }
}
