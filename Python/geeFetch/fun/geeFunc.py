from timezonefinder import TimezoneFinder

def get_timezone(lat, lon):
    tf = TimezoneFinder()
    tz_name = tf.timezone_at(lng=lon, lat=lat)
    return tz_name

# Functions for Computing Necessary indices
def func_maskClouds(image):
    imgCLP = image.select("MSK_CLDPRB")
    mskCLP = imgCLP.lt(10)  
    qa = image.select("QA60")
    Clouds = qa.bitwiseAnd(1 << 10).eq(0)  
    Cirrus = qa.bitwiseAnd(1 << 11).eq(0) 
    mask = Clouds.And(Cirrus).And(mskCLP)
    return image.updateMask(mask)

def maskClouds_L7(image):
    qa = image.select('QA_PIXEL')
    dilated_cloud = qa.bitwiseAnd(1 << 1).eq(0)
    cloud = qa.bitwiseAnd(1 << 3).eq(0)
    cloud_sha = qa.bitwiseAnd(1 << 4).eq(0)
    mask = cloud.And(cloud_sha).And(dilated_cloud)
    return image.updateMask(mask)

def func_rescale(image, scale, offset):
    refl = image.multiply(scale).add(offset)
    return refl.copyProperties(image, ["system:time_start", 'system:index'])

def func_calcIndices(image, RED, NIR, SWIR):
    NBR = image.normalizedDifference([NIR, SWIR]).rename("NBR") 
    NDVI = image.normalizedDifference([NIR, RED]).rename("NDVI") 
    return image.addBands([NBR, NDVI])

def func_calcIndices2(image):
    Cl_RBR   = image.expression(
        "dNBR / (preNBR + 1.001)", {
            "preNBR": image.select('Cl_preNBR'),
            "dNBR": image.select('Cl_dNBR') 
        }
    ).rename('Cl_RBR').toFloat()
    Cl_RdNBR = image.expression(
        "(abs(preNBR) < 0.001) ? dNBR/sqrt(0.001) : dNBR/sqrt(abs(preNBR))",{
            "preNBR": image.select('Cl_preNBR'),
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
    return image.addBands([Cl_RBR, Cl_RdNBR, M_RBR, M_RdNBR])