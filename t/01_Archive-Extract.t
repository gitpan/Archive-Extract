BEGIN { chdir 't' if -d 't' };

use strict;
use lib qw[../lib];

use Cwd                         qw[cwd];
use Test::More                  qw[no_plan];
use File::Spec; 
use File::Path;
use Data::Dumper;
use Module::Load::Conditional   qw[check_install];

my $Debug   = $ARGV[0] ? 1 : 0;

my $Class   = 'Archive::Extract';
my $Self    = File::Spec->rel2abs( cwd() );
my $SrcDir  = File::Spec->catdir( $Self,'src' );
my $OutDir  = File::Spec->catdir( $Self,'out' );     

use_ok($Class);

### set verbose if debug is on ###
### stupid stupid silly stupid warnings silly! ###
$Archive::Extract::VERBOSE  = $Archive::Extract::VERBOSE = $Debug;
$Archive::Extract::WARN     = $Archive::Extract::WARN    = $Debug ? 1 : 0;

my $tmpl = {
    ### plain files
    'x.tgz'     => {    programs    => [qw[gzip tar]],
                        modules     => [qw[Archive::Tar IO::Zlib]],
                        method      => 'is_tgz',
                        outfile     => 'a',
                    },
    'x.tar.gz' => {     programs    => [qw[gzip tar]],
                        modules     => [qw[Archive::Tar IO::Zlib]],
                        method      => 'is_tgz',
                        outfile     => 'a',
                    },
    'x.tar' => {    programs    => [qw[tar]],
                    modules     => [qw[Archive::Tar]],
                    method      => 'is_tar',
                    outfile     => 'a',
                },
    'x.gz' => {     programs    => [qw[gzip]],
                    modules     => [qw[Compress::Zlib]],
                    method      => 'is_gz',
                    outfile     => 'a',
                },
    'x.zip' => {    programs    => [qw[unzip]],
                    modules     => [qw[Archive::Zip]],
                    method      => 'is_zip',
                    outfile     => 'a',
                },
    ### with a directory                
    'y.tgz'     => {    programs    => [qw[gzip tar]],
                        modules     => [qw[Archive::Tar IO::Zlib]],
                        method      => 'is_tgz',
                        outfile     => 'z',
                        outdir      => 'y'
                    },
    'y.tar.gz' => {     programs    => [qw[gzip tar]],
                        modules     => [qw[Archive::Tar IO::Zlib]],
                        method      => 'is_tgz',
                        outfile     => 'z',
                        outdir      => 'y'
                    },
    'y.tar' => {    programs    => [qw[tar]],
                    modules     => [qw[Archive::Tar]],
                    method      => 'is_tar',
                    outfile     => 'z',
                    outdir      => 'y'
                },
    'y.zip' => {    programs    => [qw[unzip]],
                    modules     => [qw[Archive::Zip]],
                    method      => 'is_zip',
                    outfile     => 'z',
                    outdir      => 'y'
                },                
};                


for my $switch (0,1) {
    local $Archive::Extract::PREFER_BIN = $switch;
    diag("Running extract with PREFER_BIN = $Archive::Extract::PREFER_BIN")
        if $Debug;   
    
    
    for my $archive (keys %$tmpl) {    
    
        diag("Extracting $archive") if $Debug;
        
        ### check first if we can do the proper
        
        my $ae = Archive::Extract->new(
                        archive => File::Spec->catfile($SrcDir,$archive) );
    
        isa_ok( $ae, $Class );
    
        my $method = $tmpl->{$archive}->{method};
        ok( $ae->$method(),         "Archive type recognized properly" );
    
    ### 10 tests from here on down ###
    SKIP: {
        my $file        = $tmpl->{$archive}->{outfile};
        my $dir         = $tmpl->{$archive}->{outdir};  # can be undef
        my $rel_path    = File::Spec->catfile( grep { defined } $dir, $file );
        my $abs_path    = File::Spec->catfile( $OutDir, $rel_path );
        my $abs_dir     = File::Spec->catdir( grep { defined } $OutDir, $dir );
                                            
        
        ### check if we can run this test ###
        my $pgm_fail; my $mod_fail;
        for my $pgm ( @{$tmpl->{$archive}->{programs}} ) {
            $pgm_fail++ unless $Archive::Extract::PROGRAMS->{$pgm} &&
                               $Archive::Extract::PROGRAMS->{$pgm}; 
                    
        }
        
        for my $mod ( @{$tmpl->{$archive}->{modules}} ) {
            $mod_fail++ unless check_install( module => $mod );
        }
        
        skip "No binaries or modules to extract ".$archive, 10
            if $mod_fail && $pgm_fail;
        
        
        for my $use_buffer (1,0) {

            ### test buffers ###
            my $turn_off = !$use_buffer &&!$pgm_fail &&                 
                            $Archive::Extract::PREFER_BIN;
                           
            ### whitebox test ###
            ### stupid warnings ###
            local $IPC::Cmd::USE_IPC_RUN    = 0 if $turn_off;
            local $IPC::Cmd::USE_IPC_RUN    = 0 if $turn_off;
            local $IPC::Cmd::USE_IPC_OPEN3  = 0 if $turn_off;
            local $IPC::Cmd::USE_IPC_OPEN3  = 0 if $turn_off;
            
            ### try extracting ###
            my $to = $ae->is_gz ? $abs_path : $OutDir;

            diag("Extracting to: $to")                  if $Debug;
            diag("Buffers enabled: ".!$turn_off)        if $Debug;

            my $rv = $ae->extract( to => $to );
            
            ok( $rv,                "extract() for '$archive' reports success");
        
            diag("Extractor was: " . $ae->_extractor)   if $Debug;
 
            SKIP: {
                skip "No buffers available", 6,
                    if $ae->error =~ /^No buffer captured/;

                ### might be 1 or 2, depending wether we extracted a dir too
                my $file_cnt = grep { defined } $file, $dir;                    
                is( scalar @{ $ae->files || []}, $file_cnt,
                                    "Found correct number of output files" );
                is( $ae->files->[-1], $rel_path,
                                    "Found correct output file '$rel_path'" );
            
                ok( -e $abs_path,   "Output file '$abs_path' exists" );
                ok( $ae->extract_path,
                                    "Extract dir found" );
                ok( -d $ae->extract_path,
                                    "Extract dir exists" );                       
                is( $ae->extract_path, $abs_dir,
                                    "Extract dir is expected path '$abs_dir'" );
            }
        
            unlink $abs_path;
            ok( !(-e $abs_path),     "Output file successfully removed" );

            eval { rmtree( $ae->extract_path ) };
            ok( !$@,                "   rmtree gave no error" );
            ok( !(-d $ae->extract_path ),
                                    "   Extracth dir succesfully removed" );
        }            
    } }
}



