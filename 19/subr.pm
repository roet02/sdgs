package subr;

use DBI;
use DBD::Oracle qw(:ora_session_modes); # imports SYSDBA or SYSOPER
use File::Copy;
use File::Compare;

######################################################################
## writeStderr(): Write output to stderr
######################################################################
sub writeStderr
{
  my $self = shift;
  my $sev  = shift;
  my @msgs = @_;
  my $sub  = 'writeStderr()';

  my $line=shift @msgs;
  print STDERR "$sev - $line\n";

  foreach my $line (@msgs) {
    print STDERR " " x (length($sev)+3) . "$line\n";
  }
  return 1;
}


######################################################################
##
##  _check()
##  connect to database as sysdba and check and returns database role
##
######################################################################
sub _check {
  my $self = shift;
  my @result;
  my (@result,$database_role,$database_status,$database_open_mode);


  my $dbh = DBI->connect("dbi:Oracle:","sys","dbaASY_29",{ora_session_mode => ORA_SYSDBA});


  my $sql_stmt = "SELECT D.DATABASE_ROLE , D.OPEN_MODE FROM V\$DATABASE D";
  my $sth = $dbh->prepare($sql_stmt);

  $sth->execute( ) ; 
  
  while ( my @row = $sth->fetchrow_array ) {
    push(@result,\@row);
  }

  $database_role=$result[0][0];
  $database_open_mode=$result[0][1];


  $dbh->disconnect;

   
  if(($database_role eq "PRIMARY" and $database_open_mode eq "READ WRITE")){
    # $self->writeStderr('INFO ', "$self: Type is $database_role and open_mode is $database_open_mode ");
    return "PRIMARY";
  }

  if(($database_role eq "PHYSICAL STANDBY" and $database_open_mode eq "MOUNTED")){
    # $self->writeStderr('INFO ', "$self: Type is $database_role and open_mode is $database_open_mode ");
    return "STANDBY";
  }

  if(($database_role eq "PHYSICAL STANDBY" and $database_open_mode eq "READ ONLY WITH APPLY")){
    # $self->writeStderr('INFO ', "$self: Type is $database_role and open_mode is $database_open_mode ");
    return "STANDBY";
  }

  return "UNKNOWN";
}


###############################################################
## 
## _readoraclesenv():
## reads /DBA/nest/senv/local/oracle.senv into global hash HoH
## 
###############################################################
sub _readoraclesenv {
  my $self = shift;
  my $senvfile = "/DBA/nest/senv/local/oracle.senv";
  my $rc=0;
  my $rc_open="FALSE";



  $rc_open=open (my $FH, "<$senvfile");
  if ($rc_open ne 1) {
    $rc=1;
  }

  while (<$FH>) {
    if ( $_ =~ /(\[\S+\])/ .. /^$/ ) {
      ## keine leeren keys ##
      if ( $1 !~ /^$/ ) {
        chomp($_);
        push @{$HoH{$1}{secentry}},$_;
      }
    }
  }

  close($FH);

  return $rc;
}


###############################################################
## 
##  _printoraclesenv():
## prints hash HoH into file /WORK/TMP/oracle.senv
## 
###############################################################
sub _printoraclesenv {
  my $self = shift;
  my $section = shift;
  my $sectionkey;
  my $row;

  open (my $OUT, ">/WORK/TMP/oracle.senv.$$") or die "Could not open destination file. $!";

  print $OUT "USE global_oracle\n";
  print $OUT "\n";
  

  for $sectionkey (sort keys %HoH ) {

    for ($row=0; $row < scalar(@{$HoH{$sectionkey}{secentry}}); $row++) {
      # printf("%02d:%s:%s\n",$row, $sectionkey, @{$HoH{$sectionkey}{secentry}}[$row]);
      print $OUT @{$HoH{$sectionkey}{secentry}}[$row]. "\n";
    }
    print $OUT "\n";

  }

  close($OUT);

}


###############################################################
## 
## _findreplace():
## search and replace in hash HoH
## 
###############################################################
sub _findreplace {
  my $self = shift;
  my $section = shift;
  my $find    = shift;
  my $replace = shift;
  my $sectionkey;
  my $row;
  my $rc=1;
    
  for $sectionkey (sort keys %HoH ) {
    if ( $sectionkey eq $section ) {
      $rc=0; ## found section
      for ($row=0; $row < scalar(@{$HoH{$sectionkey}{secentry}}); $row++) {
        if ( @{$HoH{$sectionkey}{secentry}}[$row] =~ /$find/ ) {           
           @{$HoH{$sectionkey}{secentry}}[$row] =~ s/$find/$replace/g;
           $self->writeStderr('INFO   ', "Replace $find => $replace in Section $section ");
        }
      } 
    } 
  }
  return $rc;
}


###############################################################
## 
## _replaceoraclesenv():
## replaces /DBA/nest/senv/local/oracle.senv with /WORK/TMP/oracle.senv
## 
###############################################################
sub _replaceoraclesenv {

  if (compare("/WORK/TMP/oracle.senv.$$","/DBA/nest/senv/local/oracle.senv") != 0) {
    copy("/WORK/TMP/oracle.senv.$$","/DBA/nest/senv/local/oracle.senv") or die "Copy failed: $!";
   } else {
    unlink("/WORK/TMP/oracle.senv.$$") or die "Could not delete the file!\n";
  }

}


1; 
