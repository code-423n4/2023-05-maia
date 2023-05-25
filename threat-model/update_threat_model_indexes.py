import os
import re

def read_file_lines(file_path):
    with open(file_path, 'r') as file:
        return file.readlines()

def write_to_file(file_path, content):
    with open(file_path, 'w') as file:
        file.write(content)

def process_line(line):
    header = line[2:].strip()
    index_name = header.replace("Function: ", "").replace("`", "")
    # Remove formatting and punctuation, make lowercase, replace spaces with hyphens
    link_header = re.sub(r'\W+', '-', header.lower().replace('`', '').replace('(', '').replace(')', ''))
    return index_name, link_header

def is_secondary_header(line):
    return line.startswith("## ")

def generate_file_index(directory):
    for root, dirs, files in os.walk(directory):
        for file_name in files:
            if file_name.endswith(".md"):
                file_path = os.path.join(root, file_name)
                lines = read_file_lines(file_path)

                index_lines = []
                for line in lines:
                    if is_secondary_header(line):
                        (index_name, link_header) = process_line(line)

                        index_line = f"- [{index_name}](#{link_header})"
                        index_lines.append(index_line)

                if index_lines:
                    index_content = "\n".join(index_lines) + "\n"
                    updated_lines = remove_previous_index(lines)
                    updated_lines.insert(2, index_content)  # Insert index as the third line

                    write_to_file(file_path, "".join(updated_lines))
                    print(f"Generated index for file: {file_path}")

def remove_previous_index(lines):
    updated_lines = []
    in_index = True
    for line in lines:
        if is_secondary_header(line):
            in_index = False
        if in_index and line.startswith("-"):
            continue
        updated_lines.append(line)
    return updated_lines

def clear_existing_indices(start_directory):
    for root, dirs, files in os.walk(start_directory):
        if "README.md" in files:
            readme_path = os.path.join(root, "README.md")
            with open(readme_path, 'r') as readme_file:
                lines = readme_file.readlines()

            # Check if "### Index" is in the file
            if any("### Index" in line for line in lines):
                # If "### Index" is in the file, remove the content after it
                existing_content = ""
                for line in lines:
                    if line.strip() == "### Index":
                        existing_content += "### Index\n\n"
                        break
                    existing_content += line

                # Write back the content before "### Index" to the README.md file
                write_to_file(readme_path, "".join(existing_content))
            else:
                # If "### Index" is not in the file, delete the file
                os.remove(readme_path)

def create_all_indices(start_directory):
    index_lines = []
    # Read the content of the existing README.md file up to the "### Index" header
    readme_path = os.path.join(start_directory, "README.md")
    existing_content = read_content_up_to_index(readme_path) if os.path.exists(readme_path) else "### Index\n\n"

    index_lines = create_index_tree(start_directory, start_directory)

    # Write the existing content and the new index to the README.md file
    if index_lines:
        index_content = existing_content + "\n".join(index_lines)
        write_to_file(readme_path, "".join(index_content))
        print(f"Generated index for directory: {start_directory}")

def read_content_up_to_index(file_path):
    content = ""
    for line in read_file_lines(file_path):
        if line.strip() == "### Index":
            content += "### Index\n\n"
            break
        content += line
    return content

def create_index_tree(directory, start_directory, depth=0):
    index_lines = []

    # Generate the index as before
    for item in os.listdir(directory):
        item_path = os.path.join(directory, item)
        rel_path = os.path.relpath(item_path, start_directory)

        if os.path.isdir(item_path):  # If item is a directory
            dir_name = os.path.basename(item_path)
            index_line = f"{'  ' * depth}- [{dir_name}]({rel_path})"
            index_lines.append(index_line)

            # Call the function recursively for the subdirectory to get its index
            index_lines.extend(create_index_tree(item_path, start_directory, depth + 1))
            # Call the function recursively for the subdirectory to create its index
            create_all_indices(item_path)

        elif item.endswith(".md") and item != "README.md":
            file_path = item_path
            file_index = generate_index_tree(file_path, depth + 1, start_directory)

            link_name = os.path.splitext(item)[0]  # Remove .md extension from link text
            index_line = f"{'  ' * depth}- [{link_name}]({rel_path})\n{file_index}"
            index_lines.append(index_line)

    return index_lines

def generate_index_tree(file_path, depth, start_directory):
    lines = read_file_lines(file_path)

    index_lines = []
    for line in lines:
        if is_secondary_header(line):
            (index_name, link_header) = process_line(line)

            # Get the relative path to the file for the link
            rel_path = os.path.relpath(file_path, start_directory)
            index_line = f"{'  ' * depth}- [{index_name}]({rel_path}#{link_header})"
            index_lines.append(index_line)

    if index_lines:
        return "\n".join(index_lines)
    else:
        return ""

# Replace with threat-model directory path
destination_folder = './threat-model'

generate_file_index(destination_folder)

clear_existing_indices(destination_folder)
create_all_indices(destination_folder)
