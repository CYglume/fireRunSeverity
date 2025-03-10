from timezonefinder import TimezoneFinder

def get_timezone(lat, lon):
    tf = TimezoneFinder()
    tz_name = tf.timezone_at(lng=lon, lat=lat)
    return tz_name

# Functions for Computing Necessary indices
def func_maskClouds(image):
    imgCLP = image.select("MSK_CLDPRB")
    mskCLP = imgCLP.lt(10);  
    qa = image.select("QA60")
    Clouds = qa.bitwiseAnd(1 << 10).eq(0);  
    Cirrus = qa.bitwiseAnd(1 << 11).eq(0); 
    mask = Clouds.And(Cirrus).And(mskCLP)
    return image.updateMask(mask)

def func_rescale(image):
    refl = image.multiply(0.0001)
    return refl.copyProperties(image, ["system:time_start"])

def func_calcIndices (image):
    NBR  = image.normalizedDifference(["B8", "B12"]).rename("NBR")
    NDVI = image.normalizedDifference(["B8", "B4"]).rename("NDVI")
    return image.addBands([NBR, NDVI])

def func_calcIndices2(image):
    RBR   = image.expression(
        "dNBR / (preNBR + 1.001)", {
            "preNBR": image.select('preNBR'),
            "dNBR": image.select('Cl_dNBR') 
        }
    ).rename('Cl_RBR').toFloat()
    RdNBR = image.expression(
        "(abs(preNBR) < 0.001) ? dNBR/sqrt(0.001) : dNBR/sqrt(abs(preNBR))",{
            "preNBR": image.select('preNBR'),
            "dNBR": image.select('Cl_dNBR')
        }
    ).rename("Cl_RdNBR").toFloat()
    M_RBR   = image.expression(
        "dNBR / (preNBR + 1.001)", {
            "preNBR": image.select('M_preNBR'),
            "dNBR": image.select('M_dNBR') 
        }
    ).rename('M_RBR').toFloat()
    M_RdNBR = image.expression(
        "(abs(preNBR) < 0.001) ? dNBR/sqrt(0.001) : dNBR/sqrt(abs(preNBR))",{
            "preNBR": image.select('M_preNBR'),
            "dNBR": image.select('M_dNBR')
        }
    ).rename("M_RdNBR").toFloat()
    return image.addBands([RBR, RdNBR, M_RBR, M_RdNBR])