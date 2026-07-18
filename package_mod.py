import os
import sys
import zipfile

def create_godot_zip(mod_id):
    zip_filename = f"{mod_id}.zip"
    source_dir = mod_id
    
    if not os.path.exists(source_dir):
        print(f"Error: Directory '{source_dir}' does not exist.")
        return
        
    if os.path.exists(zip_filename):
        os.remove(zip_filename)
        
    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as zf:
        # Godot requires explicit directory entries to mount VFS paths properly
        directories_added = set()
        
        for root, dirs, files in os.walk(source_dir):
            if '.git' in root:
                continue
                
            for file in files:
                if file.endswith('.zip'):
                    continue
                    
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, source_dir)
                archive_name = f"mods-unpacked/{mod_id}/{rel_path}".replace('\\', '/')
                
                # Add all parent directory entries
                parts = archive_name.split('/')
                for i in range(1, len(parts)):
                    dir_path = '/'.join(parts[:i]) + '/'
                    if dir_path not in directories_added:
                        zinfo = zipfile.ZipInfo(dir_path)
                        zf.writestr(zinfo, '')
                        directories_added.add(dir_path)
                
                zf.write(file_path, archive_name)
                
    print(f"Successfully created Godot-compatible {zip_filename}")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        for mod in sys.argv[1:]:
            create_godot_zip(mod)
    else:
        print("Usage: python package_mod.py <ModFolder1> <ModFolder2> ...")
