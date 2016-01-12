#!/usr/bin/perl
#
####################################################################
#
# temps.pl
#
# Thierry Hugue
# 10/04/2011 
#
#
# This script is used to poll OWFS server for temperature values
# and to store them in the local RRD database
# Then, several graphs (PNG) are created out of the RRD database
#
# INPUT : 
# - data collected on the OWFS server
#
# OUTPUT :
# - RRD database updated
# - several graphs (PNG) in web directory
#
####################################################################

use strict;
use warnings;
use DateTime;
use Data::Dumper;
use DateTime::Event::Sunrise;
use Math::Round;
use OWNet;
use RRDs;
use POSIX qw(strftime);


############################
#
# Parameters to adjust
#
############################
#
my %sensors = (
        "10.121709010800" => { name => "Basement1", temp => 99, order => 5, legend => "Blue wide", color => "#4da6ff"},
        "28.CC292D040000" => { name => "Basement2", temp => 99, order => 4, legend => "Blue x 1 ", color => "#0066cc"},
        "28.FC9A2C040000" => { name => "Basement3", temp => 99, order => 3, legend => "White x 1", color => "#e6f2ff"},
        "28.4A052D040000" => { name => "Basement4", temp => 99, order => 2, legend => "Red x 1  ", color => "#ff3300"},
        "28.E9A92C040000" => { name => "Basement5", temp => 99, order => 1, legend => "Green x 1", color => "#009933"},
        "28.79CC2C040000" => { name => "Basement6", temp => 99, order => 6, legend => "Grey wide", color => "#666699"},
        "28.A549BB000000" => { name => "Basement7", temp => 99, order => 7, legend => "White x 2", color => "#ccffcc"},
        "28.33A1BB000000" => { name => "Basement8", temp => 99, order => 8, legend => "Black    ", color => "#000000"},
        "10.840609010800" => { name => "Basement9", temp => 99, order => 8, legend => "Grey x 1 ", color => "#669999"}
        );

my $owsystem = "geo:4304";
my $dir = "/code/temperature";
my $oneWireDir = "/mnt/1wire/";
my $width=600;
my $height=200;
my $LAT = "-37.8136";
my $LON = "144.9631";
my $watermark="© Thierry Hugue - 2011";


############################
#
# Global variables (should not need to be modified)
#
############################
my $file = "temps_vmc.rrd";
my $db = "$dir/$file";
my ($sunrise_secs, $sunset_secs);
my $SUNS = "";
my $IMAGE = $dir."/temps.png";
my $COMMENT="Generated on ".strftime "%Y-%m-%d %H:%M:%S", localtime() ;

############################
#
# Function to calculate the sunrise and sunset times to show on the graphs
#
############################
sub get_sunrise_sunset()
{
   # This function calculate Sunrise and Sunset
   #
   # OUTPUT:
   #   - $SUNS: free text string, containing the comment to display sunset/sunrise values
   #   - $sunrise_secs: sunrise in seconds
   #   - $sunset_secs: sunset in seconds
   #
    my $dt = DateTime->today(time_zone => 'Australia/Melbourne');
    my $sunrise_span = DateTime::Event::Sunrise ->new( longitude => $LON , latitude => $LAT, iteration => '1');
    my $both_times = $sunrise_span->sunrise_sunset_span($dt);

    my $sunr = $both_times->start->datetime;
    $sunr =~ s/^.+T//;

    my $suns = $both_times->end->datetime;
    $suns =~ s/^.+T//;

    my @sunr_bits = split(/:/, $sunr);
    my @suns_bits = split(/:/, $suns);

    $sunrise_secs = $sunr_bits[0]*3600 + $sunr_bits[1]*60 + $sunr_bits[2];
    $sunset_secs = $suns_bits[0]*3600 + $suns_bits[1]*60 + $suns_bits[2];

    $SUNS = "Sunrise: ${sunr} --- Sunset: ${suns}";
    print "$SUNS\n";

}

############################
#
# Function to collect probes values and store in RRD DB
#
############################
sub get_temps()
{
    # Setup comms to the OWFS server
	#my $owserver = OWNet->new($owsystem.' -v -C');

    # Loop through each sensor
    my $update_string = "N";
    print "\n";
    foreach my $sensor ( sort by_order keys(%sensors))
    {
        my $temp = 99;
        my $passed;
        my $tempname = $oneWireDir . "/" . $sensor .  "/temperature";
        if ( -e $tempname )
        {
            $sensors{$sensor}{temp} = `cat $tempname`;
            $sensors{$sensor}{temp} =~ s/^\s+//;
            print "$sensor: $sensors{$sensor}{name} =>\t$sensors{$sensor}{temp} \n";
            $passed = 1;
        } else
        {
            print "$sensors{$sensor}{name} not responding\n";
        }
        if ( !$passed )
        {
            print "$sensor: $sensors{$sensor} not responding\n";
            # Insert last valid value.
            $sensors{$sensor}{temp} = "U";
        }
        # Trim any leading whitespace
        $update_string .= ":$sensors{$sensor}{temp}";
    }
    print "\n";

    # Now we can submit the data as one set.
    my $chaine="N" ;
    foreach my $clef ( sort by_order keys(%sensors))
	{ $chaine .= ":".$sensors{$clef}{temp} ; }
    RRDs::update( "$db", $chaine);

    my $err = RRDs::error;
    print "ERROR while updating DB: $err\n" if $err;
}

############################
# 
# Function to sort according to probes order
# 
############################
sub by_order
{
	$sensors{$a}{order} <=> $sensors{$b}{order} ;
}



############################
#
# Function to create one graph
#
############################
sub CreateGraph  
{
  # creates graph
  # INPUT:
  #   $_[0] : interval (ie, day, week, month, year)

my $interval=shift ;
my $fichier = $dir."/temp".$interval.".png" ;
my $period = "Last ".$interval;
my ($result_arr,$xsize,$ysize) ;
my $chaine="";
my @par = () ;

my $k ;
my $loc_comment = $COMMENT ;
my $loc_suns = $SUNS ;

    $loc_comment =~ s/:/\\:/g ;
    $loc_suns =~ s/:/\\:/g ;

    print "Graphing\n";

    @par = (
    "$fichier",
    "-a", "PNG",
    "--lazy",
    "-s -1$interval",
    "-A",
    "-t", "VMC Temps For $period",
    "-v", "°C",
    "-w", "$width",
    "-h", "$height",
    "-W", "$watermark",
    "-z", 
    "-Y",
    "--slope-mode"
	) ;

    foreach my $clef ( sort by_order keys(%sensors))
    {
	$k = $sensors{$clef}{legend} ;
	$k =~ s/ /_/g ; # remove blanks
	$chaine = "DEF:".$k."=".$db.":".$sensors{$clef}{name}.":AVERAGE" ;
	push (@par,$chaine) ;
    }

    #=== if daily or weekly graph, display sunrise/sunset areas (estimated for weekly, based on today's values)
    if (($interval eq "day") or ($interval eq "week")) 
    { 
	# tip: $k has a value, still reachable from here (last Legend value) 
	push (@par, "CDEF:nightplus=LTIME,86400,%,$sunrise_secs,LT,INF,LTIME,86400,%,$sunset_secs,GT,INF,UNKN,$k,*,IF,IF") ;
	push (@par, "CDEF:nightminus=LTIME,86400,%,$sunrise_secs,LT,NEGINF,LTIME,86400,%,$sunset_secs,GT,NEGINF,UNKN,$k,*,IF,IF") ;
	push (@par, "AREA:nightplus#CCCCCCAA") ;
	push (@par, "AREA:nightminus#CCCCCCAA") ;
    }

    push (@par, "COMMENT:\\t\\t\\t\\t\\tnow       avg.      max.      min.\\n") ;

    foreach my $clef ( sort by_order keys(%sensors))
    {
	$k = $sensors{$clef}{legend} ;
	$k =~ s/ /_/g ; # remove blanks
	$chaine = "LINE1:".$k.$sensors{$clef}{color}.":".$sensors{$clef}{legend}." " ;
	push (@par,$chaine) ;
	$chaine = "GPRINT:".$k.":LAST:%5.1lf °C" ;
	push (@par,$chaine) ;
	$chaine = "GPRINT:".$k.":AVERAGE:%5.1lf °C" ;
	push (@par,$chaine) ;
	$chaine = "GPRINT:".$k.":MAX:%5.1lf °C" ;
	push (@par,$chaine) ;
	$chaine = "GPRINT:".$k.":MIN:%5.1lf °C\\\\n" ;
	push (@par,$chaine) ;
    }

    push (@par, "COMMENT:$loc_suns\\n") ;
    push (@par, "COMMENT:$loc_comment") ;
	#print Dumper( @par );

    ($result_arr,$xsize,$ysize) = RRDs::graph (@par) ;
	
   my $ERR=RRDs::error;
   die "ERROR to generate $interval graph: $ERR\n" if $ERR;

   print "Imagesize: ${xsize}x${ysize}\n" ;
   print "Averages: ". (join ", ", @$result_arr). "\n" ;
   print Dumper($result_arr);

}


############################
#
# Main processing starts here
#
############################

print $COMMENT."\n" ;

#=== Step 1 : get sunrise & sunset time
get_sunrise_sunset();

#=== Step 2: collect temperature and store them in RRD database
get_temps();

#$SUNS =~ s/:/\:/g;
print "$SUNS\n";

#=== Step 3: create each graph
CreateGraph ("day") ;
CreateGraph ("week") ;
CreateGraph ("month") ;
CreateGraph ("year") ;

