from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Header, Depends
from typing import List, Optional
import shutil
import os
import io
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload

app = FastAPI()

def get_drive_service(authorization: str = Header(...)):
    """
    Extracts the Bearer token from the Authorization header and builds the Drive service.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid Authorization header")
    
    token = authorization.split(" ")[1]
    creds = Credentials(token=token)
    try:
        service = build('drive', 'v3', credentials=creds)
        return service
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")

def check_or_create_root_folder(service, folder_name="My Doc"):
    """
    Checks if 'My Doc' folder exists. If not, creates it.
    Then ensures default subfolders ["Bills", "Notes", "Certificates", "Receipts"] exist.
    Returns the root folder ID.
    """
    try:
        # 1. Check/Create Root "My Doc"
        query = f"mimeType = 'application/vnd.google-apps.folder' and name = '{folder_name}' and trashed = false"
        results = service.files().list(q=query, fields="files(id, name)").execute()
        files = results.get('files', [])

        if files:
            root_id = files[0]['id']
        else:
            file_metadata = {
                'name': folder_name,
                'mimeType': 'application/vnd.google-apps.folder'
            }
            folder = service.files().create(body=file_metadata, fields='id').execute()
            root_id = folder['id']

        # 2. Check/Create Default Subfolders
        default_folders = ["Bills", "Notes", "Certificates", "Receipts"]
        for sub in default_folders:
            query = f"mimeType = 'application/vnd.google-apps.folder' and name = '{sub}' and '{root_id}' in parents and trashed = false"
            results = service.files().list(q=query, fields="files(id)").execute()
            if not results.get('files'):
                # Create subfolder
                print(f"Creating default folder: {sub}")
                file_metadata = {
                    'name': sub,
                    'parents': [root_id],
                    'mimeType': 'application/vnd.google-apps.folder'
                }
                service.files().create(body=file_metadata, fields='id').execute()
        
        return root_id

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error checking/creating root folder: {str(e)}")

@app.get("/")
def read_root():
    return {"message": "Google Drive Upload Backend Running"}

import img2pdf
from PIL import Image

@app.post("/upload")
async def upload_file(
    files: List[UploadFile] = File(...),
    folder_name: str = Form(...), # intended subfolder name
    folder_id: Optional[str] = Form(None), 
    service = Depends(get_drive_service)
):
    try:
        # 1. Get Root Folder "My Doc"
        root_id = check_or_create_root_folder(service)
        
        # 2. Determine target parent folder
        target_parent_id = root_id
        if folder_name != "My Doc":
            # Search for folder_name inside root_id
            query = f"mimeType = 'application/vnd.google-apps.folder' and name = '{folder_name}' and '{root_id}' in parents and trashed = false"
            results = service.files().list(q=query, fields="files(id, name)").execute()
            folders = results.get('files', [])
            
            if folders:
                 target_parent_id = folders[0]['id']
            else:
                # Create subfolder inside My Doc
                file_metadata = {
                    'name': folder_name,
                    'parents': [root_id],
                    'mimeType': 'application/vnd.google-apps.folder'
                }
                subfolder = service.files().create(body=file_metadata, fields='id').execute()
                target_parent_id = subfolder['id']

        uploaded_files_info = []

        # 3. Check if we should convert to PDF
        # Helper to check if file is image
        def is_image(file: UploadFile):
             if file.content_type.startswith('image/'):
                 return True
             ext = os.path.splitext(file.filename)[1].lower()
             return ext in ['.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp']

        # Condition: More than 0 files, and ALL are images
        is_all_images = len(files) > 0 and all(is_image(f) for f in files)
        
        if is_all_images:
            # Convert to PDF
            print("Detected images (count: {}), converting to PDF...".format(len(files)))
            image_bytes_list = []
            
            # Use the name of the first image for the PDF name, or current timestamp
            pdf_name = f"{os.path.splitext(files[0].filename)[0]}_merged.pdf"

            for file in files:
                content = await file.read()
                # Ensure valid image using Pillow (optional but good for validation)
                # img = Image.open(io.BytesIO(content))
                # img.verify() 
                image_bytes_list.append(content)
            
            # Convert
            pdf_bytes = img2pdf.convert(image_bytes_list)
            
            # Upload PDF
            media = MediaIoBaseUpload(io.BytesIO(pdf_bytes), mimetype='application/pdf', resumable=True)
            file_metadata = {'name': pdf_name, 'parents': [target_parent_id]}
            
            uploaded_file = service.files().create(
                body=file_metadata, 
                media_body=media, 
                fields='id, name, mimeType, webViewLink, thumbnailLink'
            ).execute()
            
            uploaded_files_info.append({
                "id": uploaded_file.get('id'),
                "name": uploaded_file.get('name'),
                "type": "file", # PDF is always a file
                "webViewLink": uploaded_file.get('webViewLink'),
                "thumbnailLink": uploaded_file.get('thumbnailLink')
            })
            
        else:
            # Upload individually
            for file in files:
                file_content = await file.read()
                media = MediaIoBaseUpload(io.BytesIO(file_content), mimetype=file.content_type, resumable=True)
                file_metadata = {'name': file.filename, 'parents': [target_parent_id]}
                
                uploaded_file = service.files().create(
                    body=file_metadata, 
                    media_body=media, 
                    fields='id, name, mimeType, webViewLink, thumbnailLink'
                ).execute()
                
                f_type = "folder" if uploaded_file.get('mimeType') == 'application/vnd.google-apps.folder' else "file"
                uploaded_files_info.append({
                    "id": uploaded_file.get('id'),
                    "name": uploaded_file.get('name'),
                    "type": f_type,
                    "webViewLink": uploaded_file.get('webViewLink'),
                    "thumbnailLink": uploaded_file.get('thumbnailLink')
                })

        return {
            "status": "success", 
            "uploaded": uploaded_files_info,
            "target_folder": folder_name
        }
    except Exception as e:
        print(f"Error in upload: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/create_folder")
def create_folder(
    folder_name: str = Form(...), 
    parent_folder: Optional[str] = Form("My Doc"),
    service = Depends(get_drive_service)
):
    try:
        # Ensure Root Exists
        root_id = check_or_create_root_folder(service)
        
        parent_id = root_id
        # If parent_folder is specified and is NOT "My Doc", find it inside My Doc. 
        # (This logic implies valid depth 1. Nested folders might need recursive search, keeping it simple for now).
        if parent_folder and parent_folder != "My Doc":
             query = f"mimeType = 'application/vnd.google-apps.folder' and name = '{parent_folder}' and '{root_id}' in parents and trashed = false"
             results = service.files().list(q=query, fields="files(id, name)").execute()
             folders = results.get('files', [])
             if folders:
                 parent_id = folders[0]['id']
             else:
                 # Fallback: Create the parent folder first? Or just error? 
                 # Let's default to root if parent not found to prevent crash, or creating 'parent_folder' inside root.
                 # Creating 'parent_folder' inside root:
                 file_metadata = {'name': parent_folder, 'parents': [root_id], 'mimeType': 'application/vnd.google-apps.folder'}
                 p_folder = service.files().create(body=file_metadata, fields='id').execute()
                 parent_id = p_folder['id']

        file_metadata = {
            'name': folder_name,
            'parents': [parent_id],
            'mimeType': 'application/vnd.google-apps.folder'
        }
        folder = service.files().create(body=file_metadata, fields='id, name, webViewLink').execute()
        
        return {
            "status": "success",
            "folder": {
                "id": folder.get('id'),
                "name": folder.get('name'),
                "type": "folder",
                "webViewLink": folder.get('webViewLink'),
                "thumbnailLink": None
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/files")
def list_files(
    folder_name: Optional[str] = "My Doc",
    service = Depends(get_drive_service)
):
    try:
        root_id = check_or_create_root_folder(service)
        
        target_id = root_id
        if folder_name != "My Doc":
             query = f"mimeType = 'application/vnd.google-apps.folder' and name = '{folder_name}' and '{root_id}' in parents and trashed = false"
             results = service.files().list(q=query, fields="files(id, name)").execute()
             folders = results.get('files', [])
             if folders:
                 target_id = folders[0]['id']
             else:
                 return {"files": []} # Folder not found, empty list
        
        # List files in target_id
        query = f"'{target_id}' in parents and trashed = false"
        results = service.files().list(q=query, fields="files(id, name, mimeType, webViewLink, thumbnailLink)").execute()
        files = results.get('files', [])
        
        # Format for frontend
        formatted_files = []
        for f in files:
            f_type = "folder" if f['mimeType'] == 'application/vnd.google-apps.folder' else "file"
            
            # Use a default icon for folder if thumbnail is missing, or whatever logic you prefer
            formatted_files.append({
                "id": f['id'], 
                "name": f['name'], 
                "type": f_type,
                "webViewLink": f.get('webViewLink'),
                "thumbnailLink": f.get('thumbnailLink')
            })
            
        return {"files": formatted_files}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/delete/{file_id}")
def delete_file(file_id: str, service = Depends(get_drive_service)):
    try:
        service.files().delete(fileId=file_id).execute()
        return {
            "status": "success",
            "deleted_id": file_id,
            "message": "File deleted successfully"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/rename/{file_id}")
def rename_file(
    file_id: str, 
    new_name: str = Form(...),
    service = Depends(get_drive_service)
):
    try:
        file_metadata = {'name': new_name}
        updated_file = service.files().update(
            fileId=file_id, 
            body=file_metadata,
            fields='id, name, mimeType, webViewLink, thumbnailLink'
        ).execute()
        
        return {
            "status": "success",
            "id": updated_file.get('id'),
            "name": updated_file.get('name')
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
