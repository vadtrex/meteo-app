param (
    [string]$c = "",
    [switch]$d = $false,
    [switch]$h = $false
)

$ErrorActionPreference='silentlycontinue'
$isDebug=0
$inputCityName=""

if ($d) {
      $isDebug=1
}

if (-not ($c -eq "")) {
      $inputCityName = $c
}

function weatherdata_request {
Write-Debug "*****************************"
Write-Debug "Funkcja do pobierania danych ze wszystkich stacji pogodowych"
Write-Debug "*****************************"
$weatherFile="$env:LOCALAPPDATA\meteoProject\weather_data.json" 
$cityInput=$args[0]
Write-Debug "Wprowadzone miasto: $cityInput"
if ( ( Test-Path -Path $weatherFile -PathType leaf ) -and ( $((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json" | ConvertFrom-Json) | Select-Object -First 1 | Select-Object -ExpandProperty godzina_pomiaru) -eq $(Get-Date -Format "HH") ) ) {
      Write-Debug "Plik $weatherFile istnieje i jest aktualny"
} 
else {
      Write-Debug "Plik $weatherFile nie istnieje lub nie jest aktualny"
      Write-Debug "Pobieranie danych pogodowych ze wszystkich stacji"
      curl -f -s --create-dirs -o $weatherFile https://danepubliczne.imgw.pl/api/data/synop/ 
}
weatherstationdata_parser $cityInput
}

function Write-Debug {
      $displayText=$args[0]
      if ( $isDebug -eq 1 ) { 
            Write-Host "Debug Info: $displayText"
        }
}

function Write-Help {
      Write-Host "`nmeteoProject: .\meteoProject.ps1"
      Write-Host "  Wyświetla dane pogodowe korzystając z API IMGW-PIB i Nominatim`n"
      Write-Host "  Parametry:"
      Write-Host "  -c `"NAZWA_MIASTA`"   Wyświetla dane pogodowe z najbliższej do podanego miasta stacji pogodowej"
      Write-Host "  -d   Włącza pokazywanie komunikatów o działaniu programu"
      Write-Host "  -h   Wyświetla informacje o programie`n"
}

function weatherstationdata_parser {
Write-Debug "*****************************"
Write-Debug "Funkcja do pobierania współrzędnych geograficznych stacji pogodowych"
Write-Debug "*****************************"
$cityInput=$args[0]
$cityDataFile="$env:LOCALAPPDATA\meteoProject\city_data.json" 
if (! ( Test-Path -Path $cityDataFile -PathType leaf )) {
      Write-Host "Pobieranie współrzędnych geograficznych stacji pogodowych"
      Write-Host "Potrwa to maksymalnie 2 minuty."
      echo "[" > $cityDataFile
      foreach ($k in (Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json" | ConvertFrom-Json)) {
            $cityName=$(($k) | Select-Object -ExpandProperty stacja)
            $cityNameURI=$([uri]::EscapeUriString($cityName))
            Write-Debug "Pobrano stację z miasta: $cityName"
            curl -f -s -X GET --create-dirs "https://nominatim.openstreetmap.org/search?addressdetails=1&format=json&limit=1&accept-language=pl-PL&city=$cityNameURI" >> $cityDataFile
            if (! ($cityName -eq "Zielona Góra")) {
                  echo "," >> $cityDataFile
            }
            Start-Sleep -Seconds 1
      }
      echo "]" >> $cityDataFile
      Write-Debug "Zapisano współrzędne miast wszystkich stacji pogodowych do pliku: $cityDataFile"
}
cityInput_dataRequest $cityInput
}

function cityInput_dataRequest {
Write-Debug "*****************************"
Write-Debug "Funkcja do pobierania współrzędnych wprowadzonego miasta"
Write-Debug "*****************************"
$cityInput=$args[0]
$cityNameURI=$([uri]::EscapeUriString($cityInput))
Start-Sleep -Seconds 1
$response = $(Invoke-WebRequest -Uri "https://nominatim.openstreetmap.org/search?addressdetails=1&format=json&limit=1&accept-language=pl-PL&city=$cityNameURI" | ConvertFrom-Json)
$cityLongitude=$($response | Select-Object -ExpandProperty lon)
$cityLatitude=$($response | Select-Object -ExpandProperty lat)
distance_calculator $cityLongitude $cityLatitude
}

function distance_calculator {
Write-Debug "*****************************"
Write-Debug "Funkcja do obliczania najmniejszego dystansu stacji pogodowej od wprowadzonego miasta"
Write-Debug "*****************************"
$cityLongitude=$args[0]
$cityLatitude=$args[1]
$cityDataFile="$env:LOCALAPPDATA\meteoProject\city_data.json" 
$lowestDifferenceSum=540.1
$lowestDifferenceStationCity=""
if (Test-Path -Path $cityDataFile -PathType leaf) {
      foreach ($k in (Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json" | ConvertFrom-Json)) {
            $stationCityName=$(($k) | Select-Object -ExpandProperty stacja)
            $stationCityLongitude=$(((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\city_data.json" | ConvertFrom-Json) | Where-Object { $_.name -eq $stationCityName }).lon)
            $stationCityLatitude=$(((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\city_data.json" | ConvertFrom-Json) | Where-Object { $_.name -eq $stationCityName }).lat)
            Write-Debug "Pobrano stację z miasta: $stationCityName"
            Write-Debug "Długość geograficzna miasta stacji: $stationCityLongitude"
            Write-Debug "Szerokość geograficzna miasta stacji: $stationCityLatitude"
            Write-Debug "Długość geograficzna wprowadzonego miasta: $cityLongitude"
            Write-Debug "Szerokość geograficzna wprowadzonego miasta: $cityLatitude"
            $longitudeDifference=$([math]::abs($stationCityLongitude - $cityLongitude))
            $latitudeDifference=$([math]::abs($stationCityLatitude - $cityLatitude))
            $newDifferenceSum=$latitudeDifference+$longitudeDifference
            Write-Debug "Różnica długości geograficznych: $longitudeDifference"
            Write-Debug "Różnica szerokości geograficznych: $latitudeDifference"
            Write-Debug "Suma różnic: $newDifferenceSum"
            if ($newDifferenceSum -lt $lowestDifferenceSum) { 
                  $lowestDifferenceSum=$newDifferenceSum
                  $lowestDifferenceStationCity=$stationCityName
            }
}
}
$nearestStationID=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.stacja -eq $lowestDifferenceStationCity } | Select-Object -ExpandProperty id_stacji)
Write-Debug "Najmniejszy dystans od wprowadzonego miasta ma stacja w mieście $lowestDifferenceStationCity, różnica wynosi: $lowestDifferenceSum"
weatherdata_output $nearestStationID
}

function weatherdata_output() {
Write-Debug "*****************************"
Write-Debug "Funkcja do wyświetlania danych meteorologicznych"
Write-Debug "*****************************"
$stationID=$args[0]
$city=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.id_stacji -eq $stationID } | Select-Object -ExpandProperty stacja)
$date=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.id_stacji -eq $stationID } | Select-Object -ExpandProperty data_pomiaru)
$time=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.id_stacji -eq $stationID } | Select-Object -ExpandProperty godzina_pomiaru)
$temperature=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.id_stacji -eq $stationID } | Select-Object -ExpandProperty temperatura)
$wind_speed=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.id_stacji -eq $stationID } | Select-Object -ExpandProperty predkosc_wiatru)
$wind_direction=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.id_stacji -eq $stationID } | Select-Object -ExpandProperty kierunek_wiatru)
$humidity=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.id_stacji -eq $stationID } | Select-Object -ExpandProperty wilgotnosc_wzgledna)
$rainfall=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.id_stacji -eq $stationID } | Select-Object -ExpandProperty suma_opadu)
$pressure=$((Get-Content -Raw -Path "$env:LOCALAPPDATA\meteoProject\weather_data.json"  | ConvertFrom-Json) | Where-Object { $_.id_stacji -eq $stationID } | Select-Object -ExpandProperty cisnienie)

Write-Host "ID stacji:" $stationID
Write-Host "Miejscowość stacji: " $city
Write-Host "Pomiar z dnia " $date " o godzinie" $time":00"
Write-Host "-------------------------------"
Write-Host "Dane pogodowe:"

if ( -not "$temperature" ) {
      Write-Host "Temperatura: Brak danych"
}
else {
      Write-Host "Temperatura: " $temperature "°C"
}
if ( -not "$wind_speed" ) {
      Write-Host "Prędkość wiatru: Brak danych"
}
else {
      Write-Host "Prędkość wiatru: " $wind_speed "m/s"
}
if ( -not "$wind_direction" ) {
      Write-Host "Kierunek wiatru: Brak danych"
}
else {
      Write-Host "Kierunek wiatru: " $wind_direction "°"
}
if ( -not "$humidity" ) {
      Write-Host "Wilgotność względna: Brak danych"
}
else {
      Write-Host "Wilgotność względna: " $humidity "%"
}
if ( -not "$rainfall" ) {
      Write-Host "Suma opadu: Brak danych"
}
else {
      Write-Host "Suma opadu: " $rainfall "mm"
}
if ( -not "$pressure" ) {
      Write-Host "Ciśnienie: Brak danych"
}
else {
      Write-Host "Ciśnienie: " $pressure "hPa"
    }

Write-Host "-------------------------------"
}

if ($h) {
      Write-Help
      exit
}

if (!($inputCityName -eq "")) {
      weatherdata_request $inputCityName
}
else {
      Write-Host "Wprowadź poprawną nazwę miasta przy użyciu parametru -c `"NAZWA_MIASTA`""
}

