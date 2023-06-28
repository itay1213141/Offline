#!/bin/sh

# Set default values
DEFAULT_OUTPUT_DIR="$HOME/Offline"

# Parse arguments
TYPE=$1
NAME=$2
OUTPUT_DIR=$3

if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR=$DEFAULT_OUTPUT_DIR
fi

# Function to save image as tar.gz
save_image() {
  local full_image_name="$1"
  local image_name=$(basename "$full_image_name" | cut -d':' -f1) 

  # Create output directory if it doesn't exist
  mkdir -p "${2:-OUTPUT_DIR}"
  
  local file_path="${2:-OUTPUT_DIR}/$image_name.tar.gz"

  # Pull the image, gzip, and save as tar.gz
  docker pull "$full_image_name"

  echo Saving image $(basename $full_image_name)
  docker save "$full_image_name" | gzip > "$file_path"

  echo "Image '$image_name' saved as '$file_path'"
}

if [ "$TYPE" = "image" ]; then
  # Set default values if not provided
  if [ -z "$NAME" ]; then
    echo "Image name is required"
    exit 1
  fi

  save_image "$NAME"

elif [ "$TYPE" = "chart" ]; then
  if [ -z "$NAME" ]; then
    echo "No path specified, using $(pwd)"
    NAME=$(pwd)
  fi

  FILE_NAME="$OUTPUT_DIR/$(basename $NAME).tar.gz"

  # Run helm dependency update
  helm dependency update "$NAME"

  # Run helm template and grep for image instances
  helm template "$NAME" | grep -Eo 'image: .*' | cut -d' ' -f2 | sed 's/"//g' | uniq | while read -r IMAGE; do
    save_image "$IMAGE" $NAME/images
  done

  # Zip the entire folder with resolved dependencies and saved images
  cd "$NAME" || exit
  tar -czf "$FILE_NAME" ./*
  echo "Chart folder '$NAME' and images saved as '$FILE_NAME'"

elif [ "$TYPE" = "clear" ]; then
  rm -rf "$DEFAULT_OUTPUT_DIR"/**
  echo "Folder $DEFAULT_OUTPUT_DIR cleared successfully"

elif [ "$TYPE" = "help" ]; then
  echo "Usage: $0 <type> <name/path> [output directory]"
  echo ""
  echo "Commands:"
  echo "  image <name>            : Pull an image, gzip it, and save as a tar.gz file"
  echo "  chart <name/path>       : Run helm dependency update, extract and save images, zip the folder"
  echo "  clear                   : Clear the default output directory ($DEFAULT_OUTPUT_DIR)"
  echo "  help                    : Print this help message"

else
  echo "Invalid type. Please specify 'chart', 'image', 'clear', or 'help'."
  exit 1
fi
