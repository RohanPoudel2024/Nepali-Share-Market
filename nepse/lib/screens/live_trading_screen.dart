import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nepse_market_app/providers/market_provider.dart';
import 'package:intl/intl.dart';
import 'package:nepse_market_app/screens/company/company_details_screen.dart';

class LiveTradingScreen extends StatefulWidget {
  const LiveTradingScreen({Key? key}) : super(key: key);

  @override
  _LiveTradingScreenState createState() => _LiveTradingScreenState();
}

class _LiveTradingScreenState extends State<LiveTradingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final formatter = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Provider.of<MarketProvider>(context, listen: false).loadLiveTrading();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Trading'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Consumer<MarketProvider>(
              builder: (context, marketProvider, child) {
                if (marketProvider.isLoadingLiveTrading) {
                  return Center(child: CircularProgressIndicator());
                }
  
                if (marketProvider.liveTradingError != null) {
                  return _buildErrorView(marketProvider.liveTradingError!);
                }
  
                if (marketProvider.liveTrading.isEmpty) {
                  return Center(child: Text('No trading data available'));
                }
  
                final filteredStocks = marketProvider.liveTrading
                  .where((stock) => stock.symbol.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                               stock.companyName.toLowerCase().contains(_searchQuery.toLowerCase()))
                  .toList();
  
                if (filteredStocks.isEmpty) {
                  return Center(child: Text('No results matching "$_searchQuery"'));
                }
  
                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildStocksList(filteredStocks),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by symbol or company name',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildStocksList(List filteredStocks) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredStocks.length,
      itemBuilder: (context, index) {
        final stock = filteredStocks[index];
        final isPositive = stock.change >= 0;
        
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
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
                              stock.symbol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              stock.companyName,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16,
                              color: isPositive ? Colors.green[700] : Colors.red[700],
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${isPositive ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: isPositive ? Colors.green[700] : Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCell('LTP', 'Rs. ${formatter.format(stock.ltp)}', isBold: true),
                      _buildInfoCell('Change', '${isPositive ? '+' : ''}${stock.change.toStringAsFixed(2)}'),
                      _buildInfoCell('High', 'Rs. ${formatter.format(stock.high)}'),
                      _buildInfoCell('Low', 'Rs. ${formatter.format(stock.low)}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCell(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          SizedBox(height: 16),
          Text(
            'Failed to load trading data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
          ),
        ],
      ),
    );
  }
}