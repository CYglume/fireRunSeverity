import os, re, json
import cdsapi
import geopandas as gpd
from shapely.geometry import Polygon, mapping
from datetime import datetime
from timezonefinder import TimezoneFinder
import pytz
from zoneinfo import ZoneInfo
from zipfile import ZipFile


# To get root path under project folder structure
cwd = os.path.dirname(os.path.abspath("__file__"))
root_folder = cwd.split('\\')
root_folder = root_folder[1:-2]
if root_folder[-1] != 'fireRunSeverity':
    print("!!-- Didn't get correct root folder! --!!")
    print(root_folder)
    print("!!-- Modify rooting index at line: 18 and come back --!!")
root_folder = os.path.join(os.sep,*root_folder)
run_DataDir = r"data/fireruns"
ER5_Dir     = r"data/ER5"
LandCV_Dir  = r"data/LandCover"

# Load credential
cred_json = os.path.join(cwd, ".cds_cred.json")
if os.path.exists(cred_json):
    with open(cred_json, "r") as f1:
        cred = json.load(f1)

if "cred" in locals():
    cdsAPI_KEY = cred['cdsAPI_KEY']
else:
    cdsAPI_KEY = input("CDS API Key: ")
    cred = {"cdsAPI_KEY": cdsAPI_KEY}
    with open(cred_json, "w") as f1:
        json.dump(cred, f1)
del cred

# Local Side data
# List in put data for GEE fetch
AreaList = os.listdir(os.path.join(root_folder,run_DataDir))
for in_Name in AreaList:    
    print("\n\n ######################################################")
    print("Process AOI:", in_Name)
    dataFLD = os.path.join(root_folder, run_DataDir, in_Name)
    inFLD = os.path.join(dataFLD, 'input')
    shpIn  = []
    for f in os.scandir(inFLD):
        if re.search(r".shp$", f.name):
            print("Shp Name:", f.name)
            shpIn.append(f)

    if len(shpIn) != 1:
        print("No. of shp file not equal to 1!")
        exit()
    else:
        shpIn = shpIn[0]

    # Read Shp file
    shpGPD = gpd.read_file(os.path.join(inFLD, shpIn))
    print("Shp  CRS:", shpGPD.crs)
    shpGPD_bf = shpGPD.buffer(10000)
    shpbf_reproj = shpGPD_bf.to_crs("EPSG:4326")
    del shpGPD_bf

    # Get the bounds
    minx, miny, maxx, maxy = shpbf_reproj.total_bounds
    # Create a polygon of bounds
    bounds_polygon = Polygon([(minx, miny), (minx, maxy), (maxx, maxy), (maxx, miny), (minx, miny)])
    bounds_wgs     = bounds_polygon.bounds
    # Shapely bounds: [xmin, ymin, xmax, ymax]
    # Reorder to CDS format [ymax, xmin, ymin, xmax]
    print(bounds_polygon.bounds)
    cds_bound = [bounds_wgs[3], bounds_wgs[0], bounds_wgs[1], bounds_wgs[2]]
    print(cds_bound)

    # Modify TimeZone
    latitude = (miny + maxy)/2
    longitude = (minx + maxx)/2
    tf = TimezoneFinder()
    timezone = tf.timezone_at(lng=longitude, lat=latitude)
    print(f"Accurate Time Zone: {timezone}")

    # Load Shp input
    dataFLD = os.path.join(root_folder, run_DataDir, in_Name)
    inFLD = os.path.join(dataFLD, 'input')
    shpIn  = []
    for f in os.scandir(inFLD):
        if re.search(r".shp$", f.name):
            shpIn.append(f)

    if len(shpIn) != 1:
        print("No. of shp file not equal to 1!")
        exit()
    else:
        shpIn = shpIn[0]

    shpGPD = gpd.read_file(os.path.join(inFLD, shpIn))

    # Get date of data
    # Convert time zone to UTC
    fire_dtString = list(shpGPD['FeHo'].dropna())
    fire_dtsList  = [datetime.strptime(dt, "%Y/%m/%d_%H%M").replace(tzinfo=ZoneInfo(timezone)) for dt in fire_dtString if not re.search("\\D", dt[:4])] # Filter out string with non-digit characters
    tz_utc = pytz.timezone("UTC")
    dateSt_UTC = min(fire_dtsList).astimezone(tz_utc)

    # print(sorted(fire_dtsList_UTC))
    dateSt = dateSt_UTC.date()
    print("Date of AOI:", dateSt)


    #########################
    # CDS Download          #
    #########################
    # Check LandCover Folder
    outFld = os.path.join(root_folder, LandCV_Dir, in_Name)
    if not os.path.exists(outFld):
        os.makedirs(outFld)
    output_file = os.path.join(outFld, f"CDS_LandCover_{in_Name}_{dateSt.year}.nc")

    if not os.path.exists(output_file):
        # Connect to CDS session
        c = cdsapi.Client(key=cdsAPI_KEY,
                            url='https://cds.climate.copernicus.eu/api', quiet=False, sleep_max=5, timeout=7200)

        zip_name = output_file.replace(".nc", ".zip")
        cds_year = 2022 if dateSt.year > 2022 else dateSt.year
        dt_vers  = "v2_0_7cds" if cds_year < 2016 else "v2_1_1"
        print("Use Land Cover Map Year:", cds_year)
        
        if not os.path.exists(zip_name):
            print("-- Requesting Land Cover datasets...")
            dataset = "satellite-land-cover"
            request = {
            "variable": "all",
            "year": [str(cds_year)],
            "version": [dt_vers],
            "area": cds_bound,
            }

            c.retrieve(dataset, request, zip_name)
        
        # Need to unzip because of the source format
        print("-- Unzipping dataset...")
        with ZipFile(zip_name, 'r') as zip_ref:
            if len(zip_ref.filelist) > 1:
                print("Found multiple files:", *zip_ref.filelist, sep="\n")
            elif re.search(dt_vers.replace("_", "."), zip_ref.filelist[0].filename):
                print("File version check successful:", zip_ref.filelist[0].filename, sep="\n")
                zip_ref.extract(zip_ref.filelist[0], os.path.dirname(zip_name))
                srcf = os.path.join(root_folder, LandCV_Dir, in_Name, zip_ref.filelist[0].filename)
                os.rename(srcf, output_file)
    else:
        print("NC File exists!")

    print("----- END of AOI: ", in_Name, " -----")
    print("######################################################\n")

print("----- END of Program -----")