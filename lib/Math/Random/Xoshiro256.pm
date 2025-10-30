package Math::Random::Xoshiro256;
use strict;
use warnings;
use v5.10;
use Carp qw(croak);
use Config;

# https://pause.perl.org/pause/query?ACTION=pause_operating_model#3_5_factors_considering_in_the_indexing_phase
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Math::Random::Xoshiro256', $VERSION);

# Check if the UV (unsigned value) Perl type is 64bit
my $has_64bit = ($Config{uvsize} == 8);

if (!$has_64bit) {
	croak("This module requires 64bit ints");
}

sub new {
	my ($class, $opts) = @_;
	my $self = Math::Random::Xoshiro256::_xs_new($class);

	# Check if the user passed any seeds into the constructor
	if (exists $opts->{seed}) {
		my $seed = $opts->{seed};
		$self->seed($seed);
	} elsif (exists $opts->{seed4}) {
		my @seeds = @$opts->{seeds};
		$self->seed4(@seeds);
	} else {
		$self->auto_seed;
	}

	return $self;
}

sub auto_seed {
	my ($self) = @_;

	# Get 32 bytes worth of random bytes and build 4x uint64_t seeds from them
	my $bytes = os_random_bytes(4 * 8);
	my @seeds = unpack('Q4', $bytes);

	$self->seed4(@seeds);
}

# Fetch random bytes from the OS supplied method
# /dev/urandom = Linux, Unix, FreeBSD, Mac, Android
# Windows requires the Win32::API call to call RtlGenRandom()
sub os_random_bytes {
	my $count  = shift();
	my $ret    = "";

	if ($^O eq 'MSWin32') {
		require Win32::API;

		state $rand = Win32::API->new(
			'advapi32',
			'INT SystemFunction036(PVOID RandomBuffer, ULONG RandomBufferLength)'
		) or croak("Could not import SystemFunction036: $^E");

		$ret = chr(0) x $count;
		$rand->Call($ret, $count) or croak("Could not read from csprng: $^E");
	} elsif (-r "/dev/urandom") {
		open my $urandom, '<:raw', '/dev/urandom' or croak("Couldn't open /dev/urandom: $!");

		sysread($urandom, $ret, $count) or croak("Couldn't read from csprng: $!");
	} else {
		croak("Unknown operating system $^O");
	};

	if (length($ret) != $count) {
		croak("Unable to read $count bytes from OS");
	}

	return $ret;
}

sub shuffle_array {
    my ($self, @array) = @_;

	# Make a copy of the array to shuffle
    my @shuffled = @array;
    my $n        = scalar(@shuffled);

	# Shuffle the array using the Fisher-Yates algorithm
	for (my $i = $n - 1; $i > 0; $i--) {
        my $j = $self->random_int(0, $i);
        @shuffled[$i, $j] = @shuffled[$j, $i] if $i != $j;
    }

	return @shuffled;
}

sub random_elem {
    my ($self, @array) = @_;
    return undef unless @array;
    my $idx = $self->random_int(0, $#array);
    return $array[$idx];
}

sub random_bytes {
    my ($self, $num) = @_;

    croak("random_bytes: positive number required") unless defined $num && $num > 0;

	# Get random bytes until we have the desired number
    my $bytes = '';
    while (length($bytes) < $num) {
        my $rand64 = $self->rand64;
        $bytes .= pack('Q<', $rand64); # little endian for each 64-bit chunk
    }

    return substr($bytes, 0, $num);
}

sub random_float {
    my ($self) = @_;

	# Get a random 64-bit integer and convert it to a float in [0,1]
    my $u64   = $self->rand64;
	my $top53 = $u64 >> 11;

    my $ret   = $top53 / (2**53);

	return $ret;
}

1;
__END__

=head1 NAME

Math::Random::Xoshiro256 - XS wrapper for xoshiro256+ PRNG

=head1 SYNOPSIS

  use Math::Random::Xoshiro256;
  my $rng = Math::Random::Xoshiro256->new();

  my $rand   = $rng->rand64();
  my $int    = $rng->random_int(10, 20);   # non-biased integer in [10, 20]
  my $bytes  = $rng->random_bytes(16);     # 16 random bytes from PRNG
  my $float  = $rng->random_float();       # float in [0, 1] inclusive

  my @arr       = ('red', 'green', 'blue', 'yellow', 'purple');
  my $rand_item = $rng->random_elem(@arr);
  my @mixed     = $rng->shuffle_array(@arr);

=head1 METHODS

=over

=item rand64
Return an unsigned 64-bit random integer.

=item random_int($min, $max)
Return a random integer (non-biased) in [$min, $max] inclusive.

=item shuffle_array(@array)
Returns a shuffled list using the Fisher-Yates algorithm with the PRNG instance. Input array is not modified.

=item random_elem(@array)
Returns a single random element from the given array (returns undef if array is empty).

=item random_bytes($num)
Returns $num random bytes.

=item random_float
Returns a float in the interval [0, 1] inclusive.

=back

=cut
