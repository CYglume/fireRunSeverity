import ee
import geemap
import os, re, json, time
import geopandas as gpd
from datetime import datetime, timedelta, date
from shapely.geometry import Polygon, mapping
from timezonefinder import TimezoneFinder
import pytz
from zoneinfo import ZoneInfo
from fun.geeFunc import *

ee.Authenticate(force=True)
ee.Initialize() # add project name in the argument if program failed. Ex. ee.Initialize(project = "project-id")
print(ee.String('Hello from the Earth Engine servers!').getInfo())

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
AreaList = os.listdir(os.path.join(root_folder,run_DataDir))


# Load Online Data Collection (Run for all process)
# Add Earth Engine dataset
S2_harmon = ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED")


for in_Name in AreaList:
    print("\n\n ######################################################")
    print("Process AOI:", in_Name)
    dataFLD = os.path.join(root_folder, run_DataDir, in_Name)
    inFLD = os.path.join(dataFLD, 'input')
    shpIn  = []
    for f in os.scandir(inFLD):
        if re.search(r".shp$", f.name):
            print(f.name)
            shpIn.append(f)

    if len(shpIn) != 1:
        print("No. of shp file not equal to 1!")
        exit()
    else:
        shpIn = shpIn[0]

    # Read Shp file
    shpGPD = gpd.read_file(os.path.join(inFLD, shpIn))
    print(shpGPD.crs)
    shp_reproj = shpGPD.to_crs("EPSG:4326")
    # Get the bounds
    minx, miny, maxx, maxy = shp_reproj.total_bounds
    # Create a polygon of bounds
    bounds_polygon = Polygon([(minx, miny), (minx, maxy), (maxx, maxy), (maxx, miny), (minx, miny)])
    # Convert the polygon to GeoJSON
    json_polygon = mapping(bounds_polygon)
    print(json_polygon)


    # ----------------------------------------------- #
    ##########################
    # Time Zone Modification #
    ##########################
    latitude = (miny + maxy)/2
    longitude = (minx + maxx)/2
    timezone = get_timezone(latitude, longitude)
    print(f"Accurate Time Zone: {timezone}")

    # Get date of data
    # Convert time zone to UTC
    fire_dtString = list(shpGPD['FeHo'])
    fire_dtsList  = [datetime.strptime(dt, "%Y/%m/%d_%H%M").replace(tzinfo=ZoneInfo(timezone)) for dt in fire_dtString]
    tz_utc = pytz.timezone("UTC")
    fire_dtsList_UTC = [dt.astimezone(tz_utc) for dt in fire_dtsList]

    # print(sorted(fire_dtsList_UTC))
    dateSt = min(fire_dtsList_UTC).date()
    dateEd = max(fire_dtsList_UTC).date()
    print("Fire start date and end date:")
    print(dateSt, dateEd)

    if dateSt < date(2017, 3, 28):
        print("!! ---------- Date out of range! ---------- !!")
        print("----- END of AOI: ", in_Name, " -----")
        print("######################################################\n")
        continue
    
    
    # Compute the date period for retrieving Satellite img
    prefire_date  = [dateSt - timedelta(days = 4*30), dateSt - timedelta(days = 1)]
    postfire_date = [dateEd + timedelta(days = 1),    dateEd + timedelta(days = 4*30)]

    prefire_date = [d.strftime("%Y-%m-%d") for d in prefire_date]
    postfire_date = [d.strftime("%Y-%m-%d") for d in postfire_date]

    print("Pre- and Post- fire periods selected for satellite images:")
    print(prefire_date, postfire_date)
    # ----------------------------------------------- #

    # ----------------------------------------------- #
    ##########################
    #   Online API Fetching  #
    ##########################
    clipAOI = ee.Geometry.Polygon(json_polygon["coordinates"])
    clipAOI2 = clipAOI.buffer(50000)
    
    

    ##########################
    # Satellite Calculation  #
    ##########################
    # filter satellite data
    bandList = ["B.", "B..", "QA60", "MSK_CLDPRB"]
    S2_pre_select = S2_harmon.filterDate(prefire_date[0], prefire_date[1]) \
    .filterBounds(clipAOI2).select(bandList)
    # .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 5))

    S2_pos_select = S2_harmon.filterDate(postfire_date[0], postfire_date[1]) \
    .filterBounds(clipAOI2).select(bandList)
    # .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 5))
    
    S2pre = S2_pre_select.map(func_maskClouds).map(func_rescale) \
    .sort('system:time_start') \
    .mosaic(); 

    S2pos = S2_pos_select.map(func_maskClouds).map(func_rescale) \
    .sort('system:time_start', False) \
    .mosaic(); 
    # print(json.dumps(S2pre.getInfo(), indent=4))

    S2pre_mean = S2_pre_select.map(func_maskClouds).map(func_rescale) \
    .sort('system:time_start') \
    .mean(); 

    S2pos_mean = S2_pos_select.map(func_maskClouds).map(func_rescale) \
    .sort('system:time_start', False) \
    .mean(); 
    # print(json.dumps(S2pre.getInfo(), indent=4))


    # Indices Calculation
    S2pre_id = func_calcIndices(S2pre)
    S2pos_id = func_calcIndices(S2pos)
    S2pre_id_m = func_calcIndices(S2pre_mean)
    S2pos_id_m = func_calcIndices(S2pos_mean)

    # dNBR
    S2_idcs1  = S2pre_id.select("NBR").subtract(S2pos_id.select("NBR")).multiply(1000).rename("Cl_dNBR")
    S2_idcs1  = S2_idcs1.addBands(S2pre_id_m.select("NBR").subtract(S2pos_id_m.select("NBR")).multiply(1000).rename("M_dNBR"))

    # Other indices
    S2_idcs1  = S2_idcs1.addBands([S2pre_id.select("NBR").rename("preNBR"), 
                                S2pos_id.select("NBR").rename("posNBR"),
                                S2pre_id_m.select("NBR").rename("M_preNBR"), 
                                S2pos_id_m.select("NBR").rename("M_posNBR"),])

    S2_idcs2 = func_calcIndices2(S2_idcs1)
    

    ##########################
    #   Image Exportation    #
    ##########################
    # Select needed bands
    bd = S2_idcs2.bandNames()
    bd = bd.removeAll(['preNBR', 'posNBR', 'M_preNBR', 'M_posNBR'])
    S2_idcs = S2_idcs2.select(bd)
    bd = S2_idcs.bandNames().getInfo()
    print(bd)


    # Define export parameters
    print("#-----------------#")
    print("Exporting for", in_Name)
    driveFLD = os.path.join('EarthEngineFolder', in_Name, in_Name)
    tStamp = datetime.now().strftime("%d%m%Y_%H%M")
    for bd_i in bd:
        export_task = ee.batch.Export.image.toDrive(
            image=S2_idcs.select(bd_i),
            description='sentinel2_fire_indices_image_export',
            folder='EarthEngineFolder',  # Folder in your Google Drive
            fileNamePrefix='PythonGEE_output--'+in_Name+'--S2_'+bd_i+'--'+tStamp,  # File name prefix
            region=clipAOI,  # Define the region to export (could be an area of interest)
            scale=10,  # Spatial resolution in meters
            fileFormat='GeoTIFF',  # File format
            maxPixels=1e12  # Max pixels to export
        )

        # Start the export task
        try:
            export_task.start()
            print("Band: ", bd_i)
            print("Exporting to Google Drive...")

            # Check the status of the export task
            print("Exporting... Please wait")
            while export_task.active():
                print('.',  end="")
                time.sleep(10)

            print('Export completed.')

        except ee.ee_exception.EEException as e:
            print(f"Error during export: {e}")
        except Exception as e:
            print(f"Unexpected error: {e}")
        print("----")

    print("----- END of AOI: ", in_Name, " -----")
    print("######################################################\n")
