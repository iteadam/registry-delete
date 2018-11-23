# registry-delete
Simple interactive script to delete images from a docker registry with HTTPS and Basic auth. It can list images and tags to make this easier.

This was made for internal use but open sourced as it might be useful for others as well.

## Installation
Download the bash script, make it executable and run it. It requires bash, curl, awk and jq.

Keep in mind that you need to enable delete on the registry in order for this to work (it's disabled by default).

## Contribution
Since this was primarily made for internal use with our specific setup we're not really interested in making it more general. But bug fixes are welcome.
