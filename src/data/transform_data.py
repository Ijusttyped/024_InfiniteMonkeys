import pandas as pd
import json
import requests
import logging


logging.basicConfig(level=logging.INFO)


def get_geoinformation(address):
    try:
        base_url = "https://maps.googleapis.com/maps/api/geocode/json?address={}&key=XXX"
        call_url = base_url.format(address)
        response = requests.get(call_url)
        logging.info("1 column called.")
        return response.json()
    except Exception as e:
        logging.error(e)
        return ""


def get_lat_long(geoinfo, lat_or_long):
    if len(geoinfo["results"]) > 0:
        return geoinfo["results"][0]["geometry"]["location"][lat_or_long]
    else:
        logging.error("No result")
        return None


def get_statistics():
    url = "https://rki-covid-api.now.sh/api/states"
    response = requests.get(url)
    data = pd.DataFrame.from_dict(response.json()["states"])
    data.loc[5, "code"] = "HH"
    data.loc[9, "code"] = "NRW"
    return data


if __name__ == "__main__":
    json_path = "data/divi_data.json"
    with open(json_path, "r") as f:
        json_data = json.load(f)

    data = pd.DataFrame.from_dict(json_data["clinicStatus"])
    data["apiCall"] = data["name"].apply(lambda x: x.replace(" ", "+"))

    data["geoinformation"] = data["apiCall"].apply(lambda x: get_geoinformation(x))
    data["latitude"] = data["geoinformation"].apply(lambda x: get_lat_long(x, "lat"))
    data["longitude"] = data["geoinformation"].apply(lambda x: get_lat_long(x, "lng"))

    data.to_csv("data/divi_data_with_latlong.csv", index=False)

    statistics = get_statistics()

    merged = data.merge(statistics, left_on="state", right_on="code")
    merged.drop(columns="code", inplace=True)
    merged = merged.rename({"name_x": "name", "name_y": "state_name"})
    merged.to_csv("data/divi_data_with_latlong_stats.csv", index=False)
