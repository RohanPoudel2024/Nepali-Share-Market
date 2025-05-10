import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nepse_market_app/providers/market_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nepse_market_app/utils/extensions.dart';
import 'package:nepse_market_app/utils/map_utils.dart';

class CompanyDetailsScreen extends StatefulWidget {
  final String symbol;
  final String? companyName;
  
  const CompanyDetailsScreen({
    Key? key,
    required this.symbol,
    this.companyName,
  }) : super(key: key);

  @override
  _CompanyDetailsScreenState createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _companyData = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Use postFrameCallback to load data after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final provider = Provider.of<MarketProvider>(context, listen: false);
      await provider.loadCompanyDetails(widget.symbol);
      
      if (!mounted) return;
      
      final companyDetails = provider.companyDetails;
      if (companyDetails != null) {
        setState(() {
          _companyData = Map<String, dynamic>.from(companyDetails);
          _isLoading = false;
        });
        print('Company data loaded successfully for ${widget.symbol}');
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load company details';
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading company details: $e';
      });
      print('Error loading company details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.companyName ?? widget.symbol),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading 
        ? _buildLoadingView()
        : _errorMessage != null 
          ? _buildErrorView(_errorMessage!)
          : _buildCompanyDetailsView(_companyData),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Loading company details...',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[700],
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Unable to Load Data',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: Colors.red[800],
            ),
          ),
          SizedBox(height: 12),
          Container(
            width: 280,
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyDetailsView(Map<String, dynamic> companyDetails) {
    try {
      // Debug the structure we're getting
      print('Company details structure: ${companyDetails.keys.toList()}');
      
      // Check if we have another nested level
      if (companyDetails.containsKey('data') && companyDetails['data'] is Map) {
        print('Found nested data, using that instead');
        companyDetails = Map<String, dynamic>.from(companyDetails['data']);
      }

      // Get basic company info
      final symbol = companyDetails['symbol'] as String? ?? widget.symbol;
      final companyName = companyDetails['companyName'] as String? ?? 'Unknown Company';
      final sector = companyDetails['sector'] as String? ?? 'N/A';
      
      // Get nested data structures - handle nulls and type casting properly
      Map<String, dynamic> marketData = {};
      Map<String, dynamic> keyMetrics = {};
      Map<String, dynamic> dividendInfo = {};
      
      // Safely extract nested maps
      if (companyDetails['marketData'] is Map) {
        marketData = Map<String, dynamic>.from(companyDetails['marketData'] as Map);
      }
      
      if (companyDetails['keyMetrics'] is Map) {
        keyMetrics = Map<String, dynamic>.from(companyDetails['keyMetrics'] as Map);
      }
      
      if (companyDetails['dividendInfo'] is Map) {
        dividendInfo = Map<String, dynamic>.from(companyDetails['dividendInfo'] as Map);
      }

      return NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return <Widget>[
            SliverToBoxAdapter(
              child: _buildHeaderSection(marketData, companyName, sector, symbol),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Performance'),
                    Tab(text: 'Financials'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(companyDetails, keyMetrics, marketData),
            _buildPerformanceTab(marketData),
            _buildFinancialsTab(keyMetrics, dividendInfo),
          ],
        ),
      );
    } catch (e) {
      // If we encounter any error in processing the data, show a fallback
      print('Error processing company details: $e');
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'There was an error processing company details data. Please try again later.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildHeaderSection(Map<String, dynamic> marketData, String companyName, String sector, String symbol) {
    try {
      // Extract data with proper type safety
      double currentPrice = 0.0;
      if (marketData['ltp'] != null) {
        currentPrice = (marketData['ltp'] is num) ? (marketData['ltp'] as num).toDouble() : 0.0;
      }
      
      double change = 0.0;
      if (marketData['change'] != null) {
        change = (marketData['change'] is num) ? (marketData['change'] as num).toDouble() : 0.0;
      }
      
      double percentChange = 0.0;
      if (marketData['percentChange'] != null) {
        percentChange = (marketData['percentChange'] is num) 
            ? (marketData['percentChange'] as num).toDouble() 
            : 0.0;
      } else if (currentPrice > 0) {
        final previousPrice = currentPrice - change;
        if (previousPrice > 0) {
          percentChange = (change / previousPrice) * 100;
        }
      }
      
      final isPositive = change >= 0;
      
      String lastTraded = 'N/A';
      if (marketData['lastTradedOn'] != null) {
        lastTraded = marketData['lastTradedOn'].toString();
      }
      
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company logo and name
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      symbol.isNotEmpty ? symbol.substring(0, min(2, symbol.length)) : "--",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          sector,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 28),
            
            // Price section
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Price',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Rs.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(width: 2),
                        Text(
                          currentPrice.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(width: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPositive ? Colors.green[700] : Colors.red[700],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isPositive ? Colors.green[800] : Colors.red[800])!.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      )
                    ],
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
                        '${isPositive ? "+" : ""}${percentChange.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Rs. ${change.abs().toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 16),
            
            // Chart
            Container(
              height: 80,
              margin: EdgeInsets.only(top: 8, right: 16),
              child: _buildMiniChart(isPositive),
            ),
            
            // Last traded info
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.white70,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Last Traded: $lastTraded',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error in header section: $e');
      return Container(
        padding: EdgeInsets.all(16),
        color: Theme.of(context).primaryColor,
        child: Text('Error loading company header', style: TextStyle(color: Colors.white)),
      );
    }
  }

  Widget _buildOverviewTab(Map<String, dynamic> companyDetails, Map<String, dynamic> keyMetrics, Map<String, dynamic> marketData) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    
    // Extract data safely as you currently do
    final symbol = companyDetails['symbol'] as String? ?? 'N/A';
    final companyName = companyDetails['companyName'] as String? ?? 'N/A';
    final sector = companyDetails['sector'] as String? ?? 'N/A';
    final source = companyDetails['source'] as String? ?? 'N/A';
    
    // Market cap calculation
    double marketCap = 0.0;
    if (keyMetrics['marketCap'] != null) {
      marketCap = (keyMetrics['marketCap'] is num) ? (keyMetrics['marketCap'] as num).toDouble() : 0.0;
    }
    
    // Other metrics extraction
    double sharesOutstanding = 0.0;
    if (keyMetrics['sharesOutstanding'] != null) {
      sharesOutstanding = (keyMetrics['sharesOutstanding'] is num) ? (keyMetrics['sharesOutstanding'] as num).toDouble() : 0.0;
    }
    
    String high52w = 'N/A';
    if (marketData['high52w'] != null) {
      high52w = marketData['high52w'].toString();
    }
    
    String low52w = 'N/A'; 
    if (marketData['low52w'] != null) {
      low52w = marketData['low52w'].toString();
    }
    
    double avgVolume30d = 0.0;
    if (marketData['avgVolume30d'] != null) {
      avgVolume30d = (marketData['avgVolume30d'] is num) ? (marketData['avgVolume30d'] as num).toDouble() : 0.0;
    }
    
    double yearYield = 0.0;
    if (marketData['yearYield'] != null) {
      yearYield = (marketData['yearYield'] is num) ? (marketData['yearYield'] as num).toDouble() : 0.0;
    }
    
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'Company Profile',
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Symbol', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        SizedBox(height: 4),
                        Text(
                          symbol, 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sector', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        SizedBox(height: 4),
                        Text(
                          sector, 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              _buildInfoRow('Company Name', companyName),
              _buildInfoRow('Source', source),
            ],
          ),
          
          _buildInfoCard(
            title: 'Market Information',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricBox(
                      label: 'Market Cap',
                      value: 'Rs. ${formatter.format(marketCap)}',
                      icon: Icons.bar_chart,
                      iconColor: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricBox(
                      label: 'Shares',
                      value: formatter.format(sharesOutstanding),
                      icon: Icons.people,
                      iconColor: Colors.purple,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _buildInfoRow('52W High', high52w, valueColor: Colors.green[700]),
              _buildInfoRow('52W Low', low52w, valueColor: Colors.red[700]),
              _buildInfoRow('Avg Volume (30d)', formatter.format(avgVolume30d)),
              _buildInfoRow('Year Yield', '${yearYield.toStringAsFixed(2)}%', 
                           valueColor: yearYield > 0 ? Colors.green[700] : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required IconData icon,
    Color? iconColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: iconColor ?? Colors.grey[700],
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(Map<String, dynamic> marketData) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    
    // Safe data extraction as you currently do
    double ltp = 0.0;
    if (marketData['ltp'] != null) {
      ltp = (marketData['ltp'] is num) ? (marketData['ltp'] as num).toDouble() : 0.0;
    }
    
    double change = 0.0;
    if (marketData['change'] != null) {
      change = (marketData['change'] is num) ? (marketData['change'] as num).toDouble() : 0.0;
    }
    
    String lastTradedOn = 'N/A';
    if (marketData['lastTradedOn'] != null) {
      lastTradedOn = marketData['lastTradedOn'].toString();
    }
    
    String high52w = 'N/A';
    if (marketData['high52w'] != null) {
      high52w = marketData['high52w'].toString();
    }
    
    String low52w = 'N/A';
    if (marketData['low52w'] != null) {
      low52w = marketData['low52w'].toString();
    }
    
    double avgVolume30d = 0.0;
    if (marketData['avgVolume30d'] != null) {
      avgVolume30d = (marketData['avgVolume30d'] is num) ? (marketData['avgVolume30d'] as num).toDouble() : 0.0;
    }

    final isPositive = change >= 0;
    
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'Price Performance',
            children: [
              // Visual price indicator
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Traded Price',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Rs. ${formatter.format(ltp)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                    color: isPositive ? Colors.green : Colors.red,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '${change.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: isPositive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Last Traded',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          lastTradedOn,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              
              // 52 Week range visualization
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '52 Week Range',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 60,
                    child: _build52WeekRangeChart(
                      low: double.tryParse(low52w.replaceAll('"', '')) ?? 0,
                      high: double.tryParse(high52w.replaceAll('"', '')) ?? 0,
                      current: ltp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              _buildInfoRow('52W High', high52w, valueColor: Colors.green[700]),
              _buildInfoRow('52W Low', low52w, valueColor: Colors.red[700]),
              _buildInfoRow('Avg Volume (30d)', formatter.format(avgVolume30d)),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Historical chart with placeholder
          _buildInfoCard(
            title: 'Price History',
            children: [
              Container(
                height: 250,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.insert_chart_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Historical price data not available',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build52WeekRangeChart({
    required double low,
    required double high,
    required double current,
  }) {
    // Ensure we have valid values and ranges
    if (low <= 0 || high <= 0 || low >= high) {
      return Center(child: Text('Invalid 52-week range data'));
    }
    
    // Calculate position percentage (0 to 1)
    double percentage = (current - low) / (high - low);
    percentage = percentage.clamp(0.0, 1.0);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Container(
              width: constraints.maxWidth,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [Colors.red[700]!, Colors.orange[500]!, Colors.green[700]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  width: constraints.maxWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rs. ${low.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Rs. ${high.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth * percentage - 8,
                  child: Column(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).primaryColor,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      }
    );
  }

  Widget _buildFinancialsTab(Map<String, dynamic> keyMetrics, Map<String, dynamic> dividendInfo) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    final percentFormatter = NumberFormat("##0.00", "en_US");
    
    // Extract EPS data safely as you do now
    double epsValue = 0.0;
    String fiscalYear = '';
    
    if (keyMetrics['eps'] != null) {
      if (keyMetrics['eps'] is Map) {
        final epsMap = keyMetrics['eps'] as Map;
        if (epsMap['value'] != null) {
          epsValue = (epsMap['value'] is num) ? (epsMap['value'] as num).toDouble() : 0.0;
        }
        if (epsMap['fiscalYear'] != null) {
          fiscalYear = epsMap['fiscalYear'].toString();
        }
      } else if (keyMetrics['eps'] is num) {
        epsValue = (keyMetrics['eps'] as num).toDouble();
      }
    }
    
    // Extract other financial metrics
    double pe = 0.0;
    if (keyMetrics['pe'] != null) {
      pe = (keyMetrics['pe'] is num) ? (keyMetrics['pe'] as num).toDouble() : 0.0;
    }
    
    double bookValue = 0.0;
    if (keyMetrics['bookValue'] != null) {
      bookValue = (keyMetrics['bookValue'] is num) ? (keyMetrics['bookValue'] as num).toDouble() : 0.0;
    }
    
    double pbv = 0.0;
    if (keyMetrics['pbv'] != null) {
      pbv = (keyMetrics['pbv'] is num) ? (keyMetrics['pbv'] as num).toDouble() : 0.0;
    }
    
    double avg120Day = 0.0;
    if (keyMetrics['avg120Day'] != null) {
      avg120Day = (keyMetrics['avg120Day'] is num) ? (keyMetrics['avg120Day'] as num).toDouble() : 0.0;
    }
    
    double avg180Day = 0.0;
    if (keyMetrics['avg180Day'] != null) {
      avg180Day = (keyMetrics['avg180Day'] is num) ? (keyMetrics['avg180Day'] as num).toDouble() : 0.0;
    }
    
    // Extract dividend data
    double cashDividend = 0.0;
    double bonusDividend = 0.0;
    double rightShare = 0.0;
    List<Map<String, dynamic>> bonusHistory = [];
    
    // Handle dividend data the same way as you do now
    // ...
    // Handle Cash Dividend
    if (dividendInfo['cash'] is Map) {
      final cashMap = dividendInfo['cash'] as Map;
      if (cashMap['latest'] != null) {
        cashDividend = (cashMap['latest'] is num) ? (cashMap['latest'] as num).toDouble() : 0.0;
      }
    }
    
    // Extract bonus history code the same as you have
    // ...
    
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'Key Metrics',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildFinancialMetricBox(
                      label: 'EPS',
                      value: 'Rs. ${epsValue.toStringAsFixed(2)}',
                      subtitle: fiscalYear,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildFinancialMetricBox(
                      label: 'P/E Ratio',
                      value: pe.toStringAsFixed(2),
                      subtitle: pe > 0 ? 'Multiple' : 'N/A',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFinancialMetricBox(
                      label: 'Book Value',
                      value: 'Rs. ${bookValue.toStringAsFixed(2)}',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildFinancialMetricBox(
                      label: 'PBV',
                      value: pbv.toStringAsFixed(2),
                      subtitle: pbv > 0 ? 'Multiple' : 'N/A',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _buildInfoRow('Avg 120 Day', 'Rs. ${avg120Day.toStringAsFixed(2)}'),
              _buildInfoRow('Avg 180 Day', 'Rs. ${avg180Day.toStringAsFixed(2)}'),
            ],
          ),
          
          SizedBox(height: 16),
          
          _buildInfoCard(
            title: 'Dividend Information',
            children: [
              SizedBox(height: 8),
              _buildDividendProgressBar(
                cashDividend: cashDividend,
                bonusDividend: bonusDividend,
                rightShare: rightShare,
              ),
              SizedBox(height: 20),
              _buildInfoRow('Cash Dividend', '${percentFormatter.format(cashDividend)}%', 
                           valueColor: cashDividend > 0 ? Colors.green[700] : null),
              _buildInfoRow('Bonus Share', '${percentFormatter.format(bonusDividend)}%',
                           valueColor: bonusDividend > 0 ? Colors.green[700] : null),
              _buildInfoRow('Right Share', '${percentFormatter.format(rightShare)}%',
                           valueColor: rightShare > 0 ? Colors.green[700] : null),
              Divider(height: 32),
              _buildInfoRow(
                'Total',
                '${percentFormatter.format(cashDividend + bonusDividend + rightShare)}%',
                valueColor: (cashDividend + bonusDividend + rightShare) > 0 ? Colors.green[700] : null,
              ),
            ],
          ),
          
          // Continue with any bonus history or other financial data
          // ...
        ],
      ),
    );
  }

  Widget _buildFinancialMetricBox({
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDividendProgressBar({
    required double cashDividend,
    required double bonusDividend,
    required double rightShare,
  }) {
    final total = cashDividend + bonusDividend + rightShare;
    
    // If no dividend, show empty state
    if (total <= 0) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No dividend information available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }
    
    // Calculate percentages for the stacked bar
    final cashPercent = cashDividend / total;
    final bonusPercent = bonusDividend / total;
    final rightPercent = rightShare / total;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dividend Breakdown',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.withOpacity(0.1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (cashDividend > 0)
                Expanded(
                  flex: (cashPercent * 100).round(),
                  child: Container(
                    color: Colors.blue[400],
                    child: Center(
                      child: Text(
                        'Cash',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              if (bonusDividend > 0)
                Expanded(
                  flex: (bonusPercent * 100).round(),
                  child: Container(
                    color: Colors.green[400],
                    child: Center(
                      child: Text(
                        'Bonus',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              if (rightShare > 0)
                Expanded(
                  flex: (rightPercent * 100).round(),
                  child: Container(
                    color: Colors.orange[400],
                    child: Center(
                      child: Text(
                        'Right',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Cash', Colors.blue[400]!),
            SizedBox(width: 16),
            _buildLegendItem('Bonus', Colors.green[400]!),
            SizedBox(width: 16),
            _buildLegendItem('Right', Colors.orange[400]!),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: overlapsContent ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ] : null,
      ),
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

// Helper function for min
int min(int a, int b) {
  return a < b ? a : b;
}