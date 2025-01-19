var S2_harmon = ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED");
Map.setCenter(148.3462, -37.3684,9);

// ---  30/Dec/2019 -> 27/Feb/2020 Wild Fire in Gippsland, Australia  --- //

// To load a table dataset from Earth Engine Data Catalog
var adm2 = ee.FeatureCollection("FAO/GAUL/2015/level2");
var Gipps = adm2.filter(ee.Filter.inList("ADM2_NAME", ["East Gippsland (S)"]));
var clipAOI = Gipps.geometry();
var clipAOI2 = Gipps.geometry().bounds().buffer(50000);
print(Gipps);
Map.addLayer(Gipps, {color: "blue"}, "Gippsland GAUL");


// filter satellite data
var bandList = ["B.", "B..", "QA60", "MSK_CLDPRB"];
var S2_pre_select = S2_harmon.filterDate("2019-09-01", "2019-12-29")
          .filterBounds(clipAOI2).select(bandList)
          // .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 5));

var S2_dur_select = S2_harmon.filterDate("2019-12-30", "2020-02-27")
          .filterBounds(clipAOI2).select(bandList)
          // .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 5));
          
var S2_pos_select = S2_harmon.filterDate("2020-02-28", "2020-06-30")
          .filterBounds(clipAOI2).select(bandList)
          // .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 5));

// Set up cloud mask for image combination
var maskClouds = function(image) {			
    var imgCLP = image.select("MSK_CLDPRB");
    var mskCLP = imgCLP.lt(10);  // filter out pixels by Cloud probability
    var qa = image.select("QA60");			
    var maskClouds = qa.bitwiseAnd(1 << 10).eq(0);  // filter out pixels with opaque clouds
    var maskCirrus = qa.bitwiseAnd(1 << 11).eq(0); // filter out pixels with cirrus clouds
    var mask = maskClouds.and(maskCirrus).and(mskCLP);	
    return image.updateMask(mask);			
};
var rescale = function(image){
    var refl = image.multiply(0.0001);
    return refl.copyProperties(image, ["system:time_start"]);  
};




var S2pre = S2_pre_select.map(maskClouds).map(rescale)
                  .sort('system:time_start')  // Sort by time in ascending order
                  .mosaic(); // get the latest pixel close to the fire (last on top)
var S2dur = S2_dur_select.map(rescale).min();
var S2pos = S2_pos_select.map(maskClouds).map(rescale)
                          .sort('system:time_start', false)  // Sort by time in descending order
                          .mosaic(); // get the earliest pixel close to the fire (last on top)

print(S2pre)
print(S2dur)
print(S2pos)



var visP = {bands: ["B4", "B3", "B2"], max: 0.3}
Map.addLayer(S2pre.clip(clipAOI), visP, "S2 pre fire");
Map.addLayer(S2dur.clip(clipAOI), visP, "S2 on fire");
Map.addLayer(S2pos.clip(clipAOI), visP, "S2 after fire");



// // ------------------------------------------------ // //
// Indices calculation
var calcIndices = function (image) {
  var NBR = image.normalizedDifference(["B8", "B12"]).rename("NBR"); 
  var NDVI = image.normalizedDifference(["B8", "B4"]).rename("NDVI"); 
  return image.addBands([NBR, NDVI]);
}

var S2pre_id = calcIndices(S2pre);
var S2dur_id = calcIndices(S2dur);
var S2pos_id = calcIndices(S2pos);
var S2_dNBR  = S2pre_id.select("NBR").subtract(S2pos_id.select("NBR")).multiply(1000).rename("dNBR");
print("dNBR",S2_dNBR);
var S2pre_coll_id = S2_pre_select.map(calcIndices);
print(S2pre_coll_id);


// Produce Severity classes
var S2_severity = ee.Image(1)
      .where(S2_dNBR.gt(-500).and(S2_dNBR.lte(-251)), 1)
      .where(S2_dNBR.gt(-251).and(S2_dNBR.lte(-101)), 2)
      .where(S2_dNBR.gt(-101).and(S2_dNBR.lte(99)), 3)
      .where(S2_dNBR.gt(99).and(S2_dNBR.lte(269)), 4)
      .where(S2_dNBR.gt(269).and(S2_dNBR.lte(439)), 5)
      .where(S2_dNBR.gt(439).and(S2_dNBR.lte(659)), 6)
      .where(S2_dNBR.gt(660).and(S2_dNBR.lte(1300)), 7)
      .clip(clipAOI);
// // ------------------------------------------------ // //



// // ------------------------------------------------ // //
// // NBR fire severity color:https://un-spider.org/advisory-support/recommended-practices/recommended-practice-burn-severity/Step-By-Step/RStudio
var dnbrPal = ["556B2F","6E8B3D","32CD32", "EEEE00", "EE7600", "FF0000", "A020F0"];
// // NDVI palette https://custom-scripts.sentinel-hub.com/sentinel-2/ndvi/
var ndviPal = ["0c0c0c", "eaeaea", "ccc682", "91bf51", "70a33f", "4f892d", "306d1c", "0f540a", "004400"];
// // name of the legend
var dnbrNames = ["Enhanced Regrowth, High", "Enhanced Regrowth, Low", "Unburned", "Low Severity", "Moderate-low Severity", "Moderate-high Severity", "High Severity"];
  
var visNBR = {bands: "NBR", max:1, min: -1, palette: ["green", "red"]}; 

var visNDVI = {
  bands: "NDVI",
  max: 1,
  min: -1,
  palette: ndviPal
}; 
var visdNBR = {
  max: 1300,
  min: -500,
  palette: dnbrPal
}; 
var visSevere = {
  max: 7,
  min: 1,
  palette: dnbrPal
}; 

// Map.addLayer(S2pre_id, visNDVI, "NDVI_pre");
// Map.addLayer(S2pos_id, visNDVI, "NDVI_pos");
Map.addLayer(S2_dNBR, visdNBR, "dNBR");
Map.addLayer(S2_severity, visSevere, "dNBR Severity");
// // ------------------------------------------------ // //




// // // ------------------------------------------------
// // // https://mygeoblog.com/2016/12/09/add-a-legend-to-to-your-gee-map/  
// // // Legend for fire severity
var legend = ui.Panel({
  style: {
    position: 'bottom-left',
    padding: '8px 15px'
  }
});

// Create legend title
var legendTitle = ui.Label({
  value: 'Fire Severity (dNBR)',
  style: {
    fontWeight: 'bold',
    fontSize: '18px',
    margin: '0 0 4px 0',
    padding: '0'
    }
});

// Add the title to the panel
legend.add(legendTitle);
 
// Creates and styles 1 row of the legend.
var makeRow = function(color, name) {

      // Create the label that is actually the colored box.
      var colorBox = ui.Label({
        style: {
          backgroundColor: '#' + color,
          // Use padding to give the box height and width.
          padding: '8px',
          margin: '0 0 4px 0'
        }
      });
 
      // Create the label filled with the description text.
      var description = ui.Label({
        value: name,
        style: {margin: '0 0 4px 6px'}
      });
 
      // return the panel
      return ui.Panel({
        widgets: [colorBox, description],
        layout: ui.Panel.Layout.Flow('horizontal')
      });
};

// Add color and and names
for (var i = 0; i < 7; i++) {
  legend.add(makeRow(dnbrPal[i], dnbrNames[i]));
  }
  
// add legend to map (alternatively you can also print the legend to the console)
Map.add(legend);
// // // ------------------------------------------------
