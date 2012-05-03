#!/bin/bash
# splitget.sh (Multipart file downloader)

# Command line arguments
# -i < url to download >
# -o < output filename >
# -p < [user:pass@]proxy[:port] >
# -s < approximate file size in bytes >
# -l < maximum chunk size in bytes >
# -m ? Download file in multiple chunks parallely

while getopts "i:o:p:s:l:m" OPTION; do
	case "$OPTION" in
		i)
			input="$OPTARG"
			;;
		o)
			output="$OPTARG"
			;;
		p)
			proxy="$OPTARG"
			;;
		s)
			size="$OPTARG"
			;;
		l)
			chunk_size="$OPTARG"
			;;
		m)
			parallel="on"
			;;
		*)
			echo "Unrecognized option!"
			echo "$usage"
			;;
	esac
done

# Set default values
: ${proxy=$http_proxy}
: ${chunk_size=157286400}
: ${parallel="off"}

if [ -z "$output" ]; then
	# Detect filename from URI
	output=$( echo $input | perl -MURI -le 'chomp($url = <>); $filename = (URI->new($url)->path_segments)[-1]; print $filename' )
fi

# Try to detect file size by inspecting HTTP header
header=$( curl -I $input 2> /dev/null )
detected_size=$( echo "$header" | awk '/^Content-Length:/ { print $2 }' | tr -d '\r' )

# If size can be detected from header, override size input
if [ "$detected_size" != "" ]; then
	size=$detected_size
fi

if [ "$size" != "" ]; then
	# Kill background jobs on exit
	trap 'kill 0' SIGINT SIGTERM EXIT

	chunks=$(( $size / $chunk_size + 1 ))
	# Loop one time less than the number of chunks
	for (( i=1; i<chunks; i++ )); do
		start=$(( (i - 1) * chunk_size ))
		echo $start
		end=$(( start + chunk_size - 1 ))
		echo $end
		curl --range $start-$end -o $output.part$i $input&
	done

	start=$(( (chunks - 1) * chunk_size ))
	echo $start
	curl --range $start- -o $output.part$i $input&

	wait # Wait till all parts are downloaded

	# Merge parts into single file
	cat $output.part* > $output
	rm $output.part*
fi
