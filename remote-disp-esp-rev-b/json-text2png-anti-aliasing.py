# March 7th 2024 - Renee Jastram

# This is a quick adaptation of json-text2png.py to generate anti aliased text in PNGs
# Requres: `pip install Pillow`

# Input JSON files describing desired image text

# Output PNG files for use with png2bin.py
#   Next Step: python3 png2bin.py ./lisp/assets/texts/png ./lisp/assets/texts/bin indexed4

import json
import os
from PIL import Image, ImageDraw, ImageFont

# Directory paths
input_dir = './lisp/assets/texts/json/'
output_dir = './lisp/assets/texts/png/'

# Ensure output directory exists
os.makedirs(output_dir, exist_ok=True)

# Helper function to calculate image dimensions
def calculate_image_dimensions(lines, font, line_height):
    max_text_width = max([draw.textsize(line, font=font)[0] for line in lines])
    img_width = max_text_width + 2  # 1 pixel padding on each side
    img_height = len(lines) * line_height + 2  # 1 pixel padding on top and bottom
    return img_width, img_height

# Process each JSON file in the input directory
for file_name in os.listdir(input_dir):
    if file_name.endswith('.json'):
        try:
            # Construct the full file path
            file_path = os.path.join(input_dir, file_name)
            
            # Open and parse the JSON file
            with open(file_path, 'r') as file:
                settings = json.load(file)
                
            # Extract settings
            # TODO: align, width, font-weight ignored from JSON
            font_path = os.path.join("./lisp/assets/fonts", settings['font-file'])
            text = settings["text"]
            font_size = settings["font-size"]
            line_height_multiplier = float(settings["line-height"].strip('%')) / 100
            line_height = int(font_size * line_height_multiplier)  # Adjust line height directly based on font size and multiplier
            
            # Load the font
            font = ImageFont.truetype(font_path, font_size)
            
            # Split text into lines and create a dummy image to calculate text size
            lines = text.split('\n')
            dummy_img = Image.new('RGB', (1, 1), color=(0, 0, 0))
            draw = ImageDraw.Draw(dummy_img)
            
            # Calculate image dimensions based on text
            img_width, img_height = calculate_image_dimensions(lines, font, line_height)
            
            # Create the real image with adjusted dimensions
            img = Image.new('RGB', (img_width, img_height), color=(0, 0, 0))
            draw = ImageDraw.Draw(img)
            
            # Render text (center-aligned for simplicity)
            y = -1  # Start with 1 pixel padding from the top
            for line in lines:
                text_width, text_height = draw.textsize(line, font=font)
                x = (img_width - text_width) / 2  # Center the text
                draw.text((x, y), line, font=font, fill=(255, 255, 255))
                y += line_height  # Move to the next line
            
            # Save image to output folder
            output_path = os.path.join(output_dir, file_name.replace('.json', '.png'))
            img.save(output_path)
        except Exception as e:
            print(f"Error processing {file_name}: {e}")

print("All images have been generated.")