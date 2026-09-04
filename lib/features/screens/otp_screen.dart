import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_controller.dart';
import '../../core/theme.dart';
class OtpScreen extends ConsumerStatefulWidget {
  final String email; const OtpScreen({super.key, required this.email});
  @override ConsumerState<OtpScreen> createState()=>_OtpScreenState();
}
class _OtpScreenState extends ConsumerState<OtpScreen>{
  final code=TextEditingController(); @override void dispose(){code.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final loading=ref.watch(authControllerProvider) is AuthLoading;
    final err=ref.watch(authControllerProvider); final message=err is AuthError?err.message:null;
    return Scaffold(appBar: AppBar(title: const Text('Verificar correo')),body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),child: Padding(padding: const EdgeInsets.all(24),child: GlassCard(child: Column(mainAxisSize: MainAxisSize.min,children:[const Icon(Icons.mark_email_read_outlined,size:52,color:AppColors.cyan),const SizedBox(height:18),const Text('Revisa tu correo',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(widget.email,textAlign:TextAlign.center,style:const TextStyle(color:AppColors.muted)),const SizedBox(height:20),TextField(controller:code,maxLength:8,textAlign:TextAlign.center,keyboardType:TextInputType.number,decoration:const InputDecoration(hintText:'Código'),),const SizedBox(height:8),FilledButton(onPressed:loading?null:() async=>ref.read(authControllerProvider.notifier).verifyEmailCode(widget.email,code.text),child:const Text('Verificar')),if(message!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(message,textAlign:TextAlign.center,style:const TextStyle(color:AppColors.red)))]))))));
  }
}
