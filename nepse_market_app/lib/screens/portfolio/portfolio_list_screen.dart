import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nepse_market_app/providers/portfolio_provider.dart';
import 'package:nepse_market_app/screens/portfolio/portfolio_detail_screen.dart';
import 'package:nepse_market_app/screens/portfolio/add_portfolio_screen.dart';
import 'package:intl/intl.dart';

class PortfolioListScreen extends StatefulWidget {
  const PortfolioListScreen({Key? key}) : super(key: key);

  @override
  _PortfolioListScreenState createState() => _PortfolioListScreenState();
}

class _PortfolioListScreenState extends State<PortfolioListScreen> {
  final formatter = NumberFormat("#,##0.00", "en_US");
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPortfolios();
  }

  Future<void> _loadPortfolios() async {
    setState(() {
      _isLoading = true;
    });
    
    await Provider.of<PortfolioProvider>(context, listen: false).loadUserPortfolios();
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Portfolios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPortfolios,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _buildPortfolioList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPortfolioScreen()),
          ).then((_) => _loadPortfolios());
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Portfolio',
      ),
    );
  }

  Widget _buildPortfolioList() {
    final portfolioProvider = Provider.of<PortfolioProvider>(context);
    final portfolios = portfolioProvider.portfolios;
    
    if (portfolios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No portfolios yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first portfolio to start tracking your investments',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddPortfolioScreen()),
                ).then((_) => _loadPortfolios());
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Portfolio'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadPortfolios,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: portfolios.length,
        itemBuilder: (context, index) {
          final portfolio = portfolios[index];
          final totalInvestment = portfolio.totalInvestment;
          final currentValue = portfolio.totalCurrentValue;
          final profit = portfolio.totalProfit;
          final isProfit = profit >= 0;
          final profitPercentage = portfolio.profitPercentage;
          
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PortfolioDetailScreen(portfolioId: portfolio.id),
                  ),
                ).then((_) => _loadPortfolios());
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            portfolio.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isProfit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${isProfit ? '+' : ''}${profitPercentage.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isProfit ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (portfolio.description != null && portfolio.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          portfolio.description!,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Value',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rs. ${formatter.format(currentValue)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Investment',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rs. ${formatter.format(totalInvestment)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profit/Loss',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${isProfit ? '+' : ''}Rs. ${formatter.format(profit)}',
                              style: TextStyle(
                                color: isProfit ? Colors.green[700] : Colors.red[700],
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
                              'Holdings',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${portfolio.holdings?.length ?? 0}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}