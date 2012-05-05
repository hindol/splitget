#!/bin/bash
# splitget.sh (Multipart file downloader)

# Command line arguments
# -i < url to download >
# -o < output filename >
# -p < [user:pass@]proxy[:port] >
# -s < approximate file size in bytes >
# -l < maximum chunk size in bytes >
# -m ? Download file in multiple chunks parallely

# Global variables used throughout this script
# $input     	The URL to download
# $output    	Output filename
# $proxy     	The proxy to be used for making all connections
# $size      	File size of the target URL
# $chunk_size	How large each chunk should be (default 150MB)
# $parallel  	Download chunks parallely (if set) / sequentially (if not set)?

function readArgs() {
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
				echo "${usage}"
				;;
		esac
	done
}

function setDefaults() {
	: ${proxy=$http_proxy}
	: ${chunk_size=157286400}
	: ${parallel="off"}

	if [[ -z "${output}" ]]; then
		# Detect filename from URI
		output=$( echo ${input} | perl -MURI -le 'chomp($url = <>); ${filename} = (URI->new(${url})->path_segments)[-1]; print ${filename}' )
	fi

	# Try to detect file size by inspecting HTTP header
	header=$( curl -I ${input} 2> /dev/null )
	detected_size=$( echo "${header}" | awk '/^Content-Length:/ { gsub("\015", "", $2); print $2 }' )

	# If size can be detected from header, override size input
	if [[ "${detected_size}" != "" ]]; then
		size=$detected_size
	fi
}

function cleanUp() {
	# Clean up temporary files
	for file in $output.part*; do
		if [[ -e ${file} ]]; then
			rm ${file}
		fi
	done
}

function abort() {
	kill $(jobs -pr)
	cleanUp # Cleanup temporary files

	# Clean output file if exists
	if [[ -e ${output} ]]; then
		rm ${output}
	fi

	exit
}

readArgs "$@"	# Read command line inputs
setDefaults  	# Set defaults for unspecified inputs

if [[ "${input}" != "" && "${size}" != "" ]]; then
	# Kill background jobs when interrupted
	trap 'cleanUp' EXIT
	trap 'abort' SIGINT

	chunks=$(( (size - 1) / chunk_size + 1 ))
	# Loop one time less than the number of chunks
	for (( i=1; i<chunks; i++ )); do
		start=$(( (i - 1) * chunk_size ))
		end=$(( start + chunk_size - 1 ))
		curl --range ${start}-${end} -o ${output}.part${i} ${input} &
	done

	start=$(( (chunks - 1) * chunk_size ))
	curl --range ${start}- -o ${output}.part${i} ${input} &

	wait # Wait till all parts are downloaded

	# Merge parts into single file
	cat ${output}.part* > ${output}
fi
