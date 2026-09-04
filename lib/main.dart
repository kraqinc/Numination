import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  if (Env.supabaseUrl.isEmpty || Env.supabasePublishableKey.isEmpty) {
    runApp(const ProviderScope(child: _MissingEnvApp()));
    return;
  }
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabasePublishableKey);
  runApp(const ProviderScope(child: NuminationApp()));
}
class _MissingEnvApp extends StatelessWidget{const _MissingEnvApp();@override Widget build(BuildContext context)=>MaterialApp(theme:buildTheme(),home:const Scaffold(body:Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Numination: configura SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY en .env.',textAlign:TextAlign.center)))));}
