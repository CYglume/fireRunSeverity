import ee 
from ee_plugin import Map

S2_harmon = ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED")
m.setCenter(148.3462, -37.3684,9)

# ---  30/Dec/2019 -> 27/Feb/2020 Wild Fire in Gippsland, Australia  --- #

# To load a table dataset from Earth Engine Data Catalog
adm2 = ee.FeatureCollection("FAO/GAUL/2015/level2")
Gipps = adm2.filter(ee.Filter.inList("ADM2_NAME", ["East Gippsland (S)"]))
clipAOI = Gipps.geometry()
clipAOI2 = Gipps.geometry().bounds().buffer(50000)
print(Gipps.getInfo())
m.addLayer(Gipps, {'color': "blue"}, "Gippsland GAUL")


# filter satellite data
bandList = ["B.", "B..", "QA60", "MSK_CLDPRB"]
S2_pre_select = S2_harmon.filterDate("2019-09-01", "2019-12-29") \
.filterBounds(clipAOI2).select(bandList)
# .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 5))

S2_dur_select = S2_harmon.filterDate("2019-12-30", "2020-02-27") \
.filterBounds(clipAOI2).select(bandList)
# .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 5))

S2_pos_select = S2_harmon.filterDate("2020-02-28", "2020-06-30") \
.filterBounds(clipAOI2).select(bandList)
# .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 5))

# Set up cloud mask for image combination

def func_hce(image):
    imgCLP = image.select("MSK_CLDPRB")
    mskCLP = imgCLP.lt(10);  
    qa = image.select("QA60")
    maskClouds = qa.bitwiseAnd(1 << 10).eq(0);  
    maskCirrus = qa.bitwiseAnd(1 << 11).eq(0); 
    mask = maskClouds.And(maskCirrus).And(mskCLP)
    return image.updateMask(mask)

maskClouds = func_hce









def func_oiy(image):
    refl = image.multiply(0.0001)
    return refl.copyProperties(image, ["system:time_start"])

rescale = func_oiy







S2pre = S2_pre_select.map(maskClouds).map(rescale) \
.sort('system:time_start') \
.mosaic(); 
S2dur = S2_dur_select.map(rescale).min()
S2pos = S2_pos_select.map(maskClouds).map(rescale) \
.sort('system:time_start', False) \
.mosaic(); 

print(S2pre.getInfo())
print(S2dur.getInfo())
print(S2pos.getInfo())



visP = {'bands': ["B4",  "B3",  "B2"], 'max': 0.3}
m.addLayer(S2pre.clip(clipAOI), visP, "S2 pre fire")
m.addLayer(S2dur.clip(clipAOI), visP, "S2 on fire")
m.addLayer(S2pos.clip(clipAOI), visP, "S2 after fire")



# # ------------------------------------------------ # #
# Indices calculation

def func_rvc (image):
    NBR = image.normalizedDifference(["B8", "B12"]).rename("NBR")
    NDVI = image.normalizedDifference(["B8", "B4"]).rename("NDVI")
    return image.addBands([NBR, NDVI])

calcIndices = func_rvc





S2pre_id = calcIndices(S2pre)
S2dur_id = calcIndices(S2dur)
S2pos_id = calcIndices(S2pos)
S2_dNBR  = S2pre_id.select("NBR").subtract(S2pos_id.select("NBR")).multiply(1000).rename("dNBR")
print("dNBR",S2_dNBR.getInfo())
S2pre_coll_id = S2_pre_select.map(calcIndices)
print(S2pre_coll_id.getInfo())


# Produce Severity classes
S2_severity = ee.Image(1) \
.where(S2_dNBR.gt(-500).And(S2_dNBR.lte(-251)), 1) \
.where(S2_dNBR.gt(-251).And(S2_dNBR.lte(-101)), 2) \
.where(S2_dNBR.gt(-101).And(S2_dNBR.lte(99)), 3) \
.where(S2_dNBR.gt(99).And(S2_dNBR.lte(269)), 4) \
.where(S2_dNBR.gt(269).And(S2_dNBR.lte(439)), 5) \
.where(S2_dNBR.gt(439).And(S2_dNBR.lte(659)), 6) \
.where(S2_dNBR.gt(660).And(S2_dNBR.lte(1300)), 7) \
.clip(clipAOI)
# # ------------------------------------------------ # #



# # ------------------------------------------------ # #
# # NBR fire severity color:https:#un-spider.Org/advisory-support/recommended-practices/recommended-practice-burn-severity/Step-By-Step/RStudio
dnbrPal = ["556B2F","6E8B3D","32CD32", "EEEE00", "EE7600", "FF0000", "A020F0"]
# # NDVI palette https:#custom-scripts.sentinel-hub.com/sentinel-2/ndvi/
ndviPal = ["0c0c0c", "eaeaea", "ccc682", "91bf51", "70a33f", "4f892d", "306d1c", "0f540a", "004400"]
# # name of the legend
dnbrNames = ["Enhanced Regrowth, High", "Enhanced Regrowth, Low", "Unburned", "Low Severity", "Moderate-low Severity", "Moderate-high Severity", "High Severity"]

visNBR = {'bands': "NBR", 'max':1, 'min': -1, 'palette': ["green", "red"]}

visNDVI = {
    'bands': "NDVI",
    'max': 1,
    'min': -1,
    'palette': ndviPal
}
visdNBR = {
    'max': 1300,
    'min': -500,
    'palette': dnbrPal
}
visSevere = {
    'max': 7,
    'min': 1,
    'palette': dnbrPal
}

# m.addLayer(S2pre_id, visNDVI, "NDVI_pre")
# m.addLayer(S2pos_id, visNDVI, "NDVI_pos")
m.addLayer(S2_dNBR, visdNBR, "dNBR")
m.addLayer(S2_severity, visSevere, "dNBR Severity")
# # ------------------------------------------------ # #




# # # ------------------------------------------------
# # # https:#mygeoblog.com/2016/12/09/add-a-legend-to-to-your-gee-map/
# # # Legend for fire severity
legend = ui.Panel(
style={
    position='bottom-left',
    padding='8px 15px'
}
)

# Create legend title
legendTitle = ui.Label(
value='Fire Severity (dNBR)',
style={
    fontWeight='bold',
    fontSize='18px',
    margin='0 0 4px 0',
    padding='0'
}
)

# Add the title to the panel
legend.add(legendTitle)

# Creates and styles 1 row of the legend.

def func_brd(color, name):

    # Create the label that is actually the colored box.
    colorBox = ui.Label(
        style={
                backgroundColor='#' + color,
                # Use padding to give the box height and width.
                padding='8px',
                margin='0 0 4px 0'
            }
        )

    # Create the label filled with the description text.
    description = ui.Label(
        value=name,
        style={margin='0 0 4px 6px'}
        )

    # return the panel
    return ui.Panel(
        widgets=[colorBox, description],
        layout=ui.Panel.Layout.Flow('horizontal')
        )

makeRow = func_brd
























# Add color and and names
for i in range(0, 7, 1):
    legend.add(makeRow(dnbrPal[i], dnbrNames[i]))


# add legend to map (alternatively you can also print the legend to the console)
m.add(legend)
# # # ------------------------------------------------
m