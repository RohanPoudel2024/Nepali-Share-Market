import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nepse_market_app/providers/auth_provider.dart';
import 'package:nepse_market_app/providers/market_provider.dart';
import 'package:nepse_market_app/providers/portfolio_provider.dart';
import 'package:nepse_market_app/screens/auth/login_screen.dart';
import 'package:nepse_market_app/providers/paper_trading_provider.dart';
import 'package:nepse_market_app/screens/home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  if (kIsWeb) {
    // Web initialization
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    // Desktop/mobile initialization
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MarketProvider()),
        ChangeNotifierProxyProvider<MarketProvider, PortfolioProvider>(
          create: (context) => PortfolioProvider(
            Provider.of<MarketProvider>(context, listen: false),
          ),
          update: (context, marketProvider, previousPortfolioProvider) => 
            previousPortfolioProvider ?? PortfolioProvider(marketProvider),
        ),
        ChangeNotifierProxyProvider<MarketProvider, PaperTradingProvider>(
          create: (context) => PaperTradingProvider(
            Provider.of<MarketProvider>(context, listen: false),
          ),
          update: (context, marketProvider, previousProvider) => 
            previousProvider ?? PaperTradingProvider(marketProvider),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEPSE Market App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _buildHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
  
  Widget _buildHomeScreen() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (authProvider.isAuthenticated) {
          return HomeScreen();
        }
        
        return LoginScreen();
      },
    );
  }
}