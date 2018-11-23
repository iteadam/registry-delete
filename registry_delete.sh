#!/bin/bash

function check_prereqs {
  if ! [[ -x "$(type -P curl)" ]]; then
    echo >&2 "Error: curl not found."
    exit 10
  fi

  if ! [[ -x "$(type -P awk)" ]]; then
    echo >&2 "Error: awk not found."
    exit 10
  fi

  if ! [[ -x "$(type -P jq)" ]]; then
    echo >&2 "Error: jq not found."
    exit 10
  fi
}

function prompt_repo_values {
  echo -n 'reposity url: '
  read repo_url
  if [[ -z "$repo_url" ]]; then
    echo >&2 "Error: You need to enter a repository url"
    exit 20
  fi
  repo_url="https://$repo_url"

  echo -n 'username: '
  read username
  if [[ -z "$username" ]]; then
    echo >&2 "Error: You need to enter a username"
    exit 20
  fi

  echo -n 'password: '
  read -s password
  if [[ -z "$password" ]]; then
    echo >&2 "Error: You need to enter a password"
    exit 20
  fi
  printf '\n\n'
}

function print_help {
  echo "images - List images in the registry
image <image> - Select the image to delete a layer from
tags - List tags for the selected image
tag <tag> - Select the tag to delete
delete - Delete the selected tag from the selected image
quit - Exit this program
"
}

function list_images {
  local catalog_raw
  catalog_raw="$(curl --fail --user $username:$password -X GET -sS $repo_url/v2/_catalog)"
  if (( $? )); then
    echo >&2 "Error: Could not get catalog."
    return 1
  fi

  local repositories
  repositories="$(printf "%s" "$catalog_raw" | jq -r '.repositories')"
  if (( $? )); then
    echo >&2 "Error: Could not parse response."
    return 1
  fi

  printf "%s\n" "$repositories"
}

function list_tags {
  if [[ -z "$selected_image" ]]; then
    echo >&2 "Error: No image selected"
    return 1
  fi

  local tags_raw
  tags_raw="$(curl --fail --user $username:$password -X GET -sS $repo_url/v2/$selected_image/tags/list)"
  if (( $? )); then
    printf >&2 "Error: Could not get tags for %s.\n" "$selected_image"
    return 1
  fi

  local tags
  tags="$(printf "%s" "$tags_raw" | jq -r '.tags')"
  if (( $? )); then
    echo >&2 "Error: Could not parse response."
    return 1
  fi

  printf "%s\n" "$tags"
}

function delete_image {
  if [[ -z "$selected_image" || -z "$selected_tag" ]]; then
    echo >&2 "Error: You must first select an image and a tag to delete."
    return 1
  fi

  local headers
  headers="$(curl --fail --user $username:$password -I -sS -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' $repo_url/v2/$selected_image/manifests/$selected_tag)"
  if (( $? )); then
    printf >&2 "Error: Could not get manifest for %s:%s.\n" "$selected_image" "$selected_tag"
    return 1
  fi
  local image_digest
  image_digest="$(printf "%s" "$headers" | awk '/^docker-content-digest: / { printf "%s", $2 }')"
  image_digest=${image_digest//$'\r'} # strip carriage return
  if [[ -z image_digest ]]; then
    echo >&2 "Error: Could not get content digest."
    return 1
  fi

  printf "Are you sure you want to DELETE %s:%s from %s? (y/n): " "$selected_image" "$selected_tag" "$repo_url"
  local answer
  read answer
  if [[ "$answer" == 'y' ]]; then
    curl --fail --user "$username":"$password" -X DELETE -sS "$repo_url/v2/$selected_image/manifests/$image_digest"
    if (( $? )); then
      echo >&2 "Error: Delete failed."
      return 1
    fi
    echo "Image deleted."
  else
    echo "Delete aborted."
  fi
}
# -------- entry point here ---------
check_prereqs
prompt_repo_values

while :; do
  echo 'Enter command (help, images, image <image>, tags, tag <tag>, delete, quit)'
  read command argument
  case "$command" in
    'help')
      print_help
      ;;
    'images')
      list_images
      ;;
    'image')
      if [[ -z "$argument" ]]; then
        echo 'Please specify an image'
      else
        selected_image="${argument//' '}"
      fi
      ;;
    'tags')
      list_tags
      ;;
    'tag')
      if [[ -z "$argument" ]]; then
        echo 'Please specify a tag'
      else
        selected_tag="${argument//' '}"
      fi
      ;;
    'delete')
      delete_image
      ;;
    'quit' | 'exit')
      echo 'Bye!'
      exit 0
      ;;
    *)
      echo 'Invalid command'
      ;;
  esac
  command=''
  argument=''
done
