import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nepse_market_app/providers/paper_trading_provider.dart';
import 'package:nepse_market_app/providers/market_provider.dart';
import 'package:nepse_market_app/screens/paper_trading/paper_trade_execution_screen.dart';
import 'dart:math';
import 'package:nepse_market_app/models/paper_trade.dart'; // Ensure this is the correct path to the PaperTrade class

class PaperTradingScreen extends StatefulWidget {
  const PaperTradingScreen({Key? key}) : super(key: key);

  @override
  _PaperTradingScreenState createState() => _PaperTradingScreenState();
}

class _PaperTradingScreenState extends State<PaperTradingScreen> with SingleTickerProviderStateMixin {
  final formatter = NumberFormat("#,##0.00", "en_US");
  bool _dataLoaded = false;
  late TabController _tabController;
  
  // For NEPSE Index chart
  List<FlSpot> _indexPoints = [];
  bool _loadingChart = true;
  String _selectedTimeframe = '1D'; // Default timeframe
  final List<String> _timeframes = ['1D', '1W', '1M', '3M', '6M', '1Y'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _loadingChart = true;
      _dataLoaded = true;
    });
    
    try {
      // Load portfolio data
      final provider = Provider.of<PaperTradingProvider>(context, listen: false);
      await provider.loadPaperPortfolios();
      
      // Load NEPSE index data
      final marketProvider = Provider.of<MarketProvider>(context, listen: false);
      await marketProvider.loadAllMarketData();
      
      // Generate chart points for the selected timeframe
      _generateChartData(marketProvider);
    } catch (e) {
      print("Error loading data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loadingChart = false;
        });
      }
    }
  }
  
  void _generateChartData(MarketProvider marketProvider) {
    try {
      List<FlSpot> points = [];
      
      // Try to get actual index historical data
      if (marketProvider.indices.isNotEmpty) {
        // For actual implementation, use real data points from API
        // Using simulated data with slightly realistic patterns
        final baseValue = marketProvider.indices.first['value']?.toDouble() ?? 2000.0;
        final random = Random(42); // Fixed seed for consistent results
        double lastValue = baseValue;
        
        // Generate data with realistic price movement (momentum + reversion)
        for (int i = 30; i >= 0; i--) {
          // Momentum + mean reversion model (simple)
          double momentum = (lastValue - baseValue) * 0.2;  // Slight trend
          double reversion = (baseValue - lastValue) * 0.3; // Pull back to mean
          double noise = (random.nextDouble() - 0.5) * 15.0; // Random noise
          
          lastValue = lastValue + momentum + reversion + noise;
          points.add(FlSpot((30-i).toDouble(), lastValue));
        }
      }
      
      setState(() {
        _indexPoints = points;
      });
    } catch (e) {
      print("Error generating chart data: $e");
      setState(() {
        _indexPoints = [];
      });
    } finally {
      setState(() {
        _loadingChart = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer2<PaperTradingProvider, MarketProvider>(
          builder: (context, paperProvider, marketProvider, child) {
            // First check loading state
            if (paperProvider.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading trading data...'),
                  ],
                )
              );
            }

            // Check if we have portfolios
            if (paperProvider.paperPortfolios.isEmpty) {
              return _buildErrorView("No paper portfolio available");
            }

            // If portfolios exist but selected is null, select the first one
            final portfolio = paperProvider.selectedPaperPortfolio ?? 
                            (paperProvider.paperPortfolios.isNotEmpty ? 
                             paperProvider.paperPortfolios.first : null);
                             
            if (portfolio == null) {
              return _buildErrorView("Failed to load portfolio");
            }
            
            // Continue with rendering the UI using the portfolio...
            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    title: Text('Paper Trading'),
                    pinned: true,
                    floating: true,
                    forceElevated: innerBoxIsScrolled,
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).primaryColor,
                      indicatorColor: Theme.of(context).primaryColor,
                      tabs: [
                        Tab(text: 'Dashboard'),
                        Tab(text: 'Holdings'),
                        Tab(text: 'History'),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: _loadAllData,
                        tooltip: 'Refresh Market Data',
                      ),
                    ],
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(context, portfolio, marketProvider),
                  _buildHoldingsTab(context, portfolio, paperProvider),
                  _buildHistoryTab(context, paperProvider.paperTrades),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTradeSheet(context),
        icon: Icon(Icons.add),
        label: Text('New Trade'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
      ),
    );
  }

  Widget _buildDashboardTab(BuildContext context, dynamic portfolio, MarketProvider marketProvider) {
    final isProfit = portfolio.totalProfit >= 0;
    
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NEPSE Index Chart Card - Enhanced with trading vibe
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NEPSE Index',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!_loadingChart && marketProvider.indices.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: marketProvider.indices.first['change'] >= 0 
                                ? Colors.green.withOpacity(0.1) 
                                : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  marketProvider.indices.first['change'] >= 0 
                                    ? Icons.trending_up 
                                    : Icons.trending_down,
                                  color: marketProvider.indices.first['change'] >= 0 
                                    ? Colors.green[700] 
                                    : Colors.red[700],
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${marketProvider.indices.first['change'] >= 0 ? '+' : ''}${marketProvider.indices.first['percentChange'].toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: marketProvider.indices.first['change'] >= 0 
                                      ? Colors.green[700] 
                                      : Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (!_loadingChart && marketProvider.indices.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            'Rs. ${formatter.format(marketProvider.indices.first['value'] ?? 0)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${marketProvider.indices.first['change'] >= 0 ? '+' : ''}${formatter.format(marketProvider.indices.first['change'] ?? 0)}',
                            style: TextStyle(
                              color: marketProvider.indices.first['change'] >= 0 
                                ? Colors.green[700] 
                                : Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 16),
                    // Timeframe selector - More pro trading look
                    Container(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _timeframes.map((timeframe) => 
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(timeframe),
                              selected: _selectedTimeframe == timeframe,
                              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedTimeframe = timeframe;
                                  });
                                  // In real app: reload data for this timeframe
                                }
                              },
                            ),
                          )
                        ).toList(),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 200,
                      child: _loadingChart
                        ? Center(child: CircularProgressIndicator())
                        : _indexPoints.isEmpty
                          ? Center(child: Text('No chart data available'))
                          : Stack(
                              children: [
                                LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 100,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: Colors.grey.withOpacity(0.15),
                                          strokeWidth: 1,
                                          dashArray: [5, 5],
                                        );
                                      },
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 5,
                                          getTitlesWidget: (value, meta) {
                                            // Display dates along bottom (simplified)
                                            final now = DateTime.now();
                                            final days = value.toInt();
                                            final date = now.subtract(Duration(days: 30 - days));
                                            
                                            // Only show some dates to avoid crowding
                                            if (days % 5 != 0 && days != 30) return const SizedBox();
                                            
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(
                                                DateFormat('d/M').format(date),
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 45,
                                          interval: 200,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              value.toInt().toString(),
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _indexPoints,
                                        isCurved: true,
                                        color: marketProvider.indices.isNotEmpty && 
                                               marketProvider.indices.first['change'] >= 0
                                          ? Colors.green[600]
                                          : Colors.red[600],
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: false,
                                          getDotPainter: (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 2,
                                              color: Colors.white,
                                              strokeWidth: 2,
                                              strokeColor: barData.color ?? Colors.green,
                                            );
                                          }
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: marketProvider.indices.isNotEmpty &&
                                                   marketProvider.indices.first['change'] >= 0
                                              ? [
                                                  Colors.green.withOpacity(0.3),
                                                  Colors.green.withOpacity(0.0),
                                                ]
                                              : [
                                                  Colors.red.withOpacity(0.3),
                                                  Colors.red.withOpacity(0.0),
                                                ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Add volume indicator at bottom
                                Positioned(
                                  bottom: 20,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Vol: ${(Random().nextInt(5) + 1)}M',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    // Market statistics
                    if (!_loadingChart && marketProvider.indices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMarketStat('High', 'Rs. ${(marketProvider.indices.first['value'] + Random().nextDouble() * 20).toStringAsFixed(1)}'),
                            _buildMarketStat('Low', 'Rs. ${(marketProvider.indices.first['value'] - Random().nextDouble() * 30).toStringAsFixed(1)}'),
                            _buildMarketStat('Vol', '${Random().nextInt(9) + 1}M'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Portfolio Overview Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildValueTile(
                            'Total Value',
                            'Rs. ${formatter.format(portfolio.portfolioValue)}',
                            null,
                          ),
                        ),
                        Expanded(
                          child: _buildValueTile(
                            'Cash Balance',
                            'Rs. ${formatter.format(portfolio.currentBalance)}',
                            null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildValueTile(
                            'Invested',
                            'Rs. ${formatter.format(portfolio.totalInvestment)}',
                            null,
                          ),
                        ),
                        Expanded(
                          child: _buildValueTile(
                            'Profit/Loss',
                            '${isProfit ? '+' : ''}Rs. ${formatter.format(portfolio.totalProfit)}',
                            isProfit ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isProfit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isProfit ? Icons.trending_up : Icons.trending_down,
                            color: isProfit ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${isProfit ? '+' : ''}${portfolio.profitPercentage.toStringAsFixed(2)}% Overall Return',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isProfit ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Market Movers Section - Enhanced
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Market Movers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: Theme.of(context).primaryColor,
                            unselectedLabelColor: Colors.grey[600],
                            indicatorColor: Theme.of(context).primaryColor,
                            tabs: [
                              Tab(text: 'Top Gainers'),
                              Tab(text: 'Top Losers'),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            height: 200,
                            child: TabBarView(
                              children: [
                                marketProvider.gainers.isEmpty 
                                  ? Center(child: Text('No data available'))
                                  : ListView.builder(
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: min(5, marketProvider.gainers.length),
                                      itemBuilder: (context, index) {
                                        final stock = marketProvider.gainers[index];
                                        return ListTile(
                                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                                          onTap: () => _showTradeSheet(context, preSelectedSymbol: stock.symbol),
                                          title: Text(
                                            stock.symbol,
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            'Rs. ${formatter.format(stock.ltp)} | Vol: ${(Random().nextInt(99) + 1)}K',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '+${stock.changePercent.toStringAsFixed(2)}%',
                                              style: TextStyle(
                                                color: Colors.green[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                marketProvider.losers.isEmpty 
                                  ? Center(child: Text('No data available'))
                                  : ListView.builder(
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: min(5, marketProvider.losers.length),
                                      itemBuilder: (context, index) {
                                        final stock = marketProvider.losers[index];
                                        return ListTile(
                                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                                          onTap: () => _showTradeSheet(context, preSelectedSymbol: stock.symbol),
                                          title: Text(
                                            stock.symbol,
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            'Rs. ${formatter.format(stock.ltp)} | Vol: ${(Random().nextInt(99) + 1)}K',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${stock.changePercent.toStringAsFixed(2)}%',
                                              style: TextStyle(
                                                color: Colors.red[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Other methods remain unchanged...

  Widget _buildHistoryTab(BuildContext context, List<PaperTrade> paperTrades) {
    if (paperTrades.isEmpty) {
      return Center(
        child: Text(
          'No trade history available',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: paperTrades.length,
      itemBuilder: (context, index) {
        final trade = paperTrades[index];
        final isBuy = trade.type.toUpperCase() == 'BUY';
        
        return Card(
          elevation: 4,
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isBuy ? Colors.green[100] : Colors.red[100],
              child: Icon(
                isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                color: isBuy ? Colors.green[700] : Colors.red[700],
              ),
            ),
            title: Text(
              trade.symbol,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${trade.type}: ${trade.quantity} shares @ Rs. ${formatter.format(trade.price)}',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${formatter.format(trade.totalAmount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBuy ? Colors.red[700] : Colors.green[700],
                  ),
                ),
                Text(
                  DateFormat('MMM d, yy').format(trade.tradeDate),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHoldingsTab(BuildContext context, dynamic portfolio, PaperTradingProvider paperProvider) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: portfolio.holdings.length,
      itemBuilder: (context, index) {
        final holding = portfolio.holdings[index];
        return Card(
          elevation: 4,
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(
              holding.symbol,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Quantity: ${holding.quantity}'),
            trailing: Text(
              'Rs. ${formatter.format(holding.currentValue)}',
              style: TextStyle(
                color: holding.profit >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTradeSheet(BuildContext context, {String? preSelectedSymbol}) {
    // Get the portfolioId from the first portfolio (since we only have one)
    final portfolioId = Provider.of<PaperTradingProvider>(context, listen: false)
        .paperPortfolios
        .first
        .id;
    
    // Navigate to the trade execution screen with full page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaperTradeExecutionScreen(
          portfolioId: portfolioId,
          preSelectedSymbol: preSelectedSymbol,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh data when returning from trade screen
        _loadAllData();
      }
    });
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            onPressed: _loadAllData,
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Force create a new portfolio
              Provider.of<PaperTradingProvider>(context, listen: false)
                .createPaperPortfolio(
                  "Paper Trading Portfolio",
                  "Trade with NPR 150,000 virtual money without risk!",
                  150000.0
                ).then((_) => _loadAllData());
            },
            child: Text('Create New Portfolio'),
          ),
        ],
      ),
    );
  }

  Widget _buildValueTile(String title, String value, Color? valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}