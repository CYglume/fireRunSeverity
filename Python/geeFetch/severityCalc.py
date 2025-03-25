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
ee.Initialize(project = "project-ID") # specify the project name in the argument.
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
L7_T1L2   = ee.ImageCollection("LANDSAT/LE07/C02/T1_L2")
SRTM      = ee.Image("USGS/SRTMGL1_003")

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
    # Check if any index map has been calculated
    outGEEFLD = os.path.join(root_folder, 'data', 'GEE', in_Name)
    exist_indicesList = os.listdir(outGEEFLD)
    exist_indicesList = [f.split("--")[0] for f in exist_indicesList if os.path.isfile(os.path.join(outGEEFLD, f))]

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

    L7_flag = False # for using Landsat-7 dataset if burning timing before Sentinel-2
    if dateSt < date(2017, 3, 28):
        print("!! ---------- Date before 28 Mar 2017! ---------- !!")
        print("----- AOI: ", in_Name, " -----")
        print("----- Using Landsat 7 ......")
        L7_flag = True
    
    
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
    bandList = ["SR_B.", "SR_CLOUD_QA", "QA_PIXEL"] if L7_flag else ["B.", "B..", "QA60", "MSK_CLDPRB"]

    if not L7_flag:
        S2_pre_select = S2_harmon.filterDate(prefire_date[0], prefire_date[1]) \
            .filterBounds(clipAOI2).select(bandList)
        S2_pos_select = S2_harmon.filterDate(postfire_date[0], postfire_date[1]) \
            .filterBounds(clipAOI2).select(bandList)
        
        # Mosaicking composite
        S2pre = S2_pre_select.map(func_maskClouds) \
            .map(lambda image: func_rescale(image, scale=0.0001, offset=0)) \
            .sort('system:time_start') \
            .mosaic(); 
        S2pos = S2_pos_select.map(func_maskClouds) \
            .map(lambda image: func_rescale(image, scale=0.0001, offset=0)) \
            .sort('system:time_start', False) \
            .mosaic(); 
        # print(json.dumps(S2pre.getInfo(), indent=4))

        # Mean composite
        S2pre_mean = S2_pre_select.map(func_maskClouds) \
            .map(lambda image: func_rescale(image, scale=0.0001, offset=0)) \
            .mean(); 
        S2pos_mean = S2_pos_select.map(func_maskClouds) \
            .map(lambda image: func_rescale(image, scale=0.0001, offset=0)) \
            .mean(); 
        # print(json.dumps(S2pre_mean.getInfo(), indent=4))

        # Indices Calculation
        pre_id   = func_calcIndices(S2pre,      RED="B4", NIR="B8", SWIR="B12")
        pos_id   = func_calcIndices(S2pos,      RED="B4", NIR="B8", SWIR="B12")
        pre_id_m = func_calcIndices(S2pre_mean, RED="B4", NIR="B8", SWIR="B12")
        pos_id_m = func_calcIndices(S2pos_mean, RED="B4", NIR="B8", SWIR="B12")
    else:
        L7_pre_select = L7_T1L2.filterDate(prefire_date[0], prefire_date[1]) \
            .filterBounds(clipAOI2).select(bandList)
        L7_pos_select = L7_T1L2.filterDate(postfire_date[0], postfire_date[1]) \
            .filterBounds(clipAOI2).select(bandList)
        
        # Mosaicking composite
        L7pre = L7_pre_select.map(maskClouds_L7) \
            .map(lambda image: func_rescale(image, 0.0000275, -0.2)) \
            .sort('system:time_start')  \
            .mosaic()
        L7pos = L7_pos_select.map(maskClouds_L7) \
            .map(lambda image: func_rescale(image, 0.0000275, -0.2)) \
            .sort('system:time_start', False) \
            .mosaic()
        # print(json.dumps(L7pre.getInfo(), indent=4))
        
        # Mean composite
        L7pre_mean = L7_pre_select.map(maskClouds_L7) \
            .map(lambda image: func_rescale(image, 0.0000275, -0.2)) \
            .mean()
        L7pos_mean = L7_pos_select.map(maskClouds_L7) \
            .map(lambda image: func_rescale(image, 0.0000275, -0.2)) \
            .mean()
        # print(json.dumps(L7pre_mean.getInfo(), indent=4))

        # Indices Calculation
        pre_id   = func_calcIndices(L7pre,      RED="SR_B3", NIR="SR_B4", SWIR="SR_B7")
        pos_id   = func_calcIndices(L7pos,      RED="SR_B3", NIR="SR_B4", SWIR="SR_B7")
        pre_id_m = func_calcIndices(L7pre_mean, RED="SR_B3", NIR="SR_B4", SWIR="SR_B7")
        pos_id_m = func_calcIndices(L7pos_mean, RED="SR_B3", NIR="SR_B4", SWIR="SR_B7")


    

    # dNBR
    indices_first  = pre_id.select("NBR").subtract(pos_id.select("NBR")).multiply(1000).rename("Cl_dNBR")
    indices_first  = indices_first.addBands(
        pre_id_m.select("NBR").subtract(pos_id_m.select("NBR")).multiply(1000).rename("M_dNBR")
    )

    # Other indices
    indices_first  = indices_first.addBands([pre_id.select("NBR").rename("Cl_preNBR"), 
                                             pos_id.select("NBR").rename("Cl_posNBR"),
                                             pre_id_m.select("NBR").rename("M_preNBR"), 
                                             pos_id_m.select("NBR").rename("M_posNBR"),])

    indices_final = func_calcIndices2(indices_first)
    
    # Environmental factors
    terrain = ee.Terrain.products(SRTM.clip(clipAOI2));
    indices_final = indices_final.addBands([SRTM.clip(clipAOI2).select('elevation').rename('env_elevation'),
                                            terrain.select('aspect').rename('env_aspect'),])

    ##########################
    #   Image Exportation    #
    ##########################
    # Select needed bands
    bd = indices_final.bandNames()
    bd = bd.removeAll(['Cl_preNBR', 'Cl_posNBR', 'M_preNBR', 'M_posNBR'])
    indices_for_output = indices_final.select(bd)
    bd = indices_for_output.bandNames().getInfo()
    print(bd)


    # Define export parameters
    print("#-----------------#")
    print("Exporting for", in_Name)
    driveFLD = os.path.join('EarthEngineFolder', in_Name, in_Name)
    tStamp = datetime.now().strftime("%d%m%Y_%H%M")
    datasetName = "L7" if L7_flag else "S2"
    for bd_i in bd:
        if f'{datasetName}_{bd_i}' in exist_indicesList:
            # skip map production if index maps already exist in local folder
            continue

        export_task = ee.batch.Export.image.toDrive(
            image=indices_for_output.select(bd_i),
            description='sentinel2_fire_indices_image_export',
            folder='EarthEngineFolder',  # Folder in your Google Drive
            fileNamePrefix=f'PythonGEE_output--{in_Name}--{datasetName}_{bd_i}--{tStamp}',  # File name prefix
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
