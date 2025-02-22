import os, io, json
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
from googleapiclient.errors import HttpError



####################################
# Get AOI list from Local Folders  #
####################################
# To get root path under project folder structure
cwd = os.path.dirname(os.path.abspath("__file__"))
root_folder = cwd.split('\\')
root_folder = root_folder[1:-2]
if root_folder[-1] != 'fireRunSeverity':
    print("!!-- Didn't get correct root folder! --!!")
    print(root_folder)
    print("!!-- Modify rooting index at line: 18 and come back --!!")
root_folder = os.path.join('C:\\', *root_folder)

# Local Side data
# List in put data for GEE fetch
run_DataDir = r"data/fireruns"
AOI_lst = os.listdir(os.path.join(root_folder,run_DataDir))



####################################
# Connection with Google Drive API #
####################################
# Set up the Drive API client
# If modifying these scopes, delete the file token.json.
SCOPES = ["https://www.googleapis.com/auth/drive.readonly"]
creds = None

# The file 'credentials.json' should be downloaded from Google Cloud Console
cred_js_path = os.path.join(root_folder, 'Python/geeFetch/.credential.json')
token_js_path = os.path.join(root_folder, 'Python/geeFetch/.token.json')


# Set up connection token or regenerate a new one
if os.path.exists(token_js_path):
    # Check if `SCOPES` is modified
    with open(token_js_path, 'r') as file:
        data = json.load(file)
    
    if SCOPES != data['scopes']:
        print("SCOPES changed!")
        os.remove(token_js_path)
    else:
        # SCOPES are consistent, reading token file
        creds = Credentials.from_authorized_user_file(token_js_path, SCOPES)
    
if not creds or not creds.valid:
    # If creds not exists then delete the toke file and re-fetch it from the website
    if os.path.exists(token_js_path):
      os.remove(token_js_path)
    flow = InstalledAppFlow.from_client_secrets_file(
        cred_js_path, SCOPES
    )
    creds = flow.run_local_server(port=0)
    # Save the credentials for the next run
    with open(token_js_path, "w") as token:
      token.write(creds.to_json())


############################################
# Parse Google Drive API to see file lists #
############################################
try:
    service = build("drive", "v3", credentials=creds)

    # Call the Drive v3 API
    results = (
        service.files()
        .list(pageSize=100, fields="nextPageToken, files(id, name)")
        .execute()
    )
    items = results.get("files", [])

    if not items:
      print("No files found.")
      exit()
    print("Files:")
    
    # Match file in the selected AOI
    items_filt = []
    for item in items:
      if item['name'].split("--")[0] == "PythonGEE_output":
         print(f"{item['name']} ({item['id']})")
         items_filt.append(item)
except HttpError as error:
    print(f"An error occurred: {error}")


############################################
#   Download files according to AOI_lst    #
############################################
print("\n\n !---- Start Downloading ----!\n")
for in_Name in AOI_lst:
    print("#------------------------------#")
    print("AOI:", in_Name)
    ### Folder ### 
    # Check Folder exists
    outGEEFLD = os.path.join(root_folder, 'data', 'GEE', in_Name)
    if os.path.isdir(outGEEFLD):
        print('Folder', in_Name, 'exist!')
        pass
    else:
        os.mkdir(outGEEFLD)

    # Run for each tif in list
    for item in items_filt:
        if item['name'].split("--")[1] == in_Name:
            ### Connection ###    
            # Request the file metadata to get the name
            file = service.files().get(fileId=item['id']).execute()
            print("\nFound online file:", file['name'])

            ### Download ###
            # Download the file
            out_file_name = "--".join(item['name'].split("--")[2:]) # delete AOI recognizing string
            out_file_name = os.path.join(outGEEFLD, out_file_name)
            if os.path.exists(out_file_name):
                print('!--', os.path.basename(out_file_name), 'exists!')
                continue
            else:
                request = service.files().get_media(fileId=item['id'])
                fh = io.FileIO(out_file_name, 'wb')
                downloader = MediaIoBaseDownload(fh, request)
                done = False
                while done is False:
                    status, done = downloader.next_chunk()
                    print(f"Download {int(status.progress() * 100)}%.")
    print("#------------------------------#\n\n")
