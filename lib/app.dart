import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth_controller.dart';
import 'core/theme.dart';
import 'features/screens/auth_screen.dart';
import 'features/screens/home_screen.dart';
import 'features/screens/otp_screen.dart';

class NuminationApp extends ConsumerStatefulWidget{const NuminationApp({super.key});@override ConsumerState<NuminationApp> createState()=>_NuminationAppState();}
class _NuminationAppState extends ConsumerState<NuminationApp>{String? pendingEmail;
@override Widget build(BuildContext context){final auth=ref.watch(authControllerProvider);final home=auth is AuthAuthenticated;return MaterialApp(title:'Numination',debugShowCheckedModeBanner:false,theme:buildTheme(),home:home?const HomeScreen():pendingEmail!=null?OtpScreen(email:pendingEmail!):const AuthScreen());}
void setPendingEmail(String email)=>setState(()=>pendingEmail=email);
}
