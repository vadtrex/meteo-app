isDebug=0
inputCityName=""

weatherdata_request() {
debugEcho "*****************************"
debugEcho "Funkcja do pobierania danych ze wszystkich stacji pogodowych"
debugEcho "*****************************"
local weatherFile=~/.cache/meteoProject/weather_data.json
local cityInput=$1
debugEcho "Wprowadzone miasto: $cityInput"
if [ -f $weatherFile ] && [ $(jq -r '.[0] | .godzina_pomiaru ' ~/.cache/meteoProject/weather_data.json 2> /dev/null) == $(date "+%H") ] && [ $(jq -r '.[0] | .data_pomiaru ' ~/.cache/meteoProject/weather_data.json 2> /dev/null) == $(date "+%F") ] ; then 
      debugEcho "Plik $weatherFile istnieje i jest aktualny"
else
      debugEcho "Plik $weatherFile nie istnieje lub nie jest aktualny"
      debugEcho "Pobieranie danych pogodowych ze wszystkich stacji"
      curl -f -s --create-dirs -o $weatherFile https://danepubliczne.imgw.pl/api/data/synop/ 2> /dev/null
fi
weatherstationdata_parser $cityInput
}

debugEcho() {
      local displayText=$1
      if [ $isDebug == 1 ]; then
            echo "Debug Info: $1"
      fi
}

helpEcho() {
      echo -e "\nmeteoProject: ./meteoProject.sh"
      echo -e "  Wyświetla dane pogodowe korzystając z API IMGW-PIB i Nominatim\n"
      echo -e "  Parametry:"
      echo -e "  --c \"NAZWA_MIASTA\"   Wyświetla dane pogodowe z najbliższej do podanego miasta stacji pogodowej"
      echo -e "  --d   Włącza pokazywanie komunikatów o działaniu programu"
      echo -e "  --h   Wyświetla informacje o programie\n"
}

weatherstationdata_parser() {
debugEcho "*****************************"
debugEcho "Funkcja do pobierania współrzędnych geograficznych stacji pogodowych"
debugEcho "*****************************"
local cityInput=$1
cityDataFile=~/.cache/meteoProject/city_data.json
if [ ! -f "$cityDataFile" ]; then
      echo "Pobieranie współrzędnych geograficznych stacji pogodowych"
      echo "Potrwa to maksymalnie 2 minuty."
      for k in $(jq ". | keys | .[]" ~/.cache/meteoProject/weather_data.json 2> /dev/null); do
            cityNameURI=$(jq -r ".[$k] | .stacja | @uri" ~/.cache/meteoProject/weather_data.json 2> /dev/null)
            cityName=$(jq -r ".[$k] | .stacja" ~/.cache/meteoProject/weather_data.json 2> /dev/null)
            debugEcho "Pobrano stację z miasta: $cityName"
            curl -f -s -X GET --create-dirs "https://nominatim.openstreetmap.org/search?addressdetails=1&format=json&limit=1&accept-language=pl-PL&city=$cityNameURI" >> ~/.cache/meteoProject/city_data.json 2> /dev/null
            sleep 1
            local stationLongitude=$(jq -r --arg cityNameJQ "$cityName" '.[] | select(.name == $cityNameJQ) | .lon' ~/.cache/meteoProject/city_data.json 2> /dev/null)
            local stationLatitude=$(jq -r --arg cityNameJQ "$cityName" '.[] | select(.name == $cityNameJQ) | .lat' ~/.cache/meteoProject/city_data.json 2> /dev/null)
            debugEcho "Długość geograficzna: $stationLongitude"
            debugEcho "Szerokość geograficzna: $stationLatitude"
      done
      debugEcho "Zapisano współrzędne miast wszystkich stacji pogodowych do pliku: $cityDataFile"
fi
cityInput_dataRequest $cityInput
}



cityInput_dataRequest() {
debugEcho "*****************************"
debugEcho "Funkcja do pobierania współrzędnych wprowadzonego miasta"
debugEcho "*****************************"
local cityInput=$1
cityDataFile=~/.cache/meteoProject/city_data.json
local cityNameURI=$(jq -n --arg cityName "$cityInput" '$cityName | @uri' 2> /dev/null)
if [ ! $(jq -e --arg cityNameJQ "$cityInput" '.[] | select(.name == $cityNameJQ)' ~/.cache/meteoProject/city_data.json 2> /dev/null | head -n 1) ]; then
      sleep 1
      curl -f -s -X GET --create-dirs "https://nominatim.openstreetmap.org/search?addressdetails=1&format=json&limit=1&accept-language=pl-PL&city=$cityNameURI" >> ~/.cache/meteoProject/city_data.json 2> /dev/null
fi
local cityLongitude=$(jq -r --arg cityNameJQ "$cityInput" '.[] | select(.name == $cityNameJQ) | .lon' ~/.cache/meteoProject/city_data.json 2> /dev/null)
local cityLatitude=$(jq -r --arg cityNameJQ "$cityInput" '.[] | select(.name == $cityNameJQ) | .lat' ~/.cache/meteoProject/city_data.json 2> /dev/null)
debugEcho "Zapisano współrzędne wprowadzonego miasta do pliku: $cityDataFile"
distance_calculator "$cityLongitude" "$cityLatitude"
}

distance_calculator() {
debugEcho "*****************************"
debugEcho "Funkcja do obliczania najmniejszego dystansu stacji pogodowej od wprowadzonego miasta"
debugEcho "*****************************"
local cityLongitude="$1"
cityLatitude="$2"
cityDataFile=~/.cache/meteoProject/city_data.json
local lowestDifferenceSum="540.1"
local lowestDifferenceStationCity=""
if [ -e "$cityDataFile" ]; then
      for k in $(jq ". | keys | .[]" ~/.cache/meteoProject/weather_data.json 2> /dev/null); do
            stationCityName=$(jq -r ".[$k] | .stacja" ~/.cache/meteoProject/weather_data.json 2> /dev/null)
            stationCityLongitude=$(jq -r --arg stationCityNameJQ "$stationCityName" '.[] | select(.name == $stationCityNameJQ) | .lon' ~/.cache/meteoProject/city_data.json 2> /dev/null)
            stationCityLatitude=$(jq -r --arg stationCityNameJQ "$stationCityName" '.[] | select(.name == $stationCityNameJQ) | .lat' ~/.cache/meteoProject/city_data.json 2> /dev/null)
            debugEcho "Pobrano stację z miasta: $stationCityName"
            debugEcho "Długość geograficzna miasta stacji: $stationCityLongitude"
            debugEcho "Szerokość geograficzna miasta stacji:: $stationCityLatitude"
            debugEcho "Długość geograficzna wprowadzonego miasta: $cityLongitude"
            debugEcho "Szerokość geograficzna wprowadzonego miasta: $cityLatitude"
            local longitudeDifference=$(echo "$stationCityLongitude - $cityLongitude" | bc -l | tr -d "-")
            local latitudeDifference=$(echo "$stationCityLatitude - $cityLatitude" | bc -l | tr -d "-")
            local newDifferenceSum=$(echo "$latitudeDifference + $longitudeDifference" | bc -l)
            debugEcho "Różnica długości geograficznych: $longitudeDifference"
            debugEcho "Różnica szerokości geograficznych: $latitudeDifference"
            debugEcho "Suma różnic: $newDifferenceSum"
            if [ 1 -eq $(echo "${newDifferenceSum} < ${lowestDifferenceSum}" | bc -l) ]; then
                  lowestDifferenceSum=$newDifferenceSum
                  lowestDifferenceStationCity=$stationCityName
            fi
      done
fi
local nearestStationID=$(jq -r  --arg lowestDifferenceStationCityJQ $lowestDifferenceStationCity '.[] | select(.stacja == $lowestDifferenceStationCityJQ) | .id_stacji' ~/.cache/meteoProject/weather_data.json 2> /dev/null)
debugEcho "Najmniejszy dystans od wprowadzonego miasta ma stacja w mieście $lowestDifferenceStationCity, różnica wynosi: $lowestDifferenceSum, ID Stacji: $nearestStationID"
weatherdata_output $nearestStationID
}


weatherdata_output() {
debugEcho "*****************************"
debugEcho "Funkcja do wyświetlania danych meteorologicznych"
debugEcho "*****************************"
local stationID=$1
local city=$(jq -r  --arg stationIDJQ $stationID '.[] | select(.id_stacji == $stationIDJQ) | .stacja' ~/.cache/meteoProject/weather_data.json 2> /dev/null)
local date=$(jq -r --arg stationIDJQ $stationID '.[] | select(.id_stacji == $stationIDJQ) | .data_pomiaru' ~/.cache/meteoProject/weather_data.json 2> /dev/null)
local time=$(jq -r --arg stationIDJQ $stationID '.[] | select(.id_stacji == $stationIDJQ) | .godzina_pomiaru' ~/.cache/meteoProject/weather_data.json 2> /dev/null)
local temperature=$(jq -r --arg stationIDJQ $stationID '.[] | select(.id_stacji == $stationIDJQ) | .temperatura' ~/.cache/meteoProject/weather_data.json 2> /dev/null)
local wind_speed=$(jq -r --arg stationIDJQ $stationID '.[] | select(.id_stacji == $stationIDJQ) | .predkosc_wiatru' ~/.cache/meteoProject/weather_data.json 2> /dev/null)
local wind_direction=$(jq -r --arg stationIDJQ $stationID '.[] | select(.id_stacji == $stationIDJQ) | .kierunek_wiatru' ~/.cache/meteoProject/weather_data.json 2> /dev/null) 
local humidity=$(jq -r --arg stationIDJQ $stationID '.[] | select(.id_stacji == $stationIDJQ) | .wilgotnosc_wzgledna' ~/.cache/meteoProject/weather_data.json 2> /dev/null)
local rainfall=$(jq -r --arg stationIDJQ $stationID '.[] | select(.id_stacji == $stationIDJQ) | .suma_opadu' ~/.cache/meteoProject/weather_data.json 2> /dev/null)
local pressure=$(jq -r --arg stationIDJQ $stationID '.[] | select(.id_stacji == $stationIDJQ) | .cisnienie' ~/.cache/meteoProject/weather_data.json 2> /dev/null)


echo "ID stacji:" $stationID
echo "Miejscowość stacji: " $city
echo "Pomiar z dnia " $date " o godzinie" $time":00"
echo "-------------------------------"
echo "Dane pogodowe:"
if [ -z "$temperature" ]
then
      echo "Temperatura: Brak danych"
else
      echo "Temperatura: " $temperature "°C"
fi
if [ -z "$wind_speed" ]
then
      echo "Prędkość wiatru: Brak danych"
else
      echo "Prędkość wiatru: " $wind_speed "m/s"
fi
if [ -z "$wind_direction" ]
then
      echo "Kierunek wiatru: Brak danych"
else
      echo "Kierunek wiatru: " $wind_direction "°"
fi
if [ -z "$humidity" ]
then
      echo "Wilgotność względna: Brak danych"
else
      echo "Wilgotność względna: " $humidity "%"
fi
if [ -z "$rainfall" ]
then
      echo "Suma opadu: Brak danych"
else
      echo "Suma opadu: " $rainfall "mm"
fi
if [ -z "$pressure" ]
then
      echo "Ciśnienie: Brak danych"
else
      echo "Ciśnienie: " $pressure "hPa"
fi
echo "-------------------------------"

}



while getopts ":hdc:" option; do
   case $option in
      h)
         helpEcho
         exit;;
      d)
         isDebug=1 ;;
      c)
         inputCityName=$OPTARG ;;
      
   esac
done

if [ ! $inputCityName == "" ]; then
      weatherdata_request $inputCityName
else
      echo "Wprowadź poprawną nazwę miasta przy użyciu parametru --c \"NAZWA_MIASTA\""
fi