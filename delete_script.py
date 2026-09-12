import os

# Folder where this script is located
folder_path = os.path.dirname(os.path.abspath(__file__))

for root, dirs, files in os.walk(folder_path):
    for filename in files:
        if filename.lower() == "desktop.ini":
            file_path = os.path.join(root, filename)
            try:
                os.remove(file_path)
                print(f"Deleted {file_path}")
            except Exception as e:
                print(f"Error deleting {file_path}: {e}")
