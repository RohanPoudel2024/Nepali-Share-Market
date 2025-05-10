import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

Future<Interceptor?> createCookieManager() async {
  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    final appDocPath = appDocDir.path;
    final cookieJar = PersistCookieJar(storage: FileStorage("$appDocPath/.cookies/"));
    return CookieManager(cookieJar);
  } catch (e) {
    print('Error creating native cookie manager: $e');
    // Fallback to in-memory cookie jar
    return CookieManager(CookieJar());
  }
}