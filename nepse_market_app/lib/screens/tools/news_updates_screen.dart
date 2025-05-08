import 'package:flutter/material.dart';

class NewsUpdatesScreen extends StatefulWidget {
  const NewsUpdatesScreen({Key? key}) : super(key: key);

  @override
  _NewsUpdatesScreenState createState() => _NewsUpdatesScreenState();
}

class _NewsUpdatesScreenState extends State<NewsUpdatesScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _news = [
    {
      'title': 'NEPSE Index Rises by 20 Points',
      'source': 'ShareSansar',
      'date': '2025-05-04',
      'summary': 'Nepal Stock Exchange (NEPSE) index saw a significant rise today, gaining 20 points.',
      'url': 'https://www.sharesansar.com',
      'imageUrl': 'https://via.placeholder.com/300x200',
    },
    {
      'title': 'NRB Announces New Monetary Policy',
      'source': 'Merolagani',
      'date': '2025-05-03',
      'summary': 'Nepal Rastra Bank has announced its monetary policy for the fiscal year 2082/83 BS.',
      'url': 'https://www.merolagani.com',
      'imageUrl': 'https://via.placeholder.com/300x200',
    },
    {
      'title': 'Commercial Banks Report 15% Growth in Profits',
      'source': 'NewBusinessAge',
      'date': '2025-05-02',
      'summary': 'Commercial banks have reported an average 15% growth in profits for the last quarter.',
      'url': 'https://www.newbusinessage.com',
      'imageUrl': 'https://via.placeholder.com/300x200',
    },
    {
      'title': 'IPO of Himalayan Bank Ltd. Oversubscribed',
      'source': 'ShareSansar',
      'date': '2025-05-01',
      'summary': 'The initial public offering of Himalayan Bank Ltd. has been oversubscribed by 40 times.',
      'url': 'https://www.sharesansar.com',
      'imageUrl': 'https://via.placeholder.com/300x200',
    },
  ];

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // In a real app, fetch from API
      await Future.delayed(Duration(seconds: 1));
      // News data is already pre-populated in _news
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load news: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Market News'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _loadNews,
                  child: ListView.builder(
                    itemCount: _news.length,
                    itemBuilder: (context, index) {
                      final news = _news[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(news['imageUrl']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    news['title'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Text(
                                        news['date'],
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Icon(Icons.source, size: 14, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Text(
                                        news['source'],
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Text(news['summary']),
                                  SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        // Launch URL in a real app
                                      },
                                      child: Text('Read More'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
