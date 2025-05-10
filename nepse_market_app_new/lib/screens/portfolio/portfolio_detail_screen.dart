import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nepse_market_app/providers/portfolio_provider.dart';
import 'package:nepse_market_app/models/portfolio.dart';
import 'package:nepse_market_app/models/holding.dart';
import 'package:nepse_market_app/models/transaction.dart';
import 'package:nepse_market_app/screens/portfolio/add_holding_screen.dart';
import 'package:nepse_market_app/screens/portfolio/add_transaction_screen.dart';
import 'package:nepse_market_app/screens/company/company_details_screen.dart';
import 'package:intl/intl.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final int portfolioId;
  
  const PortfolioDetailScreen({
    Key? key, 
    required this.portfolioId,
  }) : super(key: key);

  @override
  _PortfolioDetailScreenState createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen> with SingleTickerProviderStateMixin {
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
      await Provider.of<PortfolioProvider>(context, listen: false)
          .loadPortfolioDetails(widget.portfolioId);
    } catch (e) {
      // Handle errors silently as they're stored in the provider
      print('Error loading portfolio details in screen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, portfolioProvider, child) {
        final portfolio = portfolioProvider.selectedPortfolio;
        final isLoading = portfolioProvider.isLoading;
        
        if (isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Portfolio Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        if (portfolio == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Portfolio Details')),
            body: const Center(child: Text('Portfolio not found')),
          );
        }
        
        return Scaffold(
          appBar: AppBar(
            title: Text(portfolio.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadPortfolioDetails,
                tooltip: 'Refresh',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'HOLDINGS'),
                Tab(text: 'TRANSACTIONS'),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildPortfolioSummary(portfolio),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHoldingsTab(portfolio),
                    _buildTransactionsTab(portfolioProvider.transactions),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildAddOptionsSheet(portfolio.id),
              );
            },
            child: const Icon(Icons.add),
            tooltip: 'Add',
          ),
        );
      },
    );
  }
  
  Widget _buildPortfolioSummary(Portfolio portfolio) {
    final totalInvestment = portfolio.totalInvestment;
    final currentValue = portfolio.totalCurrentValue;
    final profit = portfolio.totalProfit;
    final isProfit = profit >= 0;
    final profitPercentage = portfolio.profitPercentage;
    final todaysPL = portfolio.todaysProfitLoss;
    final isTodayProfit = todaysPL >= 0;
    
    print('Portfolio summary - holdings: ${portfolio.holdings?.length ?? 0}');
    print('Portfolio summary - investment: $totalInvestment');
    print('Portfolio summary - current value: $currentValue');
    print('Portfolio summary - profit: $profit');
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rs. ${formatter.format(currentValue)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isProfit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
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
          const SizedBox(height: 4),
          Text(
            'Total Current Value',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    'Rs. ${formatter.format(totalInvestment)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Investment',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${isProfit ? '+' : ''}Rs. ${formatter.format(profit)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500, 
                      color: isProfit ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Overall Profit/Loss',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${isTodayProfit ? '+' : ''}Rs. ${formatter.format(todaysPL)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isTodayProfit ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Today\'s P/L',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildHoldingsTab(Portfolio portfolio) {
    final holdings = portfolio.holdings;    
    print('Building holdings tab, holdings: ${holdings?.length ?? 0}');
    
    if (holdings == null || holdings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No holdings yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Add your first holding to start tracking your investments',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddHoldingScreen(portfolioId: portfolio.id),
                  ),
                ).then((_) => _loadPortfolioDetails());
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Holding'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadPortfolioDetails,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: holdings.length,
        itemBuilder: (context, index) {
          final holding = holdings[index];
          final isProfit = holding.profit >= 0;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CompanyDetailsScreen(
                      symbol: holding.symbol,
                      companyName: holding.companyName ?? '',
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    const SizedBox(height: 12),
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
                            const SizedBox(height: 4),
                            Text(
                              'Rs. ${formatter.format(holding.currentPrice ?? holding.averageBuyPrice)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                            const SizedBox(height: 4),
                            Text('Rs. ${formatter.format(holding.averageBuyPrice)}'),
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
                              'Quantity',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text('${holding.quantity}'),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Today\'s P/L',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${holding.todaysProfitLoss >= 0 ? '+' : ''}Rs. ${formatter.format(holding.todaysProfitLoss)}',
                              style: TextStyle(
                                color: holding.todaysProfitLoss >= 0 ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Investment',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rs. ${formatter.format(holding.investmentValue)}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Current Value',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rs. ${formatter.format(holding.currentValue)}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Profit/Loss',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
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
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildTransactionsTab(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Add a transaction to track your buying and selling activities',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        
        return ListTile(
          title: Text(transaction.symbol),
          subtitle: Text('${transaction.quantity} @ ${transaction.price}'),
          trailing: Text(transaction.type),
        );
      }
    );
  }
  
  Widget _buildAddOptionsSheet(int portfolioId) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add to Portfolio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOptionButton(
                icon: Icons.add_chart,
                label: 'Holding',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddHoldingScreen(portfolioId: portfolioId),
                    ),
                  ).then((_) => _loadPortfolioDetails());
                },
              ),
              _buildOptionButton(
                icon: Icons.receipt_long,
                label: 'Transaction',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTransactionScreen(portfolioId: portfolioId),
                    ),
                  ).then((_) => _loadPortfolioDetails());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}