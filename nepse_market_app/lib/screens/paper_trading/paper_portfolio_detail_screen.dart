import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nepse_market_app/models/paper_portfolio.dart';
import 'package:nepse_market_app/models/paper_trade.dart';
import 'package:nepse_market_app/providers/paper_trading_provider.dart';
import 'package:nepse_market_app/screens/paper_trading/execute_paper_trade_screen.dart';
import 'package:nepse_market_app/screens/paper_trading/create_paper_portfolio_screen.dart';

class PaperPortfolioDetailScreen extends StatefulWidget {
  final int portfolioId;

  const PaperPortfolioDetailScreen({
    Key? key,
    required this.portfolioId,
  }) : super(key: key);

  @override
  _PaperPortfolioDetailScreenState createState() => _PaperPortfolioDetailScreenState();
}

class _PaperPortfolioDetailScreenState extends State<PaperPortfolioDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final formatter = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPortfolioDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPortfolioDetails() async {
    try {
      final provider = Provider.of<PaperTradingProvider>(context, listen: false);
      await provider.loadPaperPortfolioDetails(widget.portfolioId);
      
      // Force UI refresh
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error refreshing portfolio details: $e');
      // Show snackbar with error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh portfolio data')),
        );
      }
    }
  }

  void _executeNewTrade() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExecutePaperTradeScreen(
          portfolioId: widget.portfolioId,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadPortfolioDetails(); // Refresh the portfolio data
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaperTradingProvider>(
      builder: (context, provider, child) {
        final portfolio = provider.selectedPaperPortfolio;
        final isLoading = provider.isLoading;

        if (isLoading) {
          return Scaffold(
            appBar: AppBar(title: Text('Loading Portfolio')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading portfolio details...'),
                ],
              ),
            ),
          );
        }

        // Handle null portfolio - but this shouldn't happen with our fallback
        if (portfolio == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Portfolio Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  SizedBox(height: 16),
                  Text('Could not load portfolio'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Create a new portfolio as fallback
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => CreatePaperPortfolioScreen(),
                        ),
                      );
                    },
                    child: Text('Create New Portfolio'),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(portfolio.name),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _loadPortfolioDetails,
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Column(
            children: [
              _buildPortfolioSummary(portfolio),
              _buildPerformanceChart(context, portfolio),
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                tabs: [
                  Tab(text: 'Holdings'),
                  Tab(text: 'Trade History'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHoldingsTab(portfolio),
                    _buildTradeHistoryTab(provider.paperTrades),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _executeNewTrade,
            icon: Icon(Icons.add),
            label: Text('New Trade'),
          ),
        );
      },
    );
  }

  Widget _buildPortfolioSummary(PaperPortfolio portfolio) {
    final isProfit = portfolio.totalProfit >= 0;

    return Card(
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portfolio Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Balance',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rs. ${formatter.format(portfolio.currentBalance)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Invested Amount',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rs. ${formatter.format(portfolio.totalInvested)}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio Value',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rs. ${formatter.format(portfolio.portfolioValue)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Profit/Loss',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${isProfit ? '+' : ''}Rs. ${formatter.format(portfolio.totalProfit)} (${portfolio.profitPercentage.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isProfit ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceChart(BuildContext context, PaperPortfolio portfolio) {
    final List<FlSpot> spots = portfolio.paperTrades.isEmpty 
        ? [FlSpot(0, portfolio.initialBalance), FlSpot(1, portfolio.currentBalance)]
        : portfolio.paperTrades.asMap().entries.map((entry) {
            int index = entry.key;
            PaperTrade trade = entry.value;
            double balance = portfolio.initialBalance + 
                (index / portfolio.paperTrades.length) * 
                (portfolio.currentBalance - portfolio.initialBalance);
            return FlSpot(index.toDouble(), balance);
          }).toList();

    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portfolio Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: spots.length.toDouble() - 1,
                minY: spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) * 0.9,
                maxY: spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.1,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Theme.of(context).primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.3),
                          Theme.of(context).primaryColor.withOpacity(0.0),
                        ],
                        stops: [0.5, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldingsTab(PaperPortfolio portfolio) {
    if (portfolio.holdings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No Holdings Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Execute your first trade to get started',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: portfolio.holdings.length,
      itemBuilder: (context, index) {
        final holding = portfolio.holdings[index];
        final isProfit = holding.profit >= 0;

        return Card(
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holding.symbol,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (holding.companyName != null)
                            Text(
                              holding.companyName!,
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isProfit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${isProfit ? '+' : ''}${holding.profitPercentage.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: isProfit ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Price',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Rs. ${formatter.format(holding.currentPrice ?? holding.averageBuyPrice)}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Avg. Buy Price',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 4),
                        Text('Rs. ${formatter.format(holding.averageBuyPrice)}'),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantity',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 4),
                        Text('${holding.quantity}'),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Profit/Loss',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${isProfit ? '+' : ''}Rs. ${formatter.format(holding.profit)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isProfit ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTradeHistoryTab(List<PaperTrade> trades) {
    if (trades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No Trade History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your executed trades will appear here',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: trades.length,
      itemBuilder: (context, index) {
        final trade = trades[index];
        final isBuy = trade.type.toUpperCase() == 'BUY';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isBuy ? Colors.green[100] : Colors.red[100],
            child: Icon(
              isBuy ? Icons.arrow_downward : Icons.arrow_upward,
              color: isBuy ? Colors.green[700] : Colors.red[700],
            ),
          ),
          title: Text(
            '${trade.type} ${trade.symbol} (${trade.quantity} @ Rs. ${formatter.format(trade.price)})',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total: Rs. ${formatter.format(trade.totalAmount)}',
              ),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(trade.tradeDate),
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          isThreeLine: true,
        );
      },
    );
  }
}