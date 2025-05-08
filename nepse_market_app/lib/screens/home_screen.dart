import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:nepse_market_app/providers/auth_provider.dart';
import 'package:nepse_market_app/providers/market_provider.dart';
import 'package:nepse_market_app/screens/auth/login_screen.dart';
import 'package:nepse_market_app/screens/portfolio/portfolio_list_screen.dart';
import 'package:nepse_market_app/screens/tools/share_calculator_screen.dart';
import 'package:nepse_market_app/screens/tools/ipo_result_screen.dart';
import 'package:nepse_market_app/screens/tools/market_calendar_screen.dart';
import 'package:nepse_market_app/screens/tools/broker_info_screen.dart';
import 'package:nepse_market_app/screens/tools/news_updates_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nepse_market_app/screens/company/company_details_screen.dart';
import 'package:nepse_market_app/screens/live_trading_screen.dart';
import 'package:nepse_market_app/screens/profile/profile_screen.dart';
import 'package:nepse_market_app/screens/paper_trading/paper_trading_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedIndex = 'NEPSE';
  int _currentTabIndex = 0;

  // Don't make _screens a final field since we need to rebuild it when state changes
  late List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    // Initialize screens with proper callback
    _updateScreens();
    
    // Use a post-frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final marketProvider = Provider.of<MarketProvider>(context, listen: false);
        marketProvider.loadAllMarketData();
      }
    });
  }
  
  // Method to update screens list with fresh state
  void _updateScreens() {
    _screens = [
      HomeScreenContent(
        selectedIndex: _selectedIndex,
        onIndexSelected: (newIndex) {
          setState(() {
            _selectedIndex = newIndex;
            _updateScreens();
          });
        },
      ),
      PaperTradingScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final marketProvider = Provider.of<MarketProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEPSE Market App'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              marketProvider.loadAllMarketData();
            },
            tooltip: 'Refresh Market Data',
          ),
        ],
      ),
      body: _screens[_currentTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Paper Trading',
          ),
        ],
      ),
    );
  }
}

class HomeScreenContent extends StatelessWidget {
  final String selectedIndex;
  final Function(String)? onIndexSelected; // Add this callback

  HomeScreenContent({
    required this.selectedIndex,
    this.onIndexSelected, // Add this parameter
  });
  @override
  Widget build(BuildContext context) {
    final marketProvider = Provider.of<MarketProvider>(context);
    return RefreshIndicator(
      onRefresh: () async {
        await marketProvider.loadLiveTrading();
        await marketProvider.loadIndices();
      },
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Section with Index Selector
            _buildHeroSection(context, marketProvider),
            
            // Market Summary Sections
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Market Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTopGainersSection(context, marketProvider),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTopLosersSection(context, marketProvider),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tools Grid Menu
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tools & Features',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildToolsGrid(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, MarketProvider marketProvider) {
    // Define defaults to use before data loads
    Map<String, dynamic> selectedIndexData = {
      'name': selectedIndex,
      'value': 0.0,
      'change': 0.0,
      'percentChange': 0.0
    };
    double indexValue = 0;
    double indexChange = 0;
    double percentChange = 0;
    bool isPositive = false;
    String effectiveSelectedIndex = selectedIndex;
    List<String> uniqueIndices = [];
    
    // Process indices data if available
    if (!marketProvider.isLoadingIndices && marketProvider.indices.isNotEmpty) {
      // Step 1: Extract unique index names with a Map approach for deduplication
      final indexNameMap = <String, bool>{};
      for (var index in marketProvider.indices) {
        if (index['name'] != null && index['name'].toString().isNotEmpty) {
          // Use the exact name as the key to ensure uniqueness
          indexNameMap[index['name'].toString()] = true;
        }
      }
      uniqueIndices = indexNameMap.keys.toList();
      
      // Step 2: Make sure we have a valid selection
      bool hasSelectedIndex = uniqueIndices.contains(effectiveSelectedIndex);
      
      // If current selection doesn't exist, use the first available
      if (!hasSelectedIndex && uniqueIndices.isNotEmpty) {
        // Just use the first index for display without setState
        effectiveSelectedIndex = uniqueIndices.first;
      }
      
      // Find index data for the effective selection
      if (uniqueIndices.isNotEmpty) {
        selectedIndexData = _findIndexData(marketProvider.indices, effectiveSelectedIndex);
        
        // Extract values for display with safe parsing
        indexValue = _parseDouble(selectedIndexData['value'] ?? 0.0);
        indexChange = _parseDouble(selectedIndexData['change'] ?? 0.0);
        percentChange = _parseDouble(selectedIndexData['percentChange'] ?? 0.0);
        isPositive = percentChange >= 0;
      }
    }
    
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Market Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              // Only show dropdown if we have indices to show
              uniqueIndices.isEmpty
              ? Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      // Ensure we have a valid value for the dropdown
                      value: uniqueIndices.contains(effectiveSelectedIndex) ? 
                        effectiveSelectedIndex : uniqueIndices.first,
                      dropdownColor: Theme.of(context).primaryColor.withOpacity(0.9),
                      style: TextStyle(color: Colors.white),
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      items: uniqueIndices.map((indexName) {
                        return DropdownMenuItem<String>(
                          value: indexName,
                          child: Text(indexName, style: TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null && onIndexSelected != null) {
                          onIndexSelected!(newValue);
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20),
          marketProvider.isLoadingIndices
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          indexValue.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 16),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPositive ? Colors.green[700] : Colors.red[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${percentChange.toStringAsFixed(2)}% (${indexChange.toStringAsFixed(2)})',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 80,
                      child: _buildMiniChart(isPositive),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Last Updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // Simple chart for visualization
  Widget _buildMiniChart(bool isPositive) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              FlSpot(0, 2),
              FlSpot(1, 1),
              FlSpot(2, 3),
              FlSpot(3, 2.5),
              FlSpot(4, 3.5),
              FlSpot(5, 3),
              FlSpot(6, isPositive ? 4 : 2),
            ],
            isCurved: true,
            color: Colors.white,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
        lineTouchData: LineTouchData(enabled: false),
      ),
    );
  }

  Widget _buildTopGainersSection(BuildContext context, MarketProvider marketProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Gainers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_upward, color: Colors.green, size: 16),
              ],
            ),
            SizedBox(height: 12),
            marketProvider.isLoadingGainers 
              ? Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : marketProvider.gainers.isEmpty
                ? Center(child: Text('No data available'))
                : Column(
                    children: marketProvider.gainers
                      .take(5) // Show only top 5
                      .map((stock) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CompanyDetailsScreen(
                                  symbol: stock.symbol,
                                  companyName: stock.companyName,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stock.symbol,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Rs. ${stock.ltp.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+${stock.changePercent.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                      .toList(),
                  ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopLosersSection(BuildContext context, MarketProvider marketProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Losers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_downward, color: Colors.red, size: 16),
              ],
            ),
            SizedBox(height: 12),
            marketProvider.isLoadingLosers 
              ? Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : marketProvider.losers.isEmpty
                ? Center(child: Text('No data available'))
                : Column(
                    children: marketProvider.losers
                      .take(5) // Show only top 5
                      .map((stock) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CompanyDetailsScreen(
                                  symbol: stock.symbol,
                                  companyName: stock.companyName,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stock.symbol,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Rs. ${stock.ltp.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${stock.changePercent.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                      .toList(),
                  ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildToolsGrid(BuildContext context) {
    List<Map<String, dynamic>> tools = [
      {
        'title': 'Portfolio',
        'icon': Icons.account_balance_wallet,
        'color': Colors.green,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PortfolioListScreen()),
          );
        },
      },
      {
        'title': 'Live Trading',
        'icon': Icons.trending_up,
        'color': Colors.teal,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LiveTradingScreen()),
          );
        },
      },
      {
        'title': 'Calculator',
        'icon': Icons.calculate,
        'color': Colors.blue,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ShareCalculatorScreen()),
          );
        },
      },
      {
        'title': 'IPO Results',
        'icon': Icons.how_to_vote,
        'color': Colors.orange,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => IpoResultScreen()),
          );
        },
      },
      {
        'title': 'Calendar',
        'icon': Icons.calendar_today,
        'color': Colors.purple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MarketCalendarScreen()),
          );
        },
      },
      {
        'title': 'Broker Info',
        'icon': Icons.business,
        'color': Colors.indigo,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BrokerInfoScreen()),
          );
        },
      },
      {
        'title': 'News',
        'icon': Icons.article,
        'color': Colors.red,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewsUpdatesScreen()),
          );
        },
      },
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: tool['onTap'],
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tool['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tool['icon'],
                    size: 28,
                    color: tool['color'],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  tool['title'],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to find index data by name
  Map<String, dynamic> _findIndexData(List<Map<String, dynamic>> indices, String name) {
    if (indices.isEmpty) {
      return {'name': name, 'value': 0.0, 'change': 0.0, 'percentChange': 0.0};
    }
    
    try {
      return indices.firstWhere(
        (index) => index['name'] == name,
        orElse: () => indices.isNotEmpty ? indices.first : 
          {'name': name, 'value': 0.0, 'change': 0.0, 'percentChange': 0.0}
      );
    } catch (e) {
      // Fallback in case of any errors
      return {'name': name, 'value': 0.0, 'change': 0.0, 'percentChange': 0.0};
    }
  }

  // Helper method to safely parse doubles from various data types
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }
}