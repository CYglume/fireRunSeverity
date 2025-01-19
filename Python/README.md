# Installation
- Get Python from [Python.org](https://www.python.org/)
- The project folder `fireRunSeverity` is assumed to be placed under %userprofile%
  - i.e. C:\Users\user\fireRunSeverity

## Install Poetry for package management
- Adopted from [poetry website](https://python-poetry.org/docs/#installing-manually)
- Type in command line (replace `%VENV_PATH%` with any path for any prefered place)
```{python}
set VENV_PATH=%userprofile%/mapGee
python -m venv %VENV_PATH%
%VENV_PATH%/bin/pip install -U pip setuptools
%VENV_PATH%/bin/pip install poetry
```

## Install packages for GEE
- switch to Python folder in this project: `fireRunSeverity/Python`
- intall using `pyproject.toml` file provided (automatically done by poetry) 
```
set PATH=%VENV_PATH%/Scripts/;%PATH%
cd %userprofile%/fireRunSeverity/Python
poetry install
```

# GEE project setup
You will need to setup GEE project in your Google account to continue with Python API.
- Sign up for [Google Earth Engine](https://code.earthengine.google.com/register)
  - unpaid -> Academia & Research
  - Create a new Google Cloud Project
    - **ID: will be the project ID used in Python code**
  - Confirm -> You will see the code panel show up
- Python Authorization
  - Back to [Google Cloud Console](https://console.cloud.google.com/)
  - Search for `Google Earth Engine API` in the search bar
  ![GEE Search Screenshot](man/gee_Search.png)
  - Enable the API in the intro page
  ![GEE API Screenshot](man/gee_API.png)

# Operation
## Everytime setup
- Add virtual env of poetry to PATH temporarily
  - `set PATH=%userprofile%/mapGee/Scripts/;%PATH%`

```
set VENV_PATH=%userprofile%/mapGee
set PATH=%VENV_PATH%/Scripts/;%PATH%
cd %userprofile%/fireRunSeverity/Python
poetry run python main.py
```