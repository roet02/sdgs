use strict;
use subr;
use File::Copy;



######################################################################
## initial declaration
###################################################################### 
my $script = $0;
my $self = $script;
$script =~ s!^(?:.*/)?(.+?)(?:\.[^.]*)?$!$1!;
my $process_id =$$;
my $num_args = $#ARGV + 1;
my $database_role;
my $rc;


######################################################################
## check input parameters
###################################################################### 
my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  Usage();
  exit 1;
}

if ($ARGV[0] !~ "--s")  {   Usage();exit; }


my $senv_section =$ARGV[1];

subr->writeStderr('INFO', "Start:check $senv_section");

###################################################################### 
## Connect to database and check database role
###################################################################### 
if (subr->_check() ne "PRIMARY" and subr->_check() ne "STANDBY" ) {
  subr->writeStderr('Error', "unknown database role");
  exit 1;
}
$database_role=subr->_check();
subr->writeStderr('INFO', "Role:".$database_role);

###################################################################### 
## Reads oracle.senv into hash variable
###################################################################### 
if (subr->_readoraclesenv() ne 0) {
  subr->writeStderr('Error', "oracle.senv not found");
  exit 1;
}



###################################################################### 
## If Primary role, comment NEST_SUBTYP in hash
###################################################################### 
if ($database_role eq "PRIMARY" ) {
  if (subr->_findreplace($senv_section,"^ *SET NEST_SUBTYP=orasdb","## SET NEST_SUBTYP=orasdb") ne 0) {
    subr->writeStderr('Error', "Section $senv_section senv not found");
    exit 1;
  }
} 

###################################################################### 
## If Standby role, uncomment NEST_SUBTYP in hash
###################################################################### 
if ($database_role eq "STANDBY" ) {
  if (subr->_findreplace($senv_section,"^ *#+.*SET NEST_SUBTYP=orasdb","SET NEST_SUBTYP=orasdb") ne 0) {
    subr->writeStderr('Error', "Section $senv_section senv not found");
    exit 1;
  }
} 


###################################################################### 
## write hash into /WORK/TMP/oracle.senv
###################################################################### 
subr->_printoraclesenv();


###################################################################### 
## replaces /DBA/nest/senv/local/oracle.senv with  /WORK/TMP/oracle.senv
###################################################################### 
subr->_replaceoraclesenv;


subr->writeStderr('INFO', "End:check $senv_section");


###################################################################### 
## replaces component specific /DBA/nest/oracle/<COMPONENT>/data/server.config, 
## depending on database role
###################################################################### 
my $skey = $senv_section;
$skey =~ s/\[|\]//g;
copy("/DBA/nest/oracle/".$skey."/data/".$database_role."server.config","/DBA/nest/oracle/".$skey."/data/server.config") or die "Copy failed: $!";


###################################################################### 
## Usage():
###################################################################### 
sub Usage()
{
  my $self=shift;

print <<EOT;
$script: Sets the NESTSUB_TYPE in oracle.senv depending on state of the database

  Valid options:
  --------------

  --s   <key>

EOT
  return 0;
}
