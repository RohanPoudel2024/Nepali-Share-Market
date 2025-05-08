# NEPSE Market App

This is a Flutter application that provides real-time data for the Nepal Stock Exchange (NEPSE). The app fetches and displays information about top gainers, live trading data, and various market indices.

## Features

- **Home Screen**: Overview of the market with quick access to different sections.
- **Top Gainers**: Displays the top gainers in the market by fetching data from the NEPSE API.
- **Live Trading**: Shows live trading data, allowing users to stay updated with real-time market changes.
- **Market Indices**: Provides information on various market indices.

## API Endpoints

The app utilizes the following API endpoints:

- **Top Gainers**: `https://nepse-top-gainers.onrender.com/api/gainers`
- **Live Trading Data**: `https://nepse-top-gainers.onrender.com/api/live-trading`
- **Indices Data**: `https://nepse-top-gainers.onrender.com/api/indices`

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- An IDE (e.g., Android Studio, VS Code)

### Installation

1. Clone the repository:
   ```
   git clone <repository-url>
   ```
2. Navigate to the project directory:
   ```
   cd nepse_market_app
   ```
3. Install the dependencies:
   ```
   flutter pub get
   ```

### Running the App

To run the app, use the following command:
```
flutter run
```

## Folder Structure

- `lib/`: Contains the main application code.
  - `main.dart`: Entry point of the application.
  - `screens/`: Contains the different screens of the app.
  - `models/`: Contains data models for the application.
  - `services/`: Contains services for API calls.
  - `widgets/`: Contains reusable widgets.
  - `utils/`: Contains utility constants.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

## License

This project is licensed under the MIT License. See the LICENSE file for details.