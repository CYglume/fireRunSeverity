import ee
ee.Authenticate(force=True)
ee.Initialize(project='geefiresever')
print(ee.String('Hello from the Earth Engine servers!').getInfo())


if __name__ == "__main__":
    print("ok")