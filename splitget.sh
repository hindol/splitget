# splitget.sh (Multipart file downloader)
#!/bin/bash

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

if [ -z "$output" ]
	then
	# Detect filename from URI
	output=$( echo $input | perl -MURI -le 'chomp($url = <>); $filename = (URI->new($url)->path_segments)[-1]; print $filename' )
fi

# Try to detect file size by inspecting HTTP header
detected_size=$( curl -I $input 2>|/dev/null | awk '/^Content-Length:/ { print $2 }' )

# If size can be detected from header, override size input
if [[ $detected_size != "" ]]
	then
	size=$detected_size
fi

if [[ $size != "" ]]
	then
	start=0
	end=$(( chunk_size - 1 ))
	counter=1
	while [ $start -le $size ]
	do
		if [ $end -gt $size ]
			then
			end=$size
		fi

		curl --range $start-$end -o $output.part$counter $input&

		start+=$chunk_size
		end+=$chunk_size
		counter+=1
	done

	# Kill background jobs on exit
	trap 'kill 0' SIGINT SIGTERM EXIT

	wait # Wait till all parts are downloaded

	# Merge parts into single file
	cat $output.part? > $output
	rm $output.part?
fi
