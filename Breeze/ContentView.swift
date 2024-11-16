import SwiftUI
import CoreLocation

struct WeatherData: Codable {
    let main: Main
    let weather: [Weather]
    let name: String
}

struct Main: Codable {
    let temp: Double
    let feels_like: Double
    let temp_min: Double
    let temp_max: Double
    let humidity: Int
}


struct Weather: Codable {
    let description: String
}

struct City: Identifiable {
    let id = UUID()
    let name: String
    let country: String
}

struct GeoNamesResponse: Codable {
    let geonames: [GeoName]
}

struct GeoName: Codable {
    let name: String
    let countryName: String
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var cityName: String = "Fetching location..."
    @Published var locationError: String? = nil
    
    override init() {
        super.init()
        locationManager.delegate = self
        requestAuthorization()
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            // Do nothing, wait for user response
            locationManager.requestWhenInUseAuthorization()
            break
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.locationError = "Location access denied. Please enable location permissions in settings."
            }
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        fetchCityName(from: location)
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if CLLocationManager.authorizationStatus() == .denied {
            DispatchQueue.main.async {
                self.locationError = "Location access denied. Please enable location permissions in settings."
            }
        } else {
            DispatchQueue.main.async {
                self.locationError = "Failed to fetch location: \(error.localizedDescription)"
            }
        }
    }
    
    private func fetchCityName(from location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                self.locationError = "Failed to fetch city: \(error.localizedDescription)"
                return
            }
            
            if let city = placemarks?.first?.locality {
                self.cityName = city
            } else {
                self.locationError = "City not found"
            }
        }
    }
}

struct AnimatedWeatherView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var temperature: String = "--°C"
    @State private var weatherDescription: String = "Fetching weather..."
    @State private var feelsLike: String = "--°C"
    @State private var tempMin: String = "--°C"
    @State private var tempMax: String = "--°C"
    @State private var humidity: String = "--%"
    @State private var isLoading: Bool = true
    @State private var gradientColors: [Color] = [.red, .orange]
    @State private var currentColors: [Color] = [.black, .black, .black]
    @State private var animationTimer: Timer?
    @State private var showCitySearch: Bool = false
    
    let apiKey = ProcessInfo.processInfo.environment["OW_API_KEY"] ?? ""
    
    var body: some View {
        ZStack {
            // Animated Radial Gradient Background
            RadialGradient(gradient: Gradient(colors: currentColors),
                           center: .top,
                           startRadius: 0,
                           endRadius: UIScreen.main.bounds.height * 0.8)
            .edgesIgnoringSafeArea(.all)
            .animation(.easeInOut(duration: 3), value: currentColors)
            
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    if let locationError = locationManager.locationError {
                        Text(locationError)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.white)
                                .font(.headline)
                            
                            Text(locationManager.cityName)
                                .font(.headline)
                                .foregroundColor(.white)
                                .onTapGesture {
                                    showCitySearch = true // Show city search modal
                                }
                        }
                        .padding(.top, 20)
                        
                        Text(temperature)
                            .font(Font.custom("TerminaTest-Demi", size: 100))
                            .foregroundColor(.white)
                        
                        Text(weatherDescription)
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        
                        // Additional weather details
                        HStack(spacing: 24) {
                            VStack(alignment: .leading) {
                                Text("Feels Like")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(feelsLike)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Min Temp")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(tempMin)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Max Temp")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(tempMax)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Humidity")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(humidity)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.vertical, 14)
                        .background(
                            VStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.white)
                                    .opacity(0.5)
                                Spacer()
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.white)
                                    .opacity(0.5)
                            }
                        )
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
            }
        }
        .refreshable {
            fetchWeather()
        }
        .onChange(of: locationManager.cityName, perform: { _ in fetchWeather() })
        .onAppear {
            fetchWeather()
            startGradientAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
        .sheet(isPresented: $showCitySearch) {
            CitySearchView { selectedCity in
                locationManager.cityName = selectedCity
                showCitySearch = false
                fetchWeather() // Fetch weather for selected city
            }
        }
    }
    
    private func fetchWeather() {
        guard locationManager.cityName != "Fetching location..." else { return }
        
        isLoading = true
        let cityEscaped = locationManager.cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? locationManager.cityName
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(cityEscaped)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                isLoading = false
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }
            
            guard error == nil else { return }
            
            guard let data = data else { return }
            
            do {
                let weatherData = try JSONDecoder().decode(WeatherData.self, from: data)
                DispatchQueue.main.async {
                    let temp = Int(weatherData.main.temp)
                    self.temperature = "\(temp)°C"
                    self.weatherDescription = weatherData.weather.first?.description.capitalized ?? "Sunny"
                    self.feelsLike = "\(Int(weatherData.main.feels_like))°C"
                    self.tempMin = "\(Int(weatherData.main.temp_min))°C"
                    self.tempMax = "\(Int(weatherData.main.temp_max))°C"
                    self.humidity = "\(weatherData.main.humidity)%"
                    self.updateGradient(for: temp)
                }
            } catch {
                DispatchQueue.main.async {
                    self.temperature = "--°C"
                    self.weatherDescription = "Failed to fetch weather"
                }
            }
        }.resume()
    }
    
    private func updateGradient(for temperature: Int) {
        switch temperature {
        case ..<5:
            gradientColors = [.blue, .gray]
        case 5..<15:
            gradientColors = [.blue, .green]
        case 15..<30:
            gradientColors = [.yellow, .orange]
        default:
            gradientColors = [.red, .orange]
        }
    }
    
    private func startGradientAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.currentColors = gradientColors.shuffled() + [.black]
            }
        }
    }
}

struct CitySearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchQuery: String = ""
    @State private var cities: [City] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var onCitySelect: (String) -> Void
    
    let geoNamesUsername = "knezzic" // Replace with your GeoNames username
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar always at the top
                TextField("Search for a city", text: $searchQuery)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .onChange(of: searchQuery) { newValue in
                        if newValue.count > 2 {
                            fetchCitySuggestions(query: newValue)
                        } else {
                            cities.removeAll()
                        }
                    }
                
                // Display results or loading/error message
                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    List {
                        ForEach(cities) { city in
                            VStack(alignment: .leading) {
                                Text(city.name)
                                    .font(.headline)
                                Text(city.country)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .onTapGesture {
                                onCitySelect(city.name)
                                dismiss()
                            }
                        }
                    }
                    
                }
                Spacer() // Push content above to the top
            }
            .navigationBarTitle("Search Cities", displayMode: .inline)
            .navigationBarItems(leading: Button("Close") {
                dismiss()
            })
        }
    }
    
    private func fetchCitySuggestions(query: String) {
        guard let url = URL(string: "https://secure.geonames.org/searchJSON?name_startsWith=\(query)&maxRows=10&username=\(geoNamesUsername)") else {
            errorMessage = "Invalid URL."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    errorMessage = "No data received."
                }
                return
            }
            
            do {
                let geoNamesResponse = try JSONDecoder().decode(GeoNamesResponse.self, from: data)
                DispatchQueue.main.async {
                    cities = geoNamesResponse.geonames.map {
                        City(name: $0.name, country: $0.countryName)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Failed to decode response."
                }
            }
        }.resume()
    }
}

#Preview {
    AnimatedWeatherView()
}
