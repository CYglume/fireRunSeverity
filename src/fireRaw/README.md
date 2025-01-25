## This is the folder for fire perimeter raw data
- prepare your perimeter file (.shp) in the folder named `[your AOI name]` and copy it into `src/fireRaw`. (see `"AOI2"` below for reference)

- When running `EnvSetup.R` the `data` folder structure will be created.
- structure under folder `fireruns` will be created with reference to structure under `src/fireRaw`. Also, files under `src/fireRaw/(AOI)` will be copied to `data/fireruns/(AOI)`

### Folder structure
```
fireRunSeverity
│   README.md
│   
│   ...
|    
└───data
│   └───ER5
│   └───GEE
│   └───fireruns
│       └───"AOI1"
│       └───"AOI2"
|       |   └───input
│       |       │   aoi2_name.shp
|       |       │   (TesaureWind.csv)
|       |
│       └───"AOI3"
│   
└───src
│   └───fireRaw
│       └───"AOI1"
│       └───"AOI2"
│       |   │   aoi2_name.shp
│       |   │   (TesaureWind.csv)
|       |
│       └───"AOI3"
│       |   
│       |   ...
        
```